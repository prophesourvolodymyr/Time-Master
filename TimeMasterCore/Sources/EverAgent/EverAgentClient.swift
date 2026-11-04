import Foundation

public actor EverAgentClient {
    public static let defaultRequestTimeout: TimeInterval = 75
    public static let gatewayRequestLimitBytes = 128 * 1024 * 1024
    static let remoteRequestLimitBytes = 16 * 1024 * 1024

    #if os(macOS)
    public static var defaultSocketPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ompp/server/control.sock").path
    }
    #endif

    public nonisolated let socketPath: String
    public nonisolated let isRemote: Bool
    public nonisolated let requestTimeout: TimeInterval
    nonisolated let requestLimitBytes: Int
    private let openLink: @Sendable () async throws -> EverAgentLink

    private struct Link {
        let id: Int
        let socket: EverAgentLink
        let consumer: Task<Void, Never>
    }

    private struct Pending {
        let number: Int
        let method: String
        let limit: TimeInterval
        let continuation: CheckedContinuation<JSONValue, Error>
        var timer: Task<Void, Never>?
    }

    private struct Subscription {
        let token: UUID
        let continuation: AsyncStream<EverAgentEvent>.Continuation
        let filter: EverAgentEventFilter?
    }

    private var link: Link?
    private var pending: [String: Pending] = [:]
    private var subscription: Subscription?
    private var requestCounter = 0
    private var linkCounter = 0
    private var generation = 0

    init(
        isRemote: Bool,
        requestTimeout: TimeInterval,
        requestLimitBytes: Int,
        socketPath: String = "",
        openLink: @escaping @Sendable () async throws -> EverAgentLink
    ) {
        self.socketPath = socketPath
        self.isRemote = isRemote
        self.requestTimeout = requestTimeout
        self.requestLimitBytes = requestLimitBytes
        self.openLink = openLink
    }

    #if os(macOS)
    public init(
        socketPath: String = EverAgentClient.defaultSocketPath,
        requestTimeout: TimeInterval = EverAgentClient.defaultRequestTimeout,
        requestLimitBytes: Int = EverAgentClient.gatewayRequestLimitBytes
    ) {
        self.init(isRemote: false, requestTimeout: requestTimeout, requestLimitBytes: requestLimitBytes, socketPath: socketPath) {
            try EverAgentSocket.connect(to: socketPath)
        }
    }
    #endif

    public init(
        remote profile: EverAgentRemoteProfile,
        identity: EverAgentDeviceIdentity = EverAgentKeychainIdentity(),
        requestTimeout: TimeInterval = EverAgentClient.defaultRequestTimeout
    ) {
        self.init(isRemote: true, requestTimeout: requestTimeout, requestLimitBytes: Self.remoteRequestLimitBytes) {
            try await EverAgentWebSocket.connect(profile: profile, identity: identity)
        }
    }

    deinit {
        link?.consumer.cancel()
        link?.socket.shutdown()
        subscription?.continuation.finish()
    }

    public var isConnected: Bool {
        link != nil
    }

    public func connect() async throws {
        guard link == nil else { return }
        let started = generation
        let socket = try await openLink()
        guard started == generation else {
            socket.shutdown()
            throw EverAgentError.connectionClosed
        }
        guard link == nil else {
            socket.shutdown()
            return
        }
        linkCounter += 1
        let id = linkCounter
        let (incoming, sink) = makeEverAgentStream(of: EverAgentIncoming.self)
        socket.startReading(
            onLine: { line in
                if let item = try EverAgentWire.decode(line) { sink.yield(item) }
            },
            onClose: { reason in
                sink.yield(.closed(reason))
                sink.finish()
            }
        )
        let consumer = Task.detached(priority: .userInitiated) { [weak self] in
            for await item in incoming {
                guard let self else { return }
                await self.receive(item, link: id)
            }
        }
        link = Link(id: id, socket: socket, consumer: consumer)
    }

    public func close() {
        generation += 1
        teardown(.connectionClosed)
    }

    public func request(_ method: String, params: [String: JSONValue] = [:], timeout: TimeInterval? = nil) async throws -> JSONValue {
        if Task.isCancelled { throw EverAgentError.cancelled }
        guard let link else { throw EverAgentError.connectionClosed }
        requestCounter += 1
        let number = requestCounter
        let id = "tmax-\(number)"
        let line = try EverAgentWire.encodeRequest(id: id, method: method, params: params, maximumBytes: requestLimitBytes)
        let limit = timeout ?? requestTimeout
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONValue, Error>) in
                var entry = Pending(number: number, method: method, limit: limit, continuation: continuation, timer: nil)
                if limit.isFinite && limit > 0 { entry.timer = startTimer(for: id, after: limit) }
                pending[id] = entry
                transmit(line, as: id, over: link)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    public func subscribe(sessionId: String? = nil, topics: [String]? = nil) async throws -> AsyncStream<EverAgentEvent> {
        guard link != nil else { throw EverAgentError.connectionClosed }
        let token = UUID()
        let (stream, continuation) = makeEverAgentStream(of: EverAgentEvent.self)
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.endSubscription(token) }
        }
        subscription?.continuation.finish()
        subscription = Subscription(
            token: token,
            continuation: continuation,
            filter: isRemote ? EverAgentEventFilter(sessionId: sessionId, topics: topics.map(Set.init)) : nil
        )
        guard !isRemote else { return stream }
        var params: [String: JSONValue] = [:]
        if let sessionId { params["sessionId"] = .string(sessionId) }
        if let topics { params["topics"] = .array(topics.map { .string($0) }) }
        do {
            let result = try await request("events.subscribe", params: params)
            guard result["subscribed"].boolValue else {
                throw EverAgentError.protocol("The gateway did not confirm the event subscription.")
            }
        } catch {
            endSubscription(token)
            if case EverAgentError.remote(let code, _, _) = error, code == EverAgentErrorCode.notFound {
                throw EverAgentError.gatewayTooOld
            }
            throw error
        }
        return stream
    }

    private func receive(_ item: EverAgentIncoming, link id: Int) {
        guard link?.id == id else { return }
        switch item {
        case .response(let requestID, let outcome):
            complete(requestID, with: outcome)
        case .event(let event):
            guard let subscription, subscription.filter?.accepts(event) ?? true else { return }
            subscription.continuation.yield(event)
        case .closed(let reason):
            teardown(reason)
        }
    }

    private func complete(_ requestID: String, with outcome: Result<JSONValue, EverAgentError>) {
        var key = requestID
        if requestID.isEmpty {
            guard case .failure = outcome, let oldest = pending.min(by: { $0.value.number < $1.value.number }) else { return }
            key = oldest.key
        }
        guard let entry = pending.removeValue(forKey: key) else { return }
        entry.timer?.cancel()
        switch outcome {
        case .success(let value): entry.continuation.resume(returning: value)
        case .failure(let error): entry.continuation.resume(throwing: error)
        }
    }

    private func transmit(_ line: [UInt8], as id: String, over link: Link) {
        link.socket.send(line) { [weak self] failure in
            guard let failure, let self else { return }
            Task { await self.fail(id, with: failure) }
        }
    }

    private func startTimer(for id: String, after seconds: TimeInterval) -> Task<Void, Never> {
        let nanoseconds = UInt64(min(seconds, 315_360_000) * 1_000_000_000)
        return Task.detached { [weak self] in
            do { try await Task.sleep(nanoseconds: nanoseconds) } catch { return }
            await self?.expire(id)
        }
    }

    private func fail(_ id: String, with error: EverAgentError) {
        guard let entry = pending.removeValue(forKey: id) else { return }
        entry.timer?.cancel()
        entry.continuation.resume(throwing: error)
    }

    private func cancel(_ id: String) {
        fail(id, with: .cancelled)
    }

    private func expire(_ id: String) {
        guard let entry = pending[id] else { return }
        fail(id, with: .timeout(operation: entry.method, after: entry.limit))
    }

    private func endSubscription(_ token: UUID) {
        guard subscription?.token == token else { return }
        subscription?.continuation.finish()
        subscription = nil
    }

    private func teardown(_ reason: EverAgentError) {
        guard let current = link else { return }
        link = nil
        current.consumer.cancel()
        current.socket.shutdown()
        let failed = pending
        pending = [:]
        for entry in failed.values {
            entry.timer?.cancel()
            entry.continuation.resume(throwing: reason)
        }
        subscription?.continuation.finish()
        subscription = nil
    }
}

func makeEverAgentStream<Element: Sendable>(of type: Element.Type) -> (AsyncStream<Element>, AsyncStream<Element>.Continuation) {
    var continuation: AsyncStream<Element>.Continuation?
    let stream = AsyncStream<Element>(bufferingPolicy: .unbounded) { continuation = $0 }
    return (stream, continuation!)
}
