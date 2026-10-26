import Foundation

struct MenuBarMoment: Equatable {
    var kind: MenuBarMomentKind
    var title: String
    var message: String?
    var workoutName: String
}

struct MenuBarMomentDetector {
    private var workoutID: UUID?
    private var startedAt: Date?
    private var previous: WorkoutLiveState?
    private var countdownArmed = true
    private var halfwayFired = false
    private var lastMinuteFired = false
    private var lastFinishAt: Date?

    mutating func ingest(state: WorkoutLiveState?, finish: WorkoutLiveFinish?) -> [MenuBarMoment] {
        guard let state else {
            previous = nil
            guard let finish, finish.finishedAt != lastFinishAt else { return [] }
            lastFinishAt = finish.finishedAt
            return [
                MenuBarMoment(
                    kind: .finished,
                    title: "Workout complete",
                    message: "\(finish.workoutName) · \(MenuBarFormat.clock(finish.elapsedSeconds))",
                    workoutName: finish.workoutName
                )
            ]
        }

        if state.workoutID != workoutID || state.startedAt != startedAt {
            workoutID = state.workoutID
            startedAt = state.startedAt
            previous = nil
            countdownArmed = true
            halfwayFired = false
            lastMinuteFired = false
        }

        var moments: [MenuBarMoment] = []

        if let previous, state.sectionIndex > previous.sectionIndex {
            moments.append(
                MenuBarMoment(
                    kind: .sectionChanged,
                    title: "Section \(state.sectionIndex + 1) of \(state.sectionCount)",
                    message: state.title.isEmpty ? nil : state.title,
                    workoutName: state.workoutName
                )
            )
        }

        if let previous, !previous.isRest, state.isRest {
            moments.append(
                MenuBarMoment(
                    kind: .restStarted,
                    title: "Rest",
                    message: state.nextTitle.flatMap { $0.isEmpty ? nil : "Next: \($0)" },
                    workoutName: state.workoutName
                )
            )
        }

        if state.phase == .active || state.remainingSeconds > MenuBarItemPresentation.countdownSeconds {
            countdownArmed = true
        }
        if countdownArmed,
           !state.isPaused,
           state.phase != .active,
           (1...MenuBarItemPresentation.countdownSeconds).contains(state.remainingSeconds),
           let next = state.nextTitle, !next.isEmpty {
            countdownArmed = false
            moments.append(
                MenuBarMoment(
                    kind: .countdown,
                    title: "\(next) in \(state.remainingSeconds)",
                    message: nil,
                    workoutName: state.workoutName
                )
            )
        }

        if let previous {
            if !halfwayFired,
               state.totalSeconds >= 120,
               let before = previous.workoutProgress, before < 0.5,
               let now = state.workoutProgress, now >= 0.5 {
                halfwayFired = true
                moments.append(
                    MenuBarMoment(
                        kind: .halfway,
                        title: "Halfway there",
                        message: state.remainingWorkoutSeconds.map { "\(MenuBarFormat.minutes($0)) to go" },
                        workoutName: state.workoutName
                    )
                )
            }
            if !lastMinuteFired,
               state.totalSeconds >= 180,
               let before = previous.remainingWorkoutSeconds, before > 60,
               let now = state.remainingWorkoutSeconds, now <= 60 {
                lastMinuteFired = true
                moments.append(
                    MenuBarMoment(
                        kind: .lastMinute,
                        title: "One minute left",
                        message: nil,
                        workoutName: state.workoutName
                    )
                )
            }
        }

        previous = state
        return moments
    }
}
