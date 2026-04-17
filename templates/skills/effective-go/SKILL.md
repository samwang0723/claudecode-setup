---
name: effective-go
description: "Idiomatic Go patterns for production services: error handling, HTTP/gRPC handlers, concurrency, testing, database, and observability. Use PROACTIVELY when writing, reviewing, or refactoring Go code."
---

# Effective Go — Golden Patterns

Production-grade Go patterns. Correctness over cleverness. Explicit over magical.

## When Invoked

1. Check `go.mod` for module name, Go version, and dependencies
2. Identify existing patterns in the codebase (error types, handler style, DI approach)
3. Apply patterns below, adapting to established project conventions

## References

- `REFERENCE.md` — Uber Go style guide rules (Do/Don't tables)
- `examples.md` — Uber style code examples and anti-patterns
- `references/patterns.md` — Advanced patterns (graceful shutdown, worker pools, gRPC)
- `references/testing.md` — Comprehensive testing guide (table-driven, httptest, mocks)

---

## 1. Project Layout

```
service/
  cmd/
    server/main.go          # Entrypoint: wire deps, start server
  internal/
    config/config.go        # Env-based configuration
    domain/                  # Business types and interfaces (no external deps)
      model.go
      repository.go          # Interface definitions
      service.go             # Interface definitions
    handler/                 # HTTP/gRPC handlers
      user_handler.go
      middleware.go
    service/                 # Business logic implementations
      user_service.go
    repository/              # Data access implementations
      postgres/
        user_repo.go
    pkg/                     # Internal shared utilities
      httputil/response.go
      validator/validator.go
  migrations/                # SQL migration files
  api/                       # Proto files, OpenAPI specs
  go.mod
  go.sum
  Makefile
```

**Rules:**
- `internal/` prevents external imports — use it for all service code
- `domain/` holds pure business types with zero external dependencies
- Interfaces live where they are consumed, not where they are implemented
- `cmd/` is thin: parse config, wire dependencies, start server

---

## 2. Error Handling

### Sentinel Errors

```go
// domain/errors.go — package-level sentinel errors
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrUnauthorized  = errors.New("unauthorized")
    ErrForbidden     = errors.New("forbidden")
    ErrInvalidInput  = errors.New("invalid input")
)
```

### Custom Error Types

```go
// domain/errors.go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s %s", e.Field, e.Message)
}

type AppError struct {
    Code    string // Machine-readable: "USER_NOT_FOUND"
    Message string // Human-readable
    Err     error  // Wrapped cause
}

func (e *AppError) Error() string { return e.Message }
func (e *AppError) Unwrap() error { return e.Err }
```

### Wrapping with Context

```go
// GOOD: Wrap with context at every boundary
func (r *UserRepo) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    err := r.db.QueryRowContext(ctx, "SELECT ... WHERE id = $1", id).Scan(&user.ID, &user.Name)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
    }
    if err != nil {
        return nil, fmt.Errorf("query user %s: %w", id, err)
    }
    return &user, nil
}

// GOOD: Check with errors.Is/As
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    user, err := h.svc.GetUser(r.Context(), chi.URLParam(r, "id"))
    if err != nil {
        switch {
        case errors.Is(err, ErrNotFound):
            writeJSON(w, http.StatusNotFound, ErrorResponse{Error: "user not found"})
        case errors.Is(err, ErrForbidden):
            writeJSON(w, http.StatusForbidden, ErrorResponse{Error: "access denied"})
        default:
            h.log.Error("get user", "error", err)
            writeJSON(w, http.StatusInternalServerError, ErrorResponse{Error: "internal error"})
        }
        return
    }
    writeJSON(w, http.StatusOK, user)
}
```

### Anti-patterns

```go
// BAD: String matching
if err.Error() == "not found" {}

// BAD: Swallowing errors
result, _ := riskyOperation()

// BAD: Logging AND returning (double-reports)
if err != nil {
    log.Error("failed", "err", err)
    return fmt.Errorf("operation: %w", err) // caller logs again
}

// BAD: Wrapping without context
return fmt.Errorf("%w", err) // useless wrap, just return err
```

---

## 3. HTTP Handlers

### Handler Struct with Dependencies

```go
type UserHandler struct {
    svc    domain.UserService
    log    *slog.Logger
    valid  *validator.Validate
}

func NewUserHandler(svc domain.UserService, log *slog.Logger) *UserHandler {
    return &UserHandler{
        svc:   svc,
        log:   log,
        valid: validator.New(),
    }
}

func (h *UserHandler) Routes(r chi.Router) {
    r.Route("/users", func(r chi.Router) {
        r.Get("/", h.List)
        r.Post("/", h.Create)
        r.Route("/{id}", func(r chi.Router) {
            r.Get("/", h.Get)
            r.Put("/", h.Update)
            r.Delete("/", h.Delete)
        })
    })
}
```

### Request/Response Pattern

```go
// Separate types for request and response — never reuse domain models directly
type CreateUserRequest struct {
    Email     string `json:"email" validate:"required,email"`
    FirstName string `json:"first_name" validate:"required,min=1,max=100"`
    LastName  string `json:"last_name" validate:"required,min=1,max=100"`
}

type UserResponse struct {
    ID        string `json:"id"`
    Email     string `json:"email"`
    FirstName string `json:"first_name"`
    LastName  string `json:"last_name"`
    CreatedAt string `json:"created_at"`
}

func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    if err := decodeJSON(r, &req); err != nil {
        writeJSON(w, http.StatusBadRequest, ErrorResponse{Error: "invalid request body"})
        return
    }
    if err := h.valid.Struct(req); err != nil {
        writeJSON(w, http.StatusUnprocessableEntity, validationErrors(err))
        return
    }

    user, err := h.svc.CreateUser(r.Context(), domain.CreateUserParams{
        Email:     req.Email,
        FirstName: req.FirstName,
        LastName:  req.LastName,
    })
    if err != nil {
        handleError(w, h.log, err)
        return
    }

    writeJSON(w, http.StatusCreated, toUserResponse(user))
}
```

### JSON Helpers

```go
func decodeJSON(r *http.Request, dst any) error {
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    return dec.Decode(dst)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v) //nolint:errcheck
}

type ErrorResponse struct {
    Error   string            `json:"error"`
    Details map[string]string `json:"details,omitempty"`
}
```

---

## 4. Middleware

```go
// Logging middleware with structured fields
func LoggingMiddleware(log *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            ww := &responseWriter{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(ww, r)

            log.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "status", ww.status,
                "duration_ms", time.Since(start).Milliseconds(),
                "request_id", r.Context().Value(requestIDKey),
            )
        })
    }
}

// Request ID middleware
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" {
            id = uuid.NewString()
        }
        ctx := context.WithValue(r.Context(), requestIDKey, id)
        w.Header().Set("X-Request-ID", id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

// Recovery middleware
func RecoveryMiddleware(log *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if rec := recover(); rec != nil {
                    log.Error("panic recovered",
                        "panic", rec,
                        "stack", string(debug.Stack()),
                    )
                    writeJSON(w, http.StatusInternalServerError,
                        ErrorResponse{Error: "internal server error"})
                }
            }()
            next.ServeHTTP(w, r)
        })
    }
}

// responseWriter wrapper to capture status code
type responseWriter struct {
    http.ResponseWriter
    status int
}

func (w *responseWriter) WriteHeader(code int) {
    w.status = code
    w.ResponseWriter.WriteHeader(code)
}
```

---

## 5. Context

```go
// GOOD: First parameter, propagate everywhere
func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    return s.repo.FindByID(ctx, id)
}

// GOOD: Use for cancellation and timeouts
func (s *UserService) ProcessBatch(ctx context.Context, ids []string) error {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    for _, id := range ids {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            if err := s.processOne(ctx, id); err != nil {
                return fmt.Errorf("process %s: %w", id, err)
            }
        }
    }
    return nil
}

// GOOD: Typed context keys (never use string keys)
type contextKey int

const (
    requestIDKey contextKey = iota
    userIDKey
)

func UserIDFromContext(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(userIDKey).(string)
    return id, ok
}
```

---

## 6. Concurrency

### errgroup — Parallel with Error Propagation

```go
func (s *DashboardService) GetDashboard(ctx context.Context, userID string) (*Dashboard, error) {
    var (
        user     *User
        orders   []Order
        balance  *Balance
    )

    g, ctx := errgroup.WithContext(ctx)

    g.Go(func() error {
        var err error
        user, err = s.userSvc.GetUser(ctx, userID)
        return err
    })
    g.Go(func() error {
        var err error
        orders, err = s.orderSvc.ListRecent(ctx, userID, 10)
        return err
    })
    g.Go(func() error {
        var err error
        balance, err = s.walletSvc.GetBalance(ctx, userID)
        return err
    })

    if err := g.Wait(); err != nil {
        return nil, fmt.Errorf("load dashboard: %w", err)
    }

    return &Dashboard{User: user, Orders: orders, Balance: balance}, nil
}
```

### Bounded Worker Pool

```go
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(workers)

    for _, item := range items {
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }

    return g.Wait()
}
```

### Channel Patterns

```go
// Fan-out, fan-in
func FanOut(ctx context.Context, input <-chan Job, workers int) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    for range workers {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range input {
                select {
                case <-ctx.Done():
                    return
                case results <- process(job):
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Goroutine Leak Prevention

```go
// BAD: Blocks forever if context cancelled and no receiver
func leakyFetch(ctx context.Context, url string) <-chan []byte {
    ch := make(chan []byte)
    go func() {
        data, _ := fetch(url)
        ch <- data // blocks forever if no receiver
    }()
    return ch
}

// GOOD: Buffered channel + select on ctx.Done
func safeFetch(ctx context.Context, url string) <-chan []byte {
    ch := make(chan []byte, 1)
    go func() {
        data, err := fetch(url)
        if err != nil {
            return
        }
        select {
        case ch <- data:
        case <-ctx.Done():
        }
    }()
    return ch
}
```

### Anti-patterns

```go
// BAD: Fire-and-forget goroutine (leaked on error, no lifecycle)
go processItem(item)

// BAD: Goroutine in init()
func init() {
    go backgroundTask()
}

// BAD: Arbitrary channel buffer
ch := make(chan int, 100) // Why 100? Use 0 or 1.

// BAD: sync.Mutex pointer
mu := new(sync.Mutex) // Use var mu sync.Mutex
```

---

## 7. Dependency Injection

```go
// domain/service.go — interfaces where consumed
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
}

