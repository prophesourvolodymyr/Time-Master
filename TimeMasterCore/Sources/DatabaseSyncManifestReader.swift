import Foundation

final class DatabaseSyncManifestReader {
    private enum ReadError: Error { case invalidJSON }
    private let stream: InputStream
    private var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
    private var offset = 0
    private var available = 0
    private var ended = false

    private init(url: URL) throws {
        guard let stream = InputStream(url: url) else { throw CocoaError(.fileReadUnknown) }
        self.stream = stream
    }

    static func read(_ url: URL, onFilename: (String) -> Void) throws {
        let reader = try DatabaseSyncManifestReader(url: url)
        reader.stream.open()
        defer { reader.stream.close() }
        if try reader.peek() == 239 {
            try reader.expect(239)
            try reader.expect(187)
            try reader.expect(191)
        }
        try reader.readObject(onFilename: onFilename)
        try reader.whitespace()
        guard try reader.peek() == nil else { throw ReadError.invalidJSON }
    }

    private func readObject(onFilename: (String) -> Void) throws {
        try whitespace()
        try expect(123)
        try whitespace()
        if try consume(125) { return }
        var selectedKeys: Set<String> = []
        while true {
            let key = try string(maximumEncodedBytes: 128)
            try whitespace()
            try expect(58)
            try whitespace()
            switch key {
            case "mediaFilenames":
                guard selectedKeys.insert("mediaFilenames").inserted else { throw ReadError.invalidJSON }
                if try peek() == 110 { try literal("null") }
                else {
                    try expect(91)
                    try whitespace()
                    if try !consume(93) {
                        while true {
                            if let name = try string(maximumEncodedBytes: 2_048) { onFilename(name) }
                            try whitespace()
                            if try consume(93) { break }
                            try expect(44)
                            try whitespace()
                        }
                    }
                }
            case "coverImageFilename":
                guard selectedKeys.insert("coverImageFilename").inserted else { throw ReadError.invalidJSON }
                if try peek() == 110 { try literal("null") }
                else if let name = try string(maximumEncodedBytes: 2_048) { onFilename(name) }
            default:
                try skipValue(depth: 0)
            }
            try whitespace()
            if try consume(125) { return }
            try expect(44)
            try whitespace()
        }
    }

    private func skipValue(depth: Int) throws {
        guard depth < 512 else { throw ReadError.invalidJSON }
        try whitespace()
        guard let byte = try peek() else { throw ReadError.invalidJSON }
        switch byte {
        case 34:
            _ = try string(maximumEncodedBytes: nil)
        case 123:
            _ = try take()
            try whitespace()
            if try consume(125) { return }
            while true {
                _ = try string(maximumEncodedBytes: nil)
                try whitespace()
                try expect(58)
                try skipValue(depth: depth + 1)
                try whitespace()
                if try consume(125) { return }
                try expect(44)
                try whitespace()
            }
        case 91:
            _ = try take()
            try whitespace()
            if try consume(93) { return }
            while true {
                try skipValue(depth: depth + 1)
                try whitespace()
                if try consume(93) { return }
                try expect(44)
            }
        case 116: try literal("true")
        case 102: try literal("false")
        case 110: try literal("null")
        case 45, 48...57: try number()
        default: throw ReadError.invalidJSON
        }
    }

    private func string(maximumEncodedBytes: Int?) throws -> String? {
        try expect(34)
        var encoded: Data? = maximumEncodedBytes.map { _ in Data([34]) }
        func append(_ byte: UInt8) {
            if let maximumEncodedBytes, (encoded?.count ?? maximumEncodedBytes) < maximumEncodedBytes {
                encoded?.append(byte)
            } else { encoded = nil }
        }
        while let byte = try take() {
            guard byte >= 32 else { throw ReadError.invalidJSON }
            append(byte)
            if byte == 34 {
                guard let encoded else { return nil }
                do { return try JSONDecoder().decode(String.self, from: encoded) }
                catch { throw ReadError.invalidJSON }
            }
            if byte == 92 {
                guard let escaped = try take() else { throw ReadError.invalidJSON }
                switch escaped {
                case 34, 92, 47, 98, 102, 110, 114, 116, 117: break
                default: throw ReadError.invalidJSON
                }
                append(escaped)
                if escaped == 117 {
                    for _ in 0..<4 {
                        guard let hex = try take(), (48...57).contains(hex) || (65...70).contains(hex) || (97...102).contains(hex) else { throw ReadError.invalidJSON }
                        append(hex)
                    }
                }
            }
        }
        throw ReadError.invalidJSON
    }

    private func number() throws {
        _ = try consume(45)
        if try !consume(48) { try digits(required: true) }
        if try consume(46) { try digits(required: true) }
        if try peek() == 101 || peek() == 69 {
            _ = try take()
            if try !consume(43) { _ = try consume(45) }
            try digits(required: true)
        }
    }

    private func digits(required: Bool) throws {
        var found = false
        while let byte = try peek(), (48...57).contains(byte) {
            found = true
            _ = try take()
        }
        if required, !found { throw ReadError.invalidJSON }
    }

    private func literal(_ value: String) throws {
        for byte in value.utf8 { try expect(byte) }
    }

    private func whitespace() throws {
        while let byte = try peek(), byte == 32 || byte == 9 || byte == 10 || byte == 13 { _ = try take() }
    }

    private func expect(_ byte: UInt8) throws {
        guard try take() == byte else { throw ReadError.invalidJSON }
    }

    private func consume(_ byte: UInt8) throws -> Bool {
        guard try peek() == byte else { return false }
        _ = try take()
        return true
    }

    private func take() throws -> UInt8? {
        guard let byte = try peek() else { return nil }
        offset += 1
        return byte
    }

    private func peek() throws -> UInt8? {
        if offset == available {
            if ended { return nil }
            try Task.checkCancellation()
            let count = buffer.withUnsafeMutableBufferPointer { stream.read($0.baseAddress!, maxLength: $0.count) }
            guard count >= 0 else { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
            if count == 0 { ended = true; return nil }
            offset = 0
            available = count
        }
        return buffer[offset]
    }
}
