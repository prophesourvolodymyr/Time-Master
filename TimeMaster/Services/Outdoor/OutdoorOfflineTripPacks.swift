#if os(iOS)
import Foundation
import CryptoKit
import ZIPFoundation
import TimeMasterRouting

struct OfflineTripManifest: Codable {
    struct Bounds: Codable {
        var south: Double
        var west: Double
        var north: Double
        var east: Double
        var isValid: Bool {
            south.isFinite && north.isFinite && west.isFinite && east.isFinite &&
                south >= -90 && north <= 90 && west >= -180 && east <= 180 && south < north && west < east
        }
        func contains(_ coordinate: TripCoordinate) -> Bool {
            coordinate.isValid && (south...north).contains(coordinate.latitude) && (west...east).contains(coordinate.longitude)
        }
    }
    struct FileRecord: Codable {
        var size: Int64
        var sha256: String
    }
    var schemaVersion: Int
    var id: String
    var name: String
    var engineRevision: String
    var createdAt: Date
    var source: String
    var attribution: String
    var bounds: Bounds
    var hasElevation: Bool
    var elevationResolutionMeters: Int?
    var minZoom: Int
    var maxZoom: Int
    var files: [String: FileRecord]
}

struct OfflineTripRegion: Identifiable {
    var manifest: OfflineTripManifest
    var directory: URL
    var compatible: Bool
    var id: String { manifest.id }
    var styleURL: URL { directory.appendingPathComponent("map-style.json") }
    var byteCount: Int64 { manifest.files.values.reduce(0) { $0 + $1.size } }
    var dataID: String {
        [id, manifest.engineRevision, manifest.files["graph/tiles.tar"]?.sha256 ?? "", manifest.files["places.sqlite"]?.sha256 ?? ""].joined(separator: ":")
    }
}

enum OfflineTripResources {
    static var directory: URL { Bundle.main.bundleURL.appendingPathComponent("OfflineRouting", isDirectory: true) }
    static var emptyStyle: URL { directory.appendingPathComponent("empty-map.json") }
    static func data(_ name: String) throws -> Data { try Data(contentsOf: directory.appendingPathComponent(name)) }
    static func engineRevision() throws -> String {
        let object = try JSONSerialization.jsonObject(with: data("engine.json")) as? [String: String]
        guard let revision = object?["revision"], !revision.isEmpty else {
            throw TripServiceError.message("Offline routing resources are missing. Reinstall TimeMaster.")
        }
        return revision
    }
}