type UserService interface {
    GetUser(ctx context.Context, id string) (*User, error)
    CreateUser(ctx context.Context, params CreateUserParams) (*User, error)
}

// service/user_service.go — implementation
type userService struct {
    repo   domain.UserRepository
    cache  domain.CacheClient
    log    *slog.Logger
}

func NewUserService(repo domain.UserRepository, cache domain.CacheClient, log *slog.Logger) domain.UserService {
    return &userService{repo: repo, cache: cache, log: log}
}

// cmd/server/main.go — wire everything in main
func main() {
    cfg := config.MustLoad()
    log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

    db := mustConnectDB(cfg.DatabaseURL)
    defer db.Close()

    redis := mustConnectRedis(cfg.RedisURL)
    defer redis.Close()

    // Wire dependencies
    userRepo := postgres.NewUserRepository(db)
    cache := redisclient.New(redis)
    userSvc := service.NewUserService(userRepo, cache, log)
    userHandler := handler.NewUserHandler(userSvc, log)

    // Build router
    r := chi.NewRouter()
    r.Use(middleware.RequestID, middleware.RealIP)
    r.Use(LoggingMiddleware(log))
    r.Use(RecoveryMiddleware(log))
    userHandler.Routes(r)

    srv := &http.Server{Addr: cfg.Addr, Handler: r}
    gracefulShutdown(srv, log)
}
```

### Optional Behavior with Type Assertions

```go
type Flusher interface {
    Flush() error
}

