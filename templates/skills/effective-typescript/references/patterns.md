# TypeScript Advanced Patterns

## Result Type (Railway-Oriented Error Handling)

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

// Usage — explicit success/failure without exceptions
async function createUser(input: CreateUserInput): Promise<Result<User, ValidationError | ConflictError>> {
  const validation = validateInput(input);
  if (!validation.ok) return validation;

  const existing = await repo.findByEmail(input.email);
  if (existing) return err(new ConflictError("Email already registered"));

  const user = await repo.create(input);
  return ok(user);
}

// Caller
const result = await createUser(input);
if (!result.ok) {
  // TypeScript narrows error to ValidationError | ConflictError
  return res.status(result.error.statusCode).json({ error: result.error.message });
}
// result.value is User
```

---

## Dependency Injection with Factory Functions

```typescript
// No framework needed — just closures and interfaces

type Dependencies = {
  db: DatabasePool;
  cache: CacheClient;
  logger: Logger;
};

function createUserService(deps: Dependencies): UserService {
  const { db, cache, logger } = deps;

  return {
    async findById(id: string): Promise<User | null> {
      const cached = await cache.get<User>(`user:${id}`);
      if (cached) return cached;

      const user = await db.query<User>("SELECT * FROM users WHERE id = $1", [id]);
      if (user) await cache.set(`user:${id}`, user, { ttl: 300 });
      return user;
    },

    async create(input: CreateUserInput): Promise<User> {
      const user = await db.query<User>(
        "INSERT INTO users (email, name) VALUES ($1, $2) RETURNING *",
        [input.email, input.name],
      );
      logger.info({ userId: user.id }, "User created");
      return user;
    },
  };
}

// Wire at startup
const deps: Dependencies = {
  db: createPool(config.databaseUrl),
  cache: createRedisCache(config.redisUrl),
  logger: createLogger(config.logLevel),
};

const userService = createUserService(deps);
```

---

## Middleware Pattern (Express/Fastify-style)

```typescript
type Context = {
  req: Request;
  res: Response;
  user?: AuthUser;
  requestId: string;
};

type Middleware = (ctx: Context, next: () => Promise<void>) => Promise<void>;

// Compose middleware into a pipeline
function compose(...middlewares: Middleware[]): Middleware {
  return async (ctx, next) => {
    let index = -1;

    async function dispatch(i: number): Promise<void> {
      if (i <= index) throw new Error("next() called multiple times");
      index = i;
      const fn = i < middlewares.length ? middlewares[i] : next;
      await fn(ctx, () => dispatch(i + 1));
    }

    await dispatch(0);
  };
}

// Usage
const authenticate: Middleware = async (ctx, next) => {
  const token = ctx.req.headers.authorization?.replace("Bearer ", "");
  if (!token) throw new UnauthorizedError();
  ctx.user = await verifyToken(token);
  await next();
};

const rateLimit = (maxRequests: number, windowMs: number): Middleware => {
  const store = new Map<string, { count: number; resetAt: number }>();

  return async (ctx, next) => {
    const key = ctx.user?.id ?? ctx.req.ip;
    const now = Date.now();
    const entry = store.get(key);

    if (entry && entry.resetAt > now && entry.count >= maxRequests) {
      ctx.res.status(429).json({ error: "Rate limit exceeded" });
      return;
    }

    if (!entry || entry.resetAt <= now) {
      store.set(key, { count: 1, resetAt: now + windowMs });
    } else {
      entry.count++;
    }

    await next();
  };
};
```

---

## Builder Pattern with Fluent API

```typescript
class QueryBuilder<T> {
  private conditions: string[] = [];
  private params: unknown[] = [];
  private limitVal?: number;
  private offsetVal?: number;
  private orderByVal?: string;

  constructor(private readonly table: string) {}

  where(condition: string, ...values: unknown[]): this {
    const paramIndex = this.params.length + 1;
    const rewritten = condition.replace(/\?/g, () => `$${paramIndex + this.conditions.length}`);
    this.conditions.push(rewritten);
    this.params.push(...values);
    return this;
  }

  orderBy(column: string, direction: "ASC" | "DESC" = "ASC"): this {
    this.orderByVal = `${column} ${direction}`;
    return this;
  }

  limit(n: number): this {
    this.limitVal = n;
    return this;
  }

  offset(n: number): this {
    this.offsetVal = n;
    return this;
  }

  build(): { sql: string; params: unknown[] } {
    let sql = `SELECT * FROM ${this.table}`;
    if (this.conditions.length > 0) {
      sql += ` WHERE ${this.conditions.join(" AND ")}`;
    }
    if (this.orderByVal) sql += ` ORDER BY ${this.orderByVal}`;
    if (this.limitVal !== undefined) sql += ` LIMIT ${this.limitVal}`;
    if (this.offsetVal !== undefined) sql += ` OFFSET ${this.offsetVal}`;
    return { sql, params: this.params };
  }
}

