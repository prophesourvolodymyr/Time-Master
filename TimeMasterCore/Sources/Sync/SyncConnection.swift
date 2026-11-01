import Foundation

public enum SyncIntent: UInt8, Sendable {
    case sync = 1
    case pair = 2

    public func announce(on transport: SyncTransport) async throws {
        try await transport.send(Data([rawValue]))
    }

    public static func read(from transport: SyncTransport) async throws -> SyncIntent {
        let frame = try await transport.receive()
        guard frame.count == 1, let intent = SyncIntent(rawValue: frame[frame.startIndex]) else { throw SyncFailure.connectionLost }
        return intent
    }
}

public enum SyncNotice: String, Codable, Sendable {
    case changed
    case syncing
    case synced
    case failed
}

struct SyncWireMessage {
    enum Kind: UInt8 {
        case request = 1
        case response = 2
        case failure = 3
        case notice = 4
    }

    var kind: Kind
    var id: UInt32
    var header: Data
    var payload: Data = Data()

    func encoded() -> Data {
        var data = Data()
        data.append(kind.rawValue)
        withUnsafeBytes(of: id.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(header.count).bigEndian) { data.append(contentsOf: $0) }
        data.append(header)
        data.append(payload)
        return data
    }

    static func decode(_ data: Data) throws -> SyncWireMessage {
        let bytes = [UInt8](data)
        guard bytes.count >= 9, let kind = Kind(rawValue: bytes[0]) else { throw SyncFailure.connectionLost }
        func number(_ from: Int) -> UInt32 { bytes[from..<from + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } }
        let headerLength = Int(number(5))
        guard 9 + headerLength <= bytes.count else { throw SyncFailure.connectionLost }
        return SyncWireMessage(
            kind: kind, id: number(1),
            header: Data(bytes[9..<9 + headerLength]), payload: Data(bytes[(9 + headerLength)...])
        )
    }
}

private enum SyncOp: String {
    case index, bundles, readFile, pushStart, pushFile, pushCommit, shardLines, mergeHistory, configPayload, applyConfig
}

private struct Envelope<Params: Codable>: Codable {
    var op: String
    var params: Params
}

private struct OpName: Codable {
    var op: String
}

private struct Empty: Codable {}
private struct Keys: Codable { var keys: [String] }
private struct ReadFileParams: Codable { var unitKey: String; var path: String; var offset: Int64; var length: Int }
private struct PushFileParams: Codable { var token: String; var unitKey: String; var path: String; var offset: Int64 }
private struct TokenParams: Codable { var token: String }
private struct MonthParams: Codable { var month: String }
private struct MergeHistoryParams: Codable { var month: String; var lines: [String]; var tombstones: [String: SyncStamp] }
private struct ApplyConfigParams: Codable { var payload: SyncConfigPayload; var expectedHash: String? }
private struct ConfigAnswer: Codable { var payload: SyncConfigPayload? }
private struct AppliedAnswer: Codable { var applied: Bool }
private struct FailureText: Codable { var message: String }
private struct NoticeText: Codable { var notice: SyncNotice; var text: String? }

public final class SyncConnection: SyncEndpoint, @unchecked Sendable {
    public let peer: SyncPeerRecord
    private let channel: SyncSecureChannel
    private let service: SyncEndpoint
    private let onNotice: @Sendable (SyncNotice, String?) -> Void
    private let onClose: @Sendable () -> Void
    private let lock = NSLock()
    private var pending: [UInt32: Pending] = [:]
    private var nextID: UInt32 = 1
    private var isClosed = false
    private var reader: Task<Void, Never>?

    public static let requestTimeout: TimeInterval = 120
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private final class Pending: @unchecked Sendable {
        typealias Answer = (header: Data, payload: Data)
        private let lock = NSLock()
        private var result: Result<Answer, Error>?
        private var waiter: CheckedContinuation<Answer, Error>?

        func fulfil(_ value: Result<Answer, Error>) {
            settle(value)?.resume(with: value)
        }

        private func settle(_ value: Result<Answer, Error>) -> CheckedContinuation<Answer, Error>? {
            lock.lock()
            defer { lock.unlock() }
            guard result == nil else { return nil }
            result = value
            let waiting = waiter
            waiter = nil
            return waiting
        }

        func wait() async throws -> Answer {
            try await withCheckedThrowingContinuation { continuation in
                if let ready = park(continuation) { continuation.resume(with: ready) }
            }
        }

        private func park(_ continuation: CheckedContinuation<Answer, Error>) -> Result<Answer, Error>? {
            lock.lock()
            defer { lock.unlock() }
            if let result { return result }
            waiter = continuation
            return nil
        }
    }

