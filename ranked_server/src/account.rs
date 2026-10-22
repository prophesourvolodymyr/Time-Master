use crate::{ApiError, Result, auth, cloud::Subject, model::Account, store};
use axum::http::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};

pub(crate) fn ensure(db: &Connection, subject: &Subject, time: f64) -> Result<()> {
    db.execute(
        "INSERT OR IGNORE INTO cloud_accounts(subject,created) VALUES (?,?)",
        params![subject.id, time],
    )?;
    require_active(db, &subject.id)
}

pub(crate) fn require_active(db: &Connection, owner: &str) -> Result<()> {
    let deleting: Option<i64> = db
        .query_row(
            "SELECT deleting FROM cloud_accounts WHERE subject=?",
            [owner],
            |row| row.get(0),
        )
        .optional()?;
    match deleting {
        Some(0) => Ok(()),
        Some(_) => Err(ApiError::new(
            StatusCode::GONE,
            "Account deletion is in progress or completed",
        )),
        None => Err(crate::cloud::unauthorized()),
    }
}

pub(crate) fn ranked_identity(db: &Connection, subject: &Subject, time: f64) -> Result<String> {
    ensure(db, subject, time)?;
    let existing: Option<String> = db.query_row(
        "SELECT ranked_user_id FROM cloud_accounts WHERE subject=?",
        [&subject.id],
        |row| row.get(0),
    )?;
    if let Some(uid) = existing {
        return Ok(uid);
    }
    let uid = format!("supabase:{}", subject.id);
    db.execute(
        "INSERT INTO accounts VALUES (?,?,?,?,?,0,?)",
        params![
            uid,
            auth::token::<16>()?,
            uid,
            "",
            subject.display_name,
            time
        ],
    )?;
    db.execute(
        "UPDATE cloud_accounts SET ranked_user_id=? WHERE subject=?",
        params![uid, subject.id],
    )?;
    Ok(uid)
}

pub(crate) fn link(db: &Connection, subject: &Subject, legacy: &str, time: f64) -> Result<Account> {
    ensure(db, subject, time)?;
    let (current, linked): (Option<String>, bool) = db.query_row(
        "SELECT ranked_user_id,legacy_linked FROM cloud_accounts WHERE subject=?",
        [&subject.id],
        |row| Ok((row.get(0)?, row.get(1)?)),
    )?;
    let claimed: bool = db.query_row(
        "SELECT EXISTS(SELECT 1 FROM cloud_accounts WHERE ranked_user_id=?)",
        [legacy],
        |row| row.get(0),
    )?;
    if linked || claimed {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This Ranked account or TimeMaster account is already linked",
        ));
    }
    if let Some(current) = current {
        let used: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM participants WHERE user_id=?1) OR EXISTS(SELECT 1 FROM queue WHERE user_id=?1) OR EXISTS(SELECT 1 FROM ratings WHERE user_id=?1) OR EXISTS(SELECT 1 FROM requests WHERE user_id=?1) OR EXISTS(SELECT 1 FROM starts WHERE user_id=?1) OR EXISTS(SELECT 1 FROM active WHERE user_id=?1) OR EXISTS(SELECT 1 FROM physique_profiles WHERE user_id=?1)",
            [&current], |row| row.get(0),
        )?;
        if used {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "Link your existing account before starting Ranked or Physique on this TimeMaster account",
            ));
        }
        db.execute(
            "UPDATE cloud_accounts SET ranked_user_id=NULL WHERE subject=?",
            [&subject.id],
        )?;
        db.execute("DELETE FROM sessions WHERE user_id=?", [&current])?;
        db.execute("DELETE FROM accounts WHERE id=?", [&current])?;
    }
    db.execute(
        "UPDATE cloud_accounts SET ranked_user_id=?,legacy_linked=1 WHERE subject=?",
        params![legacy, subject.id],
    )?;
    db.execute("UPDATE sessions SET revoked=1 WHERE user_id=?", [legacy])?;
    store::me(db, legacy, time)
}

pub(crate) fn begin_deletion(db: &Connection, subject: &Subject, time: f64) -> Result<bool> {
    db.execute(
        "INSERT OR IGNORE INTO cloud_accounts(subject,created) VALUES (?,?)",
        params![subject.id, time],
    )?;
    let status: i64 = db.query_row(
        "SELECT deleting FROM cloud_accounts WHERE subject=?",
        [&subject.id],
        |row| row.get(0),
    )?;
    if status == 2 {
        return Ok(false);
    }
    db.execute(
        "UPDATE cloud_accounts SET deleting=1 WHERE subject=?",
        [&subject.id],
    )?;
    let uid: Option<String> = db.query_row(
        "SELECT ranked_user_id FROM cloud_accounts WHERE subject=?",
        [&subject.id],
        |row| row.get(0),
    )?;
    if let Some(uid) = uid {
        store::cancel(db, &uid, "Account deletion requested", time)?;
        crate::physique::begin_deletion(db, &uid, time)?;
    }
    Ok(true)
}

pub(crate) fn finish_deletion(db: &Connection, owner: &str, time: f64) -> Result<()> {
    let uid: Option<String> = db.query_row(
        "SELECT ranked_user_id FROM cloud_accounts WHERE subject=?",
        [owner],
        |row| row.get(0),
    )?;
    if let Some(uid) = uid {
        store::cancel(db, &uid, "Account deleted", time)?;
        crate::physique::finish_deletion(db, &uid, time)?;
        for table in [
            "sessions", "evidence", "queue", "requests", "starts", "active", "ratings",
        ] {
            db.execute(&format!("DELETE FROM {table} WHERE user_id=?"), [&uid])?;
        }
        db.execute("UPDATE participants SET nonce='',tracker=json_object('variation',(SELECT variation FROM matches WHERE matches.id=participants.match_id)) WHERE user_id=?", [&uid])?;
        db.execute("UPDATE accounts SET login=?,password='',display_name='Deleted athlete',public_id=?,listed=0 WHERE id=?", params![format!("deleted:{}", auth::identifier()?), auth::token::<16>()?, uid])?;
    }
    for table in ["sync_files", "sync_blobs", "sync_commits"] {
        db.execute(&format!("DELETE FROM {table} WHERE owner=?"), [owner])?;
    }
    db.execute(
        "UPDATE cloud_accounts SET ranked_user_id=NULL,legacy_linked=0,deleting=2 WHERE subject=?",
        [owner],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests;
