use crate::rules::{Pose, Tracker, Variation, assess, elo};
use crate::{AppState, Clock, Config, router};
use axum::{
    Router,
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use rusqlite::params;
use serde_json::{Value, json};
use std::{
    collections::HashSet,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
};
use tempfile::TempDir;
use tower::ServiceExt;

const PASSWORD: &str = "correct-horse-battery";
const VERSION: &str = "pose-1";
const INITIAL_TIME: f64 = 1_000_000.0;

struct Reply {
    status: StatusCode,
    body: Value,
    headers: axum::http::HeaderMap,
}

impl Reply {
    fn expect(self, status: u16) -> Value {
        assert_eq!(self.status.as_u16(), status, "{}", self.body);
        self.body
    }
}

async fn send(
    app: Router,
    method: &str,
    path: &str,
    auth: Option<&Value>,
    body: Option<Value>,
) -> Reply {
    let bytes = body
        .map(|value| serde_json::to_vec(&value).unwrap())
        .unwrap_or_default();
    let mut request = Request::builder()
        .method(method)
        .uri(format!("http://ranked.test/v1/{path}"));
    if let Some(auth) = auth {
        request = request.header(
            "authorization",
            format!("Bearer {}", auth["accessToken"].as_str().unwrap()),
        );
    }
    if !bytes.is_empty() {
        request = request.header("content-type", "application/json");
    }
    read_reply(
        app.oneshot(request.body(Body::from(bytes)).unwrap())
            .await
            .unwrap(),
    )
    .await
}

async fn read_reply(response: axum::response::Response) -> Reply {
    let status = response.status();
    let headers = response.headers().clone();
    let bytes = to_bytes(response.into_body(), 1_048_576).await.unwrap();
    let body =
        serde_json::from_slice(&bytes).unwrap_or_else(|_| json!(String::from_utf8_lossy(&bytes)));
    Reply {
        status,
        body,
        headers,
    }
}

struct Service {
    directory: TempDir,
    state: AppState,
    app: Router,
    time: Arc<AtomicU64>,
    a: Value,
    b: Value,
}

impl Service {
    async fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let time = Arc::new(AtomicU64::new(INITIAL_TIME.to_bits()));
        let clock = clock(&time);
        let state = AppState::with_clock(
            Config {
                database: directory.path().join("ranked.sqlite3"),
                require_tls: false,
                trust_proxy: false,
                supabase: None,
            },
            clock,
        )
        .await
        .unwrap();
        let app = router(state.clone());
        let a = register(&app, "athlete-a", "Real public alias A").await;
        let b = register(&app, "athlete-b", "Real public alias B").await;
        Self {
            directory,
            state,
            app,
            time,
            a,
            b,
        }
    }

    fn now(&self) -> f64 {
        f64::from_bits(self.time.load(Ordering::SeqCst))
    }
    fn set(&self, time: f64) {
        self.time.store(time.to_bits(), Ordering::SeqCst);
    }
    fn advance(&self, seconds: f64) {
        self.set(self.now() + seconds);
    }

    async fn get(&self, path: &str, auth: &Value) -> Reply {
        send(self.app.clone(), "GET", path, Some(auth), None).await
    }

    async fn post(&self, path: &str, auth: &Value, body: Option<Value>) -> Reply {
        send(self.app.clone(), "POST", path, Some(auth), body).await
    }

    async fn queue(&self, auth: &Value, variation: &str, id: &str) -> Reply {
        self.post(
            "queue",
            auth,
            Some(json!({"variation": variation, "ruleVersion": VERSION, "requestID": id})),
        )
        .await
    }

    async fn pair(&self, variation: &str) -> Value {
        let unique = format!("request-{}-{}", self.now(), variation);
        self.queue(&self.a, variation, &unique).await.expect(200);
        self.queue(&self.b, variation, &unique).await.expect(200);
        for _ in 0..21 {
            let a = self.get("state", &self.a).await.expect(200);
            if !a["match"].is_null() {
                return a["match"].clone();
            }
            self.get("state", &self.b).await.expect(200);
            self.advance(5.0);
            self.state.tick().await.unwrap();
        }
        panic!("compatible athletes did not match");
    }

    async fn countdown(&self, variation: &str) -> Value {
        let m = self.pair(variation).await;
        let path = format!("matches/{}/ready", m["id"].as_str().unwrap());
        let calibration: Vec<_> = (0..20)
            .map(|i| pose(100.0 + i as f64 / 10.0, false, variation.contains("Squat")))
            .collect();
        let body = json!({"ready": true, "calibration": calibration});
        self.post(&path, &self.a, Some(body.clone()))
            .await
            .expect(200);
        self.post(&path, &self.b, Some(body)).await.expect(200);
        self.get(&match_path(&m), &self.a).await.expect(200)["match"].clone()
    }

    async fn start(&self, variation: &str) -> Value {
        let m = self.countdown(variation).await;
        self.set(m["startAt"].as_f64().unwrap());
        self.state.tick().await.unwrap();
        let started = self.get(&match_path(&m), &self.a).await.expect(200)["match"].clone();
        assert_eq!(started["state"], "live");
        started
    }

    async fn heartbeat(&self, m: &Value) {
        for auth in [&self.a, &self.b] {
            self.get(&match_path(m), auth).await.expect(200);
        }
    }

    async fn reopen(&mut self) {
        let state = AppState::with_clock(
            Config {
                database: self.directory.path().join("ranked.sqlite3"),
                require_tls: false,
                trust_proxy: false,
                supabase: None,
            },
            clock(&self.time),
        )
        .await
        .unwrap();
        self.app = router(state.clone());
        self.state = state;
    }

    async fn uid(&self, auth: &Value) -> String {
        let public = self.get("me", auth).await.expect(200)["identity"]["publicID"]
            .as_str()
            .unwrap()
            .to_owned();
        self.state
            .db
            .call(move |db| {
                Ok(db.query_row(
                    "SELECT id FROM accounts WHERE public_id=?",
                    [public],
                    |row| row.get(0),
                )?)
            })
            .await
            .unwrap()
    }
}

fn clock(time: &Arc<AtomicU64>) -> Clock {
    let time = time.clone();
    Arc::new(move || f64::from_bits(time.load(Ordering::SeqCst)))
}

async fn register(app: &Router, login: &str, alias: &str) -> Value {
    send(
        app.clone(),
        "POST",
        "auth/register",
        None,
        Some(json!({
            "login": login, "password": PASSWORD, "displayName": alias, "listed": true,
        })),
    )
    .await
    .expect(200)
}

