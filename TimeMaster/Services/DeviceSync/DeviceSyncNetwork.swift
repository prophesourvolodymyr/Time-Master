import Foundation
import Network
import TimeMasterCore
import OSLog
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum DeviceSyncLog {
    static let logger = Logger(subsystem: "com.timemaster", category: "device-sync")
}

enum DeviceSyncPlatform: String, Equatable {
    case mac
    case iphone
    case ipad

    var symbol: String {
        switch self {
        case .mac: return "laptopcomputer"
        case .iphone: return "iphone"
        case .ipad: return "ipad"
        }
    }

    var label: String {
        switch self {
        case .mac: return "Mac"
        case .iphone: return "iPhone"
        case .ipad: return "iPad"
        }
    }

    init(wire: String?) {
        self = wire.flatMap(DeviceSyncPlatform.init(rawValue:)) ?? .iphone
    }
}

enum DeviceSyncIdentity {
    static var name: String {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["TIMEMASTER_SYNC_DEVICE_NAME"], !override.isEmpty { return override }
        #endif
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #endif
    }

    static var platform: DeviceSyncPlatform {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #else
        return .mac
        #endif
    }
}

struct DeviceSyncNearby: Identifiable, Equatable {
    let id: String
    var name: String
    var platform: DeviceSyncPlatform
    var isPairing: Bool
    var endpoint: NWEndpoint
}

private final class SocketOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    @discardableResult
    func succeed(_ value: T) -> Bool {
        guard let taken = take() else { return false }
        taken.resume(returning: value)
        return true
    }

    @discardableResult
    func fail(_ error: Error) -> Bool {
        guard let taken = take() else { return false }
        taken.resume(throwing: error)
        return true
    }

    private func take() -> CheckedContinuation<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let taken = continuation
        continuation = nil
        return taken
    }
}

