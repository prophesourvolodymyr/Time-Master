import Foundation

public struct OnDeviceMessage: Equatable, Sendable {
    public enum Role: Sendable {
        case user
        case assistant
    }

    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

public enum OnDeviceHistory {
    public static func digest(_ messages: [OnDeviceMessage], exchanges: Int = 3, userLimit: Int = 200, assistantLimit: Int = 280) -> String {
        let usable = messages.filter { message in
            let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("⚠️")
        }
        let recent = usable.suffix(exchanges * 2)
        guard !recent.isEmpty else { return "" }
        let lines = recent.map { message -> String in
            switch message.role {
            case .user: return "You: " + clipped(message.text, to: userLimit)
            case .assistant: return "Coach: " + clipped(message.text, to: assistantLimit)
            }
        }
        return "Earlier in this chat:\n" + lines.joined(separator: "\n")
    }

    public static func clipped(_ text: String, to limit: Int) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard flat.count > limit else { return flat }
        return String(flat.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
