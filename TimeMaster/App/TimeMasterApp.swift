import SwiftUI
import WidgetKit

// MARK: - Splash Screen

struct SplashView: View {
    @State private var opacity: Double = 0.0
    @State private var scale:   Double = 0.88

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                Text("TimeMaster")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    opacity = 1
                    scale   = 1
                }
            }
        }
    }
}

// MARK: - App

@main
struct TimeMasterApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var databaseStore = DatabaseStore.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(databaseStore)
                    .preferredColorScheme(.dark)
                    .onOpenURL { url in handleDeepLink(url) }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
            }
        }
    }

    // MARK: - Deep Link Handler

    /// Handles:
    ///   timemaster://detail?workoutID=<UUID>  → opens WorkoutDetailView
    ///   timemaster://start?workoutID=<UUID>   → starts workout player (legacy)
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "timemaster" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let idString   = components?.queryItems?.first(where: { $0.name == "workoutID" })?.value
        let workoutID  = idString.flatMap { UUID(uuidString: $0) }

        switch url.host {
        case "detail":
            guard let id = workoutID else { return }
            NotificationCenter.default.post(
                name: .openWorkoutDetail,
                object: nil,
                userInfo: ["workoutID": id]
            )
        case "start":
            guard let id = workoutID else { return }
            NotificationCenter.default.post(
                name: .launchWorkout,
                object: nil,
                userInfo: ["workoutID": id]
            )
        default:
            break
        }
    }
}

extension Notification.Name {
    static let launchWorkout    = Notification.Name("com.timemaster.launchWorkout")
    static let openWorkoutDetail = Notification.Name("com.timemaster.openWorkoutDetail")
}