final class DeviceSyncSocket: SyncTransport, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.timemaster.sync.socket")
    private let lock = NSLock()
    private var limit = 1 << 16

    static let trustedLimit = 16 << 20

    init(connection: NWConnection) {
        self.connection = connection
    }

    var remoteAddressBytes: [UInt8]? {
        guard case let .hostPort(host, _) = connection.endpoint else { return nil }
        switch host {
        case .ipv4(let address): return Array(address.rawValue)
        case .ipv6(let address): return Array(address.rawValue)
        default: return nil
        }
    }

    func raiseLimit() {
        lock.lock()
        limit = Self.trustedLimit
        lock.unlock()
    }

    private var currentLimit: Int {
        lock.lock()
        defer { lock.unlock() }
        return limit
    }

    func start(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = SocketOnce<Void>(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.succeed(())
                case .failed, .cancelled:
                    once.fail(SyncFailure.connectionLost)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                if once.fail(SyncFailure.connectionLost) { self?.close() }
            }
        }
    }

    func send(_ frame: Data) async throws {
        guard frame.count <= Self.trustedLimit else { throw SyncFailure.connectionLost }
        var length = UInt32(frame.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(frame)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: packet, completion: .contentProcessed { error in
                if let error {
                    DeviceSyncLog.logger.info("send failed: \(String(describing: error), privacy: .public)")
                    continuation.resume(throwing: SyncFailure.connectionLost)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive() async throws -> Data {
        let header = try await read(4)
        let length = header.reduce(0) { ($0 << 8) | Int($1) }
        guard length > 0, length <= currentLimit else {
            DeviceSyncLog.logger.error("a frame of \(length) bytes is over the limit of \(self.currentLimit)")
            close()
            throw SyncFailure.connectionLost
        }
        return try await read(length)
    }

    private func read(_ count: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if error == nil, let data, data.count == count {
                    continuation.resume(returning: data)
                } else {
                    DeviceSyncLog.logger.info("read of \(count) bytes failed: \(String(describing: error), privacy: .public), got \(data?.count ?? -1)")
                    continuation.resume(throwing: SyncFailure.connectionLost)
                }
            }
        }
    }

    func close() {
        connection.cancel()
    }
}

final class DeviceSyncNetwork: @unchecked Sendable {
    static let serviceType = "_tmax-sync._tcp"
    static let protocolVersion = "1"

    struct Identity: Sendable {
        let id: String
        let name: String
        let platform: DeviceSyncPlatform
    }

    private let identity: Identity
    private let queue = DispatchQueue(label: "com.timemaster.sync.network")
    private let onNearby: @Sendable ([DeviceSyncNearby]) -> Void
    private let onIncoming: @Sendable (DeviceSyncSocket) -> Void
    private let onProblem: @Sendable (String?) -> Void
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var isPairing = false
    private var isRunning = false

    init(
        identity: Identity,
        onNearby: @escaping @Sendable ([DeviceSyncNearby]) -> Void,
        onIncoming: @escaping @Sendable (DeviceSyncSocket) -> Void,
        onProblem: @escaping @Sendable (String?) -> Void
    ) {
        self.identity = identity
        self.onNearby = onNearby
        self.onIncoming = onIncoming
        self.onProblem = onProblem
    }

    static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 20
        tcp.keepaliveInterval = 8
        tcp.keepaliveCount = 3
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.prohibitedInterfaceTypes = [.cellular]
        return parameters
    }

    func start() {
        queue.async {
            guard !self.isRunning else { return }
            self.isRunning = true
            self.startListener()
            self.startBrowser()
        }
    }

    func stop() {
        queue.async {
            self.isRunning = false
            self.listener?.cancel()
            self.listener = nil
            self.browser?.cancel()
            self.browser = nil
        }
    }

    func setPairing(_ open: Bool) {
        queue.async {
            guard self.isPairing != open else { return }
            self.isPairing = open
            self.listener?.service = self.makeService()
        }
    }

    func open(_ device: DeviceSyncNearby) -> DeviceSyncSocket {
        DeviceSyncSocket(connection: NWConnection(to: device.endpoint, using: Self.parameters()))
    }


    private func makeService() -> NWListener.Service {
        let txt = NWTXTRecord([
            "v": Self.protocolVersion,
            "id": identity.id,
            "name": String(identity.name.prefix(80)),
            "platform": identity.platform.rawValue,
            "pair": isPairing ? "1" : "0",
        ])
        return NWListener.Service(name: "Tmax-\(identity.id.prefix(8))", type: Self.serviceType, txtRecord: txt)
    }

    private func startListener() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: Self.parameters())
            listener.service = makeService()
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.onProblem(nil)
                case .failed:
                    self.queue.async {
                        self.listener?.cancel()
                        self.listener = nil
                        self.onProblem("This device couldn't open itself to your other devices. Retrying…")
                        self.queue.asyncAfter(deadline: .now() + 3) {
                            if self.isRunning { self.startListener() }
                        }
                    }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            onProblem("This device couldn't open itself to your other devices.")
        }
    }

    private func accept(_ connection: NWConnection) {
        let socket = DeviceSyncSocket(connection: connection)
        guard let address = socket.remoteAddressBytes, SyncNetworkPolicy.isLocal(address) else {
            DeviceSyncLog.logger.error("refused a connection from outside the local network: \(String(describing: connection.endpoint), privacy: .public)")
            connection.cancel()
            return
        }
        onIncoming(socket)
    }


    private func startBrowser() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil), using: Self.parameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.onNearby(Self.devices(from: results, ownID: self.identity.id))
        }
        browser.stateUpdateHandler = { [weak self] state in
            guard let self, case .failed = state else { return }
            self.queue.async {
                self.browser?.cancel()
                self.browser = nil
                self.queue.asyncAfter(deadline: .now() + 3) {
                    if self.isRunning { self.startBrowser() }
                }
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private static func devices(from results: Set<NWBrowser.Result>, ownID: String) -> [DeviceSyncNearby] {
        var best: [String: (device: DeviceSyncNearby, rank: Int)] = [:]
        for result in results {
            guard case let .service(serviceName, _, _, _) = result.endpoint,
                  case let .bonjour(txt) = result.metadata,
                  txt["v"] == protocolVersion,
                  let id = txt["id"], !id.isEmpty, id != ownID else { continue }
            let onLAN = result.interfaces.contains { $0.type == .wifi || $0.type == .wiredEthernet }
            let rank = onLAN ? 2 : 1
            if let existing = best[id], existing.rank >= rank { continue }
            let name = txt["name"].flatMap { $0.isEmpty ? nil : $0 } ?? serviceName
            best[id] = (DeviceSyncNearby(
                id: id, name: name, platform: DeviceSyncPlatform(wire: txt["platform"]),
                isPairing: txt["pair"] == "1", endpoint: result.endpoint
            ), rank)
        }
        return best.values.map(\.device).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
