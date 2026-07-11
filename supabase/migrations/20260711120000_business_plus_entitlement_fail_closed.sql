-- Business Plus store entitlement verification must fail closed.
-- Store state is authoritative; caller-provided entitlement status is retained
-- in the RPC signature only for Edge Function compatibility.

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.business_plus_platform_for_store(p_store text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
  SELECT CASE p_store
    WHEN 'google_play' THEN 'android'
    WHEN 'app_store' THEN 'ios'
    ELSE NULL
  END;
$$;

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
      AND subscription.starts_at <= now()
      AND subscription.revocation_time IS NULL
      AND (
        (
          subscription.store IN ('google_play', 'app_store')
          AND subscription.entitlement_status IN ('active', 'cancelled', 'grace_period')
          AND subscription.ends_at IS NOT NULL
          AND subscription.ends_at > now()
        )
        OR
        (
          subscription.store = 'manual_admin'
          AND subscription.entitlement_status IN ('active', 'grace_period')
          AND (subscription.ends_at IS NULL OR subscription.ends_at > now())
        )
      )
  );
END;
$$;

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
  v_existing_business_id uuid;
  v_existing_owner_id uuid;
  v_context_user_id uuid;
  v_context_business_id uuid;
  v_context_consumed timestamptz;
  v_context_expires timestamptz;
  v_context_platform text;
  v_context_product_id text;
  v_platform text;
  v_store_state text;
  v_verified_expiry timestamptz;
  v_entitlement_status text;
  v_status text;
