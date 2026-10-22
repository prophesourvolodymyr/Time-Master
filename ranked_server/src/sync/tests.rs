use super::*;
use crate::{
    cloud::tests::{OWNER_A, OWNER_B, Service, request},
    router,
};
use axum::{body::Bytes, http::StatusCode};
use serde_json::{Value, json};

fn batch(mutations: Vec<Value>) -> Value {
    json!({"deviceID": "25bb1f60-584f-41a0-b027-674a07fbb55c", "mutations": mutations})
}
fn file(path: &str, base: i64, bytes: &[u8], chunks: Vec<String>) -> Value {
    json!({"path": path, "baseRevision": base, "hash": auth::digest(bytes), "size": bytes.len(), "chunks": chunks, "deleted": false})
}
fn deletion(path: &str, base: i64) -> Value {
    json!({"path": path, "baseRevision": base, "hash": null, "size": 0, "chunks": [], "deleted": true})
}

#[tokio::test]
async fn uploads_and_commits_validate_every_hash_size_and_owner_namespace() {
    let service = Service::new().await;
    let first = b"first chunk of private exercise video";
    let second = b"second differently-sized chunk";
    let joined = [first.as_slice(), second.as_slice()].concat();
    let hash = auth::digest(first);
    service
        .send(
            "PUT",
            &format!("/v1/sync/blobs/{hash}"),
            &service.a,
            b"wrong bytes".to_vec(),
            "application/octet-stream",
        )
        .await
        .expect(422);
    service
        .json("GET", &format!("/v1/sync/blobs/{hash}"), &service.a, None)
        .await
        .expect(404);
    service
        .send(
            "PUT",
            &format!("/v1/sync/blobs/{hash}"),
            &service.a,
            vec![7; CHUNK_BYTES + 1],
            "application/octet-stream",
        )
        .await
        .expect(413);
    let a = service.chunk(&service.a, first).await;
    let b = service.chunk(&service.a, second).await;
    service.chunk(&service.a, first).await;
    let blob = service
        .json("GET", &format!("/v1/sync/blobs/{a}"), &service.a, None)
        .await;
    assert_eq!(blob.status, StatusCode::OK);
    assert_eq!(blob.bytes.as_slice(), first.as_slice());
    assert_eq!(blob.headers["content-type"], "application/octet-stream");
    assert!(!blob.headers.contains_key("location"));
    service
        .json("GET", &format!("/v1/sync/blobs/{a}"), &service.b, None)
        .await
        .expect(404);
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.b,
            Some(batch(vec![file(
                "Media/private-video.mp4",
                0,
                &joined,
                vec![a.clone(), b.clone()],
            )])),
        )
        .await
        .expect(422);
    let mut wrong = file(
        "Exercises Database/Push Up/media/clip.mp4",
        0,
        &joined,
        vec![a.clone(), b.clone()],
    );
    wrong["hash"] = json!(auth::digest(b"a forged whole-file digest"));
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![wrong])),
        )
        .await
        .expect(422);
    let mut wrong = file(
        "Exercises Database/Push Up/media/clip.mp4",
        0,
        &joined,
        vec![a.clone(), b.clone()],
    );
    wrong["size"] = json!(joined.len() + 1);
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![wrong])),
        )
        .await
        .expect(422);
    let clean = service
        .json("GET", "/v1/sync/manifest", &service.a, None)
        .await
        .expect(200);
    assert_eq!(clean["files"], json!([]));
    let committed = service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![file(
                "Exercises Database/Push Up/media/clip.mp4",
                0,
                &joined,
                vec![a.clone(), b.clone()],
            )])),
        )
        .await
        .expect(200);
    assert_eq!(committed["files"][0]["hash"], auth::digest(&joined));
    let owner_b = service
        .json("GET", "/v1/sync/manifest", &service.b, None)
        .await
        .expect(200);
    assert_eq!(owner_b["files"], json!([]));
    service.chunk(&service.b, first).await;
    let objects = service.upstream.objects.lock();
    assert!(objects.contains_key(&cloud::Supabase::object_name(OWNER_A, &a)));
    assert!(objects.contains_key(&cloud::Supabase::object_name(OWNER_B, &a)));
}

