import Combine
import Foundation

struct WorkoutLiveState: Equatable {
    var workoutID: UUID
    var workoutName: String
    var colorHex: String
    var phase: WorkoutPhase
    var title: String
    var subtitle: String
    var isPaused: Bool
    var remainingSeconds: Int
    var phaseDuration: Int
    var sectionIndex: Int
    var sectionCount: Int
    var elapsedSeconds: Int
    var totalSeconds: Int
    var nextTitle: String?
    var startedAt: Date

    var phaseProgress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(phaseDuration)))
    }

    var workoutProgress: Double? {
        guard totalSeconds > 0 else { return nil }
        return min(1, max(0, Double(elapsedSeconds) / Double(totalSeconds)))
    }

    var remainingWorkoutSeconds: Int? {
        guard totalSeconds > 0 else { return nil }
        return max(0, totalSeconds - elapsedSeconds)
    }

    var isRest: Bool { phase == .setRest || phase == .sectionRest }
    var isLeadIn: Bool { phase == .warmUp || phase == .prepare }
}

struct WorkoutLiveFinish: Equatable {
    var workoutName: String
    var elapsedSeconds: Int
    var finishedAt: Date
}

@MainActor
final class WorkoutLiveSession: ObservableObject {
    static let shared = WorkoutLiveSession()

    enum Command: String {
        case togglePause
        case skipPhase
        case endWorkout
    }

    @Published private(set) var state: WorkoutLiveState?
    @Published private(set) var lastFinish: WorkoutLiveFinish?

    let commands = PassthroughSubject<Command, Never>()

    var isActive: Bool { state != nil }

#if os(macOS)
    private var activity: NSObjectProtocol?
#endif

    private init() {}

    func publish(_ newState: WorkoutLiveState) {
        if state == nil {
            lastFinish = nil
            beginActivity()
        }
        if state != newState { state = newState }
    }

    func finish(completed: Bool, elapsedSeconds: Int) {
        guard let current = state else { return }
        state = nil
        endActivity()
        lastFinish = completed
            ? WorkoutLiveFinish(workoutName: current.workoutName, elapsedSeconds: elapsedSeconds, finishedAt: Date())
            : nil
    }

    func send(_ command: Command) {
        guard isActive else { return }
        commands.send(command)
    }

    private func beginActivity() {
#if os(macOS)
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Tmax workout in progress"
        )
#endif
    }

    private func endActivity() {
#if os(macOS)
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
#endif
    }
}
