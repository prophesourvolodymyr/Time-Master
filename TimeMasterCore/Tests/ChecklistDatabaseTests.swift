import XCTest
@testable import TimeMasterCore

final class ChecklistDatabaseTests: XCTestCase {
    var root: URL!
    var db: DatabaseManager!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("checklists-\(UUID().uuidString)", isDirectory: true)
        db = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try db.bootstrapIfNeeded()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func skill(_ title: String = "Single leg", parent: String? = nil) throws -> ExercisePageManifest {
        let page = ExercisePageManifest(title: title, pageType: .skill)
        try db.createPage(manifest: page, parentID: parent)
        return try db.getPage(id: page.id)
    }

    private func file(_ name: String, _ text: String = "bytes") throws -> URL {
        let url = root.appendingPathComponent("incoming-\(UUID().uuidString)-\(name)")
        try Data(text.utf8).write(to: url)
        return url
    }

    private func manifestText(_ id: String) throws -> String {
        let folder = try db.resolvePageFolder(id: id)
        return try String(contentsOf: folder.appendingPathComponent("manifest.json"), encoding: .utf8)
    }

    @discardableResult
    private func add<Entry: ChecklistEntry>(_ type: Entry.Type, _ title: String, on page: String, under parent: String? = nil, at index: Int? = nil) throws -> Entry {
        try db.addChecklistEntry(Entry.blank(id: Entry.newID(), title: title), to: page, under: parent, at: index)
    }

    // MARK: Where lists live

    func testUntouchedPagesKeepTheirManifestsAndListsAreWrittenOnlyWhenTheyHoldSomething() throws {
        let page = try skill()
        let before = try manifestText(page.id)
        XCTAssertFalse(before.contains("todos"))
        let added: TodoItem = try add(TodoItem.self, "Drill entries", on: page.id)
        XCTAssertTrue(try manifestText(page.id).contains("todos"))
        XCTAssertFalse(try manifestText(page.id).contains("milestones"))
        try db.removeChecklistEntry(TodoItem.self, added.id, from: page.id)
        XCTAssertFalse(try manifestText(page.id).contains("todos"))
    }

    func testOnlySkillAndTutorialPagesTakeEntriesAndGroupsTakeNone() throws {
        let folder = ExercisePageManifest(title: "Folder")
        try db.createPage(manifest: folder)
        XCTAssertThrowsError(try add(TodoItem.self, "x", on: folder.id))
        let board = try skill("Wrestling")
        let group = try db.addSkillGroup(to: board.id, title: "Takedowns")
        XCTAssertThrowsError(try add(Milestone.self, "x", on: SkillGroupID.make(containerID: board.id, sectionID: group.id)))
        let tutorial = ExercisePageManifest(title: "How to sprawl", pageType: .tutorial)
        try db.createPage(manifest: tutorial)
        XCTAssertNoThrow(try add(Milestone.self, "Sprawl on reaction", on: tutorial.id))
    }

    // MARK: Adding, checking, nesting

    func testAddCheckAndReopenFollowTheTreeRule() throws {
        let page = try skill()
        let parent: TodoItem = try add(TodoItem.self, "Setups", on: page.id)
        let child: TodoItem = try add(TodoItem.self, "Collar tie", on: page.id, under: parent.id)
        let grandchild: TodoItem = try add(TodoItem.self, "Snap down", on: page.id, under: child.id)
        var list = try db.setChecklistEntry(TodoItem.self, parent.id, done: true, in: page.id)
        XCTAssertTrue(list.flattened().allSatisfy { $0.item.isDone })
        XCTAssertNotNil(list.entry(grandchild.id)?.doneAt)
        list = try db.setChecklistEntry(TodoItem.self, grandchild.id, done: false, in: page.id)
        XCTAssertFalse(list.entry(parent.id)!.isDone, "opening a child opens its parents")
        XCTAssertFalse(list.entry(child.id)!.isDone)
        XCTAssertEqual(list.openCount, 3)
    }

