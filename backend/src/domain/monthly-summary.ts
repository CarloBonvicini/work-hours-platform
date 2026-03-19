import type {
  LeaveEntry,
  MonthlySummary,
  Profile,
  ScheduleOverride,
  Weekday,
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

  return {
    month,
    expectedMinutes,
    workedMinutes,
    leaveMinutes,
    balanceMinutes: workedMinutes + leaveMinutes - expectedMinutes
  };
}
