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
    @State private var launchPhase = LaunchPhase.loading
    @State private var whiteOpacity = 0.0
    @State private var launchGeneration = 0

    private enum LaunchPhase {
        case loading, zooming, revealing, finished
    }

    private var contentIsReady: Bool {
        startup.isReady && didPrepareAccount && !databaseSync.changingAccount
            && startup.workoutStore != nil && startup.databaseStore != nil
    }

    private var canFinishLaunch: Bool {
        contentIsReady && scenePhase == .active
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if startup.isReady, didPrepareAccount, !databaseSync.changingAccount,
               let store = startup.workoutStore, let database = startup.databaseStore {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(database)
                    .id(databaseSync.libraryGeneration)
                    .allowsHitTesting(launchPhase == .finished)
                    .accessibilityHidden(launchPhase != .finished)
                    .task(id: launchPhase == .finished) {
                        guard launchPhase == .finished else { return }
                        if !didCheckResume {
                            didCheckResume = true
                            showResumePrompt = resumeManager.hasResumableWorkout
                        }
                        if let url = pendingURL {
                            pendingURL = nil
                            handleDeepLink(url)
                        }
                    }
            }
            if !contentIsReady || launchPhase == .loading || launchPhase == .zooming {
                TmaxLoadingState(
                    title: startup.isReady ? (databaseSync.changingAccount ? "Switching exercise library..." : "Preparing account...") : startup.status,
                    showsQuote: true,
                    isFinishing: launchPhase == .zooming,
                    logs: launchPhase == .finished ? [] : startup.statusHistory
                )
                .background(Color.black.ignoresSafeArea())
                .zIndex(1)
            }
            Color.white
                .ignoresSafeArea()
                .opacity(whiteOpacity)
                .allowsHitTesting(launchPhase != .finished)
                .accessibilityHidden(true)
                .zIndex(2)
        }
        .task(id: canFinishLaunch) {
            guard canFinishLaunch, launchPhase != .finished else { return }
            await finishLaunch()
        }
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
            if contentIsReady && launchPhase == .finished { handleDeepLink(url) }
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
            get: { contentIsReady && launchPhase == .finished && resumePlayerWorkout == nil && (showResumePrompt || cloudAccount.presentsRecovery) },
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

    private func finishLaunch() async {
        launchGeneration += 1
        let generation = launchGeneration
        do {
            try await animateLaunch(
                reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.55, 0, 1, 0.45, duration: 0.6),
                fallbackDuration: reduceMotion ? 300_000_000 : 650_000_000
            ) {
                launchPhase = .zooming
            }
            try await animateLaunch(.easeIn(duration: 0.2), fallbackDuration: 350_000_000) {
                whiteOpacity = 1
            }
            try await Task.sleep(nanoseconds: 120_000_000)
            launchPhase = .revealing
            try await animateLaunch(.easeOut(duration: 0.45), fallbackDuration: 500_000_000) {
                whiteOpacity = 0
            }
            launchPhase = .finished
        } catch {
            guard launchGeneration == generation else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                launchPhase = .loading
                whiteOpacity = 0
            }
        }
    }

    private func animateLaunch(_ animation: Animation, fallbackDuration: UInt64, changes: () -> Void) async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                withAnimation(animation, completionCriteria: .removed, changes) {
                    continuation.resume()
                }
            }
        } else {
            withAnimation(animation, changes)
            try await Task.sleep(nanoseconds: fallbackDuration)
        }
        try Task.checkCancellation()
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
