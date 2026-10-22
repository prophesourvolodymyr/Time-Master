use crate::{
    ApiError, Result, auth, compat,
    model::*,
    rules::{self, Tracker, Variation},
};
use axum::http::StatusCode;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use rusqlite::{Connection, OptionalExtension, Row, TransactionBehavior, params};
use std::{path::PathBuf, time::Duration};
use subtle::ConstantTimeEq;
use tokio::sync::{mpsc, oneshot};

const WINDOW: f64 = 14400.0;
const LIMIT: i64 = 10;
const RECONNECT: f64 = 8.0;
type Job = Box<dyn FnOnce(&mut Connection) + Send>;

#[derive(Clone)]
pub(crate) struct Database {
    sender: mpsc::Sender<Job>,
}

impl Database {
    pub async fn open(path: PathBuf) -> Result<Self> {
        let (sender, mut receiver) = mpsc::channel::<Job>(128);
        let (ready, initialized) = oneshot::channel();
        std::thread::Builder::new()
            .name("ranked-sqlite".into())
            .spawn(move || {
                let opened = (|| -> Result<Connection> {
                    if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
                        std::fs::create_dir_all(parent)?;
                    }
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
                        std::fs::OpenOptions::new()
                            .read(true)
                            .write(true)
                            .create(true)
                            .truncate(false)
                            .mode(0o600)
                            .open(&path)?;
                        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))?;
                    }
                    let connection = Connection::open(path)?;
                    connection.busy_timeout(Duration::from_secs(15))?;
                    connection.set_prepared_statement_cache_capacity(64);
                    let version: i64 =
                        connection.query_row("PRAGMA user_version", [], |row| row.get(0))?;
                    if version > 2 {
                        return Err(ApiError::new(
                            StatusCode::INTERNAL_SERVER_ERROR,
                            "Database schema is newer than this service",
                        ));
                    }
                    connection.execute_batch(include_str!("../schema.sql"))?;
                    Ok(connection)
                })();
                match opened {
                    Ok(mut connection) => {
                        if ready.send(Ok(())).is_err() {
                            return;
                        }
                        while let Some(job) = receiver.blocking_recv() {
                            job(&mut connection);
                        }
                    }
                    Err(error) => {
                        let _ = ready.send(Err(error));
                    }
                }
            })?;
        initialized.await.map_err(|_| ApiError::internal())??;
        Ok(Self { sender })
    }

    pub async fn call<T, F>(&self, operation: F) -> Result<T>
    where
        T: Send + 'static,
        F: FnOnce(&Connection) -> Result<T> + Send + 'static,
    {
        let (reply, response) = oneshot::channel();
        self.sender
            .send(Box::new(move |connection| {
                let result = (|| {
                    let transaction =
                        connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
                    let value = operation(&transaction)?;
                    transaction.commit()?;
                    Ok(value)
                })();
                let _ = reply.send(result);
            }))
            .await
            .map_err(|_| ApiError::internal())?;
        response.await.map_err(|_| ApiError::internal())?
    }
}

pub(crate) fn authenticated(db: &Connection, access: &str, time: f64) -> Result<String> {
    db.prepare_cached(
        "SELECT user_id FROM sessions WHERE access_hash=? AND revoked=0 AND access_expires>?",
    )?
    .query_row(params![access, time], |row| row.get(0))
    .optional()?
    .ok_or_else(|| ApiError::new(StatusCode::UNAUTHORIZED, "Session expired · Sign in again"))
}

pub(crate) fn throttle(
    db: &Connection,
    address: &str,
    login: &str,
    registration: bool,
    time: f64,
) -> Result<()> {
    let mut input = String::with_capacity(address.len() + login.len().max(8));
    input.push_str(address);
    input.push_str(if registration { "register" } else { login });
    let bucket = auth::digest(input);
    let (span, limit) = if registration {
        (3600.0, 5)
    } else {
        (600.0, 10)
    };
    db.execute("DELETE FROM auth_limits WHERE at<?", [time - 3600.0])?;
    let count: i64 = db
        .prepare_cached("SELECT count(*) FROM auth_limits WHERE bucket=? AND at>?")?
        .query_row(params![bucket, time - span], |row| row.get(0))?;
    if count >= limit {
        return Err(ApiError::new(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many attempts · Try again later",
        ));
    }
    db.execute(
        "INSERT INTO auth_limits VALUES (?,?)",
        params![bucket, time],
    )?;
    Ok(())
}

pub(crate) fn grant(db: &Connection, uid: &str, family: Option<&str>, time: f64) -> Result<Grant> {
    let access = auth::token::<32>()?;
    let refresh = auth::token::<48>()?;
    let new_family;
    let family = match family {
        Some(family) => family,
        None => {
            new_family = auth::identifier()?;
            &new_family
        }
    };
    db.execute(
        "INSERT INTO sessions VALUES (?,?,?,?,?,?,0)",
        params![
            auth::digest(&access),
            auth::digest(&refresh),
            uid,
            family,
            time + 900.0,
            time + 2592000.0
        ],
    )?;
    Ok(Grant {
        access_token: access,
        refresh_token: refresh,
        expires_at: time + 900.0,
    })
}

