# Go Testing Patterns

## Table-Driven Tests (Gold Standard)

```go
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "valid integer", input: "100", want: 10000},
        {name: "valid decimal", input: "99.99", want: 9999},
        {name: "zero", input: "0", want: 0},
        {name: "negative", input: "-50", want: -5000},
        {name: "empty string", input: "", wantErr: true},
        {name: "not a number", input: "abc", wantErr: true},
        {name: "too many decimals", input: "1.999", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAmount(tt.input)
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

---

## HTTP Handler Tests with httptest

```go
func TestGetUser(t *testing.T) {
    tests := []struct {
        name       string
        userID     string
        setup      func(*mocks.MockUserService)
        wantStatus int
        wantBody   string
    }{
        {
            name:   "success",
            userID: "u-1",
            setup: func(svc *mocks.MockUserService) {
                svc.EXPECT().GetUser(gomock.Any(), "u-1").
                    Return(&domain.User{ID: "u-1", Email: "a@b.com"}, nil)
            },
            wantStatus: http.StatusOK,
            wantBody:   `"id":"u-1"`,
        },
        {
            name:   "not found",
            userID: "missing",
            setup: func(svc *mocks.MockUserService) {
                svc.EXPECT().GetUser(gomock.Any(), "missing").
                    Return(nil, domain.ErrNotFound)
            },
            wantStatus: http.StatusNotFound,
        },
        {
            name:   "internal error",
            userID: "u-1",
            setup: func(svc *mocks.MockUserService) {
                svc.EXPECT().GetUser(gomock.Any(), "u-1").
                    Return(nil, errors.New("db down"))
            },
            wantStatus: http.StatusInternalServerError,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            svc := mocks.NewMockUserService(ctrl)
            tt.setup(svc)

            h := handler.NewUserHandler(svc, slog.Default())
            r := chi.NewRouter()
            h.Routes(r)

            req := httptest.NewRequest(http.MethodGet, "/users/"+tt.userID, nil)
            w := httptest.NewRecorder()
            r.ServeHTTP(w, req)

            assert.Equal(t, tt.wantStatus, w.Code)
            if tt.wantBody != "" {
                assert.Contains(t, w.Body.String(), tt.wantBody)
            }
        })
    }
}
```

---

## Integration Tests with testcontainers

```go
func TestUserRepository_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    ctx := context.Background()

    // Start PostgreSQL container
    pgContainer, err := postgres.Run(ctx,
        "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections").
                WithOccurrence(2).
                WithStartupTimeout(30*time.Second),
        ),
    )
    require.NoError(t, err)
    defer pgContainer.Terminate(ctx) //nolint:errcheck

    connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
    require.NoError(t, err)

    // Run migrations
    db, err := pgxpool.New(ctx, connStr)
    require.NoError(t, err)
    defer db.Close()

    runMigrations(t, connStr)

    repo := pgstore.NewUserRepository(db)

    t.Run("create and find", func(t *testing.T) {
        user := &domain.User{
            ID:        "u-1",
            Email:     "test@example.com",
            FirstName: "Alice",
            LastName:  "Smith",
        }

        err := repo.Create(ctx, user)
        require.NoError(t, err)

        found, err := repo.FindByID(ctx, "u-1")
        require.NoError(t, err)
        assert.Equal(t, user.Email, found.Email)
        assert.Equal(t, user.FirstName, found.FirstName)
    })

    t.Run("duplicate email", func(t *testing.T) {
        user := &domain.User{
            ID:    "u-2",
            Email: "test@example.com", // Same email as above
        }
        err := repo.Create(ctx, user)
        assert.ErrorIs(t, err, domain.ErrAlreadyExists)
    })

    t.Run("not found", func(t *testing.T) {
        _, err := repo.FindByID(ctx, "nonexistent")
        assert.ErrorIs(t, err, domain.ErrNotFound)
    })
}
```

---

## Mock Generation

```go
// Generate mocks with mockgen
//go:generate mockgen -source=../../domain/repository.go -destination=./mock_repository.go -package=mocks
//go:generate mockgen -source=../../domain/service.go -destination=./mock_service.go -package=mocks

