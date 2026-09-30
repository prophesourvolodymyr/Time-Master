#if os(iOS)
import Foundation
import TimeMasterRouting

enum TripServiceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct OutdoorTripService {
    private let packs = OutdoorOfflineTripPacks.shared

    func route(_ trip: OutdoorTrip, previous: OutdoorTrip? = nil) async throws -> OutdoorTrip {
        try await cancellable { cancellation in
            guard trip.stops.count >= 2 else { throw TripServiceError.message("Add a destination first.") }
            let region = try await packs.region(covering: trip.stops.flatMap { [$0.coordinate] + $0.shapingPoints })
            if trip.kind != .bike, [.gentle, .hills].contains(trip.runningGoal), !region.manifest.hasElevation {
                throw TripServiceError.message("This area has no elevation data. Install an elevation-enabled area or choose Balanced or Paved & steady.")
            }
            var result = trip
            result.legs = []
            for index in 1..<trip.stops.count {
                try Task.checkCancellation()
                let destination = trip.stops[index]
                if let previous, previous.isRouted, previous.routingDataID == region.dataID,
                   previous.kind == trip.kind, previous.preference == trip.preference, previous.runningGoal == trip.runningGoal,
                   let previousIndex = previous.stops.firstIndex(where: { $0.id == destination.id }), previousIndex > 0,
                   previous.stops[previousIndex].coordinate == destination.coordinate,
                   previous.stops[previousIndex].shapingPoints == destination.shapingPoints,
                   previous.stops[previousIndex].incomingMode == destination.incomingMode,
                   previous.stops[previousIndex].incomingPreference == destination.incomingPreference,
                   previous.stops[previousIndex - 1].coordinate == trip.stops[index - 1].coordinate,
                   let cached = previous.legs.first(where: { $0.id == destination.id }) {
                    result.legs.append(cached)
                    continue
                }
                let controls = [trip.stops[index - 1].coordinate] + destination.shapingPoints + [destination.coordinate]
                let body = request(trip: trip, destination: destination, controls: controls, elevation: region.manifest.hasElevation)
                let data = try await packs.nativeRoute(body, region: region, cancellation: cancellation)
                guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw TripServiceError.message("The offline engine returned an unreadable route.")
                }
                if let error = response["error"] as? String { throw TripServiceError.message(error) }
                let edges = try edgeDetails(response["tm_edges"])
                let wayIDs = Set(edges.compactMap { edge -> Int64? in
                    guard edge.count >= 3, edge[0].isFinite, edge[0] >= 0, edge[0] < Double(Int64.max) else { return nil }
                    return Int64(edge[0])
                })
                let surfaces = try await packs.surfaces(region: region, wayIDs: wayIDs)
                result.legs.append(try parse(response, id: destination.id, mode: destination.incomingMode, controls: controls, edges: edges, surfaces: surfaces, elevation: region.manifest.hasElevation))
            }
            result.routedAt = Date()
            result.routingFingerprint = result.fingerprint
            result.routingDataID = region.dataID
            return result
        }
    }

    func search(_ query: String, near coordinate: TripCoordinate?) async throws -> [TripPlace] {
        try await cancellable { cancellation in try await packs.search(query, near: coordinate, cancellation: cancellation) }
    }

    func places(near origin: TripCoordinate, radius: Double, categories: Set<TripPlaceCategory>) async throws -> [TripPlace] {
        let region = try await packs.region(covering: [origin])
        return try await packs.places(region: region, near: origin, radius: min(70_000, max(500, radius)), categories: categories)
    }

    func suggestions(origin: TripStop, kind: OutdoorActivityKind, distance: Double, stopCount: Int, categories: Set<TripPlaceCategory>, preference: TripRoutingPreference, runningGoal: TripRunningGoal) async throws -> [PlannedRoute] {
        guard (1_000...200_000).contains(distance), (0...8).contains(stopCount) else { throw TripServiceError.message("Choose 1–200 km and up to eight places.") }
        let region = try await packs.region(covering: [origin.coordinate])
        let candidates = stopCount > 0 ? try await packs.places(region: region, near: origin.coordinate, radius: distance / 3, categories: categories) : []
        guard stopCount == 0 || candidates.count >= stopCount else {
            throw TripServiceError.message("Not enough mapped places of these categories nearby. Select more categories, change the distance, or request fewer stops.")
        }
        let ordered = candidates.sorted {
            bearing(from: origin.coordinate, to: $0.coordinate) < bearing(from: origin.coordinate, to: $1.coordinate)
        }
        var results: [PlannedRoute] = []
        var lastError: Error?
        var usedSelections = Set<String>()
        for seed in 0..<12 {
            try Task.checkCancellation()
            do {
                var trip = OutdoorTrip(kind: kind, preference: preference, runningGoal: runningGoal, stops: [origin])
                var finish = TripStop(name: "Return to \(origin.name)", coordinate: origin.coordinate)
                if stopCount == 0 {
                    let radius = distance / (seed < 6 ? 6.6 : 5.7)
                    for offset in 0..<3 {
                        let target = project(origin.coordinate, meters: radius, bearing: Double(seed % 6) * .pi / 3 + Double(offset) * 2 * .pi / 3)
                        guard region.manifest.bounds.contains(target),
                              let anchor = try await packs.anchor(region: region, near: target, kind: kind, radius: min(2_000, max(200, radius * 0.5))) else {
                            throw TripServiceError.message("A loop at this distance extends beyond reachable roads in the installed area.")
                        }
                        finish.shapingPoints.append(anchor)
                    }
                    trip.stops.append(finish)
                } else {
                    let selected = (0..<stopCount).map { ordered[($0 * ordered.count / stopCount + seed * max(1, ordered.count / 12)) % ordered.count] }
                    let identity = selected.map(\.id).sorted().joined(separator: "|")
                    guard usedSelections.insert(identity).inserted else { continue }
                    trip.stops += selected.map { TripStop(name: $0.name, coordinate: $0.coordinate) } + [finish]
                }
                trip = try await route(trip)
                guard abs(trip.totalDistanceMeters - distance) <= max(1_000, distance * 0.25) else { continue }
                guard trip.totalDistanceMeters >= 500 else { continue }
                guard !results.contains(where: { existing in
                    guard let previous = existing.trip else { return false }
                    return abs(previous.totalDistanceMeters - trip.totalDistanceMeters) < 100 &&
                        previous.stops.flatMap { [$0.coordinate] + $0.shapingPoints } == trip.stops.flatMap { [$0.coordinate] + $0.shapingPoints }
                }) else { continue }
                var planned = PlannedRoute(title: "\(trip.effortTitle) \(kind.displayName.lowercased()) loop", points: trip.points)
                planned.trip = trip
                results.append(planned)
                if results.count == 3 { break }
            } catch is CancellationError { throw CancellationError() }
            catch { lastError = error }
        }
        guard !results.isEmpty else {
            if let lastError { throw lastError }
            throw TripServiceError.message("No connected offline route matched this distance within 25% (or 1 km for short trips). Try fewer places or a different distance.")
        }
        return results.sorted { left, right in
            guard let first = left.trip, let second = right.trip else { return left.trip != nil }
            switch runningGoal {
            case .hills:
                return (first.ascentMeters ?? 0) > (second.ascentMeters ?? 0)
            case .gentle:
                return (first.ascentMeters ?? .greatestFiniteMagnitude) < (second.ascentMeters ?? .greatestFiniteMagnitude)
            case .balanced, .paved:
                return abs(first.totalDistanceMeters - distance) < abs(second.totalDistanceMeters - distance)
            }
        }
    }

    private func request(trip: OutdoorTrip, destination: TripStop, controls: [TripCoordinate], elevation: Bool) -> [String: Any] {
        let preference = destination.incomingPreference ?? trip.preference
        let costing = destination.incomingMode == .bus ? "bus" : trip.kind == .bike ? "bicycle" : "pedestrian"
        var options: [String: Any] = ["exclude_ferries": destination.incomingMode != .bus]
        if costing == "bicycle" {
            options["bicycle_type"] = "Hybrid"
            options["cycling_speed"] = 18
            options["use_roads"] = preference == .bikeRoads ? 0.05 : preference == .mixed ? 0.5 : 1.0
            options["avoid_bad_surfaces"] = 0.25
        } else if costing == "pedestrian" {
            options["walking_speed"] = trip.kind == .run ? 10 : 5
            options["walkway_factor"] = preference == .bikeRoads ? 0.55 : preference == .mixed ? 0.9 : 1.0
            options["use_hills"] = trip.runningGoal == .gentle ? 0.0 : trip.runningGoal == .hills ? 1.0 : 0.5
            options["timemaster_terrain_goal"] = TripRunningGoal.allCases.firstIndex(of: trip.runningGoal) ?? 0
        }
        return [
            "locations": controls.enumerated().map { index, point -> [String: Any] in
                ["lat": point.latitude, "lon": point.longitude,
                 "type": index == 0 || index == controls.count - 1 ? "break" : "break_through",
                 "radius": 300, "search_cutoff": 300]
            },
            "costing": costing, "costing_options": [costing: options],
            "directions_options": ["units": "kilometers", "language": "en"],
            "elevation_interval": elevation ? 25 : 0
        ]
    }
    private func edgeDetails(_ value: Any?) throws -> [[Double]] {
        guard let groups = value as? [Any] else {
            throw TripServiceError.message("The offline engine returned incomplete road details.")
        }
        var result: [[Double]] = []
        for group in groups {
            guard let rows = group as? [Any] else {
                throw TripServiceError.message("The offline engine returned invalid road details.")
            }
            for row in rows {
                guard let values = row as? [Any], values.count == 3 else {
                    throw TripServiceError.message("The offline engine returned invalid road details.")
                }
                let numbers = values.compactMap { ($0 as? NSNumber)?.doubleValue }
                guard numbers.count == 3, numbers.allSatisfy(\.isFinite) else {
                    throw TripServiceError.message("The offline engine returned invalid road details.")
                }
                result.append(numbers)
            }
        }
        guard !result.isEmpty else {
            throw TripServiceError.message("The offline engine returned no road details.")
        }
        return result
    }

    private func parse(_ response: [String: Any], id: UUID, mode: TripLegMode, controls: [TripCoordinate], edges: [[Double]], surfaces: [Int64: Bool], elevation: Bool) throws -> TripRouteLeg {
        guard let trip = response["trip"] as? [String: Any], let legs = trip["legs"] as? [[String: Any]], legs.count == controls.count - 1 else {
            throw TripServiceError.message("The offline engine did not connect every route adjustment.")
        }
        var coordinates: [TripCoordinate] = []
        var indices = [0]
        var distance = 0.0
        var duration = 0.0
        var ascent = 0.0
        var elevationComplete = elevation
        var instructions: [String] = []
        for (index, leg) in legs.enumerated() {
            guard let shape = leg["shape"] as? String, let summary = leg["summary"] as? [String: Any],
                  let length = summary["length"] as? Double, length.isFinite, length >= 0,
                  let time = summary["time"] as? Double, time.isFinite, time >= 0 else {
                throw TripServiceError.message("The offline engine returned incomplete route geometry.")
            }
            let points = try decodePolyline(shape)
            guard points.count >= 2, controls[index].distance(to: points[0]) <= 300,
                  controls[index + 1].distance(to: points[points.count - 1]) <= 300 else {
                throw TripServiceError.message("A stop is more than 300 m from an accessible road. Move it closer to a reachable street or path.")
            }
            if let last = coordinates.last {
                guard last.distance(to: points[0]) < 3 else { throw TripServiceError.message("The offline route contains a disconnected adjustment.") }
                coordinates.append(contentsOf: points.dropFirst())
            } else { coordinates = points }
            indices.append(coordinates.count - 1)
            distance += length * 1_000
            duration += time
            if let heights = leg["elevation"] as? [Double], heights.count >= 2, heights.allSatisfy({ $0.isFinite && $0 != -32768 }) {
                ascent += zip(heights, heights.dropFirst()).reduce(0) { $0 + max(0, $1.1 - $1.0) }
            } else { elevationComplete = false }
            for maneuver in leg["maneuvers"] as? [[String: Any]] ?? [] {
                let type = maneuver["type"] as? Int ?? 0
                if index > 0 && (1...3).contains(type) { continue }
                if index < legs.count - 1 && (4...6).contains(type) { continue }
                if let instruction = maneuver["instruction"] as? String, !instruction.isEmpty { instructions.append(instruction) }
            }
        }
        var edgeDistance = 0.0
        var unpaved = 0.0
        var major = 0.0
        var surfaceComplete = !edges.isEmpty
        for edge in edges {
            guard edge.count >= 3, edge[0].isFinite, edge[0] >= 0, edge[0] < Double(Int64.max), edge[1].isFinite, edge[1] >= 0 else {
                throw TripServiceError.message("The offline engine returned invalid road details.")
            }
            edgeDistance += edge[1]
            if (0...4).contains(edge[2]) { major += edge[1] }
            if let value = surfaces[Int64(edge[0])] { if value { unpaved += edge[1] } }
            else { surfaceComplete = false }
        }
        return TripRouteLeg(id: id, mode: mode, coordinates: coordinates, controlPointIndices: indices, distanceMeters: distance,
                            durationSeconds: duration, ascentMeters: elevationComplete ? ascent : nil,
                            unpavedFraction: surfaceComplete && edgeDistance > 0 ? unpaved / edgeDistance : nil,
                            majorRoadFraction: edgeDistance > 0 ? major / edgeDistance : nil, instructions: instructions)
    }

    private func decodePolyline(_ encoded: String) throws -> [TripCoordinate] {
        var iterator = encoded.utf8.makeIterator()
        func component(_ first: UInt8) throws -> Int64 {
            var current = first
            var value: UInt64 = 0
            var shift = 0
            while true {
                guard (63...126).contains(current), shift <= 30 else { throw TripServiceError.message("The offline route shape is damaged.") }
                let byte = current - 63
                value |= UInt64(byte & 31) << shift
                if byte < 32 { return Int64(value >> 1) ^ -Int64(value & 1) }
                guard let next = iterator.next() else { throw TripServiceError.message("The offline route shape is truncated.") }
                current = next
                shift += 5
            }
        }
        var latitude: Int64 = 0
        var longitude: Int64 = 0
        var points: [TripCoordinate] = []
        points.reserveCapacity(encoded.utf8.count / 6)
        while let first = iterator.next() {
            latitude += try component(first)
            guard let second = iterator.next() else { throw TripServiceError.message("The offline route shape is truncated.") }
            longitude += try component(second)
            let point = TripCoordinate(latitude: Double(latitude) / 1_000_000, longitude: Double(longitude) / 1_000_000)
            guard point.isValid else { throw TripServiceError.message("The offline route contains invalid coordinates.") }
            points.append(point)
        }
        return points
    }

    private func project(_ point: TripCoordinate, meters: Double, bearing: Double) -> TripCoordinate {
        let angular = meters / 6_371_000
        let latitude = point.latitude * .pi / 180
        let longitude = point.longitude * .pi / 180
        let targetLatitude = asin(sin(latitude) * cos(angular) + cos(latitude) * sin(angular) * cos(bearing))
        let targetLongitude = longitude + atan2(sin(bearing) * sin(angular) * cos(latitude), cos(angular) - sin(latitude) * sin(targetLatitude))
        return TripCoordinate(latitude: targetLatitude * 180 / .pi, longitude: (targetLongitude * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
    private func bearing(from origin: TripCoordinate, to point: TripCoordinate) -> Double {
        atan2((point.longitude - origin.longitude) * cos(origin.latitude * .pi / 180), point.latitude - origin.latitude)
    }
    private func cancellable<T>(_ operation: (TMRoutingCancellation) async throws -> T) async throws -> T {
        let cancellation = TMRoutingCancellation()
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let result = try await operation(cancellation)
                try Task.checkCancellation()
                return result
            } catch {
                if cancellation.cancelled || Task.isCancelled { throw CancellationError() }
                throw error
            }
        } onCancel: { cancellation.cancel() }
    }
}
#endif