pub(crate) fn register(
    db: &Connection,
    body: Registration,
    hashed: &str,
    time: f64,
) -> Result<Grant> {
    let uid = auth::identifier()?;
    let name = body.display_name.trim();
    match db.execute(
        "INSERT INTO accounts VALUES (?,?,?,?,?,?,?)",
        params![
            uid,
            auth::token::<16>()?,
            body.login,
            hashed,
            if name.is_empty() { "Athlete" } else { name },
            body.listed,
            time
        ],
    ) {
        Ok(_) => grant(db, &uid, None, time),
        Err(rusqlite::Error::SqliteFailure(error, _))
            if error.code == rusqlite::ErrorCode::ConstraintViolation =>
        {
            Err(ApiError::new(
                StatusCode::CONFLICT,
                "This login is unavailable",
            ))
        }
        Err(error) => Err(error.into()),
    }
}

pub(crate) fn refresh(db: &Connection, token: &str, time: f64) -> Result<Grant> {
    let row: Option<(String, String, String, f64, bool)> = db.prepare_cached("SELECT access_hash,user_id,family,refresh_expires,revoked FROM sessions WHERE refresh_hash=?")?
        .query_row([auth::digest(token)], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?))).optional()?;
    let Some((access, uid, family, _, _)) = row.filter(|r| r.3 > time && !r.4) else {
        return Err(ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Session expired · Sign in again",
        ));
    };
    db.execute(
        "UPDATE sessions SET revoked=1 WHERE access_hash=?",
        [access],
    )?;
    grant(db, &uid, Some(&family), time)
}

pub(crate) fn logout(db: &Connection, uid: &str, access: &str, time: f64) -> Result<()> {
    let family: String = db.query_row(
        "SELECT family FROM sessions WHERE access_hash=?",
        [access],
        |row| row.get(0),
    )?;
    cancel(db, uid, "Signed out", time)?;
    db.execute(
        "UPDATE sessions SET revoked=1 WHERE user_id=? AND family=?",
        params![uid, family],
    )?;
    Ok(())
}

fn variation(row: &Row<'_>, index: usize) -> rusqlite::Result<Variation> {
    let value: String = row.get(index)?;
    value.parse().map_err(|_| rusqlite::Error::InvalidQuery)
}

fn rating(db: &Connection, uid: &str, movement: Variation) -> Result<(i64, i64)> {
    Ok(db
        .prepare_cached("SELECT rating,games FROM ratings WHERE user_id=? AND variation=?")?
        .query_row(params![uid, movement.as_str()], |r| {
            Ok((r.get(0)?, r.get(1)?))
        })
        .optional()?
        .unwrap_or((1000, 0)))
}

pub(crate) fn allowance(
    db: &Connection,
    uid: &str,
    family: &'static str,
    time: f64,
) -> Result<Allowance> {
    if family == "core" {
        return Ok(Allowance {
            family,
            remaining: None,
            next_slot: None,
        });
    }
    let (count, first): (i64, Option<f64>) = db
        .prepare_cached(
            "SELECT count(*),min(at) FROM starts WHERE user_id=? AND family=? AND at>?",
        )?
        .query_row(params![uid, family, time - WINDOW], |r| {
            Ok((r.get(0)?, r.get(1)?))
        })?;
    Ok(Allowance {
        family,
        remaining: Some((LIMIT - count).max(0)),
        next_slot: if count >= LIMIT {
            first.map(|t| t + WINDOW)
        } else {
            None
        },
    })
}

fn account(db: &Connection, uid: &str) -> Result<Identity> {
    Ok(db
        .prepare_cached("SELECT public_id,display_name,listed FROM accounts WHERE id=?")?
        .query_row([uid], |r| {
            Ok(Identity {
                public_id: r.get(0)?,
                display_name: r.get(1)?,
                listed: r.get(2)?,
            })
        })?)
}

