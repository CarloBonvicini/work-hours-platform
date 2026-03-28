import { createSign } from "node:crypto";

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
  skipped: boolean;
  reason?: string;
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
  const rawServiceAccount = process.env.FCM_SERVICE_ACCOUNT_JSON?.trim();
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
  const projectId = process.env.FCM_PROJECT_ID?.trim() ?? "";
  const clientEmail = process.env.FCM_CLIENT_EMAIL?.trim() ?? "";
  const privateKey = normalizePrivateKey(process.env.FCM_PRIVATE_KEY) ?? "";
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

function isInvalidRegistrationToken(responsePayload: unknown) {
  if (!responsePayload || typeof responsePayload !== "object") {
    return false;
  }

  const error = (responsePayload as { error?: unknown }).error;
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

async function parseFailedPushResponse(response: Response) {
  const responseBody = await response
    .json()
    .catch(() => null as unknown);
  return {
    sent: false,
    invalidToken: isInvalidRegistrationToken(responseBody)
  };
}

async function sendPushToToken(options: {
  config: FirebaseServiceAccountConfig;
  accessToken: string;
  token: string;
  payload: MobilePushBroadcastPayload;
}) {
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
    skipped: true,
    reason
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
    if (result.invalidToken) {
      invalidTokens.push(token);
    }
  }

  return {
    sentCount,
    failedCount,
    invalidTokens
  };
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
