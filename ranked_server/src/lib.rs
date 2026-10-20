mod auth;
mod compat;
mod model;
pub mod rules;
mod store;

use axum::{
    Extension, Json, Router,
    body::{Body, to_bytes},
    extract::{ConnectInfo, FromRequest, Path, Query, Request, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use model::*;
use rusqlite::{Connection, OptionalExtension};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use std::{
    borrow::Cow,
    net::{IpAddr, SocketAddr},
    path::PathBuf,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

pub type Result<T, E = ApiError> = std::result::Result<T, E>;
pub type Clock = Arc<dyn Fn() -> f64 + Send + Sync>;
const MAX_BODY: usize = 262144;

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    detail: Cow<'static, str>,
}

impl ApiError {
    pub(crate) fn new(status: StatusCode, detail: impl Into<Cow<'static, str>>) -> Self {
        Self {
            status,
            detail: detail.into(),
        }
    }
    pub(crate) fn invalid(detail: impl Into<Cow<'static, str>>) -> Self {
        Self::new(StatusCode::UNPROCESSABLE_ENTITY, detail)
    }
    pub(crate) fn internal() -> Self {
        Self::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "Ranked service could not complete this request",
        )
    }
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.detail.fmt(f)
    }
}
impl std::error::Error for ApiError {}

impl From<rusqlite::Error> for ApiError {
    fn from(error: rusqlite::Error) -> Self {
        eprintln!("Ranked database error: {error}");
        Self::internal()
    }
}
impl From<serde_json::Error> for ApiError {
    fn from(error: serde_json::Error) -> Self {
        eprintln!("Ranked persisted data error: {error}");
        Self::internal()
    }
}
impl From<std::io::Error> for ApiError {
    fn from(error: std::io::Error) -> Self {
        eprintln!("Ranked I/O error: {error}");
        Self::internal()
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        #[derive(Serialize)]
        struct Problem {
            detail: Cow<'static, str>,
        }
        (
            self.status,
            Json(Problem {
                detail: self.detail,
            }),
        )
            .into_response()
    }
}

#[derive(Clone)]
pub struct Config {
    pub database: PathBuf,
    pub require_tls: bool,
    pub trust_proxy: bool,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        fn boolean(name: &str, default: bool) -> Result<bool> {
            match std::env::var(name) {
                Ok(value) if value == "true" => Ok(true),
                Ok(value) if value == "false" => Ok(false),
                Ok(_) => Err(ApiError::new(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("{name} must be true or false"),
                )),
                Err(std::env::VarError::NotPresent) => Ok(default),
                Err(_) => Err(ApiError::new(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("{name} is not valid text"),
                )),
            }
        }
        Ok(Self {
            database: std::env::var_os("RANKED_DATABASE")
                .map(PathBuf::from)
                .unwrap_or_else(|| "ranked.sqlite3".into()),
            require_tls: boolean("RANKED_REQUIRE_TLS", true)?,
            trust_proxy: boolean("RANKED_TRUST_PROXY", false)?,
        })
    }
}

#[derive(Clone)]
pub struct AppState {
    pub(crate) db: store::Database,
    clock: Clock,
    require_tls: bool,
    trust_proxy: bool,
    passwords: auth::PasswordWork,
}

impl AppState {
    pub async fn open(config: Config) -> Result<Self> {
        Self::with_clock(
            config,
            Arc::new(|| {
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .expect("system clock precedes Unix epoch")
                    .as_secs_f64()
            }),
        )
        .await
    }

    pub async fn with_clock(config: Config, clock: Clock) -> Result<Self> {
        let Config {
            database,
            require_tls,
            trust_proxy,
        } = config;
        let db = store::Database::open(database).await?;
        let passwords = auth::PasswordWork::new().await?;
        Ok(Self {
            db,
            clock,
            require_tls,
            trust_proxy,
            passwords,
        })
    }

    pub async fn tick(&self) -> Result<()> {
        let clock = self.clock.clone();
        self.db
            .call(move |db| {
                let time = clock();
                store::sweep(db, time)?;
                store::pair(db, time)
            })
            .await
    }

