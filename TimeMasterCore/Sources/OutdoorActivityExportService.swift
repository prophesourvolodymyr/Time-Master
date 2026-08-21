import Foundation

public enum OutdoorActivityExportService {
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fitEpoch = Date(timeIntervalSince1970: 631_065_600)
    private static let fitCRCTable: [UInt16] = [
        0x0000, 0xCC01, 0xD801, 0x1400,
        0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401,
        0x5000, 0x9C01, 0x8801, 0x4400
    ]

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

    public static func fitURL(for manifest: OutdoorActivityManifest, points: [OutdoorTrackPoint]) throws -> URL {
        let data = fitData(for: manifest, points: points)
        return try temporaryFile(extension: "fit", data: data)
    }

    public static func privacyProjectedPoints(
        _ points: [OutdoorTrackPoint],
        hidingEndpointsMeters meters: Int
    ) -> [OutdoorTrackPoint] {
        guard !points.isEmpty else { return [] }
        let trim = Double(max(0, meters))
        guard trim > 0 else { return points.map { $0 } }
        guard points.count > 1 else { return [] }

        var cumulative = Array(repeating: 0.0, count: points.count)
        for index in 1..<points.count {
            cumulative[index] = cumulative[index - 1] + distanceMeters(from: points[index - 1], to: points[index])
        }
        let total = cumulative[points.count - 1]
        guard total > trim * 2 else { return [] }
        let startDistance = trim
        let endDistance = total - trim
        let start = point(at: startDistance, in: points, cumulative: cumulative)
        let end = point(at: endDistance, in: points, cumulative: cumulative)
        var result = [start]
        for index in 1..<(points.count - 1) where cumulative[index] > startDistance && cumulative[index] < endDistance {
            result.append(points[index])
        }
        if end != start { result.append(end) }
        return result
    }

    private struct FITField {
        let number: UInt8
        let size: UInt8
        let baseType: UInt8
    }

    private static func fitData(for manifest: OutdoorActivityManifest, points: [OutdoorTrackPoint]) -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        var body = Data()
        appendFITDefinition(local: 0, global: 0, fields: [
            FITField(number: 0, size: 1, baseType: 0x00),
            FITField(number: 1, size: 2, baseType: 0x84),
            FITField(number: 2, size: 2, baseType: 0x84),
            FITField(number: 3, size: 4, baseType: 0x8C),
            FITField(number: 4, size: 4, baseType: 0x86),
            FITField(number: 5, size: 2, baseType: 0x84)
        ], to: &body)
        appendUInt8(4, to: &body)
        appendUInt16(1, to: &body)
        appendUInt16(0, to: &body)
        appendUInt32(0, to: &body)
        appendUInt32(fitTimestamp(manifest.startedAt), to: &body)
        appendUInt16(0, to: &body)

        appendFITDefinition(local: 1, global: 21, fields: [
            FITField(number: 0, size: 1, baseType: 0x00),
            FITField(number: 1, size: 1, baseType: 0x00),
            FITField(number: 253, size: 4, baseType: 0x86)
        ], to: &body)
        appendUInt8(0x00 | 1, to: &body)
        appendUInt8(0, to: &body)
        appendUInt32(fitTimestamp(sortedPoints.first?.timestamp ?? manifest.startedAt), to: &body)

        appendFITDefinition(local: 2, global: 20, fields: [
            FITField(number: 253, size: 4, baseType: 0x86),
            FITField(number: 0, size: 4, baseType: 0x85),
            FITField(number: 1, size: 4, baseType: 0x85),
            FITField(number: 2, size: 2, baseType: 0x84),
            FITField(number: 5, size: 4, baseType: 0x86),
            FITField(number: 6, size: 2, baseType: 0x84)
        ], to: &body)
        var cumulativeDistance = 0.0
        var derivedSpeeds: [Double] = []
        var previous: OutdoorTrackPoint?
        for point in sortedPoints {
            let segmentDistance = previous.map { distanceMeters(from: $0, to: point) } ?? 0
            cumulativeDistance += segmentDistance
            appendUInt8(0x02, to: &body)
            appendUInt32(fitTimestamp(point.timestamp), to: &body)
            appendInt32(semicircles(point.latitude), to: &body)
            appendInt32(semicircles(point.longitude), to: &body)
            appendUInt16(fitAltitude(point.elevationMeters), to: &body)
            appendUInt32(fitDistance(cumulativeDistance, fallback: manifest.distanceMeters), to: &body)
            let derivedSpeed = point.speedMetersPerSecond ?? derivedSpeed(from: previous, to: point, distance: segmentDistance)
            if let derivedSpeed, derivedSpeed.isFinite, derivedSpeed >= 0 {
                derivedSpeeds.append(derivedSpeed)
            }
            appendUInt16(fitSpeed(derivedSpeed), to: &body)
            previous = point
        }

