import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ClaimRow = {
  request_id: string;
  subject_user_id: string;
  deletion_deadline_at: string;
  attempt_count: number;
  storage_deleted_at: string | null;
  data_finalized_at: string | null;
  auth_deleted_at: string | null;
};

type StorageObjectRow = {
  bucket_id: string;
  object_name: string;
};

type ProcessResult = {
  completed: number;
  retryableFailed: number;
  terminalFailed: number;
  storageObjectsDeleted: number;
  authUsersDeleted: number;
};

const emptyResult = (): ProcessResult => ({
  completed: 0,
  retryableFailed: 0,
  terminalFailed: 0,
  storageObjectsDeleted: 0,
  authUsersDeleted: 0,
});

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const workerSecret = Deno.env.get("ACCOUNT_DELETION_WORKER_SECRET")?.trim();
  const suppliedSecret = req.headers
    .get("x-account-deletion-worker-secret")
    ?.trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKeySource = selectedServiceKeySource();
  const serviceKey = serviceKeySource == null
    ? null
    : Deno.env.get(serviceKeySource)?.trim();

  if (!workerSecret || !supabaseUrl || !serviceKey) {
    return json({ error: "configuration_error" }, 500);
  }
  if (!suppliedSecret || !constantTimeEqual(suppliedSecret, workerSecret)) {
    return json({ error: "unauthorized" }, 401);
  }

  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  const limit = await requestLimit(req);
  if (limit == null) {
    return json({ error: "invalid_request" }, 400);
  }

  const workerId = `account-deletion-${crypto.randomUUID()}`;
  const { data: claimedData, error: claimError } = await serviceClient.rpc(
    "service_claim_account_deletion_requests",
    { p_limit: limit, p_worker_id: workerId },
  );
  if (claimError) {
    return json({ error: "claim_failed" }, 500);
  }

  const claimed = (claimedData ?? []) as ClaimRow[];
  const results: ProcessResult[] = [];
  for (let index = 0; index < claimed.length; index += 2) {
    const slice = claimed.slice(index, index + 2);
    const settled = await Promise.allSettled(
      slice.map((row) => processClaimSafely(
        serviceClient,
        row,
        workerId,
      )),
    );
    for (const item of settled) {
      results.push(
        item.status === "fulfilled"
          ? item.value
          : { ...emptyResult(), retryableFailed: 1 },
      );
    }
  }

  const totals = results.reduce((total, result) => ({
    completed: total.completed + result.completed,
    retryableFailed: total.retryableFailed + result.retryableFailed,
    terminalFailed: total.terminalFailed + result.terminalFailed,
    storageObjectsDeleted:
      total.storageObjectsDeleted + result.storageObjectsDeleted,
    authUsersDeleted: total.authUsersDeleted + result.authUsersDeleted,
  }), emptyResult());
  const overdue = claimed.filter((row) =>
    Date.parse(row.deletion_deadline_at) <= Date.now()
  ).length;

  return json({
    selected: claimed.length,
    processed: results.length,
    completed: totals.completed,
    retryable_failed: totals.retryableFailed,
    terminal_failed: totals.terminalFailed,
    storage_objects_deleted: totals.storageObjectsDeleted,
    auth_users_deleted: totals.authUsersDeleted,
    overdue,
    continuation_needed: claimed.length === limit,
  });
});

async function processClaimSafely(
  serviceClient: ReturnType<typeof createClient>,
  claim: ClaimRow,
  workerId: string,
): Promise<ProcessResult> {
  try {
    return await processClaim(serviceClient, claim, workerId);
  } catch {
    await recordFailure(
      serviceClient,
      claim,
      workerId,
      "unexpected_worker_failure",
      false,
    );
    return { ...emptyResult(), retryableFailed: 1 };
  }
}

