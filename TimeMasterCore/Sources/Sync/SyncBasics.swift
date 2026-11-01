import Foundation
import CryptoKit

public struct SyncStamp: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var millis: Int64
    public var counter: Int
    public var device: String

    public init(millis: Int64, counter: Int = 0, device: String) {
        self.millis = millis
        self.counter = counter
        self.device = device
    }

    public static func < (lhs: SyncStamp, rhs: SyncStamp) -> Bool {
        if lhs.millis != rhs.millis { return lhs.millis < rhs.millis }
        if lhs.counter != rhs.counter { return lhs.counter < rhs.counter }
        return lhs.device < rhs.device
    }

    public var description: String { "\(millis).\(counter).\(device)" }

    public init?(_ text: String) {
        let parts = text.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let millis = Int64(parts[0]), let counter = Int(parts[1]) else { return nil }
        self.init(millis: millis, counter: counter, device: String(parts[2]))
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let stamp = SyncStamp(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a sync stamp: \(text)"))
        }
        self = stamp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public static func at(_ date: Date, device: String) -> SyncStamp {
        SyncStamp(millis: Int64((date.timeIntervalSince1970 * 1000).rounded(.down)), counter: 0, device: device)
    }
}

public struct SyncClock: Codable, Equatable, Sendable {
    public var millis: Int64 = 0
    public var counter: Int = 0

    public init() {}

    public mutating func next(device: String, now: Date = Date()) -> SyncStamp {
        let wall = Int64((now.timeIntervalSince1970 * 1000).rounded(.down))
        if wall > millis {
            millis = wall
            counter = 0
        } else {
            counter += 1
        }
        return SyncStamp(millis: millis, counter: counter, device: device)
    }

    public mutating func observe(_ stamp: SyncStamp) {
        if stamp.millis > millis || (stamp.millis == millis && stamp.counter > counter) {
            millis = stamp.millis
            counter = stamp.counter
        }
    }
}

public enum SyncHash {
    public static func hex<D: DataProtocol>(_ data: D) -> String {
        hex(Array(SHA256.hash(data: data)))
    }

    static func hex(_ bytes: [UInt8]) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var out = [UInt8]()
        out.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            out.append(digits[Int(byte >> 4)])
            out.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    public static func hex(ofFile url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hex(Array(hasher.finalize()))
    }

    public static func combine(_ parts: [String]) -> String {
        hex(Data(parts.joined(separator: "\n").utf8))
    }
}

public enum SyncError: Error, LocalizedError, Equatable, Sendable {
    case invalid(String)
    case notFound(String)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let text), .notFound(let text), .io(let text): return text
        }
    }
}