fn match_path(m: &Value) -> String {
    format!("matches/{}", m["id"].as_str().unwrap())
}
fn own(m: &Value) -> &Value {
    m["participants"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["isYou"] == true)
        .unwrap()
}
fn evidence(m: &Value, sequence: u64, frames: Vec<Value>) -> Value {
    json!({"nonce": own(m)["nonce"], "ruleVersion": VERSION, "sequence": sequence, "frames": frames})
}
fn pose(time: f64, bottom: bool, squat: bool) -> Value {
    let values: [(&str, f64, f64); 6] = if squat {
        if bottom {
            [
                ("Shoulder", 0.38, 0.65),
                ("Hip", 0.40, 0.35),
                ("Knee", 0.28, 0.37),
                ("Ankle", 0.32, 0.08),
                ("Elbow", 0.35, 0.5),
                ("Wrist", 0.3, 0.45),
            ]
        } else {
            [
                ("Shoulder", 0.32, 0.8),
                ("Hip", 0.32, 0.55),
                ("Knee", 0.32, 0.3),
                ("Ankle", 0.32, 0.08),
                ("Elbow", 0.26, 0.65),
                ("Wrist", 0.26, 0.5),
            ]
        }
    } else if bottom {
        [
            ("Shoulder", 0.25, 0.4),
            ("Elbow", 0.4, 0.4),
            ("Wrist", 0.25, 0.25),
            ("Hip", 0.5, 0.3375),
            ("Knee", 0.68, 0.2925),
            ("Ankle", 0.85, 0.25),
        ]
    } else {
        [
            ("Shoulder", 0.25, 0.55),
            ("Elbow", 0.25, 0.4),
            ("Wrist", 0.25, 0.25),
            ("Hip", 0.5, 0.425),
            ("Knee", 0.68, 0.335),
            ("Ankle", 0.85, 0.25),
        ]
    };
    let mut joints = serde_json::Map::new();
    for side in ["left", "right"] {
        for (name, x, y) in values {
            joints.insert(
                format!("{side}{name}"),
                json!({
                    "x": x + if squat && side == "right" { 0.2 } else { 0.0 },
                    "y": y + if !squat && side == "right" { 0.1 } else { 0.0 }, "confidence": 0.99,
                }),
            );
        }
    }
    joints.insert("nose".into(), json!({"x": if squat {0.4} else {0.15}, "y": if squat { if bottom {0.78} else {0.92} } else if bottom {0.55} else {0.7}, "confidence": 0.99}));
    json!({"time": (time * 10_000.0).round() / 10_000.0, "aspect": 1.0, "people": 1,
        "joints": joints, "light": 0.5, "cameraMoving": false, "diamondContact": null})
}

fn consume(tracker: &mut Tracker, value: Value) {
    tracker
        .consume(&serde_json::from_value::<Pose>(value).unwrap())
        .unwrap();
}
fn calibrated(variation: Variation) -> Tracker {
    let mut tracker = Tracker::new(variation);
    for i in -30..0 {
        consume(
            &mut tracker,
            pose(i as f64 / 10.0, false, variation.as_str().contains("Squat")),
        );
    }
    assert!(tracker.calibrated);
    tracker
}

#[test]
fn stationary_pose_stays_zero_and_complete_cycle_counts_once() {
    let mut tr = calibrated(Variation::StandardPushUp);
    for i in 0..20 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tr.score, 0.0);
    for i in 20..25 {
        consume(&mut tr, pose(i as f64 / 10.0, true, false));
    }
    for i in 25..35 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tr.score, 1.0);
}

#[test]
fn half_rep_at_go_and_repeated_bottom_fragments_do_not_score() {
    let mut tr = calibrated(Variation::StandardPushUp);
    for i in 0..10 {
        consume(&mut tr, pose(i as f64 / 10.0, true, false));
    }
    for i in 10..20 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tr.score, 0.0);
    for i in 20..40 {
        consume(&mut tr, pose(i as f64 / 10.0, i % 2 == 0, false));
    }
    assert_eq!(tr.score, 0.0);
}

#[test]
fn pause_is_continuous_and_tempo_requires_three_second_descent() {
    let mut tr = calibrated(Variation::PausedPushUp);
    for i in 0..5 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    for i in 5..11 {
        consume(&mut tr, pose(i as f64 / 10.0, true, false));
    }
    for i in 11..17 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tr.score, 0.0);
    for i in 17..30 {
        consume(&mut tr, pose(i as f64 / 10.0, true, false));
    }
    for i in 30..35 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tr.score, 1.0);
    let mut tempo = calibrated(Variation::TempoPushUp);
    for i in 0..15 {
        consume(
            &mut tempo,
            pose(i as f64 / 10.0, (5..10).contains(&i), false),
        );
    }
    assert_eq!(tempo.score, 0.0);
}

#[test]
fn hold_preserves_longest_segment_not_sum_and_no_ghost_time() {
    let mut tr = calibrated(Variation::HighPlank);
    for i in 0..51 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert!((tr.score - 5.0).abs() < 1e-8);
    let mut bad = pose(5.1, false, false);
    bad["people"] = json!(0);
    consume(&mut tr, bad);
    for i in 52..102 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    assert!((tr.score - 5.0).abs() < 1e-8);
    consume(&mut tr, pose(20.0, false, false));
    assert!((tr.score - 5.0).abs() < 1e-8);
    assert!(!tr.calibrated);
}

#[test]
fn occlusion_multiple_people_motion_and_deadline_break_scoring() {
    for invalidity in ["people", "confidence", "cameraMoving", "light"] {
        let mut tr = calibrated(Variation::HighPlank);
        for i in 0..20 {
            consume(&mut tr, pose(i as f64 / 10.0, false, false));
        }
        let score = tr.score;
        let mut bad = pose(2.0, false, false);
        match invalidity {
            "people" => bad["people"] = json!(2),
            "confidence" => bad["joints"]["leftAnkle"]["confidence"] = json!(0.1),
            "light" => bad["light"] = json!(0.01),
            _ => bad["cameraMoving"] = json!(true),
        }
        consume(&mut tr, bad);
        consume(&mut tr, pose(2.1, false, false));
        assert_eq!(tr.score, score);
    }
    let mut tr = calibrated(Variation::HighPlank);
    for i in 0..601 {
        consume(&mut tr, pose(i as f64 / 10.0, false, false));
    }
    let score = tr.score;
    consume(&mut tr, pose(60.1, false, false));
    assert_eq!(tr.score, score);
    assert!(score <= 60.0);
}

#[test]
fn asymmetric_depth_does_not_qualify_for_complete_repetitions() {
    let mut partial = pose(0.0, true, false);
    partial["joints"]["rightElbow"] = json!({"x": 0.25, "y": 0.375, "confidence": 0.99});
    assert!(
        !assess(
            &serde_json::from_value(partial).unwrap(),
            Variation::StandardPushUp
        )
        .bottom
    );
    let mut squat = pose(0.0, true, true);
    squat["joints"]["rightKnee"] = json!({"x": 0.6, "y": 0.215, "confidence": 0.99});
    assert!(
        !assess(
            &serde_json::from_value(squat).unwrap(),
            Variation::StandardSquat
        )
        .bottom
    );
}

