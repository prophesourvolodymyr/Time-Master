import Foundation
import CryptoKit

public protocol SyncTransport: Sendable {
    func send(_ frame: Data) async throws
    func receive() async throws -> Data
    func close()
}

struct SyncCipher {
    private let key: SymmetricKey
    private var counter: UInt64 = 0

    init(key: SymmetricKey) {
        self.key = key
    }

    private mutating func nextNonce() throws -> ChaChaPoly.Nonce {
        var bytes = Data(count: 4)
        withUnsafeBytes(of: counter.bigEndian) { bytes.append(contentsOf: $0) }
        counter += 1
        return try ChaChaPoly.Nonce(data: bytes)
    }

    mutating func seal(_ plaintext: Data) throws -> Data {
        let box = try ChaChaPoly.seal(plaintext, using: key, nonce: try nextNonce())
        return box.ciphertext + box.tag
    }

    mutating func open(_ sealed: Data) throws -> Data {
        guard sealed.count >= 16 else { throw SyncFailure.connectionLost }
        let body = sealed.prefix(sealed.count - 16)
        let tag = sealed.suffix(16)
        let box = try ChaChaPoly.SealedBox(nonce: try nextNonce(), ciphertext: body, tag: tag)
        return try ChaChaPoly.open(box, using: key)
    }
}

public final class SyncSecureChannel: @unchecked Sendable {
    public let peer: SyncPeerRecord
    private let transport: SyncTransport
    private let sender: Sender
    private let receiverLock = NSLock()
    private var receiver: SyncCipher

    private actor Sender {
        private var cipher: SyncCipher
        private let transport: SyncTransport

        init(cipher: SyncCipher, transport: SyncTransport) {
            self.cipher = cipher
            self.transport = transport
        }

        func send(_ message: Data) async throws {
            try await transport.send(try cipher.seal(message))
        }
    }

    private init(peer: SyncPeerRecord, transport: SyncTransport, sending: SyncCipher, receiving: SyncCipher) {
        self.peer = peer
        self.transport = transport
        self.sender = Sender(cipher: sending, transport: transport)
        self.receiver = receiving
    }

    public func send(_ message: Data) async throws {
        try await sender.send(message)
    }

    public func receive() async throws -> Data {
        try open(try await transport.receive())
    }

    private func open(_ sealed: Data) throws -> Data {
        receiverLock.lock()
        defer { receiverLock.unlock() }
        do {
            return try receiver.open(sealed)
        } catch {
            transport.close()
            throw SyncFailure.connectionLost
        }
    }

    public func close() {
        transport.close()
    }


    private struct Hello: Codable {
        var v: Int
        var id: String
        var pub: Data
        var nonce: Data
    }

    private struct Reply: Codable {
        var id: String?
        var pub: Data?
        var nonce: Data?
        var proof: Data?
        var error: String?
    }

    private struct Finish: Codable {
        var proof: Data
    }

    private static let label = Data("tmax-sync-v1".utf8)

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func random(_ count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }

