import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

let app = buildApp();
let tempDirectory: string | null = null;

const originalUpdatesDir = process.env.MOBILE_UPDATES_DIR;
const originalNotifyToken = process.env.MOBILE_PUSH_NOTIFY_TOKEN;
const originalFcmServiceAccount = process.env.FCM_SERVICE_ACCOUNT_JSON;
const originalFcmProjectId = process.env.FCM_PROJECT_ID;
const originalFcmClientEmail = process.env.FCM_CLIENT_EMAIL;
const originalFcmPrivateKey = process.env.FCM_PRIVATE_KEY;

afterEach(async () => {
  await app.close();
  app = buildApp();

  if (tempDirectory) {
    await rm(tempDirectory, { recursive: true, force: true });
    tempDirectory = null;
  }

  if (originalUpdatesDir === undefined) {
    delete process.env.MOBILE_UPDATES_DIR;
  } else {
    process.env.MOBILE_UPDATES_DIR = originalUpdatesDir;
  }

  if (originalNotifyToken === undefined) {
    delete process.env.MOBILE_PUSH_NOTIFY_TOKEN;
  } else {
    process.env.MOBILE_PUSH_NOTIFY_TOKEN = originalNotifyToken;
  }

  if (originalFcmServiceAccount === undefined) {
    delete process.env.FCM_SERVICE_ACCOUNT_JSON;
  } else {
    process.env.FCM_SERVICE_ACCOUNT_JSON = originalFcmServiceAccount;
  }

  if (originalFcmProjectId === undefined) {
    delete process.env.FCM_PROJECT_ID;
  } else {
    process.env.FCM_PROJECT_ID = originalFcmProjectId;
  }

  if (originalFcmClientEmail === undefined) {
    delete process.env.FCM_CLIENT_EMAIL;
  } else {
    process.env.FCM_CLIENT_EMAIL = originalFcmClientEmail;
  }

  if (originalFcmPrivateKey === undefined) {
    delete process.env.FCM_PRIVATE_KEY;
  } else {
    process.env.FCM_PRIVATE_KEY = originalFcmPrivateKey;
  }
});

describe("Mobile push API", () => {
  it("registers and removes a mobile push token", async () => {
    app = buildApp();
    const token = "token-123456789012345678901234567890";

    const registerResponse = await app.inject({
      method: "POST",
      url: "/mobile-push/tokens",
      payload: {
        token,
        platform: "android",
        appVersion: "1.2.3"
      }
    });

    expect(registerResponse.statusCode).toBe(204);

    const removeResponse = await app.inject({
      method: "POST",
      url: "/mobile-push/tokens/remove",
      payload: {
        token
      }
    });

    expect(removeResponse.statusCode).toBe(200);
    expect(removeResponse.json()).toEqual({
      removed: 1
    });
  });

  it("rejects invalid mobile push token payloads", async () => {
    app = buildApp();

    const response = await app.inject({
      method: "POST",
      url: "/mobile-push/tokens",
      payload: {
        token: "short"
      }
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "token is invalid"
    });
  });

  it("requires a release token to broadcast update notifications", async () => {
    process.env.MOBILE_PUSH_NOTIFY_TOKEN = "test-release-token";
    app = buildApp();

    const missingTokenResponse = await app.inject({
      method: "POST",
      url: "/internal/mobile-updates/notify"
    });

    expect(missingTokenResponse.statusCode).toBe(401);

    const wrongTokenResponse = await app.inject({
      method: "POST",
      url: "/internal/mobile-updates/notify",
      headers: {
        "x-release-token": "wrong"
      }
    });

    expect(wrongTokenResponse.statusCode).toBe(401);
  });

  it("returns 404 when no mobile release metadata exists", async () => {
    process.env.MOBILE_PUSH_NOTIFY_TOKEN = "test-release-token";
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-push-"));
    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    app = buildApp();

    const response = await app.inject({
      method: "POST",
      url: "/internal/mobile-updates/notify",
      headers: {
        "x-release-token": "test-release-token"
      }
    });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({
      error: "No mobile release published"
    });
  });

  it("returns 503 when FCM is not configured", async () => {
    process.env.MOBILE_PUSH_NOTIFY_TOKEN = "test-release-token";
    delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    delete process.env.FCM_PROJECT_ID;
    delete process.env.FCM_CLIENT_EMAIL;
    delete process.env.FCM_PRIVATE_KEY;

    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-push-"));
    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    await writeFile(
      path.join(tempDirectory, "latest-release.json"),
      JSON.stringify({
        tag: "mobile-v1.2.3",
        version: "1.2.3",
        buildNumber: "123",
        fileName: "work-hours-mobile-1.2.3.apk",
        releaseNotes: "Nuova dashboard più chiara.",
        publishedAt: "2026-03-28T19:00:00.000Z"
      })
    );
    app = buildApp();

    const response = await app.inject({
      method: "POST",
      url: "/internal/mobile-updates/notify",
      headers: {
        "x-release-token": "test-release-token"
      }
    });

    expect(response.statusCode).toBe(503);
    expect(response.json()).toEqual({
      error: "FCM is not configured"
    });
  });
});
