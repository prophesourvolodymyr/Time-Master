import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@main
struct TmaxApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(TmaxAppDelegate.self) private var appDelegate
#endif
    @StateObject private var startup = TmaxStartupModel()

    init() {
#if os(macOS)
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
#endif
        NotificationPresenter.shared.install()
    }

    var body: some Scene {
        WindowGroup("Tmax", id: "main") {
            TmaxRootView(startup: startup)
                .preferredColorScheme(.dark)
#if os(macOS)
                .macInterfaceZoom()
                .modifier(MacWindowChrome())
                .modifier(MacMainWindowGuard())
                .toolbarBackground(Theme.background, for: .windowToolbar)
                .toolbarBackground(.visible, for: .windowToolbar)
                .frame(minWidth: 800, minHeight: 600)
#endif
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 780)
        .commands { TmaxCommands(); PhysiqueNativeCommands() }
#endif
    }
}

private struct TmaxRootView: View {
    @ObservedObject var startup: TmaxStartupModel
    @StateObject private var resumeManager = WorkoutResumeManager.shared
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif
    @ObservedObject private var databaseSync = DatabaseSyncStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showResumePrompt = false
    @State private var resumePlayerWorkout: Workout?
    @State private var pendingURL: URL?
    @State private var didCheckResume = false
    @State private var launchPhase = LaunchPhase.loading
    @State private var loadingOpacity = 1.0
    @State private var departureProgress: CGFloat = 0
    @State private var launchGeneration = 0

    private enum LaunchPhase {
        case loading, zooming, revealing, finished
    }

    private var contentIsReady: Bool {
        startup.isReady && !databaseSync.changingAccount
            && startup.workoutStore != nil && startup.databaseStore != nil
    }

    private var canFinishLaunch: Bool {
        contentIsReady && scenePhase == .active
    }

    private var commandsReady: Bool {
        contentIsReady && launchPhase == .finished
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if startup.isReady, !databaseSync.changingAccount,
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
#if os(iOS)
                            if !resumeManager.hasResumableWorkout {
                                WorkoutLiveActivityController.shared.end(completed: false, elapsedSeconds: 0)
                            }
#endif
                        }
                        if let url = pendingURL {
                            pendingURL = nil
                            handleDeepLink(url)
                        }
                    }
            }
            if !contentIsReady || launchPhase != .finished {
                TmaxLoadingState(
                    title: startup.isReady ? (databaseSync.changingAccount ? "Switching exercise library..." : "Opening Tmax…") : startup.status,
                    showsQuote: true,
                    isFinishing: launchPhase == .zooming || launchPhase == .revealing,
                    departureProgress: departureProgress,
                    logs: launchPhase == .finished ? [] : startup.statusHistory
                )
                .background(Color.black.ignoresSafeArea())
                .opacity(launchPhase == .finished ? 1 : loadingOpacity)
                .zIndex(1)
            }
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
        }
        .onOpenURL { url in
            if contentIsReady && launchPhase == .finished { handleDeepLink(url) }
            else { pendingURL = url }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchWorkout)) { notification in
            startRequestedWorkout(notification)
        }
#if os(macOS)
        .onAppear {
            MacMainWindow.openAction = { openWindow(id: "main") }
            MenuBarController.shared.install(startup: startup)
            AppCommandBus.setReady(commandsReady)
        }
        .onChange(of: commandsReady) { ready in
            AppCommandBus.setReady(ready)
        }
        .onDisappear {
            AppCommandBus.setReady(false)
        }
#endif
        .onChange(of: scenePhase) { phase in
            DatabaseSyncStore.shared.handleScenePhase(active: phase == .active)
            if phase == .active, let store = startup.workoutStore {
                NotificationManager.shared.refreshMissedDayNudges(schedules: store.typeSchedules, history: store.historyEntries)
            }
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
                reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.15, 0.7, 0.3, 1, duration: 0.4),
                fallbackDuration: reduceMotion ? 300_000_000 : 450_000_000
            ) {
                launchPhase = .zooming
                departureProgress = 1
            }
            launchPhase = .revealing
            try await animateLaunch(.easeOut(duration: 0.42), fallbackDuration: 500_000_000) {
                loadingOpacity = 0
            }
            launchPhase = .finished
        } catch {
            guard launchGeneration == generation else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                launchPhase = .loading
                loadingOpacity = 1
                departureProgress = 0
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
#if os(iOS)
                    WorkoutLiveActivityController.shared.end(completed: false, elapsedSeconds: 0)
#endif
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
            NotificationCenter.default.post(name: .launchWorkout, object: nil, userInfo: workoutID.map { ["workoutID": $0] })
        default:
            break
        }
    }

    private func startRequestedWorkout(_ notification: Notification) {
        guard contentIsReady, launchPhase == .finished, resumePlayerWorkout == nil,
              !WorkoutLiveSession.shared.isActive,
              let store = startup.workoutStore else { return }
        if resumeManager.hasResumableWorkout {
            showResumePrompt = true
            return
        }
        let requested = (notification.userInfo?["workoutID"] as? UUID).flatMap { store.workout(id: $0) }
        let scheduled = store.scheduledWorkouts(for: Date()).first { $0.status == .pending }?.workout
        let fallback = store.workouts.first { !$0.sections.isEmpty }
        guard let workout = requested ?? scheduled ?? fallback, !workout.sections.isEmpty else { return }
        resumePlayerWorkout = workout
    }
}

extension Notification.Name {
    static let launchWorkout = Notification.Name("com.timemaster.launchWorkout")
    static let openWorkoutDetail = Notification.Name("com.timemaster.openWorkoutDetail")
    static let newWorkoutCommand = Notification.Name("com.timemaster.newWorkoutCommand")
    static let openSettingsCommand = Notification.Name("com.timemaster.openSettingsCommand")
}
