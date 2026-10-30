import XCTest
@testable import TimeMasterCore

final class SkillTypeScopeTests: XCTestCase {
    func testContainerSiblingsKeepSeparatePresetsAcrossRenameReloadAndDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemHelper(dataRoot: root)
        let database = DatabaseManager(fs: fs)
        try database.bootstrapIfNeeded()

        let container = ExercisePageManifest(title: "Learning")
        let cards = ExercisePageManifest(title: "Cards", pageType: .skill)
        let guitar = ExercisePageManifest(title: "Guitar", pageType: .skill)
        let child = ExercisePageManifest(title: "Card cut", pageType: .skill)
        try database.createPage(manifest: container)
        try database.createPage(manifest: cards, parentID: container.id)
        try database.createPage(manifest: guitar, parentID: container.id)
        try database.createPage(manifest: child, parentID: cards.id)
        let type = try database.addSkillType(to: child.id, title: "Move", effect: .outline, sortRule: .top)
        try database.setSkillType(type.id, for: cards.id)
        try database.setSkillType(type.id, for: child.id)

        var renamed = try database.getPage(id: cards.id)
        renamed.title = "Card moves"
        try database.updatePage(id: cards.id, manifest: renamed, newParentID: renamed.parentID)
        let reloaded = DatabaseManager(fs: fs)
        XCTAssertEqual(try reloaded.skillTypeOwnerID(of: child.id), cards.id)
        XCTAssertEqual(try reloaded.getPage(id: cards.id).typePresets.flatMap(\.types), [type])
        XCTAssertEqual(try reloaded.skillTypePresets(for: guitar.id), [])
        XCTAssertEqual(try reloaded.getPage(id: container.id).typePresets, [])
        XCTAssertThrowsError(try reloaded.setSkillType(type.id, for: guitar.id))

        try reloaded.deleteSkillType(type.id, in: child.id)
        XCTAssertNil(try reloaded.getPage(id: cards.id).typeID)
        XCTAssertNil(try reloaded.getPage(id: child.id).typeID)
        XCTAssertEqual(try reloaded.getPage(id: guitar.id).title, "Guitar")
    }
}
