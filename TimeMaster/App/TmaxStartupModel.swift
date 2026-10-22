import SwiftUI
import TimeMasterCore

@MainActor
final class TmaxStartupModel: ObservableObject {
    @Published private(set) var completedSteps = 0
    @Published private(set) var statusHistory = ["Preparing your training space…"]
    @Published private(set) var status = "Preparing your training space…" {
        didSet {
            if statusHistory.last != status { statusHistory.append(status) }
        }
    }
    @Published private(set) var workoutStore: WorkoutStore?
    @Published private(set) var databaseStore: DatabaseStore?
    @Published private(set) var isReady = false
    private var isPreparing = false

    func prepare() async {
        guard !isPreparing, !isReady else { return }
        isPreparing = true
        let minimumDisplayDeadline = ContinuousClock.now.advanced(by: .seconds(5))

        status = "Preparing your saved workouts…"
        await Task.detached(priority: .userInitiated) { MigrationManager.migrateIfNeeded() }.value
        completedSteps = 1
        status = "Preparing your exercise library…"
        await Task.detached(priority: .userInitiated) { MigrationManager.migrateToV2PagesIfNeeded() }.value
        completedSteps = 2
        status = "Organizing your exercise pages…"
        await Task.detached(priority: .userInitiated) { MigrationManager.normalizeV2PageKindsIfNeeded() }.value
        completedSteps = 3
        status = "Preparing your training types…"
        await Task.detached(priority: .userInitiated) { MigrationManager.normalizePageTypesIfNeeded() }.value
        completedSteps = 4
        status = "Finishing library preparation…"
        await Task.detached(priority: .userInitiated) { MigrationManager.cleanLegacyPageCacheIfNeeded() }.value
        completedSteps = 5
        status = "Loading workouts and history…"
        workoutStore = await Task.detached(priority: .userInitiated) { WorkoutStore() }.value
        completedSteps = 6
        status = "Loading your exercise library…"
        databaseStore = await Task.detached(priority: .userInitiated) { DatabaseStore.shared }.value
        completedSteps = 7
        status = "Ready"

        do {
            try await Task.sleep(until: minimumDisplayDeadline, clock: .continuous)
        } catch {
            isPreparing = false
            return
        }

        isReady = true
        isPreparing = false
    }
}
