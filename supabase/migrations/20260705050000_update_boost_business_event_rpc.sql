-- Drop the old boost_business_event function with two parameters
DROP FUNCTION IF EXISTS public.boost_business_event(uuid, uuid);

-- Add unique constraint on event_id in business_event_boosts table
-- so that one event can only ever be boosted once.
ALTER TABLE public.business_event_boosts
  DROP CONSTRAINT IF EXISTS business_event_boosts_event_id_unique;

ALTER TABLE public.business_event_boosts
  ADD CONSTRAINT business_event_boosts_event_id_unique UNIQUE (event_id);

-- Update protect_event_sponsorship_fields trigger function to allow trusted boost updates
CREATE OR REPLACE FUNCTION public.protect_event_sponsorship_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Allow updates if performing a trusted boost operation
  IF current_setting('request.boost_in_progress', true) = 'true' THEN
    RETURN new;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    IF COALESCE(new.is_sponsored, false) = false
       AND new.sponsored_until IS NULL
       AND COALESCE(new.sponsored_priority, 0) = 0
       AND exists (
         SELECT 1
         FROM public.business_accounts business
         WHERE business.id = new.organizer_business_id
           AND business.owner_user_id = auth.uid()
           AND business.status = 'deleted'
       ) THEN
      RETURN new;
    END IF;

    RAISE EXCEPTION 'event_sponsorship_fields_are_admin_only';
  END IF;

  IF new.is_sponsored AND new.organizer_type <> 'business' THEN
    RAISE EXCEPTION 'sponsored_event_must_be_business';
  END IF;

  IF new.is_sponsored AND NOT exists (
    SELECT 1
    FROM public.business_accounts business
    WHERE business.id = new.organizer_business_id
      AND business.status = 'active'
      AND COALESCE(business.is_verified, false)
  ) THEN
    RAISE EXCEPTION 'sponsored_event_requires_verified_business';
  END IF;

  RETURN new;
END;
$$;

-- Redefine boost_business_event to accept only p_event_id and return statistics
CREATE OR REPLACE FUNCTION public.boost_business_event(p_event_id uuid)
RETURNS TABLE (
  is_active boolean,
  boost_expires_at timestamptz,
  monthly_used integer,
  monthly_remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_business_id uuid;
  v_boost_count integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_local_now timestamp := timezone('Europe/Istanbul', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Fetch the event details
  SELECT * INTO v_event
  FROM public.events
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Get organizing business account
  v_business_id := v_event.organizer_business_id;
  IF v_business_id IS NULL OR COALESCE(v_event.organizer_type, 'user') <> 'business' THEN
    RAISE EXCEPTION 'business_account_required';
  END IF;

  -- Ownership check
  IF NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = v_business_id AND owner_user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Basic validation of event state
  IF v_event.status <> 'active' THEN
    RAISE EXCEPTION 'event_not_active';
  END IF;

  IF v_event.event_date < now() THEN
    RAISE EXCEPTION 'event_expired';
  END IF;

  -- Fetch monthly quota stats
  v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
  v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
    at time zone 'Europe/Istanbul';

  SELECT COUNT(*)::integer INTO v_boost_count
  FROM public.business_event_boosts
  WHERE business_account_id = v_business_id
    AND boosted_at >= v_period_start
    AND boosted_at < v_period_end;

  -- Check if the event already has an active boost
  IF EXISTS (
    SELECT 1 FROM public.business_event_boosts
    WHERE event_id = p_event_id AND expires_at >= now()
  ) THEN
    RETURN QUERY SELECT
      true,
      (SELECT expires_at FROM public.business_event_boosts WHERE event_id = p_event_id LIMIT 1),
      COALESCE(v_boost_count, 0),
      CASE WHEN (5 - COALESCE(v_boost_count, 0)) < 0 THEN 0 ELSE (5 - COALESCE(v_boost_count, 0)) END;
    RETURN;
  END IF;

  -- Check if the event was already boosted before and expired
  IF EXISTS (
    SELECT 1 FROM public.business_event_boosts
    WHERE event_id = p_event_id
  ) THEN
    RAISE EXCEPTION 'event_already_boosted_once';
  END IF;

  -- Live subscription check
  IF NOT public.check_business_plus_active(v_business_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  -- Check monthly quota limit
  IF v_boost_count >= 5 THEN
    RAISE EXCEPTION 'boost_limit_reached';
  END IF;

  -- Insert new boost
  INSERT INTO public.business_event_boosts (
    business_account_id,
    event_id,
    boosted_at,
    expires_at
  )
  VALUES (
    v_business_id,
    p_event_id,
    now(),
    now() + interval '24 hours'
  );

  -- Set request.boost_in_progress to true to bypass admin-only check in trigger
  PERFORM set_config('request.boost_in_progress', 'true', true);

  -- Apply boost priority and timestamps to the event
  UPDATE public.events
  SET is_sponsored = true,
      sponsored_until = now() + interval '24 hours',
      sponsored_priority = 1
  WHERE id = p_event_id;

  RETURN QUERY SELECT
    true,
    (now() + interval '24 hours'),
    COALESCE(v_boost_count, 0) + 1,
    CASE WHEN (5 - (COALESCE(v_boost_count, 0) + 1)) < 0 THEN 0 ELSE (5 - (COALESCE(v_boost_count, 0) + 1)) END;
END;
$$;

REVOKE ALL ON FUNCTION public.boost_business_event(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.boost_business_event(uuid) TO authenticated;
