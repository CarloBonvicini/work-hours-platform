import { isValidEmail } from "./auth.js";

type ParseFailure = { value: null; error: string };
type ParseSuccess<T> = { value: T };
type ParseResult<T> = ParseFailure | ParseSuccess<T>;

function hasParseError<T>(result: ParseResult<T>): result is ParseFailure {
  return result.value === null;
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

function normalizeRecoveryCode(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function normalizeText(value: string) {
  return value.trim().replace(/\s+/g, " ");
}

function invalidBody(): ParseFailure {
  return { value: null, error: "Invalid body" };
}

function getPayloadBody(payload: unknown): ParseResult<Record<string, unknown>> {
  if (!payload || typeof payload !== "object") {
    return invalidBody();
  }
  return { value: payload as Record<string, unknown> };
}

function parseRequiredEmail(body: Record<string, unknown>): ParseResult<string> {
  const email = typeof body.email === "string" ? normalizeEmail(body.email) : null;
  if (!email || !isValidEmail(email)) {
    return { value: null, error: "email must be valid" };
  }
  return { value: email };
}

function parseRequiredPassword(
  body: Record<string, unknown>,
  field: "password" | "newPassword"
): ParseResult<string> {
  const value = typeof body[field] === "string" ? body[field] : null;
  if (!value || value.trim().length === 0) {
    return { value: null, error: `${field} is required` };
  }
  return { value };
}

function parseCreateRole(body: Record<string, unknown>): ParseResult<"user" | "admin"> {
  if (typeof body.role === "string") {
    const normalizedRole = body.role.trim().toLowerCase();
    if (normalizedRole === "user" || normalizedRole === "admin") {
      return { value: normalizedRole };
    }

    return { value: null, error: "role must be one of: user, admin" };
  }

  if (typeof body.isAdmin === "boolean") {
    return { value: body.isAdmin ? "admin" : "user" };
  }

  return { value: "user" };
}

function parseOptionalEmail(body: Record<string, unknown>): ParseResult<string | undefined> {
  if (body.email === undefined) {
    return { value: undefined };
  }

  if (typeof body.email !== "string") {
    return { value: null, error: "email must be valid" };
  }

  const normalizedEmail = normalizeEmail(body.email);
  if (!isValidEmail(normalizedEmail)) {
    return { value: null, error: "email must be valid" };
  }

  return { value: normalizedEmail };
}

function parseOptionalRole(body: Record<string, unknown>): ParseResult<"user" | "admin" | undefined> {
  if (body.role === undefined) {
    return { value: undefined };
  }

  if (typeof body.role !== "string") {
    return { value: null, error: "role must be one of: user, admin" };
  }

  const normalizedRole = body.role.trim().toLowerCase();
  if (normalizedRole !== "user" && normalizedRole !== "admin") {
    return { value: null, error: "role must be one of: user, admin" };
  }

  return { value: normalizedRole };
}

function parseRoleFromIsAdmin(body: Record<string, unknown>): ParseResult<"user" | "admin" | undefined> {
  if (body.isAdmin === undefined) {
    return { value: undefined };
  }

  if (typeof body.isAdmin !== "boolean") {
    return { value: null, error: "isAdmin must be boolean" };
  }

  return { value: body.isAdmin ? "admin" : "user" };
}

function parseRecoveryCode(body: Record<string, unknown>): ParseResult<string> {
  const recoveryCode =
    typeof body.recoveryCode === "string"
      ? normalizeRecoveryCode(body.recoveryCode)
      : null;
  if (!recoveryCode || recoveryCode.length < 8) {
    return { value: null, error: "recoveryCode must be valid" };
  }

  return { value: recoveryCode };
}

function parseBoundedNormalizedText(
  body: Record<string, unknown>,
  field: string,
  minLength: number,
  maxLength: number
): ParseResult<string> {
  const rawValue = body[field];
  const value = typeof rawValue === "string" ? normalizeText(rawValue) : null;
  if (!value || value.length < minLength || value.length > maxLength) {
    return {
      value: null,
      error: `${field} must be between ${minLength} and ${maxLength} characters`
    };
  }

  return { value };
}

function parseRequiredQuestion(
  body: Record<string, unknown>,
  field: "questionOne" | "questionTwo"
): ParseResult<string> {
  return parseBoundedNormalizedText(body, field, 8, 140);
}

function parseRequiredAnswer(
  body: Record<string, unknown>,
  field: "answerOne" | "answerTwo"
): ParseResult<string> {
  return parseBoundedNormalizedText(body, field, 2, 120);
}

function parsePasswordRecoveryByCode(
  body: Record<string, unknown>,
  email: string,
  newPassword: string
) {
  const recoveryCodeResult = parseRecoveryCode(body);
  if (hasParseError(recoveryCodeResult)) {
    return recoveryCodeResult;
  }

  return {
    value: {
      email,
      mode: "code" as const,
      recoveryCode: recoveryCodeResult.value,
      newPassword
    }
  };
}

function parsePasswordRecoveryByQuestions(
  body: Record<string, unknown>,
  email: string,
  newPassword: string
) {
  const answerOneResult = parseRequiredAnswer(body, "answerOne");
  if (hasParseError(answerOneResult)) {
    return answerOneResult;
  }

  const answerTwoResult = parseRequiredAnswer(body, "answerTwo");
  if (hasParseError(answerTwoResult)) {
    return answerTwoResult;
  }

  return {
    value: {
      email,
      mode: "questions" as const,
      answerOne: answerOneResult.value,
      answerTwo: answerTwoResult.value,
      newPassword
    }
  };
}

function ensureHasAdminUpdateFields(body: Record<string, unknown>): ParseFailure | null {
  if (
    body.email === undefined &&
    body.role === undefined &&
    body.isAdmin === undefined
  ) {
    return {
      value: null,
      error: "At least one field is required: email, role, isAdmin"
    };
  }

  return null;
}

function resolveUpdatedRole(
  body: Record<string, unknown>
): ParseResult<"user" | "admin" | undefined> {
  const roleResult = parseOptionalRole(body);
  if (hasParseError(roleResult)) {
    return roleResult;
  }

  const roleFromIsAdminResult = parseRoleFromIsAdmin(body);
  if (hasParseError(roleFromIsAdminResult)) {
    return roleFromIsAdminResult;
  }

  if (
    roleResult.value &&
    roleFromIsAdminResult.value &&
    roleResult.value !== roleFromIsAdminResult.value
  ) {
    return { value: null, error: "role and isAdmin are inconsistent" };
  }

  return { value: roleFromIsAdminResult.value ?? roleResult.value };
}

export function parseAdminRolePayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const body = bodyResult.value;
  if (typeof body.isAdmin !== "boolean") {
    return { value: null, error: "isAdmin must be boolean" as const };
  }

  return { value: { isAdmin: body.isAdmin } };
}

export function parseAdminPasswordPayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const passwordResult = parseRequiredPassword(bodyResult.value, "newPassword");
  if (hasParseError(passwordResult)) {
    return passwordResult;
  }

  return { value: { newPassword: passwordResult.value } };
}