fn ratings(db: &Connection, uid: &str, earned_only: bool) -> Result<Vec<Rating>> {
    Ok(db.prepare_cached("SELECT variation,rating,games FROM ratings WHERE user_id=? AND (?=0 OR games>0) ORDER BY variation")?
        .query_map(params![uid, earned_only], |r| Ok(Rating { variation: variation(r, 0)?, rating: r.get(1)?, games: r.get(2)? }))?.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn me(db: &Connection, uid: &str, time: f64) -> Result<Account> {
    sweep(db, time)?;
    Ok(Account {
        identity: account(db, uid)?,
        ratings: ratings(db, uid, false)?,
        allowances: [
            allowance(db, uid, "pushUps", time)?,
            allowance(db, uid, "squats", time)?,
            allowance(db, uid, "core", time)?,
        ],
    })
}

pub(crate) fn privacy(db: &Connection, uid: &str, body: Privacy) -> Result<Identity> {
    let name = body.display_name.trim();
    db.execute(
        "UPDATE accounts SET display_name=?,listed=? WHERE id=?",
        params![
            if name.is_empty() { "Athlete" } else { name },
            body.listed,
            uid
        ],
    )?;
    account(db, uid)
}

struct MatchRecord {
    id: String,
    variation: Variation,
    rules: String,
    state: String,
    created: f64,
    ready_deadline: f64,
    start: Option<f64>,
    end: Option<f64>,
    reason: Option<String>,
    winner: Option<String>,
    revision: i64,
}

impl MatchRecord {
    fn from_row(row: &Row<'_>) -> rusqlite::Result<Self> {
        Ok(Self {
            id: row.get(0)?,
            variation: variation(row, 1)?,
            rules: row.get(2)?,
            state: row.get(3)?,
            created: row.get(4)?,
            ready_deadline: row.get(5)?,
            start: row.get(6)?,
            end: row.get(7)?,
            reason: row.get(9)?,
            winner: row.get(10)?,
            revision: row.get(11)?,
        })
    }
    fn terminal(&self) -> bool {
        terminal(&self.state)
    }
}

fn terminal(state: &str) -> bool {
    matches!(state, "completed" | "forfeited" | "invalid" | "cancelled")
}

fn owned(db: &Connection, uid: &str, mid: &str) -> Result<MatchRecord> {
    db.prepare_cached("SELECT m.* FROM matches m JOIN participants p ON p.match_id=m.id WHERE m.id=? AND p.user_id=?")?
        .query_row(params![mid, uid], MatchRecord::from_row).optional()?
        .ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Match unavailable"))
}

fn match_view(db: &Connection, uid: &str, mid: &str) -> Result<Match> {
    let m = owned(db, uid, mid)?;
    let participants = db.prepare_cached("SELECT a.public_id,a.display_name,p.user_id=?2,p.ready,p.score,p.last_seen,p.verification,p.before_rating,p.after_rating,CASE WHEN p.user_id=?2 THEN p.nonce END,CASE WHEN p.user_id=?2 THEN p.sequence END FROM participants p JOIN accounts a ON a.id=p.user_id WHERE match_id=?1 ORDER BY a.public_id")?
        .query_map(params![mid, uid], |r| Ok(Participant { public_id: r.get(0)?, display_name: r.get(1)?, is_you: r.get(2)?, ready: r.get(3)?, score: r.get(4)?, last_seen: r.get(5)?, verification: r.get(6)?, before_rating: r.get(7)?, after_rating: r.get(8)?, nonce: r.get(9)?, next_sequence: r.get(10)? }))?.collect::<rusqlite::Result<Vec<_>>>()?;
    let winner = m
        .winner
        .as_deref()
        .map(|id| {
            db.query_row("SELECT public_id FROM accounts WHERE id=?", [id], |r| {
                r.get(0)
            })
        })
        .transpose()?;
    Ok(Match {
        id: m.id,
        variation: m.variation,
        rule_version: m.rules,
        state: m.state,
        created_at: m.created,
        ready_deadline: m.ready_deadline,
        start_at: m.start,
        end_at: m.end,
        reason: m.reason,
        winner,
        revision: m.revision,
        participants,
    })
}

fn state_view(db: &Connection, uid: &str, time: f64) -> Result<ServiceState> {
    let active: Option<String> = db
        .prepare_cached("SELECT match_id FROM active WHERE user_id=?")?
        .query_row([uid], |r| r.get(0))
        .optional()?;
    let queue = db
        .prepare_cached("SELECT variation,created FROM queue WHERE user_id=?")?
        .query_row([uid], |r| {
            Ok(Queued {
                variation: variation(r, 0)?,
                expires_at: r.get::<_, f64>(1)? + 90.0,
            })
        })
        .optional()?;
    Ok(ServiceState {
        server_time: time,
        queue,
        r#match: active
            .as_deref()
            .map(|mid| match_view(db, uid, mid))
            .transpose()?,
    })
}

pub(crate) fn state(db: &Connection, uid: &str, time: f64) -> Result<ServiceState> {
    sweep(db, time)?;
    db.execute(
        "UPDATE queue SET heartbeat=? WHERE user_id=?",
        params![time, uid],
    )?;
    db.execute("UPDATE participants SET last_seen=? WHERE user_id=? AND match_id IN (SELECT match_id FROM active WHERE user_id=?)", params![time, uid, uid])?;
    state_view(db, uid, time)
}

pub(crate) fn enqueue(
    db: &Connection,
    uid: &str,
    body: QueueEntry,
    time: f64,
) -> Result<ServiceState> {
    let movement: Variation = body.variation.parse().map_err(|_| {
        ApiError::new(
            StatusCode::CONFLICT,
            "Update the app to use the current movement rules",
        )
    })?;
    if body.rule_version != rules::VERSION {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "Update the app to use the current movement rules",
        ));
    }
    if movement.is_advanced() {
        return Err(ApiError::invalid(
            "Ranked verification for this advanced movement needs validated recordings and support evidence. Real camera-tracked Practice is available.",
        ));
    }
    sweep(db, time)?;
    let seen: Option<String> = db
        .prepare_cached("SELECT operation FROM requests WHERE user_id=? AND request_id=?")?
        .query_row(params![uid, body.request_id], |r| r.get(0))
        .optional()?;
    if let Some(previous) = seen {
        if previous != body.variation {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "Request identity was already used for another movement",
            ));
        }
        return state_view(db, uid, time);
    }
    let busy: bool = db.prepare_cached("SELECT EXISTS(SELECT 1 FROM active WHERE user_id=?1) OR EXISTS(SELECT 1 FROM queue WHERE user_id=?1)")?.query_row([uid], |r| r.get(0))?;
    if busy {
        return state_view(db, uid, time);
    }
    if allowance(db, uid, movement.family(), time)?.remaining == Some(0) {
        return Err(ApiError::new(
            StatusCode::TOO_MANY_REQUESTS,
            "No match slots available · Wait for the next rolling slot",
        ));
    }
    let (rating, _) = rating(db, uid, movement)?;
    db.execute(
        "INSERT INTO requests VALUES (?,?,?,?)",
        params![uid, body.request_id, movement.as_str(), time],
    )?;
    db.execute(
        "INSERT INTO queue VALUES (?,?,?,?,?,?)",
        params![uid, movement.as_str(), rules::VERSION, rating, time, time],
    )?;
    pair(db, time)?;
    state_view(db, uid, time)
}

