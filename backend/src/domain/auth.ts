import { createHash, randomBytes, randomUUID, scryptSync } from "node:crypto";
import type { AppStore, AuthRole, AuthUser, StoredAuthUser } from "../data/store.js";

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

function normalizeWhitespace(value: string) {
  return value.trim().replace(/\s+/g, " ");
}

function normalizeRecoveryCode(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export const RECOVERY_MAX_ATTEMPTS = 5;
export const RECOVERY_LOCK_WINDOW_MINUTES = 15;

function getLegacyAdminProfileEmails() {
  return new Set(
    (process.env.ADMIN_EMAILS ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value.length > 0)
      .map(normalizeEmail)
  );
}

export function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export function createPasswordDigest(password: string) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return { salt, hash };
}

export function verifyPasswordDigest(password: string, user: StoredAuthUser) {
  const hash = scryptSync(password, user.passwordSalt, 64).toString("hex");
  return hash === user.passwordHash;
}

export function createRecoveryCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let normalized = "";
  for (let index = 0; index < 10; index += 1) {
    const randomIndex = randomBytes(1)[0] % alphabet.length;
    normalized += alphabet[randomIndex];
  }

  return `${normalized.slice(0, 5)}-${normalized.slice(5)}`;
}

export function createRecoveryCodeDigest(recoveryCode: string) {
  return createPasswordDigest(normalizeRecoveryCode(recoveryCode));
}

export function normalizeRecoveryQuestion(value: string) {
  return normalizeWhitespace(value);
}

export function normalizeRecoveryAnswer(value: string) {
  return normalizeWhitespace(value).toLowerCase();
}

export function createRecoveryAnswerDigest(answer: string) {
  return createPasswordDigest(normalizeRecoveryAnswer(answer));
}

export function verifyRecoveryAnswerDigest(options: {
  answer: string;
  hash?: string;
  salt?: string;
}) {
  if (!options.hash || !options.salt) {
    return false;
  }

  const normalizedAnswer = normalizeRecoveryAnswer(options.answer);
  const hash = scryptSync(normalizedAnswer, options.salt, 64).toString("hex");
  return hash === options.hash;
}

export function hasRecoveryQuestionsConfigured(user: StoredAuthUser) {
  return Boolean(
    user.recoveryQuestionOne &&
      user.recoveryQuestionTwo &&
      user.recoveryAnswerOneHash &&
      user.recoveryAnswerOneSalt &&
      user.recoveryAnswerTwoHash &&
      user.recoveryAnswerTwoSalt
  );
}

export function isRecoveryTemporarilyLocked(
  user: StoredAuthUser,
  now = new Date()
) {
  if (!user.recoveryLockedUntil) {
    return false;
  }

  return new Date(user.recoveryLockedUntil).getTime() > now.getTime();
}

export function verifyRecoveryCodeDigest(
  recoveryCode: string,
  user: StoredAuthUser
) {
  if (!user.recoveryCodeHash || !user.recoveryCodeSalt) {
    return false;
  }

  const normalizedCode = normalizeRecoveryCode(recoveryCode);
  const hash = scryptSync(normalizedCode, user.recoveryCodeSalt, 64).toString(
    "hex"
  );
  return hash === user.recoveryCodeHash;
}

export function createSessionToken() {
  return randomBytes(32).toString("hex");
}

export function hashSessionToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export function isLegacyAdminProfileEmail(email: string) {
  return getLegacyAdminProfileEmails().has(normalizeEmail(email));
}

export function isAuthRole(value: unknown): value is AuthRole {
  return value === "user" || value === "admin" || value === "super_admin";
}

export function isAdminRole(role: AuthRole) {
  return role === "admin" || role === "super_admin";
}

export function isSuperAdminRole(role: AuthRole) {
  return role === "super_admin";
}

export function getEffectiveAuthRole(
  user: Pick<AuthUser, "email" | "role">
): AuthRole {
  if (isAuthRole(user.role)) {
    return user.role;
  }

  return isLegacyAdminProfileEmail(user.email) ? "admin" : "user";
}

