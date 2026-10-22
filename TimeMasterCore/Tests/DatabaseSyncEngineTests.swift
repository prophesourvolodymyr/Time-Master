import XCTest
import Foundation
import CryptoKit
import Network
@testable import TimeMasterCore

final class DatabaseSyncEngineTests: XCTestCase {
    private var temporary: URL!
    private var server: DatabaseSyncHTTPFixture!
    private var session: URLSession!

    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("TimeMaster-Sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        server = try DatabaseSyncHTTPFixture()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
    }

    override func tearDownWithError() throws {
        session?.invalidateAndCancel()
        server?.stop()
        try FileManager.default.removeItem(at: temporary)
    }

    func testNestedPagesBinaryMediaMovesAndDeletesStayInsideExerciseScope() async throws {
        let first = root("first")
        let second = root("second")
        let database = try database(first)
        try database.createPage(manifest: ExercisePageManifest(id: "parent", title: "Training"))
        try database.createPage(manifest: ExercisePageManifest(id: "child", title: "Technique", pageKind: .leaf, mediaFilenames: ["clip.bin", "legacy.bin"], duration: 30, parentID: "parent"))
        let binary = Data(repeating: 173, count: DatabaseSyncTransport.chunkSize + 257)
        try write(binary, root: first, path: "Exercises Database/parent/child/media/clip.bin")
        try write(Data([0, 255, 4, 0, 7]), root: first, path: "Media/legacy.bin")
        try write(Data("private".utf8), root: first, path: "Config/credentials.json")
        try write(Data("profile".utf8), root: first, path: "Media/profile-only.bin")
        try write(Data("history".utf8), root: first, path: "History/private.json")
        try write(Data("workout".utf8), root: first, path: "Workouts/private/manifest.json")
        let a = engine(first)
        let b = engine(second)
        try await a.activateAccount("owner")
        try await b.activateAccount("owner")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")

        XCTAssertEqual(try bytes(second, "Exercises Database/parent/child/media/clip.bin"), binary)
        XCTAssertEqual(try bytes(second, "Media/legacy.bin"), Data([0, 255, 4, 0, 7]))
        XCTAssertEqual(Set(server.liveFiles(owner: "owner").keys), [
            "Exercises Database/parent/manifest.json", "Exercises Database/parent/guide.md",
            "Exercises Database/parent/child/manifest.json", "Exercises Database/parent/child/guide.md",
            "Exercises Database/parent/child/media/clip.bin", "Media/legacy.bin"
        ])
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.appendingPathComponent("Config/credentials.json").path))
        XCTAssertEqual(server.incompleteManifestPublications, [])

        try database.movePage(id: "child", newParentID: nil, newOrder: 1)
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(try bytes(second, "Exercises Database/child/media/clip.bin"), binary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.appendingPathComponent("Exercises Database/parent/child").path))
        let reloaded = DatabaseManager(fs: FileSystemHelper(dataRoot: second))
        XCTAssertNil(try reloaded.getPage(id: "child").parentID)

        try database.deletePage(id: "child")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.appendingPathComponent("Exercises Database/child").path))
        XCTAssertEqual(Set(server.liveFiles(owner: "owner").keys), ["Exercises Database/parent/manifest.json", "Exercises Database/parent/guide.md"])
        XCTAssertEqual(try bytes(first, "Media/profile-only.bin"), Data("profile".utf8))
    }

    func testDivergentOfflineEditsPreserveRecoverablePageAndChooseServerVersion() async throws {
        let first = root("first")
        let second = root("second")
        try makePage(first, text: "Original", media: ["clip.bin"])
        try write(Data([1, 0, 2, 255]), root: first, path: "Exercises Database/page/media/clip.bin")
        let a = engine(first)
        let b = engine(second)
        try await a.activateAccount("owner")
        try await b.activateAccount("owner")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        try write(Data("Local offline notes".utf8), root: second, path: "Exercises Database/page/guide.md")
        try write(Data("Remote notes".utf8), root: first, path: "Exercises Database/page/guide.md")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        let report = try await b.synchronize(accountID: "owner", accessToken: "owner")

        XCTAssertEqual(report.conflicts, 1)
        XCTAssertEqual(try bytes(second, "Exercises Database/page/guide.md"), Data("Remote notes".utf8))
        let backups = try conflictFiles(second)
        XCTAssertTrue(backups.contains { $0.path.hasSuffix("Exercises Database/page/guide.md") && $0.data == Data("Local offline notes".utf8) })
        XCTAssertTrue(backups.contains { $0.path.hasSuffix("Exercises Database/page/media/clip.bin") && $0.data == Data([1, 0, 2, 255]) })
        let again = try await b.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(again.conflicts, 0)
        XCTAssertEqual(server.liveFiles(owner: "owner")["Exercises Database/page/guide.md"], Data("Remote notes".utf8))
    }

    func testFreshRemotePageDeletionDoesNotResurrectOfflineNewAttachments() async throws {
        let first = root("first")
        let second = root("second")
        try makePage(first, text: "Original")
        let a = engine(first)
        let b = engine(second)
        try await a.activateAccount("owner")
        try await b.activateAccount("owner")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        try write(Data("Offline attachment".utf8), root: second, path: "Exercises Database/page/media/new.bin")
        try FileManager.default.removeItem(at: first.appendingPathComponent("Exercises Database/page"))
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        let report = try await b.synchronize(accountID: "owner", accessToken: "owner")

        XCTAssertEqual(report.conflicts, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.appendingPathComponent("Exercises Database/page").path))
        XCTAssertNil(server.liveFiles(owner: "owner")["Exercises Database/page/media/new.bin"])
        XCTAssertTrue(try conflictFiles(second).contains { $0.path.hasSuffix("media/new.bin") && $0.data == Data("Offline attachment".utf8) })
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.appendingPathComponent("Exercises Database/page").path))
    }

    func testCommitCursorCannotSkipConcurrentRemoteChangesAndLostResponseSurvivesRestart() async throws {
        let library = root("library")
        try makePage(library, text: "Original")
        let initial = engine(library)
        try await initial.activateAccount("owner")
        _ = try await initial.synchronize(accountID: "owner", accessToken: "owner")
        try write(Data("Edited locally".utf8), root: library, path: "Exercises Database/page/guide.md")
        server.injectAfterNextCommit(owner: "owner", path: "Exercises Database/concurrent.txt", data: Data("Another device".utf8))
        _ = try await initial.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(try bytes(library, "Exercises Database/concurrent.txt"), Data("Another device".utf8))

        try write(Data("Offline edit awaiting acknowledgement".utf8), root: library, path: "Exercises Database/page/guide.md")
        server.dropNextCommitResponse()
        do { _ = try await initial.synchronize(accountID: "owner", accessToken: "owner") }
        catch {}
        let acceptedRevision = try XCTUnwrap(server.record(owner: "owner", path: "Exercises Database/page/guide.md")).revision
        let restored = engine(library)
        try await restored.activateAccount("owner")
        _ = try await restored.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(try bytes(library, "Exercises Database/page/guide.md"), Data("Offline edit awaiting acknowledgement".utf8))
        XCTAssertEqual(server.liveFiles(owner: "owner")["Exercises Database/page/guide.md"], Data("Offline edit awaiting acknowledgement".utf8))
        XCTAssertEqual(try XCTUnwrap(server.record(owner: "owner", path: "Exercises Database/page/guide.md")).revision, acceptedRevision)
    }

    func testInterruptedChunkDownloadResumesWithoutPublishingAnIncompleteManifest() async throws {
        let library = root("library")
        let binary = Data(repeating: 173, count: DatabaseSyncTransport.chunkSize + 73)
        let asset = server.seed(owner: "owner", path: "Exercises Database/page/media/clip.bin", data: binary)
        server.seed(owner: "owner", path: "Exercises Database/page/manifest.json", data: Data("{\"id\":\"page\",\"title\":\"Page\",\"mediaFilenames\":[\"clip.bin\"]}".utf8))
        server.failNextDownload(hash: asset.chunks[1])
        let first = engine(library)
        try await first.activateAccount("owner")
        do {
            _ = try await first.synchronize(accountID: "owner", accessToken: "owner")
            XCTFail("A failed media download must not be reported as a completed sync")
        } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Exercises Database/page/manifest.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Exercises Database/page/media/clip.bin").path))

        let resumed = engine(library)
        try await resumed.activateAccount("owner")
        _ = try await resumed.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(try bytes(library, "Exercises Database/page/media/clip.bin"), binary)
        XCTAssertEqual(server.downloadCount(hash: asset.chunks[0]), 1)
        XCTAssertEqual(server.downloadCount(hash: asset.chunks[1]), 2)
        XCTAssertEqual(try JSONDecoder().decode(DatabaseSyncTestMediaReferences.self, from: bytes(library, "Exercises Database/page/manifest.json")).mediaFilenames, ["clip.bin"])
    }

    func testEmptyFilesAndDifferentValidChunkBoundariesDoNotCreateFalseLocalEdits() async throws {
        let library = root("library")
        let content = Data([0, 255, 7, 128, 4, 0, 93])
        let remote = server.seed(owner: "owner", path: "Exercises Database/binary.bin", data: content, chunkSize: 3)
        let empty = server.seed(owner: "owner", path: "Exercises Database/empty.md", data: Data())
        let sync = engine(library)
        try await sync.activateAccount("owner")
        _ = try await sync.synchronize(accountID: "owner", accessToken: "owner")
        let repeated = try await sync.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(try bytes(library, "Exercises Database/binary.bin"), content)
        XCTAssertEqual(try bytes(library, "Exercises Database/empty.md"), Data())
        XCTAssertEqual(server.record(owner: "owner", path: remote.path)?.revision, remote.revision)
        XCTAssertEqual(server.record(owner: "owner", path: empty.path)?.revision, empty.revision)
        XCTAssertEqual(repeated.uploadedFiles, 0)
    }

    func testLargeManifestReadsOnlyTopLevelReferencesAndDecodesEscapedNames() throws {
        let library = root("library")
        let path = "Exercises Database/page/manifest.json"
        var manifest = Data([239, 187, 191])
        manifest.append(Data("{\"markdownBody\":\"".utf8))
        manifest.append(Data(repeating: 109, count: 9 * 1_024 * 1_024))
        manifest.append(Data("\",\"linkMetadata\":[{\"mediaFilenames\":[\"profile-only.bin\"]}],\"ignored\":{\"value\":[true,false,null,-12.5e+3]},\"mediaFilenames\":[\"legacy\\u002Ebin\",\"../private\"],\"coverImageFilename\":\"cover.png\"}".utf8))
        try write(manifest, root: library, path: path)
        let storage = DatabaseSyncStorage(root: library, serviceURL: server.url)
        let referenced = try storage.legacyReferences(manifest: library.appendingPathComponent(path), manifestPath: path, availablePaths: ["Exercises Database/page/cover.png"])
        XCTAssertEqual(referenced, ["Media/legacy.bin"])
    }

    func testEditsWhileUploadingAndDownloadingAreNotSilentlyOverwritten() async throws {
        let first = root("first")
        let second = root("second")
        try makePage(first, text: "Snapshot before upload")
        server.onNextUpload {
            do { try self.write(Data("Edited during upload".utf8), root: first, path: "Exercises Database/page/guide.md") }
            catch { XCTFail(error.localizedDescription) }
        }
        let a = engine(first)
        try await a.activateAccount("owner")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(server.liveFiles(owner: "owner")["Exercises Database/page/guide.md"], Data("Edited during upload".utf8))

        let b = engine(second)
        try await b.activateAccount("owner")
        _ = try await b.synchronize(accountID: "owner", accessToken: "owner")
        try write(Data("Remote replacement".utf8), root: first, path: "Exercises Database/page/guide.md")
        _ = try await a.synchronize(accountID: "owner", accessToken: "owner")
        server.onNextDownload {
            do { try self.write(Data("Edited while suspended".utf8), root: second, path: "Exercises Database/page/guide.md") }
            catch { XCTFail(error.localizedDescription) }
        }
        let report = try await b.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(report.conflicts, 1)
        XCTAssertEqual(try bytes(second, "Exercises Database/page/guide.md"), Data("Remote replacement".utf8))
        XCTAssertTrue(try conflictFiles(second).contains { $0.path.hasSuffix("page/guide.md") && $0.data == Data("Edited while suspended".utf8) })
    }

    func testAccountHandoffRestoresOfflineWorkJournalAndReferencedLegacyMediaWithoutContamination() async throws {
        let library = root("library")
        try makePage(library, id: "alice-page", text: "Alice", media: ["shared-name.bin"])
        try write(Data("Alice binary".utf8), root: library, path: "Media/shared-name.bin")
        try write(Data("Private profile".utf8), root: library, path: "Media/profile-only.bin")
        let sync = engine(library)
        try await sync.activateAccount("alice")
        _ = try await sync.synchronize(accountID: "alice", accessToken: "alice")
        try write(Data("Alice offline notes".utf8), root: library, path: "Exercises Database/alice-page/guide.md")
        try await sync.activateAccount("bob")
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Exercises Database/alice-page").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Media/shared-name.bin").path))
        try makePage(library, id: "bob-page", text: "Bob", media: ["shared-name.bin"])
        try write(Data("Bob binary".utf8), root: library, path: "Media/shared-name.bin")
        _ = try await sync.synchronize(accountID: "bob", accessToken: "bob")
        XCTAssertEqual(Set(server.liveFiles(owner: "bob").keys), ["Exercises Database/bob-page/guide.md", "Exercises Database/bob-page/manifest.json", "Media/shared-name.bin"])
        XCTAssertEqual(server.liveFiles(owner: "alice")["Media/shared-name.bin"], Data("Alice binary".utf8))
        XCTAssertEqual(try bytes(library, "Media/profile-only.bin"), Data("Private profile".utf8))

        try await sync.activateAccount("alice")
        XCTAssertEqual(try bytes(library, "Exercises Database/alice-page/guide.md"), Data("Alice offline notes".utf8))
        XCTAssertEqual(try bytes(library, "Media/shared-name.bin"), Data("Alice binary".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Exercises Database/bob-page").path))
        _ = try await sync.synchronize(accountID: "alice", accessToken: "alice")
        XCTAssertEqual(server.liveFiles(owner: "alice")["Exercises Database/alice-page/guide.md"], Data("Alice offline notes".utf8))
        XCTAssertNil(server.liveFiles(owner: "alice")["Exercises Database/bob-page/manifest.json"])
        let relaunched = engine(library)
        try await relaunched.activateAccount("alice")
        _ = try await relaunched.synchronize(accountID: "alice", accessToken: "alice")
        XCTAssertEqual(try bytes(library, "Exercises Database/alice-page/guide.md"), Data("Alice offline notes".utf8))
    }

    func testCancelIsABarrierAndActivationCannotReenterAnInFlightSync() async throws {
        let library = root("library")
        try makePage(library, text: "Alice local work")
        let gate = DatabaseSyncHTTPFixture.Gate(reached: expectation(description: "Manifest request suspended"))
        server.holdNextManifest(gate)
        let sync = engine(library)
        try await sync.activateAccount("alice")
        let worker = Task { try await sync.synchronize(accountID: "alice", accessToken: "alice") }
        await fulfillment(of: [gate.reached], timeout: 5)
        do {
            try await sync.activateAccount("bob")
            XCTFail("Activation must not overlap a suspended sync")
        } catch DatabaseSyncError.busy {}
        await sync.cancel()
        try await sync.activateAccount("bob")
        gate.release()
        do {
            _ = try await worker.value
            XCTFail("Cancelled synchronization must not claim success")
        } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.appendingPathComponent("Exercises Database/page/manifest.json").path))
        XCTAssertEqual(server.liveFiles(owner: "alice"), [:])
        XCTAssertEqual(server.liveFiles(owner: "bob"), [:])
        try await sync.activateAccount("alice")
        XCTAssertEqual(try bytes(library, "Exercises Database/page/guide.md"), Data("# Page\n\nAlice local work".utf8))
    }

    func testCrashAfterAtomicExchangePreservesTheRacingPreimageOnRestart() async throws {
        let library = root("library")
        try makePage(library, text: "Original")
        let initial = engine(library)
        try await initial.activateAccount("owner")
        _ = try await initial.synchronize(accountID: "owner", accessToken: "owner")
        let storage = DatabaseSyncStorage(root: library, serviceURL: server.url)
        var journal = try storage.loadJournal(accountID: "owner")
        let path = "Exercises Database/page/guide.md"
        let remote = server.seed(owner: "owner", path: path, data: Data("New server content".utf8))
        let staged = try storage.stagingURL(accountID: "owner", name: "interrupted-publication")
        try storage.prepareParent(of: staged)
        try Data("New server content".utf8).write(to: staged)
        journal.publication = DatabaseSyncPublication(remote: remote, stagingName: staged.lastPathComponent, expectedLocal: journal.local[path], isOrphanDeletion: false)
        try storage.saveJournal(journal)
        try write(Data("Racing local content".utf8), root: library, path: path)
        try storage.publish(staged: staged, to: storage.scopedURL(path))
        let restarted = engine(library)
        try await restarted.activateAccount("owner")
        let report = try await restarted.synchronize(accountID: "owner", accessToken: "owner")
        XCTAssertEqual(report.conflicts, 1)
        XCTAssertEqual(try bytes(library, path), Data("New server content".utf8))
        XCTAssertTrue(try conflictFiles(library).contains { $0.path.hasSuffix(path) && $0.data == Data("Racing local content".utf8) })
    }

    func testUnauthorizedAndSymlinkFailuresLeavePrivateFilesLocal() async throws {
        let library = root("library")
        try makePage(library, text: "Local")
        let sync = engine(library)
        try await sync.activateAccount("owner")
        do {
            _ = try await sync.synchronize(accountID: "owner", accessToken: "expired")
            XCTFail("Expired credentials must be refreshable as a typed unauthorized error")
        } catch DatabaseSyncError.unauthorized {}
        let privateFile = temporary.appendingPathComponent("private-key")
        try Data("secret".utf8).write(to: privateFile)
        try FileManager.default.createSymbolicLink(at: library.appendingPathComponent("Exercises Database/page/secret"), withDestinationURL: privateFile)
        do {
            _ = try await sync.synchronize(accountID: "owner", accessToken: "owner")
            XCTFail("Symlinks must never be followed into unrelated data")
        } catch DatabaseSyncError.unsafePath {}
        XCTAssertEqual(server.liveFiles(owner: "owner"), [:])
        XCTAssertEqual(try Data(contentsOf: privateFile), Data("secret".utf8))
    }

    private func root(_ name: String) -> URL { temporary.appendingPathComponent(name) }

    private func engine(_ root: URL) -> DatabaseSyncEngine {
        DatabaseSyncEngine(dataRoot: root, serviceURL: server.url, session: session)
    }

    private func database(_ root: URL) throws -> DatabaseManager {
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        return database
    }

    private func makePage(_ root: URL, id: String = "page", text: String, media: [String] = []) throws {
        let database = try database(root)
        try database.createPage(manifest: ExercisePageManifest(id: id, title: "Page", pageKind: .leaf, markdownBody: text, mediaFilenames: media, duration: 30))
    }

    private func write(_ data: Data, root: URL, path: String) throws {
        let destination = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
    }

    private func bytes(_ root: URL, _ path: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(path)) }

    private func conflictFiles(_ root: URL) throws -> [(path: String, data: Data)] {
        let directory = root.appendingPathComponent("Backups/Sync Conflicts")
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var files: [(String, Data)] = []
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files.append((url.path, try Data(contentsOf: url)))
        }
        return files
    }
}

