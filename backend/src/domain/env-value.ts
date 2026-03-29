export function normalizeRuntimeEnvValue(value: string | undefined | null) {
  if (typeof value !== "string") {
    return undefined;
  }

  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return undefined;
  }

  const startsWithSingleQuote = trimmedValue.startsWith("'");
  const endsWithSingleQuote = trimmedValue.endsWith("'");
  const startsWithDoubleQuote = trimmedValue.startsWith("\"");
  const endsWithDoubleQuote = trimmedValue.endsWith("\"");

  if (
    (startsWithSingleQuote && endsWithSingleQuote) ||
    (startsWithDoubleQuote && endsWithDoubleQuote)
  ) {
    const unquotedValue = trimmedValue.slice(1, -1).trim();
    return unquotedValue.length > 0 ? unquotedValue : undefined;
  }

  return trimmedValue;
}

