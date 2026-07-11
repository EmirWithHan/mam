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
};

type SubscriptionRow = {
  id: string;
  business_account_id: string;
  owner_user_id: string;
  product_id: string | null;
  base_plan_id?: string | null;
  original_transaction_id?: string | null;
  external_purchase_identity_hash: string;
  purchase_time?: string | null;
  current_period_start?: string | null;
  environment?: string | null;
  updated_at?: string;
  entitlement_status?: string;
  current_period_end?: string;
  store_subscription_status?: string;
  auto_renew_enabled?: boolean;
};

type StoredSubscription = {
  entitlement_status: string;
  store_subscription_status: string | null;
  current_period_end: string | null;
  ends_at: string | null;
  auto_renew_enabled: boolean;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKeySource = selectedServiceKeySource();
  const serviceKey = serviceKeySource == null
    ? undefined
    : Deno.env.get(serviceKeySource);
  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error("missing_supabase_secrets", {
      has_supabase_url: Boolean(supabaseUrl),
      has_anon_key: Boolean(anonKey),
      has_service_key: Boolean(serviceKey),
      service_key_source: serviceKeySource,
    });
    return json({ error: "missing_supabase_secrets" }, 500);
  }
  console.log("service_key_source", { source: serviceKeySource });

  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    return json({ error: "unauthorized" }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;
  if (userError || !user) {
    return json({ error: "unauthorized" }, 401);
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: business, error: businessError } = await serviceClient
    .from("business_accounts")
    .select("id,owner_user_id")
    .eq("owner_user_id", user.id)
    .in("status", ["active", "pending"])
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (businessError) {
    console.error("business_lookup_failed", {
      error: businessError.message,
    });
    return json({ error: "business_lookup_failed" }, 500);
  }
  if (!business) {
    return noSubscriptionResponse();
  }

  const { data: subscription, error: subscriptionError } = await serviceClient
    .from("business_plus_subscriptions")
    .select(
      "id,business_account_id,owner_user_id,product_id,base_plan_id,original_transaction_id,external_purchase_identity_hash,purchase_time,current_period_start,environment,updated_at,entitlement_status,current_period_end,store_subscription_status,auto_renew_enabled",
    )
    .eq("business_account_id", business.id)
    .eq("owner_user_id", user.id)
    .eq("store", "google_play")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (subscriptionError) {
    console.error("subscription_lookup_failed", {
      business_id: business.id,
      product_id: businessPlusProductId,
      error: subscriptionError.message,
    });
    return json({ error: "subscription_lookup_failed" }, 500);
  }
  if (!subscription) {
    return noSubscriptionResponse(business.id);
  }

  if (
    subscription.owner_user_id !== user.id ||
    subscription.business_account_id !== business.id
  ) {
    return json({ error: "forbidden_subscription_owner" }, 403);
  }

  const { data: proof, error: proofError } = await serviceClient
    .schema("private")
    .from("business_plus_subscription_proofs")
    .select("purchase_token")
    .eq("subscription_id", subscription.id)
    .maybeSingle();
  if (proofError) {
    console.error("subscription_proof_lookup_failed", {
      business_id: business.id,
      product_id: subscription.product_id ?? businessPlusProductId,
      error: proofError.message,
    });
    return json({ error: "subscription_proof_lookup_failed" }, 500);
  }
  const purchaseToken = proof?.purchase_token?.toString().trim();
  if (!purchaseToken) {
    await persistInactiveSubscription({
      serviceClient,
      subscription,
      purchaseToken: null,
      rawPayload: { missing_purchase_proof: true, user_refresh: true },
    });
    const result = await databaseSubscriptionState(
      serviceClient,
      subscription,
      subscription.external_purchase_identity_hash,
    );
    return json({
      refreshed: true,
      active: result.active,
      entitlement_status: result.stored.entitlement_status,
      subscription_state: result.stored.store_subscription_status,
      current_period_end:
        result.stored.current_period_end ?? result.stored.ends_at,
      auto_renew_enabled: result.stored.auto_renew_enabled,
      message: "Business Plus aboneliğin aktif görünmüyor.",
    });
  }

  try {
    const result = await refreshGooglePlaySubscription({
      serviceClient,
      subscription,
      purchaseToken,
    });
    return json(result);
  } catch (error) {
    console.error("refresh_business_plus_failed", {
      business_id: business.id,
      product_id: subscription.product_id ?? businessPlusProductId,
      error: safeErrorMessage(error),
    });
    return json({ error: "refresh_business_plus_failed" }, 500);
  }
});