    private static func transcript(hello: Data, id: String, pub: Data, nonce: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: label)
        hasher.update(data: hello)
        hasher.update(data: Data(id.utf8))
        hasher.update(data: pub)
        hasher.update(data: nonce)
        return Data(hasher.finalize())
    }

    private static func proof(_ role: String, key: Data, transcript: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(role.utf8) + transcript, using: SymmetricKey(data: key)))
    }

    private static func isValid(_ proof: Data, role: String, key: Data, transcript: Data) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(proof, authenticating: Data(role.utf8) + transcript, using: SymmetricKey(data: key))
    }

    private static func keys(shared: SharedSecret, secret: Data, transcript: Data) -> (clientToServer: SymmetricKey, serverToClient: SymmetricKey) {
        let material = shared.withUnsafeBytes { Data($0) } + secret
        func derive(_ info: String) -> SymmetricKey {
            HKDF<SHA256>.deriveKey(
                inputKeyMaterial: SymmetricKey(data: material), salt: transcript, info: Data(info.utf8), outputByteCount: 32
            )
        }
        return (derive("tmax c2s"), derive("tmax s2c"))
    }

    public static func connect(transport: SyncTransport, myID: String, peer: SyncPeerRecord) async throws -> SyncSecureChannel {
        do {
            return try await handshake(transport: transport, myID: myID, peer: peer)
        } catch {
            transport.close()
            throw error
        }
    }

    private static func handshake(transport: SyncTransport, myID: String, peer: SyncPeerRecord) async throws -> SyncSecureChannel {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let hello = try encode(Hello(v: 1, id: myID, pub: ephemeral.publicKey.rawRepresentation, nonce: random(16)))
        try await transport.send(hello)
        guard let reply = try? JSONDecoder().decode(Reply.self, from: try await transport.receive()) else { throw SyncFailure.connectionLost }
        if reply.error != nil { throw SyncFailure.notPaired }
        guard let id = reply.id, id == peer.id, let pub = reply.pub, let nonce = reply.nonce, let theirProof = reply.proof else {
            throw SyncFailure.notPaired
        }
        let transcript = transcript(hello: hello, id: id, pub: pub, nonce: nonce)
        guard isValid(theirProof, role: "server", key: peer.key, transcript: transcript) else { throw SyncFailure.notPaired }
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: pub))
        let derived = keys(shared: shared, secret: peer.key, transcript: transcript)
        try await transport.send(try encode(Finish(proof: proof("client", key: peer.key, transcript: transcript))))
        return SyncSecureChannel(peer: peer, transport: transport, sending: SyncCipher(key: derived.clientToServer), receiving: SyncCipher(key: derived.serverToClient))
    }

    public static func accept(transport: SyncTransport, myID: String, lookup: @Sendable (String) -> SyncPeerRecord?) async throws -> SyncSecureChannel {
        do {
            return try await answer(transport: transport, myID: myID, lookup: lookup)
        } catch {
            transport.close()
            throw error
        }
    }

    private static func answer(transport: SyncTransport, myID: String, lookup: @Sendable (String) -> SyncPeerRecord?) async throws -> SyncSecureChannel {
        let hello = try await transport.receive()
        guard let message = try? JSONDecoder().decode(Hello.self, from: hello), message.v == 1, message.pub.count == 32 else {
            throw SyncFailure.connectionLost
        }
        guard let peer = lookup(message.id) else {
            try? await transport.send(try encode(Reply(error: "unknown")))
            throw SyncFailure.notPaired
        }
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let pub = ephemeral.publicKey.rawRepresentation
        let nonce = random(16)
        let transcript = transcript(hello: hello, id: myID, pub: pub, nonce: nonce)
        try await transport.send(try encode(Reply(id: myID, pub: pub, nonce: nonce, proof: proof("server", key: peer.key, transcript: transcript))))
        guard let finish = try? JSONDecoder().decode(Finish.self, from: try await transport.receive()),
              isValid(finish.proof, role: "client", key: peer.key, transcript: transcript) else {
            throw SyncFailure.notPaired
        }
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: message.pub))
        let derived = keys(shared: shared, secret: peer.key, transcript: transcript)
        return SyncSecureChannel(peer: peer, transport: transport, sending: SyncCipher(key: derived.serverToClient), receiving: SyncCipher(key: derived.clientToServer))
    }
}

final class SyncFrameQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [Data] = []
    private var waiter: CheckedContinuation<Data, Error>?
    private var isClosed = false

    @discardableResult
    func push(_ frame: Data) -> Bool {
        let (accepted, reader) = enqueue(frame)
        reader?.resume(returning: frame)
        return accepted
    }

    private func enqueue(_ frame: Data) -> (Bool, CheckedContinuation<Data, Error>?) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return (false, nil) }
        if let waiter {
            self.waiter = nil
            return (true, waiter)
        }
        frames.append(frame)
        return (true, nil)
    }

    func close() {
        let reader = markClosed()
        reader?.resume(throwing: SyncFailure.connectionLost)
    }

    private func markClosed() -> CheckedContinuation<Data, Error>? {
        lock.lock()
        defer { lock.unlock() }
        isClosed = true
        let reader = waiter
        waiter = nil
        return reader
    }

    func pop() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            switch take(continuation) {
            case .frame(let frame): continuation.resume(returning: frame)
            case .closed: continuation.resume(throwing: SyncFailure.connectionLost)
            case .waiting: break
            }
        }
    }

    private enum Taken {
        case frame(Data)
        case closed
        case waiting
    }

    private func take(_ continuation: CheckedContinuation<Data, Error>) -> Taken {
        lock.lock()
        defer { lock.unlock() }
        if !frames.isEmpty { return .frame(frames.removeFirst()) }
        if isClosed { return .closed }
        waiter = continuation
        return .waiting
    }
}

public final class SyncMemoryTransport: SyncTransport, @unchecked Sendable {
    private let inbox: SyncFrameQueue
    private let outbox: SyncFrameQueue

    private init(inbox: SyncFrameQueue, outbox: SyncFrameQueue) {
        self.inbox = inbox
        self.outbox = outbox
    }

    public static func pair() -> (SyncMemoryTransport, SyncMemoryTransport) {
        let toB = SyncFrameQueue()
        let toA = SyncFrameQueue()
        return (SyncMemoryTransport(inbox: toA, outbox: toB), SyncMemoryTransport(inbox: toB, outbox: toA))
    }

    public func send(_ frame: Data) async throws {
        guard outbox.push(frame) else { throw SyncFailure.connectionLost }
    }

    public func receive() async throws -> Data {
        try await inbox.pop()
    }

    public func close() {
        inbox.close()
        outbox.close()
    }
}
