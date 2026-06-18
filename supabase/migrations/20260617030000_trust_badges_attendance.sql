-- Migration: Trust Score V2, Badge Engine, QR Attendance, and Business Plus Foundation
-- Target File: supabase/migrations/20260617030000_trust_badges_attendance.sql

-- 1. Extend event_participants table safely adding missing excuse columns if not exists
ALTER TABLE public.event_participants
  ADD COLUMN IF NOT EXISTS checked_in_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS on_time boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_method text DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS excuse_status text NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancellation_reason text,
  ADD COLUMN IF NOT EXISTS cancellation_window text,
  ADD COLUMN IF NOT EXISTS excuse_text text,
  ADD COLUMN IF NOT EXISTS excuse_submitted_at timestamptz;

COMMENT ON COLUMN public.event_participants.checked_in_by_user_id IS 'Normal etkinliklerde yoklamayı alan kullanıcı IDsi.';
COMMENT ON COLUMN public.event_participants.on_time IS 'Katılımcının zamanında (etkinlikten 30 dk önce ile 15 dk sonraya kadar) giriş yapıp yapmadığı.';
COMMENT ON COLUMN public.event_participants.verification_method IS 'Katılım doğrulama yöntemi: qr, manual veya unknown.';
COMMENT ON COLUMN public.event_participants.excuse_status IS 'Katılımcının mazeret durumu: none, pending, accepted, rejected.';

-- Verification Method Constraint
ALTER TABLE public.event_participants DROP CONSTRAINT IF EXISTS event_participants_verification_method_check;
ALTER TABLE public.event_participants ADD CONSTRAINT event_participants_verification_method_check 
  CHECK (verification_method IN ('qr', 'manual', 'unknown'));

-- 2. Extend badges table
ALTER TABLE public.badges
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS threshold integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.badges.category IS 'Rozet kategorisi: user veya business.';
COMMENT ON COLUMN public.badges.threshold IS 'Rozetin kazanılması için gereken eşik sayı değeri.';

-- 3. Create business_badges table
CREATE TABLE IF NOT EXISTS public.business_badges (
  business_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  badge_id text NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, badge_id)
);

ALTER TABLE public.business_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read business badges" ON public.business_badges;
CREATE POLICY "Anyone authenticated can read business badges"
  ON public.business_badges
  FOR SELECT
  TO authenticated
  USING (true);

-- Revoke all direct client modifications on business_badges
REVOKE ALL ON public.business_badges FROM public, anon, authenticated;
GRANT SELECT ON public.business_badges TO authenticated;

-- 4. Tighten direct client mutations on other sensitive tables
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.user_badges FROM authenticated, public, anon;
GRANT SELECT ON public.user_badges TO authenticated;

ALTER TABLE public.trust_score_logs ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.trust_score_logs FROM authenticated, public, anon;
GRANT SELECT ON public.trust_score_logs TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.business_plus_subscriptions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.business_plus_subscriptions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'REVOKE INSERT, UPDATE, DELETE ON public.business_plus_subscriptions FROM authenticated, public, anon';
    EXECUTE 'GRANT SELECT ON public.business_plus_subscriptions TO authenticated';
  END IF;
END $$;

-- 5. Profiles table modifications & trust_score protection trigger
ALTER TABLE public.profiles ALTER COLUMN trust_score SET DEFAULT 70;
UPDATE public.profiles SET trust_score = 70 WHERE trust_score IS NULL;

-- Trigger to prevent client from updating own trust score directly
CREATE OR REPLACE FUNCTION public.protect_profile_trust_score()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.trust_score IS DISTINCT FROM OLD.trust_score THEN
    IF CURRENT_USER IN ('authenticated', 'anon') THEN
      RAISE EXCEPTION 'cannot_update_trust_score_directly';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_trust_score ON public.profiles;
CREATE TRIGGER trg_protect_profile_trust_score
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_trust_score();

