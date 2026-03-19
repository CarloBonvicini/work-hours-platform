import { randomUUID } from "node:crypto";
import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import cors from "@fastify/cors";
import Fastify from "fastify";
import type { FastifyRequest } from "fastify";
import { InMemoryStore } from "./data/in-memory-store.js";
import type { AppStore } from "./data/store.js";
import {
  buildUniformWeekdayTargetMinutes,
  buildMonthlySummary,
  isIsoDate,
  isYearMonth,
  WEEKDAY_KEYS
} from "./domain/monthly-summary.js";
import type {
  LeaveType,
  Profile,
  WeekdayTargetMinutes
} from "./domain/types.js";

interface BuildAppOptions {
  store?: AppStore;
}

interface MobileReleaseMetadata {
  tag: string;
  version: string;
  buildNumber: string;
  fileName: string;
  releaseNotes?: string;
  publishedAt?: string;
}

interface MobileReleaseStatus {
  state: "publishing";
  tag: string;
  version: string;
  buildNumber: string;
  startedAt?: string;
}

function parseMonthQuery(query: unknown): string | null | undefined {
  if (!query || typeof query !== "object") {
    return undefined;
  }

  const monthValue = (query as Record<string, unknown>).month;
  if (monthValue === undefined) {
    return undefined;
  }

  if (typeof monthValue !== "string" || !isYearMonth(monthValue)) {
    return null;
  }

  return monthValue;
}

function isPositiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function isLeaveType(value: unknown): value is LeaveType {
  return value === "vacation" || value === "permit";
}

function parseWeekdayTargetMinutes(
  value: unknown
): WeekdayTargetMinutes | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const targetByWeekday = value as Record<string, unknown>;
  const weekdayTargetMinutes = {} as WeekdayTargetMinutes;

  for (const key of WEEKDAY_KEYS) {
    const dayValue = targetByWeekday[key];
    if (!isNonNegativeInteger(dayValue)) {
      return null;
    }

    weekdayTargetMinutes[key] = dayValue;
  }

  return weekdayTargetMinutes;
}

function deriveDailyTargetMinutes(
  useUniformDailyTarget: boolean,
  dailyTargetMinutes: number | undefined,
  weekdayTargetMinutes: WeekdayTargetMinutes
) {
  if (useUniformDailyTarget && dailyTargetMinutes !== undefined) {
    return dailyTargetMinutes;
  }

  const workingDayValues = [
    weekdayTargetMinutes.monday,
    weekdayTargetMinutes.tuesday,
    weekdayTargetMinutes.wednesday,
    weekdayTargetMinutes.thursday,
    weekdayTargetMinutes.friday
  ];
  const total = workingDayValues.reduce((sum, value) => sum + value, 0);

  return Math.round(total / workingDayValues.length);
}

function getUpdatesDirectory() {
  return process.env.MOBILE_UPDATES_DIR ?? "/app/updates";
}

function getReleaseMetadataPath() {
  return path.join(getUpdatesDirectory(), "latest-release.json");
}

function getReleaseStatusPath() {
  return path.join(getUpdatesDirectory(), "release-status.json");
}

async function loadReleaseMetadata(): Promise<MobileReleaseMetadata | null> {
  try {
    const rawValue = await fs.readFile(getReleaseMetadataPath(), "utf8");
    const parsedValue = JSON.parse(rawValue) as Partial<MobileReleaseMetadata>;
    if (
      typeof parsedValue.tag !== "string" ||
      typeof parsedValue.version !== "string" ||
      typeof parsedValue.buildNumber !== "string" ||
      typeof parsedValue.fileName !== "string"
    ) {
      return null;
    }

    return {
      tag: parsedValue.tag,
      version: parsedValue.version,
      buildNumber: parsedValue.buildNumber,
      fileName: parsedValue.fileName,
      releaseNotes: parsedValue.releaseNotes,
      publishedAt: parsedValue.publishedAt
    };
  } catch {
    return null;
  }
}

