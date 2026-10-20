import SwiftUI
import TimeMasterCore

@main
struct TmaxApp: App {
    @StateObject private var startup = TmaxStartupModel()

    var body: some Scene {
        WindowGroup("Tmax") {
            TmaxRootView(startup: startup)
                .preferredColorScheme(.dark)
#if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
#endif
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .commands { TmaxCommands() }
#endif
    }
}

private struct TmaxRootView: View {
    @ObservedObject var startup: TmaxStartupModel
    @StateObject private var resumeManager = WorkoutResumeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showResumePrompt = false
    @State private var resumePlayerWorkout: Workout?
    @State private var pendingURL: URL?
    @State private var didCheckResume = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if startup.isReady, let store = startup.workoutStore, let database = startup.databaseStore {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(database)
                    .transition(.opacity)
                    .task {
                        if !didCheckResume {
                            didCheckResume = true
                            showResumePrompt = resumeManager.hasResumableWorkout
                        }
                        if let url = pendingURL {
                            pendingURL = nil
                            handleDeepLink(url)
                        }
                    }
            } else {
                TmaxLoadingState(title: startup.status, showsQuote: true)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: startup.isReady)
        .task { await startup.prepare() }
        .onOpenURL { url in
            if startup.isReady { handleDeepLink(url) }
            else { pendingURL = url }
        }
        .sheet(isPresented: $showResumePrompt) { resumePrompt }
        .workoutPlayerPage(item: $resumePlayerWorkout) { workout in
            if let store = startup.workoutStore, let database = startup.databaseStore {
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(database)
            }
        }
    }

    @ViewBuilder
    private var resumePrompt: some View {
        if let state = resumeManager.resumeState, let store = startup.workoutStore {
            let workout = store.workouts.first { $0.id == state.workoutId }
            WorkoutResumeView(
                state: state,
                workout: workout,
                onResume: {
                    guard let workout else { return }
                    resumePlayerWorkout = workout
                    showResumePrompt = false
                },
                onDiscard: {
                    if state.elapsedSeconds >= 180, let workout {
                        store.addHistoryEntry(WorkoutHistoryEntry(
                            workoutId: workout.id,
                            workoutName: workout.name,
                            durationCompleted: workout.totalDuration,
                            workoutType: workout.type,
                            isPartial: true,
                            elapsedSeconds: state.elapsedSeconds
                        ))
                    }
                    resumeManager.clearResumeState()
                    showResumePrompt = false
                },
                onClose: { showResumePrompt = false }
            )
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "timemaster" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let workoutID = components?.queryItems?.first { $0.name == "workoutID" }?.value.flatMap(UUID.init(uuidString:))
        switch url.host {
        case "detail":
            guard let workoutID else { return }
            NotificationCenter.default.post(name: .openWorkoutDetail, object: nil, userInfo: ["workoutID": workoutID])
        case "start":
            guard let workoutID else { return }
            NotificationCenter.default.post(name: .launchWorkout, object: nil, userInfo: ["workoutID": workoutID])
        default:
            break
        }
    }
}

extension Notification.Name {
    static let launchWorkout = Notification.Name("com.timemaster.launchWorkout")
    static let openWorkoutDetail = Notification.Name("com.timemaster.openWorkoutDetail")
    static let newWorkoutCommand = Notification.Name("com.timemaster.newWorkoutCommand")
    static let openSettingsCommand = Notification.Name("com.timemaster.openSettingsCommand")
}
