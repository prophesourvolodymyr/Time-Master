use crate::{
    cloud::{
        Supabase,
        tests::{NOW, OWNER_A, OWNER_B, Service},
    },
    model::Registration,
    rules::{Tracker, Variation},
    store,
};
use rusqlite::params;
use serde_json::json;
use std::sync::atomic::Ordering;

const PASSWORD: &str = "proven-private-legacy-password";

struct Legacy {
    uid: String,
    public: String,
    access: String,
}

async fn legacy(service: &Service, login: &str) -> Legacy {
    let hashed = service.state.passwords.hash(PASSWORD.into()).await.unwrap();
    let login = login.to_owned();
    service
        .state
        .db
        .call(move |db| {
            let grant = store::register(
                db,
                Registration {
                    login: login.clone(),
                    password: PASSWORD.into(),
                    display_name: format!("Preserved {login}"),
                    listed: true,
                },
                &hashed,
                NOW - 10.0,
            )?;
            let (uid, public): (String, String) = db.query_row(
                "SELECT id,public_id FROM accounts WHERE login=?",
                [login],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )?;
            db.execute(
                "INSERT INTO ratings VALUES (?,'standardPushUp',1337,7,'elo-1')",
                [&uid],
            )?;
            Ok(Legacy {
                uid,
                public,
                access: grant.access_token,
            })
        })
        .await
        .unwrap()
}

async fn seed_file(service: &Service, token: &str, bytes: &[u8]) -> String {
    let hash = service.chunk(token, bytes).await;
    service.json("POST", "/v1/sync/commit", token, Some(json!({"deviceID": "b14d8229-d95c-4297-a76c-20bb50bcb188", "mutations": [{"path": "Exercises Database/Private/cover.jpg", "baseRevision": 0, "hash": hash, "size": bytes.len(), "chunks": [hash], "deleted": false}]}))).await.expect(200);
    hash
}

#[tokio::test]
async fn legacy_links_require_credentials_preserve_both_accounts_and_never_merge_by_identity() {
    let service = Service::new().await;
    let old_a = legacy(&service, "existing-athlete-a").await;
    let old_b = legacy(&service, "existing-athlete-b").await;
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
    service.json("POST", "/v1/account/link-ranked", &service.a, Some(json!({"login": "existing-athlete-a", "password": "wrong-password-that-is-long-enough"}))).await.expect(401);
    let linked = service
        .json(
            "POST",
            "/v1/account/link-ranked",
            &service.a,
            Some(json!({"login": "existing-athlete-a", "password": PASSWORD})),
        )
        .await
        .expect(200);
    assert_eq!(linked["identity"]["publicID"], old_a.public);
    assert_eq!(
        linked["identity"]["displayName"],
        "Preserved existing-athlete-a"
    );
    assert_eq!(linked["identity"]["listed"], true);
    assert_eq!(linked["ratings"][0]["rating"], 1337);
    assert_eq!(linked["ratings"][0]["games"], 7);
    service
        .json("GET", "/v1/me", &old_a.access, None)
        .await
        .expect(401);
    service
        .json(
            "POST",
            "/v1/account/link-ranked",
            &service.b,
            Some(json!({"login": "existing-athlete-a", "password": PASSWORD})),
        )
        .await
        .expect(409);
    service
        .json(
            "POST",
            "/v1/account/link-ranked",
            &service.a,
            Some(json!({"login": "existing-athlete-b", "password": PASSWORD})),
        )
        .await
        .expect(409);
    let linked_b = service
        .json(
            "POST",
            "/v1/account/link-ranked",
            &service.b,
            Some(json!({"login": "existing-athlete-b", "password": PASSWORD})),
        )
        .await
        .expect(200);
    assert_eq!(linked_b["identity"]["publicID"], old_b.public);
    assert_eq!(linked_b["ratings"][0]["rating"], 1337);
    let expected_a = old_a.uid;
    let expected_b = old_b.uid;
    let mapping: (String, String) = service
        .state
        .db
        .call(move |db| {
            Ok((
                db.query_row(
                    "SELECT ranked_user_id FROM cloud_accounts WHERE subject=?",
                    [OWNER_A],
                    |row| row.get(0),
                )?,
                db.query_row(
                    "SELECT ranked_user_id FROM cloud_accounts WHERE subject=?",
                    [OWNER_B],
                    |row| row.get(0),
                )?,
            ))
        })
        .await
        .unwrap();
    assert_eq!(mapping, (expected_a, expected_b));
    service
        .json(
            "POST",
            "/v1/me/privacy",
            &service.a,
            Some(json!({"displayName": "Changed only A", "listed": false})),
        )
        .await
        .expect(200);
    let b = service
        .json("GET", "/v1/me", &service.b, None)
        .await
        .expect(200);
    assert_eq!(b["identity"]["displayName"], "Preserved existing-athlete-b");
    assert_eq!(b["identity"]["listed"], true);
}

