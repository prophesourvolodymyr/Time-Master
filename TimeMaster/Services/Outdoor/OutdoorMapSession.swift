#if os(iOS)
import Foundation
import CoreLocation
import MapLibre

final class OutdoorMapSession {
    let configuration: OutdoorMapProviderConfiguration

    private(set) var requestedMode: OutdoorMapMode = .explore
    private(set) var activeMode: OutdoorMapMode = .explore
    private(set) var requestedCapability: OutdoorMapCapability
    private(set) var cameraState: OutdoorMapCameraState?
    private(set) var followsUser = false
    private(set) var userExitedFollow = false
    private(set) var heading: CLLocationDirection?
    private(set) var lastUsableStyleURL: URL?

    private var dynamicCapabilities: [OutdoorMapMode: OutdoorMapCapability] = [:]
    private(set) var hasFramedInitialRoute = false

    init(configuration: OutdoorMapProviderConfiguration = .main) {
        self.configuration = configuration
        requestedCapability = configuration.capability(for: .explore)
        lastUsableStyleURL = configuration.style(for: .explore)?.styleURL
    }

    func capability(for mode: OutdoorMapMode) -> OutdoorMapCapability {
        dynamicCapabilities[mode] ?? configuration.capability(for: mode)
    }

    func requestMode(_ mode: OutdoorMapMode) -> OutdoorMapModeSelection {
        requestedMode = mode
        requestedCapability = mode == .direction
            ? configuration.capability(for: mode)
            : capability(for: mode)
        guard requestedCapability.isUsable else {
            return OutdoorMapModeSelection(
                requestedMode: mode,
                activeMode: activeMode,
                capability: requestedCapability,
                style: nil,
                shouldReloadStyle: false
            )
        }

        let style = configuration.style(for: mode)
        if mode == .direction {
            activeMode = mode
            return OutdoorMapModeSelection(
                requestedMode: mode,
                activeMode: activeMode,
                capability: requestedCapability,
                style: nil,
                shouldReloadStyle: false
            )
        }

        guard let style else {
            let unavailable = OutdoorMapCapability.unavailable(
                mode: mode,
                provider: requestedCapability.provider,
                status: .missingEndpoint,
                reason: "The selected mode has no renderable style or tile endpoint.",
                attribution: requestedCapability.attribution,
                cacheRights: requestedCapability.cacheRights,
                coverage: requestedCapability.coverage,
                freshness: requestedCapability.freshness
            )
            requestedCapability = unavailable
            return OutdoorMapModeSelection(
                requestedMode: mode,
                activeMode: activeMode,
                capability: unavailable,
                style: nil,
                shouldReloadStyle: false
            )
        }

        let shouldReload = activeMode != mode || lastUsableStyleURL != style.styleURL
        activeMode = mode
        lastUsableStyleURL = style.styleURL
        return OutdoorMapModeSelection(
            requestedMode: mode,
            activeMode: activeMode,
            capability: requestedCapability,
            style: style,
            shouldReloadStyle: shouldReload
        )
    }

    func markProviderFailure(_ mode: OutdoorMapMode, reason: String) {
        let base = capability(for: mode)
        dynamicCapabilities[mode] = OutdoorMapCapability(
            mode: mode,
            provider: base.provider,
            status: .providerError,
            reason: reason,
            attribution: base.attribution,
            cacheRights: base.cacheRights,
            freshness: base.freshness,
            coverage: base.coverage
        )
        requestedMode = mode
        requestedCapability = dynamicCapabilities[mode]!
    }

    func markThreeDUnsupported() {
        let base = capability(for: .threeD)
        dynamicCapabilities[.threeD] = OutdoorMapCapability(
            mode: .threeD,
            provider: base.provider,
            status: .unsupported,
            reason: "The loaded vector style does not expose real building extrusion data.",
            attribution: base.attribution,
            cacheRights: base.cacheRights,
            freshness: base.freshness,
            coverage: base.coverage
        )
    }

    func markDirectionUnavailable(_ reason: String) {
        let base = configuration.capability(for: .direction)
        dynamicCapabilities[.direction] = OutdoorMapCapability(
            mode: .direction,
            provider: .device,
            status: .unsupported,
            reason: reason,
            attribution: base.attribution,
            cacheRights: base.cacheRights,
            freshness: base.freshness,
            coverage: base.coverage
        )
        requestedCapability = dynamicCapabilities[.direction]!
    }

    func markDirectionAvailable() {
        dynamicCapabilities[.direction] = configuration.capability(for: .direction)
        requestedCapability = dynamicCapabilities[.direction]!
    }

    func markThreeDAvailable() {
        dynamicCapabilities[.threeD] = configuration.capability(for: .threeD)
    }

    func captureCamera(from map: MLNMapView) {
        let camera = map.camera
        cameraState = OutdoorMapCameraState(
            center: map.centerCoordinate,
            zoomLevel: map.zoomLevel,
            altitude: camera.altitude,
            pitch: camera.pitch,
            heading: camera.heading
        )
    }

    func restoreCamera(on map: MLNMapView) {
        guard let cameraState else { return }
        let camera = MLNMapCamera(
            lookingAtCenter: cameraState.center,
            fromDistance: max(cameraState.altitude, 1),
            pitch: cameraState.pitch,
            heading: cameraState.heading
        )
        map.setCamera(camera, animated: false)
    }

    func setFollowRequested(_ requested: Bool) {
        if !requested {
            followsUser = false
            userExitedFollow = false
            return
        }
        guard !userExitedFollow else { return }
        followsUser = true
    }

    func markFollowActive() {
        followsUser = true
        userExitedFollow = false
    }

    func userDidPan() {
        followsUser = false
        userExitedFollow = true
    }

    func updateHeading(_ heading: CLLocationDirection?) {
        self.heading = heading
    }

    func resetFollowAfterExplicitFocus() {
        userExitedFollow = false
        followsUser = true
    }

    func shouldFrameRoute(hasRoute: Bool) -> Bool {
        guard hasRoute, !hasFramedInitialRoute else { return false }
        hasFramedInitialRoute = true
        return true
    }

    func resetRouteFrameIfEmpty(_ hasRoute: Bool) {
        if !hasRoute {
            hasFramedInitialRoute = false
        }
    }

    func routeThumbnail(for points: [OutdoorTrackPoint]) -> OutdoorRouteThumbnail? {
        OutdoorRouteThumbnail(points: points)
    }
}

struct OutdoorMapCameraState {
    var center: CLLocationCoordinate2D
    var zoomLevel: Double
    var altitude: CLLocationDistance
    var pitch: CGFloat
    var heading: CLLocationDirection
}
#endif
