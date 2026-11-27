import XCTest
@testable import TimeMasterCore

final class WorkoutExamplesManifestTests: XCTestCase {
    func testExamplesSurviveSavingAndOlderFilesReadAsNone() throws {
        let ids = [UUID().uuidString, UUID().uuidString]
        let section = WorkoutSectionManifest(exerciseID: "page", name: "Pull-ups", examplePageIDs: ids)
        let decoded = try JSONDecoder().decode(WorkoutSectionManifest.self, from: JSONEncoder().encode(section))
        XCTAssertEqual(decoded.examplePageIDs, ids)

        let plain = try JSONEncoder().encode(WorkoutSectionManifest(exerciseID: "page", name: "Plain"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        XCTAssertNil(object["examplePageIDs"])
        XCTAssertEqual(try JSONDecoder().decode(WorkoutSectionManifest.self, from: plain).examplePageIDs, [])
    }
}
