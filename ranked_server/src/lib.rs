mod account;
mod auth;
mod cloud;
mod compat;
mod model;
mod physique;
pub mod rules;
mod store;
mod sync;

pub use cloud::SupabaseConfig;

use axum::{
    Extension, Json, Router,
    body::{Body, to_bytes},
    extract::{ConnectInfo, FromRequest, Path, Query, Request, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{delete, get, post},
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
    conflicts: Option<Vec<sync::SyncFile>>,
}

impl ApiError {
    pub(crate) fn new(status: StatusCode, detail: impl Into<Cow<'static, str>>) -> Self {
        Self {
            status,
            detail: detail.into(),
            conflicts: None,
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
    pub(crate) fn conflict(files: Vec<sync::SyncFile>) -> Self {
        Self {
            status: StatusCode::CONFLICT,
            detail: "Exercise files changed on another device; pull the current revisions".into(),
            conflicts: Some(files),
        }
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
            #[serde(skip_serializing_if = "Option::is_none")]
            conflicts: Option<Vec<sync::SyncFile>>,
        }
        (
            self.status,
            Json(Problem {
                detail: self.detail,
                conflicts: self.conflicts,
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
    pub supabase: Option<SupabaseConfig>,
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
                .unwrap_or_else(|| {
                    if std::env::var_os("RAILWAY_ENVIRONMENT_ID").is_some() {
                        "/data/ranked.sqlite3".into()
                    } else {
                        "ranked.sqlite3".into()
                    }
                }),
            require_tls: boolean("RANKED_REQUIRE_TLS", true)?,
            trust_proxy: boolean("RANKED_TRUST_PROXY", false)?,
            supabase: SupabaseConfig::from_env()?,
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
    cloud: Option<cloud::Supabase>,
    owner_locks: sync::OwnerLocks,
    sync_work: Arc<tokio::sync::Semaphore>,
    physique: Arc<physique::Service>,
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
            supabase,
        } = config;
        let db = store::Database::open(database).await?;
        let passwords = auth::PasswordWork::new().await?;
        let cloud = supabase.map(cloud::Supabase::new).transpose()?;
        if let Some(cloud) = &cloud {
            cloud.initialize().await?;
        }
        Ok(Self {
            db,
            clock,
            require_tls,
            trust_proxy,
            passwords,
            cloud,
            owner_locks: sync::OwnerLocks::default(),
            sync_work: sync::work_limit(),
            physique: Arc::new(physique::Service::new()?),
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
            .await?;
        physique::tick(self).await
    }

    fn cloud_service(&self) -> Result<cloud::Supabase> {
        self.cloud.clone().ok_or_else(|| {
            ApiError::new(
                StatusCode::SERVICE_UNAVAILABLE,
                "Managed TimeMaster accounts and private exercise sync are not configured",
            )
        })
    }

    async fn subject(&self, headers: &HeaderMap) -> Result<cloud::Subject> {
        self.cloud_service()?
            .verify(bearer(headers)?, (self.clock)())
            .await
    }

    fn require_legacy_auth(&self) -> Result<()> {
        if self.cloud.is_some() {
            Err(ApiError::new(
                StatusCode::GONE,
                "Use managed TimeMaster sign-in; link an existing Ranked account explicitly",
            ))
        } else {
            Ok(())
        }
    }

    async fn cleanup_owner(&self, owner: String) -> Result<()> {
        let cloud = self.cloud_service()?;
        cloud.delete_objects(&owner).await?;
        cloud.delete_user(&owner).await?;
        let time = (self.clock)();
        self.db
            .call(move |db| account::finish_deletion(db, &owner, time))
            .await
    }

    pub async fn recover_deletions(&self) -> Result<()> {
        if self.cloud.is_none() {
            return Ok(());
        }
        let owners: Vec<String> = self.db.call(|db| {
            Ok(db.prepare_cached("SELECT subject FROM cloud_accounts WHERE deleting=1 ORDER BY created LIMIT 32")?
                .query_map([], |row| row.get(0))?.collect::<rusqlite::Result<_>>()?)
        }).await?;
        let mut failure = None;
        for owner in owners {
            let _guard = self.owner_locks.acquire(&owner).await?;
            let lookup = owner.clone();
            let pending: bool = self
                .db
                .call(move |db| {
                    Ok(db.query_row(
                        "SELECT deleting=1 FROM cloud_accounts WHERE subject=?",
                        [lookup],
                        |row| row.get(0),
                    )?)
                })
                .await?;
            if pending {
                if let Err(error) = self.cleanup_owner(owner).await {
                    if failure.is_none() {
                        failure = Some(error);
                    }
                }
            }
        }
        match failure {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }

    async fn authenticated<T, F>(&self, headers: &HeaderMap, operation: F) -> Result<T>
    where
        T: Send + 'static,
        F: FnOnce(&Connection, &str, f64) -> Result<T> + Send + 'static,
    {
        let clock = self.clock.clone();
        if self.cloud.is_some() {
            let subject = self.subject(headers).await?;
            self.db
                .call(move |db| {
                    let time = clock();
                    let uid = account::ranked_identity(db, &subject, time)?;
                    operation(db, &uid, time)
                })
                .await
        } else {
            let access = access_hash(headers)?;
            self.db
                .call(move |db| {
                    let time = clock();
                    let uid = store::authenticated(db, &access, time)?;
                    operation(db, &uid, time)
                })
                .await
        }
    }
}

fn bearer(headers: &HeaderMap) -> Result<&str> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .filter(|value| !value.is_empty() && !value.bytes().any(|byte| byte.is_ascii_whitespace()))
        .ok_or_else(cloud::unauthorized)
}

fn access_hash(headers: &HeaderMap) -> Result<String> {
    bearer(headers).map(auth::digest)
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
        if state.require_tls && !proxy_https && request.uri().path() != "/health" {
            return Err(ApiError::new(
                StatusCode::UPGRADE_REQUIRED,
                "HTTPS required",
            ));
        }
        let body_limit = if request.uri().path() == "/v1/sync/commit" {
            sync::MAX_COMMIT_BODY
        } else if request.method() == Method::PUT
            && request.uri().path().starts_with("/v1/sync/blobs/")
        {
            cloud::CHUNK_BYTES
        } else if request.method() == Method::POST
            && request.uri().path() == "/v1/physique/command"
        {
            physique::MAX_COMMAND_BODY
        } else {
            MAX_BODY
        };
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
            if length.len() > 9 || length.parse::<usize>().map_or(true, |n| n > body_limit) {
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
            let bytes = tokio::time::timeout(
                std::time::Duration::from_secs(120),
                to_bytes(body, body_limit),
            )
            .await
            .map_err(|_| ApiError::new(StatusCode::REQUEST_TIMEOUT, "Request upload timed out"))?
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
        .route("/v1/account/link-ranked", post(link_ranked))
        .route("/v1/account", delete(delete_account))
        .route("/v1/sync/manifest", get(sync::manifest))
        .route("/v1/sync/commit", post(sync::commit))
        .route(
            "/v1/sync/blobs/{hash}",
            get(sync::download).put(sync::upload),
        )
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
        .route("/v1/physique/policy", get(physique::policy))
        .route("/v1/physique/state", get(physique::state))
        .route("/v1/physique/command", post(physique::command).layer(axum::extract::DefaultBodyLimit::max(physique::MAX_COMMAND_BODY)))
        .route("/v1/physique/history", get(physique::history))
        .route("/v1/physique/standings", get(physique::standings))
        .route("/v1/physique/players/{id}", get(physique::player))
        .route("/v1/physique/matches/{id}", get(physique::get_match))
        .route("/v1/physique/matches/{id}/gallery", get(physique::gallery))
        .route("/v1/physique/cases", get(physique::case_list))
        .route("/v1/physique/cases/{id}", get(physique::case_detail))
        .route("/v1/physique/privacy", get(physique::privacy))
        .route("/v1/physique/blocks", get(physique::blocks))
        .route("/v1/physique/admin/cases", get(physique::admin_cases))
        .route("/v1/physique/admin/cases/{id}", get(physique::admin_case))
        .route("/v1/physique/admin/cases/{id}/media", get(physique::admin_media))
        .route("/v1/physique/admin/command", post(physique::admin_command))
        .fallback(|| async { ApiError::new(StatusCode::NOT_FOUND, "Not found") })
        .layer(middleware::from_fn_with_state(state.clone(), boundary))
        .with_state(state)
}

#[derive(Serialize)]
struct Health {
    status: &'static str,
    rules: &'static str,
    #[serde(rename = "cloudAuth")]
    cloud_auth: bool,
    #[serde(rename = "exerciseSync")]
    exercise_sync: bool,
    #[serde(rename = "supabaseIssuer", skip_serializing_if = "Option::is_none")]
    supabase_issuer: Option<String>,
    #[serde(rename = "storageBucket", skip_serializing_if = "Option::is_none")]
    storage_bucket: Option<String>,
}
async fn health(State(state): State<AppState>) -> Json<Health> {
    Json(Health {
        status: "ok",
        rules: rules::VERSION,
        cloud_auth: state.cloud.is_some(),
        exercise_sync: state.cloud.is_some(),
        supabase_issuer: state.cloud.as_ref().map(|cloud| cloud.config.issuer()),
        storage_bucket: state
            .cloud
            .as_ref()
            .map(|cloud| cloud.config.bucket.clone()),
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
    state.require_legacy_auth()?;
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
    state.require_legacy_auth()?;
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
    state.require_legacy_auth()?;
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
    if let Some(cloud) = &state.cloud {
        state
            .authenticated(&headers, |db, uid, time| {
                physique::signed_out(db, uid, time)?;
                store::cancel(db, uid, "Signed out", time)
            })
            .await?;
        cloud.sign_out(bearer(&headers)?).await?;
        return Ok(Json(OkResponse { ok: true }));
    }
    let access = access_hash(&headers)?;
    state
        .authenticated(&headers, move |db, uid, time| {
            physique::signed_out(db, uid, time)?;
            store::logout(db, uid, &access, time)?;
            Ok(OkResponse { ok: true })
        })
        .await
        .map(Json)
}

async fn link_ranked(
    State(state): State<AppState>,
    Extension(address): Extension<ClientAddress>,
    headers: HeaderMap,
    Input(body): Input<Credentials>,
) -> Result<Json<Account>> {
    let subject = state.subject(&headers).await?;
    let _owner = state.owner_locks.acquire(&subject.id).await?;
    let lookup_subject = subject.clone();
    let clock = state.clock.clone();
    let (password, account) = state
        .db
        .call(move |db| {
            let time = clock();
            account::ensure(db, &lookup_subject, time)?;
            let address = address
                .0
                .map_or_else(|| "local".into(), |ip| ip.to_string());
            store::throttle(db, &format!("link:{address}"), &body.login, false, time)?;
            store::throttle(
                db,
                &format!("link:{}", lookup_subject.id),
                "credential-proof",
                false,
                time,
            )?;
            let account: Option<(String, String)> = db
                .query_row(
                    "SELECT id,password FROM accounts WHERE login=?",
                    [body.login],
                    |row| Ok((row.get(0)?, row.get(1)?)),
                )
                .optional()?;
            Ok((body.password, account))
        })
        .await?;
    let (uid, stored) = match account {
        Some((uid, stored)) => (Some(uid), Some(stored)),
        None => (None, None),
    };
    let expected = stored.clone();
    if !state.passwords.verify(password, stored).await? {
        return Err(ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Incorrect legacy Ranked login or password",
        ));
    }
    let uid = uid.ok_or_else(cloud::unauthorized)?;
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| {
            let unchanged: bool = db
                .query_row(
                    "SELECT password=? FROM accounts WHERE id=?",
                    rusqlite::params![expected, uid],
                    |row| row.get(0),
                )
                .optional()?
                .unwrap_or(false);
            if !unchanged {
                return Err(cloud::unauthorized());
            }
            account::link(db, &subject, &uid, clock())
        })
        .await
        .map(Json)
}

async fn delete_account(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<OkResponse>> {
    let subject = state.subject(&headers).await?;
    state.cloud_service()?;
    let _owner = state.owner_locks.acquire(&subject.id).await?;
    let deleting = subject.clone();
    let time = (state.clock)();
    let needs_deletion = state
        .db
        .call(move |db| account::begin_deletion(db, &deleting, time))
        .await?;
    if !needs_deletion {
        return Ok(Json(OkResponse { ok: true }));
    }
    state.cleanup_owner(subject.id).await?;
    Ok(Json(OkResponse { ok: true }))
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
