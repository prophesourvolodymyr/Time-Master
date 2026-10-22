import Foundation
import CryptoKit
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct DatabaseSyncScan {
    var files: [String: DatabaseSyncLocalFile]
    var legacyMedia: Set<String>
}

final class DatabaseSyncStorage {
    let root: URL
    let service: String
    private let manager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    init(root: URL, serviceURL: URL) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        service = serviceURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func identifier(_ value: String) -> String {
        hex(SHA256.hash(data: Data(value.utf8)))
    }

    static func validatePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard path.utf8.count <= 1_024, components.count >= 2,
              components.first == "Exercises Database" || components.first == "Media",
              !path.contains("\\"), !path.contains("\0"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }),
              components.first != "Media" || components.count == 2 else {
            throw DatabaseSyncError.unsafePath(path)
        }
    }

    static func validateRemote(_ file: DatabaseSyncFile) throws {
        try validatePath(file.path)
        guard file.revision > 0, file.size >= 0, file.size <= DatabaseSyncTransport.maximumFileSize,
              file.chunks.count <= DatabaseSyncTransport.maximumChunks else {
            throw DatabaseSyncError.invalidResponse("Invalid file size or revision for \(file.path).")
        }
        if file.deleted {
            guard file.hash == nil, file.size == 0, file.chunks.isEmpty else {
                throw DatabaseSyncError.invalidResponse("Invalid tombstone for \(file.path).")
            }
        } else {
            guard let hash = file.hash, validHash(hash), file.chunks.allSatisfy(validHash),
                  (file.size == 0 && file.chunks.isEmpty && hash == identifier("")) ||
                    (file.size > 0 && !file.chunks.isEmpty && file.size <= Int64(file.chunks.count) * Int64(DatabaseSyncTransport.chunkSize)) else {
                throw DatabaseSyncError.invalidResponse("Invalid chunk metadata for \(file.path).")
            }
        }
    }

    static func validHash(_ hash: String) -> Bool {
        hash.utf8.count == 64 && hash.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    func activateAccount(_ accountID: String) throws {
        guard !accountID.isEmpty, accountID.utf8.count <= 256,
              !accountID.contains("\0"), !accountID.contains("\n") else {
            throw DatabaseSyncError.invalidAccount
        }
        try ensureDirectory(root)
        try ensureDirectory(internalURL(".sync"))
        let markerURL = try internalURL(".sync/ownership.json")
        var owner: Ownership
        if exists(markerURL) {
            owner = try read(Ownership.self, at: markerURL)
            if owner.pending != nil { try finishAccountSwitch(&owner) }
            if owner.accountID == accountID { return }
        } else {
            owner = Ownership(accountID: accountID, pending: nil)
            try save(owner, at: markerURL)
            return
        }

        let media = try referencedLegacyMedia().union(knownLegacyMedia(accountID: owner.accountID))
        owner.pending = AccountSwitch(from: owner.accountID, to: accountID, snapshot: UUID().uuidString.lowercased(), media: media.sorted(), phase: .archiving)
        try save(owner, at: markerURL)
        try finishAccountSwitch(&owner)
    }

    func activeAccount() throws -> String? {
        let url = try internalURL(".sync/ownership.json")
        guard exists(url) else { return nil }
        let owner = try read(Ownership.self, at: url)
        guard owner.pending == nil else { throw DatabaseSyncError.corruptJournal("An account library handoff must be completed first.") }
        return owner.accountID
    }

    func loadJournal(accountID: String) throws -> DatabaseSyncJournal {
        let url = try accountURL(accountID, "journal.json")
        guard exists(url) else { return DatabaseSyncJournal(accountID: accountID, service: service) }
        let journal = try read(DatabaseSyncJournal.self, at: url)
        guard journal.version == 1, journal.accountID == accountID, journal.service == service, journal.cursor >= 0,
              UUID(uuidString: journal.deviceID) != nil else {
            throw DatabaseSyncError.corruptJournal("The stored journal belongs to a different account or synchronization service.")
        }
        for file in journal.remote.values { try Self.validateRemote(file) }
        for file in journal.baseline.values { try Self.validateRemote(file) }
        guard journal.remote.allSatisfy({ $0.key == $0.value.path }), journal.baseline.allSatisfy({ $0.key == $0.value.path }) else {
            throw DatabaseSyncError.corruptJournal("Stored file paths do not match their revisions.")
        }
        return journal
    }

    func saveJournal(_ journal: DatabaseSyncJournal) throws {
        try save(journal, at: accountURL(journal.accountID, "journal.json"))
    }

    func scan(accountID: String, cached: [String: DatabaseSyncLocalFile]) throws -> DatabaseSyncScan {
        let paths = try exercisePaths()
        let legacy = try referencedLegacyMedia(exercisePaths: paths)
        var byFingerprint: [DatabaseSyncFingerprint: DatabaseSyncLocalFile]?
        var files: [String: DatabaseSyncLocalFile] = [:]
        for path in paths + legacy.sorted() {
            try Task.checkCancellation()
            let url = try scopedURL(path)
            guard let fingerprint = try fingerprint(url) else { continue }
            if let saved = cached[path], saved.fingerprint == fingerprint {
                files[path] = saved
            } else {
                if byFingerprint == nil {
                    var indexed: [DatabaseSyncFingerprint: DatabaseSyncLocalFile] = [:]
                    for file in cached.values { indexed[file.fingerprint] = file }
                    byFingerprint = indexed
                }
                if let saved = byFingerprint?[fingerprint] { files[path] = saved }
                else { files[path] = try hashFile(url, accountID: accountID, spoolChunks: true) }
            }
        }
        return DatabaseSyncScan(files: files, legacyMedia: legacy)
    }

    func matchesScan(_ scan: DatabaseSyncScan) throws -> Bool {
        let paths = try exercisePaths()
        let media = try referencedLegacyMedia(exercisePaths: paths)
        guard media == scan.legacyMedia else { return false }
        var found: Set<String> = []
        for path in paths + media.sorted() {
            try Task.checkCancellation()
            if let current = try currentFingerprint(path: path) {
                guard scan.files[path]?.fingerprint == current else { return false }
                found.insert(path)
            }
        }
        return found == Set(scan.files.keys)
    }

    func currentFingerprint(path: String) throws -> DatabaseSyncFingerprint? {
        try fingerprint(scopedURL(path))
    }

    func scopedURL(_ path: String) throws -> URL {
        try Self.validatePath(path)
        return try internalURL(path)
    }

    func chunkURL(accountID: String, hash: String) throws -> URL {
        guard Self.validHash(hash) else { throw DatabaseSyncError.invalidResponse("Invalid chunk identifier.") }
        return try accountURL(accountID, "blobs/\(hash)")
    }

    func stagingURL(accountID: String, name: String) throws -> URL {
        guard !name.isEmpty, name.utf8.count <= 200, !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
            throw DatabaseSyncError.corruptJournal("Invalid publication staging name.")
        }
        return try accountURL(accountID, "staging/\(name)")
    }

    func prepareParent(of url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
    }

    func exists(_ url: URL) -> Bool {
        manager.fileExists(atPath: url.path)
    }

    func remove(_ url: URL) throws {
        if exists(url) { try manager.removeItem(at: url) }
    }

    func hashFile(_ url: URL, accountID: String, spoolChunks: Bool, honorCancellation: Bool = true) throws -> DatabaseSyncLocalFile {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let before = try fingerprint(descriptor: descriptor, path: url.path)
        guard before.size <= DatabaseSyncTransport.maximumFileSize else {
            throw DatabaseSyncError.invalidResponse("\(url.lastPathComponent) exceeds the 4 GiB synchronization file limit.")
        }
        var digest = SHA256()
        var chunks: [String] = []
        var total: Int64 = 0
        while let bytes = try handle.read(upToCount: DatabaseSyncTransport.chunkSize), !bytes.isEmpty {
            if honorCancellation { try Task.checkCancellation() }
            digest.update(data: bytes)
            total += Int64(bytes.count)
            guard total <= DatabaseSyncTransport.maximumFileSize else { throw DatabaseSyncError.localFileChanged(url.lastPathComponent) }
            let hash = Self.hex(SHA256.hash(data: bytes))
            chunks.append(hash)
            if spoolChunks {
                let destination = try chunkURL(accountID: accountID, hash: hash)
                if !exists(destination) {
                    try prepareParent(of: destination)
                    try bytes.write(to: destination, options: .atomic)
                }
            }
        }
        let after = try fingerprint(descriptor: descriptor, path: url.path)
        guard before == after, total == before.size,
              try fingerprint(url) == before else { throw DatabaseSyncError.localFileChanged(url.lastPathComponent) }
        return DatabaseSyncLocalFile(fingerprint: before, hash: Self.hex(digest.finalize()), size: total, chunks: chunks)
    }

    func verifyChunk(_ url: URL, hash: String) throws -> Int {
        try readVerifiedChunk(url, hash: hash).count
    }

    private func readVerifiedChunk(_ url: URL, hash: String) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let before = try fingerprint(descriptor: descriptor, path: url.path)
        guard before.size > 0, before.size <= DatabaseSyncTransport.chunkSize else {
            throw DatabaseSyncError.invalidResponse("Invalid cached chunk.")
        }
        let bytes = try handle.read(upToCount: DatabaseSyncTransport.chunkSize) ?? Data()
        guard bytes.count == before.size,
              try fingerprint(descriptor: descriptor, path: url.path) == before,
              try fingerprint(url) == before,
              Self.hex(SHA256.hash(data: bytes)) == hash else {
            throw DatabaseSyncError.invalidResponse("A media chunk failed SHA-256 verification.")
        }
        return bytes
    }

    func assemble(_ remote: DatabaseSyncFile, accountID: String) throws -> URL {
        let name = "download-\(Self.identifier(remote.path))-\(remote.hash!)"
        let destination = try stagingURL(accountID: accountID, name: name)
        try prepareParent(of: destination)
        try remove(destination)
        guard manager.createFile(atPath: destination.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let output = try FileHandle(forWritingTo: destination)
        var completed = false
        defer {
            try? output.close()
            if !completed { try? manager.removeItem(at: destination) }
        }
        var digest = SHA256()
        var total: Int64 = 0
        for hash in remote.chunks {
            try Task.checkCancellation()
            let url = try chunkURL(accountID: accountID, hash: hash)
            let bytes = try readVerifiedChunk(url, hash: hash)
            total += Int64(bytes.count)
            guard total <= remote.size else { throw DatabaseSyncError.invalidResponse("The downloaded chunks exceed the file size.") }
            digest.update(data: bytes)
            try output.write(contentsOf: bytes)
        }
        guard total == remote.size, Self.hex(digest.finalize()) == remote.hash else {
            throw DatabaseSyncError.invalidResponse("The downloaded file failed SHA-256 verification.")
        }
        try output.synchronize()
        completed = true
        return destination
    }

    func legacyReferences(manifest: URL, manifestPath: String, availablePaths: Set<String>) throws -> Set<String> {
        let parent = String(manifestPath.dropLast("manifest.json".count))
        var legacy: Set<String> = []
        do {
            try DatabaseSyncManifestReader.read(manifest) { name in
                guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.contains("\0"), name.utf8.count <= 255 else { return }
                if !availablePaths.contains(parent + "media/" + name), !availablePaths.contains(parent + name) {
                    legacy.insert("Media/" + name)
                }
            }
        } catch { throw DatabaseSyncError.invalidManifest(manifestPath) }
        return legacy
    }

    @discardableResult
    func recordConflict(path: String, local: DatabaseSyncLocalFile?, remote: DatabaseSyncFile?, journal: inout DatabaseSyncJournal, sourceOverride: URL? = nil) throws -> Bool {
        let key = Self.identifier(path + "\0" + (local?.hash ?? "deleted") + "\0" + String(remote?.revision ?? 0))
        guard !journal.conflictVersions.contains(key) else { return false }
        let conflictRoot = "Backups/Sync Conflicts/\(Self.identifier(journal.accountID))"
        let directory = try internalURL(conflictRoot + "/" + key)
        try ensureDirectory(directory)
        let source = try scopedURL(path)
        var pageSnapshot: String?
        if let sourceOverride {
            try copyConflictFile(sourceOverride, to: directory.appendingPathComponent(path), expected: local, accountID: journal.accountID)
        } else if let local, exists(source) {
            var page = source.deletingLastPathComponent()
            while page.path.hasPrefix(root.appendingPathComponent("Exercises Database").path + "/"),
                  !exists(page.appendingPathComponent("manifest.json")) {
                page.deleteLastPathComponent()
            }
            if path.hasPrefix("Exercises Database/"), page.path != root.appendingPathComponent("Exercises Database").path,
               exists(page.appendingPathComponent("manifest.json")) {
                let relative = String(page.path.dropFirst(root.path.count + 1))
                var hashes = journal.local.filter { $0.key.hasPrefix(relative + "/") }.mapValues(\.hash)
                hashes[path] = local.hash
                var digest = SHA256()
                for file in hashes.keys.sorted() {
                    digest.update(data: Data((file + "\0" + hashes[file]! + "\0").utf8))
                }
                let snapshotPath = conflictRoot + "/Page Snapshots/" + Self.hex(digest.finalize())
                let snapshot = try internalURL(snapshotPath)
                if !exists(snapshot) {
                    let incoming = snapshot.deletingLastPathComponent().appendingPathComponent("incoming-\(UUID().uuidString)")
                    do {
                        try copySafely(page, to: incoming.appendingPathComponent(relative))
                        try manager.moveItem(at: incoming, to: snapshot)
                    } catch {
                        try? remove(incoming)
                        throw error
                    }
                }
                let preserved = try hashFile(snapshot.appendingPathComponent(path), accountID: journal.accountID, spoolChunks: false)
                guard preserved.hash == local.hash else { throw DatabaseSyncError.localFileChanged(path) }
                pageSnapshot = snapshotPath
            } else {
                try copyConflictFile(source, to: directory.appendingPathComponent(path), expected: local, accountID: journal.accountID)
            }
        }
        try save(ConflictDescription(path: path, localWasDeleted: local == nil, localHash: local?.hash, remote: remote, pageSnapshot: pageSnapshot, preservedAt: Date()), at: directory.appendingPathComponent("conflict.json"))
        journal.conflictVersions.insert(key)
        journal.unreportedConflicts += 1
        try saveJournal(journal)
        return true
    }

    func clearCompletedStaging(accountID: String) throws {
        let directory = try accountURL(accountID, "staging")
        guard exists(directory) else { return }
        for file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: file)
        }
    }

    private func copyConflictFile(_ source: URL, to destination: URL, expected: DatabaseSyncLocalFile?, accountID: String) throws {
        if !exists(destination) {
            try prepareParent(of: destination)
            let incoming = destination.deletingLastPathComponent().appendingPathComponent("incoming-\(UUID().uuidString)")
            do {
                try manager.copyItem(at: source, to: incoming)
                let preserved = try hashFile(incoming, accountID: accountID, spoolChunks: false, honorCancellation: false)
                guard preserved.hash == expected?.hash else { throw DatabaseSyncError.localFileChanged(destination.lastPathComponent) }
                try manager.moveItem(at: incoming, to: destination)
            } catch {
                try? remove(incoming)
                throw error
            }
        }
    }

    func publish(staged: URL, to destination: URL) throws {
        try prepareParent(of: destination)
        #if canImport(Darwin)
        if renameatx_np(AT_FDCWD, staged.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0 { return }
        guard errno == EEXIST else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard renameatx_np(AT_FDCWD, staged.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        #else
        guard !exists(destination) else { throw DatabaseSyncError.invalidResponse("Atomic file exchange is unavailable on this platform.") }
        try manager.moveItem(at: staged, to: destination)
        #endif
    }

    func moveToPreimage(_ source: URL, destination: URL) throws {
        try prepareParent(of: destination)
        try manager.moveItem(at: source, to: destination)
    }

    func pruneEmptyParents(of path: String) throws {
        guard path.hasPrefix("Exercises Database/") else { return }
        var directory = try scopedURL(path).deletingLastPathComponent()
        let stop = root.appendingPathComponent("Exercises Database")
        while directory.path != stop.path, directory.path.hasPrefix(stop.path + "/") {
            guard exists(directory), try manager.contentsOfDirectory(atPath: directory.path).isEmpty else { break }
            try manager.removeItem(at: directory)
            directory.deleteLastPathComponent()
        }
    }

    private func exercisePaths() throws -> [String] {
        let directory = try internalURL("Exercises Database")
        guard exists(directory) else { return [] }
        var result: [String] = []
        try walk(directory, relative: "Exercises Database", into: &result)
        return result.sorted()
    }

    private func walk(_ directory: URL, relative: String, into result: inout [String]) throws {
        let entries = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey], options: [])
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            try Task.checkCancellation()
            if entry.lastPathComponent.hasPrefix(".") { continue }
            let path = relative + "/" + entry.lastPathComponent
            try Self.validatePath(path)
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
            guard values.isSymbolicLink != true else { throw DatabaseSyncError.unsafePath(path) }
            if values.isDirectory == true { try walk(entry, relative: path, into: &result) }
            else if values.isRegularFile == true { result.append(path) }
        }
    }

    private func referencedLegacyMedia(exercisePaths: [String]? = nil) throws -> Set<String> {
        let paths = try exercisePaths ?? self.exercisePaths()
        let available = Set(paths)
        var result: Set<String> = []
        for path in paths where path.hasSuffix("/manifest.json") {
            result.formUnion(try legacyReferences(manifest: scopedURL(path), manifestPath: path, availablePaths: available))
        }
        return result
    }

    private func knownLegacyMedia(accountID: String) throws -> Set<String> {
        let url = try accountURL(accountID, "journal.json")
        guard exists(url) else { return [] }
        let journal = try read(DatabaseSyncJournal.self, at: url)
        return Set(journal.remote.keys.filter { $0.hasPrefix("Media/") })
            .union(journal.local.keys.filter { $0.hasPrefix("Media/") })
    }

    private func finishAccountSwitch(_ owner: inout Ownership) throws {
        guard var pending = owner.pending else { return }
        let snapshot = try internalURL("Backups/Account Libraries/\(Self.identifier(pending.from))/\(pending.snapshot)")
        let active = try internalURL("Exercises Database")
        if pending.phase == .archiving {
            try ensureDirectory(snapshot)
            let archived = snapshot.appendingPathComponent("Exercises Database")
            if exists(active) {
                if exists(archived) {
                    let recovery = snapshot.appendingPathComponent("Recovered Local Work-\(UUID().uuidString)")
                    try manager.moveItem(at: active, to: recovery)
                } else {
                    try manager.moveItem(at: active, to: archived)
                }
            }
            if exists(archived) {
                var paths: [String] = []
                try walk(archived, relative: "Exercises Database", into: &paths)
                var media = Set(pending.media)
                let available = Set(paths)
                for path in paths where path.hasSuffix("/manifest.json") {
                    let source = archived.appendingPathComponent(String(path.dropFirst("Exercises Database/".count)))
                    media.formUnion(try legacyReferences(manifest: source, manifestPath: path, availablePaths: available))
                }
                pending.media = media.sorted()
                owner.pending = pending
                try save(owner, at: internalURL(".sync/ownership.json"))
            }
            for path in pending.media {
                let source = try scopedURL(path)
                let destination = snapshot.appendingPathComponent(path)
                if exists(source) {
                    try prepareParent(of: destination)
                    if exists(destination) {
                        let recovery = snapshot.appendingPathComponent("Recovered Media-\(UUID().uuidString)").appendingPathComponent(path)
                        try prepareParent(of: recovery)
                        try manager.moveItem(at: source, to: recovery)
                    } else {
                        try manager.moveItem(at: source, to: destination)
                    }
                }
            }
            let journal = try accountURL(pending.from, "journal.json")
            let archivedJournal = snapshot.appendingPathComponent("journal.json")
            if exists(journal), !exists(archivedJournal) { try manager.copyItem(at: journal, to: archivedJournal) }
            try save(LibraryArchive(snapshot: pending.snapshot, media: pending.media), at: accountURL(pending.from, "library.json"))
            pending.phase = .restoring
            owner.pending = pending
            try save(owner, at: internalURL(".sync/ownership.json"))
        }

        let restoration = try accountURL(pending.to, "restoration-\(pending.snapshot)")
        let preparedTree = restoration.appendingPathComponent("Exercises Database")
        if pending.phase == .restoring {
            try remove(restoration)
            try ensureDirectory(restoration)
            let targetIndex = try accountURL(pending.to, "library.json")
            if exists(targetIndex) {
                let archive = try read(LibraryArchive.self, at: targetIndex)
                guard UUID(uuidString: archive.snapshot) != nil else { throw DatabaseSyncError.corruptJournal("Invalid account-library snapshot.") }
                let target = try internalURL("Backups/Account Libraries/\(Self.identifier(pending.to))/\(archive.snapshot)")
                let source = target.appendingPathComponent("Exercises Database")
                if exists(source) { try copySafely(source, to: preparedTree) }
                for path in archive.media {
                    let source = target.appendingPathComponent(path)
                    let destination = try scopedURL(path)
                    if exists(destination) {
                        let displaced = snapshot.appendingPathComponent("Displaced Local Media-\(UUID().uuidString)").appendingPathComponent(path)
                        try prepareParent(of: displaced)
                        try manager.moveItem(at: destination, to: displaced)
                    }
                    if exists(source) {
                        let staged = restoration.appendingPathComponent(path)
                        try prepareParent(of: staged)
                        try manager.copyItem(at: source, to: staged)
                        try prepareParent(of: destination)
                        try manager.moveItem(at: staged, to: destination)
                    }
                }
            }
            try ensureDirectory(preparedTree)
            pending.phase = .publishing
            owner.pending = pending
            try save(owner, at: internalURL(".sync/ownership.json"))
        }
        if exists(preparedTree) {
            if exists(active) {
                let recovery = snapshot.appendingPathComponent("Recovered During Handoff-\(UUID().uuidString)")
                try manager.moveItem(at: active, to: recovery)
            }
            try manager.moveItem(at: preparedTree, to: active)
        } else if !exists(active) {
            throw DatabaseSyncError.corruptJournal("The prepared account library is missing; its archive has been preserved.")
        }
        owner = Ownership(accountID: pending.to, pending: nil)
        try save(owner, at: internalURL(".sync/ownership.json"))
        try? remove(restoration)
    }

    private func copySafely(_ source: URL, to destination: URL) throws {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw DatabaseSyncError.unsafePath(source.lastPathComponent) }
        try prepareParent(of: destination)
        if values.isDirectory == true {
            try ensureDirectory(destination)
            for entry in try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) {
                try copySafely(entry, to: destination.appendingPathComponent(entry.lastPathComponent))
            }
        } else { try manager.copyItem(at: source, to: destination) }
    }

    private func accountURL(_ accountID: String, _ path: String) throws -> URL {
        try internalURL(".sync/accounts/\(Self.identifier(accountID))/\(path)")
    }

    private func internalURL(_ relative: String) throws -> URL {
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains("\0") }) else {
            throw DatabaseSyncError.unsafePath(relative)
        }
        var url = root
        for (index, component) in components.enumerated() {
            url.appendPathComponent(String(component))
            var status = stat()
            if lstat(url.path, &status) == 0 {
                guard (status.st_mode & mode_t(S_IFMT)) != mode_t(S_IFLNK),
                      index == components.count - 1 || (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
                    throw DatabaseSyncError.unsafePath(relative)
                }
            } else if errno != ENOENT { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        return url
    }

    private func ensureDirectory(_ directory: URL) throws {
        guard directory.path == root.path || directory.path.hasPrefix(root.path + "/") else { throw DatabaseSyncError.unsafePath(directory.path) }
        if directory.path != root.path { _ = try internalURL(String(directory.path.dropFirst(root.path.count + 1))) }
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw DatabaseSyncError.unsafePath(directory.path) }
        } else { try manager.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    private func save<T: Encodable>(_ value: T, at url: URL) throws {
        try prepareParent(of: url)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        do { return try decoder.decode(type, from: Data(contentsOf: url)) }
        catch { throw DatabaseSyncError.corruptJournal("\(url.lastPathComponent): \(error.localizedDescription)") }
    }

    private func fingerprint(_ url: URL) throws -> DatabaseSyncFingerprint? {
        var status = stat()
        if lstat(url.path, &status) != 0 {
            if errno == ENOENT { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return try Self.fingerprint(status, path: url.path)
    }

    private func fingerprint(descriptor: Int32, path: String) throws -> DatabaseSyncFingerprint {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return try Self.fingerprint(status, path: path)
    }

    private static func fingerprint(_ status: stat, path: String) throws -> DatabaseSyncFingerprint {
        guard (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), status.st_size >= 0 else { throw DatabaseSyncError.unsafePath(path) }
        #if canImport(Darwin)
        let modified = status.st_mtimespec
        let changed = status.st_ctimespec
        #else
        let modified = status.st_mtim
        let changed = status.st_ctim
        #endif
        return DatabaseSyncFingerprint(device: UInt64(truncatingIfNeeded: status.st_dev), inode: UInt64(status.st_ino), size: Int64(status.st_size), modifiedSeconds: Int64(modified.tv_sec), modifiedNanoseconds: Int64(modified.tv_nsec), changedSeconds: Int64(changed.tv_sec), changedNanoseconds: Int64(changed.tv_nsec))
    }

    private static func hex<T: Sequence>(_ bytes: T) -> String where T.Element == UInt8 {
        let alphabet = Array("0123456789abcdef".utf8)
        var result: [UInt8] = []
        result.reserveCapacity(64)
        for byte in bytes {
            result.append(alphabet[Int(byte >> 4)])
            result.append(alphabet[Int(byte & 15)])
        }
        return String(decoding: result, as: UTF8.self)
    }

    private struct Ownership: Codable {
        var accountID: String
        var pending: AccountSwitch?
    }

    private struct AccountSwitch: Codable {
        enum Phase: String, Codable { case archiving, restoring, publishing }
        var from: String
        var to: String
        var snapshot: String
        var media: [String]
        var phase: Phase
    }

    private struct LibraryArchive: Codable {
        var snapshot: String
        var media: [String]
    }

    private struct ConflictDescription: Codable {
        var path: String
        var localWasDeleted: Bool
        var localHash: String?
        var remote: DatabaseSyncFile?
        var pageSnapshot: String?
        var preservedAt: Date
    }
}
