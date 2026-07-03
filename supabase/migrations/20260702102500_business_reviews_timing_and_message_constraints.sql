-- Migration to drop invalid foreign key constraint on message_reports.message_id
-- and update the submit_business_review function to prevent early reviews.

-- 1. Drop foreign key constraint on message_reports.message_id to allow polymorphism
ALTER TABLE public.message_reports DROP CONSTRAINT IF EXISTS message_reports_message_id_fkey;

-- 2. Update submit_business_review function with the timing check
CREATE OR REPLACE FUNCTION public.submit_business_review(
  p_event_id uuid,
  p_business_id uuid,
  p_rating integer,
  p_comment text
)
RETURNS void AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_event public.events%rowtype;
  v_event_end timestamptz;
  v_event_start timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'invalid_rating';
  END IF;

  IF v_comment IS NOT NULL THEN
    v_comment := regexp_replace(v_comment, '\s+', ' ', 'g');
    IF length(v_comment) > 300 THEN
      RAISE EXCEPTION 'comment_too_long';
    END IF;
  END IF;

  SELECT *
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  IF COALESCE(v_event.organizer_type, 'user') <> 'business' OR v_event.organizer_business_id <> p_business_id THEN
    RAISE EXCEPTION 'not_business_event';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.business_accounts business
    WHERE business.id = p_business_id
      AND business.owner_user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'cannot_rate_own_business';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.event_participants participant
    WHERE participant.event_id = p_event_id
      AND participant.user_id = v_user_id
      AND participant.role = 'participant'
      AND participant.attendance_status IN ('checked_in', 'confirmed')
  ) THEN
    RAISE EXCEPTION 'event_not_attended';
  END IF;

  -- Timing check: Enforce that review can only be submitted after the event has ended
  IF v_event.event_end_time IS NOT NULL THEN
    v_event_start := COALESCE(
      CASE WHEN v_event.event_start_time IS NOT NULL THEN
        timezone('UTC', v_event.event_date::date + v_event.event_start_time)
      ELSE v_event.event_date END,
      v_event.event_date
    );
    v_event_end := timezone('UTC', v_event.event_date::date + v_event.event_end_time);
    IF v_event_end <= v_event_start THEN
      v_event_end := v_event_end + INTERVAL '1 day';
    END IF;
  ELSE
    v_event_end := v_event.event_date + INTERVAL '2 hours';
  END IF;

  IF now() < v_event_end THEN
    RAISE EXCEPTION 'event_not_ended';
  END IF;

  INSERT INTO public.business_reviews (
    business_id,
    event_id,
    user_id,
    rating,
    comment
  )
  VALUES (
    p_business_id,
    p_event_id,
    v_user_id,
    p_rating,
    v_comment
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
