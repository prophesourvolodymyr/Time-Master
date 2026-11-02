#if os(macOS)
import Foundation

public enum JSONValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public struct ParseError: Error, Equatable, Sendable, CustomStringConvertible {
        public let offset: Int
        public let reason: String
        public var description: String { "\(reason) at byte \(offset)" }
    }
}

public extension JSONValue {
    static func int(_ value: Int) -> JSONValue { .number(Double(value)) }

    subscript(key: String) -> JSONValue {
        get { if case .object(let object) = self { object[key] ?? .null } else { .null } }
        set {
            var object = objectValue
            object[key] = newValue
            self = .object(object)
        }
    }

    subscript(index: Int) -> JSONValue {
        if case .array(let array) = self, array.indices.contains(index) { array[index] } else { .null }
    }

    var objectValue: [String: JSONValue] { if case .object(let value) = self { value } else { [:] } }
    var arrayValue: [JSONValue] { if case .array(let value) = self { value } else { [] } }
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    var boolValue: Bool { if case .bool(let value) = self { value } else { false } }
    var numberValue: Double { if case .number(let value) = self { value } else { 0 } }
    var text: String { stringValue ?? "" }
    var isNull: Bool { self == .null }

    var intValue: Int {
        guard case .number(let value) = self, value.isFinite, value > -9.2e18, value < 9.2e18 else { return 0 }
        return Int(value)
    }
}

public extension JSONValue {
    init(parsing data: Data) throws {
        self = try data.withUnsafeBytes { try JSONValue.parse($0.bindMemory(to: UInt8.self)) }
    }

    init(parsing text: String) throws {
        var copy = text
        self = try copy.withUTF8 { try JSONValue.parse($0) }
    }

    init<Value: Encodable>(encoding value: Value) throws {
        try self.init(parsing: JSONEncoder().encode(value))
    }

    func decoded<Value: Decodable>(_ type: Value.Type = Value.self) throws -> Value {
        try JSONDecoder().decode(type, from: serialized())
    }

    func serialized() -> Data {
        var bytes: [UInt8] = []
        write(to: &bytes)
        return Data(bytes)
    }

    var jsonString: String {
        var bytes: [UInt8] = []
        write(to: &bytes)
        return String(decoding: bytes, as: UTF8.self)
    }
}

extension JSONValue {
    static func parse(_ bytes: UnsafeBufferPointer<UInt8>) throws -> JSONValue {
        var parser = JSONParser(bytes: bytes)
        return try parser.parseDocument()
    }

    func write(to output: inout [UInt8]) {
        switch self {
        case .null:
            output.append(contentsOf: "null".utf8)
        case .bool(let value):
            output.append(contentsOf: (value ? "true" : "false").utf8)
        case .number(let value):
            Self.write(number: value, to: &output)
        case .string(let value):
            Self.write(string: value, to: &output)
        case .array(let values):
            output.append(0x5B)
            for (index, value) in values.enumerated() {
                if index > 0 { output.append(0x2C) }
                value.write(to: &output)
            }
            output.append(0x5D)
        case .object(let members):
            output.append(0x7B)
            for (index, key) in members.keys.sorted().enumerated() {
                if index > 0 { output.append(0x2C) }
                Self.write(string: key, to: &output)
                output.append(0x3A)
                members[key]?.write(to: &output)
            }
            output.append(0x7D)
        }
    }

    private static func write(number value: Double, to output: inout [UInt8]) {
        guard value.isFinite else {
            output.append(contentsOf: "null".utf8)
            return
        }
        if value == value.rounded(.towardZero), abs(value) < 9_007_199_254_740_992 {
            output.append(contentsOf: String(Int64(value)).utf8)
        } else {
            output.append(contentsOf: value.description.utf8)
        }
    }

    private static let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

