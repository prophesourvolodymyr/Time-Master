use crate::{ApiError, Result, auth};
use axum::http::StatusCode;
use jsonwebtoken::{
    Algorithm, DecodingKey, Validation, decode, decode_header,
    jwk::{AlgorithmParameters, EllipticCurve, JwkSet, KeyAlgorithm, KeyOperations, PublicKeyUse},
};
use reqwest::{Client, Response, Url, redirect::Policy};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::Mutex;
use uuid::Uuid;

const MAX_JSON: usize = 256 * 1024;
const JWKS_TTL: Duration = Duration::from_secs(300);
const ROTATION_BACKOFF: Duration = Duration::from_secs(5);
pub(crate) const CHUNK_BYTES: usize = 4 * 1024 * 1024;

#[derive(Clone)]
pub struct SupabaseConfig {
    pub(crate) url: Url,
    pub(crate) anon_key: String,
    pub(crate) service_key: String,
    pub(crate) bucket: String,
}

impl SupabaseConfig {
    pub fn from_env() -> Result<Option<Self>> {
        let names = [
            "SUPABASE_URL",
            "SUPABASE_ANON_KEY",
            "SUPABASE_SERVICE_ROLE_KEY",
        ];
        let values: Vec<_> = names.iter().map(std::env::var).collect();
        if values
            .iter()
            .all(|value| matches!(value, Err(std::env::VarError::NotPresent)))
        {
            return Ok(None);
        }
        let mut values = values.into_iter().zip(names).map(|(value, name)| {
            value
                .ok()
                .filter(|value| !value.trim().is_empty())
                .ok_or_else(|| {
                    ApiError::new(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        format!("{name} is required for Supabase"),
                    )
                })
        });
        let url = values.next().unwrap()?;
        let anon_key = values.next().unwrap()?;
        let service_key = values.next().unwrap()?;
        let mut url =
            Url::parse(&url).map_err(|_| config_error("SUPABASE_URL must be an HTTPS origin"))?;
        if url.scheme() != "https"
            || url.host_str().is_none()
            || !url.username().is_empty()
            || url.password().is_some()
            || url.query().is_some()
            || url.fragment().is_some()
            || !matches!(url.path(), "" | "/")
        {
            return Err(config_error("SUPABASE_URL must be an HTTPS origin"));
        }
        url.set_path("/");
        if [anon_key.as_str(), service_key.as_str()].iter().any(|key| {
            key.len() > 8192
                || key
                    .bytes()
                    .any(|byte| byte.is_ascii_control() || byte == b' ')
        }) {
            return Err(config_error("Supabase keys contain invalid characters"));
        }
        let bucket =
            std::env::var("SUPABASE_STORAGE_BUCKET").unwrap_or_else(|_| "tm-exercise-sync".into());
        if !(3..=63).contains(&bucket.len())
            || !bucket.bytes().all(|byte| {
                byte.is_ascii_lowercase() || byte.is_ascii_digit() || b"-_".contains(&byte)
            })
        {
            return Err(config_error("SUPABASE_STORAGE_BUCKET is invalid"));
        }
        Ok(Some(Self {
            url,
            anon_key,
            service_key,
            bucket,
        }))
    }

    pub(crate) fn issuer(&self) -> String {
        format!("{}auth/v1", self.url)
    }
}

fn config_error(detail: &'static str) -> ApiError {
    ApiError::new(StatusCode::INTERNAL_SERVER_ERROR, detail)
}

#[derive(Clone, Debug)]
pub(crate) struct Subject {
    pub id: String,
    pub display_name: String,
}

#[derive(Deserialize)]
struct Claims {
    sub: String,
    exp: u64,
    #[serde(default)]
    nbf: Option<u64>,
    role: String,
    #[serde(default)]
    user_metadata: Value,
}

struct TrustedKey {
    algorithm: Algorithm,
    key: DecodingKey,
    validation: Validation,
}
type TrustedKeys = HashMap<String, TrustedKey>;

