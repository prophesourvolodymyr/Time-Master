import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

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
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @ObservedObject private var databaseSync = DatabaseSyncStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showResumePrompt = false
    @State private var resumePlayerWorkout: Workout?
    @State private var pendingURL: URL?
    @State private var didCheckResume = false
    @State private var didPrepareAccount = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if startup.isReady, didPrepareAccount, !databaseSync.changingAccount,
               let store = startup.workoutStore, let database = startup.databaseStore {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(database)
                    .id(databaseSync.libraryGeneration)
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
                TmaxLoadingState(title: startup.isReady ? (databaseSync.changingAccount ? "Switching exercise library..." : "Preparing account...") : startup.status, showsQuote: true)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: startup.isReady)
        .task {
            await startup.prepare()
            guard startup.isReady else { return }
            await cloudAccount.start()
#if os(iOS)
            databaseSync.handleScenePhase(active: UIApplication.shared.applicationState == .active)
#else
            databaseSync.handleScenePhase(active: NSApplication.shared.isActive)
#endif
            didPrepareAccount = true
        }
        .onOpenURL { url in
            if startup.isReady && didPrepareAccount && !databaseSync.changingAccount { handleDeepLink(url) }
            else { pendingURL = url }
        }
        .onChange(of: scenePhase) { phase in
            DatabaseSyncStore.shared.handleScenePhase(active: phase == .active)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseLibraryDidSync)) { notification in
            if notification.userInfo?["accountChanged"] as? Bool == true {
                startup.databaseStore?.reloadImmediately()
            } else {
                startup.databaseStore?.reload()
            }
        }
        .sheet(isPresented: Binding(
            get: { startup.isReady && didPrepareAccount && !databaseSync.changingAccount && resumePlayerWorkout == nil && (showResumePrompt || cloudAccount.presentsRecovery) },
            set: { presented in
                if !presented {
                    showResumePrompt = false
                    cloudAccount.presentsRecovery = false
                }
            }
        )) {
            if cloudAccount.presentsRecovery {
                RankedAccountView()
            } else {
                resumePrompt
            }
        }
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
        if url.host == "auth" {
            Task { await CloudAccountStore.shared.handleCallback(url) }
            return
        }
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
