use crate::{
    ApiError, AppState, Input, Result, account, auth,
    cloud::{self, CHUNK_BYTES},
    model::Validate,
};
use axum::{
    Json,
    body::{Body, to_bytes},
    extract::{Path, Query, Request, State},
    http::{HeaderMap, StatusCode, header},
    response::{IntoResponse, Response},
};
use rusqlite::{Connection, OptionalExtension, Row, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    collections::{HashMap, HashSet},
    sync::{Arc, Mutex, Weak},
    time::Duration,
};
use tokio::sync::{Mutex as AsyncMutex, OwnedMutexGuard, Semaphore};
use uuid::Uuid;

pub(crate) const MAX_COMMIT_BODY: usize = 2 * 1024 * 1024;
const MAX_MUTATIONS: usize = 100;
const MAX_FILE_CHUNKS: usize = 1024;
const MAX_COMMIT_CHUNKS: usize = 4096;
const EMPTY_HASH: &str = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

#[derive(Clone, Default)]
pub(crate) struct OwnerLocks(Arc<Mutex<HashMap<String, Weak<AsyncMutex<()>>>>>);

impl OwnerLocks {
    pub(crate) async fn acquire(&self, owner: &str) -> Result<OwnedMutexGuard<()>> {
        let lock = {
            let mut locks = self.0.lock().map_err(|_| ApiError::internal())?;
            if locks.len() > 1024 {
                locks.retain(|_, lock| lock.strong_count() > 0);
            }
            if let Some(lock) = locks.get(owner).and_then(Weak::upgrade) {
                lock
            } else {
                let lock = Arc::new(AsyncMutex::new(()));
                locks.insert(owner.into(), Arc::downgrade(&lock));
                lock
            }
        };
        Ok(lock.lock_owned().await)
    }
}

pub(crate) fn work_limit() -> Arc<Semaphore> {
    Arc::new(Semaphore::new(4))
}

