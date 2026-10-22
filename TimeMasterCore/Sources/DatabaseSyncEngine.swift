import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor DatabaseSyncEngine {
    private let storage: DatabaseSyncStorage
    private let serviceURL: URL
    private let session: URLSession
    private var accountID: String?
    private var generation: UInt64 = 0
    private var operation: Operation?

    private struct Operation {
        let id: UUID
        let task: Task<DatabaseSyncReport, Error>
    }

    public init(dataRoot: URL, serviceURL: URL, session: URLSession = .shared) {
        storage = DatabaseSyncStorage(root: dataRoot, serviceURL: serviceURL)
        self.serviceURL = serviceURL
        self.session = session
    }

    public func activateAccount(_ accountID: String) throws {
        guard operation == nil else { throw DatabaseSyncError.busy }
        try Task.checkCancellation()
        try storage.activateAccount(accountID)
        self.accountID = accountID
        generation &+= 1
    }

    public func synchronize(accountID: String, accessToken: String) async throws -> DatabaseSyncReport {
        guard operation == nil else { throw DatabaseSyncError.busy }
        guard self.accountID == accountID, try storage.activeAccount() == accountID else { throw DatabaseSyncError.accountNotActive }
        try Task.checkCancellation()
        let id = UUID()
        let generation = self.generation
        let task = Task { try await self.run(accountID: accountID, accessToken: accessToken, generation: generation) }
        operation = Operation(id: id, task: task)
        defer {
            if operation?.id == id { operation = nil }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    public func cancel() async {
        guard let current = operation else { return }
        current.task.cancel()
        _ = await current.task.result
        if operation?.id == current.id { operation = nil }
    }

    private struct PullAction {
        var remote: DatabaseSyncFile
        var expectedLocal: DatabaseSyncLocalFile?
        var orphan: Bool = false
    }

    private struct PushAction {
        var mutation: DatabaseSyncMutation
        var local: DatabaseSyncLocalFile?
    }

    private struct Plan {
        var pull: [PullAction] = []
        var push: [PushAction] = []
    }

    private func run(accountID: String, accessToken: String, generation: UInt64) async throws -> DatabaseSyncReport {
        try check(accountID: accountID, generation: generation)
        let transport = DatabaseSyncTransport(serviceURL: serviceURL, session: session, accessToken: accessToken)
        var journal = try storage.loadJournal(accountID: accountID)
        try recoverPublication(journal: &journal)
        var uploaded = 0
        var downloaded = 0
        var uploadedChunks: Set<String> = []

        for _ in 0..<12 {
            try check(accountID: accountID, generation: generation)
            try await pullManifest(transport: transport, journal: &journal, generation: generation)
            let scan = try storage.scan(accountID: accountID, cached: journal.local)
            journal.local = scan.files
            try storage.saveJournal(journal)

            var stagedManifests: [String: URL] = [:]
            var remoteLegacy: Set<String> = []
            let remotePaths = Set(journal.remote.values.filter { !$0.deleted }.map(\.path))
            for remote in journal.remote.values.filter({ !$0.deleted && Self.isManifest($0.path) }).sorted(by: { $0.path < $1.path }) {
                try check(accountID: accountID, generation: generation)
                let manifest: URL
                if scan.files[remote.path]?.hasSameContent(as: remote) == true {
                    manifest = try storage.scopedURL(remote.path)
                } else {
                    manifest = try await stage(remote, transport: transport, accountID: accountID, generation: generation)
                    stagedManifests[remote.path] = manifest
                }
                remoteLegacy.formUnion(try storage.legacyReferences(manifest: manifest, manifestPath: remote.path, availablePaths: remotePaths))
            }

            let plan = try reconcile(scan: scan, remoteLegacy: remoteLegacy, journal: &journal)
            if !plan.pull.isEmpty {
                var staged = stagedManifests
                for action in plan.pull where !action.remote.deleted {
                    try check(accountID: accountID, generation: generation)
                    if staged[action.remote.path] == nil {
                        staged[action.remote.path] = try await stage(action.remote, transport: transport, accountID: accountID, generation: generation)
                    }
                }
                for action in plan.pull.sorted(by: { Self.publicationOrder($0.remote, $1.remote) }) {
                    try check(accountID: accountID, generation: generation)
                    try apply(action, staged: staged[action.remote.path], journal: &journal)
                    downloaded += 1
                }
                continue
            }

            if plan.push.isEmpty {
                try check(accountID: accountID, generation: generation)
                try storage.clearCompletedStaging(accountID: accountID)
                let report = DatabaseSyncReport(uploadedFiles: uploaded, downloadedFiles: downloaded, conflicts: journal.unreportedConflicts)
                journal.unreportedConflicts = 0
                try storage.saveJournal(journal)
                return report
            }

            var conflicted = false
            var changedDuringTransfer = false
            let ordered = plan.push.sorted { Self.mutationOrder($0.mutation, $1.mutation) }
            for batch in Self.batches(ordered) {
                for action in batch {
                    try repairUploadSpool(action, accountID: accountID, alreadyUploaded: uploadedChunks)
                    for hash in action.mutation.chunks where !uploadedChunks.contains(hash) {
                        try check(accountID: accountID, generation: generation)
                        let chunk = try storage.chunkURL(accountID: accountID, hash: hash)
                        try await transport.uploadChunk(hash: hash, file: chunk)
                        uploadedChunks.insert(hash)
                    }
                }
                try check(accountID: accountID, generation: generation)
                if try !storage.matchesScan(scan) {
                    changedDuringTransfer = true
                    break
                }
                let result = try await transport.commit(deviceID: journal.deviceID, mutations: batch.map(\.mutation))
                try check(accountID: accountID, generation: generation)
                switch result {
                case .conflict(let files):
                    for file in files {
                        try DatabaseSyncStorage.validateRemote(file)
                        updateRemote(file, journal: &journal)
                    }
                    try storage.saveJournal(journal)
                    conflicted = true
                case .committed(let files):
                    let expected = Dictionary(uniqueKeysWithValues: batch.map { ($0.mutation.path, $0.mutation) })
                    guard files.count == expected.count, Set(files.map(\.path)).count == files.count else {
                        throw DatabaseSyncError.invalidResponse("The commit did not acknowledge every file exactly once.")
                    }
                    for file in files {
                        try DatabaseSyncStorage.validateRemote(file)
                        guard let mutation = expected[file.path], file.deleted == mutation.deleted,
                              file.hash == mutation.hash, file.size == mutation.size else {
                            throw DatabaseSyncError.invalidResponse("The commit acknowledged different file contents.")
                        }
                        updateRemote(file, journal: &journal)
                        journal.baseline[file.path] = file
                    }
                    try storage.saveJournal(journal)
                    uploaded += files.count
                }
                if conflicted { break }
            }
            if conflicted || changedDuringTransfer { continue }
        }
        throw DatabaseSyncError.localFileChanged("Exercise files are still changing or another device is synchronizing.")
    }

    private func pullManifest(transport: DatabaseSyncTransport, journal: inout DatabaseSyncJournal, generation: UInt64) async throws {
        while true {
            try check(accountID: journal.accountID, generation: generation)
            let previousCursor = journal.cursor
            let page = try await transport.manifest(cursor: previousCursor)
            try check(accountID: journal.accountID, generation: generation)
            guard page.files.count <= 500, page.cursor >= previousCursor,
                  !page.hasMore || (!page.files.isEmpty && page.cursor > previousCursor) else {
                throw DatabaseSyncError.invalidResponse("The manifest cursor did not advance safely.")
            }
            var lastRevision = previousCursor
            for file in page.files {
                try DatabaseSyncStorage.validateRemote(file)
                guard file.revision > lastRevision, file.revision <= page.cursor else {
                    throw DatabaseSyncError.invalidResponse("The manifest revisions are out of order.")
                }
                lastRevision = file.revision
                updateRemote(file, journal: &journal)
            }
            if !page.files.isEmpty, lastRevision != page.cursor {
                throw DatabaseSyncError.invalidResponse("The manifest cursor skips unreturned file revisions.")
            }
            journal.cursor = page.cursor
            try storage.saveJournal(journal)
            if !page.hasMore { return }
        }
    }

    private func reconcile(scan: DatabaseSyncScan, remoteLegacy: Set<String>, journal: inout DatabaseSyncJournal) throws -> Plan {
        var plan = Plan()
        let paths = Set(scan.files.keys).union(journal.remote.keys).union(journal.baseline.keys).sorted()
        let deletedPages = journal.remote.values.filter {
            $0.deleted && Self.isManifest($0.path) &&
                (journal.baseline[$0.path]?.deleted != true || scan.files[$0.path] == nil)
        }
        for path in paths {
            try Task.checkCancellation()
            let local = scan.files[path]
            let remote = journal.remote[path]
            let baseline = journal.baseline[path]
            let localChanged = !Self.same(local: local, remote: baseline)
            let remoteChanged = !Self.same(remote, baseline)
            let mediaInScope = scan.legacyMedia.contains(path) || remoteLegacy.contains(path)
            if path.hasPrefix("Media/"), !mediaInScope {
                if let remote, !remote.deleted, let baseline, remote.hasSameContent(as: baseline) {
                    plan.push.append(PushAction(mutation: DatabaseSyncMutation(path: path, revision: remote.revision, local: nil), local: nil))
                } else if let remote { journal.baseline[path] = remote }
                continue
            }

            if let ancestor = deletedPages.first(where: { path.hasPrefix(String($0.path.dropLast("manifest.json".count))) && path != $0.path }) {
                if local != nil {
                    if localChanged { try storage.recordConflict(path: path, local: local, remote: remote ?? ancestor, journal: &journal) }
                    let tombstone = DatabaseSyncFile(path: path, revision: remote?.revision ?? ancestor.revision, hash: nil, size: 0, chunks: [], deleted: true)
                    plan.pull.append(PullAction(remote: tombstone, expectedLocal: local, orphan: remote?.deleted != true))
                }
                if let remote, remote.deleted, local == nil { journal.baseline[path] = remote }
                continue
            }

            if Self.same(local: local, remote: remote) {
                if let remote { journal.baseline[path] = remote }
                continue
            }
            if !localChanged {
                if let remote { plan.pull.append(PullAction(remote: remote, expectedLocal: local)) }
            } else if !remoteChanged {
                plan.push.append(PushAction(mutation: DatabaseSyncMutation(path: path, revision: remote?.revision ?? 0, local: local), local: local))
            } else if let remote {
                try storage.recordConflict(path: path, local: local, remote: remote, journal: &journal)
                plan.pull.append(PullAction(remote: remote, expectedLocal: local))
            }
        }
        try storage.saveJournal(journal)
        return plan
    }

    private func stage(_ remote: DatabaseSyncFile, transport: DatabaseSyncTransport, accountID: String, generation: UInt64) async throws -> URL {
        for hash in remote.chunks {
            try check(accountID: accountID, generation: generation)
            let destination = try storage.chunkURL(accountID: accountID, hash: hash)
            if storage.exists(destination) {
                do { _ = try storage.verifyChunk(destination, hash: hash); continue }
                catch { try storage.remove(destination) }
            }
            try storage.prepareParent(of: destination)
            let temporary = destination.deletingLastPathComponent().appendingPathComponent("incoming-\(UUID().uuidString)")
            do {
                try await transport.downloadChunk(hash: hash, destination: temporary)
                try check(accountID: accountID, generation: generation)
                _ = try storage.verifyChunk(temporary, hash: hash)
                try FileManager.default.moveItem(at: temporary, to: destination)
            } catch {
                try? storage.remove(temporary)
                throw error
            }
        }
        try check(accountID: accountID, generation: generation)
        return try storage.assemble(remote, accountID: accountID)
    }

    private func apply(_ action: PullAction, staged: URL?, journal: inout DatabaseSyncJournal) throws {
        let path = action.remote.path
        let target = try storage.scopedURL(path)
        let currentFingerprint = try storage.currentFingerprint(path: path)
        var current = action.expectedLocal
        if currentFingerprint != current?.fingerprint {
            current = currentFingerprint == nil ? nil : try storage.hashFile(target, accountID: journal.accountID, spoolChunks: false)
            if !Self.same(local: current, remote: action.remote) {
                try storage.recordConflict(path: path, local: current, remote: action.remote, journal: &journal)
            }
        }
        if Self.same(local: current, remote: action.remote) {
            if !action.orphan { journal.baseline[path] = action.remote }
            journal.local[path] = current
            try storage.saveJournal(journal)
            if let staged { try storage.remove(staged) }
            return
        }
        let staging: URL
        if action.remote.deleted {
            staging = try storage.stagingURL(accountID: journal.accountID, name: "preimage-\(UUID().uuidString.lowercased())")
        } else {
            guard let staged else { throw DatabaseSyncError.invalidResponse("A file was not staged before publication.") }
            staging = staged
        }
        journal.publication = DatabaseSyncPublication(remote: action.remote, stagingName: staging.lastPathComponent, expectedLocal: current, isOrphanDeletion: action.orphan)
        try storage.saveJournal(journal)
        try Task.checkCancellation()
        if action.remote.deleted {
            if storage.exists(target) { try storage.moveToPreimage(target, destination: staging) }
        } else { try storage.publish(staged: staging, to: target) }
        try finishPublication(journal: &journal, wasPublished: true)
    }

    private func recoverPublication(journal: inout DatabaseSyncJournal) throws {
        guard let publication = journal.publication else { return }
        try DatabaseSyncStorage.validateRemote(publication.remote)
        let staged = try storage.stagingURL(accountID: journal.accountID, name: publication.stagingName)
        let target = try storage.scopedURL(publication.remote.path)
        if publication.remote.deleted {
            try finishPublication(journal: &journal, wasPublished: storage.exists(staged) || !storage.exists(target))
        } else if storage.exists(staged) {
            let stagedContents = try storage.hashFile(staged, accountID: journal.accountID, spoolChunks: false)
            if stagedContents.hasSameContent(as: publication.remote) {
                journal.publication = nil
                try storage.saveJournal(journal)
                try storage.remove(staged)
            } else { try finishPublication(journal: &journal, wasPublished: true) }
        } else {
            try finishPublication(journal: &journal, wasPublished: true)
        }
    }

    private func finishPublication(journal: inout DatabaseSyncJournal, wasPublished: Bool) throws {
        guard let publication = journal.publication else { return }
        let staged = try storage.stagingURL(accountID: journal.accountID, name: publication.stagingName)
        if wasPublished, storage.exists(staged) {
            let preimage = try storage.hashFile(staged, accountID: journal.accountID, spoolChunks: false, honorCancellation: false)
            if preimage.hash != publication.expectedLocal?.hash {
                try storage.recordConflict(path: publication.remote.path, local: preimage, remote: publication.remote, journal: &journal, sourceOverride: staged)
            }
        }
        if wasPublished, !publication.isOrphanDeletion {
            journal.baseline[publication.remote.path] = publication.remote
        } else if wasPublished {
            journal.baseline.removeValue(forKey: publication.remote.path)
        }
        journal.local.removeValue(forKey: publication.remote.path)
        journal.publication = nil
        try storage.saveJournal(journal)
        try storage.remove(staged)
        if wasPublished, publication.remote.deleted { try storage.pruneEmptyParents(of: publication.remote.path) }
    }

    private func repairUploadSpool(_ action: PushAction, accountID: String, alreadyUploaded: Set<String>) throws {
        guard let expected = action.local else { return }
        var needsRepair = false
        var checked = alreadyUploaded
        for hash in expected.chunks where checked.insert(hash).inserted {
            let url = try storage.chunkURL(accountID: accountID, hash: hash)
            do { _ = try storage.verifyChunk(url, hash: hash) }
            catch {
                try storage.remove(url)
                needsRepair = true
            }
        }
        if needsRepair {
            let actual = try storage.hashFile(storage.scopedURL(action.mutation.path), accountID: accountID, spoolChunks: true)
            guard actual.fingerprint == expected.fingerprint, actual.hash == expected.hash, actual.size == expected.size else {
                throw DatabaseSyncError.localFileChanged(action.mutation.path)
            }
        }
    }

    private func updateRemote(_ file: DatabaseSyncFile, journal: inout DatabaseSyncJournal) {
        if (journal.remote[file.path]?.revision ?? 0) <= file.revision { journal.remote[file.path] = file }
    }

    private func check(accountID: String, generation: UInt64) throws {
        try Task.checkCancellation()
        guard self.accountID == accountID, self.generation == generation else { throw DatabaseSyncError.accountNotActive }
    }

    private static func same(local: DatabaseSyncLocalFile?, remote: DatabaseSyncFile?) -> Bool {
        if let local { return local.hasSameContent(as: remote) }
        return remote == nil || remote?.deleted == true
    }

    private static func same(_ lhs: DatabaseSyncFile?, _ rhs: DatabaseSyncFile?) -> Bool {
        if let lhs { return lhs.hasSameContent(as: rhs) }
        return rhs == nil || rhs?.deleted == true
    }

    private static func isManifest(_ path: String) -> Bool {
        path.hasPrefix("Exercises Database/") && path.hasSuffix("/manifest.json")
    }

    private static func phase(path: String, deleted: Bool) -> Int {
        if !deleted { return isManifest(path) ? 1 : 0 }
        return isManifest(path) ? 2 : 3
    }

    private static func publicationOrder(_ lhs: DatabaseSyncFile, _ rhs: DatabaseSyncFile) -> Bool {
        let left = phase(path: lhs.path, deleted: lhs.deleted)
        let right = phase(path: rhs.path, deleted: rhs.deleted)
        if left != right { return left < right }
        if left == 1, lhs.path.split(separator: "/").count != rhs.path.split(separator: "/").count {
            return lhs.path.split(separator: "/").count > rhs.path.split(separator: "/").count
        }
        return lhs.path < rhs.path
    }

    private static func mutationOrder(_ lhs: DatabaseSyncMutation, _ rhs: DatabaseSyncMutation) -> Bool {
        publicationOrder(DatabaseSyncFile(path: lhs.path, revision: 1, hash: lhs.hash, size: lhs.size, chunks: lhs.chunks, deleted: lhs.deleted), DatabaseSyncFile(path: rhs.path, revision: 1, hash: rhs.hash, size: rhs.size, chunks: rhs.chunks, deleted: rhs.deleted))
    }

    private static func batches(_ ordered: [PushAction]) -> [[PushAction]] {
        var result: [[PushAction]] = []
        var batch: [PushAction] = []
        var references = 0
        var previousPhase: Int?
        for action in ordered {
            let phase = phase(path: action.mutation.path, deleted: action.mutation.deleted)
            if !batch.isEmpty && (batch.count == 100 || references + action.mutation.chunks.count > 4_096 || previousPhase != phase) {
                result.append(batch)
                batch = []
                references = 0
            }
            batch.append(action)
            references += action.mutation.chunks.count
            previousPhase = phase
        }
        if !batch.isEmpty { result.append(batch) }
        return result
    }
}
