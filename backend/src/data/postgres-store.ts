import { Pool } from "pg";
import type {
  DaySchedule,
  LeaveEntry,
  LeaveType,
  Profile,
  ScheduleOverride,
  WeekdaySchedule,
  WeekdayTargetMinutes,
  WorkEntry
} from "../domain/types.js";
import {
  buildUniformWeekdaySchedule,
  buildUniformWeekdayTargetMinutes,
  WEEKDAY_KEYS
} from "../domain/monthly-summary.js";
import type { AppStore } from "./store.js";

interface PostgresStoreOptions {
  connectionString: string;
}

type ProfileRow = {
  id: string;
  full_name: string;
  daily_target_minutes: number;
  use_uniform_daily_target: boolean;
  weekday_target_minutes: WeekdayTargetMinutes | null;
  weekday_schedule: WeekdaySchedule | null;
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

type ScheduleOverrideRow = {
  id: string;
  date: string;
  target_minutes: number;
  start_time: string | null;
  end_time: string | null;
  break_minutes: number | null;
  note: string | null;
};

const DEFAULT_PROFILE: Profile = {
  id: "default-profile",
  fullName: "Utente",
  useUniformDailyTarget: true,
  dailyTargetMinutes: 480,
  weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(480),
  weekdaySchedule: buildUniformWeekdaySchedule(480)
};

function sanitizeWeekdayTargetMinutes(
  value: WeekdayTargetMinutes | null | undefined,
  fallbackDailyTargetMinutes: number
): WeekdayTargetMinutes {
  const fallback = buildUniformWeekdayTargetMinutes(fallbackDailyTargetMinutes);
  if (!value || typeof value !== "object") {
    return fallback;
  }

  const sanitized = { ...fallback };
  for (const key of WEEKDAY_KEYS) {
    const minutes = value[key];
    sanitized[key] = Number.isInteger(minutes) && minutes >= 0
      ? minutes
      : fallback[key];
  }

  return sanitized;
}

function sanitizeDaySchedule(
  value: DaySchedule | null | undefined,
  fallbackTargetMinutes: number
): DaySchedule {
  if (!value || typeof value !== "object") {
    return {
      targetMinutes: fallbackTargetMinutes,
      breakMinutes: 0
    };
  }

  return {
    targetMinutes:
      Number.isInteger(value.targetMinutes) && value.targetMinutes >= 0
        ? value.targetMinutes
        : fallbackTargetMinutes,
    startTime: typeof value.startTime === "string" ? value.startTime : undefined,
    endTime: typeof value.endTime === "string" ? value.endTime : undefined,
    breakMinutes:
      Number.isInteger(value.breakMinutes) && value.breakMinutes >= 0
        ? value.breakMinutes
        : 0
  };
}

function sanitizeWeekdaySchedule(
  value: WeekdaySchedule | null | undefined,
  fallbackTargetMinutes: WeekdayTargetMinutes
): WeekdaySchedule {
  const sanitized = {} as WeekdaySchedule;

  for (const key of WEEKDAY_KEYS) {
    sanitized[key] = sanitizeDaySchedule(value?.[key], fallbackTargetMinutes[key]);
  }

  return sanitized;
}

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
        full_name TEXT NOT NULL
      );

      ALTER TABLE profile
        ADD COLUMN IF NOT EXISTS daily_target_minutes INTEGER NOT NULL DEFAULT 480,
        ADD COLUMN IF NOT EXISTS use_uniform_daily_target BOOLEAN NOT NULL DEFAULT TRUE,
        ADD COLUMN IF NOT EXISTS weekday_target_minutes JSONB,
        ADD COLUMN IF NOT EXISTS weekday_schedule JSONB;

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

      CREATE TABLE IF NOT EXISTS schedule_overrides (
        id TEXT PRIMARY KEY,
        date DATE NOT NULL UNIQUE,
        target_minutes INTEGER NOT NULL CHECK (target_minutes >= 0),
        start_time TEXT,
        end_time TEXT,
        break_minutes INTEGER NOT NULL DEFAULT 0,
        note TEXT
      );

      ALTER TABLE schedule_overrides
        ADD COLUMN IF NOT EXISTS start_time TEXT,
        ADD COLUMN IF NOT EXISTS end_time TEXT,
        ADD COLUMN IF NOT EXISTS break_minutes INTEGER NOT NULL DEFAULT 0;

      CREATE INDEX IF NOT EXISTS idx_schedule_overrides_date ON schedule_overrides(date);
    `);
  }

  async getProfile(): Promise<Profile> {
    const result = await this.pool.query<ProfileRow>(
      `
        SELECT id, full_name, daily_target_minutes, use_uniform_daily_target, weekday_target_minutes
        , weekday_schedule
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
    const weekdayTargetMinutes = sanitizeWeekdayTargetMinutes(
      row.weekday_target_minutes,
      row.daily_target_minutes
    );
    const weekdaySchedule = sanitizeWeekdaySchedule(
      row.weekday_schedule,
      weekdayTargetMinutes
    );

    return {
      id: row.id,
      fullName: row.full_name,
      useUniformDailyTarget: row.use_uniform_daily_target,
      dailyTargetMinutes: row.daily_target_minutes,
      weekdayTargetMinutes,
      weekdaySchedule
    };
  }

  async saveProfile(profile: Profile): Promise<Profile> {
    const weekdayTargetMinutes = sanitizeWeekdayTargetMinutes(
      profile.weekdayTargetMinutes,
      profile.dailyTargetMinutes
    );
    const weekdaySchedule = sanitizeWeekdaySchedule(
      profile.weekdaySchedule,
      weekdayTargetMinutes
    );
    const result = await this.pool.query<ProfileRow>(
      `
        INSERT INTO profile (
          id,
          full_name,
          daily_target_minutes,
          use_uniform_daily_target,
          weekday_target_minutes,
          weekday_schedule
        )
        VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb)
        ON CONFLICT (id)
        DO UPDATE SET
          full_name = EXCLUDED.full_name,
          daily_target_minutes = EXCLUDED.daily_target_minutes,
          use_uniform_daily_target = EXCLUDED.use_uniform_daily_target,
          weekday_target_minutes = EXCLUDED.weekday_target_minutes,
          weekday_schedule = EXCLUDED.weekday_schedule
        RETURNING
          id,
          full_name,
          daily_target_minutes,
          use_uniform_daily_target,
          weekday_target_minutes,
          weekday_schedule
      `,
      [
        profile.id,
        profile.fullName,
        profile.dailyTargetMinutes,
        profile.useUniformDailyTarget,
        JSON.stringify(weekdayTargetMinutes),
        JSON.stringify(weekdaySchedule)
      ]
    );

    const row = result.rows[0];
    return {
      id: row.id,
      fullName: row.full_name,
      useUniformDailyTarget: row.use_uniform_daily_target,
      dailyTargetMinutes: row.daily_target_minutes,
      weekdayTargetMinutes: sanitizeWeekdayTargetMinutes(
        row.weekday_target_minutes,
        row.daily_target_minutes
      ),
      weekdaySchedule: sanitizeWeekdaySchedule(
        row.weekday_schedule,
        sanitizeWeekdayTargetMinutes(
          row.weekday_target_minutes,
          row.daily_target_minutes
        )
      )
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

  async saveScheduleOverride(entry: ScheduleOverride): Promise<ScheduleOverride> {
    const result = await this.pool.query<ScheduleOverrideRow>(
      `
        INSERT INTO schedule_overrides (
          id,
          date,
          target_minutes,
          start_time,
          end_time,
          break_minutes,
          note
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (date)
        DO UPDATE SET
          id = EXCLUDED.id,
          target_minutes = EXCLUDED.target_minutes,
          start_time = EXCLUDED.start_time,
          end_time = EXCLUDED.end_time,
          break_minutes = EXCLUDED.break_minutes,
          note = EXCLUDED.note
        RETURNING
          id,
          TO_CHAR(date, 'YYYY-MM-DD') AS date,
          target_minutes,
          start_time,
          end_time,
          break_minutes,
          note
      `,
      [
        entry.id,
        entry.date,
        entry.targetMinutes,
        entry.startTime ?? null,
        entry.endTime ?? null,
        entry.breakMinutes,
        entry.note ?? null
      ]
    );

    const row = result.rows[0];
    return {
      id: row.id,
      date: row.date,
      targetMinutes: row.target_minutes,
      startTime: row.start_time ?? undefined,
      endTime: row.end_time ?? undefined,
      breakMinutes: row.break_minutes ?? 0,
      note: row.note ?? undefined
    };
  }

  async listScheduleOverrides(month?: string): Promise<ScheduleOverride[]> {
    const range = month ? monthRange(month) : null;

    const result = range
      ? await this.pool.query<ScheduleOverrideRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, target_minutes, note
            , start_time, end_time, break_minutes
            FROM schedule_overrides
            WHERE date >= $1 AND date < $2
            ORDER BY date ASC
          `,
          [range.start, range.end]
        )
      : await this.pool.query<ScheduleOverrideRow>(
          `
            SELECT id, TO_CHAR(date, 'YYYY-MM-DD') AS date, target_minutes, note
            , start_time, end_time, break_minutes
            FROM schedule_overrides
            ORDER BY date ASC
          `
        );

    return result.rows.map((row) => ({
      id: row.id,
      date: row.date,
      targetMinutes: row.target_minutes,
      startTime: row.start_time ?? undefined,
      endTime: row.end_time ?? undefined,
      breakMinutes: row.break_minutes ?? 0,
      note: row.note ?? undefined
    }));
  }

  async removeScheduleOverride(date: string): Promise<boolean> {
    const result = await this.pool.query(
      `
        DELETE FROM schedule_overrides
        WHERE date = $1
      `,
      [date]
    );

    return (result.rowCount ?? 0) > 0;
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
