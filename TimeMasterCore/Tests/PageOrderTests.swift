import XCTest
@testable import TimeMasterCore

final class PageOrderTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("order-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func folder(_ title: String, parent: String? = nil) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageKind: .container)
        try database.createPage(manifest: manifest, parentID: parent)
        return try database.getPage(id: manifest.id)
    }

    @discardableResult
    private func exercise(_ title: String, parent: String) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageKind: .leaf, duration: 30)
        try database.createPage(manifest: manifest, parentID: parent)
        return try database.getPage(id: manifest.id)
    }

    private func walkedChildIDs(of id: String) throws -> [String] {
        try XCTUnwrap(database.walkPageTree(in: database.exercisesDatabaseURL).first { $0.0.id == id }?.0.childIDs)
    }

    private func modificationDate(of id: String) throws -> Date? {
        let manifestURL = try database.resolvePageFolder(id: id).appendingPathComponent("manifest.json")
        return try FileManager.default.attributesOfItem(atPath: manifestURL.path)[.modificationDate] as? Date
    }

    func testPlacingPutsAPageRightBeforeOrAfterAnother() {
        let ids = ["a", "b", "c", "d"]
        XCTAssertEqual(PageOrder.placing("d", nextTo: "a", after: false, in: ids), ["d", "a", "b", "c"])
        XCTAssertEqual(PageOrder.placing("a", nextTo: "c", after: true, in: ids), ["b", "c", "a", "d"])
        XCTAssertEqual(PageOrder.placing("a", nextTo: "c", after: false, in: ids), ["b", "a", "c", "d"])
        XCTAssertEqual(PageOrder.placing("b", nextTo: "d", after: true, in: ids), ["a", "c", "d", "b"])
        XCTAssertEqual(PageOrder.placing("b", nextTo: "b", after: true, in: ids), ids, "a page next to itself stays")
        XCTAssertNil(PageOrder.placing("x", nextTo: "a", after: false, in: ids))
        XCTAssertNil(PageOrder.placing("a", nextTo: "x", after: false, in: ids))
    }

    func testSiblingsSortByPlaceThenAgeThenID() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let first = ExercisePageManifest(id: "b", title: "First", order: 0, createdAt: late)
        let second = ExercisePageManifest(id: "z", title: "Second", order: 1, createdAt: early)
        let tieOld = ExercisePageManifest(id: "y", title: "Old", order: 2, createdAt: early)
        let tieNew = ExercisePageManifest(id: "a", title: "New", order: 2, createdAt: late)
        let tieSame = ExercisePageManifest(id: "x", title: "Same", order: 2, createdAt: early)
        let sorted = [tieNew, second, tieOld, first, tieSame].sorted(by: PageOrder.precedes)
        XCTAssertEqual(sorted.map(\.id), ["b", "z", "x", "y", "a"])
    }

    func testPlacingAPageInsideAContainerRenumbersItsSiblingsAndTheContainerFollows() throws {
        let parent = try folder("Drills")
        let a = try exercise("A", parent: parent.id)
        let b = try exercise("B", parent: parent.id)
        let c = try exercise("C", parent: parent.id)
        let d = try exercise("D", parent: parent.id)

        let placed = try database.placePage(id: d.id, nextTo: a.id, after: false)

        let expected = [d.id, a.id, b.id, c.id]
        XCTAssertEqual(placed, expected)
        XCTAssertEqual(try expected.map { try database.getPage(id: $0).order }, [0, 1, 2, 3])
        XCTAssertEqual(try database.getPage(id: parent.id).childIDs, expected)
        XCTAssertEqual(try walkedChildIDs(of: parent.id), expected, "the library lists the children in their stored order")
        XCTAssertEqual(try database.getPage(id: a.id).updatedAt, a.updatedAt, "a new place is not an edit of the page")

        try database.placePage(id: d.id, nextTo: c.id, after: true)
        XCTAssertEqual(try walkedChildIDs(of: parent.id), [a.id, b.id, c.id, d.id])
    }

    func testPlacingATopLevelPageRewritesOnlyThePagesThatMoved() throws {
        let a = try folder("A")
        let b = try folder("B")
        let c = try folder("C")
        let d = try folder("D")
        let untouchedA = try modificationDate(of: a.id)
        let untouchedD = try modificationDate(of: d.id)

        try database.placePage(id: b.id, nextTo: c.id, after: true)

        XCTAssertEqual(try database.storedSiblings(parentID: nil).map { $0.manifest.id }, [a.id, c.id, b.id, d.id])
        XCTAssertEqual(try database.getPage(id: c.id).order, 1)
        XCTAssertEqual(try database.getPage(id: b.id).order, 2)
        XCTAssertEqual(try modificationDate(of: a.id), untouchedA, "pages that keep their place are not rewritten")
        XCTAssertEqual(try modificationDate(of: d.id), untouchedD, "pages that keep their place are not rewritten")
    }

    func testAPageOnlyTakesAPlaceNextToASibling() throws {
        let parent = try folder("Drills")
        let inside = try exercise("Inside", parent: parent.id)
        let outside = try folder("Outside")
        XCTAssertThrowsError(try database.placePage(id: inside.id, nextTo: outside.id, after: false))
        XCTAssertEqual(try database.getPage(id: inside.id).parentID, parent.id)
    }

    func testANewTopLevelPageGoesAfterTheLastOneEvenWhenDeletionsLeftGaps() throws {
        let a = try folder("A")
        let b = try folder("B")
        let c = try folder("C")
        try database.deletePage(id: a.id)
        try database.deletePage(id: b.id)

        let d = try folder("D")

        XCTAssertGreaterThan(d.order, try database.getPage(id: c.id).order)
        XCTAssertEqual(try database.storedSiblings(parentID: nil).map { $0.manifest.id }, [c.id, d.id])
    }

    func testMovingAPageToTheEndOfAContainerPutsItAfterEveryPageThere() throws {
        let parent = try folder("Drills")
        let a = try exercise("A", parent: parent.id)
        let b = try exercise("B", parent: parent.id)
        let c = try exercise("C", parent: parent.id)
        try database.deletePage(id: a.id)
        let loose = try folder("Loose")

        try database.movePageToEnd(id: loose.id, parentID: parent.id)

        XCTAssertEqual(try database.getPage(id: loose.id).parentID, parent.id)
        XCTAssertEqual(try walkedChildIDs(of: parent.id), [b.id, c.id, loose.id])
        XCTAssertEqual(try database.getPage(id: parent.id).childIDs.last, loose.id)
        XCTAssertGreaterThan(try database.getPage(id: loose.id).order, try database.getPage(id: c.id).order)
    }

    func testReorderingChildrenRenumbersThemSoTheLibraryListsTheNewOrder() throws {
        let parent = try folder("Drills")
        let a = try exercise("A", parent: parent.id)
        let b = try exercise("B", parent: parent.id)
        let c = try exercise("C", parent: parent.id)

        try database.reorderChildren(parentID: parent.id, childIDs: [c.id, a.id, b.id])

        XCTAssertEqual(try walkedChildIDs(of: parent.id), [c.id, a.id, b.id])
        XCTAssertEqual(try [c.id, a.id, b.id].map { try database.getPage(id: $0).order }, [0, 1, 2])
    }
}
