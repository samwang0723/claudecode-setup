# TypeScript Testing Patterns

## Vitest (Recommended)

### Basic Test Structure

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

describe("UserService", () => {
  let service: UserService;
  let mockRepo: UserRepository;

  beforeEach(() => {
    mockRepo = {
      findById: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };
    service = new UserServiceImpl(mockRepo);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("findById", () => {
    it("should return user when found", async () => {
      const user = { id: "1", name: "Alice", email: "alice@test.com" };
      vi.mocked(mockRepo.findById).mockResolvedValue(user);

      const result = await service.findById("1");

      expect(result).toEqual(user);
      expect(mockRepo.findById).toHaveBeenCalledWith("1");
      expect(mockRepo.findById).toHaveBeenCalledOnce();
    });

    it("should throw NotFoundError when user missing", async () => {
      vi.mocked(mockRepo.findById).mockResolvedValue(null);

      await expect(service.getUser("missing")).rejects.toThrow(NotFoundError);
    });
  });
});
```

### Mocking Modules

```typescript
// Mock an entire module
vi.mock("./email-service", () => ({
  sendEmail: vi.fn().mockResolvedValue({ messageId: "test-123" }),
}));

// Mock a specific export
import { sendEmail } from "./email-service";
vi.mocked(sendEmail).mockResolvedValueOnce({ messageId: "specific-test" });

// Spy on existing implementation
const spy = vi.spyOn(console, "error").mockImplementation(() => {});
// ... test ...
expect(spy).toHaveBeenCalledWith("Expected error message");
spy.mockRestore();
```

### Parameterized Tests (test.each)

```typescript
describe("parseAmount", () => {
  it.each([
    { input: "100", expected: 10000 },
    { input: "99.99", expected: 9999 },
    { input: "0", expected: 0 },
    { input: "0.01", expected: 1 },
  ])("should parse $input to $expected cents", ({ input, expected }) => {
    expect(parseAmount(input)).toBe(expected);
  });

  it.each(["", "abc", "1.999", "-", "NaN"])(
    "should throw for invalid input: %s",
    (input) => {
      expect(() => parseAmount(input)).toThrow(ValidationError);
    },
  );
});
```

### Type-Level Tests

```typescript
import { expectTypeOf } from "vitest";

describe("type safety", () => {
  it("CreateUserInput should not include id", () => {
    expectTypeOf<CreateUserInput>().not.toHaveProperty("id");
  });

  it("Config should have required DATABASE_URL", () => {
    expectTypeOf<Config>().toHaveProperty("DATABASE_URL").toBeString();
  });

  it("findById should return nullable User", () => {
    expectTypeOf<UserRepository["findById"]>()
      .returns
      .resolves
      .toEqualTypeOf<User | null>();
  });
});
```

---

## MSW (Mock Service Worker) for API Mocking

```typescript
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";

const server = setupServer(
  http.get("https://api.example.com/users/:id", ({ params }) => {
    if (params.id === "not-found") {
      return HttpResponse.json({ error: "Not found" }, { status: 404 });
    }
    return HttpResponse.json({
      id: params.id,
      name: "Alice",
      email: "alice@test.com",
    });
  }),

  http.post("https://api.example.com/users", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: "new-1", ...body, createdAt: new Date().toISOString() },
      { status: 201 },
    );
  }),
);

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Override handler for specific test
it("should handle API errors", async () => {
  server.use(
    http.get("https://api.example.com/users/:id", () => {
      return HttpResponse.json({ error: "Server error" }, { status: 500 });
    }),
  );

  await expect(apiClient.getUser("1")).rejects.toThrow(HttpError);
});
```

---

## React Testing Library

### Component Tests

```typescript
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

