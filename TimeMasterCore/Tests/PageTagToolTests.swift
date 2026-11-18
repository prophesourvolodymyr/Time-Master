import XCTest
@testable import TimeMasterCore

/// Tags on exercise and note pages: the top folder of a tree keeps them (like its workout type) and every page below it
/// shares them; skills keep their own types.
final class PageTagToolTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pagetag-\(UUID().uuidString)", isDirectory: true)
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

    private func manifest(_ reference: String) throws -> ExercisePageManifest {
        try database.getPage(id: try AgentPageIndex(database: database).resolve(reference).id)
    }

    private func tagTitles(_ listing: [String: Any]) -> [String] {
        (listing["presets"] as? [[String: Any]] ?? []).flatMap { ($0["tags"] as? [[String: Any]] ?? []).compactMap { $0["title"] as? String } }
    }

    func testTagsLiveOnTheTopFolderAndPagesAtEveryDepthWearThem() throws {
        try call("create_container_page", ["title": "Mobility & Flexibility"])
        try call("create_container_page", ["title": "Hips", "parent": "Mobility & Flexibility"])
        try call("create_container_page", ["title": "Spine", "parent": "Mobility & Flexibility"])
        try call("create_exercise_page", ["title": "90-90 Switch", "parent": "Mobility & Flexibility/Hips", "duration": 40])
        try call("create_exercise_page", ["title": "Cat Cow", "parent": "Mobility & Flexibility/Spine"])
        try call("create_note_page", ["title": "Mobility Notes", "parent": "Mobility & Flexibility", "markdownBody": "Breathe."])

        let made = try call("create_page_tag", [
            "container": "Mobility & Flexibility/Hips", "title": "Morning flow", "preset": "Routine", "color": "5ce1e6", "icon": "sunrise",
        ])
        XCTAssertEqual(made["in"] as? String, "Mobility & Flexibility", "the top folder keeps the tag, not the sub-folder")
        XCTAssertEqual(made["preset"] as? String, "Routine")
        XCTAssertEqual(made["color"] as? String, "5CE1E6")
        let tagID = try XCTUnwrap(made["id"] as? String)
        let top = try manifest("Mobility & Flexibility")
        XCTAssertEqual(top.typePresets.map(\.title), ["Routine"])
        XCTAssertEqual(top.typePresets.first?.types.map(\.id), [tagID])
        XCTAssertEqual(try manifest("Mobility & Flexibility/Hips").typePresets, [])

        let tagged = try call("update_page", ["page": "Mobility & Flexibility/Hips/90-90 Switch", "tag": "morning FLOW"])
        XCTAssertEqual(tagged["tag"] as? String, "Morning flow")
        XCTAssertEqual(tagged["changed"] as? [String], ["tag"])
        let exerciseID = try XCTUnwrap(tagged["id"] as? String)
        XCTAssertEqual(try database.getPage(id: exerciseID).typeID, tagID)
        XCTAssertEqual(try database.skillTypeOwnerID(of: exerciseID), top.id)

        XCTAssertEqual(try call("get_page", ["page": exerciseID])["tag"] as? String, "Morning flow")
        let listed = try call("list_pages", ["parent": "Mobility & Flexibility/Hips"])
        XCTAssertEqual((listed["pages"] as? [[String: Any]])?.first?["tag"] as? String, "Morning flow")
        XCTAssertNil((try call("list_pages", ["parent": "Mobility & Flexibility/Spine"])["pages"] as? [[String: Any]])?.first?["tag"])

        let found = try call("search_pages", ["query": "", "tag": "Morning flow"])
        XCTAssertEqual(found["total"] as? Int, 1)
        XCTAssertEqual((found["results"] as? [[String: Any]])?.first?["path"] as? String, "Mobility & Flexibility/Hips/90-90 Switch")
        XCTAssertEqual(try call("search_pages", ["query": "switch", "tag": tagID])["total"] as? Int, 1)
        XCTAssertEqual(try call("search_pages", ["query": "cat", "tag": tagID])["total"] as? Int, 0)
        XCTAssertEqual(failure { _ = try self.call("search_pages", ["query": "  "]) }?.code, "invalid_argument")

        let tags = try call("list_page_tags", ["container": "Mobility & Flexibility/Spine/Cat Cow"])
        XCTAssertEqual(tags["owner"] as? String, "Mobility & Flexibility")
        let preset = (tags["presets"] as? [[String: Any]])?.first
        XCTAssertEqual(preset?["title"] as? String, "Routine")
        let listedTag = (preset?["tags"] as? [[String: Any]])?.first
        XCTAssertEqual(listedTag?["title"] as? String, "Morning flow")
        XCTAssertEqual(listedTag?["color"] as? String, "5CE1E6")
        XCTAssertEqual(listedTag?["icon"] as? String, "sunrise")
        XCTAssertEqual(listedTag?["pages"] as? Int, 1)
        XCTAssertEqual(tags["untagged"] as? Int, 2, "Cat Cow and the note can still take a tag")
    }

    func testNewPagesCanStartWithATagWhileFoldersAndLoosePagesRefuseOne() throws {
        try call("create_container_page", ["title": "Mobility"])
        try call("create_container_page", ["title": "Hips", "parent": "Mobility"])
        try call("create_page_tag", ["container": "Mobility", "title": "Evening stretch"])
        let presets = try manifest("Mobility").typePresets
        XCTAssertEqual(presets.map(\.title), ["Tags"], "the first tag makes a preset called Tags")
        let evening = try XCTUnwrap(presets.first?.types.first?.id)

        let exercise = try call("create_exercise_page", ["title": "Pigeon", "parent": "Mobility/Hips", "tag": "Evening stretch"])
        XCTAssertEqual(exercise["tag"] as? String, "Evening stretch")
        let pigeon = try XCTUnwrap(exercise["id"] as? String)
        XCTAssertEqual(try database.getPage(id: pigeon).typeID, evening)
        let note = try call("create_note_page", ["title": "Why Stretch", "parent": "Mobility/Hips", "tag": "evening stretch"])
        XCTAssertEqual(try database.getPage(id: try XCTUnwrap(note["id"] as? String)).typeID, evening)

        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Loose", "tag": "Evening stretch"]) }?.code, "no_tags_here")
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": "Mobility/Hips", "tag": "Evening stretch"]) }?.code, "invalid_page")
        let unknown = failure { _ = try self.call("update_page", ["page": "Mobility/Hips/Pigeon", "tag": "Nope"]) }
        XCTAssertEqual(unknown?.code, "unknown_tag")
        XCTAssertEqual(unknown?.hint?.contains("Evening stretch"), true)
        XCTAssertEqual(failure { _ = try self.call("create_skill_page", ["title": "Splits", "parent": "Mobility", "tag": "Evening stretch"]) }?.code, "no_tags_here")
        XCTAssertNil(try? AgentPageIndex(database: database).resolve("Mobility/Splits"), "a refused tag creates nothing")

        try call("create_skill_page", ["title": "Splits", "parent": "Mobility"])
        let front = try call("create_page_tag", ["container": "Mobility/Splits", "title": "Front"])
        XCTAssertEqual(front["in"] as? String, "Mobility/Splits", "a skill keeps the types of its sub-skills")
        let sub = try call("create_skill_page", ["title": "Front Split", "parent": "Mobility/Splits", "tag": "Front"])
        XCTAssertEqual(sub["tag"] as? String, "Front")
        XCTAssertEqual(try manifest("Mobility").typePresets.flatMap(\.types).map(\.title), ["Evening stretch"])

        let cleared = try call("update_page", ["page": "Mobility/Hips/Pigeon", "tag": ""])
        XCTAssertEqual(cleared["untagged"] as? Bool, true)
        XCTAssertNil(try database.getPage(id: pigeon).typeID)
        XCTAssertNil(try call("get_page", ["page": "Mobility/Hips/Pigeon"])["tag"])
    }

    func testRenamingATagKeepsItsPagesAndDeletingItLeavesThemUntagged() throws {
        try call("create_container_page", ["title": "Mobility"])
        try call("create_container_page", ["title": "Hips", "parent": "Mobility"])
        let pigeon = try XCTUnwrap(try call("create_exercise_page", ["title": "Pigeon", "parent": "Mobility/Hips"])["id"] as? String)
        let frog = try XCTUnwrap(try call("create_exercise_page", ["title": "Frog", "parent": "Mobility/Hips"])["id"] as? String)
        try call("create_page_tag", ["container": "Mobility", "title": "Morning flow"])
        try call("create_page_tag", ["container": "Mobility", "title": "Reference"])
        try call("update_page", ["page": pigeon, "tag": "Morning flow"])
        try call("update_page", ["page": frog, "tag": "Morning flow"])

        let renamed = try call("update_page_tag", ["container": "Mobility/Hips", "tag": "Morning flow", "title": "Morning mobility", "color": "#ff7ab6"])
        XCTAssertEqual(renamed["title"] as? String, "Morning mobility")
        XCTAssertEqual(renamed["color"] as? String, "FF7AB6")
        XCTAssertEqual(renamed["changed"] as? [String], ["title", "color"])
        XCTAssertEqual(try call("get_page", ["page": frog])["tag"] as? String, "Morning mobility", "pages keep a renamed tag")
        XCTAssertEqual(failure { _ = try self.call("update_page_tag", ["container": "Mobility", "tag": "Morning mobility", "title": "reference"]) }?.code, "already_exists")
        XCTAssertEqual(failure { _ = try self.call("update_page_tag", ["container": "Mobility", "tag": "Morning mobility"]) }?.code, "invalid_argument")

        let preview = try call("delete_page_tag", ["container": "Mobility/Hips", "tag": "Morning mobility"], dryRun: true)
        XCTAssertEqual(preview["untags"] as? Int, 2)
        XCTAssertNotNil(try database.getPage(id: pigeon).typeID, "a dry run changes nothing")
        let deleted = try call("delete_page_tag", ["container": "Mobility/Hips", "tag": "Morning mobility"])
        XCTAssertEqual(deleted["untagged"] as? Int, 2)
        XCTAssertNil(try database.getPage(id: pigeon).typeID)
        XCTAssertNil(try database.getPage(id: frog).typeID)
        XCTAssertEqual(try database.getPage(id: frog).title, "Frog", "the pages themselves stay")

        let left = try call("list_page_tags", ["container": "Mobility"])
        XCTAssertEqual(tagTitles(left), ["Reference"])
        XCTAssertEqual(left["untagged"] as? Int, 2)
        XCTAssertEqual(try call("search_pages", ["query": "", "tag": "Morning mobility"])["total"] as? Int, 0)
        XCTAssertEqual(AgentToolRegistry.tool(named: "delete_page_tag")?.risk, .delete)
    }

    func testCreatingATagTwiceIsRefusedUnlessReusedAndADryRunChangesNothing() throws {
        try call("create_container_page", ["title": "Mobility"])
        let preview = try call("create_page_tag", ["container": "Mobility", "title": "Between sets"], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(preview["preset"] as? String, "Tags")
        XCTAssertEqual(preview["newPreset"] as? Bool, true)
        XCTAssertEqual(try manifest("Mobility").typePresets, [])

        let first = try call("create_page_tag", ["container": "Mobility", "title": "Between sets"])
        let again = failure { _ = try self.call("create_page_tag", ["container": "Mobility", "title": "between SETS"]) }
        XCTAssertEqual(again?.code, "already_exists")
        XCTAssertEqual(again?.details["existingID"] as? String, first["id"] as? String)
        let reused = try call("create_page_tag", ["container": "Mobility", "title": "between sets", "ifExists": "reuse"])
        XCTAssertEqual(reused["reused"] as? Bool, true)
        XCTAssertEqual(reused["id"] as? String, first["id"] as? String)
        XCTAssertEqual(try manifest("Mobility").typePresets.flatMap(\.types).count, 1)

        try call("create_page_tag", ["container": "Mobility", "title": "Skip for now"])
        let presets = try manifest("Mobility").typePresets
        XCTAssertEqual(presets.count, 1, "without a preset the tag joins the first one")
        XCTAssertEqual(presets.first?.types.map(\.title), ["Between sets", "Skip for now"])
        XCTAssertEqual(failure { _ = try self.call("create_page_tag", ["container": "Mobility", "title": "Odd", "color": "nope"]) }?.code, "invalid_argument")
    }

    func testAFailedBatchPutsTagsBackAndRemovesTheTagsItMade() throws {
        try call("create_container_page", ["title": "Mobility"])
        let pigeon = try XCTUnwrap(try call("create_exercise_page", ["title": "Pigeon", "parent": "Mobility"])["id"] as? String)
        let frog = try XCTUnwrap(try call("create_exercise_page", ["title": "Frog", "parent": "Mobility"])["id"] as? String)
        let morning = try XCTUnwrap(try call("create_page_tag", ["container": "Mobility", "title": "Morning flow"])["id"] as? String)
        try call("update_page", ["page": pigeon, "tag": "Morning flow"])

        let failed = failure {
            _ = try self.call("batch", ["operations": [
                ["tool": "create_page_tag", "arguments": ["container": "Mobility", "title": "Evening stretch", "preset": "Evening"]],
                ["tool": "update_page", "arguments": ["page": pigeon, "tag": "Evening stretch"]],
                ["tool": "update_page", "arguments": ["page": frog, "tag": "$0.id"]],
                ["tool": "update_page", "arguments": ["page": "Mobility/Nowhere", "tag": "Morning flow"]],
            ]])
        }
        XCTAssertEqual(failed?.code, "batch_failed")
        XCTAssertEqual(failed?.details["index"] as? Int, 3)
        XCTAssertEqual(try database.getPage(id: pigeon).typeID, morning, "the tag the page wore before is back")
        XCTAssertNil(try database.getPage(id: frog).typeID)
        let presets = try manifest("Mobility").typePresets
        XCTAssertEqual(presets.map(\.title), ["Tags"], "the preset the batch made is gone")
        XCTAssertEqual(presets.flatMap(\.types).map(\.title), ["Morning flow"], "and so is its tag")

        let done = try call("batch", ["operations": [
            ["tool": "update_page", "arguments": ["page": pigeon, "tag": ""]],
            ["tool": "update_page", "arguments": ["page": frog, "tag": "Morning flow"]],
        ]])
        XCTAssertEqual((done["results"] as? [[String: Any]])?.count, 2)
        XCTAssertNil(try database.getPage(id: pigeon).typeID)
        XCTAssertEqual(try database.getPage(id: frog).typeID, morning)
    }

    func testTheTopFolderKeepsTagsWhileSkillsKeepTheirOwnTypes() throws {
        let top = ExercisePageManifest(title: "Calisthenics")
        let drills = ExercisePageManifest(title: "Drills")
        let handstand = ExercisePageManifest(title: "Handstand", pageType: .skill)
        let wallWalk = ExercisePageManifest(title: "Wall Walk", pageKind: .leaf, duration: 30)
        let loose = ExercisePageManifest(title: "Loose", pageKind: .leaf, duration: 30)
        try database.createPage(manifest: top)
        try database.createPage(manifest: drills, parentID: top.id)
        try database.createPage(manifest: handstand, parentID: drills.id)
        try database.createPage(manifest: wallWalk, parentID: handstand.id)
        try database.createPage(manifest: loose)

        XCTAssertEqual(try database.skillTypeOwnerID(of: wallWalk.id), top.id, "an exercise inside a skill takes the top folder's tags")
        XCTAssertEqual(try database.skillTypeOwnerID(of: drills.id), top.id, "a sub-folder answers with its top folder")
        XCTAssertEqual(try database.skillTypeOwnerID(of: handstand.id), handstand.id, "a skill keeps its own types")
        XCTAssertThrowsError(try database.skillTypeOwnerID(of: loose.id), "a loose exercise has no folder to keep tags")

        let warmUp = try database.addSkillType(to: drills.id, title: "Warm-up")
        XCTAssertEqual(try database.getPage(id: top.id).typePresets.flatMap(\.types).map(\.id), [warmUp.id])
        XCTAssertEqual(try database.getPage(id: drills.id).typePresets, [])
        try database.setSkillType(warmUp.id, for: wallWalk.id)
        XCTAssertEqual(try database.getPage(id: wallWalk.id).typeID, warmUp.id)
        XCTAssertThrowsError(try database.setSkillType(warmUp.id, for: handstand.id), "the skill's own types do not hold the folder's tag")
        XCTAssertThrowsError(try database.setSkillType(warmUp.id, for: drills.id), "a folder wears no tag")

        try database.deleteSkillType(warmUp.id, in: wallWalk.id)
        XCTAssertNil(try database.getPage(id: wallWalk.id).typeID, "deleting a tag clears it at every depth below the top folder")
    }

    func testAnOldManifestDecodesWithoutATagAndWritesTheSameContentBack() throws {
        let old = Data("""
        {"childIDs":[],"createdAt":"2026-10-01T08:00:00Z","dropSetTemplates":[],"duration":45,"id":"6F1C2D3E-0000-4000-8000-000000000001","linkMetadata":[],"linkURLs":[],"linkedPageIDs":[],"markdownBody":"Knees at 90 degrees.","mediaComments":{},"mediaFilenames":[],"order":0,"pageKind":"leaf","pageType":"exercise","parentID":"6F1C2D3E-0000-4000-8000-000000000000","skillBoardSections":[],"title":"90-90 Switch","updatedAt":"2026-10-01T08:00:00Z"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoded = try decoder.decode(ExercisePageManifest.self, from: old)
        XCTAssertNil(decoded.typeID)
        XCTAssertEqual(decoded.typePresets, [])
        let written = try encoder.encode(decoded)
        let text = String(decoding: written, as: UTF8.self)
        XCTAssertFalse(text.contains("typeID"), text)
        XCTAssertFalse(text.contains("typePresets"), text)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: written) as? NSDictionary, try JSONSerialization.jsonObject(with: old) as? NSDictionary)
        XCTAssertEqual(try encoder.encode(try decoder.decode(ExercisePageManifest.self, from: written)), written, "a second round trip writes the same bytes")

        var tagged = decoded
        tagged.typeID = "tag-1"
        XCTAssertEqual(try decoder.decode(ExercisePageManifest.self, from: try encoder.encode(tagged)).typeID, "tag-1", "an exercise keeps its tag")
        let folder = Data(#"{"id":"F","title":"Folder","pageKind":"container","typeID":"tag-1"}"#.utf8)
        XCTAssertNil(try decoder.decode(ExercisePageManifest.self, from: folder).typeID, "a folder wears no tag")
    }
}
