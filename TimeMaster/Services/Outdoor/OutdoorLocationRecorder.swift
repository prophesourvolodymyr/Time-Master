#if os(iOS)
import Foundation
import CoreLocation
import MapLibre
import Combine

final class OutdoorLocationRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requestingAuthorization
        case recording
        case manualPaused
        case autoPaused
        case finished
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var activeActivity: OutdoorActivity?
    @Published private(set) var route: [OutdoorTrackPoint] = []
    @Published private(set) var gpsUnavailable = false
    @Published private(set) var errorMessage: String?
    var audioCuesEnabled = true
    @Published private(set) var plannedPoints: [OutdoorTrackPoint] = []

    private let store: OutdoorActivityStore
    private let kind: OutdoorActivityKind
    private var plannedRoute: PlannedRoute?
    private let locationManager = CLLocationManager()
    private var timeTargetSeconds: Int?
    private var previousLocation: CLLocation?
    private var stationarySince: Date?
    private var stationaryDistance = 0.0
    private var resumeSamples = 0
    private var hasRequestedAuthorization = false

    init(kind: OutdoorActivityKind, store: OutdoorActivityStore, timeTargetSeconds: Int? = nil, plannedRoute: PlannedRoute? = nil) {
        self.kind = kind
        self.store = store
        self.timeTargetSeconds = timeTargetSeconds
        self.plannedRoute = plannedRoute
        if let pr = plannedRoute { plannedPoints = pr.points }
        super.init()
        if let existing = store.active, existing.kind == kind {
            activeActivity = existing
            route = store.activeRoute
            if let pid = existing.plannedRouteID { /* load would be in store resume */ }
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = kind == .bike ? .fitness : .otherNavigation
    }

    func clearError() {
        errorMessage = nil
    }

    func start(timeTargetSeconds: Int? = nil) {
        if let timeTargetSeconds { self.timeTargetSeconds = timeTargetSeconds > 0 ? timeTargetSeconds : nil }
        errorMessage = nil
        guard CLLocationManager.locationServicesEnabled() else {
            fail("Location Services are disabled. Enable them in Settings to record this activity.")
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginRecording()
        case .notDetermined:
            hasRequestedAuthorization = true
            state = .requestingAuthorization
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            fail("TimeMaster needs location access to record. Allow Location While Using the App in Settings.")
        @unknown default:
            fail("TimeMaster could not determine location access.")
        }
    }

    func pauseManually() {
        guard state == .recording else { return }
        do {
            try store.pauseManually()
            state = .manualPaused
            if audioCuesEnabled { AudioManager.shared.speak("Paused") }
        } catch { fail(error.localizedDescription) }
    }

    func resumeManually() {
        guard state == .manualPaused else { return }
        do {
            try store.resumeManually()
            state = .recording
            if audioCuesEnabled { AudioManager.shared.speak("Resumed") }
        } catch { fail(error.localizedDescription) }
    }

    func lap() {
        do {
            try store.lap()
            if audioCuesEnabled { AudioManager.shared.speak("Lap \(store.active?.laps.count ?? 0)") }
        } catch { fail(error.localizedDescription) }
    }

    @discardableResult
    func finish() -> OutdoorActivity? {
        do {
            let finished = try store.finish()
            locationManager.stopUpdatingLocation()
            state = .finished
            activeActivity = finished
            if audioCuesEnabled { AudioManager.shared.speak("Activity saved") }
            return finished
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    func cancel() {
        locationManager.stopUpdatingLocation()
        try? store.discardActive()
        activeActivity = nil
        route = []
        state = .idle
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard hasRequestedAuthorization, state == .requestingAuthorization else { return }
        hasRequestedAuthorization = false
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: beginRecording()
        case .denied, .restricted: fail("Location access was denied. Allow it in Settings and try again.")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            process(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        gpsUnavailable = true
        if state == .requestingAuthorization { fail(error.localizedDescription) }
    }


    private func beginRecording() {
        guard activeActivity == nil else {
            locationManager.startUpdatingLocation()
            state = state == .manualPaused ? .manualPaused : .recording
            return
        }
        do {
            let activity = try store.begin(kind: kind, timeTargetSeconds: timeTargetSeconds, plannedRouteID: plannedRoute?.id.uuidString)
            activeActivity = activity
            route = []
            previousLocation = nil
            stationarySince = nil
            stationaryDistance = 0
            resumeSamples = 0
            gpsUnavailable = false
            state = .recording
            locationManager.startUpdatingLocation()
            AudioManager.shared.activateSession()
            if audioCuesEnabled { AudioManager.shared.speak("Started \(kind.displayName)") }
        } catch { fail(error.localizedDescription) }
    }

    private func process(_ location: CLLocation) {
        guard state == .recording || state == .autoPaused else { return }
        guard location.coordinate.latitude.isFinite, location.coordinate.longitude.isFinite,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100,
              location.timestamp.timeIntervalSince1970 > (previousLocation?.timestamp.timeIntervalSince1970 ?? 0) else { return }
        gpsUnavailable = false
        let incrementalDistance = previousLocation.map { location.distance(from: $0) } ?? 0
        let speed = location.speed >= 0 && location.speed.isFinite ? location.speed : nil
        guard speed.map({ $0 <= 70 }) ?? true else { return }
        let point = OutdoorTrackPoint(timestamp: location.timestamp, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, elevationMeters: location.altitude.isFinite ? location.altitude : nil, horizontalAccuracyMeters: location.horizontalAccuracy, speedMetersPerSecond: speed, state: state == .autoPaused ? .autoPaused : .recording)
        do {
            try store.append(point: point)
            route.append(point)
            activeActivity = store.active
            updatePauseState(date: location.timestamp, speed: speed, movement: incrementalDistance)
            previousLocation = location
            if let pr = plannedRoute, let snap = OutdoorRouteSnapper.snap(location: location, to: pr.points) {
                // future: use snap.coordinate for follow camera via delegate or state
                // publish for UI stats
            }
        } catch { fail(error.localizedDescription) }
    }

    private func updatePauseState(date: Date, speed: CLLocationSpeed?, movement: CLLocationDistance) {
        let stationary = (speed.map { $0 <= 0.8 } ?? false) || movement <= 5
        if state == .recording {
            if stationary {
                stationarySince = stationarySince ?? date
                stationaryDistance += movement
                if let since = stationarySince, date.timeIntervalSince(since) >= 20 {
                    do {
                        try store.pauseAutomatically(at: date)
                        state = .autoPaused
                        resumeSamples = 0
                        if audioCuesEnabled { AudioManager.shared.speak("Auto paused") }
                    } catch { fail(error.localizedDescription) }
                }
            } else {
                stationarySince = nil
                stationaryDistance = 0
            }
        } else if state == .autoPaused {
            if (speed.map { $0 >= 1.2 } ?? false) || movement >= 15 {
                resumeSamples += 1
                if resumeSamples >= 3 {
                    do {
                        try store.resumeAutomatically(at: date)
                        state = .recording
                        stationarySince = nil
                        stationaryDistance = 0
                        resumeSamples = 0
                        if audioCuesEnabled { AudioManager.shared.speak("Resumed") }
                    } catch { fail(error.localizedDescription) }
                }
            } else { resumeSamples = 0 }
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        state = .failed
    }
    // MARK: - Offline (step 2)
    func downloadOfflineRegion(bounds: MLNCoordinateBounds, styleURL: URL, minZoom: Int, maxZoom: Int) {
        OutdoorMapOfflineManager.shared.downloadOfflineRegion(bounds: bounds, styleURL: styleURL, minZoom: minZoom, maxZoom: maxZoom)
    }

    func hasOfflineCoverage(near coordinate: CLLocationCoordinate2D) -> Bool {
        OutdoorMapOfflineManager.shared.hasOfflinePack(near: coordinate)
    }
}
#endif
