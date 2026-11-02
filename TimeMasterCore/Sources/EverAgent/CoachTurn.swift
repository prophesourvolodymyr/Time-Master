#if os(macOS)
import Foundation

public struct CoachTurn: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        case running
        case waitingForUser
        case finished
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var activities: [CoachActivity] = []
    public private(set) var isThinking = false
    public private(set) var request: EverAgentUIRequest?
    public private(set) var needsReload = false
    private var segments: [String] = []
    private var liveText = ""
    private var assistantError: String?

    public init() {}

    public var text: String {
        (segments + [liveText]).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    public var isFinished: Bool {
        switch phase {
        case .finished, .failed: return true
        case .idle, .running, .waitingForUser: return false
        }
    }

    public var progress: CoachProgress {
        var failure: String?
        if case .failed(let reason) = phase { failure = reason }
        return CoachProgress(text: text, activities: activities, statusTitle: statusTitle, isFinished: isFinished, failure: failure)
    }

    private var statusTitle: String? {
        switch phase {
        case .waitingForUser:
            return "Waiting for your answer"
        case .running, .idle:
            if let running = activities.last(where: { $0.status == .running }) { return running.title }
            return isThinking ? "Thinking…" : nil
        case .finished, .failed:
            return nil
        }
    }

    public mutating func apply(_ event: EverAgentEvent) {
        switch event.topic {
        case EverAgentTopic.agent:
            applyAgent(event)
        case EverAgentTopic.agentError:
            let message = event.data["message"].stringValue ?? ""
            phase = .failed(message.isEmpty ? "The agent could not finish this turn." : message)
        case EverAgentTopic.uiRequest:
            if let request = event.uiRequest {
                self.request = request
                phase = .waitingForUser
            }
        case EverAgentTopic.uiRequestClosed:
            if event.data["requestId"].stringValue == request?.requestId {
                resolveRequest()
            }
        case EverAgentTopic.resync:
            needsReload = true
        default:
            break
        }
    }

    public mutating func resolveRequest() {
        request = nil
        if phase == .waitingForUser { phase = .running }
    }

    public mutating func addActivity(_ activity: CoachActivity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        } else {
            activities.insert(activity, at: 0)
        }
    }

    public mutating func fail(_ message: String) {
        for index in activities.indices where activities[index].status == .running {
            activities[index].status = .failed
        }
        request = nil
        isThinking = false
        phase = .failed(message)
    }

    public mutating func reconcile(with session: EverAgentSession) {
        let messages = session.messages
        guard let lastUser = messages.lastIndex(where: { $0.role == "user" }) else { return }
        let replies = messages[messages.index(after: lastUser)...].filter { $0.role == "assistant" }
        segments = replies.map(\.text).filter { !$0.isEmpty }
        liveText = ""
        isThinking = false
        assistantError = replies.last.flatMap { $0.stopReason == "error" ? errorText($0) : nil }
        needsReload = false
        if !session.isStreaming, !isFinished, phase == .running {
            phase = assistantError.map { .failed($0) } ?? .finished
        }
    }

    private mutating func applyAgent(_ event: EverAgentEvent) {
        if let subagent = event.subagentId {
            applySubagent(subagent, type: event.agentType)
            return
        }
        switch event.agentType {
        case "agent_start":
            if phase == .idle { phase = .running }
        case "message_start", "message_update":
            if let message = event.message, message.role == "assistant" { absorb(message) }
        case "message_end":
            if let message = event.message, message.role == "assistant" { finish(message) }
        case "tool_execution_start":
            toolEvent(event, status: nil)
        case "tool_execution_update":
            toolEvent(event, status: nil)
        case "tool_execution_end":
            let failed = event.data["isError"].boolValue || event.data["result"]["isError"].boolValue
            toolEvent(event, status: failed ? .failed : .done)
        case "agent_end":
            if !liveText.isEmpty {
                segments.append(liveText)
                liveText = ""
            }
            isThinking = false
            for index in activities.indices where activities[index].status == .running {
                activities[index].status = .done
            }
            request = nil
            if case .failed = phase { return }
            phase = assistantError.map { .failed($0) } ?? .finished
        case "error":
            let message = event.data["message"].stringValue ?? ""
            phase = .failed(message.isEmpty ? "The agent could not finish this turn." : message)
        default:
            break
        }
    }

    private mutating func absorb(_ message: EverAgentMessage) {
        liveText = message.text
        isThinking = liveText.isEmpty && message.content.contains { block in
            if case .thinking = block { return true }
            return false
        }
        if phase == .idle { phase = .running }
        for block in message.content {
            guard case .toolCall(let id, let name, let arguments) = block, !id.isEmpty else { continue }
            let label = CoachActivityLabel.make(toolName: name, arguments: arguments)
            upsert(id: id, title: label.title, detail: label.detail, status: nil)
        }
    }

    private mutating func finish(_ message: EverAgentMessage) {
        let text = message.text
        if !text.isEmpty { segments.append(text) }
        liveText = ""
        isThinking = false
        assistantError = message.stopReason == "error" ? errorText(message) : nil
    }

    private mutating func toolEvent(_ event: EverAgentEvent, status: CoachActivity.Status?) {
        guard let id = event.data["toolCallId"].stringValue, !id.isEmpty else { return }
        let arguments = event.data["args"].isNull ? event.data["arguments"] : event.data["args"]
        let intent = event.data["intent"].stringValue
        if arguments.isNull, intent == nil, let index = activities.firstIndex(where: { $0.id == id }) {
            if let status, activities[index].status != .failed { activities[index].status = status }
            return
        }
        let label = CoachActivityLabel.make(toolName: event.data["toolName"].text, arguments: arguments, intent: intent)
        upsert(id: id, title: label.title, detail: label.detail, status: status)
    }

    private mutating func applySubagent(_ id: String, type: String?) {
        let key = "sub:\(id)"
        switch type {
        case "agent_start":
            upsert(id: key, title: "A sub-agent is working", detail: nil, status: .running)
        case "agent_end":
            upsert(id: key, title: "A sub-agent is working", detail: nil, status: .done)
        default:
            break
        }
    }

    private mutating func upsert(id: String, title: String, detail: String?, status: CoachActivity.Status?) {
        if let index = activities.firstIndex(where: { $0.id == id }) {
            activities[index].title = title
            if let detail { activities[index].detail = detail }
            if let status, activities[index].status != .failed { activities[index].status = status }
        } else {
            activities.append(CoachActivity(id: id, title: title, detail: detail, status: status ?? .running))
        }
    }

    private func errorText(_ message: EverAgentMessage) -> String {
        let text = message.errorMessage ?? ""
        return text.isEmpty ? "The provider ended this turn with an error." : text
    }
}
#endif
