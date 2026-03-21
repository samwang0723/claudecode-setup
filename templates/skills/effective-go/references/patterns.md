# Go Advanced Patterns

## Graceful Shutdown with Multiple Services

```go
func run(ctx context.Context, cfg *Config, log *slog.Logger) error {
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()

    db, err := pgxpool.New(ctx, cfg.DatabaseURL)
    if err != nil {
        return fmt.Errorf("connect db: %w", err)
    }
    defer db.Close()

    // Build services
    userRepo := postgres.NewUserRepository(db)
    userSvc := service.NewUserService(userRepo, log)
    handler := handler.NewUserHandler(userSvc, log)

    // HTTP server
    srv := &http.Server{
        Addr:         cfg.Addr,
        Handler:      handler.Router(),
        ReadTimeout:  cfg.ReadTimeout,
        WriteTimeout: cfg.WriteTimeout,
        IdleTimeout:  cfg.IdleTimeout,
    }

    // Start background workers
    g, ctx := errgroup.WithContext(ctx)

    g.Go(func() error {
        log.Info("http server starting", "addr", cfg.Addr)
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            return fmt.Errorf("http server: %w", err)
        }
        return nil
    })

    g.Go(func() error {
        <-ctx.Done()
        shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
        defer shutdownCancel()
        return srv.Shutdown(shutdownCtx)
    })

    // Signal handler
    g.Go(func() error {
        quit := make(chan os.Signal, 1)
        signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
        select {
        case sig := <-quit:
            log.Info("received signal", "signal", sig)
            cancel()
        case <-ctx.Done():
        }
        return nil
    })

    return g.Wait()
}

func main() {
    cfg := config.MustLoad()
    log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

    if err := run(context.Background(), cfg, log); err != nil {
        log.Error("fatal", "error", err)
        os.Exit(1)
    }
}
```

---

## Worker Pool with Rate Limiting

```go
type WorkerPool struct {
    workers int
    limiter *rate.Limiter
    log     *slog.Logger
}

func NewWorkerPool(workers int, rps float64, log *slog.Logger) *WorkerPool {
    return &WorkerPool{
        workers: workers,
        limiter: rate.NewLimiter(rate.Limit(rps), int(rps)),
        log:     log,
    }
}

func (p *WorkerPool) Process(ctx context.Context, jobs <-chan Job) error {
    g, ctx := errgroup.WithContext(ctx)

    for range p.workers {
        g.Go(func() error {
            for {
                select {
                case <-ctx.Done():
                    return ctx.Err()
                case job, ok := <-jobs:
                    if !ok {
                        return nil
                    }
                    if err := p.limiter.Wait(ctx); err != nil {
                        return fmt.Errorf("rate limit: %w", err)
                    }
                    if err := job.Execute(ctx); err != nil {
                        p.log.Error("job failed",
                            "job_id", job.ID,
                            "error", err,
                        )
                        // Continue processing — don't fail the pool
                    }
                }
            }
        })
    }

    return g.Wait()
}
```

---

## Circuit Breaker

```go
type CircuitBreaker struct {
    mu          sync.Mutex
    failures    int
    threshold   int
    resetAfter  time.Duration
    lastFailure time.Time
    state       string // "closed", "open", "half-open"
}

func NewCircuitBreaker(threshold int, resetAfter time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        threshold:  threshold,
        resetAfter: resetAfter,
        state:      "closed",
    }
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
    cb.mu.Lock()
    if cb.state == "open" {
        if time.Since(cb.lastFailure) > cb.resetAfter {
            cb.state = "half-open"
        } else {
            cb.mu.Unlock()
            return errors.New("circuit breaker open")
        }
    }
    cb.mu.Unlock()

    err := fn()

    cb.mu.Lock()
    defer cb.mu.Unlock()

    if err != nil {
        cb.failures++
        cb.lastFailure = time.Now()
        if cb.failures >= cb.threshold {
            cb.state = "open"
        }
        return err
    }

    cb.failures = 0
    cb.state = "closed"
    return nil
}
```

---

## Retry with Exponential Backoff

