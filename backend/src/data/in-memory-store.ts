import type {
  LeaveEntry,
  Profile,
  ScheduleOverride,
  WorkEntry
} from "../domain/types.js";
import type {
  AppStore,
  AuthUser,
  CloudBackupRecord,
  StoredAuthUser
} from "./store.js";
import {
  buildDefaultWorkRules,
  buildUniformWeekdaySchedule,
  buildUniformWeekdayTargetMinutes
} from "../domain/monthly-summary.js";

const DEFAULT_WEEKDAY_SCHEDULE = buildUniformWeekdaySchedule(480);
const DEFAULT_PROFILE: Profile = {
  id: "default-profile",
  fullName: "Utente",
  useUniformDailyTarget: true,
  dailyTargetMinutes: 480,
  weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(480),
  weekdaySchedule: DEFAULT_WEEKDAY_SCHEDULE,
  workRules: buildDefaultWorkRules({
    dailyTargetMinutes: 480,
    weekdaySchedule: DEFAULT_WEEKDAY_SCHEDULE
  })
};

export class InMemoryStore implements AppStore {
  private profile: Profile = {
    ...DEFAULT_PROFILE,
    weekdayTargetMinutes: { ...DEFAULT_PROFILE.weekdayTargetMinutes },
    weekdaySchedule: structuredClone(DEFAULT_PROFILE.weekdaySchedule),
    workRules: { ...DEFAULT_PROFILE.workRules }
  };
  private workEntries: WorkEntry[] = [];
  private leaveEntries: LeaveEntry[] = [];
  private scheduleOverrides: ScheduleOverride[] = [];
  private authUsers: StoredAuthUser[] = [];
  private sessionsByTokenHash = new Map<string, string>();
  private cloudBackupsByUserId = new Map<string, CloudBackupRecord>();

  getProfile(): Profile {
    return {
      ...this.profile,
      weekdayTargetMinutes: { ...this.profile.weekdayTargetMinutes },
      weekdaySchedule: structuredClone(this.profile.weekdaySchedule),
      workRules: { ...this.profile.workRules }
    };
  }

  saveProfile(profile: Profile): Profile {
    this.profile = {
      ...profile,
      weekdayTargetMinutes: { ...profile.weekdayTargetMinutes },
      weekdaySchedule: structuredClone(profile.weekdaySchedule),
      workRules: { ...profile.workRules }
    };
    return this.getProfile();
  }

  addWorkEntry(entry: WorkEntry): WorkEntry {
    const saved = { ...entry };
    this.workEntries.push(saved);
    return saved;
  }

  listWorkEntries(month?: string): WorkEntry[] {
    const filtered = month
      ? this.workEntries.filter((entry) => entry.date.startsWith(month))
      : this.workEntries;

    return filtered
      .map((entry) => ({ ...entry }))
      .sort((left, right) => left.date.localeCompare(right.date));
  }

  addLeaveEntry(entry: LeaveEntry): LeaveEntry {
    const saved = { ...entry };
    this.leaveEntries.push(saved);
    return saved;
  }

  listLeaveEntries(month?: string): LeaveEntry[] {
    const filtered = month
      ? this.leaveEntries.filter((entry) => entry.date.startsWith(month))
      : this.leaveEntries;

    return filtered
      .map((entry) => ({ ...entry }))
      .sort((left, right) => left.date.localeCompare(right.date));
  }

  saveScheduleOverride(entry: ScheduleOverride): ScheduleOverride {
    const saved = { ...entry };
    this.scheduleOverrides = this.scheduleOverrides.filter(
      (item) => item.date !== saved.date
    );
    this.scheduleOverrides.push(saved);
    return { ...saved };
  }

  listScheduleOverrides(month?: string): ScheduleOverride[] {
    const filtered = month
      ? this.scheduleOverrides.filter((entry) => entry.date.startsWith(month))
      : this.scheduleOverrides;

    return filtered
      .map((entry) => ({ ...entry }))
      .sort((left, right) => left.date.localeCompare(right.date));
  }

  removeScheduleOverride(date: string): boolean {
    const previousLength = this.scheduleOverrides.length;
    this.scheduleOverrides = this.scheduleOverrides.filter(
      (entry) => entry.date !== date
    );
    return this.scheduleOverrides.length < previousLength;
  }

  findAuthUserByEmail(email: string): StoredAuthUser | null {
    const normalizedEmail = email.trim().toLowerCase();
    const user = this.authUsers.find((entry) => entry.email === normalizedEmail);
    return user ? { ...user } : null;
  }

  createAuthUser(user: StoredAuthUser): AuthUser {
    this.authUsers.push({ ...user });
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  listAuthUsers(): AuthUser[] {
    return this.authUsers
      .map((user) => ({
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }))
      .sort((left, right) => left.email.localeCompare(right.email));
  }

  updateAuthUserRole(userId: string, role: StoredAuthUser["role"]): AuthUser | null {
    const user = this.authUsers.find((entry) => entry.id === userId);
    if (!user) {
      return null;
    }

    user.role = role;
    user.updatedAt = new Date().toISOString();
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  updateStoredAuthUser(user: StoredAuthUser): AuthUser | null {
    const index = this.authUsers.findIndex((entry) => entry.id === user.id);
    if (index === -1) {
      return null;
    }

    this.authUsers[index] = { ...user };
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  findAuthUserByTokenHash(tokenHash: string): AuthUser | null {
    const userId = this.sessionsByTokenHash.get(tokenHash);
    if (!userId) {
      return null;
    }

    const user = this.authUsers.find((entry) => entry.id === userId);
    if (!user) {
      return null;
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  saveAuthSession(options: {
    tokenHash: string;
    userId: string;
    createdAt: string;
    updatedAt: string;
  }): void {
    this.sessionsByTokenHash.set(options.tokenHash, options.userId);
  }

  deleteAuthSession(tokenHash: string): void {
    this.sessionsByTokenHash.delete(tokenHash);
  }

  loadCloudBackup(userId: string): CloudBackupRecord | null {
    const record = this.cloudBackupsByUserId.get(userId);
    return record ? structuredClone(record) : null;
  }

  saveCloudBackup(userId: string, record: CloudBackupRecord): CloudBackupRecord {
    const nextRecord = structuredClone(record);
    this.cloudBackupsByUserId.set(userId, nextRecord);
    return structuredClone(nextRecord);
  }
}