export function isAdminUser(user: Pick<AuthUser, "email" | "role">) {
  return isAdminRole(getEffectiveAuthRole(user));
}

export function isSuperAdminUser(user: Pick<AuthUser, "email" | "role">) {
  return isSuperAdminRole(getEffectiveAuthRole(user));
}

export function getConfiguredSuperAdminCredentials() {
  const emailValue = process.env.SUPER_ADMIN_EMAIL?.trim();
  const passwordValueRaw = process.env.SUPER_ADMIN_PASSWORD;
  const passwordValue =
    typeof passwordValueRaw === "string" ? passwordValueRaw.trim() : undefined;

  if (!emailValue && (!passwordValue || passwordValue.length === 0)) {
    return null;
  }

  if (!emailValue || !passwordValue) {
    throw new Error(
      "SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD must both be configured"
    );
  }

  const email = normalizeEmail(emailValue);
  if (!isValidEmail(email)) {
    throw new Error("SUPER_ADMIN_EMAIL is not a valid email");
  }

  return {
    email,
    password: passwordValue
  };
}

export function serializeAuthUser(
  user: Pick<AuthUser, "id" | "email" | "role" | "createdAt" | "updatedAt">
) {
  const role = getEffectiveAuthRole(user);
  return {
    id: user.id,
    email: user.email,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
    role,
    isAdmin: isAdminRole(role),
    isSuperAdmin: isSuperAdminRole(role)
  };
}

async function demoteOtherSuperAdmins(store: AppStore, primaryEmail: string) {
  const users = await store.listAuthUsers();
  for (const user of users) {
    if (user.email === primaryEmail) {
      continue;
    }

    if (getEffectiveAuthRole(user) !== "super_admin") {
      continue;
    }

    await store.updateAuthUserRole(user.id, "admin");
  }
}

async function createSuperAdminUser(
  store: AppStore,
  email: string,
  password: string,
  now: string
) {
  const passwordDigest = createPasswordDigest(password);
  await store.createAuthUser({
    id: randomUUID(),
    email,
    passwordHash: passwordDigest.hash,
    passwordSalt: passwordDigest.salt,
    recoveryFailedAttempts: 0,
    role: "super_admin",
    createdAt: now,
    updatedAt: now
  });
}

async function refreshStoredSuperAdmin(
  store: AppStore,
  existingUser: StoredAuthUser,
  password: string,
  now: string
) {
  const needsPasswordRefresh = !verifyPasswordDigest(password, existingUser);
  if (!needsPasswordRefresh && getEffectiveAuthRole(existingUser) === "super_admin") {
    return;
  }

  const passwordDigest = needsPasswordRefresh
    ? createPasswordDigest(password)
    : null;

  await store.updateStoredAuthUser({
    ...existingUser,
    passwordHash: passwordDigest?.hash ?? existingUser.passwordHash,
    passwordSalt: passwordDigest?.salt ?? existingUser.passwordSalt,
    recoveryFailedAttempts: existingUser.recoveryFailedAttempts ?? 0,
    role: "super_admin",
    updatedAt: now
  });
}

export async function syncConfiguredSuperAdmin(store: AppStore) {
  const configuredSuperAdmin = getConfiguredSuperAdminCredentials();
  if (!configuredSuperAdmin) {
    return;
  }

  const now = new Date().toISOString();
  await demoteOtherSuperAdmins(store, configuredSuperAdmin.email);

  const existingUser = await store.findAuthUserByEmail(configuredSuperAdmin.email);
  if (!existingUser) {
    await createSuperAdminUser(
      store,
      configuredSuperAdmin.email,
      configuredSuperAdmin.password,
      now
    );
    return;
  }

  await refreshStoredSuperAdmin(
    store,
    existingUser,
    configuredSuperAdmin.password,
    now
  );
}
