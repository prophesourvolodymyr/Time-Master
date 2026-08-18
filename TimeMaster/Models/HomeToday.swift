import Foundation

enum ScheduledWorkoutStatus: String, Codable, Equatable {
    case pending
    case completed
    case missed

    var title: String {
        switch self {
        case .pending: "Pending"
        case .completed: "Done"
        case .missed: "Missed"
        }
    }
}

struct ScheduledWorkout: Identifiable, Equatable {
    let id: String
    let workout: Workout
    let scheduledStart: Date
    let scheduledFinish: Date
    let status: ScheduledWorkoutStatus

    var hasScheduledTime: Bool {
        scheduledStart != Calendar.current.startOfDay(for: scheduledStart)
    }

    var timeRangeText: String {
        guard hasScheduledTime else { return "Today" }
        let start = scheduledStart.formatted(date: .omitted, time: .shortened)
        let finish = scheduledFinish.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(finish)"
    }
}
