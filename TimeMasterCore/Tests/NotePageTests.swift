import XCTest
@testable import TimeMasterCore

final class NotePageTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("note-\(UUID().uuidString)", isDirectory: true)
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

    private func failure(_ block: () throws -> Void) -> Error? {
        do { try block(); return nil } catch { return error }
    }

    private func picture(_ name: String = "photo.jpg", bytes: Int = 32) throws -> URL {
        let folder = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(name)
        try Data(repeating: 9, count: bytes).write(to: file)
        return file
    }

    private func makeNote(_ title: String = "Plan", body: String = "# Plan", parent: String? = nil) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageType: .note, markdownBody: body, parentID: parent)
        try database.createPage(manifest: manifest, parentID: parent)
        return try database.getPage(id: manifest.id)
    }

    private func folder(_ title: String) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageKind: .container, workoutType: .strength)
        try database.createPage(manifest: manifest)
        return try database.getPage(id: manifest.id)
    }

    func testANoteIsALeafThatKeepsOnlyItsTitleIconAndMarkdown() throws {
        var manifest = ExercisePageManifest(
            title: "Ideas", pageType: .note, iconName: "lightbulb", iconType: .system, markdownBody: "Body",
            mediaFilenames: ["a.jpg"], linkURLs: ["https://example.com"], workoutType: .strength,
            skillStatus: .learning, duration: 40, sets: 3, childIDs: ["x"]
        )
        XCTAssertEqual(manifest.pageKind, .leaf)
        XCTAssertTrue(manifest.mediaFilenames.isEmpty && manifest.linkURLs.isEmpty)
        XCTAssertNil(manifest.workoutType)
        XCTAssertNil(manifest.skillStatus)
        XCTAssertNil(manifest.duration)
        XCTAssertTrue(manifest.childIDs.isEmpty)
        manifest.iconName = "  "
        try database.createPage(manifest: manifest)
        let stored = try database.getPage(id: manifest.id)
        XCTAssertNil(stored.iconName)
        XCTAssertNil(stored.iconType)
        XCTAssertEqual(stored.pageType, .note)
        XCTAssertEqual(stored.pageKind, .leaf)
    }

    func testANoteSurvivesAnEncodeDecodeRoundTrip() throws {
        let manifest = ExercisePageManifest(title: "Ideas", pageType: .note, iconName: "🔥", iconType: .emoji, markdownBody: "# Hi\n\n![](<Attachments/a.png>)")
        let data = try JSONEncoder().encode(manifest)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"pageType\":\"note\""))
        let decoded = try JSONDecoder().decode(ExercisePageManifest.self, from: data)
        XCTAssertEqual(decoded.pageType, .note)
        XCTAssertEqual(decoded.pageKind, .leaf)
        XCTAssertEqual(decoded.iconName, "🔥")
        XCTAssertEqual(decoded.iconType, .emoji)
        XCTAssertEqual(decoded.markdownBody, manifest.markdownBody)
    }

    func testANoteLivesAtTheRootOrInAPlainFolderOnly() throws {
        let plain = try folder("Study")
        XCTAssertEqual(try makeNote("Top").parentID, nil)
        let inside = try makeNote("Inside", parent: plain.id)
        XCTAssertEqual(try database.getPage(id: plain.id).childIDs, [inside.id])

        let skill = ExercisePageManifest(title: "Piano", pageType: .skill)
        try database.createPage(manifest: skill)
        XCTAssertNotNil(failure { try self.database.createPage(manifest: ExercisePageManifest(title: "N", pageType: .note), parentID: skill.id) })
        XCTAssertNotNil(failure { try self.database.movePage(id: inside.id, newParentID: skill.id, newOrder: 0) })
        XCTAssertEqual(try database.getPage(id: inside.id).parentID, plain.id)

        let exercise = ExercisePageManifest(title: "Squat", pageKind: .leaf, duration: 30)
        try database.createPage(manifest: exercise)
        XCTAssertNotNil(failure { try self.database.createPage(manifest: ExercisePageManifest(title: "N", pageType: .note), parentID: exercise.id) })
        XCTAssertNotNil(failure { try self.database.createPage(manifest: ExercisePageManifest(title: "Child", pageKind: .leaf, duration: 30), parentID: inside.id) })
    }

    func testANoteCanMoveBetweenFoldersAndTheRoot() throws {
        let one = try folder("One")
        let two = try folder("Two")
        let note = try makeNote(parent: one.id)
        try database.movePage(id: note.id, newParentID: two.id, newOrder: 0)
        XCTAssertEqual(try database.getPage(id: two.id).childIDs, [note.id])
        XCTAssertEqual(try database.getPage(id: one.id).childIDs, [])
        try database.movePage(id: note.id, newParentID: nil, newOrder: 5)
        XCTAssertNil(try database.getPage(id: note.id).parentID)
    }

    func testPicturesLiveInTheNotesAttachmentsFolderAndFollowTheNote() throws {
        let note = try makeNote()
        let relative = try database.importNoteImage(pageID: note.id, sourceURL: try picture())
        XCTAssertTrue(relative.hasPrefix("Attachments/") && relative.hasSuffix(".jpg"))
        let page = try database.resolvePageFolder(id: note.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: page.appendingPathComponent(relative).path))
        XCTAssertEqual(try database.noteAttachmentNames(pageID: note.id).count, 1)
        XCTAssertEqual(try database.walkPageTree(in: database.exercisesDatabaseURL).count, 1)

        var renamed = try database.getPage(id: note.id)
        renamed.title = "Renamed"
        try database.updatePage(id: note.id, manifest: renamed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try database.resolvePageFolder(id: note.id).appendingPathComponent(relative).path))

        let target = try folder("Target")
        try database.movePage(id: note.id, newParentID: target.id, newOrder: 0)
        let moved = try database.resolvePageFolder(id: note.id)
        XCTAssertTrue(moved.path.contains(target.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.appendingPathComponent(relative).path))

        try database.deletePage(id: note.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: moved.path))
        let trashed = try FileManager.default.contentsOfDirectory(atPath: database.fs.trashDirectory.path).filter { $0.hasSuffix(note.id) }
        XCTAssertEqual(trashed.count, 1)
        let trashedAttachments = database.fs.trashDirectory.appendingPathComponent(trashed[0]).appendingPathComponent(relative)
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashedAttachments.path))
    }

    func testOnlyPicturesOfASaneSizeAreImported() throws {
        let note = try makeNote()
        XCTAssertNotNil(failure { _ = try self.database.importNoteImage(pageID: note.id, sourceURL: try self.picture("clip.mov")) })
        XCTAssertNotNil(failure { _ = try self.database.importNoteImage(pageID: note.id, sourceURL: try self.picture("empty.png", bytes: 0)) })
        let exercise = ExercisePageManifest(title: "Squat", pageKind: .leaf, duration: 30)
        try database.createPage(manifest: exercise)
        XCTAssertNotNil(failure { _ = try self.database.importNoteImage(pageID: exercise.id, sourceURL: try self.picture()) })
    }

    func testPicturesTravelInTheSyncInventoryOfTheNote() throws {
        let note = try makeNote()
        let relative = try database.importNoteImage(pageID: note.id, sourceURL: try picture())
        let store = SyncStateStore(fs: database.fs)
        let snapshot = database.syncLoadSnapshot(store: store)
        let record = try XCTUnwrap(snapshot.page(note.id))
        XCTAssertEqual(record.files.map(\.path), [relative])
        XCTAssertEqual(snapshot.pages[note.id]?.pageType, .note)
    }

    func testThePageIndexReportsNotesAsTheirOwnKind() throws {
        let note = try makeNote("Plan", body: "hello")
        let index = try AgentPageIndex(database: database)
        XCTAssertEqual(index.kind(note), "note")
        XCTAssertEqual(index.summary(note)["kind"] as? String, "note")
        XCTAssertEqual(index.summary(note)["chars"] as? Int, 5)
        XCTAssertTrue(index.matches(note, kind: "note"))
        XCTAssertFalse(index.matches(note, kind: "exercise"))
        XCTAssertFalse(index.matches(note, kind: "container"))
    }

    func testAnAgentCreatesANoteWithPicturesAndFindsItByKind() throws {
        let study = try call("create_container_page", ["title": "Study", "workoutType": "Other"])["id"] as! String
        let result = try call("create_note_page", [
            "title": "Drills", "parent": "Study", "markdownBody": "# Drills\n\n- [ ] jab",
            "images": [try picture("a.jpg").path, try picture("b.png").path], "icon": "figure.boxing",
        ])
        XCTAssertEqual(result["path"] as? String, "Study/Drills")
        XCTAssertEqual(result["images"] as? Int, 2)
        let id = result["id"] as! String
        let page = try database.getPage(id: id)
        XCTAssertEqual(page.pageType, .note)
        XCTAssertEqual(page.parentID, study)
        XCTAssertEqual(page.iconName, "figure.boxing")
        XCTAssertEqual(page.iconType, .system)
        XCTAssertTrue(page.markdownBody.hasPrefix("# Drills\n\n- [ ] jab\n\n![](<Attachments/"))
        XCTAssertEqual(page.markdownBody.components(separatedBy: "![](<Attachments/").count - 1, 2)
        XCTAssertEqual(try database.noteAttachmentNames(pageID: id).count, 2)

        let found = try call("search_pages", ["query": "drills", "kind": "note"])
        XCTAssertEqual((found["results"] as! [[String: Any]]).first?["kind"] as? String, "note")
        XCTAssertEqual((try call("search_pages", ["query": "drills", "kind": "exercise"])["results"] as! [Any]).count, 0)
        XCTAssertEqual((try call("search_pages", ["query": "drills", "kind": "container"])["results"] as! [Any]).count, 0)
        XCTAssertEqual((try call("list_pages", ["parent": "Study"])["pages"] as! [[String: Any]]).first?["kind"] as? String, "note")
    }

    func testCreatingANoteHonoursIfExistsAndDryRunAndRefusesBadParents() throws {
        try call("create_note_page", ["title": "Plan"])
        XCTAssertEqual((failure { _ = try self.call("create_note_page", ["title": "plan"]) } as? AgentToolError)?.code, "already_exists")
        XCTAssertEqual(try call("create_note_page", ["title": "Plan", "ifExists": "reuse"])["reused"] as? Bool, true)
        try call("create_note_page", ["title": "Plan", "ifExists": "duplicate"])
        let preview = try call("create_note_page", ["title": "Other", "images": [try picture().path]], dryRun: true)
        XCTAssertEqual(preview["images"] as? Int, 1)
        XCTAssertEqual(try AgentPageIndex(database: database).pages.count, 2)

        try call("create_exercise_page", ["title": "Squat"])
        XCTAssertEqual((failure { _ = try self.call("create_note_page", ["title": "N", "parent": "Squat"]) } as? AgentToolError)?.code, "invalid_parent")
        try database.createPage(manifest: ExercisePageManifest(title: "Piano", pageType: .skill))
        XCTAssertEqual((failure { _ = try self.call("create_note_page", ["title": "N", "parent": "Piano"]) } as? AgentToolError)?.code, "invalid_parent")
        XCTAssertEqual((failure { _ = try self.call("create_note_page", ["title": "N", "images": [try self.picture("clip.mp4").path]]) } as? AgentToolError)?.code, "unsupported_media")
        XCTAssertEqual((failure { _ = try self.call("create_note_page", ["title": "N", "images": ["/nope/missing.jpg"]]) } as? AgentToolError)?.code, "file_not_found")
        XCTAssertEqual(try AgentPageIndex(database: database).pages.count, 4)
    }

    func testAnAgentReadsEditsAppendsMovesAndTrashesANote() throws {
        let id = try call("create_note_page", ["title": "Plan", "markdownBody": "First"])["id"] as! String
        try call("add_page_note", ["page": id, "note": "Second"])
        XCTAssertEqual(try database.getPage(id: id).markdownBody, "First\n\nSecond")
        try call("update_page", ["page": "Plan", "markdownBody": "Replaced", "title": "Plan B", "icon": "📝"])
        let page = try database.getPage(id: id)
        XCTAssertEqual(page.markdownBody, "Replaced")
        XCTAssertEqual(page.title, "Plan B")
        XCTAssertEqual(page.iconType, .emoji)
        XCTAssertEqual((failure { _ = try self.call("update_page", ["page": id, "duration": 30]) } as? AgentToolError)?.code, "invalid_page")

        let shown = try call("get_page", ["page": id])
        XCTAssertEqual(shown["kind"] as? String, "note")
        XCTAssertEqual(shown["markdownBody"] as? String, "Replaced")
        XCTAssertNil(shown["truncated"])

        let folder = try call("create_container_page", ["title": "Study"])["id"] as! String
        try call("move_page", ["page": id, "newParent": folder])
        XCTAssertEqual(try database.getPage(id: id).parentID, folder)
        XCTAssertEqual((failure { _ = try self.call("move_page", ["page": folder, "newParent": id]) } as? AgentToolError)?.code, "invalid_parent")

        let image = try picture()
        try call("attach_media", ["page": id, "path": image.path, "comment": "Chart"])
        XCTAssertTrue(try database.getPage(id: id).markdownBody.contains("![Chart](<Attachments/"))
        XCTAssertEqual(try database.noteAttachmentNames(pageID: id).count, 1)

        try call("delete_page", ["page": id])
        XCTAssertNil(failure { _ = try self.database.getPage(id: folder) })
        XCTAssertNotNil(failure { _ = try self.database.getPage(id: id) })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: database.fs.trashDirectory.path).filter { $0.hasSuffix(id) }.count, 1)
    }

    func testALongNoteComesBackInPiecesTheAgentCanReadOnFrom() throws {
        let body = String(repeating: "word ", count: 5000)
        let id = try call("create_note_page", ["title": "Long", "markdownBody": body])["id"] as! String
        var collected = ""
        var offset = 0
        var pieces = 0
        while true {
            let reply = try call("get_page", ["page": id, "bodyOffset": offset])
            collected += reply["markdownBody"] as? String ?? ""
            pieces += 1
            XCTAssertEqual(reply["bodyChars"] as? Int, body.count)
            guard reply["truncated"] as? Bool == true else { break }
            offset = reply["nextOffset"] as! Int
        }
        XCTAssertEqual(collected, body)
        XCTAssertEqual(pieces, 4)
    }

    func testNotesAreNotExercisesInContextStatsOrWorkouts() throws {
        try call("create_exercise_page", ["title": "Squat"])
        let note = try call("create_note_page", ["title": "Plan"])["id"] as! String
        let context = try call("context", [:])
        let library = context["library"] as! [String: Any]
        XCTAssertEqual(library["exercises"] as? Int, 1)
        XCTAssertEqual(library["folders"] as? Int, 0)
        XCTAssertEqual(library["notes"] as? Int, 1)
        XCTAssertEqual(try call("get_stats", [:])["exercises"] as? Int, 1)
        let error = failure { _ = try self.call("build_workout", ["name": "W", "sections": [["exercise": note]]]) } as? AgentToolError
        XCTAssertEqual(error?.code, "invalid_argument")
        let session = try AISystemPromptBuilder(fs: database.fs).buildSessionContext(db: database)
        XCTAssertEqual(session.database.totalExercises, 1)
    }

    func testTheSchemaAndTheSkillGuideDescribeNotes() throws {
        let schema = try SchemaManager(fs: database.fs).generateSchema()
        XCTAssertEqual(schema.objects["note"]?.properties["pageType"]?.description, "Always note")
        XCTAssertTrue(schema.objects["page"]?.properties["pageType"]?.description.contains("note") == true)
        XCTAssertTrue(schema.tools.contains { $0.name == "create_note_page" && $0.write })
        let guide = database.fs.skillsDirectory.appendingPathComponent("write-note.md")
        XCTAssertTrue(try String(contentsOf: guide, encoding: .utf8).contains("create_note_page"))
    }
}

final class NotePageSyncTests: SyncPairTestCase {
    func testANoteArrivesOnTheOtherDeviceWithItsPicturesAndLaterEditsFollow() async throws {
        let note = ExercisePageManifest(title: "Plan", pageType: .note, markdownBody: "v1")
        try mac.db.createPage(manifest: note)
        let source = try writeFile("picture bytes", named: "p.png")
        let relative = try mac.db.importNoteImage(pageID: note.id, sourceURL: source)

        try await sync()
        XCTAssertEqual(try phone.page(note.id).pageType, .note)
        XCTAssertEqual(try String(contentsOf: try phone.folder(note.id).appendingPathComponent(relative), encoding: .utf8), "picture bytes")
        XCTAssertTrue(libraryProblems(phone).isEmpty, "\(libraryProblems(phone))")
        try assertInSync()

        try phone.edit(note.id) { $0.markdownBody = "v2 ![](<\(relative)>)" }
        try await sync()
        XCTAssertEqual(try mac.page(note.id).markdownBody, "v2 ![](<\(relative)>)")
        try assertInSync()
    }
}
