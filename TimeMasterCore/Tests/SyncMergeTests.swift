import XCTest
@testable import TimeMasterCore

final class SyncTextMergeTests: XCTestCase {
    private func merge(_ base: String, _ local: String, _ remote: String) -> (text: String, conflicts: Int) {
        SyncTextMerge.merge(base: base, local: local, remote: remote, localLabel: "Mac", remoteLabel: "iPhone")
    }

    func testChangesToDifferentPlacesMergeCleanly() {
        let result = merge("one\ntwo\nthree\nfour\nfive", "ONE\ntwo\nthree\nfour\nfive", "one\ntwo\nthree\nfour\nFIVE")
        XCTAssertEqual(result.text, "ONE\ntwo\nthree\nfour\nFIVE")
        XCTAssertEqual(result.conflicts, 0)
    }

    func testInsertionsOnBothSidesKeepBoth() {
        XCTAssertEqual(merge("a\nb\nc", "intro\na\nb\nc", "a\nb\nc\noutro").text, "intro\na\nb\nc\noutro")
    }

    func testTheSameLineChangedTwoWaysKeepsBothVersionsInAConflictBlock() {
        let result = merge("a\nb\nc", "a\nB-mac\nc", "a\nB-phone\nc")
        XCTAssertEqual(result.conflicts, 1)
        XCTAssertEqual(result.text, "a\n<<<<<<< Mac\nB-mac\n=======\nB-phone\n>>>>>>> iPhone\nc")
    }

    func testTheSameChangeOnBothSidesIsNotAConflict() {
        let result = merge("a\nb\nc", "a\nX\nc", "a\nX\nc")
        XCTAssertEqual(result.text, "a\nX\nc")
        XCTAssertEqual(result.conflicts, 0)
    }

    func testADeletionAndAnEditElsewhereMerge() {
        XCTAssertEqual(merge("a\nb\nc\nd", "a\nc\nd", "a\nb\nc\nD").text, "a\nc\nD")
    }
}

final class SyncManifestMergeTests: XCTestCase {
    private let pageID = "11111111-1111-1111-1111-111111111111"

