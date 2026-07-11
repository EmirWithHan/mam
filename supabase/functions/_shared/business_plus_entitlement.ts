export type BusinessPlusCandidateStatus =
  | "active"
  | "cancelled"
  | "grace_period"
  | "billing_retry"
  | "paused"
  | "revoked"
  | "expired";

export type GoogleBusinessPlusEntitlementInput = {
  subscriptionState?: unknown;
  expiryTime?: unknown;
  gracePeriodExpiryTime?: unknown;
  canceledStateContext?: unknown;
  revocationTime?: unknown;
  autoRenewEnabled?: unknown;
  purchaseTime?: unknown;
};

export type ParsedGoogleBusinessPlusEntitlement = {
  rawStoreState: string;
  purchaseTime: string | null;
  currentPeriodEnd: string | null;
  gracePeriodEnd: string | null;
  cancellationTime: string | null;
  revocationTime: string | null;
  autoRenewEnabled: boolean;
  candidateEntitlementStatus: BusinessPlusCandidateStatus;
  isCandidateEntitled: boolean;
};

export function parseGoogleBusinessPlusEntitlement(
  input: GoogleBusinessPlusEntitlementInput,
  nowMs = Date.now(),
): ParsedGoogleBusinessPlusEntitlement {
  const rawStoreState = typeof input.subscriptionState === "string" &&
      input.subscriptionState.trim().length > 0
    ? input.subscriptionState.trim().toUpperCase()
    : "unknown";
  const currentPeriodEnd = validTimestamp(input.expiryTime);
  const suppliedGraceEnd = validTimestamp(input.gracePeriodExpiryTime);
  const gracePeriodEnd = rawStoreState ===
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
    ? suppliedGraceEnd ?? currentPeriodEnd
    : null;
  const candidateExpiry = gracePeriodEnd ?? currentPeriodEnd;
  const hasFutureExpiry = candidateExpiry !== null &&
    Date.parse(candidateExpiry) > nowMs;
  const cancellationTime = cancellationTimestamp(input.canceledStateContext);
  const explicitRevocationTime = validTimestamp(input.revocationTime);
  const revocationTime = explicitRevocationTime ??
    (rawStoreState === "SUBSCRIPTION_STATE_REVOKED"
      ? cancellationTime
      : null);
  const revoked = revocationTime !== null ||
    rawStoreState === "SUBSCRIPTION_STATE_REVOKED";

  let candidateEntitlementStatus: BusinessPlusCandidateStatus = "expired";
  let isCandidateEntitled = false;
  let autoRenewEnabled = input.autoRenewEnabled === true;

  if (!revoked) {
    switch (rawStoreState) {
      case "SUBSCRIPTION_STATE_ACTIVE":
        candidateEntitlementStatus = hasFutureExpiry ? "active" : "expired";
        isCandidateEntitled = hasFutureExpiry;
        break;
      case "SUBSCRIPTION_STATE_CANCELED":
        candidateEntitlementStatus = hasFutureExpiry
          ? "cancelled"
          : "expired";
        isCandidateEntitled = hasFutureExpiry;
        autoRenewEnabled = false;
        break;
      case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
        candidateEntitlementStatus = hasFutureExpiry
          ? "grace_period"
          : "expired";
        isCandidateEntitled = hasFutureExpiry;
        break;
      case "SUBSCRIPTION_STATE_ON_HOLD":
        candidateEntitlementStatus = "billing_retry";
        break;
      case "SUBSCRIPTION_STATE_PAUSED":
        candidateEntitlementStatus = "paused";
        break;
    }
  } else {
    candidateEntitlementStatus = "revoked";
    autoRenewEnabled = false;
  }

  return {
    rawStoreState,
    purchaseTime: validTimestamp(input.purchaseTime),
    currentPeriodEnd,
    gracePeriodEnd,
    cancellationTime,
    revocationTime,
    autoRenewEnabled,
    candidateEntitlementStatus,
    isCandidateEntitled,
  };
}

function validTimestamp(value: unknown): string | null {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  const time = Date.parse(value);
  return Number.isFinite(time) ? new Date(time).toISOString() : null;
}

function cancellationTimestamp(context: unknown): string | null {
  if (context === null || typeof context !== "object") return null;
  const record = context as Record<string, unknown>;
  for (
    const key of [
      "userInitiatedCancellation",
      "systemInitiatedCancellation",
      "replacementCancellation",
      "developerInitiatedCancellation",
    ]
  ) {
    const value = record[key];
    if (value !== null && typeof value === "object") {
      const timestamp = validTimestamp(
        (value as Record<string, unknown>).cancelTime,
      );
      if (timestamp !== null) return timestamp;
    }
  }
  return null;
}
