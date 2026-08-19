import Foundation
import Combine
import SwiftUI
import WidgetKit
import TimeMasterCore

class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var historyEntries: [WorkoutHistoryEntry] = []

    private let workoutsKey = "workouts"
    private let historyKey = "workout_history"
    private let restDaysKey = "workout_rest_days"
    private let goalKey = "workout_weekly_goal"
    private let schedulesKey = "workout_type_schedules"
    private let userDefaults = UserDefaults.standard

    @AppStorage("workout_weekly_goal") var weeklyGoal: Int = 4
    @Published var restDays: Set<String> = []
    @Published var typeSchedules: [TypeSchedule] = []
    @Published var customWorkoutTypes: [WorkoutType] = []

    // MARK: - Training Schedule (global)
    @Published var trainingDays: Set<Int> = []
    @Published var trainingStartDate: Date = Date()
    @Published var trainingDurationMonths: Int = 3

    private var isMigrated: Bool { MigrationManager.isMigrationComplete }

    init() {
        if isMigrated {
            loadFromFileSystem()
        } else {
            loadWorkouts()
            loadHistory()
            loadRestDays()
            loadSchedules()
            loadCustomTypes()
            loadTrainingSchedule()
            loadGoal()
            if workouts.isEmpty {
                seedDefaultWorkouts()
            } else {
                saveWorkouts()
            }
        }
    }

    // MARK: - File System Loading

    private func loadFromFileSystem() {
        let db = DatabaseManager.shared

        let manifests = (try? db.listWorkouts()) ?? []
        workouts = manifests.map { $0.toAppWorkout() }

        let history = (try? db.readHistory()) ?? []
        historyEntries = history.map { $0.toAppHistoryEntry() }

        let config: ConfigManifest
        do {
            config = try db.loadConfig()
        } catch {
            config = ConfigManifest()
        }
        customWorkoutTypes = config.customWorkoutTypes.map { WorkoutType(core: $0) }
        restDays = Set(config.restDays)
        let goalVal = config.weeklyGoal
        if goalVal >= 1, goalVal <= 7 { weeklyGoal = goalVal }
        trainingDays = Set(config.trainingDays)
        trainingStartDate = config.trainingStartDate
        trainingDurationMonths = config.trainingDurationMonths
        typeSchedules = config.typeSchedules.map { ts in
            TypeSchedule(
                id: UUID(uuidString: ts.id) ?? UUID(),
                folderID: UUID(uuidString: ts.folderID),
                type: WorkoutType(core: ts.type),
                daysOfWeek: Set(ts.daysOfWeek),
                startDate: ts.startDate,
                durationMonths: ts.durationMonths,
                weeklyGoal: ts.weeklyGoal,
                startTime: ts.startTime.map { TimeOfDay(hour: $0.hour, minute: $0.minute) },
                durationMinutes: ts.durationMinutes,
                endedAt: ts.endedAt
            )
        }


        if workouts.isEmpty {
            seedDefaultWorkouts()
        } else {
            saveWorkouts()
        }
    }

    // MARK: - Seed

    /// Inserts a default HIIT workout on first launch so the player has content
    /// to demonstrate TTS and timer behaviour right out of the box.
    private func seedDefaultWorkouts() {
        var hiit = Workout(name: "Full Body Blast", type: .hiit, colorHex: "FFFFFF")
        hiit.restBetweenSections = 20
        hiit.sections = [
            Section(name: "Jump Squats",     duration: 60),
            Section(name: "Push-Ups",        duration: 60),
            Section(name: "High Knees",      duration: 60),
            Section(name: "Burpees",         duration: 60),
            Section(name: "Mountain Climbers", duration: 60),
            Section(name: "Plank Hold",      duration: 60),
            Section(name: "Jumping Jacks",   duration: 60),
            Section(name: "Tricep Dips",     duration: 60),
        ]
        workouts.append(hiit)
        saveWorkouts()
    }

    // MARK: - CRUD

    @discardableResult
    func addWorkout(name: String, type: WorkoutType = .strength, colorHex: String = "FFFFFF") -> Workout {
        let workout = Workout(name: name, type: type, colorHex: colorHex)
        workouts.append(workout)
        saveWorkouts()
        return workout
    }

    func deleteWorkout(_ workout: Workout) {
        for section in workout.sections {
            for item in section.mediaItems {
                PhotoManager.shared.deleteMedia(filename: item.filename)
            }
        }
        workouts.removeAll { $0.id == workout.id }
        if isMigrated {
            try? DatabaseManager.shared.deleteWorkout(id: workout.id.uuidString)
        }
        saveWorkouts()
    }

    func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
            saveWorkouts()
        }
    }

    func cloneWorkout(_ workout: Workout, newName: String? = nil) {
        var clonedWorkout = workout
        clonedWorkout.id = UUID()
        clonedWorkout.name = newName ?? "\(workout.name) Copy"
        clonedWorkout.createdAt = Date()

        var newSections: [Section] = []
        for section in workout.sections {
            var newSection = section
            newSection.id = UUID()
            newSections.append(newSection)
        }
        clonedWorkout.sections = newSections

        workouts.append(clonedWorkout)
        saveWorkouts()
    }

    func addSection(to workout: Workout, section: Section) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index].sections.append(section)
            saveWorkouts()
        }
    }

    func updateSection(in workout: Workout, section: Section) {
        if let workoutIndex = workouts.firstIndex(where: { $0.id == workout.id }),
           let sectionIndex = workouts[workoutIndex].sections.firstIndex(where: { $0.id == section.id }) {
            workouts[workoutIndex].sections[sectionIndex] = section
            saveWorkouts()
        }
    }

    func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    func canNestWorkout(_ childID: UUID, in parentID: UUID) -> Bool {
        guard childID != parentID,
              workout(id: childID) != nil,
              workout(id: parentID) != nil else {
            return false
        }
        var visited: Set<UUID> = []
        return !workoutReaches(childID, targetID: parentID, visited: &visited)
    }

    func flattenedWorkout(_ source: Workout) -> Workout {
        var flattened = source
        flattened.sections = source.sections.map { section in
            var result = section
            result.slots = flattenSlots(
                section.effectiveSlots,
                visited: [source.id]
            )
            result.sets = max(1, result.slots.count)
            return result
        }
        return flattened
    }

    private func workoutReaches(
        _ sourceID: UUID,
        targetID: UUID,
        visited: inout Set<UUID>
    ) -> Bool {
        guard visited.insert(sourceID).inserted,
              let source = workout(id: sourceID) else {
            return false
        }

        for slot in source.sections.flatMap(\.effectiveSlots) {
            if slotReferences(slot, targetID: targetID, visited: &visited) {
                return true
            }
        }
        return false
    }

    private func slotReferences(
        _ slot: SetSlot,
        targetID: UUID,
        visited: inout Set<UUID>
    ) -> Bool {
        if slot.nestedWorkoutID == targetID {
            return true
        }
        if let nestedID = slot.nestedWorkoutID,
           workoutReaches(nestedID, targetID: targetID, visited: &visited) {
            return true
        }
        return slot.children.contains {
            slotReferences($0, targetID: targetID, visited: &visited)
        }
    }

    private func flattenSlots(
        _ slots: [SetSlot],
        visited: Set<UUID>
    ) -> [SetSlot] {
        slots.flatMap { flattenSlot($0, visited: visited) }
    }

    private func flattenSlot(
        _ slot: SetSlot,
        visited: Set<UUID>
    ) -> [SetSlot] {
        if let nestedID = slot.nestedWorkoutID,
           !visited.contains(nestedID),
           let nested = workout(id: nestedID) {
            var expanded: [SetSlot] = []
            let nestedVisited = visited.union([nestedID])
            for section in nested.sections {
                expanded.append(contentsOf: flattenSlots(section.effectiveSlots, visited: nestedVisited))
                let sectionRest = section.bigRestRow?.duration
                    ?? (section.customRestAfter == 0 ? 0 : nested.restBetweenSections)
                if sectionRest > 0, let lastIndex = expanded.indices.last {
                    appendRest(
                        duration: sectionRest,
                        row: section.bigRestRow,
                        to: &expanded[lastIndex]
                    )
                }
            }

            guard !expanded.isEmpty else { return [slot] }
            if let preparation = slot.prepareTime {
                expanded[0].prepareTime = preparation
            }
            if slot.restAfter > 0 {
                appendRest(duration: slot.restAfter, row: slot.restRow, to: &expanded[expanded.count - 1])
            }
            return expanded
        }

        var parent = slot
        let children = flattenSlots(slot.children, visited: visited)
        parent.children = []
        return [parent] + children
    }

    private func appendRest(
        duration: Int,
        row: RestRow?,
        to slot: inout SetSlot
    ) {
        guard duration > 0 else { return }
        slot.restAfter += duration
        if let row {
            var rest = row
            rest.kind = .normal
            rest.duration = duration
            slot.restRow = rest
        } else if slot.restRow == nil {
            slot.restRow = RestRow(duration: slot.restAfter)
        } else {
            slot.restRow?.duration = slot.restAfter
        }
    }

    func deleteSection(in workout: Workout, section: Section) {
        if let workoutIndex = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[workoutIndex].sections.removeAll { $0.id == section.id }
            for item in section.mediaItems {
                PhotoManager.shared.deleteMedia(filename: item.filename)
            }
            saveWorkouts()
        }
    }

    func reorderSections(in workout: Workout, from source: IndexSet, to destination: Int) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index].sections.move(fromOffsets: source, toOffset: destination)
            saveWorkouts()
        }
    }

    func addHistoryEntry(_ entry: WorkoutHistoryEntry) {
        historyEntries.insert(entry, at: 0)
        saveHistory()
        NotificationManager.shared.sendPostWorkoutCelebration()
        NotificationManager.shared.notifyWorkoutCompleted(
            totalWorkouts: historyEntries.count,
            streak: streakInfo().current
        )
        NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
    }

    func clearHistory() {
        historyEntries.removeAll()
        saveHistory()
        NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
    }

    func deleteHistoryEntries(at offsets: IndexSet) {
        historyEntries.remove(atOffsets: offsets)
        saveHistory()
        NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
    }

    /// Re-reads data from the active store (file system or UserDefaults).
    /// Call after a backup import to refresh in-memory state.
    func reload() {
        if isMigrated {
            loadFromFileSystem()
            saveWorkouts()   // sync App Group so widget reflects imported data
        } else {
            loadWorkouts()
            loadHistory()
            saveWorkouts()
        }
    }

    private func saveWorkouts() {
        if isMigrated {
            let db = DatabaseManager.shared
            for workout in workouts {
                let manifest = workout.coreManifest
                if (try? db.getWorkout(id: manifest.id)) != nil {
                    try? db.updateWorkout(id: manifest.id, manifest: manifest)
                } else {
                    try? db.createWorkout(id: manifest.id, manifest: manifest)
                }
            }
        }
        if let data = try? JSONEncoder().encode(workouts) {
            userDefaults.set(data, forKey: workoutsKey)
        }
        let sharedDefaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let todayHistory = historyEntries.filter { $0.completedAt >= weekStart }
        let compact = workouts.map { workout in
            WidgetWorkoutRef(
                id: workout.id.uuidString,
                name: workout.name,
                colorHex: workout.colorHex,
                type: workout.type.name,
                durationMinutes: max(1, Int(ceil(Double(workout.totalDuration) / 60.0))),
                sectionCount: workout.sections.count,
                setCount: workout.sections.reduce(0) { $0 + max(1, $1.effectiveSlots.count) },
                sessionsThisWeek: todayHistory.filter { $0.workoutId == workout.id }.count
            )
        }
        if let data = try? JSONEncoder().encode(compact) {
            sharedDefaults?.set(data, forKey: "widget_workouts")
        }
        let today = scheduledWorkouts(for: Date()).map {
            WidgetTodayRef(
                id: $0.id,
                workoutID: $0.workout.id.uuidString,
                workoutName: $0.workout.name,
                durationMinutes: max(1, Int(ceil(Double($0.workout.totalDuration) / 60.0))),
                timeRange: $0.timeRangeText,
                status: $0.status.rawValue,
                colorHex: $0.workout.colorHex
            )
        }
        if let data = try? JSONEncoder().encode(today) {
            sharedDefaults?.set(data, forKey: "widget_today")
        }
        sharedDefaults?.set(streakInfo().current, forKey: "widget_streak")
        sharedDefaults?.set(weeklyGoal, forKey: "widget_weekly_goal")
        sharedDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private struct WidgetWorkoutRef: Codable {
        var id: String
        var name: String
        var colorHex: String
        var type: String
        var durationMinutes: Int
        var sectionCount: Int
        var setCount: Int
        var sessionsThisWeek: Int
    }

    private struct WidgetTodayRef: Codable {
        var id: String
        var workoutID: String
        var workoutName: String
        var durationMinutes: Int
        var timeRange: String
        var status: String
        var colorHex: String
    }

    private func loadWorkouts() {
        guard let data = userDefaults.data(forKey: workoutsKey),
              let workouts = try? JSONDecoder().decode([Workout].self, from: data) else { return }
        self.workouts = workouts
    }

    private func saveHistory() {
        if isMigrated {
            let history = historyEntries.map { entry in
                HistoryEntry(
                    id: entry.id.uuidString,
                    workoutId: entry.workoutId.uuidString,
                    workoutName: entry.workoutName,
                    completedAt: entry.completedAt,
                    durationCompleted: entry.durationCompleted,
                    workoutType: entry.workoutType.core,
                    isPartial: entry.isPartial,
                    elapsedSeconds: entry.elapsedSeconds
                )
            }
            try? DatabaseManager.shared.replaceHistory(history)
            return
        }
        if let data = try? JSONEncoder().encode(historyEntries) {
            userDefaults.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([WorkoutHistoryEntry].self, from: data) else { return }
        self.historyEntries = history
    }

    // MARK: - F04-A: Rest Days & Goal

    private func loadRestDays() {
        if let data = userDefaults.data(forKey: restDaysKey),
           let days = try? JSONDecoder().decode(Set<String>.self, from: data) {
            restDays = days
        }
    }

    func saveRestDays() {
        if isMigrated {
            saveConfigToFileSystem()
            return
        }
        if let data = try? JSONEncoder().encode(restDays) {
            userDefaults.set(data, forKey: restDaysKey)
        }
    }

    private func loadGoal() {
        if let data = userDefaults.data(forKey: goalKey),
           let goal = try? JSONDecoder().decode(Int.self, from: data) {
            weeklyGoal = goal
        }
    }

    func setWeeklyGoal(_ goal: Int) {
        weeklyGoal = max(1, min(7, goal))
        if let data = try? JSONEncoder().encode(weeklyGoal) {
            userDefaults.set(data, forKey: goalKey)
        }
    }

    func toggleRestDay(for date: Date) {
        let key = dateKey(from: date)
        if restDays.contains(key) {
            restDays.remove(key)
        } else {
            restDays.insert(key)
        }
        saveRestDays()
        NotificationManager.shared.applyPreferences(
            NotificationManager.shared.preferences,
            schedules: typeSchedules,
            restDays: restDays
        )
    }

    func isRestDay(_ date: Date) -> Bool {
        restDays.contains(dateKey(from: date))
    }

    func isScheduledDay(_ date: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let monBased = (weekday + 5) % 7 + 1
        let dayStart = cal.startOfDay(for: date)
        if trainingDays.contains(monBased),
           dayStart >= cal.startOfDay(for: trainingStartDate),
           dayStart <= trainingEndDate {
            return true
        }
        for schedule in typeSchedules where schedule.isActive(on: date) {
            if schedule.daysOfWeek.contains(monBased),
               dayStart >= cal.startOfDay(for: schedule.startDate) {
                return true
            }
        }
        return false
    }

    private var trainingEndDate: Date {
        Calendar.current.date(byAdding: .month, value: trainingDurationMonths, to: trainingStartDate) ?? trainingStartDate
    }

    func scheduledTypes(for date: Date) -> [WorkoutType] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let monBased = (weekday + 5) % 7 + 1
        let dayStart = cal.startOfDay(for: date)
        return typeSchedules
            .filter { $0.isActive(on: date) && $0.daysOfWeek.contains(monBased) && dayStart >= cal.startOfDay(for: $0.startDate) }
            .map { $0.type }
    }
    func scheduledWorkouts(for date: Date, now: Date = Date()) -> [ScheduledWorkout] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: date)
        let mondayBasedWeekday = (weekday + 5) % 7 + 1

        let instances = typeSchedules.compactMap { schedule -> ScheduledWorkout? in
            guard schedule.isActive(on: date),
                  schedule.daysOfWeek.contains(mondayBasedWeekday),
                  dayStart >= calendar.startOfDay(for: schedule.startDate),
                  let workout = workouts.first(where: {
                      $0.type.id == schedule.type.id && !$0.sections.isEmpty
                  }) else {
                return nil
            }

            let scheduledStart = schedule.startTime?.date(on: dayStart) ?? dayStart
            let fallbackDuration = max(1, Int(ceil(Double(workout.totalDuration) / 60.0)))
            let durationMinutes = max(1, schedule.durationMinutes ?? fallbackDuration)
            let scheduledFinish = scheduledStart.addingTimeInterval(TimeInterval(durationMinutes * 60))
            let completed = historyEntries.contains {
                guard $0.workoutId == workout.id,
                      calendar.isDate($0.completedAt, inSameDayAs: dayStart) else {
                    return false
                }
                return schedule.startTime == nil || $0.completedAt <= scheduledFinish
            }
            let status: ScheduledWorkoutStatus
            if completed {
                status = .completed
            } else if schedule.startTime != nil && now > scheduledStart {
                status = .missed
            } else {
                status = .pending
            }

            return ScheduledWorkout(
                id: "\(schedule.id.uuidString)-\(dateKey(from: date))",
                workout: workout,
                scheduledStart: scheduledStart,
                scheduledFinish: scheduledFinish,
                status: status
            )
        }

        return instances.sorted { lhs, rhs in
            let leftRank = statusRank(lhs.status)
            let rightRank = statusRank(rhs.status)
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.scheduledStart < rhs.scheduledStart
        }
    }

    private func statusRank(_ status: ScheduledWorkoutStatus) -> Int {
        switch status {
        case .pending: 0
        case .completed: 1
        case .missed: 2
        }
    }


    func hasWorkout(on date: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return historyEntries.contains { cal.isDate($0.completedAt, inSameDayAs: start) }
    }

    func dateKey(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Schedule CRUD

    func addSchedule(_ schedule: TypeSchedule) {
        let start = Calendar.current.startOfDay(for: schedule.startDate)
        for index in typeSchedules.indices where typeSchedules[index].type.id == schedule.type.id && typeSchedules[index].isActive(on: start) {
            typeSchedules[index].endedAt = start
        }
        typeSchedules.append(schedule)
        saveSchedules()
        NotificationManager.shared.rescheduleNotifications(for: typeSchedules)
        NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
    }

    func updateSchedule(_ schedule: TypeSchedule) {
        if let idx = typeSchedules.firstIndex(where: { $0.id == schedule.id }) {
            typeSchedules[idx] = schedule
            saveSchedules()
            NotificationManager.shared.rescheduleNotifications(for: typeSchedules)
            NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
        }
    }

    func deleteSchedule(id: UUID) {
        typeSchedules.removeAll { $0.id == id }
        saveSchedules()
        NotificationManager.shared.rescheduleNotifications(for: typeSchedules)
        NotificationManager.shared.refreshMissedDayNudges(schedules: typeSchedules, history: historyEntries)
    }

    private func loadSchedules() {
        if let data = userDefaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([TypeSchedule].self, from: data) {
            typeSchedules = decoded
        }
    }

    private func saveSchedules() {
        if isMigrated {
            saveConfigToFileSystem()
            return
        }
        if let data = try? JSONEncoder().encode(typeSchedules) {
            userDefaults.set(data, forKey: schedulesKey)
        }
    }

    private func saveConfigToFileSystem() {
        let db = DatabaseManager.shared
        guard var config = try? db.loadConfig() else { return }
        config.typeSchedules = typeSchedules.map {
            TypeScheduleManifest(
                id: $0.id.uuidString,
                folderID: $0.folderID?.uuidString ?? "",
                type: $0.type.core,
                daysOfWeek: Array($0.daysOfWeek).sorted(),
                startDate: $0.startDate,
                durationMonths: $0.durationMonths,
                weeklyGoal: $0.weeklyGoal,
                startTime: $0.startTime.map { TimeOfDayManifest(hour: $0.hour, minute: $0.minute) },
                durationMinutes: $0.durationMinutes,
                endedAt: $0.endedAt
            )
        }
        config.customWorkoutTypes = customWorkoutTypes.map(\.core)
        config.restDays = Array(restDays).sorted()
        config.trainingDays = Array(trainingDays).sorted()
        config.trainingStartDate = trainingStartDate
        config.trainingDurationMonths = trainingDurationMonths
        config.weeklyGoal = weeklyGoal
        try? db.saveConfig(config)
    }

    private let customTypesKey = "custom_workout_types"

    func addCustomType(name: String, iconName: String, colorHex: String = "FFFFFF") {
        let id = name
        let type = WorkoutType(id: id, name: name, iconName: iconName, colorHex: colorHex)
        customWorkoutTypes.append(type)
        saveCustomTypes()
    }

    func updateCustomType(_ type: WorkoutType) {
        if let idx = customWorkoutTypes.firstIndex(where: { $0.id == type.id }) {
            customWorkoutTypes[idx] = type
            saveCustomTypes()
        }
    }

    func deleteCustomType(id: String) {
        customWorkoutTypes.removeAll { $0.id == id }
        saveCustomTypes()
    }

    private func loadCustomTypes() {
        if let data = userDefaults.data(forKey: customTypesKey),
           let decoded = try? JSONDecoder().decode([WorkoutType].self, from: data) {
            customWorkoutTypes = decoded
        }
    }

    private func saveCustomTypes() {
        if isMigrated {
            saveConfigToFileSystem()
            return
        }
        if let data = try? JSONEncoder().encode(customWorkoutTypes) {
            userDefaults.set(data, forKey: customTypesKey)
        }
    }

    private let trainingDaysKey = "training_days"
    private let trainingStartKey = "training_start_date"
    private let trainingDurationKey = "training_duration_months"

    func saveTrainingSchedule() {
        if isMigrated {
            saveConfigToFileSystem()
            return
        }
        if let data = try? JSONEncoder().encode(Array(trainingDays)) {
            userDefaults.set(data, forKey: trainingDaysKey)
        }
        userDefaults.set(trainingStartDate.timeIntervalSince1970, forKey: trainingStartKey)
        userDefaults.set(trainingDurationMonths, forKey: trainingDurationKey)
    }

    private func loadTrainingSchedule() {
        if let data = userDefaults.data(forKey: trainingDaysKey),
           let days = try? JSONDecoder().decode([Int].self, from: data) {
            trainingDays = Set(days)
        }
        let ts = userDefaults.double(forKey: trainingStartKey)
        if ts > 0 { trainingStartDate = Date(timeIntervalSince1970: ts) }
        let dur = userDefaults.integer(forKey: trainingDurationKey)
        if dur > 0 { trainingDurationMonths = dur }
    }

    func streakInfo() -> (current: Int, best: Int) {
        let cal = Calendar.current
        let daySet = Set(historyEntries.map { cal.startOfDay(for: $0.completedAt) })

        var current = 0
        var check = cal.startOfDay(for: Date())
        while daySet.contains(check) || isRestDay(check) {
            current += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }

        let days = daySet.sorted()
        var best = 0
        var cur = 0
        var prev: Date? = nil
        for day in days {
            if let p = prev,
               let next = cal.date(byAdding: .day, value: 1, to: p),
               cal.isDate(next, inSameDayAs: day) {
                cur += 1
            } else if let p = prev,
                      cal.isDate(p, inSameDayAs: day) {
                continue
            } else if let p = prev,
                      let nextDay = cal.date(byAdding: .day, value: 1, to: p) {
                let restGap = isRestDay(nextDay) && !cal.isDate(nextDay, inSameDayAs: day)
                if restGap {
                    cur += 1
                } else if cal.isDate(nextDay, inSameDayAs: day) {
                    cur += 1
                } else {
                    cur = 1
                }
            } else {
                cur = 1
            }
            best = max(best, cur)
            prev = day
        }

        return (current, best)
    }

    func typeStats(for type: WorkoutType, asOf date: Date = Date()) -> (sessionsThisWeek: Int, totalSeconds: Int, streak: Int, adherence: Double?) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let entries = historyEntries.filter { $0.workoutType.id == type.id }
        let sessionsThisWeek = entries.filter { $0.completedAt >= weekStart }.count
        let totalSeconds = entries.reduce(0) { $0 + ($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) }
        let daySet = Set(entries.map { calendar.startOfDay(for: $0.completedAt) })
        let activeSchedule = typeSchedules.last { $0.type.id == type.id && $0.isActive(on: date) }
        var streak = 0
        var cursor = calendar.startOfDay(for: date)
        if !daySet.contains(cursor), let previous = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = previous
        }
        while true {
            if daySet.contains(cursor) {
                streak += 1
            } else if let schedule = activeSchedule,
                      cursor >= calendar.startOfDay(for: schedule.startDate),
                      schedule.daysOfWeek.contains((calendar.component(.weekday, from: cursor) + 5) % 7 + 1) {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        let adherence: Double?
        if let schedule = activeSchedule {
            let scheduledDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
                .filter { schedule.daysOfWeek.contains((calendar.component(.weekday, from: $0) + 5) % 7 + 1) && $0 <= date }
            let completed = scheduledDays.filter { daySet.contains(calendar.startOfDay(for: $0)) }.count
            adherence = scheduledDays.isEmpty ? nil : Double(completed) / Double(scheduledDays.count)
        } else {
            adherence = nil
        }
        return (sessionsThisWeek, totalSeconds, streak, adherence)
    }
}

