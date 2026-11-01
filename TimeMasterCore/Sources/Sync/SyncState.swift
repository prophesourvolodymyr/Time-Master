import Foundation

public struct SyncFileEntry: Codable, Hashable, Sendable {
    public var path: String
    public var size: Int64
    public var sha256: String

    public init(path: String, size: Int64, sha256: String) {
        self.path = path
        self.size = size
        self.sha256 = sha256
    }
}

public final class SyncFileHashCache: @unchecked Sendable {
    struct Entry: Codable, Equatable {
        var size: Int64
        var modified: Double
        var sha256: String
    }

    let lock = NSLock()
    var entries: [String: Entry]
    private var isDirty = false

    public init() {
        entries = [:]
    }

    func hash(of url: URL, size: Int64, modified: Date) throws -> String {
        let key = url.standardizedFileURL.path
        let stamp = modified.timeIntervalSince1970
        lock.lock()
        let cached = entries[key]
        lock.unlock()
        if let cached, cached.size == size, cached.modified == stamp { return cached.sha256 }
        let sha = try SyncHash.hex(ofFile: url)
        lock.lock()
        entries[key] = Entry(size: size, modified: stamp, sha256: sha)
        isDirty = true
        lock.unlock()
        return sha
    }

    func prune(keeping paths: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        guard entries.keys.contains(where: { !paths.contains($0) }) else { return }
        entries = entries.filter { paths.contains($0.key) }
        isDirty = true
    }

    func takeDirtyData() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard isDirty else { return nil }
        isDirty = false
        return try? JSONEncoder().encode(entries)
    }

    func merge(data: Data) {
        guard let stored = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        lock.lock()
        for (key, value) in stored where entries[key] == nil { entries[key] = value }
        lock.unlock()
    }
}

public struct SyncKnownUnit: Codable, Equatable, Sendable {
    public var hash: String
    public var stamp: SyncStamp

    public init(hash: String, stamp: SyncStamp) {
        self.hash = hash
        self.stamp = stamp
    }
}

public struct SyncConfigRecord: Codable, Equatable, Sendable {
    public var hash: String
    public var stamp: SyncStamp

    public init(hash: String, stamp: SyncStamp) {
        self.hash = hash
        self.stamp = stamp
    }
}

public struct SyncState: Codable, Equatable, Sendable {
    public var version = 1
    public var clock = SyncClock()
    public var units: [String: SyncKnownUnit] = [:]
    public var tombstones: [String: SyncStamp] = [:]
    public var historyTombstones: [String: SyncStamp] = [:]
    public var config: SyncConfigRecord?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case version, clock, units, tombstones, historyTombstones, config
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        clock = (try? c.decode(SyncClock.self, forKey: .clock)) ?? SyncClock()
        units = (try? c.decode([String: SyncKnownUnit].self, forKey: .units)) ?? [:]
        tombstones = (try? c.decode([String: SyncStamp].self, forKey: .tombstones)) ?? [:]
        historyTombstones = (try? c.decode([String: SyncStamp].self, forKey: .historyTombstones)) ?? [:]
        config = try? c.decode(SyncConfigRecord.self, forKey: .config)
    }
}

public struct SyncPeerRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var platform: String
    public var key: Data
    public var pairedAt: Date

    public init(id: String, name: String, platform: String, key: Data, pairedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.platform = platform
        self.key = key
        self.pairedAt = pairedAt
    }
}

public struct SyncBaseUnit: Codable, Equatable, Sendable {
    public var hash: String
    public var manifest: String?
    public var files: [String: String]

    public init(hash: String, manifest: String?, files: [String: String]) {
        self.hash = hash
        self.manifest = manifest
        self.files = files
    }
}

public struct SyncBase: Codable, Equatable, Sendable {
    public var units: [String: SyncBaseUnit] = [:]
    public var config: String?
    public var configHash: String?
    public var lastSyncedAt: Date?
    public var backedUp = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case units, config, configHash, lastSyncedAt, backedUp
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        units = (try? c.decode([String: SyncBaseUnit].self, forKey: .units)) ?? [:]
        config = try? c.decode(String.self, forKey: .config)
        configHash = try? c.decode(String.self, forKey: .configHash)
        lastSyncedAt = try? c.decode(Date.self, forKey: .lastSyncedAt)
        backedUp = (try? c.decode(Bool.self, forKey: .backedUp)) ?? false
    }
}

public struct SyncExtraFolders: Equatable, Sendable {
    public var photos: URL?
    public var music: URL?

