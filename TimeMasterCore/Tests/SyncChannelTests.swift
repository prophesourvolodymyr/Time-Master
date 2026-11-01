import XCTest
import CryptoKit
@testable import TimeMasterCore

final class SyncBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }

    func update(_ change: (inout Value) -> Void) {
        lock.lock()
        change(&stored)
        lock.unlock()
    }
}

extension XCTestCase {
    func eventually(timeout: TimeInterval = 20, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        return condition()
    }
}

final class TamperingTransport: SyncTransport, @unchecked Sendable {
    private let inner: SyncTransport
    private let lock = NSLock()
    private var flipNext = false
    private var repeatNext = false
    private var last: Data?

    init(_ inner: SyncTransport) { self.inner = inner }

    func flipNextFrame() { lock.lock(); flipNext = true; lock.unlock() }
    func repeatNextFrame() { lock.lock(); repeatNext = true; lock.unlock() }

    func send(_ frame: Data) async throws { try await inner.send(frame) }
    func close() { inner.close() }

    func receive() async throws -> Data {
        if let again = replay() { return again }
        var frame = try await inner.receive()
        frame = alter(frame)
        return frame
    }

    private func replay() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard repeatNext, let last else { return nil }
        repeatNext = false
        return last
    }

    private func alter(_ frame: Data) -> Data {
        lock.lock()
        defer { lock.unlock() }
        last = frame
        guard flipNext, !frame.isEmpty else { return frame }
        flipNext = false
        var copy = frame
        copy[copy.count / 2] ^= 0x01
        return copy
    }
}

final class SyncChannelTests: XCTestCase {
    private let key = Data((0..<32).map { UInt8($0) })

    private func record(_ id: String, key: Data? = nil) -> SyncPeerRecord {
        SyncPeerRecord(id: id, name: id, platform: "mac", key: key ?? self.key)
    }

    private func open(
        dialerKey: Data? = nil, knownToListener: Bool = true,
        listenerTransport: ((SyncTransport) -> SyncTransport)? = nil
    ) async throws -> (dialer: SyncSecureChannel, listener: SyncSecureChannel) {
        let (a, b) = SyncMemoryTransport.pair()
        let listenerEnd: SyncTransport = listenerTransport?(b) ?? b
        let phone = record("phone")
        async let dialed = SyncSecureChannel.connect(transport: a, myID: "phone", peer: record("mac", key: dialerKey))
        async let accepted = SyncSecureChannel.accept(transport: listenerEnd, myID: "mac", lookup: { id in knownToListener && id == "phone" ? phone : nil })
        return try await (dialed, accepted)
    }

    func testTheHandshakeOpensAnEncryptedChannelBothWays() async throws {
        let (dialer, listener) = try await open()
        XCTAssertEqual(dialer.peer.id, "mac")
        XCTAssertEqual(listener.peer.id, "phone")
        try await dialer.send(Data("hello mac".utf8))
        let heard = try await listener.receive()
        XCTAssertEqual(String(decoding: heard, as: UTF8.self), "hello mac")
        try await listener.send(Data("hello phone".utf8))
        let answer = try await dialer.receive()
        XCTAssertEqual(String(decoding: answer, as: UTF8.self), "hello phone")
    }

