-- Add location_description to public.events
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS location_description text;
