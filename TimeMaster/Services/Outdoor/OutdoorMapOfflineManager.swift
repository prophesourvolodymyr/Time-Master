#if os(iOS)
import Foundation
import MapLibre
import CoreLocation
import Combine

final class OutdoorMapOfflineManager: ObservableObject {
    static let shared = OutdoorMapOfflineManager()


    enum OfflineError: LocalizedError {
        case invalidBounds
        case capabilityUnavailable(String)
        case unsupportedStyle(URL)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidBounds:
                return "The selected offline region bounds are invalid."
            case .capabilityUnavailable(let reason):
                return reason
            case .unsupportedStyle(let URL):
                return "No provider capability is configured for offline style \(URL.absoluteString)."
            case .cancelled:
                return "The offline map download was cancelled."
            }
        }
    }

    struct RegionMetadata: Codable, Equatable {
        var bounds: Bounds
        var minZoom: Int
        var maxZoom: Int
        var styleURL: String
        var downloadedAt: Date
        var provider: OutdoorMapProvider
        var capabilities: [OutdoorMapMode]
        var cacheRights: OutdoorMapCacheRights
        var attribution: OutdoorMapAttribution

        struct Bounds: Codable, Equatable {
            var swLat: Double
            var swLon: Double
            var neLat: Double
            var neLon: Double
        }

        init(
            bounds: Bounds,
            minZoom: Int,
            maxZoom: Int,
            styleURL: String,
            downloadedAt: Date,
            provider: OutdoorMapProvider = .openFreeMap,
            capabilities: [OutdoorMapMode] = [.explore],
            cacheRights: OutdoorMapCacheRights = .networkOnly,
            attribution: OutdoorMapAttribution = OutdoorMapAttribution(providerName: "Configured map provider")
        ) {
            self.bounds = bounds
            self.minZoom = minZoom
            self.maxZoom = maxZoom
            self.styleURL = styleURL
            self.downloadedAt = downloadedAt
            self.provider = provider
            self.capabilities = capabilities
            self.cacheRights = cacheRights
            self.attribution = attribution
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bounds = try container.decode(Bounds.self, forKey: .bounds)
            minZoom = try container.decode(Int.self, forKey: .minZoom)
            maxZoom = try container.decode(Int.self, forKey: .maxZoom)
            styleURL = try container.decode(String.self, forKey: .styleURL)
            downloadedAt = try container.decode(Date.self, forKey: .downloadedAt)
            provider = try container.decodeIfPresent(OutdoorMapProvider.self, forKey: .provider) ?? .openFreeMap
            capabilities = try container.decodeIfPresent([OutdoorMapMode].self, forKey: .capabilities) ?? [.explore]
            cacheRights = try container.decodeIfPresent(OutdoorMapCacheRights.self, forKey: .cacheRights) ?? .networkOnly
            attribution = try container.decodeIfPresent(OutdoorMapAttribution.self, forKey: .attribution)
                ?? OutdoorMapAttribution(providerName: "Configured map provider")
        }
    }

    struct DownloadProgress: Identifiable, Equatable {
        let id: UUID
        let provider: OutdoorMapProvider
        let modes: [OutdoorMapMode]
        var completedResources: UInt64
        var expectedResources: UInt64

        var fractionCompleted: Double {
            guard expectedResources > 0 else { return 0 }
            return min(1, Double(completedResources) / Double(expectedResources))
        }
    }

    private let configuration: OutdoorMapProviderConfiguration
    private let metadataKey = BackupOfflineRegionMetadata.storageKey
    @Published private(set) var activeDownloads: [DownloadProgress] = []
    private var pendingCompletions: [ObjectIdentifier: (Error?) -> Void] = [:]
    private var downloadIDsByPack: [ObjectIdentifier: UUID] = [:]
    private var packsByDownloadID: [UUID: MLNOfflinePack] = [:]

    init(configuration: OutdoorMapProviderConfiguration = .main) {
        self.configuration = configuration
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(packProgressChanged(_:)),
            name: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var installedRegions: [RegionMetadata] {
        reconciledMetadata()
    }

    func describeOfflineCapabilities(
        for bounds: MLNCoordinateBounds,
        modes: [OutdoorMapMode] = OutdoorMapMode.allCases
    ) -> [OutdoorMapCapability] {
        guard isValid(bounds) else { return [] }
        return modes.map { configuration.capability(for: $0) }
    }

    func canInstallOffline(
        mode: OutdoorMapMode,
        bounds: MLNCoordinateBounds
    ) -> Result<OutdoorMapCapability, Error> {
        guard isValid(bounds) else { return .failure(OfflineError.invalidBounds) }
        let capability = configuration.capability(for: mode)
        guard capability.isUsable else {
            return .failure(OfflineError.capabilityUnavailable(capability.reason ?? "The selected map mode is unavailable."))
        }
        guard capability.cacheRights.offlineInstallationAllowed else {
            return .failure(OfflineError.capabilityUnavailable(capability.cacheRights.explanation))
        }
        return .success(capability)
    }

    func requestOfflineRegion(
        bounds: MLNCoordinateBounds,
        mode: OutdoorMapMode = .explore,
        minZoom: Int,
        maxZoom: Int,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard case .success(let capability) = canInstallOffline(mode: mode, bounds: bounds) else {
            if case .failure(let error) = canInstallOffline(mode: mode, bounds: bounds) {
                completion?(error)
            }
            return
        }
        guard let style = configuration.style(for: mode) else {
            completion?(OfflineError.capabilityUnavailable("No renderable style is configured for \(mode.displayName)."))
            return
        }
        download(
            bounds: bounds,
            styleURL: offlineStyleURL(for: capability.provider, fallback: style.styleURL),
            minZoom: minZoom,
            maxZoom: maxZoom,
            provider: capability.provider,
            capabilities: [mode],
            cacheRights: capability.cacheRights,
            attribution: capability.attribution,
            completion: completion
        )
    }

    func downloadOfflineRegion(
        bounds: MLNCoordinateBounds,
        styleURL: URL,
        minZoom: Int,
        maxZoom: Int,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard isValid(bounds), minZoom >= 0, maxZoom >= minZoom else {
            completion?(OfflineError.invalidBounds)
            return
        }

        guard let match = configuredMode(for: styleURL) else {
            completion?(OfflineError.unsupportedStyle(styleURL))
            return
        }
        guard case .success(let capability) = canInstallOffline(mode: match.mode, bounds: bounds) else {
            if case .failure(let error) = canInstallOffline(mode: match.mode, bounds: bounds) {
                completion?(error)
            }
            return
        }
        download(
            bounds: bounds,
            styleURL: offlineStyleURL(for: capability.provider, fallback: styleURL),
            minZoom: minZoom,
            maxZoom: maxZoom,
            provider: capability.provider,
            capabilities: [match.mode],
            cacheRights: capability.cacheRights,
            attribution: capability.attribution,
            completion: completion
        )
    }

    func hasOfflinePack(
        near coordinate: CLLocationCoordinate2D,
        minZoom: Int = 10
    ) -> Bool {
        guard let packs = MLNOfflineStorage.shared.packs else { return false }
        return packs.contains { pack in
            guard let region = pack.region as? MLNTilePyramidOfflineRegion else { return false }
            guard pack.state == .active || pack.state == .complete else { return false }
            let bounds = region.bounds
            return contains(coordinate, in: bounds)
                && region.minimumZoomLevel <= Double(minZoom)
        }
    }

    func hasOfflinePack(
        near coordinate: CLLocationCoordinate2D,
        mode: OutdoorMapMode,
        minZoom: Int = 10
    ) -> Bool {
        guard let metadata = loadMetadata().first(where: {
            $0.capabilities.contains(mode)
                && $0.minZoom <= minZoom
                && contains(coordinate, in: $0.bounds)
                && $0.cacheRights.offlineInstallationAllowed
        }) else { return false }
        return hasOfflinePack(near: coordinate, minZoom: metadata.minZoom)
    }

    func downloadCurrentArea(
        center: CLLocationCoordinate2D,
        styleURL: URL,
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

    func cancelDownload(id: UUID) {
        guard let pack = packsByDownloadID.removeValue(forKey: id) else { return }
        let key = ObjectIdentifier(pack)
        pack.suspend()
        downloadIDsByPack.removeValue(forKey: key)
        activeDownloads.removeAll { $0.id == id }
        let completion = pendingCompletions.removeValue(forKey: key)
        MLNOfflineStorage.shared.removePack(pack) { _ in
            completion?(OfflineError.cancelled)
        }
    }

    @objc private func packProgressChanged(_ note: Notification) {
        guard let pack = note.object as? MLNOfflinePack else { return }
        let key = ObjectIdentifier(pack)
        if let id = downloadIDsByPack[key],
           let index = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads[index].completedResources = pack.progress.countOfResourcesCompleted
            activeDownloads[index].expectedResources = pack.progress.countOfResourcesExpected
        }
        if pack.state == .invalid {
            finishDownload(
                for: pack,
                error: OfflineError.capabilityUnavailable("MapLibre marked the provider pack invalid.")
            )
            return
        }
        guard pack.state == .complete else { return }
        if let metadata = try? JSONDecoder().decode(RegionMetadata.self, from: pack.context) {
            var saved = loadMetadata()
            saved.removeAll {
                $0.bounds == metadata.bounds
                    && $0.minZoom == metadata.minZoom
                    && $0.maxZoom == metadata.maxZoom
                    && $0.provider == metadata.provider
            }
            saved.append(metadata)
            saveMetadata(saved)
        }
        finishDownload(for: pack, error: nil)
    }

    private func download(
        bounds: MLNCoordinateBounds,
        styleURL: URL,
        minZoom: Int,
        maxZoom: Int,
        provider: OutdoorMapProvider,
        capabilities: [OutdoorMapMode],
        cacheRights: OutdoorMapCacheRights,
        attribution: OutdoorMapAttribution,
        completion: ((Error?) -> Void)?
    ) {
        guard isValid(bounds), minZoom >= 0, maxZoom >= minZoom else {
            completion?(OfflineError.invalidBounds)
            return
        }
        let downloadID = UUID()
        activeDownloads.append(
            DownloadProgress(
                id: downloadID,
                provider: provider,
                modes: capabilities,
                completedResources: 0,
                expectedResources: 0
            )
        )
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
            downloadedAt: Date(),
            provider: provider,
            capabilities: capabilities,
            cacheRights: cacheRights,
            attribution: attribution
        )
        let context = (try? JSONEncoder().encode(metadata)) ?? Data()
        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            guard let self else {
                completion?(error)
                return
            }
            guard let pack else {
                self.activeDownloads.removeAll { $0.id == downloadID }
                completion?(error)
                return
            }
            let key = ObjectIdentifier(pack)
            self.downloadIDsByPack[key] = downloadID
            self.packsByDownloadID[downloadID] = pack
            if let completion {
                self.pendingCompletions[key] = completion
            }
            if pack.state == .complete {
                var saved = self.loadMetadata()
                saved.removeAll {
                    $0.bounds == metadata.bounds
                        && $0.minZoom == metadata.minZoom
                        && $0.maxZoom == metadata.maxZoom
                        && $0.provider == metadata.provider
                }
                saved.append(metadata)
                self.saveMetadata(saved)
                self.finishDownload(for: pack, error: nil)
                return
            }
            pack.resume()
        }
    }

    private func offlineStyleURL(for provider: OutdoorMapProvider, fallback: URL) -> URL {
        guard provider == .mapTiler,
              configuration.mapTilerOfflineLicensed,
              let offlineStyleURL = configuration.mapTilerOfflineStyleURL else {
            return fallback
        }
        return offlineStyleURL
    }

    private func finishDownload(for pack: MLNOfflinePack, error: Error?) {
        let key = ObjectIdentifier(pack)
        if let id = downloadIDsByPack.removeValue(forKey: key) {
            packsByDownloadID.removeValue(forKey: id)
            activeDownloads.removeAll { $0.id == id }
        }
        let completion = pendingCompletions.removeValue(forKey: key)
        completion?(error)
    }

    private func configuredMode(for styleURL: URL) -> (mode: OutdoorMapMode, style: OutdoorMapStyleDefinition)? {
        for mode in OutdoorMapMode.allCases {
            guard let style = configuration.style(for: mode) else { continue }
            if style.styleURL == styleURL || style.styleURL.absoluteString == styleURL.absoluteString {
                return (mode, style)
            }
        }
        return nil
    }

    private func isValid(_ bounds: MLNCoordinateBounds) -> Bool {
        bounds.sw.latitude >= -90
            && bounds.ne.latitude <= 90
            && bounds.sw.latitude <= bounds.ne.latitude
            && bounds.sw.longitude >= -180
            && bounds.sw.longitude <= 180
            && bounds.ne.longitude >= -180
            && bounds.ne.longitude <= 180
    }

    private func contains(_ coordinate: CLLocationCoordinate2D, in bounds: MLNCoordinateBounds) -> Bool {
        let longitudeContains: Bool
        if bounds.sw.longitude <= bounds.ne.longitude {
            longitudeContains = coordinate.longitude >= bounds.sw.longitude && coordinate.longitude <= bounds.ne.longitude
        } else {
            longitudeContains = coordinate.longitude >= bounds.sw.longitude || coordinate.longitude <= bounds.ne.longitude
        }
        return coordinate.latitude >= bounds.sw.latitude
            && coordinate.latitude <= bounds.ne.latitude
            && longitudeContains
    }

    private func contains(_ coordinate: CLLocationCoordinate2D, in bounds: RegionMetadata.Bounds) -> Bool {
        let longitudeContains: Bool
        if bounds.swLon <= bounds.neLon {
            longitudeContains = coordinate.longitude >= bounds.swLon && coordinate.longitude <= bounds.neLon
        } else {
            longitudeContains = coordinate.longitude >= bounds.swLon || coordinate.longitude <= bounds.neLon
        }
        return coordinate.latitude >= bounds.swLat
            && coordinate.latitude <= bounds.neLat
            && longitudeContains
    }

    private func reconciledMetadata() -> [RegionMetadata] {
        guard let packs = MLNOfflineStorage.shared.packs else {
            saveMetadata([])
            return []
        }
        let metadata = packs.compactMap { pack -> RegionMetadata? in
            guard pack.state == .complete else { return nil }
            return try? JSONDecoder().decode(RegionMetadata.self, from: pack.context)
        }
        saveMetadata(metadata)
        return metadata
    }

    private func saveMetadata(_ metadata: [RegionMetadata]) {
        guard let encoded = try? JSONEncoder().encode(metadata) else { return }
        UserDefaults.standard.set(encoded, forKey: metadataKey)
    }

    private func loadMetadata() -> [RegionMetadata] {
        guard
            let data = UserDefaults.standard.data(forKey: metadataKey),
            let metadata = try? JSONDecoder().decode([RegionMetadata].self, from: data)
        else { return [] }
        return metadata
    }
}
#endif
