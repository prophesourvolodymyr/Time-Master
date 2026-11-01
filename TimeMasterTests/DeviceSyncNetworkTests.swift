import XCTest
import Network
import TimeMasterCore
@testable import TimeMaster

final class DeviceSyncNetworkTests: XCTestCase {
    private final class Loopback {
        let listener: NWListener
        private let sockets: AsyncStream<DeviceSyncSocket>
        private let ports: AsyncStream<UInt16>

        init() throws {
            var socketContinuation: AsyncStream<DeviceSyncSocket>.Continuation?
            sockets = AsyncStream { socketContinuation = $0 }
            var portContinuation: AsyncStream<UInt16>.Continuation?
            ports = AsyncStream { portContinuation = $0 }
            let listener = try NWListener(using: DeviceSyncNetwork.parameters())
            listener.newConnectionHandler = { socketContinuation?.yield(DeviceSyncSocket(connection: $0)) }
            listener.stateUpdateHandler = { [weak listener] state in
                if case .ready = state, let port = listener?.port?.rawValue { portContinuation?.yield(port) }
            }
            listener.start(queue: .global())
            self.listener = listener
        }

        func connect() async throws -> (client: DeviceSyncSocket, server: DeviceSyncSocket) {
            var portIterator = ports.makeAsyncIterator()
            var socketIterator = sockets.makeAsyncIterator()
            guard let port = await portIterator.next(), let endpointPort = NWEndpoint.Port(rawValue: port) else {
                throw SyncFailure.connectionLost
            }
            let client = DeviceSyncSocket(connection: NWConnection(host: "127.0.0.1", port: endpointPort, using: DeviceSyncNetwork.parameters()))
            try await client.start(timeout: 5)
            guard let server = await socketIterator.next() else { throw SyncFailure.connectionLost }
            try await server.start(timeout: 5)
            return (client, server)
        }

        func stop() { listener.cancel() }
    }

    func testFramesArriveWholeAndInOrder() async throws {
        let loopback = try Loopback()
        defer { loopback.stop() }
        let (client, server) = try await loopback.connect()
        defer { client.close(); server.close() }
        let frames = [Data([7]), Data((0..<40_000).map { UInt8(truncatingIfNeeded: $0) }), Data("hello".utf8)]
        for frame in frames { try await client.send(frame) }
        for frame in frames {
            let received = try await server.receive()
            XCTAssertEqual(received, frame)
        }
        try await server.send(Data("and back".utf8))
        let reply = try await client.receive()
        XCTAssertEqual(String(decoding: reply, as: UTF8.self), "and back")
    }

