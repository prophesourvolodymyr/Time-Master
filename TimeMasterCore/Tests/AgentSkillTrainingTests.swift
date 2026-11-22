import XCTest
@testable import TimeMasterCore

final class AgentSkillTrainingTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("skill-training-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Calisthenics", "workoutType": "Strength"])["id"] as! String
        try call("create_skill_page", ["title": "Handstand", "parent": folder])
        try call("create_skill_page", ["title": "Planche", "parent": folder])
        for title in ["Wall Walk", "Pike Push-up", "Wrist Circles"] {
            try call("create_exercise_page", ["title": title, "parent": folder, "duration": 30])
        }
        try call("create_container_page", ["title": "Notes Folder", "parent": folder])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    private func page(_ reference: String) throws -> ExercisePageManifest {
        try database.getPage(id: try AgentPageIndex(database: database).resolve(reference).id)
    }

    private func entries(_ pairs: [(String, String)]) -> [[String: Any]] {
        pairs.map { ["exercise": "Calisthenics/\($0.0)", "tier": $0.1] }
    }

    func testAnExercisePageKeepsTheSkillsItTrainsAndOlderFilesReadWithoutThem() throws {
        let skill = try page("Calisthenics/Handstand")
        var exercise = try page("Calisthenics/Wall Walk")
        exercise.trains = [SkillTraining(skillID: skill.id, tier: .a)]
        try database.updatePage(id: exercise.id, manifest: exercise, newParentID: exercise.parentID)

        let reread = try page("Calisthenics/Wall Walk")
        XCTAssertEqual(reread.trains, [SkillTraining(skillID: skill.id, tier: .a)])

        let plain = try JSONEncoder().encode(try page("Calisthenics/Pike Push-up"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        XCTAssertNil(object["trains"], "a page that trains nothing writes nothing")
        XCTAssertTrue(try JSONDecoder().decode(ExercisePageManifest.self, from: plain).trains.isEmpty)
    }

    func testOneCallFillsASkillWithTiersAndReportsWhatChanged() throws {
        let result = try call("set_skill_training", [
            "skill": "Calisthenics/Handstand",
            "exercises": entries([("Wall Walk", "S"), ("Pike Push-up", "b"), ("Wrist Circles", "D")]),
        ])

        XCTAssertEqual(result["added"] as? Int, 3)
        XCTAssertEqual(result["total"] as? Int, 3)
        let listing = try call("get_skill_training", ["skill": "Calisthenics/Handstand"])
        let tiers = try XCTUnwrap(listing["tiers"] as? [[String: Any]])
        XCTAssertEqual(tiers.map { $0["tier"] as? String }, ["S", "B", "D"])
        XCTAssertEqual(tiers[0]["exercises"] as? [String], ["Calisthenics/Wall Walk"])
        XCTAssertEqual(listing["count"] as? Int, 3)
    }

    func testAnExerciseCanTrainSeveralSkillsAndEachKeepsItsOwnTier() throws {
        try call("set_skill_training", ["skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "S")])])
        try call("set_skill_training", ["skill": "Calisthenics/Planche", "exercises": entries([("Wall Walk", "C")])])

        let links = try page("Calisthenics/Wall Walk").trains
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(Set(links.map(\.tier)), [.s, .c])
    }

    func testListingAgainChangesATierAndLeavesTheRestAloneUnlessReplacing() throws {
        try call("set_skill_training", ["skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "S"), ("Pike Push-up", "B")])])

        let update = try call("set_skill_training", ["skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "A")])])
        XCTAssertEqual(update["updated"] as? Int, 1)
        XCTAssertEqual(update["total"] as? Int, 2)

        let replace = try call("set_skill_training", [
            "skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "A")]), "replace": true,
        ])
        XCTAssertEqual(replace["removed"] as? Int, 1)
        XCTAssertEqual(replace["total"] as? Int, 1)
        XCTAssertTrue(try page("Calisthenics/Pike Push-up").trains.isEmpty)
    }

    func testADryRunChangesNothing() throws {
        let result = try call("set_skill_training", [
            "skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "S")]),
        ], dryRun: true)

        XCTAssertEqual(result["added"] as? Int, 1)
        XCTAssertTrue(try page("Calisthenics/Wall Walk").trains.isEmpty)
    }

    func testOnlyASkillCanBeTrainedAndNotesCannotTrain() throws {
        let notSkill = failure {
            try self.call("set_skill_training", ["skill": "Calisthenics/Wall Walk", "exercises": self.entries([("Pike Push-up", "A")])])
        }
        XCTAssertEqual(notSkill?.code, "invalid_argument")
        let badTier = failure {
            try self.call("set_skill_training", ["skill": "Calisthenics/Handstand", "exercises": self.entries([("Wall Walk", "E")])])
        }
        XCTAssertNotNil(badTier)
        let selfLink = failure {
            try self.call("set_skill_training", ["skill": "Calisthenics/Handstand", "exercises": [["exercise": "Calisthenics/Handstand", "tier": "A"]]])
        }
        XCTAssertEqual(selfLink?.code, "invalid_argument")
    }

    func testUndoPutsBackWhatTheCallChanged() throws {
        let output = try toolbox.call("set_skill_training", arguments: [
            "skill": "Calisthenics/Handstand", "exercises": entries([("Wall Walk", "S"), ("Pike Push-up", "A")]),
        ])
        XCTAssertEqual(output.effects.count, 2)

        toolbox.revert(output.effects)

        XCTAssertTrue(try page("Calisthenics/Wall Walk").trains.isEmpty)
        XCTAssertTrue(try page("Calisthenics/Pike Push-up").trains.isEmpty)
    }
}
