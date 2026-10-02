import Foundation

struct TripCoordinate: Codable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    func trackPoint(at date: Date = Date(timeIntervalSince1970: 0)) -> OutdoorTrackPoint {
        OutdoorTrackPoint(timestamp: date, latitude: latitude, longitude: longitude, horizontalAccuracyMeters: 0, state: .recording)
    }

    func distance(to other: TripCoordinate) -> Double {
        OutdoorMetricsCalculator.distanceMeters(from: trackPoint(), to: other.trackPoint())
    }
}

enum TripRoutingPreference: String, Codable, CaseIterable, Identifiable {
    case bikeRoads, mixed, fastest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bikeRoads: return "Bike Roads Preferred"
        case .mixed: return "Mixed"
        case .fastest: return "Fastest"
        }
    }
    func title(for kind: OutdoorActivityKind) -> String {
        kind == .bike ? title : (self == .bikeRoads ? "Paths Preferred" : self == .fastest ? "Direct" : "Mixed")
    }
}

enum TripLegMode: String, Codable, CaseIterable, Identifiable {
    case active, bus
    var id: String { rawValue }
}

enum TripRunningGoal: String, Codable, CaseIterable, Identifiable {
    case balanced, paved, gentle, hills
    var id: String { rawValue }
    var title: String {
        switch self {
        case .balanced: return "Balanced"
        case .paved: return "Paved & steady"
        case .gentle: return "Gentle terrain"
        case .hills: return "Hill training"
        }
    }
}

struct TripStop: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var coordinate: TripCoordinate
    var incomingMode: TripLegMode = .active
    var incomingPreference: TripRoutingPreference?
    var shapingPoints: [TripCoordinate] = []
}

struct TripRouteLeg: Identifiable, Codable, Equatable {
    var id: UUID
    var mode: TripLegMode
    var coordinates: [TripCoordinate]
    var controlPointIndices: [Int]
    var distanceMeters: Double
    var durationSeconds: Double
    var ascentMeters: Double?
    var unpavedFraction: Double?
    var majorRoadFraction: Double?
    var instructions: [String]
}

struct OutdoorTrip: Codable, Equatable {
    var version = 1
    var kind: OutdoorActivityKind = .bike
    var preference: TripRoutingPreference = .bikeRoads
    var runningGoal: TripRunningGoal = .balanced
    var isDraft = true
    var stops: [TripStop] = []
    var legs: [TripRouteLeg] = []
    var updatedAt = Date()
    var routedAt: Date?
    var routingFingerprint: String?
    var routingDataID: String?

    var fingerprint: String {
        ([kind.rawValue, preference.rawValue, runningGoal.rawValue] + stops.map {
            "\($0.id):\($0.coordinate.latitude),\($0.coordinate.longitude):\($0.incomingMode.rawValue):\($0.incomingPreference?.rawValue ?? "default"):" + $0.shapingPoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
        }).joined(separator: "|")
    }
    var isRouted: Bool { stops.count >= 2 && legs.count == stops.count - 1 && routingFingerprint == fingerprint }
    var activeDistanceMeters: Double { legs.lazy.filter { $0.mode == .active }.reduce(0) { $0 + $1.distanceMeters } }
    var totalDistanceMeters: Double { legs.reduce(0) { $0 + $1.distanceMeters } }
    var durationSeconds: Double { legs.reduce(0) { $0 + $1.durationSeconds } }
    var activeDurationSeconds: Double { legs.lazy.filter { $0.mode == .active }.reduce(0) { $0 + $1.durationSeconds } }
    var unpavedFraction: Double? { weightedFraction(\.unpavedFraction) }
    var majorRoadFraction: Double? { weightedFraction(\.majorRoadFraction) }

    private func weightedFraction(_ keyPath: KeyPath<TripRouteLeg, Double?>) -> Double? {
        var distance = 0.0
        var weighted = 0.0
        for leg in legs where leg.mode == .active {
            guard let fraction = leg[keyPath: keyPath] else { return nil }
            distance += leg.distanceMeters
            weighted += fraction * leg.distanceMeters
        }
        return distance > 0 ? weighted / distance : nil
    }
    var hasBus: Bool { stops.dropFirst().contains { $0.incomingMode == .bus } }
    var ascentMeters: Double? {
        let active = legs.lazy.filter { $0.mode == .active }
        guard !active.isEmpty, active.allSatisfy({ $0.ascentMeters != nil }) else { return nil }
        return active.reduce(0) { $0 + ($1.ascentMeters ?? 0) }
    }
    var effortScore: Double {
        activeDistanceMeters / (kind == .bike ? 20_000 : 5_000) + (ascentMeters ?? 0) / (kind == .bike ? 300 : 150)
    }
    var effortTitle: String { ascentMeters == nil ? "Effort unknown" : effortScore < 1 ? "Easy" : effortScore < 2.5 ? "Moderate" : "Demanding" }
    var points: [OutdoorTrackPoint] {
        var result: [OutdoorTrackPoint] = []
        result.reserveCapacity(legs.reduce(0) { $0 + $1.coordinates.count })
        for leg in legs {
            for coordinate in leg.coordinates {
                result.append(coordinate.trackPoint(at: Date(timeIntervalSince1970: Double(result.count))))
            }
        }
        return result
    }
}

enum TripPlaceCategory: String, CaseIterable, Identifiable {
    case parks, cafes, water, viewpoints
    var id: String { rawValue }
    var title: String {
        switch self {
        case .parks: return "Parks"
        case .cafes: return "Cafés"
        case .water: return "Drinking water"
        case .viewpoints: return "Viewpoints"
        }
    }
}

struct TripPlace: Identifiable, Equatable {
    var id: String
    var name: String
    var detail: String
    var coordinate: TripCoordinate
}
