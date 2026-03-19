export type LeaveType = "vacation" | "permit";
export type Weekday =
  | "monday"
  | "tuesday"
  | "wednesday"
  | "thursday"
  | "friday"
  | "saturday"
  | "sunday";

export type WeekdayTargetMinutes = Record<Weekday, number>;
export interface DaySchedule {
  targetMinutes: number;
  startTime?: string;
  endTime?: string;
  breakMinutes: number;
}

export type WeekdaySchedule = Record<Weekday, DaySchedule>;

export interface Profile {
  id: string;
  fullName: string;
  useUniformDailyTarget: boolean;
  dailyTargetMinutes: number;
  weekdayTargetMinutes: WeekdayTargetMinutes;
  weekdaySchedule: WeekdaySchedule;
}

export interface WorkEntry {
  id: string;
  date: string;
  minutes: number;
  note?: string;
}

export interface LeaveEntry {
  id: string;
  date: string;
  minutes: number;
  type: LeaveType;
  note?: string;
}

export interface ScheduleOverride {
  id: string;
  date: string;
  targetMinutes: number;
  startTime?: string;
  endTime?: string;
  breakMinutes: number;
  note?: string;
}

export interface MonthlySummary {
  month: string;
  expectedMinutes: number;
  workedMinutes: number;
  leaveMinutes: number;
  balanceMinutes: number;
}