async function loadReleaseStatus(): Promise<MobileReleaseStatus | null> {
  try {
    const rawValue = await fs.readFile(getReleaseStatusPath(), "utf8");
    const parsedValue = JSON.parse(rawValue) as Partial<MobileReleaseStatus>;
    if (
      parsedValue.state !== "publishing" ||
      typeof parsedValue.tag !== "string" ||
      typeof parsedValue.version !== "string" ||
      typeof parsedValue.buildNumber !== "string"
    ) {
      return null;
    }

    return {
      state: "publishing",
      tag: parsedValue.tag,
      version: parsedValue.version,
      buildNumber: parsedValue.buildNumber,
      startedAt: parsedValue.startedAt
    };
  } catch {
    return null;
  }
}

function getPublicBaseUrl(request: FastifyRequest) {
  const configuredBaseUrl = process.env.MOBILE_UPDATES_PUBLIC_BASE_URL;
  if (configuredBaseUrl) {
    return configuredBaseUrl.replace(/\/+$/, "");
  }

  const protocol =
    typeof request.headers["x-forwarded-proto"] === "string"
      ? request.headers["x-forwarded-proto"]
      : request.protocol;

  return `${protocol}://${request.headers.host ?? "localhost:8080"}`;
}

function resolveUpdateFilePath(fileName: string) {
  const updatesDir = getUpdatesDirectory();
  const downloadsDir = path.join(updatesDir, "downloads");
  const filePath = path.resolve(downloadsDir, fileName);

  if (!filePath.startsWith(path.resolve(downloadsDir) + path.sep)) {
    return null;
  }

  return filePath;
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderLandingPage(options: {
  baseUrl: string;
  latestRelease: MobileReleaseMetadata | null;
  releaseStatus: MobileReleaseStatus | null;
}) {
  const { baseUrl, latestRelease, releaseStatus } = options;
  const downloadUrl = `${baseUrl}/mobile-updates/releases/latest`;
  const hasRelease = latestRelease !== null;
  const isPublishing = releaseStatus?.state === "publishing";
  const titleLabel = hasRelease
    ? "Download disponibile"
    : isPublishing
      ? "Nuova versione in arrivo"
      : "APK non ancora disponibile";
  const versionValue = hasRelease
    ? `Versione ${latestRelease.version}`
    : isPublishing
      ? "Stiamo preparando la prossima versione"
      : "La prima versione Android non e ancora stata pubblicata";
  const detailLabel = isPublishing
    ? hasRelease
      ? "Stiamo pubblicando una nuova versione. Il download tornera disponibile appena il rilascio e completato."
      : "Stiamo pubblicando la prima versione Android. Il pulsante di download comparira qui appena pronto."
    : hasRelease
      ? "Qui trovi l ultima versione disponibile dell app Android."
      : "Quando la prima versione Android sara pronta, la troverai qui.";
  const publishedAt = latestRelease?.publishedAt
    ? new Date(latestRelease.publishedAt).toLocaleString("it-IT", {
        dateStyle: "medium",
        timeStyle: "short"
      })
    : null;
  const publishedLabel = publishedAt
    ? `Ultima pubblicazione: ${publishedAt}`
    : isPublishing
      ? "Pubblicazione in corso."
      : "Nessuna pubblicazione disponibile per ora.";
  const notesLabel = latestRelease?.releaseNotes ?? (isPublishing
    ? "Aggiorna questa pagina tra qualche minuto per vedere la nuova versione."
    : "Il pulsante di download comparira qui appena il rilascio sara disponibile.");
  const installTitle = hasRelease ? "Installazione rapida" : "Disponibilita";
  const installDescription = hasRelease
    ? "Il download funziona da browser mobile e desktop. Su Android devi confermare l installazione dell APK."
    : isPublishing
      ? "Il rilascio e in corso. Manteniamo disponibile qui l ultima informazione utile finche la nuova versione non e pronta."
      : "L APK non e ancora stato pubblicato. Quando sara pronto, potrai scaricarlo direttamente da questa pagina.";
  const installItems = hasRelease
    ? [
        "Apri la pagina dal telefono Android.",
        "Tocca Scarica APK.",
        "Se Android lo chiede, autorizza l installazione da questa sorgente.",
        "Quando uscira una nuova release, l app mostrera il banner update."
      ]
    : isPublishing
      ? [
          "La nuova versione e in preparazione.",
          "Il pulsante di download tornera disponibile appena il rilascio termina.",
          "Non serve fare altro: basta riaprire questa pagina."
        ]
      : [
          "La prima versione Android non e ancora pronta.",
          "Quando verra pubblicata, il pulsante Scarica APK comparira qui.",
          "Puoi tornare su questa pagina piu tardi per controllare."
        ];

  const primaryAction = isPublishing
    ? `<span class="button disabled">APK temporaneamente non disponibile</span>`
    : hasRelease
      ? `<a class="button primary" href="${escapeHtml(downloadUrl)}">Scarica APK</a>`
      : `<span class="button disabled">APK non disponibile</span>`;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Work Hours Platform</title>
    <style>
      :root {
        --page: #f4efe6;
        --card: rgba(255, 255, 255, 0.88);
        --ink: #112321;
        --muted: #4a5d58;
        --line: #d8cec0;
        --brand: #0b6e69;
        --brand-dark: #084c49;
        --accent: #e6b84c;
        --shadow: 0 28px 80px rgba(17, 35, 33, 0.12);
      }

      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(11, 110, 105, 0.18), transparent 34%),
          radial-gradient(circle at top right, rgba(230, 184, 76, 0.22), transparent 28%),
          linear-gradient(180deg, #faf6ee 0%, var(--page) 100%);
      }

      main {
        width: min(1080px, calc(100% - 32px));
        margin: 0 auto;
        padding: 32px 0 48px;
      }

      .hero {
        background: linear-gradient(150deg, rgba(17, 49, 49, 0.98), rgba(11, 110, 105, 0.94));
        color: white;
        border-radius: 32px;
        padding: 32px;
        box-shadow: var(--shadow);
      }

      h1 {
        margin: 0 0 10px;
        font-size: clamp(40px, 6vw, 68px);
        line-height: 0.96;
        letter-spacing: -0.04em;
      }

      .hero p {
        margin: 0;
        max-width: 720px;
        color: rgba(255, 255, 255, 0.82);
        font-size: 18px;
        line-height: 1.5;
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 28px;
      }

      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 54px;
        padding: 0 22px;
        border-radius: 18px;
        text-decoration: none;
        font-weight: 700;
      }

      .button.primary {
        background: var(--accent);
        color: #17302d;
      }

      .button.disabled {
        background: rgba(255, 255, 255, 0.12);
        color: rgba(255, 255, 255, 0.58);
        cursor: not-allowed;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(12, minmax(0, 1fr));
        gap: 16px;
        margin-top: 18px;
      }

      .panel {
        background: var(--card);
        border: 1px solid rgba(216, 206, 192, 0.92);
        border-radius: 24px;
        padding: 22px;
        backdrop-filter: blur(12px);
      }

      .panel h2 {
        margin: 0 0 8px;
        font-size: 24px;
        letter-spacing: -0.03em;
      }

      .panel p,
      .panel li {
        color: var(--muted);
        line-height: 1.5;
      }

      .panel strong {
        color: var(--ink);
      }

      .release {
        grid-column: span 8;
      }

      .install {
        grid-column: span 4;
      }

      ul {
        margin: 12px 0 0;
        padding-left: 18px;
      }

      .footer {
        margin-top: 18px;
        text-align: center;
        color: var(--muted);
        font-size: 14px;
      }

      @media (max-width: 860px) {
        main { width: min(100% - 24px, 1000px); padding-top: 20px; }
        .hero { padding: 24px; border-radius: 28px; }
        .release, .install { grid-column: 1 / -1; }
      }
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>Work Hours Platform</h1>
        <p>Scarica l app Android ufficiale o controlla quando sara disponibile la prossima versione.</p>
        <div class="actions">
          ${primaryAction}
        </div>
      </section>

      <section class="grid">
        <article class="panel release">
          <h2>${escapeHtml(titleLabel)}</h2>
          <p>${escapeHtml(detailLabel)}</p>
          <p><strong>${escapeHtml(versionValue)}</strong></p>
          <p>${escapeHtml(publishedLabel)}</p>
          <p>${escapeHtml(notesLabel)}</p>
        </article>

        <article class="panel install">
          <h2>${escapeHtml(installTitle)}</h2>
          <p>${escapeHtml(installDescription)}</p>
          <ul>
            ${installItems.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </article>
      </section>

      <p class="footer">Pagina servita dal backend Work Hours Platform.</p>
    </main>
  </body>
</html>`;
}

export function buildApp(options: BuildAppOptions = {}) {
  const store: AppStore = options.store ?? new InMemoryStore();
  const corsOrigin = process.env.CORS_ORIGIN;

  const app = Fastify({
    logger: true
  });

  void app.register(cors, {
    origin: corsOrigin ? corsOrigin.split(",").map((value) => value.trim()) : true
  });

  app.get("/", async (request, reply) => {
    const latestRelease = await loadReleaseMetadata();
    const releaseStatus = await loadReleaseStatus();
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderLandingPage({ baseUrl, latestRelease, releaseStatus }));
  });

  app.get("/health", async () => {
    return {
      status: "ok",
      service: "work-hours-backend",
      timestamp: new Date().toISOString()
    };
  });

  app.get("/profile", async () => {
    return await store.getProfile();
  });

  app.put("/profile", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.fullName !== "string" || body.fullName.trim().length === 0) {
      return reply.code(400).send({ error: "fullName is required" });
    }

    const useUniformDailyTarget =
      body.useUniformDailyTarget === undefined
        ? true
        : body.useUniformDailyTarget === true;
    if (
      body.useUniformDailyTarget !== undefined &&
      typeof body.useUniformDailyTarget !== "boolean"
    ) {
      return reply.code(400).send({
        error: "useUniformDailyTarget must be a boolean"
      });
    }

    const parsedWeekdayTargetMinutes = parseWeekdayTargetMinutes(
      body.weekdayTargetMinutes
    );
    if (
      body.weekdayTargetMinutes !== undefined &&
      parsedWeekdayTargetMinutes === null
    ) {
      return reply.code(400).send({
        error: "weekdayTargetMinutes must include monday-sunday non-negative integers"
      });
    }

    if (useUniformDailyTarget && !isPositiveInteger(body.dailyTargetMinutes)) {
      return reply.code(400).send({
        error: "dailyTargetMinutes must be a positive integer"
      });
    }

    const weekdayTargetMinutes = useUniformDailyTarget
      ? buildUniformWeekdayTargetMinutes(body.dailyTargetMinutes as number)
      : parsedWeekdayTargetMinutes;

    if (!weekdayTargetMinutes) {
      return reply.code(400).send({
        error: "weekdayTargetMinutes is required when useUniformDailyTarget is false"
      });
    }

    const dailyTargetMinutes = deriveDailyTargetMinutes(
      useUniformDailyTarget,
      isPositiveInteger(body.dailyTargetMinutes)
        ? body.dailyTargetMinutes
        : undefined,
      weekdayTargetMinutes
    );

    const profile: Profile = {
      id: "default-profile",
      fullName: body.fullName.trim(),
      useUniformDailyTarget,
      dailyTargetMinutes,
      weekdayTargetMinutes
    };

    return await store.saveProfile(profile);
  });

  app.get("/work-entries", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listWorkEntries(month)
    };
  });

  app.post("/work-entries", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isPositiveInteger(body.minutes)) {
      return reply.code(400).send({ error: "minutes must be a positive integer" });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.addWorkEntry({
      id: randomUUID(),
      date: body.date,
      minutes: body.minutes,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.get("/leave-entries", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listLeaveEntries(month)
    };
  });

  app.post("/leave-entries", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isPositiveInteger(body.minutes)) {
      return reply.code(400).send({ error: "minutes must be a positive integer" });
    }

    if (!isLeaveType(body.type)) {
      return reply.code(400).send({ error: "type must be 'vacation' or 'permit'" });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.addLeaveEntry({
      id: randomUUID(),
      date: body.date,
      minutes: body.minutes,
      type: body.type,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.get("/schedule-overrides", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listScheduleOverrides(month)
    };
  });

  app.post("/schedule-overrides", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isNonNegativeInteger(body.targetMinutes)) {
      return reply.code(400).send({
        error: "targetMinutes must be a non-negative integer"
      });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.saveScheduleOverride({
      id: randomUUID(),
      date: body.date,
      targetMinutes: body.targetMinutes,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.delete("/schedule-overrides/:date", async (request, reply) => {
    const params = request.params as { date?: unknown };
    if (typeof params.date !== "string" || !isIsoDate(params.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    const wasRemoved = await store.removeScheduleOverride(params.date);
    if (!wasRemoved) {
      return reply.code(404).send({ error: "Schedule override not found" });
    }

    return reply.code(204).send();
  });

  app.get("/monthly-summary/:month", async (request, reply) => {
    const params = request.params as { month?: unknown };
    if (typeof params.month !== "string" || !isYearMonth(params.month)) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    const month = params.month;
    const profile = await store.getProfile();
    const workEntries = await store.listWorkEntries(month);
    const leaveEntries = await store.listLeaveEntries(month);
    const scheduleOverrides = await store.listScheduleOverrides(month);

    return buildMonthlySummary(
      month,
      profile,
      workEntries,
      leaveEntries,
      scheduleOverrides
    );
  });

  app.get("/mobile-updates/latest.json", async (request, reply) => {
    const metadata = await loadReleaseMetadata();
    if (!metadata) {
      return reply.code(404).send({ error: "No mobile release published" });
    }

    const baseUrl = getPublicBaseUrl(request);

    return {
      tag_name: metadata.tag,
      name: `Work Hours Mobile ${metadata.version}`,
      html_url: `${baseUrl}/mobile-updates/releases/latest`,
      published_at: metadata.publishedAt ?? null,
      body: metadata.releaseNotes ?? null,
      assets: [
        {
          name: metadata.fileName,
          browser_download_url:
            `${baseUrl}/mobile-updates/downloads/${encodeURIComponent(metadata.fileName)}`
        }
      ]
    };
  });

  app.get("/mobile-updates/releases/latest", async (request, reply) => {
    const metadata = await loadReleaseMetadata();
    if (!metadata) {
      return reply.code(404).send({ error: "No mobile release published" });
    }

    const baseUrl = getPublicBaseUrl(request);
    return reply.redirect(
      `${baseUrl}/mobile-updates/downloads/${encodeURIComponent(metadata.fileName)}`
    );
  });

  app.get("/mobile-updates/downloads/:fileName", async (request, reply) => {
    const params = request.params as { fileName?: unknown };
    if (typeof params.fileName !== "string" || params.fileName.length === 0) {
      return reply.code(400).send({ error: "fileName is required" });
    }

    const filePath = resolveUpdateFilePath(params.fileName);
    if (!filePath) {
      return reply.code(400).send({ error: "Invalid file name" });
    }

    try {
      await fs.access(filePath);
    } catch {
      return reply.code(404).send({ error: "Update file not found" });
    }

    reply
      .type("application/vnd.android.package-archive")
      .header(
        "content-disposition",
        `attachment; filename="${path.basename(filePath)}"`
      );

    return reply.send(createReadStream(filePath));
  });

  return app;
}
