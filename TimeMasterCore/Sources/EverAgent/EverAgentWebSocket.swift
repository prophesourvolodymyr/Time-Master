import Foundation

enum EverAgentHandshake {
    static func signedPayload(serverId: String, nonce: String) -> Data {
        Data("ompp.v1\n\(serverId)\n\(nonce)".utf8)
    }

    static func authenticate(
        profile: EverAgentRemoteProfile,
        identity: EverAgentDeviceIdentity,
        receive: () async throws -> String,
        send: (String) async throws -> Void
    ) async throws {
        let challenge = try message(try await receive())
        guard challenge["type"].stringValue == "challenge", let nonce = challenge["nonce"].stringValue, !nonce.isEmpty else {
            throw EverAgentError.protocol("The gateway did not open with an authentication challenge.")
        }
        guard challenge["serverId"].stringValue == profile.serverId else { throw EverAgentError.untrustedServer }
        let signature = try identity.sign(signedPayload(serverId: profile.serverId, nonce: nonce), tag: profile.keyTag)
        let answer: JSONValue = ["type": "authenticate", "deviceId": .string(profile.deviceId), "signature": .string(signature)]
        try await send(answer.jsonString)
        let verdict: JSONValue
        do {
            verdict = try message(try await receive())
        } catch EverAgentError.connectionClosed {
            throw EverAgentError.unauthorizedDevice
        }
        guard verdict["type"].stringValue == "authenticated" else { throw EverAgentError.unauthorizedDevice }
    }

    private static func message(_ text: String) throws -> JSONValue {
        do {
            return try JSONValue(parsing: text)
        } catch {
            throw EverAgentError.protocol("The gateway sent a handshake message that is not JSON.")
        }
    }
}

final class EverAgentWebSocket: EverAgentLink, @unchecked Sendable {
    static let handshakeSeconds: TimeInterval = 15
    static let maximumMessageBytes = 256 * 1024 * 1024

    private let session: URLSession
    private let trust: EverAgentPinnedTrust
    private let socket: URLSessionWebSocketTask
    private let address: String
    private let lock = NSLock()
    private var isShutDown = false

    private init(endpoint: URL, address: String, fingerprint: String) {
        (session, trust) = EverAgentPinnedTrust.makeSession(fingerprint: fingerprint, timeout: Self.handshakeSeconds)
        socket = session.webSocketTask(with: endpoint)
        socket.maximumMessageSize = Self.maximumMessageBytes
        self.address = address
    }

    static func connect(profile: EverAgentRemoteProfile, identity: EverAgentDeviceIdentity) async throws -> EverAgentWebSocket {
        let endpoint = try EverAgentGatewayAddress.endpoint(profile.url, scheme: "wss", path: "/v1/connect")
        let link = EverAgentWebSocket(endpoint: endpoint, address: profile.url, fingerprint: profile.certificateSHA256)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await withTaskCancellationHandler {
                        link.socket.resume()
                        try await EverAgentHandshake.authenticate(profile: profile, identity: identity, receive: link.receiveText, send: link.sendText)
                    } onCancel: {
                        link.shutdown()
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(Self.handshakeSeconds * 1_000_000_000))
                    throw EverAgentError.gatewayNotRunning(path: profile.url)
                }
                try await group.next()
                group.cancelAll()
            }
        } catch is CancellationError {
            link.shutdown()
            throw EverAgentError.cancelled
        } catch {
            link.shutdown()
            throw error
        }
        return link
    }

    func startReading(
        onLine: @escaping @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @escaping @Sendable (EverAgentError) -> Void
    ) {
        Task.detached(priority: .userInitiated) { [self] in
            let reason: EverAgentError
            do {
                while true {
                    switch try await socket.receive() {
                    case .string(var text): try text.withUTF8 { try onLine($0) }
                    case .data(let data): try data.withUnsafeBytes { try onLine($0.bindMemory(to: UInt8.self)) }
                    @unknown default: break
                    }
                }
            } catch {
                reason = error as? EverAgentError ?? .connectionClosed
            }
            shutdown()
            onClose(reason)
        }
    }

    func send(_ bytes: [UInt8], completion: @escaping @Sendable (EverAgentError?) -> Void) {
        guard !lock.withLock({ isShutDown }) else {
            completion(.connectionClosed)
            return
        }
        let line = bytes.last == 0x0A ? bytes.dropLast() : bytes[...]
        socket.send(.string(String(decoding: line, as: UTF8.self))) { failure in
            completion(failure == nil ? nil : .connectionClosed)
        }
    }

    func shutdown() {
        let first = lock.withLock { () -> Bool in
            if isShutDown { return false }
            isShutDown = true
            return true
        }
        guard first else { return }
        socket.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }

    private func receiveText() async throws -> String {
        do {
            switch try await socket.receive() {
            case .string(let text): return text
            case .data(let data): return String(decoding: data, as: UTF8.self)
            @unknown default: throw EverAgentError.protocol("The gateway sent a message this app cannot read.")
            }
        } catch {
            throw failure(error)
        }
    }

    private func sendText(_ text: String) async throws {
        do {
            try await socket.send(.string(text))
        } catch {
            throw failure(error)
        }
    }

    private func failure(_ error: Error) -> EverAgentError {
        EverAgentNetworkFailure.classify(error, address: address, certificateRejected: trust.certificateRejected)
    }
}
