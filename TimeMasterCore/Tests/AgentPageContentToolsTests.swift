import XCTest
@testable import TimeMasterCore

final class AgentPageContentToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var jabID = ""
    var footworkID = ""
    var guardID = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("page-content-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        try call("create_container_page", ["title": "Boxing", "workoutType": "Strength"])
        jabID = try call("create_exercise_page", ["title": "Jab", "parent": "Boxing", "duration": 30, "sets": 3])["id"] as! String
        try call("create_exercise_page", ["title": "Cross", "parent": "Boxing", "duration": 20, "restAfter": 5])
        footworkID = try call("create_skill_page", ["title": "Footwork", "parent": "Boxing"])["id"] as! String
        guardID = try call("create_skill_page", ["title": "Guard", "parent": "Boxing"])["id"] as! String
        try call("create_skill_page", ["title": "Combos", "parent": "Boxing", "pageType": "tutorial"])
        try call("create_note_page", ["title": "Plan", "parent": "Boxing", "markdownBody": "Round one."])
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

    private func stored(_ page: String) throws -> ExercisePageManifest {
        try database.getPage(id: try AgentPageIndex(database: database).resolve(page).id)
    }

    private func fingerprint(_ page: String) throws -> Data {
        var manifest = try stored(page)
        manifest.updatedAt = Date(timeIntervalSince1970: 0)
        return try JSONEncoder().encode(manifest)
    }

    @discardableResult
    private func attach(_ page: String, _ name: String, comment: String? = nil) throws -> String {
        let folder = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(name)
        try Data(repeating: 7, count: 64).write(to: file)
        var arguments: [String: Any] = ["page": page, "path": file.path]
        if let comment { arguments["comment"] = comment }
        try call("attach_media", arguments)
        return try XCTUnwrap(try stored(page).mediaFilenames.last)
    }

    private func media(_ page: String) throws -> [[String: Any]] {
        try call("get_page", ["page": page])["media"] as? [[String: Any]] ?? []
    }

    private func paths(_ entries: Any?) -> [String?] {
        (entries as? [[String: Any]])?.map { $0["path"] as? String } ?? []
    }

    func testGetPageNumbersTheMediaAndMarksTheCoverTheIconPictureAndLearnFirstFiles() throws {
        try attach("Boxing/Footwork", "a.jpg", comment: "Setup")
        try attach("Boxing/Footwork", "b.mp4")
        try attach("Boxing/Footwork", "c.png")
        var items = try media("Boxing/Footwork")
        XCTAssertEqual(items.map { $0["index"] as? Int }, [1, 2, 3])
        XCTAssertEqual(items.map { $0["kind"] as? String }, ["image", "video", "image"])
        XCTAssertEqual(items[0]["comment"] as? String, "Setup")
        XCTAssertEqual(items.map { $0["cover"] as? Bool }, [true, nil, nil], "without a chosen banner the first file is the cover")
        XCTAssertEqual(items.map { $0["missing"] as? Bool }, [nil, nil, nil])

        try call("update_media", ["page": "Boxing/Footwork", "index": 3, "cover": true, "icon": true, "learnFirst": true])
        items = try media("Boxing/Footwork")
        XCTAssertEqual(items.map { $0["cover"] as? Bool }, [nil, nil, true], "a chosen banner wins over the first file")
        XCTAssertEqual(items.map { $0["icon"] as? Bool }, [nil, nil, true])
        XCTAssertEqual(items.map { $0["learnFirst"] as? Bool }, [nil, nil, true])

        try call("update_media", ["page": "Boxing/Footwork", "index": 3, "cover": false])
        XCTAssertEqual(try media("Boxing/Footwork").map { $0["cover"] as? Bool }, [true, nil, nil])
    }

    func testGetPageListsLinksWithCommentsOnlyWhenOneHasACommentOrFlag() throws {
        let urls = ["https://a.example/one", "https://b.example/two"]
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": urls])
        let plain = try call("get_page", ["page": "Boxing/Footwork"])
        XCTAssertEqual(plain["linkURLs"] as? [String], urls)
        XCTAssertNil(plain["links"])

        try call("update_link", ["page": "Boxing/Footwork", "url": "https://B.example/two/", "comment": "Slow motion", "learnFirst": true])
        let shown = try call("get_page", ["page": "Boxing/Footwork"])
        XCTAssertEqual(shown["linkURLs"] as? [String], urls)
        let links = try XCTUnwrap(shown["links"] as? [[String: Any]])
        XCTAssertEqual(links.map { $0["url"] as? String }, urls)
        XCTAssertNil(links[0]["comment"])
        XCTAssertNil(links[0]["learnFirst"])
        XCTAssertEqual(links[1]["comment"] as? String, "Slow motion")
        XCTAssertEqual(links[1]["learnFirst"] as? Bool, true)
    }

    func testGetPageShowsTheLearnFirstListAttachedPagesIconDropSetsAndDates() throws {
        try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard", "Boxing/Plan"]])
        try call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Jab"]])
        try call("update_page", ["page": "Boxing/Footwork", "icon": "figure.boxing"])
        try call("update_page", ["page": "Boxing/Jab", "dropSets": [["set": 2, "name": "Slow jab", "duration": 20]]])
        let footwork = try call("get_page", ["page": "Boxing/Footwork"])
        XCTAssertEqual(paths(footwork["learnFirst"]), ["Boxing/Guard", "Boxing/Plan"])
        XCTAssertEqual((footwork["learnFirst"] as? [[String: Any]])?.first?["id"] as? String, guardID)
        XCTAssertEqual(paths(footwork["linkedPages"]), ["Boxing/Jab"])
        XCTAssertEqual(footwork["icon"] as? [String: String], ["name": "figure.boxing", "type": "system"])

        let jab = try call("get_page", ["page": "Boxing/Jab"])
        let drops = try XCTUnwrap(jab["dropSets"] as? [[String: Any]])
        XCTAssertEqual(drops.count, 1)
        XCTAssertEqual(drops[0]["set"] as? Int, 2)
        XCTAssertEqual(drops[0]["name"] as? String, "Slow jab")
        XCTAssertEqual(drops[0]["duration"] as? Int, 20)
        XCTAssertEqual(drops[0]["restAfter"] as? Int, 0)
        XCTAssertNil(drops[0]["exercise"])
        for page in [footwork, jab] {
            for key in ["created", "updated"] {
                XCTAssertNotNil((page[key] as? String)?.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression), key)
            }
        }
    }

    func testGetPageLeavesOutEveryNewFieldOfAPlainPage() throws {
        let page = try call("get_page", ["page": "Boxing/Cross"])
        for key in ["media", "links", "learnFirst", "linkedPages", "icon", "dropSets"] {
            XCTAssertNil(page[key], key)
        }
        XCTAssertEqual(page["duration"] as? Int, 20)
        XCTAssertNotNil(page["created"])
    }

    func testGetPageFlagsAnAttachmentWhoseFileIsGone() throws {
        let gone = try attach("Boxing/Jab", "a.jpg")
        try attach("Boxing/Jab", "b.jpg")
        try FileManager.default.removeItem(at: try database.pageMediaURL(pageID: jabID, filename: gone))
        XCTAssertEqual(try media("Boxing/Jab").map { $0["missing"] as? Bool }, [true, nil])
    }

    func testGetPageGivesTheGroupsOfABoardTheirIds() throws {
        let group = try call("create_skill_group", ["parent": "Boxing", "title": "Defence"])
        let groups = try XCTUnwrap(try call("get_page", ["page": "Boxing"])["groups"] as? [[String: Any]])
        XCTAssertEqual(groups.first?["id"] as? String, group["id"] as? String)
        XCTAssertEqual(groups.first?["title"] as? String, "Defence")
    }

    func testUpdateMediaEditsTheCaptionAndMovesTheItemWithItsCaption() throws {
        let first = try attach("Boxing/Jab", "a.jpg", comment: "First")
        let second = try attach("Boxing/Jab", "b.mp4")
        let third = try attach("Boxing/Jab", "c.png", comment: "Third")
        let moved = try call("update_media", ["page": "Boxing/Jab", "index": 3, "position": 1, "comment": "Cover shot"])
        XCTAssertEqual(moved["changed"] as? [String], ["comment", "position"])
        XCTAssertEqual((moved["item"] as? [String: Any])?["index"] as? Int, 1)
        XCTAssertEqual((moved["item"] as? [String: Any])?["comment"] as? String, "Cover shot")
        XCTAssertEqual(try stored("Boxing/Jab").mediaFilenames, [third, first, second])
        XCTAssertEqual(try stored("Boxing/Jab").mediaComments, [third: "Cover shot", first: "First"])

        try call("update_media", ["page": "Boxing/Jab", "index": 2, "comment": "  "])
        XCTAssertEqual(try stored("Boxing/Jab").mediaComments, [third: "Cover shot"])
        try call("update_media", ["page": "Boxing/Jab", "index": 1, "position": 99])
        XCTAssertEqual(try stored("Boxing/Jab").mediaFilenames, [first, second, third])
    }

    func testPositionOneOnlyMakesTheFirstFileTheCoverWhenNoBannerWasChosen() throws {
        try attach("Boxing/Jab", "a.jpg")
        let banner = try attach("Boxing/Jab", "b.mp4")
        try attach("Boxing/Jab", "c.png")
        let first = try call("update_media", ["page": "Boxing/Jab", "index": 3, "position": 1])
        XCTAssertEqual(first["cover"] as? Int, 1)
        XCTAssertNil(first["warnings"])

        try call("update_media", ["page": "Boxing/Jab", "index": 3, "cover": true])
        XCTAssertEqual(try stored("Boxing/Jab").coverMediaFilename, banner)
        let moved = try call("update_media", ["page": "Boxing/Jab", "index": 2, "position": 1])
        XCTAssertEqual(moved["cover"] as? Int, 3, "the chosen banner stays the cover")
        XCTAssertEqual((moved["warnings"] as? [String])?.count, 1)
    }

    func testOnlySkillsAndTutorialsFlagFilesToLearnFirst() throws {
        try attach("Boxing/Footwork", "a.jpg")
        try attach("Boxing/Jab", "a.jpg")
        try call("update_media", ["page": "Boxing/Footwork", "index": 1, "learnFirst": true])
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyMediaFilenames.count, 1)
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 1, "learnFirst": true]) }?.code, "invalid_page")
        XCTAssertTrue(try stored("Boxing/Jab").dependencyMediaFilenames.isEmpty)
        try call("update_media", ["page": "Boxing/Footwork", "index": 1, "learnFirst": false])
        XCTAssertTrue(try stored("Boxing/Footwork").dependencyMediaFilenames.isEmpty)

        try call("update_page", ["page": "Boxing/Footwork", "noSkills": true])
        let hidden = try call("update_media", ["page": "Boxing/Footwork", "index": 1, "learnFirst": true])
        XCTAssertEqual((hidden["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyMediaFilenames.count, 1)
        let list = try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]])
        XCTAssertEqual((list["warnings"] as? [String])?.count, 1)
    }

    func testFoldersKeepAttachmentsTooAndEditThemTheSameWay() throws {
        let first = try attach("Boxing", "a.jpg", comment: "Gym")
        let second = try attach("Boxing", "b.mp4")
        let moved = try call("update_media", ["page": "Boxing", "index": 2, "position": 1, "cover": true, "comment": "Ring"])
        XCTAssertEqual(moved["changed"] as? [String], ["comment", "cover", "position"])
        var folder = try stored("Boxing")
        XCTAssertEqual(folder.mediaFilenames, [second, first])
        XCTAssertEqual(folder.mediaComments, [first: "Gym", second: "Ring"])
        XCTAssertEqual(folder.coverMediaFilename, second)
        XCTAssertEqual(folder.workoutType?.name, "Strength")

        try call("remove_media", ["page": "Boxing", "index": 1])
        folder = try stored("Boxing")
        XCTAssertEqual(folder.mediaFilenames, [first])
        XCTAssertNil(folder.coverMediaFilename)
        XCTAssertEqual(try stored("Boxing/Jab").title, "Jab")
    }

    func testAnIconPictureMustBeAnImageAndOnlyClearsWhenItIsTheOne() throws {
        let picture = try attach("Boxing/Jab", "a.jpg")
        try attach("Boxing/Jab", "b.mp4")
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 2, "icon": true]) }?.code, "invalid_argument")
        try call("update_media", ["page": "Boxing/Jab", "index": 1, "icon": true])
        XCTAssertEqual(try stored("Boxing/Jab").iconImage, picture)

        let untouched = try call("update_media", ["page": "Boxing/Jab", "index": 2, "icon": false])
        XCTAssertEqual(untouched["unchanged"] as? Bool, true)
        XCTAssertEqual(try stored("Boxing/Jab").iconImage, picture)
        try call("update_media", ["page": "Boxing/Jab", "index": 1, "icon": false])
        XCTAssertNil(try stored("Boxing/Jab").iconImage)
    }

    func testAnUnchangedCallWritesNothingAndLeavesNothingToUndo() throws {
        try attach("Boxing/Jab", "a.jpg", comment: "Same")
        let before = try stored("Boxing/Jab")
        let output = try toolbox.call("update_media", arguments: ["page": "Boxing/Jab", "index": 1, "comment": "Same", "position": 1, "cover": false])
        XCTAssertEqual(output.value["unchanged"] as? Bool, true)
        XCTAssertEqual(output.value["changed"] as? [String], [])
        XCTAssertTrue(output.effects.isEmpty)
        XCTAssertEqual(try stored("Boxing/Jab").updatedAt, before.updatedAt)
    }

    func testUpdateMediaExplainsWhatIsWrongWithTheCall() throws {
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 1, "comment": "x"]) }?.code, "not_found")
        try attach("Boxing/Jab", "a.jpg")
        let outOfRange = failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 2, "comment": "x"]) }
        XCTAssertEqual(outOfRange?.code, "not_found")
        XCTAssertTrue(outOfRange?.hint?.contains("1 to 1") == true)
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 1]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "index": 0, "comment": "x"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Jab", "comment": "x"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_media", ["page": "Boxing/Plan", "index": 1, "comment": "x"]) }?.code, "invalid_page")
        XCTAssertTrue(try stored("Boxing/Jab").mediaComments.isEmpty)
    }

    func testUpdateMediaCanBeUndone() throws {
        try attach("Boxing/Footwork", "a.jpg", comment: "First")
        try attach("Boxing/Footwork", "b.mp4")
        let before = try fingerprint("Boxing/Footwork")
        let output = try toolbox.call("update_media", arguments: ["page": "Boxing/Footwork", "index": 2, "position": 1, "comment": "Front", "cover": true, "learnFirst": true])
        XCTAssertNotEqual(try fingerprint("Boxing/Footwork"), before)
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
    }

    func testRemoveMediaDropsTheEntryMovesTheFileToTheTrashAndRenumbers() throws {
        let first = try attach("Boxing/Jab", "a.jpg", comment: "One")
        let second = try attach("Boxing/Jab", "b.mp4", comment: "Two")
        let third = try attach("Boxing/Jab", "c.png", comment: "Three")
        let result = try call("remove_media", ["page": "Boxing/Jab", "index": 2])
        XCTAssertEqual((result["removed"] as? [String: Any])?["index"] as? Int, 2)
        XCTAssertEqual((result["removed"] as? [String: Any])?["kind"] as? String, "video")
        XCTAssertEqual(result["left"] as? Int, 2)
        XCTAssertEqual((result["warnings"] as? [String])?.first?.contains("trash"), true)

        let page = try stored("Boxing/Jab")
        XCTAssertEqual(page.mediaFilenames, [first, third])
        XCTAssertEqual(page.mediaComments, [first: "One", third: "Three"])
        XCTAssertEqual(try media("Boxing/Jab").map { $0["index"] as? Int }, [1, 2])
        XCTAssertFalse(FileManager.default.fileExists(atPath: try database.pageMediaURL(pageID: jabID, filename: second).path))
        let trashed = try FileManager.default.contentsOfDirectory(at: database.fs.trashDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(trashed.contains { $0.lastPathComponent.hasSuffix(second) })
    }

    func testRemovingTheFileTheBannerAndTheIconPointAtClearsThem() throws {
        try attach("Boxing/Footwork", "a.jpg")
        try attach("Boxing/Footwork", "b.png")
        try call("update_media", ["page": "Boxing/Footwork", "index": 1, "cover": true, "icon": true, "learnFirst": true])
        try call("remove_media", ["page": "Boxing/Footwork", "index": 1])
        let page = try stored("Boxing/Footwork")
        XCTAssertNil(page.coverMediaFilename)
        XCTAssertNil(page.iconImage)
        XCTAssertTrue(page.dependencyMediaFilenames.isEmpty)
        XCTAssertEqual(page.mediaFilenames.count, 1)
    }

    func testRemoveMediaAsksForApprovalPreviewsAndUndoKeepsTheEntryButNotTheFile() throws {
        XCTAssertEqual(AgentToolRegistry.tool(named: "remove_media")?.risk, .delete)
        let filename = try attach("Boxing/Jab", "a.jpg", comment: "Keep me")
        let before = try fingerprint("Boxing/Jab")
        let preview = try call("remove_media", ["page": "Boxing/Jab", "index": 1], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(preview["left"] as? Int, 0)
        XCTAssertEqual(try fingerprint("Boxing/Jab"), before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try database.pageMediaURL(pageID: jabID, filename: filename).path))

        let output = try toolbox.call("remove_media", arguments: ["page": "Boxing/Jab", "index": 1])
        XCTAssertTrue(try stored("Boxing/Jab").mediaFilenames.isEmpty)
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Jab"), before)
        XCTAssertEqual(try media("Boxing/Jab").first?["missing"] as? Bool, true)
        let again = try call("remove_media", ["page": "Boxing/Jab", "index": 1])
        XCTAssertNil(again["warnings"], "nothing moved to the trash, the file was already gone")
    }

    func testUpdateLinkFindsTheLinkIgnoringCaseAndATrailingSlashAndEditsItsCommentAndFlag() throws {
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": ["https://a.example/one", "https://b.example/two"]])
        let commented = try call("update_link", ["page": "Boxing/Footwork", "url": "HTTPS://A.example/one/", "comment": "Start here"])
        XCTAssertEqual(commented["changed"] as? [String], ["comment"])
        XCTAssertEqual((commented["link"] as? [String: Any])?["url"] as? String, "https://a.example/one")
        try call("update_link", ["page": "Boxing/Footwork", "url": "https://b.example/two", "learnFirst": true])
        var page = try stored("Boxing/Footwork")
        XCTAssertEqual(page.linkComments, ["https://a.example/one": "Start here"])
        XCTAssertEqual(page.dependencyLinkURLs, ["https://b.example/two"])

        try call("update_link", ["page": "Boxing/Footwork", "url": "https://a.example/one", "comment": ""])
        try call("update_link", ["page": "Boxing/Footwork", "url": "https://b.example/two", "learnFirst": false])
        page = try stored("Boxing/Footwork")
        XCTAssertTrue(page.linkComments.isEmpty)
        XCTAssertTrue(page.dependencyLinkURLs.isEmpty)
        XCTAssertEqual(page.linkURLs, ["https://a.example/one", "https://b.example/two"])
    }

    func testChangingTheAddressKeepsThePlaceTheCommentTheFlagAndThePreviewsInStep() throws {
        let urls = ["https://a.example/1", "https://b.example/2", "https://c.example/3"]
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": urls])
        try call("update_link", ["page": "Boxing/Footwork", "url": urls[1], "comment": "Drill", "learnFirst": true])
        var seeded = try stored("Boxing/Footwork")
        seeded.linkMetadata = urls.map { LinkMetadata(url: $0, title: "Title of \($0)") }
        try database.updatePage(id: footworkID, manifest: seeded, newParentID: seeded.parentID)

        let result = try call("update_link", ["page": "Boxing/Footwork", "url": "HTTPS://B.example/2/", "newURL": "b.example/two"])
        XCTAssertEqual(result["changed"] as? [String], ["newURL"])
        let page = try stored("Boxing/Footwork")
        let moved = "https://b.example/two"
        XCTAssertEqual(page.linkURLs, [urls[0], moved, urls[2]])
        XCTAssertEqual(page.linkComments, [moved: "Drill"])
        XCTAssertEqual(page.dependencyLinkURLs, [moved])
        XCTAssertEqual(page.linkMetadata.map(\.url), page.linkURLs)
        XCTAssertEqual(page.linkMetadata.map(\.title), ["Title of \(urls[0])", nil, "Title of \(urls[2])"])

        XCTAssertEqual(failure { try self.call("update_link", ["page": "Boxing/Footwork", "url": moved, "newURL": "HTTPS://A.example/1/"]) }?.code, "already_exists")
        XCTAssertEqual(failure { try self.call("update_link", ["page": "Boxing/Footwork", "url": moved, "newURL": "not an address"]) }?.code, "invalid_argument")
        XCTAssertEqual(try stored("Boxing/Footwork").linkURLs, [urls[0], moved, urls[2]])
    }

    func testAnAddressThatFitsSeveralLinksMustBeGivenExactly() throws {
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": ["https://A.example/x", "https://a.example/x/"]])
        let vague = failure { try self.call("update_link", ["page": "Boxing/Footwork", "url": "https://a.example/X", "comment": "x"]) }
        XCTAssertEqual(vague?.code, "ambiguous")
        try call("update_link", ["page": "Boxing/Footwork", "url": "https://A.example/x", "comment": "First"])
        XCTAssertEqual(try stored("Boxing/Footwork").linkComments, ["https://A.example/x": "First"])
    }

    func testUpdateLinkListsTheLinksWhenTheAddressIsWrongAndKeepsToTheRulesOfEachPageKind() throws {
        let none = failure { try self.call("update_link", ["page": "Boxing/Jab", "url": "https://x.example", "comment": "x"]) }
        XCTAssertEqual(none?.code, "not_found")
        XCTAssertTrue(none?.hint?.contains("no links") == true)

        try call("update_page", ["page": "Boxing/Jab", "linkURLs": ["https://a.example/one"]])
        let wrong = failure { try self.call("update_link", ["page": "Boxing/Jab", "url": "https://x.example", "comment": "x"]) }
        XCTAssertEqual(wrong?.code, "not_found")
        XCTAssertTrue(wrong?.hint?.contains("https://a.example/one") == true)
        XCTAssertEqual(failure { try self.call("update_link", ["page": "Boxing/Jab", "url": "https://a.example/one"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_link", ["page": "Boxing/Jab", "url": "https://a.example/one", "learnFirst": true]) }?.code, "invalid_page")
        XCTAssertEqual(failure { try self.call("update_link", ["page": "Boxing/Plan", "url": "https://a.example/one", "comment": "x"]) }?.code, "invalid_page")

        let commented = try call("update_link", ["page": "Boxing/Jab", "url": "https://a.example/one", "comment": "Footwork drill"])
        XCTAssertEqual((commented["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(try stored("Boxing/Jab").linkComments, ["https://a.example/one": "Footwork drill"])
    }

    func testUpdateLinkCanBeUndone() throws {
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": ["https://a.example/1"]])
        let before = try fingerprint("Boxing/Footwork")
        let output = try toolbox.call("update_link", arguments: ["page": "Boxing/Footwork", "url": "https://a.example/1", "comment": "Note", "learnFirst": true, "newURL": "https://a.example/2"])
        XCTAssertNotEqual(try fingerprint("Boxing/Footwork"), before)
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
    }

    func testLearnFirstAddsRemovesAndOrdersTheList() throws {
        let combos = try stored("Boxing/Combos").id
        let added = try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard", "Boxing/Combos"]])
        XCTAssertEqual(added["changed"] as? [String], ["add"])
        XCTAssertEqual(paths(added["learnFirst"]), ["Boxing/Guard", "Boxing/Combos"])
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyPageIDs, [guardID, combos])

        let reordered = try call("update_learn_first", ["page": "Boxing/Footwork", "order": ["Boxing/Combos", "Boxing/Guard"]])
        XCTAssertEqual(reordered["changed"] as? [String], ["order"])
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyPageIDs, [combos, guardID])

        let swapped = try call("update_learn_first", ["page": "Boxing/Footwork", "remove": ["Boxing/Combos"], "add": ["Boxing/Plan"], "order": ["Boxing/Plan", "Boxing/Guard"]])
        XCTAssertEqual(swapped["changed"] as? [String], ["remove", "add"])
        XCTAssertEqual(paths(swapped["learnFirst"]), ["Boxing/Plan", "Boxing/Guard"])

        let again = try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]])
        XCTAssertEqual(again["unchanged"] as? Bool, true)
        XCTAssertEqual(again["alreadyListed"] as? [String], ["Boxing/Guard"])
    }

    func testLearnFirstRefusesSelfLoopsAndPagesThatDoNotExist() throws {
        try call("update_learn_first", ["page": "Boxing/Guard", "add": ["Boxing/Footwork"]])
        try call("update_learn_first", ["page": "Boxing/Combos", "add": ["Boxing/Guard"]])
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Footwork"]]) }?.code, "invalid_argument")
        let loop = failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]]) }
        XCTAssertEqual(loop?.code, "invalid_argument")
        XCTAssertTrue(loop?.message.contains("already waits") == true)
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Combos"]]) }?.code, "invalid_argument", "an indirect loop is refused too")
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Nothing"]]) }?.code, "not_found")
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Jab", "add": ["Boxing/Guard"]]) }?.code, "invalid_page")
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork"]) }?.code, "invalid_argument")
        XCTAssertTrue(try stored("Boxing/Footwork").dependencyPageIDs.isEmpty)
    }

    func testAnOrderMustNameEveryPageOfTheListOnce() throws {
        try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard", "Boxing/Combos"]])
        let partial = failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "order": ["Boxing/Guard"]]) }
        XCTAssertEqual(partial?.code, "invalid_argument")
        XCTAssertTrue(partial?.hint?.contains("Boxing/Combos") == true)
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "order": ["Boxing/Guard", "Boxing/Guard", "Boxing/Combos"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "order": ["Boxing/Guard", "Boxing/Combos", "Boxing/Plan"]]) }?.code, "invalid_argument")
        let absent = try call("update_learn_first", ["page": "Boxing/Footwork", "remove": ["Boxing/Plan"]])
        XCTAssertEqual(absent["unchanged"] as? Bool, true)
        XCTAssertEqual(absent["notListed"] as? [String], ["Boxing/Plan"])
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "remove": ["Boxing/Nothing"]]) }?.code, "not_found")
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyPageIDs.count, 2)
    }

    func testLearnFirstTakesASkillGroupById() throws {
        let groupID = try XCTUnwrap(try call("create_skill_group", ["parent": "Boxing", "title": "Defence"])["id"] as? String)
        let added = try call("update_learn_first", ["page": "Boxing/Footwork", "add": [groupID]])
        let entry = try XCTUnwrap((added["learnFirst"] as? [[String: Any]])?.first)
        XCTAssertEqual(entry["id"] as? String, groupID)
        XCTAssertEqual(entry["path"] as? String, "Boxing/Defence")
        XCTAssertEqual(entry["group"] as? Bool, true)
        XCTAssertEqual(try stored("Boxing/Footwork").dependencyPageIDs, [groupID])
        XCTAssertEqual(failure { try self.call("update_learn_first", ["page": "Boxing/Footwork", "add": ["\(self.stored("Boxing").id)~nothing"]]) }?.code, "not_found")

        try call("update_learn_first", ["page": "Boxing/Footwork", "remove": [groupID]])
        XCTAssertTrue(try stored("Boxing/Footwork").dependencyPageIDs.isEmpty)
    }

    func testAnEntryWhoseCompanionPageWasDeletedShowsAsMissingAndCanStillBeRemoved() throws {
        try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard", "Boxing/Combos"]])
        try call("delete_page", ["page": "Boxing/Guard"])
        let shown = try XCTUnwrap(try call("get_page", ["page": "Boxing/Footwork"])["learnFirst"] as? [[String: Any]])
        XCTAssertEqual(shown[0]["id"] as? String, guardID)
        XCTAssertEqual(shown[0]["missing"] as? Bool, true)
        XCTAssertEqual(shown[1]["path"] as? String, "Boxing/Combos")

        let removed = try call("update_learn_first", ["page": "Boxing/Footwork", "remove": [guardID]])
        XCTAssertEqual(paths(removed["learnFirst"]), ["Boxing/Combos"])
    }

    func testLearnFirstDryRunChangesNothingAndTheEditCanBeUndone() throws {
        try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]])
        let before = try fingerprint("Boxing/Footwork")
        let preview = try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Combos"], "remove": ["Boxing/Guard"]], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(preview["wouldChange"] as? [String], ["remove", "add"])
        XCTAssertEqual(paths(preview["learnFirst"]), ["Boxing/Combos"])
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)

        let output = try toolbox.call("update_learn_first", arguments: ["page": "Boxing/Footwork", "add": ["Boxing/Combos"], "remove": ["Boxing/Guard"]])
        XCTAssertNotEqual(try fingerprint("Boxing/Footwork"), before)
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
    }

    func testLinkedPagesAddRemoveAndOrder() throws {
        let added = try call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Jab", "Boxing/Cross", "Boxing/Plan", "Boxing/Jab"]])
        XCTAssertEqual(paths(added["linkedPages"]), ["Boxing/Jab", "Boxing/Cross", "Boxing/Plan"])
        XCTAssertEqual(added["changed"] as? [String], ["add"])
        try call("update_linked_pages", ["page": "Boxing/Footwork", "order": ["Boxing/Plan", "Boxing/Jab", "Boxing/Cross"]])
        let removed = try call("update_linked_pages", ["page": "Boxing/Footwork", "remove": ["Boxing/Jab"]])
        XCTAssertEqual(paths(removed["linkedPages"]), ["Boxing/Plan", "Boxing/Cross"])
        XCTAssertEqual(try stored("Boxing/Footwork").linkedPageIDs.count, 2)
        XCTAssertEqual(paths(try call("get_page", ["page": "Boxing/Footwork"])["linkedPages"]), ["Boxing/Plan", "Boxing/Cross"])
    }

    func testLinkedPagesRefuseSelfMissingPagesAndPagesThatCannotKeepThem() throws {
        XCTAssertEqual(failure { try self.call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Footwork"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Nothing"]]) }?.code, "not_found")
        for owner in ["Boxing/Jab", "Boxing", "Boxing/Plan"] {
            XCTAssertEqual(failure { try self.call("update_linked_pages", ["page": owner, "add": ["Boxing/Cross"]]) }?.code, "invalid_page", owner)
        }
        try call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Jab", "Boxing/Cross"]])
        XCTAssertEqual(failure { try self.call("update_linked_pages", ["page": "Boxing/Footwork", "order": ["Boxing/Jab", "Boxing/Jab"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("update_linked_pages", ["page": "Boxing/Footwork", "order": ["Boxing/Jab"]]) }?.code, "invalid_argument")
        XCTAssertEqual(try stored("Boxing/Footwork").linkedPageIDs.count, 2)
    }

    func testLinkedPagesDryRunChangesNothingAndTheEditCanBeUndone() throws {
        let before = try fingerprint("Boxing/Footwork")
        let preview = try call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Jab"]], dryRun: true)
        XCTAssertEqual(preview["wouldChange"] as? [String], ["add"])
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
        let output = try toolbox.call("update_linked_pages", arguments: ["page": "Boxing/Footwork", "add": ["Boxing/Jab"]])
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
    }

    func testUpdatePageReplacesAndClearsTheDropSets() throws {
        let result = try call("update_page", ["page": "Boxing/Jab", "dropSets": [
            ["exercise": "Boxing/Cross"],
            ["set": 1, "name": "  Slow jab  ", "duration": 45, "restAfter": 10],
        ]])
        XCTAssertEqual(result["changed"] as? [String], ["dropSets"])
        var templates = try stored("Boxing/Jab").dropSetTemplates
        XCTAssertEqual(templates.map(\.setIndex), [2, 0], "set is 1-based, the default is the page's last set")
        XCTAssertEqual(templates.map(\.name), ["Cross", "Slow jab"])
        XCTAssertEqual(templates.map(\.duration), [20, 45])
        XCTAssertEqual(templates.map(\.restAfter), [5, 10])
        XCTAssertEqual(templates[0].exerciseID, try stored("Boxing/Cross").id)
        XCTAssertEqual(templates[1].exerciseID, "")

        let shown = try XCTUnwrap(try call("get_page", ["page": "Boxing/Jab"])["dropSets"] as? [[String: Any]])
        XCTAssertEqual((shown[0]["exercise"] as? [String: Any])?["path"] as? String, "Boxing/Cross")
        XCTAssertEqual(shown.map { $0["set"] as? Int }, [3, 1])

        let ids = templates.map(\.id)
        try call("update_page", ["page": "Boxing/Jab", "dropSets": [
            ["exercise": "Boxing/Cross"],
            ["set": 1, "name": "Slow jab", "duration": 60, "restAfter": 10],
            ["set": 2, "name": "Shadow"],
        ]])
        templates = try stored("Boxing/Jab").dropSetTemplates
        XCTAssertEqual(Array(templates.map(\.id).prefix(2)), ids, "an unchanged drop set keeps its identity")
        XCTAssertEqual(templates.count, 3)

        try call("update_page", ["page": "Boxing/Jab", "dropSets": [[String: Any]]()])
        XCTAssertTrue(try stored("Boxing/Jab").dropSetTemplates.isEmpty)
        XCTAssertNil(try call("get_page", ["page": "Boxing/Jab"])["dropSets"])
    }

    func testDropSetsAreCheckedAgainstThePageAndTheLibrary() throws {
        func drops(_ items: [[String: Any]], _ page: String = "Boxing/Jab") -> AgentToolError? {
            failure { try self.call("update_page", ["page": page, "dropSets": items]) }
        }
        XCTAssertEqual(drops([["name": "x"]], "Boxing")?.code, "invalid_page")
        XCTAssertEqual(drops([["name": "x"]], "Boxing/Footwork")?.code, "invalid_page")
        XCTAssertEqual(drops([["name": "x"]], "Boxing/Plan")?.code, "invalid_page")
        let beyond = drops([["name": "x", "set": 4]])
        XCTAssertEqual(beyond?.code, "invalid_argument")
        XCTAssertTrue(beyond?.hint?.contains("sets") == true)
        XCTAssertEqual(drops([["set": 1]])?.code, "invalid_argument")
        XCTAssertEqual(drops([["name": "x", "duration": 2]])?.code, "invalid_argument")
        XCTAssertEqual(drops([["exercise": "Boxing"]])?.code, "invalid_argument")
        XCTAssertEqual(drops([["exercise": "Boxing/Nothing"]])?.code, "not_found")
        XCTAssertTrue(try stored("Boxing/Jab").dropSetTemplates.isEmpty)

        try call("update_page", ["page": "Boxing/Jab", "sets": 5, "dropSets": [["name": "Fifth", "set": 5]]])
        XCTAssertEqual(try stored("Boxing/Jab").dropSetTemplates.map(\.setIndex), [4])
        let preview = try call("update_page", ["page": "Boxing/Jab", "dropSets": [[String: Any]]()], dryRun: true)
        XCTAssertEqual(preview["wouldChange"] as? [String], ["dropSets"])
        XCTAssertEqual(try stored("Boxing/Jab").dropSetTemplates.count, 1)

        try call("create_exercise_page", ["title": "Temporary", "parent": "Boxing", "duration": 15])
        try call("update_page", ["page": "Boxing/Jab", "dropSets": [["exercise": "Boxing/Temporary"]]])
        let temporaryID = try stored("Boxing/Temporary").id
        XCTAssertEqual(((try call("get_page", ["page": "Boxing/Jab"])["dropSets"] as? [[String: Any]])?.first?["exercise"] as? [String: Any])?["id"] as? String, temporaryID)
        try call("delete_page", ["page": "Boxing/Temporary"])
        let gone = (try call("get_page", ["page": "Boxing/Jab"])["dropSets"] as? [[String: Any]])?.first?["exercise"] as? [String: Any]
        XCTAssertEqual(gone?["missing"] as? Bool, true)
        XCTAssertEqual(try stored("Boxing/Jab").dropSetTemplates.first?.name, "Temporary")
    }

    func testEveryKindOfPageTakesASymbolOrAnEmojiIcon() throws {
        try call("update_page", ["page": "Boxing/Jab", "icon": "figure.boxing"])
        try call("update_page", ["page": "Boxing", "icon": "🥊"])
        try call("update_page", ["page": "Boxing/Plan", "icon": "note.text"])
        XCTAssertEqual(try stored("Boxing/Jab").iconType, .system)
        XCTAssertEqual(try stored("Boxing").iconType, .emoji)
        XCTAssertEqual(try call("get_page", ["page": "Boxing"])["icon"] as? [String: String], ["name": "🥊", "type": "emoji"])
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Plan"])["icon"] as? [String: String], ["name": "note.text", "type": "system"])

        try call("update_page", ["page": "Boxing/Jab", "icon": " "])
        XCTAssertNil(try stored("Boxing/Jab").iconName)
        XCTAssertNil(try call("get_page", ["page": "Boxing/Jab"])["icon"])

        var web = try stored("Boxing/Cross")
        web.iconImage = "https://example.com/cross.png"
        try database.updatePage(id: web.id, manifest: web, newParentID: web.parentID)
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Cross"])["icon"] as? [String: String], ["image": "https://example.com/cross.png"])
    }

    func testUpdatePageEditsCanNowBeUndone() throws {
        let before = try fingerprint("Boxing/Jab")
        let output = try toolbox.call("update_page", arguments: [
            "page": "Boxing/Jab", "title": "Straight", "markdownBody": "Snap it", "duration": 45, "icon": "bolt",
            "dropSets": [["name": "Slow", "set": 1]],
        ])
        XCTAssertEqual(try stored("Boxing/Straight").dropSetTemplates.count, 1)
        toolbox.revert(output.effects)
        XCTAssertEqual(try fingerprint("Boxing/Jab"), before)
        XCTAssertEqual(try stored("Boxing/Jab").title, "Jab")
    }

    func testABatchRollsBackPageContentEditsWhenALaterStepFails() throws {
        try attach("Boxing/Footwork", "a.jpg")
        try attach("Boxing/Footwork", "b.mp4")
        let before = try fingerprint("Boxing/Footwork")
        let error = failure {
            _ = try self.call("batch", ["operations": [
                ["tool": "update_media", "arguments": ["page": "Boxing/Footwork", "index": 2, "position": 1, "comment": "Front"]],
                ["tool": "update_learn_first", "arguments": ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]]],
                ["tool": "update_link", "arguments": ["page": "Boxing/Footwork", "url": "https://nowhere.example", "comment": "x"]],
            ]])
        }
        XCTAssertEqual(error?.code, "batch_failed")
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
    }

    func testDryRunNeverTouchesAPage() throws {
        try attach("Boxing/Footwork", "a.jpg")
        try attach("Boxing/Footwork", "b.mp4")
        try call("update_page", ["page": "Boxing/Footwork", "linkURLs": ["https://a.example/1"]])
        let before = try fingerprint("Boxing/Footwork")
        let jabBefore = try fingerprint("Boxing/Jab")
        let previews = [
            try call("update_media", ["page": "Boxing/Footwork", "index": 2, "position": 1, "comment": "x", "learnFirst": true, "cover": true], dryRun: true),
            try call("remove_media", ["page": "Boxing/Footwork", "index": 1], dryRun: true),
            try call("update_link", ["page": "Boxing/Footwork", "url": "https://a.example/1", "comment": "x", "newURL": "https://a.example/2"], dryRun: true),
            try call("update_learn_first", ["page": "Boxing/Footwork", "add": ["Boxing/Guard"]], dryRun: true),
            try call("update_linked_pages", ["page": "Boxing/Footwork", "add": ["Boxing/Jab"]], dryRun: true),
            try call("update_page", ["page": "Boxing/Jab", "dropSets": [["name": "x"]], "icon": "bolt"], dryRun: true),
        ]
        for preview in previews { XCTAssertEqual(preview["dryRun"] as? Bool, true) }
        XCTAssertEqual(try fingerprint("Boxing/Footwork"), before)
        XCTAssertEqual(try fingerprint("Boxing/Jab"), jabBefore)
        XCTAssertEqual(try media("Boxing/Footwork").count, 2)
    }

    func testPagesSavedBeforeTheseFieldsExistedReadAndEditUnchanged() throws {
        let old = #"{"id":"legacy-skill","title":"Legacy","pageKind":"container","pageType":"skill","mediaFilenames":["a.jpg","b.jpg"],"mediaComments":{"a.jpg":"Keep"},"linkURLs":["https://old.example"],"markdownBody":"Keep this"}"#
        try database.createPage(manifest: try JSONDecoder().decode(ExercisePageManifest.self, from: Data(old.utf8)))
        let shown = try call("get_page", ["page": "legacy-skill"])
        XCTAssertEqual((shown["media"] as? [[String: Any]])?.map { $0["index"] as? Int }, [1, 2])
        XCTAssertEqual((shown["media"] as? [[String: Any]])?.first?["comment"] as? String, "Keep")
        for key in ["links", "learnFirst", "linkedPages", "icon", "dropSets"] { XCTAssertNil(shown[key], key) }

        try call("update_media", ["page": "legacy-skill", "index": 2, "comment": "Second"])
        let page = try database.getPage(id: "legacy-skill")
        XCTAssertEqual(page.mediaComments, ["a.jpg": "Keep", "b.jpg": "Second"])
        XCTAssertEqual(page.mediaFilenames, ["a.jpg", "b.jpg"])
        XCTAssertEqual(page.markdownBody, "Keep this")
        XCTAssertEqual(page.linkURLs, ["https://old.example"])
    }

    func testTheNewToolsNeedNoApprovalExceptRemovingAndStayOutOfTheChat() {
        for name in ["update_media", "update_link", "update_learn_first", "update_linked_pages"] {
            XCTAssertEqual(AgentToolRegistry.tool(named: name)?.risk, .write, name)
            XCTAssertEqual(AgentToolRegistry.tool(named: name)?.coach, false, name)
        }
        XCTAssertEqual(AgentToolRegistry.tool(named: "remove_media")?.coach, false)
        XCTAssertEqual(AgentToolRegistry.effectiveRisk(of: "remove_media", arguments: [:]), .delete)
    }

    func testTheSkillGuideNamesEveryTool() throws {
        let guide = try String(contentsOf: database.fs.skillsDirectory.appendingPathComponent("page-content.md"), encoding: .utf8)
        for name in ["get_page", "update_media", "remove_media", "update_link", "update_learn_first", "update_linked_pages", "dropSets"] {
            XCTAssertTrue(guide.contains(name), name)
        }
    }
}
