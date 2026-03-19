import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

let app = buildApp();
let tempDirectory: string | null = null;
const originalUpdatesDir = process.env.MOBILE_UPDATES_DIR;
const originalPublicBaseUrl = process.env.MOBILE_UPDATES_PUBLIC_BASE_URL;

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

  if (originalPublicBaseUrl === undefined) {
    delete process.env.MOBILE_UPDATES_PUBLIC_BASE_URL;
  } else {
    process.env.MOBILE_UPDATES_PUBLIC_BASE_URL = originalPublicBaseUrl;
  }
});

describe("Mobile updates API", () => {
  it("serves a landing page even when no mobile release is published", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-updates-"));
    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    process.env.MOBILE_UPDATES_PUBLIC_BASE_URL = "https://updates.example.com";
    app = buildApp();

    const response = await app.inject({
      method: "GET",
      url: "/"
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/html");
    expect(response.body).toContain("Work Hours Platform");
    expect(response.body).toContain("APK non disponibile");
    expect(response.body).toContain("/tickets");
    expect(response.body).toContain("Nessuna versione disponibile in questo momento");
    expect(response.body).toContain("Quando il download sara pronto, il pulsante Scarica APK comparira qui.");
    expect(response.body).not.toContain("Canale update");
  });

  it("returns 404 when no mobile release is published", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-updates-"));
    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    app = buildApp();

    const response = await app.inject({
      method: "GET",
      url: "/mobile-updates/latest.json"
    });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({
      error: "No mobile release published"
    });
  });

  it("serves latest mobile update metadata and apk download", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-updates-"));
    await mkdir(path.join(tempDirectory, "downloads"), { recursive: true });
    await writeFile(
      path.join(tempDirectory, "latest-release.json"),
      JSON.stringify({
        tag: "mobile-v0.1.4",
        version: "0.1.4",
        buildNumber: "14",
        fileName: "work-hours-mobile-0.1.4.apk",
        releaseNotes: "Android APK build 0.1.4 (14).",
        publishedAt: "2026-03-19T10:00:00.000Z"
      })
    );
    await writeFile(
      path.join(tempDirectory, "downloads", "work-hours-mobile-0.1.4.apk"),
      "fake-apk"
    );

    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    process.env.MOBILE_UPDATES_PUBLIC_BASE_URL = "https://updates.example.com";
    app = buildApp();

    const feedResponse = await app.inject({
      method: "GET",
      url: "/mobile-updates/latest.json"
    });

    expect(feedResponse.statusCode).toBe(200);
    expect(feedResponse.json()).toEqual({
      tag_name: "mobile-v0.1.4",
      name: "Work Hours Mobile 0.1.4",
      html_url: "https://updates.example.com/mobile-updates/releases/latest",
      published_at: "2026-03-19T10:00:00.000Z",
      body: "Android APK build 0.1.4 (14).",
      assets: [
        {
          name: "work-hours-mobile-0.1.4.apk",
          browser_download_url:
            "https://updates.example.com/mobile-updates/downloads/work-hours-mobile-0.1.4.apk"
        }
      ]
    });

    const landingPageResponse = await app.inject({
      method: "GET",
      url: "/"
    });

    expect(landingPageResponse.statusCode).toBe(200);
    expect(landingPageResponse.body).toContain("Download disponibile");
    expect(landingPageResponse.body).toContain("Versione 0.1.4");
    expect(landingPageResponse.body).toContain("Android APK build 0.1.4.");
    expect(landingPageResponse.body).not.toContain("(14)");
    expect(landingPageResponse.body).toContain(
      "https://updates.example.com/mobile-updates/releases/latest"
    );
    expect(landingPageResponse.body).not.toContain("Verifica backend");

    const downloadResponse = await app.inject({
      method: "GET",
      url: "/mobile-updates/downloads/work-hours-mobile-0.1.4.apk"
    });

    expect(downloadResponse.statusCode).toBe(200);
    expect(downloadResponse.headers["content-type"]).toContain(
      "application/vnd.android.package-archive"
    );
    expect(downloadResponse.body).toBe("fake-apk");
  });

  it("keeps the previous release visible while a new mobile release is publishing", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-updates-"));
    await mkdir(path.join(tempDirectory, "downloads"), { recursive: true });
    await writeFile(
      path.join(tempDirectory, "latest-release.json"),
      JSON.stringify({
        tag: "mobile-v0.1.8",
        version: "0.1.8",
        buildNumber: "18",
        fileName: "work-hours-mobile-0.1.8.apk",
        releaseNotes: "Android APK build 0.1.8 (18).",
        publishedAt: "2026-03-19T12:00:00.000Z"
      })
    );
    await writeFile(
      path.join(tempDirectory, "release-status.json"),
      JSON.stringify({
        state: "publishing",
        tag: "mobile-v0.1.9",
        version: "0.1.9",
        buildNumber: "19",
        startedAt: "2026-03-19T12:10:00.000Z"
      })
    );

    process.env.MOBILE_UPDATES_DIR = tempDirectory;
    process.env.MOBILE_UPDATES_PUBLIC_BASE_URL = "https://updates.example.com";
    app = buildApp();

    const response = await app.inject({
      method: "GET",
      url: "/"
    });

    expect(response.statusCode).toBe(200);
    expect(response.body).toContain("Versione 0.1.8");
    expect(response.body).toContain("Stiamo pubblicando una nuova versione.");
    expect(response.body).toContain("APK temporaneamente non disponibile");
    expect(response.body).not.toContain("APK non disponibile");
  });
});
