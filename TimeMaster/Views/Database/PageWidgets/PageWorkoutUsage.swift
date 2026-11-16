import Foundation

/// The saved workouts that train a page: those with a section, a set, a drop or a rest stretch pointing at the page (for
/// a folder, a skill or a tutorial: at it or at any page inside it), directly or through a workout nested in them. Most
/// recently trained first, then by name, each with the last time it was finished.
struct PageWorkoutUsage {
    struct Entry: Identifiable {
        let workout: Workout
        /// The last time it was finished, partly finished sessions included; nil when never.
        let lastTrained: Date?

        var id: UUID { workout.id }
    }

    let entries: [Entry]

    var isEmpty: Bool { entries.isEmpty }

    /// The last time any of them was finished.
    var lastTrained: Date? { entries.compactMap(\.lastTrained).max() }

    /// The workouts that train `page` and, for a page that holds others, the pages inside it.
    static func of(_ page: ExercisePage, library: SkillLibrary, workoutStore: WorkoutStore) -> PageWorkoutUsage {
        var pageIDs: Set<UUID> = [page.id]
        if page.isContainer { pageIDs.formUnion(library.pages(below: page).map(\.id)) }
        return resolve(pageIDs: pageIDs, workouts: workoutStore.workouts, history: workoutStore.historyEntries)
    }

    static func resolve(pageIDs: Set<UUID>, workouts: [Workout], history: [WorkoutHistoryEntry]) -> PageWorkoutUsage {
        var scanner = PageWorkoutScanner(pageIDs: pageIDs, workouts: workouts)
        let using = workouts.filter { scanner.uses($0) }
        guard !using.isEmpty else { return PageWorkoutUsage(entries: []) }
        let usingIDs = Set(using.map(\.id))
        var last: [UUID: Date] = [:]
        for entry in history where usingIDs.contains(entry.workoutId) {
            if let known = last[entry.workoutId], known >= entry.completedAt { continue }
            last[entry.workoutId] = entry.completedAt
        }
        let entries = using
            .map { Entry(workout: $0, lastTrained: last[$0.id]) }
            .sorted { first, second in
                switch (first.lastTrained, second.lastTrained) {
                case let (one?, other?) where one != other: return one > other
                case (.some, nil): return true
                case (nil, .some): return false
                default: return first.workout.name.localizedStandardCompare(second.workout.name) == .orderedAscending
                }
            }
        return PageWorkoutUsage(entries: entries)
    }
}

/// Finds whether a workout points at any of a set of pages, looking into the workouts nested in it. A loop of nested
/// workouts ends where it started; what is found is remembered per workout.
private struct PageWorkoutScanner {
    let pageIDs: Set<UUID>
    private let workouts: [UUID: Workout]
    private var known: [UUID: Bool] = [:]

    init(pageIDs: Set<UUID>, workouts: [Workout]) {
        self.pageIDs = pageIDs
        self.workouts = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    mutating func uses(_ workout: Workout) -> Bool {
        uses(workout, path: [])
    }

    /// `path`: the workouts this one is nested in, which are not looked into again. A "no" found while some were
    /// skipped is not remembered, since a skipped one may still lead to the page.
    private mutating func uses(_ workout: Workout, path: Set<UUID>) -> Bool {
        if let answer = known[workout.id] { return answer }
        let inner = path.union([workout.id])
        var found = false
        for section in workout.sections where !found {
            found = uses(section, path: inner)
        }
        if found || path.isEmpty { known[workout.id] = found }
        return found
    }

    private mutating func uses(_ section: Section, path: Set<UUID>) -> Bool {
        if points(at: section.pageID) { return true }
        if let rest = section.bigRestRow, uses(rest) { return true }
        for slot in section.slots where uses(slot, path: path) {
            return true
        }
        return false
    }

    private mutating func uses(_ slot: SetSlot, path: Set<UUID>) -> Bool {
        if points(at: slot.exercisePageID) || points(at: slot.restExercisePageID) { return true }
        if slot.drops.contains(where: { points(at: $0.exercisePageID) }) { return true }
        if let rest = slot.restRow, uses(rest) { return true }
        if let nestedID = slot.nestedWorkoutID, !path.contains(nestedID), let nested = workouts[nestedID],
           uses(nested, path: path) {
            return true
        }
        for child in slot.children where uses(child, path: path) {
            return true
        }
        return false
    }

    private func uses(_ rest: RestRow) -> Bool {
        rest.contents.contains { points(at: $0.pageID) }
    }

    private func points(at pageID: UUID?) -> Bool {
        guard let pageID else { return false }
        return pageIDs.contains(pageID)
    }
}
