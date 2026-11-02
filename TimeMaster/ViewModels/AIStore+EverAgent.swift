#if os(macOS)
import Foundation
import SwiftUI
import TimeMasterCore

extension AIStore {
    @MainActor
    func sendViaEverAgentIfReady(_ text: String, replyTo: ChatMessage?, attachmentName: String?, attachmentContent: String?) async -> Bool {
        guard await EverAgentCoachEngine.shared.isReadyToSend() else { return false }
        await sendViaEverAgent(text, replyTo: replyTo, attachmentName: attachmentName, attachmentContent: attachmentContent)
        return true
    }

    @MainActor
    func sendViaEverAgent(_ text: String, replyTo: ChatMessage?, attachmentName: String?, attachmentContent: String?) async {
        var prompt = text.isEmpty ? "(see attached file)" : text
        if let replyTo {
            prompt = "In reply to this earlier message:\n> \(replyTo.content.prefix(400))\n\n\(prompt)"
        }
        if let attachmentName, let attachmentContent {
            prompt = "[Attached file: \(attachmentName)]\n\(attachmentContent)\n\n---\n\(prompt)"
        }
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            replyToContent: replyTo.map { String($0.content.prefix(120)) },
            replyToRole: replyTo?.role,
            attachmentName: attachmentName
        )
        let placeholder = ChatMessage(role: .assistant, content: "", isLoading: true)
        let sessionID = currentSessionID
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            appendToCurrentSession(userMessage)
            appendToCurrentSession(placeholder)
            isLoading = true
            isAgentRunning = true
        }
        let title = currentSession.title
        let turn = await EverAgentCoachEngine.shared.run(sessionID: sessionID, title: title, text: prompt) { [weak self] turn in
            self?.showAgentProgress(turn, messageID: placeholder.id, sessionID: sessionID, persist: false)
        }
        showAgentProgress(turn, messageID: placeholder.id, sessionID: sessionID, persist: true)
        isLoading = false
        isAgentRunning = false
        isExecutingTools = false
        agentStatusTitle = nil
        DatabaseStore.shared.reload()
    }

    @MainActor
    func showAgentProgress(_ turn: CoachTurn, messageID: UUID, sessionID: UUID, persist: Bool) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        var message = sessions[sessionIndex].messages[messageIndex]
        var content = turn.text
        if case .failed(let reason) = turn.phase {
            content += (content.isEmpty ? "" : "\n\n") + "⚠️ \(reason)"
        } else if turn.phase == .finished, content.isEmpty {
            content = "Done."
        }
        message.content = content
        message.activity = turn.activities.isEmpty ? nil : turn.activities
        message.isLoading = !turn.isFinished && content.isEmpty
        sessions[sessionIndex].messages[messageIndex] = message
        agentStatusTitle = Self.agentStatusTitle(for: turn)
        isExecutingTools = turn.activities.contains { $0.status == .running }
        if persist { saveSessions() }
    }

    private static func agentStatusTitle(for turn: CoachTurn) -> String? {
        switch turn.phase {
        case .waitingForUser:
            return "Waiting for your answer"
        case .running, .idle:
            if let running = turn.activities.last(where: { $0.status == .running }) { return running.title }
            return turn.isThinking ? "Thinking…" : nil
        case .finished, .failed:
            return nil
        }
    }
}
#endif
