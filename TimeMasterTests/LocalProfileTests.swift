import XCTest
@testable import TimeMaster

final class LocalProfileTests: XCTestCase {
    func testVisitorVisibilityTracksPrivacyAudienceAndHiddenTabs() {
        var snapshot = LocalProfileSnapshot()
        snapshot.profile.isPrivate = false
        snapshot.profile.showPostsToVisitors = true
        snapshot.profile.showRepostsToVisitors = true
        let visible = LocalProfilePost(body: "Profile post")
        let privatePost = LocalProfilePost(body: "Private post", audience: .onlyMe)
        snapshot.posts = [visible, privatePost]
        snapshot.repostedIDs = [visible.id, privatePost.id]
        XCTAssertEqual(snapshot.visiblePosts(asVisitor: true).map(\.id), [visible.id])
        snapshot.profile.showPostsToVisitors = false
        XCTAssertTrue(snapshot.visiblePosts(asVisitor: true).isEmpty)
        XCTAssertEqual(snapshot.visiblePosts(asVisitor: true, repostsOnly: true).map(\.id), [visible.id])
        snapshot.profile.showRepostsToVisitors = false
        XCTAssertNil(visibleLocalPost(id: visible.id, in: snapshot, asVisitor: true))
        snapshot.profile.isPrivate = true
        snapshot.profile.showPostsToVisitors = true
        snapshot.profile.showRepostsToVisitors = true
        XCTAssertTrue(snapshot.visiblePosts(asVisitor: true).isEmpty)
        XCTAssertTrue(snapshot.visiblePosts(asVisitor: true, repostsOnly: true).isEmpty)
        XCTAssertEqual(Set(snapshot.visiblePosts(asVisitor: false).map(\.id)), [visible.id, privatePost.id])
    }

