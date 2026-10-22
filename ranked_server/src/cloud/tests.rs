use super::*;
use crate::{AppState, Config, router};
use axum::{
    Router,
    body::{Body, Bytes, to_bytes},
    extract::{DefaultBodyLimit, Path, State},
    http::{HeaderMap, Request},
    response::{IntoResponse, Response as AxumResponse},
    routing::{delete, get, post},
};
use base64::{
    Engine,
    engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD},
};
use jsonwebtoken::{EncodingKey, Header, encode};
use parking_lot::Mutex as FixtureMutex;
use serde_json::{Value, json};
use std::{
    collections::{HashMap, HashSet},
    sync::atomic::{AtomicBool, Ordering},
};
use tempfile::TempDir;
use tower::ServiceExt;

pub(crate) const NOW: f64 = 2_000_000_000.0;
pub(crate) const OWNER_A: &str = "b9f36982-c53f-4b88-8a33-6c315fa3dc9e";
pub(crate) const OWNER_B: &str = "6ba01ab1-78c9-49ab-af31-d53ad0be6780";
const SERVICE_KEY: &str = "isolated-storage-fixture-service-key";
pub(crate) const KEY_A: &str = "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg0BVyyz/bztDaTXs2\nBYpwy2gSyi6H8fws6dDRLbBLbRuhRANCAASWVFy9l375O1vrlbG35IuhG/mHs2mA\nxUn10/4i28+TtBpKnnX0zySHvz7jlW/xqDvPyoZvBeSDLVRpo/Q+MTnw\n-----END PRIVATE KEY-----\n";
pub(crate) const KEY_B: &str = "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgCLRsuVp3qC/wH3TN\np6c7UEd7w2J0tYZLuYrxnc4UplShRANCAAS8zRjRUFGY7feIDnfh/lziSvEvrf8k\njvkvReZNAQMa3ZLawfK20oLkI26xdG7KpM4/U8xE6wbJC4+kYGSS2RRk\n-----END PRIVATE KEY-----\n";

pub(crate) fn jwk(kid: &str, pem: &str) -> Value {
    let der = STANDARD
        .decode(
            pem.lines()
                .filter(|line| !line.starts_with('-'))
                .collect::<String>(),
        )
        .unwrap();
    let point = &der[der.len() - 65..];
    assert_eq!(point[0], 4);
    json!({"kty": "EC", "crv": "P-256", "kid": kid, "alg": "ES256", "use": "sig", "x": URL_SAFE_NO_PAD.encode(&point[1..33]), "y": URL_SAFE_NO_PAD.encode(&point[33..65])})
}

pub(crate) fn token(claims: &Value, kid: &str, key: &str) -> String {
    let mut header = Header::new(Algorithm::ES256);
    header.kid = Some(kid.into());
    encode(
        &header,
        claims,
        &EncodingKey::from_ec_pem(key.as_bytes()).unwrap(),
    )
    .unwrap()
}

#[derive(Clone)]
pub(crate) struct Upstream {
    pub keys: Arc<FixtureMutex<Value>>,
    pub objects: Arc<FixtureMutex<HashMap<String, Bytes>>>,
    pub fail_storage: Arc<AtomicBool>,
    pub fail_auth: Arc<AtomicBool>,
    pub deleted: Arc<FixtureMutex<HashSet<String>>>,
}

impl Upstream {
    fn authorized(&self, headers: &HeaderMap) -> bool {
        headers
            .get("apikey")
            .is_some_and(|value| value == SERVICE_KEY)
            && headers
                .get("authorization")
                .is_some_and(|value| value == format!("Bearer {SERVICE_KEY}").as_str())
    }
}

async fn keys(State(state): State<Upstream>) -> axum::Json<Value> {
    axum::Json(state.keys.lock().clone())
}

async fn bucket(State(state): State<Upstream>, headers: HeaderMap) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    axum::Json(json!({"id": "tm-exercise-sync", "public": false, "file_size_limit": CHUNK_BYTES}))
        .into_response()
}

async fn upload(
    State(state): State<Upstream>,
    Path((_bucket, owner, hash)): Path<(String, String, String)>,
    headers: HeaderMap,
    bytes: Bytes,
) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_storage.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    state
        .objects
        .lock()
        .insert(format!("{owner}/{hash}"), bytes);
    axum::Json(json!({"Key": format!("{owner}/{hash}")})).into_response()
}

async fn download(
    State(state): State<Upstream>,
    Path((_bucket, owner, hash)): Path<(String, String, String)>,
    headers: HeaderMap,
) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_storage.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    match state
        .objects
        .lock()
        .get(&format!("{owner}/{hash}"))
        .cloned()
    {
        Some(bytes) => ([("content-type", "application/octet-stream")], bytes).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn list(
    State(state): State<Upstream>,
    headers: HeaderMap,
    axum::Json(body): axum::Json<Value>,
) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_storage.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    let prefix = format!("{}/", body["prefix"].as_str().unwrap());
    let objects: Vec<_> = state
        .objects
        .lock()
        .keys()
        .filter_map(|key| key.strip_prefix(prefix.as_str()))
        .take(1000)
        .map(|name| json!({"name": name, "id": "fixture-object"}))
        .collect();
    axum::Json(json!(objects)).into_response()
}

