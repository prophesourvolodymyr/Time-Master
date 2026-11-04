import Foundation

public enum EverAgentCapability {
    public static let eventSubscription = "events.subscribe"
}

public struct EverAgentServerInfo: Sendable, Equatable {
    public let serverId: String
    public let name: String
    public let platform: String
    public let protocolVersion: Int
    public let capabilities: [String]

    public var supportsEventSubscription: Bool {
        capabilities.contains(EverAgentCapability.eventSubscription)
    }

    init(json: JSONValue) throws {
        guard let serverId = json["serverId"].stringValue, !serverId.isEmpty else {
            throw EverAgentError.protocol("server.info did not include a serverId.")
        }
        self.serverId = serverId
        name = json["name"].text
        platform = json["platform"].text
        protocolVersion = json["protocolVersion"].intValue
        capabilities = json["capabilities"].arrayValue.compactMap(\.stringValue)
    }
}

public struct EverAgentProject: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let root: String
    public let revision: Int
    public let createdAt: String

    init(json: JSONValue) throws {
        guard let id = json["id"].stringValue, !id.isEmpty else {
            throw EverAgentError.protocol("The gateway returned a project without an id.")
        }
        self.id = id
        name = json["name"].text
        root = json["root"].text
        revision = json["revision"].intValue
        createdAt = json["createdAt"].text
    }
}

public struct EverAgentModelRef: Sendable, Hashable {
    public let provider: String
    public let id: String

    public init(provider: String, id: String) {
        self.provider = provider
        self.id = id
    }

    public var json: JSONValue {
        ["provider": .string(provider), "id": .string(id)]
    }

    public init?(json: JSONValue) {
        guard let provider = json["provider"].stringValue, let id = json["id"].stringValue else { return nil }
        self.init(provider: provider, id: id)
    }
}

public struct EverAgentModelInfo: Sendable, Equatable {
    public let provider: String
    public let id: String
    public let name: String
    public let raw: JSONValue

    public var ref: EverAgentModelRef {
        EverAgentModelRef(provider: provider, id: id)
    }

    init?(json: JSONValue) {
        guard let provider = json["provider"].stringValue, let id = json["id"].stringValue else { return nil }
        self.provider = provider
        self.id = id
        name = json["name"].stringValue ?? id
        raw = json
    }
}

public struct EverAgentTool: Sendable, Equatable {
    public let name: String
    public let description: String
    public let raw: JSONValue

    init?(json: JSONValue) {
        guard let name = json["name"].stringValue, !name.isEmpty else { return nil }
        self.name = name
        description = json["description"].text
        raw = json
    }
}

public struct EverAgentProviderAccount: Sendable, Equatable {
    public let id: String
    public let label: String
    public let detail: String?
    public let kind: String

    init?(json: JSONValue) {
        guard let id = json["id"].stringValue else { return nil }
        self.id = id
        label = json["label"].text
        detail = json["detail"].stringValue
        kind = json["kind"].text
    }
}

public struct EverAgentProvider: Sendable, Equatable {
    public let id: String
    public let name: String
    public let accounts: [EverAgentProviderAccount]
    public let raw: JSONValue

    init?(json: JSONValue) {
        guard let id = json["id"].stringValue else { return nil }
        self.id = id
        name = json["name"].stringValue ?? id
        accounts = json["accounts"].arrayValue.compactMap(EverAgentProviderAccount.init(json:))
        raw = json
    }
}

public struct EverAgentLease: Sendable, Equatable {
    public let ownerDeviceId: String
    public let runtime: String
    public let leaseId: String
    public let expiresAt: String

    init(json: JSONValue) throws {
        guard let leaseId = json["leaseId"].stringValue, !leaseId.isEmpty else {
            throw EverAgentError.protocol("The gateway did not return a session lease.")
        }
        self.leaseId = leaseId
        ownerDeviceId = json["ownerDeviceId"].text
        runtime = json["runtime"].text
        expiresAt = json["expiresAt"].text
    }
}

public struct EverAgentPromptResult: Sendable, Equatable {
    public let accepted: Bool
    public let state: String?
    public let queued: Bool

    init(json: JSONValue) {
        accepted = json["accepted"].boolValue
        state = json["state"].stringValue
        queued = json["queued"].boolValue
    }
}

public struct EverAgentEventBatch: Sendable, Equatable {
    public let events: [EverAgentEvent]
    public let sequence: Int

    init(json: JSONValue) {
        events = json["events"].arrayValue.compactMap(EverAgentEvent.init(json:))
        sequence = json["sequence"].intValue
    }
}

public enum EverAgentContentBlock: Sendable, Equatable {
    case text(String)
    case thinking(String)
    case toolCall(id: String, name: String, arguments: JSONValue)
    case image(mimeType: String, data: String)
    case other(type: String, raw: JSONValue)

    public init(json: JSONValue) {
        switch json["type"].stringValue {
        case "text": self = .text(json["text"].text)
        case "thinking": self = .thinking(json["thinking"].text)
        case "toolCall": self = .toolCall(id: json["id"].text, name: json["name"].text, arguments: json["arguments"])
        case "image": self = .image(mimeType: json["mimeType"].text, data: json["data"].text)
        default: self = .other(type: json["type"].text, raw: json)
        }
    }
}

public struct EverAgentMessage: Sendable, Equatable {
    public let role: String
    public let content: [EverAgentContentBlock]
    public let stopReason: String?
    public let errorMessage: String?
    public let raw: JSONValue

    public var text: String {
        content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined()
    }

    public init(json: JSONValue) {
        role = json["role"].text
        switch json["content"] {
        case .string(let text): content = [.text(text)]
        case .array(let blocks): content = blocks.map(EverAgentContentBlock.init(json:))
        default: content = []
        }
        stopReason = json["stopReason"].stringValue
        errorMessage = json["errorMessage"].stringValue
        raw = json
    }
}

public struct EverAgentSession: Sendable, Equatable {
    public let id: String
    public let projectId: String
    public let title: String
    public let revision: Int
    public let runtime: String
    public let createdAt: String
    public let updatedAt: String
    public let model: EverAgentModelRef?
    public let messages: [EverAgentMessage]
    public let isStreaming: Bool
    public let raw: JSONValue

    init(json: JSONValue) throws {
        guard let id = json["id"].stringValue, !id.isEmpty else {
            throw EverAgentError.protocol("The gateway returned a session without an id.")
        }
        self.id = id
        projectId = json["projectId"].text
        title = json["title"].text
        revision = json["revision"].intValue
        runtime = json["runtime"].text
        createdAt = json["createdAt"].text
        updatedAt = json["updatedAt"].text
        model = EverAgentModelRef(json: json["model"])
        messages = json["messages"].arrayValue.map(EverAgentMessage.init(json:))
        isStreaming = json["state"]["isStreaming"].boolValue
        raw = json
    }
}
