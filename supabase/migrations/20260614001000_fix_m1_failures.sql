-- supabase/migrations/20260614001000_fix_m1_failures.sql

-- 1. R6 check_and_record_rate_limit: Fix rate limit bypass, check business from profile account_type, and fix null comparison in target_id
CREATE OR REPLACE FUNCTION public.check_and_record_rate_limit(
  user_id uuid,
  action text,
  target_id uuid DEFAULT null
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_action text := nullif(btrim(action), '');
  v_count integer;
  v_limit integer;
  v_window interval;
  v_trust_score integer;
  v_is_plus boolean;
  v_account_type text;
BEGIN
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Fix Issue 2: Ensure users can only query/record for their own account
  IF auth.uid() IS DISTINCT FROM user_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  IF v_action IS NULL THEN
    RAISE EXCEPTION 'invalid_rate_limit_action';
  END IF;

  -- Determine account type and trust score from profiles table (Fix Issue 4: check profile rather than business_accounts)
  SELECT account_type, COALESCE(trust_score, 50)
  INTO v_account_type, v_trust_score
  FROM public.profiles
  WHERE profiles.user_id = check_and_record_rate_limit.user_id;

  -- 1. Determine limit and window based on the action
  IF v_action = 'create_event' THEN
    IF v_account_type = 'business' THEN
      -- Check if user has an active Plus business account
      SELECT EXISTS (
        SELECT 1
        FROM public.business_accounts ba
        JOIN public.business_plus_subscriptions bps ON bps.business_account_id = ba.id
        WHERE ba.owner_user_id = user_id
          AND ba.status IN ('active', 'pending')
          AND bps.status = 'active'
          AND bps.starts_at <= now()
          AND (bps.ends_at IS NULL OR bps.ends_at >= now())
      ) INTO v_is_plus;

      IF v_is_plus THEN
        v_limit := 30;
        v_window := INTERVAL '30 days';
      ELSE
        v_limit := 3;
        v_window := INTERVAL '30 days';
      END IF;
    ELSE
      -- Regular user: check trust score
      IF v_trust_score >= 60 THEN
        v_limit := 3;
        v_window := INTERVAL '24 hours';
      ELSE
        v_limit := 2;
        v_window := INTERVAL '24 hours';
      END IF;
    END IF;

  ELSIF v_action = 'create_post' THEN
    v_limit := 10;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'comment_create' THEN
    v_limit := 30;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'follow_request' THEN
    v_limit := 30;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'report_create' THEN
    v_limit := 10;
    v_window := INTERVAL '24 hours';

  ELSIF v_action = 'event_join_request' THEN
    v_limit := 20;
    v_window := INTERVAL '24 hours';

  ELSIF v_action = 'event_join_review' THEN
    v_limit := 60;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'business_application_submit' THEN
    v_limit := 1;
    v_window := INTERVAL '24 hours';

  ELSIF v_action = 'business_application_review' THEN
    v_limit := 60;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'business_attendance_mark' THEN
    v_limit := 120;
    v_window := INTERVAL '1 hour';

  ELSIF v_action = 'business_review_submit' THEN
    v_limit := 1;
    v_window := NULL; -- per target_id, no time window

  ELSIF v_action = 'feedback_submit' THEN
    v_limit := 5;
    v_window := INTERVAL '24 hours';

  ELSE
    RAISE EXCEPTION 'invalid_rate_limit_action';
  END IF;

  -- 2. Check the rate limit count
  -- Fix Issue 6: target_id NULL comparison bug by using IS NOT DISTINCT FROM
  IF v_window IS NULL AND v_action = 'business_review_submit' THEN
    SELECT COUNT(*)::integer INTO v_count
    FROM public.rate_limit_events event
    WHERE event.user_id = check_and_record_rate_limit.user_id
      AND event.action = v_action
      AND event.target_id IS NOT DISTINCT FROM check_and_record_rate_limit.target_id;
  ELSE
    SELECT COUNT(*)::integer INTO v_count
    FROM public.rate_limit_events event
    WHERE event.user_id = check_and_record_rate_limit.user_id
      AND event.action = v_action
      AND event.created_at >= now() - v_window;
  END IF;

  IF v_count >= v_limit THEN
    RAISE EXCEPTION 'rate_limit_exceeded: Çok fazla işlem yaptın. Biraz sonra tekrar dene.'
      USING HINT = 'Çok fazla işlem yaptın. Biraz sonra tekrar dene.';
  END IF;

  -- 3. Record the rate limit event
  INSERT INTO public.rate_limit_events (user_id, action, target_id)
  VALUES (user_id, v_action, target_id);

  RETURN true;
END;
$$;


-- 2. R1/R7 business_accounts_set_profile_identity: Fix security search path (Issue 3) and out-of-sync business updates (Issue 5)
CREATE OR REPLACE FUNCTION public.set_profile_business_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- If TG_OP is INSERT and status is active/pending, or TG_OP is UPDATE and status is changed to active/pending
  IF (TG_OP = 'INSERT' AND NEW.status IN ('active', 'pending')) OR
     (TG_OP = 'UPDATE' AND NEW.status IN ('active', 'pending') AND (OLD.status IS DISTINCT FROM NEW.status)) THEN
    UPDATE public.profiles profile
    SET personal_full_name = COALESCE(profile.personal_full_name, profile.first_name),
        personal_username = COALESCE(profile.personal_username, profile.username),
        personal_bio = COALESCE(profile.personal_bio, profile.bio),
        personal_avatar_url = COALESCE(profile.personal_avatar_url, profile.avatar_url),
        account_type = 'business',
        business_account_id = NEW.id,
        first_name = NEW.name,
        username = NEW.username,
        bio = COALESCE(NULLIF(NEW.description, ''), profile.bio),
        city = COALESCE(NULLIF(NEW.city, ''), profile.city),
        district = COALESCE(NULLIF(NEW.district, ''), profile.district),
        is_private = false,
        is_profile_completed = true,
        updated_at = now()
    WHERE profile.user_id = NEW.owner_user_id;
  
  -- If TG_OP is UPDATE and status is not changed (or stays active/pending), propagate updates if the profile is currently active in business mode for this business account
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.profiles profile
    SET first_name = NEW.name,
        username = NEW.username,
        bio = COALESCE(NULLIF(NEW.description, ''), profile.bio),
        city = COALESCE(NULLIF(NEW.city, ''), profile.city),
        district = COALESCE(NULLIF(NEW.district, ''), profile.district),
        updated_at = now()
    WHERE profile.user_id = NEW.owner_user_id
      AND profile.account_type = 'business'
      AND profile.business_account_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS business_accounts_set_profile_identity ON public.business_accounts;
CREATE TRIGGER business_accounts_set_profile_identity
  AFTER INSERT OR UPDATE ON public.business_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_profile_business_identity();

-- Reload schema
NOTIFY pgrst, 'reload schema';
