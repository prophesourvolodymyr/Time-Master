import Foundation
import TimeMasterCore

extension WorkoutStore {
    func loadWeeklySchedule() {
        do {
            weeklySchedule = try DatabaseManager.shared.loadConfig().workoutSchedule ?? WeeklyWorkoutSchedule()
            scheduleIsLoaded = true
            scheduleError = nil
            refreshWidgetData()
        } catch {
            scheduleIsLoaded = false
            scheduleError = "Your schedule could not be loaded. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func changeWeeklySchedule(_ change: (inout WeeklyWorkoutSchedule) -> Void) -> Bool {
        guard scheduleIsLoaded else {
            scheduleError = "Load your saved schedule before making changes."
            return false
        }
        var updated = weeklySchedule
        change(&updated)
        do {
            let database = DatabaseManager.shared
            var config = try database.loadConfig()
            config.workoutSchedule = updated
            try database.saveConfig(config)
            weeklySchedule = updated
            scheduleError = nil
            refreshWidgetData()
            return true
        } catch {
            scheduleError = "Your changes were not saved. \(error.localizedDescription)"
            return false
        }
    }

    func scheduleOccurrences(on date: Date) -> [WeeklyWorkoutSchedule.Occurrence] {
        weeklySchedule.occurrences(on: date, activity: scheduleActivity)
    }

    func scheduleActivityCount(on date: Date) -> Int {
        weeklySchedule.activityCount(on: date, activity: scheduleActivity)
            + historyEntries.filter { $0.isPartial && Calendar.current.isDate($0.completedAt, inSameDayAs: date) }.count
    }

    @discardableResult
    func saveScheduleEntry(_ entry: WeeklyWorkoutSchedule.Entry, on date: Date, repeats: Bool, completed: Bool = false) -> Bool {
        changeWeeklySchedule { schedule in
            if repeats {
                var plan = schedule.selection(for: date)?.plan ?? WeeklyWorkoutSchedule.Plan(name: "My Plan")
                plan.entries.removeAll { $0.id == entry.id }
                plan.entries.append(entry)
                schedule.savePlan(plan)
                schedule.equip(plan, from: date)
            } else {
                schedule.setEntry(entry, on: date)
            }
            if completed { schedule.setComplete(true, entryID: entry.id, on: date) }
        }
    }
}
