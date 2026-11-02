#if os(macOS)
import Foundation
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
        let start = beginCoachTurn(text, replyTo: replyTo, attachmentName: attachmentName, attachmentContent: attachmentContent)
        let turn = await EverAgentCoachEngine.shared.run(sessionID: start.sessionID, title: start.title, text: start.prompt) { [weak self] turn in
            self?.showCoachProgress(turn.progress, messageID: start.placeholderID, sessionID: start.sessionID, persist: false)
        }
        finishCoachTurn(turn.progress, start)
    }
}
#endif
