import Foundation

enum HomeDay {
    static func index(for date: Date, calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func daysBetween(_ earlier: Date, _ later: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earlier),
            to: calendar.startOfDay(for: later)
        ).day ?? 0
    }

    static func wrapped(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((value % count) + count) % count
    }
}

enum HomeText {
    static func count(_ value: Int, _ one: String, _ many: String) -> String {
        value == 1 ? "1 \(one)" : "\(value) \(many)"
    }

    static func duration(seconds: Int) -> String {
        let seconds = max(0, seconds)
        if seconds < 60 { return "\(seconds) sec" }
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(remainder) min"
    }
}

enum HomeColor {
    static let fallbackHex = "FF6A00"

    static func brightness(hex: String) -> Double? {
        let digits = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard digits.count == 6, let value = UInt64(digits, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    static func accentHex(_ hex: String) -> String {
        guard let brightness = brightness(hex: hex), (0.12...0.82).contains(brightness) else { return fallbackHex }
        return hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}

struct HomeWorkoutOption: Equatable, Identifiable {
    var id: UUID
    var name: String
    var typeName: String
    var typeIcon: String
    var typeColorHex: String
    var sectionCount: Int
    var durationSeconds: Int
    var lastCompletedAt: Date?
    var preview: [String]

    var canStart: Bool { sectionCount > 0 }

    var metaText: String {
        "\(HomeText.count(sectionCount, "section", "sections")) · \(HomeText.duration(seconds: durationSeconds))"
    }
}

struct HomeRankInput: Equatable {
    var id: UUID
    var lastCompletedAt: Date?
}

enum HomeWorkoutRanking {
    static let rotationWidth = 3

    static func rotation(lastTrainedAt: Date?, now: Date, dayIndex: Int, calendar: Calendar = .current) -> Int {
        guard let lastTrainedAt else { return dayIndex }
        return max(0, HomeDay.daysBetween(lastTrainedAt, now, calendar: calendar) - 1)
    }

    static func ranked(_ inputs: [HomeRankInput], rotation: Int) -> [UUID] {
        var seen: Set<UUID> = []
        let unique = inputs.filter { seen.insert($0.id).inserted }
        let fresh = unique.filter { $0.lastCompletedAt == nil }
        let done = unique.enumerated()
            .filter { $0.element.lastCompletedAt != nil }
            .sorted { left, right in
                let leftDate = left.element.lastCompletedAt ?? .distantPast
                let rightDate = right.element.lastCompletedAt ?? .distantPast
                if leftDate != rightDate { return leftDate < rightDate }
                return left.offset < right.offset
            }
            .map(\.element)
        let ordered = (fresh + done).map(\.id)
        let width = min(rotationWidth, ordered.count)
        guard width > 1 else { return ordered }
        let shift = HomeDay.wrapped(rotation, count: width)
        let head = Array(ordered[..<width])
        let rotated = Array(head[shift...]) + Array(head[..<shift])
        return rotated + Array(ordered[width...])
    }
}

enum HomeTodayStatus: String, Equatable {
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

struct HomeTodayItem: Equatable, Identifiable {
    var id: String
    var workout: HomeWorkoutOption
    var start: Date?
    var timeText: String
    var status: HomeTodayStatus
}

enum HomePickReason: Equatable {
    case pinned
    case scheduled(Date?)
    case neverDone
    case lastDone(daysAgo: Int)
}

struct HomePickOption: Equatable, Identifiable {
    var workout: HomeWorkoutOption
    var reason: HomePickReason

    var id: UUID { workout.id }

    var kicker: String {
        switch reason {
        case .scheduled: "Up next"
        case .pinned: "Your pick"
        case .neverDone, .lastDone: "Today's pick"
        }
    }
}

enum HomePickCopy {
    static func reasonText(
        _ reason: HomePickReason,
        timeText: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }
    ) -> String {
        switch reason {
        case .pinned:
            return "Pinned to this card"
        case .scheduled(let start):
            guard let start else { return "On today's plan" }
            return "Planned for \(timeText(start))"
        case .neverDone:
            return "New for you"
        case .lastDone(let days):
            switch days {
            case ...0: return "Done earlier today"
            case 1: return "Last done yesterday"
            default: return "Last done \(days) days ago"
            }
        }
    }

    static func detailLine(
        for option: HomePickOption,
        timeText: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }
    ) -> String {
        "\(reasonText(option.reason, timeText: timeText)) · \(option.workout.metaText)"
    }
}

enum HomePickResolver {
    static func options(
        planned: [HomeTodayItem],
        skipped: Set<String>,
        ranked: [HomeWorkoutOption],
        pinned: HomeWorkoutOption? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> [HomePickOption] {
        var result: [HomePickOption] = []
        var seen: Set<UUID> = []
        func add(_ workout: HomeWorkoutOption, _ reason: HomePickReason) {
            guard workout.canStart, seen.insert(workout.id).inserted else { return }
            result.append(HomePickOption(workout: workout, reason: reason))
        }
        if let pinned { add(pinned, .pinned) }
        for item in planned where item.status == .pending && !skipped.contains(item.id) {
            add(item.workout, .scheduled(item.start))
        }
        for option in ranked {
            add(option, reason(for: option, now: now, calendar: calendar))
        }
        return result
    }

    static func reason(for option: HomeWorkoutOption, now: Date, calendar: Calendar = .current) -> HomePickReason {
        guard let last = option.lastCompletedAt else { return .neverDone }
        return .lastDone(daysAgo: max(0, HomeDay.daysBetween(last, now, calendar: calendar)))
    }
}

enum HomeTodayState: Equatable {
    case empty
    case agenda
    case allDone
}

enum HomeTodayCopy {
    static func state(items: [HomeTodayItem], skipped: Set<String>) -> HomeTodayState {
        let visible = items.filter { !skipped.contains($0.id) }
        if visible.isEmpty { return .empty }
        if visible.allSatisfy({ $0.status == .completed }) { return .allDone }
        return .agenda
    }
}

enum HomeFirstStep: String, CaseIterable, Identifiable {
    case workoutReady
    case finishSession
    case planSomething
    case addSkill
    case buildStreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workoutReady: "Get a workout ready"
        case .finishSession: "Finish your first session"
        case .planSomething: "Plan a day"
        case .addSkill: "Add a skill to learn"
        case .buildStreak: "Train two days in a row"
        }
    }

    var detail: String {
        switch self {
        case .workoutReady: "Build one, or use the one waiting for you."
        case .finishSession: "Any workout counts, even a short one."
        case .planSomething: "Put a workout on your schedule."
        case .addSkill: "Track something you want to learn, step by step."
        case .buildStreak: "Your flame lights up as the streak grows."
        }
    }

    var systemImage: String {
        switch self {
        case .workoutReady: "dumbbell.fill"
        case .finishSession: "flag.checkered"
        case .planSomething: "calendar.badge.plus"
        case .addSkill: "star.circle.fill"
        case .buildStreak: "flame.fill"
        }
    }
}

struct HomeFirstStepsProgress: Equatable {
    var done: Set<HomeFirstStep>