    public init(
        channel: SyncSecureChannel, service: SyncEndpoint,
        onNotice: @escaping @Sendable (SyncNotice, String?) -> Void = { _, _ in },
        onClose: @escaping @Sendable () -> Void = {}
    ) {
        self.peer = channel.peer
        self.channel = channel
        self.service = service
        self.onNotice = onNotice
        self.onClose = onClose
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard reader == nil, !isClosed else { return }
        reader = Task { [self] in
            while !Task.isCancelled {
                do {
                    dispatch(try SyncWireMessage.decode(try await channel.receive()))
                } catch {
                    break
                }
            }
            finish()
        }
    }

    public func close() {
        channel.close()
        finish()
    }

    private func finish() {
        lock.lock()
        let first = !isClosed
        isClosed = true
        let waiting = pending
        pending = [:]
        let task = reader
        lock.unlock()
        guard first else { return }
        task?.cancel()
        channel.close()
        for call in waiting.values { call.fulfil(.failure(SyncFailure.connectionLost)) }
        onClose()
    }


    private func dispatch(_ message: SyncWireMessage) {
        switch message.kind {
        case .request:
            Task { await serve(message) }
        case .response:
            resolve(message.id, .success((header: message.header, payload: message.payload)))
        case .failure:
            let text = (try? Self.decoder.decode(FailureText.self, from: message.header))?.message ?? "The other device could not do that."
            resolve(message.id, .failure(SyncFailure.remote(text)))
        case .notice:
            if let notice = try? Self.decoder.decode(NoticeText.self, from: message.header) { onNotice(notice.notice, notice.text) }
        }
    }

    private func resolve(_ id: UInt32, _ result: Result<Pending.Answer, Error>) {
        lock.lock()
        let call = pending.removeValue(forKey: id)
        lock.unlock()
        call?.fulfil(result)
    }

    private func serve(_ message: SyncWireMessage) async {
        let reply: SyncWireMessage
        do {
            let answer = try await handle(message)
            reply = SyncWireMessage(kind: .response, id: message.id, header: answer.header, payload: answer.payload)
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            reply = SyncWireMessage(kind: .failure, id: message.id, header: (try? Self.encoder.encode(FailureText(message: text))) ?? Data())
        }
        try? await channel.send(reply.encoded())
    }

    private func handle(_ message: SyncWireMessage) async throws -> (header: Data, payload: Data) {
        func params<P: Codable>(_ type: P.Type) throws -> P {
            try Self.decoder.decode(Envelope<P>.self, from: message.header).params
        }
        func json<T: Encodable>(_ value: T) throws -> (header: Data, payload: Data) {
            (try Self.encoder.encode(value), Data())
        }
        guard let op = SyncOp(rawValue: try Self.decoder.decode(OpName.self, from: message.header).op) else {
            throw SyncFailure.remote("The other device sent a request this version does not know.")
        }
        switch op {
        case .index:
            return try json(try await service.index())
        case .bundles:
            return try json(try await service.bundles(keys: try params(Keys.self).keys))
        case .readFile:
            let p = try params(ReadFileParams.self)
            let data = try await service.readFile(unitKey: p.unitKey, path: p.path, offset: p.offset, length: p.length)
            return (try Self.encoder.encode(Empty()), data)
        case .pushStart:
            return try json(try await service.pushStart(try params(SyncPushRequest.self)))
        case .pushFile:
            let p = try params(PushFileParams.self)
            try await service.pushFile(token: p.token, unitKey: p.unitKey, path: p.path, offset: p.offset, data: message.payload)
            return try json(Empty())
        case .pushCommit:
            return try json(try await service.pushCommit(token: try params(TokenParams.self).token))
        case .shardLines:
            return try json(try await service.shardLines(month: try params(MonthParams.self).month))
        case .mergeHistory:
            let p = try params(MergeHistoryParams.self)
            return try json(try await service.mergeHistory(month: p.month, lines: p.lines, tombstones: p.tombstones))
        case .configPayload:
            return try json(ConfigAnswer(payload: try await service.configPayload()))
        case .applyConfig:
            let p = try params(ApplyConfigParams.self)
            return try json(AppliedAnswer(applied: try await service.applyConfig(p.payload, expectedHash: p.expectedHash)))
        }
    }


