import type {
  LeaveEntry,
  Profile,
  ScheduleOverride,
  WorkEntry
} from "../domain/types.js";

export interface AppearanceSettingsRecord {
  themeMode: "light" | "dark" | "system";
  primaryColor: number;
  secondaryColor: number;
  textColor?: number;
  fontFamily: string;
  textScale: number;
}

export interface CloudBackupRecord {
  profile: Profile;
  appearanceSettings: AppearanceSettingsRecord;
  workEntries: WorkEntry[];
  leaveEntries: LeaveEntry[];
  scheduleOverrides: ScheduleOverride[];
  updatedAt: string;
}

export interface StoredAuthUser {
  id: string;
  email: string;
  passwordHash: string;
  passwordSalt: string;
  isAdmin: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuthUser {
  id: string;
  email: string;
  isAdmin: boolean;
  createdAt: string;
  updatedAt: string;
}

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
  findAuthUserByEmail(email: string): Promise<StoredAuthUser | null> | StoredAuthUser | null;
  createAuthUser(user: StoredAuthUser): Promise<AuthUser> | AuthUser;
  listAuthUsers(): Promise<AuthUser[]> | AuthUser[];
  updateAuthUserAdminStatus(
    userId: string,
    isAdmin: boolean
  ): Promise<AuthUser | null> | AuthUser | null;
  findAuthUserByTokenHash(
    tokenHash: string
  ): Promise<AuthUser | null> | AuthUser | null;
  saveAuthSession(options: {
    tokenHash: string;
    userId: string;
    createdAt: string;
    updatedAt: string;
  }): Promise<void> | void;
  deleteAuthSession(tokenHash: string): Promise<void> | void;
  loadCloudBackup(
    userId: string
  ): Promise<CloudBackupRecord | null> | CloudBackupRecord | null;
  saveCloudBackup(
    userId: string,
    record: CloudBackupRecord
  ): Promise<CloudBackupRecord> | CloudBackupRecord;
  close?(): Promise<void>;
}
