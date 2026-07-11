ALTER TABLE public.business_plus_subscriptions
  ADD COLUMN IF NOT EXISTS last_reconciliation_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_reconciliation_error_code text;

CREATE INDEX IF NOT EXISTS business_plus_reconciliation_queue_idx
  ON public.business_plus_subscriptions (
    store,
    last_reconciliation_attempt_at ASC NULLS FIRST,
    latest_verification_time ASC NULLS FIRST,
    id ASC
  );
