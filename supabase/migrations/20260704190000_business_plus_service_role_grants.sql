-- Grant service_role the narrow permissions needed by Business Plus backend verification.

GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT ON TABLE public.business_accounts TO service_role;

GRANT SELECT, INSERT, UPDATE
ON TABLE public.business_plus_subscriptions
TO service_role;

GRANT SELECT, INSERT, UPDATE
ON TABLE public.business_plus_purchase_contexts
TO service_role;

GRANT EXECUTE ON FUNCTION public.service_verify_and_upsert_subscription(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  boolean,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  uuid,
  text,
  jsonb
) TO service_role;

GRANT EXECUTE ON FUNCTION public.query_subscription_id_by_token(text)
TO service_role;

GRANT USAGE ON SCHEMA private TO service_role;

GRANT SELECT, INSERT, UPDATE
ON TABLE private.business_plus_subscription_proofs
TO service_role;

GRANT SELECT, INSERT, UPDATE
ON TABLE private.processed_webhook_notifications
TO service_role;
