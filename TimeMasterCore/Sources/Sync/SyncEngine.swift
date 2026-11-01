import Foundation

public enum SyncFailure: Error, Equatable, LocalizedError, Sendable {
    case incompatible
    case notPaired
    case cancelled
    case connectionLost
    case remote(String)

    public var errorDescription: String? { message }

    public var message: String {
        switch self {
        case .incompatible: return "Your other device runs a different version of Tmax. Update both and try again."
        case .notPaired: return "This device isn't paired with that one (any more)."
        case .cancelled: return "Sync stopped."
        case .connectionLost: return "The connection dropped. Make sure both devices are on the same Wi-Fi."
        case .remote(let text): return text
        }
    }
}

public final class SyncEngine: @unchecked Sendable {
    public let database: DatabaseManager
    public let store: SyncStateStore
    private let lock = NSLock()
    private var name: String

    public init(database: DatabaseManager, deviceName: String, extra: SyncExtraFolders = .none) {
        self.database = database
        self.store = SyncStateStore(fs: database.fs, extra: extra)
        self.name = deviceName
        database.syncPurgeStaleStaging()
    }

    public var deviceName: String {
        lock.lock()
        defer { lock.unlock() }
        return name
    }

    public func setDeviceName(_ value: String) {
        lock.lock()
        name = value
        lock.unlock()
    }

    public func deviceID() throws -> String { try store.deviceID() }

    public func scan() throws -> SyncIndex {
        try database.syncScan(store: store, deviceName: deviceName)
    }

    public func changeSignature() -> String {
        database.syncChangeSignature(store: store)
    }

    public func peers() -> [SyncPeerRecord] {
        store.locked { store.loadPeers() }
    }

    public func peer(id: String) -> SyncPeerRecord? {
        peers().first { $0.id == id }
    }

    public func addPeer(_ peer: SyncPeerRecord) throws {
        try store.locked {
            var all = store.loadPeers().filter { $0.id != peer.id }
            all.append(peer)
            try store.savePeers(all)
        }
    }

    public func removePeer(id: String) throws {
        try store.locked {
            try store.savePeers(store.loadPeers().filter { $0.id != id })
            store.deleteBase(peer: id)
        }
    }

    public func lastSynced(with peer: String) -> Date? {
        store.loadBase(peer: peer).lastSyncedAt
    }

    public func ensureSafetyCopy(for peer: String) throws {
        var base = store.loadBase(peer: peer)
        guard !base.backedUp else { return }
        let snapshot = database.syncLoadSnapshot(store: store)
        if snapshot.units.contains(where: { $0.value.kind.isFolderUnit || $0.value.kind == .route }) {
            _ = try database.syncCreateSafetyCopy()
        }
        base.backedUp = true
        try store.saveBase(base, peer: peer)
    }
}

public protocol SyncEndpoint: Sendable {
    func index() async throws -> SyncIndex
    func bundles(keys: [String]) async throws -> [SyncUnitBundle]
    func readFile(unitKey: String, path: String, offset: Int64, length: Int) async throws -> Data
    func pushStart(_ request: SyncPushRequest) async throws -> SyncPushTicket
    func pushFile(token: String, unitKey: String, path: String, offset: Int64, data: Data) async throws
    func pushCommit(token: String) async throws -> SyncPushResult
    func shardLines(month: String) async throws -> [String]
    func mergeHistory(month: String, lines: [String], tombstones: [String: SyncStamp]) async throws -> SyncHistoryMerge
    func configPayload() async throws -> SyncConfigPayload?
    func applyConfig(_ payload: SyncConfigPayload, expectedHash: String?) async throws -> Bool
}

public final class SyncService: SyncEndpoint, @unchecked Sendable {
    private let engine: SyncEngine
    private let peerID: String?
    private let lock = NSLock()
    private var uploads: [String: Upload] = [:]
    public var onApplied: (@Sendable (SyncApplyReport) -> Void)?
    public var onConfigApplied: (@Sendable () -> Void)?
    public var onHistoryChanged: (@Sendable () -> Void)?

    private final class Upload {
        let request: SyncPushRequest
        let folder: URL
        var needed: [SyncNeededFile]
        init(request: SyncPushRequest, folder: URL, needed: [SyncNeededFile]) {
            self.request = request
            self.folder = folder
            self.needed = needed
        }
    }

    public init(engine: SyncEngine, peerID: String? = nil) {
        self.engine = engine
        self.peerID = peerID
    }

    public func cancelUploads() {
        lock.lock()
        let pending = uploads
        uploads = [:]
        lock.unlock()
        for upload in pending.values { engine.database.syncRemoveStaging(upload.folder) }
    }

    public func index() async throws -> SyncIndex {
        try engine.scan()
    }

    public func bundles(keys: [String]) async throws -> [SyncUnitBundle] {
        try engine.database.syncBundles(keys: keys, store: engine.store, deviceName: engine.deviceName)
    }

    public func readFile(unitKey: String, path: String, offset: Int64, length: Int) async throws -> Data {
        try engine.database.syncReadFile(key: unitKey, path: path, offset: offset, length: min(length, SyncLimits.chunkBytes), store: engine.store)
    }

