-- Migration to support business event listing visibility and availability hours
-- 1. listing_expires_at: Business event listings should stop appearing in public lists after 24 hours.
-- 2. business_open_time / business_close_time: Opening and closing availability hours for business listings.

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS listing_expires_at timestamptz;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS business_open_time time;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS business_close_time time;

COMMENT ON COLUMN public.events.listing_expires_at IS 'Timestamp when the business listing expires and should be hidden from public discovery feeds (usually 24 hours after creation).';
COMMENT ON COLUMN public.events.business_open_time IS 'Opening hour for the business event availability.';
COMMENT ON COLUMN public.events.business_close_time IS 'Closing hour for the business event availability.';