// MARK: - TimeMasterCore → App Model Conversion

extension WorkoutType {
    init(core: TimeMasterCore.WorkoutType) {
        self.id = core.id
        self.name = core.name
        self.iconName = core.iconName
        self.colorHex = core.colorHex
    }

    var core: TimeMasterCore.WorkoutType {
        TimeMasterCore.WorkoutType(
            id: id,
            name: name,
            iconName: iconName,
            colorHex: colorHex
        )
    }
}

extension WorkoutManifest {
    func toAppWorkout() -> Workout {
        Workout(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            type: WorkoutType(core: type),
            sections: sections.map { $0.toAppSection() },
            createdAt: createdAt,
            prepareTime: prepareTime,
            restBetweenSections: restBetweenSections,
            colorHex: colorHex,
            imageFilename: imageFilename,
            coverStyle: WorkoutCoverStyle(rawValue: coverStyle.rawValue) ?? .exerciseThumbnails,
            musicTrackFilenames: musicTrackFilenames
        )
    }
}

extension WorkoutSectionManifest {
    func toAppSection() -> Section {
        Section(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            alias: alias,
            duration: duration,
            isTimerEnabled: isTimerEnabled,
            mediaItems: mediaFilenames.map { MediaItem(filename: $0, type: .photo) },
            sets: sets,
            repCount: repCount,
            restBetweenSets: restBetweenSets,
            customRestAfter: customRestAfter,
            prepareTime: prepareTime,
            pageID: UUID(uuidString: exerciseID),
            mode: mode == .bundle ? .bundle : .timed,
            slots: slots.map { $0.toAppSlot() },
            bigRestRow: bigRestRow.map { $0.toAppRestRow() }
        )
    }
}

