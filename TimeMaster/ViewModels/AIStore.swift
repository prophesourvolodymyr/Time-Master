import Foundation
import Combine
import SwiftUI
import TimeMasterCore

// MARK: - ChatMessage

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case system, user, assistant }

    var id: UUID
    var role: Role
    var content: String          // display text
    var isLoading: Bool
    var timestamp: Date
    var replyToContent: String?  // preview of the quoted message
    var replyToRole: Role?
    var attachmentName: String?  // name of attached file (display only)

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        isLoading: Bool = false,
        timestamp: Date = Date(),
        replyToContent: String? = nil,
        replyToRole: Role? = nil,
        attachmentName: String? = nil
    ) {
        self.id             = id
        self.role           = role
        self.content        = content
        self.isLoading      = isLoading
        self.timestamp      = timestamp
        self.replyToContent = replyToContent
        self.replyToRole    = replyToRole
        self.attachmentName = attachmentName
    }

    // Backward-compatible decode (old messages lack timestamp / reply fields)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,   forKey: .id)
        role           = try c.decode(Role.self,   forKey: .role)
        content        = try c.decode(String.self, forKey: .content)
        isLoading      = (try? c.decode(Bool.self,   forKey: .isLoading))      ?? false
        timestamp      = (try? c.decode(Date.self,   forKey: .timestamp))      ?? Date()
        replyToContent = try? c.decode(String.self,  forKey: .replyToContent)
        replyToRole    = try? c.decode(Role.self,    forKey: .replyToRole)
        attachmentName = try? c.decode(String.self,  forKey: .attachmentName)
    }
}

// MARK: - ChatSession

struct ChatSession: Codable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        messages: [ChatMessage] = []
    ) {
        self.id        = id
        self.title     = title
        self.createdAt = createdAt
        self.messages  = messages
    }

    var lastUserPreview: String {
        messages.last { $0.role == .user && !$0.isLoading }?.content ?? "No messages"
    }
    var visibleCount: Int { messages.filter { !$0.isLoading }.count }
}

// MARK: - ToolCall

struct ToolCall: Equatable {
    let id: String
    let name: String
    let arguments: [String: Any]

    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool { lhs.id == rhs.id }
}

struct ResponseWithTools {
    let text: String
    let toolCalls: [ToolCall]
}

struct ApprovalRequest: Identifiable {
    let id: UUID
    let toolName: String
    let summary: String
    let details: [String: String]
}

// MARK: - AIStore

final class AIStore: ObservableObject {
    static let shared = AIStore()

    // MARK: - Published state

    @Published var sessions: [ChatSession] = []
    @Published var currentSessionID: UUID  = UUID()

    // Network state
    @Published var isLoading: Bool           = false
    @Published var isExecutingTools: Bool    = false
    @Published var toolCallCount: Int        = 0
    @Published var availableModels: [String] = []
    @Published var isFetchingModels: Bool    = false

    // Active provider & model
    @Published var activeProviderID: String  = "openai"
    @Published var customBaseURL: String     = ""   // used only when id == "custom"
    @Published var model: String             = "gpt-4o"

    // Personality + knowledge
    @Published var soulPrompt: String = "You are an expert fitness coach and training assistant inside the TimeMaster workout app. Be concise, motivating, and practical."
    @Published var knowledgeFilenames: [String] = []

    // Tool calling
    let toolRouter = ToolRouter()
    private let maxToolCallIterations = 5
    var sessionContextInjected = false

    @Published var pendingApproval: ApprovalRequest?
    private var approvalContinuation: CheckedContinuation<Bool, Never>?

    private let writeOperations: Set<String> = [
        "create_exercise", "create_folder", "build_workout", "add_media_note", "update_settings",
    ]

    // MARK: - Provider helpers

    var activeProvider: AIProvider {
        AIProvider.all.first { $0.id == activeProviderID } ?? .openai
    }

    /// Current API key for the active provider.
    var currentAPIKey: String { apiKey(for: activeProviderID) }