    init(done: Set<HomeFirstStep> = []) {
        self.done = done
    }

    init(readyWorkouts: Int, finishedSessions: Int, hasPlan: Bool, skills: Int, bestStreak: Int) {
        var done: Set<HomeFirstStep> = []
        if readyWorkouts > 0 { done.insert(.workoutReady) }
        if finishedSessions > 0 { done.insert(.finishSession) }
        if hasPlan { done.insert(.planSomething) }
        if skills > 0 { done.insert(.addSkill) }
        if bestStreak >= 2 { done.insert(.buildStreak) }
        self.done = done
    }

    var total: Int { HomeFirstStep.allCases.count }
    var doneCount: Int { done.count }
    var isComplete: Bool { doneCount == total }
    var next: HomeFirstStep? { HomeFirstStep.allCases.first { !done.contains($0) } }
    var fraction: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }

    func isDone(_ step: HomeFirstStep) -> Bool { done.contains(step) }
}

struct HomeProgressSnapshot: Equatable {
    var sessionsThisWeek = 0
    var weeklyGoal = 0
    var minutesThisWeek = 0
    var currentStreak = 0
    var bestStreak = 0
    var totalSessions = 0
    var trainedToday = false

    var goalFraction: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(sessionsThisWeek) / Double(weeklyGoal))
    }

    var hasHistory: Bool { totalSessions > 0 }
    var goalReached: Bool { weeklyGoal > 0 && sessionsThisWeek >= weeklyGoal }
}

enum HomeProgressCopy {
    struct Message: Equatable {
        var headline: String
        var detail: String
    }

