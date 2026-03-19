import { randomUUID } from "node:crypto";
import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import cors from "@fastify/cors";
import Fastify from "fastify";
import type { FastifyRequest } from "fastify";
import { InMemoryStore } from "./data/in-memory-store.js";
import type { AppStore } from "./data/store.js";
import {
  buildMonthlySummary,
  isIsoDate,
  isYearMonth
} from "./domain/monthly-summary.js";
import type {
  LeaveType,
  Profile
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

function isLeaveType(value: unknown): value is LeaveType {
  return value === "vacation" || value === "permit";
}

function getUpdatesDirectory() {
  return process.env.MOBILE_UPDATES_DIR ?? "/app/updates";
}

function getReleaseMetadataPath() {
  return path.join(getUpdatesDirectory(), "latest-release.json");
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

export function buildApp(options: BuildAppOptions = {}) {
  const store: AppStore = options.store ?? new InMemoryStore();
  const corsOrigin = process.env.CORS_ORIGIN;

  const app = Fastify({
    logger: true
  });

  void app.register(cors, {
    origin: corsOrigin ? corsOrigin.split(",").map((value) => value.trim()) : true
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

    if (!isPositiveInteger(body.dailyTargetMinutes)) {
      return reply.code(400).send({ error: "dailyTargetMinutes must be a positive integer" });
    }

    const profile: Profile = {
      id: "default-profile",
      fullName: body.fullName.trim(),
      dailyTargetMinutes: body.dailyTargetMinutes
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

  app.get("/monthly-summary/:month", async (request, reply) => {
    const params = request.params as { month?: unknown };
    if (typeof params.month !== "string" || !isYearMonth(params.month)) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    const month = params.month;
    const profile = await store.getProfile();
    const workEntries = await store.listWorkEntries(month);
    const leaveEntries = await store.listLeaveEntries(month);

    return buildMonthlySummary(
      month,
      profile,
      workEntries,
      leaveEntries
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
