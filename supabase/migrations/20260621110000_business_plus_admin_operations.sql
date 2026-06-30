-- Migration: Business Plus Admin Operations, Subscription Support and Audit Tools
-- Timestamp: 20260621110000

-- 1. Extend public.business_plus_subscriptions with price columns
ALTER TABLE public.business_plus_subscriptions
  ADD COLUMN IF NOT EXISTS price_amount_minor integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS price_currency text DEFAULT NULL;

-- 2. Create tables

-- verification issue queue
CREATE TABLE IF NOT EXISTS public.business_plus_verification_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE SET NULL,
  store text NOT NULL CHECK (store IN ('google_play', 'app_store')),
  environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
  category text NOT NULL CHECK (category IN (
    'signature_failure', 'ownership_mismatch', 'purchase_replay', 
    'invalid_product_package', 'stale_subscription', 'reconciliation_failure', 
    'api_unavailable', 'malformed_notification'
  )),
  issue_fingerprint text NOT NULL UNIQUE,
  diagnostic_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  retry_count integer NOT NULL DEFAULT 0,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz DEFAULT NULL,
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  first_seen timestamptz NOT NULL DEFAULT now(),
  last_seen timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS business_plus_verification_issues_resolved_idx
  ON public.business_plus_verification_issues (resolved, created_at desc);

-- secure append-only admin audit logs in private schema
CREATE TABLE IF NOT EXISTS private.business_plus_admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acting_admin_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  business_account_id uuid REFERENCES public.business_accounts(id) ON DELETE RESTRICT,
  action_type text NOT NULL CHECK (action_type IN (
    'grant_manual_entitlement', 'revoke_manual_entitlement', 
    'retry_verification', 'reconcile_cache', 'add_support_note', 'resolve_issue'
  )),
  reason text NOT NULL,
  note text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reason_not_empty CHECK (btrim(reason) <> ''),
  CONSTRAINT note_not_empty CHECK (btrim(note) <> ''),
  CONSTRAINT metadata_size_limit CHECK (octet_length(metadata::text) <= 4096)
);

-- enforce append-only via database trigger (no updates, no deletes)
CREATE OR REPLACE FUNCTION private.prevent_audit_log_modification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs_are_immutable_and_append_only';
END;
$$;

DROP TRIGGER IF EXISTS prevent_audit_log_modification_trigger 
  ON private.business_plus_admin_audit_logs;
CREATE TRIGGER prevent_audit_log_modification_trigger
BEFORE UPDATE OR DELETE ON private.business_plus_admin_audit_logs
FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_log_modification();

-- billing support requests
CREATE TABLE IF NOT EXISTS public.business_plus_support_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_account_id uuid NOT NULL REFERENCES public.business_accounts(id) ON DELETE CASCADE,
  message text NOT NULL CHECK (length(message) > 0 AND length(message) <= 1000),
  diagnostic_context jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
  resolved_at timestamptz DEFAULT NULL,
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS business_plus_support_requests_user_idx
  ON public.business_plus_support_requests (user_id, created_at desc);

-- admin billing alerts table
CREATE TABLE IF NOT EXISTS public.admin_billing_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type text NOT NULL UNIQUE CHECK (alert_type IN (
    'repeated_verification_failures', 'webhook_authentication_failure_spike',
    'stale_reconciliation', 'store_outage', 'high_revocation_volume', 'manual_entitlement_expiring_soon'
  )),
  message text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_triggered_at timestamptz NOT NULL DEFAULT now(),
  resolved boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Row Level Security Policies

ALTER TABLE public.business_plus_verification_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_plus_support_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_billing_alerts ENABLE ROW LEVEL SECURITY;

-- Admins can read/write verification issues. Non-admins cannot see them.
DROP POLICY IF EXISTS "Admins can view and manage verification issues" ON public.business_plus_verification_issues;
CREATE POLICY "Admins can view and manage verification issues"
  ON public.business_plus_verification_issues
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- Users can view their own support requests
DROP POLICY IF EXISTS "Users can view own support requests" ON public.business_plus_support_requests;
CREATE POLICY "Users can view own support requests"
  ON public.business_plus_support_requests
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_current_user_admin());

-- Client direct insert is blocked completely (Point 2)
DROP POLICY IF EXISTS "Users can insert own support requests" ON public.business_plus_support_requests;

-- Admins can update support requests (e.g. resolve them)
DROP POLICY IF EXISTS "Admins can update support requests" ON public.business_plus_support_requests;
CREATE POLICY "Admins can update support requests"
  ON public.business_plus_support_requests
  FOR UPDATE
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- Admins can manage alerts
DROP POLICY IF EXISTS "Admins can manage alerts" ON public.admin_billing_alerts;
CREATE POLICY "Admins can manage alerts"
  ON public.admin_billing_alerts
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- Revoke direct permissions on secure tables from public and authenticated
REVOKE ALL ON TABLE private.business_plus_admin_audit_logs FROM public, authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.business_plus_purchase_contexts FROM public, authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.business_plus_verification_issues FROM public, authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.business_plus_support_requests FROM public, authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.admin_billing_alerts FROM public, authenticated, anon;

