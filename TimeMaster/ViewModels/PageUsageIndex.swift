import Foundation

/// How much the saved workouts use each page, for the "Most used" sorts. A workout uses a page when one of its
/// sections, sets, drops or rest stretches points at it, directly or through a workout nested in it (what
/// `PageWorkoutUsage` lists on a page); a page holding others is also used by what uses any page inside it. A page's
/// score is the number of workouts using it, each counted once, plus the finished sessions of those workouts. Built in
/// one pass over the workouts.
struct PageUsageIndex {
    static let empty = PageUsageIndex(scores: [:])

    private let scores: [UUID: Int]

    private init(scores: [UUID: Int]) {
        self.scores = scores
    }

    /// `parentByID`: the parent of each page, so a use also counts for every page above the one used.
    init(workouts: [Workout], history: [WorkoutHistoryEntry], parentByID: [UUID: UUID]) {
        self.init(scores: Self.computeScores(workouts: workouts, history: history, parentByID: parentByID))
    }

    func score(of pageID: UUID) -> Int {
        scores[pageID] ?? 0
    }

    /// Most used first; equal scores (pages never used among them) by title.
    func ranks(_ lhs: ExercisePage, before rhs: ExercisePage) -> Bool {
        let left = score(of: lhs.id)
        let right = score(of: rhs.id)
        if left != right { return left > right }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    // MARK: Building

    /// The pages one workout points at itself and the workouts nested in it.
    private struct References {
        var pages: Set<UUID> = []
        var nested: Set<UUID> = []
    }

    private static func computeScores(workouts: [Workout], history: [WorkoutHistoryEntry], parentByID: [UUID: UUID]) -> [UUID: Int] {
        var sessions: [UUID: Int] = [:]
        for entry in history where !entry.isPartial {
            sessions[entry.workoutId, default: 0] += 1
        }
        var byID: [UUID: Workout] = [:]
        for workout in workouts where byID[workout.id] == nil {
            byID[workout.id] = workout
        }
        var known: [UUID: References] = [:]
        func lookUp(_ id: UUID) -> References {
            if let found = known[id] { return found }
            let found = byID[id].map(Self.references(in:)) ?? References()
            known[id] = found
            return found
        }

        var scores: [UUID: Int] = [:]
        var counted: Set<UUID> = []
        for workout in workouts where counted.insert(workout.id).inserted {
            var pages: Set<UUID> = []
            var reached: Set<UUID> = [workout.id]
            var pending = [workout.id]
            while let id = pending.popLast() {
                let found = lookUp(id)
                pages.formUnion(found.pages)
                for nested in found.nested where reached.insert(nested).inserted {
                    pending.append(nested)
                }
            }
            guard !pages.isEmpty else { continue }
            var covered: Set<UUID> = []
            for page in pages {
                var current: UUID? = page
                while let id = current, covered.insert(id).inserted {
                    current = parentByID[id]
                }
            }
            let weight = 1 + (sessions[workout.id] ?? 0)
            for id in covered {
                scores[id, default: 0] += weight
            }
        }
        return scores
    }

    private static func references(in workout: Workout) -> References {
        var references = References()
        func add(_ id: UUID?) {
            if let id { references.pages.insert(id) }
        }
        func addRest(_ rest: RestRow?) {
            add(rest?.exercisePageID)
            for content in rest?.contents ?? [] { add(content.pageID) }
        }
        func addSlot(_ slot: SetSlot) {
            add(slot.exercisePageID)
            add(slot.restExercisePageID)
            for drop in slot.drops { add(drop.exercisePageID) }
            addRest(slot.restRow)
            if let nested = slot.nestedWorkoutID { references.nested.insert(nested) }
            for child in slot.children { addSlot(child) }
        }
        for section in workout.sections {
            add(section.pageID)
            addRest(section.bigRestRow)
            for slot in section.slots { addSlot(slot) }
        }
        return references
    }
}

/// The usage index of the current library, workouts and history, kept until one of them changes. Main thread only.
private final class PageUsageIndexCache {
    static let shared = PageUsageIndexCache()

    private struct Key: Equatable {
        let library: ObjectIdentifier
        let workouts: ObjectIdentifier
        let libraryRevision: Int
        let workoutsRevision: Int
        let historyRevision: Int
    }

    private var key: Key?
    private var cached = PageUsageIndex.empty

    func index(library: DatabaseStore, workouts: WorkoutStore) -> PageUsageIndex {
        let current = Key(
            library: ObjectIdentifier(library),
            workouts: ObjectIdentifier(workouts),
            libraryRevision: library.libraryRevision,
            workoutsRevision: workouts.workoutsRevision,
            historyRevision: workouts.historyRevision
        )
        if current != key {
            cached = PageUsageIndex(
                workouts: workouts.workouts,
                history: workouts.historyEntries,
                parentByID: library.index.parentByID
            )
            key = current
        }
        return cached
    }
}

extension DatabaseStore {
    /// How much the saved workouts use each page (`PageUsageIndex`), built once per change of the library, the
    /// workouts or the history.
    func pageUsage(_ workoutStore: WorkoutStore) -> PageUsageIndex {
        PageUsageIndexCache.shared.index(library: self, workouts: workoutStore)
    }
}
