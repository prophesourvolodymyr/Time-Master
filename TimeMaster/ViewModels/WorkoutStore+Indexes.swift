import Foundation

/// Lookups and change counters derived from the store's lists, cleared whenever a list changes. Main thread only.
final class WorkoutDerivedCache {
    private(set) var workoutsRevision = 0
    private(set) var historyRevision = 0
    private var workoutsByID: [UUID: Workout]?

    func workoutsDidChange() {
        workoutsRevision &+= 1
        workoutsByID = nil
    }

    /// The first workout with this id in `workouts`, as a linear search would find it.
    func workout(id: UUID, in workouts: [Workout]) -> Workout? {
        if workoutsByID == nil {
            workoutsByID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        return workoutsByID?[id]
    }

    func historyDidChange() {
        historyRevision &+= 1
    }
}

extension WorkoutStore {
    /// Bumps whenever `workouts` changes.
    var workoutsRevision: Int { derived.workoutsRevision }

    /// Bumps whenever `historyEntries` changes.
    var historyRevision: Int { derived.historyRevision }
}
