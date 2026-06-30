-- Migration: Business Plus waitlist, reminders schedule, and analytics RPCs
-- Timestamp: 20260621030000

-- 1. Add waitlisted_ineligible to check constraints
ALTER TABLE public.event_join_requests DROP CONSTRAINT IF EXISTS event_join_requests_status_check;
ALTER TABLE public.event_join_requests ADD CONSTRAINT event_join_requests_status_check
  CHECK (
    status IN (
      'pending', 'approved', 'rejected', 'cancelled', 'left',
      'pending_confirmation', 'confirmed', 'waitlisted', 'waitlisted_ineligible'
    )
  );

ALTER TABLE public.event_participants DROP CONSTRAINT IF EXISTS event_participants_attendance_status_check;
ALTER TABLE public.event_participants ADD CONSTRAINT event_participants_attendance_status_check
  CHECK (
    attendance_status IN (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'left',
      'planned',
      'checked_in',
      'attended',
      'no_show',
      'pending_confirmation',
      'confirmed',
      'waitlisted',
      'waitlisted_ineligible'
    )
  );

-- 2. Redefine reserve_business_event_participation to enforce waitlist Plus logic
CREATE OR REPLACE FUNCTION public.reserve_business_event_participation(
  p_event_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_capacity_bucket text;
  v_next_status text;
  v_token text;
  v_is_plus boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_event
  FROM public.events
  WHERE id = p_event_id
  FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF COALESCE(v_event.organizer_type, 'user') <> 'business' THEN
    RAISE EXCEPTION 'not_business_event';
  END IF;

  IF v_event.event_date < now() THEN
    RAISE EXCEPTION 'event_past';
  END IF;

  -- Validate participant requirements (age, profile completion, gender, blocks)
  PERFORM public.assert_event_participant_requirements(p_event_id, v_user_id);

  -- Verify active Plus subscription
  v_is_plus := public.check_business_plus_active(v_event.organizer_business_id);

  -- Capacity bucket
  v_capacity_bucket := public.event_capacity_bucket_for(p_event_id, v_user_id);

  IF v_capacity_bucket IS NULL THEN
    IF NOT v_is_plus THEN
      RAISE EXCEPTION 'event_full';
    END IF;
    v_next_status := 'waitlisted';
  ELSE
    v_next_status := 'confirmed';
  END IF;

  -- Check duplicate entry
  IF EXISTS (
    SELECT 1 FROM public.event_participants
    WHERE event_id = p_event_id AND user_id = v_user_id AND role = 'participant'
      AND attendance_status IN ('confirmed', 'planned', 'checked_in', 'waitlisted')
  ) THEN
    RAISE EXCEPTION 'already_joined_or_waitlisted';
  END IF;

  v_token := md5(random()::text || clock_timestamp()::text)::text;

  -- Insert/update participant
  INSERT INTO public.event_participants (
    event_id,
    user_id,
    role,
    attendance_status,
    capacity_bucket,
    check_in_token
  )
  VALUES (
    p_event_id,
    v_user_id,
    'participant',
    v_next_status,
    v_capacity_bucket,
    v_token
  )
  ON CONFLICT (event_id, user_id) DO UPDATE
  SET role = 'participant',
      attendance_status = v_next_status,
      capacity_bucket = v_capacity_bucket,
      check_in_token = COALESCE(public.event_participants.check_in_token, v_token);

  -- Insert/update join request
  INSERT INTO public.event_join_requests (
    event_id,
    user_id,
    status
  )
  VALUES (
    p_event_id,
    v_user_id,
    v_next_status
  )
  ON CONFLICT (event_id, user_id) DO UPDATE
  SET status = v_next_status,
      updated_at = now();

  -- Update event approved count
  UPDATE public.events
  SET approved_count = (
    SELECT COUNT(*)::integer
    FROM public.event_participants participant
    WHERE participant.event_id = p_event_id
      AND participant.role = 'participant'
      AND participant.attendance_status = 'confirmed'
  )
  WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_business_event_participation(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reserve_business_event_participation(uuid) TO authenticated;

-- 3. Waitlist Promotion with FIFO & Eligibility & Block validation
CREATE OR REPLACE FUNCTION public.promote_waitlist_participant(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_waitlist_record record;
  v_capacity_total integer;
  v_confirmed_count integer;
  v_event public.events%rowtype;
  v_user_profile public.profiles%rowtype;
  v_promoted boolean := false;
BEGIN
  -- Concurrency Lock for waitlist promotion per event
  PERFORM pg_advisory_xact_lock(
    hashtextextended('business_waitlist_promotion:' || p_event_id::text, 0)
  );

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RETURN;
  END IF;

  v_capacity_total := v_event.capacity_total;

  -- Count confirmed & checked_in participants
  SELECT COUNT(*)::integer INTO v_confirmed_count
  FROM public.event_participants
  WHERE event_id = p_event_id
    AND role = 'participant'
    AND attendance_status IN ('confirmed', 'checked_in');

  IF v_capacity_total <= 0 OR v_confirmed_count < v_capacity_total THEN
    -- Loop waitlist sorted by created_at (FIFO)
    FOR v_waitlist_record IN
      SELECT *
      FROM public.event_participants
      WHERE event_id = p_event_id
        AND role = 'participant'
        AND attendance_status = 'waitlisted'
      ORDER BY created_at ASC
    LOOP
      SELECT * INTO v_user_profile FROM public.profiles WHERE user_id = v_waitlist_record.user_id;

      -- Validate Eligibility
      IF (v_event.min_age IS NULL OR (EXTRACT(YEAR FROM age(v_user_profile.birth_date)) >= v_event.min_age))
         AND (NOT v_event.require_completed_profile OR (
           v_user_profile.first_name IS NOT NULL AND v_user_profile.first_name <> '' AND
           v_user_profile.birth_date IS NOT NULL AND v_user_profile.gender IS NOT NULL
         ))
         -- Validate blocks
         AND NOT EXISTS (
           SELECT 1 FROM public.blocks b
           WHERE (b.blocker_id = v_event.host_id AND b.blocked_id = v_waitlist_record.user_id)
              OR (b.blocker_id = v_waitlist_record.user_id AND b.blocked_id = v_event.host_id)
         )
      THEN
        -- Promote
        UPDATE public.event_participants
        SET attendance_status = 'confirmed',
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = v_waitlist_record.user_id;

        UPDATE public.event_join_requests
        SET status = 'confirmed',
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = v_waitlist_record.user_id;

        -- Update events approved count
        UPDATE public.events
        SET approved_count = approved_count + 1
        WHERE id = p_event_id;

        -- Notify promoted user
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
          v_waitlist_record.user_id,
          v_event.host_id,
          'event_join_approved',
          'Sıran geldi!',
          v_event.title || ' etkinliğinde bekleme listesinden ana listeye alındın.',
          'event',
          p_event_id::text,
          jsonb_build_object(
            'event_id', p_event_id,
            'attendance_status', 'confirmed'
          ),
          false
        );

        v_promoted := true;
        EXIT; -- promote one user per open slot
      ELSE
        -- Log failed promotion: mark them as ineligible (preserves request but skips future automatic promotion)
        UPDATE public.event_participants
        SET attendance_status = 'waitlisted_ineligible',
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = v_waitlist_record.user_id;

        UPDATE public.event_join_requests
        SET status = 'waitlisted_ineligible',
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = v_waitlist_record.user_id;
      END IF;
    END LOOP;
  END IF;
END;
$$;

-- Promotion trigger on participant cancel/left
CREATE OR REPLACE FUNCTION public.after_participant_status_changed_waitlist()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event_id uuid := COALESCE(new.event_id, old.event_id);
  v_old_status text := old.attendance_status;
  v_new_status text := new.attendance_status;
  v_is_business boolean;
BEGIN
  SELECT (COALESCE(organizer_type, 'user') = 'business') INTO v_is_business
  FROM public.events
  WHERE id = v_event_id;

  IF NOT v_is_business THEN
    RETURN COALESCE(new, old);
  END IF;

  IF (tg_op = 'DELETE' AND v_old_status IN ('confirmed', 'checked_in'))
     OR (tg_op = 'UPDATE' AND v_old_status IN ('confirmed', 'checked_in') AND v_new_status NOT IN ('confirmed', 'checked_in'))
  THEN
    PERFORM public.promote_waitlist_participant(v_event_id);
  END IF;

  RETURN COALESCE(new, old);
END;
$$;

DROP TRIGGER IF EXISTS after_participant_status_changed_waitlist_trigger ON public.event_participants;
CREATE TRIGGER after_participant_status_changed_waitlist_trigger
AFTER UPDATE OR DELETE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.after_participant_status_changed_waitlist();

-- 4. Reminders Scheduling Table
CREATE TABLE IF NOT EXISTS public.event_reminders_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reminder_type text NOT NULL CHECK (reminder_type IN ('24h', '1h')),
  scheduled_for timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, user_id, reminder_type)
);

