#if os(macOS)
import Darwin
import Foundation
@testable import TimeMasterCore

struct FakeGatewayFailure: Error, CustomStringConvertible {
    let description: String
}

struct FakeRequest: Sendable {
    let id: String
    let method: String
    let params: JSONValue
    let raw: JSONValue
}

enum FakeReply {
    case result(JSONValue)
    case failure(code: String, message: String, details: JSONValue? = nil)
}

final class FakeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int { lock.withLock { stored } }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            stored += 1
            return stored
        }
    }
}

final class FakeBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private enum Race<Value: Sendable>: Sendable {
    case finished(Value)
    case expired
    case timerStopped
}

func withTimeout<Value: Sendable>(_ seconds: TimeInterval, _ what: String, _ body: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Race<Value>.self) { group in
        group.addTask { .finished(try await body()) }
        group.addTask {
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) } catch { return .timerStopped }
            return .expired
        }
        defer { group.cancelAll() }
        while let result = try await group.next() {
            switch result {
            case .finished(let value): return value
            case .expired: throw FakeGatewayFailure(description: "Timed out after \(seconds) s waiting for \(what)")
            case .timerStopped: continue
            }
        }
        throw FakeGatewayFailure(description: "No result for \(what)")
    }
}

final class EventReader: @unchecked Sendable {
    private var iterator: AsyncStream<EverAgentEvent>.AsyncIterator

    init(_ stream: AsyncStream<EverAgentEvent>) {
        iterator = stream.makeAsyncIterator()
    }

    func next(timeout: TimeInterval = 3) async throws -> EverAgentEvent? {
        try await withTimeout(timeout, "an event") { await self.iterator.next() }
    }

    func expectEvent(timeout: TimeInterval = 3) async throws -> EverAgentEvent {
        guard let event = try await next(timeout: timeout) else { throw FakeGatewayFailure(description: "The event stream finished early") }
        return event
    }
}

final class FakeConnection: @unchecked Sendable {
    private let descriptor: Int32
    private let writeLock = NSLock()
    private let stateLock = NSLock()
    private let queue: AsyncStream<FakeRequest>
    private let sink: AsyncStream<FakeRequest>.Continuation
    private var iterator: AsyncStream<FakeRequest>.AsyncIterator
    private var log: [FakeRequest] = []
    private var responder: (@Sendable (FakeRequest) -> FakeReply?)?
    private var closed = false
    private let gate = DispatchSemaphore(value: 0)
    private let startPaused: Bool

    init(descriptor: Int32, responder: (@Sendable (FakeRequest) -> FakeReply?)?, startPaused: Bool = false) {
        self.startPaused = startPaused
        self.descriptor = descriptor
        self.responder = responder
        var continuation: AsyncStream<FakeRequest>.Continuation?
        queue = AsyncStream<FakeRequest>(bufferingPolicy: .unbounded) { continuation = $0 }
        sink = continuation!
        iterator = queue.makeAsyncIterator()
        var enabled: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) & ~O_NONBLOCK)
        let thread = Thread { [self] in
            if startPaused { gate.wait() }
            readLoop()
        }
        thread.name = "fake-gateway-connection"
        thread.start()
    }

    var receivedRequests: [FakeRequest] { stateLock.withLock { log } }

    func setResponder(_ responder: (@Sendable (FakeRequest) -> FakeReply?)?) {
        stateLock.withLock { self.responder = responder }
    }

    func nextRequest(timeout: TimeInterval = 5) async throws -> FakeRequest {
        let request = try await withTimeout(timeout, "a request from the client") { await self.iterator.next() }
        guard let request else { throw FakeGatewayFailure(description: "The client closed the connection") }
        return request
    }

    func waitForPeerClose(timeout: TimeInterval = 5) async throws {
        let leftover = try await withTimeout(timeout, "the client to close its end") { await self.iterator.next() }
        if let leftover { throw FakeGatewayFailure(description: "Unexpected request \(leftover.method) before the client closed") }
    }

    func respond(to request: FakeRequest, result: JSONValue) {
        send(["id": .string(request.id), "result": result])
    }

    func respond(to request: FakeRequest, code: String, message: String, details: JSONValue? = nil) {
        send(["id": .string(request.id), "error": Self.errorObject(code: code, message: message, details: details)])
    }

    func push(topic: String, sequence: Int, sessionId: String? = nil, projectId: String? = nil, data: JSONValue = [:]) {
        send(Self.eventObject(topic: topic, sequence: sequence, sessionId: sessionId, projectId: projectId, data: data))
    }

    func send(_ value: JSONValue) {
        sendRaw(Data(value.serialized() + [0x0A]))
    }

    func sendLine(_ text: String) {
        sendRaw(Data((text + "\n").utf8))
    }

    func sendRaw(_ data: Data) {
        writeLock.withLock {
            guard !stateLock.withLock({ closed }) else { return }
            Self.writeAll(data, to: descriptor)
        }
    }

    func sendChunked(_ data: Data, chunkSize: Int, pauseMilliseconds: UInt32 = 0) {
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            sendRaw(data.subdata(in: offset..<end))
            offset = end
            if pauseMilliseconds > 0 { usleep(pauseMilliseconds * 1000) }
        }
    }

    func closeFromServer() {
        stateLock.withLock {
            guard !closed else { return }
            Darwin.shutdown(descriptor, SHUT_RDWR)
        }
        gate.signal()
    }

    func waitUntilClosed(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !stateLock.withLock({ closed }) {
            guard Date() < deadline else { throw FakeGatewayFailure(description: "The connection did not close") }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    static func errorObject(code: String, message: String, details: JSONValue?) -> JSONValue {
        var error: JSONValue = ["code": .string(code), "message": .string(message)]
        if let details { error["details"] = details }
        return error
    }

    static func eventObject(topic: String, sequence: Int, sessionId: String?, projectId: String?, data: JSONValue) -> JSONValue {
        var event: JSONValue = ["type": "event", "sequence": .int(sequence), "topic": .string(topic), "data": data]
        if let sessionId { event["sessionId"] = .string(sessionId) }
        if let projectId { event["projectId"] = .string(projectId) }
        return event
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) {
        data.withUnsafeBytes { buffer in
            guard var cursor = buffer.baseAddress else { return }
            var remaining = buffer.count
            while remaining > 0 {
                let written = Darwin.write(descriptor, cursor, remaining)
                if written > 0 {
                    cursor = cursor.advanced(by: written)
                    remaining -= written
                } else if written < 0 && errno == EINTR {
                    continue
                } else {
                    return
                }
            }
        }
    }

    private func readLoop() {
        var pending = Data()
        let chunk = UnsafeMutableRawPointer.allocate(byteCount: 64 * 1024, alignment: 16)
        defer { chunk.deallocate() }
        while true {
            let count = Darwin.read(descriptor, chunk, 64 * 1024)
            if count < 0 && errno == EINTR { continue }
            if count <= 0 { break }
            pending.append(Data(bytes: chunk, count: count))
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = pending.subdata(in: pending.startIndex..<newline)
                pending.removeSubrange(pending.startIndex...newline)
                handle(line)
            }
        }
        sink.finish()
        writeLock.withLock {
            stateLock.withLock { closed = true }
            Darwin.close(descriptor)
        }
    }

    private func handle(_ line: Data) {
        guard let raw = try? JSONValue(parsing: line), let id = raw["id"].stringValue, let method = raw["method"].stringValue else { return }
        let request = FakeRequest(id: id, method: method, params: raw["params"], raw: raw)
        let responder = stateLock.withLock { () -> (@Sendable (FakeRequest) -> FakeReply?)? in
            log.append(request)
            return self.responder
        }
        if let reply = responder?(request) {
            switch reply {
            case .result(let value): respond(to: request, result: value)
            case .failure(let code, let message, let details): respond(to: request, code: code, message: message, details: details)
            }
        }
        sink.yield(request)
    }
}