    private static func write(string value: String, to output: inout [UInt8]) {
        output.append(0x22)
        for byte in value.utf8 {
            let escaped: UInt8
            switch byte {
            case 0x22, 0x5C: escaped = byte
            case 0x0A: escaped = 0x6E
            case 0x0D: escaped = 0x72
            case 0x09: escaped = 0x74
            case 0x08: escaped = 0x62
            case 0x0C: escaped = 0x66
            case 0..<0x20:
                output.append(0x5C)
                output.append(0x75)
                output.append(0x30)
                output.append(0x30)
                output.append(hexDigits[Int(byte >> 4)])
                output.append(hexDigits[Int(byte & 0x0F)])
                continue
            default:
                output.append(byte)
                continue
            }
            output.append(0x5C)
            output.append(escaped)
        }
        output.append(0x22)
    }
}

struct JSONParser {
    static let maximumDepth = 256

    private let bytes: UnsafeBufferPointer<UInt8>
    private var position = 0

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    mutating func parseDocument() throws -> JSONValue {
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF { position = 3 }
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard position == bytes.count else { throw failure("Unexpected data after the JSON value") }
        return value
    }

    private func failure(_ reason: String) -> JSONValue.ParseError {
        JSONValue.ParseError(offset: position, reason: reason)
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }

    private mutating func skipWhitespace() {
        while position < bytes.count {
            switch bytes[position] {
            case 0x20, 0x09, 0x0A, 0x0D: position += 1
            default: return
            }
        }
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard position < bytes.count else { throw failure("Unexpected end of JSON") }
        switch bytes[position] {
        case 0x7B: return try parseObject(depth: depth + 1)
        case 0x5B: return try parseArray(depth: depth + 1)
        case 0x22: return .string(try parseString())
        case 0x74:
            try expect("true")
            return .bool(true)
        case 0x66:
            try expect("false")
            return .bool(false)
        case 0x6E:
            try expect("null")
            return .null
        case 0x2D, 0x30...0x39: return try parseNumber()
        default: throw failure("Unexpected character")
        }
    }