// Usage
const query = new QueryBuilder<User>("users")
  .where("status = ?", "active")
  .where("created_at > ?", startDate)
  .orderBy("created_at", "DESC")
  .limit(20)
  .build();
```

---

## Event Emitter (Type-Safe)

```typescript
type EventMap = {
  "user:created": { user: User };
  "user:deleted": { userId: string };
  "order:placed": { order: Order; user: User };
};

class TypedEventEmitter<T extends Record<string, unknown>> {
  private listeners = new Map<keyof T, Set<(payload: any) => void>>();

  on<K extends keyof T>(event: K, handler: (payload: T[K]) => void): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
    return () => this.listeners.get(event)?.delete(handler);
  }

  emit<K extends keyof T>(event: K, payload: T[K]): void {
    this.listeners.get(event)?.forEach((handler) => handler(payload));
  }
}

// Usage
const events = new TypedEventEmitter<EventMap>();

events.on("user:created", ({ user }) => {
  // user is typed as User
  sendWelcomeEmail(user.email);
});

events.emit("user:created", { user: newUser }); // Type-checked payload
```

---

## Retry with Exponential Backoff

```typescript
type RetryConfig = {
  maxAttempts: number;
  baseDelayMs: number;
  maxDelayMs: number;
  retryOn?: (error: Error) => boolean;
};

async function retry<T>(fn: () => Promise<T>, config: RetryConfig): Promise<T> {
  const { maxAttempts, baseDelayMs, maxDelayMs, retryOn } = config;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      const isRetryable = retryOn?.(error as Error) ?? true;
      if (!isRetryable || attempt === maxAttempts - 1) {
        throw error;
      }

      const delay = Math.min(baseDelayMs * 2 ** attempt, maxDelayMs);
      const jitter = Math.random() * delay * 0.25;
      await new Promise((resolve) => setTimeout(resolve, delay + jitter));
    }
  }

  throw new Error("Unreachable");
}

// Usage
const data = await retry(() => fetchFromAPI("/users"), {
  maxAttempts: 3,
  baseDelayMs: 1000,
  maxDelayMs: 10000,
  retryOn: (err) => err instanceof HttpError && err.status >= 500,
});
```

---

## Repository Pattern with Transactions

```typescript
interface TransactionClient {
  query<T>(sql: string, params?: unknown[]): Promise<T[]>;
  queryOne<T>(sql: string, params?: unknown[]): Promise<T | null>;
}

interface Repository<T> {
  findById(id: string, client?: TransactionClient): Promise<T | null>;
  create(data: Omit<T, "id" | "createdAt">, client?: TransactionClient): Promise<T>;
}

// Transaction wrapper
async function withTransaction<T>(
  pool: DatabasePool,
  fn: (client: TransactionClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// Usage
await withTransaction(pool, async (tx) => {
  const order = await orderRepo.create(orderData, tx);
  await walletRepo.debit(userId, order.total, tx);
  await inventoryRepo.reserve(order.items, tx);
  return order;
});
```

---

## Discriminated Union Exhaustiveness

```typescript
// Exhaustive switch with compile-time safety
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "rectangle"; width: number; height: number }
  | { kind: "triangle"; base: number; height: number };

function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle":
      return Math.PI * shape.radius ** 2;
    case "rectangle":
      return shape.width * shape.height;
    case "triangle":
      return (shape.base * shape.height) / 2;
    default:
      // Compile error if a variant is missing
      return assertNever(shape);
  }
}

function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${JSON.stringify(x)}`);
}
```

---

## Type-Safe Environment Variables

```typescript
// env.d.ts — declare process.env types
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      NODE_ENV: "development" | "production" | "test";
      PORT: string;
      DATABASE_URL: string;
      JWT_SECRET: string;
    }
  }
}

export {};

// Or use Zod + infer (preferred — runtime validation + type safety)
```

---

## Mapped and Conditional Types

```typescript
// Make all functions in an interface async
type Async<T> = {
  [K in keyof T]: T[K] extends (...args: infer A) => infer R
    ? (...args: A) => Promise<Awaited<R>>
    : T[K];
};

// Extract only methods from a type
type Methods<T> = {
  [K in keyof T as T[K] extends (...args: any[]) => any ? K : never]: T[K];
};

// Create a "patch" type (all optional, no readonly)
type Mutable<T> = {
  -readonly [K in keyof T]: T[K];
};

type Patch<T> = Partial<Mutable<Omit<T, "id" | "createdAt" | "updatedAt">>>;
```