ALTER TABLE public.event_reminders_schedule ENABLE ROW LEVEL SECURITY;

-- 5. Reminder scheduling functions
CREATE OR REPLACE FUNCTION public.schedule_event_reminders(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event public.events%rowtype;
  v_participant record;
  v_24h_time timestamptz;
  v_1h_time timestamptz;
  v_is_plus boolean;
BEGIN
  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event.id IS NULL THEN
    RETURN;
  END IF;

  v_is_plus := (COALESCE(v_event.organizer_type, 'user') = 'business') AND public.check_business_plus_active(v_event.organizer_business_id);
  IF NOT v_is_plus THEN
    RETURN;
  END IF;

  v_24h_time := v_event.event_date - interval '24 hours';
  v_1h_time := v_event.event_date - interval '1 hour';

  FOR v_participant IN
    SELECT user_id
    FROM public.event_participants
    WHERE event_id = p_event_id
      AND role = 'participant'
      AND attendance_status IN ('confirmed', 'planned', 'checked_in')
  LOOP
    IF v_24h_time > now() THEN
      INSERT INTO public.event_reminders_schedule (event_id, user_id, reminder_type, scheduled_for, status)
      VALUES (p_event_id, v_participant.user_id, '24h', v_24h_time, 'pending')
      ON CONFLICT (event_id, user_id, reminder_type) DO UPDATE
      SET scheduled_for = EXCLUDED.scheduled_for,
          status = CASE 
            WHEN public.event_reminders_schedule.status = 'sent' AND public.event_reminders_schedule.scheduled_for = EXCLUDED.scheduled_for THEN 'sent'
            ELSE 'pending'
          END,
          updated_at = now();
    END IF;

    IF v_1h_time > now() THEN
      INSERT INTO public.event_reminders_schedule (event_id, user_id, reminder_type, scheduled_for, status)
      VALUES (p_event_id, v_participant.user_id, '1h', v_1h_time, 'pending')
      ON CONFLICT (event_id, user_id, reminder_type) DO UPDATE
      SET scheduled_for = EXCLUDED.scheduled_for,
          status = CASE 
            WHEN public.event_reminders_schedule.status = 'sent' AND public.event_reminders_schedule.scheduled_for = EXCLUDED.scheduled_for THEN 'sent'
            ELSE 'pending'
          END,
          updated_at = now();
    END IF;
  END LOOP;
END;
$$;

-- Participant confirmed trigger
CREATE OR REPLACE FUNCTION public.after_participant_confirmed_schedule_reminders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF new.role = 'participant' AND new.attendance_status IN ('confirmed', 'planned', 'checked_in') THEN
    PERFORM public.schedule_event_reminders(new.event_id);
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS after_participant_confirmed_schedule_reminders_trigger ON public.event_participants;
CREATE TRIGGER after_participant_confirmed_schedule_reminders_trigger
AFTER INSERT OR UPDATE OF attendance_status ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.after_participant_confirmed_schedule_reminders();

-- Participant leave/cancellation trigger
CREATE OR REPLACE FUNCTION public.cancel_scheduled_reminders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF tg_op = 'DELETE' OR (tg_op = 'UPDATE' AND new.attendance_status NOT IN ('confirmed', 'planned', 'checked_in')) THEN
    UPDATE public.event_reminders_schedule
    SET status = 'cancelled',
        updated_at = now()
    WHERE event_id = COALESCE(new.event_id, old.event_id)
      AND user_id = COALESCE(new.user_id, old.user_id)
      AND status = 'pending';
  END IF;
  RETURN COALESCE(new, old);
END;
$$;

DROP TRIGGER IF EXISTS cancel_scheduled_reminders_trigger ON public.event_participants;
CREATE TRIGGER cancel_scheduled_reminders_trigger
AFTER UPDATE OR DELETE ON public.event_participants
FOR EACH ROW EXECUTE FUNCTION public.cancel_scheduled_reminders();

-- Event reschedule/cancel trigger
CREATE OR REPLACE FUNCTION public.after_event_modified_reminders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF new.status <> 'active' OR new.moderation_status <> 'approved' THEN
    UPDATE public.event_reminders_schedule
    SET status = 'cancelled',
        updated_at = now()
    WHERE event_id = new.id
      AND status = 'pending';
  ELSIF new.event_date IS DISTINCT FROM old.event_date THEN
    -- Cancel pending
    UPDATE public.event_reminders_schedule
    SET status = 'cancelled',
        updated_at = now()
    WHERE event_id = new.id
      AND status = 'pending';
    -- Re-schedule
    PERFORM public.schedule_event_reminders(new.id);
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS after_event_modified_reminders_trigger ON public.events;
CREATE TRIGGER after_event_modified_reminders_trigger
AFTER UPDATE OF status, moderation_status, event_date ON public.events
FOR EACH ROW EXECUTE FUNCTION public.after_event_modified_reminders();

-- 6. Cron Process Event Reminders
CREATE OR REPLACE FUNCTION public.process_event_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reminder record;
  v_event public.events%rowtype;
  v_notification_id uuid;
  v_body text;
  v_title text;
BEGIN
  -- Concurrency check using lock
  PERFORM pg_advisory_xact_lock(
    hashtextextended('process_scheduled_reminders_lock', 0)
  );

  FOR v_reminder IN
    SELECT *
    FROM public.event_reminders_schedule
    WHERE status = 'pending'
      AND scheduled_for <= now()
  LOOP
    SELECT * INTO v_event FROM public.events WHERE id = v_reminder.event_id;

    IF v_event.id IS NOT NULL AND v_event.status = 'active' AND v_event.moderation_status = 'approved' THEN
      IF EXISTS (
        SELECT 1 FROM public.event_participants
        WHERE event_id = v_reminder.event_id
          AND user_id = v_reminder.user_id
          AND attendance_status IN ('confirmed', 'planned', 'checked_in')
      ) THEN
        IF v_reminder.reminder_type = '24h' THEN
          v_title := 'Etkinlik Yarın!';
          v_body := v_event.title || ' etkinliğine son 24 saat. Hazır mısın?';
        ELSE
          v_title := 'Etkinlik Yaklaşıyor!';
          v_body := v_event.title || ' etkinliğine son 1 saat. Hazırlanmaya başla!';
        END IF;

        -- Create notification
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
          v_reminder.user_id,
          v_event.host_id,
          'system',
          v_title,
          v_body,
          'event',
          v_reminder.event_id::text,
          jsonb_build_object('event_id', v_reminder.event_id, 'reminder_type', v_reminder.reminder_type),
          false
        )
        RETURNING id INTO v_notification_id;

        -- Insert to push outbox (deduplicated by notification_id)
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
          v_notification_id,
          v_reminder.user_id,
          'event_reminder',
          v_title,
          v_body,
          'event',
          v_reminder.event_id::text,
          jsonb_build_object('event_id', v_reminder.event_id, 'reminder_type', v_reminder.reminder_type)
        )
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

    UPDATE public.event_reminders_schedule
    SET status = 'sent',
        updated_at = now()
    WHERE id = v_reminder.id;
  END LOOP;