    func testADeviceThatIsNotTrustedYetCannotSendBigFrames() async throws {
        let loopback = try Loopback()
        defer { loopback.stop() }
        let (client, server) = try await loopback.connect()
        defer { client.close(); server.close() }
        try await client.send(Data(count: 100_000))
        do {
            _ = try await server.receive()
            XCTFail("a frame over the early limit must be refused")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .connectionLost)
        }
    }

    func testAfterTheHandshakeAMegabyteFitsInAFrame() async throws {
        let loopback = try Loopback()
        defer { loopback.stop() }
        let (client, server) = try await loopback.connect()
        defer { client.close(); server.close() }
        server.raiseLimit()
        let frame = Data((0..<1_100_000).map { UInt8(truncatingIfNeeded: $0 &* 7) })
        try await client.send(frame)
        let received = try await server.receive()
        XCTAssertEqual(received, frame)
    }

    func testTheConnectionEndingFailsAWaitingRead() async throws {
        let loopback = try Loopback()
        defer { loopback.stop() }
        let (client, server) = try await loopback.connect()
        defer { server.close() }
        let waiting = Task { try await server.receive() }
        try await Task.sleep(nanoseconds: 100_000_000)
        client.close()
        do {
            _ = try await waiting.value
            XCTFail("the read must fail when the other end hangs up")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .connectionLost)
        }
    }

    // MARK: A whole sync over sockets

    private func library(_ name: String) throws -> (db: DatabaseManager, engine: SyncEngine) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tm-net-\(name)-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let db = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try db.bootstrapIfNeeded()
        return (db, SyncEngine(database: db, deviceName: name))
    }

    private func outcome<T>(_ work: @escaping () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func waitUntil(_ timeout: TimeInterval = 30, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return condition()
    }

    func testTwoLibrariesSyncOverARealEncryptedConnection() async throws {
        let mac = try library("Mac")
        let phone = try library("iPhone")
        let skill = ExercisePageManifest(title: "Piano", pageType: .skill)
        try mac.db.createPage(manifest: skill)
        let scales = ExercisePageManifest(title: "Scales", pageType: .skill, markdownBody: "Major and minor.")
        try mac.db.createPage(manifest: scales, parentID: skill.id)
        let bytes = Data((0..<2_300_000).map { UInt8(truncatingIfNeeded: $0 &* 13 &+ ($0 >> 9)) })
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("net-\(UUID().uuidString).bin")
        try bytes.write(to: source)
        addTeardownBlock { try? FileManager.default.removeItem(at: source) }
        let filename = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: source)

        let key = Data(repeating: 5, count: 32)
        let macID = try mac.engine.deviceID()
        let phoneID = try phone.engine.deviceID()
        let macRecord = SyncPeerRecord(id: macID, name: "Mac", platform: "mac", key: key)
        let phoneRecord = SyncPeerRecord(id: phoneID, name: "iPhone", platform: "iphone", key: key)
        try phone.engine.addPeer(macRecord)
        try mac.engine.addPeer(phoneRecord)

        let loopback = try Loopback()
        defer { loopback.stop() }
        let (clientSocket, serverSocket) = try await loopback.connect()
        async let dialed = SyncSecureChannel.connect(transport: clientSocket, myID: phoneID, peer: macRecord)
        async let accepted = SyncSecureChannel.accept(transport: serverSocket, myID: macID, lookup: { $0 == phoneID ? phoneRecord : nil })
        let (phoneChannel, macChannel) = try await (dialed, accepted)
        clientSocket.raiseLimit()
        serverSocket.raiseLimit()

        let phoneSession = SyncPeerSession(engine: phone.engine, channel: phoneChannel, role: .dialer, onState: { _ in }, onStored: { _ in }, onClosed: {})
        let macSession = SyncPeerSession(engine: mac.engine, channel: macChannel, role: .listener, onState: { _ in }, onStored: { _ in }, onClosed: {})
        macSession.start()
        phoneSession.start()
        defer { phoneSession.stop() }

        let phoneDB = phone.db
        let arrived = await waitUntil { (try? phoneDB.getPage(id: scales.id).mediaFilenames) == [filename]
            && FileManager.default.fileExists(atPath: phoneDB.dataRoot.appendingPathComponent("Exercises Database/\(skill.id)/\(scales.id)/media/\(filename)").path) }
        XCTAssertTrue(arrived, "the page and its media file reach the phone")
        let copy = try Data(contentsOf: phone.db.dataRoot.appendingPathComponent("Exercises Database/\(skill.id)/\(scales.id)/media/\(filename)"))
        XCTAssertEqual(copy, bytes, "the file arrives byte for byte")

        var edited = try phone.db.getPage(id: scales.id)
        edited.markdownBody = "Major, minor and modes."
        try phone.db.updatePage(id: scales.id, manifest: edited)
        phoneSession.localChanged()
        let macDB = mac.db
        let reached = await waitUntil { (try? macDB.getPage(id: scales.id).markdownBody) == "Major, minor and modes." }
        XCTAssertTrue(reached, "an edit on the phone reaches the Mac without anyone asking")
    }

    func testADeviceThatWasNotPairedIsTurnedAwayOverTheNetwork() async throws {
        let loopback = try Loopback()
        defer { loopback.stop() }
        let (clientSocket, serverSocket) = try await loopback.connect()
        let stranger = SyncPeerRecord(id: "stranger", name: "Stranger", platform: "iphone", key: Data(repeating: 1, count: 32))
        async let dialed = outcome { try await SyncSecureChannel.connect(transport: clientSocket, myID: "stranger", peer: SyncPeerRecord(id: "mac", name: "Mac", platform: "mac", key: stranger.key)) }
        async let accepted = outcome { try await SyncSecureChannel.accept(transport: serverSocket, myID: "mac", lookup: { _ in nil }) }
        let (client, server) = await (dialed, accepted)
        XCTAssertThrowsError(try client.get())
        XCTAssertThrowsError(try server.get())
    }
}
