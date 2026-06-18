-- supabase/migrations/20260613161000_imp_m1_updates.sql

-- 1. R1 Business Profile Privacy Rule
-- Data cleanup: set is_private = false for any existing business accounts
UPDATE public.profiles
SET is_private = false
WHERE account_type = 'business' AND is_private = true;

-- Add check constraint to profiles
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS check_business_profile_not_private;

ALTER TABLE public.profiles
  ADD CONSTRAINT check_business_profile_not_private
  CHECK (
    (account_type = 'business' AND is_private = false) OR (account_type != 'business')
  );

-- Create trigger function to enforce is_private = false on business accounts
CREATE OR REPLACE FUNCTION public.enforce_business_profile_privacy()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.account_type = 'business' THEN
    NEW.is_private := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_business_profile_privacy ON public.profiles;
CREATE TRIGGER trg_enforce_business_profile_privacy
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_business_profile_privacy();


-- 2. R1 Updated switch_profile_account_type and set_profile_business_identity
CREATE OR REPLACE FUNCTION public.switch_profile_account_type(p_account_type text)
RETURNS setof public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_business public.business_accounts%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_account_type NOT IN ('user', 'business') THEN
    RAISE EXCEPTION 'invalid_account_type';
  END IF;

  IF p_account_type = 'business' THEN
    SELECT *
    INTO v_business
    FROM public.business_accounts business
    WHERE business.owner_user_id = v_user_id
      AND business.status IN ('active', 'pending')
    ORDER BY
      CASE business.status WHEN 'active' then 0 when 'pending' then 1 else 2 END,
      business.created_at DESC,
      business.id DESC
    LIMIT 1;

    IF v_business.id IS NULL THEN
      RAISE EXCEPTION 'business_account_missing';
    END IF;

    UPDATE public.profiles profile
    SET personal_full_name = COALESCE(profile.personal_full_name, profile.first_name),
        personal_username = COALESCE(profile.personal_username, profile.username),
        personal_bio = COALESCE(profile.personal_bio, profile.bio),
        personal_avatar_url = COALESCE(profile.personal_avatar_url, profile.avatar_url),
        account_type = 'business',
        business_account_id = v_business.id,
        first_name = v_business.name,
        username = v_business.username,
        bio = COALESCE(NULLIF(v_business.description, ''), profile.bio),
        city = COALESCE(NULLIF(v_business.city, ''), profile.city),
        district = COALESCE(NULLIF(v_business.district, ''), profile.district),
        is_private = false,
        is_profile_completed = true,
        updated_at = now()
    WHERE profile.user_id = v_user_id;
  ELSE
    UPDATE public.profiles profile
    SET account_type = 'user',
        first_name = COALESCE(profile.personal_full_name, profile.first_name),
        username = COALESCE(profile.personal_username, profile.username),
        bio = COALESCE(profile.personal_bio, profile.bio),
        avatar_url = COALESCE(profile.personal_avatar_url, profile.avatar_url),
        updated_at = now()
    WHERE profile.user_id = v_user_id;

    UPDATE public.events event
    SET status = 'cancelled',
        updated_at = now()
    WHERE event.host_id = v_user_id
      AND COALESCE(event.organizer_type, 'user') = 'business'
      AND event.status = 'active'
      AND event.event_date >= now();
  END IF;

  RETURN query
  SELECT *
  FROM public.profiles
  WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_profile_business_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('active', 'pending') THEN
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
  END IF;

  RETURN NEW;
END;
$$;


-- 3. R6 check_and_record_rate_limit Signature Update & Internal Rules
-- Drop old signature
DROP FUNCTION IF EXISTS public.check_and_record_rate_limit(text, integer, integer, uuid);

-- Create new signature
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
  v_is_business boolean;