extension WorkoutRestRowManifest {
    func toAppRestRow() -> RestRow {
        RestRow(
            id: UUID(uuidString: id) ?? UUID(),
            kind: kind == .big ? .big : .normal,
            duration: duration,
            contents: contents.map { $0.toAppRestContent() }
        )
    }
}

extension WorkoutRestContentManifest {
    func toAppRestContent() -> RestContent {
        RestContent(
            id: UUID(uuidString: id) ?? UUID(),
            kind: kind == .stretch ? .stretch : .note,
            pageID: UUID(uuidString: pageID ?? ""),
            text: text
        )
    }
}

extension WorkoutDropSetManifest {
    func toAppDropSet() -> DropSet {
        DropSet(
            id: UUID(uuidString: id) ?? UUID(),
            exercisePageID: UUID(uuidString: exerciseID),
            name: name,
            alias: alias,
            duration: duration,
            restAfter: restAfter
        )
    }
}

extension WorkoutSetSlotManifest {
    func toAppSlot() -> SetSlot {
        SetSlot(
            id: UUID(uuidString: id) ?? UUID(),
            exercisePageID: UUID(uuidString: exerciseID),
            nestedWorkoutID: UUID(uuidString: nestedWorkoutID ?? ""),
            name: name,
            alias: alias,
            duration: duration,
            repCount: repCount,
            restAfter: restAfter,
            prepareTime: prepareTime,
            restExercisePageID: UUID(uuidString: restExerciseID ?? ""),
            drops: drops.map { $0.toAppDropSet() },
            children: children.map { $0.toAppSlot() },
            restRow: restRow.map { $0.toAppRestRow() }
        )
    }
}

