import SwiftUI
import Combine
import TimeMasterCore

@MainActor
final class HomeInsightsModel: ObservableObject {
    @Published private(set) var insights: HomeInsights

    private let workouts: WorkoutStore
    private let library: DatabaseStore
    private let outdoor: OutdoorActivityStore
    private var now: Date
    private var digest: HomeLibraryDigest
    private var cancellables: Set<AnyCancellable> = []
    private var key: Key?

    private struct Key: Equatable {
        var history: Int
        var workouts: Int
        var groups: [WorkoutGroup]
        var schedule: WeeklyWorkoutSchedule
        var typeSchedules: [TypeSchedule]
        var trainingDays: Set<Int>
        var restDays: Set<String>
        var goal: Int
        var now: Date
        var calendar: Calendar
        var library: ObjectIdentifier
        var rootExercises: Int
        var activities: [OutdoorActivity]
        var routes: [PlannedRoute]
    }

    init(workouts: WorkoutStore, library: DatabaseStore, outdoor: OutdoorActivityStore, now: Date = Date()) {
        self.workouts = workouts
        self.library = library
        self.outdoor = outdoor
        self.now = now
        let digest = HomeLibraryDigest.make(from: library)
        self.digest = digest
        insights = HomeInsights.make(
            workouts: workouts,
            libraryStore: library,
            digest: digest,
            outdoor: outdoor,
            now: now
        )
        Publishers.MergeMany(
            workouts.objectWillChange.eraseToAnyPublisher(),
            library.objectWillChange.eraseToAnyPublisher(),
            outdoor.objectWillChange.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(60), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in self?.refresh() }
        .store(in: &cancellables)
    }

    func update(now: Date) {
        self.now = now
        refresh()
    }

    private func refresh() {
        if library.skillLibrary.snapshotToken != digest.token {
            digest = HomeLibraryDigest.make(from: library)
        }
        let calendar = Calendar.current
        let key = Key(
            history: workouts.historyRevision,
            workouts: workouts.workoutsRevision,
            groups: workouts.workoutGroups,
            schedule: workouts.weeklySchedule,
            typeSchedules: workouts.typeSchedules,
            trainingDays: workouts.trainingDays,
            restDays: workouts.restDays,
            goal: workouts.weeklyGoal,
            now: now,
            calendar: calendar,
            library: digest.token,
            rootExercises: library.rootExercises.count,
            activities: outdoor.activities,
            routes: outdoor.plannedRoutes
        )
        guard key != self.key else { return }
        self.key = key
        let next = HomeInsights.make(
            workouts: workouts,
            libraryStore: library,
            digest: digest,
            outdoor: outdoor,
            now: now,
            calendar: calendar
        )
        if next != insights { insights = next }
    }
}

struct HomeInsightsHost<Content: View>: View {
    @StateObject private var model: HomeInsightsModel
    @Environment(\.scenePhase) private var scenePhase

    private let now: Date
    private let content: (HomeInsights) -> Content

    init(
        workouts: WorkoutStore,
        library: DatabaseStore,
        outdoor: OutdoorActivityStore,
        now: Date,
        @ViewBuilder content: @escaping (HomeInsights) -> Content
    ) {
        _model = StateObject(wrappedValue: HomeInsightsModel(workouts: workouts, library: library, outdoor: outdoor, now: now))
        self.now = now
        self.content = content
    }

    var body: some View {
        content(model.insights)
            .onChange(of: now) { date in
                model.update(now: date)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { model.update(now: Date()) }
            }
    }
}
