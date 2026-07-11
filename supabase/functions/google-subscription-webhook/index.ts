import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "https://deno.land/x/jose@v5.9.6/index.ts";
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
const googleOidcJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

type PubSubPushBody = {
  message?: {
    data?: string;
    messageId?: string;
    message_id?: string;
  };
};

type RtdnPayload = {
  packageName?: string;
  subscriptionNotification?: {
    notificationType?: number;
    purchaseToken?: string;
    subscriptionId?: string;
  };
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

type SubscriptionRow = {
  id: string;
  business_account_id: string;
  owner_user_id: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const oidcAudience =
    requiredEnv("GOOGLE_RTDN_OIDC_AUDIENCE") ??
    requiredEnv("GOOGLE_PLAY_PUBSUB_AUDIENCE");

  const allowedEmail =
    requiredEnv("GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL") ??
    requiredEnv("GOOGLE_PLAY_PUBSUB_ALLOWED_SERVICE_ACCOUNT");
  const verificationToken = requiredEnv("GOOGLE_RTDN_VERIFICATION_TOKEN");
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const serviceKeySource = selectedServiceKeySource();
  const serviceKey = serviceKeySource == null
    ? null
    : requiredEnv(serviceKeySource);
  if (
    !oidcAudience || !allowedEmail || !verificationToken || !supabaseUrl ||
    !serviceKey || !hasGoogleServiceAccountConfiguration()
  ) {
    return json({ error: "webhook_configuration_error" }, 500);
  }

  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const { payload } = await jwtVerify(
      authHeader.slice("Bearer ".length),
      googleOidcJwks,
      {
        audience: oidcAudience,
        issuer: ["https://accounts.google.com", "accounts.google.com"],
        algorithms: ["RS256"],
        maxTokenAge: "10m",
        clockTolerance: "30s",
      },
    );
    if (payload.email !== allowedEmail || payload.email_verified !== true) {
      return json({ error: "forbidden" }, 403);
    }
  } catch {
    return json({ error: "unauthorized" }, 401);
  }

  const requestToken = new URL(req.url).searchParams.get("token");
  if (!requestToken || !constantTimeEqual(requestToken, verificationToken)) {
    return json({ error: "forbidden" }, 403);
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let body: PubSubPushBody;
  try {
    body = await req.json();
  } catch (error) {
    console.error("webhook_parse_failed", { error: safeErrorMessage(error) });
    return json({ error: "invalid_json" }, 400);
  }

  const message = body.message;
  const notificationId = message?.messageId ?? message?.message_id;
  if (!message?.data || !notificationId) {
    console.error("webhook_parse_failed", { error: "invalid_pubsub_message" });
    return json({ error: "invalid_pubsub_message" }, 400);
  }

  let payload: RtdnPayload;
  try {
    payload = JSON.parse(base64Decode(message.data));
  } catch (error) {
    console.error("webhook_parse_failed", { error: safeErrorMessage(error) });
    return json({ error: "invalid_pubsub_data" }, 400);
  }

  const packageName =
    Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || defaultPackageName;
  if (payload.packageName !== packageName) {
    console.error("unsupported_notification_type", {
      product_id: null,
      notification_type: "package_mismatch",
    });
    return json({ ok: true, ignored: "package_mismatch" });
  }

  const notification = payload.subscriptionNotification;
  if (!notification) {
    console.error("unsupported_notification_type", {
      product_id: null,
      notification_type: "non_subscription",
    });
    return json({ ok: true, ignored: "non_subscription_notification" });
  }

  const productId = notification.subscriptionId;
  const purchaseToken = notification.purchaseToken;
  const notificationType = notification.notificationType;
  if (productId !== businessPlusProductId || !purchaseToken) {
    console.error("unsupported_notification_type", {
      product_id: productId ?? null,
      notification_type: notificationType ?? null,
    });
    return json({ ok: true, ignored: "unsupported_subscription" });
  }

  const duplicate = await isDuplicateNotification(
    serviceClient,
    notificationId,
  );
  if (duplicate) {
    console.error("rtdn_duplicate_ignored", {
      product_id: productId,
      notification_type: notificationType ?? null,
    });
    return json({ ok: true, duplicate: true });
  }

  const subscriptionId = await subscriptionIdForPurchaseToken(
    serviceClient,
    purchaseToken,
  );
  if (!subscriptionId) {
    await recordNotification(serviceClient, notificationId);
    return json({ ok: true, ignored: "subscription_not_found" });
  }

  const subscription = await fetchSubscription(serviceClient, subscriptionId);
  if (!subscription) {
    await recordNotification(serviceClient, notificationId);
    return json({ ok: true, ignored: "subscription_not_found" });
  }

  let result;
  try {
    result = await reconcileGooglePlayToken({
      serviceClient,
      purchaseToken,
      productId,
      businessId: subscription.business_account_id,
      ownerUserId: subscription.owner_user_id,
      notificationId,
      notificationType,
    });
  } catch (error) {
    console.error("rtdn_processing_failed", {
      business_id: subscription.business_account_id,
      product_id: productId,
      message_id: notificationId,
      error: safeErrorMessage(error),
    });
    return json({ error: "rtdn_processing_failed" }, 500);
  }

  await recordNotification(serviceClient, notificationId);
  return json({ ok: true, ...result });
});

async function isDuplicateNotification(
  serviceClient: any,
  notificationId: string,
): Promise<boolean> {
  const { data } = await serviceClient
    .schema("private")
    .from("processed_webhook_notifications")
    .select("notification_id")
    .eq("notification_id", notificationId)
    .maybeSingle();
  return data != null;
}