    async fn authenticated<T, F>(&self, headers: &HeaderMap, operation: F) -> Result<T>
    where
        T: Send + 'static,
        F: FnOnce(&Connection, &str, f64) -> Result<T> + Send + 'static,
    {
        let access = access_hash(headers)?;
        let clock = self.clock.clone();
        self.db
            .call(move |db| {
                let time = clock();
                let uid = store::authenticated(db, &access, time)?;
                operation(db, &uid, time)
            })
            .await
    }
}

fn access_hash(headers: &HeaderMap) -> Result<String> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "))
        .map(auth::digest)
        .ok_or_else(|| ApiError::new(StatusCode::UNAUTHORIZED, "Sign in to Ranked"))
}

struct Input<T>(T);
impl<S, T> FromRequest<S> for Input<T>
where
    S: Send + Sync,
    T: DeserializeOwned + Validate,
{
    type Rejection = ApiError;
    async fn from_request(request: Request, state: &S) -> Result<Self> {
        let Json(mut value) = Json::<T>::from_request(request, state)
            .await
            .map_err(|error| {
                if error.status() == StatusCode::PAYLOAD_TOO_LARGE {
                    ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "Request too large")
                } else {
                    ApiError::invalid("Invalid request data")
                }
            })?;
        value.validate()?;
        Ok(Self(value))
    }
}

#[derive(Clone, Copy)]
struct ClientAddress(Option<IpAddr>);

async fn boundary(State(state): State<AppState>, mut request: Request, next: Next) -> Response {
    let checked = (async {
        let proxy_https = state.trust_proxy
            && request
                .headers()
                .get("x-forwarded-proto")
                .is_some_and(|value| value == "https");
        if state.require_tls && !proxy_https {
            return Err(ApiError::new(
                StatusCode::UPGRADE_REQUIRED,
                "HTTPS required",
            ));
        }
        if let Some(length) = request.headers().get(header::CONTENT_LENGTH) {
            let length = length
                .to_str()
                .map_err(|_| ApiError::new(StatusCode::BAD_REQUEST, "Invalid content length"))?;
            if length.is_empty() || !length.bytes().all(|b| b.is_ascii_digit()) {
                return Err(ApiError::new(
                    StatusCode::BAD_REQUEST,
                    "Invalid content length",
                ));
            }
            if length.len() > 9 || length.parse::<usize>().map_or(true, |n| n > MAX_BODY) {
                return Err(ApiError::new(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "Request too large",
                ));
            }
        }
        let peer = request
            .extensions()
            .get::<ConnectInfo<SocketAddr>>()
            .map(|p| p.0.ip());
        let forwarded = if state.trust_proxy {
            request
                .headers()
                .get("x-forwarded-for")
                .and_then(|h| h.to_str().ok())
                .and_then(|h| h.rsplit(',').next())
                .and_then(|h| h.trim().parse::<IpAddr>().ok())
        } else {
            None
        };
        request
            .extensions_mut()
            .insert(ClientAddress(forwarded.or(peer)));
        if request.method() == Method::POST {
            let (parts, body) = request.into_parts();
            let bytes = to_bytes(body, MAX_BODY)
                .await
                .map_err(|_| ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "Request too large"))?;
            request = Request::from_parts(parts, Body::from(bytes));
        }
        Ok(request)
    })
    .await;
    let mut response = match checked {
        Ok(request) => next.run(request).await,
        Err(error) => error.into_response(),
    };
    response
        .headers_mut()
        .insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    response.headers_mut().insert(
        header::X_CONTENT_TYPE_OPTIONS,
        HeaderValue::from_static("nosniff"),
    );
    response
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/catalog", get(catalog))
        .route("/v1/auth/register", post(register))
        .route("/v1/auth/login", post(login))
        .route("/v1/auth/refresh", post(refresh))
        .route("/v1/auth/logout", post(logout))
        .route("/v1/me", get(me))
        .route("/v1/me/privacy", post(privacy))
        .route("/v1/state", get(state_view))
        .route("/v1/queue", post(enqueue))
        .route("/v1/queue/cancel", post(cancel_queue))
        .route("/v1/matches/{mid}", get(get_match))
        .route("/v1/matches/{mid}/ready", post(ready))
        .route("/v1/matches/{mid}/presence", post(presence))
        .route("/v1/matches/{mid}/evidence", post(evidence))
        .route("/v1/matches/{mid}/submit", post(submit))
        .route("/v1/matches/{mid}/leave", post(leave))
        .route("/v1/history", get(history))
        .route("/v1/leaderboard/{variation}", get(leaderboard))
        .route("/v1/players/{public_id}", get(player))
        .fallback(|| async { ApiError::new(StatusCode::NOT_FOUND, "Not found") })
        .layer(middleware::from_fn_with_state(state.clone(), boundary))
        .with_state(state)
}