    private mutating func expect(_ literal: StaticString) throws {
        let start = position
        let count = literal.utf8CodeUnitCount
        guard start + count <= bytes.count else { throw failure("Invalid literal") }
        let matches = literal.withUTF8Buffer { expected in
            (0..<count).allSatisfy { bytes[start + $0] == expected[$0] }
        }
        guard matches else { throw failure("Invalid literal") }
        position += count
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        guard depth <= Self.maximumDepth else { throw failure("JSON is nested too deeply") }
        position += 1
        var object: [String: JSONValue] = [:]
        skipWhitespace()
        if position < bytes.count, bytes[position] == 0x7D {
            position += 1
            return .object(object)
        }
        while true {
            skipWhitespace()
            guard position < bytes.count, bytes[position] == 0x22 else { throw failure("Expected an object key") }
            let key = try parseString()
            skipWhitespace()
            guard position < bytes.count, bytes[position] == 0x3A else { throw failure("Expected ':' after an object key") }
            position += 1
            skipWhitespace()
            object[key] = try parseValue(depth: depth)
            skipWhitespace()
            guard position < bytes.count else { throw failure("Unterminated object") }
            if bytes[position] == 0x2C {
                position += 1
            } else if bytes[position] == 0x7D {
                position += 1
                return .object(object)
            } else {
                throw failure("Expected ',' or '}' in an object")
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        guard depth <= Self.maximumDepth else { throw failure("JSON is nested too deeply") }
        position += 1
        var array: [JSONValue] = []
        skipWhitespace()
        if position < bytes.count, bytes[position] == 0x5D {
            position += 1
            return .array(array)
        }
        while true {
            skipWhitespace()
            array.append(try parseValue(depth: depth))
            skipWhitespace()
            guard position < bytes.count else { throw failure("Unterminated array") }
            if bytes[position] == 0x2C {
                position += 1
            } else if bytes[position] == 0x5D {
                position += 1
                return .array(array)
            } else {
                throw failure("Expected ',' or ']' in an array")
            }
        }
    }

    private mutating func parseString() throws -> String {
        position += 1
        let start = position
        while position < bytes.count {
            let byte = bytes[position]
            if byte == 0x22 {
                let text = String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<position]), as: UTF8.self)
                position += 1
                return text
            }
            if byte == 0x5C { break }
            position += 1
        }
        guard position < bytes.count else { throw failure("Unterminated string") }
        var scratch = [UInt8](bytes[start..<position])
        scratch.reserveCapacity(scratch.count + 64)
        while position < bytes.count {
            let byte = bytes[position]
            if byte == 0x22 {
                position += 1
                return String(decoding: scratch, as: UTF8.self)
            }
            if byte == 0x5C {
                try parseEscape(into: &scratch)
            } else {
                scratch.append(byte)
                position += 1
            }
        }
        throw failure("Unterminated string")
    }

    private mutating func parseEscape(into scratch: inout [UInt8]) throws {
        position += 1
        guard position < bytes.count else { throw failure("Unterminated escape sequence") }
        let code = bytes[position]
        position += 1
        switch code {
        case 0x22, 0x5C, 0x2F: scratch.append(code)
        case 0x62: scratch.append(0x08)
        case 0x66: scratch.append(0x0C)
        case 0x6E: scratch.append(0x0A)
        case 0x72: scratch.append(0x0D)
        case 0x74: scratch.append(0x09)
        case 0x75:
            let unit = try parseHexQuad()
            var scalar = unit
            if (0xD800...0xDBFF).contains(unit) {
                scalar = 0xFFFD
                if position + 1 < bytes.count, bytes[position] == 0x5C, bytes[position + 1] == 0x75 {
                    let escapeStart = position
                    position += 2
                    let low = try parseHexQuad()
                    if (0xDC00...0xDFFF).contains(low) {
                        scalar = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
                    } else {
                        position = escapeStart
                    }
                }
            } else if (0xDC00...0xDFFF).contains(unit) {
                scalar = 0xFFFD
            }
            UTF8.encode(Unicode.Scalar(scalar) ?? "\u{FFFD}") { scratch.append($0) }
        default:
            position -= 1
            throw failure("Invalid escape sequence")
        }
    }

    private mutating func parseHexQuad() throws -> UInt32 {
        guard position + 4 <= bytes.count else { throw failure("Invalid unicode escape") }
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[position]
            let digit: UInt32
            switch byte {
            case 0x30...0x39: digit = UInt32(byte - 0x30)
            case 0x41...0x46: digit = UInt32(byte - 0x41 + 10)
            case 0x61...0x66: digit = UInt32(byte - 0x61 + 10)
            default: throw failure("Invalid unicode escape")
            }
            value = value << 4 | digit
            position += 1
        }
        return value
    }

    private mutating func parseNumber() throws -> JSONValue {
        let start = position
        var negative = false
        if bytes[position] == 0x2D {
            negative = true
            position += 1
        }
        guard position < bytes.count else { throw failure("Invalid number") }
        let digitsStart = position
        if bytes[position] == 0x30 {
            position += 1
        } else if bytes[position] >= 0x31, bytes[position] <= 0x39 {
            while position < bytes.count, isDigit(bytes[position]) { position += 1 }
        } else {
            throw failure("Invalid number")
        }
        let integerDigits = position - digitsStart
        var integral = true
        if position < bytes.count, bytes[position] == 0x2E {
            integral = false
            position += 1
            let fractionStart = position
            while position < bytes.count, isDigit(bytes[position]) { position += 1 }
            guard position > fractionStart else { throw failure("Invalid number") }
        }
        if position < bytes.count, bytes[position] | 0x20 == 0x65 {
            integral = false
            position += 1
            if position < bytes.count, bytes[position] == 0x2B || bytes[position] == 0x2D { position += 1 }
            let exponentStart = position
            while position < bytes.count, isDigit(bytes[position]) { position += 1 }
            guard position > exponentStart else { throw failure("Invalid number") }
        }
        if integral, integerDigits <= 15 {
            var value: Int64 = 0
            for index in digitsStart..<digitsStart + integerDigits { value = value * 10 + Int64(bytes[index] - 0x30) }
            return .number(Double(negative ? -value : value))
        }
        let text = String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<position]), as: UTF8.self)
        guard let value = Double(text), value.isFinite else { throw failure("Number is out of range") }
        return .number(value)
    }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue: CustomStringConvertible {
    public var description: String { jsonString }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { $1 }))
    }
}
#endif