#[tokio::test]
async fn concurrent_batches_are_atomic_and_lost_responses_are_durable_idempotent_receipts() {
    let mut service = Service::new().await;
    let initial = b"original guide";
    let left = b"edit from phone";
    let right = b"edit from mac";
    let a = service.chunk(&service.a, initial).await;
    let b = service.chunk(&service.a, left).await;
    let c = service.chunk(&service.a, right).await;
    let created = service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![file(
                "Exercises Database/Push Up/guide.md",
                0,
                initial,
                vec![a],
            )])),
        )
        .await
        .expect(200);
    let base = created["files"][0]["revision"].as_i64().unwrap();
    let left_batch = batch(vec![
        file("Exercises Database/Push Up/guide.md", base, left, vec![b]),
        file("Exercises Database/Phone/guide.md", 0, &[], vec![]),
    ]);
    let right_batch = batch(vec![
        file("Exercises Database/Push Up/guide.md", base, right, vec![c]),
        file("Exercises Database/Mac/guide.md", 0, &[], vec![]),
    ]);
    let other = router(service.second_state().await);
    let (left_reply, right_reply) = tokio::join!(
        service.json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(left_batch.clone())
        ),
        request(
            other,
            "POST",
            "/v1/sync/commit",
            &service.a,
            serde_json::to_vec(&right_batch).unwrap(),
            "application/json"
        ),
    );
    let (winner, receipt, loser_path) = match (left_reply.status, right_reply.status) {
        (StatusCode::OK, StatusCode::CONFLICT) => {
            assert_eq!(right_reply.body["conflicts"][0]["hash"], auth::digest(left));
            (
                left_batch,
                left_reply.body,
                "Exercises Database/Mac/guide.md",
            )
        }
        (StatusCode::CONFLICT, StatusCode::OK) => {
            assert_eq!(left_reply.body["conflicts"][0]["hash"], auth::digest(right));
            (
                right_batch,
                right_reply.body,
                "Exercises Database/Phone/guide.md",
            )
        }
        states => panic!("Expected one winner and one atomic conflict, got {states:?}"),
    };
    let manifest = service
        .json("GET", "/v1/sync/manifest", &service.a, None)
        .await
        .expect(200);
    assert!(
        !manifest["files"]
            .as_array()
            .unwrap()
            .iter()
            .any(|file| file["path"] == loser_path)
    );
    let winning_revision = receipt["files"][0]["revision"].as_i64().unwrap();
    let tombstone = batch(vec![deletion(
        "Exercises Database/Push Up/guide.md",
        winning_revision,
    )]);
    let deleted = service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(tombstone.clone()),
        )
        .await
        .expect(200);
    service.reopen().await;
    let retried = service
        .json("POST", "/v1/sync/commit", &service.a, Some(winner))
        .await
        .expect(200);
    assert_eq!(retried, receipt);
    let deleted_retry = service
        .json("POST", "/v1/sync/commit", &service.a, Some(tombstone))
        .await
        .expect(200);
    assert_eq!(deleted_retry, deleted);
    let after = service
        .json("GET", "/v1/sync/manifest", &service.a, None)
        .await
        .expect(200);
    assert_eq!(after["cursor"], deleted["cursor"]);
    let guide = after["files"]
        .as_array()
        .unwrap()
        .iter()
        .find(|file| file["path"] == "Exercises Database/Push Up/guide.md")
        .unwrap();
    assert_eq!(guide["deleted"], true);
    assert_eq!(guide["hash"], Value::Null);
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![
                file("Exercises Database/Push Up/guide.md", 0, &[], vec![]),
                file("Exercises Database/Partial/guide.md", 0, &[], vec![]),
            ])),
        )
        .await
        .expect(409);
    let after = service
        .json("GET", "/v1/sync/manifest", &service.a, None)
        .await
        .expect(200);
    assert!(
        !after["files"]
            .as_array()
            .unwrap()
            .iter()
            .any(|file| file["path"] == "Exercises Database/Partial/guide.md")
    );
}

