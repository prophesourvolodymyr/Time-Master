import Foundation

enum OutdoorMapMode: String, CaseIterable, Codable, Identifiable {
    case explore
    case terrain
    case satellite
    case threeD
    case transit
    case traffic
    case cycling
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explore: "Explore"
        case .terrain: "Terrain"
        case .satellite: "Satellite"
        case .threeD: "3D"
        case .transit: "Transit"
        case .traffic: "Traffic"
        case .cycling: "Cycling"
        case .dark: "Dark"
        }
    }

    var systemImageName: String {
        switch self {
        case .explore: "map"
        case .terrain: "mountain.2"
        case .satellite: "globe.americas"
        case .threeD: "building.2"
        case .transit: "tram"
        case .traffic: "car"
        case .cycling: "bicycle"
        case .dark: "moon"
        }
    }

    static let allCases: [OutdoorMapMode] = [
        .explore,
        .terrain,
        .satellite,
        .threeD,
        .transit,
        .traffic,
        .cycling,
        .dark
    ]
    static let baseModes: [OutdoorMapMode] = [.explore, .terrain, .satellite]
    static let overlayModes: [OutdoorMapMode] = [.cycling, .transit, .traffic, .threeD, .dark]

    var isBaseMapView: Bool {
        Self.baseModes.contains(self)
    }

    var isMapOverlay: Bool {
        Self.overlayModes.contains(self)
    }
}

enum OutdoorMapProvider: String, Codable {
    case openFreeMap
    case openTopoMap
    case esri
    case mapTiler
    case tomTom
    case licensedTransit
    case device
}

enum OutdoorMapCapabilityStatus: String, Codable {
    case available
    case missingCredential
    case missingEndpoint
    case unsupported
    case limitedCoverage
    case networkRequired
    case providerError
}

enum OutdoorMapCoverage: String, Codable {
    case global
    case configuredRegions
    case providerDefined
    case unknown
}

enum OutdoorMapCachePermission: String, Codable {
    case notAllowed
    case temporaryOnly
    case providerManaged
    case allowed
}

struct OutdoorMapCacheRights: Codable, Equatable {
    var networkRequired: Bool
    var cachePermission: OutdoorMapCachePermission
    var offlineInstallationAllowed: Bool
    var explanation: String

    static let networkOnly = OutdoorMapCacheRights(
        networkRequired: true,
        cachePermission: .notAllowed,
        offlineInstallationAllowed: false,
        explanation: "This provider permits online display only."
    )
}

struct OutdoorMapFreshness: Codable, Equatable {
    var maximumAge: TimeInterval?
    var lastUpdated: Date?

    func isCurrent(at date: Date = Date()) -> Bool {
        guard let maximumAge, let lastUpdated else { return true }
        return date.timeIntervalSince(lastUpdated) <= maximumAge
    }
}

struct OutdoorMapAttribution: Codable, Equatable {
    var providerName: String
    var notices: [String]
    var URLs: [URL]

    init(providerName: String, notices: [String] = [], URLs: [URL] = []) {
        self.providerName = providerName
        self.notices = notices
        self.URLs = URLs
    }
}

struct OutdoorMapCapability: Codable, Equatable, Identifiable {
    var mode: OutdoorMapMode
    var provider: OutdoorMapProvider
    var status: OutdoorMapCapabilityStatus
    var reason: String?
    var attribution: OutdoorMapAttribution
    var cacheRights: OutdoorMapCacheRights
    var freshness: OutdoorMapFreshness
    var coverage: OutdoorMapCoverage

    var id: String { mode.rawValue }
    var isUsable: Bool {
        status == .available || status == .limitedCoverage
    }

    static func unavailable(
        mode: OutdoorMapMode,
        provider: OutdoorMapProvider,
        status: OutdoorMapCapabilityStatus,
        reason: String,
        attribution: OutdoorMapAttribution,
        cacheRights: OutdoorMapCacheRights = .networkOnly,
        coverage: OutdoorMapCoverage = .unknown,
        freshness: OutdoorMapFreshness = .init(maximumAge: nil, lastUpdated: nil)
    ) -> OutdoorMapCapability {
        OutdoorMapCapability(
            mode: mode,
            provider: provider,
            status: status,
            reason: reason,
            attribution: attribution,
            cacheRights: cacheRights,
            freshness: freshness,
            coverage: coverage
        )
    }
}

struct OutdoorMapStyleDefinition: Equatable {
    var styleURL: URL
    var rasterTileURLTemplate: String?
    var vectorTileURLTemplate: String?
    var vectorSourceLayer: String?
    var attribution: OutdoorMapAttribution
}

struct OutdoorMapModeSelection: Equatable {
    var requestedMode: OutdoorMapMode
    var activeMode: OutdoorMapMode
    var capability: OutdoorMapCapability
    var style: OutdoorMapStyleDefinition?
    var shouldReloadStyle: Bool
}

struct OutdoorOfflineRegionDescriptor: Codable, Equatable, Identifiable {
    var bounds: OutdoorMapRegionBounds
    var minZoom: Int
    var maxZoom: Int
    var provider: OutdoorMapProvider
    var capabilities: [OutdoorMapMode]
    var cacheRights: OutdoorMapCacheRights
    var attribution: OutdoorMapAttribution
    var downloadedAt: Date

    var id: String {
        [
            String(bounds.swLatitude), String(bounds.swLongitude),
            String(bounds.neLatitude), String(bounds.neLongitude),
            provider.rawValue, String(minZoom), String(maxZoom)
        ].joined(separator: ":")
    }
}

struct OutdoorMapRegionBounds: Codable, Equatable {
    var swLatitude: Double
    var swLongitude: Double
    var neLatitude: Double
    var neLongitude: Double
}

struct OutdoorRouteThumbnail: Equatable {
    var points: [OutdoorTrackPoint]
    var bounds: OutdoorMapRegionBounds

    var isAvailable: Bool { points.count >= 2 }

    init?(points: [OutdoorTrackPoint]) {
        guard points.count >= 2 else { return nil }
        self.points = points
        let first = points[0]
        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var minLongitude = first.longitude
        var maxLongitude = first.longitude
        for point in points.dropFirst() {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            minLongitude = min(minLongitude, point.longitude)
            maxLongitude = max(maxLongitude, point.longitude)
        }
        bounds = OutdoorMapRegionBounds(
            swLatitude: minLatitude,
            swLongitude: minLongitude,
            neLatitude: maxLatitude,
            neLongitude: maxLongitude
        )
    }
}