fn trusted_keys(keys: JwkSet, issuer: &str) -> Result<TrustedKeys> {
    let mut trusted = HashMap::with_capacity(keys.keys.len());
    for mut jwk in keys.keys {
        let algorithm = match &jwk.algorithm {
            AlgorithmParameters::EllipticCurve(parameters)
                if parameters.curve == EllipticCurve::P256 =>
            {
                Algorithm::ES256
            }
            AlgorithmParameters::RSA(_) => Algorithm::RS256,
            _ => continue,
        };
        let advertised = match algorithm {
            Algorithm::ES256 => KeyAlgorithm::ES256,
            _ => KeyAlgorithm::RS256,
        };
        if jwk
            .common
            .key_algorithm
            .is_some_and(|alg| alg != advertised)
            || jwk
                .common
                .public_key_use
                .as_ref()
                .is_some_and(|usage| *usage != PublicKeyUse::Signature)
            || jwk
                .common
                .key_operations
                .as_ref()
                .is_some_and(|ops| !ops.contains(&KeyOperations::Verify))
        {
            continue;
        }
        let key = DecodingKey::from_jwk(&jwk)
            .map_err(|_| unavailable("Account signing key is invalid"))?;
        let Some(kid) = jwk
            .common
            .key_id
            .take()
            .filter(|kid| !kid.is_empty() && kid.len() <= 256)
        else {
            continue;
        };
        let mut validation = Validation::new(algorithm);
        validation.set_audience(&["authenticated"]);
        validation.set_issuer(&[issuer]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);
        validation.leeway = 0;
        validation.validate_exp = false;
        if trusted
            .insert(
                kid,
                TrustedKey {
                    algorithm,
                    key,
                    validation,
                },
            )
            .is_some()
        {
            return Err(unavailable(
                "Account signing key identifiers must be unique",
            ));
        }
    }
    if trusted.is_empty() {
        return Err(unavailable(
            "Supabase must publish trusted ES256 or RS256 signing keys",
        ));
    }
    Ok(trusted)
}

#[derive(Default)]
struct KeyCache {
    keys: Option<TrustedKeys>,
    fetched: Option<Instant>,
    last_rotation: Option<Instant>,
}

#[derive(Clone)]
pub(crate) struct Supabase {
    pub config: Arc<SupabaseConfig>,
    client: Client,
    keys: Arc<Mutex<KeyCache>>,
}

