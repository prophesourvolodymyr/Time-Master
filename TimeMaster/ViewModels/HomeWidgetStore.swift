import Foundation
import Combine

@MainActor
final class HomeWidgetStore: ObservableObject {
    @Published private(set) var widgets: [HomeWidgetInstance]

    private let layoutKey = "home_widget_layout_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: layoutKey),
           let decoded = try? JSONDecoder().decode([HomeWidgetInstance].self, from: data) {
            widgets = decoded
        } else {
            widgets = HomeWidgetCatalog.initialLayout
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

    func move(id: UUID, to destination: Int) {
        guard let source = widgets.firstIndex(where: { $0.id == id }) else { return }
        let clampedDestination = min(max(destination, 0), widgets.count - 1)
        guard source != clampedDestination else { return }
        let item = widgets.remove(at: source)
        widgets.insert(item, at: clampedDestination)
        save()
    }

    func move(id: UUID, before targetID: UUID) {
        guard let source = widgets.firstIndex(where: { $0.id == id }),
              let target = widgets.firstIndex(where: { $0.id == targetID }) else { return }
        let item = widgets.remove(at: source)
        let adjustedTarget = source < target ? target - 1 : target
        widgets.insert(item, at: min(max(adjustedTarget, 0), widgets.count))
        save()
    }

    func resize(id: UUID, to footprint: HomeWidgetFootprint) {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        guard widgets[index].kind.supportedFootprints.contains(footprint) else { return }
        widgets[index].footprint = footprint
        save()
    }

    func updateConfiguration(_ configuration: HomeWidgetConfiguration, for id: UUID) {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        widgets[index].configuration = configuration
        save()
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
