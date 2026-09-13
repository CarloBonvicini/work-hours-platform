import { randomUUID } from "node:crypto";
import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import cors from "@fastify/cors";
import Fastify from "fastify";
import type { FastifyRequest } from "fastify";
import { InMemoryStore } from "./data/in-memory-store.js";
import { registerEntryMutationRoutes } from "./routes/entry-mutations.js";
import type {
  AppStore,
  AppearanceSettingsRecord,
  AuthUser,
  CloudBackupRecord,
  WorkdayBreakSegmentRecord,
  WorkdaySessionRecord,
} from "./data/store.js";
import {
  buildDefaultWorkRules,
  buildUniformWeekdayTargetMinutes,
  buildMonthlySummary,
  isIsoDate,
  isYearMonth,
  WEEKDAY_KEYS
} from "./domain/monthly-summary.js";
import { buildAdminOverview } from "./domain/admin-overview.js";
import {
  broadcastMobilePush,
  isMobilePushConfigured
} from "./domain/mobile-push.js";
import {
  createPasswordDigest,
  verifyPasswordDigest,
  createRecoveryCode,
  createRecoveryCodeDigest,
  verifyRecoveryCodeDigest,
  createRecoveryAnswerDigest,
  verifyRecoveryAnswerDigest,
  hasRecoveryQuestionsConfigured,
  isRecoveryTemporarilyLocked,
  RECOVERY_MAX_ATTEMPTS,
  RECOVERY_LOCK_WINDOW_MINUTES,
  createSessionToken,
  hashSessionToken,
  isLegacyAdminProfileEmail,
  isAdminRole,
  getEffectiveAuthRole,
  isAdminUser,
  isSuperAdminUser,
  getConfiguredSuperAdminCredentials,
  serializeAuthUser,
  syncConfiguredSuperAdmin,
  isValidEmail
} from "./domain/auth.js";
import { isLeaveType, isPositiveInteger } from "./domain/entry-payloads.js";
import { normalizeRuntimeEnvValue } from "./domain/env-value.js";
import { escapeHtml, formatReleaseNotesForLanding } from "./views/html.js";
import { renderLandingPage } from "./views/landing-page.js";
import { renderTicketPage } from "./views/ticket-page.js";
import { renderAdminPage } from "./views/admin/page.js";
import {
  parseAdminRolePayload,
  parseAdminPasswordPayload,
  parseAdminUserCreatePayload,
  parseAdminUserUpdatePayload,
  parseAuthCredentials,
  parsePasswordRecoveryPayload,
  parseRecoveryQuestionLookupPayload,
  parseRecoveryQuestionSetupPayload
} from "./domain/auth-payloads.js";
import type {
  DaySchedule,
  LeaveEntry,
  Profile,
  ScheduleOverride,
  WeekdaySchedule,
  WeekdayTargetMinutes,
  WorkAllowancePeriod,
  WorkPermissionAllowanceType,
  WorkPermissionMovement,
  WorkPermissionRule,
  WorkEntry
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

type SupportTicketCategory = "bug" | "feature" | "support";
type SupportTicketStatus = "new" | "in_progress" | "answered" | "closed";
type SupportTicketReplyAuthor = "admin" | "user";
const MOBILE_PUSH_UPDATE_CHANNEL_ID = "work_hours_updates";
const MOBILE_PUSH_TICKET_CHANNEL_ID = "work_hours_ticket_replies";
const SUPPORT_TICKET_MAX_ATTACHMENTS = 3;
const SUPPORT_TICKET_MAX_ATTACHMENT_BYTES = 4 * 1024 * 1024;
// Gli allegati viaggiano in JSON come base64 (+33%): il limite del body deve
// contenere il caso peggiore piu' testo, log diagnostici e struttura JSON.
const SUPPORT_TICKET_MAX_BASE64_ATTACHMENTS_BYTES =
  SUPPORT_TICKET_MAX_ATTACHMENTS * Math.ceil((SUPPORT_TICKET_MAX_ATTACHMENT_BYTES * 4) / 3);
const REQUEST_BODY_LIMIT_BYTES = SUPPORT_TICKET_MAX_BASE64_ATTACHMENTS_BYTES + 2 * 1024 * 1024;
const SUPPORT_TICKET_ATTACHMENT_EXTENSIONS = {
  "image/png": ".png",
  "image/jpeg": ".jpg",
  "image/webp": ".webp",
  "audio/mpeg": ".mp3",
  "audio/mp4": ".m4a",
  "audio/x-m4a": ".m4a",
  "audio/wav": ".wav",
  "audio/ogg": ".ogg",
  "audio/aac": ".aac",
  "audio/webm": ".webm"
} as const;
type SupportTicketAttachmentContentType =
  keyof typeof SUPPORT_TICKET_ATTACHMENT_EXTENSIONS;
const SUPPORT_TICKET_ATTACHMENT_ALLOWED_CONTENT_TYPES = Object.keys(
  SUPPORT_TICKET_ATTACHMENT_EXTENSIONS
).join(", ");

interface SupportTicketInput {
  category: SupportTicketCategory;
  name?: string;
  email?: string;
  subject: string;
  message: string;
  clientLogs?: string;
  appVersion?: string;
  userAgent?: string;
}

interface SupportTicket extends SupportTicketInput {
  id: string;
  ownerUserId?: string;
  status: SupportTicketStatus;
  createdAt: string;
  updatedAt: string;
  attachments: SupportTicketAttachment[];
  replies: SupportTicketReply[];
}

interface SupportTicketReply {
  id: string;
  author: SupportTicketReplyAuthor;
  message: string;
  createdAt: string;
}

interface SupportTicketAttachmentUpload {
  fileName: string;
  contentType: SupportTicketAttachmentContentType;
  bytes: Buffer;
}

interface SupportTicketAttachment {
  id: string;
  fileName: string;
  contentType: SupportTicketAttachmentContentType;
  sizeBytes: number;
  storedFileName: string;
}

interface TicketReplyPushNotificationResult {
  targeted: number;
  delivered: number;
  failed: number;
  invalidRemoved: number;
  skipped: boolean;
  reason: string | null;
}

interface AuthResponse {
  token: string;
  user: AuthUser & { isAdmin: boolean; isSuperAdmin: boolean };
  recoveryCode?: string;
}

function readConfiguredRecoveryQuestions(user: {
  recoveryQuestionOne?: string;
  recoveryQuestionTwo?: string;
}) {
  if (!user.recoveryQuestionOne || !user.recoveryQuestionTwo) {
    return null;
  }

  return {
    questionOne: user.recoveryQuestionOne,
    questionTwo: user.recoveryQuestionTwo
  };
}

function buildRecoveryLockTimestamp(now = new Date()) {
  const lockUntil = new Date(
    now.getTime() + RECOVERY_LOCK_WINDOW_MINUTES * 60 * 1000
  );
  return lockUntil.toISOString();
}

function getRecoveryLockRemainingMinutes(user: { recoveryLockedUntil?: string }) {
  if (!user.recoveryLockedUntil) {
    return 0;
  }

  const remainingMs = new Date(user.recoveryLockedUntil).getTime() - Date.now();
  if (!Number.isFinite(remainingMs) || remainingMs <= 0) {
    return 0;
  }

  return Math.ceil(remainingMs / 60000);
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

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
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

function isTimeString(value: unknown): value is string {
  return typeof value === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

function toMinutesOfDay(value: string) {
  const [hoursPart, minutesPart] = value.split(":");
  return Number(hoursPart) * 60 + Number(minutesPart);
}

function isScheduleTimingConsistent(daySchedule: DaySchedule) {
  if ((daySchedule.startTime === undefined) !== (daySchedule.endTime === undefined)) {
    return false;
  }

  if (daySchedule.startTime === undefined || daySchedule.endTime === undefined) {
    return true;
  }

  const elapsedMinutes =
    toMinutesOfDay(daySchedule.endTime) - toMinutesOfDay(daySchedule.startTime);

  if (elapsedMinutes < 0 || daySchedule.breakMinutes > elapsedMinutes) {
    return false;
  }

  return elapsedMinutes - daySchedule.breakMinutes === daySchedule.targetMinutes;
}

function parseDaySchedule(value: unknown): DaySchedule | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const scheduleValue = value as Record<string, unknown>;
  if (!isNonNegativeInteger(scheduleValue.targetMinutes)) {
    return null;
  }

  const breakMinutes = scheduleValue.breakMinutes === undefined
    ? 0
    : scheduleValue.breakMinutes;
  if (!isNonNegativeInteger(breakMinutes)) {
    return null;
  }

  const startTime = scheduleValue.startTime;
  const endTime = scheduleValue.endTime;
  if (
    (startTime !== undefined && !isTimeString(startTime)) ||
    (endTime !== undefined && !isTimeString(endTime))
  ) {
    return null;
  }

  const daySchedule: DaySchedule = {
    targetMinutes: scheduleValue.targetMinutes,
    startTime,
    endTime,
    breakMinutes
  };

  if (!isScheduleTimingConsistent(daySchedule)) {
    return null;
  }

  return daySchedule;
}

function parseWeekdaySchedule(value: unknown): WeekdaySchedule | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const scheduleByWeekday = value as Record<string, unknown>;
  const weekdaySchedule = {} as WeekdaySchedule;

  for (const key of WEEKDAY_KEYS) {
    const daySchedule = parseDaySchedule(scheduleByWeekday[key]);
    if (!daySchedule) {
      return null;
    }

    weekdaySchedule[key] = daySchedule;
  }

  return weekdaySchedule;
}

function buildWeekdayScheduleFromTargetMinutes(
  weekdayTargetMinutes: WeekdayTargetMinutes
): WeekdaySchedule {
  const weekdaySchedule = {} as WeekdaySchedule;

  for (const key of WEEKDAY_KEYS) {
    weekdaySchedule[key] = {
      targetMinutes: weekdayTargetMinutes[key],
      breakMinutes: 0
    };
  }

  return weekdaySchedule;
}

function deriveWeekdayTargetMinutesFromSchedule(
  weekdaySchedule: WeekdaySchedule
): WeekdayTargetMinutes {
  const weekdayTargetMinutes = {} as WeekdayTargetMinutes;

  for (const key of WEEKDAY_KEYS) {
    weekdayTargetMinutes[key] = weekdaySchedule[key].targetMinutes;
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

function getRuntimeDirectory(envName: "MOBILE_UPDATES_DIR" | "TICKETS_DIR", leaf: string) {
  const configuredDirectory = process.env[envName]?.trim();
  if (configuredDirectory) {
    return configuredDirectory;
  }

  if (process.cwd() === "/app") {
    return path.posix.join("/app", leaf);
  }

  return path.join(process.cwd(), ".runtime-data", leaf);
}

function getUpdatesDirectory() {
  return getRuntimeDirectory("MOBILE_UPDATES_DIR", "updates");
}

function getReleaseMetadataPath() {
  return path.join(getUpdatesDirectory(), "latest-release.json");
}

function getReleaseStatusPath() {
  return path.join(getUpdatesDirectory(), "release-status.json");
}

function getTicketsDirectory() {
  return getRuntimeDirectory("TICKETS_DIR", "tickets");
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

function isTechnicalUpdateLine(value: string) {
  const normalized = value.toLowerCase();
  const technicalHints = [
    "ci",
    "cd",
    "pipeline",
    "workflow",
    "docker",
    "commit",
    "merge",
    "build",
    "gradle",
    "flutter",
    "backend",
    "frontend",
    "api",
    "sha",
    "lint",
    "test"
  ];

  return (
    /^([a-z]+)\s*:/.test(normalized) ||
    technicalHints.some((hint) => normalized.includes(hint))
  );
}

function normalizeUpdateNotificationLine(line: string) {
  return line
    .trim()
    .replace(/^[-*+]\s+/, "")
    .replace(/^\d+\.\s+/, "")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
}

function buildUpdateNotificationBody(releaseNotes?: string) {
  if (typeof releaseNotes === "string" && releaseNotes.trim().length > 0) {
    const candidateLine = releaseNotes
      .split(/\r?\n/)
      .map((line) => normalizeUpdateNotificationLine(line))
      .find((line) => {
        if (!line || line.startsWith("#")) {
          return false;
        }

        return !isTechnicalUpdateLine(line);
      });

    if (candidateLine) {
      return candidateLine.length > 140
        ? `${candidateLine.slice(0, 137)}...`
        : candidateLine;
    }
  }

  return "Nuova versione disponibile. Apri l app per vedere le novita.";
}

function buildUpdateNotificationKey(metadata: MobileReleaseMetadata) {
  const rawKey = `app_update_${metadata.version}_${metadata.buildNumber}`;
  const normalizedKey = rawKey
    .replace(/[^a-zA-Z0-9_.-]/g, "_")
    .slice(0, 64);
  return normalizedKey.length > 0 ? normalizedKey : "app_update";
}

function buildUpdatePushPayload(metadata: MobileReleaseMetadata) {
  const notificationKey = buildUpdateNotificationKey(metadata);
  const body = buildUpdateNotificationBody(metadata.releaseNotes);
  return {
    title: `Nuovo aggiornamento ${metadata.version}`,
    body,
    androidChannelId: MOBILE_PUSH_UPDATE_CHANNEL_ID,
    // Prevent duplicate notifications for the same release while still
    // allowing a visible notification for each new version.
    androidNotificationTag: notificationKey,
    androidCollapseKey: notificationKey,
    data: {
      type: "app_update",
      message: body,
      version: metadata.version,
      tag: metadata.tag,
      buildNumber: metadata.buildNumber
    }
  };
}

function parseMobilePushTokenPayload(payload: unknown): {
  value: {
    token: string;
    platform?: string;
    appVersion?: string;
  } | null;
  error?: string;
} {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  const token = typeof body.token === "string" ? body.token.trim() : "";
  if (token.length < 20 || token.length > 4096) {
    return { value: null, error: "token is invalid" };
  }

  const platform = normalizeOptionalText(body.platform, 30);
  const appVersion = normalizeOptionalText(body.appVersion, 40);
  return {
    value: {
      token,
      platform: platform || undefined,
      appVersion: appVersion || undefined
    }
  };
}

function getMobilePushNotifyToken() {
  const value = normalizeRuntimeEnvValue(process.env.MOBILE_PUSH_NOTIFY_TOKEN);
  return value ?? null;
}

function isSupportTicketCategory(value: unknown): value is SupportTicketCategory {
  return value === "bug" || value === "feature" || value === "support";
}

function isSupportTicketStatus(value: unknown): value is SupportTicketStatus {
  return (
    value === "new" ||
    value === "in_progress" ||
    value === "answered" ||
    value === "closed"
  );
}

function isSupportTicketReplyAuthor(
  value: unknown
): value is SupportTicketReplyAuthor {
  return value === "admin" || value === "user";
}

function isSupportTicketAttachmentContentType(
  value: unknown
): value is SupportTicketAttachmentContentType {
  return typeof value === "string" && value in SUPPORT_TICKET_ATTACHMENT_EXTENSIONS;
}

function normalizeSupportTicketAttachmentFileName(
  value: unknown,
  contentType: SupportTicketAttachmentContentType
) {
  const extension = SUPPORT_TICKET_ATTACHMENT_EXTENSIONS[contentType];
  const rawFileName = typeof value === "string" ? path.basename(value.trim()) : "";
  const normalizedBaseName = path
    .parse(rawFileName)
    .name
    .replace(/[^a-zA-Z0-9 _.-]+/g, "_")
    .trim()
    .slice(0, 80);

  const fallbackBaseName = contentType.startsWith("audio/")
    ? "vocale"
    : "screenshot";
  return `${normalizedBaseName || fallbackBaseName}${extension}`;
}

function parseSupportTicketAttachments(
  value: unknown
): { value: SupportTicketAttachmentUpload[]; error?: string } {
  if (value === undefined) {
    return { value: [] };
  }

  if (!Array.isArray(value)) {
    return { value: [], error: "attachments must be an array" };
  }

  if (value.length > SUPPORT_TICKET_MAX_ATTACHMENTS) {
    return {
      value: [],
      error:
        `attachments can contain at most ${SUPPORT_TICKET_MAX_ATTACHMENTS} files`
    };
  }

  const attachments: SupportTicketAttachmentUpload[] = [];
  for (const attachmentValue of value) {
    if (!attachmentValue || typeof attachmentValue !== "object") {
      return { value: [], error: "attachment must be an object" };
    }

    const attachment = attachmentValue as Record<string, unknown>;
    if (!isSupportTicketAttachmentContentType(attachment.contentType)) {
      return {
        value: [],
        error:
          `attachment contentType must be one of: ${SUPPORT_TICKET_ATTACHMENT_ALLOWED_CONTENT_TYPES}`
      };
    }

    const base64Data = typeof attachment.base64Data === "string"
      ? attachment.base64Data.trim()
      : "";
    if (
      base64Data.length === 0 ||
      base64Data.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]+=*$/.test(base64Data)
    ) {
      return { value: [], error: "attachment base64Data is invalid" };
    }

    const bytes = Buffer.from(base64Data, "base64");
    if (bytes.length === 0) {
      return { value: [], error: "attachment file is empty" };
    }

    if (bytes.length > SUPPORT_TICKET_MAX_ATTACHMENT_BYTES) {
      return {
        value: [],
        error: `attachment exceeds ${SUPPORT_TICKET_MAX_ATTACHMENT_BYTES} bytes`
      };
    }

    attachments.push({
      fileName: normalizeSupportTicketAttachmentFileName(
        attachment.fileName,
        attachment.contentType
      ),
      contentType: attachment.contentType,
      bytes
    });
  }

  return { value: attachments };
}

function normalizeOptionalText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalizedValue = value.trim();
  if (normalizedValue.length === 0) {
    return undefined;
  }

  return normalizedValue.slice(0, maxLength);
}

function normalizeOptionalLogText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalizedValue = value.replace(/\r\n/g, "\n").trim();
  if (normalizedValue.length === 0) {
    return undefined;
  }

  return normalizedValue.slice(0, maxLength);
}

function normalizeRequiredText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }

  const normalizedValue = value.trim();
  if (normalizedValue.length === 0) {
    return null;
  }

  return normalizedValue.slice(0, maxLength);
}

