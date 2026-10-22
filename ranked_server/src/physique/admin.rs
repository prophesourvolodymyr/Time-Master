use super::{
    cases, competition as comp,
    judge::{self, Settings},
    model::*,
};
use crate::{ApiError, Result, auth};
use axum::http::{HeaderMap, StatusCode};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use subtle::ConstantTimeEq;

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct StaffCommand {
    #[serde(rename = "requestID")]
    pub request_id: String,
    pub operation: String,
    #[serde(rename = "caseID")]
    pub case_id: String,
    pub status: Option<String>,
    pub text: Option<String>,
    pub reason: Option<String>,
    pub until: Option<f64>,
    pub correction: Option<String>,
}
impl crate::model::Validate for StaffCommand {
    fn validate(&mut self) -> Result<()> {
        if uuid::Uuid::parse_str(&self.request_id).is_err()
            || self.case_id.len() > 128
            || ![
                "claim",
                "status",
                "reply",
                "close",
                "restrict",
                "lift",
                "removeMedia",
                "correct",
            ]
            .contains(&self.operation.as_str())
            || self.text.as_ref().is_some_and(|s| {
                s.chars().count() > 4000
                    || s.chars().any(|c| c.is_control() && c != '\n' && c != '\t')
            })
            || self
                .reason
                .as_ref()
                .is_some_and(|s| s.len() > 600 || s.chars().any(|c| c.is_control()))
            || self.until.is_some_and(|v| !v.is_finite())
        {
            return Err(ApiError::invalid("Invalid authorized case operation"));
        }
        Ok(())
    }
}
pub fn authorize(settings: &Settings, headers: &HeaderMap) -> Result<String> {
    settings.require_intake()?;
    let raw = crate::bearer(headers)?;
    let (id, secret) = raw.split_once(':').ok_or_else(|| {
        ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Authorized case review credentials are required",
        )
    })?;
    let expected = settings.staff.get(id).ok_or_else(|| {
        ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Authorized case review credentials are required",
        )
    })?;
    let actual = auth::digest(secret);
    if secret.len() < 32 || !bool::from(expected.as_bytes().ct_eq(actual.as_bytes())) {
        return Err(ApiError::new(
            StatusCode::UNAUTHORIZED,
            "Authorized case review credentials are required",
        ));
    }
    Ok(id.into())
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QueueItem {
    pub id: String,
    pub kind: String,
    pub status: String,
    pub summary: String,
    pub created_at: f64,
    pub updated_at: f64,
    pub assigned_to: Option<String>,
}
pub fn queue(db: &Connection) -> Result<Vec<QueueItem>> {
    Ok(db.prepare_cached("SELECT id,kind,status,summary,created,updated,decision_by FROM physique_cases WHERE closed IS NULL ORDER BY created,id LIMIT 100")?.query_map([],|r|Ok(QueueItem{id:r.get(0)?,kind:r.get(1)?,status:r.get(2)?,summary:r.get(3)?,created_at:r.get(4)?,updated_at:r.get(5)?,assigned_to:r.get(6)?}))?.collect::<rusqlite::Result<_>>()?)
}
pub fn require_case(db: &Connection, id: &str, staff: &str) -> Result<String> {
    let value: Option<(String, Option<String>)> = db
        .query_row(
            "SELECT owner,decision_by FROM physique_cases WHERE id=?",
            [id],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    let (owner, assigned) =
        value.ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Case is unavailable"))?;
    if assigned.as_deref() != Some(staff) {
        return Err(ApiError::new(
            StatusCode::FORBIDDEN,
            "Claim the specific case before accessing its private content",
        ));
    }
    Ok(owner)
}
pub fn detail(db: &Connection, id: &str, staff: &str) -> Result<Case> {
    let owner = require_case(db, id, staff)?;
    cases::get(db, &owner, id)
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewPackage {
    pub case: Case,
    pub original_case: Option<Case>,
    pub declared_attire_rule: Option<String>,
}
pub fn package(db: &Connection, id: &str, staff: &str) -> Result<ReviewPackage> {
    let owner = require_case(db, id, staff)?;
    let case = cases::get(db, &owner, id)?;
    let (parent, target): (Option<String>, String) = db.query_row(
        "SELECT parent_id,target FROM physique_cases WHERE id=?",
        [id],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )?;
    let original_case = parent
        .as_ref()
        .map(|id| cases::get(db, &owner, id))
        .transpose()?;
    let subject = if case.kind == "appeal" || case.kind == "restriction" {
        Some(owner)
    } else {
        target_account(db, &target)?
    };
    let declared_attire_rule = if let (Some(subject), Some(mid)) = (subject, case.match_id.as_ref())
    {
        let declaration: Option<bool> = db
            .query_row(
                "SELECT adult_man FROM physique_participants WHERE user_id=? AND match_id=?",
                params![subject, mid],
                |r| r.get(0),
            )
            .optional()?;
        declaration.map(|adult_man| {
            if adult_man {
                "Privately declared adult man: nonsexual torso or opaque athletic top allowed"
            } else {
                "Opaque athletic top or sports bra required"
            }
            .to_owned()
        })
    } else {
        None
    };
    Ok(ReviewPackage {
        case,
        original_case,
        declared_attire_rule,
    })
}
pub fn command(
    db: &Connection,
    staff: &str,
    command: &StaffCommand,
    settings: &Settings,
    time: f64,
) -> Result<Case> {
    let fingerprint = auth::digest(serde_json::to_vec(command)?);
    let existing: Option<String> = db
        .query_row(
            "SELECT fingerprint FROM physique_staff_requests WHERE staff_id=? AND request_id=?",
            params![staff, command.request_id],
            |r| r.get(0),
        )
        .optional()?;
    if let Some(existing) = existing {
        if existing != fingerprint {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This staff requestID was used for different work",
            ));
        }
        return detail(db, &command.case_id, staff);
    }
    if command.operation == "claim" {
        let closed: bool = db
            .query_row(
                "SELECT closed IS NOT NULL FROM physique_cases WHERE id=?",
                [&command.case_id],
                |r| r.get(0),
            )
            .optional()?
            .ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Case is unavailable"))?;
        if closed {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This case already has a final decision; a permitted new appeal is reviewed separately",
            ));
        }
        let (parent, decided): (Option<String>, Option<String>) = db
            .query_row(
                "SELECT parent_id,decision_by FROM physique_cases WHERE id=?",
                [&command.case_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?
            .ok_or_else(|| ApiError::new(StatusCode::NOT_FOUND, "Case is unavailable"))?;
        if decided.as_ref().is_some_and(|v| v != staff) {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "Another authorized reviewer owns this case",
            ));
        }
        if let Some(parent) = parent {
            let original: Option<String> = db.query_row(
                "SELECT decision_by FROM physique_cases WHERE id=?",
                [parent],
                |r| r.get(0),
            )?;
            if original.as_deref() == Some(staff) {
                return Err(ApiError::new(
                    StatusCode::FORBIDDEN,
                    "A contested safety decision requires a different configured reviewer",
                ));
            }
        }
        db.execute("UPDATE physique_cases SET decision_by=?,status='inReview',updated=max(updated+0.000001,?) WHERE id=?",params![staff,time,command.case_id])?;
    } else {
        let owner = require_case(db, &command.case_id, staff)?;
        let case = cases::get(db, &owner, &command.case_id)?;
        let closed: bool = db.query_row(
            "SELECT closed IS NOT NULL FROM physique_cases WHERE id=?",
            [&command.case_id],
            |r| r.get(0),
        )?;
        if closed {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This case is already closed; its decision cannot be silently reopened",
            ));
        }
        let reason = command
            .reason
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty());
        match command.operation.as_str() {
            "status" => {
                let status = command.status.as_deref().unwrap_or("");
                if !["queued", "inReview", "needsReply", "inconclusive"].contains(&status) {
                    return Err(ApiError::invalid("Unsupported open case status"));
                }
                if status == "needsReply" {
                    let text=command.text.as_deref().map(str::trim).filter(|v|!v.is_empty()).ok_or_else(||ApiError::invalid("A reviewed safe question is required before requesting a participant reply"))?;
                    db.execute(
                        "INSERT INTO physique_case_messages VALUES (?,?,?,?,1,?)",
                        params![auth::identifier()?, command.case_id, text, time, staff],
                    )?;
                }
                db.execute("UPDATE physique_cases SET status=?,needs_reply=?,updated=max(updated+0.000001,?) WHERE id=?",params![status,status=="needsReply",time,command.case_id])?;
            }
            "reply" => {
                let text = command
                    .text
                    .as_deref()
                    .map(str::trim)
                    .filter(|v| !v.is_empty())
                    .ok_or_else(|| ApiError::invalid("Enter a reviewed safe reply"))?;
                db.execute(
                    "INSERT INTO physique_case_messages VALUES (?,?,?,?,1,?)",
                    params![auth::identifier()?, command.case_id, text, time, staff],
                )?;
                db.execute(
                    "UPDATE physique_cases SET updated=max(updated+0.000001,?) WHERE id=?",
                    params![time, command.case_id],
                )?;
            }
            "close" => {
                let status = command.status.as_deref().unwrap_or("");
                if ![
                    "actionTaken",
                    "noViolation",
                    "inconclusive",
                    "closed",
                    "upheld",
                    "revised",
                ]
                .contains(&status)
                {
                    return Err(ApiError::invalid(
                        "Choose an actual reviewed decision status",
                    ));
                }
                let reason = reason.ok_or_else(|| {
                    ApiError::invalid("A private reviewed decision explanation is required")
                })?;
                db.execute("UPDATE physique_cases SET status=?,decision=?,closed=?,updated=max(updated+0.000001,?),needs_reply=0 WHERE id=?",params![status,reason,time,time,command.case_id])?;
                release_holds(db, &command.case_id, settings, time)?;
            }
            "restrict" | "lift" => {
                let target: String = db.query_row(
                    "SELECT target FROM physique_cases WHERE id=?",
                    [&command.case_id],
                    |r| r.get(0),
                )?;
                let target_uid = if case.kind == "restriction" || case.kind == "appeal" {
                    owner.clone()
                } else {
                    target_account(db, &target)?.ok_or_else(|| {
                        ApiError::invalid(
                            "This case does not authorize a specific account restriction",
                        )
                    })?
                };
                let reason = reason.ok_or_else(|| {
                    ApiError::invalid("A safe private restriction explanation is required")
                })?;
                if command.operation == "restrict" {
                    let available:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_profiles WHERE user_id=? AND deleted=0)",[&target_uid],|r|r.get(0))?;
                    if !available {
                        return Err(ApiError::new(
                            StatusCode::GONE,
                            "This account is unavailable for a new restriction",
                        ));
                    }
                    let notified:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_cases WHERE kind='restriction' AND owner=? AND target=?)",params![target_uid,command.case_id],|r|r.get(0))?;
                    if notified {
                        return Err(ApiError::new(
                            StatusCode::CONFLICT,
                            "This case already issued its restriction notice; do not duplicate the enforcement action",
                        ));
                    }
                    if command.until.is_some_and(|v| v <= time) {
                        return Err(ApiError::invalid(
                            "Restriction expiry must be in the future",
                        ));
                    }
                    db.execute("UPDATE physique_profiles SET restricted_reason=?,restricted_until=? WHERE user_id=?",params![reason,command.until,target_uid])?;
                    db.execute("DELETE FROM physique_queue WHERE user_id=?", [&target_uid])?;
                    if let Some(mid) = comp::active(db, &target_uid)? {
                        let m = comp::stored_match(db, &mid)?;
                        comp::finish_unscored(
                            db,
                            &mid,
                            if ["ready", "countdown"].contains(&m.stage.as_str()) {
                                "cancelled"
                            } else {
                                "noContest"
                            },
                            "Participation was restricted by authorized safety review",
                            time,
                        )?;
                    }
                    let notice = auth::identifier()?;
                    db.execute("INSERT INTO physique_cases(id,owner,kind,status,summary,category,target,match_id,created,updated,closed,decision,decision_by) VALUES (?1,?2,'restriction','actionTaken','Physique access restriction','restriction',?3,?4,?5,?5,?5,?6,?7)",params![notice,target_uid,command.case_id,case.match_id,time,reason,staff])?;
                } else {
                    db.execute("UPDATE physique_profiles SET restricted_reason=NULL,restricted_until=NULL WHERE user_id=?",[&target_uid])?;
                }
            }
            "removeMedia" => {
                let target: String = db.query_row(
                    "SELECT target FROM physique_cases WHERE id=?",
                    [&command.case_id],
                    |r| r.get(0),
                )?;
                let changed=db.execute("UPDATE physique_media SET status='removed',reason='Removed for safety' WHERE id=?",[&target])?;
                if changed == 0 {
                    return Err(ApiError::invalid(
                        "This case does not identify a particular media item",
                    ));
                }
                let mid: String = db.query_row(
                    "SELECT match_id FROM physique_media WHERE id=?",
                    [&target],
                    |r| r.get(0),
                )?;
                comp::finish_unscored(
                    db,
                    &mid,
                    "noContest",
                    "Required media was removed by authorized safety review; allowance restored",
                    time,
                )?;
            }
            "correct" => {
                if case.kind != "dispute" {
                    return Err(ApiError::new(
                        StatusCode::FORBIDDEN,
                        "Competitive correction requires an assigned outcome dispute",
                    ));
                }
                let mid = case
                    .match_id
                    .as_deref()
                    .ok_or_else(|| ApiError::invalid("This review has no match"))?;
                let mode = command.correction.as_deref().unwrap_or("");
                let reason = reason.ok_or_else(|| {
                    ApiError::invalid("An evidenced private correction reason is required")
                })?;
                correct(db, mid, &command.case_id, staff, mode, reason, time)?;
                db.execute("UPDATE physique_cases SET status='revised',decision=?,closed=?,updated=max(updated+0.000001,?),needs_reply=0 WHERE id=?",params![reason,time,time,command.case_id])?;
                release_holds(db, &command.case_id, settings, time)?;
            }
            _ => return Err(ApiError::invalid("Unknown case operation")),
        }
    }
    db.execute(
        "INSERT INTO physique_staff_requests VALUES (?,?,?,?)",
        params![staff, command.request_id, fingerprint, time],
    )?;
    detail(db, &command.case_id, staff)
}
fn target_account(db: &Connection, target: &str) -> Result<Option<String>> {
    if let Some(uid) = db
        .query_row("SELECT id FROM accounts WHERE public_id=?", [target], |r| {
            r.get::<_, String>(0)
        })
        .optional()?
    {
        return Ok(Some(uid));
    }
    Ok(db.query_row("SELECT p.user_id FROM physique_media x JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE x.id=?",[target],|r|r.get::<_,Option<String>>(0)).optional()?.flatten())
}
fn release_holds(db: &Connection, id: &str, settings: &Settings, time: f64) -> Result<()> {
    let keys: Vec<String> = db
        .prepare_cached("SELECT file_key FROM physique_holds WHERE case_id=?")?
        .query_map([id], |r| r.get(0))?
        .collect::<rusqlite::Result<_>>()?;
    db.execute("DELETE FROM physique_holds WHERE case_id=?", [id])?;
    for key in keys {
        let retained:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_holds WHERE file_key=?1 AND expires>?2) OR EXISTS(SELECT 1 FROM physique_media WHERE file_key=?1 AND expires>?2)",params![key,time],|r|r.get(0))?;
        if !retained {
            judge::remove_file(settings, &key)?;
        }
    }
    Ok(())
}
fn correct(
    db: &Connection,
    mid: &str,
    case: &str,
    staff: &str,
    mode: &str,
    reason: &str,
    time: f64,
) -> Result<()> {
    if !["noContest", "recompute", "swap"].contains(&mode) {
        return Err(ApiError::invalid(
            "Correction must void invalidity or deterministically repair original accepted scores",
        ));
    }
    let stored = comp::stored_match(db, mid)?;
    if stored.finalized.is_none()
        || stored.start.is_none()
        || stored.corrected
        || !["completed", "forfeited"].contains(&stored.stage.as_str())
    {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This match has no eligible original rated result to correct",
        ));
    }
    let busy:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_active WHERE user_id IN (SELECT user_id FROM physique_participants WHERE match_id=?))",[mid],|r|r.get(0))?;
    if busy {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "The affected players must finish their current match before a coherent correction can settle",
        ));
    }
    let rows:Vec<(String,Option<String>,String,Option<String>,i64,i64,i64)>=db.prepare_cached("SELECT slot,user_id,outcome,scores,before_rating,sensitivity,coalesce(delta,0) FROM physique_participants WHERE match_id=? ORDER BY slot")?.query_map([mid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?,r.get(6)?)))?.collect::<rusqlite::Result<_>>()?;
    if rows.len() != 2 || rows.iter().any(|r| r.1.is_none()) {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "A deleted participant cannot be rerated",
        ));
    }
    let original = serde_json::to_string(
        &serde_json::json!({"stage":stored.stage,"participants":rows,"explanation":stored.explanation,"judgeVersion":stored.version}),
    )?;
    let mut scores: Vec<Option<Scores>> = rows
        .iter()
        .map(|r| r.3.as_ref().map(|v| serde_json::from_str(v)).transpose())
        .collect::<std::result::Result<_, _>>()?;
    let winner = if mode == "noContest" {
        None
    } else {
        if scores.iter().any(Option::is_none) || stored.stage != "completed" {
            return Err(ApiError::invalid(
                "A deterministic score correction requires the original complete judged scores",
            ));
        }
        if mode == "swap" {
            scores.swap(0, 1)
        }
        for score in scores.iter_mut().flatten() {
            if [
                score.muscularity,
                score.definition,
                score.symmetry,
                score.presentation,
            ]
            .into_iter()
            .any(|v| !(0..=100).contains(&v))
            {
                return Err(ApiError::invalid(
                    "The original accepted categories do not support a deterministic correction",
                ));
            }
            score.total = score.tenths() as f64 / 10.0;
        }
        let a = scores[0].as_ref().ok_or_else(ApiError::internal)?;
        let b = scores[1].as_ref().ok_or_else(ApiError::internal)?;
        a.validate()?;
        b.validate()?;
        let diff = a.tenths() - b.tenths();
        if diff.abs() < 30 {
            None
        } else if diff > 0 {
            Some("a")
        } else {
            Some("b")
        }
    };
    let correction_id = auth::identifier()?;
    for (index, (slot, owner, _, _, before, k, old_delta)) in rows.iter().enumerate() {
        let uid = owner.as_deref().ok_or_else(ApiError::internal)?;
        let desired_outcome = if mode == "noContest" {
            "noContest"
        } else {
            match winner {
                None => "draw",
                Some(s) if s == slot => "win",
                _ => "loss",
            }
        };
        let score = if desired_outcome == "draw" {
            0.5
        } else if desired_outcome == "win" {
            1.0
        } else {
            0.0
        };
        let desired_delta = if mode == "noContest" {
            0
        } else {
            comp::rating_after(*before, rows[1 - index].4, *k, score) - before
        };
        let current: i64 = db.query_row(
            "SELECT rating FROM physique_profiles WHERE user_id=?",
            [uid],
            |r| r.get(0),
        )?;
        let adjusted = (current + desired_delta - old_delta).clamp(0, 5000);
        db.execute(
            "UPDATE physique_profiles SET rating=? WHERE user_id=?",
            params![adjusted, uid],
        )?;
        db.execute("UPDATE physique_participants SET outcome=?,delta=?,scores=?,after_rating=? WHERE match_id=? AND slot=?",params![desired_outcome,desired_delta,if mode=="noContest"{None}else{scores[index].as_ref().map(serde_json::to_string).transpose()?},if mode=="noContest"{None}else{Some(before+desired_delta)},mid,slot])?;
        db.execute("UPDATE physique_rating_events SET kind='superseded' WHERE user_id=? AND match_id=? AND kind='result'",params![uid,mid])?;
        db.execute(
            "INSERT INTO physique_rating_events VALUES (?,?,?,'correction',?,?,?)",
            params![
                auth::identifier()?,
                uid,
                mid,
                time,
                adjusted - current,
                adjusted
            ],
        )?;
    }
    db.execute("UPDATE physique_matches SET stage=?,winner=?,corrected=1,reason=?,explanation=NULL WHERE id=?",params![if mode=="noContest"{"noContest"}else{"completed"},winner,reason,mid])?;
    if mode == "noContest" {
        db.execute(
            "UPDATE physique_starts SET restored=1 WHERE match_id=? AND restored=0",
            [mid],
        )?;
    }
    let corrected =
        serde_json::to_string(&serde_json::json!({"mode":mode,"winner":winner,"scores":scores}))?;
    db.execute(
        "INSERT INTO physique_corrections VALUES (?,?,?,?,?,?,?,?)",
        params![
            correction_id,
            mid,
            case,
            staff,
            time,
            reason,
            original,
            corrected
        ],
    )?;
    Ok(())
}
