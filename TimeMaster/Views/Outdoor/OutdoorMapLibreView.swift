#if os(iOS)
import SwiftUI
import MapLibre
import CoreLocation

private enum OutdoorMinimalMapPalette {
    struct Style {
        let canvas: UIColor
        let land: UIColor
        let landDetail: UIColor
        let green: UIColor
        let water: UIColor
        let waterLine: UIColor
        let road: UIColor
        let roadCasing: UIColor
        let path: UIColor
        let rail: UIColor
        let boundary: UIColor
        let building: UIColor
        let label: UIColor
        let labelHalo: UIColor
        let plannedRoute: UIColor
    }

    static let routeAccent = UIColor(red: 1, green: 0.478, blue: 0, alpha: 1)

    static let light = Style(
        canvas: UIColor(red: 0.956, green: 0.956, blue: 0.941, alpha: 1),
        land: UIColor(red: 0.929, green: 0.929, blue: 0.902, alpha: 1),
        landDetail: UIColor(red: 0.890, green: 0.890, blue: 0.855, alpha: 1),
        green: UIColor(red: 0.858, green: 0.906, blue: 0.842, alpha: 1),
        water: UIColor(red: 0.847, green: 0.910, blue: 0.953, alpha: 1),
        waterLine: UIColor(red: 0.682, green: 0.808, blue: 0.890, alpha: 1),
        road: UIColor(red: 0.997, green: 0.997, blue: 0.986, alpha: 1),
        roadCasing: UIColor(red: 0.836, green: 0.836, blue: 0.810, alpha: 1),
        path: UIColor(red: 0.673, green: 0.680, blue: 0.651, alpha: 1),
        rail: UIColor(red: 0.576, green: 0.584, blue: 0.553, alpha: 1),
        boundary: UIColor(red: 0.745, green: 0.749, blue: 0.718, alpha: 1),
        building: UIColor(red: 0.861, green: 0.855, blue: 0.831, alpha: 1),
        label: UIColor(red: 0.247, green: 0.251, blue: 0.231, alpha: 1),
        labelHalo: UIColor(red: 0.956, green: 0.956, blue: 0.941, alpha: 1),
        plannedRoute: UIColor(red: 0.278, green: 0.282, blue: 0.259, alpha: 0.76)
    )

    static let dark = Style(
        canvas: UIColor(red: 0.055, green: 0.059, blue: 0.055, alpha: 1),
        land: UIColor(red: 0.086, green: 0.094, blue: 0.086, alpha: 1),
        landDetail: UIColor(red: 0.129, green: 0.141, blue: 0.129, alpha: 1),
        green: UIColor(red: 0.137, green: 0.212, blue: 0.145, alpha: 1),
        water: UIColor(red: 0.063, green: 0.149, blue: 0.208, alpha: 1),
        waterLine: UIColor(red: 0.169, green: 0.341, blue: 0.443, alpha: 1),
        road: UIColor(red: 0.255, green: 0.267, blue: 0.251, alpha: 1),
        roadCasing: UIColor(red: 0.149, green: 0.157, blue: 0.149, alpha: 1),
        path: UIColor(red: 0.424, green: 0.459, blue: 0.424, alpha: 1),
        rail: UIColor(red: 0.503, green: 0.522, blue: 0.490, alpha: 1),
        boundary: UIColor(red: 0.286, green: 0.314, blue: 0.286, alpha: 1),
        building: UIColor(red: 0.149, green: 0.165, blue: 0.153, alpha: 1),
        label: UIColor(red: 0.910, green: 0.922, blue: 0.898, alpha: 1),
        labelHalo: UIColor(red: 0.055, green: 0.059, blue: 0.055, alpha: 1),
        plannedRoute: UIColor(red: 0.790, green: 0.812, blue: 0.780, alpha: 0.78)
    )
}

