import { describe, expect, it } from "vitest";
import { normalizeRuntimeEnvValue } from "../src/domain/env-value.js";

describe("normalizeRuntimeEnvValue", () => {
  it("returns undefined for missing or empty values", () => {
    expect(normalizeRuntimeEnvValue(undefined)).toBeUndefined();
    expect(normalizeRuntimeEnvValue(null)).toBeUndefined();
    expect(normalizeRuntimeEnvValue("")).toBeUndefined();
    expect(normalizeRuntimeEnvValue("   ")).toBeUndefined();
  });

  it("trims plain values", () => {
    expect(normalizeRuntimeEnvValue(" value ")).toBe("value");
  });

  it("removes single surrounding quotes", () => {
    expect(normalizeRuntimeEnvValue("'value'")).toBe("value");
    expect(normalizeRuntimeEnvValue(" 'value' ")).toBe("value");
  });

  it("removes double surrounding quotes", () => {
    expect(normalizeRuntimeEnvValue("\"value\"")).toBe("value");
    expect(normalizeRuntimeEnvValue(" \"value\" ")).toBe("value");
  });
});