function parseProfilePayload(
  payload: unknown,
  fallbackId: string
): { value: Profile | null; error?: string } {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid profile payload" };
  }

  const body = payload as Record<string, unknown>;
  if (typeof body.fullName !== "string" || body.fullName.trim().length === 0) {
    return { value: null, error: "fullName is required" };
  }

  const useUniformDailyTarget =
    body.useUniformDailyTarget === undefined
      ? true
      : body.useUniformDailyTarget === true;
  if (
    body.useUniformDailyTarget !== undefined &&
    typeof body.useUniformDailyTarget !== "boolean"
  ) {
    return {
      value: null,
      error: "useUniformDailyTarget must be a boolean"
    };
  }

  const parsedWeekdayTargetMinutes = parseWeekdayTargetMinutes(
    body.weekdayTargetMinutes
  );
  if (
    body.weekdayTargetMinutes !== undefined &&
    parsedWeekdayTargetMinutes === null
  ) {
    return {
      value: null,
      error:
        "weekdayTargetMinutes must include monday-sunday non-negative integers"
    };
  }

  const parsedWeekdaySchedule = parseWeekdaySchedule(body.weekdaySchedule);
  if (body.weekdaySchedule !== undefined && parsedWeekdaySchedule === null) {
    return {
      value: null,
      error:
        "weekdaySchedule must include monday-sunday targetMinutes, optional startTime/endTime in HH:MM and non-negative breakMinutes"
    };
  }

  if (
    useUniformDailyTarget &&
    parsedWeekdaySchedule === null &&
    !isPositiveInteger(body.dailyTargetMinutes)
  ) {
    return {
      value: null,
      error: "dailyTargetMinutes must be a positive integer"
    };
  }

  const weekdayTargetMinutes = parsedWeekdaySchedule
    ? deriveWeekdayTargetMinutesFromSchedule(parsedWeekdaySchedule)
    : useUniformDailyTarget
      ? buildUniformWeekdayTargetMinutes(body.dailyTargetMinutes as number)
      : parsedWeekdayTargetMinutes;

  if (!weekdayTargetMinutes) {
    return {
      value: null,
      error:
        "weekdayTargetMinutes or weekdaySchedule is required when useUniformDailyTarget is false"
    };
  }

  const weekdaySchedule =
    parsedWeekdaySchedule ??
    buildWeekdayScheduleFromTargetMinutes(weekdayTargetMinutes);

  const dailyTargetMinutes = deriveDailyTargetMinutes(
    useUniformDailyTarget,
    isPositiveInteger(body.dailyTargetMinutes) && parsedWeekdaySchedule === null
      ? body.dailyTargetMinutes
      : undefined,
    weekdayTargetMinutes
  );
  const parsedWorkRules =
    body.workRules === undefined
      ? buildDefaultWorkRules({
          dailyTargetMinutes,
          weekdaySchedule
        })
      : parseWorkRulesPayload(body.workRules);

  if (body.workRules !== undefined && parsedWorkRules === null) {
    return {
      value: null,
      error:
        "workRules must include expectedDailyMinutes > 0, minimumBreakMinutes >= 0 and non-negative daily or monthly limits"
    };
  }

  if (parsedWorkRules === null) {
    return {
      value: null,
      error: "workRules are required"
    };
  }

  return {
    value: {
      id:
        typeof body.id === "string" && body.id.trim().length > 0
          ? body.id.trim()
          : fallbackId,
      fullName: body.fullName.trim(),
      useUniformDailyTarget,
      dailyTargetMinutes,
      weekdayTargetMinutes,
      weekdaySchedule,
      workRules: parsedWorkRules
    }
  };
}