pub(crate) fn valid_hash(hash: &str) -> bool {
    hash.len() == 64
        && hash
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn valid_path(path: &str) -> bool {
    if path.len() > 1024 || path.contains('\\') || path.chars().any(char::is_control) {
        return false;
    }
    let mut components = path.split('/');
    if !matches!(components.next(), Some("Exercises Database" | "Media")) {
        return false;
    }
    let mut count = 0;
    for component in components {
        if component.is_empty() || component.len() > 255 || matches!(component, "." | "..") {
            return false;
        }
        count += 1;
    }
    count > 0
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SyncFile {
    pub path: String,
    pub revision: i64,
    pub hash: Option<String>,
    pub size: u64,
    pub chunks: Vec<String>,
    pub deleted: bool,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Mutation {
    path: String,
    base_revision: i64,
    hash: Option<String>,
    size: u64,
    chunks: Vec<String>,
    deleted: bool,
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Commit {
    #[serde(rename = "deviceID")]
    device_id: String,
    mutations: Vec<Mutation>,
}

impl Validate for Commit {
    fn validate(&mut self) -> Result<()> {
        let device = Uuid::parse_str(&self.device_id)
            .map_err(|_| ApiError::invalid("deviceID must be a UUID"))?;
        if device.is_nil() {
            return Err(ApiError::invalid("deviceID must be a nonzero UUID"));
        }
        self.device_id = device.hyphenated().to_string();
        if self.mutations.is_empty() || self.mutations.len() > MAX_MUTATIONS {
            return Err(ApiError::invalid("Commit must contain 1–100 mutations"));
        }
        let mut paths = HashSet::with_capacity(self.mutations.len());
        let mut chunks = 0;
        for mutation in &self.mutations {
            if !valid_path(&mutation.path)
                || !paths.insert(&mutation.path)
                || mutation.base_revision < 0
            {
                return Err(ApiError::invalid(
                    "Invalid, duplicate or out-of-scope exercise path/revision",
                ));
            }
            if mutation.deleted {
                if mutation.hash.is_some() || mutation.size != 0 || !mutation.chunks.is_empty() {
                    return Err(ApiError::invalid(
                        "Deleted files must have null hash, zero size and no chunks",
                    ));
                }
                continue;
            }
            if !mutation.hash.as_deref().is_some_and(valid_hash)
                || mutation.chunks.len() > MAX_FILE_CHUNKS
                || mutation.chunks.iter().any(|hash| !valid_hash(hash))
                || mutation.size > CHUNK_BYTES as u64 * MAX_FILE_CHUNKS as u64
                || (mutation.size == 0
                    && (!mutation.chunks.is_empty()
                        || mutation.hash.as_deref() != Some(EMPTY_HASH)))
                || (mutation.size > 0 && mutation.chunks.is_empty())
            {
                return Err(ApiError::invalid(
                    "Invalid file hash, size or chunk list (maximum 1024 chunks/file)",
                ));
            }
            chunks += mutation.chunks.len();
        }
        if chunks > MAX_COMMIT_CHUNKS {
            return Err(ApiError::invalid("Commit exceeds 4096 chunk references"));
        }
        Ok(())
    }
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CommitResponse {
    files: Vec<SyncFile>,
    cursor: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Manifest {
    cursor: i64,
    files: Vec<SyncFile>,
    has_more: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct ManifestPage {
    #[serde(default)]
    cursor: i64,
    #[serde(default = "page_limit")]
    limit: usize,
}
fn page_limit() -> usize {
    500
}

fn read_file(row: &Row<'_>) -> rusqlite::Result<SyncFile> {
    let chunks: String = row.get(4)?;
    let chunks = serde_json::from_str(&chunks).map_err(|error| {
        rusqlite::Error::FromSqlConversionFailure(4, rusqlite::types::Type::Text, Box::new(error))
    })?;
    Ok(SyncFile {
        path: row.get(0)?,
        revision: row.get(1)?,
        hash: row.get(2)?,
        size: row.get(3)?,
        chunks,
        deleted: row.get(5)?,
    })
}

fn current(db: &Connection, owner: &str, path: &str) -> Result<Option<SyncFile>> {
    Ok(db.prepare_cached("SELECT path,revision,hash,size,chunks,deleted FROM sync_files WHERE owner=? AND path=?")?
        .query_row(params![owner, path], read_file).optional()?)
}

fn revision(db: &Connection) -> Result<i64> {
    Ok(db.query_row(
        "SELECT value FROM sync_revision WHERE singleton=1",
        [],
        |row| row.get(0),
    )?)
}

fn cached(db: &Connection, owner: &str, request: &str) -> Result<Option<CommitResponse>> {
    let response: Option<String> = db
        .query_row(
            "SELECT response FROM sync_commits WHERE owner=? AND request_hash=?",
            params![owner, request],
            |row| row.get(0),
        )
        .optional()?;
    response
        .map(|response| serde_json::from_str(&response).map_err(Into::into))
        .transpose()
}

fn check_conflicts(db: &Connection, owner: &str, mutations: &[Mutation]) -> Result<()> {
    let mut conflicts = Vec::new();
    let mut stale = false;
    for mutation in mutations {
        let file = current(db, owner, &mutation.path)?;
        if file.as_ref().map_or(0, |file| file.revision) != mutation.base_revision {
            stale = true;
            if let Some(file) = file {
                conflicts.push(file);
            }
        }
    }
    if stale {
        return Err(ApiError::conflict(conflicts));
    }
    Ok(())
}

fn chunk_sizes(db: &Connection, owner: &str, mutations: &[Mutation]) -> Result<Vec<Vec<usize>>> {
    let mut statement =
        db.prepare_cached("SELECT size FROM sync_blobs WHERE owner=? AND hash=?")?;
    let mut sizes = Vec::with_capacity(mutations.len());
    for mutation in mutations {
        let mut file_sizes = Vec::with_capacity(mutation.chunks.len());
        let mut total: u64 = 0;
        for hash in &mutation.chunks {
            let size: Option<usize> = statement
                .query_row(params![owner, hash], |row| row.get(0))
                .optional()?;
            let size = size.ok_or_else(|| {
                ApiError::invalid("Upload every chunk to this account before committing its file")
            })?;
            total += size as u64;
            file_sizes.push(size);
        }
        if total != mutation.size {
            return Err(ApiError::invalid(
                "File size does not equal its uploaded chunks",
            ));
        }
        sizes.push(file_sizes);
    }
    Ok(sizes)
}

fn publish(
    db: &Connection,
    owner: &str,
    request: &str,
    mutations: &[Mutation],
) -> Result<CommitResponse> {
    account::require_active(db, owner)?;
    if let Some(response) = cached(db, owner, request)? {
        return Ok(response);
    }
    check_conflicts(db, owner, mutations)?;
    let mut files = Vec::with_capacity(mutations.len());
    for mutation in mutations {
        let revision: i64 = db.query_row(
            "UPDATE sync_revision SET value=value+1 WHERE singleton=1 RETURNING value",
            [],
            |row| row.get(0),
        )?;
        db.execute("INSERT INTO sync_files(owner,path,revision,hash,size,chunks,deleted) VALUES (?,?,?,?,?,?,?) ON CONFLICT(owner,path) DO UPDATE SET revision=excluded.revision,hash=excluded.hash,size=excluded.size,chunks=excluded.chunks,deleted=excluded.deleted",
            params![owner, mutation.path, revision, mutation.hash, mutation.size, serde_json::to_string(&mutation.chunks)?, mutation.deleted])?;
        files.push(SyncFile {
            path: mutation.path.clone(),
            revision,
            hash: mutation.hash.clone(),
            size: mutation.size,
            chunks: mutation.chunks.clone(),
            deleted: mutation.deleted,
        });
    }
    let response = CommitResponse {
        files,
        cursor: revision(db)?,
    };
    db.execute(
        "INSERT INTO sync_commits VALUES (?,?,?)",
        params![owner, request, serde_json::to_string(&response)?],
    )?;
    Ok(response)
}

pub(crate) async fn manifest(
    State(state): State<AppState>,
    headers: HeaderMap,
    query: std::result::Result<Query<ManifestPage>, axum::extract::rejection::QueryRejection>,
) -> Result<Json<Manifest>> {
    let Query(page) = query.map_err(|_| ApiError::invalid("Invalid sync pagination"))?;
    if page.cursor < 0 || !(1..=500).contains(&page.limit) {
        return Err(ApiError::invalid(
            "Sync cursor must be nonnegative and limit must be 1–500",
        ));
    }
    let subject = state.subject(&headers).await?;
    let time = (state.clock)();
    state.db.call(move |db| {
        account::ensure(db, &subject, time)?;
        let mut files = db.prepare_cached("SELECT path,revision,hash,size,chunks,deleted FROM sync_files WHERE owner=? AND revision>? ORDER BY revision LIMIT ?")?
            .query_map(params![subject.id, page.cursor, page.limit + 1], read_file)?.collect::<rusqlite::Result<Vec<_>>>()?;
        let has_more = files.len() > page.limit;
        files.truncate(page.limit);
        let cursor = match files.last() { Some(file) => file.revision, None => revision(db)? };
        Ok(Json(Manifest { cursor, files, has_more }))
    }).await
}

pub(crate) async fn upload(
    State(state): State<AppState>,
    Path(hash): Path<String>,
    request: Request,
) -> Result<Json<crate::OkResponse>> {
    if !valid_hash(&hash) {
        return Err(ApiError::invalid("Chunk hash must be lowercase SHA256"));
    }
    let subject = state.subject(request.headers()).await?;
    let cloud = state.cloud_service()?;
    let _permit = state
        .sync_work
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| ApiError::internal())?;
    let _owner = state.owner_locks.acquire(&subject.id).await?;
    let owner = subject.id.clone();
    let time = (state.clock)();
    state
        .db
        .call(move |db| account::ensure(db, &subject, time))
        .await?;
    let bytes = tokio::time::timeout(
        Duration::from_secs(120),
        to_bytes(request.into_body(), CHUNK_BYTES),
    )
    .await
    .map_err(|_| ApiError::new(StatusCode::REQUEST_TIMEOUT, "Chunk upload timed out"))?
    .map_err(|_| {
        ApiError::new(
            StatusCode::PAYLOAD_TOO_LARGE,
            "Chunk exceeds 4 MiB or upload was interrupted",
        )
    })?;
    if bytes.is_empty() || auth::digest(&bytes) != hash {
        return Err(ApiError::invalid("Chunk content does not match its SHA256"));
    }
    let size = bytes.len();
    cloud.upload(&owner, &hash, bytes).await?;
    state.db.call(move |db| {
        account::require_active(db, &owner)?;
        db.execute("INSERT INTO sync_blobs VALUES (?,?,?) ON CONFLICT(owner,hash) DO UPDATE SET size=excluded.size", params![owner, hash, size])?;
        Ok(Json(crate::OkResponse { ok: true }))
    }).await
}

pub(crate) async fn download(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(hash): Path<String>,
) -> Result<Response> {
    if !valid_hash(&hash) {
        return Err(ApiError::invalid("Chunk hash must be lowercase SHA256"));
    }
    let subject = state.subject(&headers).await?;
    let cloud = state.cloud_service()?;
    let _permit = state
        .sync_work
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| ApiError::internal())?;
    let _owner = state.owner_locks.acquire(&subject.id).await?;
    let owner = subject.id.clone();
    let lookup = hash.clone();
    let time = (state.clock)();
    let size: usize = state
        .db
        .call(move |db| {
            account::ensure(db, &subject, time)?;
            db.query_row(
                "SELECT size FROM sync_blobs WHERE owner=? AND hash=?",
                params![subject.id, lookup],
                |row| row.get(0),
            )
            .optional()?
            .ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Chunk not found"))
        })
        .await?;
    let bytes = cloud.download(&owner, &hash).await?;
    if bytes.len() != size {
        return Err(cloud::unavailable(
            "Stored chunk size failed its integrity check",
        ));
    }
    Ok((
        [(header::CONTENT_TYPE, "application/octet-stream")],
        Body::from(bytes),
    )
        .into_response())
}

pub(crate) async fn commit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Input(body): Input<Commit>,
) -> Result<Json<CommitResponse>> {
    let subject = state.subject(&headers).await?;
    let cloud = state.cloud_service()?;
    let _permit = state
        .sync_work
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| ApiError::internal())?;
    let _owner = state.owner_locks.acquire(&subject.id).await?;
    let owner = subject.id.clone();
    let request = auth::digest(serde_json::to_vec(&body)?);
    let lookup = request.clone();
    let body = Arc::new(body);
    let prepared = body.clone();
    let time = (state.clock)();
    let (receipt, sizes) = state
        .db
        .call(move |db| {
            account::ensure(db, &subject, time)?;
            if let Some(response) = cached(db, &subject.id, &lookup)? {
                return Ok((Some(response), Vec::new()));
            }
            check_conflicts(db, &subject.id, &prepared.mutations)?;
            Ok((None, chunk_sizes(db, &subject.id, &prepared.mutations)?))
        })
        .await?;
    if let Some(response) = receipt {
        return Ok(Json(response));
    }
    for (mutation, sizes) in body.mutations.iter().zip(sizes) {
        if mutation.deleted {
            continue;
        }
        let mut digest = Sha256::new();
        for (hash, size) in mutation.chunks.iter().zip(sizes) {
            let bytes = cloud.download(&owner, hash).await?;
            if bytes.len() != size {
                return Err(cloud::unavailable(
                    "Stored chunk size failed its integrity check",
                ));
            }
            digest.update(&bytes);
        }
        if mutation.hash.as_deref() != Some(hex::encode(digest.finalize()).as_str()) {
            return Err(ApiError::invalid(
                "Whole-file SHA256 does not match its uploaded chunks",
            ));
        }
    }
    state
        .db
        .call(move |db| publish(db, &owner, &request, &body.mutations))
        .await
        .map(Json)
}

#[cfg(test)]
mod tests;