private final class DatabaseSyncHTTPFixture: @unchecked Sendable {
    final class Gate: @unchecked Sendable {
        let reached: XCTestExpectation
        private let lock = NSLock()
        private var continuation: (() -> Void)?

        init(reached: XCTestExpectation) { self.reached = reached }

        func hold(_ continuation: @escaping () -> Void) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            reached.fulfill()
        }

        func release() {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?()
        }
    }

    private struct Account {
        var files: [String: DatabaseSyncFile] = [:]
        var blobs: [String: Data] = [:]
    }

    private struct Commit: Decodable {
        var deviceID: String
        var mutations: [DatabaseSyncMutation]
    }

    private let queue = DispatchQueue(label: "TimeMaster.DatabaseSyncHTTPFixture")
    private let listener: NWListener
    private var connections: [UUID: NWConnection] = [:]
    private var accounts: [String: Account] = [:]
    private var revision: Int64 = 0
    private var injection: (String, String, Data)?
    private var loseCommit = false
    private var failingDownload: String?
    private var uploadHook: (() -> Void)?
    private var downloadHook: (() -> Void)?
    private var manifestGate: Gate?
    private var downloads: [String: Int] = [:]
    private var incomplete: [String] = []
    private(set) var url: URL!

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        listener = try NWListener(using: parameters, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed, .cancelled: ready.signal()
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port, port.rawValue > 0 else {
            listener.cancel()
            throw CocoaError(.fileReadUnknown)
        }
        url = URL(string: "http://127.0.0.1:\(port.rawValue)")!
    }

    func stop() {
        queue.sync {
            listener.cancel()
            for connection in connections.values { connection.cancel() }
            connections.removeAll()
        }
    }

    var incompleteManifestPublications: [String] { queue.sync { incomplete } }

    func liveFiles(owner: String) -> [String: Data] {
        queue.sync {
            guard let account = accounts[owner] else { return [:] }
            return account.files.values.filter { !$0.deleted }.reduce(into: [:]) { result, file in
                result[file.path] = file.chunks.reduce(into: Data()) { data, hash in data.append(account.blobs[hash]!) }
            }
        }
    }

    func record(owner: String, path: String) -> DatabaseSyncFile? { queue.sync { accounts[owner]?.files[path] } }
    func downloadCount(hash: String) -> Int { queue.sync { downloads[hash] ?? 0 } }
    func dropNextCommitResponse() { queue.sync { loseCommit = true } }
    func failNextDownload(hash: String) { queue.sync { failingDownload = hash } }
    func holdNextManifest(_ gate: Gate) { queue.sync { manifestGate = gate } }
    func onNextUpload(_ hook: @escaping () -> Void) { queue.sync { uploadHook = hook } }
    func onNextDownload(_ hook: @escaping () -> Void) { queue.sync { downloadHook = hook } }
    func injectAfterNextCommit(owner: String, path: String, data: Data) { queue.sync { injection = (owner, path, data) } }

    @discardableResult
    func seed(owner: String, path: String, data: Data, chunkSize: Int = DatabaseSyncTransport.chunkSize) -> DatabaseSyncFile {
        queue.sync { seedOnQueue(owner: owner, path: path, data: data, chunkSize: chunkSize) }
    }

    private func seedOnQueue(owner: String, path: String, data: Data, chunkSize: Int = DatabaseSyncTransport.chunkSize) -> DatabaseSyncFile {
        var account = accounts[owner] ?? Account()
        var chunks: [String] = []
        for offset in stride(from: 0, to: data.count, by: chunkSize) {
            let chunk = data.subdata(in: offset..<min(data.count, offset + chunkSize))
            let hash = Self.hash(chunk)
            chunks.append(hash)
            account.blobs[hash] = chunk
        }
        revision += 1
        let file = DatabaseSyncFile(path: path, revision: revision, hash: Self.hash(data), size: Int64(data.count), chunks: chunks, deleted: false)
        account.files[path] = file
        accounts[owner] = account
        return file
    }

    private func accept(_ connection: NWConnection) {
        let id = UUID()
        connections[id] = connection
        connection.start(queue: queue)
        receive(connection, id: id, buffered: Data())
    }

    private func receive(_ connection: NWConnection, id: UUID, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] bytes, _, complete, error in
            guard let self else { return }
            var buffered = buffered
            if let bytes { buffered.append(bytes) }
            if let separator = buffered.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(decoding: buffered[..<separator.lowerBound], as: UTF8.self)
                let rows = header.components(separatedBy: "\r\n")
                let request = rows[0].split(separator: " ")
                var headers: [String: String] = [:]
                for row in rows.dropFirst() {
                    let pair = row.split(separator: ":", maxSplits: 1)
                    if pair.count == 2 { headers[String(pair[0]).lowercased()] = pair[1].trimmingCharacters(in: .whitespaces) }
                }
                let length = Int(headers["content-length"] ?? "0") ?? -1
                guard request.count >= 2, length >= 0, length <= DatabaseSyncTransport.chunkSize else {
                    self.reply(connection, id: id, status: 400, body: Data())
                    return
                }
                if buffered.count >= separator.upperBound + length {
                    let body = buffered.subdata(in: separator.upperBound..<(separator.upperBound + length))
                    self.route(connection, id: id, method: String(request[0]), target: String(request[1]), headers: headers, body: body)
                    return
                }
            }
            if complete || error != nil {
                connection.cancel()
                self.connections.removeValue(forKey: id)
            } else { self.receive(connection, id: id, buffered: buffered) }
        }
    }

    private func route(_ connection: NWConnection, id: UUID, method: String, target: String, headers: [String: String], body: Data) {
        guard let authorization = headers["authorization"], authorization.hasPrefix("Bearer "), authorization != "Bearer expired" else {
            reply(connection, id: id, status: 401, body: json(["detail": "Expired"]))
            return
        }
        let owner = String(authorization.dropFirst(7))
        let components = URLComponents(string: "http://127.0.0.1" + target)!
        let path = components.path
        if method == "GET", path == "/v1/sync/manifest" {
            let cursor = Int64(components.queryItems?.first(where: { $0.name == "cursor" })?.value ?? "0") ?? 0
            let files = (accounts[owner]?.files.values.filter { $0.revision > cursor } ?? []).sorted { $0.revision < $1.revision }
            let page = Array(files.prefix(500))
            let body = json(["cursor": page.last?.revision ?? revision, "files": page.map(Self.object), "hasMore": files.count > page.count])
            if let gate = manifestGate {
                manifestGate = nil
                gate.hold { [weak self] in self?.queue.async { self?.reply(connection, id: id, status: 200, body: body) } }
            } else { reply(connection, id: id, status: 200, body: body) }
        } else if path.hasPrefix("/v1/sync/blobs/") {
            let hash = String(path.dropFirst("/v1/sync/blobs/".count))
            if method == "PUT" {
                guard !body.isEmpty, Self.hash(body) == hash else { reply(connection, id: id, status: 422, body: json(["detail": "Hash mismatch"])); return }
                var account = accounts[owner] ?? Account()
                account.blobs[hash] = body
                accounts[owner] = account
                let hook = uploadHook
                uploadHook = nil
                hook?()
                reply(connection, id: id, status: 200, body: json(["ok": true]))
            } else {
                downloads[hash, default: 0] += 1
                let hook = downloadHook
                downloadHook = nil
                hook?()
                if failingDownload == hash {
                    failingDownload = nil
                    reply(connection, id: id, status: 503, body: json(["detail": "Interrupted download"]))
                } else if let bytes = accounts[owner]?.blobs[hash] {
                    reply(connection, id: id, status: 200, body: bytes, contentType: "application/octet-stream")
                } else { reply(connection, id: id, status: 404, body: json(["detail": "Missing chunk"])) }
            }
        } else if method == "POST", path == "/v1/sync/commit" {
            commit(connection, id: id, owner: owner, body: body)
        } else { reply(connection, id: id, status: 404, body: Data()) }
    }

    private func commit(_ connection: NWConnection, id: UUID, owner: String, body: Data) {
        guard let request = try? JSONDecoder().decode(Commit.self, from: body), UUID(uuidString: request.deviceID) != nil,
              request.mutations.count <= 100 else { reply(connection, id: id, status: 422, body: Data()); return }
        var account = accounts[owner] ?? Account()
        var conflicts: [DatabaseSyncFile] = []
        for mutation in request.mutations {
            if let current = account.files[mutation.path], current.revision != mutation.baseRevision,
               !(current.hash == mutation.hash && current.size == mutation.size && current.chunks == mutation.chunks && current.deleted == mutation.deleted) {
                conflicts.append(current)
            }
            if !mutation.deleted {
                var digest = SHA256()
                var count: Int64 = 0
                for hash in mutation.chunks {
                    guard let chunk = account.blobs[hash], Self.hash(chunk) == hash else { reply(connection, id: id, status: 422, body: Data()); return }
                    digest.update(data: chunk)
                    count += Int64(chunk.count)
                }
                guard count == mutation.size, Self.hex(digest.finalize()) == mutation.hash else { reply(connection, id: id, status: 422, body: Data()); return }
            }
        }
        if !conflicts.isEmpty {
            reply(connection, id: id, status: 409, body: json(["detail": "Concurrent edit", "conflicts": conflicts.map(Self.object)]))
            return
        }
        var committed: [DatabaseSyncFile] = []
        for mutation in request.mutations {
            if let current = account.files[mutation.path], current.hash == mutation.hash, current.size == mutation.size, current.chunks == mutation.chunks, current.deleted == mutation.deleted {
                committed.append(current)
            } else {
                revision += 1
                let record = DatabaseSyncFile(path: mutation.path, revision: revision, hash: mutation.hash, size: mutation.size, chunks: mutation.chunks, deleted: mutation.deleted)
                account.files[mutation.path] = record
                committed.append(record)
            }
        }
        accounts[owner] = account
        checkManifestPublication(account)
        if let injection {
            self.injection = nil
            seedOnQueue(owner: injection.0, path: injection.1, data: injection.2)
        }
        if loseCommit {
            loseCommit = false
            connection.cancel()
            connections.removeValue(forKey: id)
        } else { reply(connection, id: id, status: 200, body: json(["cursor": revision, "files": committed.map(Self.object)])) }
    }

    private func checkManifestPublication(_ account: Account) {
        for file in account.files.values where !file.deleted && file.path.hasSuffix("/manifest.json") {
            let data = file.chunks.reduce(into: Data()) { $0.append(account.blobs[$1]!) }
            guard let references = try? JSONDecoder().decode(DatabaseSyncTestMediaReferences.self, from: data) else { continue }
            let parent = String(file.path.dropLast("manifest.json".count))
            for name in (references.mediaFilenames ?? []) + (references.coverImageFilename.map { [$0] } ?? []) {
                if ![parent + "media/" + name, parent + name, "Media/" + name].contains(where: { account.files[$0]?.deleted == false }) {
                    incomplete.append(file.path)
                }
            }
        }
    }

    private func reply(_ connection: NWConnection, id: UUID, status: Int, body: Data, contentType: String = "application/json") {
        let header = "HTTP/1.1 \(status) Response\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.connections.removeValue(forKey: id)
        })
    }

    private func json(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
    private static func object(_ file: DatabaseSyncFile) -> [String: Any] {
        ["path": file.path, "revision": file.revision, "hash": file.hash.map { $0 as Any } ?? NSNull(), "size": file.size, "chunks": file.chunks, "deleted": file.deleted]
    }
    private static func hash(_ data: Data) -> String { hex(SHA256.hash(data: data)) }
    private static func hex<T: Sequence>(_ digest: T) -> String where T.Element == UInt8 { digest.map { String(format: "%02x", $0) }.joined() }
}

private struct DatabaseSyncTestMediaReferences: Decodable {
    var mediaFilenames: [String]?
    var coverImageFilename: String?
}