impl Supabase {
    pub(crate) fn new(config: SupabaseConfig) -> Result<Self> {
        let client = Client::builder()
            .https_only(true)
            .redirect(Policy::none())
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(120))
            .build()
            .map_err(|_| ApiError::internal())?;
        Ok(Self {
            config: Arc::new(config),
            client,
            keys: Arc::new(Mutex::new(KeyCache::default())),
        })
    }

    fn endpoint(&self, path: &str) -> Url {
        self.config
            .url
            .join(path)
            .expect("constant Supabase endpoint")
    }

    fn admin(&self, method: reqwest::Method, path: &str) -> reqwest::RequestBuilder {
        self.client
            .request(method, self.endpoint(path))
            .header("apikey", &self.config.service_key)
            .bearer_auth(&self.config.service_key)
    }

    pub(crate) async fn initialize(&self) -> Result<()> {
        self.check_bucket().await?;
        let keys = self.fetch_keys().await?;
        let mut cache = self.keys.lock().await;
        cache.keys = Some(keys);
        cache.fetched = Some(Instant::now());
        Ok(())
    }

    pub(crate) async fn check_bucket(&self) -> Result<()> {
        let response = self
            .admin(
                reqwest::Method::GET,
                &format!("storage/v1/bucket/{}", self.config.bucket),
            )
            .send()
            .await
            .map_err(|_| unavailable("Private cloud storage is unreachable"))?;
        if !response.status().is_success() {
            return Err(unavailable("Private cloud storage bucket is unavailable"));
        }
        let bytes = bounded(response, MAX_JSON).await?;
        let value: Value = serde_json::from_slice(&bytes)
            .map_err(|_| unavailable("Cloud storage returned invalid configuration"))?;
        if value.get("public").and_then(Value::as_bool) != Some(false) {
            return Err(unavailable("Exercise storage must be a private bucket"));
        }
        Ok(())
    }

    async fn fetch_keys(&self) -> Result<TrustedKeys> {
        let response = self
            .client
            .get(self.endpoint("auth/v1/.well-known/jwks.json"))
            .header("apikey", &self.config.anon_key)
            .send()
            .await
            .map_err(|_| unavailable("Account signing keys are temporarily unavailable"))?;
        if !response.status().is_success() {
            return Err(unavailable(
                "Account signing keys are temporarily unavailable",
            ));
        }
        let bytes = bounded(response, MAX_JSON).await?;
        let keys: JwkSet = serde_json::from_slice(&bytes)
            .map_err(|_| unavailable("Account signing keys are invalid"))?;
        if keys.keys.is_empty() || keys.keys.len() > 32 {
            return Err(unavailable(
                "Supabase must publish trusted asymmetric JWT signing keys",
            ));
        }
        trusted_keys(keys, &self.config.issuer())
    }

    pub(crate) async fn verify(&self, token: &str, now: f64) -> Result<Subject> {
        if token.len() > 16384 {
            return Err(unauthorized());
        }
        let header = decode_header(token).map_err(|_| unauthorized())?;
        if !matches!(header.alg, Algorithm::ES256 | Algorithm::RS256) {
            return Err(unauthorized());
        }
        let kid = header
            .kid
            .as_deref()
            .filter(|kid| !kid.is_empty() && kid.len() <= 256)
            .ok_or_else(unauthorized)?;
        let mut cache = self.keys.lock().await;
        let fresh_fetch = cache.fetched.is_none_or(|at| at.elapsed() >= JWKS_TTL);
        if fresh_fetch {
            cache.keys = Some(self.fetch_keys().await?);
            cache.fetched = Some(Instant::now());
        }
        let mut result = verify_keys(token, header.alg, kid, cache.keys.as_ref().unwrap(), now);
        if result.is_err()
            && !fresh_fetch
            && cache
                .last_rotation
                .is_none_or(|at| at.elapsed() >= ROTATION_BACKOFF)
        {
            cache.last_rotation = Some(Instant::now());
            cache.keys = Some(self.fetch_keys().await?);
            cache.fetched = Some(Instant::now());
            result = verify_keys(token, header.alg, kid, cache.keys.as_ref().unwrap(), now);
        }
        result
    }

    pub(crate) fn object_name(owner: &str, hash: &str) -> String {
        format!("{}/{}", auth::digest(owner), hash)
    }

    pub(crate) async fn upload(
        &self,
        owner: &str,
        hash: &str,
        bytes: axum::body::Bytes,
    ) -> Result<()> {
        let path = format!(
            "storage/v1/object/{}/{}",
            self.config.bucket,
            Self::object_name(owner, hash)
        );
        let response = self
            .admin(reqwest::Method::POST, &path)
            .header("content-type", "application/octet-stream")
            .header("x-upsert", "true")
            .body(bytes)
            .send()
            .await
            .map_err(|_| unavailable("Exercise chunk could not be uploaded"))?;
        if !response.status().is_success() {
            return Err(unavailable("Exercise chunk could not be stored privately"));
        }
        Ok(())
    }

    pub(crate) async fn download(&self, owner: &str, hash: &str) -> Result<Vec<u8>> {
        let path = format!(
            "storage/v1/object/authenticated/{}/{}",
            self.config.bucket,
            Self::object_name(owner, hash)
        );
        let response = self
            .admin(reqwest::Method::GET, &path)
            .send()
            .await
            .map_err(|_| unavailable("Exercise chunk could not be downloaded"))?;
        if !response.status().is_success() {
            return Err(unavailable("Stored exercise chunk is unavailable"));
        }
        let bytes = bounded(response, CHUNK_BYTES).await?;
        if bytes.is_empty() || auth::digest(&bytes) != hash {
            return Err(unavailable(
                "Stored exercise chunk failed its integrity check",
            ));
        }
        Ok(bytes)
    }

    pub(crate) async fn delete_objects(&self, owner: &str) -> Result<()> {
        let namespace = auth::digest(owner);
        let mut previous_first = None;
        loop {
            let response = self.admin(reqwest::Method::POST, &format!("storage/v1/object/list/{}", self.config.bucket))
                .json(&json!({"prefix": namespace, "limit": 1000, "offset": 0, "sortBy": {"column": "name", "order": "asc"}}))
                .send().await.map_err(|_| unavailable("Account assets could not be listed for deletion"))?;
            if !response.status().is_success() {
                return Err(unavailable(
                    "Account assets could not be listed for deletion",
                ));
            }
            let bytes = bounded(response, 2 * 1024 * 1024).await?;
            let objects: Vec<Value> = serde_json::from_slice(&bytes)
                .map_err(|_| unavailable("Cloud storage returned an invalid object list"))?;
            if objects.is_empty() {
                return Ok(());
            }
            let mut prefixes = Vec::with_capacity(objects.len());
            for object in objects {
                let name = object
                    .get("name")
                    .and_then(Value::as_str)
                    .filter(|name| crate::sync::valid_hash(name))
                    .ok_or_else(|| unavailable("Unexpected object in private account namespace"))?;
                prefixes.push(format!("{namespace}/{name}"));
            }
            if previous_first.as_ref() == prefixes.first() {
                return Err(unavailable(
                    "Cloud storage did not remove the account assets; deletion remains pending",
                ));
            }
            let response = self
                .admin(
                    reqwest::Method::DELETE,
                    &format!("storage/v1/object/{}", self.config.bucket),
                )
                .json(&json!({"prefixes": prefixes}))
                .send()
                .await
                .map_err(|_| unavailable("Account assets could not be deleted"))?;
            if !response.status().is_success() {
                return Err(unavailable("Account assets could not be deleted"));
            }
            previous_first = prefixes.into_iter().next();
        }
    }

    pub(crate) async fn sign_out(&self, token: &str) -> Result<()> {
        let response = self
            .client
            .post(self.endpoint("auth/v1/logout?scope=local"))
            .header("apikey", &self.config.anon_key)
            .bearer_auth(token)
            .send()
            .await
            .map_err(|_| unavailable("Managed account sign-out failed"))?;
        if !response.status().is_success() {
            return Err(unavailable("Managed account sign-out failed"));
        }
        Ok(())
    }

    pub(crate) async fn delete_user(&self, owner: &str) -> Result<()> {
        let response = self
            .admin(
                reqwest::Method::DELETE,
                &format!("auth/v1/admin/users/{owner}"),
            )
            .send()
            .await
            .map_err(|_| unavailable("Supabase account deletion failed; retry account deletion"))?;
        if !response.status().is_success() && response.status() != reqwest::StatusCode::NOT_FOUND {
            return Err(unavailable(
                "Supabase account deletion failed; retry account deletion",
            ));
        }
        Ok(())
    }
}

