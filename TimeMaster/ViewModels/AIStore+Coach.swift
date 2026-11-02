import Foundation
import SwiftUI
import TimeMasterCore

struct CoachTurnStart {
    let prompt: String
    let placeholderID: UUID
    let sessionID: UUID
    let title: String
    let history: [OnDeviceMessage]
}

extension AIStore {
    var shouldUseOnDevice: Bool {
        guard !usesOwnKey, !hasKey(for: activeProviderID) else { return false }
        return OnDeviceSupport.availability().isReady
    }

    @MainActor
    func refreshEngineName() {
        #if os(macOS)
        if EverAgentCoachEngine.shared.isActive {
            coachEngineName = "EverAgent"
            coachEngineDetail = "Your connected models"
            return
        }
        #endif
        if shouldUseOnDevice {
            coachEngineName = "On-device"
            coachEngineDetail = "Apple Intelligence on this device"
        } else {
            coachEngineName = nil
            coachEngineDetail = nil
        }
    }

    @MainActor
    func beginCoachTurn(_ text: String, replyTo: ChatMessage?, attachmentName: String?, attachmentContent: String?, replyLimit: Int = 400, attachmentLimit: Int? = nil) -> CoachTurnStart {
        let history = currentMessages
            .filter { !$0.isLoading && $0.role != .system }
            .map { OnDeviceMessage(role: $0.role == .user ? .user : .assistant, text: $0.content) }
        var prompt = text.isEmpty ? "(see attached file)" : text
        if let replyTo {
            prompt = "In reply to this earlier message:\n> \(OnDeviceHistory.clipped(replyTo.content, to: replyLimit))\n\n\(prompt)"
        }
        if let attachmentName, let attachmentContent {
            let content = attachmentLimit.map { OnDeviceHistory.clipped(attachmentContent, to: $0) } ?? attachmentContent
            prompt = "[Attached file: \(attachmentName)]\n\(content)\n\n---\n\(prompt)"
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
        return CoachTurnStart(prompt: prompt, placeholderID: placeholder.id, sessionID: sessionID, title: currentSession.title, history: history)
    }

    @MainActor
    func finishCoachTurn(_ progress: CoachProgress, _ start: CoachTurnStart) {
        var final = progress
        final.isFinished = true
        showCoachProgress(final, messageID: start.placeholderID, sessionID: start.sessionID, persist: true)
        isLoading = false
        isAgentRunning = false
        isExecutingTools = false
        agentStatusTitle = nil
        DatabaseStore.shared.reload()
    }

    @MainActor
    func showCoachProgress(_ progress: CoachProgress, messageID: UUID, sessionID: UUID, persist: Bool) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        var message = sessions[sessionIndex].messages[messageIndex]
        var content = progress.text
        if let failure = progress.failure {
            content += (content.isEmpty ? "" : "\n\n") + "⚠️ \(failure)"
        } else if progress.isFinished, content.isEmpty {
            content = "Done."
        }
        message.content = content
        message.activity = progress.activities.isEmpty ? nil : progress.activities
        message.isLoading = !progress.isFinished && content.isEmpty
        sessions[sessionIndex].messages[messageIndex] = message
        agentStatusTitle = progress.statusTitle
        isExecutingTools = progress.activities.contains { $0.status == .running }
        if persist { saveSessions() }
    }
}