#[test]
fn exact_stance_and_diamond_hand_evidence() {
    let top: Pose = serde_json::from_value(pose(0.0, false, true)).unwrap();
    let bottom: Pose = serde_json::from_value(pose(0.0, true, true)).unwrap();
    assert!(assess(&top, Variation::StandardSquat).valid);
    assert!(assess(&bottom, Variation::StandardSquat).bottom);
    assert!(!assess(&top, Variation::WideSquat).valid);
    assert!(
        !assess(
            &serde_json::from_value(pose(0.0, false, false)).unwrap(),
            Variation::DiamondPushUp
        )
        .valid
    );
}

#[test]
fn elo_boundaries_draws_and_provisional_factors() {
    assert_eq!(elo(1000, 1000, 0.5, 0, 0), (1000, 1000));
    assert_eq!(elo(1000, 1000, 1.0, 0, 0), (1020, 980));
    assert_eq!(elo(1000, 1000, 1.0, 5, 5), (1012, 988));
    assert_eq!(elo(5000, 0, 1.0, 0, 0), (5000, 0));
    let (a, b) = elo(800, 1200, 1.0, 10, 10);
    assert!(a - 800 > 12);
    assert!(b < 1200);
}

#[tokio::test]
async fn session_rotation_logout_and_public_alias_privacy() {
    let s = Service::new().await;
    assert_eq!(
        s.get("me", &json!({"accessToken": "not-a-session"}))
            .await
            .status,
        StatusCode::UNAUTHORIZED
    );
    let identity = s.get("me", &s.a).await.expect(200)["identity"].clone();
    let public = s
        .get(
            &format!("players/{}", identity["publicID"].as_str().unwrap()),
            &s.b,
        )
        .await
        .expect(200);
    assert_eq!(public["displayName"], "Real public alias A");
    for secret in [
        "athlete-a",
        PASSWORD,
        s.a["accessToken"].as_str().unwrap(),
        s.a["refreshToken"].as_str().unwrap(),
    ] {
        assert!(!public.to_string().contains(secret));
    }
    let rotated = send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": s.a["refreshToken"]})),
    )
    .await
    .expect(200);
    s.get("me", &s.a).await.expect(401);
    send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": s.a["refreshToken"]})),
    )
    .await
    .expect(401);
    assert_ne!(rotated["accessToken"], s.a["accessToken"]);
    assert_ne!(rotated["refreshToken"], s.a["refreshToken"]);
    s.post(
        "me/privacy",
        &rotated,
        Some(json!({"displayName": "Private real alias", "listed": false})),
    )
    .await
    .expect(200);
    assert_eq!(
        s.get("me", &rotated).await.expect(200)["identity"]["displayName"],
        "Private real alias"
    );
    s.get(
        &format!("players/{}", identity["publicID"].as_str().unwrap()),
        &s.b,
    )
    .await
    .expect(404);
    s.post("auth/logout", &rotated, None).await.expect(200);
    s.get("me", &rotated).await.expect(401);
    send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": rotated["refreshToken"]})),
    )
    .await
    .expect(401);
}

#[tokio::test]
async fn python_database_password_and_existing_session_remain_usable() {
    let directory = tempfile::tempdir().unwrap();
    let path = directory.path().join("legacy.sqlite3");
    let db = rusqlite::Connection::open(&path).unwrap();
    db.execute_batch(include_str!("../schema.sql")).unwrap();
    let hash = "000102030405060708090a0b0c0d0e0f:78affb7a84713b0a7dddb3570e0df0b69011dcb6431e8aff02446276a7e3c4093e154319d66164485ea19ea39bdf5b490bf36342e5a670994a892c5826379ff7";
    db.execute("INSERT INTO accounts VALUES ('legacy-user','legacy-public','legacy-login',?,'Legacy alias',1,900000)", [hash]).unwrap();
    db.execute(
        "INSERT INTO sessions VALUES (?,?,'legacy-user','legacy-family',1000900,3592000,0)",
        params![
            "8333141902402e007d225a1a1b6227d3bb2cbc680571076e1cd947d7b8aba0df",
            "3a94d127620b455a7d4f5f2d306c5394a177c572f6b02a7c6701c3e8fcffc9d6",
        ],
    )
    .unwrap();
    db.execute(
        "INSERT INTO ratings VALUES ('legacy-user','standardPushUp',1234,7,'elo-1')",
        [],
    )
    .unwrap();
    drop(db);
    let state = AppState::with_clock(
        Config {
            database: path,
            require_tls: false,
            trust_proxy: false,
            supabase: None,
        },
        Arc::new(|| INITIAL_TIME),
    )
    .await
    .unwrap();
    let app = router(state);
    let legacy = json!({"accessToken": "legacy-access-token-0000000000000000000000000000", "refreshToken": "legacy-refresh-token-000000000000000000000000000"});
    let me = send(app.clone(), "GET", "me", Some(&legacy), None)
        .await
        .expect(200);
    assert_eq!(me["identity"]["publicID"], "legacy-public");
    assert_eq!(
        me["ratings"],
        json!([{"variation": "standardPushUp", "rating": 1234, "games": 7}])
    );
    send(
        app.clone(),
        "POST",
        "auth/login",
        None,
        Some(json!({"login": "legacy-login", "password": "incorrect-password"})),
    )
    .await
    .expect(401);
    let login = send(
        app.clone(),
        "POST",
        "auth/login",
        None,
        Some(json!({"login": " LEGACY-LOGIN ", "password": PASSWORD})),
    )
    .await
    .expect(200);
    assert_eq!(
        send(app.clone(), "GET", "me", Some(&login), None)
            .await
            .expect(200)["identity"],
        me["identity"]
    );
    let rotated = send(
        app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": legacy["refreshToken"]})),
    )
    .await
    .expect(200);
    send(app.clone(), "GET", "me", Some(&legacy), None)
        .await
        .expect(401);
    send(app.clone(), "POST", "auth/logout", Some(&rotated), None)
        .await
        .expect(200);
    send(
        app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": rotated["refreshToken"]})),
    )
    .await
    .expect(401);
    send(app, "GET", "me", Some(&login), None).await.expect(200);
}

