---
name: effective-typescript
description: "Idiomatic TypeScript patterns for production applications: strict typing, error handling, async patterns, React/Next.js, Node.js services, testing, and performance. Use PROACTIVELY when writing, reviewing, or refactoring TypeScript code."
---

# Effective TypeScript — Golden Patterns

Production-grade TypeScript patterns. Type safety over convenience. Explicit over magical.

## When Invoked

1. Check `tsconfig.json` for compiler options, `strict` mode, and target
2. Check `package.json` for framework (Next.js, Express, Fastify, etc.) and key dependencies
3. Identify existing patterns in the codebase (error types, API style, state management)
4. Apply patterns below, adapting to established project conventions

## References

- `references/patterns.md` — Advanced patterns (Result types, dependency injection, middleware)
- `references/testing.md` — Testing guide (vitest, jest, React Testing Library, MSW)
- `references/react-nextjs.md` — React and Next.js patterns (server components, hooks, state)
- `references/linting.md` — ESLint flat config, Prettier, Biome, pre-commit hooks

---

## 1. Project Layout

### Node.js Service
```
service/
  src/
    index.ts                 # Entrypoint: wire deps, start server
    config/
      index.ts               # Env-based configuration with validation
    domain/
      types.ts               # Business types and interfaces (no external deps)
      errors.ts              # Domain error classes
    routes/                  # HTTP route handlers
      user.routes.ts
      middleware.ts
    services/                # Business logic implementations
      user.service.ts
    repositories/            # Data access implementations
      user.repository.ts
    lib/                     # Internal shared utilities
      http.ts
      validator.ts
  tests/
    unit/
    integration/
  tsconfig.json
  package.json
```

### Next.js App Router
```
app/
  layout.tsx                 # Root layout
  page.tsx                   # Home page
  (auth)/                    # Route group (no URL segment)
    login/page.tsx
    register/page.tsx
  api/                       # Route handlers
    users/route.ts
  _components/               # Shared components (not routable)
    ui/                      # Primitives (Button, Input, Modal)
    features/                # Domain components (UserCard, OrderTable)
  _lib/                      # Shared utilities
    actions.ts               # Server actions
    queries.ts               # Data fetching
    types.ts                 # Shared types
```

**Rules:**
- Separate domain types from implementation — keep `domain/` dependency-free
- Co-locate tests next to source files or in a mirrored `tests/` tree
- Use barrel exports (`index.ts`) sparingly — they hurt tree-shaking
- Prefix non-routable folders with `_` in Next.js App Router

---

## 2. Strict TypeScript Configuration

```jsonc
// tsconfig.json — non-negotiable settings
{
  "compilerOptions": {
    "strict": true,                    // Enables all strict checks
    "noUncheckedIndexedAccess": true,  // arr[i] is T | undefined
    "exactOptionalProperties": true,   // undefined ≠ optional
    "noImplicitOverride": true,        // Explicit override keyword
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "verbatimModuleSyntax": true,      // Explicit type imports
    "isolatedModules": true,           // Safe for bundlers
    "moduleResolution": "bundler",     // Modern resolution
    "target": "ES2022",
    "module": "ES2022"
  }
}
```

**Key strict behaviors:**
- `strictNullChecks` — `null`/`undefined` are not assignable to other types
- `noUncheckedIndexedAccess` — array/object index returns `T | undefined`
- `exactOptionalProperties` — `{ name?: string }` does NOT accept `{ name: undefined }`

---

## 3. Type System

### Prefer Types Over Interfaces for Data

```typescript
// GOOD: Type alias for data shapes — supports unions, intersections, mapped types
type User = {
  readonly id: string;
  readonly email: string;
  readonly name: string;
  readonly createdAt: Date;
};

type CreateUserInput = Omit<User, "id" | "createdAt">;
type UserUpdate = Partial<Pick<User, "email" | "name">>;

// GOOD: Interface for contracts that implementations fulfill
interface UserRepository {
  findById(id: string): Promise<User | null>;
  create(input: CreateUserInput): Promise<User>;
  update(id: string, data: UserUpdate): Promise<User>;
  delete(id: string): Promise<void>;
}

// GOOD: Discriminated unions for state machines
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };
```

