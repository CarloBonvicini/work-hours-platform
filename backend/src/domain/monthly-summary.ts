import type {
  DaySchedule,
  LeaveEntry,
  MonthlySummary,
  Profile,
  ScheduleOverride,
  UserWorkRules,
  WorkPermissionMovement,
  WorkPermissionRule,
  Weekday,
  WeekdaySchedule,
  WorkEntry
} from "./types.js";

export const WEEKDAY_KEYS: Weekday[] = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday"
];

const DEFAULT_UNBOUNDED_DAILY_LIMIT_MINUTES = 24 * 60;
const DEFAULT_UNBOUNDED_MONTHLY_LIMIT_MINUTES = 31 * 24 * 60;
const WORK_PERMISSION_PERIODS = ["daily", "weekly", "monthly", "yearly"] as const;
const WORK_PERMISSION_MOVEMENTS = [
  "entry_late",
  "exit_early",
  "entry_early",
  "exit_late"
] as const;

export function isYearMonth(value: string): boolean {
  return /^\d{4}-(0[1-9]|1[0-2])$/.test(value);
}

export function isIsoDate(value: string): boolean {
  if (!/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(value)) {
    return false;
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  return parsed.toISOString().slice(0, 10) === value;
}

export function countWeekdaysInMonth(month: string): number {
  if (!isYearMonth(month)) {
    throw new Error(`Invalid month format: ${month}`);
  }

  const [yearPart, monthPart] = month.split("-");
  const year = Number(yearPart);
  const monthIndex = Number(monthPart) - 1;
  const daysInMonth = new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();

  let weekdays = 0;
  for (let day = 1; day <= daysInMonth; day += 1) {
    const currentDate = new Date(Date.UTC(year, monthIndex, day));
    const weekDay = currentDate.getUTCDay();
    if (weekDay !== 0 && weekDay !== 6) {
      weekdays += 1;
    }
  }

  return weekdays;
}

function toWeekdayKey(date: Date): Weekday {
  switch (date.getUTCDay()) {
    case 0:
      return "sunday";
    case 1:
      return "monday";
    case 2:
      return "tuesday";
    case 3:
      return "wednesday";
    case 4:
      return "thursday";
    case 5:
      return "friday";
    default:
      return "saturday";
  }
}

export function buildUniformWeekdayTargetMinutes(
  dailyTargetMinutes: number
): Profile["weekdayTargetMinutes"] {
  return {
    monday: dailyTargetMinutes,
    tuesday: dailyTargetMinutes,
    wednesday: dailyTargetMinutes,
    thursday: dailyTargetMinutes,
    friday: dailyTargetMinutes,
    saturday: 0,
    sunday: 0
  };
}

export function buildUniformWeekdaySchedule(
  dailyTargetMinutes: number,
  options: {
    startTime?: string;
    endTime?: string;
    breakMinutes?: number;
  } = {}
): WeekdaySchedule {
  const weekdaySchedule: WeekdaySchedule = {
    monday: buildDaySchedule(dailyTargetMinutes, options),
    tuesday: buildDaySchedule(dailyTargetMinutes, options),
    wednesday: buildDaySchedule(dailyTargetMinutes, options),
    thursday: buildDaySchedule(dailyTargetMinutes, options),
    friday: buildDaySchedule(dailyTargetMinutes, options),
    saturday: buildDaySchedule(0),
    sunday: buildDaySchedule(0)
  };

  return weekdaySchedule;
}

function buildDaySchedule(
  targetMinutes: number,
  options: {
    startTime?: string;
    endTime?: string;
    breakMinutes?: number;
  } = {}
): DaySchedule {
  return {
    targetMinutes,
    startTime: options.startTime,
    endTime: options.endTime,
    breakMinutes: options.breakMinutes ?? 0
  };
}

function clampMinutes(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}

export function clampBalanceMinutes(
  balanceMinutes: number,
  maximumCreditMinutes: number,
  maximumDebitMinutes: number
): number {
  if (balanceMinutes >= 0) {
    return clampMinutes(balanceMinutes, 0, maximumCreditMinutes);
  }

  return -clampMinutes(-balanceMinutes, 0, maximumDebitMinutes);
}

export function defaultMinimumBreakMinutes(
  weekdaySchedule: WeekdaySchedule
): number {
  const scheduledBreaks = WEEKDAY_KEYS.map((key) => weekdaySchedule[key].breakMinutes)
    .filter((minutes) => minutes > 0);

  if (scheduledBreaks.length === 0) {
    return 0;
  }

  return scheduledBreaks.reduce((current, next) =>
    current < next ? current : next
  );
}

export function buildDefaultWorkRules(
  profile: Pick<Profile, "dailyTargetMinutes" | "weekdaySchedule">
): UserWorkRules {
  return {
    expectedDailyMinutes: profile.dailyTargetMinutes,
    minimumBreakMinutes: defaultMinimumBreakMinutes(profile.weekdaySchedule),
    maximumDailyCreditMinutes: DEFAULT_UNBOUNDED_DAILY_LIMIT_MINUTES,
    maximumDailyDebitMinutes: DEFAULT_UNBOUNDED_DAILY_LIMIT_MINUTES,
    maximumMonthlyCreditMinutes: DEFAULT_UNBOUNDED_MONTHLY_LIMIT_MINUTES,
    maximumMonthlyDebitMinutes: DEFAULT_UNBOUNDED_MONTHLY_LIMIT_MINUTES,
    overtimeEnabled: false,
    overtimeCapEnabled: false,
    overtimeDailyCapMinutes: 0,
    overtimeWeeklyCapMinutes: 0,
    overtimeMonthlyCapMinutes: 0,
    fixedScheduleEnabled: false,
    flexibleStartEnabled: false,
    flexibleStartWindowMinutes: 0,
    walletEnabled: false,
    walletDailyExitEarlyMinutes: 0,
    walletWeeklyExitEarlyMinutes: 0,
    implicitCreditEnabled: false,
    implicitCreditDailyCapMinutes: 0,
    additionalPermissions: [],
    leaveBanks: []
  };
}

function sanitizePermissionMovements(value: unknown): WorkPermissionMovement[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.flatMap((entry) => {
    if (
      typeof entry === "string" &&
      (WORK_PERMISSION_MOVEMENTS as readonly string[]).includes(entry)
    ) {
      return [entry as WorkPermissionMovement];
    }
    return [];
  });
}

function sanitizeWorkPermissionRule(value: unknown): WorkPermissionRule | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const rule = value as Record<string, unknown>;
  if (
    typeof rule.id !== "string" ||
    rule.id.trim().length === 0 ||
    typeof rule.name !== "string" ||
    rule.name.trim().length === 0
  ) {
    return null;
  }

  const period: WorkPermissionRule["period"] =
    typeof rule.period === "string" &&
      (WORK_PERMISSION_PERIODS as readonly string[]).includes(rule.period)
      ? (rule.period as WorkPermissionRule["period"])
      : "monthly";

  const allowanceMinutes =
    Number.isInteger(rule.allowanceMinutes) && (rule.allowanceMinutes as number) >= 0
      ? (rule.allowanceMinutes as number)
      : 0;
  const usedMinutes =
    Number.isInteger(rule.usedMinutes) && (rule.usedMinutes as number) >= 0
      ? (rule.usedMinutes as number)
      : 0;
  const movements = sanitizePermissionMovements(rule.movements);
  if (movements.length === 0) {
    movements.push("entry_late", "exit_early");
  }

  return {
    id: rule.id.trim(),
    name: rule.name.trim(),
    enabled: rule.enabled !== false,
    period,
    allowanceMinutes,
    usedMinutes,
    movements
  };
}

