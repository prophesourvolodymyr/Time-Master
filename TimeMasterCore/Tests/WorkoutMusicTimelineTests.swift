import XCTest
@testable import TimeMasterCore

final class WorkoutMusicTimelineTests: XCTestCase {
    private func clip(_ title: String, lane: WorkoutMusicLane = .background,
                      start: Double = 0, duration: Double) -> WorkoutMusicClip {
        WorkoutMusicClip(title: title, lane: lane, start: start, duration: duration,
                         tracks: [WorkoutMusicTrack(title: title, filename: "\(title).wav", duration: duration)])
    }

    func testPrimaryPausesBackgroundAndResumesItsInterruptedPosition() throws {
        let background = clip("Background", duration: 90)
        let primary = clip("Primary", lane: .primary, start: 10, duration: 10)
        var scheduler = WorkoutMusicScheduler(timeline: .init(clips: [background, primary]))
        scheduler.advance(to: 10)
        XCTAssertEqual(scheduler.selection?.clipID, primary.id)
        XCTAssertEqual(scheduler.cursor.positions[background.id], 10)
        scheduler.advance(to: 20)
        let resumed = try XCTUnwrap(scheduler.selection)
        XCTAssertEqual(resumed.clipID, background.id)
        XCTAssertEqual(resumed.offset, 10)
        scheduler.advance(to: 24)
        XCTAssertEqual(scheduler.selection?.offset, 14)
    }

    func testCatchUpAcrossMultipleCuesMatchesIncrementalPlayback() {
        let clips = [clip("Bed", duration: 80),
                     clip("First", lane: .primary, start: 10, duration: 9),
                     clip("Second", lane: .primary, start: 35, duration: 12)]
        let timeline = WorkoutMusicTimeline(clips: clips)
        var catchUp = WorkoutMusicScheduler(timeline: timeline)
        var incremental = WorkoutMusicScheduler(timeline: timeline)
        catchUp.advance(to: 60)
        for second in 1...60 { incremental.advance(to: Double(second)) }
        XCTAssertEqual(catchUp.cursor, incremental.cursor)
        XCTAssertEqual(catchUp.selection?.offset, 39)
    }

    func testLaterStartingClipWinsWithinSameLaneRegardlessOfArrayOrder() {
        let earlier = clip("Earlier", start: 0, duration: 40)
        let later = clip("Later", start: 10, duration: 5)
        var scheduler = WorkoutMusicScheduler(timeline: .init(clips: [later, earlier]))
        scheduler.advance(to: 12)
        XCTAssertEqual(scheduler.selection?.clipID, later.id)
        scheduler.advance(to: 15)
        XCTAssertEqual(scheduler.selection?.clipID, earlier.id)
        XCTAssertEqual(scheduler.selection?.offset, 10)
    }

    func testShortReplacementKeepsReservedTimingButReleasesBackgroundWhenAudioEnds() {
        let bed = clip("Bed", duration: 40)
        var primary = clip("Original", lane: .primary, duration: 20)
        let originalID = primary.id
        primary.replaceMusic(with: clip("Replacement", start: 80, duration: 5))
        XCTAssertEqual(primary.id, originalID)
        XCTAssertEqual(primary.start, 0)
        XCTAssertEqual(primary.duration, 20)
        XCTAssertEqual(primary.lane, .primary)
        var scheduler = WorkoutMusicScheduler(timeline: .init(clips: [bed, primary]))
        scheduler.advance(to: 6)
        XCTAssertEqual(scheduler.selection?.clipID, bed.id)
        XCTAssertEqual(scheduler.selection?.offset, 1)
    }

    func testCollectionOrderAndTrimStopWithoutLooping() {
        let first = WorkoutMusicTrack(title: "First", filename: "a.wav", duration: 10)
        let second = WorkoutMusicTrack(title: "Second", filename: "b.wav", duration: 20)
        let collection = WorkoutMusicClip(title: "Folder", lane: .background, start: 0,
                                          duration: 15, tracks: [first, second])
        var scheduler = WorkoutMusicScheduler(timeline: .init(clips: [collection]))
        scheduler.advance(to: 12)
        XCTAssertEqual(scheduler.selection?.track.id, second.id)
        XCTAssertEqual(scheduler.selection?.offset, 2)
        scheduler.advance(to: 15)
        XCTAssertNil(scheduler.selection)
        XCTAssertTrue(scheduler.exhausted)
        scheduler.advance(to: 100)
        XCTAssertNil(scheduler.selection)
    }

    func testGapIsSilenceButNotExhaustionBeforeFutureFallback() {
        let primary = clip("Main", duration: 10)
        let fallback = clip("Fallback", start: 20, duration: 10)
        var scheduler = WorkoutMusicScheduler(timeline: .init(clips: [primary, fallback]))
        scheduler.advance(to: 15)
        XCTAssertNil(scheduler.selection)
        XCTAssertFalse(scheduler.exhausted)
        scheduler.advance(to: 25)
        XCTAssertEqual(scheduler.selection?.clipID, fallback.id)
        scheduler.advance(to: 30)
        XCTAssertNil(scheduler.selection)
        XCTAssertTrue(scheduler.exhausted)
    }

    func testCursorRoundTripPreservesInterruptedBackgroundPosition() throws {
        let timeline = WorkoutMusicTimeline(clips: [clip("Bed", duration: 90),
                                                    clip("Push", lane: .primary, start: 10, duration: 10)])
        var scheduler = WorkoutMusicScheduler(timeline: timeline)
        scheduler.advance(to: 15)
        let checkpoint = try JSONDecoder().decode(WorkoutMusicCursor.self, from: JSONEncoder().encode(scheduler.cursor))
        var restored = WorkoutMusicScheduler(timeline: timeline, cursor: checkpoint)
        restored.advance(to: 23)
        XCTAssertEqual(restored.selection?.track.title, "Bed")
        XCTAssertEqual(restored.selection?.offset, 13)
    }

    func testLegacyPlaylistAndExplicitSilentTimelineRemainDistinct() throws {
        let legacy = try JSONDecoder().decode(WorkoutManifest.self, from: Data("{\"id\":\"legacy\"}".utf8))
        XCTAssertNil(legacy.musicTimeline)
        let silent = WorkoutManifest(id: "silent", name: "Silent", musicTimeline: .init())
        let decoded = try JSONDecoder().decode(WorkoutManifest.self, from: JSONEncoder().encode(silent))
        XCTAssertEqual(decoded.musicTimeline, .init())
    }

    func testResizeDoesNotSnapUntilRepeatedCorrectionsAtSameBoundary() {
        var intent = WorkoutMusicResizeIntent()
        XCTAssertEqual(intent.adjustedEnd(29, boundaries: [30], tolerance: 4), 29)
        XCTAssertEqual(intent.adjustedEnd(31, boundaries: [30], tolerance: 4), 31)
        XCTAssertEqual(intent.adjustedEnd(29.5, boundaries: [30], tolerance: 4), 30)
        XCTAssertEqual(intent.adjustedEnd(50, boundaries: [30], tolerance: 4), 50)
        XCTAssertEqual(intent.adjustedEnd(29.5, boundaries: [30], tolerance: 4), 29.5)
    }
}
