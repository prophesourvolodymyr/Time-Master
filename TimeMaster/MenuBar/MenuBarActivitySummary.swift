import Foundation

struct MenuBarActivitySummary: Equatable {
    struct Day: Equatable, Identifiable {
        var date: Date
        var seconds: Int
        var isToday: Bool
        var id: Date { date }
    }

    struct TypeShare: Equatable, Identifiable {
        var typeID: String
        var typeName: String
        var colorHex: String
        var seconds: Int
        var fraction: Double
        var id: String { typeID }
    }

    struct Recent: Equatable, Identifiable {
        var id: UUID
        var workoutID: UUID
        var name: String
        var date: Date
        var seconds: Int
        var isPartial: Bool
    }

    var streakCurrent: Int
    var streakBest: Int
    var sessionsThisWeek: Int
    var weeklyGoal: Int
    var weekSeconds: Int
    var days: [Day]
    var monthByType: [TypeShare]
    var recent: [Recent]
    var hasHistory: Bool

    var goalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(sessionsThisWeek) / Double(weeklyGoal))
    }

    var busiestDaySeconds: Int {
        days.lazy.map(\.seconds).max() ?? 0
    }

    static let recentLimit = 8
    static let typeLimit = 3

    static func seconds(of entry: WorkoutHistoryEntry) -> Int {
        max(0, entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted)
    }

    static func make(
        entries: [WorkoutHistoryEntry],
        now: Date,
        calendar: Calendar,
        weeklyGoal: Int,
        streak: (current: Int, best: Int)
    ) -> MenuBarActivitySummary {
        let entries = entries.filter { $0.completedAt <= now }
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? today

        let weekEntries = entries.filter { $0.completedAt >= weekStart }
        let weekSeconds = weekEntries.reduce(0) { $0 + seconds(of: $1) }

        let days: [Day] = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = entries
                .filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
                .reduce(0) { $0 + seconds(of: $1) }
            return Day(date: day, seconds: total, isToday: offset == 0)
        }

        var byType: [String: (name: String, colorHex: String, seconds: Int)] = [:]
        for entry in entries where entry.completedAt >= monthStart {
            let key = entry.workoutType.id
            var current = byType[key] ?? (entry.workoutType.name, entry.workoutType.colorHex, 0)
            current.seconds += seconds(of: entry)
            byType[key] = current
        }
        let monthTotal = byType.values.reduce(0) { $0 + $1.seconds }
        let monthByType: [TypeShare] = byType
            .map { key, value in
                TypeShare(
                    typeID: key,
                    typeName: value.name,
                    colorHex: value.colorHex,
                    seconds: value.seconds,
                    fraction: monthTotal > 0 ? Double(value.seconds) / Double(monthTotal) : 0
                )
            }
            .filter { $0.seconds > 0 }
            .sorted { lhs, rhs in
                if lhs.seconds != rhs.seconds { return lhs.seconds > rhs.seconds }
                return lhs.typeName < rhs.typeName
            }
            .prefix(typeLimit)
            .map { $0 }

        let recent = entries
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(recentLimit)
            .map {
                Recent(
                    id: $0.id,
                    workoutID: $0.workoutId,
                    name: $0.workoutName,
                    date: $0.completedAt,
                    seconds: seconds(of: $0),
                    isPartial: $0.isPartial
                )
            }

        return MenuBarActivitySummary(
            streakCurrent: streak.current,
            streakBest: streak.best,
            sessionsThisWeek: weekEntries.count,
            weeklyGoal: max(0, weeklyGoal),
            weekSeconds: weekSeconds,
            days: days,
            monthByType: monthByType,
            recent: Array(recent),
            hasHistory: !entries.isEmpty
        )
    }
}
