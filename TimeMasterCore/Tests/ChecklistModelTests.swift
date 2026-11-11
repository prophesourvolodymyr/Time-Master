import XCTest
@testable import TimeMasterCore

final class ChecklistModelTests: XCTestCase {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: try encoder.encode(value)) as! [String: Any]
    }

    private func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(text.utf8))
    }

    // MARK: Round trips

    func testAManifestWithoutListsDecodesAndEncodesWithoutThem() throws {
        let page = try decode(ExercisePageManifest.self, #"{"id":"P","title":"Single leg","pageType":"skill","markdownBody":""}"#)
        XCTAssertTrue(page.todos.isEmpty)
        XCTAssertTrue(page.milestones.isEmpty)
        let object = try json(page)
        XCTAssertNil(object["todos"])
        XCTAssertNil(object["milestones"])
    }

    func testAPlainTodoWritesOnlyTheFieldsSkillmaxKnows() throws {
        let item = TodoItem(id: "a", title: "Drill entries", createdAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Set(try json(item).keys), ["id", "title", "isDone", "children", "links", "createdAt"])
    }

    func testAPlainMilestoneWritesOnlyTheFieldsSkillmaxKnows() throws {
        let milestone = Milestone(id: "m", title: "First takedown", createdAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Set(try json(milestone).keys), ["id", "title", "note", "isDone", "children", "createdAt"])
    }

    func testRichFieldsAreWrittenOnlyWhenSetAndReadBack() throws {
        let item = TodoItem(
            id: "a", title: "Shadow drill", isDone: true, doneAt: Date(timeIntervalSince1970: 60), links: [TodoLink(id: "l", url: "https://example.com")], createdAt: Date(timeIntervalSince1970: 30),
            isSection: false, note: "Three rounds", iconName: "🥋", iconType: .emoji, iconImage: "icon.png", colorHex: "FF6A00",
            coverMediaFilename: "cover.jpg", imageFilenames: ["a.jpg", "b.jpg"]
        )
        let object = try json(item)
        XCTAssertEqual(object["note"] as? String, "Three rounds")
        XCTAssertEqual(object["iconType"] as? String, "emoji")
        XCTAssertEqual(object["imageFilenames"] as? [String], ["a.jpg", "b.jpg"])
        XCTAssertNil(object["kind"])
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(TodoItem.self, from: data), item)
    }

    func testASectionIsMarkedByKindAndAnOlderReaderSeesATitledEntry() throws {
        let section = TodoItem(id: "s", title: "Footwork", isSection: true)
        XCTAssertEqual(try json(section)["kind"] as? String, "section")
        let read = try decode(TodoItem.self, #"{"id":"s","title":"Footwork","kind":"section","unknownField":3}"#)
        XCTAssertTrue(read.isSection)
        let plain = try decode(TodoItem.self, #"{"id":"t","title":"Footwork"}"#)
        XCTAssertFalse(plain.isSection)
    }

    func testSkillmaxIconTypesAndBrokenEntriesAreReadLeniently() throws {
        let milestone = try decode(Milestone.self, #"{"id":"m","title":"Show","iconName":"star.fill","iconType":"symbol","children":[{"title":"no id"},{"id":"c","title":"Kept"}]}"#)
        XCTAssertEqual(milestone.iconType, .system)
        XCTAssertEqual(milestone.children.map(\.id), ["c"])
        let page = try decode(ExercisePageManifest.self, #"{"id":"P","title":"T","pageType":"skill","todos":[{"id":"1","title":"ok"},{"oops":true}]}"#)
        XCTAssertEqual(page.todos.map(\.id), ["1"])
    }

    func testOnlySkillAndTutorialPagesKeepLists() {
        let todo = TodoItem(title: "x")
        XCTAssertEqual(ExercisePageManifest(title: "S", pageType: .skill, todos: [todo]).todos.count, 1)
        XCTAssertEqual(ExercisePageManifest(title: "T", pageType: .tutorial, milestones: [Milestone(title: "m")]).milestones.count, 1)
        XCTAssertTrue(ExercisePageManifest(title: "E", pageKind: .leaf, todos: [todo], duration: 30).todos.isEmpty)
        XCTAssertTrue(ExercisePageManifest(title: "F", todos: [todo]).todos.isEmpty)
    }

    // MARK: Rules

    func testNormalizingTrimsAndRefusesWhatItWillNotGuess() throws {
        let cleaned = try TodoItem.normalized([TodoItem(id: "a", title: "  Drill\nentries  ", note: "\r\n line \r\n")], mediaFilenames: [])
        XCTAssertEqual(cleaned[0].title, "Drill entries")
        XCTAssertEqual(cleaned[0].note, "line")
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: "  ")], mediaFilenames: []))
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: "x"), TodoItem(id: "a", title: "y")], mediaFilenames: []))
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: String(repeating: "x", count: 501))], mediaFilenames: []))
        XCTAssertThrowsError(try Milestone.normalized([Milestone(id: "a", title: "x", colorHex: "orange")], mediaFilenames: []))
        XCTAssertEqual(try Milestone.normalized([Milestone(id: "a", title: "x", colorHex: "#ff6a00")], mediaFilenames: [])[0].colorHex, "FF6A00")
    }

    func testDepthAndCountCaps() throws {
        func chain(_ depth: Int) -> Milestone {
            var node = Milestone(id: "d\(depth)", title: "level \(depth)")
            if depth > 1 { node.children = [chain(depth - 1)] }
            return node
        }
        XCTAssertNoThrow(try Milestone.normalized([chain(Milestone.maxDepth)], mediaFilenames: []))
        XCTAssertThrowsError(try Milestone.normalized([chain(Milestone.maxDepth + 1)], mediaFilenames: []))
        let many = (0...Milestone.maxPerPage).map { Milestone(id: "\($0)", title: "m\($0)") }
        XCTAssertThrowsError(try Milestone.normalized(many, mediaFilenames: []))
        let repaired = Milestone.repaired([chain(Milestone.maxDepth + 2)] + many, mediaFilenames: [])
        XCTAssertEqual(repaired.progressTotal, Milestone.maxPerPage)
        XCTAssertTrue(repaired.flattened().allSatisfy { $0.depth <= Milestone.maxDepth })
    }

    func testACheckedParentNeverHasAnOpenChild() throws {
        let list = [TodoItem(id: "p", title: "Parent", isDone: true, children: [TodoItem(id: "c", title: "Child")])]
        let cleaned = try TodoItem.normalized(list, mediaFilenames: [], now: Date(timeIntervalSince1970: 5))
        XCTAssertFalse(cleaned[0].isDone)
        XCTAssertNil(cleaned[0].doneAt)
        var parent = TodoItem(id: "p", title: "Parent", children: [TodoItem(id: "c", title: "Child")])
        TodoItem.markDone(&parent, at: Date(timeIntervalSince1970: 9))
        let done = try TodoItem.normalized([parent], mediaFilenames: [])
        XCTAssertTrue(done[0].isDone && done[0].children[0].isDone)
        XCTAssertEqual(done[0].children[0].doneAt, Date(timeIntervalSince1970: 9))
    }

    func testSectionsStayAtTheTopEmptyAndUnchecked() throws {
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "p", title: "P", children: [TodoItem(id: "s", title: "S", isSection: true)])], mediaFilenames: []))
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "s", title: "S", children: [TodoItem(id: "c", title: "C")], isSection: true)], mediaFilenames: []))
        let section = try TodoItem.normalized([TodoItem(id: "s", title: "S", isDone: true, isSection: true, note: "x", coverMediaFilename: "a.jpg")], mediaFilenames: ["a.jpg"])[0]
        XCTAssertFalse(section.isDone)
        XCTAssertTrue(section.note.isEmpty)
        XCTAssertNil(section.coverMediaFilename)
        let repaired = TodoItem.repaired([
            TodoItem(id: "s", title: "S", children: [TodoItem(id: "c", title: "C")], isSection: true),
            TodoItem(id: "p", title: "P", children: [TodoItem(id: "n", title: "Nested section", isSection: true)]),
        ], mediaFilenames: [])
        XCTAssertEqual(repaired.map(\.id), ["s", "c", "p"])
        XCTAssertFalse(repaired[2].children[0].isSection)
    }

    func testProgressIgnoresSectionsAndPartsSplitTheList() {
        let list = [
            TodoItem(id: "a", title: "A", isDone: true),
            TodoItem(id: "s1", title: "Footwork", isSection: true),
            TodoItem(id: "b", title: "B", children: [TodoItem(id: "b1", title: "B1")]),
            TodoItem(id: "s2", title: "Finishes", isSection: true),
            TodoItem(id: "c", title: "C"),
        ]
        XCTAssertEqual(list.progressTotal, 4)
        XCTAssertEqual(list.progressDone, 1)
        XCTAssertEqual(list.openCount, 3)
        XCTAssertEqual(list.parts.map { $0.section?.id }, [nil, "s1", "s2"])
        XCTAssertEqual(list.parts[1].entries.map(\.id), ["b"])
        XCTAssertEqual(list.partEnd(of: nil), 1)
        XCTAssertEqual(list.partEnd(of: "s1"), 3)
        XCTAssertEqual(list.partEnd(of: "s2"), 5)
        XCTAssertEqual(list.section(holding: "c")?.id, "s2")
        XCTAssertNil(list.section(holding: "a"))
        XCTAssertEqual([TodoItem(id: "s", title: "S", isSection: true)].parts.count, 1)
    }

    func testPicturesAndFileLinksAreKeptOnlyWhileThePageHasThem() throws {
        let item = TodoItem(
            id: "a", title: "Grip", links: [TodoLink(url: TmaxLink.mediaURL(filename: "clip.mp4")), TodoLink(url: TmaxLink.mediaURL(filename: "gone.mp4"))],
            iconImage: "icon.png", coverMediaFilename: "clip.mp4", imageFilenames: ["a.jpg", "gone.jpg", "a.jpg"]
        )
        let cleaned = try TodoItem.normalized([item], mediaFilenames: ["a.jpg", "clip.mp4", "icon.png"])[0]
        XCTAssertNil(cleaned.coverMediaFilename, "a video is no cover")
        XCTAssertEqual(cleaned.imageFilenames, ["a.jpg"])
        XCTAssertEqual(cleaned.iconImage, "icon.png")
        XCTAssertEqual(cleaned.links.compactMap(\.target?.mediaFilename), ["clip.mp4"])
        let dropped = [cleaned].droppingMedia("a.jpg").droppingMedia("clip.mp4").droppingMedia("icon.png")[0]
        XCTAssertTrue(dropped.imageFilenames.isEmpty)
        XCTAssertTrue(dropped.links.isEmpty)
        XCTAssertNil(dropped.iconImage)
    }

    func testLinksAreCanonicalUniqueAndCapped() throws {
        let id = UUID().uuidString
        let links = [TodoLink(url: "timemaster://workout/\(id.lowercased())"), TodoLink(url: "timemaster://workout/\(id)"), TodoLink(url: " https://youtu.be/x ")]
        let cleaned = try TodoItem.normalized([TodoItem(id: "a", title: "x", links: links)], mediaFilenames: [])[0]
        XCTAssertEqual(cleaned.links.map(\.url), ["timemaster://workout/\(id)", "https://youtu.be/x"])
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: "x", links: [TodoLink(url: "ftp://nope")])], mediaFilenames: []))
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: "x", links: [TodoLink(url: "timemaster://start")])], mediaFilenames: []))
        let tooMany = (0...TodoItem.maxLinks).map { TodoLink(url: "https://example.com/\($0)") }
        XCTAssertThrowsError(try TodoItem.normalized([TodoItem(id: "a", title: "x", links: tooMany)], mediaFilenames: []))
    }

    // MARK: Derived visuals

    func testTheFirstWorkoutOrPageLinkLendsThePicture() {
        let workout = UUID().uuidString
        let page = UUID().uuidString
        var item = TodoItem(title: "x", links: [
            TodoLink(url: "https://example.com"),
            TodoLink(url: TmaxLink.mediaURL(filename: "a.mp4")),
            TodoLink(target: .page(id: page)),
            TodoLink(target: .workout(id: workout)),
        ])
        XCTAssertEqual(item.visualLink, .page(id: page))
        XCTAssertTrue(item.derivesCover)
        XCTAssertTrue(item.derivesIcon)
        item.coverMediaFilename = "cover.jpg"
        item.iconName = "🥋"
        XCTAssertFalse(item.derivesCover, "an explicit cover wins")
        XCTAssertFalse(item.derivesIcon, "an explicit icon wins")
        XCTAssertNil(TodoItem(title: "plain", links: [TodoLink(url: "https://example.com")]).visualLink)
    }
}

