export interface MobilePushFailureBreakdownItem {
  statusCode: number;
  errorStatus?: string;
  errorCode?: string;
  message?: string;
  count: number;
}

function normalizeOptionalFailureText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  if (!normalized) {
    return undefined;
  }

  return normalized.slice(0, maxLength);
}

function findFcmErrorCode(value: unknown) {
  if (!Array.isArray(value)) {
    return undefined;
  }

  for (const item of value) {
    if (!item || typeof item !== "object") {
      continue;
    }

    const errorCode = normalizeOptionalFailureText(
      (item as { errorCode?: unknown }).errorCode,
      80
    );
    if (errorCode) {
      return errorCode;
    }
  }

  return undefined;
}

export function parsePushFailurePayload(responsePayload: unknown) {
  const error = responsePayload && typeof responsePayload === "object"
    ? (responsePayload as { error?: unknown }).error
    : undefined;
  if (!error || typeof error !== "object") {
    return {
      errorStatus: undefined,
      errorCode: undefined,
      message: undefined
    };
  }

  const normalizedError = error as {
    status?: unknown;
    message?: unknown;
    details?: unknown;
  };
  return {
    errorStatus: normalizeOptionalFailureText(normalizedError.status, 80),
    errorCode: findFcmErrorCode(normalizedError.details),
    message: normalizeOptionalFailureText(normalizedError.message, 240)
  };
}

export function isInvalidRegistrationToken(responsePayload: unknown) {
  const error = responsePayload && typeof responsePayload === "object"
    ? (responsePayload as { error?: unknown }).error
    : undefined;
  if (!error || typeof error !== "object") {
    return false;
  }

  const details = (error as { details?: unknown }).details;
  if (!Array.isArray(details)) {
    return false;
  }

  return details.some((detail) => {
    if (!detail || typeof detail !== "object") {
      return false;
    }

    const code = (detail as { errorCode?: unknown }).errorCode;
    return code === "UNREGISTERED" || code === "INVALID_ARGUMENT";
  });
}

function buildFailureBreakdownKey(
  failure: Omit<MobilePushFailureBreakdownItem, "count">
) {
  const statusCode = failure.statusCode.toString();
  const errorStatus = failure.errorStatus ?? "";
  const errorCode = failure.errorCode ?? "";
  const message = failure.message ?? "";
  return `${statusCode}|${errorStatus}|${errorCode}|${message}`;
}

export function increaseFailureBreakdown(
  failureBreakdownByKey: Map<string, MobilePushFailureBreakdownItem>,
  failure: Omit<MobilePushFailureBreakdownItem, "count">
) {
  const breakdownKey = buildFailureBreakdownKey(failure);
  const currentItem = failureBreakdownByKey.get(breakdownKey);
  if (currentItem) {
    currentItem.count += 1;
    return;
  }

  failureBreakdownByKey.set(breakdownKey, {
    ...failure,
    count: 1
  });
}
