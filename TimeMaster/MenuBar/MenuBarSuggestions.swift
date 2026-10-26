import Foundation

struct MenuBarSuggestion: Equatable, Identifiable {
    enum Kind: String {
        case resume
        case startSoon
        case missed
        case streakAtRisk
        case goalAlmostMet
        case goalMet
        case typeWaiting
        case restDay
    }

    enum Action: Equatable {
        case startWorkout(UUID?)
        case openPage(SlotNavigationDestination)
        case none
    }

    var kind: Kind
    var title: String
    var message: String
    var actionTitle: String?
    var action: Action

    var id: String { kind.rawValue }
}

struct MenuBarSuggestionInput {
    struct Scheduled: Equatable {
        var workoutID: UUID
        var name: String
        var start: Date
        var hasTime: Bool
        var status: ScheduledWorkoutStatus
        var canStart: Bool
    }

    struct WaitingType: Equatable {
        var typeName: String
        var daysSinceLast: Int
        var workoutID: UUID
    }

    struct Resumable: Equatable {
        var workoutID: UUID
        var name: String
    }

    var now: Date
    var calendar: Calendar = .current
    var scheduledToday: [Scheduled] = []
    var sessionsThisWeek = 0
    var weeklyGoal = 0
    var currentStreak = 0
    var trainedToday = false
    var isRestDay = false
    var resumable: Resumable?
    var isWorkoutRunning = false
    var waitingTypes: [WaitingType] = []
}

enum MenuBarSuggestionEngine {
    static let startSoonWindow: TimeInterval = 30 * 60
    static let lateInDayHour = 18
    static let waitingTypeDays = 7

    static func make(_ input: MenuBarSuggestionInput) -> [MenuBarSuggestion] {
        guard !input.isWorkoutRunning else { return [] }
        var result: [MenuBarSuggestion] = []

        if let resumable = input.resumable {
            result.append(
                MenuBarSuggestion(
                    kind: .resume,
                    title: "Pick up where you left off",
                    message: "\(resumable.name) is waiting for you.",
                    actionTitle: "Resume",
                    action: .startWorkout(resumable.workoutID)
                )
            )
        }

        let pending = input.scheduledToday
            .filter { $0.status == .pending && $0.hasTime && $0.canStart }
            .sorted { $0.start < $1.start }
        if let soon = pending.first(where: {
            let until = $0.start.timeIntervalSince(input.now)
            return until > -MenuBarSuggestionEngine.startSoonWindow && until <= MenuBarSuggestionEngine.startSoonWindow
        }) {
            let time = soon.start.formatted(date: .omitted, time: .shortened)
            result.append(
                MenuBarSuggestion(
                    kind: .startSoon,
                    title: soon.start > input.now ? "\(soon.name) is coming up" : "Time for \(soon.name)",
                    message: "Scheduled for \(time).",
                    actionTitle: "Start",
                    action: .startWorkout(soon.workoutID)
                )
            )
        }

        if let missed = input.scheduledToday.first(where: { $0.status == .missed && $0.canStart }) {
            result.append(
                MenuBarSuggestion(
                    kind: .missed,
                    title: "You missed \(missed.name)",
                    message: "A short session still counts today.",
                    actionTitle: "Start",
                    action: .startWorkout(missed.workoutID)
                )
            )
        }

        let hour = input.calendar.component(.hour, from: input.now)
        if input.currentStreak > 0, !input.trainedToday, !input.isRestDay, hour >= lateInDayHour {
            result.append(
                MenuBarSuggestion(
                    kind: .streakAtRisk,
                    title: "Keep your \(input.currentStreak)-day streak",
                    message: "Nothing is logged today yet.",
                    actionTitle: "Start",
                    action: .startWorkout(nil)
                )
            )
        }

        if input.weeklyGoal > 0 {
            if input.sessionsThisWeek >= input.weeklyGoal {
                result.append(
                    MenuBarSuggestion(
                        kind: .goalMet,
                        title: "Weekly goal reached",
                        message: "\(input.sessionsThisWeek) of \(input.weeklyGoal) sessions done.",
                        actionTitle: "Activity",
                        action: .openPage(.analytics)
                    )
                )
            } else if input.sessionsThisWeek == input.weeklyGoal - 1 {
                result.append(
                    MenuBarSuggestion(
                        kind: .goalAlmostMet,
                        title: "One session to your weekly goal",
                        message: "\(input.sessionsThisWeek) of \(input.weeklyGoal) sessions done.",
                        actionTitle: "Start",
                        action: .startWorkout(nil)
                    )
                )
            }
        }

        if let waiting = input.waitingTypes
            .filter({ $0.daysSinceLast >= waitingTypeDays })
            .max(by: { $0.daysSinceLast < $1.daysSinceLast }) {
            result.append(
                MenuBarSuggestion(
                    kind: .typeWaiting,
                    title: "\(waiting.typeName) is waiting",
                    message: "Not trained for \(waiting.daysSinceLast) days.",
                    actionTitle: "Start",
                    action: .startWorkout(waiting.workoutID)
                )
            )
        }

        if input.isRestDay {
            result.append(
                MenuBarSuggestion(
                    kind: .restDay,
                    title: "Rest day",
                    message: "A short stretch keeps you loose. Ask the coach for ideas.",
                    actionTitle: "Coach",
                    action: .openPage(.coach)
                )
            )
        }

        return result
    }
}

extension MenuBarSuggestionInput {
    @MainActor
    static func make(store: WorkoutStore, now: Date = Date(), calendar: Calendar = .current) -> MenuBarSuggestionInput {
        let scheduled = store.scheduledWorkouts(for: now, now: now).map {
            Scheduled(
                workoutID: $0.workout.id,
                name: $0.workout.name,
                start: $0.scheduledStart,
                hasTime: $0.hasScheduledTime,
                status: $0.status,
                canStart: !$0.workout.sections.isEmpty
            )
        }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let history = store.historyEntries.filter { $0.completedAt <= now }
        let sessionsThisWeek = history.lazy.filter { $0.completedAt >= weekStart }.count
        let trainedToday = history.contains { calendar.isDate($0.completedAt, inSameDayAs: now) }

        var lastByType: [String: Date] = [:]
        for entry in history {
            let key = entry.workoutType.id
            if let existing = lastByType[key], existing >= entry.completedAt { continue }
            lastByType[key] = entry.completedAt
        }
        var waiting: [WaitingType] = []
        for workout in store.workouts where !workout.sections.isEmpty {
            guard let last = lastByType[workout.type.id],
                  !waiting.contains(where: { $0.typeName == workout.type.name }) else { continue }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: last),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            waiting.append(WaitingType(typeName: workout.type.name, daysSinceLast: days, workoutID: workout.id))
        }

        let resumable = WorkoutResumeManager.shared.resumeState.map {
            Resumable(workoutID: $0.workoutId, name: $0.workoutName)
        }

        return MenuBarSuggestionInput(
            now: now,
            calendar: calendar,
            scheduledToday: scheduled,
            sessionsThisWeek: sessionsThisWeek,
            weeklyGoal: store.weeklyGoal,
            currentStreak: store.streakInfo().current,
            trainedToday: trainedToday,
            isRestDay: store.isRestDay(now),
            resumable: resumable,
            isWorkoutRunning: WorkoutLiveSession.shared.isActive,
            waitingTypes: waiting
        )
    }
}