final class TmaxLinkTests: XCTestCase {
    func testLibraryLinksParseAndPrintTheSame() {
        let workout = UUID()
        let page = UUID()
        XCTAssertEqual(TmaxLink("timemaster://workout/\(workout.uuidString.lowercased())"), .workout(id: workout.uuidString))
        XCTAssertEqual(TmaxLink("timemaster://page/\(page.uuidString)"), .page(id: page.uuidString))
        XCTAssertEqual(TmaxLink("timemaster://page/\(page.uuidString)~grp-1"), .page(id: "\(page.uuidString)~grp-1"))
        XCTAssertEqual(TmaxLink("timemaster://media/My%20clip.mov"), .media(filename: "My clip.mov"))
        XCTAssertEqual(TmaxLink(TmaxLink.mediaURL(filename: "My clip.mov")), .media(filename: "My clip.mov"))
        XCTAssertEqual(TmaxLink(" https://youtu.be/abc "), .web("https://youtu.be/abc"))
        for link in [TmaxLink.workout(id: workout.uuidString), .page(id: page.uuidString), .media(filename: "a b.jpg"), .web("https://x.org/a")] {
            XCTAssertEqual(TmaxLink(link.urlString), link)
        }
    }

    func testTheAppRoutesAgreeWithTheDeepLinkHandler() {
        let id = UUID()
        XCTAssertEqual(TmaxLink("timemaster://start"), .start(workoutID: nil))
        XCTAssertEqual(TmaxLink("timemaster://start?workoutID=\(id.uuidString)"), .start(workoutID: id.uuidString))
        XCTAssertEqual(TmaxLink("timemaster://start?workoutID=garbage"), .start(workoutID: nil))
        XCTAssertEqual(TmaxLink("timemaster://detail?workoutID=\(id.uuidString)"), .workout(id: id.uuidString))
        XCTAssertFalse(TmaxLink.start(workoutID: nil).isItemTarget)
        XCTAssertTrue(TmaxLink.workout(id: id.uuidString).providesVisual)
        XCTAssertFalse(TmaxLink.web("https://a.b").providesVisual)
    }

    func testGarbageIsNotALink() {
        for text in ["", "hello", "ftp://x.org", "https://", "timemaster://workout/not-a-uuid", "timemaster://workout/", "timemaster://page/",
                     "timemaster://page/a/b", "timemaster://media/.hidden", "timemaster://unknown/x", "timemaster://open", "skillmax://skill/x"] {
            XCTAssertNil(TmaxLink(text), text)
        }
    }
}
