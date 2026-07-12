-- Add location_description to public.events if it does not already exist
alter table public.events add column if not exists location_description text;
