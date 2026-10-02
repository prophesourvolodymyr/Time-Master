import Foundation

enum RouteSource: String, Codable, Equatable {
    case gpxImport
    case manual
    case databasePage
}

struct PlannedRoute: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var points: [OutdoorTrackPoint]
    var source: RouteSource
    var createdAt: Date
    var trip: OutdoorTrip?
    var starred = false
    var isDraft: Bool { trip?.isDraft ?? false }

    init(id: UUID = UUID(), title: String, points: [OutdoorTrackPoint], source: RouteSource = .manual, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.points = points
        self.source = source
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, points, source, createdAt, trip, starred
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        points = try values.decode([OutdoorTrackPoint].self, forKey: .points)
        source = try values.decode(RouteSource.self, forKey: .source)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        trip = try values.decodeIfPresent(OutdoorTrip.self, forKey: .trip)
        starred = try values.decodeIfPresent(Bool.self, forKey: .starred) ?? false
    }

    var distanceMeters: Double {
        if let trip { return trip.activeDistanceMeters }
        guard points.count > 1 else { return 0 }
        var distance = 0.0
        for index in 1..<points.count {
            distance += OutdoorMetricsCalculator.distanceMeters(from: points[index - 1], to: points[index])
        }
        return distance
    }
}