#[derive(Serialize)]
struct Health {
    status: &'static str,
    rules: &'static str,
}
async fn health() -> Json<Health> {
    Json(Health {
        status: "ok",
        rules: rules::VERSION,
    })
}

#[derive(Serialize)]
struct Movement {
    variation: rules::Variation,
    competitive: bool,
    reason: Option<&'static str>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Catalog {
    rule_version: &'static str,
    round_seconds: u8,
    evidence_retention_hours: u8,
    integrity: &'static str,
    movements: [Movement; 18],
}
async fn catalog() -> Json<Catalog> {
    Json(Catalog {
        rule_version: rules::VERSION,
        round_seconds: 60,
        evidence_retention_hours: 24,
        integrity: "Derived pose validation, not proof against replay or hidden assistance",
        movements: rules::VARIATIONS.map(|variation| Movement {
            variation,
            competitive: !variation.is_advanced(),
            reason: variation.is_advanced().then_some(
                "Recording-based inverted/hand/support validation is not yet established",
            ),
        }),
    })
}

async fn register(
    State(state): State<AppState>,
    Extension(address): Extension<ClientAddress>,
    Input(body): Input<Registration>,
) -> Result<Json<Grant>> {
    let clock = state.clock.clone();
    let mut body = state
        .db
        .call(move |db| {
            let address = address
                .0
                .map_or_else(|| "local".into(), |ip| ip.to_string());
            store::throttle(db, &address, &body.login, true, clock())?;
            Ok(body)
        })
        .await?;
    let hashed = state
        .passwords
        .hash(std::mem::take(&mut body.password))
        .await?;
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| store::register(db, body, &hashed, clock()))
        .await
        .map(Json)
}

async fn login(
    State(state): State<AppState>,
    Extension(address): Extension<ClientAddress>,
    Input(body): Input<Credentials>,
) -> Result<Json<Grant>> {
    let clock = state.clock.clone();
    let (password, account) = state
        .db
        .call(move |db| {
            let address = address
                .0
                .map_or_else(|| "local".into(), |ip| ip.to_string());
            store::throttle(db, &address, &body.login, false, clock())?;
            let account: Option<(String, String)> = db
                .prepare_cached("SELECT id,password FROM accounts WHERE login=?")?
                .query_row([body.login], |row| Ok((row.get(0)?, row.get(1)?)))
                .optional()?;
            Ok((body.password, account))
        })
        .await?;
    let (uid, stored) = match account {
        Some((uid, stored)) => (Some(uid), Some(stored)),
        None => (None, None),
    };
    if !state.passwords.verify(password, stored).await? {
        return Err(ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Incorrect login or password",
        ));
    }
    let uid =
        uid.ok_or_else(|| ApiError::new(StatusCode::UNAUTHORIZED, "Incorrect login or password"))?;
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| store::grant(db, &uid, None, clock()))
        .await
        .map(Json)
}

async fn refresh(
    State(state): State<AppState>,
    Input(body): Input<Refresh>,
) -> Result<Json<Grant>> {
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| store::refresh(db, &body.refresh_token, clock()))
        .await
        .map(Json)
}