```go
type RetryConfig struct {
    MaxAttempts int
    BaseDelay   time.Duration
    MaxDelay    time.Duration
}

func Retry(ctx context.Context, cfg RetryConfig, fn func() error) error {
    var lastErr error
    for attempt := range cfg.MaxAttempts {
        lastErr = fn()
        if lastErr == nil {
            return nil
        }

        // Don't retry non-retryable errors
        var nonRetryable *NonRetryableError
        if errors.As(lastErr, &nonRetryable) {
            return lastErr
        }

        if attempt == cfg.MaxAttempts-1 {
            break
        }

        delay := cfg.BaseDelay * time.Duration(1<<uint(attempt))
        if delay > cfg.MaxDelay {
            delay = cfg.MaxDelay
        }

        // Add jitter (0-25%)
        jitter := time.Duration(rand.Int64N(int64(delay) / 4))
        delay += jitter

        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(delay):
        }
    }
    return fmt.Errorf("max retries exceeded: %w", lastErr)
}
```

---

## Options Pattern (Functional Options)

```go
type Server struct {
    addr         string
    readTimeout  time.Duration
    writeTimeout time.Duration
    maxConns     int
    logger       *slog.Logger
}

type Option func(*Server)

func WithAddr(addr string) Option {
    return func(s *Server) { s.addr = addr }
}

func WithTimeouts(read, write time.Duration) Option {
    return func(s *Server) {
        s.readTimeout = read
        s.writeTimeout = write
    }
}

func WithMaxConns(n int) Option {
    return func(s *Server) { s.maxConns = n }
}

func WithLogger(log *slog.Logger) Option {
    return func(s *Server) { s.logger = log }
}

func NewServer(opts ...Option) *Server {
    s := &Server{
        addr:         ":8080",
        readTimeout:  5 * time.Second,
        writeTimeout: 10 * time.Second,
        maxConns:     100,
        logger:       slog.Default(),
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
srv := NewServer(
    WithAddr(":9090"),
    WithTimeouts(10*time.Second, 30*time.Second),
    WithLogger(myLogger),
)
```

---

## gRPC Service Pattern

```go
// Proto definition (api/user/v1/user.proto)
// service UserService {
//   rpc GetUser(GetUserRequest) returns (GetUserResponse);
//   rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
// }

// Server implementation
type userServer struct {
    pb.UnimplementedUserServiceServer
    svc domain.UserService
    log *slog.Logger
}

func NewUserServer(svc domain.UserService, log *slog.Logger) pb.UserServiceServer {
    return &userServer{svc: svc, log: log}
}

func (s *userServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.GetUserResponse, error) {
    if req.GetId() == "" {
        return nil, status.Error(codes.InvalidArgument, "id is required")
    }

    user, err := s.svc.GetUser(ctx, req.GetId())
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrNotFound):
            return nil, status.Error(codes.NotFound, "user not found")
        default:
            s.log.Error("get user", "error", err)
            return nil, status.Error(codes.Internal, "internal error")
        }
    }

    return &pb.GetUserResponse{
        User: &pb.User{
            Id:    user.ID,
            Email: user.Email,
            Name:  user.FirstName + " " + user.LastName,
        },
    }, nil
}
```

### gRPC Interceptors

```go
// Logging interceptor
func LoggingInterceptor(log *slog.Logger) grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
        start := time.Now()
        resp, err := handler(ctx, req)
        duration := time.Since(start)

        code := status.Code(err)
        log.Info("grpc request",
            "method", info.FullMethod,
            "code", code.String(),
            "duration_ms", duration.Milliseconds(),
        )

        return resp, err
    }
}

// Recovery interceptor
func RecoveryInterceptor(log *slog.Logger) grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
        defer func() {
            if r := recover(); r != nil {
                log.Error("grpc panic", "panic", r, "stack", string(debug.Stack()))
                err = status.Error(codes.Internal, "internal error")
            }
        }()
        return handler(ctx, req)
    }
}
```

---

## Pagination Pattern

