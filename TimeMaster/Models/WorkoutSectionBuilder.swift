import Foundation
import TimeMasterCore

struct WorkoutSectionImportConfiguration {
    var duration: Int
    var sets: Int
    var repCount: Int?
    var restAfter: Int
    var restBetweenSets: Int
    var prepareTime: Int

    init(
        duration: Int,
        sets: Int,
        repCount: Int?,
        restAfter: Int,
        restBetweenSets: Int,
        prepareTime: Int
    ) {
        self.duration = max(5, duration)
        self.sets = max(1, sets)
        self.repCount = repCount.map { max(1, $0) }
        self.restAfter = max(0, restAfter)
        self.restBetweenSets = max(0, restBetweenSets)
        self.prepareTime = min(30, max(0, prepareTime))
    }
}

enum WorkoutBundleSource: Identifiable {
    case page(ExercisePage)
    case workout(Workout)

    var id: String {
        switch self {
        case .page(let page):
            return "page:\(page.manifest.id)"
        case .workout(let workout):
            return "workout:\(workout.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .page(let page):
            return page.title
        case .workout(let workout):
            return workout.name
        }
    }

    var pageID: UUID? {
        if case .page(let page) = self {
            return page.id
        }
        return nil
    }
}

enum WorkoutSectionBuilder {
    static func defaultPrepareTime(for page: ExercisePage) -> Int {
        min(30, max(0, page.manifest.prepareTime ?? 4))
    }

    static func makeSection(
        page: ExercisePage,
        configuration: WorkoutSectionImportConfiguration
    ) -> Section? {
        guard page.isLeaf else { return nil }

        return Section(
            name: page.title,
            duration: configuration.duration,
            sets: configuration.sets,
            repCount: configuration.repCount,
            restBetweenSets: configuration.restBetweenSets,
            customRestAfter: configuration.restAfter,
            prepareTime: configuration.prepareTime,
            pageID: page.id,
            mode: .timed,
            slots: makeSlots(
                page: page,
                duration: configuration.duration,
                sets: configuration.sets,
                repCount: configuration.repCount,
                restBetweenSets: configuration.restBetweenSets
            )
        )
    }

    static func makeBundle(
        pages: [ExercisePage],
        configuration: WorkoutSectionImportConfiguration
    ) -> Section? {
        makeBundle(
            sources: pages.filter(\.isLeaf).map { .page($0) },
            configuration: configuration
        )
    }

    static func makeBundle(
        sources: [WorkoutBundleSource],
        configuration: WorkoutSectionImportConfiguration
    ) -> Section? {
        guard !sources.isEmpty else { return nil }

        let slots = sources.enumerated().compactMap { index, source -> SetSlot? in
            let restAfter = index < sources.count - 1 ? configuration.restBetweenSets : 0
            switch source {
            case .page(let page):
                guard page.isLeaf else { return nil }
                return makeSlot(
                    page: page,
                    duration: page.manifest.duration ?? configuration.duration,
                    repCount: page.manifest.sets == nil ? nil : configuration.repCount,
                    slotRestAfter: restAfter,
                    setIndex: 0
                )
            case .workout(let workout):
                return SetSlot(
                    nestedWorkoutID: workout.id,
                    name: workout.name,
                    duration: max(5, workout.totalDuration),
                    restAfter: restAfter
                )
            }
        }
        guard !slots.isEmpty else { return nil }

        let names = sources.map(\.title).joined(separator: ", ")
        return Section(
            name: "Bundle: \(names)",
            duration: configuration.duration,
            sets: slots.count,
            repCount: configuration.repCount,
            restBetweenSets: configuration.restBetweenSets,
            customRestAfter: configuration.restAfter,
            prepareTime: configuration.prepareTime,
            pageID: sources.first?.pageID,
            mode: .bundle,
            slots: slots
        )
    }

    static func makeSlots(
        page: ExercisePage,
        duration: Int,
        sets: Int,
        repCount: Int?,
        restBetweenSets: Int
    ) -> [SetSlot] {
        let slotCount = max(1, sets)
        return (0..<slotCount).map { index in
            makeSlot(
                page: page,
                duration: duration,
                repCount: repCount,
                slotRestAfter: index < slotCount - 1 ? restBetweenSets : 0,
                setIndex: index
            )
        }
    }

    static func makeSlot(
        page: ExercisePage,
        duration: Int,
        repCount: Int?,
        slotRestAfter: Int,
        setIndex: Int
    ) -> SetSlot {
        SetSlot(
            exercisePageID: page.id,
            name: page.title,
            duration: duration,
            repCount: repCount,
            restAfter: slotRestAfter,
            drops: page.manifest.dropSetTemplates
                .filter { $0.setIndex == setIndex }
                .map {
                    DropSet(
                        exercisePageID: UUID(uuidString: $0.exerciseID),
                        name: $0.name,
                        duration: $0.duration,
                        restAfter: $0.restAfter
                    )
                }
        )
    }
}