func WriteAndFlush(w io.Writer, data []byte) error {
    if _, err := w.Write(data); err != nil {
        return err
    }
    if f, ok := w.(Flusher); ok {
        return f.Flush()
    }
    return nil
}
```

---

## 8. Configuration

```go
// internal/config/config.go
type Config struct {
    Addr        string        `env:"ADDR"         envDefault:":8080"`
    DatabaseURL string        `env:"DATABASE_URL,required"`
    RedisURL    string        `env:"REDIS_URL"    envDefault:"redis://localhost:6379"`
    LogLevel    string        `env:"LOG_LEVEL"    envDefault:"info"`
    ReadTimeout time.Duration `env:"READ_TIMEOUT" envDefault:"5s"`
}

func MustLoad() *Config {
    var cfg Config
    if err := env.Parse(&cfg); err != nil {
        log.Fatalf("config: %v", err)
    }
    return &cfg
}
```

---

## 9. Database

### Repository Pattern with pgx

```go
type userRepository struct {
    db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) domain.UserRepository {
    return &userRepository{db: db}
}

func (r *userRepository) FindByID(ctx context.Context, id string) (*domain.User, error) {
    query := `SELECT id, email, first_name, last_name, created_at FROM users WHERE id = $1`
    var u domain.User
    err := r.db.QueryRow(ctx, query, id).Scan(&u.ID, &u.Email, &u.FirstName, &u.LastName, &u.CreatedAt)
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, fmt.Errorf("user %s: %w", id, domain.ErrNotFound)
    }
    if err != nil {
        return nil, fmt.Errorf("query user %s: %w", id, err)
    }
    return &u, nil
}