    func testFramesSentAtTheSameTimeAllArriveReadable() async throws {
        let (dialer, listener) = try await open()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<60 { group.addTask { try? await dialer.send(Data("frame \(index)".utf8)) } }
        }
        var received = Set<String>()
        for _ in 0..<60 { received.insert(String(decoding: try await listener.receive(), as: UTF8.self)) }
        XCTAssertEqual(received, Set((0..<60).map { "frame \($0)" }))
    }

    func testADeviceHoldingAnotherSecretIsRefusedOnBothSides() async throws {
        do {
            _ = try await open(dialerKey: Data(repeating: 9, count: 32))
            XCTFail("the handshake must fail")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .notPaired)
        }
    }

    func testADeviceThatWasNeverPairedIsRefused() async throws {
        do {
            _ = try await open(knownToListener: false)
            XCTFail("the handshake must fail")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .notPaired)
        }
    }

    func testAFrameChangedOnTheWayIsRejected() async throws {
        let tamper = SyncBox<TamperingTransport?>(nil)
        let (dialer, listener) = try await open(listenerTransport: { inner in
            let wrapped = TamperingTransport(inner)
            tamper.value = wrapped
            return wrapped
        })
        tamper.value?.flipNextFrame()
        try await dialer.send(Data("delete page 4".utf8))
        do {
            _ = try await listener.receive()
            XCTFail("a changed frame must not open")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .connectionLost)
        }
    }

    func testAFrameRepeatedByAnAttackerIsRejected() async throws {
        let tamper = SyncBox<TamperingTransport?>(nil)
        let (dialer, listener) = try await open(listenerTransport: { inner in
            let wrapped = TamperingTransport(inner)
            tamper.value = wrapped
            return wrapped
        })
        try await dialer.send(Data("pay".utf8))
        _ = try await listener.receive()
        tamper.value?.repeatNextFrame()
        do {
            _ = try await listener.receive()
            XCTFail("a replayed frame must not open")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .connectionLost)
        }
    }

    func testWireMessagesKeepHeaderAndBinaryPayloadApart() throws {
        let payload = Data((0..<255).map { UInt8($0) }) + Data([0, 0, 0])
        let original = SyncWireMessage(kind: .request, id: 70_000, header: Data("{\"op\":\"index\"}".utf8), payload: payload)
        let decoded = try SyncWireMessage.decode(original.encoded())
        XCTAssertEqual(decoded.kind, .request)
        XCTAssertEqual(decoded.id, 70_000)
        XCTAssertEqual(decoded.header, original.header)
        XCTAssertEqual(decoded.payload, payload)
        XCTAssertThrowsError(try SyncWireMessage.decode(Data([1, 0, 0])))
        XCTAssertThrowsError(try SyncWireMessage.decode(Data([1, 0, 0, 0, 1, 0, 0, 0, 200, 1])), "a header longer than the frame")
    }
}

final class SyncPairingTests: XCTestCase {
    private func identity(_ name: String) -> SyncPairing.Identity {
        SyncPairing.Identity(id: "id-" + name.lowercased(), name: name, platform: name == "Mac" ? "mac" : "iphone")
    }

