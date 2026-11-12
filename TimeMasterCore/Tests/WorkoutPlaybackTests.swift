import XCTest
@testable import TimeMasterCore

final class WorkoutPlaybackTests: XCTestCase {
    private func slot(
        _ id: String, duration: Int = 20, rest: Int = 5, prepare: Int? = 0,
        drops: [WorkoutDropSetManifest] = [], restRow: WorkoutRestRowManifest? = nil
    ) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(
            id: id, exerciseID: "page-\(id)", name: id, duration: duration, restAfter: rest,
            prepareTime: prepare, drops: drops, restRow: restRow
        )
    }

    private func set(_ id: String, rest: Int, children: [WorkoutSetSlotManifest]) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(id: id, exerciseID: "", name: id, restAfter: rest, children: children)
    }

    private func bundle(prepare: Int = 4, sets: [WorkoutSetSlotManifest]) -> WorkoutSectionManifest {
        WorkoutSectionManifest(
            exerciseID: "page-A", name: "Wrestling drills", prepareTime: prepare, mode: .bundle, slots: sets
        )
    }

    func testBundleOfTwoSetsPlaysEveryExerciseWithItsOwnRestAndTheRestBetweenSets() {
        let section = bundle(sets: [
            set("s1", rest: 40, children: [slot("A", duration: 20, rest: 5), slot("B", duration: 30, rest: 5), slot("C", duration: 10, rest: 3)]),
            set("s2", rest: 40, children: [slot("A2", duration: 20, rest: 5), slot("B2", duration: 30, rest: 5), slot("C2", duration: 10, rest: 3)]),
        ])

        let plan = section.playbackSlots()

        XCTAssertEqual(plan.map(\.id), ["A", "B", "C", "A2", "B2", "C2"])
        XCTAssertEqual(plan.map(\.playbackRest), [5, 5, 40, 5, 5, 0])
        XCTAssertEqual(plan.map { $0.prepareTime ?? -1 }, [4, 0, 0, 4, 0, 0])
        XCTAssertEqual(section.calculatedDuration, 4 + 4 + 2 * 60 + (5 + 5 + 40 + 5 + 5))
    }

    func testOneSecondExercisesWithoutRestPlayBackToBack() {
        let section = bundle(prepare: 3, sets: [
            set("s1", rest: 0, children: (1...5).map { slot("E\($0)", duration: 1, rest: 0) }),
        ])

        let plan = section.playbackSlots()

        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(plan.map(\.duration), [1, 1, 1, 1, 1])
        XCTAssertEqual(plan.map(\.playbackRest), [0, 0, 0, 0, 0])
        XCTAssertEqual(section.calculatedDuration, 3 + 5)
    }

    func testRandomOrderKeepsDropSetsRightAfterTheirExercise() {
        let drop = WorkoutDropSetManifest(id: "drop", exerciseID: "page-drop", name: "Drop", duration: 7, restAfter: 2)
        let section = bundle(sets: [
            set("s1", rest: 0, children: [slot("A", drops: [drop]), slot("B"), slot("C")]),
        ])

        let plan = section.playbackSlots(order: ["C", "A", "B"])

        XCTAssertEqual(plan.map(\.id), ["C", "A", "drop", "B"])
        XCTAssertEqual(plan.first?.prepareTime, 4)
    }

    func testOrderIgnoresUnknownIdsAndKeepsUnlistedExercisesInPlace() {
        let section = bundle(sets: [
            set("s1", rest: 0, children: [slot("A"), slot("B"), slot("C")]),
        ])

        XCTAssertEqual(section.playbackSlots(order: ["ghost", "C"]).map(\.id), ["C", "A", "B"])
        XCTAssertEqual(section.playbackSlots(order: []).map(\.id), ["A", "B", "C"])
    }

    func testRestBetweenSetsKeepsItsRestRowContentAndRestExerciseOnTheLastExercise() {
        let note = WorkoutRestContentManifest(id: "note", kind: .note, text: "Breathe")
        let row = WorkoutRestRowManifest(id: "row", kind: .normal, duration: 40, contents: [note])
        var first = set("s1", rest: 40, children: [slot("A"), slot("B")])
        first.restRow = row
        first.restExerciseID = "stretch-page"
        let section = bundle(sets: [first, set("s2", rest: 0, children: [slot("A2")])])

        let plan = section.playbackSlots(order: ["B", "A"])

        XCTAssertEqual(plan.map(\.id), ["B", "A", "A2"])
        XCTAssertEqual(plan[1].restRow?.contents, [note])
        XCTAssertEqual(plan[1].restExerciseID, "stretch-page")
        XCTAssertEqual(plan[1].playbackRest, 40)
        XCTAssertEqual(plan[0].playbackRest, 5)
    }

    func testTimedSectionPlaysDropSetsBetweenTheSetAndItsRest() {
        let drop = WorkoutDropSetManifest(id: "drop", exerciseID: "page-drop", name: "Drop", duration: 5, restAfter: 3)
        let section = WorkoutSectionManifest(
            exerciseID: "page-A", name: "Timed", prepareTime: 4, mode: .timed,
            slots: [slot("set1", duration: 10, rest: 8, prepare: nil, drops: [drop]), slot("set2", duration: 12, rest: 0, prepare: 0)]
        )

        let plan = section.playbackSlots()

        XCTAssertEqual(plan.map(\.id), ["set1", "drop", "set2"])
        XCTAssertEqual(plan.map(\.duration), [10, 5, 12])
        XCTAssertEqual(plan.map(\.playbackRest), [0, 11, 0])
        XCTAssertEqual(section.calculatedDuration, 4 + 10 + 5 + 11 + 12)
    }

    func testGeneratedSetsOfASectionWithoutSlotsAreTimedAndRested() {
        let section = WorkoutSectionManifest(
            exerciseID: "page-A", name: "Pushups", duration: 30, sets: 3, restBetweenSets: 10, prepareTime: 4
        )

        XCTAssertEqual(section.playbackSlots().count, 3)
        XCTAssertEqual(section.calculatedDuration, 3 * (4 + 30) + 2 * 10)
    }

    func testADeletedSetRestIsNotReplacedByTheSectionDefault() {
        let section = WorkoutSectionManifest(
            exerciseID: "page-A", name: "No rest", duration: 30, sets: 2, restBetweenSets: 10, prepareTime: 0,
            slots: [slot("one", duration: 30, rest: 0, prepare: 0), slot("two", duration: 30, rest: 0, prepare: 0)]
        )

        XCTAssertEqual(section.playbackSlots().map(\.playbackRest), [0, 0])
        XCTAssertEqual(section.calculatedDuration, 60)
    }

    func testTotalDurationDoesNotCountARestAfterTheLastSection() {
        let timed = { (id: String) in
            WorkoutSectionManifest(
                exerciseID: "page-\(id)", name: id, duration: 20, sets: 1, prepareTime: 0,
                slots: [self.slot(id, duration: 20, rest: 0, prepare: 0)], bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 30)
            )
        }
        let manifest = WorkoutManifest(id: "w", name: "Two sections", sections: [timed("A"), timed("B")], restBetweenSections: 30)

        XCTAssertEqual(manifest.totalDuration, 20 + 30 + 20)
    }

    func testBundleSettingsRoundTripThroughTheWorkoutFile() throws {
        let section = WorkoutSectionManifest(
            exerciseID: "page-A", name: "Drills", prepareTime: 5, mode: .bundle,
            slots: [set("s1", rest: 25, children: [slot("A"), slot("B")])],
            bundleOrder: .random, bundleVoiceEnabled: false
        )
        let workout = WorkoutManifest(id: "w", name: "Bundle", sections: [section])

        let decoded = try JSONDecoder().decode(WorkoutManifest.self, from: JSONEncoder().encode(workout))

        XCTAssertEqual(decoded.sections[0].mode, .bundle)
        XCTAssertEqual(decoded.sections[0].bundleOrder, .random)
        XCTAssertFalse(decoded.sections[0].bundleVoiceEnabled)
        XCTAssertEqual(decoded.sections[0].slots[0].children.map(\.id), ["A", "B"])
        XCTAssertEqual(decoded.totalDuration, workout.totalDuration)
    }

    func testGeneratedSetsKeepStableValidIdentifiers() {
        let section = WorkoutSectionManifest(id: UUID().uuidString, exerciseID: "page-A", name: "Pushups", duration: 30, sets: 3)

        let first = section.playbackSlots().map(\.id)

        XCTAssertEqual(first, section.playbackSlots().map(\.id))
        XCTAssertEqual(Set(first).count, 3)
        XCTAssertTrue(first.allSatisfy { UUID(uuidString: $0) != nil })
    }
}
