import tsParser from "@typescript-eslint/parser";

const LEGACY_OVERSIZED_FILES = [
  "src/app.ts",
  "src/data/postgres-store.ts",
  "src/domain/monthly-summary.ts"
];

export default [
  {
    ignores: ["dist/**", "node_modules/**"]
  },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parser: tsParser,
      ecmaVersion: "latest",
      sourceType: "module"
    },
    rules: {
      "max-lines": [
        "error",
        {
          max: 400,
          skipBlankLines: true,
          skipComments: true
        }
      ],
      "max-lines-per-function": [
        "error",
        {
          max: 40,
          skipBlankLines: true,
          skipComments: true,
          IIFEs: true
        }
      ],
      complexity: ["error", 10],
      "max-depth": ["error", 4]
    }
  },
  {
    files: LEGACY_OVERSIZED_FILES,
    rules: {
      "max-lines": "off",
      "max-lines-per-function": "off",
      complexity: "off",
      "max-depth": "off"
    }
  }
];