async function processClaim(
  serviceClient: ReturnType<typeof createClient>,
  claim: ClaimRow,
  workerId: string,
): Promise<ProcessResult> {
  const result = emptyResult();

  if (claim.storage_deleted_at == null) {
    let storageEmpty = false;
    for (let iteration = 0; iteration < 100; iteration++) {
      const { data: objectData, error: objectError } = await serviceClient.rpc(
        "service_list_account_deletion_storage_objects",
        {
          p_request_id: claim.request_id,
          p_subject_user_id: claim.subject_user_id,
          p_worker_id: workerId,
          p_limit: 500,
        },
      );
      if (objectError) {
        await recordFailure(
          serviceClient,
          claim,
          workerId,
          "storage_list_failed",
          false,
        );
        result.retryableFailed = 1;
        return result;
      }

      const objects = (objectData ?? []) as StorageObjectRow[];
      if (objects.length === 0) {
        storageEmpty = true;
        break;
      }

      const grouped = new Map<string, string[]>();
      for (const objectRow of objects) {
        const paths = grouped.get(objectRow.bucket_id) ?? [];
        paths.push(objectRow.object_name);
        grouped.set(objectRow.bucket_id, paths);
      }

      for (const [bucket, paths] of grouped) {
        for (let index = 0; index < paths.length; index += 100) {
          const chunk = paths.slice(index, index + 100);
          const { error } = await serviceClient.storage.from(bucket).remove(
            chunk,
          );
          if (error) {
            await recordFailure(
              serviceClient,
              claim,
              workerId,
              "storage_delete_failed",
              false,
            );
            result.retryableFailed = 1;
            return result;
          }
          result.storageObjectsDeleted += chunk.length;
        }
      }
    }

    if (!storageEmpty) {
      await recordFailure(
        serviceClient,
        claim,
        workerId,
        "storage_objects_remaining",
        false,
      );
      result.retryableFailed = 1;
      return result;
    }

    const { data: storageComplete, error: storageCompleteError } =
      await serviceClient.rpc(
        "service_mark_account_deletion_storage_complete",
        {
          p_request_id: claim.request_id,
          p_subject_user_id: claim.subject_user_id,
          p_worker_id: workerId,
        },
      );
    if (storageCompleteError || storageComplete !== true) {
      await recordFailure(
        serviceClient,
        claim,
        workerId,
        "storage_objects_remaining",
        false,
      );
      result.retryableFailed = 1;
      return result;
    }
  }

  if (claim.data_finalized_at == null) {
    const { error: finalizationError } = await serviceClient.rpc(
      "service_finalize_account_deletion_data",
      {
        p_request_id: claim.request_id,
        p_subject_user_id: claim.subject_user_id,
        p_worker_id: workerId,
      },
    );
    if (finalizationError) {
      await recordFailure(
        serviceClient,
        claim,
        workerId,
        "data_finalization_failed",
        false,
      );
      result.retryableFailed = 1;
      return result;
    }
  }

  if (claim.auth_deleted_at == null) {
    const { data: userData, error: lookupError } =
      await serviceClient.auth.admin.getUserById(claim.subject_user_id);
    if (lookupError && !isMissingAuthUser(lookupError)) {
      await recordFailure(
        serviceClient,
        claim,
        workerId,
        "auth_user_lookup_failed",
        false,
      );
      result.retryableFailed = 1;
      return result;
    }

    if (userData?.user) {
      const { error: deleteError } = await serviceClient.auth.admin.deleteUser(
        claim.subject_user_id,
        false,
      );
      if (deleteError) {
        await recordFailure(
          serviceClient,
          claim,
          workerId,
          "auth_delete_failed",
          false,
        );
        result.retryableFailed = 1;
        return result;
      }
      result.authUsersDeleted = 1;
    }

    const { data: authComplete, error: authCompleteError } =
      await serviceClient.rpc(
        "service_mark_account_deletion_auth_complete",
        {
          p_request_id: claim.request_id,
          p_subject_user_id: claim.subject_user_id,
          p_worker_id: workerId,
        },
      );
    if (authCompleteError || authComplete !== true) {
      await recordFailure(
        serviceClient,
        claim,
        workerId,
        "completion_failed",
        false,
      );
      result.retryableFailed = 1;
      return result;
    }
  }

  const { data: completed, error: completionError } = await serviceClient.rpc(
    "service_complete_account_deletion",
    {
      p_request_id: claim.request_id,
      p_subject_user_id: claim.subject_user_id,
      p_worker_id: workerId,
    },
  );
  if (completionError || completed !== true) {
    await recordFailure(
      serviceClient,
      claim,
      workerId,
      "completion_failed",
      false,
    );
    result.retryableFailed = 1;
    return result;
  }

  result.completed = 1;
  return result;
}

async function recordFailure(
  serviceClient: ReturnType<typeof createClient>,
  claim: ClaimRow,
  workerId: string,
  errorCode: string,
  terminal: boolean,
): Promise<void> {
  try {
    await serviceClient.rpc("service_record_account_deletion_failure", {
      p_request_id: claim.request_id,
      p_subject_user_id: claim.subject_user_id,
      p_worker_id: workerId,
      p_error_code: errorCode,
      p_terminal: terminal,
    });
  } catch {
    // Stale-lock recovery is the final fallback.
  }
}

async function requestLimit(req: Request): Promise<number | null> {
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const rawLimit = body.limit ?? 10;
  if (
    typeof rawLimit !== "number" || !Number.isFinite(rawLimit) ||
    !Number.isInteger(rawLimit) || rawLimit < 1 || rawLimit > 20
  ) {
    return null;
  }
  return rawLimit;
}

function isMissingAuthUser(error: { status?: number; code?: string }): boolean {
  return error.status === 404 || error.code === "user_not_found";
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

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
