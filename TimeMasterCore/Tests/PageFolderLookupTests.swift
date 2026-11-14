import XCTest
@testable import TimeMasterCore

final class PageFolderLookupTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("lookup-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func folder(_ title: String, parent: String? = nil) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageKind: .container, workoutType: parent == nil ? .strength : nil)
        try database.createPage(manifest: manifest, parentID: parent)
        return try database.getPage(id: manifest.id)
    }

    private func exercise(_ title: String, parent: String) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageKind: .leaf, duration: 30)
        try database.createPage(manifest: manifest, parentID: parent)
        return try database.getPage(id: manifest.id)
    }

    func testLookupsFollowPagesThroughMovesExternalMovesAndDeletes() throws {
        let a = try folder("A")
        let b = try folder("B")
        let leaf = try exercise("Leaf", parent: a.id)
        XCTAssertEqual(try database.getPage(id: leaf.id).parentID, a.id)

        try database.movePage(id: leaf.id, newParentID: b.id, newOrder: 0)
        XCTAssertEqual(try database.getPage(id: leaf.id).parentID, b.id)
        XCTAssertEqual(try database.getPage(id: a.id).childIDs, [])

        try database.movePage(id: b.id, newParentID: a.id, newOrder: 0)
        let nested = try database.resolvePageFolder(id: leaf.id)
        XCTAssertTrue(nested.path.contains("/\(a.id)/\(b.id)/\(leaf.id)"))
        XCTAssertEqual(try database.getPage(id: leaf.id).title, "Leaf")

        let relocated = database.fs.exercisesDatabaseDirectory.appendingPathComponent(leaf.id, isDirectory: true)
        try FileManager.default.moveItem(at: nested, to: relocated)
        XCTAssertEqual(try database.resolvePageFolder(id: leaf.id).path, relocated.path)

        try database.deletePage(id: leaf.id)
        XCTAssertThrowsError(try database.getPage(id: leaf.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: relocated.path))
    }

    func testAddingSiblingsKeepsTheirOrderAndLeavesEarlierOnesUntouched() throws {
        let parent = try folder("Big")
        var first: ExercisePageManifest?
        for index in 0..<30 {
            let page = try exercise("Exercise \(index)", parent: parent.id)
            if index == 0 { first = page }
        }
        let before = try XCTUnwrap(first)
        let after = try database.getPage(id: before.id)
        XCTAssertEqual(after.order, 0)
        XCTAssertEqual(after.updatedAt, before.updatedAt, "creating more siblings must not rewrite earlier pages")

        let ids = try database.getPage(id: parent.id).childIDs
        XCTAssertEqual(ids.count, 30)
        for (index, id) in ids.enumerated() {
            XCTAssertEqual(try database.getPage(id: id).order, index)
            XCTAssertEqual(try database.getPage(id: id).parentID, parent.id)
        }

        try database.reorderChildren(parentID: parent.id, childIDs: Array(ids.reversed()))
        XCTAssertEqual(try database.getPage(id: parent.id).childIDs, Array(ids.reversed()))
        try database.movePage(id: ids[0], newParentID: nil, newOrder: 0)
        XCTAssertNil(try database.getPage(id: ids[0]).parentID)
        XCTAssertEqual(try database.getPage(id: parent.id).childIDs.count, 29)
    }

    func testTheCacheNeverCrossesLibraryRoots() throws {
        let a = try folder("Mine")
        let leaf = try exercise("Leaf", parent: a.id)
        _ = try database.resolvePageFolder(id: leaf.id)

        let other = FileManager.default.temporaryDirectory.appendingPathComponent("lookup-other-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: other) }
        let second = DatabaseManager(fs: FileSystemHelper(dataRoot: other))
        try second.bootstrapIfNeeded()
        XCTAssertThrowsError(try second.getPage(id: leaf.id))
    }
}
