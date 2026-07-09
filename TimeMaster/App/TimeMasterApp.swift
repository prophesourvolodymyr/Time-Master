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
        let ws = WorkoutStore()
        let ds = DatabaseStore.shared
        _store = StateObject(wrappedValue: ws)
        _databaseStore = StateObject(wrappedValue: ds)
    }

    var body: some Scene {
        #if os(macOS)
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
            .frame(minWidth: 800, minHeight: 600)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                    checkResumeState()
                }
            }
            .sheet(isPresented: $showResumePrompt, onDismiss: {
                if resumePlayerWorkout != nil { resumeManager.clearResumeState() }
            }) {
                resumePromptSheet
            }
            .sheet(item: $resumePlayerWorkout) { w in
                WorkoutPlayerView(workout: w)
                    .environmentObject(store)
            }
        }
        .windowStyle(.titleBar)
        .commands { TimeMasterCommands() }
        #else
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
                    checkResumeState()
                }
            }
            .sheet(isPresented: $showResumePrompt, onDismiss: {
                if resumePlayerWorkout != nil { resumeManager.clearResumeState() }
            }) {
                resumePromptSheet
            }
            .sheet(item: $resumePlayerWorkout) { w in
                WorkoutPlayerView(workout: w)
                    .environmentObject(store)
            }
        }
        #endif
    }

    private func checkResumeState() {
        guard resumeManager.hasResumableWorkout,
              let state = resumeManager.resumeState else { return }
        showResumePrompt = true
    }

    @ViewBuilder
    private var resumePromptSheet: some View {
        VStack(spacing: 0) {
            if let state = resumeManager.resumeState {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)

                    Text("Resume Workout?")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text(state.workoutName)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    VStack(spacing: 6) {
                        Text("Elapsed: \(formatElapsed(state.elapsedSeconds))")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Section \(state.currentSectionIndex + 1)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        if let w = store.workouts.first(where: { $0.id == state.workoutId }) {
                            resumePlayerWorkout = w
                        }
                        showResumePrompt = false
                    } label: {
                        Text("Resume")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                    }

                    Button {
                        if state.elapsedSeconds >= 180, let w = store.workouts.first(where: { $0.id == state.workoutId }) {
                            let entry = WorkoutHistoryEntry(
                                workoutId: w.id,
                                workoutName: w.name,
                                durationCompleted: w.totalDuration,
                                workoutType: w.type,
                                isPartial: true,
                                elapsedSeconds: state.elapsedSeconds
                            )
                            store.addHistoryEntry(entry)
                        }
                        resumeManager.clearResumeState()
                        showResumePrompt = false
                    } label: {
                        Text("Discard")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
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
}
