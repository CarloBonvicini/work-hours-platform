import { createHash, randomBytes, randomUUID, scryptSync } from "node:crypto";
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
  StoredAuthUser
} from "./data/store.js";
import {
  buildUniformWeekdayTargetMinutes,
  buildMonthlySummary,
  isIsoDate,
  isYearMonth,
  WEEKDAY_KEYS
} from "./domain/monthly-summary.js";
import type {
  DaySchedule,
  LeaveEntry,
  LeaveType,
  Profile,
  ScheduleOverride,
  WeekdaySchedule,
  WeekdayTargetMinutes,
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
  replies: SupportTicketReply[];
}

interface SupportTicketReply {
  id: string;
  author: SupportTicketReplyAuthor;
  message: string;
  createdAt: string;
}

interface AuthResponse {
  token: string;
  user: AuthUser;
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

function getUpdatesDirectory() {
  return process.env.MOBILE_UPDATES_DIR ?? "/app/updates";
}

function getReleaseMetadataPath() {
  return path.join(getUpdatesDirectory(), "latest-release.json");
}

function getReleaseStatusPath() {
  return path.join(getUpdatesDirectory(), "release-status.json");
}

function getTicketsDirectory() {
  return process.env.TICKETS_DIR ?? "/app/tickets";
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

function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

function createPasswordDigest(password: string) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return { salt, hash };
}

function verifyPasswordDigest(password: string, user: StoredAuthUser) {
  const hash = scryptSync(password, user.passwordSalt, 64).toString("hex");
  return hash === user.passwordHash;
}

function createSessionToken() {
  return randomBytes(32).toString("hex");
}

function hashSessionToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

function parseAuthCredentials(payload: unknown) {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid body" as const };
  }

  const body = payload as Record<string, unknown>;
  const email =
    typeof body.email === "string" ? normalizeEmail(body.email) : null;
  if (!email || !isValidEmail(email)) {
    return { value: null, error: "email must be valid" as const };
  }

  const password = typeof body.password === "string" ? body.password : null;
  if (!password || password.trim().length < 8) {
    return {
      value: null,
      error: "password must be at least 8 characters" as const
    };
  }

  return {
    value: {
      email,
      password
    }
  };
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
      weekdaySchedule
    }
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
    !isPositiveInteger(body.minutes)
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
    !isPositiveInteger(body.minutes) ||
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
): { value: CloudBackupRecord | null; error?: string } {
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

  const workEntries = Array.isArray(body.workEntries)
    ? body.workEntries.map(parseWorkEntryRecord)
    : null;
  const leaveEntries = Array.isArray(body.leaveEntries)
    ? body.leaveEntries.map(parseLeaveEntryRecord)
    : null;
  const scheduleOverrides = Array.isArray(body.scheduleOverrides)
    ? body.scheduleOverrides.map(parseScheduleOverrideRecord)
    : null;

  if (
    !workEntries ||
    workEntries.some((entry) => entry === null) ||
    !leaveEntries ||
    leaveEntries.some((entry) => entry === null) ||
    !scheduleOverrides ||
    scheduleOverrides.some((entry) => entry === null)
  ) {
    return {
      value: null,
      error:
        "workEntries, leaveEntries and scheduleOverrides must contain valid items"
    };
  }

  return {
    value: {
      profile: parsedProfile.value,
      appearanceSettings,
      workEntries: workEntries as WorkEntry[],
      leaveEntries: leaveEntries as LeaveEntry[],
      scheduleOverrides: scheduleOverrides as ScheduleOverride[],
      updatedAt: new Date().toISOString()
    }
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
): { value: SupportTicketInput | null; error?: string } {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  if (!isSupportTicketCategory(body.category)) {
    return {
      value: null,
      error: "category must be one of: bug, feature, support"
    };
  }

  const subject = normalizeRequiredText(body.subject, 160);
  if (!subject) {
    return { value: null, error: "subject is required" };
  }

  const message = normalizeRequiredText(body.message, 4000);
  if (!message) {
    return { value: null, error: "message is required" };
  }

  const email = normalizeOptionalText(body.email, 160);
  if (email && !isValidEmail(email)) {
    return { value: null, error: "email must be valid" };
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
    }
  };
}