        let elevationSummary = elevationTotals(sortedPoints)

        let startDate = sortedPoints.first?.timestamp ?? manifest.startedAt
        let endDate = sortedPoints.last?.timestamp ?? manifest.endedAt ?? startDate
        let elapsed = max(0, endDate.timeIntervalSince(startDate))
        let totalDistance = cumulativeDistance > 0 ? cumulativeDistance : max(0, manifest.distanceMeters)
        let movingSeconds = max(0, manifest.movingSeconds)
        let manifestElapsedMilliseconds = manifest.elapsedSeconds > 0 ? Double(manifest.elapsedSeconds) * 1000 : 0
        let elapsedMilliseconds = UInt32(min(Double(UInt32.max), max(manifestElapsedMilliseconds, elapsed * 1000)))
        let movingMilliseconds = UInt32(min(Double(UInt32.max), max(0, Double(movingSeconds) * 1000)))
        let maxSpeed = manifest.maxSpeedMetersPerSecond ?? (derivedSpeeds + sortedPoints.compactMap(\.speedMetersPerSecond)).max()
        let averageSpeed = manifest.averageSpeedMetersPerSecond ?? (elapsed > 0 ? totalDistance / elapsed : nil)

        appendFITDefinition(local: 3, global: 18, fields: [
            FITField(number: 253, size: 4, baseType: 0x86),
            FITField(number: 0, size: 1, baseType: 0x00),
            FITField(number: 1, size: 1, baseType: 0x00),
            FITField(number: 2, size: 4, baseType: 0x86),
            FITField(number: 5, size: 1, baseType: 0x00),
            FITField(number: 7, size: 4, baseType: 0x86),
            FITField(number: 8, size: 4, baseType: 0x86),
            FITField(number: 9, size: 4, baseType: 0x86),
            FITField(number: 14, size: 2, baseType: 0x84),
            FITField(number: 15, size: 2, baseType: 0x84),
            FITField(number: 22, size: 2, baseType: 0x84),
            FITField(number: 23, size: 2, baseType: 0x84),
            FITField(number: 26, size: 2, baseType: 0x84)
        ], to: &body)
        appendUInt8(0x03, to: &body)
        appendUInt32(fitTimestamp(endDate), to: &body)
        appendUInt8(9, to: &body)
        appendUInt8(1, to: &body)
        appendUInt32(fitTimestamp(startDate), to: &body)
        appendUInt8(sportValue(manifest.kind), to: &body)
        appendUInt32(elapsedMilliseconds, to: &body)
        appendUInt32(movingMilliseconds > 0 ? movingMilliseconds : elapsedMilliseconds, to: &body)
        appendUInt32(fitDistance(totalDistance, fallback: 0), to: &body)
        appendUInt16(fitSpeed(averageSpeed), to: &body)
        appendUInt16(fitSpeed(maxSpeed), to: &body)
        appendUInt16(fitAltitudeGain(manifest.elevationGainMeters ?? elevationSummary.gain), to: &body)
        appendUInt16(fitAltitudeGain(elevationSummary.descent), to: &body)
        appendUInt16(UInt16(min(65535, max(0, manifest.laps.count))), to: &body)

