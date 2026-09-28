import XCTest
import CoreLocation
import TimeMasterCore
@testable import TimeMaster

@MainActor
final class OutdoorRideSafetyTests: XCTestCase {
    private var root: URL!
    private var database: DatabaseManager!
    private var store: OutdoorActivityStore!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        store = OutdoorActivityStore(database: database)
    }

    override func tearDownWithError() throws {
        store = nil
        database = nil
        try FileManager.default.removeItem(at: root)
    }

    private func point(_ meters: Double, seconds: Double, altitude: Double = 100) -> TimeMaster.OutdoorTrackPoint {
        TimeMaster.OutdoorTrackPoint(
            timestamp: start.addingTimeInterval(seconds),
            latitude: 45 + meters / 6_371_000 * 180 / .pi,
            longitude: 7,
            elevationMeters: altitude,
            horizontalAccuracyMeters: 4,
            speedMetersPerSecond: 5,
            state: .recording,
            verticalAccuracyMeters: 3
        )
    }

    private func location(altitude: Double, seconds: Double) -> CLLocation {
        CLLocation(coordinate: .init(latitude: 45, longitude: 7), altitude: altitude,
                   horizontalAccuracy: 4, verticalAccuracy: 3, timestamp: start.addingTimeInterval(seconds))
    }

    private func begin() throws -> TimeMaster.OutdoorActivity {
        let manifest = OutdoorActivityManifest(id: UUID().uuidString, kind: .bike, startedAt: start)
        try database.createOutdoorActivity(id: manifest.id, manifest: manifest)
        store.reload()
        let activity = try XCTUnwrap(store.recoverableActivities.first)
        try store.resume(activity)
        return activity
    }

    func testFiftyKilometerRideSurvivesFinishEstablishAndReload() throws {
        let activity = try begin()
        for index in 0...5_000 {
            try store.append(point: point(Double(index) * 10, seconds: Double(index) * 2))
        }
        let finished = try XCTUnwrap(store.finish(at: start.addingTimeInterval(10_000)))
        XCTAssertEqual(finished.distanceMeters, 50_000, accuracy: 1)
        XCTAssertEqual(finished.movingSeconds, 10_000)
        XCTAssertEqual(try XCTUnwrap(finished.averageSpeedMetersPerSecond), 5, accuracy: 0.01)
        try store.establish(finished, visibility: .privateVisibility)
        let reopened = OutdoorActivityStore(database: DatabaseManager(fs: FileSystemHelper(dataRoot: root)))
        let saved = try XCTUnwrap(reopened.establishedActivities.first)
        XCTAssertEqual(saved.id, activity.id)
        XCTAssertEqual(saved.distanceMeters, 50_000, accuracy: 1)
        XCTAssertEqual(reopened.trackPoints(for: saved).count, 5_001)
        XCTAssertTrue(reopened.recoverableActivities.isEmpty)
    }

    func testManualPauseExcludesMovementDuringBreak() throws {
        _ = try begin()
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20))
        try store.pauseManually(at: start.addingTimeInterval(21))
        try store.resumeManually(at: start.addingTimeInterval(100))
        try store.append(point: point(1_000, seconds: 101))
        try store.append(point: point(1_100, seconds: 121))
        XCTAssertEqual(try XCTUnwrap(store.active).distanceMeters, 200, accuracy: 0.1)
        XCTAssertEqual(store.active?.movingSeconds, 40)
    }

    func testFinishedResumeDoesNotCountUnrecordedTravel() throws {
        _ = try begin()
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20))
        let finished = try XCTUnwrap(store.finish(at: start.addingTimeInterval(21)))
        try store.resume(finished, at: start.addingTimeInterval(199))
        try store.append(point: point(1_000, seconds: 200))
        try store.append(point: point(1_100, seconds: 220))
        XCTAssertEqual(try XCTUnwrap(store.active).distanceMeters, 200, accuracy: 0.1)
    }

    func testRelaunchDoesNotBridgeTimeWithoutGPS() throws {
        _ = try begin()
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20))
        let reopened = OutdoorActivityStore(database: database)
        try reopened.resume(try XCTUnwrap(reopened.recoverableActivities.first), at: start.addingTimeInterval(199))
        try reopened.append(point: point(1_000, seconds: 200))
        try reopened.append(point: point(1_100, seconds: 220))
        XCTAssertEqual(try XCTUnwrap(reopened.active).distanceMeters, 200, accuracy: 0.1)
        XCTAssertEqual(reopened.active?.movingSeconds, 40)
    }

    func testFinishedRideRemainsRecoverableUntilEstablished() throws {
        let activity = try begin()
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20))
        _ = try store.finish(at: start.addingTimeInterval(21))
        let reopened = OutdoorActivityStore(database: database)
        XCTAssertEqual(reopened.recoverableActivities.first?.id, activity.id)
        XCTAssertTrue(reopened.recoverableActivities.first?.finished == true)
    }

    func testRecoveryRebuildsLastUncheckpointedElevation() throws {
        _ = try begin()
        try store.append(point: point(0, seconds: 0), filteredElevationGainMeters: 0)
        try store.append(point: point(100, seconds: 20, altitude: 110), filteredElevationGainMeters: 10)
        let recovered = OutdoorActivityStore(database: database)
        let activity = try XCTUnwrap(recovered.recoverableActivities.first)
        XCTAssertEqual(activity.distanceMeters, 100, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(activity.elevationGainMeters), 10, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(activity.highestElevationMeters), 110, accuracy: 0.1)
    }

    func testGradualClimbAccumulatesSubthresholdIncrements() {
        let processor = OutdoorElevationProcessor(source: .gps)
        for index in 0...200 {
            _ = processor.process(location: location(altitude: 100 + Double(index) * 0.5, seconds: Double(index)))
        }
        XCTAssertEqual(processor.elevationGainMeters, 100, accuracy: 2)
    }

    func testStationaryAltitudeNoiseDoesNotAccumulateClimbing() {
        let processor = OutdoorElevationProcessor(source: .gps)
        for index in 0...200 {
            _ = processor.process(location: location(altitude: 100 + (index.isMultiple(of: 2) ? 0.5 : -0.5), seconds: Double(index)))
        }
        XCTAssertEqual(processor.elevationGainMeters, 0)
    }

    func testBarometerReanchoringDoesNotInventClimbing() {
        let processor = OutdoorElevationProcessor(source: .hybrid)
        _ = processor.process(location: location(altitude: 100, seconds: 0), barometricRelativeAltitudeMeters: 0)
        _ = processor.process(location: location(altitude: 120, seconds: 31), barometricRelativeAltitudeMeters: 0)
        XCTAssertEqual(processor.elevationGainMeters, 0)
    }

    func testTighterAccuracyDoesNotRejectEveryFuturePoint() {
        var first = point(0, seconds: 0)
        first.horizontalAccuracyMeters = 80
        XCTAssertTrue(OutdoorMetricsCalculator.accepts(point(10, seconds: 2), after: first, maximumHorizontalAccuracyMeters: 25))
    }

    func testInvalidFixesDoNotInflateDistance() {
        let first = point(0, seconds: 0)
        var inaccurate = point(20, seconds: 2)
        inaccurate.horizontalAccuracyMeters = 500
        XCTAssertFalse(OutdoorMetricsCalculator.accepts(inaccurate, after: first))
        XCTAssertFalse(OutdoorMetricsCalculator.accepts(point(10_000, seconds: 1), after: first))
        XCTAssertFalse(OutdoorMetricsCalculator.accepts(point(10, seconds: 0), after: first))
        XCTAssertFalse(OutdoorMetricsCalculator.accepts(point(10, seconds: -1), after: first))
        var invalid = point(10, seconds: 2)
        invalid.latitude = .nan
        XCTAssertFalse(OutdoorMetricsCalculator.accepts(invalid, after: first))
    }

    func testLiveSpeedReturnsToZeroWhenStoppedWithoutAutoPause() throws {
        let preferences = OutdoorRecordingPreferencesStore(database: database)
        try preferences.update { $0.autoPause = false }
        let recorder = OutdoorLocationRecorder(kind: .bike, store: store, preferences: preferences)
        let activity = try store.begin(kind: .bike)
        XCTAssertTrue(recorder.resumeAfterFinish(activity))
        defer { recorder.cancel() }
        let now = Date()
        let manager = CLLocationManager()
        for (offset, speed) in [(-2.0, 5.0), (-1.0, 0.0)] {
            recorder.locationManager(manager, didUpdateLocations: [
                CLLocation(coordinate: .init(latitude: 45, longitude: 7), altitude: 100,
                           horizontalAccuracy: 4, verticalAccuracy: 3, course: 0,
                           speed: speed, timestamp: now.addingTimeInterval(offset))
            ])
        }
        XCTAssertEqual(recorder.liveSpeedMetersPerSecond, 0)
    }

    func testInaccurateGPSWarnsWithoutDestroyingRecordedRoute() throws {
        let preferences = OutdoorRecordingPreferencesStore(database: database)
        let recorder = OutdoorLocationRecorder(kind: .bike, store: store, preferences: preferences)
        let activity = try store.begin(kind: .bike)
        XCTAssertTrue(recorder.resumeAfterFinish(activity))
        defer { recorder.cancel() }
        let now = Date()
        let manager = CLLocationManager()
        for (offset, accuracy) in [(-2.0, 4.0), (-1.0, 500.0)] {
            recorder.locationManager(manager, didUpdateLocations: [
                CLLocation(coordinate: .init(latitude: 45, longitude: 7), altitude: 100,
                           horizontalAccuracy: accuracy, verticalAccuracy: 3, course: 0,
                           speed: 5, timestamp: now.addingTimeInterval(offset))
            ])
        }
        XCTAssertTrue(recorder.gpsUnavailable)
        XCTAssertEqual(recorder.route.count, 1)
        XCTAssertEqual(recorder.state, .recording)
    }

    func testLostGPSClearsStaleSpeedAndKeepsSessionRecoverable() throws {
        let preferences = OutdoorRecordingPreferencesStore(database: database)
        let recorder = OutdoorLocationRecorder(kind: .bike, store: store, preferences: preferences)
        let activity = try store.begin(kind: .bike)
        XCTAssertTrue(recorder.resumeAfterFinish(activity))
        defer { recorder.cancel() }
        let now = Date()
        recorder.locationManager(CLLocationManager(), didUpdateLocations: [
            CLLocation(coordinate: .init(latitude: 45, longitude: 7), altitude: 100,
                       horizontalAccuracy: 4, verticalAccuracy: 3, course: 0,
                       speed: 5, timestamp: now)
        ])
        XCTAssertFalse(recorder.gpsUnavailable)
        recorder.refreshGPSHealth(at: now.addingTimeInterval(16))
        XCTAssertTrue(recorder.gpsUnavailable)
        XCTAssertNil(recorder.liveSpeedMetersPerSecond)
        XCTAssertEqual(recorder.state, .recording)
        XCTAssertTrue(recorder.isLiveSession)
    }

    func testShortDiscardAllowsDifferentNextActivityKind() throws {
        let preferences = OutdoorRecordingPreferencesStore(database: database)
        let recorder = OutdoorLocationRecorder(kind: .bike, store: store, preferences: preferences)
        let activity = try store.begin(kind: .bike)
        XCTAssertTrue(recorder.resumeAfterFinish(activity))
        guard case .shortSessionDiscarded = recorder.finishWithOutcome() else {
            return XCTFail("A zero-distance session must be discarded")
        }
        recorder.updateKind(.walk)
        XCTAssertEqual(recorder.kind, .walk)
    }

    func testSavedWorkoutEditsPreserveRecordedDataAndCustomName() throws {
        _ = try begin()
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20, altitude: 120))
        let finished = try XCTUnwrap(store.finish(at: start.addingTimeInterval(20)))
        let saved = try store.establish(finished, visibility: .publicVisibility, at: start.addingTimeInterval(30))
        let recordedPoints = store.trackPoints(for: saved)
        try store.updateTitle("Morning hills", for: saved)
        try store.setKind(.walk, for: saved)
        try store.updateDetails(for: saved, description: "A good climb", tags: ["hills"], allowComments: false, hideStartFinish: true, endpointPrivacyMeters: 200, showPlayerTracks: false)
        try store.setVisibility(.privateVisibility, for: saved)

        let reopened = OutdoorActivityStore(database: DatabaseManager(fs: FileSystemHelper(dataRoot: root)))
        let edited = try XCTUnwrap(reopened.establishedActivities.first)
        XCTAssertEqual(edited.title, "Morning hills")
        XCTAssertEqual(edited.kind, .walk)
        XCTAssertEqual(edited.publicDescription, "A good climb")
        XCTAssertEqual(edited.tags, ["hills"])
        XCTAssertEqual(edited.visibility, .privateVisibility)
        XCTAssertTrue(edited.hasPublicMetadata)
        XCTAssertEqual(edited.establishedAt, saved.establishedAt)
        XCTAssertEqual(edited.startedAt, saved.startedAt)
        XCTAssertEqual(edited.endedAt, saved.endedAt)
        XCTAssertEqual(edited.distanceMeters, saved.distanceMeters)
        XCTAssertEqual(edited.movingSeconds, saved.movingSeconds)
        XCTAssertEqual(edited.elevationGainMeters, saved.elevationGainMeters)
        XCTAssertEqual(reopened.trackPoints(for: edited), recordedPoints)
    }

    func testChangingSavedTypeUpdatesAnAutomaticNameButRejectsAnActiveRide() throws {
        let active = try begin()
        XCTAssertThrowsError(try store.setKind(.walk, for: active))
        XCTAssertEqual(store.active?.kind, .bike)
        try store.append(point: point(0, seconds: 0))
        try store.append(point: point(100, seconds: 20))
        let finished = try XCTUnwrap(store.finish(at: start.addingTimeInterval(20)))
        try store.setKind(.run, for: finished)
        store.reload()
        let edited = try XCTUnwrap(store.recoverableActivities.first)
        XCTAssertEqual(edited.kind, .run)
        XCTAssertEqual(edited.title, TimeMaster.OutdoorActivityKind.run.defaultTitle)
    }

    func testModeReminderRemembersCancellationAndConfirmationAcrossRelaunches() {
        let suite = "OutdoorModeReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let reminder = OutdoorModeReminder(defaults: defaults, at: start, observesLifecycle: false)
        XCTAssertEqual(reminder.requestPrompt(at: start), .choose)
        let reopened = OutdoorModeReminder(defaults: defaults, at: start.addingTimeInterval(20), observesLifecycle: false)
        XCTAssertEqual(reopened.requestPrompt(at: start.addingTimeInterval(20)), .confirm)
        reopened.confirm(at: start.addingTimeInterval(21))
        let confirmed = OutdoorModeReminder(defaults: defaults, at: start.addingTimeInterval(40), observesLifecycle: false)
        XCTAssertNil(confirmed.requestPrompt(at: start.addingTimeInterval(40)))
    }

    func testModeReminderExpiresAfterAnHourAwayButNotDuringActiveUse() {
        let suite = "OutdoorModeReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let reminder = OutdoorModeReminder(defaults: defaults, at: start, observesLifecycle: false)
        reminder.confirm(at: start)
        XCTAssertNil(reminder.requestPrompt(at: start.addingTimeInterval(7_200)))
        reminder.wentAway(at: start.addingTimeInterval(7_200))
        reminder.becameActive(at: start.addingTimeInterval(10_799))
        XCTAssertNil(reminder.requestPrompt(at: start.addingTimeInterval(10_799)))
        reminder.wentAway(at: start.addingTimeInterval(10_800))
        let reopened = OutdoorModeReminder(defaults: defaults, at: start.addingTimeInterval(14_400), observesLifecycle: false)
        XCTAssertEqual(reopened.requestPrompt(at: start.addingTimeInterval(14_400)), .choose)
    }

    func testPanesStayAboveSafeAreaAndPlayerWhenViewportShrinks() {
        for viewportHeight: CGFloat in [852, 420] {
            for playerHeight: CGFloat in [0, 94] {
                let layout = OutdoorPineGeometry(size: CGSize(width: 393, height: viewportHeight),
                                                 safeAreaTop: 59, safeAreaBottom: 34, playerReserve: playerHeight)
                let safeBottom = viewportHeight - 34 - playerHeight
                let mainTop = layout.mainTop(mainHeight: layout.mainFullHeight, featureHeight: nil)
                XCTAssertGreaterThanOrEqual(mainTop, layout.safeAreaTop)
                XCTAssertLessThan(mainTop + layout.mainFullHeight, safeBottom)

                let featureHeight = layout.maximumFeatureHeight(music: true)
                let featureTop = viewportHeight - layout.lowerInset - featureHeight
                let stackedTop = layout.mainTop(mainHeight: layout.mainMinimumWithFeature, featureHeight: featureHeight)
                XCTAssertGreaterThanOrEqual(stackedTop, layout.safeAreaTop)
                XCTAssertLessThanOrEqual(stackedTop + layout.mainMinimumWithFeature + 8, featureTop)
                XCTAssertLessThan(featureTop + featureHeight, safeBottom)
            }
        }
    }
}