#[tokio::test]
async fn a_played_new_ranked_profile_is_never_silently_replaced_by_legacy_linking() {
    let service = Service::new().await;
    let old = legacy(&service, "existing-athlete").await;
    let me = service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
    service.json("POST", "/v1/queue", &service.a, Some(json!({"variation": "standardPushUp", "ruleVersion": "pose-1", "requestID": "queue-before-linking-0001"}))).await.expect(200);
    service
        .json(
            "POST",
            "/v1/account/link-ranked",
            &service.a,
            Some(json!({"login": "existing-athlete", "password": PASSWORD})),
        )
        .await
        .expect(409);
    let still = service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
    assert_eq!(still["identity"]["publicID"], me["identity"]["publicID"]);
    let old_uid = old.uid;
    let rating: i64 = service
        .state
        .db
        .call(move |db| {
            Ok(db.query_row(
                "SELECT rating FROM ratings WHERE user_id=?",
                [old_uid],
                |row| row.get(0),
            )?)
        })
        .await
        .unwrap();
    assert_eq!(rating, 1337);
}

#[tokio::test]
async fn deletion_reports_cloud_failures_recovers_after_restart_and_preserves_opponents_history() {
    let mut service = Service::new().await;
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
    service
        .json("GET", "/v1/me", &service.b, None)
        .await
        .expect(200);
    service.state.db.call(|db| {
        let a: String = db.query_row("SELECT ranked_user_id FROM cloud_accounts WHERE subject=?", [OWNER_A], |row| row.get(0))?;
        let b: String = db.query_row("SELECT ranked_user_id FROM cloud_accounts WHERE subject=?", [OWNER_B], |row| row.get(0))?;
        db.execute("INSERT INTO matches(id,variation,rules,state,created,ready_deadline,finalized,reason,winner) VALUES ('shared-history','standardPushUp','pose-1','completed',?,?,?,'Round complete',?)", params![NOW - 600.0, NOW - 590.0, NOW - 530.0, b])?;
        let tracker = serde_json::to_string(&Tracker::new(Variation::StandardPushUp))?;
        for (uid, score, after) in [(&a, 12, 980), (&b, 17, 1020)] {
            db.execute("INSERT INTO participants(match_id,user_id,nonce,last_seen,tracker,score,before_rating,after_rating) VALUES ('shared-history',?,'private-nonce',?,?,?,?,?)", params![uid, NOW - 530.0, tracker, score, 1000, after])?;
            db.execute("INSERT INTO ratings VALUES (?,'standardPushUp',?,1,'elo-1')", params![uid, after])?;
        }
        db.execute("INSERT INTO evidence VALUES ('shared-history',?,1,12,'receipt-digest','private-pose-frames',?)", params![a, NOW - 550.0])?;
        Ok(())
    }).await.unwrap();
    let a_hash = seed_file(&service, &service.a, b"owner A cover").await;
    let b_hash = seed_file(&service, &service.b, b"owner B different cover").await;
    service.upstream.fail_storage.store(true, Ordering::SeqCst);
    service
        .json("DELETE", "/v1/account", &service.a, None)
        .await
        .expect(502);
    assert!(!service.upstream.deleted.lock().contains(OWNER_A));
    assert!(
        service
            .upstream
            .objects
            .lock()
            .contains_key(&Supabase::object_name(OWNER_A, &a_hash))
    );
    service.upstream.fail_storage.store(false, Ordering::SeqCst);
    service.upstream.fail_auth.store(true, Ordering::SeqCst);
    service
        .json("DELETE", "/v1/account", &service.a, None)
        .await
        .expect(502);
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(410);
    service
        .json("GET", "/v1/sync/manifest", &service.a, None)
        .await
        .expect(410);
    assert!(!service.upstream.deleted.lock().contains(OWNER_A));
    assert!(
        !service
            .upstream
            .objects
            .lock()
            .contains_key(&Supabase::object_name(OWNER_A, &a_hash))
    );
    assert!(
        service
            .upstream
            .objects
            .lock()
            .contains_key(&Supabase::object_name(OWNER_B, &b_hash))
    );
    service.reopen().await;
    service.upstream.fail_auth.store(false, Ordering::SeqCst);
    service.state.recover_deletions().await.unwrap();
    assert!(service.upstream.deleted.lock().contains(OWNER_A));
    service
        .json("DELETE", "/v1/account", &service.a, None)
        .await
        .expect(200);
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(410);
    let b = service
        .json("GET", "/v1/me", &service.b, None)
        .await
        .expect(200);
    assert_eq!(b["ratings"][0]["rating"], 1020);
    assert_eq!(b["ratings"][0]["games"], 1);
    let manifest = service
        .json("GET", "/v1/sync/manifest", &service.b, None)
        .await
        .expect(200);
    assert_eq!(manifest["files"][0]["hash"], b_hash);
    let history = service
        .json("GET", "/v1/history", &service.b, None)
        .await
        .expect(200);
    let participants = history["matches"][0]["participants"].as_array().unwrap();
    let deleted = participants
        .iter()
        .find(|participant| participant["isYou"] == false)
        .unwrap();
    assert_eq!(deleted["displayName"], "Deleted athlete");
    assert_eq!(deleted["score"], 12.0);
    let me = participants
        .iter()
        .find(|participant| participant["isYou"] == true)
        .unwrap();
    assert_eq!(me["score"], 17.0);
    let (files, frames, violations): (i64, i64, usize) = service
        .state
        .db
        .call(|db| {
            let files = db.query_row(
                "SELECT count(*) FROM sync_files WHERE owner=?",
                [OWNER_A],
                |row| row.get(0),
            )?;
            let frames = db.query_row("SELECT count(*) FROM evidence", [], |row| row.get(0))?;
            let violations = db
                .prepare("PRAGMA foreign_key_check")?
                .query_map([], |_| Ok(()))?
                .collect::<rusqlite::Result<Vec<_>>>()?
                .len();
            Ok((files, frames, violations))
        })
        .await
        .unwrap();
    assert_eq!((files, frames, violations), (0, 0, 0));
}

