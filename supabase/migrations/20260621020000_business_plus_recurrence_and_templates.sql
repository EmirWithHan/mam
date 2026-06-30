-- Migration: Business Plus recurrence, templates, and last-minute vacancy
-- Timestamp: 20260621020000

-- 1. Create event templates table
CREATE TABLE IF NOT EXISTS public.event_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  activity_type text NOT NULL,
  location_name text NOT NULL,
  latitude double precision,
  longitude double precision,
  capacity integer NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 60,
  participant_requirements jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.event_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Business owners can manage own templates" ON public.event_templates;
CREATE POLICY "Business owners can manage own templates"
  ON public.event_templates
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = event_templates.business_account_id
        AND ba.owner_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = event_templates.business_account_id
        AND ba.owner_user_id = auth.uid()
    )
  );

-- Enforce Plus on Templates insertion
CREATE OR REPLACE FUNCTION public.enforce_event_templates_plus()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.check_business_plus_active(new.business_account_id) THEN
    RAISE EXCEPTION 'business_plus_required_for_templates';
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS enforce_event_templates_plus_trigger ON public.event_templates;
CREATE TRIGGER enforce_event_templates_plus_trigger
BEFORE INSERT OR UPDATE ON public.event_templates
FOR EACH ROW EXECUTE FUNCTION public.enforce_event_templates_plus();

-- 2. Create event recurring series table
CREATE TABLE IF NOT EXISTS public.event_recurring_series (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  pattern_type text NOT NULL CHECK (pattern_type IN ('daily', 'weekly_days', 'interval_days', 'interval_weeks', 'custom_dates')),
  pattern_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.event_recurring_series ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Business owners can manage own series" ON public.event_recurring_series;
CREATE POLICY "Business owners can manage own series"
  ON public.event_recurring_series
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = event_recurring_series.business_account_id
        AND ba.owner_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.business_accounts ba
      WHERE ba.id = event_recurring_series.business_account_id
        AND ba.owner_user_id = auth.uid()
    )
  );

DROP TRIGGER IF EXISTS enforce_event_recurring_series_plus_trigger ON public.event_recurring_series;
CREATE TRIGGER enforce_event_recurring_series_plus_trigger
BEFORE INSERT OR UPDATE ON public.event_recurring_series
FOR EACH ROW EXECUTE FUNCTION public.enforce_event_templates_plus(); -- Reuse checker