#[tokio::test]
async fn queue_idempotency_exact_variation_cancel_and_consumed_request() {
    let s = Service::new().await;
    let request = json!({"variation": "standardPushUp", "ruleVersion": VERSION, "requestID": "same-request-00000001"});
    let mut tasks = Vec::new();
    for _ in 0..6 {
        let (app, auth, body) = (s.app.clone(), s.a.clone(), request.clone());
        tasks.push(tokio::spawn(async move {
            send(app, "POST", "queue", Some(&auth), Some(body))
                .await
                .expect(200)
        }));
    }
    for task in tasks {
        assert_eq!(task.await.unwrap()["queue"]["variation"], "standardPushUp");
    }
    s.queue(&s.b, "widePushUp", "different-variation-00001")
        .await
        .expect(200);
    assert!(s.get("state", &s.a).await.expect(200)["match"].is_null());
    s.queue(&s.a, "widePushUp", "same-request-00000001")
        .await
        .expect(409);
    s.post("queue/cancel", &s.b, None).await.expect(200);
    s.queue(&s.b, "standardPushUp", "matching-variation-000001")
        .await
        .expect(200);
    let m = s.get("state", &s.a).await.expect(200)["match"].clone();
    assert_eq!(m["participants"].as_array().unwrap().len(), 2);
    assert_eq!(m["variation"], "standardPushUp");
    s.post("queue/cancel", &s.a, None).await.expect(200);
    assert_eq!(
        s.get(&match_path(&m), &s.b).await.expect(200)["match"]["state"],
        "cancelled"
    );
    s.post("queue", &s.a, Some(request)).await.expect(200);
    assert!(s.get("state", &s.a).await.expect(200)["queue"].is_null());
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        10
    );
}

#[tokio::test]
async fn concurrent_opponents_claim_one_match_only() {
    let s = Service::new().await;
    let c = register(&s.app, "athlete-c", "Actual third athlete").await;
    s.queue(&s.a, "standardPushUp", "claim-first-user-000001")
        .await
        .expect(200);
    let mut tasks = Vec::new();
    for auth in [s.b.clone(), c.clone()] {
        let app = s.app.clone();
        tasks.push(tokio::spawn(async move {
            send(app, "POST", "queue", Some(&auth), Some(json!({"variation": "standardPushUp", "ruleVersion": VERSION, "requestID": "claim-opponent-00000001"}))).await.expect(200)
        }));
    }
    for task in tasks {
        task.await.unwrap();
    }
    let a = s.get("state", &s.a).await.expect(200);
    let b = s.get("state", &s.b).await.expect(200);
    let c = s.get("state", &c).await.expect(200);
    assert!(!a["match"].is_null());
    let matched: Vec<_> = [&b, &c]
        .into_iter()
        .filter(|v| !v["match"].is_null())
        .collect();
    assert_eq!(matched.len(), 1);
    assert_eq!(matched[0]["match"]["id"], a["match"]["id"]);
    let waiting = if b["match"].is_null() { &b } else { &c };
    assert_eq!(waiting["queue"]["variation"], "standardPushUp");
    assert_eq!(a["match"]["participants"].as_array().unwrap().len(), 2);
}

#[tokio::test]
async fn shared_go_and_after_go_forfeit_finalize_rating_and_slot_once() {
    let s = Service::new().await;
    let m = s.start("standardPushUp").await;
    let b = s.get(&match_path(&m), &s.b).await.expect(200)["match"].clone();
    assert_eq!(m["startAt"], b["startAt"]);
    assert_eq!(
        m["endAt"].as_f64().unwrap() - m["startAt"].as_f64().unwrap(),
        60.0
    );
    let path = format!("{}/leave", match_path(&m));
    s.post(&path, &s.a, None).await.expect(200);
    s.post(&path, &s.a, None).await.expect(200);
    s.state.tick().await.unwrap();
    let terminal = s.get(&match_path(&m), &s.a).await.expect(200)["match"].clone();
    assert_eq!(terminal["state"], "forfeited");
    assert_eq!(own(&terminal)["afterRating"], 980);
    assert_eq!(terminal["winner"], own(&b)["publicID"]);
    let me = s.get("me", &s.a).await.expect(200);
    assert_eq!(me["ratings"][0]["games"], 1);
    assert_eq!(me["allowances"][0]["remaining"], 9);
    assert_eq!(
        s.get("me", &s.b).await.expect(200)["ratings"][0]["rating"],
        1020
    );
}

#[tokio::test]
async fn pre_go_cancel_wins_before_boundary_and_leave_at_go_forfeits() {
    let s = Service::new().await;
    let m = s.countdown("standardPushUp").await;
    s.set(m["startAt"].as_f64().unwrap() - 0.001);
    s.post(&format!("{}/leave", match_path(&m)), &s.a, None)
        .await
        .expect(200);
    s.set(m["startAt"].as_f64().unwrap());
    s.state.tick().await.unwrap();
    assert_eq!(
        s.get(&match_path(&m), &s.b).await.expect(200)["match"]["state"],
        "cancelled"
    );
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        10
    );
    let next = s.countdown("standardPushUp").await;
    s.set(next["startAt"].as_f64().unwrap());
    s.post(&format!("{}/leave", match_path(&next)), &s.a, None)
        .await
        .expect(200);
    assert_eq!(
        s.get(&match_path(&next), &s.b).await.expect(200)["match"]["state"],
        "forfeited"
    );
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        9
    );
}

#[tokio::test]
async fn readiness_requires_calibration_and_lost_camera_cancels_countdown() {
    let s = Service::new().await;
    let m = s.pair("standardPushUp").await;
    let path = format!("{}/ready", match_path(&m));
    s.post(&path, &s.a, Some(json!({"ready": true, "calibration": []})))
        .await
        .expect(422);
    let mut frames: Vec<_> = (0..20)
        .map(|i| pose(i as f64 / 10.0, false, false))
        .collect();
    frames[10]["people"] = json!(2);
    s.post(
        &path,
        &s.a,
        Some(json!({"ready": true, "calibration": frames})),
    )
    .await
    .expect(422);
    assert_eq!(
        own(&s.get(&match_path(&m), &s.a).await.expect(200)["match"])["ready"],
        false
    );
    let frames: Vec<_> = (0..20)
        .map(|i| pose(i as f64 / 10.0, false, false))
        .collect();
    for auth in [&s.a, &s.b] {
        s.post(
            &path,
            auth,
            Some(json!({"ready": true, "calibration": frames})),
        )
        .await
        .expect(200);
    }
    let cancelled = s
        .post(
            &format!("{}/presence", match_path(&m)),
            &s.a,
            Some(json!({"active": true, "calibrated": false})),
        )
        .await
        .expect(200);
    assert_eq!(cancelled["match"]["state"], "cancelled");
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        10
    );
}

