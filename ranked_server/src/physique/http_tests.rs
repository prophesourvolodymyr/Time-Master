use super::*;
use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use http_body_util::BodyExt;
use tower::ServiceExt;

async fn send(
    state: &AppState,
    method: &str,
    path: &str,
    token: &str,
    body: Option<serde_json::Value>,
) -> (StatusCode, HeaderMap, serde_json::Value) {
    let mut request = Request::builder()
        .method(method)
        .uri(path)
        .header("Authorization", format!("Bearer {token}"));
    let body = if let Some(body) = body {
        request = request.header("Content-Type", "application/json");
        Body::from(serde_json::to_vec(&body).unwrap())
    } else {
        Body::empty()
    };
    let response = crate::router(state.clone())
        .oneshot(request.body(body).unwrap())
        .await
        .unwrap();
    let status = response.status();
    let headers = response.headers().clone();
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    (status, headers, serde_json::from_slice(&bytes).unwrap())
}
#[tokio::test]
async fn private_media_is_freshly_authenticated_and_owner_sharing_is_enforced() {
    let directory = tempfile::TempDir::new().unwrap();
    let mut state = AppState::with_clock(
        crate::Config {
            database: directory.path().join("service.sqlite3"),
            require_tls: false,
            trust_proxy: false,
            supabase: None,
        },
        std::sync::Arc::new(|| 1000.0),
    )
    .await
    .unwrap();
    let mut settings = super::tests::settings();
    settings.media_root = Some(directory.path().join("private-media"));
    std::fs::create_dir_all(settings.media_root.as_ref().unwrap()).unwrap();
    std::sync::Arc::get_mut(&mut state.physique)
        .unwrap()
        .settings = settings.clone();
    let seed = settings.clone();
    let mid=state.db.call(move|db|{
        for(uid,public,token)in[("a","public-a","token-a"),("b","public-b","token-b"),("c","public-c","token-c")]{
            db.execute("INSERT INTO accounts VALUES (?,?,?,?,?,0,0)",params![uid,public,uid,"","Exercise athlete"])?;
            db.execute("INSERT INTO sessions VALUES (?,?,?,?,100000,100000,0)",params![auth::digest(token),auth::digest(format!("refresh-{uid}")),uid,uid])?;
            comp::ensure(db,uid)?;
            cases::update_consent(db,uid,&Consent{adult:true,adult_man:false,rules_accepted:true,ai_processing:true,opponent_sharing:true,policy_version:"test-policy".into()},0.0)?;
        }
        let mid=super::tests::judged(db,&seed,100.0,60,50);
        for slot in ["a","b"]{for pose in comp::POSES{
            let key=judge::write_media(&seed,b"private evidence fixture")?;
            db.execute("UPDATE physique_media SET file_key=?,expires=86505 WHERE match_id=? AND slot=? AND pose=?",params![key,mid,slot,pose])?;
        }}
        Ok(mid)
    }).await.unwrap();
    let path = format!("/v1/physique/matches/{mid}/gallery");
    let (status, headers, body) = send(&state, "GET", &path, "token-c", None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(headers["cache-control"], "no-store");
    assert!(body.get("items").is_none());
    let (status, _, body) = send(&state, "GET", &path, "token-a", None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["items"].as_array().unwrap().len(), 6);
    assert!(
        body["items"]
            .as_array()
            .unwrap()
            .iter()
            .all(|item| item["status"] == "available" && item.get("url").is_none())
    );
    let(status,_,receipt)=send(&state,"POST","/v1/physique/command","token-b",Some(serde_json::json!({"operation":"withdrawSharing","requestID":"00000000-0000-4000-8000-000000000001"}))).await;
    assert_eq!(status, StatusCode::OK);
    assert!(receipt["receiptID"].is_string());
    let (status, _, body) = send(&state, "GET", &path, "token-a", None).await;
    assert_eq!(status, StatusCode::OK);
    for item in body["items"].as_array().unwrap() {
        if item["ownerID"] == "public-b" {
            assert_eq!(item["status"], "sharingWithdrawn");
            assert!(item["imageBase64"].is_null())
        } else {
            assert_eq!(item["status"], "available")
        }
    }
    state
        .db
        .call(|db| {
            db.execute("UPDATE sessions SET revoked=1 WHERE user_id='a'", [])?;
            Ok(())
        })
        .await
        .unwrap();
    let (status, _, body) = send(&state, "GET", &path, "token-a", None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert!(body.get("items").is_none());
}
