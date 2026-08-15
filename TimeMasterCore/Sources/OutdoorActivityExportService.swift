import Foundation

public enum OutdoorActivityExportService {
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    public static func gpxURL(for manifest: OutdoorActivityManifest, points: [OutdoorTrackPoint]) throws -> URL {
        let trackPoints = points.map { point in
            let elevation = point.elevationMeters.map { "<ele>\($0)</ele>" } ?? ""
            return "<trkpt lat=\"\(xml(point.latitude))\" lon=\"\(xml(point.longitude))\">\(elevation)<time>\(xml(iso8601.string(from: point.timestamp)))</time></trkpt>"
        }.joined()
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TimeMaster" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 https://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata><name>\(xml(manifest.title))</name><time>\(xml(iso8601.string(from: manifest.startedAt)))</time></metadata>
          <trk><name>\(xml(manifest.title))</name><type>\(xml(manifest.kind.rawValue))</type><trkseg>\(trackPoints)</trkseg></trk>
        </gpx>
        """
        return try temporaryFile(extension: "gpx", content: content)
    }

    public static func csvURL(for manifest: OutdoorActivityManifest, points: [OutdoorTrackPoint]) throws -> URL {
        var rows = ["timestamp,latitude,longitude,elevationMeters,horizontalAccuracyMeters,speedMetersPerSecond,state,cumulativeDistanceMeters"]
        var cumulativeDistance = 0.0
        var previous: OutdoorTrackPoint?
        for point in points {
            if let previous {
                cumulativeDistance += distanceMeters(from: previous, to: point)
            }
            let values: [String] = [
                iso8601.string(from: point.timestamp),
                String(point.latitude),
                String(point.longitude),
                point.elevationMeters.map { String($0) } ?? "",
                String(point.horizontalAccuracyMeters),
                point.speedMetersPerSecond.map { String($0) } ?? "",
                point.state.rawValue,
                String(cumulativeDistance),
            ]
            rows.append(values.map(csvEscape).joined(separator: ","))
            previous = point
        }
        return try temporaryFile(extension: "csv", content: rows.joined(separator: "\n") + "\n")
    }

    private static func temporaryFile(extension: String, content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster-\(UUID().uuidString)")
            .appendingPathExtension(`extension`)
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    private static func xml(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func xml(_ value: Double) -> String { xml(String(value)) }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func distanceMeters(from first: OutdoorTrackPoint, to second: OutdoorTrackPoint) -> Double {
        guard first.latitude.isFinite, first.longitude.isFinite, second.latitude.isFinite, second.longitude.isFinite else { return 0 }
        let radius = 6_371_000.0
        let lat1 = first.latitude * .pi / 180
        let lat2 = second.latitude * .pi / 180
        let dLat = (second.latitude - first.latitude) * .pi / 180
        let dLon = (second.longitude - first.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}
