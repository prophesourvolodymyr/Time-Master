#if os(iOS)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case warmUp
            case prepare
            case active
            case setRest
            case sectionRest
            case completed
        }

        var phase: Phase
        var title: String
        var subtitle: String
        var isPaused: Bool
        var remainingSeconds: Int
        var phaseDuration: Int
        var phaseEndDate: Date?
        var nextTitle: String?
        var elapsedSeconds: Int
    }

    var workoutID: String
    var workoutName: String
    var colorHex: String
    var startedAt: Date
}
#endif
