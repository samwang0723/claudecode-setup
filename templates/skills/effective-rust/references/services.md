# Rust Production Service Patterns

## Project Layout (Axum Service)

```
service/
  src/
    main.rs              # Entrypoint: load config, build app, run
    lib.rs               # AppState, router builder
    config.rs            # Environment-based config
    error.rs             # AppError type, IntoResponse impl
    domain/
      mod.rs
      user.rs            # Domain types (no framework deps)
    handler/
      mod.rs
      user_handler.rs    # Axum handlers
    service/
      mod.rs
      user_service.rs    # Business logic
    repository/
      mod.rs
      user_repo.rs       # Database access (sqlx)
    middleware/
      mod.rs
      auth.rs            # JWT extraction
      logging.rs         # Request/response tracing
  migrations/            # sqlx migrations
  Cargo.toml
  clippy.toml
  rustfmt.toml
```

---

## Application Error Type

```rust
// src/error.rs
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("already exists: {0}")]
    AlreadyExists(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("unauthorized")]
    Unauthorized,

    #[error("forbidden")]
    Forbidden,

    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    details: Option<String>,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            Self::NotFound(msg) => (StatusCode::NOT_FOUND, msg.clone()),
            Self::AlreadyExists(msg) => (StatusCode::CONFLICT, msg.clone()),
            Self::InvalidInput(msg) => (StatusCode::UNPROCESSABLE_ENTITY, msg.clone()),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized".into()),
            Self::Forbidden => (StatusCode::FORBIDDEN, "forbidden".into()),
            Self::Internal(err) => {
                tracing::error!(error = %err, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
        };

        (status, Json(ErrorBody { error: message, details: None })).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
```

---

## Axum Handler Pattern

```rust
// src/handler/user_handler.rs
use axum::{
    extract::{Path, State, Json},
    http::StatusCode,
    routing::{get, post},
    Router,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/users", post(create_user))
        .route("/users/{id}", get(get_user).put(update_user))
}

#[derive(Debug, Deserialize, Validate)]
struct CreateUserRequest {
    #[validate(email)]
    email: String,
    #[validate(length(min = 1, max = 100))]
    first_name: String,
    #[validate(length(min = 1, max = 100))]
    last_name: String,
}

#[derive(Serialize)]
struct UserResponse {
    id: String,
    email: String,
    first_name: String,
    last_name: String,
    created_at: String,
}

async fn create_user(
    State(state): State<AppState>,
    Json(req): Json<CreateUserRequest>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    req.validate()
        .map_err(|e| AppError::InvalidInput(e.to_string()))?;

    let user = state.user_service
        .create_user(CreateUserParams {
            email: req.email,
            first_name: req.first_name,
            last_name: req.last_name,
        })
        .await?;

    Ok((StatusCode::CREATED, Json(user.into())))
}

async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<UserResponse>> {
    let user = state.user_service
        .get_user(&id)
        .await?;

    Ok(Json(user.into()))
}
```

---

## Application State and Wiring

```rust
// src/lib.rs
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub user_service: Arc<dyn UserService>,
    pub db: PgPool,
}

pub fn build_router(state: AppState) -> Router {
    Router::new()
        .merge(handler::user_handler::routes())
        .route("/health", get(health_check))
        .layer(TraceLayer::new_for_http())
        .layer(TimeoutLayer::new(Duration::from_secs(30)))
        .with_state(state)
}

async fn health_check(State(state): State<AppState>) -> impl IntoResponse {
    match sqlx::query("SELECT 1").execute(&state.db).await {
        Ok(_) => (StatusCode::OK, Json(serde_json::json!({"status": "ok"}))),
        Err(_) => (StatusCode::SERVICE_UNAVAILABLE, Json(serde_json::json!({"status": "unhealthy"}))),
    }
}

// src/main.rs
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Tracing
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let config = Config::from_env()
        .context("failed to load config")?;

    let db = PgPoolOptions::new()
        .max_connections(config.db_pool_size)
        .connect(&config.database_url)
        .await
        .context("failed to connect to database")?;

    sqlx::migrate!()
        .run(&db)
        .await
        .context("failed to run migrations")?;

    let user_repo = Arc::new(PgUserRepository::new(db.clone()));
    let user_service = Arc::new(UserServiceImpl::new(user_repo));

    let state = AppState { user_service, db };
    let app = build_router(state);

    let listener = TcpListener::bind(&config.addr)
        .await
        .context("failed to bind")?;

    tracing::info!(addr = %config.addr, "server starting");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .context("server error")?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = tokio::signal::ctrl_c();
    let mut sigterm = tokio::signal::unix::signal(SignalKind::terminate())
        .expect("failed to register SIGTERM");

    tokio::select! {
        _ = ctrl_c => tracing::info!("received SIGINT"),
        _ = sigterm.recv() => tracing::info!("received SIGTERM"),
    }
}
```

---

## Configuration

```rust
// src/config.rs
#[derive(Debug)]
pub struct Config {
    pub addr: String,
    pub database_url: String,
    pub db_pool_size: u32,
    pub redis_url: String,
    pub log_level: String,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            addr: std::env::var("ADDR").unwrap_or_else(|_| "0.0.0.0:8080".into()),
            database_url: std::env::var("DATABASE_URL")
                .context("DATABASE_URL is required")?,
            db_pool_size: std::env::var("DB_POOL_SIZE")
                .unwrap_or_else(|_| "10".into())
                .parse()
                .context("DB_POOL_SIZE must be a number")?,
            redis_url: std::env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://localhost:6379".into()),
            log_level: std::env::var("LOG_LEVEL")
                .unwrap_or_else(|_| "info".into()),
        })
    }
}
```

