import Foundation
import Combine

@MainActor
final class HomeWidgetStore: ObservableObject {
    @Published private(set) var widgets: [HomeWidgetInstance]
    @Published private(set) var skippedScheduledInstanceIDs: Set<String>

    private let layoutKey = "home_widget_layout_v1"
    private let skippedScheduleKey = "home_skipped_schedule_instances_v1"
    private let greetingStripMigrationKey = "home_greeting_strip_migration_v1"
    private let mapOpenerMigrationKey = "home_map_opener_migration_v1"
    private let dayOneMigrationKey = "home_day_one_migration_v1"
    private let activityHeatmapMigrationKey = "home_activity_heatmap_migration_v1"
    private let firstStepsCelebratedKey = "home_first_steps_celebrated_v1"
    private static let launchToken = UUID().uuidString
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedWidgets: [HomeWidgetInstance]
        if let data = defaults.data(forKey: layoutKey),
           let decoded = try? JSONDecoder().decode(HomeWidgetLayout.self, from: data) {
            loadedWidgets = decoded.widgets
        } else {
            loadedWidgets = HomeWidgetCatalog.initialLayout
        }
        let outdoorShortcutWidgets = loadedWidgets.map { widget in
            var widget = widget
            if widget.kind == .activityShortcuts,
               widget.configuration.activityShortcuts.contains(.runWalk),
               !widget.configuration.activityShortcuts.contains(.walk) {
                widget.configuration.activityShortcuts.append(.walk)
            }
            if !widget.kind.supportedFootprints.contains(widget.footprint) {
                widget.footprint = widget.kind.defaultFootprint
            }
            return widget
        }
        let addedWalkShortcut = outdoorShortcutWidgets != loadedWidgets
        let mapOpenerMigrationNeeded = defaults.bool(forKey: mapOpenerMigrationKey) == false
        let mapOpenerWidgets: [HomeWidgetInstance]
        if mapOpenerMigrationNeeded,
           !outdoorShortcutWidgets.contains(where: { $0.kind == .outdoorMap }) {
            var migrated = outdoorShortcutWidgets
            migrated.insert(HomeWidgetInstance(kind: .outdoorMap), at: min(4, migrated.count))
            mapOpenerWidgets = migrated
        } else {
            mapOpenerWidgets = outdoorShortcutWidgets
        }
        let addedMapOpener = mapOpenerWidgets != outdoorShortcutWidgets
        let dayOneMigrationNeeded = defaults.bool(forKey: dayOneMigrationKey) == false
        var dayOneWidgets = mapOpenerWidgets
        if dayOneMigrationNeeded {
            var index = dayOneWidgets.firstIndex(where: { $0.kind == .quickStart }).map { $0 + 1 } ?? min(2, dayOneWidgets.count)
            for kind in [HomeWidgetKind.firstSteps, .weekAhead] where !dayOneWidgets.contains(where: { $0.kind == kind }) {
                dayOneWidgets.insert(HomeWidgetInstance(kind: kind), at: min(index, dayOneWidgets.count))
                index += 1
            }
        }
        let addedDayOne = dayOneWidgets != mapOpenerWidgets
        let heatmapMigrationNeeded = defaults.bool(forKey: activityHeatmapMigrationKey) == false
        var heatmapWidgets = dayOneWidgets
        if heatmapMigrationNeeded, !heatmapWidgets.contains(where: { $0.kind == .activityHeatmap }) {
            let index = heatmapWidgets.firstIndex(where: { $0.kind == .metrics }).map { $0 + 1 } ?? min(5, heatmapWidgets.count)
            heatmapWidgets.insert(HomeWidgetInstance(kind: .activityHeatmap), at: min(index, heatmapWidgets.count))
        }
        let addedHeatmap = heatmapWidgets != dayOneWidgets
        let needsGreetingStripMigration = defaults.bool(forKey: greetingStripMigrationKey) == false
        widgets = needsGreetingStripMigration
            ? heatmapWidgets.map { widget in
                var widget = widget
                if widget.kind == .greeting {
                    widget.footprint = .wide
                }
                return widget
            }
            : heatmapWidgets

        if let data = defaults.data(forKey: skippedScheduleKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            skippedScheduledInstanceIDs = decoded
        } else {
            skippedScheduledInstanceIDs = []
        }

