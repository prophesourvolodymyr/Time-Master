import Foundation

struct TripServiceConfiguration {
    var routingURL: String
    var searchURL: String
    var placesURL: String

    static var current: TripServiceConfiguration {
        let defaults = UserDefaults.standard
        return Self(
            routingURL: defaults.string(forKey: "outdoor.trip.routingURL") ?? "",
            searchURL: defaults.string(forKey: "outdoor.trip.searchURL") ?? "https://photon.komoot.io",
            placesURL: defaults.string(forKey: "outdoor.trip.placesURL") ?? "https://overpass-api.de/api/interpreter"
        )
    }

    func save() throws {
        _ = try endpoint(routingURL)
        _ = try endpoint(searchURL)
        _ = try endpoint(placesURL)
        let defaults = UserDefaults.standard
        defaults.set(routingURL, forKey: "outdoor.trip.routingURL")
        defaults.set(searchURL, forKey: "outdoor.trip.searchURL")
        defaults.set(placesURL, forKey: "outdoor.trip.placesURL")
    }

    func endpoint(_ string: String) throws -> URL {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else {
            throw TripServiceError.message("Set a secure routing server in Trip Services. Use the included GraphHopper profiles; public demo servers are not a production backend.")
        }
        return url
    }
}

enum TripServiceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct OutdoorTripService {
    var configuration: TripServiceConfiguration = .current
    var session: URLSession = .shared

    func route(_ trip: OutdoorTrip, previous: OutdoorTrip? = nil) async throws -> OutdoorTrip {
        guard trip.stops.count >= 2 else { throw TripServiceError.message("Add a destination first.") }
        let info = try await serverInfo()
        let elevation = info["elevation"] as? Bool ?? false
        if trip.kind != .bike, [.gentle, .hills].contains(trip.runningGoal), !elevation {
            throw TripServiceError.message("This server has no elevation data. Enable elevation on the routing server or choose a different running goal.")
        }
        var result = trip
        result.legs = []
        for index in 1..<trip.stops.count {
            try Task.checkCancellation()
            let destination = trip.stops[index]
            if let previous, previous.isRouted, previous.kind == trip.kind,
               previous.preference == trip.preference, previous.runningGoal == trip.runningGoal,
               let previousIndex = previous.stops.firstIndex(where: { $0.id == destination.id }), previousIndex > 0,
               previous.stops[previousIndex] == destination,
               previous.stops[previousIndex - 1].coordinate == trip.stops[index - 1].coordinate,
               let cached = previous.legs.first(where: { $0.id == destination.id }) {
                result.legs.append(cached)
                continue
            }
            let controls = [trip.stops[index - 1].coordinate] + destination.shapingPoints + [destination.coordinate]
            var body = requestBody(trip: trip, mode: destination.incomingMode, preference: destination.incomingPreference ?? trip.preference, elevation: elevation)
            body["points"] = controls.map { [$0.longitude, $0.latitude] }
            body["pass_through"] = true
            let path = try await requestPath(body)
            result.legs.append(try parseLeg(path, id: destination.id, mode: destination.incomingMode, controls: controls, elevation: elevation))
        }
        result.routedAt = Date()
        result.routingFingerprint = result.fingerprint
        return result
    }

