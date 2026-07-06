-- Migration: Fix get_admin_dashboard json/jsonb mismatch (AG-19)
-- Redefine get_admin_dashboard using jsonb_agg and to_jsonb instead of json_agg and row_to_json.

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
  v_recent_events jsonb := '[]'::jsonb;
  v_pending_business_apps_list jsonb := '[]'::jsonb;
  v_recent_moderation_actions jsonb := '[]'::jsonb;
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

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'total_events', v_total_events,
    'pending_business_apps', v_pending_business_apps,
    'recent_events', v_recent_events,
    'pending_business_apps_list', v_pending_business_apps_list,
    'recent_moderation_actions', v_recent_moderation_actions
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_dashboard() TO authenticated;
