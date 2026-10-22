import XCTest
@testable import TimeMaster

final class ExerciseLibraryAccessTests: XCTestCase {
    func testDelayedOldAccountSaveCannotOverwriteTheNewLibrary() async throws {
        let access = ExerciseLibraryAccess()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let manifest = temporary.appendingPathComponent("manifest.json")
        let oldAccount = access.capture()
        await access.beginAccountChange()
        try Data("New account library".utf8).write(to: manifest)
        access.endAccountChange()
        XCTAssertThrowsError(try access.perform(token: oldAccount) {
            try Data("Delayed old account edit".utf8).write(to: manifest)
        })
        XCTAssertEqual(try Data(contentsOf: manifest), Data("New account library".utf8))
        try access.perform(token: access.capture()) {
            try Data("Current account edit".utf8).write(to: manifest)
        }
        XCTAssertEqual(try Data(contentsOf: manifest), Data("Current account edit".utf8))
    }

    func testSaveStartedDuringHandoffStaysInvalidAfterHandoffCompletes() async throws {
        let access = ExerciseLibraryAccess()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        await access.beginAccountChange()
        let unavailableLibrary = access.capture()
        access.endAccountChange()
        let destination = temporary.appendingPathComponent("unexpected-media.jpg")
        XCTAssertThrowsError(try access.perform(token: unavailableLibrary) {
            try Data("Stale media import".utf8).write(to: destination)
        })
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}
