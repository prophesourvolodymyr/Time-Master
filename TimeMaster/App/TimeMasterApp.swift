import SwiftUI
import WidgetKit

@main
struct TimeMasterApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var databaseStore = DatabaseStore.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(databaseStore)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    // MARK: - Deep Link Handler

    /// Handles timemaster://start?workoutID=<UUID> from the widget
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "timemaster",
              url.host == "start",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idItem = components.queryItems?.first(where: { $0.name == "workoutID" }),
              let idString = idItem.value,
              let workoutID = UUID(uuidString: idString) else { return }

        // Post a notification that the tab/root view can observe to navigate
        NotificationCenter.default.post(
            name: .launchWorkout,
            object: nil,
            userInfo: ["workoutID": workoutID]
        )
    }
}

extension Notification.Name {
    static let launchWorkout = Notification.Name("com.timemaster.launchWorkout")
}
