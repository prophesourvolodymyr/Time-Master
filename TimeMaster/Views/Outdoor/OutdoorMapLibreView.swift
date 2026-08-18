#if os(iOS)
import SwiftUI
import MapLibre
import CoreLocation

/// A user-controlled outdoor map.
///
/// Recording changes the overlays, not the camera. The map is always
/// pannable, zoomable, and rotatable in a flat 2D view; the first GPS point
/// only provides an initial camera position.
struct OutdoorMapLibreView: UIViewRepresentable {
    var points: [OutdoorTrackPoint]
    var followsUser: Bool
    var state: OutdoorLocationRecorder.State
    var plannedPoints: [OutdoorTrackPoint]? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(
            frame: .zero,
            styleURL: OutdoorMapOfflineManager.defaultStyleURL
        )
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .none
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.minimumPitch = 0
        map.maximumPitch = 0
        map.isPitchEnabled = false
        map.minimumZoomLevel = 2
        map.maximumZoomLevel = 19
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.render(
            map: map,
            points: points,
            plannedPoints: plannedPoints ?? [],
            state: state,
            centerOnFirstPoint: followsUser
        )
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        private var latestPoints: [OutdoorTrackPoint] = []
        private var latestPlannedPoints: [OutdoorTrackPoint] = []
        private var latestState: OutdoorLocationRecorder.State = .idle
        private var latestCenterOnFirstPoint = false

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            guard let map else { return }
            for layer in style.layers.compactMap({ $0 as? MLNFillExtrusionStyleLayer }) {
                style.removeLayer(layer)
            }
            render(
                map: map,
                points: latestPoints,
                plannedPoints: latestPlannedPoints,
                state: latestState,
                centerOnFirstPoint: latestCenterOnFirstPoint
            )
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coordinate = userLocation?.location?.coordinate else { return }
            latestUserCoordinate = coordinate
            centerOnUserIfNeeded(map: mapView)
        }

        weak var map: MLNMapView?
        private var hasCenteredOnFirstPoint = false
        private var latestUserCoordinate: CLLocationCoordinate2D?
        private var hasCenteredOnUserLocation = false

        func render(
            map: MLNMapView,
            points: [OutdoorTrackPoint],
            plannedPoints: [OutdoorTrackPoint],
            state: OutdoorLocationRecorder.State,
            centerOnFirstPoint: Bool
        ) {
            let hadData = !latestPoints.isEmpty || !latestPlannedPoints.isEmpty
            latestPoints = points
            latestPlannedPoints = plannedPoints
            latestState = state
            latestCenterOnFirstPoint = centerOnFirstPoint

            if hadData && points.isEmpty && plannedPoints.isEmpty {
                hasCenteredOnFirstPoint = false
                hasCenteredOnUserLocation = false
            }

            guard let style = map.style else { return }

            updateLiveRoute(style: style, points: points)
            updatePlannedRoute(style: style, points: plannedPoints)
            updateAnnotations(map: map, points: points, state: state)

            if centerOnFirstPoint {
                if !hasCenteredOnFirstPoint, let first = points.first {
                    map.setCenter(
                        CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                        zoomLevel: 15,
                        animated: false
                    )
                    hasCenteredOnFirstPoint = true
                } else if !hasCenteredOnFirstPoint, points.isEmpty, !plannedPoints.isEmpty {
                    map.setVisibleCoordinateBounds(
                        bounds(for: plannedPoints),
                        edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 180, right: 40),
                        animated: false
                    )
                    hasCenteredOnFirstPoint = true
                } else if points.isEmpty && plannedPoints.isEmpty {
                    centerOnUserIfNeeded(map: map)
                }
            } else {
                hasCenteredOnFirstPoint = false
                let framingPoints = plannedPoints.isEmpty ? points : plannedPoints + points
                if !framingPoints.isEmpty {
                    map.setVisibleCoordinateBounds(
                        bounds(for: framingPoints),
                        edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 180, right: 40),
                        animated: false
                    )
                } else {
                    centerOnUserIfNeeded(map: map)
                }
            }
        }

        private func centerOnUserIfNeeded(map: MLNMapView) {
            guard
                let coordinate = latestUserCoordinate,
                map.style != nil,
                latestPoints.isEmpty,
                latestPlannedPoints.isEmpty,
                !hasCenteredOnUserLocation
            else {
                return
            }

            map.setCenter(coordinate, zoomLevel: 17, animated: false)
            hasCenteredOnUserLocation = true
        }

        private func updateLiveRoute(style: MLNStyle, points: [OutdoorTrackPoint]) {
            let sourceID = "live-route-source"
            let layerID = "live-route-line"
            guard points.count >= 2 else {
                remove(style: style, sourceID: sourceID, layerIDs: [layerID])
                return
            }

            let line = MLNPolyline(
                coordinates: coordinates(for: points),
                count: UInt(points.count)
            )
            let source = shapeSource(style: style, sourceID: sourceID, shape: line)
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
            guard points.count >= 2 else {
                remove(style: style, sourceID: sourceID, layerIDs: [layerID])
                return
            }

            let line = MLNPolyline(
                coordinates: coordinates(for: points),
                count: UInt(points.count)
            )
            let source = shapeSource(style: style, sourceID: sourceID, shape: line)
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

        private func shapeSource(
            style: MLNStyle,
            sourceID: String,
            shape: MLNShape
        ) -> MLNShapeSource {
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
            let existing = map.annotations?.filter { !($0 is MLNUserLocation) } ?? []
            map.removeAnnotations(existing)
            guard let first = points.first else { return }

            let start = MLNPointAnnotation()
            start.coordinate = coordinate(for: first)
            start.title = "Start"
            map.addAnnotation(start)

            guard let last = points.last, points.count > 1 else { return }
            let end = MLNPointAnnotation()
            end.coordinate = coordinate(for: last)
            end.title = state == .finished ? "Finish" : "Current"
            map.addAnnotation(end)
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