        if dayOneMigrationNeeded {
            defaults.set(true, forKey: dayOneMigrationKey)
        }
        if heatmapMigrationNeeded {
            defaults.set(true, forKey: activityHeatmapMigrationKey)
        }
        if needsGreetingStripMigration || addedWalkShortcut || addedMapOpener || addedDayOne || addedHeatmap {
            defaults.set(true, forKey: greetingStripMigrationKey)
            defaults.set(true, forKey: mapOpenerMigrationKey)
            save()
        }
    }

    var availableKinds: [HomeWidgetKind] {
        HomeWidgetKind.catalog.filter { kind in
            kind != .savedRoutes || !HomeWidgetPlatform.isUnavailable(.savedRoutes)
        }
    }

    @discardableResult
    func add(
        _ kind: HomeWidgetKind,
        footprint: HomeWidgetFootprint? = nil,
        configuration: HomeWidgetConfiguration? = nil
    ) -> UUID? {
        guard canAdd(kind) else { return nil }
        if kind == .firstSteps { defaults.removeObject(forKey: firstStepsCelebratedKey) }
        let size = footprint.flatMap { kind.supportedFootprints.contains($0) ? $0 : nil }
        let widget = HomeWidgetInstance(kind: kind, footprint: size, configuration: configuration)
        widgets.insert(widget, at: 0)
        save()
        return widget.id
    }

    func remove(id: UUID) {
        widgets.removeAll { $0.id == id }
        save()
    }

    func settleFirstSteps(isComplete: Bool) {
        guard widgets.contains(where: { $0.kind == .firstSteps }) else { return }
        guard isComplete else {
            defaults.removeObject(forKey: firstStepsCelebratedKey)
            return
        }
        guard let celebrated = defaults.string(forKey: firstStepsCelebratedKey) else {
            defaults.set(Self.launchToken, forKey: firstStepsCelebratedKey)
            return
        }
        guard celebrated != Self.launchToken else { return }
        defaults.removeObject(forKey: firstStepsCelebratedKey)
        widgets.removeAll { $0.kind == .firstSteps }
        save()
    }

    func move(id: UUID, toIndex destination: Int) {
        guard let source = widgets.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(destination, 0), widgets.count - 1)
        guard source != target else { return }
        var reordered = widgets
        reordered.insert(reordered.remove(at: source), at: target)
        widgets = reordered
        save()
    }


    func updateConfiguration(_ configuration: HomeWidgetConfiguration, for id: UUID) {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        widgets[index].configuration = configuration
        save()
    }

    func updateFootprint(_ footprint: HomeWidgetFootprint, for id: UUID) {
        guard let index = widgets.firstIndex(where: { $0.id == id }),
              widgets[index].kind.supportedFootprints.contains(footprint),
              widgets[index].footprint != footprint else { return }
        widgets[index].footprint = footprint
        save()
    }

    func skipScheduledInstance(id: String) {
        skippedScheduledInstanceIDs.insert(id)
        guard let data = try? JSONEncoder().encode(skippedScheduledInstanceIDs) else { return }
        defaults.set(data, forKey: skippedScheduleKey)
    }

    func restoreScheduledInstance(id: String) {
        skippedScheduledInstanceIDs.remove(id)
        guard let data = try? JSONEncoder().encode(skippedScheduledInstanceIDs) else { return }
        defaults.set(data, forKey: skippedScheduleKey)
    }

    func resetLayout() {
        widgets = HomeWidgetCatalog.initialLayout
        save()
    }

    func canAdd(_ kind: HomeWidgetKind) -> Bool {
        guard HomeWidgetPlatform.isUnavailable(kind) == false else { return false }
        guard kind.allowsDuplicates == false else { return true }
        return widgets.contains(where: { $0.kind == kind }) == false
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(widgets) else { return }
        defaults.set(data, forKey: layoutKey)
    }
}

enum HomeWidgetPlatform {
    static func isUnavailable(_ kind: HomeWidgetKind) -> Bool {
        #if os(iOS)
        switch kind {
        case .savedRoutes: false
        default: false
        }
        #else
        switch kind {
        case .recoverActivity, .savedRoutes: false
        default: false
        }
        #endif
    }
}

private extension HomeWidgetKind {
    var allowsDuplicates: Bool {
        switch self {
        case .metrics, .weeklyRhythm, .activityHeatmap, .recentWorkouts, .selectedWorkout, .typeBreakdown, .outdoorSummary:
            true
        default:
            false
        }
    }
}