    private func page(
        _ title: String = "Scales", body: String = "", status: SkillStatus = .notStarted, media: [String] = [],
        comments: [String: String] = [:], children: [String] = [], sections: [SkillBoardSection] = [], parent: String? = nil,
        sectionID: String? = nil, links: [String] = []
    ) -> ExercisePageManifest {
        var manifest = ExercisePageManifest(
            id: pageID, title: title, pageType: .skill, markdownBody: body, mediaFilenames: media, mediaComments: comments,
            linkURLs: links, skillStatus: status, skillBoardSectionID: sectionID, skillBoardSections: sections,
            childIDs: children, parentID: parent,
            createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        manifest.skillBoardSectionID = sectionID
        return manifest
    }

    private func merge(_ base: ExercisePageManifest?, _ local: ExercisePageManifest, _ remote: ExercisePageManifest, preferRemote: Bool = false) throws -> ExercisePageManifest {
        try SyncManifestMerge.merge(base: base, local: local, remote: remote, preferRemote: preferRemote, localLabel: "Mac", remoteLabel: "iPhone").manifest
    }

    func testDifferentFieldsChangedOnEachSideBothSurvive() throws {
        let base = page()
        var local = base
        local.title = "Major scales"
        var remote = base
        remote.skillStatus = .completed
        let merged = try merge(base, local, remote)
        XCTAssertEqual(merged.title, "Major scales")
        XCTAssertEqual(merged.skillStatus, .completed)
    }

    func testTheSameSingleValueChangedTwoWaysTakesThePreferredSide() throws {
        let base = page("Scales")
        var local = base
        local.title = "Mac title"
        var remote = base
        remote.title = "Phone title"
        XCTAssertEqual(try merge(base, local, remote, preferRemote: false).title, "Mac title")
        XCTAssertEqual(try merge(base, local, remote, preferRemote: true).title, "Phone title")
    }

    func testSectionsMergeItemByItem() throws {
        let base = page(sections: [SkillBoardSection(id: "a", title: "Warm up", order: 0), SkillBoardSection(id: "b", title: "Scales", order: 1)])
        var local = base
        local.skillBoardSections[0].title = "Warm up slowly"
        local.skillBoardSections.append(SkillBoardSection(id: "c", title: "Mac-only", order: 2))
        var remote = base
        remote.skillBoardSections.remove(at: 1)
        remote.skillBoardSections.append(SkillBoardSection(id: "d", title: "Phone-only", order: 2))
        let merged = try merge(base, local, remote)
        XCTAssertEqual(Set(merged.skillBoardSections.map(\.id)), ["a", "c", "d"])
        XCTAssertEqual(merged.skillBoardSections.first { $0.id == "a" }?.title, "Warm up slowly")
        XCTAssertEqual(merged.skillBoardSections.map(\.order).sorted(), [0, 1, 2])
    }

    func testAnEditBeatsARemovalOfTheSameItem() throws {
        let base = page(sections: [SkillBoardSection(id: "a", title: "Warm up", order: 0)])
        var local = base
        local.skillBoardSections[0].title = "Warm up slowly"
        var remote = base
        remote.skillBoardSections = []
        XCTAssertEqual(try merge(base, local, remote).skillBoardSections.map(\.title), ["Warm up slowly"])
    }

    func testMediaAddedOnBothSidesAreAllKeptWithTheirComments() throws {
        let base = page()
        var local = base
        local.mediaFilenames = ["mac.jpg"]
        local.mediaComments = ["mac.jpg": "from the Mac"]
        var remote = base
        remote.mediaFilenames = ["phone.jpg"]
        remote.mediaComments = ["phone.jpg": "from the phone"]
        let merged = try merge(base, local, remote)
        XCTAssertEqual(Set(merged.mediaFilenames), ["mac.jpg", "phone.jpg"])
        XCTAssertEqual(merged.mediaComments, ["mac.jpg": "from the Mac", "phone.jpg": "from the phone"])
    }

    func testChildListsMergeAsOrderedSets() throws {
        let base = page(children: ["x", "y", "z"])
        var local = base
        local.childIDs = ["x", "y", "z", "mac-new"]
        var remote = base
        remote.childIDs = ["x", "z", "phone-new"]
        let merged = try merge(base, local, remote)
        XCTAssertEqual(Set(merged.childIDs), ["x", "z", "mac-new", "phone-new"])
        XCTAssertFalse(merged.childIDs.contains("y"))
    }

    func testNotesEditedAtDifferentPlacesMerge() throws {
        let base = page(body: "# Plan\n\nWarm up\n\nPlay scales\n\nCool down")
        var local = base
        local.markdownBody = "# Plan\n\nWarm up 10 min\n\nPlay scales\n\nCool down"
        var remote = base
        remote.markdownBody = "# Plan\n\nWarm up\n\nPlay scales\n\nCool down and stretch"
        XCTAssertEqual(try merge(base, local, remote).markdownBody, "# Plan\n\nWarm up 10 min\n\nPlay scales\n\nCool down and stretch")
    }

    func testAPlaceIsOneFactEvenWhenTheDevicesChangedDifferentFields() throws {
        let base = page(parent: "p1", sectionID: nil)
        var local = base
        local.parentID = "p2"
        var remote = base
        remote.skillBoardSectionID = "s1"
        let merged = try merge(base, local, remote)
        XCTAssertEqual(merged.parentID, "p2")
        XCTAssertNil(merged.skillBoardSectionID, "the section belongs to the place the other device moved the page away from")
        let other = try merge(base, remote, local, preferRemote: true)
        XCTAssertEqual(other.parentID, "p2")
        XCTAssertNil(other.skillBoardSectionID)
    }

    func testTwoDevicesMovingThePageSomewhereTakeTheNewerPlaceWhole() throws {
        let base = page(parent: "p1", sectionID: "s1")
        var local = base
        local.parentID = "p2"
        local.skillBoardSectionID = nil
        var remote = base
        remote.parentID = "p3"
        remote.skillBoardSectionID = "s9"
        let merged = try merge(base, local, remote, preferRemote: true)
        XCTAssertEqual(merged.parentID, "p3")
        XCTAssertEqual(merged.skillBoardSectionID, "s9")
    }

    func testACoverThatTheOtherSideRemovedIsDropped() throws {
        let base = page(media: ["a.jpg"])
        var local = base
        local.coverMediaFilename = "a.jpg"
        var remote = base
        remote.mediaFilenames = []
        XCTAssertNil(try merge(base, local, remote).coverMediaFilename)
    }

    func testWithoutACommonAncestorBothSidesAreUnitedAndTheNewerWinsTheRest() throws {
        var local = page("Mac")
        local.mediaFilenames = ["a.jpg"]
        var remote = page("Phone")
        remote.mediaFilenames = ["b.jpg"]
        let merged = try merge(nil, local, remote, preferRemote: true)
        XCTAssertEqual(merged.title, "Phone")
        XCTAssertEqual(Set(merged.mediaFilenames), ["a.jpg", "b.jpg"])
    }
}

final class SyncOpaqueMergeTests: XCTestCase {
    func testWorkoutSectionsAndSlotsMergeByIdentity() {
        let base = #"{"id":"w","name":"Full body","sections":[{"id":"s1","name":"Push-ups","duration":30,"slots":[{"id":"a","name":"Set A"}]},{"id":"s2","name":"Squats","duration":30,"slots":[]}]}"#
        let local = #"{"id":"w","name":"Full body","sections":[{"id":"s1","name":"Push-ups","duration":45,"slots":[{"id":"a","name":"Set A"}]},{"id":"s2","name":"Squats","duration":30,"slots":[]}]}"#
        let remote = #"{"id":"w","name":"Full body!","sections":[{"id":"s1","name":"Push-ups","duration":30,"slots":[{"id":"a","name":"Set A"},{"id":"b","name":"Set B"}]},{"id":"s2","name":"Squats","duration":30,"slots":[]},{"id":"s3","name":"Plank","duration":60,"slots":[]}]}"#
        let merged = SyncOpaqueMerge.merge(base: base, local: local, remote: remote, preferRemote: true, localLabel: "Mac", remoteLabel: "iPhone")
        let object = SyncJSON.parse(merged.text) as? [String: Any]
        XCTAssertEqual(object?["name"] as? String, "Full body!")
        let sections = object?["sections"] as? [[String: Any]]
        XCTAssertEqual(sections?.map { $0["id"] as? String }, ["s1", "s2", "s3"])
        XCTAssertEqual(sections?[0]["duration"] as? Int, 45)
        XCTAssertEqual((sections?[0]["slots"] as? [[String: Any]])?.count, 2)
    }