struct OutdoorMapLibreView: UIViewRepresentable {
    var points: [OutdoorTrackPoint]
    var followsUser: Bool
    var state: OutdoorLocationRecorder.State
    var plannedPoints: [OutdoorTrackPoint]? = nil
    var mode: OutdoorMapMode = .explore
    var overlayModes: Set<OutdoorMapMode> = []
    var focusRequestID: Int = 0
    var northRequestID: Int = 0
    var cityFitRequestID: Int = 0
    var weatherInfoEnabled: Bool = false
    var configuration: OutdoorMapProviderConfiguration = .main
    var onCapabilityChange: ((OutdoorMapCapability) -> Void)? = nil
    var onWeatherStateChange: ((OutdoorWeatherState) -> Void)? = nil
    var onFollowStateChange: ((Bool) -> Void)? = nil
    var onHeadingChange: ((CLLocationDirection) -> Void)? = nil
    var onFocusFailure: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onCapabilityChange: onCapabilityChange,
            onWeatherStateChange: onWeatherStateChange,
            onFollowStateChange: onFollowStateChange,
            onHeadingChange: onHeadingChange,
            onFocusFailure: onFocusFailure
        )
    }
    func makeUIView(context: Context) -> MLNMapView {
        let map: MLNMapView
        if let styleURL = configuration.exploreStyleURL {
            map = MLNMapView(frame: .zero, styleURL: styleURL)
        } else {
            map = MLNMapView(
                frame: .zero,
                styleJSON: ##"{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#F4F4F0"}}]}"##
            )
        }
        context.coordinator.attach(to: map)
        return map
    }
    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.render(
            map: map,
            points: points,
            plannedPoints: plannedPoints ?? [],
            state: state,
            followsUser: followsUser,
            mode: mode,
            overlayModes: overlayModes,
            focusRequestID: focusRequestID,
            northRequestID: northRequestID,
            cityFitRequestID: cityFitRequestID,
            weatherInfoEnabled: weatherInfoEnabled
        )
    }

    @MainActor final class Coordinator: NSObject, MLNMapViewDelegate, CLLocationManagerDelegate {
        private let session: OutdoorMapSession
        private let weatherAdapter: OutdoorWeatherKitAdapter?
        private let onCapabilityChange: ((OutdoorMapCapability) -> Void)?
        private let onFollowStateChange: ((Bool) -> Void)?
        private let onHeadingChange: ((CLLocationDirection) -> Void)?
        private let onFocusFailure: ((String) -> Void)?
        private let locationManager = CLLocationManager()

        private weak var map: MLNMapView?
        private var latestPoints: [OutdoorTrackPoint] = []
        private var latestPlannedPoints: [OutdoorTrackPoint] = []
        private var latestState: OutdoorLocationRecorder.State = .idle
        private var latestOverlayModes: Set<OutdoorMapMode> = []
        private var latestUserCoordinate: CLLocationCoordinate2D?
        private var latestWeatherInfoEnabled = false
        private var isApplyingCamera = false
        private var lastUsableMode: OutdoorMapMode = .explore
        private var latestHeading: CLLocationDirection = 0
        private var isWeatherLocationUpdatesActive = false
        private var lastNorthRequestID = 0
        private var fallbackModeForPendingStyle: OutdoorMapMode?
        private var hasCenteredOnUser = false
        private var loadedStyleURL: URL?
        private var activeTileSourceIDs: Set<String> = []
        private var minimalMapStyleID: ObjectIdentifier?
        private var minimalMapUsesDarkPalette: Bool?
        private var configuredStyleID: ObjectIdentifier?
        private var configuredMode: OutdoorMapMode?
        private var configuredStyleURL: URL?
        private var lastRenderedPointsSignature: RouteRenderSignature?
        private var lastRenderedPlannedPointsSignature: RouteRenderSignature?
        private var lastRenderedState: OutdoorLocationRecorder.State?
        private var lastRenderedFollowsUser: Bool?
        private var lastRenderedMode: OutdoorMapMode?
        private var configuredOverlays: Set<OutdoorMapMode> = []
        private var lastRenderedOverlayModes: Set<OutdoorMapMode>?
        private var lastRenderedFocusRequestID: Int?
        private var lastRenderedWeatherInfoEnabled: Bool?
        private var lastRenderedCityFitRequestID: Int?
        private var pendingCityFit = false
        private var didRenderInputs = false
        private var liveRouteSignature: RouteRenderSignature?
        private var plannedRouteSignature: RouteRenderSignature?
        private var didApplyThreeDCamera = false
        private var startAnnotation: MLNPointAnnotation?
        private var endAnnotation: MLNPointAnnotation?
        private var lastFocusRequestID = 0
        private var reportedCapabilities: [OutdoorMapMode: OutdoorMapCapability] = [:]
        private var reportedFollowState: Bool?
        private struct RouteRenderSignature: Equatable {
            let count: Int
            let first: OutdoorTrackPoint?
            let last: OutdoorTrackPoint?

            init(points: [OutdoorTrackPoint]) {
                count = points.count
                first = points.first
                last = points.last
            }
        }

        init(
            configuration: OutdoorMapProviderConfiguration,
            onCapabilityChange: ((OutdoorMapCapability) -> Void)?,
            onWeatherStateChange: ((OutdoorWeatherState) -> Void)?,
            onFollowStateChange: ((Bool) -> Void)?,
            onHeadingChange: ((CLLocationDirection) -> Void)?,
            onFocusFailure: ((String) -> Void)?
        ) {
            session = OutdoorMapSession(configuration: configuration)
            self.onCapabilityChange = onCapabilityChange
            self.onFollowStateChange = onFollowStateChange
            self.onHeadingChange = onHeadingChange
            self.onFocusFailure = onFocusFailure
            if #available(iOS 16.0, *) {
                weatherAdapter = OutdoorWeatherKitAdapter(onStateChange: onWeatherStateChange)
            } else {
                weatherAdapter = nil
            }
            super.init()
            locationManager.delegate = self
            locationManager.headingFilter = 5
        }

        func attach(to map: MLNMapView) {
            self.map = map
            map.delegate = self
            map.showsUserLocation = true
            map.userTrackingMode = .none
            map.tintColor = OutdoorMinimalMapPalette.routeAccent
            map.isScrollEnabled = true
            map.isZoomEnabled = true
            map.isRotateEnabled = true
            map.isPitchEnabled = false
            map.minimumPitch = 0
            map.maximumPitch = 60
            map.minimumZoomLevel = 2
            map.maximumZoomLevel = 19
            configuredStyleID = nil
            configuredMode = nil
            hideNativeOrnaments(on: map)
            configuredStyleURL = nil
            configuredOverlays = []
            minimalMapStyleID = nil
            minimalMapUsesDarkPalette = nil
            latestOverlayModes = []
            lastRenderedPointsSignature = nil
            lastRenderedPlannedPointsSignature = nil
            lastRenderedState = nil
            lastRenderedFollowsUser = nil
            lastRenderedMode = nil
            lastRenderedOverlayModes = nil
            lastRenderedCityFitRequestID = nil
            pendingCityFit = false
            lastRenderedWeatherInfoEnabled = nil
            didRenderInputs = false
            liveRouteSignature = nil
            plannedRouteSignature = nil
            didApplyThreeDCamera = false
            latestHeading = map.camera.heading
            loadedStyleURL = map.styleURL
        }

        private func reportCapability(_ capability: OutdoorMapCapability) {
            guard reportedCapabilities[capability.mode] != capability else { return }
            reportedCapabilities[capability.mode] = capability
            DispatchQueue.main.async { [weak self] in
                self?.onCapabilityChange?(capability)
            }
        }
        private func reportFollowState(_ followsUser: Bool) {
            guard reportedFollowState != followsUser else { return }
            reportedFollowState = followsUser
            DispatchQueue.main.async { [weak self] in
                self?.onFollowStateChange?(followsUser)
            }
        }
        private func reportHeading(_ heading: CLLocationDirection) {
            let normalized = heading.truncatingRemainder(dividingBy: 360)
            guard abs(normalized - latestHeading) > 0.5 else { return }
            latestHeading = normalized
            DispatchQueue.main.async { [weak self] in
                self?.onHeadingChange?(normalized)
            }
        }

        private func resetNorth(on map: MLNMapView) {
            let camera = MLNMapCamera(
                lookingAtCenter: map.centerCoordinate,
                fromDistance: max(map.camera.altitude, 1),
                pitch: map.camera.pitch,
                heading: 0
            )
            isApplyingCamera = true
            map.setCamera(camera, animated: true)
            isApplyingCamera = false
            reportHeading(0)
            session.captureCamera(from: map)
        }


        func render(
            map: MLNMapView,
            points: [OutdoorTrackPoint],
            plannedPoints: [OutdoorTrackPoint],
            state: OutdoorLocationRecorder.State,
            followsUser: Bool,
            mode: OutdoorMapMode,
            overlayModes: Set<OutdoorMapMode>,
            focusRequestID: Int,
            northRequestID: Int,
            cityFitRequestID: Int,
            weatherInfoEnabled: Bool
        ) {
            let mapWasReattached = self.map !== map
            if mapWasReattached {
                attach(to: map)
            }

            let pointsSignature = RouteRenderSignature(points: points)
            let plannedPointsSignature = RouteRenderSignature(points: plannedPoints)
            let inputsChanged = mapWasReattached
                || !didRenderInputs
                || lastRenderedPointsSignature != pointsSignature
                || lastRenderedPlannedPointsSignature != plannedPointsSignature
                || lastRenderedState != state
                || lastRenderedFollowsUser != followsUser
                || lastRenderedMode != mode
                || lastRenderedOverlayModes != overlayModes
                || lastRenderedFocusRequestID != focusRequestID
                || lastNorthRequestID != northRequestID
                || lastRenderedCityFitRequestID != cityFitRequestID
                || lastRenderedWeatherInfoEnabled != weatherInfoEnabled
            latestPoints = points
            latestPlannedPoints = plannedPoints
            latestState = state
            latestOverlayModes = overlayModes
            latestWeatherInfoEnabled = weatherInfoEnabled
            lastRenderedPointsSignature = pointsSignature
            lastRenderedPlannedPointsSignature = plannedPointsSignature
            lastRenderedState = state
            lastRenderedFollowsUser = followsUser
            lastRenderedMode = mode
            lastRenderedOverlayModes = overlayModes
            lastRenderedFocusRequestID = focusRequestID
            if northRequestID != lastNorthRequestID {
                lastNorthRequestID = northRequestID
                resetNorth(on: map)
            }
            if let lastRenderedCityFitRequestID,
               lastRenderedCityFitRequestID != cityFitRequestID {
                pendingCityFit = true
            }
            lastRenderedCityFitRequestID = cityFitRequestID
            lastRenderedWeatherInfoEnabled = weatherInfoEnabled
            didRenderInputs = true
            guard inputsChanged else { return }

            session.captureCamera(from: map)
            let hasRoute = !points.isEmpty || !plannedPoints.isEmpty
            if hasRoute {
                hasCenteredOnUser = false
            }
            session.resetRouteFrameIfEmpty(hasRoute)
            session.setFollowRequested(followsUser)
            if focusRequestID != lastFocusRequestID {
                lastFocusRequestID = focusRequestID
                requestFocus(on: map)
            }

            let selection = session.requestMode(mode)
            reportCapability(selection.capability)
            OutdoorMapMode.overlayModes.forEach { reportCapability(session.capability(for: $0)) }
            guard selection.capability.isUsable else {
                if let style = map.style {
                    renderRouteOverlays(map: map, style: style)
                }
                applyFollowState(to: map)
                fitMapToCityIfNeeded(map: map)
                updateWeather()
                return
            }

            if selection.shouldReloadStyle, let styleURL = selection.style?.styleURL {
                fallbackModeForPendingStyle = lastUsableMode
                session.captureCamera(from: map)
                loadedStyleURL = styleURL
                map.styleURL = styleURL
                updateWeather()
                return
            }


            if let style = map.style {
                configureProviderLayers(style: style, overlays: latestOverlayModes)
                renderRouteOverlays(map: map, style: style)
                applyThreeDIfSupported(map: map, style: style, overlays: latestOverlayModes)
            }
            applyFollowState(to: map)
            applyInitialFramingIfNeeded(map: map)
            fitMapToCityIfNeeded(map: map)
            updateWeather()
        }

        private func hideNativeOrnaments(on map: MLNMapView) {
            map.showsCompassView = true
            map.compassView.isHidden = false
            map.compassViewPosition = .topRight
            map.compassViewMargins = CGPoint(x: 12, y: 12)
            map.attributionButton.isHidden = true
            map.logoView.isHidden = true
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            loadedStyleURL = mapView.styleURL
            hideNativeOrnaments(on: mapView)
            if installLocalGlyphTemplate(in: style) {
                return
            }
            isApplyingCamera = true
            session.restoreCamera(on: mapView)
            isApplyingCamera = false
            configureProviderLayers(style: style, overlays: latestOverlayModes)
            renderRouteOverlays(map: mapView, style: style)
            applyThreeDIfSupported(map: mapView, style: style, overlays: latestOverlayModes)
            applyFollowState(to: mapView)
            applyInitialFramingIfNeeded(map: mapView)
            fitMapToCityIfNeeded(map: mapView)
            updateWeather()
        }

        private func installLocalGlyphTemplate(in style: MLNStyle) -> Bool {
            guard let glyphTemplate = localGlyphTemplate,
                  let data = style.styleJSON.data(using: .utf8),
                  var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { return false }

            if json["glyphs"] as? String == glyphTemplate {
                return false
            }

            json["glyphs"] = glyphTemplate
            guard JSONSerialization.isValidJSONObject(json),
                  let rewrittenData = try? JSONSerialization.data(withJSONObject: json),
                  let rewrittenStyle = String(data: rewrittenData, encoding: .utf8)
            else { return false }

            style.styleJSON = rewrittenStyle
            return true
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            let failedMode = session.requestedMode
            let message = "\(failedMode.displayName) provider failed to load: \(error.localizedDescription)"
            session.markProviderFailure(failedMode, reason: message)
            reportCapability(session.capability(for: failedMode))
            guard failedMode != lastUsableMode,
                  let fallbackMode = fallbackModeForPendingStyle,
                  let fallbackStyle = session.configuration.style(for: fallbackMode)?.styleURL
            else { return }
            _ = session.requestMode(fallbackMode)
            lastUsableMode = fallbackMode
            fallbackModeForPendingStyle = nil
            loadedStyleURL = fallbackStyle
            mapView.styleURL = fallbackStyle
        }
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coordinate = userLocation?.location?.coordinate else { return }
            latestUserCoordinate = coordinate
            updateWeather()
            if session.followsUser {
                applyFollowState(to: mapView)
            } else {
                centerOnUserIfNeeded(map: mapView)
            }
        }
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last,
                  location.horizontalAccuracy >= 0,
                  CLLocationCoordinate2DIsValid(location.coordinate)
            else { return }
            latestUserCoordinate = location.coordinate
            updateWeather()
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard latestWeatherInfoEnabled else { return }
            startWeatherLocationUpdatesIfNeeded()
            updateWeather()
        }


        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            guard !isApplyingCamera, mapView.userTrackingMode == .none else { return }
            session.userDidPan()
            reportFollowState(false)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            guard !isApplyingCamera else { return }
            reportHeading(mapView.camera.heading)
            session.captureCamera(from: mapView)
        }



        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let point = annotation as? MLNPointAnnotation else { return nil }
            let isStart = point.title == "Start"
            let reuseIdentifier = isStart ? "outdoor-start-marker" : "outdoor-end-marker"
            let marker = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
                ?? MLNAnnotationView(reuseIdentifier: reuseIdentifier)
            let size: CGFloat = isStart ? 12 : 16
            marker.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let palette = currentMinimalMapPalette
            marker.backgroundColor = isStart ? palette.canvas : OutdoorMinimalMapPalette.routeAccent
            marker.layer.cornerRadius = size / 2
            marker.layer.borderWidth = isStart ? 2 : 2.5
            marker.layer.borderColor = isStart
                ? palette.label.cgColor
                : palette.canvas.cgColor
            marker.layer.shadowColor = UIColor.black.cgColor
            marker.layer.shadowOpacity = 0.18
            marker.layer.shadowRadius = 3
            marker.layer.shadowOffset = CGSize(width: 0, height: 1)
            return marker
        }

        private func requestFocus(on map: MLNMapView) {
            switch locationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                enableFollow(on: map)
            case .notDetermined:
                onFocusFailure?("Start recording to request location access, then focus the map.")
            case .denied, .restricted:
                onFocusFailure?("Location access is required to focus the map. Allow it in Settings and try again.")
            @unknown default:
                onFocusFailure?("Location access is unavailable.")
            }
        }

        private func enableFollow(on map: MLNMapView) {
            session.setFollowRequested(true)
            applyFollowState(to: map)
            reportFollowState(true)
        }



        private func applyFollowState(to map: MLNMapView) {
            let desiredMode: MLNUserTrackingMode = session.followsUser ? .follow : .none
            if map.userTrackingMode != desiredMode {
                map.userTrackingMode = desiredMode
            }
        }


        private func applyInitialFramingIfNeeded(map: MLNMapView) {
            guard session.shouldFrameRoute(hasRoute: !latestPoints.isEmpty || !latestPlannedPoints.isEmpty) else {
                centerOnUserIfNeeded(map: map)
                return
            }
            isApplyingCamera = true
            defer { isApplyingCamera = false }
            if session.followsUser {
                if let coordinate = latestUserCoordinate ?? latestPoints.last.map(coordinate(for:)) {
                    map.setCenter(coordinate, zoomLevel: 15, animated: false)
                }
                return
            }
            let framingPoints = latestPlannedPoints.isEmpty ? latestPoints : latestPlannedPoints + latestPoints
            guard let first = framingPoints.first else { return }
            if framingPoints.count == 1 {
                map.setCenter(coordinate(for: first), zoomLevel: 15, animated: false)
            } else {
                map.setVisibleCoordinateBounds(
                    bounds(for: framingPoints),
                    edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 180, right: 40),
                    animated: false
                )
            }
            session.captureCamera(from: map)
        }

        private func fitMapToCityIfNeeded(map: MLNMapView) {
            guard pendingCityFit else { return }
            pendingCityFit = false

            let framingPoints = latestPlannedPoints.isEmpty
                ? latestPoints
                : latestPlannedPoints + latestPoints
            let center: CLLocationCoordinate2D
            if framingPoints.isEmpty {
                center = latestUserCoordinate ?? map.centerCoordinate
            } else {
                let routeBounds = bounds(for: framingPoints)
                center = CLLocationCoordinate2D(
                    latitude: (routeBounds.sw.latitude + routeBounds.ne.latitude) / 2,
                    longitude: (routeBounds.sw.longitude + routeBounds.ne.longitude) / 2
                )
            }

            if session.followsUser {
                session.setFollowRequested(false)
                reportFollowState(false)
            }
            map.userTrackingMode = .none
            let cityZoomLevel = min(11.5, map.maximumZoomLevel)
            isApplyingCamera = true
            map.setCenter(center, zoomLevel: max(map.minimumZoomLevel, cityZoomLevel), animated: true)
            isApplyingCamera = false
        }

        private func centerOnUserIfNeeded(map: MLNMapView) {
            guard let coordinate = latestUserCoordinate,
                  latestPoints.isEmpty,
                  latestPlannedPoints.isEmpty,
                  !session.followsUser,
                  !session.hasFramedInitialRoute,
                  !hasCenteredOnUser
            else { return }
            isApplyingCamera = true
            map.setCenter(coordinate, zoomLevel: 17, animated: false)
            isApplyingCamera = false
            hasCenteredOnUser = true
            session.captureCamera(from: map)
        }

        private func startWeatherLocationUpdatesIfNeeded() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                guard !isWeatherLocationUpdatesActive else { return }
                locationManager.startUpdatingLocation()
                isWeatherLocationUpdatesActive = true
            case .denied, .restricted:
                break
            @unknown default:
                break
            }
        }

        private func stopWeatherLocationUpdates() {
            guard isWeatherLocationUpdatesActive else { return }
            locationManager.stopUpdatingLocation()
            isWeatherLocationUpdatesActive = false
        }

        private func updateWeather() {
            guard let adapter = weatherAdapter else { return }
            guard latestWeatherInfoEnabled else {
                stopWeatherLocationUpdates()
                adapter.update(location: nil, enabled: false)
                return
            }

            startWeatherLocationUpdatesIfNeeded()
            let coordinate = latestUserCoordinate ?? map?.centerCoordinate
            let location = coordinate.flatMap { CLLocationCoordinate2DIsValid($0) ? CLLocation(latitude: $0.latitude, longitude: $0.longitude) : nil }
            adapter.update(location: location, enabled: true)
        }

        private var currentMinimalMapPalette: OutdoorMinimalMapPalette.Style {
            latestOverlayModes.contains(.dark)
                ? OutdoorMinimalMapPalette.dark
                : OutdoorMinimalMapPalette.light
        }
        private var localGlyphTemplate: String? {
            guard let resourceURL = Bundle.main.resourceURL else { return nil }
            let glyphDirectory = resourceURL.appendingPathComponent("MapGlyphs", isDirectory: true)
            guard FileManager.default.fileExists(atPath: glyphDirectory.path) else { return nil }
            return glyphDirectory
                .appendingPathComponent("{fontstack}", isDirectory: true)
                .appendingPathComponent("{range}.pbf")
                .absoluteString
        }

        private func labelFontStack(for identifier: String) -> [String] {
            let isPlaceLabel = identifier.contains("place")
                || identifier.contains("country")
                || identifier.contains("state")
                || identifier.contains("city")
                || identifier.contains("town")
                || identifier.contains("village")
            return isPlaceLabel
                ? ["Inter Black Regular", "Inter Light Regular", "Noto Sans Regular"]
                : ["Inter Light Regular", "Inter Black Regular", "Noto Sans Regular"]
        }

        private func applyMinimalMapPresentation(to style: MLNStyle, overlays: Set<OutdoorMapMode>) {
            guard style.source(withIdentifier: "openmaptiles") != nil else { return }
            let styleID = ObjectIdentifier(style)
            let usesDarkPalette = overlays.contains(.dark)
            let palette = usesDarkPalette ? OutdoorMinimalMapPalette.dark : OutdoorMinimalMapPalette.light
            guard minimalMapStyleID != styleID || minimalMapUsesDarkPalette != usesDarkPalette else {
                updateMinimalLabelVisibility(in: style, showsTransit: overlays.contains(.transit))
                for case let extrusion as MLNFillExtrusionStyleLayer in style.layers {
                    extrusion.isVisible = overlays.contains(.threeD)
                }
                if localGlyphTemplate != nil {
                    for case let symbol as MLNSymbolStyleLayer in style.layers {
                        symbol.textFontNames = NSExpression(
                            forConstantValue: labelFontStack(for: symbol.identifier)
                        )
                    }
                }
                return
            }

            minimalMapStyleID = styleID
            minimalMapUsesDarkPalette = usesDarkPalette
            liveRouteSignature = nil
            plannedRouteSignature = nil

            for layer in style.layers {
                let identifier = layer.identifier
                guard !identifier.hasPrefix("outdoor-"),
                      identifier != "live-route-line",
                      identifier != "planned-route-line"
                else { continue }

                switch layer {
                case let background as MLNBackgroundStyleLayer:
                    background.backgroundColor = NSExpression(forConstantValue: palette.canvas)
                case let raster as MLNRasterStyleLayer where identifier == "natural_earth":
                    raster.rasterOpacity = NSExpression(forConstantValue: usesDarkPalette ? 0.02 : 0.04)
                case let fill as MLNFillStyleLayer:
                    if identifier == "water" {
                        fill.fillColor = NSExpression(forConstantValue: palette.water)
                        fill.fillOutlineColor = NSExpression(forConstantValue: palette.waterLine)
                    } else if identifier == "building" {
                        fill.fillColor = NSExpression(forConstantValue: palette.building)
                        fill.fillOutlineColor = NSExpression(forConstantValue: palette.roadCasing)
                    } else if identifier == "road_area_pattern" || identifier == "landcover_wetland" {
                        fill.isVisible = false
                    } else if identifier == "park"
                        || identifier.hasPrefix("landcover")
                        || identifier == "landuse_pitch"
                        || identifier == "landuse_track"
                        || identifier == "landuse_cemetery" {
                        fill.fillColor = NSExpression(forConstantValue: palette.green)
                        fill.fillOutlineColor = NSExpression(forConstantValue: palette.landDetail)
                    } else {
                        fill.fillColor = NSExpression(forConstantValue: palette.land)
                        fill.fillOutlineColor = NSExpression(forConstantValue: palette.landDetail)
                    }
                case let extrusion as MLNFillExtrusionStyleLayer:
                    extrusion.isVisible = overlays.contains(.threeD)
                    extrusion.fillExtrusionColor = NSExpression(forConstantValue: palette.building)
                    extrusion.fillExtrusionOpacity = NSExpression(forConstantValue: usesDarkPalette ? 0.86 : 0.72)
                case let line as MLNLineStyleLayer:
                    if identifier.hasPrefix("waterway") {
                        line.lineColor = NSExpression(forConstantValue: palette.waterLine)
                    } else if identifier.hasPrefix("boundary") {
                        line.lineColor = NSExpression(forConstantValue: palette.boundary)
                    } else if identifier.contains("rail") {
                        line.lineColor = NSExpression(forConstantValue: palette.rail)
                    } else if identifier.hasPrefix("road") {
                        let color: UIColor
                        if identifier.contains("path") || identifier.contains("service") || identifier.contains("track") {
                            color = palette.path
                        } else if identifier.contains("casing") {
                            color = palette.roadCasing
                        } else {
                            color = palette.road
                        }
                        line.lineColor = NSExpression(forConstantValue: color)
                    } else {
                        line.lineColor = NSExpression(forConstantValue: palette.landDetail)
                    }
                case let symbol as MLNSymbolStyleLayer:
                    symbol.textColor = NSExpression(forConstantValue: palette.label)
                    symbol.textHaloColor = NSExpression(forConstantValue: palette.labelHalo)
                    symbol.textOpacity = NSExpression(forConstantValue: 0.78)
                    if localGlyphTemplate != nil {
                        symbol.textFontNames = NSExpression(
                            forConstantValue: labelFontStack(for: identifier)
                        )
                    }
                default:
                    break
                }
            }
            updateMinimalLabelVisibility(in: style, showsTransit: overlays.contains(.transit))
        }


        private func updateMinimalLabelVisibility(in style: MLNStyle, showsTransit: Bool) {
            for case let symbol as MLNSymbolStyleLayer in style.layers {
                let identifier = symbol.identifier
                if identifier == "poi_transit" {
                    symbol.isVisible = showsTransit
                } else if identifier.hasPrefix("poi_")
                    || identifier.hasPrefix("housenumber")
                    || identifier.hasPrefix("road_one_way")
                    || identifier.hasPrefix("road_shield")
                    || identifier.hasPrefix("highway-shield")
                    || identifier == "highway-name-path"
                    || identifier == "highway-name-minor"
                    || identifier == "airport" {
                    symbol.isVisible = false
                }
            }
        }

        private func configureProviderLayers(style: MLNStyle, overlays: Set<OutdoorMapMode>) {
            applyMinimalMapPresentation(to: style, overlays: overlays)
            let styleID = ObjectIdentifier(style)
            let styleURL = map?.styleURL
            let baseMode = session.activeMode
            guard configuredStyleID != styleID
                || configuredMode != baseMode
                || configuredStyleURL != styleURL
                || configuredOverlays != overlays
            else { return }

            for identifier in activeTileSourceIDs {
                if let layer = style.layer(withIdentifier: identifier) {
                    style.removeLayer(layer)
                }
                if let source = style.source(withIdentifier: identifier) {
                    style.removeSource(source)
                }
            }
            activeTileSourceIDs.removeAll()
            configuredStyleID = styleID
            configuredMode = baseMode
            configuredStyleURL = styleURL
            configuredOverlays = overlays
            liveRouteSignature = nil
            plannedRouteSignature = nil

            guard let baseDefinition = session.configuration.style(for: baseMode) else { return }
            if baseMode == .terrain || overlays.contains(.threeD) {
                addTerrainRelief(to: style)
            }

            if let template = baseDefinition.rasterTileURLTemplate, !template.isEmpty {
                let sourceID = "outdoor-\(baseMode.rawValue)-raster-source"
                let layerID = "outdoor-\(baseMode.rawValue)-raster-layer"
                let source = MLNRasterTileSource(identifier: sourceID, tileURLTemplates: [template], options: nil)
                style.addSource(source)
                let layer = MLNRasterStyleLayer(identifier: layerID, source: source)
                layer.rasterOpacity = NSExpression(forConstantValue: baseMode == .satellite ? 1.0 : 0.72)
                style.addLayer(layer)
                activeTileSourceIDs.insert(sourceID)
                activeTileSourceIDs.insert(layerID)
            }

            func addVectorOverlay(_ overlay: OutdoorMapMode, definition: OutdoorMapStyleDefinition) {
                guard let template = definition.vectorTileURLTemplate,
                      let sourceLayer = definition.vectorSourceLayer,
                      !template.isEmpty else { return }
                let sourceID = "outdoor-\(overlay.rawValue)-vector-source"
                let layerID = "outdoor-\(overlay.rawValue)-vector-layer"
                let source = MLNVectorTileSource(identifier: sourceID, tileURLTemplates: [template], options: nil)
                style.addSource(source)
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.sourceLayerIdentifier = sourceLayer
                layer.lineColor = NSExpression(forConstantValue: overlay == .traffic ? UIColor.systemRed : UIColor.systemPurple)
                layer.lineWidth = NSExpression(forConstantValue: overlay == .traffic ? 3 : 2)
                layer.lineOpacity = NSExpression(forConstantValue: overlay == .traffic ? 0.72 : 0.85)
                style.addLayer(layer)
                activeTileSourceIDs.insert(sourceID)
                activeTileSourceIDs.insert(layerID)
            }

            if overlays.contains(.traffic), let definition = session.configuration.style(for: .traffic) {
                addVectorOverlay(.traffic, definition: definition)
            }
            if overlays.contains(.transit), let definition = session.configuration.style(for: .transit) {
                addVectorOverlay(.transit, definition: definition)
            }
            if overlays.contains(.cycling), let source = style.source(withIdentifier: "openmaptiles") {
                let layerID = "outdoor-cycling-network-layer"
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.sourceLayerIdentifier = "transportation"
                layer.minimumZoomLevel = 9
                layer.predicate = NSPredicate(
                    format: "subclass == 'cycleway' OR class == 'cycleway' OR bicycle == 'designated' OR bicycle == 'yes' OR bicycle == 'permissive'"
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemGreen)
                layer.lineWidth = NSExpression(
                    format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                    [9: 0.45, 10: 0.9, 12: 1.8, 16: 4.0]
                )
                layer.lineOpacity = NSExpression(
                    format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                    [9: 0.2, 10: 0.52, 11: 0.8, 13: 0.94]
                )
                style.addLayer(layer)
                activeTileSourceIDs.insert(layerID)
            }
            if overlays.contains(.transit),
               session.configuration.style(for: .transit)?.vectorTileURLTemplate == nil,
               let source = style.source(withIdentifier: "openmaptiles") {
                let layerID = "outdoor-transit-network-layer"
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.sourceLayerIdentifier = "transportation"
                layer.predicate = NSPredicate(
                    format: "class == 'transit' OR subclass IN {'rail', 'subway', 'tram', 'light_rail'}"
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemPurple)
                layer.lineWidth = NSExpression(
                    format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                    [8: 1.0, 14: 2.5, 18: 4.0]
                )
                layer.lineOpacity = NSExpression(forConstantValue: 0.85)
                style.addLayer(layer)
                activeTileSourceIDs.insert(layerID)
            }
        }


        private func addTerrainRelief(to style: MLNStyle) {
            guard let template = session.configuration.terrainDEMURLTemplate,
                  !template.isEmpty
            else { return }

            let sourceID = "outdoor-terrain-dem-source"
            let layerID = "outdoor-terrain-hillshade-layer"
            let options: [MLNTileSourceOption: Any] = [
                .demEncoding: NSNumber(value: 1),
                .tileSize: NSNumber(value: 256)
            ]
            let source = MLNRasterDEMSource(
                identifier: sourceID,
                tileURLTemplates: [template],
                options: options
            )
            style.addSource(source)

            let hillshade = MLNHillshadeStyleLayer(identifier: layerID, source: source)
            hillshade.hillshadeMethod = NSExpression(forConstantValue: "multidirectional")
            hillshade.hillshadeIlluminationAnchor = NSExpression(forConstantValue: "map")
            hillshade.hillshadeExaggeration = NSExpression(forConstantValue: 0.24)
            hillshade.hillshadeAccentColor = NSExpression(
                forConstantValue: UIColor(red: 0.23, green: 0.27, blue: 0.23, alpha: 1)
            )
            hillshade.hillshadeHighlightColor = NSExpression(
                forConstantValue: UIColor(red: 0.97, green: 0.97, blue: 0.93, alpha: 1)
            )
            hillshade.hillshadeShadowColor = NSExpression(
                forConstantValue: UIColor(red: 0.46, green: 0.50, blue: 0.44, alpha: 1)
            )
            if let roadLayer = style.layers.first(where: { $0.identifier.hasPrefix("road") }) {
                style.insertLayer(hillshade, below: roadLayer)
            } else if let firstSymbol = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
                style.insertLayer(hillshade, below: firstSymbol)
            } else {
                style.addLayer(hillshade)
            }
            activeTileSourceIDs.insert(sourceID)
            activeTileSourceIDs.insert(layerID)
        }

        private func applyThreeDIfSupported(
            map: MLNMapView,
            style: MLNStyle,
            overlays: Set<OutdoorMapMode>
        ) {
            guard overlays.contains(.threeD) else {
                map.isPitchEnabled = false
                if didApplyThreeDCamera {
                    let camera = MLNMapCamera(
                        lookingAtCenter: map.centerCoordinate,
                        fromDistance: max(map.camera.altitude, 1),
                        pitch: 0,
                        heading: map.camera.heading
                    )
                    isApplyingCamera = true
                    map.setCamera(camera, animated: true)
                    isApplyingCamera = false
                }
                didApplyThreeDCamera = false
                return
            }

            let hasRealBuildingExtrusion = style.layers.contains {
                guard let layer = $0 as? MLNFillExtrusionStyleLayer else { return false }
                return layer.sourceLayerIdentifier != nil
            }
            let hasTerrainRelief = style.source(withIdentifier: "outdoor-terrain-dem-source") != nil
            guard hasRealBuildingExtrusion, hasTerrainRelief else {
                session.markThreeDUnsupported()
                reportCapability(session.capability(for: .threeD))
                return
            }

            session.markThreeDAvailable()
            map.isPitchEnabled = true
            if !didApplyThreeDCamera {
                let pitch = max(map.camera.pitch, 45)
                let camera = MLNMapCamera(
                    lookingAtCenter: map.centerCoordinate,
                    fromDistance: max(map.camera.altitude, 1),
                    pitch: min(pitch, 60),
                    heading: map.camera.heading
                )
                isApplyingCamera = true
                map.setCamera(camera, animated: false)
                isApplyingCamera = false
                didApplyThreeDCamera = true
            }
            reportCapability(session.capability(for: .threeD))
        }

        private func renderRouteOverlays(map: MLNMapView, style: MLNStyle) {
            updateLiveRoute(style: style, points: latestPoints)
            updatePlannedRoute(style: style, points: latestPlannedPoints)
            updateAnnotations(map: map, points: latestPoints, state: latestState)
        }

        private func updateLiveRoute(style: MLNStyle, points: [OutdoorTrackPoint]) {
            let sourceID = "live-route-source"
            let layerID = "live-route-line"
            let signature = RouteRenderSignature(points: points)
            guard signature != liveRouteSignature else { return }
            liveRouteSignature = signature
            guard points.count >= 2 else {
                remove(style: style, sourceID: sourceID, layerIDs: [layerID])
                return
            }
            let source = shapeSource(
                style: style,
                sourceID: sourceID,
                shape: MLNPolyline(coordinates: coordinates(for: points), count: UInt(points.count))
            )
            let layer: MLNLineStyleLayer
            if let existing = style.layer(withIdentifier: layerID) as? MLNLineStyleLayer {
                layer = existing
            } else {
                layer = MLNLineStyleLayer(identifier: layerID, source: source)
                style.addLayer(layer)
            }
            layer.lineColor = NSExpression(forConstantValue: OutdoorMinimalMapPalette.routeAccent)
            layer.lineWidth = NSExpression(
                format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                [8: 3.0, 14: 5.0, 18: 7.0]
            )
            layer.lineJoin = NSExpression(forConstantValue: "round")
            layer.lineCap = NSExpression(forConstantValue: "round")

        }
        private func updatePlannedRoute(style: MLNStyle, points: [OutdoorTrackPoint]) {
            let sourceID = "planned-route-source"
            let layerID = "planned-route-line"
            let signature = RouteRenderSignature(points: points)
            guard signature != plannedRouteSignature else { return }
            plannedRouteSignature = signature
            guard points.count >= 2 else {
                remove(style: style, sourceID: sourceID, layerIDs: [layerID])
                return
            }
            let source = shapeSource(
                style: style,
                sourceID: sourceID,
                shape: MLNPolyline(coordinates: coordinates(for: points), count: UInt(points.count))
            )
            let layer: MLNLineStyleLayer
            if let existing = style.layer(withIdentifier: layerID) as? MLNLineStyleLayer {
                layer = existing
            } else {
                layer = MLNLineStyleLayer(identifier: layerID, source: source)
                style.addLayer(layer)
            }
            layer.lineColor = NSExpression(forConstantValue: currentMinimalMapPalette.plannedRoute)
            layer.lineWidth = NSExpression(
                format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                [8: 2.0, 14: 3.0, 18: 4.0]
            )
            layer.lineDashPattern = NSExpression(forConstantValue: [1.5, 1.8])
            layer.lineJoin = NSExpression(forConstantValue: "round")
            layer.lineCap = NSExpression(forConstantValue: "round")
        }

        private func shapeSource(style: MLNStyle, sourceID: String, shape: MLNShape) -> MLNShapeSource {
            if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                source.shape = shape
                return source
            }
            let source = MLNShapeSource(identifier: sourceID, shape: shape, options: nil)
            style.addSource(source)
            return source
        }

        private func remove(style: MLNStyle, sourceID: String, layerIDs: [String]) {
            for layerID in layerIDs {
                if let layer = style.layer(withIdentifier: layerID) {
                    style.removeLayer(layer)
                }
            }
            if let source = style.source(withIdentifier: sourceID) {
                style.removeSource(source)
            }
        }

        private func updateAnnotations(
            map: MLNMapView,
            points: [OutdoorTrackPoint],
            state: OutdoorLocationRecorder.State
        ) {
            guard let first = points.first else {
                if let startAnnotation { map.removeAnnotation(startAnnotation) }
                if let endAnnotation { map.removeAnnotation(endAnnotation) }
                startAnnotation = nil
                endAnnotation = nil
                return
            }

            if let startAnnotation {
                startAnnotation.coordinate = coordinate(for: first)
                startAnnotation.title = "Start"
            } else {
                let annotation = MLNPointAnnotation()
                annotation.coordinate = coordinate(for: first)
                annotation.title = "Start"
                map.addAnnotation(annotation)
                startAnnotation = annotation
            }

            guard points.count > 1, let last = points.last else {
                if let endAnnotation { map.removeAnnotation(endAnnotation) }
                endAnnotation = nil
                return
            }
            if let endAnnotation {
                endAnnotation.coordinate = coordinate(for: last)
                endAnnotation.title = state == .finished ? "Finish" : "Current"
            } else {
                let annotation = MLNPointAnnotation()
                annotation.coordinate = coordinate(for: last)
                annotation.title = state == .finished ? "Finish" : "Current"
                map.addAnnotation(annotation)
                endAnnotation = annotation
            }
        }

        private func coordinates(for points: [OutdoorTrackPoint]) -> [CLLocationCoordinate2D] {
            points.map(coordinate(for:))
        }

        private func coordinate(for point: OutdoorTrackPoint) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }

        private func bounds(for points: [OutdoorTrackPoint]) -> MLNCoordinateBounds {
            let coordinates = points.map(coordinate(for:))
            var minLatitude = coordinates[0].latitude
            var maxLatitude = minLatitude
            var minLongitude = coordinates[0].longitude
            var maxLongitude = minLongitude
            for coordinate in coordinates.dropFirst() {
                minLatitude = min(minLatitude, coordinate.latitude)
                maxLatitude = max(maxLatitude, coordinate.latitude)
                minLongitude = min(minLongitude, coordinate.longitude)
                maxLongitude = max(maxLongitude, coordinate.longitude)
            }
            return MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude),
                ne: CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
            )
        }
    }
}
#endif