pub(crate) fn pair(db: &Connection, time: f64) -> Result<()> {
    struct Entry {
        uid: String,
        variation: Variation,
        rules: String,
        rating: i64,
        created: f64,
        claimed: bool,
    }
    let mut entries = db
        .prepare_cached(
            "SELECT user_id,variation,rules,rating,created FROM queue ORDER BY created,user_id",
        )?
        .query_map([], |r| {
            Ok(Entry {
                uid: r.get(0)?,
                variation: variation(r, 1)?,
                rules: r.get(2)?,
                rating: r.get(3)?,
                created: r.get(4)?,
                claimed: false,
            })
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    for i in 0..entries.len() {
        if entries[i].claimed {
            continue;
        }
        let a = &entries[i];
        let opponent = entries
            .iter()
            .enumerate()
            .filter(|(j, b)| {
                *j != i
                    && !b.claimed
                    && b.variation == a.variation
                    && b.rules == a.rules
                    && (a.rating - b.rating).abs()
                        <= (100
                            + 25 * (((time - a.created).min(time - b.created) / 10.0).trunc()
                                as i64))
                            .min(300)
            })
            .min_by(|(_, b), (_, c)| {
                (a.rating - b.rating)
                    .abs()
                    .cmp(&(a.rating - c.rating).abs())
                    .then_with(|| b.created.total_cmp(&c.created))
                    .then_with(|| b.uid.cmp(&c.uid))
            })
            .map(|(j, _)| j);
        let Some(j) = opponent else {
            continue;
        };
        let mid = auth::identifier()?;
        db.execute("INSERT INTO matches(id,variation,rules,state,created,ready_deadline) VALUES (?,?,?,'matched',?,?)", params![mid, a.variation.as_str(), rules::VERSION, time, time + 45.0])?;
        for index in [i, j] {
            let entry = &mut entries[index];
            db.execute("INSERT INTO participants(match_id,user_id,nonce,last_seen,tracker) VALUES (?,?,?,?,?)", params![mid, entry.uid, auth::token::<32>()?, time, serde_json::to_string(&Tracker::new(entry.variation))?])?;
            db.execute("INSERT INTO active VALUES (?,?)", params![entry.uid, mid])?;
            db.execute("DELETE FROM queue WHERE user_id=?", [&entry.uid])?;
            entry.claimed = true;
        }
    }
    Ok(())
}

pub(crate) fn cancel(db: &Connection, uid: &str, reason: &str, time: f64) -> Result<()> {
    sweep(db, time)?;
    db.execute("DELETE FROM queue WHERE user_id=?", [uid])?;
    let active: Option<String> = db
        .prepare_cached("SELECT match_id FROM active WHERE user_id=?")?
        .query_row([uid], |r| r.get(0))
        .optional()?;
    if let Some(mid) = active {
        let m = owned(db, uid, &mid)?;
        match m.state.as_str() {
            "matched" | "countdown" => finalize(db, &m, "cancelled", reason, None, time)?,
            "live" => {
                let other: String = db.query_row(
                    "SELECT user_id FROM participants WHERE match_id=? AND user_id<>?",
                    params![mid, uid],
                    |r| r.get(0),
                )?;
                finalize(db, &m, "forfeited", reason, Some(&other), time)?;
            }
            _ => {}
        }
    }
    Ok(())
}

pub(crate) fn cancel_queue(db: &Connection, uid: &str, time: f64) -> Result<ServiceState> {
    cancel(db, uid, "Cancelled before Go", time)?;
    state_view(db, uid, time)
}

fn response(db: &Connection, uid: &str, mid: &str, time: f64) -> Result<MatchResponse> {
    Ok(MatchResponse {
        server_time: time,
        r#match: match_view(db, uid, mid)?,
    })
}

pub(crate) fn get_match(db: &Connection, uid: &str, mid: &str, time: f64) -> Result<MatchResponse> {
    sweep(db, time)?;
    owned(db, uid, mid)?;
    db.execute(
        "UPDATE participants SET last_seen=? WHERE match_id=? AND user_id=?",
        params![time, mid, uid],
    )?;
    response(db, uid, mid, time)
}

pub(crate) fn ready(
    db: &Connection,
    uid: &str,
    mid: &str,
    body: Ready,
    time: f64,
) -> Result<MatchResponse> {
    sweep(db, time)?;
    let m = owned(db, uid, mid)?;
    if m.terminal() {
        return response(db, uid, mid, time);
    }
    if !matches!(m.state.as_str(), "matched" | "countdown") {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "The round has already started",
        ));
    }
    if !body.ready && m.state == "countdown" {
        finalize(
            db,
            &m,
            "cancelled",
            "Camera readiness was lost before Go",
            None,
            time,
        )?;
    } else {
        if body.ready {
            let poses = &body.calibration;
            if poses.len() < 10
                || !(1.4..=4.0).contains(&(poses[poses.len() - 1].time - poses[0].time))
            {
                return Err(ApiError::invalid(
                    "Hold a stable starting pose for calibration",
                ));
            }
            if poses.iter().any(|pose| {
                let a = rules::assess(pose, m.variation);
                !a.valid || !a.top
            }) || poses.windows(2).any(|pair| {
                let gap = pair[1].time - pair[0].time;
                gap <= 0.0 || gap > 0.25
            }) {
                return Err(ApiError::invalid(
                    "Calibration needs one visible athlete in the starting position",
                ));
            }
        }
        db.execute(
            "UPDATE participants SET ready=?,last_seen=? WHERE match_id=? AND user_id=?",
            params![body.ready, time, mid, uid],
        )?;
        db.execute("UPDATE matches SET revision=revision+1 WHERE id=?", [mid])?;
        let count: i64 = db.query_row(
            "SELECT count(*) FROM participants WHERE match_id=? AND ready=1",
            [mid],
            |r| r.get(0),
        )?;
        if count == 2 && m.state == "matched" {
            db.execute(
                "UPDATE matches SET state='countdown',start=?,end=?,revision=revision+1 WHERE id=?",
                params![time + 4.0, time + 64.0, mid],
            )?;
        }
    }
    response(db, uid, mid, time)
}