    public func pushStart(_ request: SyncPushRequest) async throws -> SyncPushTicket {
        for unit in request.units {
            guard let (_, id) = SyncUnitKey.split(unit.bundle.key), SyncPaths.isSafeName(id),
                  unit.bundle.files.allSatisfy({ SyncPaths.isSafeRelative($0.path) }) else {
                throw SyncError.invalid("\(unit.bundle.key) is not an item this version understands.")
            }
        }
        let folder = try engine.database.syncStagingFolder()
        var needed: [SyncNeededFile] = []
        for unit in request.units {
            let have = Dictionary(
                try engine.database.syncLocalFiles(key: unit.bundle.key, store: engine.store).map { ($0.path, $0.sha256) },
                uniquingKeysWith: { first, _ in first }
            )
            for file in unit.bundle.files where have[file.path] != file.sha256 {
                needed.append(SyncNeededFile(unitKey: unit.bundle.key, file: file))
            }
        }
        let token = UUID().uuidString
        register(Upload(request: request, folder: folder, needed: needed), token: token)
        return SyncPushTicket(token: token, needed: needed)
    }

    private func staged(_ upload: Upload, unitKey: String, path: String) throws -> URL {
        guard SyncUnitKey.split(unitKey) != nil, SyncPaths.isSafeRelative(path) else {
            throw SyncError.invalid("\(path) is not a file path inside a library item.")
        }
        let unitFolder = upload.folder.appendingPathComponent(SyncHash.hex(Data(unitKey.utf8)), isDirectory: true)
        return SyncPaths.append(path, to: unitFolder)
    }

    private func register(_ upload: Upload, token: String) {
        lock.lock()
        uploads[token] = upload
        lock.unlock()
    }

    private func upload(_ token: String) throws -> Upload {
        lock.lock()
        defer { lock.unlock() }
        guard let upload = uploads[token] else { throw SyncError.notFound("That transfer is not open any more.") }
        return upload
    }

    private func finish(_ token: String) {
        lock.lock()
        uploads[token] = nil
        lock.unlock()
    }

    public func pushFile(token: String, unitKey: String, path: String, offset: Int64, data: Data) async throws {
        let upload = try upload(token)
        guard upload.needed.contains(where: { $0.unitKey == unitKey && $0.file.path == path }) else {
            throw SyncError.invalid("\(path) was not asked for.")
        }
        let url = try staged(upload, unitKey: unitKey, path: path)
        try engine.database.fs.ensureDirectory(url.deletingLastPathComponent())
        if offset == 0 {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw SyncError.io("Could not store \(path).") }
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { throw SyncError.io("Could not store \(path).") }
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        guard Int64(end) == offset else { throw SyncError.invalid("\(path) arrived out of order.") }
        try handle.write(contentsOf: data)
    }

    public func pushCommit(token: String) async throws -> SyncPushResult {
        let upload = try upload(token)
        finish(token)
        defer { engine.database.syncRemoveStaging(upload.folder) }

        var items: [SyncApplyItem] = []
        for unit in upload.request.units {
            var stagedFiles: [String: URL] = [:]
            for need in upload.needed where need.unitKey == unit.bundle.key {
                let url = try staged(upload, unitKey: unit.bundle.key, path: need.file.path)
                guard (try? SyncHash.hex(ofFile: url)) == need.file.sha256 else {
                    throw SyncError.invalid("\(need.file.path) did not arrive intact.")
                }
                stagedFiles[need.file.path] = url
            }
            items.append(SyncApplyItem(
                key: unit.bundle.key, manifestText: unit.bundle.manifest, stamp: unit.bundle.stamp, expectedLocalHash: unit.expectedHash,
                files: unit.bundle.files, stagedFiles: stagedFiles, removeFiles: unit.removeFiles, finalHash: unit.bundle.hash
            ))
        }
        let deletions = upload.request.deletions.map {
            SyncApplyDeletion(key: $0.key, stamp: $0.stamp, expectedLocalHash: $0.expectedHash)
        }
        if let peerID, !items.isEmpty || !deletions.isEmpty { try engine.ensureSafetyCopy(for: peerID) }
        let report = try engine.database.syncApply(items: items, deletions: deletions, store: engine.store, deviceName: engine.deviceName)
        if report.changedAnything { onApplied?(report) }
        return SyncPushResult(applied: report.applied, stale: report.stale, deleted: report.deleted, warnings: report.warnings)
    }

    public func shardLines(month: String) async throws -> [String] {
        try engine.database.syncShardLines(month, store: engine.store)
    }

    public func mergeHistory(month: String, lines: [String], tombstones: [String: SyncStamp]) async throws -> SyncHistoryMerge {
        let merge = try engine.database.syncMergeHistory(month: month, remoteLines: lines, remoteTombstones: tombstones, store: engine.store)
        if merge.changedHere { onHistoryChanged?() }
        return merge
    }

    public func configPayload() async throws -> SyncConfigPayload? {
        try engine.database.syncConfigPayload(store: engine.store, deviceName: engine.deviceName)
    }

    public func applyConfig(_ payload: SyncConfigPayload, expectedHash: String?) async throws -> Bool {
        let applied = try engine.database.syncApplyConfig(payload, expectedHash: expectedHash, store: engine.store, deviceName: engine.deviceName)
        if applied { onConfigApplied?() }
        return applied
    }
}