function parseWorkRulesPayload(payload: unknown): Profile["workRules"] | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const body = payload as Record<string, unknown>;
  if (
    !isPositiveInteger(body.expectedDailyMinutes) ||
    !isNonNegativeInteger(body.minimumBreakMinutes) ||
    !isNonNegativeInteger(body.maximumDailyCreditMinutes) ||
    !isNonNegativeInteger(body.maximumDailyDebitMinutes) ||
    !isNonNegativeInteger(body.maximumMonthlyCreditMinutes) ||
    !isNonNegativeInteger(body.maximumMonthlyDebitMinutes)
  ) {
    return null;
  }

  const parseOptionalFlag = (value: unknown) => value === true;
  const parseOptionalMinutes = (value: unknown) =>
    isNonNegativeInteger(value) ? value : 0;
  const parseOptionalDays = (value: unknown) =>
    isNonNegativeInteger(value) ? value : 0;
  const parsePauseAdjustmentMode = (value: unknown) =>
    value === "keep_end_time" ? "keep_end_time" : "keep_worked_minutes";
  const permissionMovements = new Set<WorkPermissionMovement>([
    "entry_late",
    "exit_early",
    "entry_early",
    "exit_late"
  ]);
  const permissionPeriods = new Set<WorkAllowancePeriod>([
    "daily",
    "weekly",
    "monthly",
    "yearly"
  ]);
  const permissionAllowanceTypes = new Set<WorkPermissionAllowanceType>([
    "hours",
    "days",
    "both"
  ]);

  const parsePermissionRules = (value: unknown): WorkPermissionRule[] => {
    if (!Array.isArray(value)) {
      return [];
    }

    return value.flatMap((entry) => {
      if (!entry || typeof entry !== "object") {
        return [];
      }

      const rule = entry as Record<string, unknown>;
      if (
        typeof rule.id !== "string" ||
        rule.id.trim().length === 0 ||
        typeof rule.name !== "string" ||
        rule.name.trim().length === 0
      ) {
        return [];
      }

      const movements: WorkPermissionMovement[] = Array.isArray(rule.movements)
        ? rule.movements.flatMap((movement) =>
          typeof movement === "string" &&
            permissionMovements.has(movement as WorkPermissionMovement)
            ? [movement as WorkPermissionMovement]
            : []
        )
        : [];
      const allowanceMinutes = parseOptionalMinutes(rule.allowanceMinutes);
      const usedMinutes = parseOptionalMinutes(rule.usedMinutes);
      const allowanceDays = parseOptionalDays(rule.allowanceDays);
      const usedDays = parseOptionalDays(rule.usedDays);
      const allowanceType: WorkPermissionAllowanceType =
        typeof rule.allowanceType === "string" &&
          permissionAllowanceTypes.has(
            rule.allowanceType as WorkPermissionAllowanceType
          )
          ? (rule.allowanceType as WorkPermissionAllowanceType)
          : allowanceDays > 0
            ? allowanceMinutes > 0
              ? "both"
              : "days"
            : "hours";

      return [
        {
          id: rule.id.trim(),
          name: rule.name.trim(),
          enabled: rule.enabled !== false,
          allowanceType,
          period:
            typeof rule.period === "string" &&
              permissionPeriods.has(rule.period as WorkAllowancePeriod)
              ? (rule.period as WorkAllowancePeriod)
              : "monthly",
          allowanceMinutes,
          usedMinutes,
          allowanceDays,
          usedDays,
          movements:
            movements.length > 0 ? movements : ["entry_late", "exit_early"]
        }
      ];
    });
  };

  return {
    expectedDailyMinutes: body.expectedDailyMinutes,
    minimumBreakMinutes: body.minimumBreakMinutes,
    maximumDailyCreditMinutes: body.maximumDailyCreditMinutes,
    maximumDailyDebitMinutes: body.maximumDailyDebitMinutes,
    maximumMonthlyCreditMinutes: body.maximumMonthlyCreditMinutes,
    maximumMonthlyDebitMinutes: body.maximumMonthlyDebitMinutes,
    overtimeEnabled: parseOptionalFlag(body.overtimeEnabled),
    overtimeCapEnabled: parseOptionalFlag(body.overtimeCapEnabled),
    overtimeDailyCapMinutes: parseOptionalMinutes(body.overtimeDailyCapMinutes),
    overtimeWeeklyCapMinutes: parseOptionalMinutes(body.overtimeWeeklyCapMinutes),
    overtimeMonthlyCapMinutes: parseOptionalMinutes(
      body.overtimeMonthlyCapMinutes
    ),
    fixedScheduleEnabled: parseOptionalFlag(body.fixedScheduleEnabled),
    flexibleStartEnabled: parseOptionalFlag(body.flexibleStartEnabled),
    flexibleStartWindowMinutes: parseOptionalMinutes(
      body.flexibleStartWindowMinutes
    ),
    walletEnabled: parseOptionalFlag(body.walletEnabled),
    walletDailyExitEarlyMinutes: parseOptionalMinutes(
      body.walletDailyExitEarlyMinutes
    ),
    walletWeeklyExitEarlyMinutes: parseOptionalMinutes(
      body.walletWeeklyExitEarlyMinutes
    ),
    implicitCreditEnabled: parseOptionalFlag(body.implicitCreditEnabled),
    implicitCreditDailyCapMinutes: parseOptionalMinutes(
      body.implicitCreditDailyCapMinutes
    ),
    pauseAdjustmentMode: parsePauseAdjustmentMode(body.pauseAdjustmentMode),
    additionalPermissions: parsePermissionRules(body.additionalPermissions),
    leaveBanks: parsePermissionRules(body.leaveBanks)
  };
}

function parseWorkEntryRecord(payload: unknown): WorkEntry | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const body = payload as Record<string, unknown>;
  if (
    typeof body.id !== "string" ||
    typeof body.date !== "string" ||
    !isIsoDate(body.date) ||
    !isNonNegativeInteger(body.minutes)
  ) {
    return null;
  }

  if (body.note !== undefined && typeof body.note !== "string") {
    return null;
  }

  return {
    id: body.id,
    date: body.date,
    minutes: body.minutes,
    note: typeof body.note === "string" ? body.note : undefined
  };
}

function parseLeaveEntryRecord(payload: unknown): LeaveEntry | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const body = payload as Record<string, unknown>;
  if (
    typeof body.id !== "string" ||
    typeof body.date !== "string" ||
    !isIsoDate(body.date) ||
    !isNonNegativeInteger(body.minutes) ||
    !isLeaveType(body.type)
  ) {
    return null;
  }

  if (body.note !== undefined && typeof body.note !== "string") {
    return null;
  }

  return {
    id: body.id,
    date: body.date,
    minutes: body.minutes,
    type: body.type,
    note: typeof body.note === "string" ? body.note : undefined
  };
}

function parseScheduleOverrideRecord(payload: unknown): ScheduleOverride | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const body = payload as Record<string, unknown>;
  if (
    typeof body.id !== "string" ||
    typeof body.date !== "string" ||
    !isIsoDate(body.date) ||
    !isNonNegativeInteger(body.targetMinutes)
  ) {
    return null;
  }

  const breakMinutes = body.breakMinutes === undefined ? 0 : body.breakMinutes;
  if (!isNonNegativeInteger(breakMinutes)) {
    return null;
  }

  if (
    (body.startTime !== undefined && !isTimeString(body.startTime)) ||
    (body.endTime !== undefined && !isTimeString(body.endTime))
  ) {
    return null;
  }

  if (body.note !== undefined && typeof body.note !== "string") {
    return null;
  }

  const value: ScheduleOverride = {
    id: body.id,
    date: body.date,
    targetMinutes: body.targetMinutes,
    startTime: body.startTime,
    endTime: body.endTime,
    breakMinutes,
    note: typeof body.note === "string" ? body.note : undefined
  };

  return isScheduleTimingConsistent(value) ? value : null;
}