pub(crate) fn presence(
    db: &Connection,
    uid: &str,
    mid: &str,
    body: Presence,
    time: f64,
) -> Result<MatchResponse> {
    sweep(db, time)?;
    let m = owned(db, uid, mid)?;
    db.execute(
        "UPDATE participants SET last_seen=? WHERE match_id=? AND user_id=?",
        params![time, mid, uid],
    )?;
    if !body.active && m.state == "live" {
        let other: String = db.query_row(
            "SELECT user_id FROM participants WHERE match_id=? AND user_id<>?",
            params![mid, uid],
            |r| r.get(0),
        )?;
        finalize(
            db,
            &m,
            "forfeited",
            "Participant left or backgrounded after Go",
            Some(&other),
            time,
        )?;
    } else if !body.active && matches!(m.state.as_str(), "matched" | "countdown") {
        finalize(
            db,
            &m,
            "cancelled",
            "Participant left before Go",
            None,
            time,
        )?;
    } else if !body.calibrated && matches!(m.state.as_str(), "matched" | "countdown") {
        if m.state == "countdown" {
            finalize(
                db,
                &m,
                "cancelled",
                "Camera readiness was lost before Go",
                None,
                time,
            )?;
        } else {
            db.execute(
                "UPDATE participants SET ready=0 WHERE match_id=? AND user_id=?",
                params![mid, uid],
            )?;
        }
    }
    response(db, uid, mid, time)
}

pub(crate) fn evidence(
    db: &Connection,
    uid: &str,
    mid: &str,
    body: Evidence,
    time: f64,
) -> Result<Receipt> {
    sweep(db, time)?;
    let m = owned(db, uid, mid)?;
    let (nonce, sequence, snapshot, score, submitted): (String, i64, String, f64, bool) = db.prepare_cached("SELECT nonce,sequence,tracker,score,submitted FROM participants WHERE match_id=? AND user_id=?")?
        .query_row(params![mid, uid], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?)))?;
    if !bool::from(body.nonce.as_bytes().ct_eq(nonce.as_bytes())) || body.rule_version != m.rules {
        return Err(ApiError::new(
            StatusCode::FORBIDDEN,
            "Wrong match evidence context",
        ));
    }
    let serialized = compat::evidence_json(&body.frames)?;
    let fingerprint = auth::digest(&serialized);
    let existing: Option<String> = db
        .prepare_cached(
            "SELECT digest FROM evidence WHERE match_id=? AND user_id=? AND sequence=?",
        )?
        .query_row(params![mid, uid, body.sequence], |r| r.get(0))
        .optional()?;
    if let Some(existing) = existing {
        if !bool::from(fingerprint.as_bytes().ct_eq(existing.as_bytes())) {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "A different batch already uses this sequence",
            ));
        }
        return Ok(Receipt {
            next_sequence: sequence,
            score,
        });
    }
    if body.sequence != sequence {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "Evidence must arrive in order; reconnect to reconcile",
        ));
    }
    if !matches!(m.state.as_str(), "countdown" | "live" | "verifying")
        || m.start.is_none()
        || submitted
    {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This match no longer accepts new evidence",
        ));
    }
    let elapsed = time - m.start.unwrap_or(time);
    let mut tracker: Tracker = serde_json::from_str(&snapshot)?;
    for frame in &body.frames {
        if frame.time < -4.0
            || frame.time > 60.0
            || frame.time > elapsed + 0.35
            || frame.time < elapsed - RECONNECT
        {
            return Err(ApiError::invalid(
                "Evidence outside the shared scoring timeline",
            ));
        }
        if let Some(last) = tracker.last {
            if frame.time <= last {
                return Err(ApiError::new(
                    StatusCode::CONFLICT,
                    "Duplicate or reversed frame time",
                ));
            }
            if frame.time - last < 0.045 {
                return Err(ApiError::invalid("Evidence rate exceeds capture limits"));
            }
        }
        tracker.consume(frame).map_err(ApiError::invalid)?;
    }
    let next_sequence = body.sequence + body.frames.len() as i64;
    db.execute(
        "INSERT INTO evidence VALUES (?,?,?,?,?,?,?)",
        params![
            mid,
            uid,
            body.sequence,
            body.frames.len() as i64,
            fingerprint,
            serialized,
            time
        ],
    )?;
    db.execute("UPDATE participants SET sequence=?,tracker=?,score=?,last_seen=? WHERE match_id=? AND user_id=?", params![next_sequence, serde_json::to_string(&tracker)?, (tracker.score * 1000.0).round_ties_even() / 1000.0, time, mid, uid])?;
    db.execute("UPDATE matches SET revision=revision+1 WHERE id=?", [mid])?;
    Ok(Receipt {
        next_sequence,
        score: tracker.score,
    })
}