```go
type PageRequest struct {
    Cursor string
    Limit  int
}

type PageResponse[T any] struct {
    Items      []T    `json:"items"`
    NextCursor string `json:"next_cursor,omitempty"`
    HasMore    bool   `json:"has_more"`
}

func (r *userRepository) List(ctx context.Context, page PageRequest) (*PageResponse[domain.User], error) {
    if page.Limit <= 0 || page.Limit > 100 {
        page.Limit = 20
    }

    // Fetch one extra to determine if there are more
    fetchLimit := page.Limit + 1

    var args []any
    query := `SELECT id, email, first_name, created_at FROM users`

    if page.Cursor != "" {
        query += ` WHERE id > $1 ORDER BY id LIMIT $2`
        args = append(args, page.Cursor, fetchLimit)
    } else {
        query += ` ORDER BY id LIMIT $1`
        args = append(args, fetchLimit)
    }

    rows, err := r.db.Query(ctx, query, args...)
    if err != nil {
        return nil, fmt.Errorf("list users: %w", err)
    }
    defer rows.Close()

    users, err := pgx.CollectRows(rows, pgx.RowToStructByName[domain.User])
    if err != nil {
        return nil, fmt.Errorf("scan users: %w", err)
    }

    hasMore := len(users) > page.Limit
    if hasMore {
        users = users[:page.Limit]
    }

    var nextCursor string
    if hasMore && len(users) > 0 {
        nextCursor = users[len(users)-1].ID
    }

    return &PageResponse[domain.User]{
        Items:      users,
        NextCursor: nextCursor,
        HasMore:    hasMore,
    }, nil
}
```

---

## Health Check Endpoint

```go
type HealthChecker struct {
    db    *pgxpool.Pool
    redis *redis.Client
}

type HealthStatus struct {
    Status string            `json:"status"`
    Checks map[string]string `json:"checks"`
}

func (h *HealthChecker) Handler() http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
        defer cancel()

        checks := make(map[string]string)
        healthy := true

        // Database
        if err := h.db.Ping(ctx); err != nil {
            checks["database"] = "unhealthy: " + err.Error()
            healthy = false
        } else {
            checks["database"] = "ok"
        }

        // Redis
        if err := h.redis.Ping(ctx).Err(); err != nil {
            checks["redis"] = "unhealthy: " + err.Error()
            healthy = false
        } else {
            checks["redis"] = "ok"
        }

        status := HealthStatus{Status: "ok", Checks: checks}
        code := http.StatusOK
        if !healthy {
            status.Status = "degraded"
            code = http.StatusServiceUnavailable
        }

        writeJSON(w, code, status)
    }
}
```

---

## Middleware Chain Pattern

```go
// Composable middleware ordering
func BuildRouter(h *Handler, log *slog.Logger, auth AuthMiddleware) chi.Router {
    r := chi.NewRouter()

    // Global middleware (order matters)
    r.Use(RequestIDMiddleware)              // 1. Assign request ID
    r.Use(middleware.RealIP)                // 2. Extract real IP
    r.Use(RecoveryMiddleware(log))          // 3. Catch panics
    r.Use(LoggingMiddleware(log))           // 4. Log requests
    r.Use(middleware.Timeout(30*time.Second)) // 5. Request timeout
    r.Use(CORSMiddleware)                  // 6. CORS headers

    // Public routes
    r.Get("/health", healthCheck.Handler())
    r.Post("/auth/login", h.Login)

    // Protected routes
    r.Group(func(r chi.Router) {
        r.Use(auth.Authenticate)           // JWT validation
        r.Use(auth.RequireRole("user"))    // Role check

        h.UserRoutes(r)
        h.OrderRoutes(r)
    })

    // Admin routes
    r.Group(func(r chi.Router) {
        r.Use(auth.Authenticate)
        r.Use(auth.RequireRole("admin"))

        h.AdminRoutes(r)
    })

    return r
}
```

---

## Repository with Generics (Go 1.18+)

```go
type Repository[T any] interface {
    FindByID(ctx context.Context, id string) (*T, error)
    Create(ctx context.Context, entity *T) error
    Update(ctx context.Context, entity *T) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, page PageRequest) (*PageResponse[T], error)
}

// Base implementation with pgx
type baseRepo[T any] struct {
    db    *pgxpool.Pool
    table string
}

func (r *baseRepo[T]) FindByID(ctx context.Context, id string) (*T, error) {
    query := fmt.Sprintf("SELECT * FROM %s WHERE id = $1", r.table)
    rows, err := r.db.Query(ctx, query, id)
    if err != nil {
        return nil, fmt.Errorf("query %s: %w", r.table, err)
    }
    entity, err := pgx.CollectOneRow(rows, pgx.RowToAddrOfStructByName[T])
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, fmt.Errorf("%s %s: %w", r.table, id, domain.ErrNotFound)
    }
    return entity, err
}
```
