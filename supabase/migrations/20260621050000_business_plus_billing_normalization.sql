-- Migration: Business Plus Billing Normalization
-- Timestamp: 20260621050000

-- 1. Create secure private schema if not exists
CREATE SCHEMA IF NOT EXISTS private;

-- 2. Drop old status check constraint from public.business_plus_subscriptions
ALTER TABLE public.business_plus_subscriptions 
  DROP CONSTRAINT IF EXISTS business_plus_subscriptions_status_check;

-- 3. Add billing metadata columns to public.business_plus_subscriptions
ALTER TABLE public.business_plus_subscriptions
  ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS store text,
  ADD COLUMN IF NOT EXISTS product_id text,
  ADD COLUMN IF NOT EXISTS base_plan_id text,
  ADD COLUMN IF NOT EXISTS original_transaction_id text,
  ADD COLUMN IF NOT EXISTS external_purchase_identity_hash text,
  ADD COLUMN IF NOT EXISTS store_subscription_status text,
  ADD COLUMN IF NOT EXISTS entitlement_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS purchase_time timestamptz,
  ADD COLUMN IF NOT EXISTS current_period_start timestamptz,
  ADD COLUMN IF NOT EXISTS current_period_end timestamptz,
  ADD COLUMN IF NOT EXISTS auto_renew_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS cancellation_time timestamptz,
  ADD COLUMN IF NOT EXISTS grace_period_end timestamptz,
  ADD COLUMN IF NOT EXISTS revocation_time timestamptz,
  ADD COLUMN IF NOT EXISTS environment text,
  ADD COLUMN IF NOT EXISTS latest_verification_time timestamptz,
  ADD COLUMN IF NOT EXISTS latest_notification_identity text;

-- 4. Add constraints and indexes to public.business_plus_subscriptions
ALTER TABLE public.business_plus_subscriptions
  ADD CONSTRAINT business_plus_subscriptions_store_check
    CHECK (store IS NULL OR store IN ('google_play', 'app_store', 'manual_admin')),
  ADD CONSTRAINT business_plus_subscriptions_environment_check
    CHECK (environment IS NULL OR environment IN ('sandbox', 'production')),
  ADD CONSTRAINT business_plus_subscriptions_entitlement_status_check
    CHECK (entitlement_status IN ('active', 'expired', 'cancelled', 'grace_period', 'revoked', 'billing_retry', 'paused')),
  ADD CONSTRAINT business_plus_subscriptions_external_identity_uniq
    UNIQUE (store, external_purchase_identity_hash);

CREATE INDEX IF NOT EXISTS business_plus_subscriptions_ext_hash_idx 
  ON public.business_plus_subscriptions (store, external_purchase_identity_hash);