-- 6. Insert/Update Badge Definitions
INSERT INTO public.badges (id, title, description, icon_key, sort_order, is_active, category, threshold)
VALUES
  -- User badges
  ('sozunde_duran', 'Sözünde duran', 'Katıldığı etkinliklerin en az %80''ine zamanında katılım sağladı.', 'verified_user', 10, true, 'user', 80),
  ('onayli_profil', 'Onaylı profil', 'Profil bilgilerini eksiksiz tamamladı.', 'verified', 20, true, 'user', 100),
  ('ilk_etkinlik', 'İlk etkinlik', 'İlk etkinliğine katıldı.', 'event', 30, true, 'user', 1),
  ('katilimci', 'Katılımcı', '5 etkinliğe katılım sağladı.', 'run', 40, true, 'user', 5),
  ('ortamci', 'Ortamcı', '25 etkinliğe katılım sağladı.', 'group', 50, true, 'user', 25),
  ('mudavim', 'Müdavim', '50 etkinliğe katılım sağladı.', 'workspace_premium', 60, true, 'user', 50),
  ('ev_sahibi', 'Ev sahibi', 'En az bir katılımcısı olan 1 etkinlik düzenledi.', 'home', 70, true, 'user', 1),
  ('takim_kurucu', 'Takım kurucu', 'Her biri en az bir katılımcılı 10 etkinlik düzenledi.', 'groups', 80, true, 'user', 10),
  ('etkinlik_ustasi', 'Etkinlik üstadı', 'Her biri en az bir katılımcılı 50 etkinlik düzenledi.', 'military_tech', 90, true, 'user', 50),
  ('futbolcu', 'Futbolcu', '5 futbol etkinliğine katıldı.', 'sports_soccer', 100, true, 'user', 5),
  ('kosucu', 'Koşucu', '5 koşu veya doğa sporları etkinliğine katıldı.', 'directions_run', 110, true, 'user', 5),
  ('yuzucu', 'Yüzücü', '5 yüzme etkinliğine katıldı.', 'pool', 120, true, 'user', 5),
  ('raket_ustasi', 'Raket ustası', '5 raket sporu etkinliğine katıldı.', 'sports_tennis', 130, true, 'user', 5),
  ('her_alanda_var', 'Her alanda var', 'En az 3 farklı etkinlik türüne katıldı.', 'category', 140, true, 'user', 3),
  ('dakik_oyuncu', 'Dakik oyuncu', '10 etkinliğe tam zamanında giriş yaptı.', 'schedule', 150, true, 'user', 10),
  ('kampci', 'Kampçı', '5 Kamp veya Piknik etkinliğine katıldı.', 'explore', 160, true, 'user', 5),
  ('maceraci', 'Maceracı', '5 macera ve outdoor spor etkinliğine katıldı.', 'terrain', 170, true, 'user', 5),
  ('doga_insani', 'Doğa insanı', '5 doğa ve açık hava etkinliğine katıldı.', 'hiking', 180, true, 'user', 5),
  ('salon_oyuncusu', 'Salon oyuncusu', '5 bowling, bilardo, masa veya satranç oyununa katıldı.', 'casino', 190, true, 'user', 5),
  ('fitness_mudavimi', 'Fitness müdavimi', '5 fitness, yoga, pilates veya dövüş sporu etkinliğine katıldı.', 'fitness_center', 200, true, 'user', 5),
  ('takim_oyuncu', 'Takım oyuncusu', '5 futbol, basketbol veya voleybol etkinliğine katıldı.', 'sports_handball', 210, true, 'user', 5),
  ('dans_tutkunu', 'Dans tutkunu', '5 dans etkinliğine katıldı.', 'music_note', 220, true, 'user', 5),
  ('bisikletci', 'Bisikletçi', '5 bisiklet etkinliğine katıldı.', 'directions_bike', 230, true, 'user', 5),
  -- Business badges
  ('fast_approval', 'Hızlı onay', 'Rezervasyonları hızlı ve sorunsuz yöneten işletme.', 'bolt', 10, true, 'business', 20),
  ('verified_business', 'Onaylı işletme', 'Profil bilgilerini tamamlamış ve doğrulanmış işletme.', 'verified', 20, true, 'business', 100),
  ('five_star', '10 numara 5 yıldız', 'Ortalama değerlendirmesi 4.0 üzerinde olan işletme.', 'star', 30, true, 'business', 4),
  ('popular_business', 'Popüler işletme', '50 üzerinde katılımcı ağırlayan veya 10 etkinlik tamamlayan işletme.', 'trending_up', 40, true, 'business', 50)
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    description = excluded.description,
    icon_key = excluded.icon_key,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    category = excluded.category,
    threshold = excluded.threshold;

UPDATE public.badges SET is_active = false WHERE id IN ('first_step', 'active_player');