actor OutdoorOfflineTripPacks {
    static let shared = OutdoorOfflineTripPacks()
    private let root: URL
    private let files = FileManager.default
    private var bootstrapped = false
    private var engine: TMOfflineRouter?
    private var engineDataID: String?
    private var placeIndex: OutdoorOfflinePlaceIndex?
    private var indexDataID: String?

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OutdoorRegions", isDirectory: true)
    }

    func bootstrap() throws -> [OfflineTripRegion] {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        if !bootstrapped {
            let active = Set(try catalog().values)
            for directory in try files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) {
                guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
                if !active.contains(directory.lastPathComponent) { try files.removeItem(at: directory) }
            }
            let defaults = UserDefaults.standard
            if root.lastPathComponent == "OutdoorRegions" {
                let bundled = OfflineTripResources.directory.appendingPathComponent("bundled-region.zip")
                if files.fileExists(atPath: bundled.path) {
                    let version = try bundledVersion(bundled)
                    if defaults.string(forKey: "outdoor.regions.bundledAreaVersion") != version {
                        _ = try install(bundled, cancellation: TMRoutingCancellation())
                        defaults.set(version, forKey: "outdoor.regions.bundledAreaVersion")
                    }
                }
            }
            for key in ["outdoor.regions.bundledAreaInstalled", "outdoor.trip.routingURL", "outdoor.trip.searchURL", "outdoor.trip.placesURL"] {
                defaults.removeObject(forKey: key)
            }
            for region in try regions() where region.compatible {
                try mapStyle(for: region).write(to: region.styleURL, options: .atomic)
            }
            var excludedRoot = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excludedRoot.setResourceValues(values)
            bootstrapped = true
        }
        return try regions()
    }

    func regions() throws -> [OfflineTripRegion] {
        let revision = try OfflineTripResources.engineRevision()
        return try catalog().map { id, directoryName in
            let directory = root.appendingPathComponent(directoryName, isDirectory: true)
            let manifest = try Self.decoder().decode(OfflineTripManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
            try validate(manifest)
            guard manifest.id == id else { throw TripServiceError.message("An offline area's catalog is damaged. Remove it and import it again.") }
            return OfflineTripRegion(manifest: manifest, directory: directory, compatible: manifest.engineRevision == revision)
        }.sorted { $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending }
    }

    func region(covering coordinates: [TripCoordinate]) throws -> OfflineTripRegion {
        let available = try bootstrap()
        guard !coordinates.isEmpty, coordinates.allSatisfy(\.isValid) else { throw TripServiceError.message("Choose a valid starting place.") }
        let compatible = available.filter(\.compatible)
        let candidates = compatible.filter { region in coordinates.allSatisfy(region.manifest.bounds.contains) }
        guard let result = candidates.min(by: { $0.byteCount < $1.byteCount }) else {
            let message = available.isEmpty
                ? "Install an offline area to plan routes and search places. Saved trips and drafts are still available."
                : compatible.isEmpty
                    ? "Installed areas were built for a different routing engine. Import updated area packs."
                    : "This trip needs one installed area covering all its stops and adjustments. Import a larger area or move the stops inside an installed area."
            throw TripServiceError.message(message)
        }
        return result
    }

    func install(_ archiveURL: URL, cancellation: TMRoutingCancellation) throws -> OfflineTripRegion {
        let scoped = archiveURL.startAccessingSecurityScopedResource()
        defer { if scoped { archiveURL.stopAccessingSecurityScopedResource() } }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw TripServiceError.message("Choose a TimeMaster offline-area ZIP archive with a valid manifest.")
        }
        guard let manifestEntry = archive["manifest.json"], manifestEntry.type == .file,
              manifestEntry.uncompressedSize <= 16_000_000 else {
            throw TripServiceError.message("Choose a TimeMaster offline-area ZIP archive with a valid manifest.")
        }
        var manifestData = Data()
        let manifestCRC = try archive.extract(manifestEntry, bufferSize: 262_144) { chunk in
            try Self.check(cancellation)
            guard manifestData.count + chunk.count <= 16_000_000 else { throw TripServiceError.message("The area's manifest is too large.") }
            manifestData.append(chunk)
        }
        guard manifestCRC == manifestEntry.checksum else { throw TripServiceError.message("The area's manifest is damaged.") }
        let manifest = try Self.decoder().decode(OfflineTripManifest.self, from: manifestData)
        try validate(manifest)
        guard manifest.engineRevision == (try OfflineTripResources.engineRevision()) else {
            throw TripServiceError.message("This area was built for a different routing engine. Rebuild or download the matching TimeMaster area pack.")
        }
        let bytes = manifest.files.values.reduce(Int64(0)) { $0 + $1.size }
        let available = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        if let available, available < bytes + 32_000_000 { throw TripServiceError.message("Not enough storage to install this area. Free space and try again.") }
        let staging = root.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        var installed = false
        defer { if !installed { try? files.removeItem(at: staging) } }
        var seen = Set<String>()
        var extracted = Set<String>()
        var entryCount = 0
        for entry in archive {
            try Self.check(cancellation)
            entryCount += 1
            guard entryCount <= 100_000, entry.type != .symlink else { throw TripServiceError.message("This archive contains unsupported or too many entries.") }
            let path = entry.type == .directory && entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            guard Self.validPath(path), seen.insert(path.lowercased()).inserted else { throw TripServiceError.message("This archive contains unsafe or duplicate paths.") }
            if entry.type == .directory { continue }
            if path == "manifest.json" { continue }
            guard let record = manifest.files[path], entry.uncompressedSize == UInt64(record.size) else {
                throw TripServiceError.message("The area's contents do not match its manifest.")
            }
            let destination = staging.appendingPathComponent(path)
            try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard files.createFile(atPath: destination.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let handle = try FileHandle(forWritingTo: destination)
            defer { try? handle.close() }
            var hasher = SHA256()
            var written: Int64 = 0
            let crc = try archive.extract(entry, bufferSize: 262_144) { chunk in
                try Self.check(cancellation)
                guard Int64(chunk.count) <= record.size - written else { throw TripServiceError.message("An area file exceeds its declared size.") }
                written += Int64(chunk.count)
                hasher.update(data: chunk)
                try handle.write(contentsOf: chunk)
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard written == record.size, crc == entry.checksum, digest == record.sha256 else {
                throw TripServiceError.message("An area file is damaged. Obtain a fresh copy of the archive.")
            }
            extracted.insert(path)
        }
        guard extracted == Set(manifest.files.keys) else { throw TripServiceError.message("The offline area is incomplete.") }
        try OutdoorOfflinePlaceIndex(url: staging.appendingPathComponent("places.sqlite")).validate()
        try manifestData.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        try Self.check(cancellation)
        let directoryName = "\(manifest.id)-\(UUID().uuidString.lowercased())"
        let destination = root.appendingPathComponent(directoryName, isDirectory: true)
        let region = OfflineTripRegion(manifest: manifest, directory: destination, compatible: true)
        try mapStyle(for: region).write(to: staging.appendingPathComponent("map-style.json"), options: .atomic)
        try files.moveItem(at: staging, to: destination)
        var previousDirectory: String?
        do {
            var catalog = try catalog()
            previousDirectory = catalog.updateValue(directoryName, forKey: manifest.id)
            try JSONEncoder().encode(catalog).write(to: root.appendingPathComponent("catalog.json"), options: .atomic)
        } catch {
            try? files.removeItem(at: destination)
            throw error
        }
        if let previousDirectory, previousDirectory != directoryName {
            try? files.removeItem(at: root.appendingPathComponent(previousDirectory))
        }
        installed = true
        engine = nil
        engineDataID = nil
        placeIndex = nil
        indexDataID = nil
        return region
    }

    func remove(_ id: String) throws {
        var catalog = try catalog()
        guard let directory = catalog.removeValue(forKey: id) else { return }
        try JSONEncoder().encode(catalog).write(to: root.appendingPathComponent("catalog.json"), options: .atomic)
        engine = nil
        engineDataID = nil
        placeIndex = nil
        indexDataID = nil
        try files.removeItem(at: root.appendingPathComponent(directory))
    }


    func nativeRoute(_ request: [String: Any], region: OfflineTripRegion, cancellation: TMRoutingCancellation) throws -> Data {
        try Self.check(cancellation)
        try requireInstalled(region)
        if engineDataID != region.dataID {
            var configuration = try JSONSerialization.jsonObject(with: OfflineTripResources.data("routing-config.json")) as? [String: Any] ?? [:]
            var graph = configuration["mjolnir"] as? [String: Any] ?? [:]
            graph["tile_dir"] = region.directory.appendingPathComponent("graph").path
            graph["tile_extract"] = region.directory.appendingPathComponent("graph/tiles.tar").path
            configuration["mjolnir"] = graph
            let data = try JSONSerialization.data(withJSONObject: configuration)
            guard let json = String(data: data, encoding: .utf8) else { throw TripServiceError.message("The offline engine configuration is invalid.") }
            engine = try TMOfflineRouter(configuration: json, timezoneDirectory: OfflineTripResources.directory.appendingPathComponent("tzdata").path)
            engineDataID = region.dataID
        }
        let data = try JSONSerialization.data(withJSONObject: request)
        guard let json = String(data: data, encoding: .utf8), let engine else { throw TripServiceError.message("The offline routing engine is unavailable.") }
        let result = try engine.route(withRequest: json, cancellation: cancellation)
        try Self.check(cancellation)
        return Data(result.utf8)
    }

    func search(_ query: String, near: TripCoordinate?, cancellation: TMRoutingCancellation) throws -> [TripPlace] {
        let available = try bootstrap().filter(\.compatible)
        guard !available.isEmpty else { throw TripServiceError.message("Install an offline area before searching places and addresses.") }
        var matches: [TripPlace] = []
        for region in available {
            try Self.check(cancellation)
            matches.append(contentsOf: try index(for: region).search(query, near: near))
        }
        if let near { matches.sort { $0.coordinate.distance(to: near) < $1.coordinate.distance(to: near) } }
        var result: [TripPlace] = []
        for place in matches {
            if !result.contains(where: { $0.id == place.id || ($0.name == place.name && $0.coordinate.distance(to: place.coordinate) < 80) }) { result.append(place) }
            if result.count == 8 { break }
        }
        return result
    }

    func places(region: OfflineTripRegion, near: TripCoordinate, radius: Double, categories: Set<TripPlaceCategory>) throws -> [TripPlace] {
        try requireInstalled(region)
        return try index(for: region).places(near: near, radius: radius, categories: categories)
    }

    func anchor(region: OfflineTripRegion, near: TripCoordinate, kind: OutdoorActivityKind, radius: Double) throws -> TripCoordinate? {
        try requireInstalled(region)
        return try index(for: region).anchor(near: near, cycling: kind == .bike, radius: radius)
    }

    func surfaces(region: OfflineTripRegion, wayIDs: Set<Int64>) throws -> [Int64: Bool] {
        try requireInstalled(region)
        return try index(for: region).surfaces(wayIDs)
    }

    private func index(for region: OfflineTripRegion) throws -> OutdoorOfflinePlaceIndex {
        if indexDataID != region.dataID {
            placeIndex = try OutdoorOfflinePlaceIndex(url: region.directory.appendingPathComponent("places.sqlite"))
            indexDataID = region.dataID
        }
        guard let placeIndex else { throw TripServiceError.message("The area's place index is unavailable.") }
        return placeIndex
    }

    private func requireInstalled(_ region: OfflineTripRegion) throws {
        guard try catalog()[region.id] == region.directory.lastPathComponent else {
            throw TripServiceError.message("This offline area changed during planning. Retry with the installed version.")
        }
    }

    private func catalog() throws -> [String: String] {
        let url = root.appendingPathComponent("catalog.json")
        guard files.fileExists(atPath: url.path) else { return [:] }
        let catalog = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        guard catalog.allSatisfy({ Self.validID($0.key) && Self.validID($0.value) && $0.value.hasPrefix($0.key + "-") }) else {
            throw TripServiceError.message("The offline-area catalog contains invalid paths.")
        }
        return catalog
    }

    private func bundledVersion(_ url: URL) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw TripServiceError.message("The bundled offline area is damaged. Reinstall TimeMaster.")
        }
        guard let entry = archive["manifest.json"], entry.type == .file, entry.uncompressedSize <= 16_000_000 else {
            throw TripServiceError.message("The bundled offline area is damaged. Reinstall TimeMaster.")
        }
        var data = Data()
        let crc = try archive.extract(entry, bufferSize: 262_144) { chunk in
            guard data.count + chunk.count <= 16_000_000 else {
                throw TripServiceError.message("The bundled offline area's manifest is too large.")
            }
            data.append(chunk)
        }
        guard crc == entry.checksum else { throw TripServiceError.message("The bundled offline area's manifest is damaged.") }
        let manifest = try Self.decoder().decode(OfflineTripManifest.self, from: data)
        try validate(manifest)
        guard manifest.engineRevision == (try OfflineTripResources.engineRevision()) else {
            throw TripServiceError.message("The bundled offline area does not match this version of TimeMaster.")
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func validate(_ manifest: OfflineTripManifest) throws {
        guard manifest.schemaVersion == 1, Self.validID(manifest.id), manifest.id.count <= 80,
              !manifest.name.isEmpty, manifest.name.count <= 160, manifest.bounds.isValid,
              !manifest.attribution.isEmpty, manifest.attribution.utf8.count <= 64_000,
              (0...18).contains(manifest.minZoom), (manifest.minZoom...18).contains(manifest.maxZoom),
              manifest.files.count <= 99_999,
              manifest.files["graph/tiles.tar"] != nil, manifest.files["places.sqlite"] != nil,
              manifest.files.keys.contains(where: { $0.hasPrefix("tiles/") && $0.hasSuffix(".pbf") }) else {
            throw TripServiceError.message("This offline-area manifest is incomplete or unsupported.")
        }
        var total: Int64 = 0
        var paths = Set<String>()
        for (path, record) in manifest.files {
            guard Self.validPath(path), paths.insert(path.lowercased()).inserted,
                  path != "manifest.json", path != "map-style.json", record.size >= 0,
                  record.size <= 2_000_000_000 - total,
                  record.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw TripServiceError.message("This area contains unsafe paths, invalid hashes, or more than 2 GB of data.")
            }
            total += record.size
        }
    }

    private func mapStyle(for region: OfflineTripRegion) throws -> Data {
        guard var style = try JSONSerialization.jsonObject(with: OfflineTripResources.data("map-style.json")) as? [String: Any],
              let glyphs = Bundle.main.url(forResource: "MapGlyphs", withExtension: nil) else {
            throw TripServiceError.message("Offline map resources are missing. Reinstall TimeMaster.")
        }
        style["glyphs"] = glyphs.absoluteString + "/{fontstack}/{range}.pbf"
        let bounds = region.manifest.bounds
        style["sources"] = ["openmaptiles": [
            "type": "vector", "tiles": [region.directory.appendingPathComponent("tiles").absoluteString + "/{z}/{x}/{y}.pbf"],
            "minzoom": region.manifest.minZoom, "maxzoom": region.manifest.maxZoom,
            "bounds": [bounds.west, bounds.south, bounds.east, bounds.north],
            "attribution": "© OpenStreetMap contributors · ODbL 1.0"
        ]]
        return try JSONSerialization.data(withJSONObject: style, options: [.sortedKeys])
    }

    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }
    }
    private static func validPath(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("\\") && !path.contains("\0") && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    private static func check(_ cancellation: TMRoutingCancellation) throws {
        if cancellation.cancelled { throw CancellationError() }
    }
}
#endif
