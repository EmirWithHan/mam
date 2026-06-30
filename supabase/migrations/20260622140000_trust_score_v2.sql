-- Migration: Trust Score V2 System
-- Server-authoritative, automatic, idempotent reputation system.

-- 1. Alter profiles table to add new trust columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS trust_confidence numeric DEFAULT 0.0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS trust_level text DEFAULT 'Yeni';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_recalculated_at timestamptz DEFAULT now();

-- Re-align default value of trust_score to 50 (neutral starting point)
ALTER TABLE public.profiles ALTER COLUMN trust_score SET DEFAULT 50;

-- Safe update: only set trust_score to 50 for profiles that currently have no trust_score set
UPDATE public.profiles SET trust_score = 50 WHERE trust_score IS NULL;

-- Add confidence bounds check constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_trust_confidence_bounds'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_trust_confidence_bounds
      CHECK (trust_confidence BETWEEN 0.0 AND 1.0) NOT VALID;
  END IF;
END $$;

-- 2. Create the immutable trust signals ledger table
CREATE TABLE IF NOT EXISTS public.trust_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  signal_type text NOT NULL,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  delta_score integer NOT NULL,
  delta_confidence numeric NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Unique index to support client-safe idempotency (user, type, source_type, and source_id)
-- If source_id is null, it should default to a secure sentinel UUID to satisfy the index.
CREATE UNIQUE INDEX IF NOT EXISTS trust_signals_unique_idx 
  ON public.trust_signals (user_id, signal_type, source_type, COALESCE(source_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Enable RLS on trust signals
ALTER TABLE public.trust_signals ENABLE ROW LEVEL SECURITY;

-- Block client direct writes (authenticated & anon)
REVOKE ALL ON public.trust_signals FROM public, anon, authenticated;
GRANT SELECT ON public.trust_signals TO authenticated;

-- Policy to allow authenticated users to read their own signals
DROP POLICY IF EXISTS "Users can read own trust signals" ON public.trust_signals;
CREATE POLICY "Users can read own trust signals" 
  ON public.trust_signals
  FOR SELECT 
  TO authenticated
  USING (user_id = auth.uid());

-- 3. Redefine trigger to protect profile trust fields
CREATE OR REPLACE FUNCTION public.protect_profile_trust_score()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.trust_score IS DISTINCT FROM OLD.trust_score OR
     NEW.trust_confidence IS DISTINCT FROM OLD.trust_confidence OR
     NEW.trust_level IS DISTINCT FROM OLD.trust_level OR
     NEW.last_recalculated_at IS DISTINCT FROM OLD.last_recalculated_at THEN
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

-- 4. Define default signal weights helper
CREATE OR REPLACE FUNCTION public.trust_signal_defaults(p_signal_type text, OUT o_delta_score integer, OUT o_delta_confidence numeric)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_signal_type
    WHEN 'profile_completed' THEN 5
    WHEN 'profile_event_ready' THEN 5
    WHEN 'event_checked_in' THEN 2
    WHEN 'business_event_checked_in' THEN 2
    WHEN 'host_event_with_participant' THEN 3
    WHEN 'first_event_approved' THEN 3
    WHEN 'event_join_approved' THEN 1
    WHEN 'event_linked_post' THEN 1
    WHEN 'approved_event_left' THEN 0
    WHEN 'no_show' THEN -10
    WHEN 'late_cancellation' THEN -5
    WHEN 'host_cancelled_event' THEN -15
    WHEN 'confirmed_moderation_action' THEN -20
    WHEN 'confirmed_abuse_report' THEN -10
    WHEN 'suspicious_join_leave' THEN -5
    ELSE 0
  END,
  CASE p_signal_type
    WHEN 'profile_completed' THEN 0.20
    WHEN 'profile_event_ready' THEN 0.20
    WHEN 'event_checked_in' THEN 0.05
    WHEN 'business_event_checked_in' THEN 0.05
    WHEN 'host_event_with_participant' THEN 0.08
    WHEN 'first_event_approved' THEN 0.05
    WHEN 'event_join_approved' THEN 0.02
    WHEN 'event_linked_post' THEN 0.02
    WHEN 'approved_event_left' THEN 0.00
    WHEN 'no_show' THEN 0.10
    WHEN 'late_cancellation' THEN 0.08
    WHEN 'host_cancelled_event' THEN 0.15
    WHEN 'confirmed_moderation_action' THEN 0.20
    WHEN 'confirmed_abuse_report' THEN 0.10
    WHEN 'suspicious_join_leave' THEN 0.08
    ELSE 0.0
  END;
$$;

-- 5. Define trust score recalculation engine function
CREATE OR REPLACE FUNCTION public.recalculate_user_trust(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_score integer := 50;
  v_confidence numeric := 0.0;
  v_profile_completed boolean := false;
  v_sig record;
  
  v_group_score integer := 0;
  v_group_conf numeric := 0.0;
  
  v_temp_score integer;
  v_temp_conf numeric;
  
  v_attended_count integer := 0;
  v_no_show_count integer := 0;
  v_late_cancel_count integer := 0;
  v_mod_count integer := 0;
  v_abuse_count integer := 0;
  v_suspicious_count integer := 0;
  
  v_penalty_mod integer := 0;
  v_penalty_abuse integer := 0;
  v_penalty_suspicious integer := 0;
  
  v_account_age_days integer;
  v_trust_level text;
BEGIN
  -- Verify profile exists
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id = p_user_id) THEN
    RETURN;
  END IF;

  -- A. Profile completion
  SELECT EXISTS (
    SELECT 1 FROM public.trust_signals 
    WHERE user_id = p_user_id AND signal_type IN ('profile_completed', 'profile_event_ready')
  ) INTO v_profile_completed;
  
  IF v_profile_completed THEN
    v_score := v_score + 5;
    v_confidence := v_confidence + 0.20;
  END IF;

  -- B. Diminishing returns: Event Attendance (group by actor_id - the host)
  FOR v_sig IN (
    SELECT actor_id, count(*) as att_count
    FROM public.trust_signals
    WHERE user_id = p_user_id 
      AND signal_type IN ('event_checked_in', 'business_event_checked_in')
      AND actor_id IS NOT NULL
      AND actor_id <> p_user_id -- bypass self-actions
    GROUP BY actor_id
  ) LOOP
    v_attended_count := v_attended_count + v_sig.att_count;
    
    -- 1st-3rd attendance: +2 score, +0.05 confidence each
    -- 4th-6th attendance: +0.66 score, +0.0165 confidence each
    -- 7th+: +0.13 score, +0.0033 confidence each
    IF v_sig.att_count >= 1 THEN
      v_temp_score := LEAST(3, v_sig.att_count) * 2;
      v_temp_conf := LEAST(3, v_sig.att_count) * 0.05;
    END IF;
    IF v_sig.att_count > 3 THEN
      v_temp_score := v_temp_score + (LEAST(3, v_sig.att_count - 3) * 0.66)::integer;
      v_temp_conf := v_temp_conf + LEAST(3, v_sig.att_count - 3) * 0.0165;
    END IF;
    IF v_sig.att_count > 6 THEN
      v_temp_score := v_temp_score + ((v_sig.att_count - 6) * 0.13)::integer;
      v_temp_conf := v_temp_conf + (v_sig.att_count - 6) * 0.0033;
    END IF;
    
    v_group_score := v_group_score + v_temp_score;
    v_group_conf := v_group_conf + v_temp_conf;
  END LOOP;

  -- C. Diminishing returns: Hosting (group by actor_id - the participant checked in)
  FOR v_sig IN (
    SELECT actor_id, count(*) as host_count
    FROM public.trust_signals
    WHERE user_id = p_user_id
      AND signal_type = 'host_event_with_participant'
      AND actor_id IS NOT NULL
      AND actor_id <> p_user_id -- bypass self check-in
    GROUP BY actor_id
  ) LOOP
    -- 1st-3rd check-in: +3 score, +0.08 confidence each
    -- 4th-6th check-in: +1.0 score, +0.026 confidence each
    -- 7th+: +0.2 score, +0.005 confidence each
    IF v_sig.host_count >= 1 THEN
      v_temp_score := LEAST(3, v_sig.host_count) * 3;
      v_temp_conf := LEAST(3, v_sig.host_count) * 0.08;
    END IF;
    IF v_sig.host_count > 3 THEN
      v_temp_score := v_temp_score + (LEAST(3, v_sig.host_count - 3) * 1.0)::integer;
      v_temp_conf := v_temp_conf + LEAST(3, v_sig.host_count - 3) * 0.026;
    END IF;
    IF v_sig.host_count > 6 THEN
      v_temp_score := v_temp_score + ((v_sig.host_count - 6) * 0.2)::integer;
      v_temp_conf := v_temp_conf + (v_sig.host_count - 6) * 0.005;
    END IF;
    
    v_group_score := v_group_score + v_temp_score;
    v_group_conf := v_group_conf + v_temp_conf;
  END LOOP;

  -- D. Anti-gaming rolling Positive window cap: max +15 score, +0.3 confidence in total
  IF v_group_score > 15 THEN
    v_group_score := 15;
  END IF;
  IF v_group_conf > 0.30 THEN
    v_group_conf := 0.30;
  END IF;
  
  v_score := v_score + v_group_score;
  v_confidence := v_confidence + v_group_conf;

  -- E. History Bonuses
  SELECT count(*) INTO v_no_show_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'no_show';
  SELECT count(*) INTO v_late_cancel_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'late_cancellation';
  
  -- Low cancellation rate: attended >= 5 and cancel rate < 10%
  IF v_attended_count >= 5 AND (v_late_cancel_count::numeric / (v_attended_count + v_late_cancel_count)::numeric) < 0.10 THEN
    v_score := v_score + 5;
    v_confidence := v_confidence + 0.10;
  END IF;
  
  -- Reliable participation: 5+ attendances and 0 negative check-in signals
  IF v_attended_count >= 5 AND v_no_show_count = 0 AND v_late_cancel_count = 0 THEN
    v_score := v_score + 5;
    v_confidence := v_confidence + 0.10;
  END IF;

  -- Legitimate activity duration: account age > 30 days and 1+ attendance
  SELECT EXTRACT(DAY FROM (now() - created_at))::integer INTO v_account_age_days
  FROM public.profiles
  WHERE user_id = p_user_id;
  
  IF v_account_age_days > 30 AND v_attended_count >= 1 THEN
    v_score := v_score + 5;
    v_confidence := v_confidence + 0.10;
  END IF;

  -- F. Negative Penalties (Fully server-enforced, with safe ceilings to allow recovery)
  
  -- Confirmed no-show: -10 score, +0.1 confidence
  v_score := v_score - (v_no_show_count * 10);
  v_confidence := v_confidence + (v_no_show_count * 0.10);
  
  -- Repeated late cancellation: -5 score, +0.08 confidence
  v_score := v_score - (v_late_cancel_count * 5);
  v_confidence := v_confidence + (v_late_cancel_count * 0.08);
  
  -- Host cancellation affecting participants: -15 score, +0.15 confidence
  DECLARE
    v_host_cancel_count integer := 0;
  BEGIN
    SELECT count(*) INTO v_host_cancel_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'host_cancelled_event';
    v_score := v_score - (v_host_cancel_count * 15);
    v_confidence := v_confidence + (v_host_cancel_count * 0.15);
  END;
  
  -- Confirmed moderation action: -20 score, +0.2 confidence (capped at -40 total)
  SELECT count(*) INTO v_mod_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'confirmed_moderation_action';
  v_penalty_mod := LEAST(40, v_mod_count * 20);
  v_score := v_score - v_penalty_mod;
  v_confidence := v_confidence + (v_mod_count * 0.20);
  
  -- Confirmed abuse/spam reports: -10 score, +0.1 confidence (capped at -30 total)
  SELECT count(*) INTO v_abuse_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'confirmed_abuse_report';
  v_penalty_abuse := LEAST(30, v_abuse_count * 10);
  v_score := v_score - v_penalty_abuse;
  v_confidence := v_confidence + (v_abuse_count * 0.10);
  
  -- Repeated suspicious join/leave: -5 score, +0.08 confidence (capped at -15 total)
  SELECT count(*) INTO v_suspicious_count FROM public.trust_signals WHERE user_id = p_user_id AND signal_type = 'suspicious_join_leave';
  v_penalty_suspicious := LEAST(15, v_suspicious_count * 5);
  v_score := v_score - v_penalty_suspicious;
  v_confidence := v_confidence + (v_suspicious_count * 0.08);

  -- G. Clamp outputs
  v_score := LEAST(100, GREATEST(0, v_score));
  v_confidence := LEAST(1.0, GREATEST(0.0, v_confidence));

  -- H. Determine trust level (Yeni / Gelişiyor / Güvenilir / Çok Güvenilir)
  IF v_confidence < 0.30 THEN
    IF v_confidence < 0.15 THEN
      v_trust_level := 'Yeni';
    ELSE
      v_trust_level := 'Gelişiyor';
    END IF;
  ELSE
    IF v_score < 40 THEN
      v_trust_level := 'Düşük Güven';
    ELSEIF v_score < 60 THEN
      v_trust_level := 'Gelişiyor';
    ELSEIF v_score < 80 THEN
      v_trust_level := 'Güvenilir';
    ELSE
      v_trust_level := 'Çok Güvenilir';
    END IF;
  END IF;

  -- I. Update profile trust metrics
  UPDATE public.profiles
  SET trust_score = v_score,
      trust_confidence = v_confidence,
      trust_level = v_trust_level,
      last_recalculated_at = now()
  WHERE user_id = p_user_id;
END;
$$;

-- 6. Define signal ingestion helper (idempotent, server-side only)
CREATE OR REPLACE FUNCTION public.ingest_trust_signal(
  p_user_id uuid,
  p_actor_id uuid,
  p_signal_type text,
  p_source_type text DEFAULT NULL,
  p_source_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_delta_score integer;
  v_delta_confidence numeric;
  v_source_id uuid;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  -- Map defaults
  SELECT o_delta_score, o_delta_confidence
  INTO v_delta_score, v_delta_confidence
  FROM public.trust_signal_defaults(p_signal_type);

  -- Fallback source_id if null to keep unique index stable and satisfy constraint
  v_source_id := COALESCE(p_source_id, '00000000-0000-0000-0000-000000000000'::uuid);

  -- Insert ledger entry idempotently
  INSERT INTO public.trust_signals (
    user_id,
    actor_id,
    signal_type,
    source_type,
    source_id,
    delta_score,
    delta_confidence,
    metadata
  )
  VALUES (
    p_user_id,
    p_actor_id,
    p_signal_type,
    COALESCE(p_source_type, 'unknown'),
    v_source_id,
    v_delta_score,
    v_delta_confidence,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (user_id, signal_type, source_type, COALESCE(source_id, '00000000-0000-0000-0000-000000000000'::uuid)) DO NOTHING;

  -- Recalculate
  PERFORM public.recalculate_user_trust(p_user_id);
END;
$$;

-- 7. Define backward-compatible bridge function for existing apply_trust_score_event
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
  v_score integer;
BEGIN
  -- Ingest signal (which internally recalculates user trust)
  PERFORM public.ingest_trust_signal(
    p_user_id,
    p_actor_id,
    p_event_type,
    p_source_type,
    p_source_id,
    p_metadata
  );

  SELECT COALESCE(trust_score, 50) INTO v_score
  FROM public.profiles
  WHERE user_id = p_user_id;

  -- Maintain badges
  PERFORM public.refresh_user_badges(p_user_id);

  RETURN v_score;
END;
$$;

-- 8. Define user explanations function (owner only, auth.uid() derived server-side)
CREATE OR REPLACE FUNCTION public.get_my_trust_explanations()
RETURNS TABLE (
  explanation text,
  is_positive boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_confidence numeric;
  v_score integer;
  v_att_count integer;
  v_host_count integer;
  v_profile_completed boolean;
  v_cancel_count integer;
  v_neg_count integer;
BEGIN
  -- Derive user ID server-side to prevent identity spoofing
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(trust_confidence, 0.0), COALESCE(trust_score, 50)
  INTO v_confidence, v_score
  FROM public.profiles
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 1. Cold start
  IF v_confidence < 0.30 THEN
    explanation := 'Henüz yeterli etkinlik verisi yok';
    is_positive := true;
    RETURN NEXT;
  END IF;

  -- 2. Profile completion
  SELECT EXISTS (
    SELECT 1 FROM public.trust_signals 
    WHERE user_id = v_user_id AND signal_type IN ('profile_completed', 'profile_event_ready')
  ) INTO v_profile_completed;
  
  IF v_profile_completed THEN
    explanation := 'Profilinizi tamamladınız';
    is_positive := true;
    RETURN NEXT;
  END IF;

  -- 3. Attendance history
  SELECT COUNT(*) INTO v_att_count
  FROM public.trust_signals
  WHERE user_id = v_user_id AND signal_type IN ('event_checked_in', 'business_event_checked_in');

  IF v_att_count >= 5 THEN
    explanation := 'Etkinliklere düzenli katılım';
    is_positive := true;
    RETURN NEXT;
  ELSIF v_att_count >= 1 THEN
    explanation := 'Onaylanmış katılım geçmişi';
    is_positive := true;
    RETURN NEXT;
  END IF;

  -- 4. Hosting history
  SELECT COUNT(*) INTO v_host_count
  FROM public.trust_signals
  WHERE user_id = v_user_id AND signal_type = 'host_event_with_participant';

  IF v_host_count >= 3 THEN
    explanation := 'Güvenilir etkinlik organizatörü';
    is_positive := true;
    RETURN NEXT;
  ELSIF v_host_count >= 1 THEN
    explanation := 'Etkinlik sahibi geçmişi';
    is_positive := true;
    RETURN NEXT;
  END IF;

  -- 5. Cancellations (last 30 days)
  SELECT COUNT(*) INTO v_cancel_count
  FROM public.trust_signals
  WHERE user_id = v_user_id 
    AND signal_type IN ('late_cancellation', 'no_show')
    AND created_at > now() - INTERVAL '30 days';

  IF v_cancel_count >= 2 THEN
    explanation := 'Son dönemde iptal veya gelmeme oranı yüksek';
    is_positive := false;
    RETURN NEXT;
  END IF;

  -- 6. Moderation / abuse penalty logs
  SELECT COUNT(*) INTO v_neg_count
  FROM public.trust_signals
  WHERE user_id = v_user_id 
    AND signal_type IN ('confirmed_moderation_action', 'confirmed_abuse_report');
    
  IF v_neg_count >= 1 THEN
    explanation := 'Topluluk kurallarına uyum uyarısı';
    is_positive := false;
    RETURN NEXT;
  END IF;
END;
$$;

-- Expose explanations RPC only to authenticated users
REVOKE ALL ON FUNCTION public.get_my_trust_explanations() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_trust_explanations() TO authenticated;

-- 9. Admin full recomputation helper (Service-role or platform-admin check)
CREATE OR REPLACE FUNCTION public.admin_recompute_all_trust_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user record;
BEGIN
  -- Strict role validation: only service_role (internal server tools) or authenticated admins
  IF auth.role() <> 'service_role' AND NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  
  FOR v_user IN (SELECT user_id FROM public.profiles) LOOP
    PERFORM public.recalculate_user_trust(v_user.user_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_recompute_all_trust_scores() FROM public, anon, authenticated;

-- 10. Server-side triggers for Moderation actions & Abuse reports

-- A. Event Moderation Action Trigger
CREATE OR REPLACE FUNCTION public.trg_on_event_moderation_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_host_id uuid;
BEGIN
  -- If event moderation results in rejection or removal, penalize the host
  IF NEW.new_status IN ('rejected', 'removed_by_admin') THEN
    SELECT host_id INTO v_host_id 
    FROM public.events 
    WHERE id = NEW.event_id;
    
    IF v_host_id IS NOT NULL THEN
      PERFORM public.ingest_trust_signal(
        v_host_id,
        NEW.admin_user_id,
        'confirmed_moderation_action',
        'event_moderation_log',
        NEW.id,
        jsonb_build_object('event_id', NEW.event_id)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_event_moderation_reputation_impact ON public.event_moderation_logs;
CREATE TRIGGER trg_event_moderation_reputation_impact
  AFTER INSERT ON public.event_moderation_logs
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_event_moderation_action();

-- B. Confirmed Reports Status Trigger
CREATE OR REPLACE FUNCTION public.trg_on_report_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_target_user_id uuid;
BEGIN
  -- Only trigger when a report is confirmed/resolved with action
  IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    -- Identify the user responsible based on target_type
    IF NEW.target_type = 'user' THEN
      v_target_user_id := NEW.target_id::uuid;
    ELSIF NEW.target_type = 'event' THEN
      SELECT host_id INTO v_target_user_id FROM public.events WHERE id = NEW.target_id::uuid;
    ELSIF NEW.target_type = 'post' THEN
      SELECT user_id INTO v_target_user_id FROM public.posts WHERE id = NEW.target_id::uuid;
      -- Fallback search on community posts
      IF v_target_user_id IS NULL THEN
        SELECT user_id INTO v_target_user_id FROM public.community_posts WHERE id = NEW.target_id::uuid;
      END IF;
    ELSIF NEW.target_type = 'comment' THEN
      SELECT user_id INTO v_target_user_id FROM public.post_comments WHERE id = NEW.target_id::uuid;
      -- Fallback search on community comments
      IF v_target_user_id IS NULL THEN
        SELECT user_id INTO v_target_user_id FROM public.community_comments WHERE id = NEW.target_id::uuid;
      END IF;
    END IF;

    -- Ingest confirmed abuse report signal if target user is resolved
    IF v_target_user_id IS NOT NULL THEN
      PERFORM public.ingest_trust_signal(
        v_target_user_id,
        auth.uid(), -- The admin who confirmed the report
        'confirmed_abuse_report',
        'report',
        NEW.id,
        jsonb_build_object('reason', NEW.reason)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reports_reputation_impact ON public.reports;
CREATE TRIGGER trg_reports_reputation_impact
  AFTER UPDATE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_report_status_change();


-- 11. Database backfill operation (Safe and non-destructive)
-- Backfills historical events into the trust signals ledger and runs a clean recomputation.
DO $$
DECLARE
  v_rec record;
BEGIN
  -- A. Backfill profile completion signals
  FOR v_rec IN (
    SELECT user_id, id, created_at
    FROM public.profiles
    WHERE nullif(trim(coalesce(username, '')), '') is not null
      AND nullif(trim(coalesce(first_name, '')), '') is not null
      AND nullif(trim(coalesce(city, '')), '') is not null
      AND nullif(trim(coalesce(district, '')), '') is not null
      AND birth_date is not null
  ) LOOP
    INSERT INTO public.trust_signals (user_id, actor_id, signal_type, source_type, source_id, delta_score, delta_confidence, created_at)
    VALUES (v_rec.user_id, v_rec.user_id, 'profile_completed', 'profile', v_rec.id, 5, 0.20, v_rec.created_at)
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- B. Backfill verified event attendances
  -- Where role = 'participant' and status = 'attended'
  FOR v_rec IN (
    SELECT ep.user_id, e.host_id, ep.event_id, ep.joined_at as created_at
    FROM public.event_participants ep
    JOIN public.events e ON e.id = ep.event_id
    WHERE ep.role = 'participant' 
      AND ep.attendance_status = 'attended'
  ) LOOP
    INSERT INTO public.trust_signals (user_id, actor_id, signal_type, source_type, source_id, delta_score, delta_confidence, created_at)
    VALUES (v_rec.user_id, v_rec.host_id, 'event_checked_in', 'event', v_rec.event_id, 2, 0.05, v_rec.created_at)
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- C. Backfill host success signals (host_event_with_participant)
  FOR v_rec IN (
    SELECT e.host_id, ep.user_id, ep.event_id, ep.joined_at as created_at
    FROM public.event_participants ep
    JOIN public.events e ON e.id = ep.event_id
    WHERE ep.role = 'participant' 
      AND ep.attendance_status = 'attended'
  ) LOOP
    INSERT INTO public.trust_signals (user_id, actor_id, signal_type, source_type, source_id, delta_score, delta_confidence, created_at)
    VALUES (v_rec.host_id, v_rec.user_id, 'host_event_with_participant', 'event', v_rec.event_id, 3, 0.08, v_rec.created_at)
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- D. Backfill no-shows
  FOR v_rec IN (
    SELECT ep.user_id, e.host_id, ep.event_id, ep.joined_at as created_at
    FROM public.event_participants ep
    JOIN public.events e ON e.id = ep.event_id
    WHERE ep.role = 'participant' 
      AND ep.attendance_status = 'no_show'
  ) LOOP
    INSERT INTO public.trust_signals (user_id, actor_id, signal_type, source_type, source_id, delta_score, delta_confidence, created_at)
    VALUES (v_rec.user_id, v_rec.host_id, 'no_show', 'event', v_rec.event_id, -10, 0.10, v_rec.created_at)
    ON CONFLICT DO NOTHING;
  END LOOP;

  -- E. Run initial recalculation on all users to generate V2 metrics
  FOR v_rec IN (SELECT user_id FROM public.profiles) LOOP
    BEGIN
      PERFORM public.recalculate_user_trust(v_rec.user_id);
    EXCEPTION WHEN OTHERS THEN
      -- Log failure for robustness but continue
      RAISE WARNING 'Failed backfill recalculation for user %: %', v_rec.user_id, SQLERRM;
    END;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
