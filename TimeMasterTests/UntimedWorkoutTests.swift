import XCTest
import TimeMasterCore
@testable import TimeMaster

final class UntimedWorkoutTests: XCTestCase {
    func testTheTimerChoiceSurvivesTheTripThroughTheFileManifest() throws {
        let section = Section(name: "Push-up", duration: 40, isTimerEnabled: false, sets: 3, repCount: 12)

        let manifest = try JSONDecoder().decode(WorkoutSectionManifest.self, from: JSONEncoder().encode(section.coreManifest))
        XCTAssertFalse(manifest.isTimerEnabled)
        let restored = manifest.toAppSection()
        XCTAssertFalse(restored.isTimerEnabled)
        XCTAssertEqual(restored.duration, 40)
        XCTAssertEqual(restored.slots.map(\.duration), [40, 40, 40])
        XCTAssertEqual(restored.repCount, 12)

        let copy = try JSONDecoder().decode(Section.self, from: JSONEncoder().encode(section))
        XCTAssertFalse(copy.isTimerEnabled)
    }

    func testAnOlderSectionWithoutTheKeyKeepsItsTimer() throws {
        let json = Data(#"{"name":"Squat","duration":30,"sets":2}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(WorkoutSectionManifest.self, from: json).isTimerEnabled)
        XCTAssertTrue(try JSONDecoder().decode(Section.self, from: json).isTimerEnabled)
    }

    func testUntimedSetsStillCountTheirEstimateInTheTotal() {
        let timed = Workout(name: "Push", sections: [Section(name: "Push-up", duration: 40, sets: 3, repCount: 12)])
        var untimed = timed
        untimed.sections[0].isTimerEnabled = false
        XCTAssertGreaterThan(timed.totalDuration, 0)
        XCTAssertEqual(untimed.totalDuration, timed.totalDuration)
    }

    func testExercisesOfAnUntimedSectionInANestedWorkoutAreFound() {
        let drop = DropSet(name: "Knee push-up", duration: 20)
        let untimedSlot = SetSlot(name: "Push-up", duration: 30, repCount: 10, drops: [drop])
        let timedSlot = SetSlot(name: "Plank", duration: 45)
        let nested = Workout(name: "Core", sections: [
            Section(name: "Push-up", duration: 30, isTimerEnabled: false, slots: [untimedSlot]),
            Section(name: "Plank", duration: 45, slots: [timedSlot]),
        ])
        let reference = SetSlot(nestedWorkoutID: nested.id, name: nested.name, duration: 120)
        let parent = Workout(name: "Full", sections: [Section(name: "Core", duration: 120, slots: [reference])])

        let ids = parent.nestedUntimedSlotIDs { $0 == nested.id ? nested : nil }

        XCTAssertEqual(ids, [untimedSlot.id, drop.id])
    }

    func testAWorkoutNestingItselfDoesNotLoop() {
        var loop = Workout(name: "Loop")
        let reference = SetSlot(nestedWorkoutID: loop.id, name: "Loop", duration: 30)
        loop.sections = [Section(name: "Loop", duration: 30, isTimerEnabled: false, slots: [reference])]
        let resolved = loop
        XCTAssertEqual(loop.nestedUntimedSlotIDs { $0 == resolved.id ? resolved : nil }, [])
    }

    func testAResumeCheckpointFromAnOlderBuildStillDecodes() throws {
        let older = """
        {"workoutId":"\(UUID().uuidString)","workoutName":"Legs","currentSectionIndex":0,"currentSetIndex":1,\
        "timeRemaining":12,"elapsedSeconds":90,"phase":"active","isPaused":false,"savedAt":0}
        """
        let state = try JSONDecoder().decode(ResumeState.self, from: Data(older.utf8))
        XCTAssertNil(state.untimedSetElapsed)

        var untimed = state
        untimed.untimedSetElapsed = 14
        let restored = try JSONDecoder().decode(ResumeState.self, from: JSONEncoder().encode(untimed))
        XCTAssertEqual(restored.untimedSetElapsed, 14)
    }

    func testAnUntimedLiveStateHasNoPhaseProgress() {
        let state = WorkoutLiveState(
            workoutID: UUID(), workoutName: "Legs", colorHex: "FF6A00", phase: .active, title: "Squat", subtitle: "",
            isPaused: false, remainingSeconds: 0, phaseDuration: 40, sectionIndex: 0, sectionCount: 1,
            elapsedSeconds: 10, totalSeconds: 600, nextTitle: nil, startedAt: Date(), untimedSeconds: 12
        )
        XCTAssertTrue(state.isUntimed)
        XCTAssertEqual(state.phaseProgress, 0)
        let progress = WorkoutLiveProgress(
            sectionID: nil, slotID: nil, phase: .active, remaining: 0, phaseDuration: 40,
            elapsed: 10, isPaused: false, untimedElapsed: 12
        )
        XCTAssertEqual(progress.fraction, 0)
    }
}
