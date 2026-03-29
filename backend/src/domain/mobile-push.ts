import { createSign } from "node:crypto";
import { normalizeRuntimeEnvValue } from "./env-value.js";
import {
  increaseFailureBreakdown,
  isInvalidRegistrationToken,
  type MobilePushFailureBreakdownItem,
  parsePushFailurePayload
} from "./mobile-push-failure.js";

interface FirebaseServiceAccountConfig {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface MobilePushBroadcastPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface MobilePushBroadcastResult {
  sentCount: number;
  failedCount: number;
  invalidTokens: string[];
  failureBreakdown: Array<{
    statusCode: number;
    errorStatus?: string;
    errorCode?: string;
    message?: string;
    count: number;
  }>;
  skipped: boolean;
  reason?: string;
}

interface TokenPushResult {
  sent: boolean;
  invalidToken: boolean;
  failure?: {
    statusCode: number;
    errorStatus?: string;
    errorCode?: string;
    message?: string;
  };
}

let cachedAccessToken:
  | {
      token: string;
      expiresAtEpochSeconds: number;
    }
  | undefined;

function base64UrlEncode(value: string) {
  return Buffer.from(value, "utf8").toString("base64url");
}

function normalizePrivateKey(value: string | undefined) {
  if (!value) {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.replace(/\\n/g, "\n");
}

function parseServiceAccountJson(rawValue: string) {
  try {
    const parsed = JSON.parse(rawValue) as Partial<{
      project_id: string;
      client_email: string;
      private_key: string;
    }>;
    if (
      typeof parsed.project_id !== "string" ||
      typeof parsed.client_email !== "string" ||
      typeof parsed.private_key !== "string"
    ) {
      return null;
    }

    return {
      projectId: parsed.project_id.trim(),
      clientEmail: parsed.client_email.trim(),
      privateKey: normalizePrivateKey(parsed.private_key) ?? ""
    };
  } catch {
    return null;
  }
}

function resolveFirebaseConfigFromServiceAccount():
  | FirebaseServiceAccountConfig
  | null {
  const rawServiceAccount = normalizeRuntimeEnvValue(
    process.env.FCM_SERVICE_ACCOUNT_JSON
  );
  if (!rawServiceAccount) {
    return null;
  }

  const parsed = parseServiceAccountJson(rawServiceAccount);
  if (!parsed) {
    return null;
  }

  return parsed.projectId && parsed.clientEmail && parsed.privateKey
    ? parsed
    : null;
}

function resolveFirebaseConfigFromFields(): FirebaseServiceAccountConfig | null {
  const projectId = normalizeRuntimeEnvValue(process.env.FCM_PROJECT_ID) ?? "";
  const clientEmail = normalizeRuntimeEnvValue(process.env.FCM_CLIENT_EMAIL) ?? "";
  const privateKey = normalizePrivateKey(
    normalizeRuntimeEnvValue(process.env.FCM_PRIVATE_KEY)
  ) ?? "";
  if (!projectId || !clientEmail || !privateKey) {
    return null;
  }

  return {
    projectId,
    clientEmail,
    privateKey
  };
}

function resolveFirebaseConfig(): FirebaseServiceAccountConfig | null {
  return (
    resolveFirebaseConfigFromServiceAccount() ??
    resolveFirebaseConfigFromFields()
  );
}

export function isMobilePushConfigured() {
  return resolveFirebaseConfig() !== null;
}

function buildJwtAssertion(config: FirebaseServiceAccountConfig) {
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;
  const header = base64UrlEncode(
    JSON.stringify({
      alg: "RS256",
      typ: "JWT"
    })
  );
  const payload = base64UrlEncode(
    JSON.stringify({
      iss: config.clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: issuedAt,
      exp: expiresAt
    })
  );
  const unsignedJwt = `${header}.${payload}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsignedJwt);
  signer.end();
  const signature = signer.sign(config.privateKey, "base64url");
  return `${unsignedJwt}.${signature}`;
}

async function requestFirebaseAccessToken(config: FirebaseServiceAccountConfig) {
  const now = Math.floor(Date.now() / 1000);
  if (
    cachedAccessToken &&
    cachedAccessToken.expiresAtEpochSeconds - 120 > now &&
    cachedAccessToken.token.length > 0
  ) {
    return cachedAccessToken.token;
  }

  const assertion = buildJwtAssertion(config);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });

  if (!response.ok) {
    throw new Error(`Unable to request Firebase access token (${response.status})`);
  }

  const payload = (await response.json()) as Partial<{
    access_token: string;
    expires_in: number;
  }>;
  if (
    typeof payload.access_token !== "string" ||
    payload.access_token.trim().length === 0
  ) {
    throw new Error("Invalid Firebase access token response");
  }

  const expiresIn = typeof payload.expires_in === "number" ? payload.expires_in : 3600;
  cachedAccessToken = {
    token: payload.access_token.trim(),
    expiresAtEpochSeconds: now + Math.max(300, expiresIn)
  };

  return cachedAccessToken.token;
}

function buildFcmSendUrl(projectId: string) {
  return `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`;
}

function buildFcmRequestBody(options: {
  token: string;
  payload: MobilePushBroadcastPayload;
}) {
  return JSON.stringify({
    message: {
      token: options.token,
      notification: {
        title: options.payload.title,
        body: options.payload.body
      },
      data: options.payload.data ?? {},
      android: {
        priority: "high",
        notification: {
          sound: "default"
        }
      },
      apns: {
        headers: {
          "apns-priority": "10"
        },
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    }
  });
}

async function parseFailedPushResponse(response: Response): Promise<TokenPushResult> {
  const responseBody = await response
    .json()
    .catch(() => null as unknown);
  const parsedFailure = parsePushFailurePayload(responseBody);
  return {
    sent: false,
    invalidToken: isInvalidRegistrationToken(responseBody),
    failure: {
      statusCode: response.status,
      ...parsedFailure
    }
  };
}

async function sendPushToToken(options: {
  config: FirebaseServiceAccountConfig;
  accessToken: string;
  token: string;
  payload: MobilePushBroadcastPayload;
}): Promise<TokenPushResult> {
  const response = await fetch(buildFcmSendUrl(options.config.projectId), {
    method: "POST",
    headers: {
      authorization: `Bearer ${options.accessToken}`,
      "content-type": "application/json"
    },
    body: buildFcmRequestBody({
      token: options.token,
      payload: options.payload
    })
  });

  if (response.ok) {
    return {
      sent: true,
      invalidToken: false
    };
  }

  return parseFailedPushResponse(response);
}

function buildSkippedBroadcastResult(
  reason: string,
  failedCount: number
): MobilePushBroadcastResult {
  return {
    sentCount: 0,
    failedCount,
    invalidTokens: [],
    failureBreakdown: [],
    skipped: true,
    reason
  };
}

function collectFailedPushResult(options: {
  token: string;
  result: TokenPushResult;
  invalidTokens: string[];
  failureBreakdownByKey: Map<string, MobilePushFailureBreakdownItem>;
}) {
  if (options.result.invalidToken) {
    options.invalidTokens.push(options.token);
  }

  if (options.result.failure) {
    increaseFailureBreakdown(
      options.failureBreakdownByKey,
      options.result.failure
    );
  }
}

function buildDeliveryResult(options: {
  sentCount: number;
  failedCount: number;
  invalidTokens: string[];
  failureBreakdownByKey: Map<string, MobilePushFailureBreakdownItem>;
}) {
  const failureBreakdown = Array.from(options.failureBreakdownByKey.values()).sort(
    (left, right) => right.count - left.count
  );
  return {
    sentCount: options.sentCount,
    failedCount: options.failedCount,
    invalidTokens: options.invalidTokens,
    failureBreakdown
  };
}

async function sendPushToTokens(options: {
  config: FirebaseServiceAccountConfig;
  accessToken: string;
  tokens: string[];
  payload: MobilePushBroadcastPayload;
}) {
  let sentCount = 0;
  let failedCount = 0;
  const invalidTokens: string[] = [];
  const failureBreakdownByKey = new Map<string, MobilePushFailureBreakdownItem>();

  for (const token of options.tokens) {
    const result = await sendPushToToken({
      config: options.config,
      accessToken: options.accessToken,
      token,
      payload: options.payload
    });
    if (result.sent) {
      sentCount += 1;
      continue;
    }

    failedCount += 1;
    collectFailedPushResult({
      token,
      result,
      invalidTokens,
      failureBreakdownByKey
    });
  }

  return buildDeliveryResult({
    sentCount,
    failedCount,
    invalidTokens,
    failureBreakdownByKey
  });
}

export async function broadcastMobilePush(options: {
  tokens: string[];
  payload: MobilePushBroadcastPayload;
}): Promise<MobilePushBroadcastResult> {
  if (options.tokens.length === 0) {
    return buildSkippedBroadcastResult("No mobile tokens registered", 0);
  }

  const config = resolveFirebaseConfig();
  if (!config) {
    return buildSkippedBroadcastResult("FCM is not configured", options.tokens.length);
  }

  const accessToken = await requestFirebaseAccessToken(config);
  const deliveryResult = await sendPushToTokens({
    config,
    accessToken,
    tokens: options.tokens,
    payload: options.payload
  });

  return {
    ...deliveryResult,
    skipped: false
  };
}
