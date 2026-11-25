import XCTest
@testable import TimeMasterCore

final class WorkoutComboManifestTests: XCTestCase {
    func testAComboSectionKeepsItsFlagAndIconInTheFile() throws {
        let section = WorkoutSectionManifest(
            exerciseID: "", name: "Boxing combos", mode: .bundle, isCombo: true, iconName: "🥊", iconType: "emoji"
        )
        let decoded = try JSONDecoder().decode(WorkoutSectionManifest.self, from: JSONEncoder().encode(section))
        XCTAssertTrue(decoded.isCombo)
        XCTAssertEqual(decoded.iconName, "🥊")
        XCTAssertEqual(decoded.iconType, "emoji")
    }

    func testAPlainSectionWritesNoComboFieldsAndAnOlderFileReadsAsNotACombo() throws {
        let plain = WorkoutSectionManifest(exerciseID: "", name: "Bundle", mode: .bundle)
        let data = try JSONEncoder().encode(plain)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["isCombo"])
        XCTAssertNil(object["iconName"])
        XCTAssertNil(object["iconType"])

        let decoded = try JSONDecoder().decode(WorkoutSectionManifest.self, from: data)
        XCTAssertFalse(decoded.isCombo)
        XCTAssertNil(decoded.iconName)
    }
}