#[tokio::test]
async fn manifest_pages_include_tombstones_without_skipping_other_concurrent_changes() {
    let service = Service::new().await;
    let initial = service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![
                file("Exercises Database/A/guide.md", 0, &[], vec![]),
                file("Exercises Database/B/guide.md", 0, &[], vec![]),
            ])),
        )
        .await
        .expect(200);
    let first = service
        .json(
            "GET",
            "/v1/sync/manifest?cursor=0&limit=1",
            &service.a,
            None,
        )
        .await
        .expect(200);
    assert_eq!(first["files"][0]["path"], "Exercises Database/A/guide.md");
    assert_eq!(first["hasMore"], true);
    let a_revision = initial["files"][0]["revision"].as_i64().unwrap();
    let deleted = service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![deletion(
                "Exercises Database/A/guide.md",
                a_revision,
            )])),
        )
        .await
        .expect(200);
    let cursor = first["cursor"].as_i64().unwrap();
    let next = service
        .json(
            "GET",
            &format!("/v1/sync/manifest?cursor={cursor}&limit=1"),
            &service.a,
            None,
        )
        .await
        .expect(200);
    assert_eq!(next["files"][0]["path"], "Exercises Database/B/guide.md");
    assert_eq!(next["hasMore"], true);
    let cursor = next["cursor"].as_i64().unwrap();
    let last = service
        .json(
            "GET",
            &format!("/v1/sync/manifest?cursor={cursor}&limit=1"),
            &service.a,
            None,
        )
        .await
        .expect(200);
    assert_eq!(last["files"][0]["deleted"], true);
    assert_eq!(last["cursor"], deleted["cursor"]);
    assert_eq!(last["hasMore"], false);
}

#[tokio::test]
async fn out_of_scope_paths_traversals_and_unbounded_metadata_are_rejected_before_publication() {
    let service = Service::new().await;
    for path in [
        "/Exercises Database/A/guide.md",
        "Exercises Database/../Config/secrets.json",
        "Exercises Database/escape/../../never-upload.txt",
        "Exercises Database/./guide.md",
        "Exercises Database//guide.md",
        "Exercises Database/A\\guide.md",
        "Media/../never-upload.txt",
        "Config/secrets.json",
        "Exercises Database/A\0guide.md",
    ] {
        service
            .json(
                "POST",
                "/v1/sync/commit",
                &service.a,
                Some(batch(vec![file(path, 0, &[], vec![])])),
            )
            .await
            .expect(422);
    }
    let too_long = format!("Exercises Database/{}/guide.md", "a".repeat(256));
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![file(&too_long, 0, &[], vec![])])),
        )
        .await
        .expect(422);
    let too_many: Vec<_> = (0..101)
        .map(|index| {
            file(
                &format!("Exercises Database/{index}/guide.md"),
                0,
                &[],
                vec![],
            )
        })
        .collect();
    service
        .json("POST", "/v1/sync/commit", &service.a, Some(batch(too_many)))
        .await
        .expect(422);
    let duplicate = file("Exercises Database/A/guide.md", 0, &[], vec![]);
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![duplicate.clone(), duplicate])),
        )
        .await
        .expect(422);
    assert_eq!(
        service
            .json("GET", "/v1/sync/manifest", &service.a, None)
            .await
            .expect(200)["files"],
        json!([])
    );
}

#[tokio::test]
async fn corrupted_storage_cannot_be_served_or_published_as_a_valid_file() {
    let service = Service::new().await;
    let bytes = b"original private cover";
    let hash = service.chunk(&service.a, bytes).await;
    service.upstream.objects.lock().insert(
        cloud::Supabase::object_name(OWNER_A, &hash),
        Bytes::from_static(b"corrupted cloud object"),
    );
    service
        .json("GET", &format!("/v1/sync/blobs/{hash}"), &service.a, None)
        .await
        .expect(502);
    service
        .json(
            "POST",
            "/v1/sync/commit",
            &service.a,
            Some(batch(vec![file(
                "Exercises Database/A/cover.jpg",
                0,
                bytes,
                vec![hash],
            )])),
        )
        .await
        .expect(502);
    assert_eq!(
        service
            .json("GET", "/v1/sync/manifest", &service.a, None)
            .await
            .expect(200)["files"],
        json!([])
    );
}
