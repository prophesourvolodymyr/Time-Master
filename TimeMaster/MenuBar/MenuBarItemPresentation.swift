import Foundation

struct MenuBarUpcoming: Equatable {
    var name: String
    var startsAt: Date
}

struct MenuBarItemPresentation: Equatable {
    enum Glyph: Equatable {
        case idle
        case upcoming
        case getReady
        case countdown(Int)
        case exercise
        case rest
        case paused
        case finished
    }

    var glyph: Glyph
    var label: String?
    var progress: Double?
    var accessibilityLabel: String
    var tooltip: String

    static let finishDisplaySeconds: TimeInterval = 10
    static let upcomingWindowSeconds: TimeInterval = 15 * 60
    static let countdownSeconds = 5
    static let labelLimit = 16

    static func make(
        state: WorkoutLiveState?,
        finish: WorkoutLiveFinish?,
        upcoming: MenuBarUpcoming?,
        now: Date,
        showsLabel: Bool
    ) -> MenuBarItemPresentation {
        var result = resolve(state: state, finish: finish, upcoming: upcoming, now: now)
        if !showsLabel { result.label = nil }
        return result
    }

    private static func resolve(
        state: WorkoutLiveState?,
        finish: WorkoutLiveFinish?,
        upcoming: MenuBarUpcoming?,
        now: Date
    ) -> MenuBarItemPresentation {
        if let state {
            return live(state)
        }
        if let finish {
            let age = now.timeIntervalSince(finish.finishedAt)
            if age >= 0, age < finishDisplaySeconds {
                return MenuBarItemPresentation(
                    glyph: .finished,
                    label: "Done",
                    progress: nil,
                    accessibilityLabel: "\(finish.workoutName) complete in \(MenuBarFormat.minutes(finish.elapsedSeconds))",
                    tooltip: "\(finish.workoutName) complete · \(MenuBarFormat.clock(finish.elapsedSeconds))"
                )
            }
        }
        if let upcoming {
            let until = upcoming.startsAt.timeIntervalSince(now)
            if until > 0, until <= upcomingWindowSeconds {
                let minutes = max(1, Int((until / 60).rounded(.up)))
                return MenuBarItemPresentation(
                    glyph: .upcoming,
                    label: nil,
                    progress: nil,
                    accessibilityLabel: "\(upcoming.name) starts in \(minutes) minutes",
                    tooltip: "\(upcoming.name) · in \(minutes) min"
                )
            }
        }
        return MenuBarItemPresentation(
            glyph: .idle,
            label: nil,
            progress: nil,
            accessibilityLabel: "Tmax",
            tooltip: "Tmax"
        )
    }

    private static func live(_ state: WorkoutLiveState) -> MenuBarItemPresentation {
        let clock = MenuBarFormat.clock(state.remainingSeconds)
        let tooltip = "\(state.workoutName) · \(state.title) · \(clock) left"

        if state.isPaused {
            return MenuBarItemPresentation(
                glyph: .paused,
                label: "Paused",
                progress: state.phaseProgress,
                accessibilityLabel: "\(state.workoutName) paused",
                tooltip: "\(state.workoutName) · paused"
            )
        }

        let leadsToExercise = state.phase != .active
        if leadsToExercise,
           (1...countdownSeconds).contains(state.remainingSeconds),
           let next = state.nextTitle, !next.isEmpty {
            let suffix = " in \(state.remainingSeconds)"
            return MenuBarItemPresentation(
                glyph: .countdown(state.remainingSeconds),
                label: truncated(next, suffix: suffix),
                progress: state.phaseProgress,
                accessibilityLabel: "\(next) starts in \(state.remainingSeconds) seconds",
                tooltip: tooltip
            )
        }

        switch state.phase {
        case .warmUp:
            return MenuBarItemPresentation(
                glyph: .getReady,
                label: "Warm up \(clock)",
                progress: state.phaseProgress,
                accessibilityLabel: "Warm up, \(clock) left",
                tooltip: tooltip
            )
        case .prepare:
            return MenuBarItemPresentation(
                glyph: .getReady,
                label: "Get ready",
                progress: state.phaseProgress,
                accessibilityLabel: "Get ready, \(clock) left",
                tooltip: tooltip
            )
        case .active:
            return MenuBarItemPresentation(
                glyph: .exercise,
                label: truncated(state.title, suffix: " \(clock)"),
                progress: state.phaseProgress,
                accessibilityLabel: "\(state.title), \(clock) left",
                tooltip: tooltip
            )
        case .setRest, .sectionRest:
            return MenuBarItemPresentation(
                glyph: .rest,
                label: "Rest \(clock)",
                progress: state.phaseProgress,
                accessibilityLabel: "Rest, \(clock) left",
                tooltip: tooltip
            )
        }
    }

    private static func truncated(_ name: String, suffix: String) -> String {
        let room = max(1, labelLimit - suffix.count)
        guard name.count > room else { return name + suffix }
        let trimmed = String(name.prefix(max(1, room - 1))).trimmingCharacters(in: .whitespaces)
        return trimmed + "…" + suffix
    }
}