extension Workout {
    var coreManifest: WorkoutManifest {
        WorkoutManifest(
            id: id.uuidString,
            name: name,
            type: type.core,
            sections: sections.map(\.coreManifest),
            musicTrackFilenames: musicTrackFilenames,
            colorHex: colorHex,
            createdAt: createdAt,
            prepareTime: prepareTime,
            restBetweenSections: restBetweenSections,
            imageFilename: imageFilename,
            coverStyle: TimeMasterCore.WorkoutCoverStyle(rawValue: coverStyle.rawValue) ?? .exerciseThumbnails
        )
    }
}
extension Section {
    var coreManifest: WorkoutSectionManifest {
        WorkoutSectionManifest(
            id: id.uuidString,
            exerciseID: pageID?.uuidString ?? "",
            name: name,
            alias: alias,
            duration: duration,
            sets: sets,
            repCount: repCount,
            restBetweenSets: restBetweenSets,
            prepareTime: prepareTime,
            customRestAfter: customRestAfter,
            isTimerEnabled: isTimerEnabled,
            mediaFilenames: mediaItems.map(\.filename),
            mode: mode == .bundle ? .bundle : .timed,
            slots: slots.map(\.coreManifest),
            bigRestRow: bigRestRow?.coreManifest
        )
    }
}