    private func outcome(_ work: @escaping () async throws -> SyncPeerRecord) async -> Result<SyncPeerRecord, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    func testTwoDevicesThatApproveTheSameCodeShareASecret() async throws {
        let (a, b) = SyncMemoryTransport.pair()
        let phone = SyncPairing(role: .initiator, me: identity("iPhone"), transport: a)
        let mac = SyncPairing(role: .responder, me: identity("Mac"), transport: b)
        let phoneCode = SyncBox<String?>(nil)
        let macCode = SyncBox<String?>(nil)
        let phoneSawDevice = SyncBox<String?>(nil)
        async let phoneResult = phone.run { code, other in phoneCode.value = code; phoneSawDevice.value = other.name; phone.approve() }
        async let macResult = mac.run { code, _ in macCode.value = code; mac.approve() }
        let (phonePeer, macPeer) = try await (phoneResult, macResult)

        XCTAssertEqual(phoneCode.value, macCode.value, "both screens show the same code")
        XCTAssertNotNil(phoneCode.value?.range(of: #"^\d{3} \d{3}$"#, options: .regularExpression))
        XCTAssertEqual(phonePeer.id, "id-mac")
        XCTAssertEqual(phonePeer.name, "Mac")
        XCTAssertEqual(phoneSawDevice.value, "Mac", "the code screen can say who it is pairing with")
        XCTAssertEqual(macPeer.id, "id-iphone")
        XCTAssertEqual(macPeer.platform, "iphone")
        XCTAssertEqual(phonePeer.key, macPeer.key)
        XCTAssertEqual(phonePeer.key.count, 32)
    }

    func testTheSecretFromPairingOpensASyncChannel() async throws {
        let (a, b) = SyncMemoryTransport.pair()
        let phone = SyncPairing(role: .initiator, me: identity("iPhone"), transport: a)
        let mac = SyncPairing(role: .responder, me: identity("Mac"), transport: b)
        async let phoneResult = phone.run { _, _ in phone.approve() }
        async let macResult = mac.run { _, _ in mac.approve() }
        let (macAsPhoneSeesIt, phoneAsMacSeesIt) = try await (phoneResult, macResult)

        let (c, d) = SyncMemoryTransport.pair()
        async let dialed = SyncSecureChannel.connect(transport: c, myID: "id-iphone", peer: macAsPhoneSeesIt)
        async let accepted = SyncSecureChannel.accept(transport: d, myID: "id-mac", lookup: { $0 == phoneAsMacSeesIt.id ? phoneAsMacSeesIt : nil })
        let (dialer, listener) = try await (dialed, accepted)
        try await dialer.send(Data("paired".utf8))
        let heard = try await listener.receive()
        XCTAssertEqual(String(decoding: heard, as: UTF8.self), "paired")
    }

    func testADeviceInTheMiddleMakesTheTwoCodesDiffer() async throws {
        // Phone <-> Mallory <-> Mac: Mallory pairs with each of them separately, so no two screens share a code.
        let (phoneEnd, malloryTowardsPhone) = SyncMemoryTransport.pair()
        let (malloryTowardsMac, macEnd) = SyncMemoryTransport.pair()
        let phone = SyncPairing(role: .initiator, me: identity("iPhone"), transport: phoneEnd)
        let mac = SyncPairing(role: .responder, me: identity("Mac"), transport: macEnd)
        let mallory1 = SyncPairing(role: .responder, me: SyncPairing.Identity(id: "mallory", name: "Mac", platform: "mac"), transport: malloryTowardsPhone)
        let mallory2 = SyncPairing(role: .initiator, me: SyncPairing.Identity(id: "mallory", name: "iPhone", platform: "iphone"), transport: malloryTowardsMac)
        let phoneCode = SyncBox<String?>(nil)
        let macCode = SyncBox<String?>(nil)

        let tasks = [
            Task { _ = try? await phone.run { code, _ in phoneCode.value = code } },
            Task { _ = try? await mac.run { code, _ in macCode.value = code } },
            Task { _ = try? await mallory1.run { _, _ in mallory1.approve() } },
            Task { _ = try? await mallory2.run { _, _ in mallory2.approve() } },
        ]
        let shown = await eventually { phoneCode.value != nil && macCode.value != nil }
        XCTAssertTrue(shown)
        XCTAssertNotEqual(phoneCode.value, macCode.value, "the person sees two different codes and says no")
        phone.decline()
        mac.decline()
        for task in tasks { await task.value }
    }

    func testDecliningStopsBothSides() async throws {
        let (a, b) = SyncMemoryTransport.pair()
        let phone = SyncPairing(role: .initiator, me: identity("iPhone"), transport: a)
        let mac = SyncPairing(role: .responder, me: identity("Mac"), transport: b)
        async let phoneResult = outcome { try await phone.run { _, _ in phone.approve() } }
        async let macResult = outcome { try await mac.run { _, _ in mac.decline() } }
        let (p, m) = await (phoneResult, macResult)
        XCTAssertThrowsError(try p.get()) { XCTAssertEqual($0 as? SyncFailure, .cancelled) }
        XCTAssertThrowsError(try m.get()) { XCTAssertEqual($0 as? SyncFailure, .cancelled) }
    }

    func testADeviceNotReadyToPairSaysSo() async throws {
        let (a, b) = SyncMemoryTransport.pair()
        let phone = SyncPairing(role: .initiator, me: identity("iPhone"), transport: a)
        let refusal = Task {
            _ = try? await b.receive()
            await SyncPairing.refuse(on: b, reason: "Open “Add a device” on this device first.")
        }
        do {
            _ = try await phone.run { _, _ in }
            XCTFail("pairing must fail")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .remote("Open “Add a device” on this device first."))
        }
        await refusal.value
    }

    func testARevealThatDoesNotMatchTheCommitmentIsRefused() async throws {
        // The initiator commits to one key, then shows another (how a man in the middle would try to pick its key late).
        let (attacker, mac) = SyncMemoryTransport.pair()
        let responder = SyncPairing(role: .responder, me: identity("Mac"), transport: mac)
        let codeShown = SyncBox(false)
        let outcome = Task { () -> Error? in
            do { _ = try await responder.run { _, _ in codeShown.value = true; responder.approve() }; return nil } catch { return error }
        }
        func offer(_ name: String) -> [String: Any] {
            ["id": "evil", "name": name, "platform": "iphone", "nonce": Data(repeating: 1, count: 16).base64EncodedString(),
             "pub": Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation.base64EncodedString()]
        }
        func frame(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
        let committed = try frame(offer("Phone"))
        try await attacker.send(try frame(["type": "commit", "commit": Data(SHA256.hash(data: committed)).base64EncodedString()]))
        _ = try await attacker.receive()   // the Mac's offer
        try await attacker.send(try frame(["type": "reveal", "offer": offer("Phone")]))   // a different key than the one committed to
        let failure = await outcome.value
        XCTAssertEqual(failure as? SyncFailure, .remote("That device's pairing message did not check out."))
        XCTAssertFalse(codeShown.value, "no code is shown for a pairing that failed")
    }
}

final class SyncSessionTests: SyncPairTestCase {
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storedCount = 0
        private var closedFlag = false
        private var reports: [SyncReport] = []
        var stored: Int { lock.lock(); defer { lock.unlock() }; return storedCount }
        var closed: Bool { lock.lock(); defer { lock.unlock() }; return closedFlag }
        var lastReport: SyncReport? { lock.lock(); defer { lock.unlock() }; return reports.last }
        func didStore() { lock.lock(); storedCount += 1; lock.unlock() }
        func didClose() { lock.lock(); closedFlag = true; lock.unlock() }
        func didReport(_ report: SyncReport) { lock.lock(); reports.append(report); lock.unlock() }
    }

    struct Live {
        let phone: SyncPeerSession
        let mac: SyncPeerSession
        let phoneEvents: Recorder
        let macEvents: Recorder
    }

    private func goLiveRecording() async throws -> Live {
        let key = Data(repeating: 7, count: 32)
        let macID = try mac.engine.deviceID()
        let phoneID = try phone.engine.deviceID()
        let macRecord = SyncPeerRecord(id: macID, name: "Mac", platform: "mac", key: key)
        let phoneRecord = SyncPeerRecord(id: phoneID, name: "iPhone", platform: "iphone", key: key)
        try phone.engine.addPeer(macRecord)
        try mac.engine.addPeer(phoneRecord)
        let (a, b) = SyncMemoryTransport.pair()
        async let dialed = SyncSecureChannel.connect(transport: a, myID: phoneID, peer: macRecord)
        async let accepted = SyncSecureChannel.accept(transport: b, myID: macID, lookup: { $0 == phoneID ? phoneRecord : nil })
        let (phoneChannel, macChannel) = try await (dialed, accepted)
        let phoneEvents = Recorder()
        let macEvents = Recorder()
        let phoneSession = SyncPeerSession(
            engine: phone.engine, channel: phoneChannel, role: .dialer, onState: { _ in },
            onStored: { _ in phoneEvents.didStore() }, onReport: { phoneEvents.didReport($0) }, onClosed: { phoneEvents.didClose() }
        )
        let macSession = SyncPeerSession(
            engine: mac.engine, channel: macChannel, role: .listener, onState: { _ in },
            onStored: { _ in macEvents.didStore() }, onClosed: { macEvents.didClose() }
        )
        return Live(phone: phoneSession, mac: macSession, phoneEvents: phoneEvents, macEvents: macEvents)
    }

    private func isUpToDate(_ session: SyncPeerSession) -> Bool {
        if case .upToDate = session.currentState { return true }
        return false
    }

    func testTwoDevicesStartSyncingAsSoonAsTheyAreConnected() async throws {
        let (piano, scales, _) = try makePiano(on: mac)
        _ = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("sheet music"))
        let guitar = try makePage(phone, "Guitar")
        let live = try await goLiveRecording()
        live.mac.start()
        live.phone.start()
        let done = await eventually { self.isUpToDate(live.phone) && self.isUpToDate(live.mac) }
        XCTAssertTrue(done, "both ends report being up to date")
        XCTAssertTrue(phone.exists(piano.id))
        XCTAssertTrue(phone.exists(scales.id))
        XCTAssertTrue(mac.exists(guitar.id))
        XCTAssertGreaterThan(live.phoneEvents.stored, 0, "the phone is told to reload")
        XCTAssertGreaterThan(live.macEvents.stored, 0, "so is the Mac")
        XCTAssertEqual(live.phoneEvents.lastReport?.itemsHere, 3, "Piano, Scales and Chords")
        try assertInSync()
        live.phone.stop()
    }

