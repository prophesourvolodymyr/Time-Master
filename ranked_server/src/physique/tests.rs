use super::*;
use crate::model::Validate;
use serde_json::json;

fn database() -> Connection {
    let db = Connection::open_in_memory().unwrap();
    db.execute_batch(include_str!("../../schema.sql")).unwrap();
    for (uid, public) in [("a", "public-a"), ("b", "public-b"), ("c", "public-c")] {
        db.execute(
            "INSERT INTO accounts VALUES (?,?,?,?,?,0,0)",
            params![uid, public, uid, "", "Exercise athlete"],
        )
        .unwrap();
        comp::ensure(&db, uid).unwrap();
        cases::update_consent(
            &db,
            uid,
            &Consent {
                adult: true,
                adult_man: false,
                rules_accepted: true,
                ai_processing: true,
                opponent_sharing: true,
                policy_version: "test-policy".into(),
            },
            0.0,
        )
        .unwrap();
    }
    db
}
pub(super) fn settings() -> Settings {
    let mut settings = Settings::from_env();
    settings.policy = Policy {
        version: "test-policy".into(),
        operator_name: "Test operator".into(),
        processor: "Test processor".into(),
        region: "Test region".into(),
        retention: "Test retention disclosure".into(),
        judge_version: "test-judge".into(),
        support_url: Some("https://example.test/support".into()),
        ready: true,
        unavailable_reason: None,
    };
    settings.key = "test-policy-key".into();
    settings.intake_ready = true;
    settings.media_root = None;
    settings
}
fn command(operation: &str, id: u8) -> Command {
    serde_json::from_value(
        json!({"operation":operation,"requestID":format!("00000000-0000-4000-8000-{id:012}")}),
    )
    .unwrap()
}
fn scores(value: i64) -> Scores {
    Scores {
        muscularity: value,
        definition: value,
        symmetry: value,
        presentation: value,
        total: value as f64,
    }
}
fn verdict(a: i64, b: i64) -> judge::Verdict {
    judge::Verdict {
        a: scores(a),
        b: scores(b),
        evidence_adequate: true,
        winner: if (a - b).abs() < 3 {
            "draw"
        } else if a > b {
            "A"
        } else {
            "B"
        }
        .into(),
        explanation:
            "The accepted common-region category evidence supports these rubric-relative totals."
                .into(),
        provider_model: "test-provider-model".into(),
    }
}
fn started(db: &Connection, settings: &Settings, time: f64) -> String {
    comp::start_search(db, "a", settings, time).unwrap();
    comp::start_search(db, "b", settings, time).unwrap();
    let mid = comp::active(db, "a").unwrap().unwrap();
    comp::ready(db, "a", &mid, true, settings, time).unwrap();
    comp::ready(db, "b", &mid, true, settings, time).unwrap();
    comp::sweep(db, settings, time + 3.0).unwrap();
    mid
}
pub(super) fn judged(db: &Connection, settings: &Settings, time: f64, a: i64, b: i64) -> String {
    let mid = started(db, settings, time);
    db.execute(
        "UPDATE physique_participants SET submitted=1 WHERE match_id=?",
        [&mid],
    )
    .unwrap();
    db.execute("UPDATE physique_matches SET stage='judging',judging_started=?,judging_deadline=? WHERE id=?",params![time+4.0,time+34.0,mid]).unwrap();
    for slot in ["a", "b"] {
        for pose in comp::POSES {
            db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,created,expires) VALUES (?,?,?,?,1,'accepted',?,?)",params![auth::identifier().unwrap(),mid,slot,pose,time,time+86400.0]).unwrap();
        }
    }
    let verdict = verdict(a, b);
    let winner = match verdict.winner.as_str() {
        "A" => Some("a"),
        "B" => Some("b"),
        _ => None,
    };
    comp::finalize(db, &mid, winner, false, Some(&verdict), time + 5.0).unwrap();
    mid
}
#[test]
fn strict_wire_contract_and_exact_draw_boundary() {
    let mut request = command("reply", 1);
    request.target_id = Some("case".into());
    request.expected_revision = Some(1.0);
    request.validate().unwrap();
    let json = serde_json::to_value(&request).unwrap();
    assert!(json.get("requestID").is_some());
    assert!(json.get("targetID").is_some());
    assert_eq!(json["expectedRevision"], 1.0);
    let db = database();
    let settings = settings();
    let policy = serde_json::to_value(&settings.policy).unwrap();
    assert!(policy.get("supportURL").is_some());
    assert!(policy.get("supportUrl").is_none());
    let reply = response(
        &db,
        "a",
        &settings,
        Some("canonical-receipt".into()),
        None,
        100.0,
    )
    .unwrap();
    let reply = serde_json::to_value(reply).unwrap();
    assert_eq!(reply["receiptID"], "canonical-receipt");
    assert!(reply.get("receiptId").is_none());
    assert!(serde_json::from_value::<Command>(json!({"operation":"enqueue","requestID":"00000000-0000-4000-8000-000000000001","rating":5000})).is_err());
    let mut close = verdict(53, 50);
    close.winner = "draw".into();
    assert!(close.validate().is_err());
    let exact = Scores {
        muscularity: 53,
        definition: 50,
        symmetry: 50,
        presentation: 50,
        total: 51.2,
    };
    assert!(exact.validate().is_ok());
    let mut malformed = exact;
    malformed.total = 51.21;
    assert!(malformed.validate().is_err());
    assert_eq!(comp::rating_after(1000, 1000, 40, 1.0), 1020);
    assert_eq!(comp::rating_after(1000, 1000, 40, 0.0), 980);
    assert_eq!(comp::rating_after(1000, 1000, 24, 1.0), 1012);
    assert_eq!(comp::rating_after(5000, 5000, 40, 1.0), 5000);
    assert!(judge::decode_image("not an image").is_err());
}
#[test]
fn queue_outcome_is_persistent_without_a_fake_match() {
    let db = database();
    let settings = settings();
    comp::start_search(&db, "a", &settings, 100.0).unwrap();
    comp::sweep(&db, &settings, 190.0).unwrap();
    let snapshot = comp::snapshot(&db, "a", &settings, 190.0).unwrap();
    assert_eq!(snapshot.queue_outcome.as_deref(), Some("noOpponent"));
    assert!(snapshot.r#match.is_none());
    assert_eq!(snapshot.account.allowance.remaining, 10);
    comp::start_search(&db, "a", &settings, 191.0).unwrap();
    assert!(
        comp::snapshot(&db, "a", &settings, 191.0)
            .unwrap()
            .queue_outcome
            .is_none()
    );
}
#[test]
fn pairing_respects_both_skill_windows_and_mutual_blocks() {
    let db = database();
    let settings = settings();
    db.execute(
        "UPDATE physique_profiles SET rating=1150 WHERE user_id='b'",
        [],
    )
    .unwrap();
    comp::start_search(&db, "a", &settings, 100.0).unwrap();
    comp::start_search(&db, "b", &settings, 120.0).unwrap();
    comp::touch(&db, "a", None, 131.0).unwrap();
    comp::touch(&db, "b", None, 131.0).unwrap();
    comp::pair(&db, &settings, 131.0).unwrap();
    assert!(comp::active(&db, "a").unwrap().is_none());
    comp::touch(&db, "a", None, 151.0).unwrap();
    comp::touch(&db, "b", None, 151.0).unwrap();
    db.execute("INSERT INTO physique_blocks VALUES ('b','a',151)", [])
        .unwrap();
    comp::pair(&db, &settings, 151.0).unwrap();
    assert!(comp::active(&db, "a").unwrap().is_none());
    db.execute("DELETE FROM physique_blocks", []).unwrap();
    comp::pair(&db, &settings, 151.0).unwrap();
    assert!(comp::active(&db, "a").unwrap().is_some());
}
#[test]
fn readiness_withdrawal_and_late_cancel_never_become_implicit_forfeit() {
    let db = database();
    let settings = settings();
    comp::start_search(&db, "a", &settings, 100.0).unwrap();
    comp::start_search(&db, "b", &settings, 100.0).unwrap();
    let mid = comp::active(&db, "a").unwrap().unwrap();
    comp::ready(&db, "a", &mid, true, &settings, 100.0).unwrap();
    comp::ready(&db, "b", &mid, true, &settings, 100.0).unwrap();
    comp::ready(&db, "a", &mid, false, &settings, 101.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "ready");
    assert_eq!(
        db.query_row("SELECT count(*) FROM physique_starts", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    comp::ready(&db, "a", &mid, true, &settings, 102.0).unwrap();
    comp::sweep(&db, &settings, 105.0).unwrap();
    assert!(comp::cancel(&db, "a", 105.0).is_err());
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "capture");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
    assert_eq!(comp::allowance(&db, "a", 105.0).unwrap().remaining, 9);
}
#[test]
fn finalization_and_allowance_restoration_are_exactly_once() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    comp::finish_unscored(&db, &mid, "noContest", "Unavailable", 104.0).unwrap();
    comp::finish_unscored(&db, &mid, "noContest", "Late duplicate", 105.0).unwrap();
    comp::finalize(&db, &mid, Some("a"), false, Some(&verdict(60, 50)), 106.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "noContest");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
    assert_eq!(comp::allowance(&db, "a", 106.0).unwrap().remaining, 10);
    let valid = judged(&db, &settings, 120.0, 60, 50);
    comp::finalize(&db, &valid, Some("a"), false, Some(&verdict(60, 50)), 126.0).unwrap();
    let record = comp::summary(&db, "a").unwrap().record;
    assert_eq!(
        (record.games, record.wins, record.rating, record.best),
        (1, 1, Some(1020), Some(1020))
    );
    assert_eq!(
        db.query_row(
            "SELECT count(*) FROM physique_rating_events WHERE match_id=?",
            [valid],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        2
    );
}
#[test]
fn forfeit_is_rated_but_never_a_judged_badge_or_score() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    comp::leave(&db, "b", &mid, "forfeit", &settings, 104.0).unwrap();
    comp::leave(&db, "a", &mid, "forfeit", &settings, 105.0).unwrap();
    let summary = comp::summary(&db, "a").unwrap();
    assert_eq!(summary.record.wins, 1);
    assert!(!summary.badges.iter().any(|b| b.id == "firstBell"));
    let view = comp::match_view(&db, "a", &mid, 105.0).unwrap();
    let result = view.result.unwrap();
    assert_eq!(result.outcome, "forfeitWin");
    assert!(result.you.is_none());
    assert!(!view.gallery_available);
}
#[test]
fn request_identity_binds_exact_payload_and_never_reapplies_completed_work() {
    let db = database();
    let request = command("listing", 1);
    record(
        &db,
        "a",
        &request,
        "complete",
        Some("receipt"),
        Some("saved"),
        100.0,
    )
    .unwrap();
    assert_eq!(
        prior(&db, "a", &request).unwrap().unwrap().0.as_deref(),
        Some("receipt")
    );
    let mut changed = request.clone();
    changed.value = Some(true);
    assert!(prior(&db, "a", &changed).is_err());
    assert!(prior(&db, "b", &request).unwrap().is_none());
    let revision = cases::consent_revision(&db, "a").unwrap();
    let mut choices = comp::consent(&db, "a").unwrap();
    choices.ai_processing = false;
    cases::update_consent(&db, "a", &choices, 100.0).unwrap();
    assert!(cases::consent_revision(&db, "a").unwrap() > revision);
    assert!(!comp::consent(&db, "a").unwrap().ai_processing);
}
#[test]
fn private_intake_is_isolated_deduplicated_and_revision_bound() {
    let db = database();
    let settings = settings();
    let mid = judged(&db, &settings, 100.0, 60, 50);
    let mut request = command("report", 1);
    request.target_id = Some(mid.clone());
    request.match_id = Some(mid);
    request.reason = Some("unsafeAI".into());
    request.text = Some("Please review the explanation".into());
    let (id, _) = cases::report(&db, "a", &request, &settings, 106.0).unwrap();
    let (second, _) = cases::report(&db, "a", &request, &settings, 107.0).unwrap();
    assert_eq!(id, second);
    assert!(cases::get(&db, "b", &id).is_err());
    db.execute(
        "UPDATE physique_cases SET status='needsReply',needs_reply=1,updated=108 WHERE id=?",
        [&id],
    )
    .unwrap();
    let mut reply = command("reply", 2);
    reply.target_id = Some(id.clone());
    reply.text = Some("Safe further context".into());
    reply.expected_revision = Some(107.0);
    assert!(cases::reply(&db, "a", &reply, 109.0).is_err());
    reply.expected_revision = Some(108.0);
    cases::reply(&db, "a", &reply, 109.0).unwrap();
    assert!(!cases::get(&db, "a", &id).unwrap().needs_reply);
}
#[test]
fn sharing_withdrawal_is_not_ai_withdrawal_or_a_forfeit() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    let request = command("withdrawSharing", 1);
    cases::privacy_action(&db, "a", &request, &settings, 104.0).unwrap();
    let consent = comp::consent(&db, "a").unwrap();
    assert!(consent.ai_processing);
    assert!(!consent.opponent_sharing);
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "capture");
    cases::privacy_action(&db, "a", &command("withdrawAI", 2), &settings, 105.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "noContest");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
}
#[test]
fn correction_keeps_original_receipt_and_later_settlements_unchanged() {
    let db = database();
    let settings = settings();
    let first = judged(&db, &settings, 100.0, 60, 50);
    let later = judged(&db, &settings, 120.0, 60, 50);
    let before = comp::match_view(&db, "a", &later, 126.0)
        .unwrap()
        .result
        .unwrap()
        .rating
        .unwrap();
    let current = comp::summary(&db, "a").unwrap().record.rating.unwrap();
    let mut review = command("review", 1);
    review.target_id = Some(first.clone());
    review.reason = Some("dispute:evidence".into());
    let (case, _) = cases::review(&db, "a", &review, &settings, 127.0).unwrap();
    let claim = admin::StaffCommand {
        request_id: "00000000-0000-4000-8000-000000000010".into(),
        operation: "claim".into(),
        case_id: case.clone(),
        status: None,
        text: None,
        reason: None,
        until: None,
        correction: None,
    };
    admin::command(&db, "reviewer", &claim, &settings, 128.0).unwrap();
    let correction = admin::StaffCommand {
        request_id: "00000000-0000-4000-8000-000000000011".into(),
        operation: "correct".into(),
        case_id: case,
        status: None,
        text: None,
        reason: Some("Original accepted evidence was confirmed invalid".into()),
        until: None,
        correction: Some("noContest".into()),
    };
    admin::command(&db, "reviewer", &correction, &settings, 129.0).unwrap();
    admin::command(&db, "reviewer", &correction, &settings, 130.0).unwrap();
    let result = comp::match_view(&db, "a", &first, 130.0)
        .unwrap()
        .result
        .unwrap();
    assert_eq!(result.outcome, "noContest");
    assert_eq!(result.rating.as_ref().unwrap().change, 20);
    assert!(result.you.is_none());
    let audit = result.correction.unwrap();
    assert_eq!(
        (audit.original_change, audit.adjustment, audit.after),
        (20, -20, current - 20)
    );
    let after = comp::match_view(&db, "a", &later, 130.0)
        .unwrap()
        .result
        .unwrap()
        .rating
        .unwrap();
    assert_eq!(
        (before.before, before.change, before.after),
        (after.before, after.change, after.after)
    );
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 1);
}
#[test]
fn page_cursors_are_private_stable_and_expire_honestly() {
    let db = database();
    let settings = settings();
    for index in 0..21 {
        judged(&db, &settings, 100.0 + index as f64 * 15000.0, 50, 50);
    }
    let page = pages::history(&db, "a", None, 400000.0).unwrap();
    assert_eq!(page.items.len(), 20);
    let cursor = page.cursor.unwrap();
    assert!(pages::history(&db, "b", Some(&cursor), 400001.0).is_err());
    assert_eq!(
        pages::history(&db, "a", Some(&cursor), 400001.0)
            .unwrap()
            .items
            .len(),
        1
    );
    assert!(pages::history(&db, "a", Some(&cursor), 400901.0).is_err());
}
#[test]
fn global_deletion_revokes_physique_identity_and_retains_only_safe_counterpart_facts() {
    let db = database();
    let settings = settings();
    let mid = judged(&db, &settings, 100.0, 60, 50);
    cases::begin_deletion(&db, "a", 106.0).unwrap();
    cases::finish_deletion(&db, "a", &settings, 107.0).unwrap();
    assert!(comp::require_member(&db, "a", &mid).is_err());
    let view = comp::match_view(&db, "b", &mid, 108.0).unwrap();
    assert_eq!(view.opponent.identity.display_name, "Unavailable player");
    assert!(view.opponent.identity.id.is_empty());
    assert_eq!(view.result.unwrap().outcome, "loss");
    assert!(comp::identity_and_record(&db, "a").is_err());
}
#[test]
fn rejected_capture_has_a_real_private_appealable_notice() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,reason,created,expires) VALUES ('rejected-pose',?,'a','front',1,'rejected','Coverage unclear',104,86504)",[&mid]).unwrap();
    cases::rejection_notice(&db, "a", &mid, "rejected-pose", "Coverage unclear", 104.0).unwrap();
    let evidence = comp::match_view(&db, "a", &mid, 104.0)
        .unwrap()
        .evidence
        .remove(0);
    let case = evidence.appeal_case_id.unwrap();
    assert!(cases::get(&db, "a", &case).unwrap().can_appeal);
    assert!(cases::get(&db, "b", &case).is_err());
    let mut request = command("review", 1);
    request.target_id = Some(case.clone());
    request.match_id = Some(mid);
    request.reason = Some("appeal:coverage".into());
    let (appeal, _) = cases::review(&db, "a", &request, &settings, 105.0).unwrap();
    assert_eq!(cases::get(&db, "a", &appeal).unwrap().kind, "appeal");
    assert!(!cases::get(&db, "a", &case).unwrap().can_appeal);
}
#[test]
fn account_linking_cannot_delete_an_existing_physique_identity() {
    let db = database();
    db.execute("INSERT INTO cloud_accounts VALUES ('owner','a',0,0,0)", [])
        .unwrap();
    let subject = crate::cloud::Subject {
        id: "owner".into(),
        display_name: "Account holder".into(),
    };
    let error = crate::account::link(&db, &subject, "b", 100.0)
        .err()
        .expect("An existing Physique identity cannot be overwritten by linking");
    assert_eq!(error.status, StatusCode::CONFLICT);
    assert!(comp::identity_and_record(&db, "a").is_ok());
}
#[test]
fn multiple_case_tombstones_never_collide_during_retention_or_account_deletion() {
    let db = database();
    let settings = settings();
    let mid = judged(&db, &settings, 100.0, 60, 50);
    for (id, operation, target, reason) in [
        (1, "report", mid.clone(), "unsafeAI"),
        (2, "review", mid.clone(), "dispute:evidence"),
    ] {
        let mut request = command(operation, id);
        request.target_id = Some(target);
        request.match_id = Some(mid.clone());
        request.reason = Some(reason.into());
        if operation == "report" {
            cases::report(&db, "a", &request, &settings, 106.0).unwrap();
        } else {
            cases::review(&db, "a", &request, &settings, 107.0).unwrap();
        }
    }
    let mut player = command("report", 3);
    player.target_id = Some("public-b".into());
    player.reason = Some("harassment".into());
    cases::report(&db, "a", &player, &settings, 108.0).unwrap();
    db.execute("UPDATE physique_cases SET closed=109 WHERE owner='a'", [])
        .unwrap();
    cases::cleanup(&db, &settings, 109.0 + 91.0 * 86400.0).unwrap();
    let targets: Vec<String> = db
        .prepare("SELECT target FROM physique_cases WHERE owner='a'")
        .unwrap()
        .query_map([], |r| r.get(0))
        .unwrap()
        .collect::<rusqlite::Result<_>>()
        .unwrap();
    assert_eq!(targets.len(), 3);
    assert_eq!(
        targets
            .iter()
            .collect::<std::collections::HashSet<_>>()
            .len(),
        3
    );
    assert!(targets.iter().all(|t| t.starts_with("redacted:")));
    cases::begin_deletion(&db, "a", 110.0 + 91.0 * 86400.0).unwrap();
    cases::finish_deletion(&db, "a", &settings, 111.0 + 91.0 * 86400.0).unwrap();
}
#[test]
fn bare_report_cannot_void_a_match_but_authorized_safety_removal_prevents_late_rating() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,created,expires) VALUES ('unsafe-pose',?,'b','front',1,'accepted',104,86504)",[&mid]).unwrap();
    db.execute(
        "UPDATE physique_participants SET submitted=1 WHERE match_id=?",
        [&mid],
    )
    .unwrap();
    db.execute("UPDATE physique_matches SET stage='judging',judging_started=104,judging_deadline=134,judge_claimed=1 WHERE id=?",[&mid]).unwrap();
    let mut report = command("report", 1);
    report.target_id = Some("unsafe-pose".into());
    report.match_id = Some(mid.clone());
    report.reason = Some("sexual".into());
    let (case, _) = cases::report(&db, "a", &report, &settings, 105.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "judging");
    assert_eq!(
        db.query_row(
            "SELECT status FROM physique_media WHERE id='unsafe-pose'",
            [],
            |r| r.get::<_, String>(0)
        )
        .unwrap(),
        "accepted"
    );
    let claim = admin::StaffCommand {
        request_id: "00000000-0000-4000-8000-000000000010".into(),
        operation: "claim".into(),
        case_id: case.clone(),
        status: None,
        text: None,
        reason: None,
        until: None,
        correction: None,
    };
    admin::command(&db, "reviewer", &claim, &settings, 105.5).unwrap();
    let removal = admin::StaffCommand {
        request_id: "00000000-0000-4000-8000-000000000011".into(),
        operation: "removeMedia".into(),
        case_id: case,
        status: None,
        text: None,
        reason: Some("Confirmed unsafe evidence".into()),
        until: None,
        correction: None,
    };
    admin::command(&db, "reviewer", &removal, &settings, 106.0).unwrap();
    comp::finalize(&db, &mid, Some("a"), false, Some(&verdict(60, 50)), 106.5).unwrap();
    comp::leave(&db, "b", &mid, "forfeit", &settings, 107.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "noContest");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
    assert_eq!(comp::allowance(&db, "a", 107.0).unwrap().remaining, 10);
}
#[test]
fn finalization_rechecks_removed_evidence_even_without_a_prior_abort() {
    let db = database();
    let settings = settings();
    let mid = started(&db, &settings, 100.0);
    db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,created,expires) VALUES ('removed-pose',?,'a','front',1,'removed',104,86504)",[&mid]).unwrap();
    comp::leave(&db, "a", &mid, "forfeit", &settings, 105.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "noContest");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
}
#[test]
fn image_removal_receipt_finishes_when_its_original_evidence_hold_expires() {
    let directory = tempfile::TempDir::new().unwrap();
    let db = database();
    let mut settings = settings();
    settings.media_root = Some(directory.path().to_owned());
    let mid = judged(&db, &settings, 100.0, 60, 50);
    let image: String = db
        .query_row(
            "SELECT id FROM physique_media WHERE match_id=? AND slot='a' AND pose='front'",
            [&mid],
            |r| r.get(0),
        )
        .unwrap();
    let key = judge::write_media(&settings, b"protected test evidence").unwrap();
    db.execute(
        "UPDATE physique_media SET file_key=? WHERE id=?",
        params![key, image],
    )
    .unwrap();
    let mut report = command("report", 1);
    report.target_id = Some(image);
    report.match_id = Some(mid.clone());
    report.reason = Some("other".into());
    cases::report(&db, "a", &report, &settings, 106.0).unwrap();
    let mut removal = command("removeImages", 2);
    removal.match_id = Some(mid);
    let (receipt, _) = cases::privacy_action(&db, "a", &removal, &settings, 107.0).unwrap();
    assert_eq!(
        cases::privacy_list(&db, "a")
            .unwrap()
            .into_iter()
            .find(|r| r.id == receipt)
            .unwrap()
            .status,
        "partiallyHeld"
    );
    assert!(judge::media_path(&settings, &key).unwrap().exists());
    cases::cleanup(&db, &settings, 107.0 + 30.0 * 86400.0).unwrap();
    let receipt = cases::privacy_list(&db, "a")
        .unwrap()
        .into_iter()
        .find(|r| r.id == receipt)
        .unwrap();
    assert_eq!(receipt.status, "completed");
    assert!(receipt.retained_reason.is_none());
    assert!(!judge::media_path(&settings, &key).unwrap().exists());
}
#[test]
fn logout_cancels_only_queue_and_pre_go_while_submitted_judging_can_finish_offline() {
    let db = database();
    let settings = settings();
    comp::start_search(&db, "a", &settings, 100.0).unwrap();
    signed_out(&db, "a", 101.0).unwrap();
    assert!(
        comp::snapshot(&db, "a", &settings, 101.0)
            .unwrap()
            .queue_started_at
            .is_none()
    );
    comp::start_search(&db, "a", &settings, 102.0).unwrap();
    comp::start_search(&db, "b", &settings, 102.0).unwrap();
    let preparation = comp::active(&db, "a").unwrap().unwrap();
    comp::ready(&db, "a", &preparation, true, &settings, 102.0).unwrap();
    comp::ready(&db, "b", &preparation, true, &settings, 102.0).unwrap();
    assert!(
        pages::history(&db, "a", None, 103.0)
            .unwrap()
            .items
            .is_empty()
    );
    signed_out(&db, "a", 103.0).unwrap();
    assert_eq!(
        comp::stored_match(&db, &preparation).unwrap().stage,
        "cancelled"
    );
    assert!(
        pages::history(&db, "a", None, 104.0)
            .unwrap()
            .items
            .is_empty()
    );
    assert_eq!(comp::allowance(&db, "a", 104.0).unwrap().remaining, 10);
    let mid = started(&db, &settings, 120.0);
    signed_out(&db, "a", 124.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "capture");
    assert_eq!(comp::summary(&db, "a").unwrap().record.games, 0);
    db.execute(
        "UPDATE physique_participants SET submitted=1 WHERE match_id=?",
        [&mid],
    )
    .unwrap();
    db.execute("UPDATE physique_matches SET stage='judging',judging_started=125,judging_deadline=155 WHERE id=?",[&mid]).unwrap();
    for slot in ["a", "b"] {
        for pose in comp::POSES {
            db.execute("INSERT INTO physique_media(id,match_id,slot,pose,attempts,status,created,expires) VALUES (?,?,?,?,1,'accepted',125,86525)",params![auth::identifier().unwrap(),mid,slot,pose]).unwrap();
        }
    }
    signed_out(&db, "a", 126.0).unwrap();
    assert_eq!(comp::stored_match(&db, &mid).unwrap().stage, "judging");
    comp::finalize(&db, &mid, Some("a"), false, Some(&verdict(60, 50)), 127.0).unwrap();
    assert_eq!(comp::summary(&db, "a").unwrap().record.wins, 1);
}
