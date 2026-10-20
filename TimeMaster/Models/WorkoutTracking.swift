import Foundation

enum AnalyticsTracker: String, CaseIterable, Identifiable {
    case sessions
    case trainingTime
    case streak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions: "Sessions this week"
        case .trainingTime: "Training this week"
        case .streak: "Day streak"
        }
    }

    var systemImage: String {
        switch self {
        case .sessions: "checkmark.circle"
        case .trainingTime: "clock"
        case .streak: "flame"
        }
    }
}

struct WorkoutWeekSummary {
    struct Day: Identifiable {
        let date: Date
        var sessions = 0
        var seconds = 0
        var id: Date { date }
    }

    let days: [Day]
    let sessions: Int
    let seconds: Int

    init(entries: [WorkoutHistoryEntry], asOf date: Date = Date(), calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        var days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { Day(date: $0) }
        }
        var sessions = 0
        var seconds = 0
        for entry in entries where entry.completedAt >= start && entry.completedAt <= date {
            guard let index = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: entry.completedAt)).day,
                  days.indices.contains(index) else { continue }
            let duration = entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted
            days[index].sessions += 1
            days[index].seconds += duration
            sessions += 1
            seconds += duration
        }
        self.days = days
        self.sessions = sessions
        self.seconds = seconds
    }
}
