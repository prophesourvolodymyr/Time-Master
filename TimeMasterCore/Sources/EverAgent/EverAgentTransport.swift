#if os(macOS)
import Darwin
import Foundation

struct EverAgentLineSplitter {
    static let defaultMaximumLineBytes = 256 * 1024 * 1024

    private var partial: [UInt8] = []
    private let maximumLineBytes: Int

    init(maximumLineBytes: Int = EverAgentLineSplitter.defaultMaximumLineBytes) {
        self.maximumLineBytes = maximumLineBytes
    }

    var bufferedBytes: Int { partial.count }

    mutating func feed(_ chunk: UnsafeRawBufferPointer, line handle: (UnsafeBufferPointer<UInt8>) throws -> Void) throws {
        guard let raw = chunk.baseAddress, chunk.count > 0 else { return }
        let base = raw.assumingMemoryBound(to: UInt8.self)
        let count = chunk.count
        var start = 0
        while start < count {
            guard let hit = memchr(base + start, 0x0A, count - start) else {
                try stash(UnsafeBufferPointer(start: base + start, count: count - start))
                return
            }
            let end = UnsafeRawPointer(base).distance(to: UnsafeRawPointer(hit))
            let segment = UnsafeBufferPointer(start: base + start, count: end - start)
            if partial.isEmpty {
                guard segment.count <= maximumLineBytes else { throw tooLong() }
                if !segment.isEmpty { try handle(segment) }
            } else {
                defer { release() }
                try stash(segment)
                try partial.withUnsafeBufferPointer { try handle($0) }
            }
            start = end + 1
        }
    }

    private mutating func stash(_ bytes: UnsafeBufferPointer<UInt8>) throws {
        guard partial.count + bytes.count <= maximumLineBytes else { throw tooLong() }
        partial.append(contentsOf: bytes)
    }

    private mutating func release() {
        if partial.capacity > 4 * 1024 * 1024 {
            partial = []
        } else {
            partial.removeAll(keepingCapacity: true)
        }
    }

    private func tooLong() -> EverAgentError {
        .protocol("A line from the gateway is longer than \(maximumLineBytes) bytes.")
    }
}

enum EverAgentPOSIX {
    static func socketAddress(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        let bytes = Array(path.utf8)
        guard !bytes.contains(0) else { throw EverAgentError.gatewayNotRunning(path: path) }
        guard bytes.count < capacity else { throw EverAgentError.socketPathTooLong(path: path, limit: capacity - 1) }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    static func writeAll(_ bytes: UnsafeRawBufferPointer, using write: (UnsafeRawPointer, Int) -> Int) throws {
        guard var cursor = bytes.baseAddress else { return }
        var remaining = bytes.count
        while remaining > 0 {
            let written = write(cursor, remaining)
            if written > 0 {
                let advanced = min(written, remaining)
                cursor = cursor.advanced(by: advanced)
                remaining -= advanced
            } else if written < 0 && errno == EINTR {
                continue
            } else {
                throw EverAgentError.connectionClosed
            }
        }
    }

    static func readSome(into buffer: UnsafeMutableRawBufferPointer, using read: (UnsafeMutableRawPointer, Int) -> Int) -> Int {
        guard let base = buffer.baseAddress, !buffer.isEmpty else { return 0 }
        while true {
            let count = read(base, buffer.count)
            if count >= 0 || errno != EINTR { return count }
        }
    }
}

final class EverAgentSocket: @unchecked Sendable {
    static let readChunkBytes = 256 * 1024
    static let socketBufferBytes: Int32 = 256 * 1024

    private let descriptor: Int32
    private let writeQueue = DispatchQueue(label: "com.timemaster.everagent.write", qos: .userInitiated)
    private let lock = NSLock()
    private var isShutDown = false

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        Darwin.close(descriptor)
    }

    static func connect(to path: String) throws -> EverAgentSocket {
        var address = try EverAgentPOSIX.socketAddress(for: path)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw EverAgentError.io(operation: "open", code: errno) }
        var enabled: Int32 = 1
        var buffer = socketBufferBytes
        let size = socklen_t(MemoryLayout<Int32>.size)
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, size)
        setsockopt(descriptor, SOL_SOCKET, SO_SNDBUF, &buffer, size)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVBUF, &buffer, size)
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        var status: Int32
        repeat {
            status = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
        } while status != 0 && errno == EINTR
        if status != 0 && errno != EISCONN {
            let code = errno
            Darwin.close(descriptor)
            switch code {
            case ENOENT, ECONNREFUSED, ENOTDIR, ENOTSOCK: throw EverAgentError.gatewayNotRunning(path: path)
            default: throw EverAgentError.io(operation: "connect to", code: code)
            }
        }
        return EverAgentSocket(descriptor: descriptor)
    }

    var hasNoSigPipe: Bool {
        var value: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        return getsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &value, &size) == 0 && value != 0
    }

    func startReading(
        maximumLineBytes: Int,
        onLine: @escaping @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @escaping @Sendable (EverAgentError) -> Void
    ) {
        let thread = Thread { [self] in
            readLoop(maximumLineBytes: maximumLineBytes, onLine: onLine, onClose: onClose)
        }
        thread.name = "com.timemaster.everagent.read"
        thread.stackSize = 8 * 1024 * 1024
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    func send(_ bytes: [UInt8], completion: @escaping @Sendable (EverAgentError?) -> Void) {
        writeQueue.async { [self] in
            guard !lock.withLock({ isShutDown }) else {
                completion(.connectionClosed)
                return
            }
            do {
                try bytes.withUnsafeBytes { buffer in
                    try EverAgentPOSIX.writeAll(buffer) { Darwin.write(descriptor, $0, $1) }
                }
                completion(nil)
            } catch {
                completion(error as? EverAgentError ?? .connectionClosed)
            }
        }
    }

    func shutdown() {
        let first = lock.withLock { () -> Bool in
            if isShutDown { return false }
            isShutDown = true
            return true
        }
        if first { Darwin.shutdown(descriptor, SHUT_RDWR) }
    }

    private func readLoop(
        maximumLineBytes: Int,
        onLine: @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @Sendable (EverAgentError) -> Void
    ) {
        var splitter = EverAgentLineSplitter(maximumLineBytes: maximumLineBytes)
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Self.readChunkBytes, alignment: 16)
        defer { buffer.deallocate() }
        var reason = EverAgentError.connectionClosed
        while true {
            let count = EverAgentPOSIX.readSome(into: buffer) { Darwin.read(descriptor, $0, $1) }
            if count <= 0 { break }
            do {
                try splitter.feed(UnsafeRawBufferPointer(rebasing: buffer[..<count]), line: onLine)
            } catch let error as EverAgentError {
                reason = error
                break
            } catch {
                reason = .protocol(String(describing: error))
                break
            }
        }
        shutdown()
        onClose(reason)
    }
}

extension EverAgentSocket: EverAgentLink {
    func startReading(
        onLine: @escaping @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @escaping @Sendable (EverAgentError) -> Void
    ) {
        startReading(maximumLineBytes: EverAgentLineSplitter.defaultMaximumLineBytes, onLine: onLine, onClose: onClose)
    }
}
#endif
