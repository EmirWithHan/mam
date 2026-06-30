-- Migration: Business Plus subscription, cache column, boosts, and pinning
-- Timestamp: 20260621010000

-- 1. Add performance cache and enhanced profile columns to business_accounts
ALTER TABLE public.business_accounts 
  ADD COLUMN IF NOT EXISTS is_plus_active boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS gallery_urls text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS pinned_event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS custom_theme_color text,
  ADD COLUMN IF NOT EXISTS highlighted_services text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS facebook_url text,
  ADD COLUMN IF NOT EXISTS twitter_url text,
  ADD COLUMN IF NOT EXISTS youtube_url text;

-- 2. Create authoritative live entitlement check
CREATE OR REPLACE FUNCTION public.check_business_plus_active(p_business_account_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.business_plus_subscriptions subscription
    WHERE subscription.business_account_id = p_business_account_id
      AND subscription.status = 'active'
      AND subscription.starts_at <= now()
      AND (subscription.ends_at IS NULL OR subscription.ends_at > now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_business_plus_active(uuid) TO authenticated;

-- 3. Cache update function & trigger
CREATE OR REPLACE FUNCTION public.update_business_account_plus_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(id)
  WHERE id = COALESCE(new.business_account_id, old.business_account_id);
  RETURN COALESCE(new, old);
END;
$$;

DROP TRIGGER IF EXISTS update_business_account_plus_status_trigger 
  ON public.business_plus_subscriptions;
CREATE TRIGGER update_business_account_plus_status_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.business_plus_subscriptions
FOR EACH ROW EXECUTE FUNCTION public.update_business_account_plus_status();

-- 4. Cache reconciliation RPC
CREATE OR REPLACE FUNCTION public.reconcile_all_business_plus_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.business_accounts ba
  SET is_plus_active = public.check_business_plus_active(ba.id);
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_all_business_plus_cache() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_all_business_plus_cache() TO authenticated;

-- 5. Admin entitlement RPC (Manual override for testing)
CREATE OR REPLACE FUNCTION public.admin_set_business_plus_subscription(
  p_business_account_id uuid,
  p_status text,
  p_duration_days integer DEFAULT 30
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_subscription_id uuid;
  v_ends_at timestamptz;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_duration_days IS NOT NULL THEN
    v_ends_at := now() + (p_duration_days || ' days')::interval;
  ELSE
    v_ends_at := NULL;
  END IF;

  -- Deactivate active
  UPDATE public.business_plus_subscriptions
  SET status = 'cancelled',
      updated_at = now()
  WHERE business_account_id = p_business_account_id
    AND status = 'active';

  -- Insert new
  INSERT INTO public.business_plus_subscriptions (
    business_account_id,
    status,
    starts_at,
    ends_at
  )
  VALUES (
    p_business_account_id,
    p_status,
    now(),
    v_ends_at
  )
  RETURNING id INTO v_subscription_id;

  -- Sync cache immediately
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  RETURN v_subscription_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_business_plus_subscription(uuid, text, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_business_plus_subscription(uuid, text, integer) TO authenticated;

-- 6. Business event boosts table
CREATE TABLE IF NOT EXISTS public.business_event_boosts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  boosted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.business_event_boosts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Business owners can view own boosts" ON public.business_event_boosts;
CREATE POLICY "Business owners can view own boosts"
  ON public.business_event_boosts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = business_event_boosts.business_account_id
        AND ba.owner_user_id = auth.uid()
    )
  );

-- 7. Boost Event RPC (with lock to prevent concurrent bypass)
CREATE OR REPLACE FUNCTION public.boost_business_event(
  p_business_account_id uuid,
  p_event_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_boost_count integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_local_now timestamp := timezone('Europe/Istanbul', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Concurrency Lock on Business account level
  PERFORM pg_advisory_xact_lock(
    hashtextextended('business_boosts_lock:' || p_business_account_id::text, 0)
  );

  -- Live subscription check
  IF NOT public.check_business_plus_active(p_business_account_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  -- Ownership check
  IF NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = p_business_account_id AND owner_user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT * INTO v_event
  FROM public.events
  WHERE id = p_event_id AND organizer_business_id = p_business_account_id
  FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF v_event.status <> 'active' THEN
    RAISE EXCEPTION 'event_not_active';
  END IF;

  IF v_event.event_date < now() THEN
    RAISE EXCEPTION 'event_expired';
  END IF;

  IF v_event.moderation_status <> 'approved' THEN
    RAISE EXCEPTION 'event_not_approved';
  END IF;

  -- Capacity check
  IF COALESCE(v_event.capacity_total, 0) > 0 AND v_event.approved_count >= v_event.capacity_total THEN
    RAISE EXCEPTION 'event_is_full';
  END IF;

  -- Check duplicate boost
  IF v_event.is_sponsored AND v_event.sponsored_until >= now() THEN
    RAISE EXCEPTION 'event_already_boosted';
  END IF;

  -- Quota calculation
  v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
  v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
    at time zone 'Europe/Istanbul';

  SELECT COUNT(*)::integer INTO v_boost_count
  FROM public.business_event_boosts
  WHERE business_account_id = p_business_account_id
    AND boosted_at >= v_period_start
    AND boosted_at < v_period_end;

  IF v_boost_count >= 5 THEN
    RAISE EXCEPTION 'boost_limit_exceeded';
  END IF;

  -- Insert boost
  INSERT INTO public.business_event_boosts (
    business_account_id,
    event_id,
    boosted_at,
    expires_at
  )
  VALUES (
    p_business_account_id,
    p_event_id,
    now(),
    now() + interval '24 hours'
  );

  -- Apply to event
  UPDATE public.events
  SET is_sponsored = true,
      sponsored_until = now() + interval '24 hours',
      sponsored_priority = 1
  WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.boost_business_event(uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.boost_business_event(uuid, uuid) TO authenticated;

-- 8. Boost Stats RPC
CREATE OR REPLACE FUNCTION public.get_business_boost_stats(p_business_account_id uuid)
RETURNS TABLE (
  boosts_used integer,
  boosts_allowed integer,
  period_end timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_boost_count integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_local_now timestamp := timezone('Europe/Istanbul', now());
  v_is_plus boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_is_plus := public.check_business_plus_active(p_business_account_id);

  v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
  v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
    at time zone 'Europe/Istanbul';

  SELECT COUNT(*)::integer INTO v_boost_count
  FROM public.business_event_boosts
  WHERE business_account_id = p_business_account_id
    AND boosted_at >= v_period_start
    AND boosted_at < v_period_end;

  RETURN QUERY SELECT
    COALESCE(v_boost_count, 0),
    CASE WHEN v_is_plus THEN 5 ELSE 0 END,
    v_period_end;
END;
$$;

REVOKE ALL ON FUNCTION public.get_business_boost_stats(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_business_boost_stats(uuid) TO authenticated;

-- 9. Pin Event RPC
CREATE OR REPLACE FUNCTION public.pin_business_event(
  p_business_account_id uuid,
  p_event_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verify active subscription
  IF p_event_id IS NOT NULL AND NOT public.check_business_plus_active(p_business_account_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  -- Verify ownership
  IF NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = p_business_account_id AND owner_user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_event_id IS NULL THEN
    UPDATE public.business_accounts
    SET pinned_event_id = NULL
    WHERE id = p_business_account_id;
    RETURN;
  END IF;

  SELECT * INTO v_event
  FROM public.events
  WHERE id = p_event_id AND organizer_business_id = p_business_account_id;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF v_event.status <> 'active' THEN
    RAISE EXCEPTION 'event_not_active';
  END IF;

  IF v_event.event_date < now() THEN
    RAISE EXCEPTION 'event_expired';
  END IF;

  IF v_event.moderation_status <> 'approved' THEN
    RAISE EXCEPTION 'event_not_approved';
  END IF;

  UPDATE public.business_accounts
  SET pinned_event_id = p_event_id
  WHERE id = p_business_account_id;
END;
$$;

REVOKE ALL ON FUNCTION public.pin_business_event(uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.pin_business_event(uuid, uuid) TO authenticated;

-- 10. Auto Unpin Trigger
CREATE OR REPLACE FUNCTION public.auto_unpin_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF new.status <> 'active' OR new.moderation_status <> 'approved' OR new.event_date < now() THEN
    UPDATE public.business_accounts
    SET pinned_event_id = NULL
    WHERE pinned_event_id = new.id;
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS auto_unpin_event_trigger ON public.events;
CREATE TRIGGER auto_unpin_event_trigger
AFTER UPDATE OF status, moderation_status, event_date ON public.events
FOR EACH ROW EXECUTE FUNCTION public.auto_unpin_event();

-- 11. Redefine get_event_creation_quota to use check_business_plus_active
CREATE OR REPLACE FUNCTION public.get_event_creation_quota(
  p_is_business_event boolean,
  p_business_account_id uuid DEFAULT null,
  p_creation_request_id uuid DEFAULT null
)
RETURNS TABLE (
  quota_tier text,
  error_code text,
  allowed_limit integer,
  counted_total integer,
  period_start timestamptz,
  period_end timestamptz,
  is_allowed boolean,
  is_business_plus_eligible boolean,
  already_inserted boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_local_now timestamp := timezone('Europe/Istanbul', now());
  v_trust_score integer := 50;
  v_is_active_business boolean := false;
  v_is_plus boolean := false;
  v_quota_tier text;
  v_error_code text;
  v_limit integer;
  v_count integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_plus_eligible boolean := false;
  v_already_inserted boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_creation_request_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.events event
      WHERE event.host_id = v_user_id
        AND event.creation_request_id = p_creation_request_id
    ) INTO v_already_inserted;
  END IF;

  IF COALESCE(p_is_business_event, false) THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.business_accounts business
      WHERE business.id = p_business_account_id
        AND business.owner_user_id = v_user_id
        AND business.status = 'active'
    ) INTO v_is_active_business;

    IF NOT v_is_active_business THEN
      RAISE EXCEPTION 'invalid_active_business_account';
    END IF;

    -- Authoritative live check
    v_is_plus := public.check_business_plus_active(p_business_account_id);

    v_quota_tier := CASE WHEN v_is_plus THEN 'business_plus' ELSE 'business_standard' END;
    v_error_code := CASE
      WHEN v_is_plus THEN 'business_plus_monthly_limit'
      ELSE 'business_monthly_limit'
    END;
    v_limit := CASE WHEN v_is_plus THEN 30 ELSE 3 END;
    v_plus_eligible := NOT v_is_plus;
    v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
    v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
      at time zone 'Europe/Istanbul';

    SELECT count(*)::integer
    INTO v_count
    FROM public.event_creation_quota_events quota_event
    WHERE quota_event.business_account_id = p_business_account_id
      AND quota_event.created_at >= v_period_start
      AND quota_event.created_at < v_period_end;
  ELSE
    SELECT COALESCE(profile.trust_score, 50)
    INTO v_trust_score
    FROM public.profiles profile
    WHERE profile.user_id = v_user_id;

    v_trust_score := COALESCE(v_trust_score, 50);
    v_quota_tier := CASE
      WHEN v_trust_score >= 60 THEN 'normal_trusted'
      ELSE 'normal_new'
    END;
    v_error_code := CASE
      WHEN v_trust_score >= 60 THEN 'normal_trusted_daily_limit'
      ELSE 'normal_new_daily_limit'
    END;
    v_limit := CASE WHEN v_trust_score >= 60 THEN 3 ELSE 2 END;
    v_period_start := date_trunc('day', v_local_now) at time zone 'Europe/Istanbul';
    v_period_end := (date_trunc('day', v_local_now) + interval '1 day')
      at time zone 'Europe/Istanbul';

    SELECT count(*)::integer
    INTO v_count
    FROM public.event_creation_quota_events quota_event
    WHERE quota_event.owner_user_id = v_user_id
      AND quota_event.business_account_id IS NULL
      AND quota_event.created_at >= v_period_start
      AND quota_event.created_at < v_period_end;
  END IF;

  RETURN QUERY SELECT
    v_quota_tier,
    v_error_code,
    v_limit,
    COALESCE(v_count, 0),
    v_period_start,
    v_period_end,
    v_already_inserted OR COALESCE(v_count, 0) < v_limit,
    v_plus_eligible,
    v_already_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.get_event_creation_quota(boolean, uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_event_creation_quota(boolean, uuid, uuid) TO authenticated;

-- Sync initial cache values
SELECT public.reconcile_all_business_plus_cache();

NOTIFY pgrst, 'reload schema';
