import SwiftUI
#if os(iOS)
import WidgetKit
#endif
import TimeMasterCore

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
    @StateObject private var store: WorkoutStore
    @StateObject private var databaseStore: DatabaseStore
    @StateObject private var resumeManager = WorkoutResumeManager.shared
    @State private var showSplash = true
    @State private var showResumePrompt = false
    @State private var resumePlayerWorkout: Workout?

    init() {
        MigrationManager.migrateIfNeeded()
        MigrationManager.migrateToV2PagesIfNeeded()
        MigrationManager.normalizeV2PageKindsIfNeeded()
        MigrationManager.normalizePageTypesIfNeeded()
        MigrationManager.cleanLegacyPageCacheIfNeeded()
        let ws = WorkoutStore()
        let ds = DatabaseStore.shared
        _store = StateObject(wrappedValue: ws)
        _databaseStore = StateObject(wrappedValue: ds)
    }

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
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                    checkResumeState()
                }
            }
            .sheet(isPresented: $showResumePrompt) {
                resumePromptSheet
            }
            .workoutPlayerPage(item: $resumePlayerWorkout) { w in
                WorkoutPlayerView(workout: w)
                    .environmentObject(store)
                    .environmentObject(databaseStore)
            }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .commands { TimeMasterCommands() }
        #endif
    }

    private func checkResumeState() {
        guard resumeManager.hasResumableWorkout,
              let state = resumeManager.resumeState else { return }
        showResumePrompt = true
    }

    @ViewBuilder
    private var resumePromptSheet: some View {
        if let state = resumeManager.resumeState {
            let workout = store.workouts.first(where: { $0.id == state.workoutId })
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
                        let entry = WorkoutHistoryEntry(
                            workoutId: workout.id,
                            workoutName: workout.name,
                            durationCompleted: workout.totalDuration,
                            workoutType: workout.type,
                            isPartial: true,
                            elapsedSeconds: state.elapsedSeconds
                        )
                        store.addHistoryEntry(entry)
                    }
                    resumeManager.clearResumeState()
                    showResumePrompt = false
                },
                onClose: {
                    showResumePrompt = false
                }
            )
        }
    }

    // MARK: - Deep Link Handler

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
    static let newWorkoutCommand = Notification.Name("com.timemaster.newWorkoutCommand")
    static let openSettingsCommand = Notification.Name("com.timemaster.openSettingsCommand")
}