extension RestRow {
    var coreManifest: WorkoutRestRowManifest {
        WorkoutRestRowManifest(
            id: id.uuidString,
            kind: kind == .big ? .big : .normal,
            duration: duration,
            contents: contents.map(\.coreManifest)
        )
    }
}

extension RestContent {
    var coreManifest: WorkoutRestContentManifest {
        WorkoutRestContentManifest(
            id: id.uuidString,
            kind: kind == .stretch ? .stretch : .note,
            pageID: pageID?.uuidString,
            text: text
        )
    }
}

extension DropSet {
    var coreManifest: WorkoutDropSetManifest {
        WorkoutDropSetManifest(
            id: id.uuidString,
            exerciseID: exercisePageID?.uuidString ?? "",
            name: name,
            alias: alias,
            duration: duration,
            restAfter: restAfter
        )
    }
}

extension SetSlot {
    var coreManifest: WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(
            id: id.uuidString,
            exerciseID: exercisePageID?.uuidString ?? "",
            name: name,
            nestedWorkoutID: nestedWorkoutID?.uuidString,
            alias: alias,
            duration: duration,
            repCount: repCount,
            restAfter: restAfter,
            prepareTime: prepareTime,
            restExerciseID: restExercisePageID?.uuidString,
            drops: drops.map(\.coreManifest),
            children: children.map(\.coreManifest),
            restRow: restRow?.coreManifest
        )
    }
}

extension HistoryEntry {
    func toAppHistoryEntry() -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(
            id: UUID(uuidString: id) ?? UUID(),
            workoutId: UUID(uuidString: workoutId) ?? UUID(),
            workoutName: workoutName,
            completedAt: completedAt,
            durationCompleted: durationCompleted,
            workoutType: WorkoutType(core: workoutType),
            isPartial: isPartial,
            elapsedSeconds: elapsedSeconds
        )
    }
}
