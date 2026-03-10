import { Pool } from "pg";
import type {
  LeaveEntry,
  LeaveType,
  Profile,
  WorkEntry
} from "../domain/types.js";
import type { AppStore } from "./store.js";

interface PostgresStoreOptions {
  connectionString: string;
}

type ProfileRow = {
  id: string;
  full_name: string;
  daily_target_minutes: number;
};

type WorkEntryRow = {
  id: string;
  date: string;
  minutes: number;
  note: string | null;
};

type LeaveEntryRow = {
  id: string;
  date: string;
  minutes: number;
  type: LeaveType;
  note: string | null;
};

const DEFAULT_PROFILE: Profile = {
  id: "default-profile",
  fullName: "Utente",
  dailyTargetMinutes: 480
};

function monthRange(month: string): { start: string; end: string } {
  const [yearPart, monthPart] = month.split("-");
  const year = Number(yearPart);
  const monthNumber = Number(monthPart);

  const startDate = new Date(Date.UTC(year, monthNumber - 1, 1));
  const endDate = new Date(Date.UTC(year, monthNumber, 1));

  return {
    start: startDate.toISOString().slice(0, 10),
    end: endDate.toISOString().slice(0, 10)
  };
}

export class PostgresStore implements AppStore {
  private constructor(private readonly pool: Pool) {}

  static async create(options: PostgresStoreOptions): Promise<PostgresStore> {
    if (!options.connectionString || options.connectionString.trim().length === 0) {
      throw new Error("DATABASE_URL is required when DATA_PROVIDER=postgres");
    }

    const pool = new Pool({
      connectionString: options.connectionString
    });

    const store = new PostgresStore(pool);
    await store.ensureSchema();

    return store;
  }

  private async ensureSchema(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS profile (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        daily_target_minutes INTEGER NOT NULL CHECK (daily_target_minutes > 0)
      );

      CREATE TABLE IF NOT EXISTS work_entries (
        id TEXT PRIMARY KEY,
        date DATE NOT NULL,
        minutes INTEGER NOT NULL CHECK (minutes > 0),
        note TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_work_entries_date ON work_entries(date);

      CREATE TABLE IF NOT EXISTS leave_entries (
        id TEXT PRIMARY KEY,
        date DATE NOT NULL,
        minutes INTEGER NOT NULL CHECK (minutes > 0),
        type TEXT NOT NULL CHECK (type IN ('vacation', 'permit')),
        note TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_leave_entries_date ON leave_entries(date);
    `);
  }

  async getProfile(): Promise<Profile> {
    const result = await this.pool.query<ProfileRow>(
      `
        SELECT id, full_name, daily_target_minutes
        FROM profile
        WHERE id = $1
        LIMIT 1
      `,
      [DEFAULT_PROFILE.id]
    );

    if (result.rowCount === 0) {
      return { ...DEFAULT_PROFILE };
    }

    const row = result.rows[0];
    return {
      id: row.id,
      fullName: row.full_name,
      dailyTargetMinutes: row.daily_target_minutes
    };
  }

  async saveProfile(profile: Profile): Promise<Profile> {
    const result = await this.pool.query<ProfileRow>(
      `
        INSERT INTO profile (id, full_name, daily_target_minutes)
        VALUES ($1, $2, $3)
        ON CONFLICT (id)
        DO UPDATE SET
          full_name = EXCLUDED.full_name,
          daily_target_minutes = EXCLUDED.daily_target_minutes
        RETURNING id, full_name, daily_target_minutes
      `,
      [profile.id, profile.fullName, profile.dailyTargetMinutes]
    );

    const row = result.rows[0];
    return {
      id: row.id,
      fullName: row.full_name,
      dailyTargetMinutes: row.daily_target_minutes
    };
  }

  async addWorkEntry(entry: WorkEntry): Promise<WorkEntry> {
    const result = await this.pool.query<WorkEntryRow>(
      `
        INSERT INTO work_entries (id, date, minutes, note)
        VALUES ($1, $2, $3, $4)
        RETURNING id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, note
      `,
      [entry.id, entry.date, entry.minutes, entry.note ?? null]
    );

    const row = result.rows[0];
    return {
      id: row.id,
      date: row.date,
      minutes: row.minutes,
      note: row.note ?? undefined
    };
  }

  async listWorkEntries(month?: string): Promise<WorkEntry[]> {
    const range = month ? monthRange(month) : null;

    const result = range
      ? await this.pool.query<WorkEntryRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, note
            FROM work_entries
            WHERE date >= $1 AND date < $2
            ORDER BY date ASC
          `,
          [range.start, range.end]
        )
      : await this.pool.query<WorkEntryRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, note
            FROM work_entries
            ORDER BY date ASC
          `
        );

    return result.rows.map((row) => ({
      id: row.id,
      date: row.date,
      minutes: row.minutes,
      note: row.note ?? undefined
    }));
  }

  async addLeaveEntry(entry: LeaveEntry): Promise<LeaveEntry> {
    const result = await this.pool.query<LeaveEntryRow>(
      `
        INSERT INTO leave_entries (id, date, minutes, type, note)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, type, note
      `,
      [entry.id, entry.date, entry.minutes, entry.type, entry.note ?? null]
    );

    const row = result.rows[0];
    return {
      id: row.id,
      date: row.date,
      minutes: row.minutes,
      type: row.type,
      note: row.note ?? undefined
    };
  }

  async listLeaveEntries(month?: string): Promise<LeaveEntry[]> {
    const range = month ? monthRange(month) : null;

    const result = range
      ? await this.pool.query<LeaveEntryRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, type, note
            FROM leave_entries
            WHERE date >= $1 AND date < $2
            ORDER BY date ASC
          `,
          [range.start, range.end]
        )
      : await this.pool.query<LeaveEntryRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, minutes, type, note
            FROM leave_entries
            ORDER BY date ASC
          `
        );

    return result.rows.map((row) => ({
      id: row.id,
      date: row.date,
      minutes: row.minutes,
      type: row.type,
      note: row.note ?? undefined
    }));
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
