import Foundation

struct OutdoorMapProviderConfiguration {
    static let infoKeys = InfoKeys()

    struct InfoKeys {
        let exploreStyleURL = "TMExploreStyleURL"
        let exploreOfflineAllowed = "TMExploreOfflineAllowed"
        let mapTilerKey = "TMMapTilerKey"
        let mapTilerTerrainStyleURL = "TMMapTilerTerrainStyleURL"
        let mapTilerSatelliteStyleURL = "TMMapTilerSatelliteStyleURL"
        let mapTilerThreeDStyleURL = "TMMapTilerThreeDStyleURL"
        let mapTilerCyclingStyleURL = "TMMapTilerCyclingStyleURL"
        let mapTilerDarkStyleURL = "TMMapTilerDarkStyleURL"
        let mapTilerOfflineStyleURL = "TMMapTilerOfflineStyleURL"
        let mapTilerOfflineLicensed = "TMMapTilerOfflineLicensed"
        let terrainRasterTileURL = "TMTerrainRasterTileURL"
        let satelliteRasterTileURL = "TMSatelliteRasterTileURL"
        let tomTomTrafficTileURL = "TMTomTomTrafficTileURL"
        let tomTomTrafficKey = "TMTomTomTrafficKey"
        let tomTomTrafficSourceLayer = "TMTomTomTrafficSourceLayer"
        let transitFeedURL = "TMLicensedTransitFeedURL"
        let transitTileURL = "TMLicensedTransitTileURL"
        let transitSourceLayer = "TMLicensedTransitSourceLayer"
        let transitAttribution = "TMLicensedTransitAttribution"
    }

    let exploreStyleURL: URL?
    let exploreOfflineAllowed: Bool
    let mapTilerKey: String?
    let mapTilerTerrainStyleURL: URL?
    let mapTilerSatelliteStyleURL: URL?
    let mapTilerThreeDStyleURL: URL?
    let mapTilerCyclingStyleURL: URL?
    let mapTilerDarkStyleURL: URL?
    let mapTilerOfflineStyleURL: URL?
    let mapTilerOfflineLicensed: Bool
    let terrainRasterTileURLTemplate: String?
    let satelliteRasterTileURLTemplate: String?
    let tomTomTrafficTileURLTemplate: String?
    let tomTomTrafficKey: String?
    let tomTomTrafficSourceLayer: String
    let licensedTransitFeedURL: URL?
    let licensedTransitTileURLTemplate: String?
    let licensedTransitSourceLayer: String
    let licensedTransitAttribution: String

    static var main: OutdoorMapProviderConfiguration {
        OutdoorMapProviderConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        let keys = Self.infoKeys
        exploreStyleURL = Self.url(infoDictionary[keys.exploreStyleURL])
        exploreOfflineAllowed = Self.bool(infoDictionary[keys.exploreOfflineAllowed])
        mapTilerKey = Self.secretLikeValue(infoDictionary[keys.mapTilerKey])
        mapTilerTerrainStyleURL = Self.url(infoDictionary[keys.mapTilerTerrainStyleURL])
        mapTilerSatelliteStyleURL = Self.url(infoDictionary[keys.mapTilerSatelliteStyleURL])
        mapTilerThreeDStyleURL = Self.url(infoDictionary[keys.mapTilerThreeDStyleURL])
        mapTilerCyclingStyleURL = Self.url(infoDictionary[keys.mapTilerCyclingStyleURL])
        mapTilerDarkStyleURL = Self.url(infoDictionary[keys.mapTilerDarkStyleURL])
        mapTilerOfflineStyleURL = Self.url(infoDictionary[keys.mapTilerOfflineStyleURL])
        mapTilerOfflineLicensed = Self.bool(infoDictionary[keys.mapTilerOfflineLicensed])
        terrainRasterTileURLTemplate = Self.template(infoDictionary[keys.terrainRasterTileURL])
        satelliteRasterTileURLTemplate = Self.template(infoDictionary[keys.satelliteRasterTileURL])
        tomTomTrafficTileURLTemplate = Self.template(infoDictionary[keys.tomTomTrafficTileURL])
        tomTomTrafficKey = Self.secretLikeValue(infoDictionary[keys.tomTomTrafficKey])
        tomTomTrafficSourceLayer = Self.value(infoDictionary[keys.tomTomTrafficSourceLayer]) ?? "flow"
        licensedTransitFeedURL = Self.url(infoDictionary[keys.transitFeedURL])
        licensedTransitTileURLTemplate = Self.template(infoDictionary[keys.transitTileURL])
        licensedTransitSourceLayer = Self.value(infoDictionary[keys.transitSourceLayer]) ?? "transit"
        licensedTransitAttribution = Self.value(infoDictionary[keys.transitAttribution]) ?? "Licensed transit provider"
    }