// Alternative: interface-based (no source file needed)
//go:generate mockgen -destination=./mock_cache.go -package=mocks github.com/myorg/myservice/internal/domain CacheClient
```

---

## Test Helpers

```go
// testutil/helpers.go
package testutil

// MustJSON serializes to JSON or panics (test-only)
func MustJSON(t *testing.T, v any) string {
    t.Helper()
    b, err := json.Marshal(v)
    require.NoError(t, err)
    return string(b)
}

// NewRequest creates an authenticated test request
func NewRequest(t *testing.T, method, path string, body any, userID string) *http.Request {
    t.Helper()
    var reader io.Reader
    if body != nil {
        b, err := json.Marshal(body)
        require.NoError(t, err)
        reader = bytes.NewReader(b)
    }
    req := httptest.NewRequest(method, path, reader)
    req.Header.Set("Content-Type", "application/json")
    if userID != "" {
        ctx := context.WithValue(req.Context(), domain.UserIDKey, userID)
        req = req.WithContext(ctx)
    }
    return req
}

// AssertJSON asserts JSON response body fields
func AssertJSON(t *testing.T, w *httptest.ResponseRecorder, key, expected string) {
    t.Helper()
    var result map[string]any
    err := json.NewDecoder(w.Body).Decode(&result)
    require.NoError(t, err)
    assert.Equal(t, expected, fmt.Sprint(result[key]))
}
```

---

## Benchmarks

```go
func BenchmarkUserService_GetUser(b *testing.B) {
    ctrl := gomock.NewController(b)
    repo := mocks.NewMockUserRepository(ctrl)
    repo.EXPECT().FindByID(gomock.Any(), "u-1").
        Return(&domain.User{ID: "u-1"}, nil).
        AnyTimes()

    svc := service.NewUserService(repo, nil, slog.Default())
    ctx := context.Background()

    b.ResetTimer()
    for range b.N {
        svc.GetUser(ctx, "u-1") //nolint:errcheck
    }
}

func BenchmarkParseAmount(b *testing.B) {
    inputs := []string{"100.50", "0.01", "99999.99", "0"}

    for _, input := range inputs {
        b.Run(input, func(b *testing.B) {
            for range b.N {
                ParseAmount(input) //nolint:errcheck
            }
        })
    }
}
```

---

## Test Fixtures with Golden Files

```go
func TestRenderTemplate(t *testing.T) {
    got := renderTemplate(data)

    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        os.WriteFile(golden, []byte(got), 0644) //nolint:errcheck
        return
    }

    expected, err := os.ReadFile(golden)
    require.NoError(t, err)
    assert.Equal(t, string(expected), got)
}

// Run with: go test -update to regenerate golden files
var update = flag.Bool("update", false, "update golden files")
```

---

## Testing Anti-patterns

```go
// BAD: Testing implementation details
func TestService_calls_repo(t *testing.T) {
    repo.EXPECT().FindByID(gomock.Any(), "1").Times(1) // Brittle
}

// GOOD: Test behavior
func TestService_returns_user(t *testing.T) {
    // Setup returns
    got, err := svc.GetUser(ctx, "1")
    assert.NoError(t, err)
    assert.Equal(t, "1", got.ID) // Test the result
}

// BAD: Shared mutable state between tests
var globalDB *sql.DB // Race condition

// GOOD: Per-test setup
func TestFoo(t *testing.T) {
    db := setupTestDB(t)
    // ...
}

// BAD: Sleep in tests
time.Sleep(100 * time.Millisecond)

// GOOD: Use channels, waitgroups, or require.Eventually
require.Eventually(t, func() bool {
    return checkCondition()
}, 5*time.Second, 50*time.Millisecond)

// BAD: Ignoring t.Helper()
func assertEqual(t *testing.T, got, want any) {
    // Missing t.Helper() — error reports this line, not caller
}

// GOOD: Always call t.Helper() in test helpers
func assertEqual(t *testing.T, got, want any) {
    t.Helper()
    assert.Equal(t, want, got)
}
```