func (r *userRepository) Create(ctx context.Context, u *domain.User) error {
    query := `INSERT INTO users (id, email, first_name, last_name) VALUES ($1, $2, $3, $4)`
    _, err := r.db.Exec(ctx, query, u.ID, u.Email, u.FirstName, u.LastName)
    if err != nil {
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && pgErr.Code == "23505" {
            return fmt.Errorf("user %s: %w", u.Email, domain.ErrAlreadyExists)
        }
        return fmt.Errorf("insert user: %w", err)
    }
    return nil
}
```

### Transactions

```go
func (r *userRepository) TransferBalance(ctx context.Context, fromID, toID string, amount int64) error {
    tx, err := r.db.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin tx: %w", err)
    }
    defer tx.Rollback(ctx) //nolint:errcheck

    // Debit
    res, err := tx.Exec(ctx,
        `UPDATE wallets SET balance = balance - $1 WHERE user_id = $2 AND balance >= $1`,
        amount, fromID)
    if err != nil {
        return fmt.Errorf("debit: %w", err)
    }
    if res.RowsAffected() == 0 {
        return domain.ErrInsufficientBalance
    }

    // Credit
    _, err = tx.Exec(ctx,
        `UPDATE wallets SET balance = balance + $1 WHERE user_id = $2`,
        amount, toID)
    if err != nil {
        return fmt.Errorf("credit: %w", err)
    }

    if err := tx.Commit(ctx); err != nil {
        return fmt.Errorf("commit: %w", err)
    }
    return nil
}
```

---

## 10. Testing

### Table-Driven Tests

```go
func TestUserService_GetUser(t *testing.T) {
    tests := []struct {
        name    string
        id      string
        setup   func(repo *mocks.MockUserRepository)
        want    *domain.User
        wantErr error
    }{
        {
            name: "found",
            id:   "user-1",
            setup: func(repo *mocks.MockUserRepository) {
                repo.EXPECT().FindByID(gomock.Any(), "user-1").
                    Return(&domain.User{ID: "user-1", Email: "a@b.com"}, nil)
            },
            want: &domain.User{ID: "user-1", Email: "a@b.com"},
        },
        {
            name: "not found",
            id:   "missing",
            setup: func(repo *mocks.MockUserRepository) {
                repo.EXPECT().FindByID(gomock.Any(), "missing").
                    Return(nil, domain.ErrNotFound)
            },
            wantErr: domain.ErrNotFound,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            repo := mocks.NewMockUserRepository(ctrl)
            tt.setup(repo)

            svc := service.NewUserService(repo, nil, slog.Default())
            got, err := svc.GetUser(context.Background(), tt.id)

            if tt.wantErr != nil {
                assert.ErrorIs(t, err, tt.wantErr)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

### HTTP Handler Tests

```go
func TestUserHandler_Create(t *testing.T) {
    ctrl := gomock.NewController(t)
    svc := mocks.NewMockUserService(ctrl)

    svc.EXPECT().CreateUser(gomock.Any(), gomock.Any()).
        Return(&domain.User{ID: "new-1", Email: "a@b.com"}, nil)

    h := handler.NewUserHandler(svc, slog.Default())

    body := `{"email":"a@b.com","first_name":"Alice","last_name":"Smith"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    r := chi.NewRouter()
    h.Routes(r)
    r.ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)

    var resp handler.UserResponse
    json.NewDecoder(w.Body).Decode(&resp)
    assert.Equal(t, "new-1", resp.ID)
}
```

See `references/testing.md` for integration tests, benchmarks, and testcontainers patterns.

---

## 11. Logging (slog)

```go
// Structured logging with slog (stdlib, Go 1.21+)
log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

// Add persistent fields
log = log.With("service", "user-api", "version", version)

// In handlers — add request context
log.Info("user created",
    "user_id", user.ID,
    "email_domain", extractDomain(user.Email), // Never log full email (PII)
    "duration_ms", time.Since(start).Milliseconds(),
)

// Error with cause
log.Error("failed to create user",
    "error", err,
    "request_id", requestIDFromCtx(ctx),
)
```

**PII rules:** Never log full emails, phone numbers, tokens, or addresses. Use masked/domain-only values.

---

## 12. Graceful Shutdown

```go
func gracefulShutdown(srv *http.Server, log *slog.Logger) {
    go func() {
        log.Info("server starting", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            log.Error("server error", "error", err)
            os.Exit(1)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    sig := <-quit
    log.Info("shutting down", "signal", sig)

    ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Error("forced shutdown", "error", err)
    }
    log.Info("server stopped")
}
```

---

## 13. Memory & Performance

### sync.Pool for Frequent Allocations

```go
var bufPool = sync.Pool{
    New: func() any {
        return new(bytes.Buffer)
    },
}

func ProcessRequest(data []byte) []byte {
    buf := bufPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufPool.Put(buf)
    }()

    buf.Write(data)
    // Process...
    return bytes.Clone(buf.Bytes())
}
```

### String Building

```go
// BAD: O(n²) allocations in loop
var result string
for _, p := range parts {
    result += p + ","
}

// GOOD: Single allocation with strings.Builder
var sb strings.Builder
for i, p := range parts {
    if i > 0 {
        sb.WriteString(",")
    }
    sb.WriteString(p)
}
return sb.String()

// BEST: Use stdlib when it fits
return strings.Join(parts, ",")
```

### Slice/Map Pre-allocation

```go
// BAD: Grows multiple times
var results []Result
for _, item := range items {
    results = append(results, process(item))
}

// GOOD: Single allocation
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, process(item))
}
```

---

## 14. Tooling

```bash
# Essential pipeline
go build ./...
go test -race ./...
go vet ./...
gofmt -w .
goimports -w .

# Extended analysis
golangci-lint run
staticcheck ./...

# Module hygiene
go mod tidy
go mod verify
```

Recommended `.golangci.yml` linters: `errcheck`, `gosimple`, `govet` (with shadow check), `staticcheck`, `unused`, `gofmt`, `goimports`, `misspell`, `unconvert`, `unparam`. Enable `check-type-assertions: true` for errcheck.

---

## Quick Reference — Do/Don't

| Do | Don't |
|-----|-------|
| `errors.Is(err, ErrNotFound)` | `err.Error() == "not found"` |
| `fmt.Errorf("load user: %w", err)` | `fmt.Errorf("%w", err)` |
| `var mu sync.Mutex` | `mu := new(sync.Mutex)` |
| `make(map[K]V, hint)` | `map[K]V{}` without capacity |
| `make([]T, 0, cap)` | `append` without pre-allocation |
| `context.Context` as first param | Context in struct fields |
| `v, ok := x.(T)` | `v := x.(T)` (panics) |
| `strconv.Itoa(n)` | `fmt.Sprintf("%d", n)` |
| Named struct fields `{Name: "x"}` | Positional `{"x", 1}` |
| `var s Service` (zero value) | `s := Service{}` |
| Return `nil` slice | Return `[]T{}` |
| `errors.New("...")` sentinel | String comparison |
| Managed goroutine with WaitGroup | Fire-and-forget `go f()` |
| Channel size 0 or 1 | Arbitrary buffer `make(chan T, 100)` |
| `defer` outside loops | `defer` inside loops |
| Copy slices at API boundaries | Return internal slices |
| `strings.Builder` for concat | `+=` in loops (O(n²)) |
| `sync.Pool` for hot-path allocs | `new(T)` every request |
| Buffered chan + `select` ctx.Done | Unbuffered send (goroutine leak) |
