import Foundation
import Combine

// MARK: - ChatMessage

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case system, user, assistant }
    let id: UUID
    var role: Role
    var content: String
    var isLoading: Bool

    init(id: UUID = UUID(), role: Role, content: String, isLoading: Bool = false) {
        self.id        = id
        self.role      = role
        self.content   = content
        self.isLoading = isLoading
    }
}

// MARK: - AIStore

final class AIStore: ObservableObject {
    static let shared = AIStore()

    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false

    // Settings — persisted in UserDefaults (non-sensitive)
    @Published var baseURL: String   = "https://api.openai.com"
    @Published var model: String     = "gpt-4o"
    @Published var soulPrompt: String = "You are an expert fitness coach and training assistant inside the TimeMaster workout app. Be concise, motivating, and practical."

    // Sensitive — stored in Keychain
    var apiKey: String {
        get { KeychainHelper.load(forKey: "ai_api_key") ?? "" }
        set { KeychainHelper.save(newValue, forKey: "ai_api_key") }
    }

    // Knowledge files
    @Published var knowledgeFilenames: [String] = []

    private let messagesKey        = "ai_chat_messages_v1"
    private let baseURLKey         = "ai_base_url_v1"
    private let modelKey           = "ai_model_v1"
    private let soulPromptKey      = "ai_soul_prompt_v1"
    private let knowledgeFilesKey  = "ai_knowledge_filenames_v1"

    private var knowledgeDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("AIKnowledge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() { load() }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decoded.filter { !$0.isLoading }
        }
        baseURL      = UserDefaults.standard.string(forKey: baseURLKey)     ?? "https://api.openai.com"
        model        = UserDefaults.standard.string(forKey: modelKey)       ?? "gpt-4o"
        soulPrompt   = UserDefaults.standard.string(forKey: soulPromptKey)  ?? soulPrompt
        knowledgeFilenames = UserDefaults.standard.stringArray(forKey: knowledgeFilesKey) ?? []
    }

    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages.filter { !$0.isLoading }) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(baseURL,     forKey: baseURLKey)
        UserDefaults.standard.set(model,       forKey: modelKey)
        UserDefaults.standard.set(soulPrompt,  forKey: soulPromptKey)
        UserDefaults.standard.set(knowledgeFilenames, forKey: knowledgeFilesKey)
    }

    // MARK: - History

    func clearHistory() {
        messages.removeAll()
        saveMessages()
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
        let url = knowledgeDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        knowledgeFilenames.removeAll { $0 == filename }
        saveSettings()
    }

    private func loadKnowledgeContext() -> String {
        var parts: [String] = []
        for filename in knowledgeFilenames {
            let url = knowledgeDir.appendingPathComponent(filename)
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                parts.append("--- \(filename) ---\n\(text)")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Send message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        await MainActor.run {
            messages.append(ChatMessage(role: .user, content: trimmed))
            saveMessages()
            isLoading = true
        }

        let placeholderID = UUID()
        await MainActor.run {
            messages.append(ChatMessage(id: placeholderID, role: .assistant, content: "", isLoading: true))
        }

        do {
            let reply = try await callAPI(userText: trimmed)
            await MainActor.run {
                messages.removeAll { $0.id == placeholderID }
                messages.append(ChatMessage(role: .assistant, content: reply))
                saveMessages()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                messages.removeAll { $0.id == placeholderID }
                messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
                saveMessages()
                isLoading = false
            }
        }
    }

    // MARK: - API call (OpenAI-compatible /chat/completions)

    private func callAPI(userText: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(base)/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        // Build messages array
        var apiMessages: [[String: String]] = []

        // System prompt
        var systemContent = soulPrompt
        let knowledge = loadKnowledgeContext()
        if !knowledge.isEmpty { systemContent += "\n\n# Knowledge\n\(knowledge)" }
        apiMessages.append(["role": "system", "content": systemContent])

        // Conversation history (last 20 visible messages)
        let history = messages.filter { !$0.isLoading }.suffix(20)
        for msg in history {
            switch msg.role {
            case .user:      apiMessages.append(["role": "user",      "content": msg.content])
            case .assistant: apiMessages.append(["role": "assistant", "content": msg.content])
            case .system:    break
            }
        }

        let body: [String: Any] = ["model": model, "messages": apiMessages, "max_tokens": 1024]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first   = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }
        return content
    }

    enum AIError: LocalizedError {
        case missingAPIKey, invalidURL, badResponse, parseError
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:       return "No API key set. Go to AI Settings to add one."
            case .invalidURL:          return "Invalid API base URL."
            case .badResponse:         return "Unexpected server response."
            case .parseError:          return "Could not parse the API response."
            case .httpError(let c, let m): return "HTTP \(c): \(m)"
            }
        }
    }
}
