#if os(macOS)
import Foundation

public extension EverAgentClient {
    func serverInfo() async throws -> EverAgentServerInfo {
        try EverAgentServerInfo(json: try await request("server.info"))
    }

    func projects() async throws -> [EverAgentProject] {
        try await request("projects.list")["projects"].arrayValue.map { try EverAgentProject(json: $0) }
    }

    func attachProject(root: String) async throws -> EverAgentProject {
        try EverAgentProject(json: try await request("projects.attach", params: ["root": .string(root)]))
    }

    func createSession(projectId: String, title: String, model: EverAgentModelRef? = nil, sessionId requested: String? = nil) async throws -> String {
        let sessionId = requested ?? Self.newIdentifier()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var session: JSONValue = [
            "id": .string(sessionId),
            "projectId": .string(projectId),
            "title": .string(title),
            "runtime": "mac",
            "revision": 0,
            "createdAt": .string(timestamp),
            "updatedAt": .string(timestamp),
            "messages": [],
            "entries": [],
        ]
        if let model { session["model"] = model.json }
        let saved = try await request("sessions.save", params: [
            "session": session,
            "baseRevision": 0,
            "opId": .string(Self.newIdentifier()),
        ])
        let savedId = saved["id"].stringValue ?? sessionId
        _ = try await claimSession(sessionId: savedId)
        return savedId
    }

    func ensureSession(sessionId: String, projectId: String, title: String, model: EverAgentModelRef? = nil) async throws {
        do {
            _ = try await getSession(sessionId: sessionId)
            _ = try await claimSession(sessionId: sessionId)
        } catch EverAgentError.remote(let code, _, _) where code == EverAgentErrorCode.notFound {
            _ = try await createSession(projectId: projectId, title: title, model: model, sessionId: sessionId)
        }
    }

    func claimSession(sessionId: String) async throws -> EverAgentLease {
        try EverAgentLease(json: try await request("sessions.claim", params: ["sessionId": .string(sessionId), "runtime": "mac"]))
    }

    func prompt(sessionId: String, projectId: String, text: String, images: [JSONValue] = []) async throws -> EverAgentPromptResult {
        _ = try await claimSession(sessionId: sessionId)
        var arguments: [String: JSONValue] = ["text": .string(text)]
        if !images.isEmpty { arguments["images"] = .array(images) }
        let result = try await workerCall("session.prompt", projectId: projectId, sessionId: sessionId, arguments: arguments, durable: true)
        return EverAgentPromptResult(json: result)
    }

    func abort(sessionId: String, projectId: String) async throws {
        _ = try await claimSession(sessionId: sessionId)
        _ = try await workerCall("session.abort", projectId: projectId, sessionId: sessionId, durable: true)
    }

    func setModel(sessionId: String, projectId: String, model: EverAgentModelRef, thinkingLevel: String? = nil) async throws {
        _ = try await claimSession(sessionId: sessionId)
        var arguments: [String: JSONValue] = ["model": model.json]
        if let thinkingLevel { arguments["thinkingLevel"] = .string(thinkingLevel) }
        _ = try await workerCall("session.setModel", projectId: projectId, sessionId: sessionId, arguments: arguments, durable: true)
    }

    func getSession(sessionId: String) async throws -> EverAgentSession {
        try EverAgentSession(json: try await request("sessions.get", params: ["sessionId": .string(sessionId)]))
    }

    func listTools(sessionId: String, projectId: String) async throws -> [EverAgentTool] {
        try await fetchTools(sessionId: sessionId, projectId: projectId, timeout: nil)
    }

    func waitForTools(
        sessionId: String,
        projectId: String,
        prefix: String,
        timeout: TimeInterval = 10,
        pollInterval: TimeInterval = 0.1
    ) async throws -> [EverAgentTool] {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        let operation = "the tools starting with \(prefix)"
        func secondsLeft() -> TimeInterval {
            let left = clock.now.duration(to: deadline).components
            return TimeInterval(left.seconds) + TimeInterval(left.attoseconds) / 1e18
        }
        while true {
            var remaining = secondsLeft()
            guard remaining > 0 else { throw EverAgentError.timeout(operation: operation, after: timeout) }
            let tools: [EverAgentTool]
            do {
                tools = try await fetchTools(sessionId: sessionId, projectId: projectId, timeout: remaining)
            } catch EverAgentError.timeout {
                throw EverAgentError.timeout(operation: operation, after: timeout)
            }
            let matching = tools.filter { $0.name.hasPrefix(prefix) }
            if !matching.isEmpty { return matching }
            remaining = secondsLeft()
            guard remaining > 0 else { throw EverAgentError.timeout(operation: operation, after: timeout) }
            do {
                try await Task.sleep(nanoseconds: UInt64(min(max(pollInterval, 0.001), remaining) * 1_000_000_000))
            } catch {
                throw EverAgentError.cancelled
            }
        }
    }

    func respondUI(projectId: String, sessionId: String, requestId: String, result: JSONValue, cancelled: Bool = false) async throws {
        var params: [String: JSONValue] = [
            "projectId": .string(projectId),
            "sessionId": .string(sessionId),
            "requestId": .string(requestId),
            "result": result,
        ]
        if cancelled { params["cancelled"] = true }
        _ = try await request("worker.ui.response", params: params)
    }

    func models(projectId: String) async throws -> [EverAgentModelInfo] {
        try await workerCall("models.list", projectId: projectId)["models"].arrayValue.compactMap(EverAgentModelInfo.init(json:))
    }

    func providerCatalog(projectId: String) async throws -> [EverAgentProvider] {
        try await workerCall("providers.catalog", projectId: projectId)["providers"].arrayValue.compactMap(EverAgentProvider.init(json:))
    }

    func eventsAfter(sequence: Int, limit: Int? = nil) async throws -> EverAgentEventBatch {
        var params: [String: JSONValue] = ["sequence": .int(sequence)]
        if let limit { params["limit"] = .int(limit) }
        return EverAgentEventBatch(json: try await request("events.after", params: params))
    }
}

extension EverAgentClient {
    static func newIdentifier() -> String {
        UUID().uuidString.lowercased()
    }

    func workerCall(
        _ method: String,
        projectId: String,
        sessionId: String? = nil,
        arguments: [String: JSONValue] = [:],
        durable: Bool = false,
        timeout: TimeInterval? = nil
    ) async throws -> JSONValue {
        var scoped = arguments
        var params: [String: JSONValue] = ["projectId": .string(projectId), "method": .string(method)]
        if let sessionId {
            params["sessionId"] = .string(sessionId)
            scoped["sessionId"] = .string(sessionId)
        }
        params["arguments"] = .object(scoped)
        if durable { params["opId"] = .string(Self.newIdentifier()) }
        return try await request("worker.call", params: params, timeout: timeout)
    }

    func fetchTools(sessionId: String, projectId: String, timeout: TimeInterval?) async throws -> [EverAgentTool] {
        try await workerCall("tools.list", projectId: projectId, sessionId: sessionId, timeout: timeout)["tools"].arrayValue.compactMap(EverAgentTool.init(json:))
    }
}
#endif
