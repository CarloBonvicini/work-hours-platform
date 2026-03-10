import type {
  LeaveEntry,
  Profile,
  WorkEntry
} from "../domain/types.js";
import type { AppStore } from "./store.js";

const DEFAULT_PROFILE: Profile = {
  id: "default-profile",
  fullName: "Utente",
  dailyTargetMinutes: 480
};

export class InMemoryStore implements AppStore {
  private profile: Profile = { ...DEFAULT_PROFILE };
  private workEntries: WorkEntry[] = [];
  private leaveEntries: LeaveEntry[] = [];

  getProfile(): Profile {
    return { ...this.profile };
  }

  saveProfile(profile: Profile): Profile {
    this.profile = { ...profile };
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
}