#[tokio::test]
async fn family_allowance_is_shared_and_expires_at_exact_rolling_boundary() {
    let s = Service::new().await;
    for i in 0..10 {
        let variation = if i % 2 == 0 {
            "standardPushUp"
        } else {
            "pausedPushUp"
        };
        let m = s.start(variation).await;
        s.post(&format!("{}/leave", match_path(&m)), &s.a, None)
            .await
            .expect(200);
    }
    let me = s.get("me", &s.a).await.expect(200);
    assert_eq!(
        me["allowances"]
            .as_array()
            .unwrap()
            .iter()
            .map(|v| v["remaining"].clone())
            .collect::<Vec<_>>(),
        vec![json!(0), json!(10), Value::Null]
    );
    s.queue(&s.a, "widePushUp", "blocked-family-slot-0001")
        .await
        .expect(429);
    let next = me["allowances"][0]["nextSlot"].as_f64().unwrap();
    s.state
        .db
        .call(move |db| {
            db.execute("UPDATE sessions SET access_expires=?", [next + 900.0])?;
            Ok(())
        })
        .await
        .unwrap();
    s.set(next - 0.0001);
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        0
    );
    s.queue(&s.a, "widePushUp", "before-rolling-slot-0001")
        .await
        .expect(429);
    s.set(next);
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        1
    );
    s.queue(&s.a, "widePushUp", "exact-rolling-slot-00001")
        .await
        .expect(200);
}

#[tokio::test]
async fn readiness_expiry_and_live_reconnect_grace_have_exact_boundaries() {
    let s = Service::new().await;
    let m = s.pair("standardPushUp").await;
    s.advance(8.0);
    s.state.tick().await.unwrap();
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "matched"
    );
    s.advance(0.001);
    s.state.tick().await.unwrap();
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "cancelled"
    );
    let m = s.start("standardPushUp").await;
    s.heartbeat(&m).await;
    s.advance(7.9);
    s.heartbeat(&m).await;
    s.advance(7.9);
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "live"
    );
    s.get(&match_path(&m), &s.b).await.expect(200);
    s.advance(8.0);
    s.get(&match_path(&m), &s.b).await.expect(200);
    s.advance(0.001);
    s.state.tick().await.unwrap();
    let terminal = s.get(&match_path(&m), &s.b).await.expect(200)["match"].clone();
    assert_eq!(terminal["state"], "forfeited");
    assert_eq!(terminal["winner"], own(&terminal)["publicID"]);
}

#[tokio::test]
async fn both_disconnected_is_invalid_and_background_presence_forfeits() {
    let s = Service::new().await;
    let m = s.start("standardPushUp").await;
    s.advance(8.001);
    s.state.tick().await.unwrap();
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "invalid"
    );
    assert_eq!(s.get("me", &s.a).await.expect(200)["ratings"], json!([]));
    let m = s.start("standardPushUp").await;
    let terminal = s
        .post(
            &format!("{}/presence", match_path(&m)),
            &s.a,
            Some(json!({"active": false, "calibrated": true})),
        )
        .await
        .expect(200);
    assert_eq!(terminal["match"]["state"], "forfeited");
    assert_eq!(own(&terminal["match"])["afterRating"], 980);
}

#[tokio::test]
async fn evidence_authorization_order_retries_conflicts_and_capture_rate() {
    let s = Service::new().await;
    let m = s.start("standardPushUp").await;
    let path = format!("{}/evidence", match_path(&m));
    let body = evidence(&m, 0, vec![pose(0.0, false, false)]);
    s.post(&path, &s.b, Some(body.clone())).await.expect(403);
    let c = register(&s.app, "outsider", "Actual outsider alias").await;
    s.get(&match_path(&m), &c).await.expect(404);
    for endpoint in ["leave", "submit", "evidence", "ready", "presence"] {
        let body = match endpoint {
            "evidence" => Some(body.clone()),
            "ready" => Some(json!({"ready": false, "calibration": []})),
            "presence" => Some(json!({"active": true, "calibrated": true})),
            _ => None,
        };
        s.post(&format!("{}/{endpoint}", match_path(&m)), &c, body)
            .await
            .expect(404);
    }
    let view = s.get(&match_path(&m), &s.b).await.expect(200)["match"].clone();
    let other = view["participants"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["isYou"] == false)
        .unwrap();
    assert!(other["nonce"].is_null());
    assert!(other["nextSequence"].is_null());
    assert_eq!(other["displayName"], "Real public alias A");
    assert!(!view.to_string().contains("athlete-a"));
    assert!(!view.to_string().contains("athlete-b"));
    let mut wrong_version = body.clone();
    wrong_version["ruleVersion"] = json!("pose-obsolete");
    s.post(&path, &s.a, Some(wrong_version)).await.expect(403);
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 1, vec![pose(0.0, false, false)])),
    )
    .await
    .expect(409);
    assert_eq!(
        s.post(&path, &s.a, Some(body.clone())).await.expect(200)["nextSequence"],
        1
    );
    let retry = s.post(&path, &s.a, Some(body.clone())).await.expect(200);
    assert_eq!(retry["nextSequence"], 1);
    assert_eq!(retry["score"], 0.0);
    let mut changed = body;
    changed["frames"][0]["people"] = json!(2);
    s.post(&path, &s.a, Some(changed)).await.expect(409);
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 1, vec![pose(0.0, false, false)])),
    )
    .await
    .expect(409);
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 1, vec![pose(0.044, false, false)])),
    )
    .await
    .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 1, vec![pose(0.045, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        2
    );
    let batch = evidence(
        &m,
        2,
        vec![pose(0.1, false, false), pose(0.09, false, false)],
    );
    s.post(&path, &s.a, Some(batch)).await.expect(409);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 2, vec![pose(0.1, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        3
    );
    let mut unknown = evidence(&m, 3, vec![pose(0.2, false, false)]);
    unknown["score"] = json!(500);
    s.post(&path, &s.a, Some(unknown)).await.expect(422);
    let mut unknown_joint = pose(0.2, false, false);
    unknown_joint["joints"]["leftWrist"]["score"] = json!(99);
    s.post(&path, &s.a, Some(evidence(&m, 3, vec![unknown_joint])))
        .await
        .expect(422);
    let mut unknown_pose = pose(0.2, false, false);
    unknown_pose["claimedScore"] = json!(99);
    s.post(&path, &s.a, Some(evidence(&m, 3, vec![unknown_pose])))
        .await
        .expect(422);
    let mut unknown_name = pose(0.2, false, false);
    unknown_name["joints"]
        .as_object_mut()
        .unwrap()
        .remove("nose");
    unknown_name["joints"]["unrecognizedJoint"] = json!({"x": 0.2, "y": 0.3, "confidence": 0.99});
    s.post(&path, &s.a, Some(evidence(&m, 3, vec![unknown_name])))
        .await
        .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 3, vec![pose(0.2, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        4
    );
}

#[tokio::test]
async fn evidence_timestamp_windows_include_boundaries_and_reject_stale_future() {
    let s = Service::new().await;
    let m = s.countdown("standardPushUp").await;
    let start = m["startAt"].as_f64().unwrap();
    let path = format!("{}/evidence", match_path(&m));
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 0, vec![pose(-4.0001, false, false)])),
    )
    .await
    .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 0, vec![pose(-4.0, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        1
    );
    s.set(start);
    s.heartbeat(&m).await;
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 1, vec![pose(0.3501, false, false)])),
    )
    .await
    .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 1, vec![pose(0.35, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        2
    );
    s.set(start + 7.0);
    s.heartbeat(&m).await;
    s.set(start + 8.5);
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 2, vec![pose(0.4999, false, false)])),
    )
    .await
    .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 2, vec![pose(0.5, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        3
    );
    for second in (14..=56).step_by(7) {
        s.set(start + second as f64);
        s.heartbeat(&m).await;
    }
    s.set(start + 60.0);
    s.heartbeat(&m).await;
    s.post(
        &path,
        &s.a,
        Some(evidence(&m, 3, vec![pose(60.0001, false, false)])),
    )
    .await
    .expect(422);
    assert_eq!(
        s.post(
            &path,
            &s.a,
            Some(evidence(&m, 3, vec![pose(60.0, false, false)]))
        )
        .await
        .expect(200)["nextSequence"],
        4
    );
}