function parseAppearanceSettingsRecord(
  payload: unknown
): AppearanceSettingsRecord | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const body = payload as Record<string, unknown>;
  if (
    body.themeMode !== "light" &&
    body.themeMode !== "dark" &&
    body.themeMode !== "system"
  ) {
    return null;
  }

  if (
    !Number.isInteger(body.primaryColor) ||
    !Number.isInteger(body.secondaryColor) ||
    typeof body.fontFamily !== "string" ||
    typeof body.textScale !== "number"
  ) {
    return null;
  }

  if (body.textColor !== undefined && !Number.isInteger(body.textColor)) {
    return null;
  }

  if (body.textScale < 0.8 || body.textScale > 1.5) {
    return null;
  }

  return {
    themeMode: body.themeMode,
    primaryColor: body.primaryColor as number,
    secondaryColor: body.secondaryColor as number,
    textColor: body.textColor as number | undefined,
    fontFamily: body.fontFamily,
    textScale: body.textScale
  };
}

function parseWorkdaySessionRecord(
  value: unknown
): WorkdaySessionRecord | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const body = value as Record<string, unknown>;
  if (!isNonNegativeInteger(body.startMinutes)) {
    return null;
  }

  const breakSegments: WorkdayBreakSegmentRecord[] = [];
  if (Array.isArray(body.breakSegments)) {
    for (const rawSegment of body.breakSegments) {
      if (!rawSegment || typeof rawSegment !== "object") {
        continue;
      }
      const segment = rawSegment as Record<string, unknown>;
      if (
        isNonNegativeInteger(segment.startMinutes) &&
        isNonNegativeInteger(segment.endMinutes) &&
        segment.endMinutes > segment.startMinutes
      ) {
        breakSegments.push({
          startMinutes: segment.startMinutes,
          endMinutes: segment.endMinutes
        });
      }
    }
  }

  return {
    startMinutes: body.startMinutes,
    ...(isNonNegativeInteger(body.breakStartedMinutes)
      ? { breakStartedMinutes: body.breakStartedMinutes }
      : {}),
    accumulatedBreakMinutes: isNonNegativeInteger(body.accumulatedBreakMinutes)
      ? body.accumulatedBreakMinutes
      : 0,
    breakSegments,
    ...(isNonNegativeInteger(body.endMinutes)
      ? { endMinutes: body.endMinutes }
      : {})
  };
}

function parseWorkdaySessionsRecord(
  value: unknown
): { sessions: Record<string, WorkdaySessionRecord>; dropped: number } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { sessions: {}, dropped: 0 };
  }

  const sessions: Record<string, WorkdaySessionRecord> = {};
  let dropped = 0;
  for (const [date, rawSession] of Object.entries(
    value as Record<string, unknown>
  )) {
    const session = parseWorkdaySessionRecord(rawSession);
    if (isIsoDate(date) && session) {
      sessions[date] = session;
    } else {
      dropped += 1;
    }
  }

  return { sessions, dropped };
}

function parseCloudBackupPayload(
  payload: unknown,
  fallbackProfileId: string
): {
  value: CloudBackupRecord | null;
  error?: string;
  droppedItems?: {
    workEntries: number;
    leaveEntries: number;
    scheduleOverrides: number;
    workdaySessions: number;
  };
} {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  const parsedProfile = parseProfilePayload(body.profile, fallbackProfileId);
  if (!parsedProfile.value) {
    return { value: null, error: parsedProfile.error ?? "Invalid profile" };
  }

  const appearanceSettings = parseAppearanceSettingsRecord(
    body.appearanceSettings
  );
  if (!appearanceSettings) {
    return {
      value: null,
      error:
        "appearanceSettings must include themeMode, colors, fontFamily and textScale"
    };
  }

  if (
    !Array.isArray(body.workEntries) ||
    !Array.isArray(body.leaveEntries) ||
    !Array.isArray(body.scheduleOverrides)
  ) {
    return {
      value: null,
      error:
        "workEntries, leaveEntries and scheduleOverrides must contain valid items"
    };
  }

  const parsedWorkEntries = body.workEntries
    .map(parseWorkEntryRecord)
    .filter((entry): entry is WorkEntry => entry !== null);
  const parsedLeaveEntries = body.leaveEntries
    .map(parseLeaveEntryRecord)
    .filter((entry): entry is LeaveEntry => entry !== null);
  const parsedScheduleOverrides = body.scheduleOverrides
    .map(parseScheduleOverrideRecord)
    .filter((entry): entry is ScheduleOverride => entry !== null);
  const parsedWorkdaySessions = parseWorkdaySessionsRecord(
    body.workdaySessions
  );

  const droppedItems = {
    workEntries: body.workEntries.length - parsedWorkEntries.length,
    leaveEntries: body.leaveEntries.length - parsedLeaveEntries.length,
    scheduleOverrides:
      body.scheduleOverrides.length - parsedScheduleOverrides.length,
    workdaySessions: parsedWorkdaySessions.dropped
  };

  return {
    value: {
      profile: parsedProfile.value,
      appearanceSettings,
      workEntries: parsedWorkEntries,
      leaveEntries: parsedLeaveEntries,
      scheduleOverrides: parsedScheduleOverrides,
      workdaySessions: parsedWorkdaySessions.sessions,
      updatedAt: new Date().toISOString()
    },
    droppedItems
  };
}

async function readAuthenticatedUser(
  request: FastifyRequest,
  store: AppStore
): Promise<{ user: AuthUser | null; tokenHash: string | null }> {
  const authorization = request.headers.authorization;
  if (typeof authorization !== "string") {
    return { user: null, tokenHash: null };
  }

  const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!bearerMatch) {
    return { user: null, tokenHash: null };
  }

  const token = bearerMatch[1]?.trim();
  if (!token) {
    return { user: null, tokenHash: null };
  }

  const tokenHash = hashSessionToken(token);
  const user = await store.findAuthUserByTokenHash(tokenHash);
  return { user, tokenHash };
}

function logCloudAuthRejection(request: FastifyRequest, endpoint: string) {
  const authorization =
    typeof request.headers.authorization === "string"
      ? request.headers.authorization
      : "";
  const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);

  request.log.warn(
    {
      endpoint,
      hasAuthorizationHeader: authorization.length > 0,
      hasBearerToken: bearerMatch !== null,
      bearerTokenLength: bearerMatch?.[1]?.trim().length ?? 0
    },
    "Cloud request rejected due to missing or invalid auth session"
  );
}

