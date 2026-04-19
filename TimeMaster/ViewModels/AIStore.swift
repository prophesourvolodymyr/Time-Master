import Foundation
import Combine
import SwiftUI

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

// MARK: - AIStore

final class AIStore: ObservableObject {
    static let shared = AIStore()

    // Sessions
    @Published var sessions: [ChatSession] = []
    @Published var currentSessionID: UUID  = UUID()

    // Network state
    @Published var isLoading: Bool          = false
    @Published var availableModels: [String] = []
    @Published var isFetchingModels: Bool    = false

    // Settings (UserDefaults)
    @Published var baseURL: String    = "https://api.openai.com"
    @Published var model: String      = "gpt-4o"
    @Published var soulPrompt: String = "You are an expert fitness coach and training assistant inside the TimeMaster workout app. Be concise, motivating, and practical."
    @Published var knowledgeFilenames: [String] = []

    // API key – Keychain + UserDefaults fallback (see KeychainHelper)
    var apiKey: String {
        get { KeychainHelper.load(forKey: "ai_api_key") ?? "" }
        set { KeychainHelper.save(newValue, forKey: "ai_api_key") }
    }

    // UserDefaults keys
    private let sessionsKey       = "ai_sessions_v2"
    private let currentIDKey      = "ai_current_session_id_v2"
    private let baseURLKey        = "ai_base_url_v1"
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
        baseURL    = UserDefaults.standard.string(forKey: baseURLKey)    ?? "https://api.openai.com"
        model      = UserDefaults.standard.string(forKey: modelKey)      ?? "gpt-4o"
        soulPrompt = UserDefaults.standard.string(forKey: soulPromptKey) ?? soulPrompt
        knowledgeFilenames = UserDefaults.standard.stringArray(forKey: knowledgeFilesKey) ?? []

        // Load sessions
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
        UserDefaults.standard.set(baseURL,    forKey: baseURLKey)
        UserDefaults.standard.set(model,      forKey: modelKey)
        UserDefaults.standard.set(soulPrompt, forKey: soulPromptKey)
        UserDefaults.standard.set(knowledgeFilenames, forKey: knowledgeFilesKey)
    }

    // MARK: - Session helpers

    var currentSession: ChatSession {
        sessions.first { $0.id == currentSessionID } ?? sessions[0]
    }

    var currentMessages: [ChatMessage] {
        currentSession.messages
    }

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
            guard let text = try? String(contentsOf: knowledgeDir.appendingPathComponent(name), encoding: .utf8) else { return nil }
            return "--- \(name) ---\n\(text)"
        }.joined(separator: "\n\n")
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
            let reply = try await callAPI(
                displayText:       trimmed.isEmpty ? "(see attached file)" : trimmed,
                attachmentName:    attachmentName,
                attachmentContent: attachmentContent
            )
            let assistantMsg = ChatMessage(role: .assistant, content: reply)
            await MainActor.run {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    replaceLoadingMessage(id: placeholderID, with: assistantMsg)
                    isLoading = false
                }
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

    // MARK: - Fetch available models

    func fetchModels() async {
        guard !apiKey.isEmpty else { return }
        await MainActor.run { isFetchingModels = true }
        defer { Task { await MainActor.run { self.isFetchingModels = false } } }

        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(base)/v1/models") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelList = json["data"] as? [[String: Any]] else { return }

        let ids = modelList.compactMap { $0["id"] as? String }.sorted()
        await MainActor.run { availableModels = ids }
    }

    // MARK: - API call

    private func callAPI(
        displayText: String,
        attachmentName: String?,
        attachmentContent: String?
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(base)/v1/chat/completions") else { throw AIError.invalidURL }

        // Build messages
        var apiMessages: [[String: String]] = []

        var systemContent = soulPrompt
        let knowledge = loadKnowledgeContext()
        if !knowledge.isEmpty { systemContent += "\n\n# Knowledge\n\(knowledge)" }
        apiMessages.append(["role": "system", "content": systemContent])

        // Last 20 non-loading visible messages
        let history = currentMessages.filter { !$0.isLoading && $0.role != .system }.suffix(20)
        for msg in history {
            var msgContent = msg.content
            // Enrich last user message with attachment if provided
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard http.statusCode == 200 else {
            throw AIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
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