    public init(photos: URL? = nil, music: URL? = nil) {
        self.photos = photos
        self.music = music
    }

    public static let none = SyncExtraFolders()
}

enum SyncLocks {
    private static let guardLock = NSLock()
    private static var locks: [String: NSRecursiveLock] = [:]

    static func lock(for root: URL) -> NSRecursiveLock {
        let key = root.standardizedFileURL.path
        guardLock.lock()
        defer { guardLock.unlock() }
        if let existing = locks[key] { return existing }
        let created = NSRecursiveLock()
        locks[key] = created
        return created
    }
}

enum SyncCoding {
    static func encoder(pretty: Bool = true) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func writePrivately(_ data: Data, to url: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        guard manager.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw SyncError.io("Could not write \(url.lastPathComponent).")
        }
        do {
            if manager.fileExists(atPath: url.path) {
                _ = try manager.replaceItemAt(url, withItemAt: temporary)
            } else {
                try manager.moveItem(at: temporary, to: url)
            }
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }
}

public final class SyncStateStore: @unchecked Sendable {
    public let fs: FileSystemHelper
    public let extra: SyncExtraFolders
    public let hashCache = SyncFileHashCache()
    public let lock: NSRecursiveLock
    private let cacheLock = NSLock()
    private var cacheLoaded = false

    public init(fs: FileSystemHelper, extra: SyncExtraFolders = .none) {
        self.fs = fs
        self.extra = extra
        self.lock = SyncLocks.lock(for: fs.dataRoot)
    }

    public var directory: URL { fs.configDirectory.appendingPathComponent("sync", isDirectory: true) }
    private var deviceURL: URL { directory.appendingPathComponent("device.json") }
    private var stateURL: URL { directory.appendingPathComponent("state.json") }
    private var peersURL: URL { directory.appendingPathComponent("peers.json") }
    private var cacheURL: URL { directory.appendingPathComponent("filehashes.json") }
    private func baseURL(_ peer: String) -> URL {
        directory.appendingPathComponent("bases", isDirectory: true).appendingPathComponent("\(Self.safe(peer)).json")
    }

    private static func safe(_ name: String) -> String {
        String(name.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    }

    public var hasState: Bool {
        FileManager.default.fileExists(atPath: stateURL.path)
    }

    private struct DeviceFile: Codable {
        var id: String
        var createdAt: Date
    }

    public func deviceID() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        if let data = try? Data(contentsOf: deviceURL), let device = try? SyncCoding.decoder().decode(DeviceFile.self, from: data), !device.id.isEmpty {
            return device.id
        }
        let device = DeviceFile(id: UUID().uuidString.lowercased(), createdAt: Date())
        try fs.writeAtomically(to: deviceURL, data: try SyncCoding.encoder().encode(device))
        return device.id
    }

    public func loadState() -> SyncState {
        guard let data = try? Data(contentsOf: stateURL) else { return SyncState() }
        return (try? SyncCoding.decoder().decode(SyncState.self, from: data)) ?? SyncState()
    }

    public func saveState(_ state: SyncState) throws {
        try fs.writeAtomically(to: stateURL, data: try SyncCoding.encoder(pretty: false).encode(state))
    }

    public func loadPeers() -> [SyncPeerRecord] {
        guard let data = try? Data(contentsOf: peersURL) else { return [] }
        return (try? SyncCoding.decoder().decode([SyncPeerRecord].self, from: data)) ?? []
    }

    public func savePeers(_ peers: [SyncPeerRecord]) throws {
        try SyncCoding.writePrivately(try SyncCoding.encoder().encode(peers), to: peersURL)
    }

    public func loadBase(peer: String) -> SyncBase {
        guard let data = try? Data(contentsOf: baseURL(peer)) else { return SyncBase() }
        return (try? SyncCoding.decoder().decode(SyncBase.self, from: data)) ?? SyncBase()
    }

    public func saveBase(_ base: SyncBase, peer: String) throws {
        try fs.writeAtomically(to: baseURL(peer), data: try SyncCoding.encoder(pretty: false).encode(base))
    }

    public func deleteBase(peer: String) {
        try? fs.removeItem(at: baseURL(peer))
    }

    func loadHashCacheIfNeeded() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard !cacheLoaded else { return }
        cacheLoaded = true
        if let data = try? Data(contentsOf: cacheURL) { hashCache.merge(data: data) }
    }

    func saveHashCacheIfNeeded() {
        guard let data = hashCache.takeDirtyData() else { return }
        try? fs.writeAtomically(to: cacheURL, data: data)
    }
}