    func apiKey(for providerID: String) -> String {
        KeychainHelper.load(forKey: "ai_key_\(providerID)") ?? ""
    }

    func setApiKey(_ key: String, for providerID: String) {
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeychainHelper.delete(forKey: "ai_key_\(providerID)")
        } else {
            KeychainHelper.save(key.trimmingCharacters(in: .whitespacesAndNewlines),
                                forKey: "ai_key_\(providerID)")
        }
    }

    func hasKey(for providerID: String) -> Bool { !apiKey(for: providerID).isEmpty }

    // MARK: - UserDefaults keys

    private let sessionsKey       = "ai_sessions_v2"
    private let currentIDKey      = "ai_current_session_id_v2"
    private let activeProviderKey = "ai_active_provider_v1"
    private let customBaseURLKey  = "ai_custom_base_url_v1"
    private let modelKey          = "ai_model_v1"
    private let soulPromptKey     = "ai_soul_prompt_v1"
    private let knowledgeFilesKey = "ai_knowledge_filenames_v1"

    private var knowledgeDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("AIKnowledge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() { load() }

    // MARK: - Load / Save

    private func load() {
        model      = UserDefaults.standard.string(forKey: modelKey)      ?? "gpt-4o"
        soulPrompt = UserDefaults.standard.string(forKey: soulPromptKey) ?? soulPrompt
        knowledgeFilenames = UserDefaults.standard.stringArray(forKey: knowledgeFilesKey) ?? []
        customBaseURL = UserDefaults.standard.string(forKey: customBaseURLKey) ?? ""
        activeProviderID  = UserDefaults.standard.string(forKey: activeProviderKey) ?? "openai"

        // ── Migration: old single "ai_api_key" → ai_key_openai ──────────────
        if let oldKey = KeychainHelper.load(forKey: "ai_api_key"), !oldKey.isEmpty {
            if !hasKey(for: "openai") { setApiKey(oldKey, for: "openai") }
            KeychainHelper.delete(forKey: "ai_api_key")
        }

        // ── Migration: old baseURL → customBaseURL / activeProviderID ────────
        let oldBase = UserDefaults.standard.string(forKey: "ai_base_url_v1") ?? ""
        if !oldBase.isEmpty && oldBase != "https://api.openai.com" && customBaseURL.isEmpty {
            customBaseURL    = oldBase
            activeProviderID = "custom"
        }

        // ── Sessions ─────────────────────────────────────────────────────────
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = decoded
        }

        // Migrate from old single-session format
        if sessions.isEmpty {
            let oldKey = "ai_chat_messages_v1"
            if let data = UserDefaults.standard.data(forKey: oldKey),
               let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data),
               !msgs.isEmpty {
                let s = ChatSession(title: "Previous Chat", messages: msgs.filter { !$0.isLoading })
                sessions = [s]
            }
        }

        if sessions.isEmpty { sessions = [ChatSession()] }

        if let uuidStr = UserDefaults.standard.string(forKey: currentIDKey),
           let id = UUID(uuidString: uuidStr),
           sessions.contains(where: { $0.id == id }) {
            currentSessionID = id
        } else {
            currentSessionID = sessions[0].id
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
        UserDefaults.standard.set(currentSessionID.uuidString, forKey: currentIDKey)
    }

    func saveSettings() {
        UserDefaults.standard.set(activeProviderID, forKey: activeProviderKey)
        UserDefaults.standard.set(customBaseURL,    forKey: customBaseURLKey)
        UserDefaults.standard.set(model,            forKey: modelKey)
        UserDefaults.standard.set(soulPrompt,       forKey: soulPromptKey)
        UserDefaults.standard.set(knowledgeFilenames, forKey: knowledgeFilesKey)
    }

    // MARK: - Session helpers

    var currentSession: ChatSession {
        sessions.first { $0.id == currentSessionID } ?? sessions[0]
    }

    var currentMessages: [ChatMessage] { currentSession.messages }

    func newSession() {
        let s = ChatSession()
        sessions.insert(s, at: 0)
        currentSessionID = s.id
        saveSessions()
    }

    func switchSession(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        currentSessionID = id
        UserDefaults.standard.set(id.uuidString, forKey: currentIDKey)
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if sessions.isEmpty { sessions.append(ChatSession()) }
        if currentSessionID == id { currentSessionID = sessions[0].id }
        saveSessions()
    }

    func clearCurrentSession() {
        mutateCurrentSession {
            $0.messages.removeAll()
            $0.title = "New Chat"
        }
    }

    // MARK: - Knowledge files

    func saveKnowledgeFile(url: URL) {
        let dest = knowledgeDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)
        if !knowledgeFilenames.contains(url.lastPathComponent) {
            knowledgeFilenames.append(url.lastPathComponent)
            saveSettings()
        }
    }

    func deleteKnowledgeFile(filename: String) {
        try? FileManager.default.removeItem(at: knowledgeDir.appendingPathComponent(filename))
        knowledgeFilenames.removeAll { $0 == filename }
        saveSettings()
    }

    private func loadKnowledgeContext() -> String {
        knowledgeFilenames.compactMap { name -> String? in
            guard let text = try? String(contentsOf: knowledgeDir.appendingPathComponent(name),
                                        encoding: .utf8) else { return nil }
            return "--- \(name) ---\n\(text)"
        }.joined(separator: "\n\n")
    }

    private func buildDatabaseContext() -> String {
        let fs = TimeMasterCore.FileSystemHelper()
        let promptBuilder = TimeMasterCore.AISystemPromptBuilder(fs: fs)
        let db = TimeMasterCore.DatabaseManager.shared
        guard let ctx = try? promptBuilder.buildSessionContext(db: db) else { return "" }
        return ctx.toSystemMessage()
    }

    // MARK: - Mutations

    private func mutateCurrentSession(_ block: (inout ChatSession) -> Void) {
        guard let idx = sessions.firstIndex(where: { $0.id == currentSessionID }) else { return }
        block(&sessions[idx])
        saveSessions()
    }

    private func appendToCurrentSession(_ message: ChatMessage) {
        mutateCurrentSession { session in
            session.messages.append(message)
            // Auto-title from first user message
            if (session.title == "New Chat" || session.title.isEmpty), message.role == .user {
                let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                session.title = text.count > 42 ? String(text.prefix(42)) + "…" : text
            }
        }
    }

    private func replaceLoadingMessage(id: UUID, with replacement: ChatMessage) {
        mutateCurrentSession { session in
            if let idx = session.messages.firstIndex(where: { $0.id == id }) {
                session.messages[idx] = replacement
            }
        }
    }

    // MARK: - Approval gate

    func approveCurrentToolCall() {
        approvalContinuation?.resume(returning: true)
        approvalContinuation = nil
    }

    func rejectCurrentToolCall() {
        approvalContinuation?.resume(returning: false)
        approvalContinuation = nil
    }

    private func buildApprovalSummary(toolName: String, args: [String: Any]) -> String {
        switch toolName {
        case "create_exercise":
            let name = args["name"] as? String ?? "New Exercise"
            let type = args["type"] as? String ?? "Other"
            return "Create exercise \"\(name)\" (Type: \(type))"
        case "create_folder":
            let name = args["name"] as? String ?? "New Folder"
            return "Create folder \"\(name)\""
        case "build_workout":
            let name = args["name"] as? String ?? "New Workout"
            let sections = args["sections"] as? [[String: Any]] ?? []
            return "Build workout \"\(name)\" (\(sections.count) sections)"
        case "add_media_note":
            let exerciseID = args["exerciseID"] as? String ?? ""
            return "Add note to exercise \(exerciseID.prefix(8))..."
        case "update_settings":
            return "Update app settings"
        default:
            return "\(toolName): \(args.keys.joined(separator: ", "))"
        }
    }

    private func buildApprovalDetails(toolName: String, args: [String: Any]) -> [String: String] {
        switch toolName {
        case "create_exercise":
            var d: [String: String] = [:]
            if let n = args["name"] as? String { d["Name"] = n }
            if let t = args["type"] as? String { d["Type"] = t }
            if let dur = args["duration"] as? Int { d["Duration"] = "\(dur)s" }
            if let ra = args["restAfter"] as? Int { d["Rest"] = "\(ra)s" }
            if let det = args["details"] as? String, !det.isEmpty { d["Description"] = det }
            return d
        case "create_folder":
            var d: [String: String] = [:]
            if let n = args["name"] as? String { d["Name"] = n }
            if let p = args["parentID"] as? String { d["Parent"] = p }
            return d
        case "build_workout":
            var d: [String: String] = [:]
            if let n = args["name"] as? String { d["Name"] = n }
            if let t = args["type"] as? String { d["Type"] = t }
            if let s = args["sections"] as? [[String: Any]] { d["Sections"] = "\(s.count)" }
            return d
        case "add_media_note":
            return ["Note": args["note"] as? String ?? ""]
        case "update_settings":
            return args.compactMapValues { "\($0)" }
        default:
            return args.compactMapValues { "\($0)" }
        }
    }

    // MARK: - Send message

    func sendMessage(
        _ text: String,
        replyTo: ChatMessage?         = nil,
        attachmentName: String?       = nil,
        attachmentContent: String?    = nil
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachmentName != nil else { return }

        let userMsg = ChatMessage(
            role:           .user,
            content:        trimmed,
            replyToContent: replyTo.map { String($0.content.prefix(120)) },
            replyToRole:    replyTo?.role,
            attachmentName: attachmentName
        )
        let placeholderID = UUID()
        let placeholder   = ChatMessage(id: placeholderID, role: .assistant, content: "", isLoading: true)

        await MainActor.run {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                appendToCurrentSession(userMsg)
                appendToCurrentSession(placeholder)
                isLoading = true
            }
        }

        do {
            let result = try await sendWithToolLoop(
                displayText:       trimmed.isEmpty ? "(see attached file)" : trimmed,
                attachmentName:    attachmentName,
                attachmentContent: attachmentContent
            )
            let assistantMsg = ChatMessage(role: .assistant, content: result)
            await MainActor.run {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    replaceLoadingMessage(id: placeholderID, with: assistantMsg)
                    isLoading = false
                }
                DatabaseStore.shared.reload()
            }
        } catch {
            let errMsg = ChatMessage(role: .assistant, content: "⚠️ \(error.localizedDescription)")
            await MainActor.run {
                withAnimation {
                    replaceLoadingMessage(id: placeholderID, with: errMsg)
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Tool call loop

    private func sendWithToolLoop(
        displayText: String,
        attachmentName: String?,
        attachmentContent: String?
    ) async throws -> String {
        var iteration = 0
        var apiMessages = buildAPIMessages(
            displayText: displayText,
            attachmentName: attachmentName,
            attachmentContent: attachmentContent
        )

        await MainActor.run { toolCallCount = 0 }

        while iteration < maxToolCallIterations {
            iteration += 1
            let provider = activeProvider
            let key = currentAPIKey
            guard !key.isEmpty else { throw AIError.missingAPIKey }

            let baseStr = resolveBaseURL(for: provider)
            let base = baseStr.hasSuffix("/") ? String(baseStr.dropLast()) : baseStr

            let response: ResponseWithTools
            switch provider.authStyle {
            case .bearer:
                response = try await callOpenAICompat(
                    base: base, key: key,
                    messages: apiMessages
                )
            case .xApiKey:
                response = try await callAnthropicMessages(
                    base: base, key: key,
                    apiMessages: apiMessages
                )
            }

            if response.toolCalls.isEmpty {
                await MainActor.run { isExecutingTools = false }
                return response.text.isEmpty ? "Done." : response.text
            }

            await MainActor.run { [iteration] in
                isExecutingTools = true
                toolCallCount = iteration
            }

            apiMessages.append(["role": "assistant", "content": response.text.isEmpty ? "Calling tools..." : response.text])

            for tc in response.toolCalls {
                if writeOperations.contains(tc.name) {
                    let summary = buildApprovalSummary(toolName: tc.name, args: tc.arguments)
                    let details = buildApprovalDetails(toolName: tc.name, args: tc.arguments)
                    let req = ApprovalRequest(id: UUID(), toolName: tc.name, summary: summary, details: details)
                    await MainActor.run { pendingApproval = req }
                    let approved = await withCheckedContinuation { [weak self] cont in
                        self?.approvalContinuation = cont
                    }
                    await MainActor.run { pendingApproval = nil }
                    guard approved else {
                        apiMessages.append(["role": "tool", "content": "TOOL REJECTED: User declined \(tc.name).", "tool_call_id": tc.id])
                        continue
                    }
                }
                let result = await toolRouter.execute(toolName: tc.name, args: tc.arguments)
                let toolContent: String
                if result.success {
                    toolContent = result.data
                } else {
                    toolContent = "TOOL ERROR: \(result.data)"
                }
                apiMessages.append(["role": "tool", "content": toolContent, "tool_call_id": tc.id])
            }
        }

        await MainActor.run { isExecutingTools = false }
        let finalResponse = try await sendFinalAPIRequest(messages: apiMessages)
        return finalResponse
    }

    private func sendFinalAPIRequest(messages: [[String: Any]]) async throws -> String {
        let provider = activeProvider
        let key = currentAPIKey
        guard !key.isEmpty else { throw AIError.missingAPIKey }

        let baseStr = resolveBaseURL(for: provider)
        let base = baseStr.hasSuffix("/") ? String(baseStr.dropLast()) : baseStr

        switch provider.authStyle {
        case .bearer:
            let response = try await callOpenAICompat(base: base, key: key, messages: messages)
            return response.text.isEmpty ? "I've completed those actions." : response.text
        case .xApiKey:
            let response = try await callAnthropicMessages(base: base, key: key, apiMessages: messages)
            return response.text.isEmpty ? "I've completed those actions." : response.text
        }
    }

    private func resolveBaseURL(for provider: AIProvider) -> String {
        if provider.id == "custom" {
            return customBaseURL
        }
        return provider.baseURL
    }

    // MARK: - Fetch available models

    func fetchModels() async {
        let provider = activeProvider
        let key      = currentAPIKey
        guard !key.isEmpty else { return }

        let baseStr: String
        if provider.id == "custom" {
            guard !customBaseURL.isEmpty else { return }
            baseStr = customBaseURL
        } else {
            baseStr = provider.baseURL
        }

        await MainActor.run { isFetchingModels = true }
        defer { Task { await MainActor.run { self.isFetchingModels = false } } }

        let base = baseStr.hasSuffix("/") ? String(baseStr.dropLast()) : baseStr
        guard let url = URL(string: "\(base)/models") else { return }

        var request = URLRequest(url: url)
        request.httpMethod  = "GET"
        request.timeoutInterval = 15
        applyAuth(to: &request, key: key, style: provider.authStyle)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelList = json["data"] as? [[String: Any]] else { return }

        let ids = modelList.compactMap { $0["id"] as? String }.sorted()
        await MainActor.run { availableModels = ids }
    }

    // MARK: - Conversation building

    private func buildAPIMessages(
        displayText: String,
        attachmentName: String?,
        attachmentContent: String?
    ) -> [[String: Any]] {
        var apiMessages: [[String: Any]] = []

        var systemContent = soulPrompt

        let dbContext = buildDatabaseContext()
        if !dbContext.isEmpty {
            systemContent += "\n\n## Current Database State\n\(dbContext)"
        }

        let knowledge = loadKnowledgeContext()
        if !knowledge.isEmpty { systemContent += "\n\n# Knowledge\n\(knowledge)" }
        apiMessages.append(["role": "system", "content": systemContent])

        let history = currentMessages.filter { !$0.isLoading && $0.role != .system }.suffix(20)
        for msg in history {
            var msgContent = msg.content
            if msg.id == history.last?.id, msg.role == .user,
               let attContent = attachmentContent, let attName = attachmentName {
                msgContent = "[Attached file: \(attName)]\n\(attContent)\n\n---\n\(msgContent)"
            }
            switch msg.role {
            case .user:      apiMessages.append(["role": "user",      "content": msgContent])
            case .assistant: apiMessages.append(["role": "assistant", "content": msgContent])
            case .system:    break
            }
        }
        return apiMessages
    }

    // MARK: - API routing (old path kept for models fetch)

    private func callAPI(
        displayText: String,
        attachmentName: String?,
        attachmentContent: String?
    ) async throws -> String {
        let provider = activeProvider
        let key      = currentAPIKey
        guard !key.isEmpty else { throw AIError.missingAPIKey }

        let baseStr: String
        if provider.id == "custom" {
            guard !customBaseURL.isEmpty else { throw AIError.invalidURL }
            baseStr = customBaseURL
        } else {
            baseStr = provider.baseURL
        }
        let base = baseStr.hasSuffix("/") ? String(baseStr.dropLast()) : baseStr

        switch provider.authStyle {
        case .bearer:
            var apiMessages: [[String: String]] = []
            var systemContent = soulPrompt
            let knowledge = loadKnowledgeContext()
            if !knowledge.isEmpty { systemContent += "\n\n# Knowledge\n\(knowledge)" }
            apiMessages.append(["role": "system", "content": systemContent])

            let history = currentMessages.filter { !$0.isLoading && $0.role != .system }.suffix(20)
            for msg in history {
                var msgContent = msg.content
                if msg.id == history.last?.id, msg.role == .user,
                   let attContent = attachmentContent, let attName = attachmentName {
                    msgContent = "[Attached file: \(attName)]\n\(attContent)\n\n---\n\(msgContent)"
                }
                switch msg.role {
                case .user:      apiMessages.append(["role": "user",      "content": msgContent])
                case .assistant: apiMessages.append(["role": "assistant", "content": msgContent])
                case .system:    break
                }
            }

            let body: [String: Any] = ["model": model, "messages": apiMessages, "max_tokens": 1024]
            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: URL(string: "\(base)/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            applyAuth(to: &request, key: key, style: .bearer)
            request.httpBody = bodyData
            request.timeoutInterval = 60

            return try await executeAndParseOpenAI(request: request)
        case .xApiKey:
            guard let url = URL(string: "\(base)/messages") else { throw AIError.invalidURL }

            var systemContent = soulPrompt
            let knowledge = loadKnowledgeContext()
            if !knowledge.isEmpty { systemContent += "\n\n# Knowledge\n\(knowledge)" }

            var apiMessages: [[String: String]] = []
            let history = currentMessages.filter { !$0.isLoading && $0.role != .system }.suffix(20)
            for msg in history {
                var msgContent = msg.content
                if msg.id == history.last?.id, msg.role == .user,
                   let attContent = attachmentContent, let attName = attachmentName {
                    msgContent = "[Attached file: \(attName)]\n\(attContent)\n\n---\n\(msgContent)"
                }
                switch msg.role {
                case .user:      apiMessages.append(["role": "user",      "content": msgContent])
                case .assistant: apiMessages.append(["role": "assistant", "content": msgContent])
                case .system:    break
                }
            }
            if apiMessages.first?["role"] == "assistant" {
                apiMessages.insert(["role": "user", "content": "(continuing)"], at: 0)
            }

            let body: [String: Any] = [
                "model":      model,
                "max_tokens": 1024,
                "system":     systemContent,
                "messages":   apiMessages
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            applyAuth(to: &request, key: key, style: .xApiKey)
            request.httpBody      = bodyData
            request.timeoutInterval = 60

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
            guard http.statusCode == 200 else {
                throw AIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown")
            }
            guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let text    = content.first?["text"] as? String else { throw AIError.parseError }
            return text
        }
    }

    // MARK: - OpenAI-compatible with tools

    private func callOpenAICompat(
        base: String, key: String,
        messages: [[String: Any]]
    ) async throws -> ResponseWithTools {
        guard let url = URL(string: "\(base)/chat/completions") else { throw AIError.invalidURL }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1024,
            "tools": AIProvider.toolDefinitions,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request, key: key, style: .bearer)
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard http.statusCode == 200 else {
            throw AIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else { throw AIError.parseError }

        let text = message["content"] as? String ?? ""
        let rawToolCalls = message["tool_calls"] as? [[String: Any]] ?? []

        var toolCalls: [ToolCall] = []
        for rawTC in rawToolCalls {
            guard let id = rawTC["id"] as? String,
                  let funcObj = rawTC["function"] as? [String: Any],
                  let name = funcObj["name"] as? String else { continue }

            let args: [String: Any]
            if let argsStr = funcObj["arguments"] as? String,
               let argsData = argsStr.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                args = parsed
            } else {
                args = [:]
            }
            toolCalls.append(ToolCall(id: id, name: name, arguments: args))
        }

        return ResponseWithTools(text: text, toolCalls: toolCalls)
    }

    // MARK: - Anthropic Messages API with tools

    private func callAnthropicMessages(
        base: String, key: String,
        apiMessages: [[String: Any]]
    ) async throws -> ResponseWithTools {
        guard let url = URL(string: "\(base)/messages") else { throw AIError.invalidURL }

        var systemPrompt = ""
        var anthropicMessages: [[String: Any]] = []
        for msg in apiMessages {
            let role = msg["role"] as? String ?? ""
            if role == "system" {
                systemPrompt = msg["content"] as? String ?? ""
                continue
            }
            if role == "tool" {
                let toolCallId = msg["tool_call_id"] as? String ?? ""
                let content = msg["content"] as? String ?? ""
                anthropicMessages.append([
                    "role": "user",
                    "content": [[
                        "type": "tool_result",
                        "tool_use_id": toolCallId,
                        "content": content,
                    ]]
                ])
                continue
            }
            if role == "user" || role == "assistant" {
                if let content = msg["content"] as? String {
                    anthropicMessages.append(["role": role, "content": content])
                }
            }
        }
        if anthropicMessages.first?["role"] as? String == "assistant" {
            anthropicMessages.insert(["role": "user", "content": "(continuing)"], at: 0)
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": anthropicMessages,
            "tools": AIProvider.anthropicToolDefinitions,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request, key: key, style: .xApiKey)
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard http.statusCode == 200 else {
            throw AIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { throw AIError.parseError }

        var text = ""
        var toolCalls: [ToolCall] = []

        for block in content {
            let type = block["type"] as? String ?? ""
            if type == "text", let t = block["text"] as? String {
                text += t
            } else if type == "tool_use",
                      let id = block["id"] as? String,
                      let name = block["name"] as? String {
                let args = (block["input"] as? [String: Any]) ?? [:]
                toolCalls.append(ToolCall(id: id, name: name, arguments: args))
            }
        }

        return ResponseWithTools(text: text, toolCalls: toolCalls)
    }

    // MARK: - Shared helpers

    private func applyAuth(to request: inout URLRequest, key: String, style: AIProvider.AuthStyle) {
        switch style {
        case .bearer:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .xApiKey:
            request.setValue(key,         forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
    }

    private func executeAndParseOpenAI(request: URLRequest) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard http.statusCode == 200 else {
            throw AIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown")
        }
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = choices.first?["message"] as? [String: Any],
              let text    = content["content"] as? String else { throw AIError.parseError }
        return text
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case missingAPIKey, invalidURL, badResponse, parseError
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:             return "No API key set — open AI Settings to add one."
            case .invalidURL:                return "Invalid API base URL."
            case .badResponse:               return "Unexpected server response."
            case .parseError:                return "Could not parse the API response."
            case .httpError(let c, let m):   return "HTTP \(c): \(m)"
            }
        }
    }
}
