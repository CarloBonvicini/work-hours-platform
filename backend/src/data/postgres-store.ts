import { Pool } from "pg";
import type {
  AppearanceSettingsRecord,
  AuthRole,
  AuthUser,
  CloudBackupRecord,
  StoredAuthUser,
} from "./store.js";
import type {
  DaySchedule,
  LeaveEntry,
  LeaveType,
  Profile,
  ScheduleOverride,
  UserWorkRules,
  WeekdaySchedule,
  WeekdayTargetMinutes,
  WorkEntry
} from "../domain/types.js";
import {
  buildDefaultWorkRules,
  buildUniformWeekdaySchedule,
  buildUniformWeekdayTargetMinutes,
  sanitizeWorkRules,
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
  work_rules: UserWorkRules | null;
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

type AuthUserRow = {
  id: string;
  email: string;
  role: AuthRole;
  password_hash: string;
  password_salt: string;
  created_at: string;
  updated_at: string;
};

type AuthSessionUserRow = {
  id: string;
  email: string;
  role: AuthRole;
  created_at: string;
  updated_at: string;
};

type CloudBackupRow = {
  user_id: string;
  payload: CloudBackupRecord;
  updated_at: string;
};

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

function toAuthUser(row: {
  id: string;
  email: string;
  role: AuthRole;
  created_at: string;
  updated_at: string;
}): AuthUser {
  return {
    id: row.id,
    email: row.email,
    role: row.role,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function sanitizeAppearanceSettings(
  value: AppearanceSettingsRecord
): AppearanceSettingsRecord {
  return {
    themeMode:
      value.themeMode === "dark" || value.themeMode === "system"
        ? value.themeMode
        : "light",
    primaryColor: value.primaryColor,
    secondaryColor: value.secondaryColor,
    textColor: value.textColor,
    fontFamily: value.fontFamily,
    textScale: value.textScale
  };
}

function sanitizeCloudBackupRecord(value: CloudBackupRecord): CloudBackupRecord {
  const weekdayTargetMinutes = sanitizeWeekdayTargetMinutes(
    value.profile.weekdayTargetMinutes,
    value.profile.dailyTargetMinutes
  );
  const weekdaySchedule = sanitizeWeekdaySchedule(
    value.profile.weekdaySchedule,
    weekdayTargetMinutes
  );
  const workRules = sanitizeWorkRules(value.profile.workRules, {
    dailyTargetMinutes: value.profile.dailyTargetMinutes,
    weekdaySchedule
  });

  return {
    profile: {
      ...value.profile,
      weekdayTargetMinutes,
      weekdaySchedule,
      workRules
    },
    appearanceSettings: sanitizeAppearanceSettings(value.appearanceSettings),
    workEntries: value.workEntries.map((entry) => ({ ...entry })),
    leaveEntries: value.leaveEntries.map((entry) => ({ ...entry })),
    scheduleOverrides: value.scheduleOverrides.map((entry) => ({ ...entry })),
    updatedAt: value.updatedAt
  };
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
        ADD COLUMN IF NOT EXISTS weekday_schedule JSONB,
        ADD COLUMN IF NOT EXISTS work_rules JSONB;

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

      CREATE TABLE IF NOT EXISTS auth_users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        is_admin BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      ALTER TABLE auth_users
        ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user',
        ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

      UPDATE auth_users
      SET role = CASE WHEN is_admin THEN 'admin' ELSE 'user' END
      WHERE
        role IS NULL
        OR role NOT IN ('user', 'admin', 'super_admin')
        OR (role = 'user' AND is_admin = TRUE);

      UPDATE auth_users
      SET is_admin = CASE WHEN role IN ('admin', 'super_admin') THEN TRUE ELSE FALSE END
      WHERE is_admin IS DISTINCT FROM CASE WHEN role IN ('admin', 'super_admin') THEN TRUE ELSE FALSE END;

      CREATE TABLE IF NOT EXISTS auth_sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id);

      CREATE TABLE IF NOT EXISTS cloud_backups (
        user_id TEXT PRIMARY KEY REFERENCES auth_users(id) ON DELETE CASCADE,
        payload JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );
    `);
  }

  async getProfile(): Promise<Profile> {
    const result = await this.pool.query<ProfileRow>(
      `
        SELECT id, full_name, daily_target_minutes, use_uniform_daily_target, weekday_target_minutes
        , weekday_schedule, work_rules
        FROM profile
        WHERE id = $1
        LIMIT 1
      `,
      [DEFAULT_PROFILE.id]
    );

    if (result.rowCount === 0) {
      return {
        ...DEFAULT_PROFILE,
        weekdayTargetMinutes: { ...DEFAULT_PROFILE.weekdayTargetMinutes },
        weekdaySchedule: structuredClone(DEFAULT_PROFILE.weekdaySchedule),
        workRules: { ...DEFAULT_PROFILE.workRules }
      };
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
    const workRules = sanitizeWorkRules(row.work_rules, {
      dailyTargetMinutes: row.daily_target_minutes,
      weekdaySchedule
    });

    return {
      id: row.id,
      fullName: row.full_name,
      useUniformDailyTarget: row.use_uniform_daily_target,
      dailyTargetMinutes: row.daily_target_minutes,
      weekdayTargetMinutes,
      weekdaySchedule,
      workRules
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
    const workRules = sanitizeWorkRules(profile.workRules, {
      dailyTargetMinutes: profile.dailyTargetMinutes,
      weekdaySchedule
    });
    const result = await this.pool.query<ProfileRow>(
      `
        INSERT INTO profile (
          id,
          full_name,
          daily_target_minutes,
          use_uniform_daily_target,
          weekday_target_minutes,
          weekday_schedule,
          work_rules
        )
        VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb)
        ON CONFLICT (id)
        DO UPDATE SET
          full_name = EXCLUDED.full_name,
          daily_target_minutes = EXCLUDED.daily_target_minutes,
          use_uniform_daily_target = EXCLUDED.use_uniform_daily_target,
          weekday_target_minutes = EXCLUDED.weekday_target_minutes,
          weekday_schedule = EXCLUDED.weekday_schedule,
          work_rules = EXCLUDED.work_rules
        RETURNING
          id,
          full_name,
          daily_target_minutes,
          use_uniform_daily_target,
          weekday_target_minutes,
          weekday_schedule,
          work_rules
      `,
      [
        profile.id,
        profile.fullName,
        profile.dailyTargetMinutes,
        profile.useUniformDailyTarget,
        JSON.stringify(weekdayTargetMinutes),
        JSON.stringify(weekdaySchedule),
        JSON.stringify(workRules)
      ]
    );

    const row = result.rows[0];
    const savedWeekdayTargetMinutes = sanitizeWeekdayTargetMinutes(
      row.weekday_target_minutes,
      row.daily_target_minutes
    );
    const savedWeekdaySchedule = sanitizeWeekdaySchedule(
      row.weekday_schedule,
      savedWeekdayTargetMinutes
    );
    return {
      id: row.id,
      fullName: row.full_name,
      useUniformDailyTarget: row.use_uniform_daily_target,
      dailyTargetMinutes: row.daily_target_minutes,
      weekdayTargetMinutes: savedWeekdayTargetMinutes,
      weekdaySchedule: savedWeekdaySchedule,
      workRules: sanitizeWorkRules(row.work_rules, {
        dailyTargetMinutes: row.daily_target_minutes,
        weekdaySchedule: savedWeekdaySchedule
      })
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

  async findAuthUserByEmail(email: string): Promise<StoredAuthUser | null> {
    const result = await this.pool.query<AuthUserRow>(
      `
        SELECT
          id,
          email,
          role,
          password_hash,
          password_salt,
          TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
        FROM auth_users
        WHERE email = $1
        LIMIT 1
      `,
      [email.trim().toLowerCase()]
    );

    if (result.rowCount === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      id: row.id,
      email: row.email,
      role: row.role,
      passwordHash: row.password_hash,
      passwordSalt: row.password_salt,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  async createAuthUser(user: StoredAuthUser): Promise<AuthUser> {
    const result = await this.pool.query<AuthSessionUserRow>(
      `
        INSERT INTO auth_users (
          id,
          email,
          password_hash,
          password_salt,
          role,
          is_admin,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7::timestamptz, $8::timestamptz)
        RETURNING
          id,
          email,
          role,
          TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
      `,
      [
        user.id,
        user.email.trim().toLowerCase(),
        user.passwordHash,
        user.passwordSalt,
        user.role,
        user.role !== "user",
        user.createdAt,
        user.updatedAt
      ]
    );

    return toAuthUser(result.rows[0]);
  }

  async listAuthUsers(): Promise<AuthUser[]> {
    const result = await this.pool.query<AuthSessionUserRow>(
      `
        SELECT
          id,
          email,
          role,
          TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
        FROM auth_users
        ORDER BY email ASC
      `
    );

    return result.rows.map(toAuthUser);
  }

  async updateAuthUserRole(
    userId: string,
    role: AuthRole
  ): Promise<AuthUser | null> {
    const result = await this.pool.query<AuthSessionUserRow>(
      `
        UPDATE auth_users
        SET
          role = $2,
          is_admin = CASE WHEN $2 IN ('admin', 'super_admin') THEN TRUE ELSE FALSE END,
          updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          email,
          role,
          TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
      `,
      [userId, role]
    );

    if (result.rowCount === 0) {
      return null;
    }

    return toAuthUser(result.rows[0]);
  }

  async updateStoredAuthUser(user: StoredAuthUser): Promise<AuthUser | null> {
    const result = await this.pool.query<AuthSessionUserRow>(
      `
        UPDATE auth_users
        SET
          email = $2,
          password_hash = $3,
          password_salt = $4,
          role = $5,
          is_admin = CASE WHEN $5 IN ('admin', 'super_admin') THEN TRUE ELSE FALSE END,
          updated_at = $6::timestamptz
        WHERE id = $1
        RETURNING
          id,
          email,
          role,
          TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
      `,
      [
        user.id,
        user.email.trim().toLowerCase(),
        user.passwordHash,
        user.passwordSalt,
        user.role,
        user.updatedAt
      ]
    );

    if (result.rowCount === 0) {
      return null;
    }

    return toAuthUser(result.rows[0]);
  }

  async findAuthUserByTokenHash(tokenHash: string): Promise<AuthUser | null> {
    const result = await this.pool.query<AuthSessionUserRow>(
      `
        SELECT
          auth_users.id,
          auth_users.email,
          auth_users.role,
          TO_CHAR(auth_users.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS created_at,
          TO_CHAR(auth_users.updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
        FROM auth_sessions
        INNER JOIN auth_users ON auth_users.id = auth_sessions.user_id
        WHERE auth_sessions.token_hash = $1
        LIMIT 1
      `,
      [tokenHash]
    );

    if (result.rowCount === 0) {
      return null;
    }

    return toAuthUser(result.rows[0]);
  }

  async saveAuthSession(options: {
    tokenHash: string;
    userId: string;
    createdAt: string;
    updatedAt: string;
  }): Promise<void> {
    await this.pool.query(
      `
        INSERT INTO auth_sessions (token_hash, user_id, created_at, updated_at)
        VALUES ($1, $2, $3::timestamptz, $4::timestamptz)
        ON CONFLICT (token_hash)
        DO UPDATE SET
          user_id = EXCLUDED.user_id,
          updated_at = EXCLUDED.updated_at
      `,
      [options.tokenHash, options.userId, options.createdAt, options.updatedAt]
    );
  }

  async deleteAuthSession(tokenHash: string): Promise<void> {
    await this.pool.query(
      `
        DELETE FROM auth_sessions
        WHERE token_hash = $1
      `,
      [tokenHash]
    );
  }

  async loadCloudBackup(userId: string): Promise<CloudBackupRecord | null> {
    const result = await this.pool.query<CloudBackupRow>(
      `
        SELECT
          user_id,
          payload,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
        FROM cloud_backups
        WHERE user_id = $1
        LIMIT 1
      `,
      [userId]
    );

    if (result.rowCount === 0) {
      return null;
    }

    return sanitizeCloudBackupRecord({
      ...result.rows[0].payload,
      updatedAt: result.rows[0].updated_at
    } as CloudBackupRecord);
  }

  async saveCloudBackup(
    userId: string,
    record: CloudBackupRecord
  ): Promise<CloudBackupRecord> {
    const sanitized = sanitizeCloudBackupRecord(record);
    const result = await this.pool.query<CloudBackupRow>(
      `
        INSERT INTO cloud_backups (user_id, payload, updated_at)
        VALUES ($1, $2::jsonb, $3::timestamptz)
        ON CONFLICT (user_id)
        DO UPDATE SET
          payload = EXCLUDED.payload,
          updated_at = EXCLUDED.updated_at
        RETURNING
          user_id,
          payload,
          TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS updated_at
      `,
      [userId, JSON.stringify(sanitized), sanitized.updatedAt]
    );

    return sanitizeCloudBackupRecord({
      ...result.rows[0].payload,
      updatedAt: result.rows[0].updated_at
    } as CloudBackupRecord);
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