pub(crate) fn submit(db: &Connection, uid: &str, mid: &str, time: f64) -> Result<MatchResponse> {
    sweep(db, time)?;
    let m = owned(db, uid, mid)?;
    if m.end.is_none_or(|end| time < end) {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "The shared round has not ended",
        ));
    }
    if !m.terminal() {
        db.execute(
            "UPDATE participants SET submitted=1,last_seen=? WHERE match_id=? AND user_id=?",
            params![time, mid, uid],
        )?;
        sweep(db, time)?;
    }
    response(db, uid, mid, time)
}

pub(crate) fn leave(db: &Connection, uid: &str, mid: &str, time: f64) -> Result<MatchResponse> {
    let m = owned(db, uid, mid)?;
    let active: Option<String> = db
        .prepare_cached("SELECT match_id FROM active WHERE user_id=?")?
        .query_row([uid], |r| r.get(0))
        .optional()?;
    if active.as_deref() == Some(mid) {
        cancel(
            db,
            uid,
            if m.start.is_some_and(|start| time >= start) {
                "Participant left after Go"
            } else {
                "Participant cancelled before Go"
            },
            time,
        )?;
    }
    response(db, uid, mid, time)
}

struct PlayerRecord {
    uid: String,
    last_seen: f64,
    submitted: bool,
    score: f64,
}

