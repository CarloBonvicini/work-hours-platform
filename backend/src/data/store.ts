import type {
  LeaveEntry,
  Profile,
  ScheduleOverride,
  WorkEntry
} from "../domain/types.js";

export interface AppStore {
  getProfile(): Promise<Profile> | Profile;
  saveProfile(profile: Profile): Promise<Profile> | Profile;
  addWorkEntry(entry: WorkEntry): Promise<WorkEntry> | WorkEntry;
  listWorkEntries(month?: string): Promise<WorkEntry[]> | WorkEntry[];
  addLeaveEntry(entry: LeaveEntry): Promise<LeaveEntry> | LeaveEntry;
  listLeaveEntries(month?: string): Promise<LeaveEntry[]> | LeaveEntry[];
  saveScheduleOverride(
    entry: ScheduleOverride
  ): Promise<ScheduleOverride> | ScheduleOverride;
  listScheduleOverrides(month?: string): Promise<ScheduleOverride[]> | ScheduleOverride[];
  removeScheduleOverride(date: string): Promise<boolean> | boolean;
  close?(): Promise<void>;
}