function sanitizeWorkPermissionRules(value: unknown): WorkPermissionRule[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.flatMap((entry) => {
    const rule = sanitizeWorkPermissionRule(entry);
    return rule ? [rule] : [];
  });
}

export function sanitizeWorkRules(
  value: UserWorkRules | null | undefined,
  fallbackProfile: Pick<Profile, "dailyTargetMinutes" | "weekdaySchedule">
): UserWorkRules {
  const fallback = buildDefaultWorkRules(fallbackProfile);
  if (!value || typeof value !== "object") {
    return fallback;
  }

  return {
    expectedDailyMinutes:
      Number.isInteger(value.expectedDailyMinutes) && value.expectedDailyMinutes > 0
        ? value.expectedDailyMinutes
        : fallback.expectedDailyMinutes,
    minimumBreakMinutes:
      Number.isInteger(value.minimumBreakMinutes) && value.minimumBreakMinutes >= 0
        ? value.minimumBreakMinutes
        : fallback.minimumBreakMinutes,
    maximumDailyCreditMinutes:
      Number.isInteger(value.maximumDailyCreditMinutes) &&
      value.maximumDailyCreditMinutes >= 0
        ? value.maximumDailyCreditMinutes
        : fallback.maximumDailyCreditMinutes,
    maximumDailyDebitMinutes:
      Number.isInteger(value.maximumDailyDebitMinutes) &&
      value.maximumDailyDebitMinutes >= 0
        ? value.maximumDailyDebitMinutes
        : fallback.maximumDailyDebitMinutes,
    maximumMonthlyCreditMinutes:
      Number.isInteger(value.maximumMonthlyCreditMinutes) &&
      value.maximumMonthlyCreditMinutes >= 0
        ? value.maximumMonthlyCreditMinutes
        : fallback.maximumMonthlyCreditMinutes,
    maximumMonthlyDebitMinutes:
      Number.isInteger(value.maximumMonthlyDebitMinutes) &&
      value.maximumMonthlyDebitMinutes >= 0
        ? value.maximumMonthlyDebitMinutes
        : fallback.maximumMonthlyDebitMinutes,
    overtimeEnabled: value.overtimeEnabled === true,
    overtimeCapEnabled: value.overtimeCapEnabled === true,
    overtimeDailyCapMinutes:
      Number.isInteger(value.overtimeDailyCapMinutes) &&
      (value.overtimeDailyCapMinutes as number) >= 0
        ? (value.overtimeDailyCapMinutes as number)
        : 0,
    overtimeWeeklyCapMinutes:
      Number.isInteger(value.overtimeWeeklyCapMinutes) &&
      (value.overtimeWeeklyCapMinutes as number) >= 0
        ? (value.overtimeWeeklyCapMinutes as number)
        : 0,
    overtimeMonthlyCapMinutes:
      Number.isInteger(value.overtimeMonthlyCapMinutes) &&
      (value.overtimeMonthlyCapMinutes as number) >= 0
        ? (value.overtimeMonthlyCapMinutes as number)
        : 0,
    fixedScheduleEnabled: value.fixedScheduleEnabled === true,
    flexibleStartEnabled: value.flexibleStartEnabled === true,
    flexibleStartWindowMinutes:
      Number.isInteger(value.flexibleStartWindowMinutes) &&
      (value.flexibleStartWindowMinutes as number) >= 0
        ? (value.flexibleStartWindowMinutes as number)
        : 0,
    walletEnabled: value.walletEnabled === true,
    walletDailyExitEarlyMinutes:
      Number.isInteger(value.walletDailyExitEarlyMinutes) &&
      (value.walletDailyExitEarlyMinutes as number) >= 0
        ? (value.walletDailyExitEarlyMinutes as number)
        : 0,
    walletWeeklyExitEarlyMinutes:
      Number.isInteger(value.walletWeeklyExitEarlyMinutes) &&
      (value.walletWeeklyExitEarlyMinutes as number) >= 0
        ? (value.walletWeeklyExitEarlyMinutes as number)
        : 0,
    implicitCreditEnabled: value.implicitCreditEnabled === true,
    implicitCreditDailyCapMinutes:
      Number.isInteger(value.implicitCreditDailyCapMinutes) &&
      (value.implicitCreditDailyCapMinutes as number) >= 0
        ? (value.implicitCreditDailyCapMinutes as number)
        : 0,
    additionalPermissions: sanitizeWorkPermissionRules(value.additionalPermissions),
    leaveBanks: sanitizeWorkPermissionRules(value.leaveBanks)
  };
}