END;
$$;

-- 7. Advanced QR & Attendance Analytics RPC
CREATE OR REPLACE FUNCTION public.get_business_attendance_analytics(
  p_business_account_id uuid,
  p_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_total_approved bigint := 0;
  v_total_checked_in bigint := 0;
  v_total_no_show bigint := 0;
  v_attendance_percentage numeric := 0;
  v_returning_percentage numeric := 0;
  v_total_unique_attended bigint := 0;
  v_total_returning bigint := 0;
  v_day_performance jsonb := '[]'::jsonb;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verify active Plus subscription
  IF NOT public.check_business_plus_active(p_business_account_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  -- Verify ownership
  IF NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = p_business_account_id AND owner_user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- General counts
  SELECT
    COALESCE(SUM(CASE WHEN ep.attendance_status IN ('confirmed', 'checked_in') THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN ep.attendance_status = 'checked_in' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN ep.attendance_status = 'no_show' THEN 1 ELSE 0 END), 0)
  INTO v_total_approved, v_total_checked_in, v_total_no_show
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE e.organizer_business_id = p_business_account_id
    AND e.status = 'active'
    AND e.event_date >= (now() - (p_days || ' days')::interval)
    AND e.event_date <= now()
    AND ep.role = 'participant';

  IF v_total_approved > 0 THEN
    v_attendance_percentage := (v_total_checked_in * 100.0) / v_total_approved;
  END IF;

  -- Returning Participant Rate (verified attendance on more than one distinct event)
  SELECT COUNT(DISTINCT ep.user_id) INTO v_total_unique_attended
  FROM public.event_participants ep
  JOIN public.events e ON e.id = ep.event_id
  WHERE e.organizer_business_id = p_business_account_id
    AND ep.attendance_status = 'checked_in'
    AND ep.role = 'participant';

  WITH user_checked_in_counts AS (
    SELECT ep.user_id, COUNT(DISTINCT ep.event_id) as event_count
    FROM public.event_participants ep
    JOIN public.events e ON e.id = ep.event_id
    WHERE e.organizer_business_id = p_business_account_id
      AND ep.attendance_status = 'checked_in'
      AND ep.role = 'participant'
    GROUP BY ep.user_id
  )
  SELECT COUNT(*) INTO v_total_returning
  FROM user_checked_in_counts
  WHERE event_count > 1;

  IF v_total_unique_attended > 0 THEN
    v_returning_percentage := (v_total_returning * 100.0) / v_total_unique_attended;
  END IF;

  -- Day/time performance aggregation
  SELECT json_agg(row_to_json(day_perf))::jsonb INTO v_day_performance
  FROM (
    SELECT
      to_char(timezone('Europe/Istanbul', e.event_date), 'TMDay') as day_name,
      to_char(timezone('Europe/Istanbul', e.event_date), 'HH24:00') as time_slot,
      COUNT(DISTINCT e.id) as event_count,
      COALESCE(SUM(CASE WHEN ep.attendance_status = 'checked_in' THEN 1 ELSE 0 END), 0) as checked_in_count
    FROM public.events e
    LEFT JOIN public.event_participants ep ON ep.event_id = e.id AND ep.role = 'participant'
    WHERE e.organizer_business_id = p_business_account_id
      AND e.status = 'active'
      AND e.event_date >= (now() - (p_days || ' days')::interval)
      AND e.event_date <= now()
    GROUP BY day_name, time_slot
    ORDER BY checked_in_count DESC
    LIMIT 5
  ) day_perf;

  v_result := jsonb_build_object(
    'approved_count', v_total_approved,
    'checked_in_count', v_total_checked_in,
    'no_show_count', v_total_no_show,
    'attendance_percentage', ROUND(v_attendance_percentage, 1),
    'returning_participant_percentage', ROUND(v_returning_percentage, 1),
    'day_performance', COALESCE(v_day_performance, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_business_attendance_analytics(uuid, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_business_attendance_analytics(uuid, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
