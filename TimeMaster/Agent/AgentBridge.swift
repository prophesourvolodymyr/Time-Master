#if os(macOS)
import Foundation
import AppKit
import Combine
import Darwin
import TimeMasterCore

struct AgentBridgePaths {
    static let protocolVersion = 1

    let directory: URL
    let discovery: URL
    let socketPath: String

    init(dataRoot: URL) {
        directory = dataRoot.appendingPathComponent(".agent", isDirectory: true)
        discovery = directory.appendingPathComponent("bridge.json")
        let preferred = directory.appendingPathComponent("bridge.sock").path
        if preferred.utf8.count <= 100 {
            socketPath = preferred
        } else {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in dataRoot.path.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
            socketPath = "/tmp/tmax-\(getuid())/\(String(hash, radix: 16)).sock"
        }
    }

    func prepare() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let socketDirectory = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        if socketDirectory.path != directory.path {
            try manager.createDirectory(at: socketDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }
}

final class AgentBridge: @unchecked Sendable {
    static let shared = AgentBridge()

    private static let maximumRequestBytes = 16 * 1024 * 1024

    private let lock = NSLock()
    private let acceptQueue = DispatchQueue(label: "com.timemaster.agent.accept", qos: .utility)
    private var listener: Int32 = -1
    private var source: DispatchSourceRead?
    private var paths: AgentBridgePaths?
    private var ready = false
    private var cancellable: AnyCancellable?
    private var terminationObserver: NSObjectProtocol?

    private init() {}

    @MainActor
    func activate() {
        guard cancellable == nil else { return }
        cancellable = AgentAccessPreferences.shared.$level.sink { [weak self] level in
            if level == .off { self?.stop() } else { self?.start() }
        }
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            self?.stop()
        }
    }

    func setReady(_ value: Bool) {
        lock.lock()
        ready = value
        lock.unlock()
    }

