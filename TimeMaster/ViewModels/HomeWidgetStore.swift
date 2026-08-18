import Foundation
import Combine

@MainActor
final class HomeWidgetStore: ObservableObject {
    @Published private(set) var widgets: [HomeWidgetInstance]
    @Published private(set) var skippedScheduledInstanceIDs: Set<String>

    private let layoutKey = "home_widget_layout_v1"
    private let skippedScheduleKey = "home_skipped_schedule_instances_v1"
    private let greetingStripMigrationKey = "home_greeting_strip_migration_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedWidgets: [HomeWidgetInstance]
        if let data = defaults.data(forKey: layoutKey),
           let decoded = try? JSONDecoder().decode([HomeWidgetInstance].self, from: data) {
            loadedWidgets = decoded
        } else {
            loadedWidgets = HomeWidgetCatalog.initialLayout
        }

        let needsGreetingStripMigration = defaults.bool(forKey: greetingStripMigrationKey) == false
        widgets = needsGreetingStripMigration
            ? loadedWidgets.map { widget in
                var widget = widget
                if widget.kind == .greeting {
                    widget.footprint = .wide
                }
                return widget
            }
            : loadedWidgets

        if let data = defaults.data(forKey: skippedScheduleKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            skippedScheduledInstanceIDs = decoded
        } else {
            skippedScheduledInstanceIDs = []
        }

        if needsGreetingStripMigration {
            defaults.set(true, forKey: greetingStripMigrationKey)
            save()
        }
    }

    var availableKinds: [HomeWidgetKind] {
        HomeWidgetKind.catalog.filter { kind in
            kind != .savedRoutes || !HomeWidgetPlatform.isUnavailable(.savedRoutes)
        }
    }

    func add(
        _ kind: HomeWidgetKind,
        footprint: HomeWidgetFootprint? = nil,
        configuration: HomeWidgetConfiguration? = nil
    ) {
        guard canAdd(kind) else { return }
        widgets.append(
            HomeWidgetInstance(
                kind: kind,
                footprint: footprint,
                configuration: configuration
            )
        )
        save()
    }

    func remove(id: UUID) {
        widgets.removeAll { $0.id == id }
        save()
    }

    func move(id: UUID, toInsertionIndex destination: Int) {
        guard let source = widgets.firstIndex(where: { $0.id == id }) else { return }

        let item = widgets.remove(at: source)
        let adjustedDestination = destination > source ? destination - 1 : destination
        let insertionIndex = min(max(adjustedDestination, 0), widgets.count)
        guard insertionIndex != source else {
            widgets.insert(item, at: source)
            return
        }

        widgets.insert(item, at: insertionIndex)
        save()
    }


    func updateConfiguration(_ configuration: HomeWidgetConfiguration, for id: UUID) {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        widgets[index].configuration = configuration
        save()
    }

    func updateFootprint(_ footprint: HomeWidgetFootprint, for id: UUID) {
        guard let index = widgets.firstIndex(where: { $0.id == id }),
              widgets[index].kind.supportedFootprints.contains(footprint) else { return }
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
