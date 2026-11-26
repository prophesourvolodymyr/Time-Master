import Foundation
import TimeMasterCore

/// Lookups and change counters derived from the store's lists, cleared whenever a list changes. Main thread only.
final class WorkoutDerivedCache {
    typealias TypeStats = (sessionsThisWeek: Int, totalSeconds: Int, streak: Int, adherence: Double?)

    private(set) var workoutsRevision = 0
    private(set) var historyRevision = 0
    private var workoutsByID: [UUID: Workout]?
    private var readyWorkoutsByType: [String: Workout]?
    private var calendar = Calendar.current
    private var historyByDay: [Date: [WorkoutHistoryEntry]]?
    private var restDayMemo: [Date: Bool] = [:]
    private var scheduledDayMemo: [Date: Bool] = [:]
    private var activityCountMemo: [Date: Int] = [:]
    private var streakMemo: (day: Date, value: (current: Int, best: Int))?
    private var typeStatsMemo: [String: (day: Date, value: TypeStats)] = [:]
    private var scheduleProgressMemo: (week: Date, day: Date, value: WeeklyWorkoutSchedule.Progress)?
    private var dayKeyFormatter: (formatter: DateFormatter, timeZone: TimeZone, locale: Locale)?

    func workoutsDidChange() {
        workoutsRevision &+= 1
        workoutsByID = nil
        readyWorkoutsByType = nil
    }

    /// The first workout with this id in `workouts`, as a linear search would find it.
    func workout(id: UUID, in workouts: [Workout]) -> Workout? {
        if workoutsByID == nil {
            workoutsByID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        return workoutsByID?[id]
    }

    func readyWorkout(ofType typeID: String, in workouts: [Workout]) -> Workout? {
        if readyWorkoutsByType == nil {
            var first: [String: Workout] = [:]
            for workout in workouts where !workout.sections.isEmpty && first[workout.type.id] == nil {
                first[workout.type.id] = workout
            }
            readyWorkoutsByType = first
        }
        return readyWorkoutsByType?[typeID]
    }

    func historyDidChange() {
        historyRevision &+= 1
        historyByDay = nil
        clearDayFacts()
    }

    func scheduleDidChange() {
        restDayMemo = [:]
        scheduledDayMemo = [:]
        clearDayFacts()
    }

    private func clearDayFacts() {
        activityCountMemo = [:]
        streakMemo = nil
        typeStatsMemo = [:]
        scheduleProgressMemo = nil
    }

    func dayStart(_ date: Date) -> Date {
        let current = Calendar.current
        if current != calendar {
            calendar = current
            historyByDay = nil
            restDayMemo = [:]
            scheduledDayMemo = [:]
            clearDayFacts()
        }
        return calendar.startOfDay(for: date)
    }

    func entries(onDay day: Date, in history: [WorkoutHistoryEntry]) -> [WorkoutHistoryEntry] {
        if historyByDay == nil {
            let dayCalendar = calendar
            historyByDay = Dictionary(grouping: history) { dayCalendar.startOfDay(for: $0.completedAt) }
        }
        return historyByDay?[day] ?? []
    }

    func restDay(_ day: Date, compute: () -> Bool) -> Bool {
        if let known = restDayMemo[day] { return known }
        let value = compute()
        restDayMemo[day] = value
        return value
    }

    func scheduledDay(_ day: Date, compute: () -> Bool) -> Bool {
        if let known = scheduledDayMemo[day] { return known }
        let value = compute()
        scheduledDayMemo[day] = value
        return value
    }

    func activityCount(_ day: Date, compute: () -> Int) -> Int {
        if let known = activityCountMemo[day] { return known }
        let value = compute()
        activityCountMemo[day] = value
        return value
    }

    func streak(on day: Date, compute: () -> (current: Int, best: Int)) -> (current: Int, best: Int) {
        if let memo = streakMemo, memo.day == day { return memo.value }
        let value = compute()
        streakMemo = (day, value)
        return value
    }

    func typeStats(_ typeID: String, on day: Date, compute: () -> TypeStats) -> TypeStats {
        if let memo = typeStatsMemo[typeID], memo.day == day { return memo.value }
        let value = compute()
        typeStatsMemo[typeID] = (day, value)
        return value
    }

    func scheduleProgress(
        through week: Date,
        on day: Date,
        compute: () -> WeeklyWorkoutSchedule.Progress
    ) -> WeeklyWorkoutSchedule.Progress {
        if let memo = scheduleProgressMemo, memo.week == week, memo.day == day { return memo.value }
        let value = compute()
        scheduleProgressMemo = (week, day, value)
        return value
    }

    func dayKey(_ date: Date) -> String {
        let timeZone = TimeZone.current
        let locale = Locale.current
        if let cached = dayKeyFormatter, cached.timeZone == timeZone, cached.locale == locale {
            return cached.formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        dayKeyFormatter = (formatter, timeZone, locale)
        return formatter.string(from: date)
    }
}

extension WorkoutStore {
    /// Bumps whenever `workouts` changes.
    var workoutsRevision: Int { derived.workoutsRevision }

    /// Bumps whenever `historyEntries` changes.
    var historyRevision: Int { derived.historyRevision }
}
