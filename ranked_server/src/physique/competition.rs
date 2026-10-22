use super::{
    judge::{Settings, Verdict},
    model::*,
};
use crate::{ApiError, Result, auth};
use axum::http::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};

pub const WINDOW: f64 = 14400.0;
pub const LIMIT: i64 = 10;
pub const POSES: [&str; 3] = ["front", "side", "rear"];

pub fn ensure(db: &Connection, uid: &str) -> Result<()> {
    db.execute(
        "INSERT OR IGNORE INTO physique_profiles(user_id) VALUES (?)",
        [uid],
    )?;
    let deleted: bool = db.query_row(
        "SELECT deleted FROM physique_profiles WHERE user_id=?",
        [uid],
        |r| r.get(0),
    )?;
    if deleted {
        return Err(ApiError::new(
            StatusCode::GONE,
            "This account is no longer available",
        ));
    }
    Ok(())
}
pub fn consent(db: &Connection, uid: &str) -> Result<Consent> {
    let value: String = db.query_row(
        "SELECT consent FROM physique_profiles WHERE user_id=?",
        [uid],
        |r| r.get(0),
    )?;
    Ok(serde_json::from_str(&value)?)
}
pub fn blocked(db: &Connection, a: &str, b: &str) -> Result<bool> {
    Ok(db.query_row("SELECT EXISTS(SELECT 1 FROM physique_blocks WHERE (owner=?1 AND target=?2) OR (owner=?2 AND target=?1))",params![a,b],|r|r.get(0))?)
}
pub fn restricted(db: &Connection, uid: &str, time: f64) -> Result<Option<String>> {
    Ok(db.query_row("SELECT CASE WHEN restricted_until IS NULL OR restricted_until>?2 THEN restricted_reason END FROM physique_profiles WHERE user_id=?1",params![uid,time],|r|r.get(0))?)
}
pub fn allowance(db: &Connection, uid: &str, time: f64) -> Result<Allowance> {
    let (count, first): (i64, Option<f64>) = db.query_row(
        "SELECT count(*),min(at) FROM physique_starts WHERE user_id=? AND at>? AND restored=0",
        params![uid, time - WINDOW],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    let reserved: bool = db.query_row("SELECT EXISTS(SELECT 1 FROM physique_queue WHERE user_id=?1) OR EXISTS(SELECT 1 FROM physique_active a JOIN physique_matches m ON m.id=a.match_id WHERE a.user_id=?1 AND m.stage IN ('ready','countdown'))",[uid],|r|r.get(0))?;
    Ok(Allowance {
        remaining: (LIMIT - count - i64::from(reserved)).max(0),
        limit: LIMIT,
        next_available_at: if count >= LIMIT {
            first.map(|v| v + WINDOW)
        } else {
            None
        },
    })
}
pub fn eligible(
    db: &Connection,
    uid: &str,
    settings: &Settings,
    time: f64,
    needs_sharing: bool,
) -> Result<()> {
    settings.require_ready()?;
    ensure(db, uid)?;
    if let Some(reason) = restricted(db, uid, time)? {
        return Err(ApiError::new(StatusCode::FORBIDDEN, reason));
    }
    let consent = consent(db, uid)?;
    if !consent.adult
        || !consent.rules_accepted
        || !consent.ai_processing
        || consent.policy_version != settings.policy.version
        || (needs_sharing && !consent.opponent_sharing)
    {
        return Err(ApiError::new(
            StatusCode::FORBIDDEN,
            "Current adult eligibility, rules and separate sharing choices are required",
        ));
    }
    Ok(())
}
#[derive(Clone)]
pub struct Summary {
    pub record: Record,
    pub streak: i64,
    pub badges: Vec<Badge>,
}
pub fn summary(db: &Connection, uid: &str) -> Result<Summary> {
    let rating: i64 = db.query_row(
        "SELECT rating FROM physique_profiles WHERE user_id=?",
        [uid],
        |r| r.get(0),
    )?;
    let rows:Vec<(String,f64)> = db.prepare_cached("SELECT p.outcome,m.start FROM physique_participants p JOIN physique_matches m ON m.id=p.match_id WHERE p.user_id=? AND p.outcome IS NOT NULL AND m.start IS NOT NULL ORDER BY m.start,m.id")?.query_map([uid],|r|Ok((r.get(0)?,r.get(1)?)))?.collect::<rusqlite::Result<_>>()?;
    let (mut wins, mut losses, mut draws, mut judged, mut streak) = (0, 0, 0, 0, 0);
    let (mut first_bell, mut ten_rounds, mut three_straight, mut placed) = (None, None, None, None);
    for (outcome, at) in rows {
        match outcome.as_str() {
            "win" | "forfeitWin" => {
                wins += 1;
                streak += 1;
            }
            "loss" | "forfeitLoss" => {
                losses += 1;
                streak = 0;
            }
            "draw" => {
                draws += 1;
                streak = 0;
            }
            _ => continue,
        }
        if ["win", "loss", "draw"].contains(&outcome.as_str()) {
            judged += 1;
            if first_bell.is_none() {
                first_bell = Some(at)
            }
            if judged == 10 {
                ten_rounds = Some(at)
            }
        }
        if wins + losses + draws == 5 {
            placed = Some(at);
        }
        if streak >= 3 && three_straight.is_none() {
            three_straight = Some(at)
        }
    }
    let games = wins + losses + draws;
    let best:Option<i64> = db.query_row("SELECT max(e.after_rating) FROM physique_rating_events e JOIN physique_participants p ON p.match_id=e.match_id AND p.user_id=e.user_id WHERE e.user_id=? AND e.kind IN ('result','correction') AND p.outcome IN ('win','loss','draw','forfeitWin','forfeitLoss')",[uid],|r|r.get(0))?;
    let mut badges = Vec::new();
    if games >= 5 {
        let tier = tier(rating);
        badges.push(Badge{id:"placed".into(),title:format!("{tier} · Placed"),symbol:tier.to_lowercase(),detail:"Five rated Physique results completed. Current competitive placement, not identity verification.".into(),earned_at:placed});
    }
    for (id, title, symbol, detail, earned_at) in [
        (
            "firstBell",
            "First Bell",
            "bell",
            "First valid AI-judged Physique match, win, loss, or draw.",
            first_bell,
        ),
        (
            "tenRounds",
            "Ten Rounds",
            "10.circle",
            "Ten effective valid AI-judged Physique matches. Forfeits do not count.",
            ten_rounds,
        ),
        (
            "threeStraight",
            "Three Straight",
            "flag.3.crossed",
            "Earned for a past run of three Physique wins. Current streak is separate.",
            three_straight,
        ),
    ] {
        if earned_at.is_some() {
            badges.push(Badge {
                id: id.into(),
                title: title.into(),
                symbol: symbol.into(),
                detail: detail.into(),
                earned_at,
            });
        }
    }
    Ok(Summary {
        record: Record {
            rating: (games > 0).then_some(rating),
            best: if games > 0 {
                best.or(Some(rating))
            } else {
                None
            },
            games,
            wins,
            losses,
            draws,
        },
        streak,
        badges,
    })
}
pub fn tier(rating: i64) -> &'static str {
    match rating {
        0..=799 => "Iron",
        800..=999 => "Bronze",
        1000..=1399 => "Silver",
        1400..=1799 => "Gold",
        1800..=2199 => "Diamond",
        _ => "Champion",
    }
}
pub fn identity_and_record(db: &Connection, uid: &str) -> Result<(Identity, Record)> {
    let (id,name,country):(String,String,Option<String>)=db.query_row("SELECT a.public_id,p.display_name,p.country_code FROM accounts a JOIN physique_profiles p ON p.user_id=a.id WHERE a.id=? AND p.deleted=0",[uid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?)))?;
    let data = summary(db, uid)?;
    let identity = Identity {
        id,
        display_name: name,
        country_code: country,
        rating: data.record.rating,
        games: data.record.games,
        tier: if data.record.games >= 5 {
            data.record.rating.map(|v| tier(v).to_owned())
        } else {
            None
        },
        badges: data.badges,
        streak: Some(data.streak),
    };
    Ok((identity, data.record))
}
pub fn account(db: &Connection, uid: &str, time: f64) -> Result<Account> {
    let listed: bool = db.query_row(
        "SELECT listed FROM physique_profiles WHERE user_id=?",
        [uid],
        |r| r.get(0),
    )?;
    let (identity, record) = identity_and_record(db, uid)?;
    Ok(Account {
        identity,
        consent: consent(db, uid)?,
        consent_revision: Some(super::cases::consent_revision(db, uid)?),
        record,
        allowance: allowance(db, uid, time)?,
        listed,
        restricted_reason: restricted(db, uid, time)?,
    })
}
pub fn active(db: &Connection, uid: &str) -> Result<Option<String>> {
    Ok(db
        .query_row(
            "SELECT match_id FROM physique_active WHERE user_id=?",
            [uid],
            |r| r.get(0),
        )
        .optional()?)
}
pub fn require_member(db: &Connection, uid: &str, mid: &str) -> Result<String> {
    db.query_row(
        "SELECT slot FROM physique_participants WHERE user_id=? AND match_id=?",
        params![uid, mid],
        |r| r.get(0),
    )
    .optional()?
    .ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Physique match is unavailable"))
}
pub fn resolve_target(db: &Connection, viewer: &str, public: &str, time: f64) -> Result<String> {
    let uid:Option<String>=db.query_row("SELECT a.id FROM accounts a JOIN physique_profiles p ON p.user_id=a.id WHERE a.public_id=? AND p.deleted=0",[public],|r|r.get(0)).optional()?;
    let uid = uid.ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Player is unavailable"))?;
    if uid == viewer {
        return Ok(uid);
    }
    let paired:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_participants x JOIN physique_participants y ON y.match_id=x.match_id WHERE x.user_id=? AND y.user_id=?)",params![viewer,uid],|r|r.get(0))?;
    if !paired && (!is_public(db, &uid, time)? || blocked(db, viewer, &uid)?) {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "Player is unavailable",
        ));
    }
    Ok(uid)
}
pub fn is_public(db: &Connection, uid: &str, time: f64) -> Result<bool> {
    let row: Option<(bool, bool)> = db
        .query_row(
            "SELECT listed,deleted FROM physique_profiles WHERE user_id=?",
            [uid],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    let Some((listed, deleted)) = row else {
        return Ok(false);
    };
    if !listed || deleted || restricted(db, uid, time)?.is_some() {
        return Ok(false);
    }
    Ok(db.query_row("SELECT EXISTS(SELECT 1 FROM physique_participants WHERE user_id=? AND outcome IN ('win','loss','draw','forfeitWin','forfeitLoss') LIMIT 1 OFFSET 4)",[uid],|r|r.get(0))?)
}
pub fn start_search(db: &Connection, uid: &str, settings: &Settings, time: f64) -> Result<String> {
    eligible(db, uid, settings, time, true)?;
    if active(db, uid)?.is_some() {
        return Ok("Existing Physique match restored".into());
    }
    if db.query_row(
        "SELECT EXISTS(SELECT 1 FROM physique_queue WHERE user_id=?)",
        [uid],
        |r| r.get::<_, bool>(0),
    )? {
        return Ok("Existing opponent search restored".into());
    }
    if allowance(db, uid, time)?.remaining == 0 {
        return Err(ApiError::new(
            StatusCode::TOO_MANY_REQUESTS,
            "No Physique allowance is available in the rolling four-hour window",
        ));
    }
    db.execute(
        "INSERT INTO physique_queue VALUES (?,?,?,?)",
        params![uid, time, time, settings.key],
    )?;
    db.execute("INSERT INTO physique_queue_status(user_id,status,updated) VALUES (?,'searching',?) ON CONFLICT(user_id) DO UPDATE SET status='searching',updated=excluded.updated",params![uid,time])?;
    pair(db, settings, time)?;
    Ok("Opponent search started".into())
}
pub fn cancel(db: &Connection, uid: &str, time: f64) -> Result<()> {
    db.execute("DELETE FROM physique_queue WHERE user_id=?", [uid])?;
    db.execute("INSERT INTO physique_queue_status(user_id,status,updated) VALUES (?,'cancelled',?) ON CONFLICT(user_id) DO UPDATE SET status='cancelled',updated=excluded.updated",params![uid,time])?;
    if let Some(mid) = active(db, uid)? {
        let stage: String = db.query_row(
            "SELECT stage FROM physique_matches WHERE id=?",
            [&mid],
            |r| r.get(0),
        )?;
        if stage == "ready" || stage == "countdown" {
            finish_unscored(db, &mid, "cancelled", "Match cancelled before Go", time)?;
        } else {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This match has started. Rejoin or explicitly confirm Forfeit and leave",
            ));
        }
    }
    Ok(())
}
pub fn pair(db: &Connection, settings: &Settings, time: f64) -> Result<()> {
    if !settings.policy.ready {
        return Ok(());
    }
    let queued:Vec<(String,f64)>=db.prepare_cached("SELECT user_id,created FROM physique_queue WHERE policy_key=? AND heartbeat>=? AND created>? ORDER BY created,user_id")?.query_map(params![settings.key,time-20.0,time-90.0],|r|Ok((r.get(0)?,r.get(1)?)))?.collect::<rusqlite::Result<_>>()?;
    let mut used = std::collections::HashSet::new();
    for (a, created) in &queued {
        if used.contains(a) || eligible(db, a, settings, time, true).is_err() {
            continue;
        }
        let rating: i64 = db.query_row(
            "SELECT rating FROM physique_profiles WHERE user_id=?",
            [a],
            |r| r.get(0),
        )?;
        let mut candidates = Vec::new();
        for (b, bc) in &queued {
            if a == b
                || used.contains(b)
                || blocked(db, a, b)?
                || eligible(db, b, settings, time, true).is_err()
            {
                continue;
            }
            let br: i64 = db.query_row(
                "SELECT rating FROM physique_profiles WHERE user_id=?",
                [b],
                |r| r.get(0),
            )?;
            let distance = (rating - br).abs();
            if distance <= band(time - *created) && distance <= band(time - *bc) {
                candidates.push((distance, *bc, b.clone()))
            }
        }
        candidates.sort_by(|x, y| {
            x.0.cmp(&y.0)
                .then_with(|| x.1.total_cmp(&y.1))
                .then_with(|| x.2.cmp(&y.2))
        });
        let Some((_, _, b)) = candidates.into_iter().next() else {
            continue;
        };
        let mid = auth::identifier()?;
        db.execute("INSERT INTO physique_matches(id,stage,created,deadline,judge_version,policy_key) VALUES (?,'ready',?,?,?,?)",params![mid,time,time+30.0,settings.policy.judge_version,settings.key])?;
        for (slot, uid) in [("a", a), ("b", &b)] {
            let (identity, record) = identity_and_record(db, uid)?;
            let rating: i64 = db.query_row(
                "SELECT rating FROM physique_profiles WHERE user_id=?",
                [uid],
                |r| r.get(0),
            )?;
            db.execute("INSERT INTO physique_participants(match_id,slot,user_id,identity,adult_man,last_seen,before_rating,before_games,sensitivity) VALUES (?,?,?,?,?,?,?,?,?)",params![mid,slot,uid,serde_json::to_string(&identity)?,consent(db,uid)?.adult_man,time,rating,record.games,if record.games<5{40}else{24}])?;
            db.execute(
                "INSERT INTO physique_active VALUES (?,?)",
                params![uid, mid],
            )?;
            db.execute("DELETE FROM physique_queue WHERE user_id=?", [uid])?;
            db.execute(
                "UPDATE physique_queue_status SET status='paired',updated=? WHERE user_id=?",
                params![time, uid],
            )?;
            used.insert(uid.clone());
        }
    }
    Ok(())
}
pub fn band(elapsed: f64) -> i64 {
    if elapsed < 30.0 {
        100
    } else if elapsed < 60.0 {
        200
    } else {
        400
    }
}
pub fn ready(
    db: &Connection,
    uid: &str,
    mid: &str,
    value: bool,
    settings: &Settings,
    time: f64,
) -> Result<()> {
    require_member(db, uid, mid)?;
    let (stage, start): (String, Option<f64>) = db.query_row(
        "SELECT stage,start FROM physique_matches WHERE id=?",
        [mid],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    if !["ready", "countdown"].contains(&stage.as_str()) || start.is_some_and(|s| s <= time) {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "Readiness can change only before Go",
        ));
    }
    if value {
        eligible(db, uid, settings, time, true)?
    }
    db.execute(
        "UPDATE physique_participants SET ready=?,last_seen=? WHERE match_id=? AND user_id=?",
        params![value, time, mid, uid],
    )?;
    if !value {
        db.execute(
            "UPDATE physique_matches SET stage='ready',start=NULL,deadline=created+30.0 WHERE id=?",
            [mid],
        )?;
    } else {
        let count: i64 = db.query_row(
            "SELECT count(*) FROM physique_participants WHERE match_id=? AND ready=1",
            [mid],
            |r| r.get(0),
        )?;
        if count == 2 && stage == "ready" {
            db.execute(
                "UPDATE physique_matches SET stage='countdown',start=?,deadline=? WHERE id=?",
                params![time + 3.0, time + 93.0, mid],
            )?;
        }
    }
    Ok(())
}
pub fn touch(db: &Connection, uid: &str, mid: Option<&str>, time: f64) -> Result<()> {
    if let Some(mid) = mid {
        require_member(db, uid, mid)?;
        db.execute(
            "UPDATE physique_participants SET last_seen=? WHERE match_id=? AND user_id=?",
            params![time, mid, uid],
        )?;
    }
    db.execute(
        "UPDATE physique_queue SET heartbeat=? WHERE user_id=?",
        params![time, uid],
    )?;
    Ok(())
}
pub fn finish_unscored(
    db: &Connection,
    mid: &str,
    stage: &str,
    reason: &str,
    time: f64,
) -> Result<()> {
    let changed = db.execute(
        "UPDATE physique_matches SET stage=?,reason=?,finalized=? WHERE id=? AND finalized IS NULL",
        params![stage, reason, time, mid],
    )?;
    if changed == 0 {
        return Ok(());
    }
    if stage == "noContest" {
        db.execute(
            "UPDATE physique_participants SET outcome='noContest' WHERE match_id=?",
            [mid],
        )?;
        db.execute(
            "UPDATE physique_starts SET restored=1 WHERE match_id=? AND restored=0",
            [mid],
        )?;
    }
    db.execute(
        "UPDATE physique_media SET expires=? WHERE match_id=?",
        params![time + 86400.0, mid],
    )?;
    db.execute("DELETE FROM physique_active WHERE match_id=?", [mid])?;
    Ok(())
}
pub fn rating_after(before: i64, other: i64, sensitivity: i64, score: f64) -> i64 {
    let expected = 1.0 / (1.0 + 10_f64.powf((other - before) as f64 / 400.0));
    (before + (sensitivity as f64 * (score - expected)).round() as i64).clamp(0, 5000)
}
pub fn finalize(
    db: &Connection,
    mid: &str,
    winner: Option<&str>,
    forfeit: bool,
    verdict: Option<&Verdict>,
    time: f64,
) -> Result<()> {
    if let Some(verdict) = verdict {
        verdict.validate()?;
    }
    let (stage, deadline): (String, Option<f64>) = db.query_row(
        "SELECT stage,judging_deadline FROM physique_matches WHERE id=?",
        [mid],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    if !["capture", "submitting", "judging"].contains(&stage.as_str()) {
        return Ok(());
    }
    if !forfeit && (stage != "judging" || deadline.is_none_or(|v| v <= time)) {
        return finish_unscored(
            db,
            mid,
            "noContest",
            "Judging deadline expired; allowance restored",
            time,
        );
    }
    let unsafe_evidence: bool = db.query_row(
        "SELECT EXISTS(SELECT 1 FROM physique_media WHERE match_id=? AND status<>'accepted')",
        [mid],
        |r| r.get(0),
    )?;
    let accepted: i64 = db.query_row(
        "SELECT count(*) FROM physique_media WHERE match_id=? AND status='accepted'",
        [mid],
        |r| r.get(0),
    )?;
    if unsafe_evidence || (!forfeit && accepted != 6) {
        return finish_unscored(
            db,
            mid,
            "noContest",
            "Required evidence could not safely support finalization; allowance restored",
            time,
        );
    }
    let rows:Vec<(String,String,i64,i64,i64)>=db.prepare_cached("SELECT slot,user_id,before_rating,before_games,sensitivity FROM physique_participants WHERE match_id=? ORDER BY slot")?.query_map([mid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?)))?.collect::<rusqlite::Result<_>>()?;
    if rows.len() != 2 {
        return Err(ApiError::internal());
    }
    let changed=db.execute("UPDATE physique_matches SET stage=?,winner=?,explanation=?,finalized=? WHERE id=? AND finalized IS NULL",params![if forfeit{"forfeited"}else{"completed"},winner,verdict.map(|v|v.explanation.as_str()),time,mid])?;
    if changed == 0 {
        return Ok(());
    }
    for (index, (slot, uid, before, games, k)) in rows.iter().enumerate() {
        let outcome = match winner {
            None => "draw",
            Some(w) if w == slot => {
                if forfeit {
                    "forfeitWin"
                } else {
                    "win"
                }
            }
            _ => {
                if forfeit {
                    "forfeitLoss"
                } else {
                    "loss"
                }
            }
        };
        let score = if outcome == "draw" {
            0.5
        } else if outcome == "win" || outcome == "forfeitWin" {
            1.0
        } else {
            0.0
        };
        let after = rating_after(*before, rows[1 - index].2, *k, score);
        let scores = verdict
            .map(|v| if slot == "a" { &v.a } else { &v.b })
            .map(serde_json::to_string)
            .transpose()?;
        db.execute("UPDATE physique_participants SET outcome=?,original_outcome=?,original_delta=?,delta=?,after_rating=?,after_games=?,scores=? WHERE match_id=? AND slot=?",params![outcome,outcome,after-before,after-before,after,games+1,scores,mid,slot])?;
        db.execute(
            "UPDATE physique_profiles SET rating=? WHERE user_id=?",
            params![after, uid],
        )?;
        db.execute(
            "INSERT INTO physique_rating_events VALUES (?,?,?,'result',?,?,?)",
            params![auth::identifier()?, uid, mid, time, after - before, after],
        )?;
    }
    if let Some(verdict) = verdict {
        db.execute(
            "UPDATE physique_matches SET provider_model=? WHERE id=?",
            params![verdict.provider_model, mid],
        )?;
    }
    db.execute(
        "UPDATE physique_media SET expires=? WHERE match_id=?",
        params![time + 86400.0, mid],
    )?;
    db.execute("DELETE FROM physique_active WHERE match_id=?", [mid])?;
    Ok(())
}
pub fn leave(
    db: &Connection,
    uid: &str,
    mid: &str,
    reason: &str,
    settings: &Settings,
    time: f64,
) -> Result<()> {
    let slot = require_member(db, uid, mid)?;
    let (stage, finalized): (String, Option<f64>) = db.query_row(
        "SELECT stage,finalized FROM physique_matches WHERE id=?",
        [mid],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    if finalized.is_some() {
        return Ok(());
    }
    if ["ready", "countdown"].contains(&stage.as_str()) {
        if reason != "cancel" {
            return Err(ApiError::invalid("Use Cancel before Go"));
        }
        return cancel(db, uid, time);
    }
    if reason != "forfeit" {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This match has started. Rejoin or explicitly confirm Forfeit and leave",
        ));
    }
    let invalid: bool = db.query_row(
        "SELECT EXISTS(SELECT 1 FROM physique_media WHERE match_id=? AND status='rejected')",
        [mid],
        |r| r.get(0),
    )?;
    let users: Vec<String> = db
        .prepare_cached("SELECT user_id FROM physique_participants WHERE match_id=?")?
        .query_map([mid], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    if invalid
        || users
            .iter()
            .any(|u| eligible(db, u, settings, time, false).is_err())
    {
        return finish_unscored(
            db,
            mid,
            "noContest",
            "A safe eligible rated outcome was unavailable; allowance restored",
            time,
        );
    }
    finalize(
        db,
        mid,
        Some(if slot == "a" { "b" } else { "a" }),
        true,
        None,
        time,
    )
}
pub fn sweep(db: &Connection, settings: &Settings, time: f64) -> Result<()> {
    let expired: Vec<String> = db
        .prepare_cached(
            "SELECT user_id FROM physique_queue WHERE created<=? OR heartbeat<? OR policy_key<>?",
        )?
        .query_map(params![time - 90.0, time - 20.0, settings.key], |r| {
            r.get(0)
        })?
        .collect::<rusqlite::Result<_>>()?;
    for uid in expired {
        let status:String=db.query_row("SELECT CASE WHEN created<=? THEN 'noOpponent' ELSE 'cancelled' END FROM physique_queue WHERE user_id=?",params![time-90.0,uid],|r|r.get(0))?;
        db.execute(
            "UPDATE physique_queue_status SET status=?,updated=? WHERE user_id=?",
            params![status, time, uid],
        )?;
        db.execute("DELETE FROM physique_queue WHERE user_id=?", [uid])?;
    }
    let matches:Vec<(String,String,Option<f64>,Option<f64>,Option<f64>,String)>=db.prepare_cached("SELECT id,stage,start,deadline,judging_deadline,policy_key FROM physique_matches WHERE finalized IS NULL")?.query_map([],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?)))?.collect::<rusqlite::Result<_>>()?;
    for (mid, stage, start, deadline, judging_deadline, key) in matches {
        let before_go = stage == "ready" || stage == "countdown";
        let stale:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_participants WHERE match_id=? AND submitted=0 AND last_seen<?)",params![mid,time-20.0],|r|r.get(0))?;
        let users:Vec<String>=db.prepare_cached("SELECT user_id FROM physique_participants WHERE match_id=? AND user_id IS NOT NULL")?.query_map([&mid],|r|r.get(0))?.collect::<rusqlite::Result<_>>()?;
        let ineligible = users.len() != 2
            || key != settings.key
            || users
                .iter()
                .any(|u| eligible(db, u, settings, time, before_go).is_err());
        if ineligible || stale {
            finish_unscored(
                db,
                &mid,
                if before_go { "cancelled" } else { "noContest" },
                if before_go {
                    "Preparation cancelled; eligibility or connection is unavailable"
                } else {
                    "Participation could not safely continue; allowance restored"
                },
                time,
            )?;
            continue;
        }
        if stage == "ready" && deadline.is_some_and(|d| d <= time) {
            finish_unscored(db, &mid, "cancelled", "Ready room expired before Go", time)?;
        } else if stage == "countdown" && start.is_some_and(|s| s <= time) {
            let used:Vec<i64>=users.iter().map(|u|db.query_row("SELECT count(*) FROM physique_starts WHERE user_id=? AND restored=0 AND at>?",params![u,time-WINDOW],|r|r.get(0))).collect::<rusqlite::Result<_>>()?;
            if used.into_iter().any(|count| count >= LIMIT) {
                finish_unscored(
                    db,
                    &mid,
                    "cancelled",
                    "Physique allowance became unavailable before Go",
                    time,
                )?;
                continue;
            }
            db.execute(
                "UPDATE physique_matches SET stage='capture' WHERE id=?",
                [&mid],
            )?;
            for uid in users {
                db.execute(
                    "INSERT OR IGNORE INTO physique_starts VALUES (?,?,?,0)",
                    params![uid, mid, start],
                )?;
            }
        } else if ["capture", "submitting"].contains(&stage.as_str())
            && deadline.is_some_and(|d| d <= time)
        {
            finish_unscored(
                db,
                &mid,
                "noContest",
                "Required pose evidence was not received before the capture deadline; allowance restored",
                time,
            )?;
        } else if stage == "judging" && judging_deadline.is_some_and(|d| d <= time) {
            finish_unscored(
                db,
                &mid,
                "noContest",
                "Judging deadline expired; allowance restored",
                time,
            )?;
        }
    }
    Ok(())
}
#[derive(Clone)]
pub struct StoredMatch {
    pub id: String,
    pub stage: String,
    pub created: f64,
    pub start: Option<f64>,
    pub deadline: Option<f64>,
    pub judging_started: Option<f64>,
    pub judging_deadline: Option<f64>,
    pub finalized: Option<f64>,
    pub reason: Option<String>,
    pub version: String,
    pub explanation: Option<String>,
    pub corrected: bool,
}
pub fn stored_match(db: &Connection, mid: &str) -> Result<StoredMatch> {
    db.query_row("SELECT id,stage,created,start,deadline,judging_started,judging_deadline,finalized,reason,judge_version,explanation,corrected FROM physique_matches WHERE id=?",[mid],|r|Ok(StoredMatch{id:r.get(0)?,stage:r.get(1)?,created:r.get(2)?,start:r.get(3)?,deadline:r.get(4)?,judging_started:r.get(5)?,judging_deadline:r.get(6)?,finalized:r.get(7)?,reason:r.get(8)?,version:r.get(9)?,explanation:r.get(10)?,corrected:r.get(11)?})).optional()?.ok_or_else(||ApiError::new(StatusCode::NOT_FOUND,"Physique match is unavailable"))
}
pub fn match_view(db: &Connection, uid: &str, mid: &str, time: f64) -> Result<Match> {
    let own = require_member(db, uid, mid)?;
    let stored = stored_match(db, mid)?;
    let mut people = Vec::new();
    let rows:Vec<(String,Option<String>,String,bool,bool,i64,Option<String>,Option<String>,Option<i64>,Option<i64>,i64,i64)>=db.prepare_cached("SELECT slot,user_id,identity,ready,submitted,before_games,scores,outcome,delta,after_rating,before_rating,coalesce(after_games,before_games) FROM physique_participants WHERE match_id=? ORDER BY slot")?.query_map([mid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?,r.get(6)?,r.get(7)?,r.get(8)?,r.get(9)?,r.get(10)?,r.get(11)?)))?.collect::<rusqlite::Result<_>>()?;
    if rows.len() != 2 {
        return Err(ApiError::internal());
    }
    for (slot, owner, label, ready, submitted, _, scores, outcome, _, _, _, _) in &rows {
        let mut identity: Identity = serde_json::from_str(label)?;
        if let Some(owner) = owner {
            let deleted: bool = db
                .query_row(
                    "SELECT deleted FROM physique_profiles WHERE user_id=?",
                    [owner],
                    |r| r.get(0),
                )
                .optional()?
                .unwrap_or(true);
            if deleted {
                identity = unavailable_identity("Unavailable player");
            } else if owner != uid && blocked(db, uid, owner)? {
                identity = unavailable_identity("Blocked player");
            } else {
                let country: Option<String> = db.query_row(
                    "SELECT country_code FROM physique_profiles WHERE user_id=?",
                    [owner],
                    |r| r.get(0),
                )?;
                if country != identity.country_code {
                    identity.country_code = None;
                }
            }
        } else {
            identity = unavailable_identity("Unavailable player")
        }
        let accepted: i64 = if scores.is_some()
            && outcome
                .as_ref()
                .is_some_and(|v| ["win", "loss", "draw"].contains(&v.as_str()))
        {
            3
        } else {
            db.query_row("SELECT count(*) FROM physique_media WHERE match_id=? AND slot=? AND status='accepted'",params![mid,slot],|r|r.get(0))?
        };
        people.push((
            slot.clone(),
            Participant {
                identity,
                ready: *ready,
                submitted: *submitted,
                accepted_count: accepted,
            },
        ));
    }
    let index = usize::from(own == "b");
    let own_row = &rows[index];
    let other = &rows[1 - index];
    let original_delta: Option<i64> = db.query_row(
        "SELECT original_delta FROM physique_participants WHERE match_id=? AND user_id=?",
        params![mid, uid],
        |r| r.get(0),
    )?;
    let correction:Option<Correction>=db.query_row("SELECT c.id,c.created,c.reason,p.original_outcome,p.outcome,p.original_delta,e.delta,e.after_rating FROM physique_corrections c JOIN physique_participants p ON p.match_id=c.match_id JOIN physique_rating_events e ON e.match_id=c.match_id AND e.user_id=p.user_id AND e.kind='correction' WHERE c.match_id=? AND p.user_id=?",params![mid,uid],|r|Ok(Correction{id:r.get(0)?,created_at:r.get(1)?,reason:r.get(2)?,original_outcome:r.get(3)?,corrected_outcome:r.get(4)?,original_change:r.get(5)?,adjustment:r.get(6)?,after:r.get(7)?})).optional()?;
    let result = own_row
        .7
        .as_ref()
        .map(|outcome| -> Result<MatchResult> {
            Ok(MatchResult {
                outcome: outcome.clone(),
                you: own_row
                    .6
                    .as_ref()
                    .map(|v| serde_json::from_str(v))
                    .transpose()?,
                opponent: other
                    .6
                    .as_ref()
                    .map(|v| serde_json::from_str(v))
                    .transpose()?,
                rating: original_delta.map(|change| RatingReceipt {
                    before: (own_row.5 > 0).then_some(own_row.10),
                    change,
                    after: own_row.10 + change,
                    games: own_row.5 + 1,
                }),
                explanation: stored.explanation.clone(),
                judge_version: Some(stored.version.clone()),
                corrected: stored.corrected,
                correction,
            })
        })
        .transpose()?;
    let evidence=db.prepare_cached("SELECT x.id,x.pose,x.status,x.attempts,x.reason,(SELECT c.id FROM physique_cases c WHERE c.owner=?3 AND c.kind='restriction' AND c.target=x.id AND NOT EXISTS(SELECT 1 FROM physique_cases a WHERE a.owner=c.owner AND a.kind='appeal' AND a.target=c.id)) FROM physique_media x WHERE x.match_id=?1 AND x.slot=?2 ORDER BY CASE x.pose WHEN 'front' THEN 0 WHEN 'side' THEN 1 ELSE 2 END")?.query_map(params![mid,own,uid],|r|Ok(Evidence{id:r.get(0)?,pose:r.get(1)?,status:r.get(2)?,retakes:r.get::<_,i64>(3)?-1,reason:r.get(4)?,appeal_case_id:r.get(5)?}))?.collect::<rusqlite::Result<_>>()?;
    let gallery = stored.stage == "completed"
        && result
            .as_ref()
            .is_some_and(|v| ["win", "loss", "draw"].contains(&v.outcome.as_str()))
        && stored.finalized.is_some_and(|v| v + 86400.0 > time)
        && consent(db, uid)?.adult;
    Ok(Match {
        id: stored.id,
        stage: if stored.stage == "capture" && own_row.4 {
            "submitting".into()
        } else {
            stored.stage
        },
        created_at: stored.created,
        start_at: stored.start,
        deadline: stored.deadline,
        judging_started_at: stored.judging_started,
        judging_deadline: stored.judging_deadline,
        finalized_at: stored.finalized,
        reason: stored.reason,
        you: people[index].1.clone(),
        opponent: people[1 - index].1.clone(),
        evidence,
        result,
        gallery_available: gallery,
        media_expires_at: stored.finalized.map(|v| v + 86400.0),
    })
}
pub fn unavailable_identity(name: &str) -> Identity {
    Identity {
        id: String::new(),
        display_name: name.into(),
        country_code: None,
        rating: None,
        games: 0,
        tier: None,
        badges: vec![],
        streak: None,
    }
}
pub fn snapshot(db: &Connection, uid: &str, settings: &Settings, time: f64) -> Result<Snapshot> {
    ensure(db, uid)?;
    let queue: Option<f64> = db
        .query_row(
            "SELECT created FROM physique_queue WHERE user_id=?",
            [uid],
            |r| r.get(0),
        )
        .optional()?;
    let queue_outcome:Option<String>=db.query_row("SELECT status FROM physique_queue_status WHERE user_id=? AND status IN ('noOpponent','cancelled')",[uid],|r|r.get(0)).optional()?;
    let mid=active(db,uid)?.or(db.query_row("SELECT p.match_id FROM physique_participants p JOIN physique_matches m ON m.id=p.match_id WHERE p.user_id=? AND m.finalized IS NOT NULL ORDER BY m.finalized DESC,m.id DESC LIMIT 1",[uid],|r|r.get(0)).optional()?);
    Ok(Snapshot {
        server_time: time,
        policy: settings.policy.clone(),
        account: account(db, uid, time)?,
        r#match: mid.map(|mid| match_view(db, uid, &mid, time)).transpose()?,
        queue_started_at: queue,
        queue_deadline: queue.map(|v| v + 90.0),
        queue_outcome,
    })
}