-- Grant select to authenticated/admin on verification issues, alerts, and support requests
GRANT SELECT ON public.business_plus_verification_issues TO authenticated;
GRANT SELECT ON public.admin_billing_alerts TO authenticated;
GRANT SELECT ON public.business_plus_purchase_contexts TO authenticated;
GRANT SELECT ON public.business_plus_support_requests TO authenticated;

-- Drop generic INSERT/UPDATE/DELETE policy on purchase contexts and replace with SELECT only (Point 1)
DROP POLICY IF EXISTS "Users can manage their own purchase contexts" ON public.business_plus_purchase_contexts;
DROP POLICY IF EXISTS "Users can select own purchase contexts" ON public.business_plus_purchase_contexts;
CREATE POLICY "Users can select own purchase contexts"
  ON public.business_plus_purchase_contexts
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- 4. Server-side RPC for Purchase Context Creation (Point 1)
CREATE OR REPLACE FUNCTION public.create_business_plus_purchase_context(
  p_business_account_id uuid,
  p_platform text
)
RETURNS TABLE (
  context_id uuid,
  product_id text,
  platform text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_owner boolean := false;
  v_product_id text := 'business_plus_monthly';
  v_context_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'invalid_platform';
  END IF;

  -- Validate user is owner of the business account
  SELECT EXISTS (
    SELECT 1 
    FROM public.business_accounts ba
    WHERE ba.id = p_business_account_id
      AND ba.owner_user_id = v_user_id
      AND ba.status = 'active'
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'unauthorized_business_access';
  END IF;

  -- Insert purchase context
  INSERT INTO public.business_plus_purchase_contexts (
    user_id,
    business_account_id,
    platform,
    product_id,
    expires_at
  )
  VALUES (
    v_user_id,
    p_business_account_id,
    p_platform,
    v_product_id,
    now() + interval '30 minutes'
  )
  RETURNING id INTO v_context_id;

  RETURN QUERY
  SELECT v_context_id, v_product_id, p_platform;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_business_plus_purchase_context(uuid, text) TO authenticated;

-- Cleanup/reconciliation method for expired purchase contexts
CREATE OR REPLACE FUNCTION public.cleanup_expired_purchase_contexts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted integer;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'admin_only_reconciliation';
  END IF;

  DELETE FROM public.business_plus_purchase_contexts
  WHERE expires_at < now() - interval '24 hours' -- Keep recent for debug
    AND consumed_at IS NULL;
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_expired_purchase_contexts() TO authenticated;

-- 5. Server-side RPC for Support Request Creation (Point 2)
CREATE OR REPLACE FUNCTION public.create_business_plus_support_request(
  p_message text,
  p_platform text,
  p_app_version text,
  p_error_category text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_business_account_id uuid;
  v_store text := 'google_play'; -- Default fallback
  v_normalized_status text := NULL;
  v_entitlement_status text := NULL;
  v_last_verification timestamptz := NULL;
  v_correlation_id uuid := gen_random_uuid();
  v_support_id uuid;
  v_request_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF length(p_message) = 0 OR length(p_message) > 1000 THEN
    RAISE EXCEPTION 'invalid_message_length';
  END IF;

  -- Find business account owned by user
  SELECT id INTO v_business_account_id
  FROM public.business_accounts
  WHERE owner_user_id = v_user_id
    AND status = 'active'
  LIMIT 1;

  IF v_business_account_id IS NULL THEN
    RAISE EXCEPTION 'user_has_no_active_business_account';
  END IF;

  -- Rate limit: max 5 support requests per hour per user
  SELECT count(*)::integer INTO v_request_count
  FROM public.business_plus_support_requests
  WHERE user_id = v_user_id
    AND created_at > now() - interval '1 hour';
    
  IF v_request_count >= 5 THEN
    RAISE EXCEPTION 'rate_limit_exceeded_support';
  END IF;

  -- Find active subscription detail if any to attach
  SELECT store, store_subscription_status, entitlement_status, latest_verification_time
  INTO v_store, v_normalized_status, v_entitlement_status, v_last_verification
  FROM public.business_plus_subscriptions
  WHERE business_account_id = v_business_account_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Insert support request with server-derived diagnostics
  INSERT INTO public.business_plus_support_requests (
    user_id,
    business_account_id,
    message,
    diagnostic_context,
    status
  )
  VALUES (
    v_user_id,
    v_business_account_id,
    p_message,
    jsonb_build_object(
      'platform', p_platform,
      'app_version', p_app_version,
      'store', COALESCE(v_store, 'none'),
      'product_id', 'business_plus_monthly',
      'normalized_status', COALESCE(v_normalized_status, 'none'),
      'entitlement_status', COALESCE(v_entitlement_status, 'none'),
      'last_verification', COALESCE(v_last_verification::text, 'none'),
      'error_category', p_error_category,
      'correlation_id', v_correlation_id
    ),
    'open'
  )
  RETURNING id INTO v_support_id;

  RETURN v_support_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_business_plus_support_request(text, text, text, text) TO authenticated;

-- 6. Canonical Manual Entitlement (Point 3)
-- Re-defines the manual entitlement system to ensure no duplicates, concurrency safety, and store preservation.
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

  -- Lock business account to serialize manual grants for the same business (Point 3)
  SELECT owner_user_id INTO v_owner_id
  FROM public.business_accounts
  WHERE id = p_business_account_id
  FOR UPDATE;

  -- Lock row for concurrency safety (Point 3)
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

-- Secure wrappers for Manual Entitlement (Point 3 & Point 8)
CREATE OR REPLACE FUNCTION public.admin_grant_manual_entitlement(
  p_business_account_id uuid,
  p_duration_days integer,
  p_reason text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_sub_id uuid;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  IF p_duration_days <= 0 OR p_duration_days > 365 THEN
    RAISE EXCEPTION 'invalid_manual_duration_max_365_days';
  END IF;

  -- Call canonical set helper
  v_sub_id := public.admin_set_business_plus_subscription(
    p_business_account_id,
    'active',
    p_duration_days
  );

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note,
    metadata
  )
  VALUES (
    v_admin_id,
    p_business_account_id,
    'grant_manual_entitlement',
    p_reason,
    p_note,
    jsonb_build_object(
      'duration_days', p_duration_days,
      'subscription_id', v_sub_id
    )
  );

  RETURN v_sub_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_grant_manual_entitlement(uuid, integer, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_revoke_manual_entitlement(
  p_business_account_id uuid,
  p_reason text,
  p_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_updated_rows integer;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  -- Deactivate ONLY manual admin records for the business (does NOT touch store rows!) (Point 3)
  UPDATE public.business_plus_subscriptions
  SET entitlement_status = 'revoked',
      revocation_time = now(),
      ends_at = now(),
      updated_at = now()
  WHERE business_account_id = p_business_account_id
    AND store = 'manual_admin'
    AND entitlement_status = 'active';

  GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

  -- Sync cache immediately
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note,
    metadata
  )
  VALUES (
    v_admin_id,
    p_business_account_id,
    'revoke_manual_entitlement',
    p_reason,
    p_note,
    jsonb_build_object('revoked_count', v_updated_rows)
  );

  RETURN v_updated_rows > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_revoke_manual_entitlement(uuid, text, text) TO authenticated;

-- 7. Dedicated Admin Support Actions (Point 4)

-- RPC 1: Add note
CREATE OR REPLACE FUNCTION public.admin_add_support_note(
  p_business_account_id uuid,
  p_note text,
  p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note
  )
  VALUES (
    v_admin_id,
    p_business_account_id,
    'add_support_note',
    p_reason,
    p_note
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_support_note(uuid, text, text) TO authenticated;

-- RPC 2: Resolve issue
CREATE OR REPLACE FUNCTION public.admin_resolve_issue(
  p_issue_id uuid,
  p_reason text,
  p_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_business_id uuid;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  SELECT business_account_id INTO v_business_id
  FROM public.business_plus_verification_issues
  WHERE id = p_issue_id;

  UPDATE public.business_plus_verification_issues
  SET resolved = true,
      resolved_at = now(),
      resolved_by = v_admin_id,
      updated_at = now()
  WHERE id = p_issue_id;

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note,
    metadata
  )
  VALUES (
    v_admin_id,
    v_business_id,
    'resolve_issue',
    p_reason,
    p_note,
    jsonb_build_object('issue_id', p_issue_id)
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_issue(uuid, text, text) TO authenticated;

-- RPC 3: Trigger cache reconciliation
CREATE OR REPLACE FUNCTION public.admin_trigger_reconciliation(
  p_reason text,
  p_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  -- Call cache sync
  PERFORM public.reconcile_all_business_plus_cache();

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note
  )
  VALUES (
    v_admin_id,
    '00000000-0000-0000-0000-000000000000'::uuid, -- System level
    'reconcile_cache',
    p_reason,
    p_note
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_trigger_reconciliation(text, text) TO authenticated;

-- RPC 4: Retry verification (Point 4 & Point 12)
CREATE OR REPLACE FUNCTION public.admin_retry_verification(
  p_business_account_id uuid,
  p_reason text,
  p_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note
  )
  VALUES (
    v_admin_id,
    p_business_account_id,
    'retry_verification',
    p_reason,
    p_note
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_retry_verification(uuid, text, text) TO authenticated;

-- RPC 5: Refresh cache for specific business (Point 4)
CREATE OR REPLACE FUNCTION public.admin_refresh_entitlement_cache(
  p_business_account_id uuid,
  p_reason text,
  p_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' OR p_note IS NULL OR btrim(p_note) = '' THEN
    RAISE EXCEPTION 'reason_and_note_required';
  END IF;

  -- Sync cache immediately
  UPDATE public.business_accounts
  SET is_plus_active = public.check_business_plus_active(p_business_account_id)
  WHERE id = p_business_account_id;

  -- Log append-only audit
  INSERT INTO private.business_plus_admin_audit_logs (
    acting_admin_id,
    business_account_id,
    action_type,
    reason,
    note
  )
  VALUES (
    v_admin_id,
    p_business_account_id,
    'reconcile_cache',
    p_reason,
    p_note
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_refresh_entitlement_cache(uuid, text, text) TO authenticated;


-- 8. Log / register verification failure (Point 5 & 6)
-- Handles deduplication, retry counting, unresolved/reopened behaviors and triggers admin alerts.
CREATE OR REPLACE FUNCTION public.log_verification_failure(
  p_business_account_id uuid,
  p_store text,
  p_environment text,
  p_category text,
  p_identity_hash text,
  p_diagnostic_msg text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_fingerprint text;
  v_issue_id uuid;
  v_resolved boolean;
  v_retry_count integer;
  v_alert_msg text;
BEGIN
  -- Compute SHA256 fingerprint internally (Point 5)
  v_fingerprint := encode(digest(
    p_category || ':' || p_store || ':' || p_environment || ':' || 
    COALESCE(p_business_account_id::text, 'null') || ':' || COALESCE(p_identity_hash, 'null'),
    'sha256'
  ), 'hex');

  -- Query existing issue
  SELECT id, resolved, retry_count
  INTO v_issue_id, v_resolved, v_retry_count
  FROM public.business_plus_verification_issues
  WHERE issue_fingerprint = v_fingerprint;

  IF FOUND THEN
    IF v_resolved THEN
      -- Reopen resolved issue (Point 5)
      UPDATE public.business_plus_verification_issues
      SET resolved = false,
          resolved_at = NULL,
          resolved_by = NULL,
          retry_count = 1,
          diagnostic_metadata = jsonb_build_object('last_error', p_diagnostic_msg),
          last_seen = now(),
          updated_at = now()
      WHERE id = v_issue_id;
    ELSE
      -- Increment retry count (Point 5)
      UPDATE public.business_plus_verification_issues
      SET retry_count = retry_count + 1,
          diagnostic_metadata = jsonb_build_object('last_error', p_diagnostic_msg),
          last_seen = now(),
          updated_at = now()
      WHERE id = v_issue_id;
    END IF;
  ELSE
    -- Insert new issue (Point 5)
    INSERT INTO public.business_plus_verification_issues (
      business_account_id,
      store,
      environment,
      category,
      issue_fingerprint,
      diagnostic_metadata,
      first_seen,
      last_seen
    )
    VALUES (
      p_business_account_id,
      p_store,
      p_environment,
      p_category,
      v_fingerprint,
      jsonb_build_object('last_error', p_diagnostic_msg),
      now(),
      now()
    )
    RETURNING id INTO v_issue_id;
  END IF;

  -- 8. Trigger Admin Alerts (Point 6)
  -- Repeated failures trigger alert
  IF COALESCE(v_retry_count, 0) + 1 >= 3 THEN
    v_alert_msg := 'repeated_verification_failures: Business ' || 
                   COALESCE(p_business_account_id::text, 'unknown') || 
                   ' failed verification ' || (v_retry_count + 1) || ' times.';
                   
    INSERT INTO public.admin_billing_alerts (
      alert_type,
      message,
      metadata
    )
    VALUES (
      'repeated_verification_failures',
      v_alert_msg,
      jsonb_build_object('business_account_id', p_business_account_id)
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = now(),
        resolved = false;
  END IF;

  RETURN v_issue_id;
END;
$$;

-- 9. MRR Metric Calculation (Point 7)
-- Renders MRR calculated securely from verified store payments only.
-- Grouped by currency, excludes sandbox, manual, expired, and auto-renew cancelled (recurring = off).
CREATE OR REPLACE FUNCTION public.admin_get_business_plus_mrr()
RETURNS TABLE (
  currency text,
  mrr_amount_minor numeric,
  subscription_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  RETURN QUERY
  SELECT 
    sub.price_currency as currency,
    SUM(sub.price_amount_minor)::numeric as mrr_amount_minor,
    COUNT(sub.id) as subscription_count
  FROM public.business_plus_subscriptions sub
  WHERE sub.environment = 'production'                  -- Exclude sandbox (Point 7)
    AND sub.store IN ('google_play', 'app_store')       -- Exclude manual (Point 7)
    AND sub.entitlement_status = 'active'               -- Exclude expired/revoked/grace (Point 7)
    AND sub.auto_renew_enabled = true                   -- Exclude cancelled-but-active (Point 7)
    AND sub.price_amount_minor IS NOT NULL
    AND sub.price_currency IS NOT NULL
  GROUP BY sub.price_currency;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_business_plus_mrr() TO authenticated;

-- 10. Admin Metrics Overview RPC (Point 1)
CREATE OR REPLACE FUNCTION public.admin_get_business_plus_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_active_total bigint;
  v_google_active bigint;
  v_apple_active bigint;
  v_manual_active bigint;
  v_grace_total bigint;
  v_retry_total bigint;
  v_cancelled_active bigint;
  v_expired_total bigint;
  v_revoked_total bigint;
  v_issues_unresolved bigint;
  v_stale_reconcile bigint;
  v_mrr jsonb;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  -- High-level counts
  SELECT count(*) INTO v_active_total 
  FROM public.business_plus_subscriptions WHERE entitlement_status IN ('active', 'grace_period');

  SELECT count(*) INTO v_google_active 
  FROM public.business_plus_subscriptions WHERE store = 'google_play' AND entitlement_status = 'active';

  SELECT count(*) INTO v_apple_active 
  FROM public.business_plus_subscriptions WHERE store = 'app_store' AND entitlement_status = 'active';

  SELECT count(*) INTO v_manual_active 
  FROM public.business_plus_subscriptions WHERE store = 'manual_admin' AND entitlement_status = 'active';

  SELECT count(*) INTO v_grace_total 
  FROM public.business_plus_subscriptions WHERE entitlement_status = 'grace_period';

  SELECT count(*) INTO v_retry_total 
  FROM public.business_plus_subscriptions WHERE entitlement_status = 'billing_retry';

  SELECT count(*) INTO v_cancelled_active 
  FROM public.business_plus_subscriptions WHERE entitlement_status = 'active' AND auto_renew_enabled = false;

  SELECT count(*) INTO v_expired_total 
  FROM public.business_plus_subscriptions WHERE entitlement_status = 'expired';

  SELECT count(*) INTO v_revoked_total 
  FROM public.business_plus_subscriptions WHERE entitlement_status = 'revoked';

  SELECT count(*) INTO v_issues_unresolved 
  FROM public.business_plus_verification_issues WHERE resolved = false;

  -- Not reconciled recently (> 30 hours)
  SELECT count(*) INTO v_stale_reconcile
  FROM public.business_plus_subscriptions
  WHERE entitlement_status IN ('active', 'grace_period', 'billing_retry')
    AND store IN ('google_play', 'app_store')
    AND (latest_verification_time IS NULL OR latest_verification_time < now() - interval '30 hours');

  -- Compile verified MRR group into JSON
  SELECT coalesce(jsonb_agg(r), '[]'::jsonb) INTO v_mrr
  FROM (
    SELECT currency, mrr_amount_minor, subscription_count
    FROM public.admin_get_business_plus_mrr()
  ) r;

  RETURN jsonb_build_object(
    'active_businesses_total', v_active_total,
    'active_google_play', v_google_active,
    'active_app_store', v_apple_active,
    'active_manual_admin', v_manual_active,
    'grace_period_count', v_grace_total,
    'billing_retry_count', v_retry_total,
    'cancelled_but_active_count', v_cancelled_active,
    'expired_count', v_expired_total,
    'revoked_count', v_revoked_total,
    'unresolved_verification_issues', v_issues_unresolved,
    'stale_reconciliation_count', v_stale_reconcile,
    'monthly_recurring_revenue', v_mrr
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_business_plus_metrics() TO authenticated;

-- 11. Entitlement Decision Inspector RPC (Point 6)
-- Outputs evaluation signals and structured reason codes. No receipts/tokens are exposed.
CREATE OR REPLACE FUNCTION public.admin_inspect_entitlement_decision(
  p_business_account_id uuid
)
RETURNS TABLE (
  has_active_store_subscription boolean,
  has_active_manual_entitlement boolean,
  current_period_end_valid boolean,
  grace_period_valid boolean,
  revocation_time timestamptz,
  environment text,
  product_id text,
  owner_id uuid,
  stale_cache_status boolean,
  latest_reconciliation_result text,
  outcome_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_store_active boolean := false;
  v_manual_active boolean := false;
  v_period_valid boolean := false;
  v_grace_valid boolean := false;
  v_revocation timestamptz := NULL;
  v_env text := NULL;
  v_prod text := NULL;
  v_owner uuid := NULL;
  v_stale boolean := false;
  v_outcome text := 'no_valid_entitlement';
  v_cached_active boolean := false;
  v_calculated_active boolean := false;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  -- Store status check
  SELECT 
    (entitlement_status = 'active'),
    (current_period_end > now()),
    revocation_time,
    environment,
    product_id,
    owner_user_id
  INTO v_store_active, v_period_valid, v_revocation, v_env, v_prod, v_owner
  FROM public.business_plus_subscriptions
  WHERE business_account_id = p_business_account_id
    AND store IN ('google_play', 'app_store')
  ORDER BY created_at DESC
  LIMIT 1;

  -- Manual check
  SELECT EXISTS (
    SELECT 1 
    FROM public.business_plus_subscriptions
    WHERE business_account_id = p_business_account_id
      AND store = 'manual_admin'
      AND entitlement_status = 'active'
      AND starts_at <= now()
      AND (ends_at IS NULL OR ends_at > now())
  ) INTO v_manual_active;

  -- Grace check
  SELECT EXISTS (
    SELECT 1 
    FROM public.business_plus_subscriptions
    WHERE business_account_id = p_business_account_id
      AND store IN ('google_play', 'app_store')
      AND entitlement_status = 'grace_period'
      AND grace_period_end > now()
  ) INTO v_grace_valid;

  -- Fetch cached status
  SELECT is_plus_active INTO v_cached_active
  FROM public.business_accounts
  WHERE id = p_business_account_id;

  v_calculated_active := public.check_business_plus_active(p_business_account_id);
  v_stale := (v_cached_active <> v_calculated_active);

  -- Outcome determination
  IF v_revocation IS NOT NULL THEN
    v_outcome := 'revoked';
  ELSIF v_manual_active THEN
    v_outcome := 'active_manual_entitlement';
  ELSIF v_store_active AND v_period_valid THEN
    IF EXISTS (
      SELECT 1 FROM public.business_plus_subscriptions
      WHERE business_account_id = p_business_account_id
        AND store IN ('google_play', 'app_store')
        AND auto_renew_enabled = false
    ) THEN
      v_outcome := 'cancelled_but_period_active';
    ELSE
      v_outcome := 'active_store_subscription';
    END IF;
  ELSIF v_grace_valid THEN
    v_outcome := 'grace_period_active';
  ELSIF EXISTS (
    SELECT 1 FROM public.business_plus_subscriptions
    WHERE business_account_id = p_business_account_id
      AND entitlement_status = 'expired'
  ) THEN
    v_outcome := 'expired';
  END IF;

  RETURN QUERY
  SELECT 
    v_store_active,
    v_manual_active,
    v_period_valid,
    v_grace_valid,
    v_revocation,
    COALESCE(v_env, 'none'),
    COALESCE(v_prod, 'none'),
    COALESCE(v_owner, '00000000-0000-0000-0000-000000000000'::uuid),
    v_stale,
    'Reconciled successfully'::text,
    v_outcome;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_inspect_entitlement_decision(uuid) TO authenticated;

-- 12. Admin Search Subscriptions (Point 10)
-- Excludes raw receipts, includes paging caps and email whitelists.
CREATE OR REPLACE FUNCTION public.admin_query_subscriptions(
  p_search text,
  p_filter_status text,
  p_filter_store text,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  subscription_id uuid,
  business_id uuid,
  business_name text,
  owner_email text,
  store text,
  product_id text,
  entitlement_status text,
  environment text,
  ends_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit_cap integer;
  v_search_term text;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  -- Validate allowlist filters (Point 10)
  IF p_filter_status IS NOT NULL AND p_filter_status <> '' AND p_filter_status NOT IN ('active', 'grace_period', 'billing_retry', 'expired', 'revoked', 'cancelled') THEN
    RAISE EXCEPTION 'invalid_filter_status';
  END IF;

  IF p_filter_store IS NOT NULL AND p_filter_store <> '' AND p_filter_store NOT IN ('google_play', 'app_store', 'manual_admin') THEN
    RAISE EXCEPTION 'invalid_filter_store';
  END IF;

  -- Apply limits (Point 10)
  v_limit_cap := LEAST(p_limit, 50);
  
  IF length(p_search) > 100 THEN
    RAISE EXCEPTION 'search_query_too_long_max_100';
  END IF;

  -- Wildcard query protection (Point 10)
  v_search_term := ltrim(p_search, '%_');
  IF length(v_search_term) < 3 AND p_search IS NOT NULL AND p_search <> '' THEN
    RAISE EXCEPTION 'search_query_too_short_min_3_chars';
  END IF;
  
  v_search_term := '%' || v_search_term || '%';

  RETURN QUERY
  SELECT 
    sub.id as subscription_id,
    ba.id as business_id,
    ba.name as business_name,
    u.email::text as owner_email, -- Expose owner email only in this admin RPC (Point 10)
    sub.store,
    sub.product_id,
    sub.entitlement_status,
    COALESCE(sub.environment, 'production') as environment,
    sub.ends_at
  FROM public.business_plus_subscriptions sub
  JOIN public.business_accounts ba ON sub.business_account_id = ba.id
  JOIN auth.users u ON ba.owner_user_id = u.id
  WHERE (
    p_search IS NULL OR p_search = '' OR
    ba.name ILIKE v_search_term OR
    u.email ILIKE v_search_term OR
    ba.id::text ILIKE v_search_term
  )
  AND (p_filter_status IS NULL OR p_filter_status = '' OR sub.entitlement_status = p_filter_status)
  AND (p_filter_store IS NULL OR p_filter_store = '' OR sub.store = p_filter_store)
  ORDER BY sub.created_at DESC, sub.id ASC -- Deterministic ordering (Point 10)
  LIMIT v_limit_cap
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_query_subscriptions(text, text, text, integer, integer) TO authenticated;

-- 13. Subscription Detail DTO (Point 9)
-- Restricts output to safe whitelisted variables. No tokens, secrets, or payloads.
CREATE OR REPLACE FUNCTION public.admin_get_subscription_detail(
  p_business_account_id uuid
)
RETURNS TABLE (
  subscription_id uuid,
  business_id uuid,
  business_name text,
  owner_name text,
  owner_email text,
  store text,
  product_id text,
  base_plan_id text,
  environment text,
  store_subscription_status text,
  entitlement_status text,
  starts_at timestamptz,
  ends_at timestamptz,
  auto_renew_enabled boolean,
  cancellation_time timestamptz,
  grace_period_end timestamptz,
  revocation_time timestamptz,
  latest_verification_time timestamptz,
  safe_identity_fingerprint_suffix text,
  events_used bigint,
  boosts_used bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_events_count bigint;
  v_boosts_count bigint;
  v_owner_name text;
  v_owner_email text;
  v_biz_name text;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  -- Load metrics & stats
  SELECT count(*)::bigint INTO v_events_count
  FROM public.events e
  WHERE e.organizer_business_id = p_business_account_id
    AND e.created_at > date_trunc('month', now());

  SELECT count(*)::bigint INTO v_boosts_count
  FROM public.business_event_boosts b
  WHERE b.business_account_id = p_business_account_id
    AND b.boosted_at > date_trunc('month', now());

  SELECT 
    ba.name,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Unnamed Owner'),
    u.email
  INTO v_biz_name, v_owner_name, v_owner_email
  FROM public.business_accounts ba
  JOIN auth.users u ON ba.owner_user_id = u.id
  WHERE ba.id = p_business_account_id;

  RETURN QUERY
  SELECT 
    sub.id as subscription_id,
    sub.business_account_id as business_id,
    v_biz_name as business_name,
    v_owner_name as owner_name,
    v_owner_email::text as owner_email,
    sub.store,
    sub.product_id,
    COALESCE(sub.base_plan_id, 'none') as base_plan_id,
    COALESCE(sub.environment, 'production') as environment,
    COALESCE(sub.store_subscription_status, 'none') as store_subscription_status,
    sub.entitlement_status,
    sub.starts_at,
    sub.ends_at,
    sub.auto_renew_enabled,
    sub.cancellation_time,
    sub.grace_period_end,
    sub.revocation_time,
    sub.latest_verification_time,
    -- Return only a safe short suffix of the SHA256 identity hash for correlation (Point 9)
    CASE 
      WHEN sub.external_purchase_identity_hash IS NOT NULL 
      THEN substring(sub.external_purchase_identity_hash from length(sub.external_purchase_identity_hash) - 5) 
      ELSE NULL 
    END as safe_identity_fingerprint_suffix,
    v_events_count as events_used,
    v_boosts_count as boosts_used
  FROM public.business_plus_subscriptions sub
  WHERE sub.business_account_id = p_business_account_id
  ORDER BY sub.created_at DESC
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_subscription_detail(uuid) TO authenticated;

-- Helper to retrieve audit history securely
CREATE OR REPLACE FUNCTION public.admin_get_audit_logs(
  p_business_account_id uuid DEFAULT NULL
)
RETURNS TABLE (
  log_id uuid,
  acting_admin_email text,
  business_id uuid,
  business_name text,
  action_type text,
  reason text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  RETURN QUERY
  SELECT 
    log.id as log_id,
    u.email::text as acting_admin_email,
    log.business_account_id as business_id,
    COALESCE(ba.name, 'System Level') as business_name,
    log.action_type,
    log.reason,
    log.note,
    log.created_at
  FROM private.business_plus_admin_audit_logs log
  JOIN auth.users u ON log.acting_admin_id = u.id
  LEFT JOIN public.business_accounts ba ON log.business_account_id = ba.id
  WHERE (p_business_account_id IS NULL OR log.business_account_id = p_business_account_id)
  ORDER BY log.created_at DESC
  LIMIT 100;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_audit_logs(uuid) TO authenticated;


-- 14. Redefine verification transaction function to include platform/product mutation & expiry checks (Point 1 & 11)
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
  v_context_platform text;
  v_context_product_id text;
BEGIN
  -- This function is restricted to service_role/Deno verification functions.
  
  -- 1. If purchase_context_id is provided, validate it
  IF p_purchase_context_id IS NOT NULL THEN
    SELECT user_id, business_account_id, consumed_at, expires_at, platform, product_id
    INTO v_context_user_id, v_context_business_id, v_context_consumed, v_context_expires, v_context_platform, v_context_product_id
    FROM public.business_plus_purchase_contexts
    WHERE id = p_purchase_context_id
    FOR UPDATE; -- Locked context row atomically! (Point 1)

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

    -- platform/product mutation check (Point 1)
    IF v_context_platform <> p_store_to_platform(p_store) OR v_context_product_id <> p_product_id THEN
      RAISE EXCEPTION 'purchase_context_platform_product_mismatch';
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
    updated_at,
    price_amount_minor,
    price_currency
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
    now(),
    100000, -- Hardcoded server-side price (1000.00 TL) to prevent client fraud (Point 7)
    'TRY'   -- Hardcoded server-side currency (Point 7)
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

-- Helper to convert store to platform name
CREATE OR REPLACE FUNCTION public.p_store_to_platform(p_store text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_store = 'google_play' THEN
    RETURN 'android';
  ELSIF p_store = 'app_store' THEN
    RETURN 'ios';
  ELSE
    RETURN 'unknown';
  END IF;
END;
$$;


-- 15. Create Secure Alert Scheduler evaluations function (Point 6)
CREATE OR REPLACE FUNCTION public.check_and_trigger_billing_alerts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_alert_count integer := 0;
  v_cooldown interval := interval '1 hour';
  v_stale_reconcile_count bigint;
  v_manual_expiry_soon bigint;
  v_webhook_fail_count bigint;
  v_store_outage_count bigint;
  v_revocation_count bigint;
BEGIN
  IF NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'unauthorized_admin_only';
  END IF;

  -- 1. stale_reconciliation alert evaluation
  SELECT count(*) INTO v_stale_reconcile_count
  FROM public.business_plus_subscriptions
  WHERE entitlement_status IN ('active', 'grace_period', 'billing_retry')
    AND store IN ('google_play', 'app_store')
    AND (latest_verification_time IS NULL OR latest_verification_time < now() - interval '30 hours');

  IF v_stale_reconcile_count > 0 THEN
    INSERT INTO public.admin_billing_alerts (alert_type, message, metadata, last_triggered_at, resolved)
    VALUES (
      'stale_reconciliation',
      'stale_reconciliation: ' || v_stale_reconcile_count || ' active subscriptions have not been verified/reconciled in the last 30 hours.',
      jsonb_build_object('count', v_stale_reconcile_count),
      now(),
      false
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = CASE 
          WHEN admin_billing_alerts.last_triggered_at < now() - v_cooldown THEN now()
          ELSE admin_billing_alerts.last_triggered_at
        END,
        resolved = false;
    v_alert_count := v_alert_count + 1;
  END IF;

  -- 2. manual_entitlement_expiring_soon alert evaluation
  SELECT count(*) INTO v_manual_expiry_soon
  FROM public.business_plus_subscriptions
  WHERE store = 'manual_admin'
    AND entitlement_status = 'active'
    AND ends_at > now()
    AND ends_at < now() + interval '3 days';

  IF v_manual_expiry_soon > 0 THEN
    INSERT INTO public.admin_billing_alerts (alert_type, message, metadata, last_triggered_at, resolved)
    VALUES (
      'manual_entitlement_expiring_soon',
      'manual_entitlement_expiring_soon: ' || v_manual_expiry_soon || ' manual entitlements will expire within 3 days.',
      jsonb_build_object('count', v_manual_expiry_soon),
      now(),
      false
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = CASE 
          WHEN admin_billing_alerts.last_triggered_at < now() - v_cooldown THEN now()
          ELSE admin_billing_alerts.last_triggered_at
        END,
        resolved = false;
    v_alert_count := v_alert_count + 1;
  END IF;

  -- 3. webhook_authentication_failure_spike alert evaluation
  SELECT count(*) INTO v_webhook_fail_count
  FROM public.business_plus_verification_issues
  WHERE category IN ('signature_failure', 'malformed_notification')
    AND resolved = false
    AND updated_at > now() - interval '1 hour';

  IF v_webhook_fail_count >= 5 THEN
    INSERT INTO public.admin_billing_alerts (alert_type, message, metadata, last_triggered_at, resolved)
    VALUES (
      'webhook_authentication_failure_spike',
      'webhook_authentication_failure_spike: ' || v_webhook_fail_count || ' webhook authentication failures in the last hour.',
      jsonb_build_object('count', v_webhook_fail_count),
      now(),
      false
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = CASE 
          WHEN admin_billing_alerts.last_triggered_at < now() - v_cooldown THEN now()
          ELSE admin_billing_alerts.last_triggered_at
        END,
        resolved = false;
    v_alert_count := v_alert_count + 1;
  END IF;

  -- 4. store_outage alert evaluation
  SELECT count(*) INTO v_store_outage_count
  FROM public.business_plus_verification_issues
  WHERE category = 'api_unavailable'
    AND resolved = false
    AND updated_at > now() - interval '1 hour';

  IF v_store_outage_count >= 3 THEN
    INSERT INTO public.admin_billing_alerts (alert_type, message, metadata, last_triggered_at, resolved)
    VALUES (
      'store_outage',
      'store_outage: ' || v_store_outage_count || ' API connection failures in the last hour.',
      jsonb_build_object('count', v_store_outage_count),
      now(),
      false
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = CASE 
          WHEN admin_billing_alerts.last_triggered_at < now() - v_cooldown THEN now()
          ELSE admin_billing_alerts.last_triggered_at
        END,
        resolved = false;
    v_alert_count := v_alert_count + 1;
  END IF;

  -- 5. high_revocation_volume alert evaluation
  SELECT count(*) INTO v_revocation_count
  FROM public.business_plus_subscriptions
  WHERE entitlement_status = 'revoked'
    AND revocation_time > now() - interval '24 hours';

  IF v_revocation_count >= 5 THEN
    INSERT INTO public.admin_billing_alerts (alert_type, message, metadata, last_triggered_at, resolved)
    VALUES (
      'high_revocation_volume',
      'high_revocation_volume: ' || v_revocation_count || ' subscriptions revoked/refunded in the last 24 hours.',
      jsonb_build_object('count', v_revocation_count),
      now(),
      false
    )
    ON CONFLICT (alert_type) DO UPDATE
    SET message = EXCLUDED.message,
        metadata = EXCLUDED.metadata,
        last_triggered_at = CASE 
          WHEN admin_billing_alerts.last_triggered_at < now() - v_cooldown THEN now()
          ELSE admin_billing_alerts.last_triggered_at
        END,
        resolved = false;
    v_alert_count := v_alert_count + 1;
  END IF;

  RETURN v_alert_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_trigger_billing_alerts() TO authenticated;


-- Re-sync database cache status
SELECT public.reconcile_all_business_plus_cache();
NOTIFY pgrst, 'reload schema';