function parseSupportTicketInput(
  payload: unknown,
  userAgent: string | undefined
): {
  value: SupportTicketInput | null;
  attachments: SupportTicketAttachmentUpload[];
  error?: string;
} {
  if (!payload || typeof payload !== "object") {
    return { value: null, attachments: [], error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  if (!isSupportTicketCategory(body.category)) {
    return {
      value: null,
      attachments: [],
      error: "category must be one of: bug, feature, support"
    };
  }

  const subject = normalizeRequiredText(body.subject, 160);
  if (!subject) {
    return { value: null, attachments: [], error: "subject is required" };
  }

  const message = normalizeRequiredText(body.message, 4000);
  if (!message) {
    return { value: null, attachments: [], error: "message is required" };
  }

  const email = normalizeOptionalText(body.email, 160);
  if (email && !isValidEmail(email)) {
    return { value: null, attachments: [], error: "email must be valid" };
  }

  const parsedAttachments = parseSupportTicketAttachments(body.attachments);
  if (parsedAttachments.error) {
    return {
      value: null,
      attachments: [],
      error: parsedAttachments.error
    };
  }

  return {
    value: {
      category: body.category,
      name: normalizeOptionalText(body.name, 120),
      email,
      subject,
      message,
      clientLogs: normalizeOptionalLogText(body.clientLogs, 12000),
      appVersion: normalizeOptionalText(body.appVersion, 40),
      userAgent
    },
    attachments: parsedAttachments.value
  };
}

async function saveSupportTicket(
  input: SupportTicketInput,
  attachments: SupportTicketAttachmentUpload[] = [],
  options?: { ownerUserId?: string }
): Promise<SupportTicket> {
  const now = new Date().toISOString();
  const ticketId = randomUUID();
  const ticket: SupportTicket = {
    id: ticketId,
    ownerUserId: options?.ownerUserId,
    status: "new",
    createdAt: now,
    updatedAt: now,
    attachments: [],
    replies: [],
    ...input
  };

  const createdAttachmentPaths: string[] = [];
  try {
    for (const attachment of attachments) {
      const attachmentId = randomUUID();
      const extension = SUPPORT_TICKET_ATTACHMENT_EXTENSIONS[attachment.contentType];
      const storedFileName = `${attachmentId}${extension}`;
      const attachmentPath = getSupportTicketAttachmentPath(ticket.id, storedFileName);
      if (!attachmentPath) {
        throw new Error("Invalid attachment path");
      }

      await fs.mkdir(path.dirname(attachmentPath), { recursive: true });
      await fs.writeFile(attachmentPath, attachment.bytes);
      createdAttachmentPaths.push(attachmentPath);
      ticket.attachments.push({
        id: attachmentId,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        sizeBytes: attachment.bytes.length,
        storedFileName
      });
    }

    await fs.mkdir(getTicketsDirectory(), { recursive: true });
    await fs.writeFile(
      path.join(getTicketsDirectory(), `${ticket.id}.json`),
      JSON.stringify(ticket, null, 2),
      "utf8"
    );
  } catch (error) {
    await Promise.all(
      createdAttachmentPaths.map((filePath) =>
        fs.rm(filePath, { force: true }).catch(() => undefined)
      )
    );
    throw error;
  }

  return ticket;
}

function getSupportTicketPath(ticketId: string) {
  if (!/^[a-zA-Z0-9-]+$/.test(ticketId)) {
    return null;
  }

  const ticketsDirectory = path.resolve(getTicketsDirectory());
  const ticketPath = path.resolve(ticketsDirectory, `${ticketId}.json`);
  if (!ticketPath.startsWith(`${ticketsDirectory}${path.sep}`)) {
    return null;
  }

  return ticketPath;
}

function getSupportTicketAttachmentPath(ticketId: string, storedFileName: string) {
  if (!/^[a-zA-Z0-9-]+$/.test(ticketId)) {
    return null;
  }

  if (!/^[a-zA-Z0-9-]+\.(png|jpg|webp|mp3|m4a|wav|ogg|aac|webm)$/.test(storedFileName)) {
    return null;
  }

  const ticketsDirectory = path.resolve(getTicketsDirectory());
  const attachmentPath = path.resolve(
    ticketsDirectory,
    "attachments",
    ticketId,
    storedFileName
  );
  if (!attachmentPath.startsWith(`${ticketsDirectory}${path.sep}`)) {
    return null;
  }

  return attachmentPath;
}

function serializeSupportTicket(ticket: SupportTicket) {
  const { ownerUserId: _ownerUserId, ...publicTicket } = ticket;
  return {
    ...publicTicket,
    attachments: ticket.attachments.map((attachment) => ({
      id: attachment.id,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      sizeBytes: attachment.sizeBytes,
      downloadPath: `/tickets/${encodeURIComponent(ticket.id)}/attachments/${encodeURIComponent(attachment.id)}`
    }))
  };
}

function normalizeSupportTicketRecord(value: unknown): SupportTicket | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const rawValue = value as Record<string, unknown>;
  if (
    typeof rawValue.id !== "string" ||
    !isSupportTicketCategory(rawValue.category) ||
    typeof rawValue.subject !== "string" ||
    typeof rawValue.message !== "string" ||
    typeof rawValue.createdAt !== "string"
  ) {
    return null;
  }

  const replies = Array.isArray(rawValue.replies)
    ? rawValue.replies.flatMap((replyValue) => {
        if (!replyValue || typeof replyValue !== "object") {
          return [];
        }

        const reply = replyValue as Record<string, unknown>;
        if (
          typeof reply.id !== "string" ||
          !isSupportTicketReplyAuthor(reply.author) ||
          typeof reply.message !== "string" ||
          typeof reply.createdAt !== "string"
        ) {
          return [];
        }

        return [
          {
            id: reply.id,
            author: reply.author,
            message: reply.message,
            createdAt: reply.createdAt
          }
        ];
      })
    : [];

  const attachments = Array.isArray(rawValue.attachments)
    ? rawValue.attachments.flatMap((attachmentValue) => {
        if (!attachmentValue || typeof attachmentValue !== "object") {
          return [];
        }

        const attachment = attachmentValue as Record<string, unknown>;
        if (
          typeof attachment.id !== "string" ||
          typeof attachment.fileName !== "string" ||
          !isSupportTicketAttachmentContentType(attachment.contentType) ||
          !isPositiveInteger(attachment.sizeBytes) ||
          typeof attachment.storedFileName !== "string"
        ) {
          return [];
        }

        return [
          {
            id: attachment.id,
            fileName: attachment.fileName,
            contentType: attachment.contentType,
            sizeBytes: attachment.sizeBytes,
            storedFileName: attachment.storedFileName
          }
        ];
      })
    : [];

  return {
    id: rawValue.id,
    category: rawValue.category,
    ownerUserId:
      typeof rawValue.ownerUserId === "string" &&
        rawValue.ownerUserId.trim().length > 0
        ? rawValue.ownerUserId.trim()
        : undefined,
    name: normalizeOptionalText(rawValue.name, 120),
    email: normalizeOptionalText(rawValue.email, 160),
    subject: rawValue.subject.trim(),
    message: rawValue.message.trim(),
    clientLogs: normalizeOptionalLogText(rawValue.clientLogs, 12000),
    appVersion: normalizeOptionalText(rawValue.appVersion, 40),
    userAgent: normalizeOptionalText(rawValue.userAgent, 400),
    createdAt: rawValue.createdAt,
    updatedAt:
      typeof rawValue.updatedAt === "string"
        ? rawValue.updatedAt
        : rawValue.createdAt,
    status: isSupportTicketStatus(rawValue.status) ? rawValue.status : "new",
    attachments,
    replies
  };
}

async function readSupportTicket(ticketId: string): Promise<SupportTicket | null> {
  const ticketPath = getSupportTicketPath(ticketId);
  if (!ticketPath) {
    return null;
  }

  try {
    const rawValue = await fs.readFile(ticketPath, "utf8");
    return normalizeSupportTicketRecord(JSON.parse(rawValue));
  } catch {
    return null;
  }
}

async function writeSupportTicket(ticket: SupportTicket) {
  await fs.mkdir(getTicketsDirectory(), { recursive: true });
  const ticketPath = getSupportTicketPath(ticket.id);
  if (!ticketPath) {
    throw new Error("Invalid ticket id");
  }

  await fs.writeFile(ticketPath, JSON.stringify(ticket, null, 2), "utf8");
}

async function listSupportTickets(): Promise<SupportTicket[]> {
  await fs.mkdir(getTicketsDirectory(), { recursive: true });
  const entries = await fs.readdir(getTicketsDirectory(), { withFileTypes: true });
  const tickets = await Promise.all(
    entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
      .map(async (entry) => {
        try {
          const rawValue = await fs.readFile(
            path.join(getTicketsDirectory(), entry.name),
            "utf8"
          );
          return normalizeSupportTicketRecord(JSON.parse(rawValue));
        } catch {
          return null;
        }
      })
  );

  return tickets
    .filter((ticket): ticket is SupportTicket => ticket !== null)
    .sort((left, right) =>
      right.updatedAt.localeCompare(left.updatedAt) ||
      right.createdAt.localeCompare(left.createdAt)
    );
}

async function appendSupportTicketReply(options: {
  ticketId: string;
  author: SupportTicketReplyAuthor;
  message: string;
  status?: SupportTicketStatus;
}) {
  const ticket = await readSupportTicket(options.ticketId);
  if (!ticket) {
    return null;
  }

  const now = new Date().toISOString();
  ticket.replies.push({
    id: randomUUID(),
    author: options.author,
    message: options.message,
    createdAt: now
  });
  ticket.status = options.status ?? "answered";
  ticket.updatedAt = now;
  await writeSupportTicket(ticket);

  return ticket;
}

async function notifySupportTicketReplyPush(options: {
  store: AppStore;
  ticket: SupportTicket;
  logger: FastifyRequest["log"];
}): Promise<TicketReplyPushNotificationResult> {
  const ownerUserId = options.ticket.ownerUserId
    ? options.ticket.ownerUserId
    : options.ticket.email
      ? (await options.store.findAuthUserByEmail(options.ticket.email))?.id
      : undefined;
  if (!ownerUserId) {
    return {
      targeted: 0,
      delivered: 0,
      failed: 0,
      invalidRemoved: 0,
      skipped: true,
      reason: "Ticket owner is not linked to an account"
    };
  }

  const uniqueTokens = [
    ...new Set(
      (await options.store.listMobilePushTokens())
        .filter((item) => item.userId === ownerUserId)
        .map((item) => item.token.trim())
        .filter((token) => token.length > 0)
    )
  ];
  if (uniqueTokens.length === 0) {
    return {
      targeted: 0,
      delivered: 0,
      failed: 0,
      invalidRemoved: 0,
      skipped: true,
      reason: "No mobile tokens registered for ticket owner"
    };
  }

  if (!isMobilePushConfigured()) {
    return {
      targeted: uniqueTokens.length,
      delivered: 0,
      failed: uniqueTokens.length,
      invalidRemoved: 0,
      skipped: true,
      reason: "FCM is not configured"
    };
  }

  try {
    const pushResult = await broadcastMobilePush({
      tokens: uniqueTokens,
      payload: {
        title: "Nuova risposta dal supporto",
        body: "Apri l app per leggere l aggiornamento del ticket.",
        androidChannelId: MOBILE_PUSH_TICKET_CHANNEL_ID,
        data: {
          type: "ticket_reply",
          ticketId: options.ticket.id,
          status: options.ticket.status
        }
      }
    });

    const removedInvalidTokens = pushResult.invalidTokens.length > 0
      ? await options.store.deleteMobilePushTokens(pushResult.invalidTokens)
      : 0;

    return {
      targeted: uniqueTokens.length,
      delivered: pushResult.sentCount,
      failed: pushResult.failedCount,
      invalidRemoved: removedInvalidTokens,
      skipped: pushResult.skipped,
      reason: pushResult.reason ?? null
    };
  } catch (error) {
    options.logger.error(
      {
        ticketId: options.ticket.id,
        err: error
      },
      "Unable to broadcast ticket reply push notification"
    );
    return {
      targeted: uniqueTokens.length,
      delivered: 0,
      failed: uniqueTokens.length,
      invalidRemoved: 0,
      skipped: true,
      reason: "Push broadcast failed"
    };
  }
}

function getAdminDashboardToken() {
  const token = process.env.ADMIN_DASHBOARD_TOKEN?.trim();
  return token && token.length > 0 ? token : null;
}

function isAdminDashboardTokenAuthorized(request: FastifyRequest) {
  const configuredToken = getAdminDashboardToken();
  if (!configuredToken) {
    return false;
  }

  const authorization = request.headers.authorization;
  if (typeof authorization === "string") {
    const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (bearerMatch && bearerMatch[1] === configuredToken) {
      return true;
    }
  }

  const headerToken = request.headers["x-admin-token"];
  return typeof headerToken === "string" && headerToken === configuredToken;
}

async function authorizeAdminRequest(
  request: FastifyRequest,
  store: AppStore
): Promise<{ authorized: boolean; statusCode?: number; error?: string }> {
  if (isAdminDashboardTokenAuthorized(request)) {
    return { authorized: true };
  }

  const { user } = await readAuthenticatedUser(request, store);
  if (!user) {
    return { authorized: false, statusCode: 401, error: "Unauthorized" };
  }

  if (!isAdminUser(user)) {
    return {
      authorized: false,
      statusCode: 403,
      error: "Admin profile required"
    };
  }

  return { authorized: true };
}

async function authorizeAdminProfileRequest(
  request: FastifyRequest,
  store: AppStore
): Promise<{
  authorized: boolean;
  user?: AuthUser;
  statusCode?: number;
  error?: string;
}> {
  const { user } = await readAuthenticatedUser(request, store);
  if (!user) {
    return { authorized: false, statusCode: 401, error: "Unauthorized" };
  }

  if (!isAdminUser(user)) {
    return {
      authorized: false,
      statusCode: 403,
      error: "Admin profile required"
    };
  }

  return { authorized: true, user };
}

async function authorizeSuperAdminProfileRequest(
  request: FastifyRequest,
  store: AppStore
): Promise<{
  authorized: boolean;
  user?: AuthUser;
  statusCode?: number;
  error?: string;
}> {
  const adminAccess = await authorizeAdminProfileRequest(request, store);
  if (!adminAccess.authorized || !adminAccess.user) {
    return adminAccess;
  }

  if (!isSuperAdminUser(adminAccess.user)) {
    return {
      authorized: false,
      statusCode: 403,
      error: "Super admin required"
    };
  }

  return adminAccess;
}




export function buildApp(options: BuildAppOptions = {}) {
  const store: AppStore = options.store ?? new InMemoryStore();
  const corsOrigin = process.env.CORS_ORIGIN;

  const app = Fastify({
    logger: true,
    bodyLimit: REQUEST_BODY_LIMIT_BYTES
  });

  void app.register(cors, {
    origin: corsOrigin ? corsOrigin.split(",").map((value) => value.trim()) : true
  });

  app.addHook("onReady", async () => {
    await syncConfiguredSuperAdmin(store);
  });

  app.get("/", async (request, reply) => {
    const latestRelease = await loadReleaseMetadata();
    const releaseStatus = await loadReleaseStatus();
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderLandingPage({ baseUrl, latestRelease, releaseStatus }));
  });

  app.get("/tickets", async (request, reply) => {
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderTicketPage({ baseUrl }));
  });

  app.post("/tickets", async (request, reply) => {
    const { value, attachments, error } = parseSupportTicketInput(
      request.body,
      typeof request.headers["user-agent"] === "string"
        ? request.headers["user-agent"]
        : undefined
    );
    if (!value) {
      return reply.code(400).send({ error: error ?? "Invalid ticket payload" });
    }

    const { user } = await readAuthenticatedUser(request, store);
    const savedTicket = await saveSupportTicket(value, attachments, {
      ownerUserId: user?.id
    });
    return reply.code(201).send(serializeSupportTicket(savedTicket));
  });

  app.get("/tickets/:ticketId", async (request, reply) => {
    const params = request.params as { ticketId?: unknown };
    if (typeof params.ticketId !== "string" || params.ticketId.length === 0) {
      return reply.code(400).send({ error: "ticketId is required" });
    }

    const ticket = await readSupportTicket(params.ticketId);
    if (!ticket) {
      return reply.code(404).send({ error: "Ticket not found" });
    }

    return serializeSupportTicket(ticket);
  });

  app.get("/tickets/:ticketId/attachments/:attachmentId", async (request, reply) => {
    const params = request.params as {
      ticketId?: unknown;
      attachmentId?: unknown;
    };
    if (
      typeof params.ticketId !== "string" ||
      params.ticketId.length === 0 ||
      typeof params.attachmentId !== "string" ||
      params.attachmentId.length === 0
    ) {
      return reply.code(400).send({ error: "ticketId and attachmentId are required" });
    }

    const ticket = await readSupportTicket(params.ticketId);
    if (!ticket) {
      return reply.code(404).send({ error: "Ticket not found" });
    }

    const attachment = ticket.attachments.find(
      (entry) => entry.id === params.attachmentId
    );
    if (!attachment) {
      return reply.code(404).send({ error: "Attachment not found" });
    }

    const attachmentPath = getSupportTicketAttachmentPath(
      ticket.id,
      attachment.storedFileName
    );
    if (!attachmentPath) {
      return reply.code(404).send({ error: "Attachment not found" });
    }

    try {
      await fs.access(attachmentPath);
    } catch {
      return reply.code(404).send({ error: "Attachment not found" });
    }

    reply
      .type(attachment.contentType)
      .header(
        "content-disposition",
        `inline; filename="${path.basename(attachment.fileName)}"`
      );

    return reply.send(createReadStream(attachmentPath));
  });

  app.post("/tickets/:ticketId/replies", async (request, reply) => {
    const params = request.params as { ticketId?: unknown };
    if (typeof params.ticketId !== "string" || params.ticketId.length === 0) {
      return reply.code(400).send({ error: "ticketId is required" });
    }

    const body =
      request.body && typeof request.body === "object"
        ? (request.body as Record<string, unknown>)
        : null;
    if (!body) {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const message = normalizeRequiredText(body.message, 4000);
    if (!message) {
      return reply.code(400).send({ error: "message is required" });
    }

    const updatedTicket = await appendSupportTicketReply({
      ticketId: params.ticketId,
      author: "user",
      message,
      status: "in_progress"
    });
    if (!updatedTicket) {
      return reply.code(404).send({ error: "Ticket not found" });
    }

    return serializeSupportTicket(updatedTicket);
  });

  app.get("/admin", async (request, reply) => {
    const baseUrl = getPublicBaseUrl(request);
    const superAdminConfigured = getConfiguredSuperAdminCredentials() !== null;

    return reply
      .type("text/html; charset=utf-8")
      .send(
        renderAdminPage({
          baseUrl,
          superAdminConfigured
        })
      );
  });

  app.get("/admin/api/overview", async (request, reply) => {
    const adminAccess = await authorizeAdminRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const baseUrl = getPublicBaseUrl(request);
    const latestRelease = await loadReleaseMetadata();
    const releaseStatus = await loadReleaseStatus();
    const tickets = await listSupportTickets();
    reply.header("cache-control", "no-store");

    return buildAdminOverview({
      baseUrl,
      latestRelease,
      releaseStatus,
      tickets
    });
  });

  app.get("/admin/api/tickets", async (request, reply) => {
    const adminAccess = await authorizeAdminRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    reply.header("cache-control", "no-store");
    return {
      items: (await listSupportTickets()).map(serializeSupportTicket)
    };
  });

  app.get("/admin/api/tickets/:ticketId", async (request, reply) => {
    const adminAccess = await authorizeAdminRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { ticketId?: unknown };
    if (typeof params.ticketId !== "string" || params.ticketId.length === 0) {
      return reply.code(400).send({ error: "ticketId is required" });
    }

    const ticket = await readSupportTicket(params.ticketId);
    if (!ticket) {
      return reply.code(404).send({ error: "Ticket not found" });
    }

    reply.header("cache-control", "no-store");
    return serializeSupportTicket(ticket);
  });

  app.get("/admin/api/users", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const queryValue =
      request.query && typeof request.query === "object"
        ? ((request.query as Record<string, unknown>).search ?? undefined)
        : undefined;
    const search =
      typeof queryValue === "string" ? queryValue.trim().toLowerCase() : "";
    const users = (await store.listAuthUsers()).map((user) => serializeAuthUser(user));

    const items = search.length > 0
      ? users.filter((user) => user.email.toLowerCase().includes(search))
      : users;

    return {
      items
    };
  });

  app.post("/admin/api/users", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const parsedPayload = parseAdminUserCreatePayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid user payload"
      });
    }

    const existingUser = await store.findAuthUserByEmail(parsedPayload.value.email);
    if (existingUser) {
      return reply.code(409).send({ error: "email already registered" });
    }

    const now = new Date().toISOString();
    const passwordDigest = createPasswordDigest(parsedPayload.value.password);
    const recoveryCode = createRecoveryCode();
    const recoveryCodeDigest = createRecoveryCodeDigest(recoveryCode);

    const createdUser = await store.createAuthUser({
      id: randomUUID(),
      email: parsedPayload.value.email,
      passwordHash: passwordDigest.hash,
      passwordSalt: passwordDigest.salt,
      recoveryCodeHash: recoveryCodeDigest.hash,
      recoveryCodeSalt: recoveryCodeDigest.salt,
      recoveryFailedAttempts: 0,
      role: parsedPayload.value.role,
      createdAt: now,
      updatedAt: now
    });

    return reply.code(201).send({
      user: serializeAuthUser(createdUser),
      recoveryCode
    });
  });

  app.patch("/admin/api/users/:userId", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { userId?: unknown };
    if (typeof params.userId !== "string" || params.userId.length === 0) {
      return reply.code(400).send({ error: "userId is required" });
    }

    const parsedPayload = parseAdminUserUpdatePayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid user payload"
      });
    }

    const users = await store.listAuthUsers();
    const targetUser = users.find((user) => user.id === params.userId) ?? null;
    if (!targetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    if (isSuperAdminUser(targetUser)) {
      return reply.code(409).send({
        error:
          "The super admin profile is managed from SUPER_ADMIN_EMAIL and cannot be changed here."
      });
    }

    const nextEmail = parsedPayload.value.email ?? targetUser.email;
    const nextRole = parsedPayload.value.role ?? targetUser.role;

    if (
      parsedPayload.value.role === "user" &&
      isLegacyAdminProfileEmail(targetUser.email) &&
      nextEmail === targetUser.email
    ) {
      return reply.code(409).send({
        error:
          "This admin is granted via ADMIN_EMAILS. Remove the email from ADMIN_EMAILS to revoke access."
      });
    }

    if (nextEmail !== targetUser.email) {
      const existingUser = await store.findAuthUserByEmail(nextEmail);
      if (existingUser && existingUser.id !== targetUser.id) {
        return reply.code(409).send({ error: "email already registered" });
      }
    }

    const currentIsAdmin = isAdminUser(targetUser);
    const nextIsAdmin = isAdminRole(
      getEffectiveAuthRole({
        email: nextEmail,
        role: nextRole
      })
    );
    if (currentIsAdmin && !nextIsAdmin) {
      const otherAdmins = users.filter(
        (user) => user.id !== targetUser.id && isAdminUser(user)
      );
      if (otherAdmins.length === 0) {
        return reply.code(409).send({
          error: "At least one admin profile must remain active"
        });
      }
    }

    const storedTargetUser = await store.findAuthUserByEmail(targetUser.email);
    if (!storedTargetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    const updatedUser = await store.updateStoredAuthUser({
      ...storedTargetUser,
      email: nextEmail,
      role: nextRole,
      updatedAt: new Date().toISOString()
    });
    if (!updatedUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    return serializeAuthUser(updatedUser);
  });

  app.delete("/admin/api/users/:userId", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { userId?: unknown };
    if (typeof params.userId !== "string" || params.userId.length === 0) {
      return reply.code(400).send({ error: "userId is required" });
    }

    const users = await store.listAuthUsers();
    const targetUser = users.find((user) => user.id === params.userId) ?? null;
    if (!targetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    if (isSuperAdminUser(targetUser)) {
      return reply.code(409).send({
        error:
          "The super admin profile is managed from SUPER_ADMIN_EMAIL and cannot be deleted here."
      });
    }

    if (isAdminUser(targetUser)) {
      const otherAdmins = users.filter(
        (user) => user.id !== targetUser.id && isAdminUser(user)
      );
      if (otherAdmins.length === 0) {
        return reply.code(409).send({
          error: "At least one admin profile must remain active"
        });
      }
    }

    const deleted = await store.deleteAuthUser(targetUser.id);
    if (!deleted) {
      return reply.code(404).send({ error: "User not found" });
    }

    return {
      deleted: true,
      userId: targetUser.id
    };
  });

  app.post("/admin/api/users/:userId/admin", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized || !adminAccess.user) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { userId?: unknown };
    if (typeof params.userId !== "string" || params.userId.length === 0) {
      return reply.code(400).send({ error: "userId is required" });
    }

    const parsedPayload = parseAdminRolePayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid role payload"
      });
    }

    const users = await store.listAuthUsers();
    const targetUser = users.find((user) => user.id === params.userId) ?? null;
    if (!targetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    if (!parsedPayload.value.isAdmin && isLegacyAdminProfileEmail(targetUser.email)) {
      return reply.code(409).send({
        error:
          "This admin is granted via ADMIN_EMAILS. Remove the email from ADMIN_EMAILS to revoke access."
      });
    }

    if (isSuperAdminUser(targetUser)) {
      return reply.code(409).send({
        error:
          "The super admin role is managed from SUPER_ADMIN_EMAIL and cannot be changed here."
      });
    }

    if (!parsedPayload.value.isAdmin && isAdminUser(targetUser)) {
      const otherAdmins = users.filter(
        (user) => user.id !== targetUser.id && isAdminUser(user)
      );
      if (otherAdmins.length === 0) {
        return reply.code(409).send({
          error: "At least one admin profile must remain active"
        });
      }
    }

    const updatedUser = await store.updateAuthUserRole(
      targetUser.id,
      parsedPayload.value.isAdmin ? "admin" : "user"
    );
    if (!updatedUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    return serializeAuthUser(updatedUser);
  });

  app.post("/admin/api/users/:userId/password", async (request, reply) => {
    const adminAccess = await authorizeSuperAdminProfileRequest(request, store);
    if (!adminAccess.authorized || !adminAccess.user) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { userId?: unknown };
    if (typeof params.userId !== "string" || params.userId.length === 0) {
      return reply.code(400).send({ error: "userId is required" });
    }

    const parsedPayload = parseAdminPasswordPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid password payload"
      });
    }

    const users = await store.listAuthUsers();
    const targetUser = users.find((user) => user.id === params.userId) ?? null;
    if (!targetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    if (isSuperAdminUser(targetUser)) {
      return reply.code(409).send({
        error:
          "The super admin password is managed from SUPER_ADMIN_PASSWORD and cannot be changed here."
      });
    }

    const storedTargetUser = await store.findAuthUserByEmail(targetUser.email);
    if (!storedTargetUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    const passwordDigest = createPasswordDigest(parsedPayload.value.newPassword);
    const updatedUser = await store.updateStoredAuthUser({
      ...storedTargetUser,
      passwordHash: passwordDigest.hash,
      passwordSalt: passwordDigest.salt,
      updatedAt: new Date().toISOString()
    });
    if (!updatedUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    return serializeAuthUser(updatedUser);
  });

  app.post("/admin/api/tickets/:ticketId/replies", async (request, reply) => {
    const adminAccess = await authorizeAdminRequest(request, store);
    if (!adminAccess.authorized) {
      return reply
        .code(adminAccess.statusCode ?? 401)
        .send({ error: adminAccess.error ?? "Unauthorized" });
    }

    const params = request.params as { ticketId?: unknown };
    if (typeof params.ticketId !== "string" || params.ticketId.length === 0) {
      return reply.code(400).send({ error: "ticketId is required" });
    }

    const body =
      request.body && typeof request.body === "object"
        ? (request.body as Record<string, unknown>)
        : null;
    if (!body) {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const message = normalizeRequiredText(body.message, 4000);
    if (!message) {
      return reply.code(400).send({ error: "message is required" });
    }

    const nextStatus =
      body.status === undefined
        ? undefined
        : isSupportTicketStatus(body.status)
          ? body.status
          : null;
    if (nextStatus === null) {
      return reply.code(400).send({
        error: "status must be one of: new, in_progress, answered, closed"
      });
    }

    const updatedTicket = await appendSupportTicketReply({
      ticketId: params.ticketId,
      author: "admin",
      message,
      status: nextStatus ?? undefined
    });
    if (!updatedTicket) {
      return reply.code(404).send({ error: "Ticket not found" });
    }

    const pushNotification = await notifySupportTicketReplyPush({
      store,
      ticket: updatedTicket,
      logger: request.log
    });

    return {
      ...serializeSupportTicket(updatedTicket),
      pushNotification
    };
  });

  app.post("/auth/register", async (request, reply) => {
    const parsedCredentials = parseAuthCredentials(request.body);
    if (!parsedCredentials.value) {
      return reply.code(400).send({
        error: parsedCredentials.error ?? "Invalid credentials"
      });
    }

    const existingUser = await store.findAuthUserByEmail(
      parsedCredentials.value.email
    );
    if (existingUser) {
      return reply.code(409).send({ error: "email already registered" });
    }

    const now = new Date().toISOString();
    const passwordDigest = createPasswordDigest(parsedCredentials.value.password);
    const recoveryCode = createRecoveryCode();
    const recoveryCodeDigest = createRecoveryCodeDigest(recoveryCode);
    const createdUser = await store.createAuthUser({
      id: randomUUID(),
      email: parsedCredentials.value.email,
      passwordHash: passwordDigest.hash,
      passwordSalt: passwordDigest.salt,
      recoveryCodeHash: recoveryCodeDigest.hash,
      recoveryCodeSalt: recoveryCodeDigest.salt,
      recoveryFailedAttempts: 0,
      role: isLegacyAdminProfileEmail(parsedCredentials.value.email)
        ? "admin"
        : "user",
      createdAt: now,
      updatedAt: now
    });

    const token = createSessionToken();
    await store.saveAuthSession({
      tokenHash: hashSessionToken(token),
      userId: createdUser.id,
      createdAt: now,
      updatedAt: now
    });

    const response: AuthResponse = {
      token,
      user: serializeAuthUser(createdUser),
      recoveryCode
    };

    return reply.code(201).send(response);
  });

  app.post("/auth/login", async (request, reply) => {
    const parsedCredentials = parseAuthCredentials(request.body);
    if (!parsedCredentials.value) {
      return reply.code(400).send({
        error: parsedCredentials.error ?? "Invalid credentials"
      });
    }

    const user = await store.findAuthUserByEmail(parsedCredentials.value.email);
    if (!user || !verifyPasswordDigest(parsedCredentials.value.password, user)) {
      request.log.warn(
        {
          email: parsedCredentials.value.email
        },
        "Invalid login attempt"
      );
      return reply.code(401).send({ error: "invalid email or password" });
    }

    let nextRecoveryCode: string | undefined;
    let effectiveUser = user;
    if (!user.recoveryCodeHash || !user.recoveryCodeSalt) {
      nextRecoveryCode = createRecoveryCode();
      const recoveryCodeDigest = createRecoveryCodeDigest(nextRecoveryCode);
      const refreshedAt = new Date().toISOString();
      await store.updateStoredAuthUser({
        ...user,
        recoveryCodeHash: recoveryCodeDigest.hash,
        recoveryCodeSalt: recoveryCodeDigest.salt,
        updatedAt: refreshedAt
      });
      effectiveUser = {
        ...user,
        recoveryCodeHash: recoveryCodeDigest.hash,
        recoveryCodeSalt: recoveryCodeDigest.salt,
        updatedAt: refreshedAt
      };
    }

    const token = createSessionToken();
    const now = new Date().toISOString();
    await store.saveAuthSession({
      tokenHash: hashSessionToken(token),
      userId: effectiveUser.id,
      createdAt: now,
      updatedAt: now
    });

    const response: AuthResponse = {
      token,
      user: serializeAuthUser(effectiveUser),
      recoveryCode: nextRecoveryCode
    };

    return response;
  });

  app.post("/auth/recovery-questions", async (request, reply) => {
    const parsedPayload = parseRecoveryQuestionLookupPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid recovery lookup payload"
      });
    }

    const user = await store.findAuthUserByEmail(parsedPayload.value.email);
    if (!user) {
      return reply.code(404).send({ error: "account not found" });
    }

    const questions = readConfiguredRecoveryQuestions(user);
    if (!questions) {
      return reply.code(404).send({ error: "recovery questions not configured" });
    }

    const retryAfterMinutes = getRecoveryLockRemainingMinutes(user);
    return {
      available: true,
      locked: retryAfterMinutes > 0,
      retryAfterMinutes: retryAfterMinutes > 0 ? retryAfterMinutes : undefined,
      ...questions
    };
  });

  app.put("/me/recovery-questions", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const parsedPayload = parseRecoveryQuestionSetupPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid recovery question payload"
      });
    }

    const storedUser = await store.findAuthUserByEmail(user.email);
    if (!storedUser) {
      return reply.code(404).send({ error: "User not found" });
    }

    const answerOneDigest = createRecoveryAnswerDigest(
      parsedPayload.value.answerOne
    );
    const answerTwoDigest = createRecoveryAnswerDigest(
      parsedPayload.value.answerTwo
    );
    const now = new Date().toISOString();

    await store.updateStoredAuthUser({
      ...storedUser,
      recoveryQuestionOne: parsedPayload.value.questionOne,
      recoveryQuestionTwo: parsedPayload.value.questionTwo,
      recoveryAnswerOneHash: answerOneDigest.hash,
      recoveryAnswerOneSalt: answerOneDigest.salt,
      recoveryAnswerTwoHash: answerTwoDigest.hash,
      recoveryAnswerTwoSalt: answerTwoDigest.salt,
      recoveryFailedAttempts: 0,
      recoveryLockedUntil: undefined,
      updatedAt: now
    });

    return {
      success: true,
      questionOne: parsedPayload.value.questionOne,
      questionTwo: parsedPayload.value.questionTwo
    };
  });

  app.post("/auth/recover-password", async (request, reply) => {
    const parsedPayload = parsePasswordRecoveryPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid recovery payload"
      });
    }

    const user = await store.findAuthUserByEmail(parsedPayload.value.email);
    if (!user) {
      return reply.code(401).send({
        error: "invalid recovery credentials"
      });
    }

    if (parsedPayload.value.mode === "code") {
      if (!verifyRecoveryCodeDigest(parsedPayload.value.recoveryCode, user)) {
        return reply.code(401).send({
          error: "invalid recovery credentials"
        });
      }
    } else {
      if (!hasRecoveryQuestionsConfigured(user)) {
        return reply.code(400).send({
          error: "recovery questions not configured"
        });
      }

      if (isRecoveryTemporarilyLocked(user)) {
        const retryAfterMinutes = getRecoveryLockRemainingMinutes(user);
        return reply.code(429).send({
          error: "too many recovery attempts",
          retryAfterMinutes: retryAfterMinutes > 0
            ? retryAfterMinutes
            : RECOVERY_LOCK_WINDOW_MINUTES
        });
      }

      const isAnswerOneValid = verifyRecoveryAnswerDigest({
        answer: parsedPayload.value.answerOne,
        hash: user.recoveryAnswerOneHash,
        salt: user.recoveryAnswerOneSalt
      });
      const isAnswerTwoValid = verifyRecoveryAnswerDigest({
        answer: parsedPayload.value.answerTwo,
        hash: user.recoveryAnswerTwoHash,
        salt: user.recoveryAnswerTwoSalt
      });

      if (!isAnswerOneValid || !isAnswerTwoValid) {
        const now = new Date().toISOString();
        const failedAttempts = (user.recoveryFailedAttempts ?? 0) + 1;
        const shouldLock = failedAttempts >= RECOVERY_MAX_ATTEMPTS;

        await store.updateStoredAuthUser({
          ...user,
          recoveryFailedAttempts: shouldLock ? 0 : failedAttempts,
          recoveryLockedUntil: shouldLock
            ? buildRecoveryLockTimestamp(new Date(now))
            : undefined,
          updatedAt: now
        });

        if (shouldLock) {
          return reply.code(429).send({
            error: "too many recovery attempts",
            retryAfterMinutes: RECOVERY_LOCK_WINDOW_MINUTES
          });
        }

        return reply.code(401).send({
          error: "invalid recovery credentials"
        });
      }
    }

    const passwordDigest = createPasswordDigest(parsedPayload.value.newPassword);
    const nextRecoveryCode = createRecoveryCode();
    const nextRecoveryDigest = createRecoveryCodeDigest(nextRecoveryCode);
    const now = new Date().toISOString();

    await store.updateStoredAuthUser({
      ...user,
      passwordHash: passwordDigest.hash,
      passwordSalt: passwordDigest.salt,
      recoveryCodeHash: nextRecoveryDigest.hash,
      recoveryCodeSalt: nextRecoveryDigest.salt,
      recoveryFailedAttempts: 0,
      recoveryLockedUntil: undefined,
      updatedAt: now
    });

    return {
      success: true,
      recoveryCode: nextRecoveryCode
    };
  });

  app.get("/auth/me", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    return serializeAuthUser(user);
  });

  app.delete("/auth/session", async (request, reply) => {
    const { user, tokenHash } = await readAuthenticatedUser(request, store);
    if (!user || !tokenHash) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    await store.deleteAuthSession(tokenHash);
    return reply.code(204).send();
  });

  app.get("/me/backup", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      logCloudAuthRejection(request, "/me/backup");
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const bundle = await store.loadCloudBackup(user.id);
    return {
      hasBackup: bundle !== null,
      bundle
    };
  });

  app.get("/me/backup/meta", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      logCloudAuthRejection(request, "/me/backup/meta");
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const bundle = await store.loadCloudBackup(user.id);
    return {
      hasBackup: bundle !== null,
      updatedAt: bundle?.updatedAt ?? null
    };
  });

  app.put("/me/backup", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      logCloudAuthRejection(request, "/me/backup");
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const parsedBundle = parseCloudBackupPayload(
      request.body,
      `${user.id}-profile`
    );
    if (!parsedBundle.value) {
      return reply.code(400).send({
        error: parsedBundle.error ?? "Invalid backup payload"
      });
    }

    const savedBundle = await store.saveCloudBackup(user.id, parsedBundle.value);
    return {
      savedAt: savedBundle.updatedAt,
      bundle: savedBundle,
      droppedItems: parsedBundle.droppedItems ?? {
        workEntries: 0,
        leaveEntries: 0,
        scheduleOverrides: 0,
        workdaySessions: 0
      }
    };
  });

  app.post("/mobile-push/tokens", async (request, reply) => {
    const parsedPayload = parseMobilePushTokenPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid push token payload"
      });
    }

    const now = new Date().toISOString();
    const { user } = await readAuthenticatedUser(request, store);
    await store.saveMobilePushToken({
      token: parsedPayload.value.token,
      userId: user?.id,
      platform: parsedPayload.value.platform,
      appVersion: parsedPayload.value.appVersion,
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now
    });

    return reply.code(204).send();
  });

  app.post("/mobile-push/tokens/remove", async (request, reply) => {
    const parsedPayload = parseMobilePushTokenPayload(request.body);
    if (!parsedPayload.value) {
      return reply.code(400).send({
        error: parsedPayload.error ?? "Invalid push token payload"
      });
    }

    const removed = await store.deleteMobilePushTokens([
      parsedPayload.value.token
    ]);
    return {
      removed
    };
  });

  app.post("/internal/mobile-updates/notify", async (request, reply) => {
    const expectedToken = getMobilePushNotifyToken();
    if (!expectedToken) {
      return reply.code(503).send({
        error: "MOBILE_PUSH_NOTIFY_TOKEN is not configured"
      });
    }

    const headerToken = normalizeRuntimeEnvValue(
      typeof request.headers["x-release-token"] === "string"
        ? request.headers["x-release-token"]
        : undefined
    );
    if (!headerToken || headerToken !== expectedToken) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const metadata = await loadReleaseMetadata();
    if (!metadata) {
      return reply.code(404).send({ error: "No mobile release published" });
    }

    if (!isMobilePushConfigured()) {
      return reply.code(503).send({
        error: "FCM is not configured"
      });
    }

    const uniqueTokens = [
      ...new Set((await store.listMobilePushTokens()).map((item) => item.token))
    ];
    const pushResult = await broadcastMobilePush({
      tokens: uniqueTokens,
      payload: buildUpdatePushPayload(metadata)
    });

    const removedInvalidTokens = pushResult.invalidTokens.length > 0
      ? await store.deleteMobilePushTokens(pushResult.invalidTokens)
      : 0;

    if (pushResult.failedCount > 0) {
      request.log.warn(
        {
          targeted: uniqueTokens.length,
          failed: pushResult.failedCount,
          failureBreakdown: pushResult.failureBreakdown
        },
        "Mobile update push broadcast returned failed deliveries"
      );
    }

    return {
      targeted: uniqueTokens.length,
      delivered: pushResult.sentCount,
      failed: pushResult.failedCount,
      invalidRemoved: removedInvalidTokens,
      skipped: pushResult.skipped,
      reason: pushResult.reason ?? null,
      failureBreakdown: pushResult.failureBreakdown
    };
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
    const parsedProfile = parseProfilePayload(request.body, "default-profile");
    if (!parsedProfile.value) {
      return reply.code(400).send({
        error: parsedProfile.error ?? "Invalid profile payload"
      });
    }

    return await store.saveProfile(parsedProfile.value);
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

  registerEntryMutationRoutes(app, store);

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
      return reply
        .code(400)
        .send({ error: "type must be 'vacation', 'permit' or 'sickness'" });
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

    const breakMinutes = body.breakMinutes === undefined ? 0 : body.breakMinutes;
    if (!isNonNegativeInteger(breakMinutes)) {
      return reply.code(400).send({
        error: "breakMinutes must be a non-negative integer"
      });
    }

    if (
      (body.startTime !== undefined && !isTimeString(body.startTime)) ||
      (body.endTime !== undefined && !isTimeString(body.endTime))
    ) {
      return reply.code(400).send({
        error: "startTime and endTime must be in HH:MM format"
      });
    }

    const scheduleOverride: ScheduleOverride = {
      id: randomUUID(),
      date: body.date,
      targetMinutes: body.targetMinutes,
      startTime: body.startTime,
      endTime: body.endTime,
      breakMinutes,
      note: typeof body.note === "string" ? body.note : undefined
    };
    if (!isScheduleTimingConsistent(scheduleOverride)) {
      return reply.code(400).send({
        error:
          "targetMinutes must match startTime/endTime minus breakMinutes"
      });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.saveScheduleOverride(scheduleOverride);

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