    func testAChangeOnEitherDeviceReachesTheOtherWithoutAskingAgain() async throws {
        let (piano, _, _) = try makePiano(on: mac)
        let live = try await goLiveRecording()
        live.mac.start()
        live.phone.start()
        let first = await eventually { self.phone.exists(piano.id) && self.isUpToDate(live.phone) }
        XCTAssertTrue(first)

        let arpeggios = try makePage(mac, "Arpeggios", parent: piano.id, body: "Broken chords.")
        live.mac.localChanged()
        let reachedPhone = await eventually { self.phone.exists(arpeggios.id) }
        XCTAssertTrue(reachedPhone, "a page made on the Mac (the listening side) appears on the phone")

        try phone.edit(arpeggios.id) { $0.markdownBody = "Broken chords, slowly." }
        live.phone.localChanged()
        let reachedMac = await eventually { (try? self.mac.page(arpeggios.id).markdownBody) == "Broken chords, slowly." }
        XCTAssertTrue(reachedMac, "an edit made on the phone (the dialing side) appears on the Mac")

        let settled = await eventually { self.isUpToDate(live.phone) && self.isUpToDate(live.mac) }
        XCTAssertTrue(settled)
        try assertInSync()
        live.phone.stop()
    }

    func testManyQuickChangesEndInTheSameLibrary() async throws {
        let (piano, _, _) = try makePiano(on: mac)
        let live = try await goLiveRecording()
        live.mac.start()
        live.phone.start()
        _ = await eventually { self.phone.exists(piano.id) }
        var made: [String] = []
        for index in 0..<8 {
            made.append(try makePage(mac, "Etude \(index)", parent: piano.id).id)
            live.mac.localChanged()
            made.append(try makePage(phone, "Song \(index)", parent: piano.id).id)
            live.phone.localChanged()
        }
        let arrived = await eventually { made.allSatisfy { self.mac.exists($0) && self.phone.exists($0) } }
        XCTAssertTrue(arrived)
        let settled = await eventually { self.isUpToDate(live.phone) && ((try? self.inSyncQuietly()) ?? false) }
        XCTAssertTrue(settled)
        try assertInSync()
        XCTAssertTrue(libraryProblems(mac).isEmpty, "\(libraryProblems(mac))")
        live.phone.stop()
    }

