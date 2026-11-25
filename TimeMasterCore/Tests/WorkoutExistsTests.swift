import XCTest
@testable import TimeMasterCore

final class WorkoutExistsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("workout-exists-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testAWorkoutExistsOnceItsManifestIsOnDiskAndNotBefore() throws {
        let id = UUID().uuidString
        XCTAssertFalse(database.workoutExists(id: id))

        try database.createWorkout(id: id, manifest: WorkoutManifest(id: id, name: "Legs", sections: []))
        XCTAssertTrue(database.workoutExists(id: id))

        try database.deleteWorkout(id: id)
        XCTAssertFalse(database.workoutExists(id: id))
    }

    func testTheCheckNeverDecodesTheFileSoAnUnreadableManifestStillCounts() throws {
        let id = UUID().uuidString
        try database.createWorkout(id: id, manifest: WorkoutManifest(id: id, name: "Legs", sections: []))
        let manifestURL = root.appendingPathComponent("Workouts/\(id)/manifest.json")
        try Data("not json".utf8).write(to: manifestURL)

        XCTAssertTrue(database.workoutExists(id: id))
        XCTAssertThrowsError(try database.getWorkout(id: id))
    }
}
