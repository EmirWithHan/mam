-- Migration: Community Achievements and Badges
-- Server-authoritative, automatic, idempotent badge system.

-- 1. Create achievement definitions table
CREATE TABLE IF NOT EXISTS public.achievement_definitions (
  code text PRIMARY KEY,
  target_type text NOT NULL CHECK (target_type in ('community', 'user')),
  title text NOT NULL,
  description text NOT NULL,
  icon_key text NOT NULL,
  is_revocable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS on definitions
ALTER TABLE public.achievement_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read achievement definitions" ON public.achievement_definitions;
CREATE POLICY "Anyone authenticated can read achievement definitions"
  ON public.achievement_definitions
  FOR SELECT TO authenticated USING (true);

-- Block client direct mutations
REVOKE ALL ON public.achievement_definitions FROM public, anon, authenticated;
GRANT SELECT ON public.achievement_definitions TO authenticated;

-- 2. Create achievement awards ledger table
CREATE TABLE IF NOT EXISTS public.achievement_awards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type text NOT NULL CHECK (target_type in ('community', 'user')),
  target_id uuid NOT NULL,
  achievement_code text NOT NULL REFERENCES public.achievement_definitions(code) ON DELETE CASCADE,
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  evaluation_version integer NOT NULL DEFAULT 1,
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);

-- Enable RLS on awards
ALTER TABLE public.achievement_awards ENABLE ROW LEVEL SECURITY;

-- Select policy: Anyone authenticated can read active achievements
DROP POLICY IF EXISTS "Anyone authenticated can read active achievement awards" ON public.achievement_awards;
CREATE POLICY "Anyone authenticated can read active achievement awards"
  ON public.achievement_awards
  FOR SELECT TO authenticated USING (revoked_at IS NULL);

-- Block client mutations
REVOKE ALL ON public.achievement_awards FROM public, anon, authenticated;
GRANT SELECT ON public.achievement_awards TO authenticated;

-- 3. Populate Initial Automatic Achievements Catalog
INSERT INTO public.achievement_definitions (code, target_type, title, description, icon_key, is_revocable)
VALUES
  ('active_community', 'community', 'Aktif Topluluk', 'En az 10 aktif üyeye ve 3 tamamlanmış etkinliğe sahip topluluk.', 'groups', true),
  ('growing_community', 'community', 'Büyüyen Topluluk', 'Son 60 günde oluşturulmuş ve organik üye büyümesi gösteren topluluk.', 'trending_up', true),
  ('consistent_community', 'community', 'İstikrarlı Topluluk', 'Son 90 günde farklı günlerde en az 4 etkinlik düzenleyen topluluk.', 'event_available', true),
  ('trusted_community', 'community', 'Güvenilir Topluluk', 'En az 5 tamamlanmış etkinliğe sahip, yüksek katılımlı ve temiz moderasyon geçmişli topluluk.', 'verified', true),
  ('community_founder', 'user', 'Topluluk Kurucusu', 'Aktif en az bir topluluğun kurucusu olan üye.', 'workspace_premium', true),
  ('community_organizer', 'user', 'Etkinlik Yöneticisi', 'En az 3 tamamlanmış topluluk etkinliğini başarıyla düzenleyen üye.', 'military_tech', false),
  ('community_leader', 'user', 'Topluluk Lideri', 'En az 25 üyeli aktif bir topluluğun yöneticisi veya sahibi olan üye.', 'stars', true)
ON CONFLICT (code) DO UPDATE
SET title = excluded.title,
    description = excluded.description,
    icon_key = excluded.icon_key,
    is_revocable = excluded.is_revocable;

-- 4. Server-Side Helper Functions for Award and Revocation