BEGIN
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_action IS NULL THEN
    RAISE EXCEPTION 'invalid_rate_limit_action';
  END IF;

  -- 1. Determine limit and window based on the action
  IF v_action = 'create_event' THEN
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
      -- Check if user has a standard business account
      SELECT EXISTS (
        SELECT 1
        FROM public.business_accounts ba
        WHERE ba.owner_user_id = user_id
          AND ba.status IN ('active', 'pending')
      ) INTO v_is_business;

      IF v_is_business THEN
        v_limit := 3;
        v_window := INTERVAL '30 days';
      ELSE
        -- Regular user: check trust score
        SELECT COALESCE(trust_score, 50) INTO v_trust_score
        FROM public.profiles
        WHERE profiles.user_id = check_and_record_rate_limit.user_id;

        IF v_trust_score >= 60 THEN
          v_limit := 3;
          v_window := INTERVAL '24 hours';
        ELSE
          v_limit := 2;
          v_window := INTERVAL '24 hours';
        END IF;
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
  IF v_window IS NULL AND v_action = 'business_review_submit' THEN
    SELECT COUNT(*)::integer INTO v_count
    FROM public.rate_limit_events event
    WHERE event.user_id = check_and_record_rate_limit.user_id
      AND event.action = v_action
      AND event.target_id = check_and_record_rate_limit.target_id;
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

REVOKE ALL ON FUNCTION public.check_and_record_rate_limit(uuid, text, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.check_and_record_rate_limit(uuid, text, uuid) TO authenticated;


-- 4. R7 Business Plus Schema & custom fields
ALTER TABLE public.business_accounts
  ADD COLUMN IF NOT EXISTS custom_theme_color text,
  ADD COLUMN IF NOT EXISTS pinned_event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gallery_urls text[];

-- Check constraint on hex regex
ALTER TABLE public.business_accounts
  DROP CONSTRAINT IF EXISTS business_accounts_custom_theme_color_check;

ALTER TABLE public.business_accounts
  ADD CONSTRAINT business_accounts_custom_theme_color_check
  CHECK (custom_theme_color IS NULL OR custom_theme_color ~* '^#[0-9A-Fa-f]{6}$');

-- Create business_plus_subscriptions table
CREATE TABLE IF NOT EXISTS public.business_plus_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_plus_subscriptions_status_check
    CHECK (status IN ('active', 'expired', 'cancelled'))
);

-- Enable RLS
ALTER TABLE public.business_plus_subscriptions ENABLE ROW LEVEL SECURITY;

-- SELECT policy for authenticated users
DROP POLICY IF EXISTS "Authenticated users can select business plus subscriptions" ON public.business_plus_subscriptions;
CREATE POLICY "Authenticated users can select business plus subscriptions"
  ON public.business_plus_subscriptions
  FOR SELECT
  TO authenticated
  USING (true);


-- 5. Update helper RPC functions
-- Update get_public_profile_detail
DROP FUNCTION IF EXISTS public.get_public_profile_detail(uuid);
CREATE FUNCTION public.get_public_profile_detail(p_user_id uuid)
RETURNS table (
  user_id uuid,
  username text,
  tag text,
  first_name text,
  last_name text,
  city text,
  district text,
  avatar_url text,
  bio text,
  trust_score integer,
  is_private boolean,
  account_type text,
  business_account_id uuid,
  business_name text,
  business_username text,
  business_tag text,
  business_category text,
  business_custom_category text,
  business_city text,
  business_district text,
  business_description text,
  business_logo_url text,
  business_cover_url text,
  business_is_verified boolean,
  business_custom_theme_color text,
  business_pinned_event_id uuid,
  business_gallery_urls text[],
  business_is_plus_active boolean,
  followers_count bigint,
  following_count bigint,
  is_following boolean,
  is_followed_by boolean,
  pending_follow_request_by_me boolean,
  can_view_extended_profile boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    profile.user_id,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.last_name::text,
    profile.city::text,
    profile.district::text,
    profile.avatar_url::text,
    profile.bio::text,
    profile.trust_score::integer,
    coalesce(profile.is_private, false),
    profile.account_type::text,
    business.id,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    business.category::text,
    business.custom_category::text,
    business.city::text,
    business.district::text,
    business.description::text,
    business.logo_url::text,
    business.cover_url::text,
    coalesce(business.is_verified, false),
    business.custom_theme_color::text,
    business.pinned_event_id,
    business.gallery_urls,
    exists (
      select 1
      from public.business_plus_subscriptions bps
      where bps.business_account_id = business.id
        and bps.status = 'active'
        and bps.starts_at <= now()
        and (bps.ends_at is null or bps.ends_at >= now())
    ) as business_is_plus_active,
    (
      select count(*)
      from public.follows follower_rows
      where follower_rows.following_id = profile.user_id
    ) as followers_count,
    (
      select count(*)
      from public.follows following_rows
      where following_rows.follower_id = profile.user_id
    ) as following_count,
    exists (
      select 1
      from public.follows my_follow_rows
      where my_follow_rows.follower_id = auth.uid()
        and my_follow_rows.following_id = profile.user_id
    ) as is_following,
    exists (
      select 1
      from public.follows follows_me_rows
      where follows_me_rows.follower_id = profile.user_id
        and follows_me_rows.following_id = auth.uid()
    ) as is_followed_by,
    exists (
      select 1
      from public.follow_requests request_rows
      where request_rows.requester_id = auth.uid()
        and request_rows.target_user_id = profile.user_id
        and request_rows.status = 'pending'
    ) as pending_follow_request_by_me,
    (
      auth.uid() = profile.user_id
      or coalesce(profile.is_private, false) = false
      or exists (
        select 1
        from public.follows viewer_follow_rows
        where viewer_follow_rows.follower_id = auth.uid()
          and viewer_follow_rows.following_id = profile.user_id
      )
    ) as can_view_extended_profile
  FROM public.profiles profile
  LEFT JOIN public.business_accounts business
    ON profile.account_type = 'business'
    AND business.id = profile.business_account_id
    AND business.status IN ('active', 'pending')
  WHERE profile.user_id = p_user_id
    AND auth.uid() is not null;
$$;

-- Update get_public_profile_preview
DROP FUNCTION IF EXISTS public.get_public_profile_preview(text);
CREATE FUNCTION public.get_public_profile_preview(p_user_id text)
RETURNS table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean,
  business_custom_theme_color text,
  business_pinned_event_id uuid,
  business_gallery_urls text[],
  business_is_plus_active boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false),
    business.custom_theme_color::text as business_custom_theme_color,
    business.pinned_event_id as business_pinned_event_id,
    business.gallery_urls as business_gallery_urls,
    exists (
      select 1
      from public.business_plus_subscriptions bps
      where bps.business_account_id = business.id
        and bps.status = 'active'
        and bps.starts_at <= now()
        and (bps.ends_at is null or bps.ends_at >= now())
    ) as business_is_plus_active
  FROM public.profiles profile
  LEFT JOIN public.business_accounts business
    ON profile.account_type = 'business'
    AND business.id = profile.business_account_id
    AND business.status IN ('active', 'pending')
  WHERE profile.user_id::text = p_user_id
    AND auth.uid() is not null;
