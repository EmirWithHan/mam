import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type OutboxRow = {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  entity_type: string | null;
  entity_id: string | null;
  metadata: Record<string, unknown>;
  attempts: number;
};

type PushTokenRow = {
  token: string;
  platform: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-worker-secret",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const workerServiceKey = Deno.env.get("MAM_SUPABASE_SERVICE_KEY")?.trim();
  const projectId = Deno.env.get("FCM_PROJECT_ID");
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FCM_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  const workerSecret = Deno.env.get("PUSH_WORKER_SECRET")?.trim();

  if (!workerSecret) {
    return json({ error: "missing_worker_secret" }, 500);
  }
  const suppliedSecret = req.headers.get("x-worker-secret")?.trim();
  if (!suppliedSecret || !constantTimeEqual(suppliedSecret, workerSecret)) {
    return json({ error: "unauthorized_worker" }, 401);
  }

  const mode = await requestMode(req);
  if (!supabaseUrl || !workerServiceKey) {
    const response = {
      ok: false,
      error: "missing_worker_service_key",
      message: "MAM_SUPABASE_SERVICE_KEY is required",
    };
    return json(response, 500);
  }

  if (isPublishableKey(workerServiceKey)) {
    return json(
      {
        ok: false,
        error: "invalid_worker_service_key",
        message: "MAM_SUPABASE_SERVICE_KEY must be a server-side service/secret key",
      },
      500,
    );
  }

  const supabase = createWorkerSupabaseClient(supabaseUrl, workerServiceKey);
  if (mode === "self_test") {
    return await selfTest({
      supabase,
      env: envStatus({
        supabaseUrl,
        workerServiceKey,
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }

  if (!projectId || !clientEmail || !privateKey) {
    return json({ error: "missing_fcm_secrets" }, 500);
  }

  let accessToken: string;
  try {
    accessToken = await fcmAccessToken({
      clientEmail,
      privateKey,
    });
  } catch {
    return json({ error: "fcm_access_token_failed" }, 500);
  }

  const { data: rows, error } = await supabase.rpc(
    "service_claim_push_notification_outbox",
    { p_limit: 25 },
  );
  if (error) {
    return json(
      { error: "outbox_claim_failed", detail: safeError(error.message) },
      500,
    );
  }

  let sent = 0;
  let skipped = 0;
  let failed = 0;

  if (!rows || rows.length === 0) {
    return json({ ok: true, processed: 0, sent, skipped, failed });
  }

  for (const row of (rows ?? []) as OutboxRow[]) {
    const { data: tokens, error: tokenError } = await supabase
      .from("user_push_tokens")
      .select("token,platform")
      .eq("user_id", row.recipient_id);

    if (tokenError) {
      failed += 1;
      await markFailed(supabase, row.id, safeError(tokenError.message));
      continue;
    }

    const activeTokens = ((tokens ?? []) as PushTokenRow[]).filter((item) =>
      item.token.trim().length > 0
    );
    if (activeTokens.length === 0) {
      skipped += 1;
      await supabase
        .from("push_notification_outbox")
        .update({
          status: "skipped",
          last_error: "no_push_tokens",
          updated_at: new Date().toISOString(),
        })
        .eq("id", row.id)
        .eq("status", "processing");
      continue;
    }

    const responses = await Promise.allSettled(
      activeTokens.map((item) =>
        sendFcm({
          accessToken,
          projectId,
          token: item.token,
          title: row.title,
          body: row.body,
          data: {
            entity_type: row.entity_type ?? "",
            entity_id: row.entity_id ?? "",
            notification_id: row.id,
          },
        })
      ),
    );

    const anySent = responses.some((item) => item.status === "fulfilled");
    if (anySent) {
      sent += 1;
      await supabase
        .from("push_notification_outbox")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          last_error: null,
        })
        .eq("id", row.id)
        .eq("status", "processing");
      continue;
    }

    failed += 1;
    await markFailed(supabase, row.id, "fcm_send_failed");
  }

  return json({ ok: true, processed: rows?.length ?? 0, sent, skipped, failed });
});

function createWorkerSupabaseClient(supabaseUrl: string, serverKey: string) {
  return createClient(supabaseUrl, serverKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        apikey: serverKey,
        Authorization: `Bearer ${serverKey}`,
      },
    },
  });
}

function envStatus({
  supabaseUrl,
  workerServiceKey,
  projectId,
  clientEmail,
  privateKey,
}: {
  supabaseUrl: string | undefined;
  workerServiceKey: string | undefined;
  projectId: string | undefined;
  clientEmail: string | undefined;
  privateKey: string | undefined;
}): Record<string, boolean> {
  return {
    supabaseUrl: Boolean(supabaseUrl),
    mamSupabaseServiceKey: Boolean(workerServiceKey),
    fcmProjectId: Boolean(projectId),
    fcmClientEmail: Boolean(clientEmail),
    fcmPrivateKey: Boolean(privateKey),
  };
}

function isPublishableKey(value: string): boolean {
  const normalized = value.trim().toLowerCase();
  return normalized.startsWith("sb_publishable_") ||
    normalized.includes("anon");
}

async function requestMode(req: Request): Promise<string | undefined> {
  if (req.method !== "POST") return undefined;
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) return undefined;

  try {
    const body = await req.clone().json() as { mode?: unknown };
    return typeof body.mode === "string" ? body.mode : undefined;
  } catch {
    return undefined;
  }
}

async function selfTest({
  supabase,
  env,
}: {
  supabase: ReturnType<typeof createWorkerSupabaseClient>;
  env: Record<string, boolean>;
}): Promise<Response> {
  const { error } = await supabase
    .from("push_notification_outbox")
    .select("id")
    .limit(1);
  const dbReadable = !error;

  return json(
    {
      ok: dbReadable,
      mode: "self_test",
      selectedKeySource: "MAM_SUPABASE_SERVICE_KEY",
      env,
      dbReadable,
      ...(error ? { dbError: safeError(error.message) } : {}),
    },
    dbReadable ? 200 : 500,
  );
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function safeError(message: string): string {
  return message.length > 160 ? `${message.slice(0, 157)}...` : message;
}

async function markFailed(
  supabase: ReturnType<typeof createClient>,
  id: string,
  message: string,
) {
  await supabase
    .from("push_notification_outbox")
    .update({
      status: "failed",
      last_error: message,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "processing");
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

async function sendFcm({
  accessToken,
  projectId,
  token,
  title,
  body,
  data,
}: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }
}

async function fcmAccessToken({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64Url(header)}.${base64Url(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(await response.text());
  }
  const json = await response.json();
  return json.access_token as string;
}

function base64Url(value: unknown): string {
  const bytes = value instanceof ArrayBuffer
    ? new Uint8Array(value)
    : new TextEncoder().encode(JSON.stringify(value));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