-- 7. Helper: Normalize Sport Type
CREATE OR REPLACE FUNCTION public.normalize_sport_type(p_val text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
AS $$
  SELECT lower(translate(p_val, 'çğıöşüÇĞİÖŞÜ', 'cgiosucgiosu'));
$$;

-- 8. Trust Score delta V2 configuration
CREATE OR REPLACE FUNCTION public.trust_score_delta_for_event(p_event_type text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE p_event_type
    -- Legacy/existing events
    WHEN 'profile_event_ready' THEN 2
    WHEN 'first_event_approved' THEN 3
    WHEN 'event_join_approved' THEN 1
    WHEN 'host_event_with_participant' THEN 2
    WHEN 'event_linked_post' THEN 1
    WHEN 'approved_event_left' THEN -2
    WHEN 'event_join_cancelled' THEN 0
    WHEN 'event_join_rejected' THEN 0
    -- V2 positive events
    WHEN 'event_checked_in' THEN 3
    WHEN 'business_event_checked_in' THEN 3
    WHEN 'event_on_time_bonus' THEN 1
    WHEN 'event_manual_attended' THEN 1
    WHEN 'event_completed_attended' THEN 1
    WHEN 'event_completed_hosted' THEN 2
    WHEN 'attendance_streak_bonus' THEN 2
    -- V2 negative events
    WHEN 'cancel_24h_to_6h' THEN -1
    WHEN 'cancel_6h_to_2h' THEN -3
    WHEN 'cancel_less_than_2h' THEN -6
    WHEN 'event_no_show' THEN -10
    WHEN 'business_event_no_show' THEN -10
    ELSE 0
  END;
$$;

-- 9. Ensure trust_score_logs schema and DB-level unique index for idempotency
ALTER TABLE public.trust_score_logs
  ADD COLUMN IF NOT EXISTS actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delta integer,
  ADD COLUMN IF NOT EXISTS previous_score integer,
  ADD COLUMN IF NOT EXISTS new_score integer,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Handle existing duplicates by backing them up before creating unique index
CREATE TABLE IF NOT EXISTS public.trust_score_logs_duplicate_backup (
  LIKE public.trust_score_logs INCLUDING ALL
);

-- Copy all duplicate records to the backup table to preserve audit history
INSERT INTO public.trust_score_logs_duplicate_backup
SELECT a.*
FROM public.trust_score_logs a
JOIN (
  SELECT user_id, source_id, reason
  FROM public.trust_score_logs
  WHERE source_id IS NOT NULL
  GROUP BY user_id, source_id, reason
  HAVING COUNT(*) > 1
) b ON a.user_id = b.user_id
  AND a.source_id = b.source_id
  AND a.reason = b.reason
ON CONFLICT (id) DO NOTHING;

-- Remove duplicates keeping only the first entry per (user_id, source_id, reason)
DELETE FROM public.trust_score_logs a USING (
  SELECT MIN(id) as keep_id, user_id, source_id, reason
  FROM public.trust_score_logs
  WHERE source_id IS NOT NULL
  GROUP BY user_id, source_id, reason
  HAVING COUNT(*) > 1
) b
WHERE a.user_id = b.user_id
  AND a.source_id = b.source_id
  AND a.reason = b.reason
  AND a.id <> b.keep_id;

-- Create unique index for DB-level idempotency
DROP INDEX IF EXISTS public.trust_score_logs_user_source_reason_idx;
CREATE UNIQUE INDEX trust_score_logs_user_source_reason_idx
  ON public.trust_score_logs (user_id, source_id, reason)
  WHERE source_id IS NOT NULL;

-- 10. Redefine apply_trust_score_event with V2 rules
CREATE OR REPLACE FUNCTION public.apply_trust_score_event(
  p_user_id uuid,
  p_actor_id uuid,
  p_event_type text,
  p_source_type text DEFAULT NULL,
  p_source_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_delta integer := 0;
  v_previous_score integer;
  v_new_score integer;
  v_original_log_id uuid;
  v_original_delta integer;
  v_streak_count integer;
BEGIN
  -- Idempotency check for unique rewards/penalties on (user_id, source_id, reason)
  IF p_source_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.trust_score_logs log
    WHERE log.user_id = p_user_id
      AND log.reason = p_event_type
      AND log.source_id = p_source_id
  ) THEN
    SELECT COALESCE(profile.trust_score, 70)
    INTO v_previous_score
    FROM public.profiles profile
    WHERE profile.user_id = p_user_id;
    RETURN COALESCE(v_previous_score, 70);
  END IF;

  -- Dynamic Excuse Reversal Logic
  IF p_event_type = 'excuse_accepted' THEN
    SELECT id, delta INTO v_original_log_id, v_original_delta
    FROM public.trust_score_logs
    WHERE user_id = p_user_id
      AND source_id = p_source_id
      AND delta < 0
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_original_log_id IS NOT NULL THEN
      -- Verify that we haven't already reversed this penalty log
      IF EXISTS (
        SELECT 1
        FROM public.trust_score_logs
        WHERE user_id = p_user_id
          AND (metadata->>'reverses_log_id')::uuid = v_original_log_id
      ) THEN
        SELECT COALESCE(profile.trust_score, 70)
        INTO v_previous_score
        FROM public.profiles profile
        WHERE profile.user_id = p_user_id;
        RETURN COALESCE(v_previous_score, 70);
      END IF;

      -- Reversal delta is positive equivalent of the penalty delta
      v_delta := -v_original_delta;
      p_metadata := COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('reverses_log_id', v_original_log_id::text);
    ELSE
      v_delta := 0;
    END IF;
  ELSE
    v_delta := public.trust_score_delta_for_event(p_event_type);
  END IF;

  -- Fetch previous trust score
  SELECT COALESCE(profile.trust_score, 70)
  INTO v_previous_score
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 70;
  END IF;

  -- Adjust score and clamp between 0 and 100
  v_new_score := LEAST(100, GREATEST(0, v_previous_score + v_delta));

  -- Update profiles table
  UPDATE public.profiles
  SET trust_score = v_new_score,
      updated_at = now()
  WHERE user_id = p_user_id;

  -- Insert ledger entry
  INSERT INTO public.trust_score_logs (
    user_id,
    actor_id,
    delta,
    previous_score,
    new_score,
    reason,
    source_type,
    source_id,
    metadata
  )
  VALUES (
    p_user_id,
    p_actor_id,
    v_delta,
    v_previous_score,
    v_new_score,
    p_event_type,
    p_source_type,
    p_source_id,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT DO NOTHING;

  -- Streak calculations on check-in
  IF p_event_type IN ('event_checked_in', 'business_event_checked_in') THEN
    SELECT count(*)
    INTO v_streak_count
    FROM public.trust_score_logs
    WHERE user_id = p_user_id
      AND created_at > COALESCE(
        (SELECT max(created_at) FROM public.trust_score_logs WHERE user_id = p_user_id AND delta < 0),
        '-infinity'::timestamptz
      )
      AND reason IN ('event_checked_in', 'business_event_checked_in');

    -- Award streak bonus every 5 consecutive successful check-ins
    IF v_streak_count > 0 AND v_streak_count % 5 = 0 THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.trust_score_logs
        WHERE user_id = p_user_id
          AND reason = 'attendance_streak_bonus'
          AND source_id = p_source_id
      ) THEN
        PERFORM public.apply_trust_score_event(
          p_user_id,
          p_actor_id,
          'attendance_streak_bonus',
          p_source_type,
          p_source_id,
          jsonb_build_object('streak_length', v_streak_count)
        );
      END IF;
    END IF;
  END IF;

  -- Refresh User Badges
  PERFORM public.refresh_user_badges(p_user_id);

  RETURN v_new_score;
END;
$$;

-- 11. Excuse Status Security Safeguard Trigger
CREATE OR REPLACE FUNCTION public.check_participant_update_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_event public.events%rowtype;
  v_business_id uuid;
  v_is_authorized boolean := false;
BEGIN
  -- Excuse status validation
  IF NEW.excuse_status IS DISTINCT FROM OLD.excuse_status AND NEW.excuse_status IN ('accepted', 'rejected') THEN
    SELECT * INTO v_event FROM public.events WHERE id = OLD.event_id;
    
    IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
      SELECT id INTO v_business_id
      FROM public.business_accounts
      WHERE owner_user_id = auth.uid() AND status = 'active'
      LIMIT 1;

      IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
        v_is_authorized := true;
      END IF;
    ELSE
      IF v_event.host_id = auth.uid() THEN
        v_is_authorized := true;
      END IF;
    END IF;

    IF NOT v_is_authorized THEN
      RAISE EXCEPTION 'unauthorized_excuse_status_change';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_participant_update_rules ON public.event_participants;
CREATE TRIGGER trg_check_participant_update_rules
BEFORE UPDATE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.check_participant_update_rules();

-- 12. Redefine unified QR check-in RPC verify_and_check_in_participant
CREATE OR REPLACE FUNCTION public.verify_and_check_in_participant(
  p_event_id uuid,
  p_user_id uuid,
  p_token text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_is_authorized boolean := false;
  v_on_time boolean := false;
  v_business_id uuid;
  v_target_status text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'cannot_check_in_self';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := 'checked_in';
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := 'attended';
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized_scanner';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_user_id
    AND role = 'participant';

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Already Checked In Checks
  IF v_participant.attendance_status IN ('checked_in', 'attended') THEN
    RETURN 'already_checked_in';
  END IF;

  -- Confirm approved status
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    IF v_participant.attendance_status <> 'confirmed' THEN
      RAISE EXCEPTION 'participant_not_confirmed';
    END IF;
  ELSE
    IF v_participant.attendance_status <> 'planned' THEN
      RAISE EXCEPTION 'participant_not_approved';
    END IF;
  END IF;

  IF v_participant.check_in_token IS NULL OR v_participant.check_in_token <> p_token THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;

  -- Calculate On-Time status
  IF now() >= v_event.event_date - interval '30 minutes' AND now() <= v_event.event_date + interval '15 minutes' THEN
    v_on_time := true;
  END IF;

  -- Update Attendance status
  UPDATE public.event_participants
  SET attendance_status = v_target_status,
      checked_in_at = now(),
      checked_in_by = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN v_business_id ELSE NULL END,
      checked_in_by_user_id = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN NULL ELSE v_actor_id END,
      verification_method = 'qr',
      on_time = v_on_time
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  -- Recalculate event approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust V2 Scores
  PERFORM public.apply_trust_score_event(
    p_user_id,
    v_actor_id,
    'event_checked_in',
    'event',
    p_event_id,
    jsonb_build_object('attendance_status', v_target_status, 'verification_method', 'qr')
  );

  IF v_on_time THEN
    PERFORM public.apply_trust_score_event(
      p_user_id,
      v_actor_id,
      'event_on_time_bonus',
      'event',
      p_event_id,
      jsonb_build_object('on_time', true)
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_user_id);

  -- Recalculate Business Badges (if business event)
  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_business_id IS NOT NULL THEN
    PERFORM public.recalculate_business_badges(v_business_id);
  END IF;

  RETURN 'success';
END;
$$;

-- 13. RPC for manual host/business check-in/no-show: mark_event_attendance
CREATE OR REPLACE FUNCTION public.mark_event_attendance(
  p_event_id uuid,
  p_participant_user_id uuid,
  p_attendance_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
  v_target_status text;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_attendance_status NOT IN ('checked_in', 'attended', 'no_show') THEN
    RAISE EXCEPTION 'invalid_attendance_status';
  END IF;

  IF p_participant_user_id = v_actor_id THEN
    RAISE EXCEPTION 'cannot_mark_own_attendance';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id FOR UPDATE;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := CASE WHEN p_attendance_status = 'no_show' THEN 'no_show' ELSE 'checked_in' END;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
    v_target_status := CASE WHEN p_attendance_status = 'no_show' THEN 'no_show' ELSE 'attended' END;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_participant_user_id
    AND role = 'participant'
  FOR UPDATE;

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Already Checked In Checks
  IF v_participant.attendance_status IN ('checked_in', 'attended') THEN
    RETURN;
  END IF;

  -- No-Show Safety check (Prefer event_end_time if it exists)
  IF p_attendance_status = 'no_show' THEN
    IF v_event.event_end_time IS NOT NULL THEN
      DECLARE
        v_event_end timestamptz;
      BEGIN
        IF v_event.event_start_time IS NOT NULL THEN
          IF v_event.event_end_time >= v_event.event_start_time THEN
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time);
          ELSE
            v_event_end := v_event.event_date + (v_event.event_end_time - v_event.event_start_time) + interval '24 hours';
          END IF;
        ELSE
          -- Fallback: assume event date in Europe/Istanbul local timezone and combine with event_end_time
          v_event_end := timezone('Europe/Istanbul', timezone('UTC', v_event.event_date))::date + v_event.event_end_time;
          v_event_end := timezone('Europe/Istanbul', v_event_end);
        END IF;

        IF now() < v_event_end THEN
          RAISE EXCEPTION 'cannot_mark_no_show_before_event_end';
        END IF;
      END;
    ELSE
      IF now() < v_event.event_date THEN
        RAISE EXCEPTION 'cannot_mark_no_show_before_event_start';
      END IF;
    END IF;
  END IF;

  -- Update Attendance status
  UPDATE public.event_participants
  SET attendance_status = v_target_status,
      checked_in_at = CASE WHEN p_attendance_status IN ('checked_in', 'attended') THEN now() ELSE checked_in_at END,
      checked_in_by = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN v_business_id ELSE NULL END,
      checked_in_by_user_id = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN NULL ELSE v_actor_id END,
      verification_method = CASE WHEN p_attendance_status IN ('checked_in', 'attended') THEN 'manual' ELSE verification_method END,
      on_time = false -- manual check-in does not award on-time bonus
  WHERE event_id = p_event_id
    AND user_id = p_participant_user_id;

  -- Recalculate event approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust V2 Scores (Use event_manual_attended reason for manual checks)
  IF p_attendance_status = 'no_show' THEN
    PERFORM public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_no_show',
      'event',
      p_event_id,
      jsonb_build_object('attendance_status', 'no_show', 'verification_method', 'manual')
    );
  ELSE
    PERFORM public.apply_trust_score_event(
      p_participant_user_id,
      v_actor_id,
      'event_manual_attended',
      'event',
      p_event_id,
      jsonb_build_object('attendance_status', v_target_status, 'verification_method', 'manual')
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_participant_user_id);

  -- Recalculate Business Badges (if business event)
  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_business_id IS NOT NULL THEN
    PERFORM public.recalculate_business_badges(v_business_id);
  END IF;
END;
$$;

-- 14. RPC for participant cancellation and excuse submit: cancel_event_participation
CREATE OR REPLACE FUNCTION public.cancel_event_participation(
  p_event_id uuid,
  p_excuse_text text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_window text;
  v_penalty_reason text;
  v_excuse_status text := 'none';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = v_user_id
    AND role = 'participant';

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  -- Only approved/confirmed participants can trigger cancellation penalty rules
  IF v_participant.attendance_status NOT IN ('planned', 'confirmed') THEN
    RAISE EXCEPTION 'cannot_cancel_unapproved_participation';
  END IF;

  -- Determine cancellation window
  IF now() < v_event.event_date - interval '24 hours' THEN
    v_window := 'more_than_24h';
    v_penalty_reason := NULL;
  ELSIF now() < v_event.event_date - interval '6 hours' THEN
    v_window := '24h_to_6h';
    v_penalty_reason := 'cancel_24h_to_6h';
  ELSIF now() < v_event.event_date - interval '2 hours' THEN
    v_window := '6h_to_2h';
    v_penalty_reason := 'cancel_6h_to_2h';
  ELSE
    v_window := 'less_than_2h';
    v_penalty_reason := 'cancel_less_than_2h';
  END IF;

  IF p_excuse_text IS NOT NULL AND trim(p_excuse_text) <> '' THEN
    v_excuse_status := 'pending';
  END IF;

  -- Update participant record
  UPDATE public.event_participants
  SET attendance_status = 'cancelled',
      cancelled_at = now(),
      cancellation_reason = p_excuse_text,
      cancellation_window = v_window,
      excuse_text = p_excuse_text,
      excuse_submitted_at = CASE WHEN p_excuse_text IS NOT NULL THEN now() ELSE excuse_submitted_at END,
      excuse_status = v_excuse_status
  WHERE event_id = p_event_id
    AND user_id = v_user_id;

  -- Update approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

  -- Apply Trust score penalty if late and event is not cancelled by host/business
  IF v_penalty_reason IS NOT NULL AND COALESCE(v_event.status, 'active') <> 'cancelled' THEN
    PERFORM public.apply_trust_score_event(
      v_user_id,
      v_user_id,
      v_penalty_reason,
      'event',
      p_event_id,
      jsonb_build_object('cancellation_window', v_window, 'has_excuse', (p_excuse_text IS NOT NULL))
    );
  END IF;

  -- Recalculate user badges
  PERFORM public.refresh_user_badges(v_user_id);
END;
$$;

-- RPC for host/business excuse approval: resolve_participant_excuse
CREATE OR REPLACE FUNCTION public.resolve_participant_excuse(
  p_event_id uuid,
  p_user_id uuid,
  p_excuse_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_participant public.event_participants%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_excuse_status NOT IN ('accepted', 'rejected') THEN
    RAISE EXCEPTION 'invalid_excuse_status';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Authorization Checks
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT * INTO v_participant
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  IF v_participant.user_id IS NULL THEN
    RAISE EXCEPTION 'participant_not_found';
  END IF;

  IF v_participant.excuse_status <> 'pending' THEN
    RAISE EXCEPTION 'no_pending_excuse';
  END IF;

  -- Update excuse status
  UPDATE public.event_participants
  SET excuse_status = p_excuse_status
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  -- Revert penalty on accept
  IF p_excuse_status = 'accepted' THEN
    PERFORM public.apply_trust_score_event(
      p_user_id,
      v_actor_id,
      'excuse_accepted',
      'event',
      p_event_id,
      jsonb_build_object('resolved_by', v_actor_id)
    );
  END IF;

  -- Recalculate User Badges
  PERFORM public.refresh_user_badges(p_user_id);
END;
$$;

-- 15. Unified RPC to fetch check-in participants for both host & business
CREATE OR REPLACE FUNCTION public.get_event_check_in_participants(
  p_event_id uuid
)
RETURNS TABLE (
  user_id text,
  username text,
  tag text,
  first_name text,
  avatar_url text,
  attendance_status text,
  checked_in_at timestamptz,
  check_in_token text,
  excuse_text text,
  excuse_submitted_at timestamptz,
  excuse_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_is_authorized boolean := false;
  v_business_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RETURN;
  END IF;

  -- Verify scanner/viewer authorization
  IF COALESCE(v_event.organizer_type, 'user') = 'business' THEN
    SELECT id INTO v_business_id
    FROM public.business_accounts
    WHERE owner_user_id = v_actor_id AND status = 'active'
    LIMIT 1;

    IF v_business_id IS NOT NULL AND v_event.organizer_business_id = v_business_id THEN
      v_is_authorized := true;
    END IF;
  ELSE
    IF v_event.host_id = v_actor_id THEN
      v_is_authorized := true;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  SELECT
    participant.user_id::text,
    profile.username::text,
    profile.tag::text,
    profile.first_name::text,
    profile.avatar_url::text,
    participant.attendance_status::text,
    participant.checked_in_at,
    participant.check_in_token,
    participant.excuse_text,
    participant.excuse_submitted_at,
    participant.excuse_status::text
  FROM public.event_participants participant
  JOIN public.profiles profile
    ON profile.user_id = participant.user_id
  WHERE participant.event_id = p_event_id
    AND participant.role = 'participant'
    AND participant.attendance_status IN ('confirmed', 'checked_in', 'no_show', 'planned', 'attended', 'cancelled')
  ORDER BY
    participant.attendance_status IN ('confirmed', 'planned') DESC,
    profile.first_name,
    profile.username;
END;
$$;

-- 16. Backward-compatible wrap for get_business_event_check_in_participants
CREATE OR REPLACE FUNCTION public.get_business_event_check_in_participants(
  p_event_id uuid
)
RETURNS TABLE (
  user_id text,
  username text,
  tag text,
  first_name text,
  avatar_url text,
  attendance_status text,
  checked_in_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    user_id,
    username,
    tag,
    first_name,
    avatar_url,
    attendance_status,
    checked_in_at
  FROM public.get_event_check_in_participants(p_event_id);
$$;

-- 17. Redefine refresh_user_badges with V2 rules (Requires verification_method = 'qr' for sport/type badges)
CREATE OR REPLACE FUNCTION public.refresh_user_badges(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_ready boolean;
  v_trust_score integer;
  v_qr_attended_count integer;
  v_on_time_count integer;
  v_hosted_completed_with_attendance integer;
  v_total_committed integer;
  v_attended_ratio float := 0.0;
  
  -- Category counts
  v_futbol_count integer := 0;
  v_kosu_count integer := 0;
  v_yuzme_count integer := 0;
  v_raket_count integer := 0;
  v_distinct_types integer := 0;
  v_kamp_count integer := 0;
  v_macera_count integer := 0;
  v_doga_count integer := 0;
  v_salon_count integer := 0;
  v_fitness_count integer := 0;
  v_takim_count integer := 0;
  v_dans_count integer := 0;
  v_bisiklet_count integer := 0;
BEGIN
  -- 1. Check if profile is complete and fetch trust_score
  SELECT
    (NULLIF(trim(coalesce(profile.username, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.first_name, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.city, '')), '') IS NOT NULL
      AND NULLIF(trim(coalesce(profile.district, '')), '') IS NOT NULL
      AND profile.birth_date IS NOT NULL),
    COALESCE(profile.trust_score, 70)
  INTO v_profile_ready, v_trust_score
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 2. Count QR-verified event attendances
  SELECT count(*)
  INTO v_qr_attended_count
  FROM public.event_participants
  WHERE user_id = p_user_id
    AND role = 'participant'
    AND attendance_status IN ('checked_in', 'attended')
    AND verification_method = 'qr';

  -- 3. Count on-time QR check-ins
  SELECT count(*)
  INTO v_on_time_count
  FROM public.event_participants
  WHERE user_id = p_user_id
    AND role = 'participant'
    AND attendance_status IN ('checked_in', 'attended')
    AND verification_method = 'qr'
    AND on_time = true;

  -- 4. Count hosted events with at least one checked-in participant
  -- Note: Host badges count completed hosted events where at least one participant checked in (via either QR or manual verification methods)
  SELECT count(distinct e.id)
  INTO v_hosted_completed_with_attendance
  FROM public.events e
  JOIN public.event_participants ep ON ep.event_id = e.id
  WHERE e.host_id = p_user_id
    AND e.event_date < now()
    AND ep.role = 'participant'
    AND ep.attendance_status IN ('checked_in', 'attended');

  -- 5. Calculate Sözünde Duran ratio
  SELECT count(*)
  INTO v_total_committed
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.user_id = p_user_id
    AND ep.role = 'participant'
    -- Exclude early cancellations (>24h) from the sample
    AND (
      ep.attendance_status IN ('checked_in', 'attended', 'no_show')
      OR (ep.attendance_status = 'cancelled' AND ep.cancellation_window IN ('24h_to_6h', '6h_to_2h', 'less_than_2h'))
    );

  -- 6. Count sport categories for checked-in events (Enforces verification_method = 'qr')
  SELECT count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'futbol') AS futbol,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('kosu', 'doga yuruyusu', 'trekking')) AS kosu,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'yuzme') AS yuzme,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('tenis', 'padel', 'masa tenisi')) AS raket,
         count(distinct public.normalize_sport_type(e.sport_type)) AS distinct_types,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('kamp', 'piknik')) AS kamp,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('paintball', 'karting', 'tirmanis', 'kayak / snowboard', 'kayak', 'snowboard')) AS macera,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('doga yuruyusu', 'trekking', 'kamp', 'balik tutma')) AS doga,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('bowling', 'bilardo', 'masa oyunlari', 'satranc')) AS salon,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('fitness', 'yoga', 'pilates', 'dovus sporlari')) AS fitness,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) IN ('futbol', 'basketbol', 'voleybol')) AS takim,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'dans') AS dans,
         count(*) FILTER (WHERE public.normalize_sport_type(e.sport_type) = 'bisiklet') AS bisiklet
  INTO v_futbol_count, v_kosu_count, v_yuzme_count, v_raket_count, v_distinct_types, v_kamp_count, v_macera_count, v_doga_count, v_salon_count, v_fitness_count, v_takim_count, v_dans_count, v_bisiklet_count
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.user_id = p_user_id
    AND ep.role = 'participant'
    AND ep.attendance_status IN ('checked_in', 'attended')
    AND ep.verification_method = 'qr';

  -- --- AWARD USER BADGES ---

  -- Onaylı Profil
  IF v_profile_ready THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'onayli_profil') ON CONFLICT DO NOTHING;
  END IF;

  -- Sözünde Duran
  IF v_total_committed >= 5 THEN
    v_attended_ratio := v_qr_attended_count::float / v_total_committed::float;
    IF v_attended_ratio >= 0.8 THEN
      INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'sozunde_duran') ON CONFLICT DO NOTHING;
    ELSE
      DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge_id = 'sozunde_duran';
    END IF;
  ELSE
    DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge_id = 'sozunde_duran';
  END IF;

  -- Attendance Counts (İlk etkinlik, Katılımcı, Ortamcı, Müdavim)
  IF v_qr_attended_count >= 1 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ilk_etkinlik') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'katilimci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 25 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ortamci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_qr_attended_count >= 50 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'mudavim') ON CONFLICT DO NOTHING;
  END IF;

  -- Host Badges (Ev sahibi, Takım kurucu, Etkinlik üstadı)
  IF v_hosted_completed_with_attendance >= 1 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'ev_sahibi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_hosted_completed_with_attendance >= 10 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'takim_kurucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_hosted_completed_with_attendance >= 50 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'etkinlik_ustasi') ON CONFLICT DO NOTHING;
  END IF;

  -- Sport Type Badges
  IF v_futbol_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'futbolcu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_kosu_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'kosucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_yuzme_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'yuzucu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_raket_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'raket_ustasi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_distinct_types >= 3 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'her_alanda_var') ON CONFLICT DO NOTHING;
  END IF;
  IF v_on_time_count >= 10 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'dakik_oyuncu') ON CONFLICT DO NOTHING;
  END IF;

  -- Additional Badges
  IF v_kamp_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'kampci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_macera_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'maceraci') ON CONFLICT DO NOTHING;
  END IF;
  IF v_doga_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'doga_insani') ON CONFLICT DO NOTHING;
  END IF;
  IF v_salon_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'salon_oyuncusu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_fitness_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'fitness_mudavimi') ON CONFLICT DO NOTHING;
  END IF;
  IF v_takim_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'takim_oyuncu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_dans_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'dans_tutkunu') ON CONFLICT DO NOTHING;
  END IF;
  IF v_bisiklet_count >= 5 THEN
    INSERT INTO public.user_badges (user_id, badge_id) VALUES (p_user_id, 'bisikletci') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- 18. RPC to recalculate business badges: recalculate_business_badges