#[derive(Serialize)]
struct OkResponse {
    ok: bool,
}

async fn logout(State(state): State<AppState>, headers: HeaderMap) -> Result<Json<OkResponse>> {
    let access = access_hash(&headers)?;
    state
        .authenticated(&headers, move |db, uid, time| {
            store::logout(db, uid, &access, time)?;
            Ok(OkResponse { ok: true })
        })
        .await
        .map(Json)
}
async fn me(State(state): State<AppState>, headers: HeaderMap) -> Result<Json<Account>> {
    state.authenticated(&headers, store::me).await.map(Json)
}
async fn privacy(
    State(state): State<AppState>,
    headers: HeaderMap,
    Input(body): Input<Privacy>,
) -> Result<Json<Identity>> {
    state
        .authenticated(&headers, move |db, uid, _| store::privacy(db, uid, body))
        .await
        .map(Json)
}
async fn state_view(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ServiceState>> {
    state.authenticated(&headers, store::state).await.map(Json)
}
async fn enqueue(
    State(state): State<AppState>,
    headers: HeaderMap,
    Input(body): Input<QueueEntry>,
) -> Result<Json<ServiceState>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::enqueue(db, uid, body, time)
        })
        .await
        .map(Json)
}
async fn cancel_queue(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ServiceState>> {
    state
        .authenticated(&headers, store::cancel_queue)
        .await
        .map(Json)
}
async fn get_match(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
) -> Result<Json<MatchResponse>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::get_match(db, uid, &mid, time)
        })
        .await
        .map(Json)
}
async fn ready(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
    Input(body): Input<Ready>,
) -> Result<Json<MatchResponse>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::ready(db, uid, &mid, body, time)
        })
        .await
        .map(Json)
}
async fn presence(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
    Input(body): Input<Presence>,
) -> Result<Json<MatchResponse>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::presence(db, uid, &mid, body, time)
        })
        .await
        .map(Json)
}
async fn evidence(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
    Input(body): Input<Evidence>,
) -> Result<Json<Receipt>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::evidence(db, uid, &mid, body, time)
        })
        .await
        .map(Json)
}
async fn submit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
) -> Result<Json<MatchResponse>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::submit(db, uid, &mid, time)
        })
        .await
        .map(Json)
}
async fn leave(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(mid): Path<String>,
) -> Result<Json<MatchResponse>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            store::leave(db, uid, &mid, time)
        })
        .await
        .map(Json)
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct Page {
    cursor: Option<String>,
    #[serde(default)]
    around_me: bool,
}
async fn history(
    State(state): State<AppState>,
    headers: HeaderMap,
    query: std::result::Result<Query<Page>, axum::extract::rejection::QueryRejection>,
) -> Result<Json<History>> {
    let Query(page) = query.map_err(|_| ApiError::invalid("Invalid history page"))?;
    state
        .authenticated(&headers, move |db, uid, time| {
            store::history(db, uid, page.cursor.as_deref(), time)
        })
        .await
        .map(Json)
}
async fn leaderboard(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(variation): Path<String>,
    query: std::result::Result<Query<Page>, axum::extract::rejection::QueryRejection>,
) -> Result<Json<Leaderboard>> {
    let movement = variation
        .parse()
        .map_err(|_| ApiError::new(StatusCode::NOT_FOUND, "Unknown movement"))?;
    let Query(page) = query.map_err(|_| ApiError::invalid("Invalid leaderboard page"))?;
    state
        .authenticated(&headers, move |db, uid, _| {
            store::leaderboard(db, uid, movement, page.cursor.as_deref(), page.around_me)
        })
        .await
        .map(Json)
}
async fn player(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(public_id): Path<String>,
) -> Result<Json<Player>> {
    state
        .authenticated(&headers, move |db, _, _| store::player(db, &public_id))
        .await
        .map(Json)
}

#[cfg(test)]
mod tests;