final class FakeGateway: @unchecked Sendable {
    let path: String
    private let listener: Int32
    private let source: DispatchSourceRead
    private let queue = DispatchQueue(label: "fake-gateway-accept")
    private let accepted: AsyncStream<FakeConnection>
    private let acceptedSink: AsyncStream<FakeConnection>.Continuation
    private var acceptedIterator: AsyncStream<FakeConnection>.AsyncIterator
    private let lock = NSLock()
    private var connections: [FakeConnection] = []
    private var responder: (@Sendable (FakeRequest) -> FakeReply?)?
    private var stopped = false
    private var totalConnections = 0
    private let pausesReading: Bool

    init(pausesReading: Bool = false, responder: (@Sendable (FakeRequest) -> FakeReply?)? = nil) throws {
        let name = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        path = "/tmp/tmax-ea-\(name).sock"
        self.pausesReading = pausesReading
        self.responder = responder
        var continuation: AsyncStream<FakeConnection>.Continuation?
        accepted = AsyncStream<FakeConnection>(bufferingPolicy: .unbounded) { continuation = $0 }
        acceptedSink = continuation!
        acceptedIterator = accepted.makeAsyncIterator()
        var address = try EverAgentPOSIX.socketAddress(for: path)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw FakeGatewayFailure(description: "socket() failed: \(errno)") }
        unlink(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(descriptor, 16) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw FakeGatewayFailure(description: "bind/listen failed: \(code)")
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        listener = descriptor
        source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [unowned self] in acceptPending() }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
    }

    func setResponder(_ responder: (@Sendable (FakeRequest) -> FakeReply?)?) {
        lock.withLock { self.responder = responder }
    }

    func nextConnection(timeout: TimeInterval = 5) async throws -> FakeConnection {
        let connection = try await withTimeout(timeout, "the client to connect") { await self.acceptedIterator.next() }
        guard let connection else { throw FakeGatewayFailure(description: "The gateway stopped before a client connected") }
        return connection
    }

    var connectionCount: Int { lock.withLock { totalConnections } }

    func stop() {
        let alreadyStopped = lock.withLock { () -> Bool in
            let was = stopped
            stopped = true
            return was
        }
        guard !alreadyStopped else { return }
        source.cancel()
        unlink(path)
        acceptedSink.finish()
        let open = lock.withLock { () -> [FakeConnection] in
            let current = connections
            connections = []
            return current
        }
        for connection in open { connection.closeFromServer() }
    }

    private func acceptPending() {
        while true {
            let client = Darwin.accept(listener, nil, nil)
            if client < 0 { return }
            let responder = lock.withLock { self.responder }
            let connection = FakeConnection(descriptor: client, responder: responder, startPaused: pausesReading)
            lock.withLock {
                connections.append(connection)
                totalConnections += 1
            }
            acceptedSink.yield(connection)
        }
    }
}
#endif