async function recordNotification(serviceClient: any, notificationId: string) {
  await serviceClient
    .schema("private")
    .from("processed_webhook_notifications")
    .upsert(
      { notification_id: notificationId, store: "google_play" },
      { onConflict: "notification_id", ignoreDuplicates: true },
    );
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
): Promise<SubscriptionRow | null> {
  const { data, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select("id,business_account_id,owner_user_id")
    .eq("id", subscriptionId)
    .maybeSingle();
  if (error) throw error;
  return data as SubscriptionRow | null;
}

async function reconcileGooglePlayToken({
  serviceClient,
  purchaseToken,
  productId,
  businessId,
  ownerUserId,
  notificationId,
  notificationType,
}: {
  serviceClient: any;
  purchaseToken: string;
  productId: string;
  businessId: string;
  ownerUserId: string;
  notificationId?: string;
  notificationType?: number;
}) {
  const tokenHash = await sha256Hex(purchaseToken);
  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.error("google_auth_failed", {
      product_id: productId,
      notification_type: notificationType ?? null,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  let googlePurchase: GoogleSubscriptionPurchase;
  try {
    googlePurchase = await getGoogleSubscription({ accessToken, purchaseToken });
  } catch (error) {
    if (safeErrorMessage(error) === "google_subscription_not_found") {
      await persistInactiveWebhook({
        serviceClient,
        businessId,
        ownerUserId,
        productId,
        tokenHash,
        purchaseToken,
        rawPayload: { google_purchase_missing: true },
      });
      return {
        reconciled: true,
        ...(await storedSubscriptionState(
          serviceClient,
          businessId,
          ownerUserId,
          tokenHash,
        )),
      };
    }
    console.error("google_verification_failed", {
      product_id: productId,
      notification_type: notificationType ?? null,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  const lineItem = findBusinessPlusLineItem(googlePurchase, productId);
  if (!lineItem) {
    await persistInactiveWebhook({
      serviceClient,
      businessId,
      ownerUserId,
      productId,
      tokenHash,
      purchaseToken,
      rawPayload: { malformed_product_response: true },
    });
    return {
      reconciled: true,
      ...(await storedSubscriptionState(
        serviceClient,
        businessId,
        ownerUserId,
        tokenHash,
      )),
    };
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
  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: businessId,
      p_owner_user_id: ownerUserId,
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
      p_purchase_token: purchaseToken,
      p_raw_payload: {
        google_subscription: sanitizedGooglePurchase(googlePurchase),
        latest_notification_identity: notificationId ?? null,
        notification_type: notificationType ?? null,
      },
    },
  );
  if (error) {
    console.error("subscription_sync_failed", {
      product_id: productId,
      notification_type: notificationType ?? null,
      subscription_state: subscriptionState,
      entitlement_status: sync.candidateEntitlementStatus,
      business_id: businessId,
      error: error.message,
    });
    throw error;
  }

  const stored = await storedSubscriptionState(
    serviceClient,
    businessId,
    ownerUserId,
    tokenHash,
  );
  if (
    googlePurchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
    stored.active &&
    ["active", "cancelled", "grace_period"].includes(stored.entitlement_status) &&
    isFutureTimestamp(stored.ends_at ?? stored.current_period_end)
  ) {
    await acknowledgeGoogleSubscription({
      accessToken,
      productId,
      purchaseToken,
    });
  }

  return {
    reconciled: true,
    active: stored.active,
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
  const response = await fetch(googleTokenUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!response.ok) throw new Error("google_token_failed");
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
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404 || response.status === 410) {
    throw new Error("google_subscription_not_found");
  }
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

function requiredEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value ? value : null;
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

async function storedSubscriptionState(
  serviceClient: any,
  businessId: string,
  ownerUserId: string,
  purchaseIdentityHash: string,
) {
  const { data: active, error: activeError } = await serviceClient.rpc(
    "check_business_plus_active",
    { p_business_account_id: businessId },
  );
  const { data, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select(
      "entitlement_status,store_subscription_status,current_period_end,ends_at,auto_renew_enabled",
    )
    .eq("business_account_id", businessId)
    .eq("owner_user_id", ownerUserId)
    .eq("store", "google_play")
    .eq("external_purchase_identity_hash", purchaseIdentityHash)
    .maybeSingle();
  if (activeError || typeof active !== "boolean" || error || !data) {
    throw new Error("stored_subscription_read_failed");
  }
  return { active, ...data };
}

async function persistInactiveWebhook({
  serviceClient,
  businessId,
  ownerUserId,
  productId,
  tokenHash,
  purchaseToken,
  rawPayload,
}: {
  serviceClient: any;
  businessId: string;
  ownerUserId: string;
  productId: string;
  tokenHash: string;
  purchaseToken: string;
  rawPayload: Record<string, unknown>;
}) {
  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: businessId,
      p_owner_user_id: ownerUserId,
      p_store: "google_play",
      p_product_id: productId,
      p_base_plan_id: null,
      p_original_transaction_id: null,
      p_external_purchase_identity_hash: tokenHash,
      p_store_subscription_status: "unknown",
      p_entitlement_status: "expired",
      p_purchase_time: null,
      p_current_period_start: null,
      p_current_period_end: null,
      p_auto_renew_enabled: false,
      p_cancellation_time: null,
      p_grace_period_end: null,
      p_revocation_time: null,
      p_environment: null,
      p_purchase_context_id: null,
      p_purchase_token: purchaseToken,
      p_raw_payload: rawPayload,
    },
  );
  if (error) throw error;
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
  const packageName =
    Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || defaultPackageName;
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

function base64Decode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - normalized.length % 4) % 4),
    "=",
  );
  return new TextDecoder().decode(
    Uint8Array.from(atob(padded), (char) => char.charCodeAt(0)),
  );
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
