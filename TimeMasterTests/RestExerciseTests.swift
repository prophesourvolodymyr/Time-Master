import XCTest
import TimeMasterCore
@testable import TimeMaster

final class RestExerciseTests: XCTestCase {
    private let wrist = UUID()

    private func page(duration: Int?) -> ExercisePage {
        var manifest = ExercisePageManifest(id: wrist.uuidString, title: "Wrist Circles")
        manifest.duration = duration
        return ExercisePage(manifest: manifest)
    }

    func testASectionFromAToolCarriesItsRestExerciseIntoEverySetButTheLast() {
        let fromTool = WorkoutSectionManifest(
            exerciseID: UUID().uuidString, name: "Dips", duration: 40, sets: 3, restBetweenSets: 60,
            bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 45, exerciseID: wrist.uuidString),
            restExerciseID: wrist.uuidString
        )

        let section = fromTool.toAppSection()
        XCTAssertEqual(section.slots.map(\.restExercisePageID), [wrist, wrist, nil])
        XCTAssertEqual(section.bigRestRow?.exercisePageID, wrist)
        XCTAssertEqual(section.betweenSetsRestExercisePageID, wrist)

        let saved = section.coreManifest
        XCTAssertEqual(saved.slots.map(\.restExerciseID), [wrist.uuidString, wrist.uuidString, nil])
        XCTAssertEqual(saved.bigRestRow?.exerciseID, wrist.uuidString)
        XCTAssertEqual(saved.calculatedDuration, fromTool.calculatedDuration)
    }

    func testARestOfZeroNeverGivesASetARestExercise() {
        let fromTool = WorkoutSectionManifest(exerciseID: UUID().uuidString, name: "Dips", sets: 3, restBetweenSets: 0, restExerciseID: wrist.uuidString)

        XCTAssertTrue(fromTool.toAppSection().slots.allSatisfy { $0.restExercisePageID == nil })
    }

    func testARestOnlyHoldsAnExerciseThatFitsInIt() {
        XCTAssertTrue(RestExercise.fits(page(duration: 30), restSeconds: 30))
        XCTAssertFalse(RestExercise.fits(page(duration: 90), restSeconds: 60))
        XCTAssertTrue(RestExercise.fits(page(duration: nil), restSeconds: 5))
        XCTAssertFalse(RestExercise.fits(page(duration: nil), restSeconds: 0))
    }

    func testABigRestExerciseCountsAsAPageTheWorkoutUses() {
        var section = Section(name: "Dips", pageID: UUID())
        section.bigRestRow = RestRow(kind: .big, duration: 45, exercisePageID: wrist)
        let workout = Workout(name: "Pull", sections: [section])

        XCTAssertEqual(PageUsageIndex(workouts: [workout], history: [], parentByID: [:]).score(of: wrist), 1)
        XCTAssertTrue(WorkoutMediaCatalog.pageIDs(in: workout).contains(wrist))
    }

    func testAnOlderRestRowWithoutAnExerciseStillDecodes() throws {
        let json = Data(#"{"id":"\#(UUID().uuidString)","kind":"big","duration":30,"contents":[]}"#.utf8)

        XCTAssertNil(try JSONDecoder().decode(RestRow.self, from: json).exercisePageID)
    }
}
