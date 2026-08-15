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
}
