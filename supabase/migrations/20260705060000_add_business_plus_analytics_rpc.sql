-- Migration: Add secure Business Plus analytics RPC function
CREATE OR REPLACE FUNCTION public.get_business_plus_analytics(p_business_account_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_total_events integer := 0;
  v_upcoming_events integer := 0;
  v_past_events integer := 0;
  v_total_participants integer := 0;
  v_total_checked_in integer := 0;
  v_attendance_rate numeric := 0;
  v_pending_join_requests integer := 0;
  v_approved_join_requests integer := 0;
  v_rejected_join_requests integer := 0;
  v_monthly_boosts_used integer := 0;
  v_monthly_boosts_remaining integer := 5;
  v_active_boosts integer := 0;
  v_expired_boosts integer := 0;
  v_top_events jsonb := '[]'::jsonb;
  v_recent_events jsonb := '[]'::jsonb;
  v_local_now timestamp := timezone('Europe/Istanbul', now());
  v_period_start timestamptz;
  v_period_end timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verify ownership or membership
  IF NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = p_business_account_id AND owner_user_id = v_user_id AND status = 'active'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.business_members
    WHERE business_id = p_business_account_id
      AND user_id = v_user_id
      AND role IN ('owner', 'admin', 'staff')
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Verify active Plus subscription
  IF NOT public.check_business_plus_active(p_business_account_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  -- 1. General event counts
  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE event_date >= now())::integer,
    COUNT(*) FILTER (WHERE event_date < now())::integer
  INTO v_total_events, v_upcoming_events, v_past_events
  FROM public.events
  WHERE organizer_business_id = p_business_account_id
    AND status = 'active';

  -- 2. Participants and attendance counts (confirmed or checked_in)
  SELECT
    COUNT(*) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status IN ('confirmed', 'checked_in'))::integer,
    COUNT(*) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status = 'checked_in')::integer
  INTO v_total_participants, v_total_checked_in
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE e.organizer_business_id = p_business_account_id
    AND e.status = 'active';

  IF v_total_participants > 0 THEN
    v_attendance_rate := ROUND((v_total_checked_in * 100.0) / v_total_participants, 1);
  END IF;

  -- 3. Join requests counts
  SELECT
    COUNT(*) FILTER (WHERE ejr.status = 'pending')::integer,
    COUNT(*) FILTER (WHERE ejr.status = 'approved')::integer,
    COUNT(*) FILTER (WHERE ejr.status = 'rejected')::integer
  INTO v_pending_join_requests, v_approved_join_requests, v_rejected_join_requests
  FROM public.event_join_requests ejr
  JOIN public.events e ON e.id = ejr.event_id
  WHERE e.organizer_business_id = p_business_account_id
    AND e.status = 'active';

  -- 4. Boost metrics
  v_period_start := date_trunc('month', v_local_now) at time zone 'Europe/Istanbul';
  v_period_end := (date_trunc('month', v_local_now) + interval '1 month')
    at time zone 'Europe/Istanbul';

  SELECT COUNT(*)::integer INTO v_monthly_boosts_used
  FROM public.business_event_boosts
  WHERE business_account_id = p_business_account_id
    AND boosted_at >= v_period_start
    AND boosted_at < v_period_end;

  v_monthly_boosts_remaining := GREATEST(0, 5 - v_monthly_boosts_used);

  SELECT
    COUNT(*) FILTER (WHERE expires_at >= now())::integer,
    COUNT(*) FILTER (WHERE expires_at < now())::integer
  INTO v_active_boosts, v_expired_boosts
  FROM public.business_event_boosts
  WHERE business_account_id = p_business_account_id;

  -- 5. Top events by participant count (limit 5)
  SELECT COALESCE(json_agg(row_to_json(top_evs)), '[]'::jsonb) INTO v_top_events
  FROM (
    SELECT
      e.id,
      e.title,
      e.event_date,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status IN ('confirmed', 'checked_in'))::integer as participant_count,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status = 'checked_in')::integer as check_in_count
    FROM public.events e
    LEFT JOIN public.event_participants ep ON ep.event_id = e.id
    WHERE e.organizer_business_id = p_business_account_id
      AND e.status = 'active'
    GROUP BY e.id, e.title, e.event_date
    ORDER BY participant_count DESC, e.event_date DESC
    LIMIT 5
  ) top_evs;

  -- 6. Recent event performance (limit 5, past events)
  SELECT COALESCE(json_agg(row_to_json(rec_evs)), '[]'::jsonb) INTO v_recent_events
  FROM (
    SELECT
      e.id,
      e.title,
      e.event_date,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status IN ('confirmed', 'checked_in'))::integer as participant_count,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status = 'checked_in')::integer as check_in_count,
      COUNT(ep.id) FILTER (WHERE ep.role = 'participant' AND ep.attendance_status = 'no_show')::integer as no_show_count,
      (SELECT COUNT(*)::integer FROM public.event_join_requests ejr WHERE ejr.event_id = e.id) as join_requests_count
    FROM public.events e
    LEFT JOIN public.event_participants ep ON ep.event_id = e.id
    WHERE e.organizer_business_id = p_business_account_id
      AND e.status = 'active'
      AND e.event_date < now()
    GROUP BY e.id, e.title, e.event_date
    ORDER BY e.event_date DESC
    LIMIT 5
  ) rec_evs;

  RETURN jsonb_build_object(
    'total_events', v_total_events,
    'upcoming_events', v_upcoming_events,
    'past_events', v_past_events,
    'total_participants', v_total_participants,
    'total_checked_in', v_total_checked_in,
    'attendance_rate', v_attendance_rate,
    'pending_join_requests', v_pending_join_requests,
    'approved_join_requests', v_approved_join_requests,
    'rejected_join_requests', v_rejected_join_requests,
    'monthly_boosts_used', v_monthly_boosts_used,
    'monthly_boosts_remaining', v_monthly_boosts_remaining,
    'active_boosts', v_active_boosts,
    'expired_boosts', v_expired_boosts,
    'top_events', v_top_events,
    'recent_events', v_recent_events
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_business_plus_analytics(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_business_plus_analytics(uuid) TO authenticated;