-- 5. Create secure server-only proofs table
CREATE TABLE IF NOT EXISTS private.business_plus_subscription_proofs (
  subscription_id uuid PRIMARY KEY REFERENCES public.business_plus_subscriptions(id) ON DELETE CASCADE,
  purchase_token text,
  raw_payload jsonb,
  app_account_token uuid,
  obfuscated_account_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS and revoke all public/authenticated access to proofs
ALTER TABLE private.business_plus_subscription_proofs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.business_plus_subscription_proofs FROM public, authenticated, anon;

-- 6. Create secure server-only webhook deduplication table
CREATE TABLE IF NOT EXISTS private.processed_webhook_notifications (
  notification_id text PRIMARY KEY,
  store text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS and revoke all access to dedupe table
ALTER TABLE private.processed_webhook_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.processed_webhook_notifications FROM public, authenticated, anon;

-- 7. Create public purchase contexts table for context binding
CREATE TABLE IF NOT EXISTS public.business_plus_purchase_contexts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('android', 'ios')),
  product_id text NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS on purchase contexts
ALTER TABLE public.business_plus_purchase_contexts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own purchase contexts" ON public.business_plus_purchase_contexts;
CREATE POLICY "Users can manage their own purchase contexts"
  ON public.business_plus_purchase_contexts
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 8. Redefine public.check_business_plus_active to use entitlement_status and revocation_time
CREATE OR REPLACE FUNCTION public.check_business_plus_active(p_business_account_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.business_plus_subscriptions subscription
    WHERE subscription.business_account_id = p_business_account_id
      AND subscription.entitlement_status IN ('active', 'grace_period')
      AND subscription.starts_at <= now()
      AND (subscription.ends_at IS NULL OR subscription.ends_at > now())
      AND subscription.revocation_time IS NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_business_plus_active(uuid) TO authenticated;

-- 9. Redefine manual admin entitlement override to keep store subscriptions separate
CREATE OR REPLACE FUNCTION public.admin_set_business_plus_subscription(
  p_business_account_id uuid,
  p_status text,
  p_duration_days integer DEFAULT 30
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_subscription_id uuid;
  v_ends_at timestamptz;
  v_owner_id uuid;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_duration_days IS NOT NULL AND p_duration_days > 0 THEN
    v_ends_at := now() + (p_duration_days || ' days')::interval;
  ELSE
    v_ends_at := NULL;
  END IF;

  SELECT owner_user_id INTO v_owner_id
  FROM public.business_accounts
  WHERE id = p_business_account_id;

  -- Deactivate any previous manual_admin subscription only
  UPDATE public.business_plus_subscriptions
  SET entitlement_status = 'expired',
      ends_at = now(),
      updated_at = now()
  WHERE business_account_id = p_business_account_id
    AND store = 'manual_admin'
    AND entitlement_status = 'active';

  -- Insert new manual subscription
  INSERT INTO public.business_plus_subscriptions (
    business_account_id,
    owner_user_id,
    store,
    product_id,
    entitlement_status,
    starts_at,
    ends_at,
    status
  )
  VALUES (
    p_business_account_id,
    v_owner_id,
    'manual_admin',
    'business_plus_manual',
    p_status,
    now(),
    v_ends_at,
    p_status
  )
  RETURNING id INTO v_subscription_id;

  -- Sync cache immediately
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  RETURN v_subscription_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_business_plus_subscription(uuid, text, integer) TO authenticated;

-- 10. Create atomic transaction-safe RPC for purchase verification and ingestion
CREATE OR REPLACE FUNCTION public.service_verify_and_upsert_subscription(
  p_business_account_id uuid,
  p_owner_user_id uuid,
  p_store text,
  p_product_id text,
  p_base_plan_id text,
  p_original_transaction_id text,
  p_external_purchase_identity_hash text,
  p_store_subscription_status text,
  p_entitlement_status text,
  p_purchase_time timestamptz,
  p_current_period_start timestamptz,
  p_current_period_end timestamptz,
  p_auto_renew_enabled boolean,
  p_cancellation_time timestamptz,
  p_grace_period_end timestamptz,
  p_revocation_time timestamptz,
  p_environment text,
  p_purchase_context_id uuid,
  p_purchase_token text,
  p_raw_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_subscription_id uuid;
  v_context_user_id uuid;
  v_context_business_id uuid;
  v_context_consumed timestamptz;
  v_context_expires timestamptz;
BEGIN
  -- This function is restricted to service_role (or admin-like connection)
  -- The Edge Function calls it using service_role client.
  
  -- 1. If purchase_context_id is provided, validate it
  IF p_purchase_context_id IS NOT NULL THEN
    SELECT user_id, business_account_id, consumed_at, expires_at
    INTO v_context_user_id, v_context_business_id, v_context_consumed, v_context_expires
    FROM public.business_plus_purchase_contexts
    WHERE id = p_purchase_context_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid_purchase_context';
    END IF;

    IF v_context_consumed IS NOT NULL THEN
      RAISE EXCEPTION 'purchase_context_already_consumed';
    END IF;

    IF v_context_expires < now() THEN
      RAISE EXCEPTION 'purchase_context_expired';
    END IF;

    IF v_context_user_id <> p_owner_user_id THEN
      RAISE EXCEPTION 'purchase_context_user_mismatch';
    END IF;

    IF v_context_business_id <> p_business_account_id THEN
      RAISE EXCEPTION 'purchase_context_business_mismatch';
    END IF;
  END IF;

  -- 2. Check for duplicate binding: another business using the same store external token/transaction
  IF EXISTS (
    SELECT 1 FROM public.business_plus_subscriptions
    WHERE store = p_store
      AND external_purchase_identity_hash = p_external_purchase_identity_hash
      AND business_account_id <> p_business_account_id
  ) THEN
    RAISE EXCEPTION 'purchase_already_linked_to_another_business';
  END IF;

  -- 3. Upsert subscription record
  INSERT INTO public.business_plus_subscriptions (
    business_account_id,
    owner_user_id,
    store,
    product_id,
    base_plan_id,
    original_transaction_id,
    external_purchase_identity_hash,
    store_subscription_status,
    entitlement_status,
    purchase_time,
    current_period_start,
    current_period_end,
    auto_renew_enabled,
    cancellation_time,
    grace_period_end,
    revocation_time,
    environment,
    starts_at,
    ends_at,
    status,
    latest_verification_time,
    updated_at
  )
  VALUES (
    p_business_account_id,
    p_owner_user_id,
    p_store,
    p_product_id,
    p_base_plan_id,
    p_original_transaction_id,
    p_external_purchase_identity_hash,
    p_store_subscription_status,
    p_entitlement_status,
    p_purchase_time,
    p_current_period_start,
    p_current_period_end,
    p_auto_renew_enabled,
    p_cancellation_time,
    p_grace_period_end,
    p_revocation_time,
    p_environment,
    COALESCE(p_current_period_start, now()),
    COALESCE(p_grace_period_end, p_current_period_end),
    CASE 
      WHEN p_entitlement_status IN ('active', 'grace_period') THEN 'active'
      WHEN p_entitlement_status = 'cancelled' THEN 'cancelled'
      ELSE 'expired'
    END,
    now(),
    now()
  )
  ON CONFLICT (store, external_purchase_identity_hash) DO UPDATE
  SET
    store_subscription_status = EXCLUDED.store_subscription_status,
    entitlement_status = EXCLUDED.entitlement_status,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    auto_renew_enabled = EXCLUDED.auto_renew_enabled,
    cancellation_time = EXCLUDED.cancellation_time,
    grace_period_end = EXCLUDED.grace_period_end,
    revocation_time = EXCLUDED.revocation_time,
    ends_at = EXCLUDED.ends_at,
    status = EXCLUDED.status,
    latest_verification_time = now(),
    updated_at = now()
  RETURNING id INTO v_subscription_id;

  -- 4. Insert raw proof details securely in private schema
  INSERT INTO private.business_plus_subscription_proofs (
    subscription_id,
    purchase_token,
    raw_payload,
    app_account_token,
    obfuscated_account_id,
    updated_at
  )
  VALUES (
    v_subscription_id,
    p_purchase_token,
    p_raw_payload,
    CASE WHEN p_store = 'app_store' AND p_purchase_context_id IS NOT NULL THEN p_purchase_context_id ELSE NULL END,
    CASE WHEN p_store = 'google_play' AND p_purchase_context_id IS NOT NULL THEN p_purchase_context_id::text ELSE NULL END,
    now()
  )
  ON CONFLICT (subscription_id) DO UPDATE
  SET
    purchase_token = EXCLUDED.purchase_token,
    raw_payload = EXCLUDED.raw_payload,
    app_account_token = EXCLUDED.app_account_token,
    obfuscated_account_id = EXCLUDED.obfuscated_account_id,
    updated_at = now();

  -- 5. If purchase context exists, mark it as consumed
  IF p_purchase_context_id IS NOT NULL THEN
    UPDATE public.business_plus_purchase_contexts
    SET consumed_at = now()
    WHERE id = p_purchase_context_id;
  END IF;

  -- 6. Trigger is_plus_active cache sync
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  RETURN v_subscription_id;
END;
$$;

REVOKE ALL ON FUNCTION public.service_verify_and_upsert_subscription(
  uuid, uuid, text, text, text, text, text, text, text, timestamptz, timestamptz, timestamptz, boolean, timestamptz, timestamptz, timestamptz, text, uuid, text, jsonb
) FROM public, authenticated, anon;

-- 11. Create secure helper to retrieve subscription ID by purchase token
CREATE OR REPLACE FUNCTION public.query_subscription_id_by_token(p_purchase_token text)
RETURNS TABLE (subscription_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Restrict execution to server-role queries
  RETURN QUERY
  SELECT bps.subscription_id
  FROM private.business_plus_subscription_proofs bps
  WHERE bps.purchase_token = p_purchase_token;
END;
$$;

REVOKE ALL ON FUNCTION public.query_subscription_id_by_token(text) FROM public, authenticated, anon;

-- Re-sync cache values
SELECT public.reconcile_all_business_plus_cache();

NOTIFY pgrst, 'reload schema';
