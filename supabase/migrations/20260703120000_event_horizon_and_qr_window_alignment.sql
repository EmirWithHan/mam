-- Align event scheduling and QR check-in windows with app-side rules.

CREATE OR REPLACE FUNCTION public.enforce_event_scheduling_horizon()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_business_plus boolean := false;
  v_enforce_horizon boolean := false;
BEGIN
  IF new.organizer_type = 'user' AND new.community_id IS NULL THEN
    v_enforce_horizon := true;
  ELSIF new.organizer_type = 'business' THEN
    IF new.organizer_business_id IS NOT NULL THEN
      v_is_business_plus := public.check_business_plus_active(new.organizer_business_id);
    END IF;
    v_enforce_horizon := NOT v_is_business_plus;
  END IF;

  IF v_enforce_horizon THEN
    IF TG_OP = 'UPDATE' THEN
      IF new.event_date IS DISTINCT FROM old.event_date THEN
        IF old.event_date > (now() + interval '28 days') THEN
          IF new.event_date > old.event_date THEN
            RAISE EXCEPTION 'event_date_too_far';
          END IF;
        ELSE
          IF new.event_date > (now() + interval '28 days') THEN
            RAISE EXCEPTION 'event_date_too_far';
          END IF;
        END IF;
      END IF;
    ELSE
      IF new.event_date > (now() + interval '28 days') THEN
        RAISE EXCEPTION 'event_date_too_far';
      END IF;
    END IF;
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_scheduling_horizon ON public.events;
CREATE TRIGGER trg_enforce_event_scheduling_horizon
  BEFORE INSERT OR UPDATE ON public.events
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_event_scheduling_horizon();

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

  v_window_start := v_event_start - interval '1 hour';
  v_window_end := v_event_start + interval '23 hours';

  IF now() < v_window_start THEN
    RAISE EXCEPTION 'checkin_window_not_open';
  END IF;

  IF now() > v_window_end THEN
    RAISE EXCEPTION 'checkin_window_closed';
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

  IF now() >= v_event.event_date - interval '30 minutes'
     AND now() <= v_event.event_date + interval '15 minutes' THEN
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

REVOKE ALL ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.verify_and_check_in_participant(uuid, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
