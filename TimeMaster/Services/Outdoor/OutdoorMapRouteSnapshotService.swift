#if os(iOS)
import UIKit
import MapLibre
import CoreLocation

@MainActor
final class OutdoorMapRouteSnapshotService {
    static let shared = OutdoorMapRouteSnapshotService()

    private let cache = NSCache<NSString, UIImage>()
    private var activeSnapshotters: [UUID: MLNMapSnapshotter] = [:]

    private init() {}

    func snapshot(
        points: [OutdoorTrackPoint],
        styleURL: URL,
        size: CGSize,
        cacheKey: String,
        completion: @escaping (UIImage?, Error?) -> Void
    ) {
        let resolvedCacheKey = "\(cacheKey)|\(styleURL.absoluteString)|\(Int(size.width.rounded()))x\(Int(size.height.rounded()))" as NSString
        if let image = cache.object(forKey: resolvedCacheKey) {
            completion(image, nil)
            return
        }

        guard let thumbnail = OutdoorRouteThumbnail(points: points) else {
            completion(nil, NSError(domain: "OutdoorMapSnapshot", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "A route snapshot requires at least two recorded points."
            ]))
            return
        }

        let bounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(
                latitude: thumbnail.bounds.swLatitude,
                longitude: thumbnail.bounds.swLongitude
            ),
            ne: CLLocationCoordinate2D(
                latitude: thumbnail.bounds.neLatitude,
                longitude: thumbnail.bounds.neLongitude
            )
        )
        let center = CLLocationCoordinate2D(
            latitude: (thumbnail.bounds.swLatitude + thumbnail.bounds.neLatitude) / 2,
            longitude: (thumbnail.bounds.swLongitude + thumbnail.bounds.neLongitude) / 2
        )
        let camera = MLNMapCamera(
            lookingAtCenter: center,
            fromDistance: 1_000,
            pitch: 0,
            heading: 0
        )
        let options = MLNMapSnapshotOptions(styleURL: styleURL, camera: camera, size: size)
        options.coordinateBounds = bounds
        options.showsAttribution = true
        options.showsLogo = true

        let snapshotter = MLNMapSnapshotter(options: options)
        let snapshotID = UUID()
        activeSnapshotters[snapshotID] = snapshotter
        snapshotter.start(overlayHandler: { overlay in
            let context = overlay.context
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            for (index, point) in thumbnail.points.enumerated() {
                let projected = overlay.point(for: CLLocationCoordinate2D(
                    latitude: point.latitude,
                    longitude: point.longitude
                ))
                if index == 0 {
                    context.move(to: projected)
                } else {
                    context.addLine(to: projected)
                }
            }
            context.strokePath()
        }, completionHandler: { [weak self] snapshot, error in
            guard let self else { return }
            activeSnapshotters.removeValue(forKey: snapshotID)
            if let image = snapshot?.image {
                cache.setObject(image, forKey: resolvedCacheKey)
                completion(image, nil)
            } else {
                completion(nil, error)
            }
        })
    }

    func tripSnapshot(_ route: PlannedRoute, styleURL: URL, size: CGSize) async throws -> UIImage {
        guard route.trip?.isRouted != false, let thumbnail = OutdoorRouteThumbnail(points: route.points) else {
            throw TripServiceError.message("Finish calculating the trip before exporting its map.")
        }
        let cacheKey = "trip|\(route.id)|\(route.trip?.routedAt?.timeIntervalSince1970 ?? route.createdAt.timeIntervalSince1970)|\(styleURL)|\(Int(size.width))x\(Int(size.height))" as NSString
        if let image = cache.object(forKey: cacheKey) { return image }
        let latitudePadding = max(0.002, (thumbnail.bounds.neLatitude - thumbnail.bounds.swLatitude) * 0.14)
        let longitudePadding = max(0.002, (thumbnail.bounds.neLongitude - thumbnail.bounds.swLongitude) * 0.14)
        let camera = MLNMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(
                latitude: (thumbnail.bounds.swLatitude + thumbnail.bounds.neLatitude) / 2,
                longitude: (thumbnail.bounds.swLongitude + thumbnail.bounds.neLongitude) / 2
            ), fromDistance: 1_000, pitch: 0, heading: 0
        )
        let options = MLNMapSnapshotOptions(styleURL: styleURL, camera: camera, size: size)
        options.coordinateBounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: max(-85, thumbnail.bounds.swLatitude - latitudePadding), longitude: max(-180, thumbnail.bounds.swLongitude - longitudePadding)),
            ne: CLLocationCoordinate2D(latitude: min(85, thumbnail.bounds.neLatitude + latitudePadding), longitude: min(180, thumbnail.bounds.neLongitude + longitudePadding))
        )
        options.scale = 1
        options.showsAttribution = true
        options.showsLogo = false
        let snapshotter = MLNMapSnapshotter(options: options)
        let id = UUID()
        activeSnapshotters[id] = snapshotter
        return try await withCheckedThrowingContinuation { continuation in
            snapshotter.start(overlayHandler: { overlay in
                OutdoorTripMapStyle.draw(route, on: overlay)
            }, completionHandler: { [weak self] snapshot, error in
                MainActor.assumeIsolated {
                    self?.activeSnapshotters.removeValue(forKey: id)
                    if let image = snapshot?.image {
                        self?.cache.setObject(image, forKey: cacheKey)
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: error ?? TripServiceError.message("The offline map image could not be rendered."))
                    }
                }
            })
        }
    }
}
#endif
