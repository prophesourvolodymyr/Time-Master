import Foundation
import Combine

class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var historyEntries: [WorkoutHistoryEntry] = []

    private let workoutsKey = "workouts"
    private let historyKey = "workout_history"
    private let userDefaults = UserDefaults.standard

    init() {
        loadWorkouts()
        loadHistory()
    }

    func addWorkout(name: String, type: WorkoutType = .strength) {
        let workout = Workout(name: name, type: type)
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
    }

    func clearHistory() {
        historyEntries.removeAll()
        saveHistory()
    }

    private func saveWorkouts() {
        if let data = try? JSONEncoder().encode(workouts) {
            userDefaults.set(data, forKey: workoutsKey)
        }
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
}
