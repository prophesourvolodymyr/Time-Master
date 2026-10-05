#if os(iOS)
import Foundation
import Combine
import CoreLocation

@MainActor
final class OutdoorNearbyRoutes: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: TripCoordinate?
    @Published private(set) var routes: [PlannedRoute] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private var authorizationStatus: CLAuthorizationStatus?
    private var kind: OutdoorActivityKind?
    private var generatedOrigin: TripCoordinate?
    private var generatedKind: OutdoorActivityKind?
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var isRequestingLocation = false
    private lazy var permissionManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
        return manager
    }()

    deinit { task?.cancel() }

    var locationDenied: Bool {
        let status = authorizationStatus ?? permissionManager.authorizationStatus
        return status == .denied || status == .restricted || !CLLocationManager.locationServicesEnabled()
    }

    func requestLocation() {
        errorMessage = nil
        let manager = permissionManager
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            requestAuthorizedLocation(manager)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationStatus = manager.authorizationStatus
            guard kind != nil, location == nil else { return }
            requestAuthorizedLocation(manager)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            isRequestingLocation = false
            guard let coordinate = locations.last?.coordinate else { return }
            updateLocation(TripCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            isRequestingLocation = false
            errorMessage = error.localizedDescription
        }
    }

    private func requestAuthorizedLocation(_ manager: CLLocationManager) {
        guard !isRequestingLocation,
              manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        isRequestingLocation = true
        manager.requestLocation()
    }

    func updateLocation(_ value: TripCoordinate) {
        guard value.isValid else { return }
        if let location, location.distance(to: value) < 25 { return }
        location = value
        guard let kind, generatedOrigin.map({ $0.distance(to: value) >= 500 }) ?? true else { return }
        refresh(kind: kind)
    }

    func activate(kind: OutdoorActivityKind) {
        self.kind = kind
        if location == nil { requestAuthorizedLocation(permissionManager) }
        let moved = location.flatMap { location in generatedOrigin.map { $0.distance(to: location) >= 500 } } ?? false
        guard generatedKind != kind || generatedOrigin == nil || moved else { return }
        refresh(kind: kind)
    }

    func deactivate() {
        kind = nil
        if isRequestingLocation {
            permissionManager.stopUpdatingLocation()
            isRequestingLocation = false
        }
        generation = UUID()
        task?.cancel()
        if isLoading { generatedOrigin = nil }
        isLoading = false
    }

    func refresh(kind: OutdoorActivityKind) {
        self.kind = kind
        generation = UUID()
        task?.cancel()
        routes = []
        errorMessage = nil
        isLoading = false
        guard let location else { return }
        generatedOrigin = location
        generatedKind = kind
        let token = generation
        let distance: Double = kind == .bike ? 20_000 : kind == .walk ? 3_000 : 5_000
        isLoading = true
        task = Task { [weak self] in
            do {
                let candidates = try await OutdoorTripService().suggestions(
                    origin: TripStop(name: "Current location", coordinate: location), kind: kind,
                    distance: distance, stopCount: 0, categories: [], preference: .bikeRoads, runningGoal: .balanced
                )
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.routes = candidates.sorted {
                    let left = Self.score($0, target: distance)
                    let right = Self.score($1, target: distance)
                    return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
                }
                self.isLoading = false
            } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private static func score(_ route: PlannedRoute, target: Double) -> Double {
        guard let trip = route.trip else { return .infinity }
        return abs(trip.activeDistanceMeters - target) / target
            + (trip.majorRoadFraction ?? 1) * 2
            + (trip.unpavedFraction ?? 1)
            + (trip.ascentMeters.map { $0 / max(1, trip.activeDistanceMeters) } ?? 0.1)
    }
}
#endif
