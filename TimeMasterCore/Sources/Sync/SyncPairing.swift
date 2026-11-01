import Foundation
import CryptoKit

public final class SyncPairing: @unchecked Sendable {
    public enum Role: Sendable {
        case initiator
        case responder
    }

    public struct Identity: Sendable {
        public var id: String
        public var name: String
        public var platform: String

        public init(id: String, name: String, platform: String) {
            self.id = id
            self.name = name
            self.platform = platform
        }
    }

    private struct Offer: Codable {
        var id: String
        var name: String
        var platform: String
        var pub: Data
        var nonce: Data
    }

    private struct Message: Codable {
        var type: String
        var commit: Data?
        var offer: Offer?
        var mac: Data?
        var reason: String?
    }

    private let role: Role
    private let me: Identity
    private let transport: SyncTransport
    private let lock = NSLock()
    private var decision: CheckedContinuation<Bool, Never>?
    private var decided: Bool?

    public static let decisionTimeout: TimeInterval = 120

    public init(role: Role, me: Identity, transport: SyncTransport) {
        self.role = role
        self.me = me
        self.transport = transport
    }


    public func approve() { settle(true) }
    public func decline() { settle(false) }

    private func settle(_ value: Bool) {
        lock.lock()
        decided = value
        let waiting = decision
        decision = nil
        lock.unlock()
        waiting?.resume(returning: value)
    }

    private func answer() async -> Bool {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let decided {
                lock.unlock()
                continuation.resume(returning: decided)
            } else {
                decision = continuation
                lock.unlock()
            }
        }
    }


    private static func canonical<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    public static func refuse(on transport: SyncTransport, reason: String) async {
        guard let data = try? canonical(Message(type: "refused", reason: reason)) else { return }
        try? await transport.send(data)
    }

    private func send(_ message: Message) async throws {
        try await transport.send(try Self.canonical(message))
    }

    private func receive() async throws -> Message {
        guard let message = try? JSONDecoder().decode(Message.self, from: try await transport.receive()) else { throw SyncFailure.connectionLost }
        if message.type == "refused" { throw SyncFailure.remote(message.reason ?? "That device isn't ready to pair.") }
        if message.type == "decline" { throw SyncFailure.cancelled }
        return message
    }

    static func code(from transcript: Data) -> String {
        let value = transcript.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1_000_000
        let digits = String(format: "%06d", value)
        return "\(digits.prefix(3)) \(digits.suffix(3))"
    }


    public func run(onCode: @escaping @Sendable (String, Identity) -> Void) async throws -> SyncPeerRecord {
        do {
            return try await exchange(onCode: onCode)
        } catch {
            transport.close()
            throw error
        }
    }

    private func exchange(onCode: @escaping @Sendable (String, Identity) -> Void) async throws -> SyncPeerRecord {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let mine = Offer(
            id: me.id, name: me.name, platform: me.platform,
            pub: ephemeral.publicKey.rawRepresentation, nonce: Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        )
        let mineBytes = try Self.canonical(mine)
        let theirs: Offer
        let theirBytes: Data
        switch role {
        case .initiator:
            try await send(Message(type: "commit", commit: Data(SHA256.hash(data: mineBytes))))
            guard let offer = try await receive().offer else { throw SyncFailure.connectionLost }
            theirs = offer
            theirBytes = try Self.canonical(offer)
            try await send(Message(type: "reveal", offer: mine))
        case .responder:
            guard let commit = try await receive().commit else { throw SyncFailure.connectionLost }
            try await send(Message(type: "offer", offer: mine))
            guard let offer = try await receive().offer else { throw SyncFailure.connectionLost }
            theirs = offer
            theirBytes = try Self.canonical(offer)
            guard Data(SHA256.hash(data: theirBytes)) == commit else { throw SyncFailure.remote("That device's pairing message did not check out.") }
        }
        guard theirs.pub.count == 32, theirs.id != me.id else { throw SyncFailure.connectionLost }

        let initiatorBytes = role == .initiator ? mineBytes : theirBytes
        let responderBytes = role == .initiator ? theirBytes : mineBytes
        var hasher = SHA256()
        hasher.update(data: Data("tmax-pair-v1".utf8))
        hasher.update(data: initiatorBytes)
        hasher.update(data: responderBytes)
        let transcript = Data(hasher.finalize())
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirs.pub))
        let material = SymmetricKey(data: shared.withUnsafeBytes { Data($0) })
        func derive(_ info: String) -> SymmetricKey {
            HKDF<SHA256>.deriveKey(inputKeyMaterial: material, salt: transcript, info: Data(info.utf8), outputByteCount: 32)
        }
        let confirmKey = derive("confirm")
        let longTermKey = derive("key")

        onCode(Self.code(from: transcript), Identity(id: theirs.id, name: theirs.name, platform: theirs.platform))
        let approved = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask { await self.answer() }
            group.addTask {
                do { try await Task.sleep(nanoseconds: UInt64(Self.decisionTimeout * 1_000_000_000)) } catch { return false }
                self.settle(false)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        guard approved else {
            try? await send(Message(type: "decline"))
            throw SyncFailure.cancelled
        }

        let roleTag = role == .initiator ? "initiator" : "responder"
        let theirTag = role == .initiator ? "responder" : "initiator"
        let mac = Data(HMAC<SHA256>.authenticationCode(for: Data(roleTag.utf8) + transcript, using: confirmKey))
        do {
            try await send(Message(type: "confirm", mac: mac))
        } catch {
            _ = try await receive()
            throw error
        }
        guard let theirMac = try await receive().mac,
              HMAC<SHA256>.isValidAuthenticationCode(theirMac, authenticating: Data(theirTag.utf8) + transcript, using: confirmKey) else {
            throw SyncFailure.remote("The other device did not confirm the same code.")
        }
        return SyncPeerRecord(
            id: theirs.id, name: theirs.name, platform: theirs.platform,
            key: longTermKey.withUnsafeBytes { Data($0) }, pairedAt: Date()
        )
    }
}
