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

export interface MobilePushTokenRecord {
  token: string;
  platform?: string;
  appVersion?: string;
  createdAt: string;
  updatedAt: string;
  lastSeenAt: string;
}

export type AuthRole = "user" | "admin" | "super_admin";

export interface StoredAuthUser {
  id: string;
  email: string;
  passwordHash: string;
  passwordSalt: string;
  recoveryCodeHash?: string;
  recoveryCodeSalt?: string;
  recoveryQuestionOne?: string;
  recoveryQuestionTwo?: string;
  recoveryAnswerOneHash?: string;
  recoveryAnswerOneSalt?: string;
  recoveryAnswerTwoHash?: string;
  recoveryAnswerTwoSalt?: string;
  recoveryFailedAttempts: number;
  recoveryLockedUntil?: string;
  role: AuthRole;
  createdAt: string;
  updatedAt: string;
}

export interface AuthUser {
  id: string;
  email: string;
  role: AuthRole;
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
  updateAuthUserRole(
    userId: string,
    role: AuthRole
  ): Promise<AuthUser | null> | AuthUser | null;
  updateStoredAuthUser(user: StoredAuthUser): Promise<AuthUser | null> | AuthUser | null;
  deleteAuthUser(userId: string): Promise<boolean> | boolean;
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
  saveMobilePushToken(
    record: MobilePushTokenRecord
  ): Promise<MobilePushTokenRecord> | MobilePushTokenRecord;
  listMobilePushTokens(): Promise<MobilePushTokenRecord[]> | MobilePushTokenRecord[];
  deleteMobilePushTokens(tokens: string[]): Promise<number> | number;
  close?(): Promise<void>;
}