    private func inSyncQuietly() throws -> Bool {
        let x = try mac.engine.scan()
        let y = try phone.engine.scan()
        return x.units.map { "\($0.key) \($0.hash)" } == y.units.map { "\($0.key) \($0.hash)" }
    }

    func testALargeFileCrossesTheEncryptedWireIntact() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        let big = base.appendingPathComponent("big-\(UUID().uuidString).bin")
        let bytes = Data((0..<(2_600_000)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ ($0 >> 8)) })
        try bytes.write(to: big)
        let filename = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: big)
        let live = try await goLiveRecording()
        live.mac.start()
        live.phone.start()
        let done = await eventually(timeout: 40) { self.isUpToDate(live.phone) && self.phone.exists(scales.id) }
        XCTAssertTrue(done)
        let copy = try Data(contentsOf: try phone.folder(scales.id).appendingPathComponent("media/\(filename)"))
        XCTAssertEqual(copy, bytes, "every byte arrives, in order")
        live.phone.stop()
    }

    func testClosingOneEndClosesTheOther() async throws {
        _ = try makePiano(on: mac)
        let live = try await goLiveRecording()
        live.mac.start()
        live.phone.start()
        _ = await eventually { self.isUpToDate(live.phone) }
        live.phone.stop()
        let closed = await eventually { live.macEvents.closed && live.phoneEvents.closed }
        XCTAssertTrue(closed)
    }
}
