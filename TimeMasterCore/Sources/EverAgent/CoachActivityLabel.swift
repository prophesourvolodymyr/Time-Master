#if os(macOS)
import Foundation

public enum CoachActivityLabel {
    public static func make(toolName: String, arguments: JSONValue, intent: String? = nil) -> (title: String, detail: String?) {
        let derived = derive(toolName: toolName, arguments: arguments)
        if let intent = trimmed(intent) {
            return (intent, derived.detail)
        }
        if let intent = trimmed(arguments["i"].stringValue ?? arguments["intent"].stringValue) {
            return (intent, derived.detail)
        }
        return derived
    }

    private static func derive(toolName: String, arguments: JSONValue) -> (title: String, detail: String?) {
        let path = trimmed(arguments["path"].stringValue ?? arguments["file_path"].stringValue)
        if let path, path.hasPrefix("xd://") {
            return (deviceTitle(String(path.dropFirst("xd://".count))), nil)
        }
        switch toolName.lowercased() {
        case "bash", "shell", "exec":
            return ("Running a command", firstLine(arguments["command"].stringValue ?? arguments["cmd"].stringValue))
        case "read":
            return ("Reading \(fileName(path))", nil)
        case "write":
            return ("Writing \(fileName(path))", nil)
        case "edit", "ast_edit", "apply_patch":
            return ("Editing \(fileName(path))", nil)
        case "glob", "grep", "find", "ast_grep", "lsp":
            return ("Searching the project", firstLine(arguments["pattern"].stringValue ?? arguments["query"].stringValue))
        case "web_search":
            return ("Searching the web", firstLine(arguments["query"].stringValue))
        case "task":
            return ("Delegating to a sub-agent", firstLine(arguments["description"].stringValue ?? arguments["assignment"].stringValue))
        case "todo":
            return ("Updating the plan", nil)
        case "ask":
            return ("Asking you a question", nil)
        case "attach_files":
            return ("Attaching files", nil)
        case "manage_skill":
            return ("Updating a skill", nil)
        default:
            return (sentence(toolName), nil)
        }
    }

    private static func deviceTitle(_ device: String) -> String {
        guard device.hasPrefix("mcp__") else { return sentence(device) }
        let rest = device.dropFirst("mcp__".count)
        guard let split = rest.firstIndex(of: "_") else { return sentence(String(rest)) }
        let server = String(rest[rest.startIndex..<split])
        let tool = String(rest[rest.index(after: split)...])
        guard !tool.isEmpty else { return sentence(server) }
        return "\(server.prefix(1).uppercased() + server.dropFirst()): \(tool.replacingOccurrences(of: "_", with: " "))"
    }

    private static func sentence(_ name: String) -> String {
        let words = name.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private static func fileName(_ path: String?) -> String {
        guard let path, let last = path.split(separator: "/").last else { return "a file" }
        return String(last)
    }

    private static func firstLine(_ text: String?) -> String? {
        guard let line = trimmed(text)?.split(whereSeparator: \.isNewline).first else { return nil }
        let value = String(line).trimmingCharacters(in: .whitespaces)
        return value.count > 90 ? String(value.prefix(90)) + "…" : value
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
#endif