#[tokio::test]
async fn invalid_visibility_is_accepted_without_scoring_or_wedging_uploads() {
    let s = Service::new().await;
    let m = s.start("standardPushUp").await;
    let path = format!("{}/evidence", match_path(&m));
    let mut frames = vec![
        pose(0.0, false, false),
        pose(0.1, false, false),
        pose(0.2, false, false),
        pose(0.3, false, false),
    ];
    frames[0]["joints"]["leftWrist"]["x"] = json!(-0.1);
    frames[1]["people"] = json!(2);
    frames[2]["people"] = json!(0);
    let receipt = s
        .post(&path, &s.a, Some(evidence(&m, 0, frames)))
        .await
        .expect(200);
    assert_eq!(receipt["nextSequence"], 4);
    assert_eq!(receipt["score"], 0.0);
    s.advance(2.0);
    let frames = (4..20)
        .map(|i| pose(i as f64 / 10.0, false, false))
        .collect();
    let receipt = s
        .post(&path, &s.a, Some(evidence(&m, 4, frames)))
        .await
        .expect(200);
    assert_eq!(receipt["nextSequence"], 20);
    assert_eq!(receipt["score"], 0.0);
}

#[tokio::test]
async fn python_persisted_digest_accepts_same_body_retry_with_float_exponents() {
    let mut s = Service::new().await;
    let m = s.start("standardPushUp").await;
    let path = format!("{}/evidence", match_path(&m));
    let body = evidence(
        &m,
        0,
        vec![json!({"time": 0, "aspect": 1, "people": 1,
        "joints": {"leftWrist": {"x": 1e-7, "y": 1e20, "confidence": 0.99}},
        "light": 0.5, "cameraMoving": false, "diamondContact": null})],
    );
    assert_eq!(
        s.post(&path, &s.a, Some(body.clone())).await.expect(200)["nextSequence"],
        1
    );
    let uid = s.uid(&s.a).await;
    let mid = m["id"].as_str().unwrap().to_owned();
    s.state
        .db
        .call(move |db| {
            db.execute(
                "UPDATE evidence SET digest=? WHERE match_id=? AND user_id=? AND sequence=0",
                params![
                    "7380090b633ed9ad2e4c0f52243adedf5b801f7ee4d4b6095067bcc850602fa8",
                    mid,
                    uid,
                ],
            )?;
            Ok(())
        })
        .await
        .unwrap();
    s.reopen().await;
    let retry = s.post(&path, &s.a, Some(body.clone())).await.expect(200);
    assert_eq!(retry["nextSequence"], 1);
    assert_eq!(retry["score"], 0.0);
    let mut conflict = body;
    conflict["frames"][0]["joints"]["leftWrist"]["x"] = json!(2e-7);
    s.post(&path, &s.a, Some(conflict)).await.expect(409);
}

#[tokio::test]
async fn insufficient_evidence_never_awards_elo_but_consumes_started_slot() {
    let s = Service::new().await;
    let m = s.start("standardPushUp").await;
    s.post(&format!("{}/submit", match_path(&m)), &s.a, None)
        .await
        .expect(409);
    for i in 1..=60 {
        s.set(m["startAt"].as_f64().unwrap() + i as f64);
        s.heartbeat(&m).await;
    }
    for auth in [&s.a, &s.b] {
        s.post(&format!("{}/submit", match_path(&m)), auth, None)
            .await
            .expect(200);
    }
    let terminal = s.get(&match_path(&m), &s.a).await.expect(200)["match"].clone();
    assert_eq!(terminal["state"], "invalid");
    assert!(terminal["winner"].is_null());
    assert!(
        terminal["participants"]
            .as_array()
            .unwrap()
            .iter()
            .all(|p| p["verification"] == "insufficientEvidence" && p["afterRating"].is_null())
    );
    for auth in [&s.a, &s.b] {
        let me = s.get("me", auth).await.expect(200);
        assert_eq!(me["ratings"], json!([]));
        assert_eq!(me["allowances"][0]["remaining"], 9);
    }
}