    func testLongBase64IsNeverTextMerged() {
        let a = String(repeating: "QUJD", count: 100)
        let b = String(repeating: "REVG", count: 100)
        let merged = SyncOpaqueMerge.merge(base: nil, local: "{\"snapshot\":\"\(a)\"}", remote: "{\"snapshot\":\"\(b)\"}", preferRemote: true, localLabel: "Mac", remoteLabel: "iPhone")
        XCTAssertEqual((SyncJSON.parse(merged.text) as? [String: Any])?["snapshot"] as? String, b)
        XCTAssertEqual(merged.conflicts, 0)
    }

    func testSchedulesMergeEntriesAndSets() {
        let base = #"{"restDays":["2026-01-01"],"trainingDays":[1,3],"workoutSchedule":{"plans":[{"id":"p","name":"My Plan","entries":[{"id":"e1","title":"Run"}]}]}}"#
        let local = #"{"restDays":["2026-01-01","2026-01-02"],"trainingDays":[1,3],"workoutSchedule":{"plans":[{"id":"p","name":"My Plan","entries":[{"id":"e1","title":"Run"},{"id":"e2","title":"Swim"}]}]}}"#
        let remote = #"{"restDays":["2026-01-01"],"trainingDays":[1,3,5],"workoutSchedule":{"plans":[{"id":"p","name":"My Plan","entries":[{"id":"e1","title":"Run"},{"id":"e3","title":"Lift"}]}]}}"#
        let text = SyncConfigMerge.merge(base: base, local: local, remote: remote, preferRemote: true)
        let object = SyncJSON.parse(text) as? [String: Any]
        XCTAssertEqual(Set((object?["restDays"] as? [String]) ?? []), ["2026-01-01", "2026-01-02"])
        XCTAssertEqual(Set((object?["trainingDays"] as? [Int]) ?? []), [1, 3, 5])
        let plans = object?["workoutSchedule"] as? [String: Any]
        let entries = ((plans?["plans"] as? [[String: Any]])?.first?["entries"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
        XCTAssertEqual(Set(entries ?? []), ["e1", "e2", "e3"])
    }
}