### Branded Types for Primitive Safety

```typescript
// Prevent mixing up string IDs
type UserId = string & { readonly __brand: "UserId" };
type OrderId = string & { readonly __brand: "OrderId" };

function createUserId(id: string): UserId {
  // validate format
  return id as UserId;
}

// Compiler prevents: findUser(orderId)
function findUser(id: UserId): Promise<User | null> { /* ... */ }
```

### Const Assertions and Enums

```typescript
// GOOD: const object + type extraction (tree-shakeable, no runtime overhead)
const STATUS = {
  Active: "active",
  Inactive: "inactive",
  Suspended: "suspended",
} as const;

type Status = (typeof STATUS)[keyof typeof STATUS]; // "active" | "inactive" | "suspended"

// AVOID: TypeScript enums (numeric enums are footguns, string enums add runtime code)
// enum Status { Active = "active" } // generates JavaScript object
```

### Utility Types — Use the Standard Library

```typescript
// Don't reinvent — use built-in utility types
type Readonly<T>       // Immutable version
type Partial<T>        // All properties optional
type Required<T>       // All properties required
type Pick<T, K>        // Subset of properties
type Omit<T, K>        // Remove properties
type Record<K, V>      // Key-value map
type Extract<T, U>     // Members of T assignable to U
type Exclude<T, U>     // Members of T not assignable to U
type NonNullable<T>    // Exclude null and undefined
type ReturnType<T>     // Return type of function
type Parameters<T>     // Parameter types of function
type Awaited<T>        // Unwrap Promise type
```

### Anti-patterns

```typescript
// BAD: any
function parse(data: any) {} // Disables all type checking

// BAD: Type assertion to silence errors
const user = data as User; // Bypasses type checking

// GOOD: Type guard instead
function isUser(data: unknown): data is User {
  return (
    typeof data === "object" &&
    data !== null &&
    "id" in data &&
    "email" in data
  );
}

// BAD: Non-null assertion
const name = user!.name; // Runtime error if null

// GOOD: Explicit check
const name = user?.name ?? "Unknown";

// BAD: Enum for simple values
enum Direction { Up, Down } // Up = 0, Down = 1 (footgun)

// BAD: Nested ternaries for type narrowing
// GOOD: Use exhaustive switch with never check
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`);
}
```

---

## 4. Error Handling

### Domain Error Classes

```typescript
// domain/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly cause?: Error,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export class NotFoundError extends AppError {
  constructor(entity: string, id: string) {
    super(`${entity} not found: ${id}`, "NOT_FOUND", 404);
    this.name = "NotFoundError";
  }
}

export class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly fields: Record<string, string>,
  ) {
    super(message, "VALIDATION_ERROR", 422);
    this.name = "ValidationError";
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = "Unauthorized") {
    super(message, "UNAUTHORIZED", 401);
    this.name = "UnauthorizedError";
  }
}
```

### Centralized Error Handler

```typescript
// middleware/error-handler.ts
import type { Request, Response, NextFunction } from "express";

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: { code: err.code, message: err.message },
    });
    return;
  }

  // Unknown error — log full details, return generic message
  console.error("Unhandled error:", err);
  res.status(500).json({
    error: { code: "INTERNAL_ERROR", message: "Internal server error" },
  });
}
```

### Anti-patterns

```typescript
// BAD: Catching and swallowing
try { await riskyOp(); } catch {} // Silent failure

// BAD: Catching generic Error and rethrowing string
catch (err) { throw "Something failed"; } // Loses stack trace

// BAD: Logging AND rethrowing (double reports)
catch (err) {
  console.error(err);
  throw err; // Caller logs again
}

