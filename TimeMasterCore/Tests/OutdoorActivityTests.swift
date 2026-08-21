import XCTest
import CoreLocation
@testable import TimeMasterCore

final class OutdoorActivityTests: XCTestCase {
    private var db: DatabaseManager!
    private var fs: FileSystemHelper!
    private var tempDir: URL!
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fs = FileSystemHelper(dataRoot: tempDir)
        db = DatabaseManager(fs: fs)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testBootstrapCreatesActivitiesDirectory() throws {
        try db.bootstrapIfNeeded()
        XCTAssertTrue(fs.directoryExists(at: fs.outdoorActivitiesDirectory))
    }

    func testManifestCreateUpdateListDelete() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        var manifest = OutdoorActivityManifest(id: id, kind: .bike, startedAt: baseDate)
        try db.createOutdoorActivity(id: id, manifest: manifest)
        XCTAssertEqual(try db.getOutdoorActivity(id: id), manifest)
        manifest.title = "Evening Bike"
        try db.updateOutdoorActivity(id: id, manifest: manifest)
        XCTAssertEqual(try db.listOutdoorActivities().map(\.title), ["Evening Bike"])
        try db.deleteOutdoorActivity(id: id)
        XCTAssertTrue(try db.listOutdoorActivities().isEmpty)
        XCTAssertFalse(fs.directoryExists(at: fs.outdoorActivitiesDirectory.appendingPathComponent(id)))
    }

    func testAppendReadPreservesOrderedPointsAndIgnoresMalformedLine() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        try db.createOutdoorActivity(id: id, manifest: OutdoorActivityManifest(id: id, kind: .runWalk, startedAt: baseDate))
        for index in 0..<100 {
            try db.appendOutdoorTrackPoint(id: id, point: OutdoorTrackPoint(timestamp: baseDate.addingTimeInterval(Double(index)), latitude: 40 + Double(index) / 1000, longitude: -73, horizontalAccuracyMeters: 4, speedMetersPerSecond: 2, state: .recording))
        }
        let routeURL = fs.outdoorActivitiesDirectory.appendingPathComponent(id).appendingPathComponent("track.jsonl")
        try fs.appendLineAtomically(to: routeURL, data: Data("not-json\n".utf8))
        let points = try db.readOutdoorTrackPoints(id: id)
        XCTAssertEqual(points.count, 100)
        XCTAssertEqual(points.first?.timestamp, baseDate)
        XCTAssertEqual(points.last?.timestamp, baseDate.addingTimeInterval(99))
    }

    func testManifestISO8601AndFinishedMetadataRoundTrip() throws {
        try db.bootstrapIfNeeded()
        let pause = OutdoorPauseInterval(startedAt: baseDate.addingTimeInterval(10), endedAt: baseDate.addingTimeInterval(30), automatic: true)
        let lap = OutdoorLap(number: 1, timestamp: baseDate.addingTimeInterval(60), elapsedSeconds: 60, distanceMeters: 250)
        let id = UUID().uuidString
        let manifest = OutdoorActivityManifest(id: id, kind: .bike, startedAt: baseDate, endedAt: baseDate.addingTimeInterval(60), elapsedSeconds: 60, movingSeconds: 40, distanceMeters: 250, averageSpeedMetersPerSecond: 6.25, maxSpeedMetersPerSecond: 9, timeTargetSeconds: 60, pauseIntervals: [pause], laps: [lap], trackPointCount: 3, recordingState: .finished, finished: true)
        try db.createOutdoorActivity(id: id, manifest: manifest)
        let saved = try db.getOutdoorActivity(id: id)
        XCTAssertEqual(saved, manifest)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(OutdoorActivityManifest.self, from: encoder.encode(manifest)), manifest)
    }

    func testExportersProduceValidEmptyAndPopulatedFiles() throws {
        let manifest = OutdoorActivityManifest(id: "export", kind: .bike, title: "A & B", startedAt: baseDate)
        let points = (0..<3).map { index in
            OutdoorTrackPoint(timestamp: baseDate.addingTimeInterval(Double(index) * 10), latitude: 40 + Double(index) / 1000, longitude: -73, elevationMeters: Double(index), horizontalAccuracyMeters: 4, speedMetersPerSecond: 2, state: .recording)
        }
        let gpx = try OutdoorActivityExportService.gpxURL(for: manifest, points: points)
        let csv = try OutdoorActivityExportService.csvURL(for: manifest, points: points)
        let gpxText = try String(contentsOf: gpx)
        let csvText = try String(contentsOf: csv)
        XCTAssertTrue(gpxText.contains("version=\"1.1\""))
        XCTAssertEqual(gpxText.components(separatedBy: "<trkpt ").count - 1, 3)
        XCTAssertTrue(gpxText.contains("<ele>1.0</ele>"))
        XCTAssertTrue(gpxText.contains("A &amp; B"))
        XCTAssertEqual(csvText.components(separatedBy: "\n").count, 5)
        XCTAssertTrue(csvText.hasPrefix("timestamp,latitude,longitude,elevationMeters,horizontalAccuracyMeters,speedMetersPerSecond,state,cumulativeDistanceMeters\n"))
        let emptyCSV = try OutdoorActivityExportService.csvURL(for: manifest, points: [])
        XCTAssertEqual(try String(contentsOf: emptyCSV).components(separatedBy: "\n").count, 2)
    }

    func testSnapperSnapsToStraightLineWithinOneMeter() {
        // straight line from (0,0) to (0,0.01) ~1.1km
        let route = (0..<10).map { i in
            OutdoorTrackPoint(timestamp: Date().addingTimeInterval(Double(i)), latitude: 0, longitude: Double(i) * 0.001, horizontalAccuracyMeters: 5, state: .recording)
        }
        let off = CLLocation(latitude: 0.000005, longitude: 0.005) // slightly off the line, under one meter
        let snap = OutdoorRouteSnapper.snap(location: off, to: route, radiusMeters: 100)
        XCTAssertNotNil(snap)
        if let s = snap {
            XCTAssertLessThan(s.distanceToRouteMeters, 1.0, "snapped point must be within 1m of line")
        }
    }
 
    func testLegacyFinishedManifestDecodesAsEstablishedPrivateAndUnstarred() throws {
        let payload: [String: Any] = [
            "id": "legacy",
            "kind": "bike",
            "title": "Legacy Ride",
            "startedAt": baseDate.timeIntervalSince1970,
            "endedAt": baseDate.addingTimeInterval(60).timeIntervalSince1970,
            "elapsedSeconds": 60,
            "movingSeconds": 50,
            "distanceMeters": 500,
            "trackPointCount": 2,
            "recordingState": "finished",
            "finished": true
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let manifest = try decoder.decode(OutdoorActivityManifest.self, from: data)

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.establishedAt, baseDate.addingTimeInterval(60))
        XCTAssertEqual(manifest.visibility, .privateVisibility)
        XCTAssertFalse(manifest.starred)
        XCTAssertFalse(manifest.hasPublicMetadata)
        XCTAssertTrue(manifest.playedTracks.isEmpty)
    }

    func testVersionTwoFinishedManifestPreservesNilEstablishedAt() throws {
        let manifest = OutdoorActivityManifest(
            id: "v2",
            kind: .run,
            startedAt: baseDate,
            endedAt: baseDate.addingTimeInterval(120),
            recordingState: .finished,
            finished: true,
            schemaVersion: 2,
            establishedAt: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(OutdoorActivityManifest.self, from: encoder.encode(manifest))
        XCTAssertEqual(decoded, manifest)
        XCTAssertNil(decoded.establishedAt)
    }

    func testNewOutdoorActivityKindsRoundTripWithStableRawValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for kind in [OutdoorActivityKind.run, .walk, .runWalk, .bike] {
            let data = try encoder.encode(kind)
            XCTAssertEqual(try decoder.decode(OutdoorActivityKind.self, from: data), kind)
        }
        XCTAssertEqual(OutdoorActivityKind.run.rawValue, "run")
        XCTAssertEqual(OutdoorActivityKind.walk.rawValue, "walk")
        XCTAssertEqual(OutdoorActivityKind.runWalk.rawValue, "runWalk")
        XCTAssertEqual(OutdoorActivityKind.bike.rawValue, "bike")
    }

    func testManifestPrivacyClampingAndMetadataRetentionRoundTrip() throws {
        let playedTrack = OutdoorPlayedTrackEvent(
            id: "event-1",
            timestamp: baseDate,
            trackID: "track-1",
            title: "Morning",
            artist: "Artist",
            artworkReference: "artwork"
        )
        let weather = OutdoorWeatherSnapshot(
            timestamp: baseDate,
            temperatureCelsius: 21.5,
            condition: "clear",
            symbolName: "sun.max"
        )
        let manifest = OutdoorActivityManifest(
            id: "metadata",
            kind: .walk,
            startedAt: baseDate,
            visibility: .publicVisibility,
            publicDescription: "Riverside route",
            tags: ["river", "easy"],
            allowComments: false,
            hideStartFinish: false,
            endpointPrivacyMeters: 150,
            showPlayerTracks: false,
            hasPublicMetadata: true,
            playedTracks: [playedTrack],
            weather: weather
        )
        XCTAssertEqual(manifest.endpointPrivacyMeters, 200)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OutdoorActivityManifest.self, from: encoder.encode(manifest))
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.playedTracks, [playedTrack])
        XCTAssertEqual(decoded.weather, weather)
        XCTAssertEqual(OutdoorActivityManifest.clampedEndpointPrivacyMeters(-1), 100)
        XCTAssertEqual(OutdoorActivityManifest.clampedEndpointPrivacyMeters(999), 500)
    }

    func testTrackPointElevationAccuracyFieldsRoundTrip() throws {
        let point = OutdoorTrackPoint(
            timestamp: baseDate,
            latitude: 40,
            longitude: -73,
            elevationMeters: 42,
            horizontalAccuracyMeters: 4,
            speedMetersPerSecond: 2,
            state: .recording,
            verticalAccuracyMeters: 3.5,
            barometricRelativeAltitudeMeters: 1.25
        )
        XCTAssertEqual(try JSONDecoder().decode(OutdoorTrackPoint.self, from: JSONEncoder().encode(point)), point)
    }

    func testConfigManifestOldAndNewOutdoorPreferenceDecoding() throws {
        let oldConfig = try JSONDecoder().decode(ConfigManifest.self, from: Data("{\"weeklyGoal\":5}".utf8))
        XCTAssertEqual(oldConfig.weeklyGoal, 5)
        XCTAssertNil(oldConfig.outdoorRecording)

        let preferences = OutdoorRecordingPreferences(
            unitSystem: .imperial,
            autoPause: false,
            keepScreenAwake: true,
            gpsAccuracy: .balanced,
            elevationSource: .barometer,
            speedSmoothing: false,
            autoDownloadRouteArea: true,
            weatherInfo: false,
            audioCues: .normal,
            defaultVisibility: .publicVisibility,
            hideStartFinish: false,
            endpointPrivacyMeters: 900,
            allowComments: false,
            showPlayerTracks: false,
            haptics: false,
            exportFormat: .fit
        )
        XCTAssertEqual(preferences.endpointPrivacyMeters, 500)
        let config = ConfigManifest(outdoorRecording: preferences)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(ConfigManifest.self, from: encoder.encode(config)), config)
    }
}