fn participants(db: &Connection, mid: &str) -> Result<Vec<PlayerRecord>> {
    Ok(db.prepare_cached("SELECT user_id,last_seen,submitted,score FROM participants WHERE match_id=? ORDER BY user_id")?
        .query_map([mid], |r| Ok(PlayerRecord { uid: r.get(0)?, last_seen: r.get(1)?, submitted: r.get(2)?, score: r.get(3)? }))?.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn sweep(db: &Connection, time: f64) -> Result<()> {
    db.execute(
        "DELETE FROM queue WHERE heartbeat<? OR created<?",
        params![time - 12.0, time - 90.0],
    )?;
    db.execute(
        "UPDATE evidence SET frames=NULL WHERE received<? AND frames IS NOT NULL",
        [time - 86400.0],
    )?;
    let matches = db.prepare_cached("SELECT * FROM matches WHERE state NOT IN ('completed','forfeited','invalid','cancelled')")?
        .query_map([], MatchRecord::from_row)?.collect::<rusqlite::Result<Vec<_>>>()?;
    for mut m in matches {
        let ps = participants(db, &m.id)?;
        if ps.len() != 2 {
            return Err(ApiError::internal());
        }
        if matches!(m.state.as_str(), "matched" | "countdown") {
            if m.ready_deadline < time || ps.iter().any(|p| p.last_seen < time - RECONNECT) {
                finalize(
                    db,
                    &m,
                    "cancelled",
                    "Readiness expired before Go",
                    None,
                    time,
                )?;
                continue;
            }
            if m.state == "countdown" && m.start.is_some_and(|start| time >= start) {
                let start = m.start.unwrap_or(time);
                let family = m.variation.family();
                let mut unavailable = false;
                for p in &ps {
                    unavailable |= allowance(db, &p.uid, family, start)?.remaining == Some(0);
                }
                if unavailable {
                    finalize(
                        db,
                        &m,
                        "cancelled",
                        "A participant has no remaining family allowance",
                        None,
                        time,
                    )?;
                    continue;
                }
                if family != "core" {
                    for p in &ps {
                        db.execute(
                            "INSERT OR IGNORE INTO starts VALUES (?,?,?,?)",
                            params![p.uid, m.id, family, start],
                        )?;
                    }
                }
                db.execute(
                    "UPDATE matches SET state='live',revision=revision+1 WHERE id=?",
                    [&m.id],
                )?;
                m.state = "live".into();
            }
        }
        if m.state == "live" {
            let end = m.end.ok_or_else(ApiError::internal)?;
            let missing_a = ps[0].last_seen < time.min(end) - RECONNECT;
            let missing_b = ps[1].last_seen < time.min(end) - RECONNECT;
            if missing_a || missing_b {
                if missing_a && missing_b {
                    finalize(
                        db,
                        &m,
                        "invalid",
                        "Both participants disconnected",
                        None,
                        time,
                    )?;
                } else {
                    finalize(
                        db,
                        &m,
                        "forfeited",
                        "Reconnection grace expired after Go",
                        Some(&ps[usize::from(missing_a)].uid),
                        time,
                    )?;
                }
                continue;
            }
            if time >= end {
                db.execute(
                    "UPDATE matches SET state='verifying',revision=revision+1 WHERE id=?",
                    [&m.id],
                )?;
                m.state = "verifying".into();
            }
        }
        if m.state == "verifying"
            && (ps.iter().all(|p| p.submitted) || m.end.is_some_and(|end| time >= end + 12.0))
        {
            let mut sufficient = true;
            for p in &ps {
                let snapshot: String = db
                    .prepare_cached(
                        "SELECT tracker FROM participants WHERE match_id=? AND user_id=?",
                    )?
                    .query_row(params![m.id, p.uid], |row| row.get(0))?;
                let tracker: Tracker = serde_json::from_str(&snapshot)?;
                let valid = p.submitted
                    && tracker.covered_seconds >= 55.0
                    && tracker.valid_seconds >= 48.0
                    && tracker.last.unwrap_or(0.0) >= 59.5
                    && !m.variation.is_advanced();
                db.execute(
                    "UPDATE participants SET verification=? WHERE match_id=? AND user_id=?",
                    params![
                        if valid {
                            "motionValidated"
                        } else {
                            "insufficientEvidence"
                        },
                        m.id,
                        p.uid
                    ],
                )?;
                sufficient &= valid;
            }
            if !sufficient {
                finalize(
                    db,
                    &m,
                    "invalid",
                    "Insufficient movement evidence · No rating change",
                    None,
                    time,
                )?;
            } else {
                let a = score(ps[0].score, m.variation);
                let b = score(ps[1].score, m.variation);
                let winner = if a == b {
                    None
                } else {
                    Some(ps[usize::from(b > a)].uid.as_str())
                };
                finalize(
                    db,
                    &m,
                    "completed",
                    "Derived pose evidence validated · Hidden assistance and replay are not ruled out",
                    winner,
                    time,
                )?;
            }
        }
    }
    Ok(())
}

fn score(value: f64, variation: Variation) -> f64 {
    if variation.is_core() {
        (value * 10.0 + 0.0001).floor() / 10.0
    } else {
        value.trunc()
    }
}

fn finalize(
    db: &Connection,
    m: &MatchRecord,
    state: &str,
    reason: &str,
    winner: Option<&str>,
    time: f64,
) -> Result<()> {
    let current: String = db.query_row("SELECT state FROM matches WHERE id=?", [&m.id], |r| {
        r.get(0)
    })?;
    if terminal(&current) {
        return Ok(());
    }
    let ps = participants(db, &m.id)?;
    if ps.len() != 2 {
        return Err(ApiError::internal());
    }
    for p in &ps {
        db.execute(
            "UPDATE participants SET score=? WHERE match_id=? AND user_id=?",
            params![score(p.score, m.variation), m.id, p.uid],
        )?;
    }
    if matches!(state, "completed" | "forfeited") {
        let (ra, ga) = rating(db, &ps[0].uid, m.variation)?;
        let (rb, gb) = rating(db, &ps[1].uid, m.variation)?;
        let result = match winner {
            None => 0.5,
            Some(winner) if winner == ps[0].uid => 1.0,
            Some(_) => 0.0,
        };
        let (na, nb) = rules::elo(ra, rb, result, ga, gb);
        for (p, before, after, games) in [(&ps[0], ra, na, ga), (&ps[1], rb, nb, gb)] {
            db.execute("INSERT INTO ratings VALUES (?,?,?,?,'elo-1') ON CONFLICT(user_id,variation) DO UPDATE SET rating=excluded.rating,games=excluded.games,policy=excluded.policy", params![p.uid, m.variation.as_str(), after, games + 1])?;
            db.execute("UPDATE participants SET before_rating=?,after_rating=? WHERE match_id=? AND user_id=?", params![before, after, m.id, p.uid])?;
        }
    }
    db.execute(
        "UPDATE matches SET state=?,reason=?,winner=?,finalized=?,revision=revision+1 WHERE id=?",
        params![state, reason, winner, time, m.id],
    )?;
    db.execute("DELETE FROM active WHERE match_id=?", [&m.id])?;
    Ok(())
}

fn encode_cursor<T: serde::Serialize>(value: &T) -> Result<String> {
    Ok(URL_SAFE_NO_PAD.encode(serde_json::to_vec(value)?))
}

fn decode_cursor<T: serde::de::DeserializeOwned>(value: &str) -> Result<T> {
    if value.len() > 256 {
        return Err(ApiError::invalid("Invalid page cursor"));
    }
    let decoded = URL_SAFE_NO_PAD
        .decode(value.trim_end_matches('='))
        .map_err(|_| ApiError::invalid("Invalid page cursor"))?;
    serde_json::from_slice(&decoded).map_err(|_| ApiError::invalid("Invalid page cursor"))
}

pub(crate) fn history(
    db: &Connection,
    uid: &str,
    cursor: Option<&str>,
    time: f64,
) -> Result<History> {
    sweep(db, time)?;
    let cursor: Option<(f64, String)> = cursor
        .filter(|c| !c.is_empty())
        .map(decode_cursor)
        .transpose()?;
    if cursor.as_ref().is_some_and(|(at, _)| !at.is_finite()) {
        return Err(ApiError::invalid("Invalid history cursor"));
    }
    let (at, id) = cursor
        .as_ref()
        .map(|(at, id)| (Some(*at), id.as_str()))
        .unwrap_or((None, ""));
    let rows = db.prepare_cached("SELECT m.id,m.created FROM matches m JOIN participants p ON m.id=p.match_id WHERE p.user_id=?1 AND (?2 IS NULL OR m.created<?2 OR (m.created=?2 AND m.id<?3)) ORDER BY m.created DESC,m.id DESC LIMIT 21")?
        .query_map(params![uid, at, id], |r| Ok((r.get::<_, String>(0)?, r.get::<_, f64>(1)?)))?.collect::<rusqlite::Result<Vec<_>>>()?;
    let next_cursor = if rows.len() > 20 {
        Some(encode_cursor(&(rows[19].1, &rows[19].0))?)
    } else {
        None
    };
    let matches = rows
        .iter()
        .take(20)
        .map(|(id, _)| match_view(db, uid, id))
        .collect::<Result<Vec<_>>>()?;
    Ok(History {
        matches,
        next_cursor,
    })
}

const LADDER_ME: &str = "WITH ladder AS (SELECT a.public_id,a.display_name,r.rating,r.games,row_number() OVER (ORDER BY r.rating DESC,a.public_id ASC) position FROM ratings r JOIN accounts a ON a.id=r.user_id WHERE r.variation=?1 AND r.games>0 AND a.listed=1) SELECT * FROM ladder WHERE public_id=?2";
const LADDER_PAGE: &str = "WITH ladder AS (SELECT a.public_id,a.display_name,r.rating,r.games,row_number() OVER (ORDER BY r.rating DESC,a.public_id ASC) position FROM ratings r JOIN accounts a ON a.id=r.user_id WHERE r.variation=?1 AND r.games>0 AND a.listed=1) SELECT * FROM ladder WHERE (?2 IS NULL OR rating<?2 OR (rating=?2 AND public_id>?3)) ORDER BY rating DESC,public_id ASC LIMIT 21 OFFSET ?4";

fn standing(row: &Row<'_>) -> rusqlite::Result<Standing> {
    Ok(Standing {
        public_id: row.get(0)?,
        display_name: row.get(1)?,
        rating: row.get(2)?,
        games: row.get(3)?,
        position: row.get(4)?,
    })
}

pub(crate) fn leaderboard(
    db: &Connection,
    uid: &str,
    movement: Variation,
    cursor: Option<&str>,
    around_me: bool,
) -> Result<Leaderboard> {
    let identity = account(db, uid)?;
    let mine = db
        .prepare_cached(LADDER_ME)?
        .query_row(params![movement.as_str(), identity.public_id], standing)
        .optional()?;
    let offset = if around_me {
        mine.as_ref().map_or(0, |me| (me.position - 10).max(0))
    } else {
        0
    };
    let cursor: Option<(i64, String)> = if around_me {
        None
    } else {
        cursor
            .filter(|c| !c.is_empty())
            .map(decode_cursor)
            .transpose()?
    };
    let (rating, id) = cursor
        .as_ref()
        .map(|(rating, id)| (Some(*rating), id.as_str()))
        .unwrap_or((None, ""));
    let mut rows = db
        .prepare_cached(LADDER_PAGE)?
        .query_map(params![movement.as_str(), rating, id, offset], standing)?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    let next_cursor = if rows.len() > 20 {
        Some(encode_cursor(&(rows[19].rating, &rows[19].public_id))?)
    } else {
        None
    };
    rows.truncate(20);
    Ok(Leaderboard {
        rows,
        me: mine,
        next_cursor,
    })
}

pub(crate) fn player(db: &Connection, public_id: &str) -> Result<Player> {
    let found: Option<(String, String, String)> = db
        .prepare_cached(
            "SELECT id,public_id,display_name FROM accounts WHERE public_id=? AND listed=1",
        )?
        .query_row([public_id], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
        .optional()?;
    let Some((uid, public_id, display_name)) = found else {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "This player does not share a public Ranked profile",
        ));
    };
    Ok(Player {
        public_id,
        display_name,
        ratings: ratings(db, &uid, true)?,
    })
}
