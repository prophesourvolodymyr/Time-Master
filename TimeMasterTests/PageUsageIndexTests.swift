import XCTest
import TimeMasterCore
@testable import TimeMaster

final class PageUsageIndexTests: XCTestCase {
    private let folder = UUID()
    private let squat = UUID()
    private let lunge = UUID()
    private let stretch = UUID()
    private let unused = UUID()

    /// Squat and lunge sit in the folder; the stretch and the unused page at the top.
    private var parents: [UUID: UUID] { [squat: folder, lunge: folder] }

    private func workout(_ name: String, id: UUID = UUID(), sections: [Section]) -> Workout {
        Workout(id: id, name: name, sections: sections)
    }

    private func finished(_ workout: Workout, times: Int, partial: Int = 0) -> [WorkoutHistoryEntry] {
        (0..<times).map { _ in WorkoutHistoryEntry(workoutId: workout.id, workoutName: workout.name, durationCompleted: 60) }
            + (0..<partial).map { _ in
                WorkoutHistoryEntry(workoutId: workout.id, workoutName: workout.name, durationCompleted: 10, isPartial: true)
            }
    }

    private func page(_ id: UUID, _ title: String) -> ExercisePage {
        ExercisePage(manifest: ExercisePageManifest(id: id.uuidString, title: title))
    }

    func testAPageScoresItsWorkoutsAndTheirFinishedSessions() {
        let legs = workout("Legs", sections: [Section(name: "Squat", pageID: squat)])
        let index = PageUsageIndex(workouts: [legs], history: finished(legs, times: 3, partial: 2), parentByID: parents)
        XCTAssertEqual(index.score(of: squat), 4, "one workout plus three finished sessions; partial ones do not count")
        XCTAssertEqual(index.score(of: unused), 0)
    }

    func testAFolderCountsEachWorkoutUsingAnythingInsideItOnce() {
        let both = workout("Both", sections: [Section(name: "Squat", pageID: squat), Section(name: "Lunge", pageID: lunge)])
        let lungesOnly = workout("Lunges", sections: [Section(name: "Lunge", pageID: lunge)])
        let history = finished(both, times: 2) + finished(lungesOnly, times: 1)
        let index = PageUsageIndex(workouts: [both, lungesOnly], history: history, parentByID: parents)
        XCTAssertEqual(index.score(of: squat), 3)
        XCTAssertEqual(index.score(of: lunge), 5)
        XCTAssertEqual(index.score(of: folder), 5, "two workouts (one using two pages inside) and their three sessions")
    }

    func testSetsDropsRestsAndNestedWorkoutsCountAsUses() {
        let warmUpID = UUID()
        let warmUp = workout("Warm-up", id: warmUpID, sections: [
            Section(name: "Rest", slots: [SetSlot(name: "Hold", restRow: RestRow(contents: [RestContent(kind: .stretch, pageID: stretch)]))])
        ])
        let main = workout("Main", sections: [
            Section(name: "Block", slots: [
                SetSlot(name: "Drop", drops: [DropSet(exercisePageID: squat, name: "Squat")]),
                SetSlot(nestedWorkoutID: warmUpID, name: "Warm-up")
            ])
        ])
        let index = PageUsageIndex(workouts: [warmUp, main], history: finished(main, times: 1), parentByID: parents)
        XCTAssertEqual(index.score(of: squat), 2)
        XCTAssertEqual(index.score(of: stretch), 3, "used by the warm-up itself and, through it, by the main workout")
    }

    func testWorkoutsNestedInEachOtherDoNotLoop() {
        let firstID = UUID()
        let secondID = UUID()
        let first = workout("First", id: firstID, sections: [
            Section(name: "Squat", pageID: squat),
            Section(name: "Next", slots: [SetSlot(nestedWorkoutID: secondID, name: "Second")])
        ])
        let second = workout("Second", id: secondID, sections: [
            Section(name: "Back", slots: [SetSlot(nestedWorkoutID: firstID, name: "First")])
        ])
        let index = PageUsageIndex(workouts: [first, second], history: [], parentByID: parents)
        XCTAssertEqual(index.score(of: squat), 2)
    }

    func testMostUsedComesFirstAndUnusedPagesSinkByName() {
        let legs = workout("Legs", sections: [Section(name: "Squat", pageID: squat)])
        let index = PageUsageIndex(workouts: [legs], history: [], parentByID: [:])
        let pages = [page(unused, "Zebra crawl"), page(stretch, "Arm circles"), page(squat, "Squat")]
        let ranked = pages.sorted { index.ranks($0, before: $1) }
        XCTAssertEqual(ranked.map(\.title), ["Squat", "Arm circles", "Zebra crawl"])
    }
}
