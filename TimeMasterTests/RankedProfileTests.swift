import XCTest
@testable import TimeMaster

final class RankedProfileTests: XCTestCase {
    @MainActor
    func testOlderProfileAcceptsIndependentLevelsAndClearingWithoutLosingIdentityOrPosts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        var snapshot = LocalProfileSnapshot()
        snapshot.profile.displayName = "Existing athlete"
        snapshot.profile.isPrivate = false
        snapshot.posts = [LocalProfilePost(body: "Keep my post")]
        snapshot.cosmeticSelections = ["frame": "orbit"]
        try LocalProfilePersistence.save(snapshot, to: url)
        let store = LocalProfileStore(fileURL: url)
        let existing = store.snapshot
        XCTAssertNil(store.rankedLevels.overall)
        XCTAssertNil(store.rankedLevels[.standardPushUp])
        var levels = store.rankedLevels
        levels.overall = 1_400
        levels[.standardPushUp] = 1_100
        levels[.wideSquat] = 1_800
        levels[.forearmPlank] = 900
        levels[.leftSidePlank] = 1_200
        levels[.rightSidePlank] = 1_600
        try store.updateRankedLevels(levels)
        let reloaded = LocalProfileStore(fileURL: url)
        XCTAssertEqual(reloaded.rankedLevels, levels)
        XCTAssertEqual(reloaded.profile, existing.profile)
        XCTAssertEqual(reloaded.snapshot.posts, existing.posts)
        XCTAssertEqual(reloaded.snapshot.cosmeticSelections, existing.cosmeticSelections)
        levels[.standardPushUp] = nil
        levels[.leftSidePlank] = nil
        try reloaded.updateRankedLevels(levels)
        let cleared = LocalProfileStore(fileURL: url)
        XCTAssertNil(cleared.rankedLevels[.standardPushUp])
        XCTAssertEqual(cleared.rankedLevels.overall, 1_400)
        XCTAssertEqual(cleared.rankedLevels[.wideSquat], 1_800)
        XCTAssertEqual(cleared.rankedLevels[.forearmPlank], 900)
        XCTAssertNil(cleared.rankedLevels[.leftSidePlank])
        XCTAssertEqual(cleared.rankedLevels[.rightSidePlank], 1_600)
        XCTAssertFalse(cleared.profile.visibleTabs.contains(.ranked))
    }

    @MainActor
    func testInvalidLevelsDoNotReplaceSavedLevels() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = LocalProfileStore(fileURL: url)
        let valid = RankedLevels(overall: 1_000, variations: [RankedVariation.standardSquat.rawValue: 1_400])
        try store.updateRankedLevels(valid)
        let data = try Data(contentsOf: url)
        XCTAssertThrowsError(try store.updateRankedLevels(RankedLevels(overall: -1)))
        XCTAssertThrowsError(try store.updateRankedLevels(RankedLevels(overall: 5_001)))
        XCTAssertThrowsError(try store.updateRankedLevels(RankedLevels(variations: ["unknown": 1_000])))
        XCTAssertEqual(store.rankedLevels, valid)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testBackupMergeKeepsChosenLocalLevelsButRestoresIntoAnEmptyProfile() {
        var local = LocalProfileSnapshot()
        local.rankedLevels = RankedLevels(overall: 1_400)
        var imported = LocalProfileSnapshot()
        imported.profile.displayName = "Backup identity"
        imported.rankedLevels = RankedLevels(overall: 2_200)
        let merged = local.merging(imported)
        XCTAssertEqual(merged.profile.id, local.profile.id)
        XCTAssertEqual(merged.rankedLevels?.overall, 1_400)
        let restored = LocalProfileSnapshot().merging(imported)
        XCTAssertEqual(restored.profile.id, imported.profile.id)
        XCTAssertEqual(restored.rankedLevels?.overall, 2_200)
    }

    @MainActor
    func testOutOfRangeStoredLevelIsPreservedWithoutOpeningAnEditableProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        var invalid = LocalProfileSnapshot()
        invalid.rankedLevels = RankedLevels(overall: 99_999)
        try LocalProfilePersistence.save(invalid, to: url)
        let original = try Data(contentsOf: url)
        let store = LocalProfileStore(fileURL: url)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertThrowsError(try store.updateRankedLevels(RankedLevels(overall: 1_000)))
        XCTAssertEqual(try Data(contentsOf: url), original)
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
