import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseGoogleBusinessPlusEntitlement } from "../_shared/business_plus_entitlement.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const androidPublisherScope =
  "https://www.googleapis.com/auth/androidpublisher";
const googleTokenUrl = "https://oauth2.googleapis.com/token";
const businessPlusProductId = "business_plus_monthly";
const defaultPackageName = "com.matchaman.app";

type ReconcileRequest = {
  purchase_token?: string;
  subscription_id?: string;
  limit?: number;
};

type GoogleLineItem = {
  productId?: string;
  expiryTime?: string;
  latestSuccessfulOrderId?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
  offerDetails?: { basePlanId?: string };
};

type GoogleSubscriptionPurchase = {
  startTime?: string;
  subscriptionState?: string;
  latestOrderId?: string;
  linkedPurchaseToken?: string;
  testPurchase?: unknown;
  lineItems?: GoogleLineItem[];
  canceledStateContext?: Record<string, unknown>;
  acknowledgementState?: string;
};

type SubscriptionTarget = {
  id: string;
  business_account_id: string;
  owner_user_id: string;
  product_id: string | null;
  base_plan_id: string | null;
  original_transaction_id: string | null;
  external_purchase_identity_hash: string;
  purchase_time: string | null;
  current_period_start: string | null;
  environment: string | null;
  purchase_token: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const internalSecret = Deno.env.get("PUSH_WORKER_SECRET")?.trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKeySource = selectedServiceKeySource();
  const serviceKey = serviceKeySource == null
    ? null
    : Deno.env.get(serviceKeySource)?.trim();
  if (
    !internalSecret || !supabaseUrl || !serviceKey ||
    !hasGoogleServiceAccountConfiguration()
  ) {
    return json({ error: "reconciliation_configuration_error" }, 500);
  }
  const suppliedSecret = bearerToken(req.headers.get("authorization"));
  if (!suppliedSecret || !constantTimeEqual(suppliedSecret, internalSecret)) {
    return json({ error: "unauthorized" }, 401);
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: ReconcileRequest = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  try {
    const targets = await reconciliationTargets(serviceClient, body);
    let accessTokenPromise: Promise<string> | null = null;
    const getAccessToken = (): Promise<string> => {
      accessTokenPromise ??= googleAccessToken();
      return accessTokenPromise;
    };
    const results: Array<Record<string, unknown>> = [];
    for (let index = 0; index < targets.length; index += 5) {
      const batch = targets.slice(index, index + 5);
      const batchResults = await Promise.all(batch.map(async (target) => {
        try {
          return await reconcileTarget({
            serviceClient,
            target,
            getAccessToken,
          });
        } catch (error) {
          const errorCode = reconciliationErrorCode(error);
          await recordReconciliationError(
            serviceClient,
            target.id,
            errorCode,
          );
          console.error("reconcile_failed", {
            product_id: target.product_id ?? businessPlusProductId,
            business_id: target.business_account_id,
            error: errorCode,
          });
          return { reconciled: false, active: false, retryable: true };
        }
      }));
      results.push(...batchResults);
    }

    const selected = targets.length;
    const processed = results.length;
    const succeeded = results.filter((item) => item.reconciled === true).length;
    const inactive = results.filter((item) => item.inactive === true).length;
    const failed = processed - succeeded;
    const acknowledgementRetried = results.filter(
      (item) => item.acknowledgement_retried === true,
    ).length;
    const totalEligible = body.purchase_token || body.subscription_id
      ? selected
      : await eligibleSubscriptionCount(serviceClient);
    const remaining = Math.max(0, totalEligible - selected);
    return json({
      selected,
      processed,
      succeeded,
      inactive,
      failed,
      acknowledgement_retried: acknowledgementRetried,
      remaining,
      partial: remaining > 0 || failed > 0,
      continuation_needed: remaining > 0 || failed > 0,
    });
  } catch (error) {
    console.error("reconcile_failed", { error: safeErrorMessage(error) });
    return json({ error: "reconcile_failed" }, 500);
  }
});