async function refreshGooglePlaySubscription({
  serviceClient,
  subscription,
  purchaseToken,
}: {
  serviceClient: any;
  subscription: SubscriptionRow;
  purchaseToken: string;
}) {
  const productId = subscription.product_id ?? businessPlusProductId;
  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.error("google_auth_failed", {
      business_id: subscription.business_account_id,
      product_id: productId,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  let googlePurchase: GoogleSubscriptionPurchase;
  try {
    googlePurchase = await getGoogleSubscription({ accessToken, purchaseToken });
  } catch (error) {
    if (safeErrorMessage(error) === "google_subscription_not_found") {
      await persistInactiveSubscription({
        serviceClient,
        subscription,
        purchaseToken,
        rawPayload: { google_purchase_missing: true, user_refresh: true },
      });
      const result = await databaseSubscriptionState(
        serviceClient,
        subscription,
        subscription.external_purchase_identity_hash,
      );
      return {
        refreshed: true,
        active: result.active,
        entitlement_status: result.stored.entitlement_status,
        subscription_state: result.stored.store_subscription_status,
        current_period_end:
          result.stored.current_period_end ?? result.stored.ends_at,
        auto_renew_enabled: result.stored.auto_renew_enabled,
        message: "Business Plus aboneliğin aktif görünmüyor.",
      };
    }
    console.error("google_verification_failed", {
      business_id: subscription.business_account_id,
      product_id: productId,
      error: safeErrorMessage(error),
    });
    throw error;
  }

  const lineItem = findBusinessPlusLineItem(googlePurchase, productId);
  if (!lineItem) {
    await persistInactiveSubscription({
      serviceClient,
      subscription,
      purchaseToken,
      rawPayload: {
        google_subscription: sanitizedGooglePurchase(googlePurchase),
        malformed_product_response: true,
        user_refresh: true,
      },
    });
    const result = await databaseSubscriptionState(
      serviceClient,
      subscription,
      subscription.external_purchase_identity_hash,
    );
    return {
      refreshed: true,
      active: result.active,
      entitlement_status: result.stored.entitlement_status,
      subscription_state: result.stored.store_subscription_status,
      current_period_end:
        result.stored.current_period_end ?? result.stored.ends_at,
      auto_renew_enabled: result.stored.auto_renew_enabled,
      message: "Business Plus aboneliğin aktif görünmüyor.",
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
  const tokenHash = await sha256Hex(purchaseToken);

  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: subscription.business_account_id,
      p_owner_user_id: subscription.owner_user_id,
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
        user_refresh: true,
      },
    },
  );
  if (error) {
    console.error("subscription_sync_failed", {
      business_id: subscription.business_account_id,
      product_id: productId,
      subscription_state: subscriptionState,
      entitlement_status: sync.candidateEntitlementStatus,
      error: error.message,
    });
    throw error;
  }

  const result = await databaseSubscriptionState(
    serviceClient,
    subscription,
    tokenHash,
  );

  return {
    refreshed: true,
    active: result.active,
    entitlement_status: result.stored.entitlement_status,
    subscription_state: result.stored.store_subscription_status,
    current_period_end:
      result.stored.current_period_end ?? result.stored.ends_at,
    auto_renew_enabled: result.stored.auto_renew_enabled,
    message: result.active
      ? "Business Plus durumu güncellendi."
      : "Business Plus aboneliğin aktif görünmüyor.",
  };
}

function noSubscriptionResponse(businessId?: string): Response {
  return json({
    refreshed: false,
    active: false,
    entitlement_status: null,
    subscription_state: null,
    current_period_end: null,
    auto_renew_enabled: null,
    message: businessId
      ? "Business Plus aboneliği bulunamadı."
      : "Business Plus için aktif bir işletme hesabı gerekir.",
  });
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

async function databaseActive(
  serviceClient: any,
  businessAccountId: string,
): Promise<boolean> {
  const { data, error } = await serviceClient.rpc(
    "check_business_plus_active",
    { p_business_account_id: businessAccountId },
  );
  if (error || typeof data !== "boolean") {
    throw new Error(error?.message ?? "invalid_active_result");
  }
  return data;
}

async function databaseSubscriptionState(
  serviceClient: any,
  subscription: SubscriptionRow,
  purchaseIdentityHash: string,
): Promise<{ active: boolean; stored: StoredSubscription }> {
  const active = await databaseActive(
    serviceClient,
    subscription.business_account_id,
  );
  const { data, error } = await serviceClient
    .from("business_plus_subscriptions")
    .select(
      "entitlement_status,store_subscription_status,current_period_end,ends_at,auto_renew_enabled",
    )
    .eq("business_account_id", subscription.business_account_id)
    .eq("owner_user_id", subscription.owner_user_id)
    .eq("store", "google_play")
    .eq("external_purchase_identity_hash", purchaseIdentityHash)
    .maybeSingle();
  if (error || !data) {
    throw new Error(error?.message ?? "stored_subscription_missing");
  }
  return { active, stored: data as StoredSubscription };
}

async function persistInactiveSubscription({
  serviceClient,
  subscription,
  purchaseToken,
  rawPayload,
}: {
  serviceClient: any;
  subscription: SubscriptionRow;
  purchaseToken: string | null;
  rawPayload: Record<string, unknown>;
}): Promise<void> {
  const { error } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: subscription.business_account_id,
      p_owner_user_id: subscription.owner_user_id,
      p_store: "google_play",
      p_product_id: subscription.product_id ?? businessPlusProductId,
      p_base_plan_id: subscription.base_plan_id ?? null,
      p_original_transaction_id: subscription.original_transaction_id ?? null,
      p_external_purchase_identity_hash:
        subscription.external_purchase_identity_hash,
      p_store_subscription_status: "unknown",
      p_entitlement_status: "expired",
      p_purchase_time: subscription.purchase_time ?? null,
      p_current_period_start: subscription.current_period_start ?? null,
      p_current_period_end: null,
      p_auto_renew_enabled: false,
      p_cancellation_time: null,
      p_grace_period_end: null,
      p_revocation_time: null,
      p_environment: subscription.environment ?? null,
      p_purchase_context_id: null,
      p_purchase_token: purchaseToken,
      p_raw_payload: rawPayload,
    },
  );
  if (error) throw error;
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