export function buildExpectedMinutes(
  month: string,
  profile: Profile,
  scheduleOverrides: ScheduleOverride[]
): number {
  if (!isYearMonth(month)) {
    throw new Error(`Invalid month format: ${month}`);
  }

  const overridesByDate = new Map(
    scheduleOverrides.map((entry) => [entry.date, entry.targetMinutes])
  );
  const [yearPart, monthPart] = month.split("-");
  const year = Number(yearPart);
  const monthIndex = Number(monthPart) - 1;
  const daysInMonth = new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();

  let expectedMinutes = 0;
  for (let day = 1; day <= daysInMonth; day += 1) {
    const currentDate = new Date(Date.UTC(year, monthIndex, day));
    const isoDate = currentDate.toISOString().slice(0, 10);
    const overrideMinutes = overridesByDate.get(isoDate);
    if (overrideMinutes !== undefined) {
      expectedMinutes += overrideMinutes;
      continue;
    }

    const weekdayKey = toWeekdayKey(currentDate);
    expectedMinutes += profile.weekdayTargetMinutes[weekdayKey];
  }

  return expectedMinutes;
}

export function buildMonthlySummary(
  month: string,
  profile: Profile,
  workEntries: WorkEntry[],
  leaveEntries: LeaveEntry[],
  scheduleOverrides: ScheduleOverride[]
): MonthlySummary {
  const expectedMinutes = buildExpectedMinutes(
    month,
    profile,
    scheduleOverrides
  );
  const workedMinutes = workEntries.reduce((total, entry) => total + entry.minutes, 0);
  const leaveMinutes = leaveEntries.reduce((total, entry) => total + entry.minutes, 0);
  const workRules = sanitizeWorkRules(profile.workRules, profile);
  const rawBalanceMinutes = workedMinutes + leaveMinutes - expectedMinutes;

  return {
    month,
    expectedMinutes,
    workedMinutes,
    leaveMinutes,
    rawBalanceMinutes,
    balanceMinutes: clampBalanceMinutes(
      rawBalanceMinutes,
      workRules.maximumMonthlyCreditMinutes,
      workRules.maximumMonthlyDebitMinutes
    ),
    remainingCreditMinutes: clampMinutes(
      workRules.maximumMonthlyCreditMinutes - rawBalanceMinutes,
      0,
      workRules.maximumMonthlyCreditMinutes
    ),
    remainingDebitMinutes: clampMinutes(
      workRules.maximumMonthlyDebitMinutes + rawBalanceMinutes,
      0,
      workRules.maximumMonthlyDebitMinutes
    )
  };
}
