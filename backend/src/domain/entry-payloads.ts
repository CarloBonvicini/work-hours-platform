import { isIsoDate } from "./monthly-summary.js";
import type { LeaveType } from "./types.js";

export interface WorkEntryPayload {
  date: string;
  minutes: number;
  note?: string;
}

export interface LeaveEntryPayload extends WorkEntryPayload {
  type: LeaveType;
}

export type PayloadResult<T> =
  | { value: T; error?: undefined }
  | { value?: undefined; error: string };

export function isPositiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

export function isLeaveType(value: unknown): value is LeaveType {
  return value === "vacation" || value === "permit" || value === "sickness";
}

/** Valida il corpo di una voce di lavoro (creazione o aggiornamento). */
export function parseWorkEntryPayload(payload: unknown): PayloadResult<WorkEntryPayload> {
  if (!payload || typeof payload !== "object") {
    return { error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  if (typeof body.date !== "string" || !isIsoDate(body.date)) {
    return { error: "date must be in YYYY-MM-DD format" };
  }

  if (!isPositiveInteger(body.minutes)) {
    return { error: "minutes must be a positive integer" };
  }

  if (body.note !== undefined && typeof body.note !== "string") {
    return { error: "note must be a string" };
  }

  return {
    value: {
      date: body.date,
      minutes: body.minutes,
      note: typeof body.note === "string" ? body.note : undefined
    }
  };
}

/** Valida il corpo di una causale (creazione o aggiornamento). */
export function parseLeaveEntryPayload(payload: unknown): PayloadResult<LeaveEntryPayload> {
  const base = parseWorkEntryPayload(payload);
  if (base.error !== undefined) {
    return { error: base.error };
  }

  const type = (payload as Record<string, unknown>).type;
  if (!isLeaveType(type)) {
    return { error: "type must be 'vacation', 'permit' or 'sickness'" };
  }

  return { value: { ...base.value, type } };
}
