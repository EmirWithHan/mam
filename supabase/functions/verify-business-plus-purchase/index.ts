import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseGoogleBusinessPlusEntitlement } from "../_shared/business_plus_entitlement.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const androidPublisherScope =
  "https://www.googleapis.com/auth/androidpublisher";
const googleTokenUrl = "https://oauth2.googleapis.com/token";
const businessPlusProductId = "business_plus_monthly";
const defaultPackageName = "com.matchaman.app";

type VerifyRequest = {
  business_id?: string;
  product_id?: string;
  purchase_token?: string;
  purchase_id?: string;
  verification_source?: string;
  is_restored?: boolean;
  pending_complete_purchase?: boolean;
  platform?: string;
};

type GoogleLineItem = {
  productId?: string;
  expiryTime?: string;
  latestSuccessfulOrderId?: string;
  autoRenewingPlan?: {
    autoRenewEnabled?: boolean;
  };
  offerDetails?: {
    basePlanId?: string;
  };
};

type GoogleSubscriptionPurchase = {
  startTime?: string;
  subscriptionState?: string;
  latestOrderId?: string;
  linkedPurchaseToken?: string;
  acknowledgementState?: string;
  testPurchase?: unknown;
  lineItems?: GoogleLineItem[];
  canceledStateContext?: Record<string, unknown>;
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
  const { data: userData, error: userError } =
    await userClient.auth.getUser();
  const user = userData.user;
  if (userError || !user) {
    return json({ error: "unauthorized" }, 401);
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: VerifyRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const businessId = body.business_id?.trim();
  const productId = body.product_id?.trim();
  const purchaseToken = body.purchase_token?.trim();
  const platform = body.platform?.trim();
  if (!businessId || !productId || !purchaseToken || !platform) {
    return json({ error: "missing_required_fields" }, 400);
  }
  if (platform !== "android") {
    return json({ error: "unsupported_platform" }, 400);
  }
  if (productId !== businessPlusProductId) {
    return json({ error: "invalid_product" }, 400);
  }

  const { data: business, error: businessError } = await serviceClient
    .from("business_accounts")
    .select("id,owner_user_id")
    .eq("id", businessId)
    .maybeSingle();
  if (businessError) {
    console.error("business_lookup_failed", {
      business_id: businessId,
      product_id: productId,
      platform,
      error: businessError.message,
    });
    return json({ error: "business_lookup_failed" }, 500);
  }
  if (!business || business.owner_user_id !== user.id) {
    return json({ error: "forbidden_business_owner" }, 403);
  }

  let accessToken: string;
  try {
    accessToken = await googleAccessToken();
  } catch (error) {
    console.error("google_auth_failed", {
      business_id: businessId,
      product_id: productId,
      platform,
      error: safeErrorMessage(error),
    });
    return json({ error: "google_auth_failed" }, 500);
  }

  const packageName =
    Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || defaultPackageName;

  let googlePurchase: GoogleSubscriptionPurchase;
  try {
    googlePurchase = await getGoogleSubscription({
      accessToken,
      packageName,
      purchaseToken,
    });
  } catch (error) {
    console.error("google_verification_failed", {
      business_id: businessId,
      product_id: productId,
      platform,
      error: safeErrorMessage(error),
    });
    return json({ error: "google_verification_failed" }, 502);
  }

  const lineItem = findBusinessPlusLineItem(googlePurchase, productId);
  if (!lineItem) {
    return json({ error: "google_product_mismatch" }, 400);
  }

  const parsedEntitlement = parseGoogleBusinessPlusEntitlement({
    subscriptionState: googlePurchase.subscriptionState,
    expiryTime: lineItem.expiryTime,
    gracePeriodExpiryTime: lineItem.expiryTime,
    canceledStateContext: googlePurchase.canceledStateContext,
    autoRenewEnabled: lineItem.autoRenewingPlan?.autoRenewEnabled,
    purchaseTime: googlePurchase.startTime,
  });
  const subscriptionState = parsedEntitlement.rawStoreState;

  let acknowledged = googlePurchase.acknowledgementState ===
    "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
  const tokenHash = await sha256Hex(purchaseToken);
  const environment = googlePurchase.testPurchase ? "sandbox" : "production";


  const { error: upsertError } = await serviceClient.rpc(
    "service_verify_and_upsert_subscription",
    {
      p_business_account_id: businessId,
      p_owner_user_id: user.id,
      p_store: "google_play",
      p_product_id: productId,
      p_base_plan_id: lineItem.offerDetails?.basePlanId ?? null,
      p_original_transaction_id:
        googlePurchase.linkedPurchaseToken ??
        lineItem.latestSuccessfulOrderId ??
        googlePurchase.latestOrderId ??
        body.purchase_id ??
        null,
      p_external_purchase_identity_hash: tokenHash,
      p_store_subscription_status: subscriptionState,
      p_entitlement_status: parsedEntitlement.candidateEntitlementStatus,
      p_purchase_time: parsedEntitlement.purchaseTime,
      p_current_period_start: parsedEntitlement.purchaseTime,
      p_current_period_end: parsedEntitlement.currentPeriodEnd,
      p_auto_renew_enabled: parsedEntitlement.autoRenewEnabled,
      p_cancellation_time: parsedEntitlement.cancellationTime,
      p_grace_period_end: parsedEntitlement.gracePeriodEnd,
      p_revocation_time: parsedEntitlement.revocationTime,
      p_environment: environment,
      p_purchase_context_id: null,
      p_purchase_token: purchaseToken,
      p_raw_payload: {
        google_subscription: sanitizedGooglePurchase(googlePurchase),
        client_purchase_id: body.purchase_id ?? null,
        verification_source: body.verification_source ?? null,
        is_restored: body.is_restored === true,
        pending_complete_purchase: body.pending_complete_purchase === true,
        acknowledged,
      },
    },
  );
  if (upsertError) {
    console.error("subscription_sync_failed", {
      business_id: businessId,
      product_id: productId,
      platform,
      subscription_state: subscriptionState,
      entitlement_status: parsedEntitlement.candidateEntitlementStatus,
      error: upsertError.message,
    });
    return json({ error: "subscription_sync_failed" }, 500);
  }

  const { data: active, error: activeError } = await serviceClient.rpc(
    "check_business_plus_active",
    { p_business_account_id: businessId },
  );
  if (activeError || typeof active !== "boolean") {
    console.error("subscription_active_check_failed", {
      business_id: businessId,
      product_id: productId,
      error: activeError?.message ?? "invalid_active_result",
    });
    return json({ error: "subscription_active_check_failed" }, 500);
  }

  const { data: storedSubscription, error: storedError } = await serviceClient
    .from("business_plus_subscriptions")
    .select(
      "entitlement_status,store_subscription_status,current_period_end,ends_at,auto_renew_enabled",
    )
    .eq("business_account_id", businessId)
    .eq("owner_user_id", user.id)
    .eq("store", "google_play")
    .eq("external_purchase_identity_hash", tokenHash)
    .maybeSingle();
  if (storedError || !storedSubscription) {
    console.error("stored_subscription_read_failed", {
      business_id: businessId,
      product_id: productId,
      error: storedError?.message ?? "stored_subscription_missing",
    });
    return json({ error: "stored_subscription_read_failed" }, 500);
  }
  const stored = storedSubscription as StoredSubscription;
  const storedExpiry = stored.ends_at ?? stored.current_period_end;
  const storedExpiryMs = storedExpiry == null
    ? Number.NaN
    : Date.parse(storedExpiry);
  const acknowledgementEligible = active &&
    ["active", "cancelled", "grace_period"].includes(
      stored.entitlement_status,
    ) && Number.isFinite(storedExpiryMs) && storedExpiryMs > Date.now();

  if (
    acknowledgementEligible &&
    googlePurchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING"
  ) {
    try {
      await acknowledgeGoogleSubscription({
        accessToken,
        packageName,
        productId,
        purchaseToken,
      });
      acknowledged = true;
    } catch (error) {
      console.error("google_acknowledgement_failed", {
        business_id: businessId,
        product_id: productId,
        platform,
        subscription_state: subscriptionState,
        entitlement_status: stored.entitlement_status,
        error: safeErrorMessage(error),
      });
      return json({ error: "google_acknowledgement_failed" }, 502);
    }
  }

  return json({
    verified: true,
    active,
    entitlement_status: stored.entitlement_status,
    subscription_state: stored.store_subscription_status,
    current_period_end: stored.current_period_end ?? stored.ends_at,
    auto_renew_enabled: stored.auto_renew_enabled,
    acknowledged,
    message: active
      ? "Business Plus aktif edildi."
      : "Satın alma doğrulandı ancak abonelik aktif görünmüyor.",
  });
});

async function googleAccessToken(): Promise<string> {
  const serviceAccount = serviceAccountCredentials();
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signedJwt(
    {
      alg: "RS256",
      typ: "JWT",
    },
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

async function getGoogleSubscription({
  accessToken,
  packageName,
  purchaseToken,
}: {
  accessToken: string;
  packageName: string;
  purchaseToken: string;
}): Promise<GoogleSubscriptionPurchase> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) throw new Error("google_subscription_get_failed");
  return await response.json();
}

async function acknowledgeGoogleSubscription({
  accessToken,
  packageName,
  productId,
  purchaseToken,
}: {
  accessToken: string;
  packageName: string;
  productId: string;
  purchaseToken: string;
}) {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }:acknowledge`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: "{}",
  });
  if (!response.ok) throw new Error("google_subscription_ack_failed");
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

function safeErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function sanitizedGooglePurchase(
  purchase: GoogleSubscriptionPurchase,
): Record<string, unknown> {
  const copy = { ...purchase } as Record<string, unknown>;
  delete copy.subscribeWithGoogleInfo;
  return copy;
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

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}


