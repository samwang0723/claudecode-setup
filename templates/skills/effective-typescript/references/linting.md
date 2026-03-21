# TypeScript Linting & Formatting

## ESLint Flat Config (eslint.config.ts)

The industry standard. Used by Vercel, Google, Microsoft, Meta, and most major TS projects.
Since ESLint v9, flat config (`eslint.config.ts`) replaces `.eslintrc.*`.

### Recommended Setup

```bash
pnpm add -D eslint typescript-eslint @eslint/js eslint-plugin-import-x
# Optional but recommended:
pnpm add -D eslint-plugin-react eslint-plugin-react-hooks  # React projects
pnpm add -D eslint-plugin-n                                # Node.js projects
```

### Base Config (eslint.config.ts)

```typescript
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import importX from "eslint-plugin-import-x";

export default tseslint.config(
  // Global ignores
  { ignores: ["dist/", "node_modules/", ".next/", "coverage/"] },

  // Base JS rules
  eslint.configs.recommended,

  // TypeScript strict rules (type-checked)
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,

  // TypeScript parser options
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },

  // Import ordering and validation
  {
    plugins: { "import-x": importX },
    rules: {
      "import-x/order": ["error", {
        groups: ["builtin", "external", "internal", "parent", "sibling", "index", "type"],
        "newlines-between": "always",
        alphabetize: { order: "asc" },
      }],
      "import-x/no-duplicates": "error",
      "import-x/no-cycle": ["error", { maxDepth: 3 }],
    },
  },

  // Project-specific overrides
  {
    rules: {
      // Enforce explicit return types on exported functions
      "@typescript-eslint/explicit-function-return-type": ["error", {
        allowExpressions: true,
        allowTypedFunctionExpressions: true,
      }],

      // Prevent floating (unhandled) promises
      "@typescript-eslint/no-floating-promises": "error",

      // Require awaiting async functions
      "@typescript-eslint/no-misused-promises": "error",

      // Prevent unused variables (allow underscore prefix)
      "@typescript-eslint/no-unused-vars": ["error", {
        argsIgnorePattern: "^_",
        varsIgnorePattern: "^_",
      }],

      // Consistent type imports
      "@typescript-eslint/consistent-type-imports": ["error", {
        prefer: "type-imports",
        fixStyle: "inline-type-imports",
      }],

      // Exhaustive switch/union handling
      "@typescript-eslint/switch-exhaustiveness-check": "error",

      // Naming conventions
      "@typescript-eslint/naming-convention": [
        "error",
        { selector: "interface", format: ["PascalCase"] },
        { selector: "typeAlias", format: ["PascalCase"] },
        { selector: "enum", format: ["PascalCase"] },
        { selector: "enumMember", format: ["PascalCase", "UPPER_CASE"] },
      ],
    },
  },

  // Relax rules for test files
  {
    files: ["**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
    },
  },
);
```

### React Project Extension

```typescript
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";

// Add to the config array:
{
  plugins: { react, "react-hooks": reactHooks },
  settings: { react: { version: "detect" } },
  rules: {
    ...reactHooks.configs.recommended.rules,
    "react/jsx-no-leaked-render": "error",     // Prevent {count && <El />} (0 renders "0")
    "react/no-array-index-key": "warn",        // Prefer stable keys
    "react/self-closing-comp": "error",        // <Foo /> not <Foo></Foo>
    "react/hook-use-state": "error",           // Enforce [x, setX] naming
  },
}
```

### Next.js Project Extension

```bash
pnpm add -D @next/eslint-plugin-next
```

```typescript
import nextPlugin from "@next/eslint-plugin-next";

// Add to config:
{
  plugins: { "@next/next": nextPlugin },
  rules: {
    ...nextPlugin.configs.recommended.rules,
    ...nextPlugin.configs["core-web-vitals"].rules,
  },
}
```

---

## Critical ESLint Rules Explained

| Rule | Why It Matters |
|------|---------------|
| `no-floating-promises` | Unhandled async errors silently swallowed — #1 cause of mystery bugs |
| `no-misused-promises` | Passing async to void callback (e.g., `onClick={async () => {}}`) hides errors |
| `switch-exhaustiveness-check` | Adding a union variant without handling it compiles but crashes at runtime |
| `consistent-type-imports` | `import type` is erased at compile time — prevents bundling unused code |
| `no-explicit-any` (strict) | `any` disables type checking — use `unknown` and narrow |
| `import/no-cycle` | Circular imports cause load-order bugs and break tree-shaking |

---

## Prettier (Formatting)

Separate concern from ESLint — ESLint handles logic rules, Prettier handles formatting.

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

```json
// .prettierignore
dist
node_modules
.next
coverage
pnpm-lock.yaml
```

### Integration

```bash
# Run Prettier then ESLint
pnpm add -D eslint-config-prettier  # Disables ESLint rules that conflict with Prettier
```

```typescript
// Add to eslint.config.ts as LAST item:
import prettier from "eslint-config-prettier";

export default tseslint.config(
  // ... other configs ...
  prettier, // Must be last — disables conflicting format rules
);
```

---

## Biome (Alternative: All-in-One)

Rust-based linter + formatter. 10-100x faster than ESLint + Prettier. Growing adoption but smaller ecosystem.

```json
// biome.json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": { "enabled": true },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "correctness": {
        "noUnusedImports": "error",
        "noUnusedVariables": "error",
        "useExhaustiveDependencies": "warn"
      },
      "suspicious": {
        "noExplicitAny": "error",
        "noArrayIndexKey": "warn"
      },
      "style": {
        "useConst": "error",
        "noNonNullAssertion": "error"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  }
}
```

**When to use Biome over ESLint:**
- Monorepos with many packages (speed matters)
- New projects without legacy ESLint config
- Teams that want zero-config formatting + linting

**When to stick with ESLint:**
- Need type-aware rules (`no-floating-promises`, `switch-exhaustiveness-check`)
- Need React/Next.js-specific plugins
- Existing ESLint config with custom rules

---

## package.json Scripts

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "check": "pnpm typecheck && pnpm lint && pnpm format:check"
  }
}
```

## Pre-commit Hooks (lint-staged + husky)

```bash
pnpm add -D husky lint-staged
pnpm exec husky init
```

```json
// .lintstagedrc
{
  "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,yaml}": ["prettier --write"]
}
```

```bash
# .husky/pre-commit
pnpm exec lint-staged
```
