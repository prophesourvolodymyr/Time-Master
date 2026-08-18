#if os(iOS)
import Foundation
import MapLibre
import CoreLocation

/// Owns MapLibre offline packs and the small amount of metadata needed to
/// show whether an area has already been downloaded.
final class OutdoorMapOfflineManager {
    static let shared = OutdoorMapOfflineManager()

    static let defaultStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!

    private let metadataKey = "OutdoorOfflineRegions"
    private var pendingCompletions: [ObjectIdentifier: (Error?) -> Void] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(packProgressChanged(_:)),
            name: NSNotification.Name.MLNOfflinePackProgressChanged,
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

        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            guard let self else {
                completion?(error)
                return
            }
            guard let pack else {
                completion?(error)
                return
            }
            if let completion {
                if pack.state == .complete {
                    completion(nil)
                } else {
                    self.pendingCompletions[ObjectIdentifier(pack)] = completion
                }
            }
            pack.resume()
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
        styleURL: URL = OutdoorMapOfflineManager.defaultStyleURL,
        completion: ((Error?) -> Void)? = nil
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
            maxZoom: 16,
            completion: completion
        )
    }

    @objc private func packProgressChanged(_ note: Notification) {
        guard let pack = note.object as? MLNOfflinePack else {
            return
        }
        if pack.state == .invalid {
            let completion = pendingCompletions.removeValue(forKey: ObjectIdentifier(pack))
            completion?(NSError(
                domain: "OutdoorMapOffline",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MapLibre marked the offline pack invalid."]
            ))
            return
        }
        guard pack.state == .complete else {
            return
        }
        let data = pack.context
        if let metadata = try? JSONDecoder().decode(RegionMetadata.self, from: data) {
            var saved = loadMetadata()
            saved.removeAll { $0 == metadata }
            saved.append(metadata)
            if let encoded = try? JSONEncoder().encode(saved) {
                UserDefaults.standard.set(encoded, forKey: metadataKey)
            }
        }
        let completion = pendingCompletions.removeValue(forKey: ObjectIdentifier(pack))
        completion?(nil)
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