---

## Repository with sqlx

```rust
// src/repository/user_repo.rs
pub struct PgUserRepository {
    db: PgPool,
}

impl PgUserRepository {
    pub fn new(db: PgPool) -> Self {
        Self { db }
    }
}

#[async_trait]
impl UserRepository for PgUserRepository {
    async fn find_by_id(&self, id: &str) -> AppResult<User> {
        sqlx::query_as!(
            User,
            r#"SELECT id, email, first_name, last_name, created_at FROM users WHERE id = $1"#,
            id
        )
        .fetch_optional(&self.db)
        .await
        .context("query user")?
        .ok_or_else(|| AppError::NotFound(format!("user {id}")))
    }

    async fn create(&self, user: &User) -> AppResult<()> {
        sqlx::query!(
            r#"INSERT INTO users (id, email, first_name, last_name) VALUES ($1, $2, $3, $4)"#,
            user.id,
            user.email,
            user.first_name,
            user.last_name,
        )
        .execute(&self.db)
        .await
        .map_err(|e| match e {
            sqlx::Error::Database(ref db_err) if db_err.constraint() == Some("users_email_key") => {
                AppError::AlreadyExists(format!("email {}", user.email))
            }
            _ => AppError::Internal(e.into()),
        })?;

        Ok(())
    }

    async fn list(&self, cursor: Option<&str>, limit: i64) -> AppResult<Vec<User>> {
        let users = match cursor {
            Some(c) => {
                sqlx::query_as!(
                    User,
                    r#"SELECT id, email, first_name, last_name, created_at
                       FROM users WHERE id > $1 ORDER BY id LIMIT $2"#,
                    c, limit
                )
                .fetch_all(&self.db)
                .await
                .context("list users")?
            }
            None => {
                sqlx::query_as!(
                    User,
                    r#"SELECT id, email, first_name, last_name, created_at
                       FROM users ORDER BY id LIMIT $1"#,
                    limit
                )
                .fetch_all(&self.db)
                .await
                .context("list users")?
            }
        };

        Ok(users)
    }
}
```

### Transactions

```rust
async fn transfer_balance(
    db: &PgPool,
    from_id: &str,
    to_id: &str,
    amount: i64,
) -> AppResult<()> {
    let mut tx = db.begin().await.context("begin tx")?;

    let rows = sqlx::query!(
        "UPDATE wallets SET balance = balance - $1 WHERE user_id = $2 AND balance >= $1",
        amount, from_id
    )
    .execute(&mut *tx)
    .await
    .context("debit")?
    .rows_affected();

    if rows == 0 {
        return Err(AppError::InvalidInput("insufficient balance".into()));
    }

    sqlx::query!(
        "UPDATE wallets SET balance = balance + $1 WHERE user_id = $2",
        amount, to_id
    )
    .execute(&mut *tx)
    .await
    .context("credit")?;

    tx.commit().await.context("commit")?;
    Ok(())
}
```

---

## Middleware — Auth Extraction

```rust
use axum::extract::FromRequestParts;
use axum::http::request::Parts;

pub struct AuthUser {
    pub id: String,
    pub roles: Vec<String>,
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let token = parts.headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Unauthorized)?;

        let claims = decode_jwt(token)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(AuthUser {
            id: claims.sub,
            roles: claims.roles,
        })
    }
}

// Usage in handler — just add AuthUser parameter
async fn get_profile(
    auth: AuthUser,
    State(state): State<AppState>,
) -> AppResult<Json<UserResponse>> {
    let user = state.user_service.get_user(&auth.id).await?;
    Ok(Json(user.into()))
}
```

---

## Testing Axum Handlers

```rust
#[cfg(test)]
mod tests {
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt; // for `oneshot`

    #[tokio::test]
    async fn test_create_user() {
        let app = build_test_app().await;

        let body = serde_json::json!({
            "email": "test@example.com",
            "first_name": "Alice",
            "last_name": "Smith"
        });

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/users")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&body).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::CREATED);

        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        let user: UserResponse = serde_json::from_slice(&body).unwrap();
        assert_eq!(user.email, "test@example.com");
    }

    #[tokio::test]
    async fn test_get_user_not_found() {
        let app = build_test_app().await;

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/users/nonexistent")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    async fn build_test_app() -> Router {
        // Use testcontainers or mock services
        let db = setup_test_db().await;
        let user_repo = Arc::new(PgUserRepository::new(db.clone()));
        let user_service = Arc::new(UserServiceImpl::new(user_repo));
        let state = AppState { user_service, db };
        build_router(state)
    }
}
```

---

## Structured Logging with tracing

```rust
use tracing::{info, error, warn, instrument};

#[instrument(skip(self), fields(user_id = %id))]
async fn get_user(&self, id: &str) -> AppResult<User> {
    let user = self.repo.find_by_id(id).await?;
    info!(email_domain = %extract_domain(&user.email), "user found");
    Ok(user)
}

// Request tracing layer
use tower_http::trace::TraceLayer;

let app = Router::new()
    .merge(routes())
    .layer(
        TraceLayer::new_for_http()
            .make_span_with(|request: &Request<Body>| {
                tracing::info_span!(
                    "http_request",
                    method = %request.method(),
                    uri = %request.uri(),
                    request_id = %uuid::Uuid::new_v4(),
                )
            })
    );
```
