-- Migration: Event Flow Fixes (AG-16)
-- Redefine verify_and_check_in_participant with 2h to 22h window and stable exceptions (qr_too_early, qr_expired)
-- Redefine queue_push_for_notification to whitelist business_event_confirm_required
-- Redefine cancel_event_participation to update event_join_requests status to cancelled

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
  v_event_start timestamptz;
  v_event_end timestamptz;
  v_window_start timestamptz;
  v_window_end timestamptz;
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

  IF COALESCE(v_event.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'event_not_checkin_active';
  END IF;

  IF v_event.event_start_time IS NOT NULL THEN
    v_event_start := timezone(
      'Europe/Istanbul',
      timezone('Europe/Istanbul', v_event.event_date)::date + v_event.event_start_time
    );
  ELSE
    v_event_start := v_event.event_date;
  END IF;

  v_window_start := v_event_start - interval '2 hours';
  v_window_end := v_event_start + interval '22 hours';

  IF now() < v_window_start THEN
    RAISE EXCEPTION 'qr_too_early';
  END IF;

  IF now() > v_window_end THEN
    RAISE EXCEPTION 'qr_expired';
  END IF;

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

  IF now() >= v_event_start - interval '30 minutes'
     AND now() <= v_event_start + interval '15 minutes' THEN
    v_on_time := true;
  END IF;

  UPDATE public.event_participants
  SET attendance_status = v_target_status,
      checked_in_at = now(),
      checked_in_by = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN v_business_id ELSE NULL END,
      checked_in_by_user_id = CASE WHEN COALESCE(v_event.organizer_type, 'user') = 'business' THEN NULL ELSE v_actor_id END,
      verification_method = 'qr',
      on_time = v_on_time
  WHERE event_id = p_event_id
    AND user_id = p_user_id;

  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'checked_in', 'planned', 'attended')
  )
  WHERE id = p_event_id;

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

  PERFORM public.refresh_user_badges(p_user_id);

  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_business_id IS NOT NULL THEN
    PERFORM public.recalculate_business_badges(v_business_id);
  END IF;

  RETURN 'success';
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.queue_push_for_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_body text;
  v_title text;
  v_community_id uuid;
  v_is_muted boolean := false;
BEGIN
  -- Exclude trigger updates if not in eligible list
  IF new.type NOT IN (
    'event_join_request',
    'event_join_approved',
    'event_join_rejected',
    'event_join_cancelled',
    'event_left',
    'event_updated',
    'community_membership_approved',
    'community_membership_rejected',
    'community_role_assigned',
    'community_role_removed',
    'community_announcement',
    'community_chat_mention',
    'community_post_mention',
    'community_comment_mention',
    'community_comment_reply',
    'community_members_only_event',
    'community_membership_revocation',
    'follow_request',
    'follow_request_approved',
    'follow_request_rejected',
    'follow',
    'message',
    'business_event_confirm_required'
  ) THEN
    RETURN new;
  END IF;

  -- Mute check for community chat mentions
  IF new.type IN ('community_chat_mention', 'community_announcement', 'community_members_only_event') THEN
    v_community_id := (new.metadata->>'community_id')::uuid;
    IF v_community_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.community_chat_mutes
        WHERE community_id = v_community_id
          AND user_id = new.recipient_id
      ) INTO v_is_muted;
    END IF;
  END IF;

  -- Mute check for event messages
  IF new.type = 'message' AND new.entity_type = 'event' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.chat_mutes
      WHERE event_id = new.entity_id::uuid
        AND user_id = new.recipient_id
    ) INTO v_is_muted;
  END IF;

  IF v_is_muted THEN
    RETURN new;
  END IF;

  v_body := nullif(btrim(coalesce(new.body, '')), '');
  v_title := nullif(btrim(coalesce(new.title, '')), '');

  IF v_body IS NULL THEN
    v_body := 'Yeni bir bildiriminiz var.';
  END IF;
  IF v_title IS NULL THEN
    v_title := 'Akanzi';
  END IF;

  -- Customize titles/bodies for message push notifications (retaining historical fallback check)
  IF new.type = 'message' THEN
    IF new.entity_type = 'direct_message' THEN
      v_title := v_title || ' sana mesaj gönderdi';
      v_body := 'Yeni bir mesajın var';
    ELSIF new.entity_type = 'event' THEN
      v_title := v_title || ' (' || COALESCE((SELECT title FROM public.events WHERE id = new.entity_id::uuid), 'Etkinlik') || ')';
      v_body := 'Yeni bir grup mesajın var';
    END IF;
  END IF;

  INSERT INTO public.push_notification_outbox (
    notification_id,
    recipient_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    metadata
  )
  VALUES (
    new.id,
    new.recipient_id,
    new.type,
    v_title,
    v_body,
    new.entity_type,
    new.entity_id,
    COALESCE(new.metadata, '{}'::jsonb)
  )
  ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$;

GRANT EXECUTE ON FUNCTION public.queue_push_for_notification() TO authenticated;


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

  -- Also update the join request status to cancelled
  UPDATE public.event_join_requests
  SET status = 'cancelled',
      updated_at = now()
  WHERE event_id = p_event_id
    AND user_id = v_user_id
    AND status NOT IN ('cancelled', 'rejected');

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

GRANT EXECUTE ON FUNCTION public.cancel_event_participation(uuid, text) TO authenticated;
