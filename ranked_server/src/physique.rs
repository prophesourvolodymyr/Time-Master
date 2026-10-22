mod admin;
mod cases;
mod competition;
mod judge;
mod model;
mod pages;

use crate::{ApiError, AppState, Input, Result, auth};
use axum::{
    Json,
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
};
use base64::{Engine, engine::general_purpose::STANDARD};
use competition as comp;
use judge::Settings;
pub(crate) use judge::{MAX_COMMAND_BODY, Service};
use model::*;
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;

pub(crate) async fn policy(State(state): State<AppState>) -> Json<Policy> {
    Json(state.physique.settings.policy.clone())
}
pub(crate) async fn state(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Snapshot>> {
    let settings = state.physique.settings.clone();
    state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            comp::sweep(db, &settings, time)?;
            comp::pair(db, &settings, time)?;
            comp::snapshot(db, uid, &settings, time)
        })
        .await
        .map(Json)
}
#[derive(Deserialize)]
pub(crate) struct PageQuery {
    cursor: Option<String>,
}
pub(crate) async fn history(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<PageQuery>,
) -> Result<Json<Page<Match>>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            pages::history(db, uid, query.cursor.as_deref(), time)
        })
        .await
        .map(Json)
}
pub(crate) async fn standings(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<PageQuery>,
) -> Result<Json<Page<Standing>>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            pages::standings(db, uid, query.cursor.as_deref(), time)
        })
        .await
        .map(Json)
}
pub(crate) async fn player(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Standing>> {
    state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            pages::standing(db, uid, &id, time)
        })
        .await
        .map(Json)
}
pub(crate) async fn get_match(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Match>> {
    let settings = state.physique.settings.clone();
    state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            comp::sweep(db, &settings, time)?;
            comp::match_view(db, uid, &id, time)
        })
        .await
        .map(Json)
}
pub(crate) async fn case_list(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Items<Case>>> {
    state
        .authenticated(&headers, move |db, uid, _| {
            comp::ensure(db, uid)?;
            Ok(Items {
                items: cases::list(db, uid)?,
            })
        })
        .await
        .map(Json)
}
pub(crate) async fn case_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Case>> {
    state
        .authenticated(&headers, move |db, uid, _| {
            comp::ensure(db, uid)?;
            cases::get(db, uid, &id)
        })
        .await
        .map(Json)
}
pub(crate) async fn privacy(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Items<PrivacyReceipt>>> {
    state
        .authenticated(&headers, move |db, uid, _| {
            comp::ensure(db, uid)?;
            Ok(Items {
                items: cases::privacy_list(db, uid)?,
            })
        })
        .await
        .map(Json)
}
pub(crate) async fn blocks(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Items<BlockedPlayer>>> {
    state.authenticated(&headers,move|db,uid,_|{
        comp::ensure(db,uid)?;
        let items=db.prepare_cached("SELECT a.public_id,p.display_name FROM physique_blocks b JOIN accounts a ON a.id=b.target JOIN physique_profiles p ON p.user_id=a.id WHERE b.owner=? AND p.deleted=0 ORDER BY b.created DESC,a.public_id")?.query_map([uid],|r|Ok(BlockedPlayer{id:r.get(0)?,display_name:r.get(1)?}))?.collect::<rusqlite::Result<_>>()?;
        Ok(Items{items})
    }).await.map(Json)
}
pub(crate) async fn gallery(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Items<Media>>> {
    let settings = state.physique.settings.clone();
    state.authenticated(&headers,move|db,uid,time|{
        comp::ensure(db,uid)?;comp::require_member(db,uid,&id)?;
        let view=comp::match_view(db,uid,&id,time)?;
        if !view.gallery_available{return Err(ApiError::new(StatusCode::FORBIDDEN,"This match has no currently authorized judged pose gallery"))}
        let rows:Vec<(String,String,String,String,Option<String>,f64,Option<String>,bool)>=db.prepare_cached("SELECT x.id,x.pose,x.status,p.identity,x.file_key,x.expires,p.user_id,p.sharing FROM physique_media x JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE x.match_id=? ORDER BY p.slot,CASE x.pose WHEN 'front' THEN 0 WHEN 'side' THEN 1 ELSE 2 END")?.query_map([&id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?,r.get(6)?,r.get(7)?)))?.collect::<rusqlite::Result<_>>()?;
        let mut items=Vec::new();
        for (id,pose,stored_status,label,key,expires,owner,sharing) in rows{
            let label:Identity=serde_json::from_str(&label)?;
            let hidden:Option<bool>=db.query_row("SELECT reported FROM physique_hides WHERE owner=? AND media_id=?",params![uid,id],|r|r.get(0)).optional()?;
            let status=if owner.is_none(){"removed"}else if owner.as_ref().is_some_and(|o|comp::blocked(db,uid,o).unwrap_or(true)){"blocked"}else if hidden==Some(true){"reported"}else if hidden==Some(false){"hidden"}else if !sharing{"sharingWithdrawn"}else if expires<=time{"expired"}else if stored_status=="removed"{"removed"}else if stored_status!="accepted"||key.is_none(){"unavailable"}else{"available"};
            let image=if status=="available"{key.as_ref().and_then(|key|judge::read_media(&settings,key).ok()).map(|bytes|STANDARD.encode(bytes))}else{None};
            items.push(Media{id,owner_id:label.id,pose,status:if status=="available"&&image.is_none(){"unavailable".into()}else{status.into()},image_base64:image,expires_at:Some(expires)});
        }
        Ok(Items{items})
    }).await.map(Json)
}
fn fingerprint(command: &Command) -> Result<String> {
    Ok(auth::digest(serde_json::to_vec(command)?))
}
fn prior(
    db: &Connection,
    uid: &str,
    command: &Command,
) -> Result<Option<(Option<String>, Option<String>)>> {
    let found:Option<(String,String,Option<String>,Option<String>)>=db.query_row("SELECT fingerprint,status,receipt_id,message FROM physique_requests WHERE user_id=? AND request_id=?",params![uid,command.request_id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?))).optional()?;
    if let Some((hash, status, receipt, message)) = found {
        if hash != fingerprint(command)? {
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This requestID was already used for a different Physique action",
            ));
        }
        if status == "pending" {
            let terminal = command
                .match_id
                .as_ref()
                .map(|mid| comp::stored_match(db, mid))
                .transpose()?
                .is_some_and(|m| m.finalized.is_some());
            if terminal {
                let message = "This protected action ended with its match; no additional upload or rating was processed";
                db.execute("UPDATE physique_requests SET status='complete',message=? WHERE user_id=? AND request_id=?",params![message,uid,command.request_id])?;
                return Ok(Some((receipt, Some(message.into()))));
            }
            return Err(ApiError::new(
                StatusCode::CONFLICT,
                "This exact protected action is still checking. Refresh its current state before retrying",
            ));
        }
        Ok(Some((receipt, message)))
    } else {
        Ok(None)
    }
}
fn record(
    db: &Connection,
    uid: &str,
    command: &Command,
    status: &str,
    receipt: Option<&str>,
    message: Option<&str>,
    time: f64,
) -> Result<()> {
    db.execute("INSERT INTO physique_requests VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(user_id,request_id) DO UPDATE SET status=excluded.status,receipt_id=excluded.receipt_id,message=excluded.message",params![uid,command.request_id,fingerprint(command)?,command.operation,time,status,receipt,message])?;
    Ok(())
}
fn response(
    db: &Connection,
    uid: &str,
    settings: &Settings,
    receipt_id: Option<String>,
    message: Option<String>,
    time: f64,
) -> Result<CommandResponse> {
    Ok(CommandResponse {
        snapshot: comp::snapshot(db, uid, settings, time)?,
        receipt_id,
        message,
    })
}
pub(crate) async fn command(
    State(state): State<AppState>,
    headers: HeaderMap,
    Input(body): Input<Command>,
) -> Result<Json<CommandResponse>> {
    if body.operation == "deleteAccount" {
        state.authenticated(&headers, |_, _, _| Ok(())).await?;
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "Use the shared authenticated DELETE /v1/account operation to delete the complete TimeMaster account. Physique-only deletion is not account deletion",
        ));
    }
    if body.operation == "candidate" {
        return candidate(state, headers, body).await.map(Json);
    }
    let settings = state.physique.settings.clone();
    let name = if body.operation == "identity" {
        body.text.clone()
    } else {
        None
    };
    if let Some(name) = name {
        let request = body.clone();
        let config = settings.clone();
        if let Some(replay) = state
            .authenticated(&headers, move |db, uid, time| {
                comp::ensure(db, uid)?;
                prior(db, uid, &request)?
                    .map(|(receipt, message)| response(db, uid, &config, receipt, message, time))
                    .transpose()
            })
            .await?
        {
            return Ok(Json(replay));
        }
        settings.require_intake()?;
        validate_name(&name)?;
        if !state.physique.screen_text(&name, true).await? {
            return Err(ApiError::invalid(
                "This public display name did not pass the contextual text rules",
            ));
        }
    }
    state.authenticated(&headers,move|db,uid,time|{
        comp::ensure(db,uid)?;
        if let Some((receipt,message))=prior(db,uid,&body)?{return response(db,uid,&settings,receipt,message,time)}
        comp::sweep(db,&settings,time)?;
        let mut receipt=None;
        let message=match body.operation.as_str(){
            "consent"=>{
                if !settings.intake_ready||settings.policy.version.is_empty()||settings.policy.processor.is_empty()||settings.policy.region.is_empty(){return Err(judge::unavailable("Actual processing recipients and sharing disclosures must be configured before accepting consent"))}
                let value=body.consent.as_ref().ok_or_else(||ApiError::invalid("Consent choices are required"))?;
                if value.policy_version!=settings.policy.version{return Err(ApiError::new(StatusCode::CONFLICT,"The sharing policy changed. Read the current disclosures before granting permission"))}
                if body.expected_revision!=Some(cases::consent_revision(db,uid)?){return Err(ApiError::new(StatusCode::CONFLICT,"Sharing choices changed on another device. Refresh before granting consent"))}
                cases::update_consent(db,uid,value,time)?;
                if !value.accepted(&settings.policy.version){
                    if let Some(mid)=comp::active(db,uid)?{
                        let m=comp::stored_match(db,&mid)?;
                        if ["ready","countdown"].contains(&m.stage.as_str()){comp::cancel(db,uid,time)?;}
                        else if !value.ai_processing||!value.adult||!value.rules_accepted{comp::finish_unscored(db,&mid,"noContest","Required processing authorization was withdrawn; allowance restored",time)?;}
                    }
                    db.execute("DELETE FROM physique_queue WHERE user_id=?",[uid])?;
                    if !value.opponent_sharing{db.execute("UPDATE physique_participants SET sharing=0 WHERE user_id=?",[uid])?;}
                }
                "Current separate sharing choices saved".into()
            }
            "identity"=>{
                if let Some(name)=&body.text{validate_name(name)?;db.execute("UPDATE physique_profiles SET display_name=? WHERE user_id=?",params![name.trim(),uid])?;}
                if let Some(country)=&body.country_code{
                    let country=country.trim().to_uppercase();
                    if !country.is_empty()&&!valid_country(&country){return Err(ApiError::invalid("Choose a supported country or region, or remove the choice"))}
                    db.execute("UPDATE physique_profiles SET country_code=? WHERE user_id=?",params![if country.is_empty(){None}else{Some(country)},uid])?;
                    db.execute("UPDATE physique_participants SET identity=json_set(identity,'$.countryCode',NULL) WHERE user_id=?",[uid])?;
                }
                if body.text.is_none()&&body.country_code.is_none(){return Err(ApiError::invalid("Choose a display name or country change"))}
                "Permitted public identity preference saved".into()
            }
            "listing"=>{let value=body.value.ok_or_else(||ApiError::invalid("A listing choice is required"))?;db.execute("UPDATE physique_profiles SET listed=? WHERE user_id=?",params![value,uid])?;"Physique public-listing choice saved; earned records are unchanged".into()}
            "enqueue"=>comp::start_search(db,uid,&settings,time)?,
            "cancel"=>{comp::cancel(db,uid,time)?;"Opponent search or preparation cancelled before Go".into()}
            "ready"=>{let mid=required_match(&body)?;comp::ready(db,uid,mid,body.value.unwrap_or(true),&settings,time)?;"Readiness saved".into()}
            "presence"=>{comp::touch(db,uid,body.match_id.as_deref(),time)?;comp::pair(db,&settings,time)?;"Current participation refreshed".into()}
            "submit"=>{submit(db,uid,required_match(&body)?,&settings,time)?;"Accepted pose set locked for this match".into()}
            "leave"=>{comp::leave(db,uid,required_match(&body)?,body.reason.as_deref().unwrap_or(""),&settings,time)?;"The confirmed match exit was settled by the service".into()}
            "block"|"unblock"=>{
                let public=body.target_id.as_deref().ok_or_else(||ApiError::invalid("Choose the player"))?;
                let target=if body.operation=="unblock"{
                    db.query_row("SELECT b.target FROM physique_blocks b JOIN accounts a ON a.id=b.target WHERE b.owner=? AND a.public_id=?",params![uid,public],|r|r.get::<_,String>(0)).optional()?.ok_or_else(||ApiError::new(StatusCode::NOT_FOUND,"This player is not in your block list"))?
                }else{comp::resolve_target(db,uid,public,time)?};
                if target==uid{return Err(ApiError::invalid("You cannot block your own account"))}
                if body.operation=="block"{
                    db.execute("INSERT OR IGNORE INTO physique_blocks VALUES (?,?,?)",params![uid,target,time])?;
                    if let Some(mid)=comp::active(db,uid)?{
                        let paired:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_participants WHERE match_id=? AND user_id=?)",params![mid,target],|r|r.get(0))?;
                        let m=comp::stored_match(db,&mid)?;
                        if paired&&["ready","countdown"].contains(&m.stage.as_str()){comp::cancel(db,uid,time)?;}
                    }
                    "Player blocked. Relevant media and public discovery are hidden; an already started match is not automatically forfeited".into()
                }else{db.execute("DELETE FROM physique_blocks WHERE owner=? AND target=?",params![uid,target])?;"Player unblocked. No rematch or expired media was restored".into()}
            }
            "report"=>{let(id,message)=cases::report(db,uid,&body,&settings,time)?;receipt=Some(id);message}
            "review"=>{let(id,message)=cases::review(db,uid,&body,&settings,time)?;receipt=Some(id);message}
            "reply"=>{let(id,message)=cases::reply(db,uid,&body,time)?;receipt=Some(id);message}
            "withdrawCase"=>{let id=body.target_id.as_deref().ok_or_else(||ApiError::invalid("Choose the private case"))?;let(id,message)=cases::withdraw(db,uid,id,time)?;receipt=Some(id);message}
            "withdrawAI"|"withdrawSharing"|"removeImages"=>{let(id,message)=cases::privacy_action(db,uid,&body,&settings,time)?;receipt=Some(id);message}
            _=>return Err(ApiError::invalid("This Physique operation is unavailable")),
        };
        record(db,uid,&body,"complete",receipt.as_deref(),Some(&message),time)?;
        response(db,uid,&settings,receipt,Some(message),time)
    }).await.map(Json)
}
fn required_match(command: &Command) -> Result<&str> {
    command
        .match_id
        .as_deref()
        .ok_or_else(|| ApiError::invalid("A Physique match reference is required"))
}
fn validate_name(name: &str) -> Result<()> {
    let name = name.trim();
    if name.chars().count() < 2
        || name.chars().count() > 32
        || name
            .chars()
            .any(|c| !(c.is_alphanumeric() || c == ' ' || c == '_' || c == '-' || c == '.'))
    {
        return Err(ApiError::invalid(
            "Display name must contain2..32 letters, numbers, spaces, dots, underscores or hyphens",
        ));
    }
    Ok(())
}
fn valid_country(code: &str) -> bool {
    const COUNTRIES: &str = "AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW";
    code.len() == 2 && COUNTRIES.split(' ').any(|v| v == code)
}
fn submit(db: &Connection, uid: &str, mid: &str, settings: &Settings, time: f64) -> Result<()> {
    let slot = comp::require_member(db, uid, mid)?;
    comp::eligible(db, uid, settings, time, false)?;
    let stored = comp::stored_match(db, mid)?;
    if !["capture", "submitting"].contains(&stored.stage.as_str())
        || stored.deadline.is_none_or(|v| v <= time)
    {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "This match is not accepting final pose sets",
        ));
    }
    let accepted:i64=db.query_row("SELECT count(*) FROM physique_media WHERE match_id=? AND slot=? AND status='accepted' AND file_key IS NOT NULL",params![mid,slot],|r|r.get(0))?;
    if accepted != 3 {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "All three current pose candidates must pass protected checks before submission",
        ));
    }
    db.execute(
        "UPDATE physique_participants SET submitted=1,last_seen=? WHERE match_id=? AND user_id=?",
        params![time, mid, uid],
    )?;
    let submitted: i64 = db.query_row(
        "SELECT count(*) FROM physique_participants WHERE match_id=? AND submitted=1",
        [mid],
        |r| r.get(0),
    )?;
    if submitted == 2 {
        db.execute("UPDATE physique_matches SET stage='judging',judging_started=?,judging_deadline=? WHERE id=? AND finalized IS NULL",params![time,time+30.0,mid])?;
    }
    Ok(())
}
#[derive(Clone)]
struct Intake {
    mid: String,
    id: String,
    key: String,
    digest: String,
    adult_man: bool,
}
async fn candidate(state: AppState, headers: HeaderMap, body: Command) -> Result<CommandResponse> {
    let body = std::sync::Arc::new(body);
    let settings = state.physique.settings.clone();
    let request = body.clone();
    let config = settings.clone();
    if let Some(replay) = state
        .authenticated(&headers, move |db, uid, time| {
            comp::ensure(db, uid)?;
            prior(db, uid, &request)?
                .map(|(receipt, message)| response(db, uid, &config, receipt, message, time))
                .transpose()
        })
        .await?
    {
        return Ok(replay);
    }
    settings.require_ready()?;
    let _permit=state.physique.permits.clone().try_acquire_owned().map_err(|_|judge::unavailable("Protected capture processing is busy. Retry within this match's unchanged deadline"))?;
    let decode = body.clone();
    let bytes = tokio::task::spawn_blocking(move || {
        judge::decode_image(
            decode
                .image_base64
                .as_deref()
                .ok_or_else(|| ApiError::invalid("A redacted JPEG candidate is required"))?,
        )
    })
    .await
    .map_err(|_| ApiError::internal())??;
    let prepare = body.clone();
    let config = settings.clone();
    let digest = auth::digest(&bytes);
    let (intake,replay)=state.authenticated(&headers,move|db,uid,time|{
        if let Some((receipt,message))=prior(db,uid,&prepare)?{return Ok((None,Some(response(db,uid,&config,receipt,message,time)?)))}
        comp::sweep(db,&config,time)?;
        comp::eligible(db,uid,&config,time,false)?;
        let mid=required_match(&prepare)?;let slot=comp::require_member(db,uid,mid)?;
        let stored=comp::stored_match(db,mid)?;
        if stored.stage!="capture"||stored.deadline.is_none_or(|d|d<=time){return Err(ApiError::new(StatusCode::CONFLICT,"Candidate capture is no longer open for this match"))}
        let submitted:bool=db.query_row("SELECT submitted FROM physique_participants WHERE match_id=? AND user_id=?",params![mid,uid],|r|r.get(0))?;
        if submitted{return Err(ApiError::new(StatusCode::CONFLICT,"Your submitted pose set is locked"))}
        let pose=prepare.pose.as_deref().ok_or_else(||ApiError::invalid("Choose the named pose"))?;
        let previous:Option<(String,i64,Option<String>)>=db.query_row("SELECT id,attempts,file_key FROM physique_media WHERE match_id=? AND slot=? AND pose=?",params![mid,slot,pose],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).optional()?;
        let attempts=previous.as_ref().map_or(1,|p|p.1+1);
        if attempts>3{return Err(ApiError::new(StatusCode::CONFLICT,"This pose has used its two retakes"))}
        let id=auth::identifier()?;
        let key=judge::write_media(&config,&bytes)?;
        if let Some((old_id,_,old_key))=previous{
            let held:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_holds WHERE media_id=? AND expires>?)",params![old_id,time],|r|r.get(0))?;
            if held{return Err(ApiError::new(StatusCode::CONFLICT,"This evidence is retained for a received safety case and cannot be replaced"))}
            db.execute("DELETE FROM physique_hides WHERE media_id=?",[old_id])?;
            if let Some(old)=old_key{judge::remove_file(&config,&old)?;}
        }
        db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,file_key,digest,created,expires) VALUES (?,?,?,?,?,'checking',?,?,?,?) ON CONFLICT(match_id,slot,pose) DO UPDATE SET id=excluded.id,attempts=excluded.attempts,status='checking',reason=NULL,file_key=excluded.file_key,digest=excluded.digest,created=excluded.created,expires=excluded.expires",params![id,mid,slot,pose,attempts,key,digest,time,time+86400.0])?;
        record(db,uid,&prepare,"pending",None,None,time)?;
        let adult_man=db.query_row("SELECT adult_man FROM physique_participants WHERE match_id=? AND user_id=?",params![mid,uid],|r|r.get(0))?;
        Ok((Some((Intake{mid:mid.into(),id,key,digest,adult_man},bytes)),None))
    }).await?;
    if let Some(response) = replay {
        return Ok(response);
    }
    let (intake, bytes) = intake.ok_or_else(ApiError::internal)?;
    let decision = state
        .physique
        .screen_image(&bytes, body.pose.as_deref().unwrap_or(""), intake.adult_man)
        .await;
    let config = settings.clone();
    state.authenticated(&headers,move|db,uid,time|{
        let current:bool=db.query_row("SELECT EXISTS(SELECT 1 FROM physique_media WHERE id=? AND digest=? AND file_key=?)",params![intake.id,intake.digest,intake.key],|r|r.get(0))?;
        let stored=comp::stored_match(db,&intake.mid)?;
        let allowed=comp::eligible(db,uid,&config,time,false).is_ok()&&stored.stage=="capture"&&stored.deadline.is_some_and(|d|d>time);
        let message=if !current||!allowed{
            if current{db.execute("UPDATE physique_media SET file_key=NULL,status='removed',reason='Capture authorization or timing changed' WHERE id=?",[&intake.id])?;judge::remove_file(&config,&intake.key)?;}
            "This candidate was not accepted because the capture or authorization changed".to_owned()
        }else{match decision{
            Ok(decision)if decision.accepted()=>{db.execute("UPDATE physique_media SET status='accepted',reason=NULL WHERE id=? AND digest=?",params![intake.id,intake.digest])?;"The current redacted pose passed protected contextual and evidence checks".into()}
            Ok(decision)=>{
                db.execute("UPDATE physique_media SET status='rejected',reason=?,file_key=NULL WHERE id=? AND digest=?",params![decision.safe_reason(),intake.id,intake.digest])?;
                judge::remove_file(&config,&intake.key)?;
                cases::rejection_notice(db,uid,&intake.mid,&intake.id,decision.safe_reason(),time)?;
                if decision.reason=="unsafe"{comp::finish_unscored(db,&intake.mid,"noContest","Required contextual safety checks prevented a valid result; allowance restored",time)?;}
                decision.safe_reason().into()
            }
            Err(_)=>{db.execute("UPDATE physique_media SET status='rejected',reason='Required screening was unavailable',file_key=NULL WHERE id=?",[&intake.id])?;judge::remove_file(&config,&intake.key)?;comp::finish_unscored(db,&intake.mid,"noContest","Required contextual screening was unavailable; allowance restored",time)?;"Required screening was unavailable. No contest; no rating changed".into()}
        }};
        record(db,uid,&body,"complete",None,Some(&message),time)?;
        response(db,uid,&config,None,Some(message),time)
    }).await
}
pub(crate) async fn tick(state: &AppState) -> Result<()> {
    let settings = state.physique.settings.clone();
    let clock = state.clock.clone();
    let permits = state.physique.permits.clone();
    let maintenance = state.physique.maintenance.clone();
    let jobs=state.db.call(move|db|{
        let time=clock();comp::sweep(db,&settings,time)?;comp::pair(db,&settings,time)?;
        cases::cleanup(db,&settings,time)?;
        let now=time.max(0.0)as u64;
        let previous=maintenance.load(std::sync::atomic::Ordering::Relaxed);
        if now>=previous.saturating_add(60)&&maintenance.compare_exchange(previous,now,std::sync::atomic::Ordering::Relaxed,std::sync::atomic::Ordering::Relaxed).is_ok(){
            let retained=db.prepare_cached("SELECT file_key FROM physique_media WHERE file_key IS NOT NULL UNION SELECT file_key FROM physique_holds")?.query_map([],|r|r.get::<_,String>(0))?.collect::<rusqlite::Result<std::collections::HashSet<_>>>()?;
            judge::remove_orphans(&settings,&retained,time)?;
        }
        let mids:Vec<String>=db.prepare_cached("SELECT id FROM physique_matches WHERE stage='judging' AND finalized IS NULL AND judge_claimed=0 AND judging_deadline>? ORDER BY judging_deadline,id LIMIT 4")?.query_map([time],|r|r.get(0))?.collect::<rusqlite::Result<_>>()?;
        let mut jobs=Vec::new();
        for mid in mids{
            let Ok(permit)=permits.clone().try_acquire_owned()else{break};
            let rows:Vec<(String,String,String)>=db.prepare_cached("SELECT slot,pose,file_key FROM physique_media WHERE match_id=? AND status='accepted' AND file_key IS NOT NULL ORDER BY slot,pose")?.query_map([&mid],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?)))?.collect::<rusqlite::Result<_>>()?;
            if rows.len()!=6{comp::finish_unscored(db,&mid,"noContest","The accepted paired evidence was incomplete; allowance restored",time)?;continue}
            let images=rows.into_iter().map(|(slot,pose,key)|Ok(judge::JudgeImage{slot:slot.to_uppercase(),pose,bytes:judge::read_media(&settings,&key)?})).collect::<Result<Vec<_>>>();
            match images{Ok(images)=>{db.execute("UPDATE physique_matches SET judge_claimed=1 WHERE id=? AND judge_claimed=0",[&mid])?;jobs.push((mid,images,permit));},Err(_)=>comp::finish_unscored(db,&mid,"noContest","Protected evidence was unavailable; allowance restored",time)?,}
        }
        Ok(jobs)
    }).await?;
    for (mid, images, permit) in jobs {
        let state = state.clone();
        tokio::spawn(async move {
            let _permit = permit;
            let verdict = tokio::time::timeout(
                std::time::Duration::from_secs(28),
                state.physique.judge(images),
            )
            .await;
            let settings = state.physique.settings.clone();
            let clock = state.clock.clone();
            let result=state.db.call(move|db|{
                let time=clock();comp::sweep(db,&settings,time)?;
                let stored=comp::stored_match(db,&mid)?;
                if stored.stage!="judging"||stored.finalized.is_some(){return Ok(())}
                match verdict{
                    Ok(Ok(verdict))=>{let winner=match verdict.winner.as_str(){"A"=>Some("a"),"B"=>Some("b"),_=>None};comp::finalize(db,&mid,winner,false,Some(&verdict),time)},
                    _=>comp::finish_unscored(db,&mid,"noContest","The judge did not supply a complete safe result before its deadline; allowance restored",time),
                }
            }).await;
            if result.is_err() {
                eprintln!("Physique result settlement could not complete");
            }
        });
    }
    Ok(())
}
pub(crate) fn signed_out(db: &Connection, uid: &str, time: f64) -> Result<()> {
    if let Some(mid) = comp::active(db, uid)? {
        let stored = comp::stored_match(db, &mid)?;
        if ["ready", "countdown"].contains(&stored.stage.as_str()) {
            comp::cancel(db, uid, time)?;
        }
    } else {
        let queued: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM physique_queue WHERE user_id=?)",
            [uid],
            |r| r.get(0),
        )?;
        if queued {
            comp::cancel(db, uid, time)?;
        }
    }
    Ok(())
}
pub(crate) fn begin_deletion(db: &Connection, uid: &str, time: f64) -> Result<()> {
    cases::begin_deletion(db, uid, time)
}
pub(crate) fn finish_deletion(db: &Connection, uid: &str, time: f64) -> Result<()> {
    cases::finish_deletion(db, uid, &Settings::from_env(), time)
}
pub(crate) async fn admin_cases(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Items<admin::QueueItem>>> {
    admin::authorize(&state.physique.settings, &headers)?;
    state
        .db
        .call(|db| {
            Ok(Items {
                items: admin::queue(db)?,
            })
        })
        .await
        .map(Json)
}
pub(crate) async fn admin_case(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<admin::ReviewPackage>> {
    let staff = admin::authorize(&state.physique.settings, &headers)?;
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| {
            let package = admin::package(db, &id, &staff)?;
            db.execute(
                "INSERT INTO physique_staff_access VALUES (?,?,?,'case',?)",
                params![auth::identifier()?, staff, id, clock()],
            )?;
            Ok(package)
        })
        .await
        .map(Json)
}
pub(crate) async fn admin_command(
    State(state): State<AppState>,
    headers: HeaderMap,
    Input(body): Input<admin::StaffCommand>,
) -> Result<Json<Case>> {
    let staff = admin::authorize(&state.physique.settings, &headers)?;
    let settings = state.physique.settings.clone();
    let clock = state.clock.clone();
    state
        .db
        .call(move |db| admin::command(db, &staff, &body, &settings, clock()))
        .await
        .map(Json)
}
pub(crate) async fn admin_media(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Items<Media>>> {
    let staff = admin::authorize(&state.physique.settings, &headers)?;
    let settings = state.physique.settings.clone();
    let clock = state.clock.clone();
    state.db.call(move|db|{
        admin::require_case(db,&id,&staff)?;let time=clock();
        db.execute("INSERT INTO physique_staff_access VALUES (?,?,?,'media',?)",params![auth::identifier()?,staff,id,time])?;
        let rows:Vec<(String,String,String,String,f64)>=db.prepare_cached("SELECT x.id,x.pose,h.file_key,p.identity,h.expires FROM physique_holds h JOIN physique_media x ON x.id=h.media_id JOIN physique_participants p ON p.match_id=x.match_id AND p.slot=x.slot WHERE h.case_id=? AND h.expires>?")?.query_map(params![id,time],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?)))?.collect::<rusqlite::Result<_>>()?;
        let mut items=Vec::new();
        for(id,pose,key,label,expires)in rows{let label:Identity=serde_json::from_str(&label)?;items.push(Media{id,owner_id:label.id,pose,status:"restrictedCaseEvidence".into(),image_base64:Some(STANDARD.encode(judge::read_media(&settings,&key)?)),expires_at:Some(expires)});}
        Ok(Items{items})
    }).await.map(Json)
}

#[cfg(test)]
mod http_tests;
#[cfg(test)]
mod tests;