    private var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard listener < 0, AgentAccessLevel.current != .off else { return }
        let paths = AgentBridgePaths(dataRoot: DatabaseManager.shared.dataRoot)
        do { try paths.prepare() } catch { return }
        if Self.peerIsAlive(path: paths.socketPath) { return }
        unlink(paths.socketPath)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return }
        var address = Self.address(for: paths.socketPath)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(paths.socketPath, 0o600) == 0, listen(descriptor, 16) == 0 else {
            close(descriptor)
            unlink(paths.socketPath)
            return
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        let accepting = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: acceptQueue)
        accepting.setEventHandler { [weak self] in self?.acceptPending(on: descriptor) }
        accepting.setCancelHandler { close(descriptor) }
        accepting.resume()
        listener = descriptor
        source = accepting
        self.paths = paths
        writeDiscovery(paths)
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard listener >= 0, let paths else { return }
        source?.cancel()
        source = nil
        listener = -1
        unlink(paths.socketPath)
        if let data = try? Data(contentsOf: paths.discovery),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           (object["pid"] as? Int32) == getpid() || (object["pid"] as? Int) == Int(getpid()) {
            try? FileManager.default.removeItem(at: paths.discovery)
        }
        self.paths = nil
    }

    private func writeDiscovery(_ paths: AgentBridgePaths) {
        let info = Bundle.main.infoDictionary
        let object: [String: Any] = [
            "protocol": AgentBridgePaths.protocolVersion,
            "pid": Int(getpid()),
            "socket": paths.socketPath,
            "app": Bundle.main.bundleIdentifier ?? "com.timemaster.macos",
            "version": info?["CFBundleShortVersionString"] as? String ?? "",
            "schema": AgentToolRegistry.schemaVersion,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        try? data.write(to: paths.discovery, options: .atomic)
        chmod(paths.discovery.path, 0o600)
    }

    private static func address(for path: String) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        path.withCString { text in
            withUnsafeMutableBytes(of: &address.sun_path) { destination in
                destination.copyMemory(from: UnsafeRawBufferPointer(start: text, count: min(Int(strlen(text)) + 1, capacity)))
            }
        }
        return address
    }

    private static func peerIsAlive(path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var address = address(for: path)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        return result == 0
    }

    private func acceptPending(on descriptor: Int32) {
        while true {
            let client = accept(descriptor, nil, nil)
            if client < 0 { return }
            var enabled: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
            _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
            Thread.detachNewThread { [weak self] in self?.serve(client) }
        }
    }

    private func serve(_ client: Int32) {
        defer { close(client) }
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { return }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = read(client, &chunk, chunk.count)
            if count <= 0 { return }
            buffer.append(chunk, count: count)
            if buffer.count > Self.maximumRequestBytes {
                Self.write(client, Self.failure(id: nil, AgentToolError("request_too_large", "Requests are limited to 16 MB.")))
                return
            }
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<newline)
                buffer.removeSubrange(buffer.startIndex...newline)
                if line.isEmpty { continue }
                Self.write(client, respond(to: line))
            }
        }
    }

    private static func write(_ client: Int32, _ data: Data) {
        var payload = data
        payload.append(0x0A)
        payload.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = Darwin.write(client, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                if written <= 0 { return }
                offset += written
            }
        }
    }

    private final class Reply: @unchecked Sendable {
        var data = Data()
    }

    private func respond(to line: Data) -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let reply = Reply()
        Task.detached { [self] in
            reply.data = await handle(line)
            semaphore.signal()
        }
        semaphore.wait()
        return reply.data
    }

    private func handle(_ line: Data) async -> Data {
        guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
            return Self.failure(id: nil, AgentToolError("bad_request", "Each line must be one JSON object."))
        }
        let id = object["id"]
        let params = object["params"] as? [String: Any] ?? [:]
        switch object["method"] as? String ?? "" {
        case "hello":
            return Self.success(id: id, ["result": hello()])
        case "tools.list":
            return Self.success(id: id, ["result": ["tools": AgentToolRegistry.catalog()]])
        case "tools.call":
            return await call(id: id, params: params)
        default:
            return Self.failure(id: id, AgentToolError("unknown_method", "Unknown method.", hint: "Use hello, tools.list or tools.call."))
        }
    }

    private func hello() -> [String: Any] {
        let info = Bundle.main.infoDictionary
        return [
            "protocol": AgentBridgePaths.protocolVersion,
            "app": "Tmax",
            "version": info?["CFBundleShortVersionString"] as? String ?? "",
            "build": info?["CFBundleVersion"] as? String ?? "",
            "schema": AgentToolRegistry.schemaVersion,
            "ready": isReady,
            "access": AgentAccessLevel.current.rawValue,
            "tools": AgentToolRegistry.tools.count,
            "pid": Int(getpid()),
        ]
    }

    private func call(id: Any?, params: [String: Any]) async -> Data {
        let name = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let dryRun = params["dryRun"] as? Bool ?? false
        let wait = min(max((params["wait"] as? NSNumber)?.doubleValue ?? 120, 1), 600)
        guard AgentToolRegistry.tool(named: name) != nil else {
            let close = AgentToolRegistry.suggestions(for: name)
            return Self.failure(id: id, AgentToolError("unknown_tool", "Unknown tool '\(name)'.", hint: close.isEmpty ? "Run tools to list what is available." : "Did you mean: \(close.joined(separator: ", "))?"))
        }
        guard isReady else {
            return Self.failure(id: id, AgentToolError("app_not_ready", "Tmax is still opening.", hint: "Retry in a few seconds."))
        }
        let level = AgentAccessLevel.current
        let risk = dryRun ? AgentToolRisk.read : AgentToolRegistry.effectiveRisk(of: name, arguments: arguments)
        switch level.decision(for: risk) {
        case .deny:
            return Self.failure(id: id, AgentToolError("forbidden", "Agent access is set to \(level.title) in Tmax, which does not allow \(name).", hint: "Change it in Settings → Agent Access."))
        case .approve:
            let outcome = await AgentApprovalPresenter.shared.request(
                summary: AgentApproval.summary(tool: name, arguments: arguments),
                details: AgentApproval.details(tool: name, arguments: arguments),
                timeout: wait
            )
            switch outcome {
            case .allowed: break
            case .denied: return Self.failure(id: id, AgentToolError("approval_denied", "You declined this change in Tmax."))
            case .timedOut: return Self.failure(id: id, AgentToolError("approval_timeout", "No answer in Tmax within \(Int(wait)) seconds.", hint: "Approve the prompt in Tmax, or raise --wait."))
            }
        case .allow:
            break
        }
        do {
            let result = try await AgentToolRouter.shared.execute(name, arguments: arguments, dryRun: dryRun, origin: .external)
            var envelope: [String: Any] = ["result": result.value]
            if let batch = result.batchID { envelope["batch"] = batch }
            return Self.success(id: id, envelope)
        } catch {
            return Self.failure(id: id, AgentToolError.translating(error))
        }
    }

    private static func success(id: Any?, _ fields: [String: Any]) -> Data {
        var object = fields
        object["ok"] = true
        if let id { object["id"] = id }
        return (try? AgentJSON.data(object)) ?? Data("{\"ok\":false}".utf8)
    }

    private static func failure(id: Any?, _ error: AgentToolError) -> Data {
        var object: [String: Any] = ["ok": false, "error": error.payload]
        if let id { object["id"] = id }
        return (try? AgentJSON.data(object)) ?? Data("{\"ok\":false}".utf8)
    }
}
#endif
