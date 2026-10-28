import Foundation

public struct AgentToolCall {
    public let id: String
    public let name: String
    public let arguments: [String: Any]
    public let argumentError: String?

    public init(id: String, name: String, arguments: [String: Any], argumentError: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.argumentError = argumentError
    }
}

public enum AgentWire {
    public static let truncatedArguments = "The tool arguments were not valid JSON, so nothing was run. The reply was probably cut off; call the tool again with shorter arguments."

    public static func parseOpenAI(message: [String: Any]) -> (text: String, calls: [AgentToolCall]) {
        let text = message["content"] as? String ?? ""
        let raw = message["tool_calls"] as? [[String: Any]] ?? []
        var calls: [AgentToolCall] = []
        for item in raw {
            guard let id = item["id"] as? String,
                  let function = item["function"] as? [String: Any],
                  let name = function["name"] as? String else { continue }
            let text = (function["arguments"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                calls.append(AgentToolCall(id: id, name: name, arguments: [:]))
            } else if let data = text.data(using: .utf8), let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                calls.append(AgentToolCall(id: id, name: name, arguments: parsed))
            } else {
                calls.append(AgentToolCall(id: id, name: name, arguments: [:], argumentError: truncatedArguments))
            }
        }
        return (text, calls)
    }

    public static func parseAnthropic(content: [[String: Any]]) -> (text: String, calls: [AgentToolCall]) {
        var text = ""
        var calls: [AgentToolCall] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                text += block["text"] as? String ?? ""
            case "tool_use":
                guard let id = block["id"] as? String, let name = block["name"] as? String else { continue }
                calls.append(AgentToolCall(id: id, name: name, arguments: block["input"] as? [String: Any] ?? [:]))
            default:
                break
            }
        }
        return (text, calls)
    }

    public static func openAIAssistantMessage(text: String, calls: [AgentToolCall]) -> [String: Any] {
        var message: [String: Any] = ["role": "assistant"]
        if !text.isEmpty { message["content"] = text }
        message["tool_calls"] = calls.map { call -> [String: Any] in
            let data = (try? JSONSerialization.data(withJSONObject: call.arguments, options: [.sortedKeys])) ?? Data("{}".utf8)
            return [
                "id": call.id,
                "type": "function",
                "function": ["name": call.name, "arguments": String(data: data, encoding: .utf8) ?? "{}"] as [String: Any],
            ]
        }
        return message
    }

    public static func toolMessage(callID: String, content: String) -> [String: Any] {
        ["role": "tool", "tool_call_id": callID, "content": content]
    }

    public static func anthropicRequest(from messages: [[String: Any]]) -> (system: String, messages: [[String: Any]]) {
        var system: [String] = []
        var out: [[String: Any]] = []
        var pendingResults: [[String: Any]] = []

        func flush() {
            guard !pendingResults.isEmpty else { return }
            out.append(["role": "user", "content": pendingResults])
            pendingResults = []
        }

        for message in messages {
            let role = message["role"] as? String ?? ""
            switch role {
            case "system":
                if let text = message["content"] as? String, !text.isEmpty { system.append(text) }
            case "tool":
                pendingResults.append([
                    "type": "tool_result",
                    "tool_use_id": message["tool_call_id"] as? String ?? "",
                    "content": message["content"] as? String ?? "",
                ])
            case "assistant":
                flush()
                let calls = message["tool_calls"] as? [[String: Any]] ?? []
                if calls.isEmpty {
                    if let text = message["content"] as? String, !text.isEmpty { out.append(["role": "assistant", "content": text]) }
                } else {
                    var blocks: [[String: Any]] = []
                    if let text = message["content"] as? String, !text.isEmpty { blocks.append(["type": "text", "text": text]) }
                    for call in calls {
                        let function = call["function"] as? [String: Any] ?? [:]
                        let argumentText = function["arguments"] as? String ?? "{}"
                        let input = (argumentText.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
                        blocks.append(["type": "tool_use", "id": call["id"] as? String ?? "", "name": function["name"] as? String ?? "", "input": input])
                    }
                    out.append(["role": "assistant", "content": blocks])
                }
            case "user":
                flush()
                if let text = message["content"] as? String { out.append(["role": "user", "content": text]) }
            default:
                break
            }
        }
        flush()
        if out.first?["role"] as? String == "assistant" {
            out.insert(["role": "user", "content": "(continuing)"], at: 0)
        }
        return (system.joined(separator: "\n\n"), out)
    }
}

public enum AgentApproval {
    public static func summary(tool: String, arguments: [String: Any]) -> String {
        func text(_ key: String) -> String? { (arguments[key] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        func quoted(_ key: String) -> String { text(key).map { "“\($0)”" } ?? "a page" }
        switch tool {
        case "create_container_page": return "Create folder \(quoted("title"))" + (text("parent").map { " in \($0)" } ?? "")
        case "create_exercise_page": return "Create exercise \(quoted("title"))" + (text("parent").map { " in \($0)" } ?? "")
        case "attach_media": return "Attach \(text("path").map { ($0 as NSString).lastPathComponent } ?? "a file") to \(quoted("page"))"
        case "add_page_note": return "Add a note to \(quoted("page"))"
        case "update_page": return "Edit \(quoted("page"))"
        case "move_page": return "Move \(quoted("page")) to \(text("newParent") ?? "the root")"
        case "delete_page": return "Move \(quoted("page")) and everything inside it to the trash"
        case "build_workout":
            let count = (arguments["sections"] as? [Any])?.count ?? 0
            return "Build workout \(quoted("name")) (\(count) section\(count == 1 ? "" : "s"))"
        case "delete_workout": return "Move workout \(quoted("workout")) to the trash"
        case "update_settings": return "Update app settings"
        case "import_video": return "Import video clips from \(text("source") ?? "a video")"
        case "batch":
            let count = (arguments["operations"] as? [Any])?.count ?? 0
            return "Run \(count) library operation\(count == 1 ? "" : "s") together"
        case "undo": return "Undo the last agent changes"
        default: return "\(tool): \(arguments.keys.sorted().joined(separator: ", "))"
        }
    }

    public static func details(tool: String, arguments: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for key in arguments.keys.sorted() {
            let value = arguments[key] as Any
            let rendered: String
            if let string = value as? String { rendered = string }
            else if let array = value as? [Any] { rendered = "\(array.count) item\(array.count == 1 ? "" : "s")" }
            else if JSONSerialization.isValidJSONObject(["v": value]),
                    let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]),
                    let string = String(data: data, encoding: .utf8) { rendered = string }
            else { rendered = "\(value)" }
            out[key.prefix(1).uppercased() + key.dropFirst()] = rendered.count > 240 ? String(rendered.prefix(240)) + "…" : rendered
        }
        return out
    }
}