async function saveSupportTicket(input: SupportTicketInput): Promise<SupportTicket> {
  const now = new Date().toISOString();
  const ticket: SupportTicket = {
    id: randomUUID(),
    status: "new",
    createdAt: now,
    updatedAt: now,
    replies: [],
    ...input
  };

  await fs.mkdir(getTicketsDirectory(), { recursive: true });
  await fs.writeFile(
    path.join(getTicketsDirectory(), `${ticket.id}.json`),
    JSON.stringify(ticket, null, 2),
    "utf8"
  );

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

function isAdminDashboardAuthorized(request: FastifyRequest) {
  const configuredToken = getAdminDashboardToken();
  if (!configuredToken) {
    return true;
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

function buildAdminOverview(options: {
  baseUrl: string;
  latestRelease: MobileReleaseMetadata | null;
  releaseStatus: MobileReleaseStatus | null;
  tickets: SupportTicket[];
}) {
  const { baseUrl, latestRelease, releaseStatus, tickets } = options;

  return {
    generatedAt: new Date().toISOString(),
    service: "work-hours-backend",
    dataProvider: process.env.DATA_PROVIDER ?? "memory",
    links: {
      landing: `${baseUrl}/`,
      publicTickets: `${baseUrl}/tickets`,
      health: `${baseUrl}/health`,
      releaseFeed: `${baseUrl}/mobile-updates/latest.json`
    },
    release: {
      current: latestRelease
        ? {
            version: latestRelease.version,
            tag: latestRelease.tag,
            publishedAt: latestRelease.publishedAt ?? null,
            fileName: latestRelease.fileName
          }
        : null,
      publishing: releaseStatus
        ? {
            version: releaseStatus.version,
            tag: releaseStatus.tag,
            startedAt: releaseStatus.startedAt ?? null
          }
        : null
    },
    tickets: {
      total: tickets.length,
      waiting: tickets.filter((ticket) => ticket.status === "new").length,
      inProgress: tickets.filter((ticket) => ticket.status === "in_progress").length,
      answered: tickets.filter((ticket) => ticket.status === "answered").length,
      closed: tickets.filter((ticket) => ticket.status === "closed").length,
      bug: tickets.filter((ticket) => ticket.category === "bug").length,
      feature: tickets.filter((ticket) => ticket.category === "feature").length,
      support: tickets.filter((ticket) => ticket.category === "support").length,
      latestCreatedAt: tickets[0]?.createdAt ?? null,
      latestUpdatedAt: tickets[0]?.updatedAt ?? null
    }
  };
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

      .hero a {
        display: inline-flex;
        margin-top: 18px;
        color: white;
        text-decoration: none;
        font-weight: 700;
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
        <a href="${escapeHtml(baseUrl)}/">Torna al download app</a>
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

function renderAdminPage(options: { baseUrl: string; authRequired: boolean }) {
  const { baseUrl, authRequired } = options;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Admin Dashboard - Work Hours Platform</title>
    <style>
      :root {
        --bg: #1b1d22;
        --bg-card: rgba(37, 37, 38, 0.96);
        --bg-soft: rgba(32, 35, 44, 0.92);
        --line: #3f3f46;
        --line-strong: #4c4c52;
        --ink: #eceff4;
        --muted: #98a2b3;
        --accent: #0e639c;
        --accent-soft: rgba(14, 99, 156, 0.16);
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
        color: var(--ink);
        font-family: "Segoe UI", "IBM Plex Sans", sans-serif;
        background:
          linear-gradient(180deg, rgba(14, 99, 156, 0.12), transparent 220px),
          radial-gradient(circle at top right, rgba(14, 99, 156, 0.14), transparent 32%),
          linear-gradient(180deg, #181818 0%, var(--bg) 100%);
      }
      .shell { max-width: 1440px; margin: 0 auto; padding: 28px 20px 56px; }
      .hero { text-align: center; margin-bottom: 22px; }
      .hero-actions { display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 12px; }
      .ghost-link, button, input, textarea, select {
        font: inherit;
      }
      .ghost-link {
        display: inline-flex; align-items: center; padding: 8px 12px; border-radius: 8px;
        border: 1px solid var(--line); background: rgba(22, 26, 35, 0.56); color: #c4e0f7; text-decoration: none; font-size: 12px; font-weight: 600;
      }
      .eyebrow { margin: 0 0 10px; color: var(--info); text-transform: uppercase; letter-spacing: 0.18em; font-size: 12px; }
      h1,h2,h3,h4 { margin: 0 0 12px; color: #fff; }
      h1 { font-size: clamp(2.2rem, 4vw, 3rem); }
      p { margin: 0; }
      .lede, .muted { color: var(--muted); line-height: 1.5; }
      .panel, .card, .stat { background: var(--bg-card); border: 1px solid var(--line); border-radius: 14px; box-shadow: var(--shadow); }
      .panel { padding: 20px; margin-bottom: 18px; }
      .hidden { display: none !important; }
      .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
      .toolbar-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
      button {
        border: 1px solid var(--line); border-radius: 10px; background: rgba(26, 30, 38, 0.9);
        color: var(--ink); min-height: 38px; padding: 0 14px; cursor: pointer;
      }
      button.primary { background: var(--accent); border-color: rgba(117, 190, 255, 0.42); color: white; }
      button:hover, .ghost-link:hover { border-color: var(--line-strong); }
      input, textarea, select {
        width: 100%; border-radius: 10px; border: 1px solid var(--line); background: #1f1f1f; color: var(--ink); padding: 12px 13px;
      }
      textarea { min-height: 140px; resize: vertical; }
      .status { border-radius: 10px; padding: 12px 14px; border: 1px solid transparent; font-weight: 600; }
      .status.info { background: rgba(117, 190, 255, 0.1); color: var(--info); }
      .status.error { background: var(--danger-soft); color: var(--danger); }
      .status.success { background: var(--success-soft); color: var(--success); }
      .stats { display: grid; gap: 12px; grid-template-columns: repeat(4, minmax(0, 1fr)); }
      .stat { padding: 18px; background: linear-gradient(180deg, rgba(37, 37, 38, 0.96), rgba(28, 28, 31, 0.96)); }
      .stat-label { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
      .stat-value { margin-top: 10px; font-size: 30px; font-weight: 700; }
      .stat-note { margin-top: 8px; color: var(--muted); font-size: 13px; line-height: 1.45; }
      .dashboard-grid { display: grid; gap: 16px; grid-template-columns: 340px minmax(0, 1fr); margin-top: 18px; }
      .ticket-list { display: grid; gap: 10px; max-height: 70vh; overflow: auto; }
      .ticket-card { border-radius: 12px; border: 1px solid var(--line); background: var(--bg-soft); padding: 14px; cursor: pointer; }
      .ticket-card.is-active { border-color: rgba(117, 190, 255, 0.72); box-shadow: inset 0 0 0 1px rgba(117, 190, 255, 0.24); }
      .ticket-card-head, .ticket-badges, .reply-meta, .reply-actions { display: flex; gap: 8px; flex-wrap: wrap; }
      .ticket-card-head, .toolbar { align-items: flex-start; }
      .ticket-card-head { justify-content: space-between; }
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
      .thread { display: grid; gap: 12px; margin-top: 18px; }
      .message-card { border-radius: 12px; border: 1px solid var(--line); padding: 14px; background: rgba(255,255,255,0.02); }
      .message-card.reply { background: rgba(117, 190, 255, 0.06); border-color: rgba(117, 190, 255, 0.22); }
      .detail-grid { display: grid; gap: 12px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .field { display: grid; gap: 6px; }
      .reply-form { display: grid; gap: 12px; margin-top: 20px; }
      .reply-actions { justify-content: flex-end; }
      .empty-state { border-radius: 12px; border: 1px dashed var(--line); padding: 18px; color: var(--muted); text-align: center; }
      @media (max-width: 1024px) { .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } .dashboard-grid { grid-template-columns: 1fr; } }
      @media (max-width: 720px) { .shell { padding: 20px 14px 40px; } .stats, .detail-grid { grid-template-columns: 1fr; } }
    </style>
  </head>
  <body data-base-url="${escapeHtml(baseUrl)}" data-auth-required="${authRequired ? "true" : "false"}">
    <main class="shell">
      <section class="hero">
        <div class="hero-actions">
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/">Home</a>
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/tickets">Ticket pubblici</a>
        </div>
        <p class="eyebrow">Work Hours Platform</p>
        <h1>Admin Dashboard</h1>
        <p class="lede">Panoramica rapida per manutenzione, release e ticket.</p>
      </section>

      <section class="panel" id="admin-auth-panel">
        <h2>Accesso admin</h2>
        <p class="lede">Inserisci il token admin per aprire la dashboard.</p>
        <div style="display:grid; gap:12px; margin-top:16px; max-width:420px;">
          <input id="admin-token-input" type="password" placeholder="Token admin" />
          <div class="toolbar-actions" style="justify-content:flex-start;">
            <button class="primary" id="admin-login-btn" type="button">Entra</button>
          </div>
        </div>
      </section>

      <section class="panel hidden" id="admin-dashboard-panel">
        <div class="toolbar">
          <div>
            <h2 style="margin-bottom:6px;">Console</h2>
            <p class="lede">Dati utili, stato release e thread ticket.</p>
          </div>
          <div class="toolbar-actions">
            <button type="button" id="admin-refresh-btn">Refresh</button>
            <button type="button" id="admin-logout-btn">Esci</button>
          </div>
        </div>
        <div id="admin-status" class="status info">Caricamento dashboard...</div>
        <section style="margin-top:18px;">
          <div class="stats" id="admin-stats"></div>
        </section>
        <section class="dashboard-grid">
          <aside class="card" style="padding:16px;">
            <div class="toolbar">
              <h3 style="margin-bottom:0;">Ticket</h3>
              <button type="button" id="admin-refresh-tickets-btn">Aggiorna</button>
            </div>
            <div class="ticket-list" id="admin-ticket-list" style="margin-top:14px;"></div>
          </aside>
          <section class="card" style="padding:18px;" id="admin-ticket-detail"></section>
        </section>
      </section>
    </main>
    <script>
      const ADMIN_TOKEN_KEY = "work_hours_admin_token";
      const baseUrl = document.body.dataset.baseUrl || "";
      const authRequired = document.body.dataset.authRequired === "true";
      const authPanel = document.getElementById("admin-auth-panel");
      const dashboardPanel = document.getElementById("admin-dashboard-panel");
      const tokenInput = document.getElementById("admin-token-input");
      const statusBox = document.getElementById("admin-status");
      const statsContainer = document.getElementById("admin-stats");
      const ticketList = document.getElementById("admin-ticket-list");
      const ticketDetail = document.getElementById("admin-ticket-detail");
      const state = { token: "", overview: null, tickets: [], selectedTicketId: null };

      function readToken() { try { return sessionStorage.getItem(ADMIN_TOKEN_KEY) || ""; } catch (_) { return ""; } }
      function writeToken(value) { try { value ? sessionStorage.setItem(ADMIN_TOKEN_KEY, value) : sessionStorage.removeItem(ADMIN_TOKEN_KEY); } catch (_) {} }
      function escapeHtml(value) {
        return String(value ?? "").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#39;");
      }
      function formatDateTime(value) {
        if (!value) return "—";
        try { return new Date(value).toLocaleString("it-IT", { dateStyle: "medium", timeStyle: "short" }); }
        catch (_) { return value; }
      }
      function setStatus(message, tone = "info") {
        statusBox.textContent = message;
        statusBox.className = "status " + tone;
      }
      async function api(path, options = {}) {
        const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
        if (state.token) headers.Authorization = "Bearer " + state.token;
        const response = await fetch(path, { ...options, headers });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(payload.error || "Request failed");
        return payload;
      }
      function statusBadge(status) {
        const labels = { new: "Nuovo", in_progress: "In lavorazione", answered: "Risposto", closed: "Chiuso" };
        return '<span class="badge status-' + escapeHtml(status) + '">' + (labels[status] || status) + '</span>';
      }
      function categoryBadge(category) {
        const labels = { bug: "Bug", feature: "Feature", support: "Supporto" };
        return '<span class="badge category-' + escapeHtml(category) + '">' + (labels[category] || category) + '</span>';
      }
      function renderStats() {
        if (!state.overview) { statsContainer.innerHTML = ""; return; }
        const cards = [
          {
            label: "Release corrente",
            value: state.overview.release.current ? escapeHtml(state.overview.release.current.version) : "Nessuna",
            note: state.overview.release.current ? "Tag " + escapeHtml(state.overview.release.current.tag) : "Ancora nessuna release pubblicata",
          },
          {
            label: "Release in corso",
            value: state.overview.release.publishing ? escapeHtml(state.overview.release.publishing.version) : "No",
            note: state.overview.release.publishing ? "Da " + formatDateTime(state.overview.release.publishing.startedAt) : "Nessun rilascio in pubblicazione",
          },
          {
            label: "Ticket aperti",
            value: String(state.overview.tickets.waiting + state.overview.tickets.inProgress),
            note: state.overview.tickets.total + " ticket totali",
          },
          {
            label: "Provider dati",
            value: escapeHtml(state.overview.dataProvider),
            note: "Health e release feed disponibili dalla dashboard",
          },
        ];
        statsContainer.innerHTML = cards.map((card) => '<article class="stat"><div class="stat-label">' + card.label + '</div><div class="stat-value">' + card.value + '</div><div class="stat-note">' + card.note + '</div></article>').join("");
      }
      function selectTicket(ticketId) { state.selectedTicketId = ticketId; renderTicketList(); renderTicketDetail(); }
      function renderTicketList() {
        if (!state.tickets.length) { ticketList.innerHTML = '<div class="empty-state">Nessun ticket trovato.</div>'; return; }
        ticketList.innerHTML = state.tickets.map((ticket) => '<article class="ticket-card ' + (ticket.id === state.selectedTicketId ? "is-active" : "") + '" data-ticket-id="' + escapeHtml(ticket.id) + '"><div class="ticket-card-head"><div class="ticket-badges">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div><span class="muted">' + formatDateTime(ticket.updatedAt) + '</span></div><div class="ticket-title">' + escapeHtml(ticket.subject) + '</div><div class="ticket-meta">' + escapeHtml(ticket.name || ticket.email || "Ticket anonimo") + '</div><div class="ticket-meta" style="margin-top:6px;">' + escapeHtml(ticket.message.slice(0, 120)) + (ticket.message.length > 120 ? "..." : "") + '</div></article>').join("");
        ticketList.querySelectorAll("[data-ticket-id]").forEach((node) => node.addEventListener("click", () => selectTicket(node.getAttribute("data-ticket-id"))));
      }
      function renderTicketDetail() {
        const ticket = state.tickets.find((entry) => entry.id === state.selectedTicketId) || state.tickets[0];
        if (!ticket) { ticketDetail.innerHTML = '<div class="empty-state">Seleziona un ticket per vedere il dettaglio.</div>'; return; }
        state.selectedTicketId = ticket.id;
        const replies = Array.isArray(ticket.replies) ? ticket.replies : [];
        ticketDetail.innerHTML = '<div class="toolbar"><div><h3 style="margin-bottom:6px;">' + escapeHtml(ticket.subject) + '</h3><div class="reply-meta">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div></div></div><div class="detail-grid" style="margin-top:14px;"><div class="field"><div class="field-label">Creato</div><div>' + formatDateTime(ticket.createdAt) + '</div></div><div class="field"><div class="field-label">Aggiornato</div><div>' + formatDateTime(ticket.updatedAt) + '</div></div><div class="field"><div class="field-label">Contatto</div><div>' + escapeHtml(ticket.name || "—") + (ticket.email ? " (" + escapeHtml(ticket.email) + ")" : "") + '</div></div><div class="field"><div class="field-label">Versione app</div><div>' + escapeHtml(ticket.appVersion || "—") + '</div></div></div><section class="thread"><article class="message-card"><div class="field-label">Messaggio utente</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(ticket.message) + '</div></article>' + (replies.map((reply) => '<article class="message-card reply"><div class="field-label">' + (reply.author === "admin" ? "Risposta admin" : "Replica utente") + ' · ' + formatDateTime(reply.createdAt) + '</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(reply.message) + '</div></article>').join("") || '<div class="empty-state">Ancora nessuna risposta nel thread.</div>') + '</section><form id="admin-reply-form" class="reply-form"><label class="field"><span class="field-label">Nuova risposta</span><textarea name="message" required placeholder="Scrivi la risposta che vuoi salvare nel thread del ticket"></textarea></label><label class="field"><span class="field-label">Nuovo stato</span><select name="status"><option value="answered">Risposto</option><option value="in_progress">In lavorazione</option><option value="closed">Chiuso</option></select></label><div class="reply-actions"><button type="submit" class="primary">Salva risposta</button></div></form>';
        const form = document.getElementById("admin-reply-form");
        form?.addEventListener("submit", async (event) => {
          event.preventDefault();
          const formData = new FormData(form);
          const message = String(formData.get("message") || "").trim();
          const status = String(formData.get("status") || "").trim();
          if (!message) { setStatus("Scrivi una risposta prima di salvare.", "error"); return; }
          try {
            setStatus("Salvataggio risposta...", "info");
            await api(baseUrl + "/admin/api/tickets/" + encodeURIComponent(ticket.id) + "/replies", { method: "POST", body: JSON.stringify({ message, status }) });
            form.reset();
            await loadDashboard();
            setStatus("Risposta ticket salvata.", "success");
          } catch (error) {
            setStatus(error.message || "Errore durante il salvataggio della risposta.", "error");
          }
        });
      }
      async function loadDashboard() {
        state.overview = await api(baseUrl + "/admin/api/overview");
        state.tickets = (await api(baseUrl + "/admin/api/tickets")).items || [];
        if (!state.selectedTicketId && state.tickets[0]) state.selectedTicketId = state.tickets[0].id;
        renderStats();
        renderTicketList();
        renderTicketDetail();
      }
      async function bootstrapDashboard() {
        try {
          setStatus("Caricamento dashboard...", "info");
          await loadDashboard();
          authPanel.classList.add("hidden");
          dashboardPanel.classList.remove("hidden");
          setStatus("Dashboard aggiornata.", "success");
        } catch (error) {
          if (authRequired) {
            authPanel.classList.remove("hidden");
            dashboardPanel.classList.add("hidden");
          }
          setStatus(error.message || "Impossibile caricare la dashboard.", "error");
        }
      }
      document.getElementById("admin-login-btn")?.addEventListener("click", () => {
        state.token = String(tokenInput.value || "").trim();
        writeToken(state.token);
        bootstrapDashboard();
      });
      document.getElementById("admin-logout-btn")?.addEventListener("click", () => {
        state.token = ""; writeToken(""); tokenInput.value = "";
        dashboardPanel.classList.add("hidden");
        if (authRequired) { authPanel.classList.remove("hidden"); setStatus("Token rimosso.", "info"); }
        else { bootstrapDashboard(); }
      });
      document.getElementById("admin-refresh-btn")?.addEventListener("click", bootstrapDashboard);
      document.getElementById("admin-refresh-tickets-btn")?.addEventListener("click", bootstrapDashboard);
      state.token = readToken();
      if (state.token) tokenInput.value = state.token;
      if (!authRequired) authPanel.classList.add("hidden");
      bootstrapDashboard();
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

  app.get("/tickets", async (request, reply) => {
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderTicketPage({ baseUrl }));
  });

  app.post("/tickets", async (request, reply) => {
    const { value, error } = parseSupportTicketInput(
      request.body,
      typeof request.headers["user-agent"] === "string"
        ? request.headers["user-agent"]
        : undefined
    );
    if (!value) {
      return reply.code(400).send({ error: error ?? "Invalid ticket payload" });
    }

    const savedTicket = await saveSupportTicket(value);
    return reply.code(201).send(savedTicket);
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

    return ticket;
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

    return updatedTicket;
  });

  app.get("/admin", async (request, reply) => {
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(
        renderAdminPage({
          baseUrl,
          authRequired: getAdminDashboardToken() !== null
        })
      );
  });

  app.get("/admin/api/overview", async (request, reply) => {
    if (!isAdminDashboardAuthorized(request)) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const baseUrl = getPublicBaseUrl(request);
    const latestRelease = await loadReleaseMetadata();
    const releaseStatus = await loadReleaseStatus();
    const tickets = await listSupportTickets();

    return buildAdminOverview({
      baseUrl,
      latestRelease,
      releaseStatus,
      tickets
    });
  });

  app.get("/admin/api/tickets", async (request, reply) => {
    if (!isAdminDashboardAuthorized(request)) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    return {
      items: await listSupportTickets()
    };
  });

  app.post("/admin/api/tickets/:ticketId/replies", async (request, reply) => {
    if (!isAdminDashboardAuthorized(request)) {
      return reply.code(401).send({ error: "Unauthorized" });
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

    return updatedTicket;
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
    const createdUser = await store.createAuthUser({
      id: randomUUID(),
      email: parsedCredentials.value.email,
      passwordHash: passwordDigest.hash,
      passwordSalt: passwordDigest.salt,
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
      user: createdUser
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

    const token = createSessionToken();
    const now = new Date().toISOString();
    await store.saveAuthSession({
      tokenHash: hashSessionToken(token),
      userId: user.id,
      createdAt: now,
      updatedAt: now
    });

    const response: AuthResponse = {
      token,
      user: {
        id: user.id,
        email: user.email,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    };

    return response;
  });

  app.get("/auth/me", async (request, reply) => {
    const { user } = await readAuthenticatedUser(request, store);
    if (!user) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    return user;
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
      bundle: savedBundle
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
