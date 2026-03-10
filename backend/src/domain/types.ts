export type LeaveType = "vacation" | "permit";

export interface Profile {
  id: string;
  fullName: string;
  dailyTargetMinutes: number;
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

export interface MonthlySummary {
  month: string;
  expectedMinutes: number;
  workedMinutes: number;
  leaveMinutes: number;
  balanceMinutes: number;
}
