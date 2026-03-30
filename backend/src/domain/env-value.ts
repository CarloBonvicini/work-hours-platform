function unwrapQuotedValue(value: string) {
  let normalizedValue = value;

  // Keep unwrapping for common cases like "\"token\"" or "'\"token\"'".
  for (let index = 0; index < 4; index += 1) {
    const hasSingleQuotes =
      normalizedValue.startsWith("'") && normalizedValue.endsWith("'");
    const hasDoubleQuotes =
      normalizedValue.startsWith("\"") && normalizedValue.endsWith("\"");
    const hasEscapedSingleQuotes =
      normalizedValue.startsWith("\\'") && normalizedValue.endsWith("\\'");
    const hasEscapedDoubleQuotes =
      normalizedValue.startsWith("\\\"") && normalizedValue.endsWith("\\\"");

    if (hasEscapedSingleQuotes || hasEscapedDoubleQuotes) {
      normalizedValue = normalizedValue.slice(2, -2).trim();
      continue;
    }

    if (hasSingleQuotes || hasDoubleQuotes) {
      normalizedValue = normalizedValue.slice(1, -1).trim();
      continue;
    }

    break;
  }

  return normalizedValue;
}

export function normalizeRuntimeEnvValue(value: string | undefined | null) {
  if (typeof value !== "string") {
    return undefined;
  }

  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return undefined;
  }

  const normalizedValue = unwrapQuotedValue(trimmedValue);
  return normalizedValue.length > 0 ? normalizedValue : undefined;
}