    static func message(for progress: HomeProgressSnapshot) -> Message {
        let goal = progress.weeklyGoal
        let done = progress.sessionsThisWeek
        if !progress.hasHistory && done == 0 {
            return Message(
                headline: "Your first session starts the ring",
                detail: goal > 0
                    ? "Finish one workout and it begins to fill. Weekly goal: \(HomeText.count(goal, "session", "sessions"))."
                    : "Finish one workout and your journey begins."
            )
        }
        guard goal > 0 else {
            return done == 0
                ? Message(headline: "A fresh week", detail: "One session is all it takes to begin.")
                : Message(headline: HomeText.count(done, "session", "sessions") + " this week", detail: "Keep the rhythm going.")
        }
        if done == 0 {
            return Message(
                headline: "A fresh week",
                detail: "\(fills(goal)) your ring. One is all it takes to begin."
            )
        }
        if done >= goal {
            return Message(
                headline: "Weekly goal reached",
                detail: "\(HomeText.count(done, "session", "sessions")) this week. Anything more is a bonus."
            )
        }
        let left = goal - done
        return Message(
            headline: left == 1 ? "One more session fills your ring" : "\(left) more sessions fill your ring",
            detail: "\(done) of \(goal) done this week."
        )
    }

    static func ringLabel(for progress: HomeProgressSnapshot) -> String {
        progress.weeklyGoal > 0
            ? "\(progress.sessionsThisWeek)/\(progress.weeklyGoal)"
            : "\(progress.sessionsThisWeek)"
    }

    static func streakText(_ streak: Int) -> String? {
        streak > 0 ? "\(streak)-day streak" : nil
    }

    static func minutesText(_ minutes: Int) -> String? {
        minutes > 0 ? "\(minutes) min active" : nil
    }

    private static func fills(_ goal: Int) -> String {
        goal == 1 ? "One session fills" : "\(goal) sessions fill"
    }
}

struct HomeWeekDay: Equatable, Identifiable {
    var date: Date
    var weekdayShort: String
    var relativeLabel: String
    var dayNumber: Int
    var isToday: Bool
    var planned: Int
    var done: Int
    var titles: [String]

    var id: Date { date }
    var isOpen: Bool { planned == 0 }
    var isDone: Bool { planned > 0 && done >= planned }
    var pending: Int { max(0, planned - done) }
}

enum HomeWeekCopy {
    static func summary(_ days: [HomeWeekDay]) -> String {
        let planned = days.reduce(0) { $0 + $1.planned }
        let pending = days.reduce(0) { $0 + $1.pending }
        if planned == 0 { return "Nothing planned yet" }
        if pending == 0 { return "All planned sessions done" }
        return "\(HomeText.count(pending, "session", "sessions")) planned"
    }

    static func firstOpenDay(_ days: [HomeWeekDay]) -> HomeWeekDay? {
        days.first { $0.isOpen }
    }

    static func upcoming(_ days: [HomeWeekDay], limit: Int) -> [HomeWeekDay] {
        Array(days.filter { $0.pending > 0 }.prefix(max(0, limit)))
    }
}

struct HomeLibraryCounts: Equatable {
    var exercises = 0
    var skills = 0
    var workouts = 0
    var notes = 0
    var routes = 0
}

struct HomeStat: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case exercises
        case skills
        case workouts
        case notes
        case routes
    }

    var kind: Kind
    var value: Int

    var id: String { kind.rawValue }

    var label: String {
        switch kind {
        case .exercises: value == 1 ? "exercise" : "exercises"
        case .skills: value == 1 ? "skill" : "skills"
        case .workouts: value == 1 ? "workout" : "workouts"
        case .notes: value == 1 ? "note" : "notes"
        case .routes: value == 1 ? "route" : "routes"
        }
    }

    var text: String { "\(value) \(label)" }
}

enum HomeLibraryCopy {
    static func stats(_ counts: HomeLibraryCounts, kinds: [HomeStat.Kind]) -> [HomeStat] {
        kinds.compactMap { kind in
            let value: Int
            switch kind {
            case .exercises: value = counts.exercises
            case .skills: value = counts.skills
            case .workouts: value = counts.workouts
            case .notes: value = counts.notes
            case .routes: value = counts.routes
            }
            return value > 0 ? HomeStat(kind: kind, value: value) : nil
        }
    }

    static func summary(_ stats: [HomeStat]) -> String {
        stats.map(\.text).joined(separator: " · ")
    }

    static func invite(_ counts: HomeLibraryCounts, canRecordOutdoor: Bool) -> String? {
        if counts.workouts == 0 { return "Build your first workout." }
        if counts.exercises == 0 { return "Add exercises to build richer workouts." }
        if counts.skills == 0 { return "Add a skill to learn it step by step." }
        if canRecordOutdoor && counts.routes == 0 { return "Plan a route and it will show up here." }
        return nil
    }
}
