import Foundation
import Combine
import SwiftUI
import WidgetKit

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

    init() {
        loadWorkouts()
        loadHistory()
        loadRestDays()
        loadSchedules()
        loadCustomTypes()
        loadGoal()
        if workouts.isEmpty {
            seedDefaultWorkouts()   // saveWorkouts() is called inside seed
        } else {
            saveWorkouts()          // push existing workouts to App Group on every launch
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

    func addWorkout(name: String, type: WorkoutType = .strength, colorHex: String = "FFFFFF") {
        let workout = Workout(name: name, type: type, colorHex: colorHex)
        workouts.append(workout)
        saveWorkouts()
    }

    func deleteWorkout(_ workout: Workout) {
        for section in workout.sections {
            for item in section.mediaItems {
                PhotoManager.shared.deleteMedia(filename: item.filename)
            }
        }
        workouts.removeAll { $0.id == workout.id }
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
    }

    func clearHistory() {
        historyEntries.removeAll()
        saveHistory()
    }

    func deleteHistoryEntries(at offsets: IndexSet) {
        historyEntries.remove(atOffsets: offsets)
        saveHistory()
    }

    /// Re-reads both workouts and history from UserDefaults.
    /// Call after a backup import to refresh in-memory state.
    func reload() {
        loadWorkouts()
        loadHistory()
        saveWorkouts()   // sync App Group so widget reflects imported data
    }

    private func saveWorkouts() {
        if let data = try? JSONEncoder().encode(workouts) {
            userDefaults.set(data, forKey: workoutsKey)
        }
        // Sync compact list to App Group for widget
        let sharedDefaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        let compact = workouts.map { WidgetWorkoutRef(id: $0.id.uuidString, name: $0.name, colorHex: $0.colorHex, type: $0.type.name) }
        if let data = try? JSONEncoder().encode(compact) {
            sharedDefaults?.set(data, forKey: "widget_workouts")
            // synchronize() is required in cross-process scenarios (app ↔ widget extension)
            // to guarantee the write is flushed to disk before WidgetKit reads it.
            sharedDefaults?.synchronize()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Compact model mirrored by the widget extension
    private struct WidgetWorkoutRef: Codable {
        var id: String
        var name: String
        var colorHex: String
        var type: String
    }

    private func loadWorkouts() {
        guard let data = userDefaults.data(forKey: workoutsKey),
              let workouts = try? JSONDecoder().decode([Workout].self, from: data) else { return }
        self.workouts = workouts
    }

    private func saveHistory() {
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
    }

    func isRestDay(_ date: Date) -> Bool {
        restDays.contains(dateKey(from: date))
    }

    func isScheduledDay(_ date: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let monBased = (weekday + 5) % 7 + 1
        let dayStart = cal.startOfDay(for: date)
        for schedule in typeSchedules where schedule.isActive {
            if schedule.daysOfWeek.contains(monBased),
               dayStart >= cal.startOfDay(for: schedule.startDate) {
                return true
            }
        }
        return false
    }

    func scheduledTypes(for date: Date) -> [WorkoutType] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let monBased = (weekday + 5) % 7 + 1
        let dayStart = cal.startOfDay(for: date)
        return typeSchedules
            .filter { $0.isActive && $0.daysOfWeek.contains(monBased) && dayStart >= cal.startOfDay(for: $0.startDate) }
            .map { $0.type }
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
        typeSchedules.append(schedule)
        saveSchedules()
    }

    func updateSchedule(_ schedule: TypeSchedule) {
        if let idx = typeSchedules.firstIndex(where: { $0.id == schedule.id }) {
            typeSchedules[idx] = schedule
            saveSchedules()
        }
    }

    func deleteSchedule(id: UUID) {
        typeSchedules.removeAll { $0.id == id }
        saveSchedules()
    }

    private func loadSchedules() {
        if let data = userDefaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([TypeSchedule].self, from: data) {
            typeSchedules = decoded
        }
    }

    private func saveSchedules() {
        if let data = try? JSONEncoder().encode(typeSchedules) {
            userDefaults.set(data, forKey: schedulesKey)
        }
    }

    private let customTypesKey = "custom_workout_types"

    func addCustomType(name: String, iconName: String) {
        let id = name
        let type = WorkoutType(id: id, name: name, iconName: iconName)
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
        if let data = try? JSONEncoder().encode(customWorkoutTypes) {
            userDefaults.set(data, forKey: customTypesKey)
        }
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
}
