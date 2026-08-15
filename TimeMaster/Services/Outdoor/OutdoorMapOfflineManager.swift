#if os(iOS)
import Foundation
import MapLibre
import CoreLocation

/// Owns MapLibre offline packs and the small amount of metadata needed to
/// show whether an area has already been downloaded.
final class OutdoorMapOfflineManager {
    static let shared = OutdoorMapOfflineManager()

    private let metadataKey = "OutdoorOfflineRegions"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(packProgressChanged(_:)),
            name: Notification.Name("MLNOfflinePackProgressChangedNotification"),
            object: nil
        )
    }

    struct RegionMetadata: Codable, Equatable {
        var bounds: Bounds
        var minZoom: Int
        var maxZoom: Int
        var styleURL: String
        var downloadedAt: Date

        struct Bounds: Codable, Equatable {
            var swLat: Double
            var swLon: Double
            var neLat: Double
            var neLon: Double
        }
    }

    func downloadOfflineRegion(
        bounds: MLNCoordinateBounds,
        styleURL: URL,
        minZoom: Int,
        maxZoom: Int,
        completion: ((Error?) -> Void)? = nil
    ) {
        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: Double(minZoom),
            toZoomLevel: Double(maxZoom)
        )
        let metadata = RegionMetadata(
            bounds: .init(
                swLat: bounds.sw.latitude,
                swLon: bounds.sw.longitude,
                neLat: bounds.ne.latitude,
                neLon: bounds.ne.longitude
            ),
            minZoom: minZoom,
            maxZoom: maxZoom,
            styleURL: styleURL.absoluteString,
            downloadedAt: Date()
        )
        let context = (try? JSONEncoder().encode(metadata)) ?? Data()

        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { pack, error in
            guard let pack else {
                completion?(error)
                return
            }
            pack.resume()
            completion?(nil)
        }
    }

    func hasOfflinePack(
        near coordinate: CLLocationCoordinate2D,
        minZoom: Int = 10
    ) -> Bool {
        guard let packs = MLNOfflineStorage.shared.packs else { return false }
        return packs.contains { pack in
            guard let region = pack.region as? MLNTilePyramidOfflineRegion else {
                return false
            }
            let isUsable = pack.state == .active || pack.state == .complete
            let bounds = region.bounds
            let withinLatitude = coordinate.latitude >= bounds.sw.latitude
                && coordinate.latitude <= bounds.ne.latitude
            let withinLongitude = coordinate.longitude >= bounds.sw.longitude
                && coordinate.longitude <= bounds.ne.longitude
            return isUsable
                && region.minimumZoomLevel <= Double(minZoom)
                && withinLatitude
                && withinLongitude
        }
    }

    /// Convenience entry point for a future Settings screen.
    func downloadCurrentArea(
        center: CLLocationCoordinate2D,
        styleURL: URL = URL(string: "https://demotiles.maplibre.org/style.json")!
    ) {
        let delta = 0.05
        let bounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(
                latitude: center.latitude - delta,
                longitude: center.longitude - delta
            ),
            ne: CLLocationCoordinate2D(
                latitude: center.latitude + delta,
                longitude: center.longitude + delta
            )
        )
        downloadOfflineRegion(
            bounds: bounds,
            styleURL: styleURL,
            minZoom: 10,
            maxZoom: 16
        )
    }

    @objc private func packProgressChanged(_ note: Notification) {
        guard
            let pack = note.object as? MLNOfflinePack,
            pack.state == .complete
        else {
            return
        }
        let data = pack.context
        guard let metadata = try? JSONDecoder().decode(RegionMetadata.self, from: data) else {
            return
        }
        var saved = loadMetadata()
        saved.removeAll { $0 == metadata }
        saved.append(metadata)
        if let encoded = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(encoded, forKey: metadataKey)
        }
    }

    private func loadMetadata() -> [RegionMetadata] {
        guard
            let data = UserDefaults.standard.data(forKey: metadataKey),
            let metadata = try? JSONDecoder().decode([RegionMetadata].self, from: data)
        else {
            return []
        }
        return metadata
    }
}
#endif