export function parseAdminUserCreatePayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }
  const body = bodyResult.value;

  const emailResult = parseRequiredEmail(body);
  if (hasParseError(emailResult)) {
    return emailResult;
  }

  const passwordResult = parseRequiredPassword(body, "password");
  if (hasParseError(passwordResult)) {
    return passwordResult;
  }

  const roleResult = parseCreateRole(body);
  if (hasParseError(roleResult)) {
    return roleResult;
  }

  return {
    value: {
      email: emailResult.value,
      password: passwordResult.value,
      role: roleResult.value
    }
  };
}

export function parseAdminUserUpdatePayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }
  const body = bodyResult.value;

  const missingFieldsError = ensureHasAdminUpdateFields(body);
  if (missingFieldsError) {
    return missingFieldsError;
  }

  const emailResult = parseOptionalEmail(body);
  if (hasParseError(emailResult)) {
    return emailResult;
  }

  const roleResult = resolveUpdatedRole(body);
  if (hasParseError(roleResult)) {
    return roleResult;
  }

  return {
    value: {
      email: emailResult.value,
      role: roleResult.value
    }
  };
}

export function parseAuthCredentials(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const emailResult = parseRequiredEmail(bodyResult.value);
  if (hasParseError(emailResult)) {
    return emailResult;
  }

  const passwordResult = parseRequiredPassword(bodyResult.value, "password");
  if (hasParseError(passwordResult)) {
    return passwordResult;
  }

  return {
    value: {
      email: emailResult.value,
      password: passwordResult.value
    }
  };
}

export function parsePasswordRecoveryPayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const body = bodyResult.value;
  const emailResult = parseRequiredEmail(body);
  if (hasParseError(emailResult)) {
    return emailResult;
  }

  const newPasswordResult = parseRequiredPassword(body, "newPassword");
  if (hasParseError(newPasswordResult)) {
    return newPasswordResult;
  }

  if (typeof body.recoveryCode === "string" && body.recoveryCode.trim().length > 0) {
    return parsePasswordRecoveryByCode(
      body,
      emailResult.value,
      newPasswordResult.value
    );
  }

  return parsePasswordRecoveryByQuestions(
    body,
    emailResult.value,
    newPasswordResult.value
  );
}

export function parseRecoveryQuestionLookupPayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const emailResult = parseRequiredEmail(bodyResult.value);
  if (hasParseError(emailResult)) {
    return emailResult;
  }

  return {
    value: {
      email: emailResult.value
    }
  };
}

export function parseRecoveryQuestionSetupPayload(payload: unknown) {
  const bodyResult = getPayloadBody(payload);
  if (hasParseError(bodyResult)) {
    return bodyResult;
  }

  const body = bodyResult.value;
  const questionOneResult = parseRequiredQuestion(body, "questionOne");
  if (hasParseError(questionOneResult)) {
    return questionOneResult;
  }

  const questionTwoResult = parseRequiredQuestion(body, "questionTwo");
  if (hasParseError(questionTwoResult)) {
    return questionTwoResult;
  }

  if (questionOneResult.value.toLowerCase() === questionTwoResult.value.toLowerCase()) {
    return {
      value: null,
      error: "questionTwo must be different from questionOne"
    };
  }

  const answerOneResult = parseRequiredAnswer(body, "answerOne");
  if (hasParseError(answerOneResult)) {
    return answerOneResult;
  }

  const answerTwoResult = parseRequiredAnswer(body, "answerTwo");
  if (hasParseError(answerTwoResult)) {
    return answerTwoResult;
  }

  return {
    value: {
      questionOne: questionOneResult.value,
      questionTwo: questionTwoResult.value,
      answerOne: answerOneResult.value,
      answerTwo: answerTwoResult.value
    }
  };
}
