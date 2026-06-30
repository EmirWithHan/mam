-- Migration: Personal Event 30-Day Scheduling Horizon Enforcer
-- Restricts ordinary personal user events to a strict 30-day window.

CREATE OR REPLACE FUNCTION public.enforce_event_scheduling_horizon()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Identify ordinary personal event: organizer_type = 'user' and community_id is NULL
  IF new.organizer_type = 'user' AND new.community_id IS NULL THEN
    
    -- For UPDATE operations, check if the event_date is actually being modified
    IF TG_OP = 'UPDATE' THEN
      IF new.event_date IS DISTINCT FROM old.event_date THEN
        -- If the original date was already outside the 30-day window
        IF old.event_date > (now() + interval '30 days') THEN
          -- User cannot move it even farther into the future
          IF new.event_date > old.event_date THEN
            RAISE EXCEPTION 'event_date_too_far';
          END IF;
        ELSE
          -- Original date was within 30 days, so the new date must also be within 30 days
          IF new.event_date > (now() + interval '30 days') THEN
            RAISE EXCEPTION 'event_date_too_far';
          END IF;
        END IF;
      END IF;
    ELSE
      -- For INSERT operations, the date must be within 30 days
      IF new.event_date > (now() + interval '30 days') THEN
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

NOTIFY pgrst, 'reload schema';