async function reconciliationTargets(
  serviceClient: any,
  body: ReconcileRequest,
): Promise<SubscriptionTarget[]> {
  if (body.purchase_token) {
    const subscriptionId = await subscriptionIdForPurchaseToken(
      serviceClient,
      body.purchase_token,
    );
    if (!subscriptionId) return [];
    const subscription = await fetchSubscription(serviceClient, subscriptionId);
    if (!subscription) return [];
    return [subscriptionTarget(subscription, body.purchase_token)];
  }

  if (body.subscription_id) {
    const subscription = await fetchSubscription(
      serviceClient,
      body.subscription_id,
    );
    if (!subscription) return [];
    const proof = await fetchProof(serviceClient, body.subscription_id);
    return [subscriptionTarget(subscription, proof?.purchase_token ?? null)];
  }

  const requestedLimit = typeof body.limit === "number" &&
      Number.isFinite(body.limit) && body.limit > 0
    ? Math.max(1, Math.floor(body.limit))
    : 500;
  const limit = Math.min(500, requestedLimit);

  const { data: subscriptions, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select("id,business_account_id,owner_user_id,product_id,base_plan_id,original_transaction_id,external_purchase_identity_hash,purchase_time,current_period_start,environment")
    .eq("store", "google_play")
    .in("entitlement_status", [
      "active",
      "grace_period",
      "billing_retry",
      "paused",
      "cancelled",
    ])
    .order("last_reconciliation_attempt_at", {
      ascending: true,
      nullsFirst: true,
    })
    .order("latest_verification_time", { ascending: true, nullsFirst: true })
    .order("id", { ascending: true })
    .limit(limit);
  if (error) throw error;

  const targets: SubscriptionTarget[] = [];
  const subscriptionIds = (subscriptions ?? []).map((subscription: any) =>
    subscription.id
  );
  const proofsBySubscriptionId = await fetchProofsBySubscriptionId(
    serviceClient,
    subscriptionIds,
  );
  for (const subscription of subscriptions ?? []) {
    targets.push(
      subscriptionTarget(
        subscription,
        proofsBySubscriptionId.get(subscription.id) ?? null,
      ),
    );
  }
  return targets;
}

function subscriptionTarget(
  subscription: Record<string, any>,
  purchaseToken: string | null,
): SubscriptionTarget {
  return {
    id: subscription.id,
    business_account_id: subscription.business_account_id,
    owner_user_id: subscription.owner_user_id,
    product_id: subscription.product_id ?? null,
    base_plan_id: subscription.base_plan_id ?? null,
    original_transaction_id: subscription.original_transaction_id ?? null,
    external_purchase_identity_hash:
      typeof subscription.external_purchase_identity_hash === "string"
        ? subscription.external_purchase_identity_hash.trim()
        : "",
    purchase_time: subscription.purchase_time ?? null,
    current_period_start: subscription.current_period_start ?? null,
    environment: subscription.environment ?? null,
    purchase_token: purchaseToken,
  };
}

async function subscriptionIdForPurchaseToken(
  serviceClient: any,
  purchaseToken: string,
): Promise<string | null> {
  const { data, error } = await serviceClient.rpc(
    "query_subscription_id_by_token",
    { p_purchase_token: purchaseToken },
  );
  if (error) throw error;
  const first = Array.isArray(data) ? data[0] : data;
  return first?.subscription_id ?? null;
}

async function fetchSubscription(
  serviceClient: any,
  subscriptionId: string,
): Promise<Omit<SubscriptionTarget, "purchase_token"> | null> {
  const { data, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select("id,business_account_id,owner_user_id,product_id,base_plan_id,original_transaction_id,external_purchase_identity_hash,purchase_time,current_period_start,environment")
    .eq("id", subscriptionId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchProof(serviceClient: any, subscriptionId: string) {
  const { data, error } = await serviceClient
    .schema("private")
    .from("business_plus_subscription_proofs")
    .select("purchase_token")
    .eq("subscription_id", subscriptionId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchProofsBySubscriptionId(
  serviceClient: any,
  subscriptionIds: string[],
): Promise<Map<string, string>> {
  if (subscriptionIds.length === 0) return new Map();
  const { data, error } = await serviceClient
    .schema("private")
    .from("business_plus_subscription_proofs")
    .select("subscription_id,purchase_token")
    .in("subscription_id", subscriptionIds);
  if (error) throw error;

  const proofs = new Map<string, string>();
  for (const proof of data ?? []) {
    const purchaseToken = proof.purchase_token?.toString().trim();
    if (purchaseToken) proofs.set(proof.subscription_id, purchaseToken);
  }
  return proofs;
}

async function reconcileTarget({
  serviceClient,
  target,
  getAccessToken,
}: {
  serviceClient: any;
  target: SubscriptionTarget;
  getAccessToken: () => Promise<string>;
}) {
  await markReconciliationAttempt(serviceClient, target.id);
  if (!target.external_purchase_identity_hash) {
    throw new Error("subscription_purchase_identity_invalid");
  }
  if (!target.purchase_token) {
    await persistInactiveTarget(serviceClient, target, null, {
      missing_purchase_proof: true,
      reconciliation: true,
    });
    await clearReconciliationError(serviceClient, target.id);
    return { reconciled: true, active: false, inactive: true };
  }
  const productId = target.product_id ?? businessPlusProductId;
  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (error) {
    console.error("google_auth_failed", {
      product_id: productId,
      business_id: target.business_account_id,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  let googlePurchase: GoogleSubscriptionPurchase;
  try {
    googlePurchase = await getGoogleSubscription({
      accessToken,
      purchaseToken: target.purchase_token,
    });
  } catch (error) {
    if (safeErrorMessage(error) === "google_subscription_not_found") {
      await persistInactiveTarget(
        serviceClient,
        target,
        target.purchase_token,
        { google_purchase_missing: true, reconciliation: true },
      );
      await clearReconciliationError(serviceClient, target.id);
      return { reconciled: true, active: false, inactive: true };
    }
    console.error("google_verification_failed", {
      product_id: productId,
      business_id: target.business_account_id,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  const lineItem = findBusinessPlusLineItem(googlePurchase, productId);
  if (!lineItem) {
    await persistInactiveTarget(
      serviceClient,
      target,
      target.purchase_token,
      { malformed_product_response: true, reconciliation: true },
    );
    await clearReconciliationError(serviceClient, target.id);
    return { reconciled: true, active: false, inactive: true };
  }

  const sync = parseGoogleBusinessPlusEntitlement({
    subscriptionState: googlePurchase.subscriptionState,
    expiryTime: lineItem.expiryTime,
    gracePeriodExpiryTime: lineItem.expiryTime,
    canceledStateContext: googlePurchase.canceledStateContext,
    autoRenewEnabled: lineItem.autoRenewingPlan?.autoRenewEnabled,
    purchaseTime: googlePurchase.startTime,
  });
  const subscriptionState = sync.rawStoreState;
  const tokenHash = await sha256Hex(target.purchase_token);

  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: target.business_account_id,
      p_owner_user_id: target.owner_user_id,
      p_store: "google_play",
      p_product_id: productId,
      p_base_plan_id: lineItem.offerDetails?.basePlanId ?? null,
      p_original_transaction_id:
        googlePurchase.linkedPurchaseToken ??
        lineItem.latestSuccessfulOrderId ??
        googlePurchase.latestOrderId ??
        null,
      p_external_purchase_identity_hash: tokenHash,
      p_store_subscription_status: subscriptionState,
      p_entitlement_status: sync.candidateEntitlementStatus,
      p_purchase_time: sync.purchaseTime,
      p_current_period_start: sync.purchaseTime,
      p_current_period_end: sync.currentPeriodEnd,
      p_auto_renew_enabled: sync.autoRenewEnabled,
      p_cancellation_time: sync.cancellationTime,
      p_grace_period_end: sync.gracePeriodEnd,
      p_revocation_time: sync.revocationTime,
      p_environment: googlePurchase.testPurchase ? "sandbox" : "production",
      p_purchase_context_id: null,
      p_purchase_token: target.purchase_token,
      p_raw_payload: {
        google_subscription: sanitizedGooglePurchase(googlePurchase),
        reconciliation: true,
      },
    },
  );
  if (error) {
    console.error("subscription_sync_failed", {
      product_id: productId,
      business_id: target.business_account_id,
      subscription_state: subscriptionState,
      entitlement_status: sync.candidateEntitlementStatus,
      error: error.message,
    });
    throw error;
  }

  await clearReconciliationError(serviceClient, target.id);

  const stored = await storedTargetState(serviceClient, target, tokenHash);
  let acknowledgementRetried = false;
  if (
    googlePurchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
    stored.active &&
    ["active", "cancelled", "grace_period"].includes(stored.entitlement_status) &&
    isFutureTimestamp(stored.ends_at ?? stored.current_period_end)
  ) {
    await acknowledgeGoogleSubscription({
      accessToken,
      productId,
      purchaseToken: target.purchase_token,
    });
    acknowledgementRetried = true;
  }

  return {
    reconciled: true,
    active: stored.active,
    inactive: !stored.active,
    acknowledgement_retried: acknowledgementRetried,
    entitlement_status: stored.entitlement_status,
    subscription_state: stored.store_subscription_status,
    message: stored.active
      ? "Business Plus entitlement is active."
      : "Business Plus entitlement is not active.",
  };
}

async function googleAccessToken(): Promise<string> {
  const serviceAccount = serviceAccountCredentials();
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signedJwt(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.clientEmail,
      scope: androidPublisherScope,
      aud: googleTokenUrl,
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.privateKey,
  );
  let response: Response;
  try {
    response = await fetch(googleTokenUrl, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
  } catch {
    throw new Error("network_failure");
  }
  if (response.status === 429) throw new Error("google_rate_limited");
  if (response.status >= 500) throw new Error("google_server_error");
  if (!response.ok) throw new Error("google_auth_failed");
  const data = await response.json();
  if (!data.access_token) throw new Error("google_token_missing");
  return data.access_token as string;
}

function serviceAccountCredentials(): {
  clientEmail: string;
  privateKey: string;
} {
  const rawJson = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (rawJson) {
    const parsed = JSON.parse(rawJson);
    if (parsed.client_email && parsed.private_key) {
      return {
        clientEmail: parsed.client_email,
        privateKey: parsed.private_key.replace(/\\n/g, "\n"),
      };
    }
  }
  const clientEmail = Deno.env.get("GOOGLE_PLAY_CLIENT_EMAIL");
  const privateKey = Deno.env.get("GOOGLE_PLAY_PRIVATE_KEY")?.replace(
    /\\n/g,
    "\n",
  );
  if (!clientEmail || !privateKey) {
    throw new Error("missing_google_service_account");
  }
  return { clientEmail, privateKey };
}

async function getGoogleSubscription({
  accessToken,
  purchaseToken,
}: {
  accessToken: string;
  purchaseToken: string;
}): Promise<GoogleSubscriptionPurchase> {
  const packageName =
    Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || defaultPackageName;
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  let response: Response;
  try {
    response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch {
    throw new Error("network_failure");
  }
  if (response.status === 404 || response.status === 410) {
    throw new Error("google_subscription_not_found");
  }
  if (response.status === 429) throw new Error("google_rate_limited");
  if (response.status >= 500) throw new Error("google_server_error");
  if (!response.ok) throw new Error("google_subscription_get_failed");
  return await response.json();
}

function findBusinessPlusLineItem(
  purchase: GoogleSubscriptionPurchase,
  productId: string,
): GoogleLineItem | null {
  for (const item of purchase.lineItems ?? []) {
    if (item.productId === productId) return item;
  }
  return null;
}

function sanitizedGooglePurchase(
  purchase: GoogleSubscriptionPurchase,
): Record<string, unknown> {
  const copy = { ...purchase } as Record<string, unknown>;
  delete copy.subscribeWithGoogleInfo;
  return copy;
}

function selectedServiceKeySource(): string | null {
  if (Deno.env.get("SERVICE_ROLE_KEY")) return "SERVICE_ROLE_KEY";
  if (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) {
    return "SUPABASE_SERVICE_ROLE_KEY";
  }
  if (Deno.env.get("MAM_SUPABASE_SERVICE_KEY")) {
    return "MAM_SUPABASE_SERVICE_KEY";
  }
  return null;
}

function hasGoogleServiceAccountConfiguration(): boolean {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")?.trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed.client_email && parsed.private_key) return true;
    } catch {
      return false;
    }
  }
  return Boolean(
    Deno.env.get("GOOGLE_PLAY_CLIENT_EMAIL")?.trim() &&
      Deno.env.get("GOOGLE_PLAY_PRIVATE_KEY")?.trim(),
  );
}

async function eligibleSubscriptionCount(serviceClient: any): Promise<number> {
  const { count, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select("id", { count: "exact", head: true })
    .eq("store", "google_play")
    .in("entitlement_status", [
      "active",
      "grace_period",
      "billing_retry",
      "paused",
      "cancelled",
    ]);
  if (error) throw error;
  return count ?? 0;
}

function bearerToken(header: string | null): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  const value = header.slice("Bearer ".length).trim();
  return value.length > 0 ? value : null;
}

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index++) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

async function markReconciliationAttempt(
  serviceClient: any,
  subscriptionId: string,
): Promise<void> {
  const { error } = await serviceClient
    .from("business_plus_subscriptions")
    .update({ last_reconciliation_attempt_at: new Date().toISOString() })
    .eq("id", subscriptionId);
  if (error) throw new Error("attempt_state_update_failed");
}

async function clearReconciliationError(
  serviceClient: any,
  subscriptionId: string,
): Promise<void> {
  const { error } = await serviceClient
    .from("business_plus_subscriptions")
    .update({ last_reconciliation_error_code: null })
    .eq("id", subscriptionId);
  if (error) throw new Error("attempt_state_update_failed");
}

async function recordReconciliationError(
  serviceClient: any,
  subscriptionId: string,
  errorCode: string,
): Promise<void> {
  const { error } = await serviceClient
    .from("business_plus_subscriptions")
    .update({ last_reconciliation_error_code: errorCode })
    .eq("id", subscriptionId);
  if (error) {
    console.error("attempt_error_state_update_failed", {
      subscription_id: subscriptionId,
      error: "attempt_state_update_failed",
    });
  }
}

function reconciliationErrorCode(error: unknown): string {
  const code = safeErrorMessage(error);
  if (code === "missing_purchase_proof") return "missing_purchase_proof";
  if (code === "subscription_purchase_identity_invalid") {
    return "purchase_identity_invalid";
  }
  if (code === "google_rate_limited") return "google_rate_limited";
  if (code === "google_server_error") return "google_server_error";
  if (code === "network_failure") return "network_failure";
  if (code === "google_subscription_get_failed") {
    return "google_subscription_get_failed";
  }
  if (code.startsWith("google_token") || code === "google_auth_failed") {
    return "google_auth_failed";
  }
  if (code === "google_subscription_ack_failed") {
    return "google_acknowledgement_failed";
  }
  return "reconciliation_failed";
}

async function persistInactiveTarget(
  serviceClient: any,
  target: SubscriptionTarget,
  purchaseToken: string | null,
  rawPayload: Record<string, unknown>,
): Promise<void> {
  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: target.business_account_id,
      p_owner_user_id: target.owner_user_id,
      p_store: "google_play",
      p_product_id: target.product_id ?? businessPlusProductId,
      p_base_plan_id: target.base_plan_id,
      p_original_transaction_id: target.original_transaction_id,
      p_external_purchase_identity_hash: target.external_purchase_identity_hash,
      p_store_subscription_status: "unknown",
      p_entitlement_status: "expired",
      p_purchase_time: target.purchase_time,
      p_current_period_start: target.current_period_start,
      p_current_period_end: null,
      p_auto_renew_enabled: false,
      p_cancellation_time: null,
      p_grace_period_end: null,
      p_revocation_time: null,
      p_environment: target.environment,
      p_purchase_context_id: null,
      p_purchase_token: purchaseToken,
      p_raw_payload: rawPayload,
    },
  );
  if (error) throw error;
}

async function storedTargetState(
  serviceClient: any,
  target: SubscriptionTarget,
  identityHash: string,
) {
  const { data: active, error: activeError } = await serviceClient.rpc(
    "check_business_plus_active",
    { p_business_account_id: target.business_account_id },
  );
  const { data, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select("entitlement_status,store_subscription_status,current_period_end,ends_at")
    .eq("business_account_id", target.business_account_id)
    .eq("owner_user_id", target.owner_user_id)
    .eq("store", "google_play")
    .eq("external_purchase_identity_hash", identityHash)
    .maybeSingle();
  if (activeError || typeof active !== "boolean" || error || !data) {
    throw new Error("stored_subscription_read_failed");
  }
  return { active, ...data };
}

function isFutureTimestamp(value: unknown): boolean {
  if (typeof value !== "string") return false;
  const time = Date.parse(value);
  return Number.isFinite(time) && time > Date.now();
}

async function acknowledgeGoogleSubscription({
  accessToken,
  productId,
  purchaseToken,
}: {
  accessToken: string;
  productId: string;
  purchaseToken: string;
}) {
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() ||
    defaultPackageName;
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: "{}",
    },
  );
  if (!response.ok) throw new Error("google_subscription_ack_failed");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function signedJwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const input = `${encodedHeader}.${encodedPayload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64UrlEncode(signature)}`;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0)).buffer;
}

function base64UrlEncode(value: string | ArrayBuffer): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function safeErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
