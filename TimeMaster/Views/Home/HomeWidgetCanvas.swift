import SwiftUI
import UniformTypeIdentifiers

struct HomeWidgetCanvas: View {
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    @Binding var isEditing: Bool
    let now: Date
    let skippedScheduledInstanceIDs: Set<String>
    let onStartWorkout: (Workout) -> Void
    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?) -> Void

    @State private var draggedWidgetID: UUID?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(widgetStore.widgets) { widget in
                    tile(for: widget)
                        .gridCellColumns(widget.footprint.columnSpan)
                }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: widgetStore.widgets)
        }
        .overlay {
            if widgetStore.widgets.isEmpty {
                emptyCanvas
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tile(for widget: HomeWidgetInstance) -> some View {
        let content = HomeWidgetTile(
            widget: widget,
            isEditing: isEditing,
            widgetStore: widgetStore,
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore,
            now: now,
            skippedScheduledInstanceIDs: skippedScheduledInstanceIDs,
            onStartWorkout: onStartWorkout,
            onBrowseWorkouts: onBrowseWorkouts,
            onBrowseDatabase: onBrowseDatabase,
            onCreateWorkout: onCreateWorkout,
            onStartOutdoor: onStartOutdoor,
        )

        if isEditing {
            content
                .onDrag {
                    draggedWidgetID = widget.id
                    return NSItemProvider(object: NSString(string: widget.id.uuidString))
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: HomeWidgetDropDelegate(
                        targetID: widget.id,
                        draggedID: $draggedWidgetID,
                        widgetStore: widgetStore
                    )
                )
        } else {
            content
        }
    }

    private var emptyCanvas: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Your Home is ready to shape")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Add a widget to build your daily brief.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct HomeWidgetTile: View {
    let widget: HomeWidgetInstance
    let isEditing: Bool
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    let now: Date
    let skippedScheduledInstanceIDs: Set<String>
    let onStartWorkout: (Workout) -> Void
    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?) -> Void

    var body: some View {
        HomeWidgetContent(
            widget: widget,
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore,
            now: now,
            skippedScheduledInstanceIDs: skippedScheduledInstanceIDs,
            onStartWorkout: onStartWorkout,
            onBrowseWorkouts: onBrowseWorkouts,
            onBrowseDatabase: onBrowseDatabase,
            onCreateWorkout: onCreateWorkout,
            onStartOutdoor: onStartOutdoor,
            onSkipScheduledWorkout: { scheduled in
                widgetStore.skipScheduledInstance(id: scheduled.id)
            }
        )
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if isEditing {
                editingControls
                    .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            if widget.kind.supportsOptions {
                optionsMenu
            }
            if isEditing {
                resizeMenu
                Divider()
                Button(role: .destructive) {
                    widgetStore.remove(id: widget.id)
                } label: {
                    Label("Remove Widget", systemImage: "minus.circle")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(widget.kind.title)
        .accessibilityHint(isEditing ? "Drag to reorder or use the edit controls" : "Open widget action")
        .accessibilityAction(named: "Remove") {
            if isEditing { widgetStore.remove(id: widget.id) }
        }
    }

    private var height: CGFloat {
        switch widget.footprint {
        case .compact: 104
        case .standard: 132
        case .tall: 220
        case .large: 292
        }
    }

    private var editingControls: some View {
        HStack(spacing: 6) {
            Button(role: .destructive) {
                widgetStore.remove(id: widget.id)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.red, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(widget.kind.title) widget")

            Menu {
                resizeMenu
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Resize \(widget.kind.title) widget")
        }
    }

    @ViewBuilder
    private var resizeMenu: some View {
        Menu("Resize") {
            ForEach(widget.kind.supportedFootprints) { footprint in
                Button {
                    widgetStore.resize(id: widget.id, to: footprint)
                } label: {
                    Label(
                        footprint.accessibilityName.capitalized,
                        systemImage: footprint == widget.footprint ? "checkmark" : "rectangle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var optionsMenu: some View {
        switch widget.kind {
        case .activityShortcuts:
            Menu("Actions") {
                ForEach(HomeActivityShortcut.allCases) { action in
                    Button {
                        var configuration = widget.configuration
                        if configuration.activityShortcuts.contains(action) {
                            guard configuration.activityShortcuts.count > 1 else { return }
                            configuration.activityShortcuts.removeAll { $0 == action }
                        } else {
                            configuration.activityShortcuts.append(action)
                        }
                        widgetStore.updateConfiguration(configuration, for: widget.id)
                    } label: {
                        Label(
                            action.title,
                            systemImage: configurationContains(action) ? "checkmark" : action.systemImage
                        )
                    }
                }
            }
        case .metrics:
            Menu("Metrics") {
                ForEach(HomeMetricField.allCases) { field in
                    Button {
                        var configuration = widget.configuration
                        if configuration.metricFields.contains(field) {
                            guard configuration.metricFields.count > 1 else { return }
                            configuration.metricFields.removeAll { $0 == field }
                        } else {
                            configuration.metricFields.append(field)
                        }
                        widgetStore.updateConfiguration(configuration, for: widget.id)
                    } label: {
                        Label(
                            field.title,
                            systemImage: widget.configuration.metricFields.contains(field) ? "checkmark" : "plus"
                        )
                    }
                }
            }
        case .today, .recentWorkouts:
            visibleCountMenu
            if widget.kind == .today {
                Button {
                    toggleShowStatus()
                } label: {
                    Label(widget.configuration.showStatus ? "Hide status" : "Show status", systemImage: widget.configuration.showStatus ? "checkmark" : "circle")
                }
            }
        case .quickStart, .selectedWorkout:
            Button {
                toggleShowDetails()
            } label: {
                Label(widget.configuration.showDetails ? "Hide details" : "Show details", systemImage: widget.configuration.showDetails ? "checkmark" : "circle")
            }
            selectedWorkoutMenu
        case .weeklyRhythm, .typeBreakdown:
            selectedTypeMenu
        case .activityHeatmap:
            Button {
                toggleShowDetails()
            } label: {
                Label(widget.configuration.showDetails ? "Show labels" : "Hide labels", systemImage: widget.configuration.showDetails ? "checkmark" : "circle")
            }
        default:
            Button {
                toggleShowDetails()
            } label: {
                Label(widget.configuration.showDetails ? "Hide details" : "Show details", systemImage: widget.configuration.showDetails ? "checkmark" : "circle")
            }
        }
    }

    private var visibleCountMenu: some View {
        Menu("Visible items") {
            ForEach([1, 2, 3, 4, 5], id: \.self) { count in
                Button {
                    var configuration = widget.configuration
                    configuration.visibleCount = count
                    widgetStore.updateConfiguration(configuration, for: widget.id)
                } label: {
                    Label("\(count)", systemImage: widget.configuration.visibleCount == count ? "checkmark" : "circle")
                }
            }
        }
    }

    private var selectedTypeMenu: some View {
        Menu("Workout type") {
            Button {
                var configuration = widget.configuration
                configuration.selectedTypeID = nil
                widgetStore.updateConfiguration(configuration, for: widget.id)
            } label: {
                Label("All types", systemImage: widget.configuration.selectedTypeID == nil ? "checkmark" : "circle")
            }
            ForEach(WorkoutType.all(custom: workoutStore.customWorkoutTypes)) { type in
                Button {
                    var configuration = widget.configuration
                    configuration.selectedTypeID = type.id
                    widgetStore.updateConfiguration(configuration, for: widget.id)
                } label: {
                    Label(type.name, systemImage: widget.configuration.selectedTypeID == type.id ? "checkmark" : type.iconName)
                }
            }
        }
    }

    private var selectedWorkoutMenu: some View {
        Menu("Workout") {
            ForEach(workoutStore.workouts.filter { !$0.sections.isEmpty }) { workout in
                Button {
                    var configuration = widget.configuration
                    configuration.selectedWorkoutID = workout.id
                    widgetStore.updateConfiguration(configuration, for: widget.id)
                } label: {
                    Label(workout.name, systemImage: widget.configuration.selectedWorkoutID == workout.id ? "checkmark" : workout.type.iconName)
                }
            }
        }
    }

    private func configurationContains(_ action: HomeActivityShortcut) -> Bool {
        widget.configuration.activityShortcuts.contains(action)
    }

    private func toggleShowDetails() {
        var configuration = widget.configuration
        configuration.showDetails.toggle()
        widgetStore.updateConfiguration(configuration, for: widget.id)
    }

    private func toggleShowStatus() {
        var configuration = widget.configuration
        configuration.showStatus.toggle()
        widgetStore.updateConfiguration(configuration, for: widget.id)
    }
}

private struct HomeWidgetDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let widgetStore: HomeWidgetStore

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        widgetStore.move(id: draggedID, before: targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}