    func search(_ query: String, near coordinate: TripCoordinate?) async throws -> [TripPlace] {
        let base = try configuration.endpoint(configuration.searchURL).appendingPathComponent("api")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "8")]
        if let coordinate {
            components.queryItems?.append(contentsOf: [URLQueryItem(name: "lat", value: String(coordinate.latitude)), URLQueryItem(name: "lon", value: String(coordinate.longitude))])
        }
        let json = try await request(URLRequest(url: components.url!))
        return (json["features"] as? [[String: Any]] ?? []).compactMap { feature in
            guard let properties = feature["properties"] as? [String: Any], let geometry = feature["geometry"] as? [String: Any], let pair = geometry["coordinates"] as? [Double], pair.count >= 2 else { return nil }
            let coordinate = TripCoordinate(latitude: pair[1], longitude: pair[0])
            guard coordinate.isValid else { return nil }
            let detail = ["street", "city", "state", "country"].compactMap { properties[$0] as? String }.joined(separator: ", ")
            return TripPlace(id: "\(properties["osm_type"] ?? "")-\(properties["osm_id"] ?? "")-\(pair)", name: properties["name"] as? String ?? properties["street"] as? String ?? "Map place", detail: detail, coordinate: coordinate)
        }
    }

    func places(near origin: TripCoordinate, radius: Double, categories: Set<TripPlaceCategory>) async throws -> [TripPlace] {
        guard !categories.isEmpty else { return [] }
        let clauses = categories.sorted { $0.rawValue < $1.rawValue }.map {
            "nwr\($0.osmFilter)(around:\(Int(min(30_000, max(500, radius)))),\(origin.latitude),\(origin.longitude));"
        }.joined()
        let query = "[out:json][timeout:20];(\(clauses));out center 120;"
        var request = URLRequest(url: try configuration.endpoint(configuration.placesURL))
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(query.utf8)
        let json = try await self.request(request)
        return (json["elements"] as? [[String: Any]] ?? []).compactMap { element in
            let center = element["center"] as? [String: Any] ?? element
            guard let lat = center["lat"] as? Double, let lon = center["lon"] as? Double else { return nil }
            let tags = element["tags"] as? [String: String] ?? [:]
            let coordinate = TripCoordinate(latitude: lat, longitude: lon)
            guard coordinate.isValid else { return nil }
            return TripPlace(id: "\(element["type"] ?? "")-\(element["id"] ?? "")", name: tags["name"] ?? tags["amenity"]?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Park or viewpoint", detail: tags["description"] ?? "OpenStreetMap place", coordinate: coordinate)
        }
    }

    func suggestions(origin: TripStop, kind: OutdoorActivityKind, distance: Double, stopCount: Int, categories: Set<TripPlaceCategory>, preference: TripRoutingPreference, runningGoal: TripRunningGoal) async throws -> [PlannedRoute] {
        guard (1_000...200_000).contains(distance), (0...8).contains(stopCount) else {
            throw TripServiceError.message("Choose 1–200 km and up to eight places.")
        }
        let info = try await serverInfo()
        let elevation = info["elevation"] as? Bool ?? false
        var base = OutdoorTrip(kind: kind, preference: preference, runningGoal: runningGoal, stops: [origin])
        if kind != .bike, [.gentle, .hills].contains(runningGoal), !elevation {
            throw TripServiceError.message("Elevation data is required for that running goal.")
        }
        let candidates = stopCount > 0 ? try await places(near: origin.coordinate, radius: distance / 3, categories: categories) : []
        guard stopCount == 0 || candidates.count >= stopCount else {
            throw TripServiceError.message("Not enough mapped places of these categories nearby. Widen the distance, select more categories, or request fewer stops.")
        }
        var results: [PlannedRoute] = []
        var lastError: Error?
        for seed in 0..<6 {
            try Task.checkCancellation()
            do {
                var trip: OutdoorTrip
                if stopCount == 0 {
                    var body = requestBody(trip: base, mode: .active, preference: preference, elevation: elevation)
                    body["points"] = [[origin.coordinate.longitude, origin.coordinate.latitude]]
                    body["algorithm"] = "round_trip"
                    body["round_trip.distance"] = distance
                    body["round_trip.seed"] = seed
                    let path = try await requestPath(body)
                    let endpoint = TripStop(name: "Return to \(origin.name)", coordinate: origin.coordinate)
                    let leg = try parseLeg(path, id: endpoint.id, mode: .active, controls: [], elevation: elevation)
                    guard leg.coordinates.count > 4 else { continue }
                    var finish = endpoint
                    finish.shapingPoints = [0.25, 0.5, 0.75].map { leg.coordinates[min(leg.coordinates.count - 1, Int(Double(leg.coordinates.count - 1) * $0))] }
                    base.stops = [origin, finish]
                    trip = try await route(base)
                } else {
                    let ordered = candidates.sorted {
                        let angle0 = atan2($0.coordinate.latitude - origin.coordinate.latitude, $0.coordinate.longitude - origin.coordinate.longitude)
                        let angle1 = atan2($1.coordinate.latitude - origin.coordinate.latitude, $1.coordinate.longitude - origin.coordinate.longitude)
                        return angle0 < angle1
                    }
                    let selected = (0..<stopCount).map { ordered[($0 * ordered.count / stopCount + seed * max(1, ordered.count / 6)) % ordered.count] }
                    base.stops = [origin] + selected.map { TripStop(name: $0.name, coordinate: $0.coordinate) } + [TripStop(name: "Return to \(origin.name)", coordinate: origin.coordinate)]
                    trip = try await route(base)
                }
                guard abs(trip.totalDistanceMeters - distance) <= max(1_000, distance * 0.25) else { continue }
                guard !results.contains(where: { route in
                    guard let existing = route.trip else { return false }
                    return abs(existing.totalDistanceMeters - trip.totalDistanceMeters) < 100 && existing.stops.map(\.coordinate) == trip.stops.map(\.coordinate)
                }) else { continue }
                var route = PlannedRoute(title: "\(trip.effortTitle) \(kind.displayName.lowercased()) loop", points: trip.points)
                route.trip = trip
                results.append(route)
                if results.count == 3 { break }
            } catch is CancellationError { throw CancellationError() }
            catch { lastError = error }
        }
        guard !results.isEmpty else {
            if let lastError { throw lastError }
            throw TripServiceError.message("No connected route matched this distance within 25% (or 1 km for short trips). Try fewer places or a different distance.")
        }
        return results.sorted { ($0.trip?.effortScore ?? 0) < ($1.trip?.effortScore ?? 0) }
    }

    private func serverInfo() async throws -> [String: Any] {
        try await request(URLRequest(url: configuration.endpoint(configuration.routingURL).appendingPathComponent("info")))
    }

    private func requestBody(trip: OutdoorTrip, mode: TripLegMode, preference: TripRoutingPreference, elevation: Bool) -> [String: Any] {
        var body: [String: Any] = ["profile": mode == .bus ? "bus" : preference.profile(for: trip.kind), "points_encoded": false, "elevation": elevation, "instructions": true, "details": ["surface", "road_class"], "ch.disable": true, "locale": "en", "timeout_ms": 12_000, "snap_preventions": mode == .bus ? [] : ["motorway", "trunk", "ferry"]]
        if mode == .active, trip.kind != .bike, trip.runningGoal != .balanced {
            let condition: String
            switch trip.runningGoal {
            case .paved: condition = "surface != ASPHALT && surface != PAVED && surface != CONCRETE"
            case .gentle: condition = "max_slope > 6 || max_slope < -6"
            case .hills: condition = "max_slope > -3 && max_slope < 3"
            case .balanced: condition = "false"
            }
            body["custom_model"] = ["priority": [["if": condition, "multiply_by": "0.4"]]]
        }
        return body
    }

    private func requestPath(_ body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: try configuration.endpoint(configuration.routingURL).appendingPathComponent("route"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await self.request(request)
        guard let path = (json["paths"] as? [[String: Any]])?.first else { throw TripServiceError.message("The routing service returned no usable route.") }
        return path
    }

    private func parseLeg(_ path: [String: Any], id: UUID, mode: TripLegMode, controls: [TripCoordinate], elevation: Bool) throws -> TripRouteLeg {
        guard let geometry = path["points"] as? [String: Any], let pairs = geometry["coordinates"] as? [[Double]], pairs.count >= 2,
              let distance = path["distance"] as? Double, distance.isFinite, distance >= 0,
              let time = path["time"] as? Double, time.isFinite, time >= 0 else {
            throw TripServiceError.message("The routing service returned invalid geometry.")
        }
        let coordinates = pairs.compactMap { pair -> TripCoordinate? in
            guard pair.count >= 2 else { return nil }
            return TripCoordinate(latitude: pair[1], longitude: pair[0])
        }
        guard coordinates.count == pairs.count, coordinates.allSatisfy(\.isValid) else { throw TripServiceError.message("Invalid route coordinates.") }
        let snapped = (path["snapped_waypoints"] as? [String: Any])?["coordinates"] as? [[Double]] ?? []
        if !controls.isEmpty {
            guard snapped.count == controls.count, zip(controls, snapped).allSatisfy({ coordinate, pair in
                pair.count >= 2 && coordinate.distance(to: TripCoordinate(latitude: pair[1], longitude: pair[0])) <= 300
            }) else { throw TripServiceError.message("A stop is more than 300 m from an accessible road. Move it closer to a reachable street or path.") }
        }
        var lowerBound = 0
        let indices = snapped.compactMap { pair -> Int? in
            guard pair.count >= 2 else { return nil }
            let target = TripCoordinate(latitude: pair[1], longitude: pair[0])
            let index = (lowerBound..<coordinates.count).min { coordinates[$0].distance(to: target) < coordinates[$1].distance(to: target) } ?? lowerBound
            lowerBound = index
            return index
        }
        let details = path["details"] as? [String: Any] ?? [:]
        func fraction(_ key: String, matching values: Set<String>) -> Double? {
            guard let rows = details[key] as? [[Any]], !rows.isEmpty else { return nil }
            var matching = 0.0
            var covered = 0.0
            for row in rows {
                guard row.count == 3, let from = row[0] as? Int, let to = row[1] as? Int, let value = row[2] as? String, value != "missing", value != "other", from >= 0, to < coordinates.count, from < to else { return nil }
                let length = (from..<to).reduce(0.0) { $0 + coordinates[$1].distance(to: coordinates[$1 + 1]) }
                covered += length
                if values.contains(value.lowercased()) { matching += length }
            }
            return covered > 0 ? matching / covered : nil
        }
        return TripRouteLeg(id: id, mode: mode, coordinates: coordinates, controlPointIndices: indices, distanceMeters: distance, durationSeconds: time / 1_000, ascentMeters: elevation ? path["ascend"] as? Double : nil, unpavedFraction: fraction("surface", matching: ["unpaved", "gravel", "ground", "dirt", "grass", "sand", "wood", "fine_gravel", "compacted"]), majorRoadFraction: fraction("road_class", matching: ["motorway", "trunk", "primary", "secondary", "tertiary"]), instructions: (path["instructions"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String })
    }

    private func request(_ input: URLRequest) async throws -> [String: Any] {
        try Task.checkCancellation()
        var request = input
        request.timeoutInterval = 30
        request.setValue("TimeMaster/1.0 (https://github.com/prophesourvolodymyr/Time-Master)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw TripServiceError.message("No response from the trip service.") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 429 { throw TripServiceError.message("The trip service is busy. Wait a moment before trying again.") }
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw TripServiceError.message(message ?? "Trip service failed (HTTP \(http.statusCode)). Your stops and last route are preserved.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TripServiceError.message("Invalid trip service response.") }
        return json
    }
}