        appendFITDefinition(local: 1, global: 21, fields: [
            FITField(number: 0, size: 1, baseType: 0x00),
            FITField(number: 1, size: 1, baseType: 0x00),
            FITField(number: 253, size: 4, baseType: 0x86)
        ], to: &body)
        appendUInt8(0x00 | 1, to: &body)
        appendUInt8(1, to: &body)
        appendUInt32(fitTimestamp(endDate), to: &body)

        appendFITDefinition(local: 4, global: 34, fields: [
            FITField(number: 253, size: 4, baseType: 0x86),
            FITField(number: 0, size: 4, baseType: 0x86),
            FITField(number: 1, size: 2, baseType: 0x84),
            FITField(number: 2, size: 1, baseType: 0x00),
            FITField(number: 3, size: 1, baseType: 0x00),
            FITField(number: 4, size: 1, baseType: 0x00)
        ], to: &body)
        appendUInt8(0x04, to: &body)
        appendUInt32(fitTimestamp(endDate), to: &body)
        appendUInt32(movingMilliseconds > 0 ? movingMilliseconds : elapsedMilliseconds, to: &body)
        appendUInt16(1, to: &body)
        appendUInt8(0, to: &body)
        appendUInt8(26, to: &body)
        appendUInt8(1, to: &body)

