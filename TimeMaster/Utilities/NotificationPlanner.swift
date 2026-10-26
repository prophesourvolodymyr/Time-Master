import Foundation

enum NotificationPlanner {
    struct MissedNudge: Equatable {
        let type: WorkoutType
        let workoutDate: Date
        let fireDate: Date
    }

    static let missedGrace: TimeInterval = 60 * 60
    static let lookaheadDays = 7

    static func missedNudges(
        schedules: [TypeSchedule],
        history: [WorkoutHistoryEntry],
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [MissedNudge] {
        var nudges: [MissedNudge] = []
        let today = calendar.startOfDay(for: now)
        for schedule in schedules {
            for offset in 0..<lookaheadDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      schedule.daysOfWeek.contains(mondayBasedWeekday(of: day, calendar: calendar)),
                      schedule.isActive(on: day),
                      let workoutDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
                else { continue }
                let fireDate = workoutDate.addingTimeInterval(missedGrace)
                guard fireDate > now else { continue }
                let didComplete = history.contains {
                    $0.workoutType.id == schedule.type.id && calendar.isDate($0.completedAt, inSameDayAs: day)
                }
                guard !didComplete else { continue }
                nudges.append(MissedNudge(type: schedule.type, workoutDate: workoutDate, fireDate: fireDate))
            }
        }
        return nudges
    }

    static func mondayBasedWeekday(of date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}
