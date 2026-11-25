import Foundation
import TimeMasterCore

struct HomeOutdoorSnapshot: Equatable {
    var routes = 0
    var sessions = 0
    var distanceKilometers = 0.0
}

struct HomeInsights: Equatable {
    var ranked: [HomeWorkoutOption] = []
    var today: [HomeTodayItem] = []
    var week: [HomeWeekDay] = []
    var progress = HomeProgressSnapshot()
    var steps = HomeFirstStepsProgress()
    var counts = HomeLibraryCounts()
    var outdoor = HomeOutdoorSnapshot()
}

struct HomeLibraryDigest {
    var library: SkillLibrary
    var exercises: Int
    var notes: Int
    var skills: Int

    var token: ObjectIdentifier { library.snapshotToken }

    static func make(from store: DatabaseStore) -> HomeLibraryDigest {
        let library = store.skillLibrary
        var exercises = 0
        var notes = 0
        for page in store.allPagesFlat {
            if page.isExercise {
                exercises += 1
            } else if page.isNote {
                notes += 1
            }
        }
        return HomeLibraryDigest(
            library: library,
            exercises: exercises,
            notes: notes,
            skills: SkillShelf.listed(library.topLevelEntries()).count
        )
    }
}

extension HomeInsights {
    static let rankedLimit = 8
    static let weekLength = 7

    static func make(
        workouts: WorkoutStore,
        libraryStore: DatabaseStore,
        digest: HomeLibraryDigest,
        outdoor: OutdoorActivityStore,
        now: Date,
        calendar: Calendar = .current
    ) -> HomeInsights {
        let dayIndex = HomeDay.index(for: now, calendar: calendar)
        let history = historySummary(workouts.historyEntries, now: now, calendar: calendar)
        let streak = workouts.streakInfo()
        let ready = workouts.workouts.filter { !$0.sections.isEmpty }
        let ranked = rankedOptions(
            ready: ready.filter { !workouts.isArchived($0) },
            history: history,
            now: now,
            dayIndex: dayIndex,
            calendar: calendar
        )
        let scheduledToday = workouts.scheduledWorkouts(for: now, now: now)
        let today = scheduledToday.map { item in
            HomeTodayItem(
                id: item.id,
                workout: option(for: item.workout, lastCompletedAt: history.lastDone[item.workout.id]),
                start: item.hasScheduledTime ? item.scheduledStart : nil,
                timeText: item.timeRangeText,
                status: HomeTodayStatus(rawValue: item.status.rawValue) ?? .pending
            )
        }
        let progress = HomeProgressSnapshot(
            sessionsThisWeek: history.weekSessions,
            weeklyGoal: workouts.weeklyGoal,
            minutesThisWeek: history.weekMinutes,
            currentStreak: streak.current,
            bestStreak: streak.best,
            totalSessions: history.total,
            trainedToday: history.trainedToday
        )
        let established = outdoor.establishedActivities
        let outdoorSnapshot = HomeOutdoorSnapshot(
            routes: outdoor.plannedRoutes.filter { !$0.isDraft }.count,
            sessions: established.count,
            distanceKilometers: established.reduce(0) { $0 + $1.distanceMeters } / 1000
        )
        let counts = HomeLibraryCounts(
            exercises: max(digest.exercises, libraryStore.rootExercises.count),
            skills: digest.skills,
            workouts: workouts.workouts.count,
            notes: digest.notes,
            routes: outdoorSnapshot.routes
        )
        let steps = HomeFirstStepsProgress(
            readyWorkouts: ready.count,
            finishedSessions: history.finished,
            hasPlan: hasPlan(
                schedule: workouts.weeklySchedule,
                typeScheduleCount: workouts.typeSchedules.count,
                trainingDayCount: workouts.trainingDays.count
            ),
            skills: digest.skills,
            bestStreak: streak.best
        )
        return HomeInsights(
            ranked: ranked,
            today: today,
            week: weekDays(workouts: workouts, scheduledToday: scheduledToday, now: now, calendar: calendar),
            progress: progress,
            steps: steps,
            counts: counts,
            outdoor: outdoorSnapshot
        )
    }

