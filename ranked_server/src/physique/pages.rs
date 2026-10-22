use super::{competition as comp, model::*};
use crate::{ApiError, Result, auth};
use axum::http::StatusCode;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct Saved<T> {
    items: Vec<T>,
}
fn expired() -> ApiError {
    ApiError::new(
        StatusCode::CONFLICT,
        "This saved Physique page expired or changed. Show latest to continue",
    )
}
fn slice<T: Serialize + for<'de> Deserialize<'de>>(
    db: &Connection,
    uid: &str,
    kind: &str,
    cursor: Option<&str>,
    fresh: impl FnOnce() -> Result<Vec<T>>,
    time: f64,
) -> Result<(Vec<T>, Option<String>)> {
    let (id, offset, items) = if let Some(cursor) = cursor {
        if cursor.len() > 200 {
            return Err(expired());
        }
        let bytes = URL_SAFE_NO_PAD.decode(cursor).map_err(|_| expired())?;
        let value = String::from_utf8(bytes).map_err(|_| expired())?;
        let (id, offset) = value.split_once(':').ok_or_else(expired)?;
        let offset = offset.parse::<usize>().map_err(|_| expired())?;
        if offset == 0 || offset % 20 != 0 {
            return Err(expired());
        }
        let data: Option<String> = db
            .query_row(
                "SELECT data FROM physique_pages WHERE id=? AND owner=? AND kind=? AND expires>?",
                params![id, uid, kind, time],
                |r| r.get(0),
            )
            .optional()?;
        let saved: Saved<T> = serde_json::from_str(&data.ok_or_else(expired)?)?;
        if offset >= saved.items.len() {
            return Err(expired());
        }
        (id.to_owned(), offset, saved.items)
    } else {
        let items = fresh()?;
        let id = auth::identifier()?;
        db.execute(
            "INSERT INTO physique_pages VALUES (?,?,?,?,?)",
            params![
                id,
                uid,
                kind,
                serde_json::to_string(&serde_json::json!({"items":&items}))?,
                time + 900.0
            ],
        )?;
        (id, 0, items)
    };
    let total = items.len();
    let next =
        (offset + 20 < total).then(|| URL_SAFE_NO_PAD.encode(format!("{id}:{}", offset + 20)));
    Ok((items.into_iter().skip(offset).take(20).collect(), next))
}
pub fn history(db: &Connection, uid: &str, cursor: Option<&str>, time: f64) -> Result<Page<Match>> {
    let (ids, cursor) = slice(
        db,
        uid,
        "history",
        cursor,
        || {
            Ok(db.prepare_cached("SELECT m.id FROM physique_matches m JOIN physique_participants p ON p.match_id=m.id JOIN physique_starts s ON s.match_id=m.id AND s.user_id=p.user_id WHERE p.user_id=? ORDER BY s.at DESC,m.id DESC")?.query_map([uid],|r|r.get::<_,String>(0))?.collect::<rusqlite::Result<_>>()?)
        },
        time,
    )?;
    Ok(Page {
        items: ids
            .into_iter()
            .map(|id| comp::match_view(db, uid, &id, time))
            .collect::<Result<_>>()?,
        cursor,
    })
}
pub fn standing(db: &Connection, viewer: &str, public: &str, time: f64) -> Result<Standing> {
    let uid = comp::resolve_target(db, viewer, public, time)?;
    if uid != viewer && (!comp::is_public(db, &uid, time)? || comp::blocked(db, viewer, &uid)?) {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "Current public Physique identity is unavailable",
        ));
    }
    let (identity, record) = comp::identity_and_record(db, &uid)?;
    let position = if comp::is_public(db, &uid, time)? {
        let rating = record.rating.ok_or_else(ApiError::internal)?;
        let candidates:Vec<String>=db.prepare_cached("SELECT user_id FROM physique_profiles WHERE listed=1 AND deleted=0 AND rating>? ORDER BY user_id")?.query_map([rating],|r|r.get(0))?.collect::<rusqlite::Result<_>>()?;
        let mut above = 0;
        for other in candidates {
            if comp::is_public(db, &other, time)? {
                above += 1
            }
        }
        Some(above + 1)
    } else {
        None
    };
    Ok(Standing {
        id: identity.id.clone(),
        position,
        identity,
        record,
    })
}
pub fn standings(
    db: &Connection,
    uid: &str,
    cursor: Option<&str>,
    time: f64,
) -> Result<Page<Standing>> {
    let (items, cursor) = slice(
        db,
        uid,
        "standings",
        cursor,
        || {
            let ids:Vec<String>=db.prepare_cached("SELECT user_id FROM physique_profiles WHERE listed=1 AND deleted=0 ORDER BY rating DESC,user_id")?.query_map([],|r|r.get(0))?.collect::<rusqlite::Result<_>>()?;
            let mut items = Vec::new();
            let (mut last, mut rank, mut index) = (None, 0, 0);
            for id in ids {
                if !comp::is_public(db, &id, time)? {
                    continue;
                }
                let (identity, record) = comp::identity_and_record(db, &id)?;
                index += 1;
                if last != identity.rating {
                    rank = index;
                    last = identity.rating;
                }
                if !comp::blocked(db, uid, &id)? {
                    items.push(Standing {
                        id: identity.id.clone(),
                        position: Some(rank),
                        identity,
                        record,
                    });
                }
            }
            Ok(items)
        },
        time,
    )?;
    let mut visible = Vec::new();
    for mut row in items {
        let owner: Option<String> = db
            .query_row(
                "SELECT id FROM accounts WHERE public_id=?",
                [&row.id],
                |r| r.get(0),
            )
            .optional()?;
        let Some(owner) = owner else { continue };
        if !comp::is_public(db, &owner, time)? || comp::blocked(db, uid, &owner)? {
            continue;
        }
        let country: Option<String> = db.query_row(
            "SELECT country_code FROM physique_profiles WHERE user_id=?",
            [&owner],
            |r| r.get(0),
        )?;
        row.identity.country_code = country;
        visible.push(row);
    }
    Ok(Page {
        items: visible,
        cursor,
    })
}
