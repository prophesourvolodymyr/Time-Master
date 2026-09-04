#if os(iOS)
import SwiftUI
import MapLibre
import CoreLocation

struct OutdoorMapLibreView: UIViewRepresentable {
    var points: [OutdoorTrackPoint]
    var followsUser: Bool
    var state: OutdoorLocationRecorder.State
    var plannedPoints: [OutdoorTrackPoint]? = nil
    var mode: OutdoorMapMode = .explore
    var overlayModes: Set<OutdoorMapMode> = []
    var focusRequestID: Int = 0
    var cityFitRequestID: Int = 0
    var weatherInfoEnabled: Bool = false
    var configuration: OutdoorMapProviderConfiguration = .main
    var onCapabilityChange: ((OutdoorMapCapability) -> Void)? = nil
    var onWeatherStateChange: ((OutdoorWeatherState) -> Void)? = nil
    var onFollowStateChange: ((Bool) -> Void)? = nil
    var onFocusFailure: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onCapabilityChange: onCapabilityChange,
            onWeatherStateChange: onWeatherStateChange,
            onFollowStateChange: onFollowStateChange,
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
                styleJSON: ##"{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#08101A"}}]}"##
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
            cityFitRequestID: cityFitRequestID,
            weatherInfoEnabled: weatherInfoEnabled
        )
    }

    @MainActor final class Coordinator: NSObject, MLNMapViewDelegate, CLLocationManagerDelegate {
        private let session: OutdoorMapSession
        private let weatherAdapter: OutdoorWeatherKitAdapter?
        private let onCapabilityChange: ((OutdoorMapCapability) -> Void)?
        private let onFollowStateChange: ((Bool) -> Void)?
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
        private var fallbackModeForPendingStyle: OutdoorMapMode?
        private var hasCenteredOnUser = false
        private var loadedStyleURL: URL?
        private var activeTileSourceIDs: Set<String> = []
        private var darkOverlayView: UIView?
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
            onFocusFailure: ((String) -> Void)?
        ) {
            session = OutdoorMapSession(configuration: configuration)
            self.onCapabilityChange = onCapabilityChange
            self.onFollowStateChange = onFollowStateChange
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
            darkOverlayView?.removeFromSuperview()
            darkOverlayView = nil
            self.map = map
            map.delegate = self
            map.showsUserLocation = true
            map.userTrackingMode = .none
            map.isScrollEnabled = true
            map.isZoomEnabled = true
            map.isRotateEnabled = true
            map.isPitchEnabled = true
            map.minimumPitch = 0
            map.maximumPitch = 60
            map.minimumZoomLevel = 2
            map.maximumZoomLevel = 19
            map.attributionButton.isHidden = true
            map.logoView.isHidden = true
            configuredStyleID = nil
            configuredMode = nil
            configuredStyleURL = nil
            configuredOverlays = []
            latestOverlayModes = []
            lastRenderedPointsSignature = nil
            lastRenderedPlannedPointsSignature = nil
            lastRenderedState = nil
            lastRenderedFollowsUser = nil
            lastRenderedMode = nil
            lastRenderedFocusRequestID = nil
            lastRenderedOverlayModes = nil
            lastRenderedCityFitRequestID = nil
            pendingCityFit = false
            lastRenderedWeatherInfoEnabled = nil
            didRenderInputs = false
            liveRouteSignature = nil
            plannedRouteSignature = nil
            didApplyThreeDCamera = false
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


        func render(
            map: MLNMapView,
            points: [OutdoorTrackPoint],
            plannedPoints: [OutdoorTrackPoint],
            state: OutdoorLocationRecorder.State,
            followsUser: Bool,
            mode: OutdoorMapMode,
            overlayModes: Set<OutdoorMapMode>,
            focusRequestID: Int,
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

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            loadedStyleURL = mapView.styleURL
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

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            guard !isApplyingCamera, mapView.userTrackingMode == .none else { return }
            session.userDidPan()
            reportFollowState(false)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            guard !isApplyingCamera else { return }
            session.captureCamera(from: mapView)
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

        private func updateWeather() {
            guard let adapter = weatherAdapter else { return }
            let location = latestUserCoordinate.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            }
            adapter.update(location: location, enabled: latestWeatherInfoEnabled)
        }

        private func configureProviderLayers(style: MLNStyle, overlays: Set<OutdoorMapMode>) {
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

            guard let baseDefinition = session.configuration.style(for: baseMode) else {
                updateDarkOverlay(on: map, overlays: overlays)
                return
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
                layer.predicate = NSPredicate(
                    format: "subclass == 'cycleway' OR class == 'cycleway' OR bicycle == 'designated'"
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemGreen)
                layer.lineWidth = NSExpression(
                    format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                    [8: 1.2, 14: 3.0, 18: 5.0]
                )
                layer.lineOpacity = NSExpression(forConstantValue: 0.9)
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
            updateDarkOverlay(on: map, overlays: overlays)
        }

        private func updateDarkOverlay(on map: MLNMapView?, overlays: Set<OutdoorMapMode>) {
            guard let map else {
                darkOverlayView?.removeFromSuperview()
                darkOverlayView = nil
                return
            }

            if overlays.contains(.dark) {
                let overlay = darkOverlayView ?? UIView()
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.30)
                overlay.isUserInteractionEnabled = false
                overlay.frame = map.bounds
                overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                if overlay.superview == nil {
                    map.addSubview(overlay)
                }
                darkOverlayView = overlay
            } else {
                darkOverlayView?.removeFromSuperview()
                darkOverlayView = nil
            }
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
            guard hasRealBuildingExtrusion else {
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
            if style.layer(withIdentifier: layerID) == nil {
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemBlue)
                layer.lineWidth = NSExpression(forConstantValue: 5)
                layer.lineJoin = NSExpression(forConstantValue: "round")
                layer.lineCap = NSExpression(forConstantValue: "round")
                style.addLayer(layer)
            }

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
            if style.layer(withIdentifier: layerID) == nil {
                let layer = MLNLineStyleLayer(identifier: layerID, source: source)
                layer.lineColor = NSExpression(forConstantValue: UIColor.systemOrange)
                layer.lineWidth = NSExpression(forConstantValue: 4)
                layer.lineDashPattern = NSExpression(forConstantValue: [2, 2])
                layer.lineJoin = NSExpression(forConstantValue: "round")
                layer.lineCap = NSExpression(forConstantValue: "round")
                style.addLayer(layer)
            }
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
