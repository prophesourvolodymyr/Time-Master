import CryptoKit
import Foundation
@testable import TimeMasterCore

final class MemoryIdentity: EverAgentDeviceIdentity, @unchecked Sendable {
    struct Creation: Equatable {
        let tag: String
        let development: Bool
    }

    private let lock = NSLock()
    private var keys: [String: P256.Signing.PrivateKey] = [:]
    private var createdLog: [Creation] = []
    private var removedLog: [String] = []
    private var signedLog: [Data] = []
    private var creationFailure: EverAgentError?

    var created: [Creation] { lock.withLock { createdLog } }
    var removed: [String] { lock.withLock { removedLog } }
    var signed: [Data] { lock.withLock { signedLog } }

    func failCreation(with error: EverAgentError) {
        lock.withLock { creationFailure = error }
    }

    func publicKey(tag: String) -> P256.Signing.PublicKey? {
        lock.withLock { keys[tag]?.publicKey }
    }

    func createKey(tag: String, development: Bool) throws -> String {
        try lock.withLock {
            if let creationFailure { throw creationFailure }
            let key = P256.Signing.PrivateKey()
            keys[tag] = key
            createdLog.append(Creation(tag: tag, development: development))
            return key.publicKey.x963Representation.base64EncodedString()
        }
    }

    func sign(_ message: Data, tag: String) throws -> String {
        try lock.withLock {
            guard let key = keys[tag] else { throw EverAgentError.unauthorizedDevice }
            signedLog.append(message)
            return try key.signature(for: message).derRepresentation.base64EncodedString()
        }
    }

    func removeKey(tag: String) {
        lock.withLock {
            keys[tag] = nil
            removedLog.append(tag)
        }
    }
}

final class MemoryLink: EverAgentLink, @unchecked Sendable {
    private let lock = NSLock()
    private let queue: AsyncStream<FakeRequest>
    private let sink: AsyncStream<FakeRequest>.Continuation
    private var iterator: AsyncStream<FakeRequest>.AsyncIterator
    private var lineHandler: (@Sendable (UnsafeBufferPointer<UInt8>) throws -> Void)?
    private var closeHandler: (@Sendable (EverAgentError) -> Void)?
    private var responder: (@Sendable (FakeRequest) -> FakeReply?)?
    private var log: [FakeRequest] = []
    private var finished = false
    private var shutdownCalls = 0

    init(responder: (@Sendable (FakeRequest) -> FakeReply?)? = nil) {
        self.responder = responder
        var continuation: AsyncStream<FakeRequest>.Continuation?
        queue = AsyncStream<FakeRequest>(bufferingPolicy: .unbounded) { continuation = $0 }
        sink = continuation!
        iterator = queue.makeAsyncIterator()
    }

    var receivedRequests: [FakeRequest] { lock.withLock { log } }
    var shutdownCount: Int { lock.withLock { shutdownCalls } }
    var isShutDown: Bool { shutdownCount > 0 }

    func setResponder(_ responder: (@Sendable (FakeRequest) -> FakeReply?)?) {
        lock.withLock { self.responder = responder }
    }

    func startReading(
        onLine: @escaping @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @escaping @Sendable (EverAgentError) -> Void
    ) {
        lock.withLock {
            lineHandler = onLine
            closeHandler = onClose
        }
    }

    func send(_ bytes: [UInt8], completion: @escaping @Sendable (EverAgentError?) -> Void) {
        guard !lock.withLock({ finished }) else {
            completion(.connectionClosed)
            return
        }
        let line = bytes.last == 0x0A ? Array(bytes.dropLast()) : bytes
        guard let raw = try? JSONValue(parsing: Data(line)), let id = raw["id"].stringValue, let method = raw["method"].stringValue else {
            completion(nil)
            return
        }
        let request = FakeRequest(id: id, method: method, params: raw["params"], raw: raw)
        let responder = lock.withLock { () -> (@Sendable (FakeRequest) -> FakeReply?)? in
            log.append(request)
            return self.responder
        }
        completion(nil)
        if let reply = responder?(request) {
            switch reply {
            case .result(let value): respond(to: request, result: value)
            case .failure(let code, let message, let details): respond(to: request, code: code, message: message, details: details)
            }
        }
        sink.yield(request)
    }

    func shutdown() {
        let handler = lock.withLock { () -> (@Sendable (EverAgentError) -> Void)? in
            shutdownCalls += 1
            guard !finished else { return nil }
            finished = true
            return closeHandler
        }
        sink.finish()
        handler?(.connectionClosed)
    }

    func nextRequest(timeout: TimeInterval = 3) async throws -> FakeRequest {
        let request = try await withTimeout(timeout, "a request from the client") { await self.iterator.next() }
        guard let request else { throw FakeGatewayFailure(description: "The client closed the link") }
        return request
    }

    func respond(to request: FakeRequest, result: JSONValue) {
        deliver(["id": .string(request.id), "result": result])
    }

    func respond(to request: FakeRequest, code: String, message: String, details: JSONValue? = nil) {
        var error: JSONValue = ["code": .string(code), "message": .string(message)]
        if let details { error["details"] = details }
        deliver(["id": .string(request.id), "error": error])
    }

    func push(topic: String, sequence: Int, sessionId: String? = nil, projectId: String? = nil, data: JSONValue = [:]) {
        var event: JSONValue = ["type": "event", "sequence": .int(sequence), "topic": .string(topic), "data": data]
        if let sessionId { event["sessionId"] = .string(sessionId) }
        if let projectId { event["projectId"] = .string(projectId) }
        deliver(event)
    }

    func deliver(_ value: JSONValue) {
        deliverLine(value.jsonString)
    }

    func deliverLine(_ text: String) {
        var copy = text
        let handler = lock.withLock { lineHandler }
        do {
            try copy.withUTF8 { try handler?($0) }
        } catch {
            drop(error as? EverAgentError ?? .protocol(String(describing: error)))
        }
    }

    func drop(_ reason: EverAgentError = .connectionClosed) {
        let handler = lock.withLock { () -> (@Sendable (EverAgentError) -> Void)? in
            guard !finished else { return nil }
            finished = true
            return closeHandler
        }
        sink.finish()
        handler?(reason)
    }
}

actor OpeningGate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    private(set) var arrivals = 0

    func pass() async {
        arrivals += 1
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        isOpen = true
        for continuation in waiting { continuation.resume() }
        waiting = []
    }
}

func closedLoopbackPort() -> UInt16 {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    defer { close(descriptor) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
    let size = socklen_t(MemoryLayout<sockaddr_in>.size)
    withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = bind(descriptor, $0, size) } }
    var length = size
    withUnsafeMutablePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(descriptor, $0, &length) } }
    return UInt16(bigEndian: address.sin_port)
}