// GOOD: Handle or propagate, never both
catch (err) {
  throw new AppError("Operation failed", "OP_FAILED", 500, err as Error);
}
```

---

## 5. Async Patterns

### Promise.allSettled for Resilient Parallel Ops

```typescript
async function loadDashboard(userId: string): Promise<Dashboard> {
  const [userResult, ordersResult, balanceResult] = await Promise.allSettled([
    userService.findById(userId),
    orderService.listRecent(userId, 10),
    walletService.getBalance(userId),
  ]);

  return {
    user: userResult.status === "fulfilled" ? userResult.value : null,
    orders: ordersResult.status === "fulfilled" ? ordersResult.value : [],
    balance: balanceResult.status === "fulfilled" ? balanceResult.value : null,
    errors: [userResult, ordersResult, balanceResult]
      .filter((r): r is PromiseRejectedResult => r.status === "rejected")
      .map((r) => r.reason),
  };
}
```

### AbortController for Cancellation

```typescript
async function fetchWithTimeout<T>(
  url: string,
  options: RequestInit & { timeoutMs?: number } = {},
): Promise<T> {
  const { timeoutMs = 5000, ...fetchOptions } = options;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...fetchOptions,
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new AppError(`HTTP ${response.status}`, "HTTP_ERROR", response.status);
    }
    return (await response.json()) as T;
  } finally {
    clearTimeout(timeoutId);
  }
}
```

### Async Iteration

```typescript
// Process large datasets without loading all into memory
async function* paginate<T>(
  fetcher: (cursor: string | null) => Promise<{ items: T[]; nextCursor: string | null }>,
): AsyncGenerator<T> {
  let cursor: string | null = null;
  do {
    const page = await fetcher(cursor);
    for (const item of page.items) {
      yield item;
    }
    cursor = page.nextCursor;
  } while (cursor !== null);
}

// Usage
for await (const user of paginate((cursor) => api.listUsers({ cursor, limit: 100 }))) {
  await processUser(user);
}
```

---

## 6. Zod Validation

```typescript
import { z } from "zod";

// Schema doubles as type definition and runtime validator
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(["user", "admin"]).default("user"),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

// In route handler
function createUser(req: Request, res: Response): void {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        details: result.error.flatten().fieldErrors,
      },
    });
    return;
  }
  // result.data is typed as CreateUserInput
  const user = await userService.create(result.data);
  res.status(201).json(user);
}

// Reusable schemas
const PaginationSchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const IdParamSchema = z.object({
  id: z.string().uuid(),
});
```

---

## 7. Immutability

```typescript
// GOOD: Readonly types for function parameters
function processUsers(users: readonly User[]): UserSummary[] {
  return users.map((u) => ({ id: u.id, displayName: u.name }));
}

// GOOD: Spread for object updates (never mutate)
function updateUser(user: User, changes: UserUpdate): User {
  return { ...user, ...changes, updatedAt: new Date() };
}

// GOOD: Readonly deeply nested
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K];
};

// GOOD: Array operations that return new arrays
const sorted = [...items].sort((a, b) => a.name.localeCompare(b.name));
const filtered = items.filter((item) => item.active);
const updated = items.map((item) =>
  item.id === targetId ? { ...item, status: "done" } : item,
);

// BAD: Mutation
users.push(newUser);        // Mutates array
user.name = "New Name";     // Mutates object
items.sort();               // Mutates in place
```

---

## 8. Module and Import Patterns

```typescript
// GOOD: Explicit type imports (enforced by verbatimModuleSyntax)
import type { User, CreateUserInput } from "./types.ts";
import { UserService } from "./user.service.ts";

// GOOD: Re-export from domain barrel (keep it small)
// domain/index.ts
export type { User, Order, Product } from "./types.ts";
export { NotFoundError, ValidationError } from "./errors.ts";

// AVOID: Deep barrel exports that defeat tree-shaking
// export * from "./services";
// export * from "./repositories";
// export * from "./utils";

// GOOD: Direct imports for implementation details
import { hashPassword } from "../lib/crypto.ts";
```

---

## 9. Node.js HTTP Service (Express/Fastify)

### Route Handler Pattern

```typescript
// routes/user.routes.ts
import type { Router } from "express";

export function userRoutes(router: Router, deps: { userService: UserService }): void {
  const { userService } = deps;

  router.get("/users/:id", async (req, res, next) => {
    try {
      const { id } = IdParamSchema.parse(req.params);
      const user = await userService.findById(id);
      if (!user) {
        throw new NotFoundError("User", id);
      }
      res.json(user);
    } catch (err) {
      next(err);
    }
  });

  router.post("/users", async (req, res, next) => {
    try {
      const input = CreateUserSchema.parse(req.body);
      const user = await userService.create(input);
      res.status(201).json(user);
    } catch (err) {
      next(err);
    }
  });
}
```

### Dependency Injection (Manual Wiring)

```typescript
// index.ts — wire everything at startup
import express from "express";