describe("LoginForm", () => {
  it("should submit with email and password", async () => {
    const onSubmit = vi.fn();
    const user = userEvent.setup();

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/email/i), "alice@test.com");
    await user.type(screen.getByLabelText(/password/i), "secret123");
    await user.click(screen.getByRole("button", { name: /log in/i }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: "alice@test.com",
      password: "secret123",
    });
  });

  it("should show validation errors", async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);

    await user.click(screen.getByRole("button", { name: /log in/i }));

    expect(screen.getByText(/email is required/i)).toBeInTheDocument();
    expect(screen.getByText(/password is required/i)).toBeInTheDocument();
  });

  it("should show loading state during submission", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn().mockImplementation(
      () => new Promise((resolve) => setTimeout(resolve, 100)),
    );

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/email/i), "alice@test.com");
    await user.type(screen.getByLabelText(/password/i), "secret123");
    await user.click(screen.getByRole("button", { name: /log in/i }));

    expect(screen.getByRole("button", { name: /log in/i })).toBeDisabled();
    expect(screen.getByText(/loading/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByRole("button", { name: /log in/i })).toBeEnabled();
    });
  });
});
```

### Testing Hooks

```typescript
import { renderHook, act, waitFor } from "@testing-library/react";

describe("useDebounce", () => {
  it("should debounce value updates", async () => {
    vi.useFakeTimers();
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 300),
      { initialProps: { value: "initial" } },
    );

    expect(result.current).toBe("initial");

    rerender({ value: "updated" });
    expect(result.current).toBe("initial"); // Not yet

    act(() => {
      vi.advanceTimersByTime(300);
    });

    expect(result.current).toBe("updated");
    vi.useRealTimers();
  });
});
```

### Testing with Providers (Context)

```typescript
function renderWithProviders(
  ui: React.ReactElement,
  options?: { initialUser?: User },
) {
  const { initialUser } = options ?? {};

  function Wrapper({ children }: { children: React.ReactNode }) {
    return (
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <AuthProvider initialUser={initialUser}>
          {children}
        </AuthProvider>
      </QueryClientProvider>
    );
  }

  return render(ui, { wrapper: Wrapper });
}

// Usage
it("should show user name when logged in", () => {
  renderWithProviders(<Header />, {
    initialUser: { id: "1", name: "Alice" },
  });

  expect(screen.getByText("Alice")).toBeInTheDocument();
});
```

---

## Integration Testing (Supertest + Testcontainers)

```typescript
import { GenericContainer, StartedTestContainer } from "testcontainers";
import request from "supertest";

describe("User API", () => {
  let container: StartedTestContainer;
  let app: Express;

  beforeAll(async () => {
    container = await new GenericContainer("postgres:16")
      .withEnvironment({ POSTGRES_DB: "test", POSTGRES_PASSWORD: "test" })
      .withExposedPorts(5432)
      .start();

    const dbUrl = `postgresql://postgres:test@${container.getHost()}:${container.getMappedPort(5432)}/test`;
    app = createApp({ databaseUrl: dbUrl });

    // Run migrations
    await migrate(dbUrl);
  }, 60000);

  afterAll(async () => {
    await container.stop();
  });

  it("POST /users should create and return user", async () => {
    const res = await request(app)
      .post("/users")
      .send({ email: "alice@test.com", name: "Alice" })
      .expect(201);

    expect(res.body).toMatchObject({
      id: expect.any(String),
      email: "alice@test.com",
      name: "Alice",
    });
  });

  it("GET /users/:id should return 404 for missing user", async () => {
    await request(app)
      .get("/users/nonexistent-id")
      .expect(404)
      .expect((res) => {
        expect(res.body.error.code).toBe("NOT_FOUND");
      });
  });
});
```

---

## Test Best Practices

| Do | Don't |
|-----|-------|
| Test behavior, not implementation | Test internal state or private methods |
| Use `getByRole`, `getByLabelText` | Use `getByTestId` as first choice |
| Assert on user-visible outcomes | Assert on component internals |
| Mock at boundaries (API, DB) | Mock everything (over-mocking) |
| Use `vi.fn()` for spies | Implement manual spy classes |
| Group tests by behavior | Group tests by method name |
| One assertion per logical outcome | Multiple unrelated assertions |
| Use `toMatchObject` for partials | Deep equality on large objects |
| Cleanup in `afterEach` | Leave side effects between tests |
| Test error paths explicitly | Only test happy paths |
