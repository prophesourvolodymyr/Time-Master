#if os(iOS)
import Foundation
import CoreLocation
import MapLibre
import Combine
import TimeMasterCore
import UIKit

@MainActor
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

    enum FinishOutcome {
        case shortSessionDiscarded(distanceMeters: Double)
        case finished(OutdoorActivity)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var activeActivity: OutdoorActivity?
    @Published private(set) var route: [OutdoorTrackPoint] = []
    @Published private(set) var gpsUnavailable = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var liveSpeedMetersPerSecond: Double?
    @Published private(set) var smoothedLiveSpeedMetersPerSecond: Double?
    @Published private(set) var plannedPoints: [OutdoorTrackPoint] = []
    @Published private(set) var snappedPosition: SnappedPosition?

    var audioCuesEnabled = true
    private(set) var kind: OutdoorActivityKind

    private let store: OutdoorActivityStore
    private weak var preferenceStore: OutdoorRecordingPreferencesStore?
    private var preferences: OutdoorRecordingPreferences
    private var plannedRoute: PlannedRoute?
    private let locationManager = CLLocationManager()
    private let elevationProcessor: OutdoorElevationProcessor
    private var timeTargetSeconds: Int?
    private var previousAcceptedLocation: CLLocation?
    private var lastObservedLocation: CLLocation?
    private var stationarySince: Date?
    private var resumeSamples = 0
    private var elevationBaseGainMeters = 0.0
    private var hasRequestedAutomaticOfflineArea = false
    private var hasRequestedAuthorization = false
    private var isStarted = false
    private var gpsHealthMonitor: AnyCancellable?

    init(
        kind: OutdoorActivityKind,
        store: OutdoorActivityStore,
        timeTargetSeconds: Int? = nil,
        plannedRoute: PlannedRoute? = nil,
        preferencesStore: OutdoorRecordingPreferencesStore? = nil
    ) {
        self.kind = kind
        self.store = store
        self.timeTargetSeconds = timeTargetSeconds
        self.plannedRoute = plannedRoute
        self.preferenceStore = preferencesStore
        self.preferences = preferencesStore?.preferences ?? OutdoorRecordingPreferences()
        self.elevationProcessor = OutdoorElevationProcessor(source: self.preferences.elevationSource)
        if let pr = plannedRoute { plannedPoints = pr.points }
        super.init()
        if let existing = store.active,
           existing.kind == kind || (existing.kind == .runWalk && kind == .run) {
            activeActivity = existing
            route = store.activeRoute
            let recoveredRoute = store.recordedPlan(for: existing)
            self.plannedRoute = recoveredRoute
            plannedPoints = recoveredRoute?.points ?? []
            state = Self.state(for: existing.recordingState)
            isStarted = true
            previousAcceptedLocation = route.last.map(Self.location(from:))
            lastObservedLocation = previousAcceptedLocation
            elevationBaseGainMeters = existing.elevationGainMeters ?? 0
        }
        locationManager.delegate = self
        configureLocationManager()
        gpsHealthMonitor = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshGPSHealth() }
    }

    convenience init(
        kind: OutdoorActivityKind,
        store: OutdoorActivityStore,
        preferences: OutdoorRecordingPreferencesStore,
        timeTargetSeconds: Int? = nil,
        plannedRoute: PlannedRoute? = nil
    ) {
        self.init(
            kind: kind,
            store: store,
            timeTargetSeconds: timeTargetSeconds,
            plannedRoute: plannedRoute,
            preferencesStore: preferences
        )
    }

    var requiresLocationSettingsRecovery: Bool {
        guard CLLocationManager.locationServicesEnabled() else { return true }
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
    var isLiveSession: Bool {
        guard activeActivity != nil else { return false }
        switch state {
        case .requestingAuthorization, .recording, .manualPaused, .autoPaused, .failed:
            return true
        case .idle, .finished:
            return false
        }
    }

    func elapsedSeconds(at date: Date = Date()) -> Int {
        guard let activity = activeActivity else { return 0 }
        if activity.finished { return activity.elapsedSeconds }
        return max(activity.elapsedSeconds, max(0, Int(date.timeIntervalSince(activity.startedAt).rounded())))
    }
    func checkpoint(at date: Date = Date()) {
        do {
            try store.checkpoint(at: date)
            activeActivity = store.active
        } catch {
            fail(error.localizedDescription)
        }
    }

    func updateKind(_ newKind: OutdoorActivityKind) {
        guard !isStarted, activeActivity == nil, state == .idle else { return }
        kind = newKind
        configureLocationManager()
    }

    func setKind(_ newKind: OutdoorActivityKind) {
        updateKind(newKind)
    }
    func applyPreferences() {
        if state == .autoPaused, preferenceStore?.preferences.autoPause == false {
            resumeManually()
        }
        refreshPreferences()
        updateIdleTimer()
    }

    var isOnBus: Bool { activeActivity?.currentTravelMode == .bus }
    var selectedPlan: PlannedRoute? { plannedRoute }

    func selectPlannedRoute(_ route: PlannedRoute?) {
        guard !isStarted, activeActivity == nil, state == .idle else { return }
        plannedRoute = route
        plannedPoints = route?.points ?? []
        if let kind = route?.trip?.kind { updateKind(kind) }
    }

    func toggleBusTransfer() {
        guard isLiveSession else { return }
        if state == .autoPaused { resumeManually() }
        do {
            try store.setTravelMode(isOnBus ? .active : .bus)
            activeActivity = store.active
            previousAcceptedLocation = nil
            stationarySince = nil
            resumeSamples = 0
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
            elevationBaseGainMeters = activeActivity?.elevationGainMeters ?? 0
            elevationProcessor.reset()
            if isOnBus { elevationProcessor.stop() } else { elevationProcessor.start() }
            haptic()
            speak(isOnBus ? "Bus transfer. Riding distance paused." : "Riding distance resumed.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    func start(timeTargetSeconds: Int? = nil) {
        if let timeTargetSeconds { self.timeTargetSeconds = timeTargetSeconds > 0 ? timeTargetSeconds : nil }
        refreshPreferences()
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
            activeActivity = store.active
            elevationProcessor.stop()
            liveSpeedMetersPerSecond = 0
            smoothedLiveSpeedMetersPerSecond = 0
            previousAcceptedLocation = nil
            lastObservedLocation = nil
            stationarySince = nil
            resumeSamples = 0
            haptic()
            speak("Paused")
        } catch { fail(error.localizedDescription) }
    }

    func resumeManually() {
        guard state == .manualPaused || state == .autoPaused else { return }
        do {
            if state == .manualPaused {
                try store.resumeManually()
            } else {
                try store.resumeAutomatically()
            }
            state = .recording
            activeActivity = store.active
            elevationBaseGainMeters = activeActivity?.elevationGainMeters ?? 0
            elevationProcessor.reset()
            elevationProcessor.start()
            liveSpeedMetersPerSecond = 0
            smoothedLiveSpeedMetersPerSecond = 0
            previousAcceptedLocation = nil
            lastObservedLocation = nil
            stationarySince = nil
            resumeSamples = 0
            locationManager.startUpdatingLocation()
            haptic()
            speak("Resumed")
        } catch { fail(error.localizedDescription) }
    }

    func lap() {
        do {
            try store.lap()
            haptic()
            speak("Lap \(store.active?.laps.count ?? 0)")
        } catch { fail(error.localizedDescription) }
    }

    @discardableResult
    func finish() -> OutdoorActivity? {
        guard case .finished(let activity) = finishWithOutcome() else { return nil }
        return activity
    }

    @discardableResult
    func finishWithOutcome(at date: Date = Date()) -> FinishOutcome {
        let distance = activeActivity?.tripDistanceMeters ?? 0
        guard distance >= 3 else {
            do {
                locationManager.stopUpdatingLocation()
                elevationProcessor.stop()
                try store.discardActive()
                activeActivity = nil
                route = []
                previousAcceptedLocation = nil
                lastObservedLocation = nil
                liveSpeedMetersPerSecond = nil
                smoothedLiveSpeedMetersPerSecond = nil
                state = .idle
                isStarted = false
                updateIdleTimer()
                errorMessage = "Workout not saved — less than 3 m recorded."
                return .shortSessionDiscarded(distanceMeters: distance)
            } catch {
                fail(error.localizedDescription)
                return .failed(error.localizedDescription)
            }
        }
        do {
            let finished = try store.finish(at: date)
            guard let finished else {
                let message = "TimeMaster could not finish this activity."
                fail(message)
                return .failed(message)
            }
            locationManager.stopUpdatingLocation()
            elevationProcessor.stop()
            isStarted = true
            state = .finished
            activeActivity = finished
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
            updateIdleTimer()
            speak("Activity saved")
            haptic()
            return .finished(finished)
        } catch {
            fail(error.localizedDescription)
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func finishOutcome(at date: Date = Date()) -> FinishOutcome {
        finishWithOutcome(at: date)
    }

    @discardableResult
    func resumeAfterFinish(_ activity: OutdoorActivity? = nil) -> Bool {
        guard state == .finished || activity != nil else { return false }
        let candidate = activity ?? activeActivity
        guard let candidate else { return false }
        kind = candidate.kind
        configureLocationManager()
        do {
            try store.resume(candidate)
            kind = candidate.kind
            configureLocationManager()
            activeActivity = store.active ?? candidate
            route = store.activeRoute
            plannedRoute = store.recordedPlan(for: candidate)
            plannedPoints = plannedRoute?.points ?? []
            state = Self.state(for: activeActivity?.recordingState ?? .recording)
            isStarted = true
            gpsUnavailable = state == .recording || state == .autoPaused
            previousAcceptedLocation = route.last.map(Self.location(from:))
            lastObservedLocation = previousAcceptedLocation
            elevationBaseGainMeters = candidate.elevationGainMeters ?? 0
            stationarySince = nil
            resumeSamples = 0
            elevationProcessor.reset()
            elevationProcessor.source = preferences.elevationSource
            elevationProcessor.start()
            if state != .manualPaused {
                locationManager.startUpdatingLocation()
            }
            updateIdleTimer()
            if state == .recording {
                haptic()
                speak("Resumed")
            }
            return true
        } catch {
            fail(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func resumeFinished(_ activity: OutdoorActivity? = nil) -> Bool {
        resumeAfterFinish(activity)
    }
    func clearFinishedSession() {
        guard state == .finished else { return }
        locationManager.stopUpdatingLocation()
        elevationProcessor.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        activeActivity = nil
        route = []
        plannedPoints = []
        plannedRoute = nil
        snappedPosition = nil
        previousAcceptedLocation = nil
        lastObservedLocation = nil
        liveSpeedMetersPerSecond = nil
        smoothedLiveSpeedMetersPerSecond = nil
        hasRequestedAutomaticOfflineArea = false
        isStarted = false
        state = .idle
    }

    func cancel() {
        locationManager.stopUpdatingLocation()
        elevationProcessor.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        try? store.discardActive()
        activeActivity = nil
        route = []
        snappedPosition = nil
        previousAcceptedLocation = nil
        lastObservedLocation = nil
        hasRequestedAutomaticOfflineArea = false
        isStarted = false
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
        for location in locations { process(location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        gpsUnavailable = true
        liveSpeedMetersPerSecond = nil
        smoothedLiveSpeedMetersPerSecond = nil
        if (error as? CLError)?.code == .denied {
            fail("Location access was revoked. Allow Location While Using the App and Precise Location in Settings to continue this saved workout.")
        } else if state == .requestingAuthorization {
            fail(error.localizedDescription)
        }
    }

    func downloadOfflineRegion(bounds: MLNCoordinateBounds, styleURL: URL, minZoom: Int, maxZoom: Int) {
        OutdoorMapOfflineManager.shared.downloadOfflineRegion(bounds: bounds, styleURL: styleURL, minZoom: minZoom, maxZoom: maxZoom)
    }

    func hasOfflineCoverage(near coordinate: CLLocationCoordinate2D) -> Bool {
        OutdoorMapOfflineManager.shared.hasOfflinePack(near: coordinate)
    }

    private func beginRecording() {
        refreshPreferences()
        if let existing = activeActivity, existing.finished {
            resumeAfterFinish(existing)
            return
        }
        guard activeActivity == nil else {
            if state != .manualPaused {
                elevationProcessor.source = preferences.elevationSource
                elevationProcessor.start()
                locationManager.startUpdatingLocation()
            }
            state = state == .manualPaused ? .manualPaused : .recording
            updateIdleTimer()
            return
        }
        do {
            let activity = try store.begin(
                kind: kind,
                timeTargetSeconds: timeTargetSeconds,
                plannedRoute: plannedRoute,
                preferences: preferences
            )
            activeActivity = activity
            route = []
            previousAcceptedLocation = nil
            lastObservedLocation = nil
            stationarySince = nil
            resumeSamples = 0
            gpsUnavailable = true
            elevationBaseGainMeters = 0
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
            hasRequestedAutomaticOfflineArea = false
            isStarted = true
            elevationProcessor.reset()
            elevationProcessor.source = preferences.elevationSource
            elevationProcessor.start()
            state = .recording
            updateIdleTimer()
            locationManager.startUpdatingLocation()
            AudioManager.shared.activateSession()
            speak("Started \(kind.displayName)")
            haptic()
        } catch { fail(error.localizedDescription) }
    }

    private func process(_ location: CLLocation) {
        guard state == .recording || state == .autoPaused else { return }
        guard isUsableLocation(location) else {
            gpsUnavailable = true
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
            return
        }
        if let lastObservedLocation, location.timestamp <= lastObservedLocation.timestamp { return }
        let observedMovement = lastObservedLocation.map { location.distance(from: $0) } ?? 0
        lastObservedLocation = location
        gpsUnavailable = false

        let candidate = OutdoorTrackPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevationMeters: location.altitude.isFinite ? location.altitude : nil,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            speedMetersPerSecond: location.speed.isFinite && location.speed >= 0 ? location.speed : nil,
            state: state == .recording ? .recording : .autoPaused,
            verticalAccuracyMeters: location.verticalAccuracy.isFinite && location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            barometricRelativeAltitudeMeters: isOnBus ? nil : elevationProcessor.latestBarometricRelativeAltitudeMeters,
            travelMode: isOnBus ? .bus : .active
        )

        if state == .autoPaused {
            let moving = (location.speed >= 1.2 && location.speed.isFinite) || observedMovement >= 15
            if moving { resumeSamples += 1 } else { resumeSamples = 0 }
            if resumeSamples >= 3 {
                do {
                    try store.resumeAutomatically(at: location.timestamp)
                    state = .recording
                    resumeSamples = 0
                    activeActivity = store.active
                    elevationBaseGainMeters = activeActivity?.elevationGainMeters ?? 0
                    elevationProcessor.reset()
                    elevationProcessor.start()
                    stationarySince = nil
                    var resumedCandidate = candidate
                    resumedCandidate.state = .recording
                    if OutdoorMetricsCalculator.accepts(
                        resumedCandidate,
                        after: previousAcceptedLocation.map(Self.trackPoint(from:)),
                        maximumHorizontalAccuracyMeters: maximumHorizontalAccuracy,
                        minimumMovementMeters: minimumMovement,
                        maximumPlausibleSpeedMetersPerSecond: Self.maximumPlausibleSpeed
                    ), appendAccepted(resumedCandidate, location: location) {
                        haptic()
                        previousAcceptedLocation = location
                        speak("Resumed")
                    }
                } catch { fail(error.localizedDescription) }
            }
            return
        }
        updateLiveSpeed(location: location)


        if OutdoorMetricsCalculator.accepts(
            candidate,
            after: previousAcceptedLocation.map(Self.trackPoint(from:)),
            maximumHorizontalAccuracyMeters: maximumHorizontalAccuracy,
            minimumMovementMeters: minimumMovement,
            maximumPlausibleSpeedMetersPerSecond: Self.maximumPlausibleSpeed
        ) {
            if appendAccepted(candidate, location: location) {
                previousAcceptedLocation = location
            }
        }
        updatePauseState(date: location.timestamp, speed: location.speed, movement: observedMovement)
    }

    @discardableResult
    private func appendAccepted(_ point: OutdoorTrackPoint, location: CLLocation) -> Bool {
        if point.effectiveTravelMode == .bus {
            do {
                try store.append(point: point)
                route.append(point)
                activeActivity = store.active
                return true
            } catch {
                fail(error.localizedDescription)
                return false
            }
        }
        let elevation = elevationProcessor.process(location: location)
        var acceptedPoint = point
        acceptedPoint.elevationMeters = elevation.elevationMeters
        acceptedPoint.barometricRelativeAltitudeMeters = preferences.elevationSource == .gps ? nil : elevationProcessor.latestBarometricRelativeAltitudeMeters
        do {
            try store.append(
                point: acceptedPoint,
                filteredElevationGainMeters: elevationBaseGainMeters + elevation.gainMeters,
                filteredHighestElevationMeters: elevation.highestElevationMeters
            )
            route.append(acceptedPoint)
            requestAutomaticOfflineAreaIfNeeded(location.coordinate)
            activeActivity = store.active
            snappedPosition = plannedRoute.flatMap { OutdoorRouteSnapper.snap(location: location, to: $0.points) }
            return true
        } catch {
            fail(error.localizedDescription)
            return false
        }
    }

    private func updatePauseState(date: Date, speed: CLLocationSpeed, movement: CLLocationDistance) {
        guard state == .recording, !isOnBus else { return }
        guard preferences.autoPause else {
            stationarySince = nil
            return
        }
        let stationary = !speed.isFinite || speed < 0.8 ? movement <= 5 : speed <= 0.8 && movement <= 5
        if stationary {
            stationarySince = stationarySince ?? date
            if let since = stationarySince, date.timeIntervalSince(since) >= 20 {
                do {
                    haptic()
                    try store.pauseAutomatically(at: date)
                    state = .autoPaused
                    activeActivity = store.active
                    elevationProcessor.stop()
                    resumeSamples = 0
                    liveSpeedMetersPerSecond = 0
                    smoothedLiveSpeedMetersPerSecond = 0
                    speak("Auto paused")
                } catch { fail(error.localizedDescription) }
            }
        } else {
            stationarySince = nil
        }
    }

    func refreshGPSHealth(at date: Date = Date()) {
        guard state == .recording || state == .autoPaused else { return }
        if lastObservedLocation.map({ date.timeIntervalSince($0.timestamp) > 15 }) ?? true {
            gpsUnavailable = true
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
        }
    }

    private func updateLiveSpeed(location: CLLocation) {
        guard !isOnBus else {
            liveSpeedMetersPerSecond = nil
            smoothedLiveSpeedMetersPerSecond = nil
            return
        }
        let raw: Double
        if location.speed.isFinite, location.speed >= 0 {
            raw = location.speed
        } else if let previousAcceptedLocation {
            let delta = location.timestamp.timeIntervalSince(previousAcceptedLocation.timestamp)
            raw = delta > 0 ? location.distance(from: previousAcceptedLocation) / delta : 0
        } else {
            raw = 0
        }
        liveSpeedMetersPerSecond = raw
        if preferences.speedSmoothing {
            let prior = smoothedLiveSpeedMetersPerSecond ?? raw
            smoothedLiveSpeedMetersPerSecond = prior * 0.7 + raw * 0.3
        } else {
            smoothedLiveSpeedMetersPerSecond = raw
        }
    }

    private func refreshPreferences() {
        if let preferenceStore { preferences = preferenceStore.preferences }
        configureLocationManager()
        elevationProcessor.source = preferences.elevationSource
        elevationProcessor.maximumVerticalAccuracyMeters = preferences.gpsAccuracy == .precise ? 25 : 75
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = preferences.gpsAccuracy == .precise ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = preferences.gpsAccuracy == .precise ? 1 : 5
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.activityType = kind == .bike ? .fitness : .otherNavigation
    }

    private var maximumHorizontalAccuracy: Double {
        preferences.gpsAccuracy == .precise ? OutdoorMetricsCalculator.preciseMaximumHorizontalAccuracyMeters : OutdoorMetricsCalculator.defaultMaximumHorizontalAccuracyMeters
    }

    private var minimumMovement: Double {
        3
    }

    private static let maximumPlausibleSpeed = 70.0
    private static let maximumLocationAge: TimeInterval = 15
    private static let maximumFutureTimestampLead: TimeInterval = 5


    private func isUsableLocation(_ location: CLLocation) -> Bool {
        let coordinate = location.coordinate
        let age = Date().timeIntervalSince(location.timestamp)
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude),
              location.timestamp.timeIntervalSinceReferenceDate.isFinite,
              age <= Self.maximumLocationAge,
              age >= -Self.maximumFutureTimestampLead,
              location.horizontalAccuracy.isFinite,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maximumHorizontalAccuracy else { return false }
        if location.speed.isFinite, location.speed >= 0 {
            return location.speed <= Self.maximumPlausibleSpeed
        }
        return true
    }

    private func requestAutomaticOfflineAreaIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        guard preferences.autoDownloadRouteArea,
              !hasRequestedAutomaticOfflineArea,
              !OutdoorMapOfflineManager.shared.hasOfflinePack(near: coordinate),
              let styleURL = OutdoorMapProviderConfiguration.main.exploreStyleURL,
              OutdoorMapProviderConfiguration.main.capability(for: .explore).cacheRights.offlineInstallationAllowed else {
            return
        }
        hasRequestedAutomaticOfflineArea = true
        OutdoorMapOfflineManager.shared.downloadCurrentArea(center: coordinate, styleURL: styleURL)
    }

    private func haptic() {
        guard preferences.haptics else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func speak(_ message: String) {
        guard audioCuesEnabled, preferences.audioCues != .off else { return }
        AudioManager.shared.speak(message, volume: preferences.audioCues == .quiet ? 0.42 : 1)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = preferences.keepScreenAwake && isStarted && state != .finished && state != .idle && state != .failed
    }

    private func fail(_ message: String) {
        locationManager.stopUpdatingLocation()
        elevationProcessor.stop()
        errorMessage = message
        state = .failed
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private static func state(for state: OutdoorRecordingState) -> State {
        switch state {
        case .recording: .recording
        case .manualPaused: .manualPaused
        case .autoPaused: .autoPaused
        case .finished: .finished
        }
    }

    private static func trackPoint(from location: CLLocation) -> OutdoorTrackPoint {
        OutdoorTrackPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            speedMetersPerSecond: location.speed.isFinite && location.speed >= 0 ? location.speed : nil,
            state: .recording
        )
    }

    private static func location(from point: OutdoorTrackPoint) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
            altitude: point.elevationMeters ?? 0,
            horizontalAccuracy: point.horizontalAccuracyMeters,
            verticalAccuracy: point.verticalAccuracyMeters ?? -1,
            course: -1,
            speed: point.speedMetersPerSecond ?? -1,
            timestamp: point.timestamp
        )
    }
}
#endif