    func capability(for mode: OutdoorMapMode) -> OutdoorMapCapability {
        switch mode {
        case .explore:
            guard let exploreStyleURL else {
                return .unavailable(
                    mode: mode,
                    provider: .openFreeMap,
                    status: .missingEndpoint,
                    reason: "Explore style endpoint is not configured.",
                    attribution: openFreeMapAttribution,
                    cacheRights: .networkOnly
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: .openFreeMap,
                status: .available,
                reason: nil,
                attribution: openFreeMapAttribution,
                cacheRights: exploreOfflineAllowed ? openFreeMapOfflineRights : .networkOnly,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .terrain:
            if mapTilerKey != nil, mapTilerTerrainStyleURL != nil {
                return mapTilerCapability(mode: mode, coverage: .providerDefined, cacheRights: mapTilerCacheRights)
            }
            guard exploreStyleURL != nil, terrainRasterTileURLTemplate != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .openTopoMap,
                    status: .missingEndpoint,
                    reason: "No terrain map endpoint is configured.",
                    attribution: openTopoMapAttribution
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: .openTopoMap,
                status: .available,
                reason: nil,
                attribution: openTopoMapAttribution,
                cacheRights: .networkOnly,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .satellite:
            if mapTilerKey != nil, mapTilerSatelliteStyleURL != nil {
                return mapTilerCapability(mode: mode, coverage: .providerDefined, cacheRights: mapTilerCacheRights)
            }
            guard exploreStyleURL != nil, satelliteRasterTileURLTemplate != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .esri,
                    status: .missingEndpoint,
                    reason: "No satellite map endpoint is configured.",
                    attribution: esriAttribution
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: .esri,
                status: .available,
                reason: nil,
                attribution: esriAttribution,
                cacheRights: .networkOnly,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .threeD:
            if mapTilerThreeDStyleURL != nil, mapTilerKey == nil {
                return missingMapTilerCredential(for: mode)
            }
            guard exploreStyleURL != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .openFreeMap,
                    status: .missingEndpoint,
                    reason: "A vector style with building data is required for 3D.",
                    attribution: openFreeMapAttribution
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: mapTilerThreeDStyleURL == nil ? .openFreeMap : .mapTiler,
                status: .available,
                reason: nil,
                attribution: mapTilerThreeDStyleURL == nil ? openFreeMapAttribution : mapTilerAttribution,
                cacheRights: mapTilerThreeDStyleURL == nil ? (exploreOfflineAllowed ? openFreeMapOfflineRights : .networkOnly) : mapTilerCacheRights,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .transit:
            guard exploreStyleURL != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .openFreeMap,
                    status: .missingEndpoint,
                    reason: "A vector map style with transport data is not configured.",
                    attribution: openFreeMapAttribution
                )
            }
            let usesLicensedFeed = licensedTransitFeedURL != nil && licensedTransitTileURLTemplate != nil
            return OutdoorMapCapability(
                mode: mode,
                provider: usesLicensedFeed ? .licensedTransit : .openFreeMap,
                status: .available,
                reason: usesLicensedFeed ? nil : "Showing mapped public transport infrastructure; live departures are not configured.",
                attribution: usesLicensedFeed ? transitAttribution : openFreeMapAttribution,
                cacheRights: .networkOnly,
                freshness: .init(maximumAge: usesLicensedFeed ? 30 : nil, lastUpdated: nil),
                coverage: usesLicensedFeed ? .configuredRegions : .global
            )

        case .traffic:
            guard tomTomTrafficKey != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .tomTom,
                    status: .missingCredential,
                    reason: "A TomTom traffic key is not configured.",
                    attribution: tomTomAttribution,
                    cacheRights: .networkOnly,
                    coverage: .providerDefined,
                    freshness: .init(maximumAge: 300, lastUpdated: nil)
                )
            }
            guard tomTomTrafficTileURLTemplate != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .tomTom,
                    status: .missingEndpoint,
                    reason: "A TomTom traffic tile endpoint is not configured.",
                    attribution: tomTomAttribution,
                    cacheRights: .networkOnly,
                    coverage: .providerDefined,
                    freshness: .init(maximumAge: 300, lastUpdated: nil)
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: .tomTom,
                status: .available,
                reason: nil,
                attribution: tomTomAttribution,
                cacheRights: .networkOnly,
                freshness: .init(maximumAge: 300, lastUpdated: nil),
                coverage: .providerDefined
            )

        case .cycling:
            guard exploreStyleURL != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .openFreeMap,
                    status: .missingEndpoint,
                    reason: "A shared vector style with cycling attributes is not configured.",
                    attribution: openFreeMapAttribution
                )
            }
            if mapTilerCyclingStyleURL != nil, mapTilerKey == nil {
                return missingMapTilerCredential(for: mode)
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: mapTilerCyclingStyleURL == nil ? .openFreeMap : .mapTiler,
                status: .available,
                reason: nil,
                attribution: mapTilerCyclingStyleURL == nil ? openFreeMapAttribution : mapTilerAttribution,
                cacheRights: mapTilerCyclingStyleURL == nil && exploreOfflineAllowed ? openFreeMapOfflineRights : .networkOnly,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .dark:
            guard exploreStyleURL != nil else {
                return .unavailable(
                    mode: mode,
                    provider: .openFreeMap,
                    status: .missingEndpoint,
                    reason: "A vector style is required before a dark presentation can be applied.",
                    attribution: openFreeMapAttribution
                )
            }
            return OutdoorMapCapability(
                mode: mode,
                provider: .openFreeMap,
                status: .available,
                reason: nil,
                attribution: openFreeMapAttribution,
                cacheRights: exploreOfflineAllowed ? openFreeMapOfflineRights : .networkOnly,
                freshness: .init(maximumAge: nil, lastUpdated: nil),
                coverage: .global
            )

        case .direction:
            return OutdoorMapCapability(
                mode: mode,
                provider: .device,
                status: .available,
                reason: nil,
                attribution: OutdoorMapAttribution(providerName: "Device heading"),
                cacheRights: OutdoorMapCacheRights(
                    networkRequired: false,
                    cachePermission: .allowed,
                    offlineInstallationAllowed: true,
                    explanation: "Direction uses the existing map and device heading."
                ),
                freshness: .init(maximumAge: 1, lastUpdated: nil),
                coverage: .global
            )
        }
    }

    func style(for mode: OutdoorMapMode) -> OutdoorMapStyleDefinition? {
        guard capability(for: mode).isUsable else { return nil }
        switch mode {
        case .explore:
            guard let exploreStyleURL else { return nil }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: openFreeMapAttribution
            )
        case .terrain:
            guard let exploreStyleURL else { return nil }
            if let mapTilerTerrainStyleURL, mapTilerKey != nil {
                return OutdoorMapStyleDefinition(
                    styleURL: expandedURL(mapTilerTerrainStyleURL, key: mapTilerKey),
                    rasterTileURLTemplate: nil,
                    vectorTileURLTemplate: nil,
                    vectorSourceLayer: nil,
                    attribution: mapTilerAttribution
                )
            }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: terrainRasterTileURLTemplate,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: openTopoMapAttribution
            )
        case .satellite:
            guard let exploreStyleURL else { return nil }
            if let mapTilerSatelliteStyleURL, mapTilerKey != nil {
                return OutdoorMapStyleDefinition(
                    styleURL: expandedURL(mapTilerSatelliteStyleURL, key: mapTilerKey),
                    rasterTileURLTemplate: nil,
                    vectorTileURLTemplate: nil,
                    vectorSourceLayer: nil,
                    attribution: mapTilerAttribution
                )
            }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: satelliteRasterTileURLTemplate,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: esriAttribution
            )
        case .threeD:
            return OutdoorMapStyleDefinition(
                styleURL: expandedURL(mapTilerThreeDStyleURL ?? exploreStyleURL!, key: mapTilerKey),
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: mapTilerThreeDStyleURL == nil ? openFreeMapAttribution : mapTilerAttribution
            )
        case .transit:
            guard let exploreStyleURL else { return nil }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: licensedTransitTileURLTemplate.map { expanded($0, key: nil) },
                vectorSourceLayer: licensedTransitTileURLTemplate == nil ? nil : licensedTransitSourceLayer,
                attribution: licensedTransitTileURLTemplate == nil ? openFreeMapAttribution : transitAttribution
            )
        case .traffic:
            guard let exploreStyleURL, let tomTomTrafficTileURLTemplate else { return nil }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: expanded(tomTomTrafficTileURLTemplate, key: tomTomTrafficKey),
                vectorSourceLayer: tomTomTrafficSourceLayer,
                attribution: tomTomAttribution
            )
        case .cycling:
            guard let styleURL = mapTilerCyclingStyleURL ?? exploreStyleURL else { return nil }
            return OutdoorMapStyleDefinition(
                styleURL: expandedURL(styleURL, key: mapTilerKey),
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: mapTilerCyclingStyleURL == nil ? openFreeMapAttribution : mapTilerAttribution
            )
        case .dark:
            guard let exploreStyleURL else { return nil }
            return OutdoorMapStyleDefinition(
                styleURL: exploreStyleURL,
                rasterTileURLTemplate: nil,
                vectorTileURLTemplate: nil,
                vectorSourceLayer: nil,
                attribution: openFreeMapAttribution
            )
        case .direction:
            return nil
        }
    }

    func offlineRights(for provider: OutdoorMapProvider) -> OutdoorMapCacheRights {
        switch provider {
        case .openFreeMap:
            return exploreOfflineAllowed ? openFreeMapOfflineRights : .networkOnly
        case .mapTiler:
            return mapTilerCacheRights
        case .openTopoMap, .esri, .tomTom, .licensedTransit, .device:
            return .networkOnly
        }
    }

    var openFreeMapAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(
            providerName: "OpenFreeMap",
            notices: ["© OpenStreetMap contributors"],
            URLs: ["https://openfreemap.org", "https://www.openstreetmap.org/copyright"].compactMap(URL.init(string:))
        )
    }

    var mapTilerAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(
            providerName: "MapTiler",
            notices: ["© MapTiler", "© OpenStreetMap contributors"],
            URLs: ["https://www.maptiler.com/copyright/", "https://www.openstreetmap.org/copyright"].compactMap(URL.init(string:))
        )
    }

    var openTopoMapAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(
            providerName: "OpenTopoMap",
            notices: ["© OpenStreetMap contributors", "SRTM"],
            URLs: ["https://opentopomap.org/about", "https://www.openstreetmap.org/copyright"].compactMap(URL.init(string:))
        )
    }

    var esriAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(
            providerName: "Esri World Imagery",
            notices: ["Esri and imagery contributors"],
            URLs: ["https://www.esri.com/en-us/legal/terms/full-master-agreement"].compactMap(URL.init(string:))
        )
    }

    var tomTomAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(
            providerName: "TomTom",
            notices: ["TomTom traffic data"],
            URLs: ["https://www.tomtom.com/legal/"].compactMap(URL.init(string:))
        )
    }

    var transitAttribution: OutdoorMapAttribution {
        OutdoorMapAttribution(providerName: licensedTransitAttribution)
    }

    private var openFreeMapOfflineRights: OutdoorMapCacheRights {
        OutdoorMapCacheRights(
            networkRequired: true,
            cachePermission: .allowed,
            offlineInstallationAllowed: true,
            explanation: "The configured OpenFreeMap license permits this vector pack."
        )
    }

    private var mapTilerCacheRights: OutdoorMapCacheRights {
        guard mapTilerOfflineLicensed, mapTilerOfflineStyleURL != nil else {
            return OutdoorMapCacheRights(
                networkRequired: true,
                cachePermission: .providerManaged,
                offlineInstallationAllowed: false,
                explanation: "MapTiler Cloud data is online-only unless a written offline license and licensed offline base are configured."
            )
        }
        return OutdoorMapCacheRights(
            networkRequired: true,
            cachePermission: .allowed,
            offlineInstallationAllowed: true,
            explanation: "Offline installation is enabled by the explicitly configured provider license."
        )
    }

    private func mapTilerCapability(
        mode: OutdoorMapMode,
        coverage: OutdoorMapCoverage,
        cacheRights: OutdoorMapCacheRights
    ) -> OutdoorMapCapability {
        OutdoorMapCapability(
            mode: mode,
            provider: .mapTiler,
            status: .available,
            reason: nil,
            attribution: mapTilerAttribution,
            cacheRights: cacheRights,
            freshness: .init(maximumAge: nil, lastUpdated: nil),
            coverage: coverage
        )
    }

    private func missingMapTilerCredential(for mode: OutdoorMapMode) -> OutdoorMapCapability {
        .unavailable(
            mode: mode,
            provider: .mapTiler,
            status: .missingCredential,
            reason: "A MapTiler key is not configured.",
            attribution: mapTilerAttribution,
            cacheRights: mapTilerCacheRights,
            coverage: .providerDefined
        )
    }

    private func missingMapTilerEndpoint(for mode: OutdoorMapMode, detail: String) -> OutdoorMapCapability {
        .unavailable(
            mode: mode,
            provider: .mapTiler,
            status: .missingEndpoint,
            reason: "\(detail) is not configured.",
            attribution: mapTilerAttribution,
            cacheRights: mapTilerCacheRights,
            coverage: .providerDefined
        )
    }

    private func expanded(_ template: String, key: String?) -> String {
        template.replacingOccurrences(of: "{key}", with: key ?? "")
    }

    private func expandedURL(_ url: URL, key: String?) -> URL {
        guard let expanded = URL(string: expanded(url.absoluteString, key: key)) else { return url }
        return expanded
    }

    private static func value(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "<未配置>" else { return nil }
        return trimmed
    }

    private static func secretLikeValue(_ raw: Any?) -> String? {
        value(raw)
    }

    private static func template(_ raw: Any?) -> String? {
        value(raw)
    }

    private static func url(_ raw: Any?) -> URL? {
        guard let value = value(raw), let url = URL(string: value), url.scheme != nil else { return nil }
        return url
    }

    private static func bool(_ raw: Any?) -> Bool {
        if let value = raw as? Bool { return value }
        guard let string = value(raw)?.lowercased() else { return false }
        return string == "yes" || string == "true" || string == "1"
    }
}
