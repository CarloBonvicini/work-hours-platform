import type {
  LeaveEntry,
  MonthlySummary,
  Profile,
  WorkEntry
} from "./types.js";

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

export function buildMonthlySummary(
  month: string,
  profile: Profile,
  workEntries: WorkEntry[],
  leaveEntries: LeaveEntry[]
): MonthlySummary {
  const expectedMinutes = countWeekdaysInMonth(month) * profile.dailyTargetMinutes;
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
