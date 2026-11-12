import Foundation

public enum WorkoutStreak {
    public static func current(
        workoutDays: Set<Date>,
        isRestDay: (Date) -> Bool,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(workoutDays.map { calendar.startOfDay(for: $0) })
        guard let firstDay = days.min() else { return 0 }
        var check = calendar.startOfDay(for: today)
        if !days.contains(check), !isRestDay(check) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: check) else { return 0 }
            check = yesterday
        }
        var count = 0
        var trained = false
        while check >= firstDay, days.contains(check) || isRestDay(check) {
            if days.contains(check) { trained = true }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = previous
        }
        return trained ? count : 0
    }
}
