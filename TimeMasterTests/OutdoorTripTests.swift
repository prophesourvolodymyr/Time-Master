import XCTest
import TimeMasterCore
@testable import TimeMaster

@MainActor
final class OutdoorTripTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func point(_ meters: Double, _ seconds: Double, mode: OutdoorTravelMode = .active, altitude: Double = 0) -> TimeMaster.OutdoorTrackPoint {
        TimeMaster.OutdoorTrackPoint(timestamp: start.addingTimeInterval(seconds), latitude: 45 + meters / 6_371_000 * 180 / .pi, longitude: 7, elevationMeters: altitude, horizontalAccuracyMeters: 4, state: .recording, travelMode: mode)
    }

    func testBusTravelDoesNotInflateRidingSpeedTimeOrElevation() throws {
        let points = [point(0, 0), point(100, 20, altitude: 5), point(110, 22, mode: .bus, altitude: 10), point(2_110, 122, mode: .bus, altitude: 300), point(2_120, 124, altitude: 300), point(2_220, 144, altitude: 305)]
        let metrics = OutdoorMetricsCalculator.aggregate(points: points, pauses: [])
        XCTAssertEqual(metrics.distanceMeters, 200, accuracy: 0.1)
        XCTAssertEqual(metrics.totalDistanceMeters, 2_220, accuracy: 0.1)
        XCTAssertEqual(metrics.movingSeconds, 40)
        XCTAssertEqual(try XCTUnwrap(metrics.averageSpeedMetersPerSecond), 5, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(metrics.maxSpeedMetersPerSecond), 5, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(metrics.elevationGainMeters), 10, accuracy: 0.01)
    }

    func testBusPauseDoesNotBridgeUnrecordedDistance() {
        let points = [point(0, 0, mode: .bus), point(100, 10, mode: .bus), point(1_100, 110, mode: .bus), point(1_200, 120, mode: .bus)]
        let pauses = [TimeMaster.OutdoorPauseInterval(startedAt: start.addingTimeInterval(11), endedAt: start.addingTimeInterval(109), automatic: false)]
        let metrics = OutdoorMetricsCalculator.aggregate(points: points, pauses: pauses)
        XCTAssertEqual(metrics.distanceMeters, 0)
        XCTAssertEqual(metrics.totalDistanceMeters, 200, accuracy: 0.1)
        XCTAssertEqual(metrics.movingSeconds, 0)
        XCTAssertNil(metrics.maxSpeedMetersPerSecond)
    }

    func testRecoveryKeepsBusModeAndOriginalPlanAfterTripDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        let store = OutdoorActivityStore(database: database)
        var plan = PlannedRoute(title: "Original itinerary", points: [point(0, 0), point(100, 20)])
        plan.trip = OutdoorTrip(kind: .bike, isDraft: false, stops: [TripStop(name: "Start", coordinate: .init(latitude: 45, longitude: 7)), TripStop(name: "Bus stop", coordinate: .init(latitude: 45.01, longitude: 7), incomingMode: .bus)])
        try store.savePlannedRoute(plan)
        _ = try store.begin(kind: .bike, plannedRoute: plan)
        try store.setTravelMode(.bus)
        try store.append(point: point(0, 0, mode: .bus))
        try store.append(point: point(100, 10, mode: .bus))
        try store.deletePlannedRoute(plan)
        let reopened = OutdoorActivityStore(database: database)
        let activity = try XCTUnwrap(reopened.recoverableActivities.first)
        XCTAssertEqual(activity.currentTravelMode, .bus)
        XCTAssertEqual(activity.distanceMeters, 0)
        XCTAssertEqual(activity.tripDistanceMeters, 100, accuracy: 0.1)
        XCTAssertEqual(reopened.recordedPlan(for: activity)?.title, "Original itinerary")
        XCTAssertEqual(reopened.recordedPlan(for: activity)?.trip?.stops.last?.incomingMode, .bus)
    }

    func testDraftReloadAndDiscardEditingDoNotDeleteSavedTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        let store = OutdoorActivityStore(database: database)
        let editor = OutdoorTripEditor(route: nil, kind: .bike, store: store)
        editor.setCurrentLocation(.init(latitude: 45, longitude: 7))
        editor.rename("Draft name")
        let saved = try editor.save(draft: true)
        let reopened = OutdoorActivityStore(database: database)
        XCTAssertEqual(reopened.plannedRoutes.first?.title, "Draft name")
        XCTAssertEqual(reopened.plannedRoutes.first?.trip?.stops.count, 1)
        XCTAssertTrue(reopened.plannedRoutes.first?.isDraft == true)
        let editing = OutdoorTripEditor(route: saved, kind: .bike, store: reopened)
        editing.rename("Unsaved name")
        try editing.discardEdits()
        XCTAssertNil(try reopened.loadTripRecovery())
        reopened.reload()
        XCTAssertEqual(reopened.plannedRoutes.first?.title, "Draft name")
    }

    func testPlannedBusDistanceAndClimbingRemainSeparateFromActiveEffort() throws {
        let coordinate = TripCoordinate(latitude: 49.27, longitude: -123.13)
        let active = TripRouteLeg(id: UUID(), mode: .active, coordinates: [coordinate, coordinate], controlPointIndices: [0, 1], distanceMeters: 2_000, durationSeconds: 400, ascentMeters: 20, instructions: [])
        let bus = TripRouteLeg(id: UUID(), mode: .bus, coordinates: [coordinate, coordinate], controlPointIndices: [0, 1], distanceMeters: 100_000, durationSeconds: 3_600, ascentMeters: 1_000, instructions: [])
        var trip = OutdoorTrip(legs: [active, bus])
        XCTAssertEqual(trip.activeDistanceMeters, 2_000)
        XCTAssertEqual(trip.totalDistanceMeters, 102_000)
        XCTAssertEqual(try XCTUnwrap(trip.ascentMeters), 20)
        trip.legs = [bus]
        XCTAssertEqual(trip.activeDistanceMeters, 0)
        XCTAssertEqual(trip.totalDistanceMeters, 100_000)
        XCTAssertNil(trip.ascentMeters)
        trip.legs = [TripRouteLeg(id: UUID(), mode: .active, coordinates: [], controlPointIndices: [], distanceMeters: 1_000, durationSeconds: 200, instructions: []), bus]
        XCTAssertNil(trip.ascentMeters)
    }

    func testRoadAssessmentWeightsActiveDistanceAndKeepsMissingCoverageUnknown() throws {
        let coordinate = TripCoordinate(latitude: 49.27, longitude: -123.13)
        let short = TripRouteLeg(id: UUID(), mode: .active, coordinates: [coordinate, coordinate], controlPointIndices: [0, 1],
            distanceMeters: 1_000, durationSeconds: 100, unpavedFraction: 0.1, majorRoadFraction: 0.2, instructions: [])
        let long = TripRouteLeg(id: UUID(), mode: .active, coordinates: [coordinate, coordinate], controlPointIndices: [0, 1],
            distanceMeters: 9_000, durationSeconds: 900, unpavedFraction: 0.5, majorRoadFraction: 0.6, instructions: [])
        let bus = TripRouteLeg(id: UUID(), mode: .bus, coordinates: [coordinate, coordinate], controlPointIndices: [0, 1],
            distanceMeters: 100_000, durationSeconds: 5_000, unpavedFraction: 1, majorRoadFraction: 1, instructions: [])
        var trip = OutdoorTrip(legs: [short, long, bus])
        XCTAssertEqual(try XCTUnwrap(trip.unpavedFraction), 0.46, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(trip.majorRoadFraction), 0.56, accuracy: 0.0001)
        XCTAssertEqual(trip.activeDurationSeconds, 1_000)
        trip.legs[1].unpavedFraction = nil
        XCTAssertNil(trip.unpavedFraction)
        XCTAssertEqual(try XCTUnwrap(trip.majorRoadFraction), 0.56, accuracy: 0.0001)
        trip.legs = [bus]
        XCTAssertNil(trip.unpavedFraction)
        XCTAssertNil(trip.majorRoadFraction)
        XCTAssertEqual(trip.activeDurationSeconds, 0)
        trip.legs = [TripRouteLeg(id: UUID(), mode: .active, coordinates: [], controlPointIndices: [], distanceMeters: 0,
            durationSeconds: 0, unpavedFraction: 0, majorRoadFraction: 0, instructions: [])]
        XCTAssertNil(trip.unpavedFraction)
        XCTAssertNil(trip.majorRoadFraction)
    }

    func testCancelledRouteDragRestoresStopsAndRoadGeometry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OutdoorActivityStore(database: DatabaseManager(fs: FileSystemHelper(dataRoot: root)))
        let first = TripStop(name: "Start", coordinate: .init(latitude: 45, longitude: 7))
        let last = TripStop(name: "Finish", coordinate: .init(latitude: 45.01, longitude: 7))
        var trip = OutdoorTrip(stops: [first, last], legs: [TripRouteLeg(id: last.id, mode: .active, coordinates: [first.coordinate, last.coordinate], controlPointIndices: [0, 1], distanceMeters: 1_000, durationSeconds: 200, instructions: [])])
        trip.routingFingerprint = trip.fingerprint
        var plan = PlannedRoute(title: "Stable route", points: trip.points)
        plan.trip = trip
        let editor = OutdoorTripEditor(route: plan, kind: .bike, store: store)
        editor.beginDrag(legID: last.id, coordinateIndex: 0)
        editor.updateDrag(.init(latitude: 45.005, longitude: 7.001), ended: false)
        editor.cancelDrag()
        XCTAssertEqual(editor.route, plan)
        XCTAssertTrue(editor.canSave)
        XCTAssertEqual(editor.trip.stops.count, 2)
        XCTAssertTrue(editor.trip.stops.last?.shapingPoints.isEmpty == true)
    }

    func testExistingRouteFilesRemainAvailableWithoutStarMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        let route = PlannedRoute(title: "Existing imported route", points: [point(0, 0), point(100, 20)], source: .gpxImport)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var oldFile = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(route)) as? [String: Any])
        oldFile.removeValue(forKey: "starred")
        try JSONSerialization.data(withJSONObject: oldFile).write(to: database.routesDirectory.appendingPathComponent("\(route.id).json"))
        let reopened = OutdoorActivityStore(database: database)
        let loaded = try XCTUnwrap(reopened.plannedRoute(withID: route.id.uuidString))
        XCTAssertEqual(loaded.points, route.points)
        XCTAssertEqual(loaded.source, .gpxImport)
        XCTAssertFalse(loaded.starred)
        XCTAssertEqual(loaded.distanceMeters, 100, accuracy: 0.1)
    }

    func testStarPersistenceDoesNotPromoteAnUnfinishedDraft() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        let store = OutdoorActivityStore(database: database)
        var draft = PlannedRoute(title: "Unfinished route", points: [])
        draft.trip = OutdoorTrip(stops: [TripStop(name: "Start", coordinate: .init(latitude: 49.27, longitude: -123.13))])
        try store.savePlannedRoute(draft)
        try store.setStarred(true, for: draft)
        let reopened = OutdoorActivityStore(database: database)
        let starred = try XCTUnwrap(reopened.plannedRoute(withID: draft.id.uuidString))
        XCTAssertTrue(starred.starred)
        XCTAssertTrue(starred.isDraft)
        XCTAssertFalse(try XCTUnwrap(starred.trip).isRouted)
        try reopened.setStarred(false, for: starred)
        let unstarred = try XCTUnwrap(OutdoorActivityStore(database: database).plannedRoute(withID: draft.id.uuidString))
        XCTAssertFalse(unstarred.starred)
        XCTAssertTrue(unstarred.isDraft)
    }

    func testImportedPreviewPreservesOriginalGeometryUntilAnEdit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OutdoorActivityStore(database: DatabaseManager(fs: FileSystemHelper(dataRoot: root)))
        let original = PlannedRoute(title: "Imported road", points: [point(0, 0), point(100, 20), point(300, 60)], source: .gpxImport)
        let editor = OutdoorTripEditor(route: original, kind: .run, store: store)
        XCTAssertTrue(editor.canSave)
        XCTAssertEqual(editor.trip.kind, .run)
        XCTAssertEqual(editor.trip.stops.first?.coordinate.latitude, original.points.first?.latitude)
        editor.suspend()
        let saved = try editor.save(draft: false)
        XCTAssertNil(saved.trip)
        XCTAssertEqual(saved.points, original.points)
        XCTAssertEqual(try XCTUnwrap(store.plannedRoute(withID: original.id.uuidString)).points, original.points)
    }
}
