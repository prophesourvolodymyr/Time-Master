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

    func testSeveralRestExercisesKeepTheirOrderThroughTheManifestAndBack() {
        let other = UUID()
        var slot = SetSlot(exercisePageID: UUID(), name: "Dips", duration: 40, restAfter: 60)
        slot.restExercisePageIDs = [wrist, other]
        var row = RestRow(kind: .big, duration: 45)
        row.exercisePageIDs = [other, wrist]

        let slotBack = slot.coreManifest.toAppSlot()
        let rowBack = row.coreManifest.toAppRestRow()

        XCTAssertEqual(slot.coreManifest.restExerciseChoices, [wrist.uuidString, other.uuidString])
        XCTAssertEqual(slotBack.restExercisePageIDs, [wrist, other])
        XCTAssertEqual(rowBack.exercisePageIDs, [other, wrist])
        XCTAssertEqual(rowBack.exercisePageID, other)
    }

    func testAddingRemovingAndPickingTheDefaultKeepsTheListClean() {
        let a = UUID(), b = UUID(), c = UUID()

        XCTAssertEqual(RestExercise.adding(b, to: [a, b]), [a, b])
        XCTAssertEqual(RestExercise.adding(c, to: [a, b]), [a, b, c])
        XCTAssertEqual(RestExercise.removing(a, from: [a, b, c]), [b, c])
        XCTAssertEqual(RestExercise.making(c, defaultIn: [a, b, c]), [c, a, b])
        XCTAssertEqual(RestExercise.making(UUID(), defaultIn: [a, b]), [a, b])

        var row = RestRow(kind: .normal, duration: 30, exercisePageID: a, alternativePageIDs: [b])
        row.exercisePageIDs = RestExercise.removing(a, from: row.exercisePageIDs)
        XCTAssertEqual(row.exercisePageID, b)
        XCTAssertTrue(row.alternativePageIDs.isEmpty)
        row.exercisePageIDs = []
        XCTAssertNil(row.exercisePageID)
    }

    func testEveryRestExerciseChoiceCountsAsAPageTheWorkoutUses() {
        let other = UUID()
        var set = SetSlot(exercisePageID: UUID(), name: "Dips", duration: 40, restAfter: 60)
        set.restExercisePageIDs = [wrist, other]
        let workout = Workout(name: "Pull", sections: [Section(name: "Dips", slots: [set, SetSlot(exercisePageID: UUID(), name: "Dips", duration: 40, restAfter: 0)])])

        XCTAssertEqual(PageUsageIndex(workouts: [workout], history: [], parentByID: [:]).score(of: other), 1)
        XCTAssertTrue(WorkoutMediaCatalog.pageIDs(in: workout).contains(other))
    }

    func testOlderFilesLoadWithoutChoicesAndNewFilesOnlyWriteThemWhenThereAreSome() throws {
        let plain = SetSlot(exercisePageID: UUID(), name: "Dips", duration: 40, restAfter: 60, restExercisePageID: wrist)
        let plainObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any])
        XCTAssertNil(plainObject["restExerciseAlternativeIDs"])
        XCTAssertEqual(try JSONDecoder().decode(SetSlot.self, from: JSONEncoder().encode(plain)).restExercisePageIDs, [wrist])

        var withChoices = plain
        withChoices.restExercisePageIDs = [wrist, UUID()]
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(withChoices)) as? [String: Any])
        XCTAssertEqual((object["restExerciseAlternativeIDs"] as? [String])?.count, 1)
        XCTAssertEqual(try JSONDecoder().decode(SetSlot.self, from: JSONEncoder().encode(withChoices)), withChoices)
    }
}