fn verify_keys(
    token: &str,
    algorithm: Algorithm,
    kid: &str,
    keys: &TrustedKeys,
    now: f64,
) -> Result<Subject> {
    let key = keys
        .get(kid)
        .filter(|key| key.algorithm == algorithm)
        .ok_or_else(unauthorized)?;
    let claims = decode::<Claims>(token, &key.key, &key.validation)
        .map_err(|_| unauthorized())?
        .claims;
    if !now.is_finite()
        || now < 0.0
        || claims.exp as f64 <= now
        || claims.nbf.is_some_and(|nbf| nbf as f64 > now)
        || claims.role != "authenticated"
    {
        return Err(unauthorized());
    }
    let id = Uuid::parse_str(&claims.sub).map_err(|_| unauthorized())?;
    if id.is_nil() {
        return Err(unauthorized());
    }
    let display_name = ["display_name", "full_name", "name"]
        .into_iter()
        .find_map(|key| claims.user_metadata.get(key).and_then(Value::as_str))
        .unwrap_or("Athlete")
        .trim()
        .chars()
        .filter(|character| !character.is_control())
        .take(60)
        .collect::<String>();
    Ok(Subject {
        id: id.hyphenated().to_string(),
        display_name: if display_name.is_empty() {
            "Athlete".into()
        } else {
            display_name
        },
    })
}

pub(crate) fn unauthorized() -> ApiError {
    ApiError::new(
        StatusCode::UNAUTHORIZED,
        "Session expired or invalid · Sign in to TimeMaster",
    )
}

pub(crate) fn unavailable(detail: &'static str) -> ApiError {
    ApiError::new(StatusCode::BAD_GATEWAY, detail)
}

async fn bounded(mut response: Response, limit: usize) -> Result<Vec<u8>> {
    if response
        .content_length()
        .is_some_and(|size| size > limit as u64)
    {
        return Err(unavailable("Cloud response exceeded its size limit"));
    }
    let mut bytes =
        Vec::with_capacity(response.content_length().unwrap_or(0).min(limit as u64) as usize);
    while let Some(chunk) = response
        .chunk()
        .await
        .map_err(|_| unavailable("Cloud response was interrupted"))?
    {
        if chunk.len() > limit - bytes.len() {
            return Err(unavailable("Cloud response exceeded its size limit"));
        }
        bytes.extend_from_slice(&chunk);
    }
    Ok(bytes)
}

#[cfg(test)]
pub(crate) mod tests;
