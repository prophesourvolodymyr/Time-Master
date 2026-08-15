import Foundation

enum WorkoutPhase: String, Codable {
    case warmUp
    case prepare
    case active
    case setRest
    case sectionRest
}

struct ResumeState: Codable {
    var workoutId: UUID
    var workoutName: String
    var currentSectionIndex: Int
    var currentSetIndex: Int
    var timeRemaining: Int
    var elapsedSeconds: Int
    var phase: WorkoutPhase
    var isPaused: Bool
    var savedAt: Date

    var sectionName: String {
        "Section \(currentSectionIndex + 1)"
    }
}

final class WorkoutResumeManager: ObservableObject {
    static let shared = WorkoutResumeManager()
    private let key = "workout_resume_state_v1"
    private let defaults = UserDefaults.standard

    @Published var resumeState: ResumeState?
    @Published var hasResumableWorkout: Bool = false

    private init() { loadState() }

    func saveState(
        workoutId: UUID,
        workoutName: String,
        currentSectionIndex: Int,
        currentSetIndex: Int,
        timeRemaining: Int,
        elapsedSeconds: Int,
        phase: WorkoutPhase,
        isPaused: Bool
    ) {
        let state = ResumeState(
            workoutId: workoutId,
            workoutName: workoutName,
            currentSectionIndex: currentSectionIndex,
            currentSetIndex: currentSetIndex,
            timeRemaining: timeRemaining,
            elapsedSeconds: elapsedSeconds,
            phase: phase,
            isPaused: isPaused,
            savedAt: Date()
        )
        resumeState = state
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
        hasResumableWorkout = true
    }

    func clearResumeState() {
        resumeState = nil
        hasResumableWorkout = false
        defaults.removeObject(forKey: key)
    }

    private func loadState() {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(ResumeState.self, from: data)
        else {
            hasResumableWorkout = false
            return
        }
        resumeState = state
        hasResumableWorkout = true
    }
}
