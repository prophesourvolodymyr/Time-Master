import Foundation

public struct AgentToolError: Error, LocalizedError {
    public let code: String
    public let message: String
    public let hint: String?
    public let details: [String: Any]

    public init(_ code: String, _ message: String, hint: String? = nil, details: [String: Any] = [:]) {
        self.code = code
        self.message = message
        self.hint = hint
        self.details = details
    }

    public var errorDescription: String? {
        hint.map { "\(message) \($0)" } ?? message
    }

    public var payload: [String: Any] {
        var out: [String: Any] = ["code": code, "message": message]
        if let hint { out["hint"] = hint }
        if !details.isEmpty { out["details"] = details }
        return out
    }

    public static func translating(_ error: Error) -> AgentToolError {
        if let known = error as? AgentToolError { return known }
        if let file = error as? FileSystemHelper.Error {
            switch file {
            case .notFound(let path):
                return AgentToolError("not_found", "Not found: \((path as NSString).lastPathComponent).")
            case .invalidPageKind(let reason):
                return AgentToolError("invalid_page", "That change is not allowed: \(reason).")
            case .writeFailed(let reason):
                if reason.contains("media items") {
                    return AgentToolError("media_limit", reason, hint: "A page holds up to 20 attachments.")
                }
                return AgentToolError("write_failed", reason)
            case .decodeFailed(let reason):
                return AgentToolError("invalid_data", reason)
            default:
                return AgentToolError("failed", file.localizedDescription)
            }
        }
        return AgentToolError("failed", error.localizedDescription)
    }
}

public enum AgentEffect: Codable, Equatable {
    case createdPage(id: String)
    case attachedMedia(pageID: String, filename: String)
    case createdWorkout(id: String)
    case changedMarkdown(pageID: String, previous: String)
}

public struct AgentToolOutput {
    public var value: [String: Any]
    public var effects: [AgentEffect]

    public init(value: [String: Any], effects: [AgentEffect] = []) {
        self.value = value
        self.effects = effects
    }
}

enum AgentValue {
    static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return value is Bool }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    static func integer(_ value: Any) -> Int? {
        if isBoolean(value) { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber {
            let double = number.doubleValue
            return double.rounded() == double && abs(double) < 1e15 ? Int(double) : nil
        }
        if let text = value as? String { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func number(_ value: Any) -> Double? {
        if isBoolean(value) { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func boolean(_ value: Any) -> Bool? {
        if isBoolean(value) { return (value as? NSNumber)?.boolValue ?? (value as? Bool) }
        if let text = value as? String {
            switch text.lowercased() {
            case "true", "yes", "1", "on": return true
            case "false", "no", "0", "off": return false
            default: return nil
            }
        }
        return nil
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

struct AgentArguments {
    let values: [String: Any]

    init(tool: AgentTool, raw: [String: Any], allowReferences: Bool = false) throws {
        values = try Self.normalize(raw, schema: tool.schema, path: "", strict: true, allowReferences: allowReferences)
    }

    func string(_ key: String) -> String? { values[key] as? String }
    func int(_ key: String) -> Int? { values[key] as? Int }
    func bool(_ key: String) -> Bool? { values[key] as? Bool }
    func strings(_ key: String) -> [String]? { values[key] as? [String] }
    func objects(_ key: String) -> [[String: Any]] { values[key] as? [[String: Any]] ?? [] }
    func has(_ key: String) -> Bool { values[key] != nil }

    func requiredString(_ key: String) throws -> String {
        let text = (string(key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentToolError("invalid_argument", "'\(key)' must not be empty.") }
        return text
    }

    static func normalize(_ raw: [String: Any], schema: [String: Any], path: String, strict: Bool, allowReferences: Bool) throws -> [String: Any] {
        let properties = schema["properties"] as? [String: [String: Any]] ?? [:]
        let required = schema["required"] as? [String] ?? []
        let prefix = path.isEmpty ? "" : path + "."
        if strict || !properties.isEmpty {
            let unknown = raw.keys.filter { properties[$0] == nil }.sorted()
            if !unknown.isEmpty {
                let list = unknown.map { "'\(prefix)\($0)'" }.joined(separator: ", ")
                let allowed = properties.keys.sorted().joined(separator: ", ")
                throw AgentToolError("invalid_argument", "Unknown argument\(unknown.count == 1 ? "" : "s") \(list).", hint: allowed.isEmpty ? "This tool takes no arguments." : "Allowed: \(allowed).")
            }
        } else {
            return raw
        }
        var out: [String: Any] = [:]
        for (key, value) in raw where !(value is NSNull) {
            out[key] = try coerce(value, schema: properties[key] ?? [:], path: prefix + key, allowReferences: allowReferences)
        }
        for key in required where out[key] == nil {
            throw AgentToolError("invalid_argument", "Missing required argument '\(prefix + key)'.", hint: "Required: \(required.joined(separator: ", ")).")
        }
        return out
    }

    static func coerce(_ value: Any, schema: [String: Any], path: String, allowReferences: Bool) throws -> Any {
        if allowReferences, let text = value as? String, text.hasPrefix("$") { return text }
        let type = schema["type"] as? String ?? "string"
        switch type {
        case "string":
            var text: String?
            if let string = value as? String { text = string }
            else if let object = value as? [String: Any] { text = (object["name"] ?? object["id"]) as? String }
            else if !AgentValue.isBoolean(value), let number = value as? NSNumber { text = number.stringValue }
            guard var result = text else { throw AgentToolError("invalid_argument", "'\(path)' must be text.") }
            if let allowed = schema["enum"] as? [String] {
                guard let match = allowed.first(where: { $0.caseInsensitiveCompare(result) == .orderedSame }) else {
                    throw AgentToolError("invalid_argument", "'\(path)' must be one of: \(allowed.joined(separator: ", ")).")
                }
                result = match
            }
            return result
        case "integer":
            guard let int = AgentValue.integer(value) else { throw AgentToolError("invalid_argument", "'\(path)' must be a whole number.") }
            try checkRange(Double(int), schema: schema, path: path)
            return int
        case "number":
            guard let number = AgentValue.number(value) else { throw AgentToolError("invalid_argument", "'\(path)' must be a number.") }
            try checkRange(number, schema: schema, path: path)
            return number
        case "boolean":
            guard let bool = AgentValue.boolean(value) else { throw AgentToolError("invalid_argument", "'\(path)' must be true or false.") }
            return bool
        case "array":
            let itemSchema = schema["items"] as? [String: Any] ?? [:]
            let elements: [Any] = (value as? [Any]) ?? [value]
            return try elements.enumerated().map { index, element in
                try coerce(element, schema: itemSchema, path: "\(path)[\(index)]", allowReferences: allowReferences)
            }
        case "object":
            guard let object = value as? [String: Any] else { throw AgentToolError("invalid_argument", "'\(path)' must be an object.") }
            return try normalize(object, schema: schema, path: path, strict: false, allowReferences: allowReferences)
        default:
            return value
        }
    }

    private static func checkRange(_ value: Double, schema: [String: Any], path: String) throws {
        if let minimum = schema["minimum"] as? Int, value < Double(minimum) {
            throw AgentToolError("invalid_argument", "'\(path)' must be at least \(minimum).")
        }
        if let maximum = schema["maximum"] as? Int, value > Double(maximum) {
            throw AgentToolError("invalid_argument", "'\(path)' must be at most \(maximum).")
        }
    }
}