    func testReturnPlacesTheNextEntryAfterTheCurrentOne() throws {
        let page = try skill()
        let first: TodoItem = try add(TodoItem.self, "One", on: page.id)
        try add(TodoItem.self, "Three", on: page.id)
        try add(TodoItem.self, "Two", on: page.id, at: 1)
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id).map(\.title), ["One", "Two", "Three"])
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id).first?.id, first.id)
    }

    func testIndentAndOutdentLikeAnOutliner() throws {
        let page = try skill()
        let a: TodoItem = try add(TodoItem.self, "A", on: page.id)
        let b: TodoItem = try add(TodoItem.self, "B", on: page.id)
        XCTAssertFalse(try db.indentChecklistEntry(TodoItem.self, a.id, in: page.id), "nothing above the first entry")
        XCTAssertTrue(try db.indentChecklistEntry(TodoItem.self, b.id, in: page.id))
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id).entry(a.id)?.children.map(\.id), [b.id])
        XCTAssertTrue(try db.outdentChecklistEntry(TodoItem.self, b.id, in: page.id))
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id).map(\.id), [a.id, b.id])
        XCTAssertFalse(try db.outdentChecklistEntry(TodoItem.self, b.id, in: page.id))
    }

    func testMilestonesNestFourLevelsAtMost() throws {
        let page = try skill()
        var parent: Milestone = try add(Milestone.self, "Level 1", on: page.id)
        for level in 2...Milestone.maxDepth { parent = try add(Milestone.self, "Level \(level)", on: page.id, under: parent.id) }
        XCTAssertThrowsError(try add(Milestone.self, "Too deep", on: page.id, under: parent.id))
        let loose: Milestone = try add(Milestone.self, "Loose", on: page.id)
        XCTAssertThrowsError(try db.moveChecklistEntry(Milestone.self, loose.id, in: page.id, toParent: parent.id))
        XCTAssertThrowsError(try db.moveChecklistEntry(Milestone.self, try db.checklist(Milestone.self, of: page.id)[0].id, in: page.id, toParent: parent.id), "not inside itself")
    }

    // MARK: Sections

    func testSectionsAddRenameMoveAndDelete() throws {
        let page = try skill()
        let a: TodoItem = try add(TodoItem.self, "Stance", on: page.id)
        let footwork = try db.addChecklistSection(TodoItem.self, title: "Footwork", iconName: "👣", colorHex: "34D399", to: page.id)
        let b: TodoItem = try add(TodoItem.self, "Penetration step", on: page.id)
        let finishes = try db.addChecklistSection(TodoItem.self, title: "Finishes", to: page.id)
        let c: TodoItem = try add(TodoItem.self, "Run the pipe", on: page.id)
        var list = try db.checklist(TodoItem.self, of: page.id)
        XCTAssertEqual(list.progressTotal, 3, "sections do not count")
        XCTAssertEqual(list.parts.map { $0.entries.map(\.title) }, [["Stance"], ["Penetration step"], ["Run the pipe"]])

        try db.updateChecklistEntry(TodoItem.self, footwork.id, in: page.id) { $0.title = "Feet" }
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id).entry(footwork.id)?.title, "Feet")

        list = try db.moveChecklistEntry(TodoItem.self, c.id, in: page.id, toSection: footwork.id)
        XCTAssertEqual(list.parts[1].entries.map(\.id), [b.id, c.id], "moving across a divider is reordering")
        list = try db.moveChecklistEntry(TodoItem.self, a.id, in: page.id, toSection: finishes.id)
        XCTAssertEqual(list.parts.map { $0.section?.id }, [footwork.id, finishes.id])
        XCTAssertEqual(list.parts.last?.entries.map(\.id), [a.id])

        XCTAssertThrowsError(try db.setChecklistEntry(TodoItem.self, footwork.id, done: true, in: page.id))
        XCTAssertThrowsError(try add(TodoItem.self, "inside", on: page.id, under: footwork.id))
        XCTAssertThrowsError(try db.moveChecklistEntry(TodoItem.self, b.id, in: page.id, toParent: finishes.id))

        try db.removeChecklistEntry(TodoItem.self, footwork.id, from: page.id)
        list = try db.checklist(TodoItem.self, of: page.id)
        XCTAssertEqual(list.map(\.id), [b.id, c.id, finishes.id, a.id], "its entries join the part above")
    }

    func testAnEntryCannotBeNestedUnderASectionByTabAndTheFirstEntryOfAPartStaysAtTheTop() throws {
        let page = try skill()
        try db.addChecklistSection(TodoItem.self, title: "Footwork", to: page.id)
        let first: TodoItem = try add(TodoItem.self, "Stance", on: page.id)
        XCTAssertFalse(try db.indentChecklistEntry(TodoItem.self, first.id, in: page.id))
        let second: TodoItem = try add(TodoItem.self, "Step", on: page.id)
        XCTAssertTrue(try db.indentChecklistEntry(TodoItem.self, second.id, in: page.id))
        let section = try db.checklist(TodoItem.self, of: page.id)[0]
        XCTAssertFalse(try db.indentChecklistEntry(TodoItem.self, section.id, in: page.id), "a section never nests")
    }

    func testOnlyAnEmptyTopLevelEntryBecomesASection() throws {
        let page = try skill()
        let parent: TodoItem = try add(TodoItem.self, "Parent", on: page.id)
        let child: TodoItem = try add(TodoItem.self, "Child", on: page.id, under: parent.id)
        XCTAssertThrowsError(try db.updateChecklistEntry(TodoItem.self, parent.id, in: page.id) { $0.isSection = true })
        XCTAssertThrowsError(try db.updateChecklistEntry(TodoItem.self, child.id, in: page.id) { $0.isSection = true })
        let lone: TodoItem = try add(TodoItem.self, "Lone", on: page.id)
        XCTAssertTrue(try db.updateChecklistEntry(TodoItem.self, lone.id, in: page.id) { $0.isSection = true }.isSection)
    }

    // MARK: Pictures and files

    func testPicturesAttachInOneStepAndLeaveWithTheirFile() throws {
        let page = try skill()
        let item: Milestone = try add(Milestone.self, "First takedown", on: page.id)
        let cover = try db.attachChecklistPicture(Milestone.self, from: try file("cover.jpg"), to: item.id, in: page.id, as: .cover)
        let strip = try db.attachChecklistPicture(Milestone.self, from: try file("strip.png"), to: item.id, in: page.id, as: .image)
        let icon = try db.attachChecklistPicture(Milestone.self, from: try file("icon.heic"), to: item.id, in: page.id, as: .icon)
        let clip = try db.attachChecklistPicture(Milestone.self, from: try file("clip.mov"), to: item.id, in: page.id, as: .attachment)
        XCTAssertThrowsError(try db.attachChecklistPicture(Milestone.self, from: try file("notes.pdf"), to: item.id, in: page.id, as: .cover))
        var saved = try db.checklist(Milestone.self, of: page.id)[0]
        XCTAssertEqual(saved.coverMediaFilename, cover)
        XCTAssertEqual(saved.imageFilenames, [strip])
        XCTAssertEqual(saved.iconImage, icon)
        XCTAssertEqual(saved.links.compactMap(\.target?.mediaFilename), [clip])
        XCTAssertEqual(try db.getPage(id: page.id).mediaFilenames, [cover, strip, icon, clip], "the refused PDF did not stay")

        for name in [cover, strip, icon, clip] { try db.removeMediaFromPage(pageID: page.id, filename: name) }
        saved = try db.checklist(Milestone.self, of: page.id)[0]
        XCTAssertNil(saved.coverMediaFilename)
        XCTAssertTrue(saved.imageFilenames.isEmpty)
        XCTAssertNil(saved.iconImage)
        XCTAssertTrue(saved.links.isEmpty)
    }

    func testReferencesMustBeFilesOfThePage() throws {
        let page = try skill()
        let item: TodoItem = try add(TodoItem.self, "Grip", on: page.id)
        XCTAssertThrowsError(try db.updateChecklistEntry(TodoItem.self, item.id, in: page.id) { $0.coverMediaFilename = "elsewhere.jpg" }) { error in
            XCTAssertEqual(error as? ChecklistError, .notFound("“elsewhere.jpg” is not a file of Single leg."))
        }
        let video = try db.uploadMediaToPage(pageID: page.id, sourceURL: try file("clip.mp4"))
        XCTAssertThrowsError(try db.updateChecklistEntry(TodoItem.self, item.id, in: page.id) { $0.imageFilenames = [video] })
        XCTAssertNoThrow(try db.updateChecklistEntry(TodoItem.self, item.id, in: page.id) { $0.links = [TodoLink(target: .media(filename: video))] })
    }

    func testEditingThePageKeepsTheListsAndDropsWhatItsMediaNoLongerHas() throws {
        let page = try skill()
        let item: TodoItem = try add(TodoItem.self, "Shot", on: page.id)
        let picture = try db.attachChecklistPicture(TodoItem.self, from: try file("a.jpg"), to: item.id, in: page.id, as: .image)
        var manifest = try db.getPage(id: page.id)
        manifest.title = "Single-leg shot"
        try db.updatePage(id: page.id, manifest: manifest)
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id)[0].imageFilenames, [picture])
        manifest = try db.getPage(id: page.id)
        manifest.mediaFilenames = []
        try db.updatePage(id: page.id, manifest: manifest)
        XCTAssertTrue(try db.checklist(TodoItem.self, of: page.id)[0].imageFilenames.isEmpty)
    }

    func testTurningASkillIntoAnExerciseDropsItsLists() throws {
        let page = try skill()
        try add(TodoItem.self, "x", on: page.id)
        var manifest = try db.getPage(id: page.id)
        manifest.pageType = .exercise
        manifest.pageKind = .leaf
        manifest.duration = 30
        try db.updatePage(id: page.id, manifest: manifest)
        XCTAssertTrue(try db.getPage(id: page.id).todos.isEmpty)
    }

    // MARK: Findings

    func testDeadLinksAndMissingFilesAreReportedNotRepaired() throws {
        let page = try skill()
        let target = try skill("Double leg")
        let workoutID = UUID().uuidString
        try db.createWorkout(id: workoutID, manifest: WorkoutManifest(id: workoutID, name: "Single-leg bundle", sections: []))
        var item = TodoItem.blank(id: TodoItem.newID(), title: "Drill")
        item.links = [TodoLink(target: .workout(id: workoutID)), TodoLink(target: .page(id: target.id))]
        try db.addChecklistEntry(item, to: page.id)
        let pictureItem: Milestone = try add(Milestone.self, "Show", on: page.id)
        let cover = try db.attachChecklistPicture(Milestone.self, from: try file("c.jpg"), to: pictureItem.id, in: page.id, as: .cover)
        XCTAssertTrue(try db.checklistFindings().isEmpty)

        try db.deleteWorkout(id: workoutID)
        try db.deletePage(id: target.id)
        try FileManager.default.removeItem(at: try db.pageMediaURL(pageID: page.id, filename: cover))
        let findings = try db.checklistFindings(pageID: page.id)
        XCTAssertEqual(Set(findings.map(\.problem)), [.missingWorkout, .missingPage, .missingFile])
        XCTAssertEqual(findings.first { $0.problem == .missingFile }?.kind, .milestone)
        XCTAssertEqual(try db.checklist(TodoItem.self, of: page.id)[0].links.count, 2, "the links stay for the user to decide")
    }
}