    @MainActor
    func testDeletingPostRemovesItsRepliesAndRepostWithoutChangingOtherPosts() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = LocalProfileStore(fileURL: url)
        let first = try store.publish(body: "Delete me", imageFilename: nil, audience: .profile, allowsReplies: true)
        let second = try store.publish(body: "Keep me", imageFilename: nil, audience: .onlyMe, allowsReplies: true)
        try store.addReply(postID: first, body: "First reply")
        try store.addReply(postID: second, body: "Keep this reply")
        try store.toggleRepost(postID: first)
        try store.toggleRepost(postID: second)
        try store.deletePost(id: first)
        let restored = LocalProfileStore(fileURL: url)
        XCTAssertEqual(restored.snapshot.posts.map(\.id), [second])
        XCTAssertEqual(restored.snapshot.posts.first?.replies.map(\.body), ["Keep this reply"])
        XCTAssertEqual(restored.snapshot.repostedIDs, [second])
        XCTAssertThrowsError(try restored.addReply(postID: first, body: "Stale reply"))
        var profile = restored.profile
        profile.allowReplies = false
        try restored.updateProfile(profile)
        XCTAssertThrowsError(try restored.addReply(postID: second, body: "Disabled reply"))
        XCTAssertEqual(restored.snapshot.posts.first?.replies.map(\.body), ["Keep this reply"])
    }

    @MainActor
    func testFailedDiskWriteDoesNotPublishOrDeleteInMemory() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalProfileStore(fileURL: directory.appendingPathComponent("profile.json"))
        let existing = try store.publish(body: "Already saved", imageFilename: nil, audience: .profile, allowsReplies: true)
        try FileManager.default.removeItem(at: directory)
        try Data("Write barrier".utf8).write(to: directory)
        XCTAssertThrowsError(try store.publish(body: "Must not appear", imageFilename: nil, audience: .profile, allowsReplies: true))
        XCTAssertThrowsError(try store.deletePost(id: existing))
        XCTAssertEqual(store.snapshot.posts.map(\.id), [existing])
        XCTAssertEqual(store.snapshot.posts.first?.body, "Already saved")
        XCTAssertEqual(try Data(contentsOf: directory), Data("Write barrier".utf8))
    }

    @MainActor
    func testCorruptFileIsPreservedAndLockedUntilSuccessfulReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("profile.json")
        let corrupt = Data("{unfinished".utf8)
        try corrupt.write(to: url)
        let store = LocalProfileStore(fileURL: url)
        var edited = store.profile
        edited.displayName = "Must not overwrite"
        XCTAssertTrue(store.isReadOnly)
        XCTAssertThrowsError(try store.updateProfile(edited))
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        var repaired = LocalProfileSnapshot()
        repaired.profile.displayName = "Recovered profile"
        try LocalProfilePersistence.save(repaired, to: url)
        store.reload()
        XCTAssertFalse(store.isReadOnly)
        XCTAssertEqual(store.profile.displayName, "Recovered profile")
    }

    func testVerificationWindowAndAllThreeEligibilityBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let joined = calendar.date(byAdding: .day, value: -180, to: now)!
        let sessions = (0..<100).map { index in
            LocalTrainingSession(id: "session-\(index)", completedAt: calendar.date(byAdding: .day, value: -(index % 75), to: now)!, isComplete: true)
        }
        let ignored = [
            sessions[0],
            LocalTrainingSession(id: "partial", completedAt: now, isComplete: false),
            LocalTrainingSession(id: "future", completedAt: now.addingTimeInterval(1), isComplete: true),
            LocalTrainingSession(id: "expired", completedAt: joined.addingTimeInterval(-1), isComplete: true)
        ]
        let progress = LocalVerificationProgress(createdAt: joined, sessions: sessions + ignored, now: now, calendar: calendar)
        XCTAssertEqual(progress.completedSessions, 100)
        XCTAssertEqual(progress.activeDays, 75)
        XCTAssertTrue(progress.isEligible)
        XCTAssertFalse(LocalVerificationProgress(createdAt: calendar.date(byAdding: .day, value: -179, to: now)!, sessions: sessions, now: now, calendar: calendar).isEligible)
        XCTAssertFalse(LocalVerificationProgress(createdAt: joined, sessions: Array(sessions.dropLast()), now: now, calendar: calendar).isEligible)
        let fewerDays = sessions.filter { $0.id != "session-74" } + [LocalTrainingSession(id: "replacement", completedAt: now, isComplete: true)]
        let dayBoundary = LocalVerificationProgress(createdAt: joined, sessions: fewerDays, now: now, calendar: calendar)
        XCTAssertEqual(dayBoundary.completedSessions, 100)
        XCTAssertEqual(dayBoundary.activeDays, 74)
        XCTAssertFalse(dayBoundary.isEligible)
    }

    func testBackupMergeKeepsLocalPreferencesAndNeverExposesImportedPrivatePosts() {
        var local = LocalProfileSnapshot()
        local.profile.displayName = "Current profile"
        local.profile.isPrivate = false
        local.profile.showActivityToVisitors = true
        let existing = LocalProfilePost(body: "Keep local edit")
        local.posts = [existing]
        var imported = LocalProfileSnapshot()
        imported.profile.isPrivate = true
        let privatePost = LocalProfilePost(body: "Imported private content")
        var staleCopy = existing
        staleCopy.body = "Stale backup copy"
        imported.posts = [staleCopy, privatePost]
        imported.repostedIDs = [privatePost.id]
        let merged = local.merging(imported).merging(imported)
        XCTAssertEqual(merged.profile.id, local.profile.id)
        XCTAssertTrue(merged.profile.showActivityToVisitors)
        XCTAssertEqual(merged.posts.first(where: { $0.id == existing.id })?.body, "Keep local edit")
        XCTAssertEqual(merged.posts.count, 2)
        XCTAssertEqual(merged.visiblePosts(asVisitor: true).map(\.id), [existing.id])
        XCTAssertTrue(merged.visiblePosts(asVisitor: true, repostsOnly: true).isEmpty)
        var configuredEmpty = LocalProfileSnapshot()
        configuredEmpty.profile.isPrivate = false
        XCTAssertFalse(configuredEmpty.merging(imported).profile.isPrivate)
        XCTAssertEqual(LocalProfileSnapshot().merging(imported).profile.id, imported.profile.id)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LocalProfileTests-\(UUID().uuidString)")
    }
}