#[tokio::test]
async fn legacy_credential_proofs_are_throttled_across_changing_login_names() {
    let service = Service::new().await;
    for attempt in 0..11 {
        service
            .json(
                "POST",
                "/v1/account/link-ranked",
                &service.a,
                Some(json!({
                    "login": format!("unknown-athlete-{attempt}"), "password": PASSWORD,
                })),
            )
            .await
            .expect(if attempt < 10 { 401 } else { 429 });
    }
    service
        .json("GET", "/v1/me", &service.a, None)
        .await
        .expect(200);
}

#[tokio::test]
async fn managed_logout_cancels_ranked_and_reports_remote_revocation_failures() {
    let service = Service::new().await;
    service.json("POST", "/v1/queue", &service.a, Some(json!({
        "variation": "standardPushUp", "ruleVersion": "pose-1", "requestID": "queued-before-signout-0001",
    }))).await.expect(200);
    service.upstream.fail_auth.store(true, Ordering::SeqCst);
    service
        .json("POST", "/v1/auth/logout", &service.a, None)
        .await
        .expect(502);
    let state = service
        .json("GET", "/v1/state", &service.a, None)
        .await
        .expect(200);
    assert_eq!(state["queue"], serde_json::Value::Null);
    service.upstream.fail_auth.store(false, Ordering::SeqCst);
    service
        .json("POST", "/v1/auth/logout", &service.a, None)
        .await
        .expect(200);
}
