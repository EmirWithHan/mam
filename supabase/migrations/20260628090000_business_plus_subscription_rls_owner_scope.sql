-- Migration: Restrict Business Plus subscription reads to owners and admins
-- Timestamp: 20260628090000

ALTER TABLE public.business_plus_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can select business plus subscriptions"
  ON public.business_plus_subscriptions;

DROP POLICY IF EXISTS "Business owners and admins can select business plus subscriptions"
  ON public.business_plus_subscriptions;

CREATE POLICY "Business owners and admins can select business plus subscriptions"
  ON public.business_plus_subscriptions
  FOR SELECT
  TO authenticated
  USING (
    owner_user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.business_accounts business
      WHERE business.id = business_plus_subscriptions.business_account_id
        AND business.owner_user_id = auth.uid()
    )
    OR public.is_current_user_admin()
  );

REVOKE INSERT, UPDATE, DELETE ON public.business_plus_subscriptions
  FROM authenticated, public, anon;

GRANT SELECT ON public.business_plus_subscriptions TO authenticated;

ALTER TABLE private.business_plus_subscription_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.processed_webhook_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.business_plus_admin_audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.business_plus_subscription_proofs
  FROM public, authenticated, anon;
REVOKE ALL ON TABLE private.processed_webhook_notifications
  FROM public, authenticated, anon;
REVOKE ALL ON TABLE private.business_plus_admin_audit_logs
  FROM public, authenticated, anon;

NOTIFY pgrst, 'reload schema';