#[tokio::test]
async fn full_evidence_round_finalizes_once_and_survives_state_reopen() {
    let mut s = Service::new().await;
    let m = s.start("standardPushUp").await;
    let b = s.get(&match_path(&m), &s.b).await.expect(200)["match"].clone();
    let path = format!("{}/evidence", match_path(&m));
    let mut sequences = [0, 0];
    for i in (-30..600).step_by(10) {
        s.set(m["startAt"].as_f64().unwrap() + ((i + 9) as f64 / 10.0).max(0.0));
        for (athlete, auth, view) in [(0, &s.a, &m), (1, &s.b, &b)] {
            let frames = (i..i + 10)
                .map(|j| {
                    pose(
                        j as f64 / 10.0,
                        athlete == 0 && (40..45).contains(&j),
                        false,
                    )
                })
                .collect();
            let receipt = s
                .post(
                    &path,
                    auth,
                    Some(evidence(view, sequences[athlete], frames)),
                )
                .await
                .expect(200);
            sequences[athlete] = receipt["nextSequence"].as_u64().unwrap();
        }
    }
    s.set(m["endAt"].as_f64().unwrap());
    for auth in [&s.a, &s.b] {
        s.post(&format!("{}/submit", match_path(&m)), auth, None)
            .await
            .expect(200);
    }
    let a = s.get(&match_path(&m), &s.a).await.expect(200)["match"].clone();
    let b = s.get(&match_path(&m), &s.b).await.expect(200)["match"].clone();
    assert_eq!(a["state"], "completed");
    assert_eq!(a["winner"], own(&a)["publicID"]);
    assert_eq!(a["winner"], b["winner"]);
    assert_eq!(own(&a)["score"], 1.0);
    assert_eq!(own(&b)["score"], 0.0);
    assert!(
        a["participants"]
            .as_array()
            .unwrap()
            .iter()
            .all(|p| p["verification"] == "motionValidated")
    );
    let mut tasks = Vec::new();
    for _ in 0..6 {
        let (app, auth, path) = (
            s.app.clone(),
            s.a.clone(),
            format!("{}/submit", match_path(&m)),
        );
        tasks.push(tokio::spawn(async move {
            send(app, "POST", &path, Some(&auth), None)
                .await
                .expect(200)
        }));
    }
    for task in tasks {
        assert_eq!(task.await.unwrap()["match"]["winner"], a["winner"]);
    }
    s.reopen().await;
    s.state.tick().await.unwrap();
    let history = s.get("history", &s.a).await.expect(200);
    assert_eq!(
        history["matches"]
            .as_array()
            .unwrap()
            .iter()
            .map(|v| v["id"].clone())
            .collect::<Vec<_>>(),
        vec![m["id"].clone()]
    );
    let ratings_a = s.get("me", &s.a).await.expect(200)["ratings"].clone();
    let ratings_b = s.get("me", &s.b).await.expect(200)["ratings"].clone();
    assert_eq!(
        ratings_a,
        json!([{"variation": "standardPushUp", "rating": 1020, "games": 1}])
    );
    assert_eq!(
        ratings_b,
        json!([{"variation": "standardPushUp", "rating": 980, "games": 1}])
    );
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["winner"],
        a["winner"]
    );
}

#[tokio::test]
async fn advanced_movements_are_unavailable_and_old_rules_cannot_queue() {
    let s = Service::new().await;
    for variation in [
        "diamondPushUp",
        "wallHandstandPushUp",
        "freestandingHandstandPushUp",
        "planchePushUp",
    ] {
        s.queue(&s.a, variation, "advanced-attempt-0000001")
            .await
            .expect(422);
    }
    s.post("queue", &s.a, Some(json!({"variation": "standardPushUp", "ruleVersion": "pose-old", "requestID": "old-rule-request-000001"}))).await.expect(409);
    let state = s.get("state", &s.a).await.expect(200);
    assert!(state["queue"].is_null());
    assert!(state["match"].is_null());
}

#[tokio::test]
async fn leaderboard_order_keyset_pagination_around_me_and_private_profiles() {
    let s = Service::new().await;
    let uid = s.uid(&s.a).await;
    s.state.db.call(move |db| {
        db.execute("INSERT INTO ratings VALUES (?, 'standardPushUp',1000,6,'elo-1')", [uid])?;
        for i in 0..27 {
            let uid = format!("seed-user-{i:02}");
            let public = format!("public-{i:02}");
            db.execute("INSERT INTO accounts VALUES (?,?,?,'fixture-only',?,1,1000000)", params![uid, public, format!("private-login-{i}"), format!("Athlete alias {i}")])?;
            db.execute("INSERT INTO ratings VALUES (?,'standardPushUp',?,6,'elo-1')", params![uid, 1500 - i / 3])?;
        }
        db.execute("INSERT INTO accounts VALUES ('private-user','hidden-public','hidden-login','fixture-only','Hidden alias',0,1000000)", [])?;
        db.execute("INSERT INTO ratings VALUES ('private-user','standardPushUp',4999,10,'elo-1')", [])?;
        db.execute("INSERT INTO accounts VALUES ('unplayed-user','unplayed-public','unplayed-login','fixture-only','No games alias',1,1000000)", [])?;
        db.execute("INSERT INTO ratings VALUES ('unplayed-user','standardPushUp',5000,0,'elo-1')", [])?;
        Ok(())
    }).await.unwrap();
    let first = s.get("leaderboard/standardPushUp", &s.a).await.expect(200);
    let second = s
        .get(
            &format!(
                "leaderboard/standardPushUp?cursor={}",
                first["nextCursor"].as_str().unwrap()
            ),
            &s.a,
        )
        .await
        .expect(200);
    assert_eq!(first["rows"].as_array().unwrap().len(), 20);
    assert_eq!(second["rows"].as_array().unwrap().len(), 8);
    assert!(second["nextCursor"].is_null());
    let rows: Vec<_> = first["rows"]
        .as_array()
        .unwrap()
        .iter()
        .chain(second["rows"].as_array().unwrap())
        .collect();
    let ids: HashSet<_> = rows
        .iter()
        .map(|r| r["publicID"].as_str().unwrap())
        .collect();
    assert_eq!(ids.len(), 28);
    assert!(!ids.contains("hidden-public"));
    assert!(!ids.contains("unplayed-public"));
    for (i, row) in rows.iter().enumerate() {
        assert_eq!(row["position"], i + 1);
    }
    for pair in rows.windows(2) {
        let (a, b) = (pair[0], pair[1]);
        assert!(
            a["rating"].as_i64().unwrap() > b["rating"].as_i64().unwrap()
                || a["rating"] == b["rating"]
                    && a["publicID"].as_str().unwrap() < b["publicID"].as_str().unwrap()
        );
    }
    let around = s
        .get("leaderboard/standardPushUp?aroundMe=true", &s.a)
        .await
        .expect(200);
    assert_eq!(around["me"]["position"], 28);
    assert!(
        around["rows"]
            .as_array()
            .unwrap()
            .iter()
            .any(|row| row["publicID"] == around["me"]["publicID"])
    );
    assert_eq!(
        s.get("leaderboard/widePushUp", &s.a).await.expect(200)["rows"],
        json!([])
    );
    let public = s.get("players/public-00", &s.b).await.expect(200);
    assert_eq!(public["displayName"], "Athlete alias 0");
    assert_eq!(
        public["ratings"],
        json!([{"variation": "standardPushUp", "rating": 1500, "games": 6}])
    );
    assert!(!public.to_string().contains("private-login"));
    s.get("players/hidden-public", &s.b).await.expect(404);
    s.get("leaderboard/standardPushUp?cursor=invalid!", &s.a)
        .await
        .expect(422);
    s.get("history?cursor=invalid!", &s.a).await.expect(422);
    s.post(
        "me/privacy",
        &s.a,
        Some(json!({"displayName": "Real private alias A", "listed": false})),
    )
    .await
    .expect(200);
    let hidden = s
        .get("leaderboard/standardPushUp?aroundMe=true", &s.a)
        .await
        .expect(200);
    assert!(hidden["me"].is_null());
    assert!(
        hidden["rows"]
            .as_array()
            .unwrap()
            .iter()
            .all(|row| row["publicID"] != around["me"]["publicID"])
    );
}

