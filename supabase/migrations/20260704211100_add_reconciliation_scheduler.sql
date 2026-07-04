-- Migration: Add SQL helper function for scheduled Business Plus reconciliation
-- Timestamp: 20260704211100

-- Enable pg_net extension if not exists
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create helper function to trigger the reconciliation Edge Function
CREATE OR REPLACE FUNCTION public.cron_reconcile_subscriptions(
  p_project_ref text,
  p_secret text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://' || p_project_ref || '.supabase.co/functions/v1/reconcile-business-plus-subscription',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || p_secret
    ),
    body := jsonb_build_object(
      'limit', p_limit,
      'offset', p_offset
    )
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
