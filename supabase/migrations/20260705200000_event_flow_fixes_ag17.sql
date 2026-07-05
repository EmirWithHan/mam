-- Migration: Event Flow Fixes AG-17
-- Redefine on_event_join_request_change trigger function to automatically mark older unread join requests as read.
-- Redefine check_participant_update_rules trigger function to allow safe transitions for approved participants to leave/cancel their participation.

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

  -- Mark previous unread join request notifications from this user to this event as read
  IF new.status IN ('cancelled', 'rejected', 'approved', 'confirmed', 'left') THEN
    UPDATE public.notifications
    SET is_read = true
    WHERE recipient_id = v_recipient_id
      AND actor_id = v_actor_id
      AND type = 'event_join_request'
      AND entity_id = v_event_id
      AND is_read = false;
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

GRANT EXECUTE ON FUNCTION public.on_event_join_request_change() TO authenticated;


CREATE OR REPLACE FUNCTION public.check_participant_update_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event public.events%rowtype;
  v_business_id uuid;
  v_is_authorized boolean := false;
  v_actor_id uuid;
BEGIN
  v_actor_id := auth.uid();

  -- If updated by the participant themselves, restrict columns
  IF v_actor_id IS NOT NULL AND v_actor_id = old.user_id THEN
    -- Check if it is a safe status transition to 'cancelled' or 'left'
    IF (new.attendance_status IS DISTINCT FROM old.attendance_status) THEN
      IF old.attendance_status NOT IN ('planned', 'confirmed') OR
         new.attendance_status NOT IN ('cancelled', 'left') THEN
        RAISE EXCEPTION 'unauthorized_column_change';
      END IF;
    END IF;

    -- Block other column changes
    IF new.role IS DISTINCT FROM old.role OR
       new.capacity_bucket IS DISTINCT FROM old.capacity_bucket OR
       new.event_id IS DISTINCT FROM old.event_id OR
       new.user_id IS DISTINCT FROM old.user_id OR
       new.checked_in_at IS DISTINCT FROM old.checked_in_at OR
       new.checked_in_by IS DISTINCT FROM old.checked_in_by OR
       new.checked_in_by_user_id IS DISTINCT FROM old.checked_in_by_user_id OR
       new.verification_method IS DISTINCT FROM old.verification_method OR
       new.on_time IS DISTINCT FROM old.on_time OR
       new.removed_by IS DISTINCT FROM old.removed_by OR
       new.removed_at IS DISTINCT FROM old.removed_at THEN
      RAISE EXCEPTION 'unauthorized_column_change';
    END IF;
  END IF;

  -- Excuse status validation
  IF new.excuse_status IS DISTINCT FROM old.excuse_status AND new.excuse_status IN ('accepted', 'rejected') THEN
    SELECT * INTO v_event FROM public.events WHERE id = old.event_id;
    
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
      RAISE EXCEPTION 'unauthorized_excuse_status_change';
    END IF;
  END IF;

  RETURN new;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_participant_update_rules() TO authenticated;
