#if os(iOS)
import UIKit
import XCTest
@testable import TimeMaster

@available(iOS 17.0, *)
final class WorkoutLiveActivityTests: XCTestCase {
    private func state(
        phase: WorkoutActivityAttributes.ContentState.Phase = .active,
        title: String = "Single Leg Takedown",
        remaining: Int = 30,
        duration: Int = 60,
        paused: Bool = false,
        itemIndex: Int? = nil,
        itemCount: Int? = nil,
        sectionIndex: Int = 0,
        sectionCount: Int = 0,
        nextTitle: String? = nil,
        nextKind: String? = nil
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            phase: phase,
            title: title,
            subtitle: "",
            isPaused: paused,
            remainingSeconds: remaining,
            phaseDuration: duration,
            phaseEndDate: paused ? nil : Date().addingTimeInterval(TimeInterval(remaining)),
            nextTitle: nextTitle,
            elapsedSeconds: 125,
            itemIndex: itemIndex,
            itemCount: itemCount,
            sectionIndex: sectionIndex,
            sectionCount: sectionCount,
            nextKind: nextKind
        )
    }

    func testPositionCollapsesToABarWhenThereAreTooManyDots() {
        XCTAssertNil(WorkoutLivePosition(index: 1, count: 1))
        XCTAssertNil(WorkoutLivePosition(index: nil, count: 5))
        XCTAssertNil(WorkoutLivePosition(index: 2, count: nil))
        let dots = WorkoutLivePosition(index: 3, count: 6)
        XCTAssertEqual(dots?.style, .dots)
        XCTAssertEqual(dots?.current, 2)
        XCTAssertEqual(WorkoutLivePosition(index: 1, count: WorkoutLivePosition.maxDots)?.style, .dots)
        let bar = WorkoutLivePosition(index: 18, count: 36)
        XCTAssertEqual(bar?.style, .bar)
        XCTAssertEqual(bar?.fraction ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(WorkoutLivePosition(index: 99, count: 4)?.current, 3)
        XCTAssertEqual(WorkoutLivePosition(index: 0, count: 4)?.current, 0)
    }

    func testPhaseProgressTracksElapsedShareAndClamps() throws {
        XCTAssertEqual(state(remaining: 15, duration: 60).elapsedFraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(state(remaining: 90, duration: 60).elapsedFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(state(remaining: 0, duration: 0).elapsedFraction, 0)
        let interval = try XCTUnwrap(state(remaining: 20, duration: 60).runningInterval)
        XCTAssertEqual(interval.upperBound.timeIntervalSince(interval.lowerBound), 60, accuracy: 0.001)
        XCTAssertNil(state(paused: true).runningInterval)
    }

    func testWorkoutFractionCombinesSectionAndQueuePosition() {
        XCTAssertEqual(state(itemIndex: 1, itemCount: 4, sectionIndex: 0, sectionCount: 2).workoutFraction ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(state(itemIndex: 3, itemCount: 4, sectionIndex: 1, sectionCount: 2).workoutFraction ?? -1, 0.5 + 0.25, accuracy: 0.0001)
        XCTAssertEqual(state(sectionIndex: 2, sectionCount: 4).workoutFraction ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(state(sectionIndex: 0, sectionCount: 1).workoutFraction)
        XCTAssertNil(state().workoutFraction)
        XCTAssertEqual(state(phase: .completed).workoutFraction, 1)
        XCTAssertLessThanOrEqual(state(itemIndex: 9, itemCount: 4, sectionIndex: 7, sectionCount: 2).workoutFraction ?? 2, 1)
    }

    func testNextKindFallsBackToExerciseWhenOnlyATitleIsKnown() {
        XCTAssertEqual(state(nextTitle: "Sprawl").nextKindValue, .exercise)
        XCTAssertEqual(state(nextTitle: "Cooldown", nextKind: "section").nextKindValue, .section)
        XCTAssertEqual(state(nextKind: "finish").nextKindValue, .finish)
        XCTAssertNil(state(nextKind: "bogus").nextKindValue)
        XCTAssertNil(state().nextKindValue)
        XCTAssertFalse(state(phase: .completed, nextKind: "finish").hasNext)
    }

    func testSpokenSummaryReplacesTheDroppedText() {
        let rest = state(
            phase: .setRest,
            title: "Rest",
            itemIndex: 2,
            itemCount: 5,
            sectionIndex: 1,
            sectionCount: 3,
            nextTitle: "Single Leg Takedown",
            nextKind: "exercise"
        )
        XCTAssertEqual(
            rest.spokenSummary(workoutName: "Wrestling"),
            "Rest, up next Single Leg Takedown, set 2 of 5, section 2 of 3"
        )
        var bundle = rest
        bundle.isBundle = true
        XCTAssertTrue(bundle.spokenSummary(workoutName: "Wrestling").contains("exercise 2 of 5"))
        var paused = state(phase: .active, title: "Sprawl", paused: true)
        XCTAssertEqual(paused.spokenSummary(workoutName: "W"), "Paused, Sprawl")
        paused.phase = .completed
        XCTAssertEqual(paused.spokenSummary(workoutName: "W"), "Workout complete, total time 2 minutes, 5 seconds")
    }

    func testContentStateStaysFarUnderTheActivityKitLimit() throws {
        let long = String(repeating: "W", count: 60)
        let content = WorkoutActivityAttributes.ContentState(
            phase: .setRest,
            title: long,
            subtitle: long,
            isPaused: false,
            remainingSeconds: 3599,
            phaseDuration: 3600,
            phaseEndDate: Date(),
            nextTitle: long,
            elapsedSeconds: 99_999,
            itemIndex: 99,
            itemCount: 99,
            sectionIndex: 20,
            sectionCount: 20,
            isBundle: true,
            nextKind: "exercise",
            artworkName: String(repeating: "a", count: 80),
            nextArtworkName: String(repeating: "b", count: 80)
        )
        let attributes = WorkoutActivityAttributes(
            workoutID: UUID().uuidString,
            workoutName: long,
            colorHex: "FF6A00",
            startedAt: Date()
        )
        let size = try JSONEncoder().encode(content).count + JSONEncoder().encode(attributes).count
        XCTAssertLessThan(size, 2_000)
    }

    func testContentStateFromAnOlderBuildStillDecodes() throws {
        let json = """
        {"phase":"active","title":"Squat","subtitle":"Section 1 of 2","isPaused":false,\
        "remainingSeconds":10,"phaseDuration":30,"nextTitle":"Lunge","elapsedSeconds":4}
        """
        let decoded = try JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.title, "Squat")
        XCTAssertNil(decoded.itemIndex)
        XCTAssertEqual(decoded.sectionCount, 0)
        XCTAssertFalse(decoded.isBundle)
        XCTAssertEqual(decoded.nextKindValue, .exercise)
    }

    func testSnapshotNormalizationKeepsQueueFieldsConsistent() {
        let snapshot = WorkoutLiveActivitySnapshot(
            workoutID: UUID(),
            workoutName: "Drills",
            colorHex: "FF6A00",
            phase: .active,
            title: "",
            subtitle: "",
            isPaused: false,
            remainingSeconds: -4,
            phaseDuration: 20,
            elapsedSeconds: 0,
            nextTitle: "",
            startedAt: Date(),
            itemIndex: 9,
            itemCount: 4,
            sectionIndex: 7,
            sectionCount: 3,
            nextKind: "nonsense",
            artworkName: String(repeating: "x", count: 200),
            nextArtworkName: "next.jpg"
        ).normalized
        XCTAssertEqual(snapshot.title, "Drills")
        XCTAssertEqual(snapshot.remainingSeconds, 0)
        XCTAssertEqual(snapshot.itemIndex, 4)
        XCTAssertEqual(snapshot.itemCount, 4)
        XCTAssertEqual(snapshot.sectionIndex, 2)
        XCTAssertNil(snapshot.nextTitle)
        XCTAssertNil(snapshot.nextKind)
        XCTAssertNil(snapshot.artworkName)
        XCTAssertEqual(snapshot.nextArtworkName, "next.jpg")
        let empty = WorkoutLiveActivitySnapshot(
            workoutID: UUID(), workoutName: "A", colorHex: "FF6A00", phase: .active, title: "A", subtitle: "",
            isPaused: false, remainingSeconds: 1, phaseDuration: 1, elapsedSeconds: 0, nextTitle: nil,
            startedAt: Date(), itemIndex: 3, itemCount: 0
        ).normalized
        XCTAssertNil(empty.itemIndex)
        XCTAssertNil(empty.itemCount)
    }

    func testArtworkFilesAreStoredReadPrunedAndNeverEscapeTheFolder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tm-artwork-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 480))
        let jpeg = renderer.jpegData(withCompressionQuality: 0.7) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 480, height: 480))
        }

        let name = try XCTUnwrap(WorkoutLiveActivityArtwork.store(jpeg: jpeg, key: "exercise/1:a", in: directory))
        XCTAssertEqual(name, "exercise_1_a.jpg")
        XCTAssertEqual(WorkoutLiveActivityArtwork.store(jpeg: jpeg, key: "exercise/1:a", in: directory), name)
        XCTAssertNil(WorkoutLiveActivityArtwork.store(jpeg: Data(), key: "x", in: directory))
        XCTAssertNil(WorkoutLiveActivityArtwork.store(jpeg: jpeg, key: "///", in: directory))

        let image = try XCTUnwrap(WorkoutLiveActivityArtwork.image(named: name, in: directory))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, CGFloat(WorkoutLiveActivityArtwork.maxPixelSize))
        XCTAssertNil(WorkoutLiveActivityArtwork.image(named: "../\(name)", in: directory))
        XCTAssertNil(WorkoutLiveActivityArtwork.image(named: "missing.jpg", in: directory))

        _ = WorkoutLiveActivityArtwork.store(jpeg: jpeg, key: "other", in: directory)
        WorkoutLiveActivityArtwork.prune(keeping: [name], in: directory)
        XCTAssertNotNil(WorkoutLiveActivityArtwork.image(named: name, in: directory))
        XCTAssertNil(WorkoutLiveActivityArtwork.image(named: "other.jpg", in: directory))
    }
}
#endif
