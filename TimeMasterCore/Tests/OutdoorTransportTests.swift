import XCTest
@testable import TimeMasterCore

final class OutdoorTransportTests: XCTestCase {
    func testVersionThreeFinishedDraftIsNotAutoEstablishedBySchemaUpgrade() throws {
        let payload = Data("""
        {"id":"pending","schemaVersion":3,"kind":"bike","startedAt":"2024-01-01T00:00:00Z","finished":true,"recordingState":"finished"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(OutdoorActivityManifest.self, from: payload)
        XCTAssertNil(manifest.establishedAt)
        XCTAssertEqual(manifest.tripDistanceMeters, manifest.distanceMeters)
    }

    func testCSVSeparatesActiveAndBusDistanceWithoutJoiningPausedTravel() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func point(_ meters: Double, _ seconds: Double, _ mode: OutdoorTravelMode) -> OutdoorTrackPoint {
            OutdoorTrackPoint(timestamp: start.addingTimeInterval(seconds), latitude: meters / 6_371_000 * 180 / .pi, longitude: 0, horizontalAccuracyMeters: 4, state: .recording, travelMode: mode)
        }
        let points = [point(0, 0, .active), point(100, 20, .active), point(110, 22, .bus), point(2_110, 122, .bus), point(2_120, 124, .active), point(2_220, 144, .active)]
        let manifest = OutdoorActivityManifest(kind: .bike, startedAt: start)
        let url = try OutdoorActivityExportService.csvURL(for: manifest, points: points)
        defer { try? FileManager.default.removeItem(at: url) }
        let rows = try String(contentsOf: url).split(separator: "\n").map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let header = rows[0]
        let activeColumn = try XCTUnwrap(header.firstIndex(of: "cumulativeDistanceMeters"))
        let totalColumn = try XCTUnwrap(header.firstIndex(of: "totalDistanceMeters"))
        let modeColumn = try XCTUnwrap(header.firstIndex(of: "travelMode"))
        let last = try XCTUnwrap(rows.last)
        XCTAssertEqual(try XCTUnwrap(Double(last[activeColumn])), 200, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(Double(last[totalColumn])), 2_220, accuracy: 0.1)
        XCTAssertEqual(rows[4][modeColumn], "bus")
        XCTAssertEqual(try XCTUnwrap(Double(rows[4][activeColumn])), 100, accuracy: 0.1)
    }
}