#[tokio::test]
async fn request_boundary_rejects_oversized_unknown_and_nonfinite_json() {
    let s = Service::new().await;
    let response = s.get("me", &s.a).await;
    assert_eq!(response.headers.get("cache-control").unwrap(), "no-store");
    assert_eq!(
        response.headers.get("x-content-type-options").unwrap(),
        "nosniff"
    );
    response.expect(200);
    let mut body = json!({"displayName": "Actual alias", "listed": true});
    body["rating"] = json!(5000);
    s.post("me/privacy", &s.a, Some(body)).await.expect(422);
    for (length, payload, expected) in [
        (None, vec![b' '; 262_145], 413),
        (Some("262145"), b"{}".to_vec(), 413),
        (Some("not-a-length"), b"{}".to_vec(), 400),
    ] {
        let mut request = Request::builder()
            .method("POST")
            .uri("http://ranked.test/v1/me/privacy")
            .header(
                "authorization",
                format!("Bearer {}", s.a["accessToken"].as_str().unwrap()),
            )
            .header("content-type", "application/json");
        if let Some(length) = length {
            request = request.header("content-length", length);
        }
        read_reply(
            s.app
                .clone()
                .oneshot(request.body(Body::from(payload)).unwrap())
                .await
                .unwrap(),
        )
        .await
        .expect(expected);
    }
    let m = s.start("standardPushUp").await;
    let body = evidence(&m, 0, vec![pose(0.0, false, false)]);
    for malformed in [
        body.to_string()
            .replace("\"aspect\":1.0", "\"aspect\":1e999"),
        body.to_string().replace("\"aspect\":1.0", "\"aspect\":NaN"),
    ] {
        let request = Request::builder()
            .method("POST")
            .uri(format!("http://ranked.test/v1/{}/evidence", match_path(&m)))
            .header(
                "authorization",
                format!("Bearer {}", s.a["accessToken"].as_str().unwrap()),
            )
            .header("content-type", "application/json")
            .body(Body::from(malformed))
            .unwrap();
        let response = read_reply(s.app.clone().oneshot(request).await.unwrap()).await;
        assert!(
            response.status == StatusCode::BAD_REQUEST
                || response.status == StatusCode::UNPROCESSABLE_ENTITY,
            "{}",
            response.body
        );
    }
    assert_eq!(
        s.post(&format!("{}/evidence", match_path(&m)), &s.a, Some(body))
            .await
            .expect(200)["nextSequence"],
        1
    );
}

#[tokio::test]
async fn tls_requires_explicitly_trusted_proxy_and_rejects_absolute_uri_spoofing() {
    for trust_proxy in [false, true] {
        let directory = tempfile::tempdir().unwrap();
        let state = AppState::with_clock(
            Config {
                database: directory.path().join("tls.sqlite3"),
                require_tls: true,
                trust_proxy,
                supabase: None,
            },
            Arc::new(|| INITIAL_TIME),
        )
        .await
        .unwrap();
        let app = router(state);
        for (uri, forwarded, expected) in [
            ("http://ranked.test/v1/catalog", None, 426),
            ("https://ranked.test/v1/catalog", None, 426),
            (
                "http://ranked.test/v1/catalog",
                Some("https"),
                if trust_proxy { 200 } else { 426 },
            ),
            ("http://ranked.test/v1/catalog", Some("http"), 426),
            (
                "https://ranked.test/v1/catalog",
                Some("https"),
                if trust_proxy { 200 } else { 426 },
            ),
            ("https://ranked.test/v1/catalog", Some("http"), 426),
        ] {
            let mut request = Request::builder().uri(uri);
            if let Some(proto) = forwarded {
                request = request.header("x-forwarded-proto", proto);
            }
            let response = read_reply(
                app.clone()
                    .oneshot(request.body(Body::empty()).unwrap())
                    .await
                    .unwrap(),
            )
            .await;
            response.expect(expected);
        }
    }
}

#[test]
fn python_tracker_snapshot_resumes_mid_rep_without_losing_progress() {
    let snapshot = r#"{"variation":"standardPushUp","score":0,"phase":2,"stable":null,"calibration":-3.0,"scale":0.2795084971874737,"hold":null,"descending":0.5,"bottom":0.5,"last":0.9,"calibrated":true,"valid_seconds":0.9,"covered_seconds":0.9,"last_usable":true,"reason":"Complete the full movement"}"#;
    let mut tracker: Tracker = serde_json::from_str(snapshot).unwrap();
    for i in 10..13 {
        consume(&mut tracker, pose(i as f64 / 10.0, false, false));
    }
    assert_eq!(tracker.score, 1.0);
    assert!((tracker.covered_seconds - 1.2).abs() < 1e-8);
    assert!((tracker.valid_seconds - 1.2).abs() < 1e-8);
}

#[tokio::test]
async fn sessions_expire_at_exact_access_and_refresh_boundaries() {
    let s = Service::new().await;
    s.set(INITIAL_TIME + 899.999);
    s.get("me", &s.a).await.expect(200);
    s.set(INITIAL_TIME + 900.0);
    s.get("me", &s.a).await.expect(401);
    let rotated = send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": s.a["refreshToken"]})),
    )
    .await
    .expect(200);
    s.get("me", &rotated).await.expect(200);
    s.set(INITIAL_TIME + 2_592_000.0);
    send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": s.b["refreshToken"]})),
    )
    .await
    .expect(401);
    let renewed = send(
        s.app.clone(),
        "POST",
        "auth/refresh",
        None,
        Some(json!({"refreshToken": rotated["refreshToken"]})),
    )
    .await
    .expect(200);
    s.get("me", &renewed).await.expect(200);
}

#[tokio::test]
async fn matched_readiness_deadline_expires_even_with_continuous_presence() {
    let s = Service::new().await;
    let m = s.pair("standardPushUp").await;
    let deadline = m["readyDeadline"].as_f64().unwrap();
    for second in (7..=42).step_by(7) {
        s.set(m["createdAt"].as_f64().unwrap() + second as f64);
        s.heartbeat(&m).await;
    }
    s.set(deadline);
    s.heartbeat(&m).await;
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "matched"
    );
    s.set(deadline + 0.001);
    s.state.tick().await.unwrap();
    assert_eq!(
        s.get(&match_path(&m), &s.a).await.expect(200)["match"]["state"],
        "cancelled"
    );
    assert_eq!(
        s.get("me", &s.a).await.expect(200)["allowances"][0]["remaining"],
        10
    );
}
