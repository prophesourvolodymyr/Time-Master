import Foundation
import TimeMasterCore

extension AIStore {
    @MainActor
    func sendViaOnDeviceIfReady(_ text: String, replyTo: ChatMessage?, attachmentName: String?, attachmentContent: String?) async -> Bool {
        guard shouldUseOnDevice else { return false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await sendViaOnDevice(text, replyTo: replyTo, attachmentName: attachmentName, attachmentContent: attachmentContent)
            return true
        }
        #endif
        return false
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension AIStore {
    @MainActor
    func sendViaOnDevice(_ text: String, replyTo: ChatMessage?, attachmentName: String?, attachmentContent: String?) async {
        let start = beginCoachTurn(text, replyTo: replyTo, attachmentName: attachmentName, attachmentContent: attachmentContent, replyLimit: 200, attachmentLimit: 1_000)
        let coach = OnDeviceCoach(execute: { [weak self] name, json in
            guard let self else { return "TOOL ERROR: The coach is not available." }
            let arguments = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
            return await self.runToolCall(AgentToolCall(id: UUID().uuidString, name: name, arguments: arguments))
        })
        let request = OnDeviceCoach.Request(message: start.prompt, history: start.history, persona: soulPrompt)
        let task = Task { @MainActor [weak self] in
            var last = CoachProgress()
            var shown = ContinuousClock.now
            for await progress in coach.run(request) {
                last = progress
                let now = ContinuousClock.now
                if progress.isFinished || shown.duration(to: now) > .milliseconds(40) {
                    shown = now
                    self?.showCoachProgress(progress, messageID: start.placeholderID, sessionID: start.sessionID, persist: false)
                }
            }
            if Task.isCancelled, last.text.isEmpty, last.failure == nil { last.text = "Stopped." }
            self?.finishCoachTurn(last, start)
        }
        onDeviceTask = task
        await task.value
        onDeviceTask = nil
    }
}
#endif
