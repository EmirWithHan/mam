-- Migration to support business profile defaults and business event creation fields
-- Adding business account defaults
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS working_hours jsonb;
ALTER TABLE public.business_accounts ADD COLUMN IF NOT EXISTS amenities text[];

COMMENT ON COLUMN public.business_accounts.latitude IS 'Latitude of the business location for map default.';
COMMENT ON COLUMN public.business_accounts.longitude IS 'Longitude of the business location for map default.';
COMMENT ON COLUMN public.business_accounts.working_hours IS 'General working hours of the business profile.';
COMMENT ON COLUMN public.business_accounts.amenities IS 'List of facility features / amenities.';

-- Adding event-specific pricing and participation metadata
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_start_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_end_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_type text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_amount numeric;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price_currency text DEFAULT 'TRY';
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS listing_expires_at timestamptz;

COMMENT ON COLUMN public.events.event_start_time IS 'Event-specific start time.';
COMMENT ON COLUMN public.events.event_end_time IS 'Event-specific end time.';
COMMENT ON COLUMN public.events.price_type IS 'Pricing type (free, pay_at_business).';
COMMENT ON COLUMN public.events.price_amount IS 'Pricing amount if paid.';
COMMENT ON COLUMN public.events.price_currency IS 'Pricing currency (default TRY).';
COMMENT ON COLUMN public.events.listing_expires_at IS 'Timestamp when the business listing expires and should be hidden from public discovery feeds (usually 24 hours after creation).';