CREATE OR REPLACE FUNCTION public.recalculate_business_badges(p_business_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_checked_in_participants integer := 0;
  v_is_verified boolean := false;
  v_reviews_avg float := 0.0;
  v_reviews_count integer := 0;
  v_completed_events_count integer := 0;
BEGIN
  -- Count verified business check-ins (Requiring QR verification as high-quality proof)
  -- Note: We count only participants checked in via QR code (verification_method = 'qr').
  -- Manual attendance is treated as a business correction, not as QR-quality proof for badge progression.
  SELECT count(*)
  INTO v_checked_in_participants
  FROM public.event_participants
  WHERE checked_in_by = p_business_id
    AND attendance_status = 'checked_in'
    AND verification_method = 'qr';

  -- Check verified status safely using inspect columns
  IF exists (
    select 1 
    from information_schema.columns 
    where table_schema = 'public' 
      and table_name = 'business_accounts' 
      and column_name = 'is_verified'
  ) THEN
    EXECUTE 'SELECT COALESCE(is_verified, false) FROM public.business_accounts WHERE id = $1'
    INTO v_is_verified
    USING p_business_id;
  ELSE
    v_is_verified := false;
  END IF;

  -- Count reviews & average rating safely
  IF to_regclass('public.business_reviews') IS NOT NULL THEN
    EXECUTE 'SELECT COALESCE(avg(rating), 0.0), count(*) FROM public.business_reviews WHERE business_id = $1'
    INTO v_reviews_avg, v_reviews_count
    USING p_business_id;
  ELSE
    v_reviews_avg := 0.0;
    v_reviews_count := 0;
  END IF;

  -- Completed business events with checked-in participants (Requiring QR verification)
  -- Note: We count completed events where at least one participant was checked in via QR.
  SELECT count(distinct event_id)
  INTO v_completed_events_count
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE ep.checked_in_by = p_business_id
    AND ep.attendance_status = 'checked_in'
    AND ep.verification_method = 'qr';

  -- --- AWARD BUSINESS BADGES ---

  -- Hızlı Onay (20+ check-ins)
  IF v_checked_in_participants >= 20 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'fast_approval') ON CONFLICT DO NOTHING;
  END IF;

  -- Onaylı İşletme (Doğrulanmış)
  IF v_is_verified THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'verified_business') ON CONFLICT DO NOTHING;
  END IF;

  -- 10 Numara 5 Yıldız (Ortalama > 4.0 ve min 1 değerlendirme)
  IF v_reviews_count >= 1 AND v_reviews_avg > 4.0 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'five_star') ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.business_badges WHERE business_id = p_business_id AND badge_id = 'five_star';
  END IF;

  -- Popüler İşletme (50+ katılımcı ya da 10+ tamamlanmış etkinlik)
  IF v_checked_in_participants >= 50 OR v_completed_events_count >= 10 THEN
    INSERT INTO public.business_badges (business_id, badge_id) VALUES (p_business_id, 'popular_business') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- 19. RPC to read business badges: get_business_badges