    static func option(for workout: Workout, lastCompletedAt: Date?) -> HomeWorkoutOption {
        HomeWorkoutOption(
            id: workout.id,
            name: workout.name,
            typeName: workout.type.name,
            typeIcon: workout.type.iconName,
            typeColorHex: workout.type.colorHex,
            sectionCount: workout.sections.count,
            durationSeconds: workout.totalDuration,
            lastCompletedAt: lastCompletedAt,
            preview: workout.sections.prefix(4).map { sectionTitle($0) }
        )
    }

    static func hasPlan(schedule: WeeklyWorkoutSchedule, typeScheduleCount: Int, trainingDayCount: Int) -> Bool {
        schedule.plans.contains { !$0.entries.isEmpty }
            || schedule.additions.values.contains { !$0.isEmpty }
            || typeScheduleCount > 0
            || trainingDayCount > 0
    }

    private static func sectionTitle(_ section: Section) -> String {
        let alias = section.alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return alias.isEmpty ? section.name : alias
    }

    private struct HistorySummary {
        var lastDone: [UUID: Date] = [:]
        var lastAny: Date?
        var finished = 0
        var total = 0
        var weekSessions = 0
        var weekMinutes = 0
        var trainedToday = false
    }

    private static func historySummary(_ entries: [WorkoutHistoryEntry], now: Date, calendar: Calendar) -> HistorySummary {
        var summary = HistorySummary()
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart
        summary.total = entries.count
        for entry in entries {
            if let lastAny = summary.lastAny {
                if entry.completedAt > lastAny { summary.lastAny = entry.completedAt }
            } else {
                summary.lastAny = entry.completedAt
            }
            if !entry.isPartial {
                summary.finished += 1
                if let known = summary.lastDone[entry.workoutId] {
                    if entry.completedAt > known { summary.lastDone[entry.workoutId] = entry.completedAt }
                } else {
                    summary.lastDone[entry.workoutId] = entry.completedAt
                }
            }
            if entry.completedAt >= weekStart {
                summary.weekSessions += 1
                summary.weekMinutes += (entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted) / 60
            }
            if entry.completedAt >= todayStart && entry.completedAt < tomorrowStart {
                summary.trainedToday = true
            }
        }
        return summary
    }

    private static func rankedOptions(
        ready: [Workout],
        history: HistorySummary,
        now: Date,
        dayIndex: Int,
        calendar: Calendar
    ) -> [HomeWorkoutOption] {
        let rotation = HomeWorkoutRanking.rotation(
            lastTrainedAt: history.lastAny,
            now: now,
            dayIndex: dayIndex,
            calendar: calendar
        )
        let order = HomeWorkoutRanking.ranked(
            ready.map { HomeRankInput(id: $0.id, lastCompletedAt: history.lastDone[$0.id]) },
            rotation: rotation
        )
        let byID = Dictionary(ready.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.prefix(rankedLimit).compactMap { id in
            byID[id].map { option(for: $0, lastCompletedAt: history.lastDone[id]) }
        }
    }

    private static func weekDays(
        workouts: WorkoutStore,
        scheduledToday: [ScheduledWorkout],
        now: Date,
        calendar: Calendar
    ) -> [HomeWeekDay] {
        let todayStart = calendar.startOfDay(for: now)
        return (0..<weekLength).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: todayStart) else { return nil }
            let items = offset == 0 ? scheduledToday : workouts.scheduledWorkouts(for: date, now: now)
            let label: String
            switch offset {
            case 0: label = "Today"
            case 1: label = "Tomorrow"
            default: label = date.formatted(.dateTime.weekday(.wide))
            }
            return HomeWeekDay(
                date: date,
                weekdayShort: date.formatted(.dateTime.weekday(.abbreviated)),
                relativeLabel: label,
                dayNumber: calendar.component(.day, from: date),
                isToday: offset == 0,
                planned: items.count,
                done: items.filter { $0.status == .completed }.count,
                titles: items.prefix(3).map { $0.workout.name }
            )
        }
    }
}