BEGIN
  v_platform := private.business_plus_platform_for_store(p_store);
  IF v_platform IS NULL THEN
    RAISE EXCEPTION 'unsupported_subscription_store';
  END IF;

  IF p_business_account_id IS NULL
     OR p_owner_user_id IS NULL
     OR p_product_id IS NULL
     OR btrim(p_product_id) = ''
     OR p_external_purchase_identity_hash IS NULL
     OR btrim(p_external_purchase_identity_hash) = '' THEN
    RAISE EXCEPTION 'invalid_subscription_binding';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.business_accounts account
    WHERE account.id = p_business_account_id
      AND account.owner_user_id = p_owner_user_id
      AND account.status = 'active'
  ) THEN
    RAISE EXCEPTION 'business_owner_mismatch';
  END IF;

  IF p_purchase_context_id IS NOT NULL THEN
    SELECT user_id, business_account_id, consumed_at, expires_at, platform, product_id
    INTO v_context_user_id, v_context_business_id, v_context_consumed,
         v_context_expires, v_context_platform, v_context_product_id
    FROM public.business_plus_purchase_contexts
    WHERE id = p_purchase_context_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid_purchase_context';
    END IF;
    IF v_context_consumed IS NOT NULL THEN
      RAISE EXCEPTION 'purchase_context_already_consumed';
    END IF;
    IF v_context_expires IS NULL OR v_context_expires <= now() THEN
      RAISE EXCEPTION 'purchase_context_expired';
    END IF;
    IF v_context_user_id IS DISTINCT FROM p_owner_user_id THEN
      RAISE EXCEPTION 'purchase_context_user_mismatch';
    END IF;
    IF v_context_business_id IS DISTINCT FROM p_business_account_id THEN
      RAISE EXCEPTION 'purchase_context_business_mismatch';
    END IF;
    IF v_context_platform IS DISTINCT FROM v_platform
       OR v_context_product_id IS DISTINCT FROM p_product_id THEN
      RAISE EXCEPTION 'purchase_context_platform_product_mismatch';
    END IF;
  END IF;

  SELECT subscription.business_account_id, subscription.owner_user_id
  INTO v_existing_business_id, v_existing_owner_id
  FROM public.business_plus_subscriptions subscription
  WHERE subscription.store = p_store
    AND subscription.external_purchase_identity_hash = p_external_purchase_identity_hash
  FOR UPDATE;

  IF FOUND AND (
    v_existing_business_id IS DISTINCT FROM p_business_account_id
    OR v_existing_owner_id IS DISTINCT FROM p_owner_user_id
  ) THEN
    RAISE EXCEPTION 'purchase_already_linked_to_another_owner';
  END IF;

  v_store_state := upper(btrim(COALESCE(p_store_subscription_status, '')));
  v_verified_expiry := CASE
    WHEN v_store_state = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
      THEN COALESCE(p_grace_period_end, p_current_period_end)
    ELSE p_current_period_end
  END;

  v_entitlement_status := CASE
    WHEN p_revocation_time IS NOT NULL OR v_store_state = 'SUBSCRIPTION_STATE_REVOKED'
      THEN 'revoked'
    WHEN v_store_state = 'SUBSCRIPTION_STATE_ACTIVE'
      AND v_verified_expiry IS NOT NULL AND v_verified_expiry > now()
      THEN 'active'
    WHEN v_store_state = 'SUBSCRIPTION_STATE_CANCELED'
      AND v_verified_expiry IS NOT NULL AND v_verified_expiry > now()
      THEN 'cancelled'
    WHEN v_store_state = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
      AND v_verified_expiry IS NOT NULL AND v_verified_expiry > now()
      THEN 'grace_period'
    WHEN v_store_state = 'SUBSCRIPTION_STATE_ON_HOLD' THEN 'billing_retry'
    WHEN v_store_state = 'SUBSCRIPTION_STATE_PAUSED' THEN 'paused'
    ELSE 'expired'
  END;

  v_status := CASE
    WHEN v_entitlement_status IN ('active', 'cancelled', 'grace_period') THEN 'active'
    ELSE 'expired'
  END;

  v_subscription_id := NULL;

  INSERT INTO public.business_plus_subscriptions (
    business_account_id, owner_user_id, store, product_id, base_plan_id,
    original_transaction_id, external_purchase_identity_hash,
    store_subscription_status, entitlement_status, purchase_time,
    current_period_start, current_period_end, auto_renew_enabled,
    cancellation_time, grace_period_end, revocation_time, environment,
    starts_at, ends_at, status, latest_verification_time, updated_at,
    price_amount_minor, price_currency
  ) VALUES (
    p_business_account_id, p_owner_user_id, p_store, p_product_id, p_base_plan_id,
    p_original_transaction_id, p_external_purchase_identity_hash,
    p_store_subscription_status, v_entitlement_status, p_purchase_time,
    p_current_period_start, p_current_period_end,
    CASE WHEN v_store_state = 'SUBSCRIPTION_STATE_CANCELED' THEN false
         ELSE COALESCE(p_auto_renew_enabled, false) END,
    p_cancellation_time, p_grace_period_end, p_revocation_time, p_environment,
    COALESCE(p_current_period_start, now()), v_verified_expiry, v_status,
    now(), now(), 100000, 'TRY'
  )
  ON CONFLICT (store, external_purchase_identity_hash) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    base_plan_id = EXCLUDED.base_plan_id,
    original_transaction_id = EXCLUDED.original_transaction_id,
    store_subscription_status = EXCLUDED.store_subscription_status,
    entitlement_status = EXCLUDED.entitlement_status,
    purchase_time = EXCLUDED.purchase_time,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    auto_renew_enabled = EXCLUDED.auto_renew_enabled,
    cancellation_time = EXCLUDED.cancellation_time,
    grace_period_end = EXCLUDED.grace_period_end,
    revocation_time = EXCLUDED.revocation_time,
    environment = EXCLUDED.environment,
    starts_at = EXCLUDED.starts_at,
    ends_at = EXCLUDED.ends_at,
    status = EXCLUDED.status,
    latest_verification_time = now(),
    updated_at = now()
  WHERE business_plus_subscriptions.business_account_id = EXCLUDED.business_account_id
    AND business_plus_subscriptions.owner_user_id IS NOT DISTINCT FROM EXCLUDED.owner_user_id
  RETURNING id INTO v_subscription_id;

  IF v_subscription_id IS NULL THEN
    RAISE EXCEPTION 'purchase_already_linked_to_another_owner';
  END IF;

  INSERT INTO private.business_plus_subscription_proofs (
    subscription_id, purchase_token, raw_payload, app_account_token,
    obfuscated_account_id, updated_at
  ) VALUES (
    v_subscription_id, p_purchase_token, p_raw_payload,
    CASE WHEN p_store = 'app_store' AND p_purchase_context_id IS NOT NULL
      THEN p_purchase_context_id ELSE NULL END,
    CASE WHEN p_store = 'google_play' AND p_purchase_context_id IS NOT NULL
      THEN p_purchase_context_id::text ELSE NULL END,
    now()
  )
  ON CONFLICT (subscription_id) DO UPDATE SET
    purchase_token = EXCLUDED.purchase_token,
    raw_payload = EXCLUDED.raw_payload,
    app_account_token = EXCLUDED.app_account_token,
    obfuscated_account_id = EXCLUDED.obfuscated_account_id,
    updated_at = now();

  IF p_purchase_context_id IS NOT NULL THEN
    UPDATE public.business_plus_purchase_contexts
    SET consumed_at = now()
    WHERE id = p_purchase_context_id;
  END IF;

  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  RETURN v_subscription_id;
END;
$$;

UPDATE public.business_plus_subscriptions
SET status = 'active',
    auto_renew_enabled = false,
    updated_at = now()
WHERE store IN ('google_play', 'app_store')
  AND entitlement_status = 'cancelled'
  AND ends_at IS NOT NULL
  AND ends_at > now()
  AND revocation_time IS NULL
  AND status IS DISTINCT FROM 'active';

UPDATE public.business_accounts account
SET is_plus_active = public.check_business_plus_active(account.id)
WHERE account.is_plus_active IS DISTINCT FROM
  public.check_business_plus_active(account.id);

REVOKE ALL ON FUNCTION private.business_plus_platform_for_store(text)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.check_business_plus_active(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_business_plus_active(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.service_verify_and_upsert_subscription(
  uuid, uuid, text, text, text, text, text, text, text, timestamptz,
  timestamptz, timestamptz, boolean, timestamptz, timestamptz, timestamptz,
  text, uuid, text, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_verify_and_upsert_subscription(
  uuid, uuid, text, text, text, text, text, text, text, timestamptz,
  timestamptz, timestamptz, boolean, timestamptz, timestamptz, timestamptz,
  text, uuid, text, jsonb
) TO service_role;

NOTIFY pgrst, 'reload schema';