-- 3. Add columns to events table
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES public.event_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS series_id uuid REFERENCES public.event_recurring_series(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_last_minute_vacancy boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS vacancy_count integer DEFAULT 0;

-- 4. Create atomic recurring series creation RPC (with idempotency and quota checking)
CREATE OR REPLACE FUNCTION public.create_recurring_event_series(
  p_business_account_id uuid,
  p_pattern_type text,
  p_pattern_metadata jsonb,
  p_event_data jsonb,
  p_dates timestamptz[],
  p_creation_request_ids uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_series_id uuid;
  v_date timestamptz;
  v_required_quota integer;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_month_counts jsonb := '{}'::jsonb;
  v_month_key text;
  v_month_total integer;
  v_user_id uuid := auth.uid();
  v_idx integer;
  v_req_id uuid;
  v_existing_series_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Verify active subscription
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

  -- Concurrency quota lock
  PERFORM pg_advisory_xact_lock(
    hashtextextended('business_quota_lock:' || p_business_account_id::text, 0)
  );

  -- Idempotency check: if the first request ID already exists, return its series ID
  IF p_creation_request_ids IS NOT NULL AND array_length(p_creation_request_ids, 1) > 0 THEN
    SELECT series_id INTO v_existing_series_id
    FROM public.events
    WHERE host_id = v_user_id
      AND creation_request_id = p_creation_request_ids[1]
    LIMIT 1;

    IF v_existing_series_id IS NOT NULL THEN
      RETURN v_existing_series_id;
    END IF;
  END IF;

  -- Horizon & length checks
  IF p_dates IS NULL OR array_length(p_dates, 1) = 0 THEN
    RAISE EXCEPTION 'empty_dates';
  END IF;

  IF array_length(p_dates, 1) > 50 THEN
    RAISE EXCEPTION 'max_occurrences_exceeded';
  END IF;

  FOREACH v_date IN ARRAY p_dates LOOP
    IF v_date > (now() + interval '180 days') THEN
      RAISE EXCEPTION 'horizon_exceeded';
    END IF;
    IF v_date < now() THEN
      RAISE EXCEPTION 'past_date_not_allowed';
    END IF;
  END LOOP;

  -- Group by calendar month in Europe/Istanbul timezone
  FOREACH v_date IN ARRAY p_dates LOOP
    v_month_key := to_char(timezone('Europe/Istanbul', v_date), 'YYYY-MM');
    v_month_counts := jsonb_set(
      v_month_counts,
      ARRAY[v_month_key],
      to_jsonb(COALESCE((v_month_counts->>v_month_key)::integer, 0) + 1)
    );
  END LOOP;

  -- Quota verification
  FOR v_month_key IN SELECT jsonb_object_keys(v_month_counts) LOOP
    v_required_quota := (v_month_counts->>v_month_key)::integer;
    v_period_start := timezone('Europe/Istanbul', (v_month_key || '-01 00:00:00')::timestamp) at time zone 'Europe/Istanbul';
    v_period_end := (v_period_start + interval '1 month');

    SELECT COUNT(*)::integer INTO v_month_total
    FROM public.event_creation_quota_events
    WHERE business_account_id = p_business_account_id
      AND created_at >= v_period_start
      AND created_at < v_period_end;

    IF (v_month_total + v_required_quota) > 30 THEN
      RAISE EXCEPTION 'quota_limit_exceeded_for_month %', v_month_key;
    END IF;
  END LOOP;

  -- Insert recurring series
  INSERT INTO public.event_recurring_series (
    business_account_id,
    pattern_type,
    pattern_metadata
  )
  VALUES (
    p_business_account_id,
    p_pattern_type,
    p_pattern_metadata
  )
  RETURNING id INTO v_series_id;

  -- Insert events
  FOR v_idx IN 1..array_length(p_dates, 1) LOOP
    v_date := p_dates[v_idx];
    v_req_id := NULL;
    IF p_creation_request_ids IS NOT NULL AND array_length(p_creation_request_ids, 1) >= v_idx THEN
      v_req_id := p_creation_request_ids[v_idx];
    END IF;

    INSERT INTO public.events (
      host_id,
      organizer_type,
      organizer_business_id,
      title,
      description,
      activity_type,
      location_name,
      latitude,
      longitude,
      capacity,
      duration_minutes,
      participant_requirements,
      event_date,
      series_id,
      creation_request_id,
      event_start_time,
      event_end_time
    )
    VALUES (
      v_user_id,
      'business',
      p_business_account_id,
      p_event_data->>'title',
      p_event_data->>'description',
      p_event_data->>'activity_type',
      p_event_data->>'location_name',
      (p_event_data->>'latitude')::double precision,
      (p_event_data->>'longitude')::double precision,
      (p_event_data->>'capacity')::integer,
      COALESCE((p_event_data->>'duration_minutes')::integer, 60),
      COALESCE(p_event_data->'participant_requirements', '{}'::jsonb),
      v_date,
      v_series_id,
      v_req_id,
      p_event_data->>'event_start_time',
      p_event_data->>'event_end_time'
    );
  END LOOP;

  RETURN v_series_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_recurring_event_series(uuid, text, jsonb, jsonb, timestamptz[], uuid[]) TO authenticated;

-- 5. Last Minute Vacancy RPC (with safety/quota checks)
CREATE OR REPLACE FUNCTION public.toggle_last_minute_vacancy(
  p_event_id uuid,
  p_is_active boolean,
  p_vacancy_count integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_remaining_capacity integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO v_event FROM public.events WHERE id = p_event_id FOR UPDATE;

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'event_not_found';
  END IF;

  -- Ownership check
  IF v_event.organizer_type <> 'business' OR NOT EXISTS (
    SELECT 1 FROM public.business_accounts
    WHERE id = v_event.organizer_business_id AND owner_user_id = v_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Plus check
  IF NOT public.check_business_plus_active(v_event.organizer_business_id) THEN
    RAISE EXCEPTION 'business_plus_required';
  END IF;

  IF p_is_active THEN
    -- Active event checks: approved, active, <= 24 hours
    IF v_event.status <> 'active' THEN
      RAISE EXCEPTION 'event_not_active';
    END IF;

    IF v_event.moderation_status <> 'approved' THEN
      RAISE EXCEPTION 'event_not_approved';
    END IF;

    IF v_event.event_date < now() THEN
      RAISE EXCEPTION 'event_already_started';
    END IF;

    IF v_event.event_date > (now() + interval '24 hours') THEN
      RAISE EXCEPTION 'event_starts_beyond_24h';
    END IF;

    -- Vacancy count checks
    v_remaining_capacity := v_event.capacity_total - v_event.approved_count;
    IF v_remaining_capacity <= 0 THEN
      RAISE EXCEPTION 'event_is_full';
    END IF;

    IF p_vacancy_count <= 0 OR p_vacancy_count > v_remaining_capacity THEN
      RAISE EXCEPTION 'invalid_vacancy_count';
    END IF;

    -- Update vacancy status
    UPDATE public.events
    SET is_last_minute_vacancy = true,
        vacancy_count = p_vacancy_count
    WHERE id = p_event_id;
  ELSE
    UPDATE public.events
    SET is_last_minute_vacancy = false,
        vacancy_count = 0
    WHERE id = p_event_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.toggle_last_minute_vacancy(uuid, boolean, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.toggle_last_minute_vacancy(uuid, boolean, integer) TO authenticated;

-- 6. Trigger to automatically close last minute vacancy when full or started
CREATE OR REPLACE FUNCTION public.auto_close_last_minute_vacancy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_remaining integer;
BEGIN
  IF new.is_last_minute_vacancy THEN
    v_remaining := new.capacity_total - new.approved_count;
    IF v_remaining <= 0 OR new.event_date <= now() OR new.status <> 'active' OR new.moderation_status <> 'approved' THEN
      new.is_last_minute_vacancy := false;
      new.vacancy_count := 0;
    ELSIF new.vacancy_count > v_remaining THEN
      new.vacancy_count := v_remaining;
    END IF;
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS auto_close_last_minute_vacancy_trigger ON public.events;
CREATE TRIGGER auto_close_last_minute_vacancy_trigger
BEFORE UPDATE OF approved_count, status, moderation_status, event_date, vacancy_count ON public.events
FOR EACH ROW EXECUTE FUNCTION public.auto_close_last_minute_vacancy();

NOTIFY pgrst, 'reload schema';