CREATE OR REPLACE FUNCTION public.get_business_badges(p_business_id uuid)
RETURNS TABLE (
  id text,
  title text,
  description text,
  icon_key text,
  sort_order integer,
  earned_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    badge.id,
    badge.title,
    badge.description,
    badge.icon_key,
    badge.sort_order,
    bus_badge.earned_at
  FROM public.badges badge
  LEFT JOIN public.business_badges bus_badge
    ON bus_badge.business_id = p_business_id
    AND bus_badge.badge_id = badge.id
  WHERE badge.is_active
    AND badge.category = 'business'
  ORDER BY
    bus_badge.earned_at IS NULL,
    COALESCE(bus_badge.earned_at, 'infinity'::timestamptz),
    badge.sort_order,
    badge.id;
$$;

-- 20. Redefine get_profile_badges to fetch user badges only
CREATE OR REPLACE FUNCTION public.get_profile_badges(p_user_id uuid)
RETURNS TABLE (
  id text,
  title text,
  description text,
  icon_key text,
  sort_order integer,
  earned_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_is_private boolean;
  v_can_view boolean := false;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN;
  END IF;

  SELECT coalesce(profile.is_private, false) INTO v_is_private
  FROM public.profiles profile
  WHERE profile.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_actor_id = p_user_id OR v_is_private = false OR EXISTS (
    SELECT 1
    FROM public.follows follow_rows
    WHERE follow_rows.follower_id = v_actor_id
      AND follow_rows.following_id = p_user_id
  ) THEN
    v_can_view := true;
  END IF;

  IF NOT v_can_view THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    badge.id,
    badge.title,
    badge.description,
    badge.icon_key,
    badge.sort_order,
    user_badge.earned_at
  FROM public.badges badge
  LEFT JOIN public.user_badges user_badge
    ON user_badge.user_id = p_user_id
    AND user_badge.badge_id = badge.id
  WHERE badge.is_active
    AND badge.category = 'user'
  ORDER BY
    user_badge.earned_at IS NULL,
    COALESCE(user_badge.earned_at, 'infinity'::timestamptz),
    badge.sort_order,
    badge.id;
END;
$$;

-- 21. Trigger function to ensure check_in_token exists for approved/confirmed participants
CREATE OR REPLACE FUNCTION public.ensure_check_in_token_exists()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'participant' 
     AND NEW.attendance_status IN ('planned', 'confirmed', 'attended', 'checked_in', 'approved', 'pending_confirmation')
     AND NEW.check_in_token IS NULL THEN
    NEW.check_in_token := gen_random_uuid()::text;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_check_in_token ON public.event_participants;
CREATE TRIGGER trg_ensure_check_in_token
BEFORE INSERT OR UPDATE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.ensure_check_in_token_exists();

-- 22. Backfill check_in_tokens for existing approved/confirmed participations using strong gen_random_uuid()
UPDATE public.event_participants
SET check_in_token = gen_random_uuid()::text
WHERE check_in_token IS NULL
  AND role = 'participant'
  AND attendance_status IN ('planned', 'approved', 'confirmed', 'pending_confirmation');

-- 23. Grants
REVOKE ALL ON FUNCTION public.apply_trust_score_event(uuid, uuid, text, text, uuid, jsonb) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_user_badges(uuid) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.recalculate_business_badges(uuid) FROM public, anon, authenticated;

REVOKE ALL ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.mark_event_attendance(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_event_attendance(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_event_participation(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.cancel_event_participation(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_participant_excuse(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.resolve_participant_excuse(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.get_business_badges(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_business_badges(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_profile_badges(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_badges(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_event_check_in_participants(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_event_check_in_participants(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
