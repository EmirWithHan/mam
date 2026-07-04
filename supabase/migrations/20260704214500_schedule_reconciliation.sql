-- Migration: Schedule Business Plus reconciliation daily at 04:00 UTC
-- Timestamp: 20260704214500

-- Schedule the daily reconciliation job using pg_cron.
-- It retrieves the PUSH_WORKER_SECRET securely from the Supabase Vault
-- to avoid exposing the raw secret value in the cron.job.command table.
SELECT cron.schedule(
  'reconcile-business-plus-subscriptions',
  '0 4 * * *',
  $$
  SELECT public.cron_reconcile_subscriptions(
    'exzwwvjfudevpycpypkf',
    COALESCE(
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'reconcile_push_worker_secret'),
      ''
    )
  );
  $$
);
