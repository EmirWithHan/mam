-- Migration: pg_cron scheduler setup for reminders and cache reconciliation (Inert Foundation)
-- Timestamp: 20260621040000

-- Enable pg_cron extension if not exists
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Note: Cron jobs registration has been moved to manual SQL scripts for staging safety.
-- See: supabase/manual/business_plus_enable_staging_cron.sql

NOTIFY pgrst, 'reload schema';