    public func notify(_ notice: SyncNotice, text: String? = nil) async {
        guard let header = try? Self.encoder.encode(NoticeText(notice: notice, text: text)) else { return }
        try? await channel.send(SyncWireMessage(kind: .notice, id: 0, header: header).encoded())
    }

    private func register() throws -> (UInt32, Pending) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { throw SyncFailure.connectionLost }
        let id = nextID
        nextID &+= 1
        let call = Pending()
        pending[id] = call
        return (id, call)
    }

    private func call<Params: Codable>(_ op: SyncOp, _ params: Params, payload: Data = Data()) async throws -> (header: Data, payload: Data) {
        let header = try Self.encoder.encode(Envelope(op: op.rawValue, params: params))
        let (id, call) = try register()
        let timeout = Task {
            do { try await Task.sleep(nanoseconds: UInt64(Self.requestTimeout * 1_000_000_000)) } catch { return }
            call.fulfil(.failure(SyncFailure.connectionLost))
        }
        defer { timeout.cancel() }
        return try await withTaskCancellationHandler {
            do {
                try await channel.send(SyncWireMessage(kind: .request, id: id, header: header, payload: payload).encoded())
            } catch {
                resolve(id, .failure(error))
            }
            return try await call.wait()
        } onCancel: {
            call.fulfil(.failure(SyncFailure.cancelled))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ answer: (header: Data, payload: Data)) throws -> T {
        do {
            return try Self.decoder.decode(T.self, from: answer.header)
        } catch {
            throw SyncFailure.remote("The other device sent an answer this version does not understand.")
        }
    }

    public func index() async throws -> SyncIndex {
        try decode(SyncIndex.self, try await call(.index, Empty()))
    }

    public func bundles(keys: [String]) async throws -> [SyncUnitBundle] {
        try decode([SyncUnitBundle].self, try await call(.bundles, Keys(keys: keys)))
    }

    public func readFile(unitKey: String, path: String, offset: Int64, length: Int) async throws -> Data {
        try await call(.readFile, ReadFileParams(unitKey: unitKey, path: path, offset: offset, length: length)).payload
    }

    public func pushStart(_ request: SyncPushRequest) async throws -> SyncPushTicket {
        try decode(SyncPushTicket.self, try await call(.pushStart, request))
    }

    public func pushFile(token: String, unitKey: String, path: String, offset: Int64, data: Data) async throws {
        _ = try await call(.pushFile, PushFileParams(token: token, unitKey: unitKey, path: path, offset: offset), payload: data)
    }

    public func pushCommit(token: String) async throws -> SyncPushResult {
        try decode(SyncPushResult.self, try await call(.pushCommit, TokenParams(token: token)))
    }

    public func shardLines(month: String) async throws -> [String] {
        try decode([String].self, try await call(.shardLines, MonthParams(month: month)))
    }

    public func mergeHistory(month: String, lines: [String], tombstones: [String: SyncStamp]) async throws -> SyncHistoryMerge {
        try decode(SyncHistoryMerge.self, try await call(.mergeHistory, MergeHistoryParams(month: month, lines: lines, tombstones: tombstones)))
    }

    public func configPayload() async throws -> SyncConfigPayload? {
        try decode(ConfigAnswer.self, try await call(.configPayload, Empty())).payload
    }

    public func applyConfig(_ payload: SyncConfigPayload, expectedHash: String?) async throws -> Bool {
        try decode(AppliedAnswer.self, try await call(.applyConfig, ApplyConfigParams(payload: payload, expectedHash: expectedHash))).applied
    }
}
