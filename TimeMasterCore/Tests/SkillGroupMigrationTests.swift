import XCTest
@testable import TimeMasterCore

final class SkillGroupMigrationTests: XCTestCase {
    func testFirstPageMigrationKeepsSkillContentReadableAndMediaOutOfTheTree() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemHelper(dataRoot: root)
        let database = DatabaseManager(fs: fs)
        try database.bootstrapIfNeeded()
        let cards = ExercisePageManifest(title: "Cards", pageType: .skill)
        let first = ExercisePageManifest(title: "Grip", pageType: .skill)
        let second = ExercisePageManifest(title: "Cut", pageType: .skill)
        try database.createPage(manifest: cards)
        let group = try database.addSkillGroup(to: cards.id, title: "Foundations")
        let groupID = SkillGroupID.make(containerID: cards.id, sectionID: group.id)
        try database.createPage(manifest: first, parentID: groupID)
        try database.createPage(manifest: second, parentID: cards.id)
        let source = root.appendingPathComponent("reference.txt")
        let bytes = Data("Keep the grip light.".utf8)
        try bytes.write(to: source)
        _ = try database.uploadMediaToPage(pageID: cards.id, sourceURL: source)
        let filename = try database.uploadMediaToPage(pageID: groupID, sourceURL: source)
        var material = try database.getPage(id: groupID)
        material.markdownBody = "Group notes"
        try database.updatePage(id: groupID, manifest: material)
        let physicalOrder = try XCTUnwrap(database.walkPageTree(in: fs.exercisesDatabaseDirectory).first { $0.0.id == cards.id }?.0.childIDs)
        var page = try database.getPage(id: cards.id)
        page.childIDs = Array(physicalOrder.reversed())
        try database.updatePage(id: cards.id, manifest: page)

        _ = try MigrationManager(db: database).migrateToV2Pages()
        let reloaded = DatabaseManager(fs: fs)
        XCTAssertEqual(try reloaded.getPage(id: cards.id).title, "Cards")
        XCTAssertEqual(try reloaded.getPage(id: groupID).markdownBody, "Group notes")
        XCTAssertEqual(Set(try reloaded.walkPageTree(in: fs.exercisesDatabaseDirectory).map { $0.0.id }), Set([cards.id, first.id, second.id]))
        let cardFolder = fs.exercisesDatabaseDirectory.appendingPathComponent(cards.id)
        XCTAssertFalse(fs.fileExists(at: cardFolder.appendingPathComponent("media/manifest.json")))
        XCTAssertFalse(fs.fileExists(at: cardFolder.appendingPathComponent("Sections/manifest.json")))
        let groupFile = SkillGroupID.mediaFolder(containerFolder: cardFolder, sectionID: group.id).appendingPathComponent(filename)
        XCTAssertEqual(try Data(contentsOf: groupFile), bytes)
    }
}