CREATE OR REPLACE FUNCTION public.award_achievement(
  p_target_type text,
  p_target_id uuid,
  p_code text,
  p_evidence jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_idempotency_key text;
BEGIN
  v_idempotency_key := p_target_id::text || ':' || p_code;
  
  -- If active award exists, skip
  IF EXISTS (
    SELECT 1 
    FROM public.achievement_awards 
    WHERE target_id = p_target_id 
      AND achievement_code = p_code 
      AND revoked_at IS NULL
  ) THEN
    RETURN;
  END IF;
  
  -- Insert or restore if previously revoked
  INSERT INTO public.achievement_awards (
    target_type,
    target_id,
    achievement_code,
    evidence,
    idempotency_key
  )
  VALUES (
    p_target_type,
    p_target_id,
    p_code,
    p_evidence,
    v_idempotency_key
  )
  ON CONFLICT (idempotency_key) DO UPDATE
  SET revoked_at = NULL,
      evidence = excluded.evidence,
      created_at = now(); -- resets award timestamp on reactivation
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_achievement(
  p_target_id uuid,
  p_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.achievement_awards
  SET revoked_at = now(),
      idempotency_key = idempotency_key || ':revoked:' || extract(epoch from now())::text
  WHERE target_id = p_target_id
    AND achievement_code = p_code
    AND revoked_at IS NULL;
END;
$$;

-- 5. Individual Evaluation Logic Functions

-- A. Evaluate One Community
CREATE OR REPLACE FUNCTION public.evaluate_one_community(p_community_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_community record;
  v_active_members integer := 0;
  v_completed_events integer := 0;
  v_distinct_attendees integer := 0;
  v_events_last_90d integer := 0;
  v_manipulators integer := 0;
  v_avg_attendance numeric := 0.0;
  v_recent_mod_actions integer := 0;
  
  v_eligible_active boolean := false;
  v_eligible_growing boolean := false;
  v_eligible_consistent boolean := false;
  v_eligible_trusted boolean := false;
BEGIN
  SELECT * INTO v_community
  FROM public.communities
  WHERE id = p_community_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Suspended communities lose all achievements immediately
  IF v_community.status = 'suspended' THEN
    PERFORM public.revoke_achievement(p_community_id, 'active_community');
    PERFORM public.revoke_achievement(p_community_id, 'growing_community');
    PERFORM public.revoke_achievement(p_community_id, 'consistent_community');
    PERFORM public.revoke_achievement(p_community_id, 'trusted_community');
    RETURN;
  END IF;
  
  -- Calculations:
  -- Active members
  SELECT count(*) INTO v_active_members
  FROM public.community_memberships
  WHERE community_id = p_community_id 
    AND status = 'active';
    
  -- Completed events (must occur in the past, active, and approved)
  SELECT count(*) INTO v_completed_events
  FROM public.events
  WHERE community_id = p_community_id
    AND status = 'active'
    AND moderation_status = 'approved'
    AND event_date < now();
    
  -- Distinct verified attendees
  SELECT count(distinct ep.user_id) INTO v_distinct_attendees
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE e.community_id = p_community_id
    AND ep.role = 'participant'
    AND ep.attendance_status = 'attended';
    
  -- Completed events on distinct dates last 90 days
  SELECT count(distinct event_date::date) INTO v_events_last_90d
  FROM public.events
  WHERE community_id = p_community_id
    AND status = 'active'
    AND moderation_status = 'approved'
    AND event_date < now()
    and event_date > now() - interval '90 days';
    
  -- Manipulators (users leaving/joining > 2 times in 60 days)
  SELECT count(distinct user_id) INTO v_manipulators
  FROM (
    SELECT m.user_id
    FROM public.community_membership_audit audit
    JOIN public.community_memberships m ON m.id = audit.membership_id
    WHERE audit.community_id = p_community_id
      AND audit.action in ('join', 'leave', 'update')
      AND (audit.old_status = 'active' OR audit.new_status = 'active')
      AND audit.created_at > now() - interval '60 days'
    GROUP BY m.user_id
    HAVING count(*) > 2
  ) manip;
  
  -- Average attendance per completed event
  IF v_completed_events > 0 THEN
    SELECT count(*)::numeric / v_completed_events::numeric INTO v_avg_attendance
    FROM public.event_participants ep
    JOIN public.events e ON e.id = ep.event_id
    WHERE e.community_id = p_community_id
      AND ep.role = 'participant'
      AND ep.attendance_status = 'attended';
  END IF;
  
  -- Recent confirmed serious moderation actions on events
  SELECT count(*) INTO v_recent_mod_actions
  FROM public.event_moderation_logs ml
  JOIN public.events e ON e.id = ml.event_id
  WHERE e.community_id = p_community_id
    AND ml.new_status in ('rejected', 'removed_by_admin')
    AND ml.created_at > now() - interval '30 days';

  -- Evaluate criteria:
  
  -- active_community
  IF v_active_members >= 10 AND v_completed_events >= 3 AND v_distinct_attendees >= 5 THEN
    v_eligible_active := true;
  END IF;
  
  -- growing_community (created last 60 days, active members minus manipulators >= 15)
  IF v_community.created_at > now() - interval '60 days' 
     AND (v_active_members - v_manipulators) >= 15 THEN
    v_eligible_growing := true;
  END IF;
  
  -- consistent_community
  IF v_events_last_90d >= 4 THEN
    v_eligible_consistent := true;
  END IF;
  
  -- trusted_community
  IF v_completed_events >= 5 AND v_avg_attendance >= 3.0 AND v_recent_mod_actions = 0 THEN
    v_eligible_trusted := true;
  END IF;

  -- Apply Awards
  IF v_eligible_active THEN
    PERFORM public.award_achievement('community', p_community_id, 'active_community', 
      jsonb_build_object('members', v_active_members, 'events', v_completed_events, 'distinct_attendees', v_distinct_attendees));
  ELSE
    PERFORM public.revoke_achievement(p_community_id, 'active_community');
  END IF;
  
  IF v_eligible_growing THEN
    PERFORM public.award_achievement('community', p_community_id, 'growing_community', 
      jsonb_build_object('members', v_active_members, 'manipulators_excluded', v_manipulators, 'created_at', v_community.created_at));
  ELSE
    PERFORM public.revoke_achievement(p_community_id, 'growing_community');
  END IF;
  
  IF v_eligible_consistent THEN
    PERFORM public.award_achievement('community', p_community_id, 'consistent_community', 
      jsonb_build_object('events_last_90d', v_events_last_90d));
  ELSE
    PERFORM public.revoke_achievement(p_community_id, 'consistent_community');
  END IF;
  
  IF v_eligible_trusted THEN
    PERFORM public.award_achievement('community', p_community_id, 'trusted_community', 
      jsonb_build_object('events', v_completed_events, 'avg_attendance', v_avg_attendance));
  ELSE
    PERFORM public.revoke_achievement(p_community_id, 'trusted_community');
  END IF;
END;
$$;

-- B. Evaluate One User
CREATE OR REPLACE FUNCTION public.evaluate_one_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile record;
  v_founder_count integer := 0;
  v_events_hosted_count integer := 0;
  v_leader_count integer := 0;
  
  v_eligible_founder boolean := false;
  v_eligible_organizer boolean := false;
  v_eligible_leader boolean := false;
  v_evidence_organizer jsonb := '{}'::jsonb;
BEGIN
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = p_user_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Business profiles are strictly blocked from user achievements
  IF v_profile.account_type = 'business' THEN
    PERFORM public.revoke_achievement(p_user_id, 'community_founder');
    PERFORM public.revoke_achievement(p_user_id, 'community_organizer');
    PERFORM public.revoke_achievement(p_user_id, 'community_leader');
    RETURN;
  END IF;

  -- Calculations:
  -- community_founder: user owns at least one active, non-suspended community
  SELECT count(*) INTO v_founder_count
  FROM public.communities
  WHERE owner_user_id = p_user_id
    AND status = 'active';
    
  -- community_organizer: hosted >= 3 completed community events with distinct participants
  SELECT count(*) INTO v_events_hosted_count
  FROM public.events e
  WHERE e.host_id = p_user_id
    AND e.community_id IS NOT NULL
    AND e.status = 'active'
    AND e.moderation_status = 'approved'
    AND e.event_date < now()
    AND (
      SELECT count(distinct ep.user_id) 
      FROM public.event_participants ep 
      WHERE ep.event_id = e.id 
        AND ep.role = 'participant' 
        AND ep.attendance_status = 'attended'
        AND ep.user_id <> p_user_id -- exclude host self-checking
    ) >= 1;
    
  -- community_leader: user currently owns or manages an active community with >= 25 members
  SELECT count(*) INTO v_leader_count
  FROM (
    SELECT id FROM public.communities
    WHERE owner_user_id = p_user_id
      AND status = 'active'
      AND member_count >= 25
    UNION
    SELECT c.id FROM public.communities c
    JOIN public.community_memberships m ON m.community_id = c.id
    WHERE m.user_id = p_user_id
      AND m.role = 'manager'
      AND m.status = 'active'
      AND c.status = 'active'
      AND c.member_count >= 25
  ) lead_comm;

  -- Evaluate Eligibility:
  IF v_founder_count >= 1 THEN
    v_eligible_founder := true;
  END IF;
  
  IF v_events_hosted_count >= 3 THEN
    v_eligible_organizer := true;
  END IF;
  
  IF v_leader_count >= 1 THEN
    v_eligible_leader := true;
  END IF;

  -- Apply Awards
  IF v_eligible_founder THEN
    PERFORM public.award_achievement('user', p_user_id, 'community_founder', 
      jsonb_build_object('founded_active_count', v_founder_count));
  ELSE
    PERFORM public.revoke_achievement(p_user_id, 'community_founder');
  END IF;
  
  IF v_eligible_organizer THEN
    PERFORM public.award_achievement('user', p_user_id, 'community_organizer', 
      jsonb_build_object('events_hosted_count', v_events_hosted_count));
  ELSE
    PERFORM public.revoke_achievement(p_user_id, 'community_organizer');
  END IF;
  
  IF v_eligible_leader THEN
    PERFORM public.award_achievement('user', p_user_id, 'community_leader', 
      jsonb_build_object('leader_communities_count', v_leader_count));
  ELSE
    PERFORM public.revoke_achievement(p_user_id, 'community_leader');
  END IF;
END;
$$;

-- C. Evaluate Event Completion Impact
CREATE OR REPLACE FUNCTION public.evaluate_achievements_for_event_completion(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event record;
BEGIN
  SELECT community_id, host_id INTO v_event
  FROM public.events
  WHERE id = p_event_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  IF v_event.community_id IS NOT NULL THEN
    PERFORM public.evaluate_one_community(v_event.community_id);
  END IF;
  
  IF v_event.host_id IS NOT NULL THEN
    PERFORM public.evaluate_one_user(v_event.host_id);
  END IF;
END;
$$;

-- 6. Trigger Integrations for Automated Evaluation Hookups

-- A. Event Participants Update Hook
CREATE OR REPLACE FUNCTION public.trg_on_participant_achievement_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.evaluate_achievements_for_event_completion(new.event_id);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_achievement_participant_update ON public.event_participants;
CREATE TRIGGER trg_achievement_participant_update
  AFTER INSERT OR UPDATE OF attendance_status ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_participant_achievement_update();

-- B. Community Memberships Hook
CREATE OR REPLACE FUNCTION public.trg_on_membership_achievement_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.evaluate_one_community(old.community_id);
    IF old.user_id IS NOT NULL THEN
      PERFORM public.evaluate_one_user(old.user_id);
    END IF;
    RETURN old;
  ELSE
    PERFORM public.evaluate_one_community(new.community_id);
    IF new.user_id IS NOT NULL THEN
      PERFORM public.evaluate_one_user(new.user_id);
    END IF;
    RETURN new;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_achievement_membership_update ON public.community_memberships;
CREATE TRIGGER trg_achievement_membership_update
  AFTER INSERT OR UPDATE OF status, role OR DELETE ON public.community_memberships
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_membership_achievement_update();

-- C. Community Details / Status Hook
CREATE OR REPLACE FUNCTION public.trg_on_community_achievement_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.evaluate_one_community(new.id);
  PERFORM public.evaluate_one_user(new.owner_user_id);
  IF TG_OP = 'UPDATE' AND old.owner_user_id IS DISTINCT FROM new.owner_user_id THEN
    PERFORM public.evaluate_one_user(old.owner_user_id);
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_achievement_community_update ON public.communities;
CREATE TRIGGER trg_achievement_community_update
  AFTER INSERT OR UPDATE OF status, owner_user_id ON public.communities
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_community_achievement_update();

-- D. Event Moderation Action Hook
CREATE OR REPLACE FUNCTION public.trg_on_moderation_achievement_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.evaluate_achievements_for_event_completion(new.event_id);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_achievement_moderation_update ON public.event_moderation_logs;
CREATE TRIGGER trg_achievement_moderation_update
  AFTER INSERT ON public.event_moderation_logs
  FOR EACH ROW EXECUTE FUNCTION public.trg_on_moderation_achievement_update();

-- 7. Public Safe Fetch RPC Function (Zero private data leakage)
CREATE OR REPLACE FUNCTION public.get_achievements_for_target(p_target_id uuid)
RETURNS TABLE (
  code text,
  title text,
  description text,
  icon_key text,
  awarded_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT 
    d.code,
    d.title,
    d.description,
    d.icon_key,
    a.created_at as awarded_at
  FROM public.achievement_awards a
  JOIN public.achievement_definitions d ON d.code = a.achievement_code
  WHERE a.target_id = p_target_id
    AND a.revoked_at IS NULL
  ORDER BY a.created_at ASC;
$$;

-- Expose RPC to authenticated users
REVOKE ALL ON FUNCTION public.get_achievements_for_target(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_achievements_for_target(uuid) TO authenticated;

-- 8. Admin-Safe Batch Recompute Function (Service-role or platform-admin check)
CREATE OR REPLACE FUNCTION public.admin_recompute_all_achievements()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_rec record;
BEGIN
  IF auth.role() <> 'service_role' AND NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  
  -- Recompute all communities
  FOR v_rec IN (SELECT id FROM public.communities) LOOP
    PERFORM public.evaluate_one_community(v_rec.id);
  END LOOP;
  
  -- Recompute all users
  FOR v_rec IN (SELECT user_id FROM public.profiles) LOOP
    PERFORM public.evaluate_one_user(v_rec.user_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_recompute_all_achievements() FROM public, anon, authenticated;

-- 9. Trigger batch recompute once during migration to populate awards ledger non-destructively
DO $$
DECLARE
  v_rec record;
BEGIN
  -- Recompute communities
  FOR v_rec IN (SELECT id FROM public.communities) LOOP
    BEGIN
      PERFORM public.evaluate_one_community(v_rec.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed initial achievements recompute for community %: %', v_rec.id, SQLERRM;
    END;
  END LOOP;

  -- Recompute users
  FOR v_rec IN (SELECT user_id FROM public.profiles) LOOP
    BEGIN
      PERFORM public.evaluate_one_user(v_rec.user_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed initial achievements recompute for user %: %', v_rec.user_id, SQLERRM;
    END;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
