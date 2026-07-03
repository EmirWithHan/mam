-- Enforce organizer event edit limits.

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS organizer_edit_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS organizer_last_edited_at timestamptz;

CREATE OR REPLACE FUNCTION public.enforce_event_organizer_edit_locks()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizer_fields_changed boolean := false;
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN new;
  END IF;

  v_organizer_fields_changed :=
    old.title IS DISTINCT FROM new.title OR
    old.description IS DISTINCT FROM new.description OR
    old.event_date IS DISTINCT FROM new.event_date OR
    old.sport_type IS DISTINCT FROM new.sport_type OR
    old.city IS DISTINCT FROM new.city OR
    old.district IS DISTINCT FROM new.district OR
    old.location_text IS DISTINCT FROM new.location_text OR
    old.location_lat IS DISTINCT FROM new.location_lat OR
    old.location_lng IS DISTINCT FROM new.location_lng OR
    old.location_description IS DISTINCT FROM new.location_description OR
    old.capacity_total IS DISTINCT FROM new.capacity_total OR
    old.generic_capacity IS DISTINCT FROM new.generic_capacity OR
    old.male_capacity IS DISTINCT FROM new.male_capacity OR
    old.female_capacity IS DISTINCT FROM new.female_capacity OR
    old.is_paid IS DISTINCT FROM new.is_paid OR
    old.price_type IS DISTINCT FROM new.price_type OR
    old.price_amount IS DISTINCT FROM new.price_amount OR
    old.price_currency IS DISTINCT FROM new.price_currency OR
    old.organizer_business_id IS DISTINCT FROM new.organizer_business_id;

  IF NOT v_organizer_fields_changed THEN
    new.organizer_edit_count := old.organizer_edit_count;
    new.organizer_last_edited_at := old.organizer_last_edited_at;
    RETURN new;
  END IF;

  IF auth.role() = 'service_role' THEN
    RETURN new;
  END IF;

  IF coalesce(old.organizer_edit_count, 0) >= 1 THEN
    RAISE EXCEPTION 'event_edit_limit_reached';
  END IF;

  IF old.event_date <= now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'event_edit_window_closed';
  END IF;

  new.organizer_edit_count := coalesce(old.organizer_edit_count, 0) + 1;
  new.organizer_last_edited_at := now();

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_event_organizer_edit_locks ON public.events;
CREATE TRIGGER trg_enforce_event_organizer_edit_locks
  BEFORE UPDATE ON public.events
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_event_organizer_edit_locks();