$$;

-- Update get_public_profile_previews
DROP FUNCTION IF EXISTS public.get_public_profile_previews(text[]);
CREATE FUNCTION public.get_public_profile_previews(p_user_ids text[])
RETURNS table (
  user_id text,
  username text,
  tag text,
  first_name text,
  city text,
  avatar_url text,
  trust_score integer,
  is_profile_completed boolean,
  account_type text,
  business_name text,
  business_username text,
  business_tag text,
  business_logo_url text,
  business_is_verified boolean,
  business_custom_theme_color text,
  business_pinned_event_id uuid,
  business_gallery_urls text[],
  business_is_plus_active boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    profile.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.city::text,
    profile.avatar_url::text,
    profile.trust_score::integer,
    coalesce(profile.is_profile_completed, false),
    profile.account_type::text,
    null::text as business_name,
    null::text as business_username,
    null::text as business_tag,
    null::text as business_logo_url,
    coalesce(business.is_verified, false),
    business.custom_theme_color::text as business_custom_theme_color,
    business.pinned_event_id as business_pinned_event_id,
    business.gallery_urls as business_gallery_urls,
    exists (
      select 1
      from public.business_plus_subscriptions bps
      where bps.business_account_id = business.id
        and bps.status = 'active'
        and bps.starts_at <= now()
        and (bps.ends_at is null or bps.ends_at >= now())
    ) as business_is_plus_active
  FROM public.profiles profile
  LEFT JOIN public.business_accounts business
    ON profile.account_type = 'business'
    AND business.id = profile.business_account_id
    AND business.status IN ('active', 'pending')
  WHERE profile.user_id::text = any(p_user_ids)
    and auth.uid() is not null;
$$;

REVOKE ALL ON FUNCTION public.get_public_profile_detail(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_public_profile_detail(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_public_profile_preview(text) FROM public;
GRANT EXECUTE ON FUNCTION public.get_public_profile_preview(text) TO authenticated;

REVOKE ALL ON FUNCTION public.get_public_profile_previews(text[]) FROM public;
GRANT EXECUTE ON FUNCTION public.get_public_profile_previews(text[]) TO authenticated;

-- Reload Schema
notify pgrst, 'reload schema';
