-- Migration: Admin Reports Center and Removed Events (AG-20)
-- 1. Redefine SELECT policies on public.events to hide removed/rejected events from normal users.
-- 2. Create RPC function resolve_report_as_admin to resolve/reject user and message reports.
-- 3. Extend get_admin_dashboard to return report counts and recent reports.

-- 1. Event SELECT policies update
DROP POLICY IF EXISTS "Authenticated users can read active events" ON public.events;
DROP POLICY IF EXISTS "Events are visible to members or public list" ON public.events;
DROP POLICY IF EXISTS "Events are visible with moderation guard" ON public.events;

CREATE POLICY "Events are visible with moderation guard"
ON public.events
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
  OR host_id = auth.uid()
  OR (
    COALESCE(moderation_status, 'approved') = 'approved'
    AND (
      public.is_event_participant(id, auth.uid())
      OR (
        status IN ('active', 'completed')
        AND (
          community_id IS NULL
          OR community_access = 'public'
          OR public.is_community_active_member(community_id, auth.uid())
        )
      )
    )
  )
);


-- 2. Create resolve_report_as_admin RPC function
CREATE OR REPLACE FUNCTION public.resolve_report_as_admin(
  p_report_type text,
  p_report_id uuid,
  p_status text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  IF p_report_type NOT IN ('user', 'message') THEN
    RAISE EXCEPTION 'invalid_report_type';
  END IF;

  IF p_status NOT IN ('resolved', 'rejected') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  IF p_report_type = 'user' THEN
    IF NOT EXISTS (SELECT 1 FROM public.reports WHERE id = p_report_id) THEN
      RAISE EXCEPTION 'report_not_found';
    END IF;

    UPDATE public.reports
    SET status = p_status,
        updated_at = now()
    WHERE id = p_report_id;

    INSERT INTO public.admin_moderation_actions (
      admin_user_id,
      action,
      target_type,
      target_id,
      reason
    )
    VALUES (
      v_admin_id,
      'user_report_' || p_status,
      'report',
      p_report_id,
      p_reason
    );
  ELSIF p_report_type = 'message' THEN
    IF NOT EXISTS (SELECT 1 FROM public.message_reports WHERE id = p_report_id) THEN
      RAISE EXCEPTION 'report_not_found';
    END IF;

    UPDATE public.message_reports
    SET status = p_status
    WHERE id = p_report_id;

    INSERT INTO public.admin_moderation_actions (
      admin_user_id,
      action,
      target_type,
      target_id,
      reason
    )
    VALUES (
      v_admin_id,
      'message_report_' || p_status,
      'message_report',
      p_report_id,
      p_reason
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_report_as_admin(text, uuid, text, text) TO authenticated;


-- 3. Extend get_admin_dashboard to include reports
CREATE OR REPLACE FUNCTION public.get_admin_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_total_users integer := 0;
  v_total_events integer := 0;
  v_pending_business_apps integer := 0;
  v_pending_reports_count integer := 0;
  v_pending_message_reports_count integer := 0;
  v_recent_events jsonb := '[]'::jsonb;
  v_pending_business_apps_list jsonb := '[]'::jsonb;
  v_recent_moderation_actions jsonb := '[]'::jsonb;
  v_recent_reports jsonb := '[]'::jsonb;
  v_recent_message_reports jsonb := '[]'::jsonb;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  -- 1. General counts
  SELECT COUNT(*)::integer INTO v_total_users FROM public.profiles;
  SELECT COUNT(*)::integer INTO v_total_events FROM public.events;
  SELECT COUNT(*)::integer INTO v_pending_business_apps
  FROM public.business_applications
  WHERE status = 'pending';
  
  SELECT COUNT(*)::integer INTO v_pending_reports_count
  FROM public.reports
  WHERE status = 'open';

  SELECT COUNT(*)::integer INTO v_pending_message_reports_count
  FROM public.message_reports
  WHERE status = 'pending';

  -- 2. Recent events list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(rec_evs)), '[]'::jsonb) INTO v_recent_events
  FROM (
    SELECT
      e.id,
      e.title,
      e.host_id,
      e.organizer_business_id,
      e.event_date,
      e.moderation_status,
      e.created_at,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status IN ('confirmed', 'checked_in'))::integer as participant_count
    FROM public.events e
    LEFT JOIN public.event_participants ep ON ep.event_id = e.id
    GROUP BY e.id, e.title, e.host_id, e.organizer_business_id, e.event_date, e.moderation_status, e.created_at
    ORDER BY e.created_at DESC
    LIMIT 15
  ) rec_evs;

  -- 3. Pending business applications list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(pend_apps)), '[]'::jsonb) INTO v_pending_business_apps_list
  FROM (
    SELECT
      ba.id,
      ba.user_id,
      ba.business_name,
      ba.category,
      ba.full_address,
      ba.business_phone,
      ba.website,
      ba.description,
      ba.status,
      ba.created_at
    FROM public.business_applications ba
    WHERE ba.status = 'pending'
    ORDER BY ba.created_at DESC
    LIMIT 15
  ) pend_apps;

  -- 4. Recent moderation actions list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(mod_acts)), '[]'::jsonb) INTO v_recent_moderation_actions
  FROM (
    SELECT
      ma.id,
      ma.admin_user_id,
      ma.action,
      ma.target_type,
      ma.target_id,
      ma.reason,
      ma.created_at
    FROM public.admin_moderation_actions ma
    ORDER BY ma.created_at DESC
    LIMIT 15
  ) mod_acts;

  -- 5. Recent reports list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(recs)), '[]'::jsonb) INTO v_recent_reports
  FROM (
    SELECT
      r.id,
      r.reporter_id,
      r.target_type,
      r.target_id,
      r.reason,
      r.description,
      r.status,
      r.created_at
    FROM public.reports r
    ORDER BY r.created_at DESC
    LIMIT 15
  ) recs;

  -- 6. Recent message reports list (limit 15)
  SELECT COALESCE(jsonb_agg(to_jsonb(msgs)), '[]'::jsonb) INTO v_recent_message_reports
  FROM (
    SELECT
      mr.id,
      mr.message_id,
      mr.reporter_id,
      mr.reason,
      mr.created_at,
      mr.reported_user_id,
      mr.message_type,
      mr.event_id,
      mr.conversation_id,
      mr.status
    FROM public.message_reports mr
    ORDER BY mr.created_at DESC
    LIMIT 15
  ) msgs;

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'total_events', v_total_events,
    'pending_business_apps', v_pending_business_apps,
    'pending_reports_count', v_pending_reports_count,
    'pending_message_reports_count', v_pending_message_reports_count,
    'recent_events', v_recent_events,
    'pending_business_apps_list', v_pending_business_apps_list,
    'recent_moderation_actions', v_recent_moderation_actions,
    'recent_reports', v_recent_reports,
    'recent_message_reports', v_recent_message_reports
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;
