import Foundation

public enum EverAgentTopic {
    public static let agent = "agent"
    public static let agentError = "agent.error"
    public static let agentNotice = "agent.notice"
    public static let uiRequest = "ui.request"
    public static let uiRequestClosed = "ui.request.closed"
    public static let session = "session"
    public static let sessionUpdated = "session.updated"
    public static let resync = "events.resync"
}

public struct EverAgentEvent: Sendable, Equatable {
    public let sequence: Int
    public let topic: String
    public let projectId: String?
    public let sessionId: String?
    public let data: JSONValue
    public let resync: Bool

    public init(sequence: Int, topic: String, projectId: String? = nil, sessionId: String? = nil, data: JSONValue = .null) {
        self.sequence = sequence
        self.topic = topic
        self.projectId = projectId
        self.sessionId = sessionId
        self.data = data
        resync = topic == EverAgentTopic.resync
    }

    init?(json: JSONValue) {
        guard let topic = json["topic"].stringValue else { return nil }
        self.init(
            sequence: json["sequence"].intValue,
            topic: topic,
            projectId: json["projectId"].stringValue,
            sessionId: json["sessionId"].stringValue,
            data: json["data"]
        )
    }
}

struct EverAgentEventFilter: Sendable, Equatable {
    let sessionId: String?
    let topics: Set<String>?

    func accepts(_ event: EverAgentEvent) -> Bool {
        event.resync || ((sessionId == nil || event.sessionId == sessionId) && (topics?.contains(event.topic) ?? true))
    }
}

public extension EverAgentEvent {
    private static let circularReference = "[Circular]"

    var agentType: String? {
        topic == EverAgentTopic.agent ? data["type"].stringValue : nil
    }

    var subagentId: String? {
        topic == EverAgentTopic.agent ? data["subagentId"].stringValue : nil
    }

    var message: EverAgentMessage? {
        guard topic == EverAgentTopic.agent else { return nil }
        let candidates = [data["message"], data["assistantMessageEvent"]["partial"]]
        return candidates.first { !$0.isNull && $0["content"].stringValue != Self.circularReference }.map(EverAgentMessage.init(json:))
    }

    var uiRequest: EverAgentUIRequest? {
        topic == EverAgentTopic.uiRequest ? EverAgentUIRequest(json: data) : nil
    }
}

public struct EverAgentUIRequest: Sendable, Equatable {
    public let requestId: String
    public let kind: String
    public let title: String
    public let message: String?
    public let payload: JSONValue
    public let raw: JSONValue

    init?(json: JSONValue) {
        guard let requestId = json["requestId"].stringValue else { return nil }
        self.requestId = requestId
        kind = json["kind"].text
        title = json["title"].text
        message = json["message"].stringValue
        payload = json["payload"]
        raw = json
    }
}
