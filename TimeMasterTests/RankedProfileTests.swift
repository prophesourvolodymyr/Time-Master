import XCTest
@testable import TimeMaster

final class RankedProfileTests: XCTestCase {
    @MainActor
    func testLegacyLevelsSurviveProfileEditsWithoutBecomingEarnedRatings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        var snapshot = LocalProfileSnapshot()
        snapshot.profile.displayName = "Existing athlete"
        snapshot.posts = [LocalProfilePost(body: "Keep my post")]
        snapshot.cosmeticSelections = ["frame": "orbit"]
        snapshot.savedCollectibleIDs = ["original"]
        snapshot.legacyRankedLevels = LegacyRankedLevels(overall: 99_999, variations: ["leftSidePlank": 1200, "rightSidePlank": 1600])
        try LocalProfilePersistence.save(snapshot, to: url)
        let store = LocalProfileStore(fileURL: url)
        XCTAssertFalse(store.isReadOnly)
        var edited = store.profile
        edited.biography = "Still my profile"
        try store.updateProfile(edited)
        let reloaded = try XCTUnwrap(LocalProfilePersistence.load(from: url))
        XCTAssertEqual(reloaded.profile.id, snapshot.profile.id)
        XCTAssertEqual(reloaded.profile.biography, "Still my profile")
        XCTAssertEqual(reloaded.posts.map(\.id), snapshot.posts.map(\.id))
        XCTAssertEqual(reloaded.posts.map(\.body), snapshot.posts.map(\.body))
        XCTAssertEqual(reloaded.cosmeticSelections, snapshot.cosmeticSelections)
        XCTAssertEqual(reloaded.savedCollectibleIDs, snapshot.savedCollectibleIDs)
        XCTAssertEqual(reloaded.legacyRankedLevels, snapshot.legacyRankedLevels)
        XCTAssertFalse(reloaded.profile.visibleTabs.contains(.ranked))
    }

    func testHistoricalBackupMergePreservesIdentityAndArchivedLevels() {
        var local = LocalProfileSnapshot()
        local.profile.displayName = "Local identity"
        local.legacyRankedLevels = LegacyRankedLevels(overall: 1400)
        var imported = LocalProfileSnapshot()
        imported.profile.displayName = "Backup identity"
        imported.legacyRankedLevels = LegacyRankedLevels(overall: 2200)
        imported.posts = [LocalProfilePost(body: "Private backup post")]
        let merged = local.merging(imported)
        XCTAssertEqual(merged.profile, local.profile)
        XCTAssertEqual(merged.legacyRankedLevels?.overall, 1400)
        XCTAssertEqual(merged.posts.first?.audience, .onlyMe)
        let restored = LocalProfileSnapshot().merging(imported)
        XCTAssertEqual(restored.profile, imported.profile)
        XCTAssertEqual(restored.legacyRankedLevels, imported.legacyRankedLevels)
    }

    @MainActor
    func testNavigationUpgradePreservesUserOrderAndLaterRankedRemoval() {
        let suite = "RankedNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["settings", "home", "profile"], forKey: "tm.navigation.order.v1")
        defaults.set(true, forKey: "tm.navigation.scheduleSettingsAdded")
        let first = SlotNavigationLayoutStore(defaults: defaults)
        XCTAssertEqual(first.order, [.settings, .home, .ranked, .profile])
        first.remove(id: "ranked")
        let second = SlotNavigationLayoutStore(defaults: defaults)
        XCTAssertEqual(second.order, [.settings, .home, .profile])
        XCTAssertTrue(second.catalog.contains { $0.id == "ranked" && !$0.isPending })
    }
}
