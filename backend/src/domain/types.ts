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

export type WorkPermissionMovement =
  | "entry_late"
  | "exit_early"
  | "entry_early"
  | "exit_late";

export type WorkAllowancePeriod = "daily" | "weekly" | "monthly" | "yearly";
export type PauseAdjustmentMode = "keep_worked_minutes" | "keep_end_time";

export interface WorkPermissionRule {
  id: string;
  name: string;
  enabled: boolean;
  period: WorkAllowancePeriod;
  allowanceMinutes: number;
  usedMinutes: number;
  movements: WorkPermissionMovement[];
}

export interface UserWorkRules {
  expectedDailyMinutes: number;
  minimumBreakMinutes: number;
  maximumDailyCreditMinutes: number;
  maximumDailyDebitMinutes: number;
  maximumMonthlyCreditMinutes: number;
  maximumMonthlyDebitMinutes: number;
  overtimeEnabled?: boolean;
  overtimeCapEnabled?: boolean;
  overtimeDailyCapMinutes?: number;
  overtimeWeeklyCapMinutes?: number;
  overtimeMonthlyCapMinutes?: number;
  fixedScheduleEnabled?: boolean;
  flexibleStartEnabled?: boolean;
  flexibleStartWindowMinutes?: number;
  walletEnabled?: boolean;
  walletDailyExitEarlyMinutes?: number;
  walletWeeklyExitEarlyMinutes?: number;
  implicitCreditEnabled?: boolean;
  implicitCreditDailyCapMinutes?: number;
  pauseAdjustmentMode?: PauseAdjustmentMode;
  additionalPermissions?: WorkPermissionRule[];
  leaveBanks?: WorkPermissionRule[];
}

export interface Profile {
  id: string;
  fullName: string;
  useUniformDailyTarget: boolean;
  dailyTargetMinutes: number;
  weekdayTargetMinutes: WeekdayTargetMinutes;
  weekdaySchedule: WeekdaySchedule;
  workRules: UserWorkRules;
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
  rawBalanceMinutes: number;
  balanceMinutes: number;
  remainingCreditMinutes: number;
  remainingDebitMinutes: number;
}
