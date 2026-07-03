-- 1. Redefine trigger function to automatically notify host/business owner on join requests
-- Safely maps 'confirmed' and 'waitlisted' to 'event_join_request' type to satisfy notifications_type_check.
CREATE OR REPLACE FUNCTION public.on_event_join_request_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recipient_id uuid;
  v_actor_id uuid := new.user_id;
  v_event_id uuid := new.event_id;
  v_event public.events%rowtype;
  v_notification_type text;
  v_title text;
  v_body text;
BEGIN
  -- Fetch the event details
  SELECT * INTO v_event FROM public.events WHERE id = v_event_id;
  IF v_event.id IS NULL THEN
    RETURN new;
  END IF;

  -- Determine the recipient host
  IF COALESCE(v_event.organizer_type, 'user') = 'business' AND v_event.organizer_business_id IS NOT NULL THEN
    SELECT owner_user_id
    INTO v_recipient_id
    FROM public.business_accounts
    WHERE id = v_event.organizer_business_id;
  END IF;

  IF v_recipient_id IS NULL THEN
    v_recipient_id := v_event.host_id;
  END IF;

  -- Do not notify self
  IF v_recipient_id = v_actor_id THEN
    RETURN new;
  END IF;

  -- Determine title/body based on the new status
  -- Use 'event_join_request' to satisfy the notifications_type_check constraint
  IF new.status = 'pending' THEN
    v_notification_type := 'event_join_request';
    v_title := 'Yeni katılım isteği';
    v_body := 'Etkinliğine yeni bir katılım isteği geldi.';
  ELSIF new.status = 'confirmed' THEN
    v_notification_type := 'event_join_request';
    v_title := 'Yeni katılımcı';
    v_body := 'Etkinliğine yeni bir katılımcı katıldı.';
  ELSIF new.status = 'waitlisted' THEN
    v_notification_type := 'event_join_request';
    v_title := 'Yedek katılım';
    v_body := 'Etkinliğinin yedek listesine yeni bir katılımcı eklendi.';
  ELSE
    RETURN new;
  END IF;

  -- Insert notification if no unread duplicate exists
  IF NOT EXISTS (
    SELECT 1
    from public.notifications
    WHERE recipient_id = v_recipient_id
      AND actor_id = v_actor_id
      AND type = v_notification_type
      AND entity_id = v_event_id
      AND is_read = false
  ) THEN
    INSERT INTO public.notifications (
      recipient_id,
      actor_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      metadata,
      is_read
    )
    VALUES (
      v_recipient_id,
      v_actor_id,
      v_notification_type,
      v_title,
      v_body,
      'event',
      v_event_id,
      jsonb_build_object(
        'event_id', v_event_id::text,
        'request_id', new.id::text
      ),
      false
    );
  END IF;

  RETURN new;
END;
$$;

-- 2. Redefine unified QR check-in RPC verify_and_check_in_participant
-- Opens check-in starting exactly 1 hour before event start time.
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

  IF v_event.event_end_time IS NOT NULL THEN
    IF v_event.event_start_time IS NOT NULL THEN
      IF v_event.event_end_time >= v_event.event_start_time THEN
        v_event_end := v_event_start + (v_event.event_end_time - v_event.event_start_time);
      ELSE
        v_event_end := v_event_start + (v_event.event_end_time - v_event.event_start_time) + interval '24 hours';
      END IF;
    ELSE
      v_event_end := timezone(
        'Europe/Istanbul',
        timezone('Europe/Istanbul', v_event.event_date)::date + v_event.event_end_time
      );
    END IF;
  ELSE
    v_event_end := timezone(
      'Europe/Istanbul',
      timezone('Europe/Istanbul', v_event.event_date)::date + time '23:59:59'
    );
  END IF;

  -- Open scanner 1 hour before event start time
  v_window_start := v_event_start - interval '1 hour';
  v_window_end := v_event_end + interval '6 hours';

  IF now() < v_window_start THEN
    RAISE EXCEPTION 'checkin_window_not_open';
  END IF;

  IF now() > v_window_end THEN
    RAISE EXCEPTION 'checkin_window_closed';
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

REVOKE ALL ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