async fn remove(
    State(state): State<Upstream>,
    headers: HeaderMap,
    axum::Json(body): axum::Json<Value>,
) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_storage.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    let mut objects = state.objects.lock();
    for prefix in body["prefixes"].as_array().unwrap() {
        objects.remove(prefix.as_str().unwrap());
    }
    axum::Json(json!([])).into_response()
}

async fn remove_user(
    State(state): State<Upstream>,
    Path(owner): Path<String>,
    headers: HeaderMap,
) -> AxumResponse {
    if !state.authorized(&headers) {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_auth.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    state.deleted.lock().insert(owner);
    axum::Json(json!({})).into_response()
}

async fn logout(State(state): State<Upstream>, headers: HeaderMap) -> AxumResponse {
    if headers
        .get("apikey")
        .is_none_or(|value| value != "public-fixture-key")
        || headers
            .get("authorization")
            .and_then(|value| value.to_str().ok())
            .is_none_or(|value| !value.starts_with("Bearer ey"))
    {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    if state.fail_auth.load(Ordering::SeqCst) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    StatusCode::NO_CONTENT.into_response()
}

pub(crate) struct Reply {
    pub status: StatusCode,
    pub body: Value,
    pub bytes: Vec<u8>,
    pub headers: HeaderMap,
}
impl Reply {
    pub fn expect(self, status: u16) -> Value {
        assert_eq!(self.status.as_u16(), status, "{}", self.body);
        self.body
    }
}

pub(crate) struct Service {
    directory: TempDir,
    pub state: AppState,
    pub app: Router,
    pub upstream: Upstream,
    pub a: String,
    pub b: String,
    task: tokio::task::JoinHandle<()>,
}

impl Drop for Service {
    fn drop(&mut self) {
        self.task.abort();
    }
}

impl Service {
    pub async fn new() -> Self {
        let upstream = Upstream {
            keys: Arc::new(FixtureMutex::new(json!({"keys": [jwk("key-a", KEY_A)]}))),
            objects: Arc::new(FixtureMutex::new(HashMap::new())),
            fail_storage: Arc::new(AtomicBool::new(false)),
            fail_auth: Arc::new(AtomicBool::new(false)),
            deleted: Arc::new(FixtureMutex::new(HashSet::new())),
        };
        let fixture = Router::new()
            .route("/auth/v1/.well-known/jwks.json", get(keys))
            .route("/storage/v1/bucket/{bucket}", get(bucket))
            .route("/storage/v1/object/{bucket}/{owner}/{hash}", post(upload))
            .route(
                "/storage/v1/object/authenticated/{bucket}/{owner}/{hash}",
                get(download),
            )
            .route("/storage/v1/object/list/{bucket}", post(list))
            .route("/storage/v1/object/{bucket}", delete(remove))
            .route("/auth/v1/admin/users/{owner}", delete(remove_user))
            .route("/auth/v1/logout", post(logout))
            .layer(DefaultBodyLimit::max(CHUNK_BYTES + 1))
            .with_state(upstream.clone());
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        let task = tokio::spawn(async move {
            axum::serve(listener, fixture).await.unwrap();
        });
        let cloud = Supabase {
            config: Arc::new(SupabaseConfig {
                url,
                anon_key: "public-fixture-key".into(),
                service_key: SERVICE_KEY.into(),
                bucket: "tm-exercise-sync".into(),
            }),
            client: Client::builder()
                .redirect(Policy::none())
                .timeout(Duration::from_secs(5))
                .build()
                .unwrap(),
            keys: Arc::new(Mutex::new(KeyCache::default())),
        };
        let directory = tempfile::tempdir().unwrap();
        let mut state = AppState::with_clock(
            Config {
                database: directory.path().join("ranked.sqlite3"),
                require_tls: false,
                trust_proxy: false,
                supabase: None,
            },
            Arc::new(|| NOW),
        )
        .await
        .unwrap();
        state.cloud = Some(cloud);
        let app = router(state.clone());
        let a = token(
            &json!({"sub": OWNER_A, "exp": NOW as u64 + 3600, "iss": state.cloud.as_ref().unwrap().config.issuer(), "aud": "authenticated", "role": "authenticated", "user_metadata": {"display_name": "Private athlete A"}}),
            "key-a",
            KEY_A,
        );
        let b = token(
            &json!({"sub": OWNER_B, "exp": NOW as u64 + 3600, "iss": state.cloud.as_ref().unwrap().config.issuer(), "aud": "authenticated", "role": "authenticated"}),
            "key-a",
            KEY_A,
        );
        Self {
            directory,
            state,
            app,
            upstream,
            a,
            b,
            task,
        }
    }

    pub fn claims(&self, owner: &str) -> Value {
        json!({"sub": owner, "exp": NOW as u64 + 3600, "iss": self.state.cloud.as_ref().unwrap().config.issuer(), "aud": "authenticated", "role": "authenticated"})
    }

    pub async fn second_state(&self) -> AppState {
        let mut state = AppState::with_clock(
            Config {
                database: self.directory.path().join("ranked.sqlite3"),
                require_tls: false,
                trust_proxy: false,
                supabase: None,
            },
            Arc::new(|| NOW),
        )
        .await
        .unwrap();
        state.cloud = self.state.cloud.clone();
        state
    }

    pub async fn reopen(&mut self) {
        self.state = self.second_state().await;
        self.app = router(self.state.clone());
    }

    pub async fn json(&self, method: &str, path: &str, token: &str, value: Option<Value>) -> Reply {
        self.send(
            method,
            path,
            token,
            value
                .map(|value| serde_json::to_vec(&value).unwrap())
                .unwrap_or_default(),
            "application/json",
        )
        .await
    }

    pub async fn send(
        &self,
        method: &str,
        path: &str,
        token: &str,
        bytes: Vec<u8>,
        content_type: &str,
    ) -> Reply {
        request(self.app.clone(), method, path, token, bytes, content_type).await
    }

    pub async fn chunk(&self, token: &str, bytes: &[u8]) -> String {
        let hash = auth::digest(bytes);
        self.send(
            "PUT",
            &format!("/v1/sync/blobs/{hash}"),
            token,
            bytes.to_vec(),
            "application/octet-stream",
        )
        .await
        .expect(200);
        hash
    }
}

pub(crate) async fn request(
    app: Router,
    method: &str,
    path: &str,
    token: &str,
    bytes: Vec<u8>,
    content_type: &str,
) -> Reply {
    let response = app
        .oneshot(
            Request::builder()
                .method(method)
                .uri(path)
                .header("authorization", format!("Bearer {token}"))
                .header("content-type", content_type)
                .body(Body::from(bytes))
                .unwrap(),
        )
        .await
        .unwrap();
    let status = response.status();
    let headers = response.headers().clone();
    let bytes = to_bytes(response.into_body(), 8 * 1024 * 1024)
        .await
        .unwrap()
        .to_vec();
    let body = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    Reply {
        status,
        body,
        bytes,
        headers,
    }
}

#[tokio::test]
async fn only_trusted_unexpired_supabase_subjects_reach_ranked_and_sync() {
    let service = Service::new().await;
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
    let claims = service.claims(OWNER_A);
    let mut invalid = Vec::new();
    invalid.push(token(&claims, "key-a", KEY_B));
    for (field, value) in [
        ("exp", json!(NOW as u64)),
        ("iss", json!("https://attacker.invalid/auth/v1")),
        ("aud", json!("anon")),
        ("sub", json!("not-a-uuid")),
        ("role", json!("anon")),
        ("nbf", json!(NOW as u64 + 1)),
    ] {
        let mut claims = claims.clone();
        claims[field] = value;
        invalid.push(token(&claims, "key-a", KEY_A));
    }
    invalid.push(token(&claims, "unknown-key", KEY_A));
    let mut header = Header::new(Algorithm::HS256);
    header.kid = Some("key-a".into());
    invalid.push(
        encode(
            &header,
            &claims,
            &EncodingKey::from_secret(b"not-a-trusted-public-key"),
        )
        .unwrap(),
    );
    for token in invalid {
        service
            .json("GET", "/v1/me", &token, None)
            .await
            .expect(401);
        service
            .json("GET", "/v1/sync/manifest", &token, None)
            .await
            .expect(401);
    }
    service.json("POST", "/v1/auth/register", &service.a, Some(json!({"login": "should-not-create", "password": "correct-horse-battery", "displayName": "No account", "listed": false}))).await.expect(410);
    let count: i64 = service
        .state
        .db
        .call(|db| Ok(db.query_row("SELECT count(*) FROM accounts", [], |row| row.get(0))?))
        .await
        .unwrap();
    assert_eq!(count, 1);
}

#[tokio::test]
async fn cached_jwks_refreshes_for_new_kid_and_reused_kid_rotation() {
    for reused in [false, true] {
        let service = Service::new().await;
        service
            .json("GET", "/v1/me", &service.a, None)
            .await
            .expect(200);
        let kid = if reused { "key-a" } else { "key-b" };
        *service.upstream.keys.lock() = json!({"keys": [jwk(kid, KEY_B)]});
        let rotated = token(&service.claims(OWNER_A), kid, KEY_B);
        let me = service
            .json("GET", "/v1/me", &rotated, None)
            .await
            .expect(200);
        assert_eq!(me["identity"]["displayName"], "Private athlete A");
        service
            .json("GET", "/v1/me", &service.a, None)
            .await
            .expect(401);
    }
}
