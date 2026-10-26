#if os(iOS)
import AppIntents
import Foundation

extension Notification.Name {
    static let workoutLiveActivityCommand = Notification.Name("com.timemaster.workoutLiveActivityCommand")
}

@available(iOS 17.0, *)
struct TogglePauseWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Workout"
    static var isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .workoutLiveActivityCommand,
            object: nil,
            userInfo: ["command": "togglePause"]
        )
        return .result()
    }
}
#endif
