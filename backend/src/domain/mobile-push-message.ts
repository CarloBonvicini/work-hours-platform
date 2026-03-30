import type { MobilePushBroadcastPayload } from "./mobile-push.js";

function normalizeNonEmptyString(value: string | undefined) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function buildAndroidNotification(payload: MobilePushBroadcastPayload) {
  const androidNotification: Record<string, string> = {
    title: payload.title,
    body: payload.body,
    sound: "default"
  };

  const channelId = normalizeNonEmptyString(payload.androidChannelId);
  if (channelId) {
    androidNotification.channel_id = channelId;
  }

  const notificationTag = normalizeNonEmptyString(payload.androidNotificationTag);
  if (notificationTag) {
    androidNotification.tag = notificationTag;
  }

  return androidNotification;
}

function buildAndroidMessage(payload: MobilePushBroadcastPayload) {
  const androidMessage: {
    priority: "high";
    notification: Record<string, string>;
    collapse_key?: string;
  } = {
    priority: "high",
    notification: buildAndroidNotification(payload)
  };

  const collapseKey = normalizeNonEmptyString(payload.androidCollapseKey);
  if (collapseKey) {
    androidMessage.collapse_key = collapseKey;
  }

  return androidMessage;
}

function buildApnsHeaders(payload: MobilePushBroadcastPayload) {
  const headers: Record<string, string> = {
    "apns-priority": "10"
  };
  const notificationTag = normalizeNonEmptyString(payload.androidNotificationTag);
  if (notificationTag) {
    headers["apns-collapse-id"] = notificationTag;
  }

  return headers;
}

export function buildFcmRequestBody(options: {
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
      android: buildAndroidMessage(options.payload),
      apns: {
        headers: buildApnsHeaders(options.payload),
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    }
  });
}
