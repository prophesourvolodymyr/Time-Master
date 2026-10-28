import Foundation

public extension AgentToolRisk {
    var rank: Int {
        switch self {
        case .read: 0
        case .write: 1
        case .delete: 2
        }
    }
}

public extension AgentToolRegistry {
    static func validate(_ name: String, arguments: [String: Any]) throws -> [String: Any] {
        guard let tool = tool(named: name) else {
            let close = suggestions(for: name)
            throw AgentToolError("unknown_tool", "Unknown tool '\(name)'.", hint: close.isEmpty ? "Run tools to list what is available." : "Did you mean: \(close.joined(separator: ", "))?")
        }
        return try AgentArguments(tool: tool, raw: arguments).values
    }

    static func effectiveRisk(of name: String, arguments: [String: Any]) -> AgentToolRisk {
        guard let entry = tool(named: name) else { return .delete }
        guard name == "batch" else { return entry.risk }
        let operations = arguments["operations"] as? [[String: Any]] ?? []
        return operations
            .compactMap { operation in (operation["tool"] as? String).flatMap { tool(named: $0) }?.risk }
            .max { $0.rank < $1.rank } ?? entry.risk
    }
}

public enum AgentFiles {
    public static func validateMedia(path: String) throws -> URL {
        try AgentMedia.validate(path: path)
    }

    public static func isVideo(_ url: URL) -> Bool {
        AgentMedia.videos.contains(url.pathExtension.lowercased())
    }
}

public enum AgentJSON {
    public static func sanitize(_ value: Any) -> Any {
        switch value {
        case is NSNull: return NSNull()
        case let text as String: return text
        case let dictionary as [String: Any]: return dictionary.mapValues { sanitize($0) }
        case let array as [Any]: return array.map { sanitize($0) }
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case let url as URL: return url.path
        default:
            if AgentValue.isBoolean(value) { return (value as? NSNumber)?.boolValue ?? false }
            if let number = value as? NSNumber {
                return number.doubleValue.isFinite ? number : NSNull()
            }
            if let int = value as? Int { return int }
            return "\(value)"
        }
    }

    public static func data(_ value: Any, pretty: Bool = false) throws -> Data {
        let clean = sanitize(value)
        return try JSONSerialization.data(withJSONObject: clean, options: pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes])
    }

    public static func string(_ value: Any, pretty: Bool = false) -> String {
        (try? data(value, pretty: pretty)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