const app = express();
app.use(express.json());

// Wire dependencies
const db = createPool(config.databaseUrl);
const userRepo = new PostgresUserRepository(db);
const userService = new UserServiceImpl(userRepo);

// Mount routes
userRoutes(app.router, { userService });

// Error handler last
app.use(errorHandler);

app.listen(config.port, () => {
  console.log(`Server running on :${config.port}`);
});
```

---

## 10. Testing

### Unit Tests with Vitest

```typescript
import { describe, it, expect, vi } from "vitest";

describe("UserService", () => {
  it("should return user when found", async () => {
    const mockRepo: UserRepository = {
      findById: vi.fn().mockResolvedValue({ id: "1", name: "Alice", email: "a@b.com" }),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };
    const service = new UserServiceImpl(mockRepo);

    const user = await service.findById("1");

    expect(user).toEqual({ id: "1", name: "Alice", email: "a@b.com" });
    expect(mockRepo.findById).toHaveBeenCalledWith("1");
  });

  it("should throw NotFoundError when user missing", async () => {
    const mockRepo: UserRepository = {
      findById: vi.fn().mockResolvedValue(null),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };
    const service = new UserServiceImpl(mockRepo);

    await expect(service.getUser("missing")).rejects.toThrow(NotFoundError);
  });
});
```

### Type-Level Tests

```typescript
import { expectTypeOf } from "vitest";

it("CreateUserInput should not include id", () => {
  expectTypeOf<CreateUserInput>().not.toHaveProperty("id");
});

it("UserRepository.findById should return nullable User", () => {
  expectTypeOf<UserRepository["findById"]>().returns.resolves.toEqualTypeOf<User | null>();
});
```

See `references/testing.md` for integration tests, MSW mocks, and React Testing Library patterns.

---

## 11. Configuration

```typescript
// config/index.ts
import { z } from "zod";

const ConfigSchema = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url().default("redis://localhost:6379"),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
  JWT_SECRET: z.string().min(32),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
});

export type Config = z.infer<typeof ConfigSchema>;

export function loadConfig(): Config {
  const result = ConfigSchema.safeParse(process.env);
  if (!result.success) {
    console.error("Invalid config:", result.error.flatten().fieldErrors);
    process.exit(1);
  }
  return result.data;
}
```

---

## 12. Logging

```typescript
// Use structured logging (pino, winston) — never console.log in production
import pino from "pino";

export const logger = pino({
  level: config.LOG_LEVEL,
  ...(config.NODE_ENV === "development" && { transport: { target: "pino-pretty" } }),
});

// In handlers — add request context
logger.info({ userId: user.id, action: "create" }, "User created");

// Error with cause
logger.error({ err, requestId }, "Failed to create user");

// PII rules: Never log full emails, passwords, tokens, or PII.
// Log masked values: email domain, user ID, truncated token
```

---

## Quick Reference — Do/Don't

| Do | Don't |
|-----|-------|
| `strict: true` in tsconfig | Loose compiler options |
| `unknown` for external data | `any` type |
| Type guards (`is` predicates) | Type assertions (`as`) |
| `readonly` properties/params | Mutable objects/arrays |
| Discriminated unions | String/number enums |
| `const` assertions | TypeScript enums |
| Zod/Valibot for validation | Manual runtime checks |
| `import type { X }` | Mixed value/type imports |
| Explicit return types on public APIs | Implicit complex returns |
| `satisfies` for type checking | `as` for type narrowing |
| `Error` subclasses with `cause` | String throws |
| `Promise.allSettled` for resilience | `Promise.all` when partial OK |
| Spread for immutable updates | Object mutation |
| `??` (nullish coalescing) | `\|\|` (falsy coalescing) |
| `?.` (optional chaining) | `!` (non-null assertion) |
| `Map`/`Set` for dynamic keys | Plain objects as maps |
| `using` (explicit resource mgmt) | Manual cleanup in finally |
