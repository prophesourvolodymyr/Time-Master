use super::{
    competition as comp,
    judge::{self, Settings},
    model::*,
};
use crate::{ApiError, Result, auth};
use axum::http::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};

pub fn get(db: &Connection, uid: &str, id: &str) -> Result<Case> {
    let mut case=db.query_row("SELECT id,kind,status,summary,created,updated,match_id,decision,needs_reply,closed FROM physique_cases WHERE id=? AND owner=?",params![id,uid],|r|{
        let kind:String=r.get(1)?;let status:String=r.get(2)?;let closed:Option<f64>=r.get(9)?;
        Ok(Case{id:r.get(0)?,kind:kind.clone(),status:status.clone(),summary:r.get(3)?,created_at:r.get(4)?,updated_at:r.get(5)?,match_id:r.get(6)?,decision:r.get(7)?,needs_reply:r.get(8)?,can_appeal:kind=="restriction"&&closed.is_some(),can_withdraw:closed.is_none()&&status!="withdrawn",messages:vec![]})
    }).optional()?.ok_or_else(||ApiError::new(StatusCode::NOT_FOUND,"Private case is unavailable"))?;
    case.messages=db.prepare_cached("SELECT id,text,created,from_staff FROM physique_case_messages WHERE case_id=? ORDER BY created,id")?.query_map([id],|r|Ok(CaseMessage{id:r.get(0)?,text:r.get(1)?,created_at:r.get(2)?,from_staff:r.get(3)?}))?.collect::<rusqlite::Result<_>>()?;
    if case.can_appeal {
        case.can_appeal=!db.query_row("SELECT EXISTS(SELECT 1 FROM physique_cases WHERE owner=? AND kind='appeal' AND target=?)",params![uid,id],|r|r.get::<_,bool>(0))?;
    }
    Ok(case)
}
pub fn list(db: &Connection, uid: &str) -> Result<Vec<Case>> {
    let ids: Vec<String> = db
        .prepare_cached(
            "SELECT id FROM physique_cases WHERE owner=? ORDER BY updated DESC,id DESC",
        )?
        .query_map([uid], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    ids.into_iter().map(|id| get(db, uid, &id)).collect()
}
fn add_message(
    db: &Connection,
    id: &str,
    text: &str,
    time: f64,
    staff: Option<&str>,
) -> Result<()> {
    if !text.trim().is_empty() {
        db.execute(
            "INSERT INTO physique_case_messages VALUES (?,?,?,?,?,?)",
            params![auth::identifier()?, id, text, time, staff.is_some(), staff],
        )?;
    }
    Ok(())
}
fn category(value: &str) -> Result<&str> {
    if [
        "nudity",
        "sexual",
        "eligibility",
        "privacy",
        "harassment",
        "integrity",
        "unsafeAI",
        "urgent",
        "spam",
        "other",
    ]
    .contains(&value)
    {
        Ok(value)
    } else {
        Err(ApiError::invalid(
            "Choose a supported safety report category",
        ))
    }
}
pub fn rejection_notice(
    db: &Connection,
    uid: &str,
    mid: &str,
    evidence: &str,
    reason: &str,
    time: f64,
) -> Result<()> {
    db.execute("INSERT OR IGNORE INTO physique_cases(id,owner,kind,status,summary,category,target,match_id,created,updated,closed,decision,decision_by) VALUES (?,?,'restriction','actionTaken','Capture check did not accept this pose','capture',?,?,?,?,?,?, 'automated-contextual-safety')",params![auth::identifier()?,uid,evidence,mid,time,time,time,format!("Automated protected check: {reason}. This is not a human misconduct finding and does not itself restrict the account")])?;
    Ok(())
}
pub fn report(
    db: &Connection,
    uid: &str,
    command: &Command,
    settings: &Settings,
    time: f64,
) -> Result<(String, String)> {
    settings.require_intake()?;
    let target = command
        .target_id
        .as_deref()
        .ok_or_else(|| ApiError::invalid("Choose the report target"))?;
    let reason = category(command.reason.as_deref().unwrap_or(""))?;
    let media: Option<(String, String)> = db
        .query_row(
            "SELECT match_id,slot FROM physique_media WHERE id=?",
            [target],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    let mut mid = command.match_id.clone();
    if let Some((actual, _)) = &media {
        comp::require_member(db, uid, actual)?;
        if mid.as_ref().is_some_and(|m| m != actual) {
            return Err(ApiError::invalid(
                "Report target does not belong to this match",
            ));
        }
        mid = Some(actual.clone());
    } else if let Some(match_id) = &mid {
        comp::require_member(db, uid, match_id)?;
        if target != match_id {
            let owner = comp::resolve_target(db, uid, target, time)?;
            let member: bool = db.query_row(
                "SELECT EXISTS(SELECT 1 FROM physique_participants WHERE match_id=? AND user_id=?)",
                params![match_id, owner],
                |r| r.get(0),
            )?;
            if !member {
                return Err(ApiError::invalid(
                    "The report target is not part of this match",
                ));
            }
        }
    } else {
        let is_match: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM physique_participants WHERE user_id=? AND match_id=?)",
            params![uid, target],
            |r| r.get(0),
        )?;
        if is_match {
            mid = Some(target.into())
        } else {
            comp::resolve_target(db, uid, target, time)?;
        }
    }
    let existing: Option<String> = db
        .query_row(
            "SELECT id FROM physique_cases WHERE owner=? AND kind='report' AND target=?",
            params![uid, target],
            |r| r.get(0),
        )
        .optional()?;
    if let Some(id) = existing {
        return Ok((
            id,
            "This concern already has a private case; no duplicate evidence hold was created"
                .into(),
        ));
    }
    let id = auth::identifier()?;
    db.execute("INSERT INTO physique_cases(id,owner,kind,status,summary,category,target,match_id,created,updated) VALUES (?,?,'report','received',?,?,?,?,?,?)",params![id,uid,format!("Safety report: {reason}"),reason,target,mid,time,time])?;
    add_message(db, &id, command.text.as_deref().unwrap_or(""), time, None)?;
    if media.is_some() {
        db.execute("INSERT INTO physique_hides(owner,media_id,reported) VALUES (?,?,1) ON CONFLICT(owner,media_id) DO UPDATE SET reported=1",params![uid,target])?;
    }
    let urgent = ["sexual", "eligibility", "urgent"].contains(&reason);
    if !urgent && media.is_some() {
        let origin:f64=db.query_row("SELECT coalesce(min(created),?2) FROM physique_cases WHERE match_id=?1 AND kind IN ('report','dispute')",params![mid,time],|r|r.get(0))?;
        db.execute("INSERT OR IGNORE INTO physique_holds SELECT ?1,x.id,x.file_key,?2 FROM physique_media x JOIN physique_matches m ON m.id=x.match_id WHERE x.id=?3 AND x.file_key IS NOT NULL AND x.status='accepted' AND x.expires>?4 AND m.stage='completed' AND m.finalized IS NOT NULL",params![id,origin+30.0*86400.0,target,time])?;
    }
    Ok((id,"Report received as a private case. This is an automated receipt, not confirmation of human review".into()))
}
pub fn review(
    db: &Connection,
    uid: &str,
    command: &Command,
    settings: &Settings,
    time: f64,
) -> Result<(String, String)> {
    settings.require_intake()?;
    let target = command
        .target_id
        .as_deref()
        .ok_or_else(|| ApiError::invalid("Choose the original case or match"))?;
    let (kind, reason) = command
        .reason
        .as_deref()
        .unwrap_or("")
        .split_once(':')
        .ok_or_else(|| ApiError::invalid("Choose appeal or dispute and a review reason"))?;
    if !["appeal", "dispute"].contains(&kind)
        || ![
            "evidence",
            "judgement",
            "arithmetic",
            "identity",
            "forfeit",
            "finality",
            "coverage",
            "eligibility",
            "restriction",
            "removal",
            "other",
        ]
        .contains(&reason)
    {
        return Err(ApiError::invalid("Choose a supported review reason"));
    }
    let (mid, parent, hold_origin) = if kind == "appeal" {
        let original = get(db, uid, target)?;
        if !original.can_appeal {
            let duplicate: Option<String> = db
                .query_row(
                    "SELECT id FROM physique_cases WHERE owner=? AND kind='appeal' AND target=?",
                    params![uid, target],
                    |r| r.get(0),
                )
                .optional()?;
            if let Some(id) = duplicate {
                return Ok((id, "This decision already has a private appeal".into()));
            }
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This case does not authorize a new appeal",
            ));
        }
        (
            original.match_id,
            Some(target.to_owned()),
            original.created_at,
        )
    } else {
        comp::require_member(db, uid, target)?;
        let stored = comp::stored_match(db, target)?;
        let started: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM physique_starts WHERE user_id=? AND match_id=?)",
            params![uid, target],
            |r| r.get(0),
        )?;
        if !started || stored.finalized.is_none() {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "A result dispute requires a finalized started match",
            ));
        }
        (Some(target.to_owned()), None, time)
    };
    let existing: Option<String> = db
        .query_row(
            "SELECT id FROM physique_cases WHERE owner=? AND kind=? AND target=?",
            params![uid, kind, target],
            |r| r.get(0),
        )
        .optional()?;
    if let Some(id) = existing {
        return Ok((id, "This result already has a private review case".into()));
    }
    let id = auth::identifier()?;
    db.execute("INSERT INTO physique_cases(id,owner,kind,status,summary,category,target,match_id,parent_id,created,updated) VALUES (?,?,?,'received',?,?,?,?,?,?,?)",params![id,uid,kind,format!("{} review: {reason}",if kind=="appeal"{"Safety decision"}else{"Outcome"}),reason,target,mid,parent,time,time])?;
    add_message(db, &id, command.text.as_deref().unwrap_or(""), time, None)?;
    if kind == "dispute" {
        let origin:f64=db.query_row("SELECT coalesce(min(created),?2) FROM physique_cases WHERE match_id=?1 AND kind IN ('report','dispute')",params![mid,hold_origin],|r|r.get(0))?;
        db.execute("INSERT OR IGNORE INTO physique_holds SELECT ?1,id,file_key,?2 FROM physique_media WHERE match_id=?3 AND file_key IS NOT NULL AND status='accepted' AND expires>?4",params![id,origin+30.0*86400.0,mid,time])?;
    }
    Ok((id,"Review request received. The current outcome remains effective; no model reroll was requested".into()))
}
pub fn reply(db: &Connection, uid: &str, command: &Command, time: f64) -> Result<(String, String)> {
    let id = command
        .target_id
        .as_deref()
        .ok_or_else(|| ApiError::invalid("Choose the private case"))?;
    let case = get(db, uid, id)?;
    if !case.needs_reply || !case.can_withdraw {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This case is not awaiting a reply",
        ));
    }
    if command.expected_revision != Some(case.updated_at) {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "The staff request changed. Refresh this case before sending the reply",
        ));
    }
    let text = command
        .text
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| ApiError::invalid("Enter a safe text reply"))?;
    add_message(db, id, text, time, None)?;
    db.execute(
        "UPDATE physique_cases SET status='queued',needs_reply=0,updated=? WHERE id=?",
        params![revision(time, case.updated_at), id],
    )?;
    Ok((
        id.to_owned(),
        "Reply received for private case review".into(),
    ))
}
pub fn withdraw(db: &Connection, uid: &str, id: &str, time: f64) -> Result<(String, String)> {
    let case = get(db, uid, id)?;
    if !case.can_withdraw {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This case cannot be withdrawn in its current state",
        ));
    }
    db.execute(
        "UPDATE physique_cases SET status='withdrawn',needs_reply=0,updated=? WHERE id=?",
        params![revision(time, case.updated_at), id],
    )?;
    Ok((id.into(),"Your request is marked withdrawn. A received safety concern or justified evidence hold may still require review".into()))
}
pub fn revision(time: f64, prior: f64) -> f64 {
    time.max(prior + 0.000001)
}
pub fn consent_revision(db: &Connection, uid: &str) -> Result<f64> {
    Ok(db
        .query_row(
            "SELECT revision FROM physique_consent_revisions WHERE user_id=?",
            [uid],
            |r| r.get(0),
        )
        .optional()?
        .unwrap_or(0.0))
}
pub fn update_consent(db: &Connection, uid: &str, value: &Consent, time: f64) -> Result<()> {
    db.execute(
        "UPDATE physique_profiles SET consent=? WHERE user_id=?",
        params![serde_json::to_string(value)?, uid],
    )?;
    let next = revision(time, consent_revision(db, uid)?);
    db.execute("INSERT INTO physique_consent_revisions VALUES (?,?) ON CONFLICT(user_id) DO UPDATE SET revision=excluded.revision",params![uid,next])?;
    Ok(())
}
pub fn privacy_receipt(
    db: &Connection,
    uid: &str,
    scope: &str,
    detail: &str,
    held: bool,
    time: f64,
) -> Result<String> {
    let id = auth::identifier()?;
    db.execute("INSERT INTO physique_privacy VALUES (?,?,?,?,?,?,?,?)",params![id,uid,scope,if held{"partiallyHeld"}else{"completed"},time,time,detail,if held{Some("Minimum existing evidence remains restricted to a received case until its original bounded hold expires")}else{None}])?;
    Ok(id)
}
pub fn remove_images(
    db: &Connection,
    uid: &str,
    mid: Option<&str>,
    settings: &Settings,
    time: f64,
) -> Result<bool> {
    if let Some(mid) = mid {
        comp::require_member(db, uid, mid)?;
    }
    let rows:Vec<(String,String,Option<String>)>=db.prepare_cached("SELECT x.id,x.match_id,x.file_key FROM physique_media x JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE p.user_id=?1 AND (?2 IS NULL OR x.match_id=?2)")?.query_map(params![uid,mid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?)))?.collect::<rusqlite::Result<_>>()?;
    let mut held = false;
    for (id, match_id, key) in rows {
        let keep: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM physique_holds WHERE media_id=? AND expires>?)",
            params![id, time],
            |r| r.get(0),
        )?;
        held |= keep;
        db.execute("UPDATE physique_media SET status='removed',reason='Images removed by their owner',file_key=NULL WHERE id=?",[&id])?;
        if !keep {
            if let Some(key) = key {
                judge::remove_file(settings, &key)?;
            }
        }
        let stage: String = db.query_row(
            "SELECT stage FROM physique_matches WHERE id=?",
            [&match_id],
            |r| r.get(0),
        )?;
        if ["capture", "submitting", "judging"].contains(&stage.as_str()) {
            comp::finish_unscored(
                db,
                &match_id,
                "noContest",
                "Required evidence was removed; allowance restored",
                time,
            )?;
        }
    }
    Ok(held)
}
pub fn privacy_action(
    db: &Connection,
    uid: &str,
    command: &Command,
    settings: &Settings,
    time: f64,
) -> Result<(String, String)> {
    let operation = command.operation.as_str();
    let mut consent = comp::consent(db, uid)?;
    let held;
    let detail;
    if operation == "removeImages" {
        held = remove_images(db, uid, command.match_id.as_deref(), settings, time)?;
        detail = "Ordinary own pose images were removed from participant access. Earned results are unchanged. This cannot recall external copies or independently retained processor data";
    } else {
        if operation == "withdrawAI" {
            consent.ai_processing = false;
        } else {
            consent.opponent_sharing = false;
        }
        update_consent(db, uid, &consent, time)?;
        if operation == "withdrawSharing" {
            db.execute(
                "UPDATE physique_participants SET sharing=0 WHERE user_id=?",
                [uid],
            )?;
        }
        if let Some(mid) = comp::active(db, uid)? {
            let stored = comp::stored_match(db, &mid)?;
            if ["ready", "countdown"].contains(&stored.stage.as_str()) {
                comp::cancel(db, uid, time)?;
            } else if operation == "withdrawAI" {
                comp::finish_unscored(
                    db,
                    &mid,
                    "noContest",
                    "Further processing authorization was withdrawn; allowance restored",
                    time,
                )?;
            }
        }
        db.execute("DELETE FROM physique_queue WHERE user_id=?", [uid])?;
        held = false;
        detail = if operation == "withdrawAI" {
            "Further AI processing was withdrawn and new uploads stopped. An already accepted processor request may not be retractable. Active incomplete participation ended without a judged result"
        } else {
            "Future participant access to your existing stills was revoked. Separately authorized processing and valid results are unchanged. Regrant does not reopen withdrawn historical galleries"
        };
    }
    let id = privacy_receipt(db, uid, operation, detail, held, time)?;
    if held {
        db.execute("INSERT INTO physique_privacy_holds SELECT ?1,x.id FROM physique_media x JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE p.user_id=?2 AND (?3 IS NULL OR x.match_id=?3) AND EXISTS(SELECT 1 FROM physique_holds h WHERE h.media_id=x.id AND h.expires>?4)",params![id,uid,command.match_id,time])?;
    }
    Ok((id, detail.into()))
}
pub fn privacy_list(db: &Connection, uid: &str) -> Result<Vec<PrivacyReceipt>> {
    Ok(db.prepare_cached("SELECT id,scope,status,created,updated,detail,retained_reason FROM physique_privacy WHERE owner=? ORDER BY created DESC,id DESC")?.query_map([uid],|r|Ok(PrivacyReceipt{id:r.get(0)?,scope:r.get(1)?,status:r.get(2)?,created_at:r.get(3)?,updated_at:r.get(4)?,detail:r.get(5)?,retained_reason:r.get(6)?}))?.collect::<rusqlite::Result<_>>()?)
}
pub fn begin_deletion(db: &Connection, uid: &str, time: f64) -> Result<()> {
    if !db.query_row(
        "SELECT EXISTS(SELECT 1 FROM physique_profiles WHERE user_id=?)",
        [uid],
        |r| r.get::<_, bool>(0),
    )? {
        return Ok(());
    }
    db.execute("DELETE FROM physique_queue WHERE user_id=?", [uid])?;
    if let Some(mid) = comp::active(db, uid)? {
        let stored = comp::stored_match(db, &mid)?;
        comp::finish_unscored(
            db,
            &mid,
            if ["ready", "countdown"].contains(&stored.stage.as_str()) {
                "cancelled"
            } else {
                "noContest"
            },
            "Account deletion revoked further participation",
            time,
        )?;
    }
    db.execute("UPDATE physique_profiles SET deleted=1,listed=0,display_name='Unavailable player',country_code=NULL,consent=? WHERE user_id=?",params![serde_json::to_string(&Consent::default())?,uid])?;
    db.execute(
        "UPDATE physique_participants SET sharing=0,identity=? WHERE user_id=?",
        params![
            serde_json::to_string(&comp::unavailable_identity("Unavailable player"))?,
            uid
        ],
    )?;
    Ok(())
}
pub fn finish_deletion(db: &Connection, uid: &str, settings: &Settings, time: f64) -> Result<()> {
    let held_keys:Vec<String>=db.prepare_cached("SELECT DISTINCT h.file_key FROM physique_holds h JOIN physique_media x ON x.id=h.media_id JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE p.user_id=?1 OR h.case_id IN (SELECT id FROM physique_cases WHERE owner=?1)")?.query_map([uid],|r|r.get(0))?.collect::<rusqlite::Result<_>>()?;
    let rows:Vec<(String,Option<String>)>=db.prepare_cached("SELECT x.id,x.file_key FROM physique_media x JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE p.user_id=?")?.query_map([uid],|r|Ok((r.get(0)?,r.get(1)?)))?.collect::<rusqlite::Result<_>>()?;
    for (id, key) in rows {
        db.execute("DELETE FROM physique_holds WHERE media_id=?", [&id])?;
        db.execute("UPDATE physique_media SET file_key=NULL,status='removed',reason='Account deleted' WHERE id=?",[id])?;
        if let Some(key) = key {
            judge::remove_file(settings, &key)?;
        }
    }
    let case_ids: Vec<String> = db
        .prepare_cached("SELECT id FROM physique_cases WHERE owner=?")?
        .query_map([uid], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    for id in case_ids {
        db.execute("DELETE FROM physique_holds WHERE case_id=?", [&id])?;
        db.execute("DELETE FROM physique_case_messages WHERE case_id=?", [&id])?;
        db.execute("UPDATE physique_cases SET summary='Account deleted',category='removed',target='redacted:'||id,decision=NULL,needs_reply=0,closed=coalesce(closed,?),updated=? WHERE id=?",params![time,time,id])?;
    }
    for table in [
        "physique_blocks",
        "physique_hides",
        "physique_pages",
        "physique_privacy",
    ] {
        db.execute(&format!("DELETE FROM {table} WHERE owner=?"), [uid])?;
    }
    db.execute("DELETE FROM physique_blocks WHERE target=?", [uid])?;
    db.execute("UPDATE physique_corrections SET reason='A private review corrected this match',original_result='{}',corrected_result='{}' WHERE match_id IN (SELECT match_id FROM physique_participants WHERE user_id=?)",[uid])?;
    for table in [
        "physique_queue_status",
        "physique_consent_revisions",
        "physique_starts",
        "physique_requests",
        "physique_rating_events",
    ] {
        db.execute(&format!("DELETE FROM {table} WHERE user_id=?"), [uid])?;
    }
    db.execute(
        "UPDATE physique_participants SET user_id=NULL,adult_man=0,sharing=0 WHERE user_id=?",
        [uid],
    )?;
    db.execute("DELETE FROM physique_profiles WHERE user_id=?", [uid])?;
    for key in held_keys {
        let retained:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_media WHERE file_key=?1) OR EXISTS(SELECT 1 FROM physique_holds WHERE file_key=?1)",[&key],|r|r.get(0))?;
        if !retained {
            judge::remove_file(settings, &key)?;
        }
    }
    Ok(())
}
pub fn cleanup(db: &Connection, settings: &Settings, time: f64) -> Result<()> {
    db.execute("DELETE FROM physique_pages WHERE expires<=?", [time])?;
    db.execute("UPDATE physique_privacy SET status='completed',updated=?1,retained_reason=NULL WHERE status='partiallyHeld' AND EXISTS(SELECT 1 FROM physique_privacy_holds l WHERE l.receipt_id=physique_privacy.id) AND NOT EXISTS(SELECT 1 FROM physique_privacy_holds l JOIN physique_holds h ON h.media_id=l.media_id WHERE l.receipt_id=physique_privacy.id AND h.expires>?1)",[time])?;
    db.execute("DELETE FROM physique_privacy_holds WHERE receipt_id IN (SELECT id FROM physique_privacy WHERE status='completed')",[])?;
    let expired: Vec<(String, String)> = db
        .prepare_cached(
            "SELECT id,file_key FROM physique_media WHERE file_key IS NOT NULL AND expires<=?",
        )?
        .query_map([time], |r| Ok((r.get(0)?, r.get(1)?)))?
        .collect::<rusqlite::Result<_>>()?;
    for (id, key) in expired {
        let keep: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM physique_holds WHERE file_key=? AND expires>?)",
            params![key, time],
            |r| r.get(0),
        )?;
        db.execute("UPDATE physique_media SET file_key=NULL,status=CASE WHEN status='removed' THEN status ELSE 'expired' END WHERE id=?",[id])?;
        if !keep {
            judge::remove_file(settings, &key)?;
        }
    }
    let keys: Vec<String> = db
        .prepare_cached("SELECT DISTINCT file_key FROM physique_holds WHERE expires<=?")?
        .query_map([time], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    db.execute("DELETE FROM physique_holds WHERE expires<=?", [time])?;
    for key in keys {
        let keep:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_holds WHERE file_key=?1) OR EXISTS(SELECT 1 FROM physique_media WHERE file_key=?1)",[&key],|r|r.get(0))?;
        if !keep {
            judge::remove_file(settings, &key)?;
        }
    }
    db.execute("DELETE FROM physique_case_messages WHERE case_id IN (SELECT id FROM physique_cases WHERE closed IS NOT NULL AND closed<?)",[time-90.0*86400.0])?;
    db.execute("DELETE FROM physique_staff_access WHERE case_id IN (SELECT id FROM physique_cases WHERE closed IS NOT NULL AND closed<?)",[time-90.0*86400.0])?;
    db.execute("UPDATE physique_cases SET summary='Closed case retention expired',category='removed',target='redacted:'||id,decision=NULL WHERE closed IS NOT NULL AND closed<?",[time-90.0*86400.0])?;
    Ok(())
}
