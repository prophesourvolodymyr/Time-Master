import XCTest
@testable import TimeMasterCore

final class PageIconTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var folderID = ""
    var exerciseID = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("page-icons-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        folderID = try toolbox.call("create_container_page", arguments: ["title": "Boxing", "workoutType": "Strength"]).value["id"] as! String
        exerciseID = try toolbox.call("create_exercise_page", arguments: ["title": "Jab", "parent": folderID, "duration": 30]).value["id"] as! String
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func picture() throws -> URL {
        let url = root.appendingPathComponent("\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        return url
    }

    private func save(_ id: String, _ change: (inout ExercisePageManifest) -> Void) throws -> ExercisePageManifest {
        var manifest = try database.getPage(id: id)
        change(&manifest)
        try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        return try database.getPage(id: id)
    }

    func testExerciseAndFolderPagesKeepASymbolOrAnEmoji() throws {
        let exercise = try save(exerciseID) { $0.iconName = "figure.boxing"; $0.iconType = .system }
        XCTAssertEqual(exercise.iconName, "figure.boxing")
        XCTAssertEqual(exercise.iconType, .system)

        let folder = try save(folderID) { $0.iconName = "🥊"; $0.iconType = .emoji }
        XCTAssertEqual(folder.iconName, "🥊")
        XCTAssertEqual(folder.iconType, .emoji)
    }

    func testAPictureIconMustBeOneOfThePagesOwnMedia() throws {
        let filename = try database.uploadMediaToPage(pageID: exerciseID, sourceURL: try picture())

        let own = try save(exerciseID) { $0.iconImage = filename }
        XCTAssertEqual(own.iconImage, filename)

        let foreign = try save(exerciseID) { $0.iconImage = "somebody-elses.png" }
        XCTAssertNil(foreign.iconImage)

        let web = try save(folderID) { $0.iconImage = "https://example.com/jab.png" }
        XCTAssertEqual(web.iconImage, "https://example.com/jab.png")
    }

    func testAFolderKeepsAPictureOfItsOwnMedia() throws {
        let filename = try database.uploadMediaToPage(pageID: folderID, sourceURL: try picture())

        let folder = try save(folderID) { $0.iconImage = filename }

        XCTAssertEqual(folder.iconImage, filename)
    }

    func testABlankIconIsNoIconAndTakesItsTypeWithIt() throws {
        let exercise = try save(exerciseID) { $0.iconName = "  "; $0.iconType = .system }

        XCTAssertNil(exercise.iconName)
        XCTAssertNil(exercise.iconType)
    }

    func testANoteStillKeepsOnlyASymbolOrAnEmoji() throws {
        let noteID = try toolbox.call("create_note_page", arguments: ["title": "Ideas", "parent": folderID]).value["id"] as! String

        let note = try save(noteID) { $0.iconName = "lightbulb"; $0.iconType = .system; $0.iconImage = "https://example.com/x.png" }

        XCTAssertEqual(note.iconName, "lightbulb")
        XCTAssertNil(note.iconImage)
    }
}