        var file = Data()
        appendUInt8(14, to: &file)
        appendUInt8(0x20, to: &file)
        appendUInt16(0x0810, to: &file)
        appendUInt32(UInt32(min(UInt64(UInt32.max), UInt64(body.count))), to: &file)
        file.append(contentsOf: [0x2E, 0x46, 0x49, 0x54])
        appendUInt16(fitCRC(file), to: &file)
        file.append(body)
        appendUInt16(fitCRC(file), to: &file)
        return file
    }

    private static func appendFITDefinition(local: UInt8, global: UInt16, fields: [FITField], to data: inout Data) {
        appendUInt8(0x40 | local, to: &data)
        appendUInt8(0, to: &data)
        appendUInt8(0, to: &data)
        appendUInt16(global, to: &data)
        appendUInt8(UInt8(fields.count), to: &data)
        for field in fields {
            appendUInt8(field.number, to: &data)
            appendUInt8(field.size, to: &data)
            appendUInt8(field.baseType, to: &data)
        }
    }

    private static func fitTimestamp(_ date: Date) -> UInt32 {
        let interval = date.timeIntervalSince(fitEpoch)
        guard interval.isFinite else { return 0 }
        return UInt32(min(Double(UInt32.max), max(0, interval.rounded())))
    }

    private static func semicircles(_ degrees: Double) -> Int32 {
        guard degrees.isFinite else { return 0 }
        let boundedDegrees = min(180, max(-180, degrees))
        let value = boundedDegrees * (2_147_483_648.0 / 180.0)
        return Int32(clamping: Int64(value.rounded()))
    }

    private static func fitAltitude(_ altitude: Double?) -> UInt16 {
        guard let altitude, altitude.isFinite else { return UInt16.max }
        let value = min(Double(UInt16.max - 1), max(0, ((altitude + 500) * 5).rounded()))
        return UInt16(clamping: Int(value))
    }

    private static func fitDistance(_ distance: Double, fallback: Double) -> UInt32 {
        let value = distance > 0 ? distance : max(0, fallback)
        guard value.isFinite else { return 0 }
        return UInt32(clamping: Int64(min(Double(UInt32.max), max(0, (value * 100).rounded()))))
    }

    private static func fitSpeed(_ speed: Double?) -> UInt16 {
        guard let speed, speed.isFinite, speed >= 0 else { return UInt16.max }
        let value = min(Double(UInt16.max - 1), (speed * 1000).rounded())
        return UInt16(clamping: Int(value))
    }

    private static func fitAltitudeGain(_ gain: Double?) -> UInt16 {
        guard let gain, gain.isFinite, gain >= 0 else { return UInt16.max }
        return UInt16(clamping: Int(min(Double(UInt16.max - 1), gain.rounded())))
    }


    private static func sportValue(_ kind: OutdoorActivityKind) -> UInt8 {
        switch kind {
        case .run, .runWalk: 1
        case .bike: 2
        case .walk: 11
        }
    }

    private static func derivedSpeed(from previous: OutdoorTrackPoint?, to point: OutdoorTrackPoint, distance: Double) -> Double? {
        guard let previous else { return nil }
        let interval = point.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0, distance.isFinite else { return nil }
        return distance / interval
    }
    private static func elevationTotals(_ points: [OutdoorTrackPoint]) -> (gain: Double?, descent: Double?) {
        var gain = 0.0
        var descent = 0.0
        var previous: Double?
        for point in points {
            guard let elevation = point.elevationMeters, elevation.isFinite else { continue }
            if let previous {
                let delta = elevation - previous
                if delta > 0 {
                    gain += delta
                } else {
                    descent -= delta
                }
            }
            previous = elevation
        }
        return (gain > 0 ? gain : nil, descent > 0 ? descent : nil)
    }

    private static func point(
        at distance: Double,
        in points: [OutdoorTrackPoint],
        cumulative: [Double]
    ) -> OutdoorTrackPoint {
        if distance <= 0 { return points[0] }
        if distance >= cumulative[cumulative.count - 1] { return points[points.count - 1] }
        for index in 1..<points.count where cumulative[index] >= distance {
            let startDistance = cumulative[index - 1]
            let segment = cumulative[index] - startDistance
            guard segment > 0 else { return points[index] }
            let fraction = (distance - startDistance) / segment
            return interpolate(points[index - 1], points[index], fraction: fraction)
        }
        return points[points.count - 1]
    }

    private static func interpolate(_ first: OutdoorTrackPoint, _ second: OutdoorTrackPoint, fraction: Double) -> OutdoorTrackPoint {
        let f = min(1, max(0, fraction))
        func blend(_ first: Double?, _ second: Double?) -> Double? {
            switch (first, second) {
            case let (.some(a), .some(b)): a + (b - a) * f
            case let (.some(a), .none): a
            case let (.none, .some(b)): b
            case (.none, .none): nil
            }
        }
        return OutdoorTrackPoint(
            timestamp: Date(timeIntervalSince1970: first.timestamp.timeIntervalSince1970 + (second.timestamp.timeIntervalSince1970 - first.timestamp.timeIntervalSince1970) * f),
            latitude: first.latitude + (second.latitude - first.latitude) * f,
            longitude: first.longitude + (second.longitude - first.longitude) * f,
            elevationMeters: blend(first.elevationMeters, second.elevationMeters),
            horizontalAccuracyMeters: first.horizontalAccuracyMeters + (second.horizontalAccuracyMeters - first.horizontalAccuracyMeters) * f,
            speedMetersPerSecond: blend(first.speedMetersPerSecond, second.speedMetersPerSecond),
            state: f < 0.5 ? first.state : second.state,
            verticalAccuracyMeters: blend(first.verticalAccuracyMeters, second.verticalAccuracyMeters),
            barometricRelativeAltitudeMeters: blend(first.barometricRelativeAltitudeMeters, second.barometricRelativeAltitudeMeters)
        )
    }

    private static func temporaryFile(extension: String, content: String) throws -> URL {
        try temporaryFile(extension: `extension`, data: Data(content.utf8))
    }

    private static func temporaryFile(extension: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster-\(UUID().uuidString)")
            .appendingPathExtension(`extension`)
        try data.write(to: url, options: .atomic)
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

    private static func appendUInt8(_ value: UInt8, to data: inout Data) {
        data.append(value)
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }

    private static func appendInt32(_ value: Int32, to data: inout Data) {
        appendUInt32(UInt32(bitPattern: value), to: &data)
    }

    private static func fitCRC(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            var value = fitCRCTable[Int(crc & 0x000F)]
            crc = (crc >> 4) & 0x0FFF
            crc ^= value
            crc ^= fitCRCTable[Int(byte & 0x0F)]
            value = fitCRCTable[Int(crc & 0x000F)]
            crc = (crc >> 4) & 0x0FFF
            crc ^= value
            crc ^= fitCRCTable[Int(byte >> 4)]
        }
        return crc
    }
}
