import { describe, expect, it } from "vitest";
import { buildFcmRequestBody } from "../src/domain/mobile-push-message.js";

describe("buildFcmRequestBody", () => {
  it("includes Android notification title and body", () => {
    const rawBody = buildFcmRequestBody({
      token: "token-123",
      payload: {
        title: "Nuovo aggiornamento 0.1.98",
        body: "Apri l app per vedere le novita.",
        androidChannelId: "work_hours_updates",
        androidNotificationTag: "app_update_0.1.98_98",
        androidCollapseKey: "app_update_0.1.98_98",
        data: {
          type: "app_update",
          version: "0.1.98"
        }
      }
    });

    const body = JSON.parse(rawBody) as {
      message: {
        notification: {
          title: string;
          body: string;
        };
        android: {
          collapse_key?: string;
          notification: Record<string, string>;
        };
      };
    };

    expect(body.message.notification).toEqual({
      title: "Nuovo aggiornamento 0.1.98",
      body: "Apri l app per vedere le novita."
    });
    expect(body.message.android.notification).toMatchObject({
      title: "Nuovo aggiornamento 0.1.98",
      body: "Apri l app per vedere le novita.",
      sound: "default",
      channel_id: "work_hours_updates",
      tag: "app_update_0.1.98_98"
    });
    expect(body.message.android.collapse_key).toBe("app_update_0.1.98_98");
  });

  it("keeps Android-specific optional fields empty when not provided", () => {
    const rawBody = buildFcmRequestBody({
      token: "token-456",
      payload: {
        title: "Titolo",
        body: "Messaggio"
      }
    });

    const body = JSON.parse(rawBody) as {
      message: {
        android: {
          collapse_key?: string;
          notification: Record<string, string>;
        };
      };
    };

    expect(body.message.android.notification).toEqual({
      title: "Titolo",
      body: "Messaggio",
      sound: "default"
    });
    expect(body.message.android.collapse_key).toBeUndefined();
  });
});
