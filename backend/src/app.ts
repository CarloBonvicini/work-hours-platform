import { randomUUID } from "node:crypto";
import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import cors from "@fastify/cors";
import Fastify from "fastify";
import type { FastifyRequest } from "fastify";
import { InMemoryStore } from "./data/in-memory-store.js";
import type {
  AppStore,
  AppearanceSettingsRecord,
  AuthUser,
  CloudBackupRecord,
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
  LeaveType,
  Profile,
  ScheduleOverride,
  WeekdaySchedule,
  WeekdayTargetMinutes,
  WorkAllowancePeriod,
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
const SUPPORT_TICKET_MAX_ATTACHMENTS = 3;
const SUPPORT_TICKET_MAX_ATTACHMENT_BYTES = 4 * 1024 * 1024;
const SUPPORT_TICKET_ATTACHMENT_EXTENSIONS = {
  "image/png": ".png",
  "image/jpeg": ".jpg",
  "image/webp": ".webp"
} as const;
type SupportTicketAttachmentContentType =
  keyof typeof SUPPORT_TICKET_ATTACHMENT_EXTENSIONS;

interface SupportTicketInput {
  category: SupportTicketCategory;
  name?: string;
  email?: string;
  subject: string;
  message: string;
  appVersion?: string;
  userAgent?: string;
}

interface SupportTicket extends SupportTicketInput {
  id: string;
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

  return `${normalizedBaseName || "screenshot"}${extension}`;
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
      error: `attachments can contain at most ${SUPPORT_TICKET_MAX_ATTACHMENTS} images`
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
        error: "attachment contentType must be one of: image/png, image/jpeg, image/webp"
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

      return [
        {
          id: rule.id.trim(),
          name: rule.name.trim(),
          enabled: rule.enabled !== false,
          period:
            typeof rule.period === "string" &&
              permissionPeriods.has(rule.period as WorkAllowancePeriod)
              ? (rule.period as WorkAllowancePeriod)
              : "monthly",
          allowanceMinutes: parseOptionalMinutes(rule.allowanceMinutes),
          usedMinutes: parseOptionalMinutes(rule.usedMinutes),
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

  const droppedItems = {
    workEntries: body.workEntries.length - parsedWorkEntries.length,
    leaveEntries: body.leaveEntries.length - parsedLeaveEntries.length,
    scheduleOverrides:
      body.scheduleOverrides.length - parsedScheduleOverrides.length
  };

  return {
    value: {
      profile: parsedProfile.value,
      appearanceSettings,
      workEntries: parsedWorkEntries,
      leaveEntries: parsedLeaveEntries,
      scheduleOverrides: parsedScheduleOverrides,
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
      appVersion: normalizeOptionalText(body.appVersion, 40),
      userAgent
    },
    attachments: parsedAttachments.value
  };
}

async function saveSupportTicket(
  input: SupportTicketInput,
  attachments: SupportTicketAttachmentUpload[] = []
): Promise<SupportTicket> {
  const now = new Date().toISOString();
  const ticketId = randomUUID();
  const ticket: SupportTicket = {
    id: ticketId,
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

  if (!/^[a-zA-Z0-9-]+\.(png|jpg|webp)$/.test(storedFileName)) {
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
  return {
    ...ticket,
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
    name: normalizeOptionalText(rawValue.name, 120),
    email: normalizeOptionalText(rawValue.email, 160),
    subject: rawValue.subject.trim(),
    message: rawValue.message.trim(),
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

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatReleaseNotesForLanding(releaseNotes: string) {
  return releaseNotes
    .replace(/ \(\d+\)(?=[.!?,]|$)/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function renderTicketPage(options: { baseUrl: string }) {
  const { baseUrl } = options;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Ticket - Work Hours Platform</title>
    <style>
      :root {
        --page: #f4efe6;
        --card: rgba(255, 255, 255, 0.9);
        --ink: #112321;
        --muted: #4a5d58;
        --line: #d8cec0;
        --brand: #0b6e69;
        --brand-dark: #084c49;
        --accent: #e6b84c;
        --danger: #9d3d2f;
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
        width: min(980px, calc(100% - 32px));
        margin: 0 auto;
        padding: 32px 0 48px;
      }

      .hero,
      .panel {
        background: var(--card);
        border: 1px solid rgba(216, 206, 192, 0.92);
        border-radius: 28px;
        box-shadow: var(--shadow);
      }

      .hero {
        background: linear-gradient(150deg, rgba(17, 49, 49, 0.98), rgba(11, 110, 105, 0.94));
        color: white;
        padding: 28px;
      }

      h1 {
        margin: 0 0 10px;
        font-size: clamp(34px, 5vw, 56px);
        line-height: 0.96;
        letter-spacing: -0.04em;
      }

      .hero p {
        margin: 0;
        max-width: 720px;
        color: rgba(255, 255, 255, 0.84);
        font-size: 18px;
        line-height: 1.5;
      }

      .hero-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 18px;
      }

      .hero-link {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 48px;
        padding: 0 18px;
        border-radius: 16px;
        text-decoration: none;
        font-weight: 700;
        color: white;
        border: 1px solid rgba(255, 255, 255, 0.22);
        background: rgba(255, 255, 255, 0.12);
      }

      .panel {
        margin-top: 18px;
        padding: 24px;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(12, minmax(0, 1fr));
        gap: 16px;
      }

      .intro {
        grid-column: span 4;
      }

      .form-panel {
        grid-column: span 8;
      }

      h2 {
        margin: 0 0 8px;
        font-size: 26px;
        letter-spacing: -0.03em;
      }

      p,
      li,
      label,
      legend {
        color: var(--muted);
        line-height: 1.5;
      }

      .stack {
        display: grid;
        gap: 16px;
      }

      .field {
        display: grid;
        gap: 8px;
      }

      .field-row {
        display: grid;
        gap: 16px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      input,
      textarea,
      select {
        width: 100%;
        border-radius: 18px;
        border: 1px solid var(--line);
        padding: 14px 16px;
        font: inherit;
        color: var(--ink);
        background: white;
      }

      textarea {
        min-height: 180px;
        resize: vertical;
      }

      fieldset {
        margin: 0;
        padding: 0;
        border: 0;
      }

      .choices {
        display: grid;
        gap: 12px;
      }

      .choice {
        display: grid;
        grid-template-columns: auto 1fr;
        gap: 12px;
        align-items: start;
        padding: 14px 16px;
        border: 1px solid var(--line);
        border-radius: 18px;
        background: rgba(255, 255, 255, 0.6);
      }

      .choice strong {
        display: block;
        color: var(--ink);
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
      }

      button {
        border: 0;
        border-radius: 18px;
        min-height: 54px;
        padding: 0 22px;
        font: inherit;
        font-weight: 700;
        cursor: pointer;
        background: var(--accent);
        color: #17302d;
      }

      button:disabled {
        cursor: wait;
        opacity: 0.6;
      }

      .muted-link {
        color: var(--brand-dark);
        text-decoration: none;
        font-weight: 700;
      }

      .status {
        display: none;
        padding: 14px 16px;
        border-radius: 18px;
        font-weight: 600;
      }

      .status.success {
        display: block;
        background: rgba(11, 110, 105, 0.12);
        color: var(--brand-dark);
      }

      .status.error {
        display: block;
        background: rgba(157, 61, 47, 0.12);
        color: var(--danger);
      }

      ul {
        margin: 12px 0 0;
        padding-left: 18px;
      }

      @media (max-width: 860px) {
        main { width: min(100% - 24px, 980px); padding-top: 20px; }
        .intro, .form-panel { grid-column: 1 / -1; }
        .field-row { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>Invia un ticket</h1>
        <p>Usa questa pagina per segnalare bug, chiedere nuove funzioni o inviare una richiesta di supporto sul progetto.</p>
        <div class="hero-actions">
          <a class="hero-link" href="${escapeHtml(baseUrl)}/">Torna al download app</a>
          <a class="hero-link" href="${escapeHtml(baseUrl)}/admin">Area admin</a>
        </div>
      </section>

      <section class="grid">
        <article class="panel intro">
          <h2>Quando usarlo</h2>
          <p>Ti conviene aprire un ticket quando vuoi far arrivare un problema o una richiesta in modo ordinato e rintracciabile.</p>
          <ul>
            <li>Bug o comportamento anomalo dell app</li>
            <li>Nuove funzioni o miglioramenti desiderati</li>
            <li>Dubbi pratici su uso, installazione o aggiornamenti</li>
          </ul>
        </article>

        <article class="panel form-panel">
          <h2>Raccontaci cosa ti serve</h2>
          <form id="ticket-form" class="stack">
            <fieldset class="field">
              <legend>Tipo di ticket</legend>
              <div class="choices">
                <label class="choice">
                  <input type="radio" name="category" value="bug" checked />
                  <span><strong>Bug</strong>Segnala un problema che hai trovato.</span>
                </label>
                <label class="choice">
                  <input type="radio" name="category" value="feature" />
                  <span><strong>Nuova funzione</strong>Proponi una funzione o un miglioramento.</span>
                </label>
                <label class="choice">
                  <input type="radio" name="category" value="support" />
                  <span><strong>Supporto</strong>Scrivi per dubbi, blocchi o chiarimenti.</span>
                </label>
              </div>
            </fieldset>

            <div class="field-row">
              <label class="field">
                <span>Nome</span>
                <input name="name" type="text" maxlength="120" placeholder="Come ti chiami" />
              </label>
              <label class="field">
                <span>Email</span>
                <input name="email" type="email" maxlength="160" placeholder="Se vuoi una risposta" />
              </label>
            </div>

            <div class="field-row">
              <label class="field">
                <span>Oggetto</span>
                <input name="subject" type="text" maxlength="160" required placeholder="Riassunto breve" />
              </label>
              <label class="field">
                <span>Versione app</span>
                <input name="appVersion" type="text" maxlength="40" placeholder="Facoltativa" />
              </label>
            </div>

            <label class="field">
              <span>Messaggio</span>
              <textarea name="message" required maxlength="4000" placeholder="Descrivi il problema o la richiesta nel modo piu chiaro possibile"></textarea>
            </label>

            <div id="ticket-status" class="status"></div>

            <div class="actions">
              <button id="ticket-submit" type="submit">Invia ticket</button>
              <a class="muted-link" href="${escapeHtml(baseUrl)}/">Annulla</a>
            </div>
          </form>
        </article>
      </section>
    </main>

    <script>
      const form = document.getElementById('ticket-form');
      const submitButton = document.getElementById('ticket-submit');
      const statusBox = document.getElementById('ticket-status');

      form.addEventListener('submit', async (event) => {
        event.preventDefault();
        statusBox.className = 'status';
        statusBox.textContent = '';
        submitButton.disabled = true;
        submitButton.textContent = 'Invio in corso...';

        const formData = new FormData(form);
        const payload = {
          category: formData.get('category'),
          name: formData.get('name'),
          email: formData.get('email'),
          subject: formData.get('subject'),
          message: formData.get('message'),
          appVersion: formData.get('appVersion')
        };

        try {
          const response = await fetch('${escapeHtml(baseUrl)}/tickets', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(payload)
          });
          const result = await response.json().catch(() => ({}));

          if (!response.ok) {
            throw new Error(result.error || 'Non siamo riusciti a inviare il ticket.');
          }

          form.reset();
          const bugChoice = form.querySelector('input[name="category"][value="bug"]');
          if (bugChoice) bugChoice.checked = true;
          statusBox.className = 'status success';
          statusBox.textContent = 'Ticket inviato. Grazie, lo prendiamo in carico.';
        } catch (error) {
          statusBox.className = 'status error';
          statusBox.textContent = error instanceof Error
            ? error.message
            : 'Non siamo riusciti a inviare il ticket.';
        } finally {
          submitButton.disabled = false;
          submitButton.textContent = 'Invia ticket';
        }
      });
    </script>
  </body>
</html>`;
}

function renderAdminPage(options: {
  baseUrl: string;
  superAdminConfigured: boolean;
}) {
  const { baseUrl, superAdminConfigured } = options;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Admin Dashboard - Work Hours Platform</title>
    <style>
      :root {
        --bg: #1e1e1e;
        --bg-card: rgba(37, 37, 38, 0.96);
        --bg-soft: rgba(22, 26, 35, 0.74);
        --bg-input: #1f1f1f;
        --line: #3f3f46;
        --line-strong: #4c4c52;
        --ink: #d4d4d4;
        --muted: #9da3a9;
        --accent: #0e639c;
        --accent-hover: #1177bb;
        --success: #73c991;
        --success-soft: rgba(115, 201, 145, 0.14);
        --warning: #f2cc60;
        --warning-soft: rgba(242, 204, 96, 0.14);
        --danger: #f48771;
        --danger-soft: rgba(244, 135, 113, 0.14);
        --info: #75beff;
        --shadow: 0 18px 40px rgba(0, 0, 0, 0.28);
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        overflow-x: hidden;
        color: var(--ink);
        font-family: "Segoe UI", "IBM Plex Sans", sans-serif;
        background-color: var(--bg);
        background:
          linear-gradient(180deg, rgba(14, 99, 156, 0.12), transparent 220px),
          radial-gradient(circle at top right, rgba(14, 99, 156, 0.14), transparent 32%),
          linear-gradient(180deg, #181818 0%, var(--bg) 100%);
        background-repeat: no-repeat;
        background-size: 100% 220px, 100% 100%, 100% 100%;
        background-attachment: fixed;
      }
      .shell { max-width: 1440px; margin: 0 auto; padding: 32px 20px 64px; }
      .hero { text-align: center; margin-bottom: 26px; }
      .hero-actions { display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 12px; }
      .brand-lockup { position: relative; width: min(100%, 220px); height: 88px; margin: 0 auto 10px; }
      .brand-mark { position: absolute; inset: 0; margin: auto; width: 108px; height: 72px; border-radius: 22px; border: 1px solid rgba(117,190,255,0.24); background: linear-gradient(135deg, rgba(117,190,255,0.16), rgba(14,99,156,0.72)); box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 14px 30px rgba(0,0,0,0.28); }
      .brand-mark::before, .brand-mark::after { content: ""; position: absolute; inset: 0; margin: auto; }
      .brand-mark::before { width: 30px; height: 30px; border-radius: 10px; border: 2px solid rgba(255,255,255,0.74); transform: translateX(-18px) rotate(10deg); }
      .brand-mark::after { width: 10px; height: 34px; border-radius: 999px; background: rgba(255,255,255,0.84); transform: translateX(18px); }
      .brand-mark-main::before { box-shadow: 22px 0 0 rgba(255,255,255,0.22); }
      .brand-mark-glow { opacity: 0.68; filter: blur(18px) saturate(1.16); transform: scale(1.08); }
      .ghost-link, button, input, textarea, select, code {
        font: inherit;
      }
      .ghost-link {
        display: inline-flex; align-items: center; justify-content: center; padding: 8px 12px; border-radius: 8px;
        border: 1px solid var(--line); background: rgba(22, 26, 35, 0.56); color: #c4e0f7; text-decoration: none; font-size: 12px; font-weight: 600; letter-spacing: 0.02em;
        transition: border-color 140ms ease, color 140ms ease, background 140ms ease;
      }
      .ghost-link:hover { border-color: rgba(117,190,255,0.72); background: rgba(14,99,156,0.18); color: #e9f6ff; }
      .toolbar-quick-link { font-size: 13px; font-weight: 700; }
      .eyebrow { margin: 0 0 10px; color: var(--info); text-transform: uppercase; letter-spacing: 0.18em; font-size: 12px; }
      h1,h2,h3,h4 { margin: 0 0 12px; color: #fff; font-family: "Segoe UI Semibold", "Segoe UI", sans-serif; }
      h1 { font-size: clamp(2.2rem, 4vw, 3rem); }
      p { margin: 0; }
      .lede, .muted { color: var(--muted); line-height: 1.45; overflow-wrap: anywhere; }
      .panel, .card, .stat { background: var(--bg-card); border: 1px solid var(--line); border-radius: 14px; box-shadow: var(--shadow); min-width: 0; max-width: 100%; }
      .panel { padding: 20px; margin-bottom: 18px; }
      .auth-stage { display: grid; justify-items: center; padding: 0; border: 0; background: transparent; box-shadow: none; }
      .auth-shell { width: min(100%, 920px); padding: 20px; border-color: rgba(117,190,255,0.24); background: rgba(22,26,35,0.62); backdrop-filter: blur(16px); box-shadow: 0 22px 50px rgba(0,0,0,0.4), 0 0 0 1px rgba(117,190,255,0.14), 0 0 34px rgba(14,99,156,0.22); }
      .auth-view { display: grid; gap: 14px; }
      .auth-cta { color: var(--muted); font-size: 14px; }
      .auth-grid { display: grid; gap: 14px; grid-template-columns: minmax(0, 460px); justify-content: center; }
      .auth-card { align-content: start; }
      .auth-card h3 { margin-bottom: 6px; }
      .auth-switch { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; color: var(--muted); font-size: 13px; }
      .link-button {
        min-height: 0;
        padding: 0;
        border: 0;
        background: transparent;
        color: var(--info);
        font-weight: 700;
      }
      .link-button:hover { background: transparent; color: #bfe2ff; }
      .pill { display: inline-flex; align-items: center; gap: 6px; width: fit-content; border-radius: 999px; padding: 5px 10px; font-size: 12px; font-weight: 700; }
      .pill.info { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .pill.warning { background: var(--warning-soft); color: var(--warning); }
      .pill.success { background: var(--success-soft); color: var(--success); }
      .hidden { display: none !important; }
      .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
      .console-toolbar { margin-bottom: 6px; align-items: flex-start; }
      .toolbar-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
      button {
        border: 1px solid var(--line); border-radius: 8px; background: var(--bg-input);
        color: var(--ink); min-height: 42px; padding: 0 14px; cursor: pointer;
        transition: border-color 140ms ease, box-shadow 140ms ease, background 140ms ease, transform 140ms ease;
      }
      button.primary { background: linear-gradient(180deg, var(--accent-hover), var(--accent)); border-color: rgba(117,190,255,0.42); color: white; }
      button:hover { border-color: var(--line-strong); background: rgba(255,255,255,0.06); }
      input, textarea, select {
        width: 100%; border-radius: 8px; border: 1px solid var(--line); background: var(--bg-input); color: var(--ink); padding: 12px 13px;
      }
      textarea { min-height: 140px; resize: vertical; }
      form { display: grid; gap: 12px; }
      label { display: grid; gap: 7px; color: var(--muted); font-size: 13px; }
      code { display: inline-block; padding: 2px 6px; border-radius: 6px; background: rgba(255,255,255,0.06); color: #f0f3f6; }
      .status { border-radius: 10px; padding: 12px 14px; border: 1px solid transparent; font-weight: 600; }
      .status.info { background: rgba(117, 190, 255, 0.1); color: var(--info); }
      .status.error { background: var(--danger-soft); color: var(--danger); }
      .status.success { background: var(--success-soft); color: var(--success); }
      .console-section { display: grid; gap: 14px; margin-top: 18px; }
      .section-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
      .section-heading-copy { display: grid; gap: 4px; }
      .section-heading h3 { margin-bottom: 4px; }
      .section-heading p { margin: 0; color: var(--muted); font-size: 13px; }
      .stats { display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); }
      .stat { padding: 16px; background: linear-gradient(180deg, rgba(37,37,38,0.96), rgba(28,28,31,0.96)); }
      .stat.tone-info { border-color: rgba(117,190,255,0.2); }
      .stat.tone-warning { border-color: rgba(242,204,96,0.2); }
      .stat.tone-success { border-color: rgba(115,201,145,0.2); }
      .stat-label { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
      .stat-value { margin-top: 10px; font-size: 30px; font-weight: 700; color: #fff; }
      .stat-note { margin-top: 8px; color: var(--muted); font-size: 13px; line-height: 1.45; }
      .admin-console-layout { display: grid; gap: 16px; grid-template-columns: minmax(240px, 280px) minmax(0, 1fr); align-items: start; }
      .workspace-nav { display: grid; gap: 12px; padding: 14px; }
      .workspace-nav h4 { margin: 0; color: var(--muted); font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; }
      .workspace-stack { display: grid; gap: 12px; }
      .workspace-card { display: grid; gap: 10px; border: 1px solid var(--line); border-radius: 10px; background: rgba(22,22,24,0.75); padding: 12px; }
      .mini-label { color: #89929d; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; }
      .workspace-value { color: #fff; font-size: 16px; font-weight: 700; }
      .metric-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; color: #d8dde4; }
      .metric-row + .metric-row { padding-top: 8px; border-top: 1px solid rgba(255,255,255,0.06); }
      .metric-row strong { color: #fff; }
      .quick-link-grid { display: grid; gap: 8px; }
      .admin-content-grid { display: grid; gap: 16px; }
      .ticket-workspace { display: grid; gap: 16px; grid-template-columns: minmax(300px, 360px) minmax(0, 1fr); align-items: start; }
      .ticket-list { display: grid; gap: 10px; max-height: 72vh; overflow: auto; padding-right: 4px; }
      .ticket-card { border-radius: 12px; border: 1px solid var(--line); background: var(--bg-soft); padding: 14px; cursor: pointer; transition: border-color 140ms ease, background 140ms ease, transform 140ms ease; }
      .ticket-card:hover { border-color: rgba(117,190,255,0.34); background: rgba(26,30,38,0.9); transform: translateY(-1px); }
      .ticket-card.is-active { border-color: rgba(117,190,255,0.72); box-shadow: inset 0 0 0 1px rgba(117,190,255,0.24), 0 14px 28px rgba(0,0,0,0.2); }
      .ticket-card-head, .ticket-badges, .ticket-card-summary, .reply-meta, .reply-actions { display: flex; gap: 8px; flex-wrap: wrap; }
      .ticket-card-head { align-items: flex-start; justify-content: space-between; }
      .ticket-card-head { justify-content: space-between; }
      .ticket-card-summary { margin-top: 10px; color: var(--muted); font-size: 12px; }
      .badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 4px 10px; font-size: 12px; font-weight: 700; }
      .badge.status-new { background: var(--warning-soft); color: var(--warning); }
      .badge.status-in_progress { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .badge.status-answered { background: var(--success-soft); color: var(--success); }
      .badge.status-closed { background: rgba(255,255,255,0.08); color: var(--muted); }
      .badge.category-bug { background: var(--danger-soft); color: var(--danger); }
      .badge.category-feature { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .badge.category-support { background: rgba(255,255,255,0.08); color: #d9e2ec; }
      .ticket-title { margin: 6px 0 4px; font-size: 16px; font-weight: 700; }
      .ticket-meta, .field-label { color: var(--muted); font-size: 12px; }
      .field-label { text-transform: uppercase; letter-spacing: 0.08em; }
      .detail-shell { display: grid; gap: 18px; }
      .detail-title { margin: 6px 0; }
      .thread { display: grid; gap: 12px; }
      .message-card { border-radius: 12px; border: 1px solid var(--line); padding: 14px; background: rgba(255,255,255,0.02); }
      .message-card.reply { background: rgba(117, 190, 255, 0.06); border-color: rgba(117, 190, 255, 0.22); }
      .attachment-gallery { display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); margin-top: 12px; }
      .attachment-card { display: grid; gap: 10px; border-radius: 12px; border: 1px solid var(--line); background: rgba(255,255,255,0.03); padding: 12px; text-decoration: none; color: inherit; }
      .attachment-preview { display: block; width: 100%; aspect-ratio: 4 / 3; object-fit: cover; border-radius: 10px; border: 1px solid rgba(255,255,255,0.08); background: rgba(0,0,0,0.16); }
      .attachment-name { font-size: 13px; font-weight: 700; color: #fff; word-break: break-word; }
      .attachment-meta { color: var(--muted); font-size: 12px; }
      .detail-grid { display: grid; gap: 12px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .field { display: grid; gap: 6px; }
      .reply-form { display: grid; gap: 12px; }
      .reply-actions { justify-content: flex-end; }
      .empty-state { border-radius: 12px; border: 1px dashed var(--line); padding: 18px; color: var(--muted); text-align: center; }
      .user-list { display: grid; gap: 10px; }
      .user-row { display: grid; gap: 10px; grid-template-columns: minmax(0, 1fr) auto; align-items: center; border: 1px solid var(--line); border-radius: 12px; background: var(--bg-soft); padding: 14px; }
      .user-row-main { display: grid; gap: 6px; min-width: 0; }
      .user-row-email { color: #fff; font-weight: 700; overflow-wrap: anywhere; }
      .user-row-meta { display: flex; gap: 8px; flex-wrap: wrap; color: var(--muted); font-size: 12px; }
      .user-actions { display: flex; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
      @media (max-width: 1120px) { .ticket-workspace { grid-template-columns: 1fr; } }
      @media (max-width: 980px) { .admin-console-layout { grid-template-columns: 1fr; } }
      @media (max-width: 720px) { .shell { padding: 20px 14px 40px; } .hero-actions, .toolbar, .section-heading, .user-row { flex-direction: column; align-items: stretch; } .toolbar-actions, .user-actions { justify-content: flex-start; } .stats, .detail-grid, .auth-grid { grid-template-columns: 1fr; } .user-row { display: grid; grid-template-columns: 1fr; } }
    </style>
  </head>
  <body
    data-base-url="${escapeHtml(baseUrl)}"
    data-super-admin-configured="${superAdminConfigured ? "true" : "false"}"
  >
    <main class="shell">
      <section class="hero">
        <div class="hero-actions">
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/">Home</a>
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/tickets">Ticket pubblici</a>
        </div>
        <div class="brand-lockup" aria-hidden="true">
          <div class="brand-mark brand-mark-glow"></div>
          <div class="brand-mark brand-mark-main"></div>
        </div>
        <p class="eyebrow">Work Hours Platform</p>
        <h1>Admin Console</h1>
      </section>

      <section class="panel auth-stage" id="admin-auth-panel">
        <div class="card auth-shell">
          <section class="auth-view">
            <h2>Accesso admin</h2>
            <p class="lede">Accedi con un profilo gia autorizzato. Se devi prima creare un account, apri la registrazione dal link qui sotto.</p>
            <div id="admin-auth-status" class="status info">Accedi con un profilo admin per aprire la dashboard.</div>
            <div class="auth-grid">
              <article class="workspace-card auth-card" id="admin-login-card">
                <span class="pill info">Login</span>
                <div>
                  <h3>Entra in dashboard</h3>
                  <p class="lede">Accedi con email e password del super admin o di un admin gia promosso.</p>
                </div>
                <form id="admin-login-form">
                  <label>Email
                    <input id="admin-email-input" type="email" autocomplete="username" placeholder="admin@example.com" required />
                  </label>
                  <label>Password
                    <input id="admin-password-input" type="password" autocomplete="current-password" placeholder="Password" required />
                  </label>
                  <div class="toolbar-actions" style="justify-content:flex-start;">
                    <button class="primary" id="admin-login-btn" type="submit">Login</button>
                  </div>
                </form>
                <div class="auth-switch">
                  <span>Non hai ancora un profilo?</span>
                  <button class="link-button" id="admin-show-register-btn" type="button">Registrati</button>
                </div>
              </article>

              <article class="workspace-card auth-card hidden" id="admin-register-card">
                <span class="pill success">Registrazione</span>
                <div>
                  <h3>Registra profilo</h3>
                  <p class="lede">La registrazione crea un account normale. Solo il super admin puo promuoverti ad admin.</p>
                </div>
                <form id="admin-register-form">
                  <label>Email
                    <input id="admin-register-email-input" type="email" autocomplete="username" placeholder="utente@example.com" required />
                  </label>
                  <label>Password
                    <input id="admin-register-password-input" type="password" autocomplete="new-password" placeholder="Scegli la password" required />
                  </label>
                  <div class="toolbar-actions" style="justify-content:flex-start;">
                    <button type="submit">Registrati</button>
                  </div>
                </form>
                <div class="auth-switch">
                  <span>Hai gia un profilo?</span>
                  <button class="link-button" id="admin-show-login-btn" type="button">Torna al login</button>
                </div>
              </article>
            </div>
            <p class="auth-cta" id="admin-auth-cta">La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.</p>
          </section>
        </div>
      </section>

      <section class="panel hidden" id="admin-dashboard-panel">
        <div class="toolbar console-toolbar">
          <div>
            <p class="eyebrow" style="margin-bottom:8px;">Sessione Admin</p>
            <h2 style="margin-bottom:6px;">Admin Dashboard</h2>
            <p class="lede" id="admin-session-copy">Monitoraggio release, data provider e thread ticket.</p>
          </div>
          <div class="toolbar-actions">
            <a class="ghost-link toolbar-quick-link" href="${escapeHtml(baseUrl)}/">Home</a>
            <a class="ghost-link toolbar-quick-link" href="${escapeHtml(baseUrl)}/tickets">Ticket pubblici</a>
            <button type="button" id="admin-refresh-btn">Refresh all</button>
            <button type="button" id="admin-logout-btn">Logout</button>
          </div>
        </div>
        <div id="admin-status" class="status info">Caricamento dashboard...</div>

        <section class="console-section" id="overview-section">
          <div class="section-heading">
            <div class="section-heading-copy">
              <h3>Overview</h3>
              <p>Segnali rapidi per release, provider e coda ticket. La parte alta resta panoramica, il workspace operativo vive sotto come nell altra admin.</p>
            </div>
          </div>
          <div class="stats" id="admin-stats"></div>
        </section>

        <section class="console-section" id="tickets-section">
          <div class="section-heading">
            <div class="section-heading-copy">
              <h3>Support Inbox</h3>
              <p>Prima scorri l inbox, poi apri il dettaglio solo sul ticket che vuoi gestire.</p>
            </div>
          </div>
          <div class="admin-console-layout">
            <aside class="card workspace-nav" aria-label="Admin workspace">
              <h4>Workspace</h4>
              <div class="workspace-stack">
                <article class="workspace-card">
                  <div class="mini-label">Profilo</div>
                  <div class="workspace-value" id="admin-session-email">Sessione non caricata</div>
                  <p class="lede" id="admin-generated-at">Ultimo aggiornamento: -</p>
                </article>
                <article class="workspace-card">
                  <div class="mini-label">Ambiente</div>
                  <div class="workspace-value" id="admin-service-label">work-hours-backend</div>
                  <p class="lede" id="admin-provider-note">Provider dati: -</p>
                </article>
                <article class="workspace-card">
                  <div class="mini-label">Link rapidi</div>
                  <div class="quick-link-grid">
                    <a class="ghost-link" id="admin-health-link" href="${escapeHtml(baseUrl)}/health" target="_blank" rel="noreferrer">Health</a>
                    <a class="ghost-link" id="admin-feed-link" href="${escapeHtml(baseUrl)}/mobile-updates/latest.json" target="_blank" rel="noreferrer">Feed release</a>
                    <a class="ghost-link" id="admin-public-tickets-link" href="${escapeHtml(baseUrl)}/tickets" target="_blank" rel="noreferrer">Ticket pubblici</a>
                  </div>
                </article>
                <article class="workspace-card">
                  <div class="mini-label">Queue ticket</div>
                  <div class="metric-row"><span>Nuovi</span><strong id="admin-ticket-waiting">0</strong></div>
                  <div class="metric-row"><span>In lavorazione</span><strong id="admin-ticket-progress">0</strong></div>
                  <div class="metric-row"><span>Risposti</span><strong id="admin-ticket-answered">0</strong></div>
                  <div class="metric-row"><span>Chiusi</span><strong id="admin-ticket-closed">0</strong></div>
                </article>
              </div>
            </aside>

            <div class="admin-content-grid">
              <div class="ticket-workspace">
                <section class="card" style="padding:16px;">
                  <div class="toolbar">
                    <div>
                      <h3 style="margin-bottom:6px;">Ticket</h3>
                      <p class="lede">Seleziona un ticket per aprire messaggi, screenshot e risposta admin.</p>
                    </div>
                    <button type="button" id="admin-refresh-tickets-btn">Aggiorna</button>
                  </div>
                  <div class="ticket-list" id="admin-ticket-list" style="margin-top:14px;"></div>
                </section>
                <section class="card" style="padding:18px;" id="admin-ticket-detail"></section>
              </div>
              <section class="card" style="padding:16px;" id="admin-user-management-section">
                <div class="toolbar">
                  <div>
                    <h3 style="margin-bottom:6px;">Accessi e ruoli</h3>
                    <p class="lede">Solo il super admin puo promuovere, revocare accessi admin e resettare password.</p>
                  </div>
                  <button type="button" id="admin-refresh-users-btn">Aggiorna utenti</button>
                </div>
                <div style="margin-top:14px; display:grid; gap:10px;">
                  <label class="field">
                    <span class="field-label">Ricerca utenti</span>
                    <input id="admin-user-search-input" type="search" placeholder="Cerca per email" />
                  </label>
                  <form id="admin-create-user-form" class="reply-form">
                    <div class="field-label">Crea utente</div>
                    <div class="detail-grid">
                      <label class="field">
                        <span class="field-label">Email</span>
                        <input id="admin-create-user-email-input" type="email" placeholder="utente@example.com" required />
                      </label>
                      <label class="field">
                        <span class="field-label">Password</span>
                        <input id="admin-create-user-password-input" type="password" placeholder="Scegli la password" required />
                      </label>
                      <label class="field">
                        <span class="field-label">Ruolo</span>
                        <select id="admin-create-user-role-input">
                          <option value="user">Utente</option>
                          <option value="admin">Admin</option>
                        </select>
                      </label>
                    </div>
                    <div class="reply-actions">
                      <button type="submit" class="primary">Crea utente</button>
                    </div>
                  </form>
                </div>
                <div class="user-list" id="admin-user-list" style="margin-top:14px;"></div>
              </section>
            </div>
          </div>
        </section>
      </section>
    </main>
    <script>
      const ADMIN_TOKEN_KEY = "work_hours_admin_session_token";
      const bodyDataset = document.body.dataset || {};
      const baseUrl = bodyDataset.baseUrl || "";
      const normalizedBaseUrl = String(baseUrl || "").replace(/\\/+$/, "");
      const sameOriginOrigin = (
        typeof window !== "undefined" &&
        window.location &&
        window.location.origin
      )
        ? String(window.location.origin).replace(/\\/+$/, "")
        : "";
      const inferredBasePath = (
        typeof window !== "undefined" &&
        window.location &&
        typeof window.location.pathname === "string"
      )
        ? (() => {
            const pathname = window.location.pathname;
            const adminMarker = "/admin";
            const markerIndex = pathname.lastIndexOf(adminMarker);
            if (markerIndex <= 0) {
              return "";
            }
            return pathname.slice(0, markerIndex);
          })()
        : "";
      const sameOriginBaseUrl = (sameOriginOrigin + inferredBasePath).replace(/\\/+$/, "");
      const apiBaseCandidates = Array.from(
        new Set(
          [sameOriginBaseUrl, normalizedBaseUrl, sameOriginOrigin].filter(
            (value) => typeof value === "string" && value.length > 0
          )
        )
      );
      const authPanel = document.getElementById("admin-auth-panel");
      const dashboardPanel = document.getElementById("admin-dashboard-panel");
      const authStatusBox = document.getElementById("admin-auth-status");
      const authCta = document.getElementById("admin-auth-cta");
      const loginCard = document.getElementById("admin-login-card");
      const loginForm = document.getElementById("admin-login-form");
      const emailInput = document.getElementById("admin-email-input");
      const passwordInput = document.getElementById("admin-password-input");
      const registerCard = document.getElementById("admin-register-card");
      const registerForm = document.getElementById("admin-register-form");
      const registerEmailInput = document.getElementById("admin-register-email-input");
      const registerPasswordInput = document.getElementById("admin-register-password-input");
      const showRegisterButton = document.getElementById("admin-show-register-btn");
      const showLoginButton = document.getElementById("admin-show-login-btn");
      const statusBox = document.getElementById("admin-status");
      const statsContainer = document.getElementById("admin-stats");
      const ticketList = document.getElementById("admin-ticket-list");
      const ticketDetail = document.getElementById("admin-ticket-detail");
      const userList = document.getElementById("admin-user-list");
      const userManagementSection = document.getElementById("admin-user-management-section");
      const userSearchInput = document.getElementById("admin-user-search-input");
      const createUserForm = document.getElementById("admin-create-user-form");
      const createUserEmailInput = document.getElementById("admin-create-user-email-input");
      const createUserPasswordInput = document.getElementById("admin-create-user-password-input");
      const createUserRoleInput = document.getElementById("admin-create-user-role-input");
      const sessionCopy = document.getElementById("admin-session-copy");
      const sessionEmail = document.getElementById("admin-session-email");
      const generatedAtLabel = document.getElementById("admin-generated-at");
      const serviceLabel = document.getElementById("admin-service-label");
      const providerNote = document.getElementById("admin-provider-note");
      const healthLink = document.getElementById("admin-health-link");
      const feedLink = document.getElementById("admin-feed-link");
      const publicTicketsLink = document.getElementById("admin-public-tickets-link");
      const waitingCount = document.getElementById("admin-ticket-waiting");
      const inProgressCount = document.getElementById("admin-ticket-progress");
      const answeredCount = document.getElementById("admin-ticket-answered");
      const closedCount = document.getElementById("admin-ticket-closed");
      const state = {
        token: "",
        adminUser: null,
        overview: null,
        tickets: [],
        users: [],
        ticketDetailsById: {},
        selectedTicketId: null,
        userSearchQuery: "",
        authMode: "login",
        superAdminConfigured: bodyDataset.superAdminConfigured === "true"
      };

      function readToken() {
        try {
          return sessionStorage.getItem(ADMIN_TOKEN_KEY) || "";
        } catch (_) {
          return "";
        }
      }
      function writeToken(value) {
        try {
          value
            ? sessionStorage.setItem(ADMIN_TOKEN_KEY, value)
            : sessionStorage.removeItem(ADMIN_TOKEN_KEY);
        } catch (_) {}
      }
      function escapeHtml(value) {
        return String(value ?? "")
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#39;");
      }
      function formatDateTime(value) {
        if (!value) return "-";
        try {
          return new Date(value).toLocaleString("it-IT", {
            dateStyle: "medium",
            timeStyle: "short"
          });
        } catch (_) {
          return value;
        }
      }
      function formatBytes(value) {
        const size = Number(value || 0);
        if (!Number.isFinite(size) || size <= 0) return "0 KB";
        if (size >= 1024 * 1024) return (size / (1024 * 1024)).toFixed(1) + " MB";
        return Math.ceil(size / 1024) + " KB";
      }
      function defaultAuthMessage() {
        if (!state.superAdminConfigured) {
          return "Login disponibile, ma prima va configurato il super admin nel runtime del backend.";
        }
        return "Accedi con un profilo admin per aprire la dashboard.";
      }
      function updateAuthMode(nextMode = "login") {
        state.authMode = nextMode === "register" ? "register" : "login";
        loginCard?.classList.toggle("hidden", state.authMode !== "login");
        registerCard?.classList.toggle("hidden", state.authMode !== "register");
      }
      function updateAuthPanel() {
        if (authCta) {
          if (!state.superAdminConfigured) {
            authCta.innerHTML =
              'La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.';
          } else {
            authCta.innerHTML =
              'La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.';
          }
        }
      }
      function setStatus(message, tone = "info", scope = "both") {
        const targets = scope === "auth"
          ? [authStatusBox]
          : scope === "dashboard"
            ? [statusBox]
            : [authStatusBox, statusBox];
        targets.filter(Boolean).forEach((element) => {
          element.textContent = message;
          element.className = "status " + tone;
        });
      }
      function resolveApiUrl(path, apiRoot = apiBaseCandidates[0] || "") {
        const value = String(path ?? "");
        if (value.startsWith("http://") || value.startsWith("https://")) {
          return value;
        }

        const normalizedPath = value.startsWith("/") ? value : "/" + value;
        return String(apiRoot || "").replace(/\\/+$/, "") + normalizedPath;
      }
      async function api(path, options = {}) {
        const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
        if (state.token) headers.Authorization = "Bearer " + state.token;

        let lastError = null;
        for (let index = 0; index < apiBaseCandidates.length; index += 1) {
          const requestUrl = resolveApiUrl(path, apiBaseCandidates[index]);
          try {
            const response = await fetch(requestUrl, {
              cache: "no-store",
              ...options,
              headers
            });
            const contentType = String(response.headers.get("content-type") || "");
            const payload = contentType.includes("application/json")
              ? await response.json().catch(() => null)
              : null;

            if (!response.ok) {
              const errorMessage =
                payload &&
                typeof payload === "object" &&
                typeof payload.error === "string"
                  ? payload.error
                  : "Request failed";

              const canRetry =
                index < apiBaseCandidates.length - 1 &&
                (response.status === 404 ||
                  response.status === 405 ||
                  response.status === 502 ||
                  response.status === 503);
              if (canRetry) {
                continue;
              }
              throw new Error(errorMessage);
            }

            if (!payload || typeof payload !== "object") {
              if (index < apiBaseCandidates.length - 1) {
                continue;
              }
              throw new Error("Risposta API non valida.");
            }

            return payload;
          } catch (error) {
            lastError = error;
            if (index < apiBaseCandidates.length - 1) {
              continue;
            }
            throw error;
          }
        }

        throw lastError || new Error("Request failed");
      }
      function statusBadge(status) {
        const labels = { new: "Nuovo", in_progress: "In lavorazione", answered: "Risposto", closed: "Chiuso" };
        return '<span class="badge status-' + escapeHtml(status) + '">' + (labels[status] || status) + '</span>';
      }
      function categoryBadge(category) {
        const labels = { bug: "Bug", feature: "Feature", support: "Supporto" };
        return '<span class="badge category-' + escapeHtml(category) + '">' + (labels[category] || category) + '</span>';
      }
      function resolveTicketAssetUrl(path) {
        if (typeof path !== "string" || path.length === 0) {
          return "#";
        }
        if (path.startsWith("http://") || path.startsWith("https://")) {
          return path;
        }
        return resolveApiUrl(path);
      }
      function renderWorkspaceSummary() {
        const overview = state.overview;
        const user = state.adminUser;
        if (sessionEmail) sessionEmail.textContent = user && user.email ? user.email : "Sessione non caricata";
        if (generatedAtLabel) generatedAtLabel.textContent = "Ultimo aggiornamento: " + (overview ? formatDateTime(overview.generatedAt) : "-");
        if (serviceLabel) serviceLabel.textContent = overview ? String(overview.service || "work-hours-backend") : "work-hours-backend";
        if (providerNote) providerNote.textContent = "Provider dati: " + (overview ? String(overview.dataProvider || "-") : "-");
        if (sessionCopy) {
          const currentVersion = overview && overview.release && overview.release.current
            ? String(overview.release.current.version || overview.release.current.tag || "n/d")
            : "nessuna release";
          const roleLabel = user && user.isSuperAdmin
            ? "super admin"
            : user && user.isAdmin
              ? "admin"
              : "utente";
          sessionCopy.textContent = user && user.email
            ? "Sessione " + roleLabel + " attiva per " + user.email + ". Release live: " + currentVersion + "."
            : "Monitoraggio release, data provider e thread ticket.";
        }
        if (healthLink && overview && overview.links) healthLink.href = String(overview.links.health || healthLink.href);
        if (feedLink && overview && overview.links) feedLink.href = String(overview.links.releaseFeed || feedLink.href);
        if (publicTicketsLink && overview && overview.links) publicTicketsLink.href = String(overview.links.publicTickets || publicTicketsLink.href);
        if (waitingCount) waitingCount.textContent = overview ? String(overview.tickets.waiting || 0) : "0";
        if (inProgressCount) inProgressCount.textContent = overview ? String(overview.tickets.inProgress || 0) : "0";
        if (answeredCount) answeredCount.textContent = overview ? String(overview.tickets.answered || 0) : "0";
        if (closedCount) closedCount.textContent = overview ? String(overview.tickets.closed || 0) : "0";
      }
      function renderStats() {
        if (!state.overview) { statsContainer.innerHTML = ""; return; }
        const currentRelease = state.overview.release.current;
        const publishingRelease = state.overview.release.publishing;
        const activeTickets = Number(state.overview.tickets.active || 0);
        const resolvedTickets = Number(state.overview.tickets.resolved || 0);
        const cards = [
          {
            label: "Release live",
            value: currentRelease ? escapeHtml(currentRelease.version) : "Nessuna",
            note: currentRelease ? "Tag " + escapeHtml(currentRelease.tag) + " - " + formatDateTime(currentRelease.publishedAt) : "Ancora nessuna release pubblicata",
            tone: "tone-info",
          },
          {
            label: "Pipeline",
            value: publishingRelease ? escapeHtml(publishingRelease.version) : "Idle",
            note: publishingRelease ? "Pubblicazione iniziata " + formatDateTime(publishingRelease.startedAt) : "Nessun rilascio in corso",
            tone: publishingRelease ? "tone-warning" : "",
          },
          {
            label: "Ticket da gestire",
            value: String(activeTickets),
            note: state.overview.tickets.total + " totali, " + state.overview.tickets.waiting + " nuovi, " + state.overview.tickets.inProgress + " in lavorazione",
            tone: activeTickets > 0 ? "tone-warning" : "",
          },
          {
            label: "Ticket gestiti",
            value: String(resolvedTickets),
            note: state.overview.tickets.answered + " risposti, " + state.overview.tickets.closed + " chiusi, ultimo update " + formatDateTime(state.overview.tickets.latestUpdatedAt),
            tone: resolvedTickets > 0 ? "tone-success" : "",
          },
          {
            label: "Storage",
            value: escapeHtml(state.overview.dataProvider),
            note: "Service " + escapeHtml(state.overview.service) + ", overview generata " + formatDateTime(state.overview.generatedAt),
            tone: "",
          },
        ];
        statsContainer.innerHTML = cards.map((card) => '<article class="stat ' + escapeHtml(card.tone || "") + '"><div class="stat-label">' + card.label + '</div><div class="stat-value">' + card.value + '</div><div class="stat-note">' + card.note + '</div></article>').join("");
      }
      function renderTicketDetailLoading() {
        ticketDetail.innerHTML = '<div class="empty-state">Caricamento dettaglio ticket...</div>';
      }
      async function loadSelectedTicketDetail(options = {}) {
        if (!state.selectedTicketId) {
          return null;
        }

        const forceReload = options.force === true;
        if (!forceReload && state.ticketDetailsById[state.selectedTicketId]) {
          return state.ticketDetailsById[state.selectedTicketId];
        }

        const detail = await api(
          "/admin/api/tickets/" + encodeURIComponent(state.selectedTicketId)
        );
        state.ticketDetailsById[state.selectedTicketId] = detail;
        return detail;
      }
      async function selectTicket(ticketId) {
        if (!ticketId) {
          return;
        }
        state.selectedTicketId = ticketId;
        renderTicketList();
        renderTicketDetailLoading();
        try {
          await loadSelectedTicketDetail({ force: true });
          renderTicketDetail();
        } catch (error) {
          ticketDetail.innerHTML = '<div class="empty-state">Impossibile caricare il dettaglio ticket.</div>';
          setStatus(
            error.message || "Errore durante il caricamento del ticket.",
            "error",
            "dashboard"
          );
        }
      }
      function renderTicketList() {
        if (!state.tickets.length) { ticketList.innerHTML = '<div class="empty-state">Nessun ticket trovato.</div>'; return; }
        ticketList.innerHTML = state.tickets.map((ticket) => {
          const attachments = Array.isArray(ticket.attachments) ? ticket.attachments.length : 0;
          const replies = Array.isArray(ticket.replies) ? ticket.replies.length : 0;
          return '<article class="ticket-card ' + (ticket.id === state.selectedTicketId ? "is-active" : "") + '" data-ticket-id="' + escapeHtml(ticket.id) + '"><div class="ticket-card-head"><div class="ticket-badges">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div><span class="muted">' + formatDateTime(ticket.updatedAt) + '</span></div><div class="ticket-title">' + escapeHtml(ticket.subject) + '</div><div class="ticket-meta">' + escapeHtml(ticket.name || ticket.email || "Ticket anonimo") + '</div><div class="ticket-meta" style="margin-top:6px;">' + escapeHtml(ticket.message.slice(0, 120)) + (ticket.message.length > 120 ? "..." : "") + '</div><div class="ticket-card-summary"><span>' + replies + ' risposte</span><span>' + attachments + ' screenshot</span></div></article>';
        }).join("");
        ticketList.querySelectorAll("[data-ticket-id]").forEach((node) => node.addEventListener("click", () => selectTicket(node.getAttribute("data-ticket-id"))));
      }
      function renderTicketDetail() {
        if (!state.selectedTicketId) {
          ticketDetail.innerHTML = '<div class="empty-state">Seleziona un ticket dall elenco per aprire messaggi, allegati e risposta admin.</div>';
          return;
        }
        const ticket = state.ticketDetailsById[state.selectedTicketId];
        if (!ticket) {
          ticketDetail.innerHTML = '<div class="empty-state">Apri un ticket dalla lista per caricare il dettaglio completo.</div>';
          return;
        }
        const attachments = Array.isArray(ticket.attachments) ? ticket.attachments : [];
        const replies = Array.isArray(ticket.replies) ? ticket.replies : [];
        const attachmentsSection = attachments.length
          ? '<article class="message-card"><div class="field-label">Screenshot allegati</div><div class="attachment-gallery">' + attachments.map((attachment) => '<a class="attachment-card" target="_blank" rel="noreferrer" href="' + escapeHtml(resolveTicketAssetUrl(attachment.downloadPath || "#")) + '"><img class="attachment-preview" loading="lazy" src="' + escapeHtml(resolveTicketAssetUrl(attachment.downloadPath || "#")) + '" alt="' + escapeHtml(attachment.fileName || "Screenshot ticket") + '" /><div class="attachment-name">' + escapeHtml(attachment.fileName) + '</div><div class="attachment-meta">' + escapeHtml(attachment.contentType || "immagine") + ' - ' + escapeHtml(formatBytes(attachment.sizeBytes)) + '</div></a>').join("") + '</div></article>'
          : '';
        ticketDetail.innerHTML = '<div class="detail-shell"><div class="toolbar"><div><div class="reply-meta">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div><h3 class="detail-title">' + escapeHtml(ticket.subject) + '</h3><p class="lede">' + escapeHtml(ticket.name || ticket.email || "Ticket anonimo") + '</p></div></div><div class="detail-grid"><div class="field"><div class="field-label">Creato</div><div>' + formatDateTime(ticket.createdAt) + '</div></div><div class="field"><div class="field-label">Aggiornato</div><div>' + formatDateTime(ticket.updatedAt) + '</div></div><div class="field"><div class="field-label">Contatto</div><div>' + escapeHtml(ticket.name || "-") + (ticket.email ? " (" + escapeHtml(ticket.email) + ")" : "") + '</div></div><div class="field"><div class="field-label">Versione app</div><div>' + escapeHtml(ticket.appVersion || "-") + '</div></div></div><section class="thread"><article class="message-card"><div class="field-label">Messaggio utente</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(ticket.message) + '</div></article>' + attachmentsSection + (replies.map((reply) => '<article class="message-card reply"><div class="field-label">' + (reply.author === "admin" ? "Risposta admin" : "Replica utente") + ' - ' + formatDateTime(reply.createdAt) + '</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(reply.message) + '</div></article>').join("") || '<div class="empty-state">Ancora nessuna risposta nel thread.</div>') + '</section><form id="admin-reply-form" class="reply-form"><label class="field"><span class="field-label">Nuova risposta</span><textarea name="message" required placeholder="Scrivi la risposta che vuoi salvare nel thread del ticket"></textarea></label><label class="field"><span class="field-label">Nuovo stato</span><select name="status"><option value="answered">Risposto</option><option value="in_progress">In lavorazione</option><option value="closed">Chiuso</option></select></label><div class="reply-actions"><button type="submit" class="primary">Salva risposta</button></div></form></div>';
        const form = document.getElementById("admin-reply-form");
        form?.addEventListener("submit", async (event) => {
          event.preventDefault();
          const formData = new FormData(form);
          const message = String(formData.get("message") || "").trim();
          const status = String(formData.get("status") || "").trim();
          if (!message) { setStatus("Scrivi una risposta prima di salvare.", "error", "dashboard"); return; }
          try {
            setStatus("Salvataggio risposta...", "info", "dashboard");
            await api("/admin/api/tickets/" + encodeURIComponent(ticket.id) + "/replies", { method: "POST", body: JSON.stringify({ message, status }) });
            form.reset();
            delete state.ticketDetailsById[ticket.id];
            await loadDashboard();
            setStatus("Risposta ticket salvata.", "success", "dashboard");
          } catch (error) {
            setStatus(error.message || "Errore durante il salvataggio della risposta.", "error", "dashboard");
          }
        });
      }
      function renderUserList() {
        const canManageUsers = Boolean(state.adminUser && state.adminUser.isSuperAdmin === true);
        if (userManagementSection) {
          userManagementSection.classList.toggle("hidden", !canManageUsers);
        }
        if (!canManageUsers) {
          if (userSearchInput) {
            userSearchInput.value = "";
          }
          userList.innerHTML = "";
          return;
        }

        const normalizedSearch = String(state.userSearchQuery || "")
          .trim()
          .toLowerCase();
        const visibleUsers = normalizedSearch
          ? state.users.filter((user) =>
              String(user.email || "").toLowerCase().includes(normalizedSearch)
            )
          : state.users;

        if (!visibleUsers.length) {
          userList.innerHTML =
            state.users.length === 0
              ? '<div class="empty-state">Nessun profilo registrato.</div>'
              : '<div class="empty-state">Nessun utente trovato con questo filtro.</div>';
          return;
        }

        userList.innerHTML = visibleUsers.map((user) => {
          const isCurrentUser = Boolean(state.adminUser && state.adminUser.id === user.id);
          const roleLabel = user.isSuperAdmin
            ? "Super admin"
            : user.isAdmin
              ? "Admin"
              : "Utente";
          const roleTone = user.isSuperAdmin
            ? "warning"
            : user.isAdmin
              ? "success"
              : "info";
          const actionButtons = user.isSuperAdmin
            ? ""
            : (
                (user.isAdmin
                  ? '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="toggle-admin" data-next-admin="false">Rimuovi admin</button>'
                  : '<button type="button" class="primary" data-user-id="' + escapeHtml(user.id) + '" data-user-action="toggle-admin" data-next-admin="true">Rendi admin</button>') +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="edit-user">Modifica</button>' +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="reset-password">Reset password</button>' +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="delete-user">Elimina</button>'
              );

          return '<article class="user-row"><div class="user-row-main"><div class="user-row-email">' + escapeHtml(user.email) + '</div><div class="user-row-meta"><span class="pill ' + roleTone + '">' + roleLabel + '</span>' + (isCurrentUser ? '<span class="pill info">Sessione corrente</span>' : "") + '<span>Creato ' + formatDateTime(user.createdAt) + '</span><span>Aggiornato ' + formatDateTime(user.updatedAt) + '</span></div></div><div class="user-actions">' + actionButtons + '</div></article>';
        }).join("");

        userList.querySelectorAll("[data-user-action]").forEach((node) => {
          node.addEventListener("click", async () => {
            const userId = node.getAttribute("data-user-id");
            const action = node.getAttribute("data-user-action");
            if (!userId || !action) return;

            if (action === "toggle-admin") {
              const nextAdmin = node.getAttribute("data-next-admin") === "true";
              try {
                setStatus("Aggiornamento ruolo in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId) + "/admin",
                  {
                    method: "POST",
                    body: JSON.stringify({ isAdmin: nextAdmin })
                  }
                );
                await loadDashboard();
                setStatus("Ruolo aggiornato.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare il ruolo.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "edit-user") {
              const targetUser = state.users.find((user) => user.id === userId);
              if (!targetUser) {
                return;
              }

              const emailPrompt = window.prompt(
                "Email utente:",
                targetUser.email || ""
              );
              if (emailPrompt === null) {
                return;
              }
              const nextEmail = String(emailPrompt || "").trim().toLowerCase();
              if (!nextEmail) {
                setStatus("Email non valida.", "error", "dashboard");
                return;
              }

              const currentRole = targetUser.isAdmin ? "admin" : "user";
              const rolePrompt = window.prompt("Ruolo (user/admin):", currentRole);
              if (rolePrompt === null) {
                return;
              }
              const nextRole = String(rolePrompt || "").trim().toLowerCase();
              if (nextRole !== "user" && nextRole !== "admin") {
                setStatus("Ruolo non valido. Usa user oppure admin.", "error", "dashboard");
                return;
              }

              try {
                setStatus("Aggiornamento utente in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId),
                  {
                    method: "PATCH",
                    body: JSON.stringify({ email: nextEmail, role: nextRole })
                  }
                );
                await loadDashboard();
                setStatus("Utente aggiornato.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare l utente.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "reset-password") {
              const newPassword = window.prompt(
                "Nuova password per questo utente:",
                ""
              );
              if (newPassword === null) {
                return;
              }

              if (String(newPassword).trim().length === 0) {
                setStatus(
                  "La password non puo essere vuota.",
                  "error",
                  "dashboard"
                );
                return;
              }

              const confirmation = window.prompt("Conferma la nuova password:", "");
              if (confirmation === null) {
                return;
              }

              if (confirmation !== newPassword) {
                setStatus("Le password non coincidono.", "error", "dashboard");
                return;
              }

              try {
                setStatus("Aggiornamento password in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId) + "/password",
                  {
                    method: "POST",
                    body: JSON.stringify({ newPassword })
                  }
                );
                await loadDashboard();
                setStatus("Password aggiornata.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare la password.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "delete-user") {
              const targetUser = state.users.find((user) => user.id === userId);
              if (!targetUser) {
                return;
              }

              const confirmed = window.confirm(
                "Confermi eliminazione utente " + (targetUser.email || userId) + "?"
              );
              if (!confirmed) {
                return;
              }

              try {
                setStatus("Eliminazione utente in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId),
                  {
                    method: "DELETE"
                  }
                );
                await loadDashboard();
                setStatus("Utente eliminato.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile eliminare l utente.",
                  "error",
                  "dashboard"
                );
              }
            }
          });
        });
      }
      function resetDashboardState() {
        state.adminUser = null;
        state.overview = null;
        state.tickets = [];
        state.users = [];
        state.ticketDetailsById = {};
        state.selectedTicketId = null;
        state.userSearchQuery = "";
        if (userSearchInput) {
          userSearchInput.value = "";
        }
        renderWorkspaceSummary();
        renderStats();
        renderTicketList();
        renderTicketDetail();
        renderUserList();
      }
      async function loadDashboard() {
        const [adminUser, overview, ticketsResponse] = await Promise.all([
          api("/auth/me"),
          api("/admin/api/overview"),
          api("/admin/api/tickets")
        ]);
        state.adminUser = adminUser;
        state.overview = overview;
        state.tickets = Array.isArray(ticketsResponse.items) ? ticketsResponse.items : [];
        state.ticketDetailsById = Object.fromEntries(
          Object.entries(state.ticketDetailsById).filter(([ticketId]) =>
            state.tickets.some((ticket) => ticket.id === ticketId)
          )
        );
        if (adminUser && adminUser.isSuperAdmin === true) {
          const searchQuery = String(state.userSearchQuery || "").trim();
          const usersPath = searchQuery.length > 0
            ? "/admin/api/users?search=" + encodeURIComponent(searchQuery)
            : "/admin/api/users";
          const usersResponse = await api(usersPath);
          state.users = Array.isArray(usersResponse.items) ? usersResponse.items : [];
        } else {
          state.users = [];
        }
        if (state.selectedTicketId && !state.tickets.some((ticket) => ticket.id === state.selectedTicketId)) {
          state.selectedTicketId = null;
        }
        renderWorkspaceSummary();
        renderStats();
        renderTicketList();
        if (state.selectedTicketId) {
          renderTicketDetailLoading();
          try {
            await loadSelectedTicketDetail({ force: true });
          } catch (_) {}
        }
        renderTicketDetail();
        renderUserList();
        updateAuthPanel();
      }
      async function bootstrapDashboard() {
        if (!state.token) {
          authPanel.classList.remove("hidden");
          dashboardPanel.classList.add("hidden");
          resetDashboardState();
          updateAuthMode("login");
          updateAuthPanel();
          setStatus(defaultAuthMessage(), "info", "auth");
          return;
        }
        try {
          setStatus("Caricamento dashboard...", "info", "dashboard");
          await loadDashboard();
          authPanel.classList.add("hidden");
          dashboardPanel.classList.remove("hidden");
          setStatus("Dashboard aggiornata.", "success", "dashboard");
        } catch (error) {
          resetDashboardState();
          authPanel.classList.remove("hidden");
          dashboardPanel.classList.add("hidden");
          updateAuthMode("login");
          state.token = "";
          writeToken("");
          updateAuthPanel();
          setStatus(error.message || "Impossibile caricare la dashboard.", "error", "auth");
        }
      }
      async function loginAdmin() {
        const email = String(emailInput?.value || "").trim();
        const password = String(passwordInput?.value || "");
        if (!email || !password) {
          setStatus("Inserisci email e password del profilo admin.", "error", "auth");
          return;
        }

        try {
          setStatus("Verifica profilo admin...", "info", "auth");
          const response = await api("/auth/login", {
            method: "POST",
            body: JSON.stringify({ email, password })
          });
          if (!response.user || response.user.isAdmin !== true) {
            try {
              await fetch(resolveApiUrl("/auth/session"), {
                method: "DELETE",
                headers: {
                  Authorization: "Bearer " + response.token
                }
              });
            } catch (_) {}
            throw new Error("Questo profilo non ha accesso admin.");
          }

          state.token = String(response.token || "");
          state.adminUser = response.user || null;
          writeToken(state.token);
          if (emailInput) emailInput.value = response.user.email || email;
          if (passwordInput) passwordInput.value = "";
          await bootstrapDashboard();
        } catch (error) {
          state.token = "";
          state.adminUser = null;
          writeToken("");
          setStatus(error.message || "Accesso admin non riuscito.", "error", "auth");
        }
      }
      async function registerAccount() {
        const email = String(registerEmailInput?.value || "").trim();
        const password = String(registerPasswordInput?.value || "");
        if (!email || !password) {
          setStatus("Inserisci email e password per creare il profilo.", "error", "auth");
          return;
        }

        try {
          setStatus("Creazione profilo in corso...", "info", "auth");
          const response = await api("/auth/register", {
            method: "POST",
            body: JSON.stringify({ email, password })
          });

          if (registerForm) registerForm.reset();
          if (emailInput) emailInput.value = response.user?.email || email;

          if (response.user && response.user.isAdmin === true) {
            state.token = String(response.token || "");
            state.adminUser = response.user || null;
            writeToken(state.token);
            await bootstrapDashboard();
            return;
          }

          try {
            if (response.token) {
              await fetch(resolveApiUrl("/auth/session"), {
                method: "DELETE",
                headers: {
                  Authorization: "Bearer " + response.token
                }
              });
            }
          } catch (_) {}

          updateAuthMode("login");
          if (passwordInput) passwordInput.value = "";
          setStatus(
            "Profilo creato. Ora fai login quando il super admin ti avra promosso, oppure attendi la promozione dalla sezione Accessi e ruoli.",
            "success",
            "auth"
          );
        } catch (error) {
          setStatus(error.message || "Registrazione non riuscita.", "error", "auth");
        }
      }
      async function createManagedUser() {
        const email = String(createUserEmailInput?.value || "").trim();
        const password = String(createUserPasswordInput?.value || "");
        const role = String(createUserRoleInput?.value || "user")
          .trim()
          .toLowerCase();
        if (!email || !password) {
          setStatus("Inserisci email e password per creare l utente.", "error", "dashboard");
          return;
        }
        if (password.trim().length === 0) {
          setStatus("La password non puo essere vuota.", "error", "dashboard");
          return;
        }
        if (role !== "user" && role !== "admin") {
          setStatus("Ruolo non valido.", "error", "dashboard");
          return;
        }

        try {
          setStatus("Creazione utente in corso...", "info", "dashboard");
          const response = await api("/admin/api/users", {
            method: "POST",
            body: JSON.stringify({ email, password, role })
          });
          createUserForm?.reset();
          if (createUserRoleInput) {
            createUserRoleInput.value = "user";
          }
          await loadDashboard();
          const recoveryCode =
            response &&
            typeof response === "object" &&
            typeof response.recoveryCode === "string"
              ? response.recoveryCode
              : null;
          setStatus(
            recoveryCode
              ? "Utente creato. Recovery code: " + recoveryCode
              : "Utente creato.",
            "success",
            "dashboard"
          );
        } catch (error) {
          setStatus(
            error.message || "Impossibile creare l utente.",
            "error",
            "dashboard"
          );
        }
      }
      loginForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        loginAdmin();
      });
      registerForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        registerAccount();
      });
      createUserForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        createManagedUser();
      });
      userSearchInput?.addEventListener("input", (event) => {
        const target = event.target;
        const nextQuery =
          target && typeof target === "object" && "value" in target
            ? String(target.value || "")
            : "";
        state.userSearchQuery = nextQuery;
        renderUserList();
      });
      showRegisterButton?.addEventListener("click", () => {
        updateAuthMode("register");
        setStatus(
          "La registrazione crea un profilo normale. Solo il super admin puo darti accesso admin.",
          "info",
          "auth"
        );
      });
      showLoginButton?.addEventListener("click", () => {
        updateAuthMode("login");
        setStatus(defaultAuthMessage(), "info", "auth");
      });
      document.getElementById("admin-logout-btn")?.addEventListener("click", async () => {
        const currentToken = state.token;
        state.token = "";
        state.adminUser = null;
        writeToken("");
        if (passwordInput) passwordInput.value = "";
        try {
          if (currentToken) {
            await fetch(resolveApiUrl("/auth/session"), {
              method: "DELETE",
              headers: {
                Authorization: "Bearer " + currentToken
              }
            });
          }
        } catch (_) {}
        dashboardPanel.classList.add("hidden");
        authPanel.classList.remove("hidden");
        resetDashboardState();
        updateAuthMode("login");
        updateAuthPanel();
        setStatus("Sessione admin chiusa.", "info", "auth");
      });
      document.getElementById("admin-refresh-btn")?.addEventListener("click", bootstrapDashboard);
      document.getElementById("admin-refresh-tickets-btn")?.addEventListener("click", bootstrapDashboard);
      document.getElementById("admin-refresh-users-btn")?.addEventListener("click", bootstrapDashboard);
      updateAuthPanel();
      updateAuthMode("login");
      state.token = readToken();
      if (state.token) {
        bootstrapDashboard();
      } else {
        resetDashboardState();
        updateAuthPanel();
        setStatus(defaultAuthMessage(), "info", "auth");
      }
    </script>
  </body>
</html>`;
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
      : "APK non disponibile in questo momento";
  const versionValue = hasRelease
    ? `Versione ${latestRelease.version}`
    : isPublishing
      ? "Stiamo preparando la prossima versione"
      : "Nessuna versione disponibile in questo momento";
  const detailLabel = isPublishing
    ? hasRelease
      ? "Stiamo pubblicando una nuova versione. Il download tornera disponibile appena il rilascio e completato."
      : "Stiamo pubblicando una nuova versione. Il pulsante di download comparira qui appena pronto."
    : hasRelease
      ? "Qui trovi l ultima versione disponibile dell app Android."
      : "Il download non e disponibile al momento.";
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
  const notesLabel = latestRelease?.releaseNotes
    ? formatReleaseNotesForLanding(latestRelease.releaseNotes)
    : isPublishing
      ? "Aggiorna questa pagina tra qualche minuto per vedere la nuova versione."
      : "Controlla di nuovo piu tardi per vedere quando il download sara disponibile.";
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
          "Al momento non c e un APK disponibile da scaricare.",
          "Quando il download sara pronto, il pulsante Scarica APK comparira qui.",
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

      .button.secondary {
        background: rgba(255, 255, 255, 0.14);
        color: white;
        border: 1px solid rgba(255, 255, 255, 0.2);
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
          <a class="button secondary" href="${escapeHtml(baseUrl)}/tickets">Invia ticket</a>
          <a class="button secondary" href="${escapeHtml(baseUrl)}/admin">Area admin</a>
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
    logger: true,
    bodyLimit: 15 * 1024 * 1024
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

    const savedTicket = await saveSupportTicket(value, attachments);
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

    return serializeSupportTicket(updatedTicket);
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
        scheduleOverrides: 0
      }
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
