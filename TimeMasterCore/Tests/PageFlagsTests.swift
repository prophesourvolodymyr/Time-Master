import XCTest
@testable import TimeMasterCore

final class PageFlagsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pageflags-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
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

    private func roundTrip(_ manifest: ExercisePageManifest) throws -> ExercisePageManifest {
        try JSONDecoder().decode(ExercisePageManifest.self, from: try JSONEncoder().encode(manifest))
    }

    // MARK: Which widgets show

    func testAutomaticShowsOnlyThePagesOwnTilesThatHaveSomethingToShow() {
        let withContent: Set<PageWidgetKind> = [.clips, .folder, .todos, .workouts]
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: .tutorial, noSkills: false) { withContent.contains($0) }, [.clips, .todos, .workouts])
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: .exercise, noSkills: false) { _ in false }, [])
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: nil, noSkills: false) { _ in true }, [.clips, .folder, .progress, .workouts])
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: .note, noSkills: false) { _ in true }, [])
    }

    func testNoSkillsLeavesOutTheSubSkillTilesEvenWhenTheyHaveSomethingToShow() {
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: .skill, noSkills: true) { _ in true }, [.clips, .workouts])
        XCTAssertEqual(PageWidgetSelection.automatic.resolved(for: nil, noSkills: true) { _ in true }, [.clips, .folder, .workouts])
        let chosen = PageWidgetSelection.chosen([.milestones, .clips, .learnFirst, .workouts, .progress, .todos])
        XCTAssertEqual(chosen.resolved(for: .tutorial, noSkills: true) { _ in true }, [.clips, .workouts])
    }

    func testAnEmptyListShowsNoStrip() {
        XCTAssertEqual(PageWidgetSelection(stored: []), .hidden)
        XCTAssertEqual(PageWidgetSelection.hidden.resolved(for: .skill, noSkills: false) { _ in true }, [])
    }

    func testAChosenListKeepsItsOrderAndItsEmptyTilesButOnlyWhatThePageCanShow() {
        let chosen = PageWidgetSelection(stored: ["workouts", "milestones", "folder", "clips", "milestones", "sparkles"])
        XCTAssertEqual(chosen, .chosen([.workouts, .milestones, .folder, .clips]))
        XCTAssertEqual(chosen.resolved(for: .skill, noSkills: false) { _ in false }, [.workouts, .milestones, .clips])
        XCTAssertEqual(chosen.resolved(for: .exercise, noSkills: false) { _ in false }, [.workouts, .clips])
        XCTAssertEqual(chosen.resolved(for: nil, noSkills: false) { _ in false }, [.workouts, .folder, .clips])
    }

    func testASelectionStoresWhatItReads() {
        XCTAssertEqual(PageWidgetSelection(stored: nil), .automatic)
        XCTAssertNil(PageWidgetSelection.automatic.stored)
        XCTAssertEqual(PageWidgetSelection.hidden.stored, [])
        XCTAssertEqual(PageWidgetSelection.chosen([.todos, .clips, .todos]).stored, ["todos", "clips"])
        var manifest = ExercisePageManifest(title: "Lateral switch step", pageType: .tutorial)
        manifest.widgetSelection = .chosen([.clips])
        XCTAssertEqual(manifest.widgets, ["clips"])
        manifest.widgetSelection = .automatic
        XCTAssertNil(manifest.widgets)
    }

    func testSwitchingATileOnKeepsTheOrderOfTheList() {
        XCTAssertEqual([PageWidgetKind.clips, .todos].settingWidget(.progress, shown: true), [.clips, .progress, .todos])
        XCTAssertEqual([PageWidgetKind.workouts, .clips].settingWidget(.todos, shown: true), [.workouts, .clips, .todos])
        XCTAssertEqual([PageWidgetKind.todos].settingWidget(.clips, shown: true), [.clips, .todos])
        XCTAssertEqual([PageWidgetKind.clips].settingWidget(.clips, shown: true), [.clips])
        XCTAssertEqual([PageWidgetKind.clips, .todos].settingWidget(.clips, shown: false), [.todos])
    }

    // MARK: Manifest files

    func testAPageWrittenBeforeTheFlagsReadsAsAutomaticAndWritesNoFlagKeys() throws {
        let old = """
        {"id":"p1","title":"Lateral switch step","pageKind":"container","pageType":"tutorial","markdownBody":"Step left, switch.","mediaFilenames":["reel.mp4"],"skillStatus":"learning","childIDs":[],"order":3}
        """
        let manifest = try JSONDecoder().decode(ExercisePageManifest.self, from: Data(old.utf8))
        XCTAssertNil(manifest.noSkills)
        XCTAssertNil(manifest.widgets)
        XCTAssertFalse(manifest.hidesSkills)
        XCTAssertEqual(manifest.widgetSelection, .automatic)
        let written = String(decoding: try JSONEncoder().encode(manifest), as: UTF8.self)
        XCTAssertFalse(written.contains("noSkills"))
        XCTAssertFalse(written.contains("widgets"))
        XCTAssertEqual(try roundTrip(manifest).markdownBody, "Step left, switch.")
    }

    func testTheFlagsRoundTripAndAnEmptyListStaysApartFromAutomatic() throws {
        var manifest = ExercisePageManifest(title: "Reel", pageType: .tutorial, noSkills: true, widgets: [])
        var decoded = try roundTrip(manifest)
        XCTAssertEqual(decoded.noSkills, true)
        XCTAssertEqual(decoded.widgets, [])
        XCTAssertEqual(decoded.widgetSelection, .hidden)

        manifest.widgets = ["workouts", "clips"]
        decoded = try roundTrip(manifest)
        XCTAssertEqual(decoded.widgets, ["workouts", "clips"])

        let cleared = ExercisePageManifest(title: "Reel", pageType: .tutorial, noSkills: false)
        XCTAssertNil(cleared.noSkills)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(cleared), as: UTF8.self).contains("noSkills"))
    }

    func testFlagsOfAnotherShapeAreIgnoredWithoutLosingThePage() throws {
        let odd = """
        {"id":"p2","title":"Odd","pageType":"skill","noSkills":"yes","widgets":"clips","markdownBody":"kept"}
        """
        let manifest = try JSONDecoder().decode(ExercisePageManifest.self, from: Data(odd.utf8))
        XCTAssertNil(manifest.noSkills)
        XCTAssertNil(manifest.widgets)
        XCTAssertEqual(manifest.markdownBody, "kept")
    }

    func testSavingAPageKeepsItsFlagsAndTidiesThem() throws {
        let page = ExercisePageManifest(title: "Lateral switch step", pageType: .tutorial)
        try database.createPage(manifest: page)
        var stored = try database.getPage(id: page.id)
        stored.noSkills = true
        stored.widgets = ["clips", "workouts", "clips"]
        try database.updatePage(id: page.id, manifest: stored, newParentID: nil)
        stored = try database.getPage(id: page.id)
        XCTAssertEqual(stored.noSkills, true)
        XCTAssertEqual(stored.widgets, ["clips", "workouts"])

        let folder = ExercisePageManifest(title: "Footwork")
        try database.createPage(manifest: folder)
        try database.movePage(id: page.id, newParentID: folder.id, newOrder: 0)
        stored = try database.getPage(id: page.id)
        XCTAssertEqual(stored.noSkills, true)
        XCTAssertEqual(stored.widgets, ["clips", "workouts"])

        stored.noSkills = false
        try database.updatePage(id: page.id, manifest: stored, newParentID: folder.id)
        XCTAssertNil(try database.getPage(id: page.id).noSkills)
    }

    // MARK: Agent tools

    func testCreateSkillPageTakesTheFlagsAndGetPageReportsThem() throws {
        let id = try call("create_skill_page", ["title": "Lateral switch step", "pageType": "tutorial", "noSkills": true, "widgets": ["workouts", "clips"]])["id"] as! String
        let page = try database.getPage(id: id)
        XCTAssertEqual(page.noSkills, true)
        XCTAssertEqual(page.widgets, ["workouts", "clips"])
        let read = try call("get_page", ["page": id])
        XCTAssertEqual(read["noSkills"] as? Bool, true)
        XCTAssertEqual(read["widgets"] as? [String], ["workouts", "clips"])

        let plain = try call("get_page", ["page": try call("create_skill_page", ["title": "Footwork"])["id"] as! String])
        XCTAssertNil(plain["noSkills"])
        XCTAssertNil(plain["widgets"])
    }

    func testUpdatePageSetsResetsAndClearsTheFlags() throws {
        let id = try call("create_skill_page", ["title": "Lateral switch step"])["id"] as! String
        var result = try call("update_page", ["page": id, "noSkills": true, "widgets": ["none"]])
        XCTAssertEqual(result["changed"] as? [String], ["noSkills", "widgets"])
        XCTAssertEqual(try database.getPage(id: id).noSkills, true)
        XCTAssertEqual(try database.getPage(id: id).widgets, [])

        try call("update_page", ["page": id, "widgets": ["auto"]])
        XCTAssertNil(try database.getPage(id: id).widgets)
        try call("update_page", ["page": id, "widgets": [String]()])
        XCTAssertEqual(try database.getPage(id: id).widgets, [])

        result = try call("update_page", ["page": id, "widgets": ["clips", "todos"]])
        XCTAssertEqual((result["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(try database.getPage(id: id).widgets, ["clips", "todos"])

        try call("update_page", ["page": id, "widgets": ["workouts"]], dryRun: true)
        XCTAssertEqual(try database.getPage(id: id).widgets, ["clips", "todos"])

        try call("update_page", ["page": id, "noSkills": false])
        let cleared = try database.getPage(id: id)
        XCTAssertNil(cleared.noSkills)
        XCTAssertEqual(cleared.widgets, ["clips", "todos"])
    }

    func testWidgetNamesAreCheckedAgainstWhatThePageCanShow() throws {
        let exercise = try call("create_exercise_page", ["title": "Squat", "widgets": ["clips", "workouts"]])["id"] as! String
        XCTAssertEqual(try database.getPage(id: exercise).widgets, ["clips", "workouts"])

        let unknown = failure { _ = try self.call("update_page", ["page": exercise, "widgets": ["sparkles"]]) }
        XCTAssertEqual(unknown?.code, "invalid_argument")
        XCTAssertTrue(unknown?.message.contains("learnFirst") == true)

        let elsewhere = failure { _ = try self.call("update_page", ["page": exercise, "widgets": ["todos"]]) }
        XCTAssertEqual(elsewhere?.code, "invalid_argument")
        XCTAssertTrue(elsewhere?.hint?.contains("clips, workouts") == true)

        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": exercise, "widgets": ["auto", "clips"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Lunge", "widgets": ["folder"]]) }?.code, "invalid_argument")
        XCTAssertNil(try AgentPageIndex(database: database).pages.first { $0.title == "Lunge" })

        let folder = try call("create_container_page", ["title": "Drills", "noSkills": true, "widgets": ["folder"]])["id"] as! String
        XCTAssertEqual(try database.getPage(id: folder).noSkills, true)
        XCTAssertEqual(try database.getPage(id: folder).widgets, ["folder"])

        let note = try call("create_note_page", ["title": "Plan"])["id"] as! String
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": note, "noSkills": true]) }?.code, "invalid_page")
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": note, "widgets": ["auto"]]) }?.code, "invalid_page")
    }
}
