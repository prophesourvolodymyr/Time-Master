import SwiftUI

struct HomeWidgetCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var activeInsertionIndex: Int?
    @State private var widgetFrames: [UUID: CGRect] = [:]
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                insertionSlot(index: 0)

                ForEach(Array(widgetStore.widgets.enumerated()), id: \.element.id) { item in
                    tile(for: item.element)
                    insertionSlot(index: item.offset + 1)
                }
            }
            .padding(.horizontal, HomeWidgetSizing.canvasPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(layoutAnimation, value: widgetStore.widgets)
        }
        .coordinateSpace(name: "home-widget-canvas")
        .scrollDisabled(draggedWidgetID != nil)
        .overlay {
            if widgetStore.widgets.isEmpty {
                emptyCanvas
            }
        }
        .onPreferenceChange(HomeWidgetFramePreferenceKey.self) { frames in
            widgetFrames = frames
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tile(for widget: HomeWidgetInstance) -> some View {
        let tile = HomeWidgetTile(
            widget: widget,
            isEditing: isEditing,
            widgetStore: widgetStore,
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore,
            now: now,
            skippedScheduledInstanceIDs: skippedScheduledInstanceIDs,
            draggedWidgetID: $draggedWidgetID,
            onDragChanged: updateDrag,
            onDragEnded: finishDrag,
            onStartWorkout: onStartWorkout,
            onBrowseWorkouts: onBrowseWorkouts,
            onBrowseDatabase: onBrowseDatabase,
            onCreateWorkout: onCreateWorkout,
            onStartOutdoor: onStartOutdoor
        )

        if widget.footprint == .compact {
            HStack(spacing: 12) {
                tile
                    .frame(maxWidth: .infinity)
                Color.clear
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            tile
        }
    }
    private var layoutAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.34, dampingFraction: 0.88)
    }

    private func updateDrag(widgetID: UUID, location: CGPoint) {
        guard isEditing,
              let currentIndex = widgetStore.widgets.firstIndex(where: { $0.id == widgetID }) else {
            return
        }

        draggedWidgetID = widgetID

        let remainingFrames = widgetFrames
            .filter { $0.key != widgetID }
            .sorted { $0.value.minY < $1.value.minY }
        let insertionAfterRemoval = remainingFrames.firstIndex { location.y < $0.value.midY } ?? remainingFrames.count
        let destination = insertionAfterRemoval >= currentIndex
            ? insertionAfterRemoval + 1
            : insertionAfterRemoval

        activeInsertionIndex = destination
        guard destination != currentIndex else { return }

        withAnimation(layoutAnimation) {
            widgetStore.move(id: widgetID, toInsertionIndex: destination)
        }
    }

    private func finishDrag() {
        withAnimation(layoutAnimation) {
            draggedWidgetID = nil
            activeInsertionIndex = nil
        }
    }


    @ViewBuilder
    private func insertionSlot(index: Int) -> some View {
        if isEditing && draggedWidgetID != nil {
            HomeWidgetInsertionSlot(
                isActive: activeInsertionIndex == index
            )
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
    @Binding var draggedWidgetID: UUID?
    let onDragChanged: (UUID, CGPoint) -> Void
    let onDragEnded: () -> Void
    let onStartWorkout: (Workout) -> Void
    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?) -> Void

    private var renderedContent: some View {
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
    }

    var body: some View {
        Group {
            if widget.kind == .greeting {
                renderedContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 58, alignment: .center)
            } else {
                renderedContent
                    .frame(maxWidth: .infinity)
                    .aspectRatio(widget.footprint.aspectRatio, contentMode: .fit)
            }
        }
        .background {
            if isEditing && widget.kind != .greeting {
                RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surface2, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            }
        }
        .overlay {
            if isEditing {
                RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius + 2)
                    .stroke(
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5], dashPhase: 0)
                    )
                    .foregroundStyle(.white.opacity(draggedWidgetID == widget.id ? 0.85 : 0.42))
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                HStack(spacing: 8) {
                    widgetOptionsButton
                    removeButton
                }
                .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: HomeWidgetFramePreferenceKey.self,
                        value: [widget.id: proxy.frame(in: .named("home-widget-canvas"))]
                    )
            }
        }
        .simultaneousGesture(baseDragGesture)
        .contextMenu {
            if widget.kind.supportsOptions {
                optionsMenu
            }
            if widget.kind.supportedFootprints.count > 1 {
                if widget.kind.supportsOptions {
                    Divider()
                }
                footprintMenu
            }
            if isEditing {
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
        .accessibilityValue("\(widget.footprint.accessibilityName) shape")
        .accessibilityHint(isEditing ? "Drag this widget from anywhere on its base to reorder it" : "Open widget action")
        .accessibilityAction(named: "Remove") {
            if isEditing {
                widgetStore.remove(id: widget.id)
            }
        }
    }

    private var baseDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 18)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named("home-widget-canvas")
                )
            )
            .onChanged { value in
                guard isEditing else { return }
                guard case .second(true, let drag) = value, let drag else { return }
                if draggedWidgetID == nil {
                    draggedWidgetID = widget.id
                }
                onDragChanged(widget.id, drag.location)
            }
            .onEnded { value in
                guard isEditing, case .second(true, _) = value else { return }
                onDragEnded()
            }
    }


    private var widgetOptionsButton: some View {
        Menu {
            if widget.kind.supportsOptions {
                optionsMenu
            }
            if widget.kind.supportedFootprints.count > 1 {
                if widget.kind.supportsOptions {
                    Divider()
                }
                footprintMenu
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.62), in: Circle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Edit \(widget.kind.title) options")
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            widgetStore.remove(id: widget.id)
        } label: {
            Image(systemName: "minus")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.red, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(widget.kind.title) widget")
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
                            systemImage: widget.configuration.activityShortcuts.contains(action) ? "checkmark" : action.systemImage
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
                    var configuration = widget.configuration
                    configuration.showStatus.toggle()
                    widgetStore.updateConfiguration(configuration, for: widget.id)
                } label: {
                    Label(
                        widget.configuration.showStatus ? "Hide status" : "Show status",
                        systemImage: widget.configuration.showStatus ? "checkmark" : "circle"
                    )
                }
            }
        case .quickStart, .selectedWorkout:
            Button {
                var configuration = widget.configuration
                configuration.showDetails.toggle()
                widgetStore.updateConfiguration(configuration, for: widget.id)
            } label: {
                Label(
                    widget.configuration.showDetails ? "Hide details" : "Show details",
                    systemImage: widget.configuration.showDetails ? "checkmark" : "circle"
                )
            }
            selectedWorkoutMenu
        case .weeklyRhythm, .typeBreakdown:
            selectedTypeMenu
        case .activityHeatmap:
            Button {
                var configuration = widget.configuration
                configuration.showDetails.toggle()
                widgetStore.updateConfiguration(configuration, for: widget.id)
            } label: {
                Label(
                    widget.configuration.showDetails ? "Show labels" : "Hide labels",
                    systemImage: widget.configuration.showDetails ? "checkmark" : "circle"
                )
            }
        default:
            Button {
                var configuration = widget.configuration
                configuration.showDetails.toggle()
                widgetStore.updateConfiguration(configuration, for: widget.id)
            } label: {
                Label(
                    widget.configuration.showDetails ? "Hide details" : "Show details",
                    systemImage: widget.configuration.showDetails ? "checkmark" : "circle"
                )
            }
        }
    }

    private var footprintMenu: some View {
        Menu("Shape") {
            ForEach(widget.kind.supportedFootprints) { footprint in
                Button {
                    widgetStore.updateFootprint(footprint, for: widget.id)
                } label: {
                    Label(
                        footprint.menuTitle,
                        systemImage: widget.footprint == footprint ? "checkmark" : "circle"
                    )
                }
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
                    Label(
                        "\(count)",
                        systemImage: widget.configuration.visibleCount == count ? "checkmark" : "circle"
                    )
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
                    Label(
                        type.name,
                        systemImage: widget.configuration.selectedTypeID == type.id ? "checkmark" : type.iconName
                    )
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
                    Label(
                        workout.name,
                        systemImage: widget.configuration.selectedWorkoutID == workout.id ? "checkmark" : workout.type.iconName
                    )
                }
            }
        }
    }
}

private struct HomeWidgetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

private struct HomeWidgetInsertionSlot: View {
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                style: StrokeStyle(lineWidth: isActive ? 2 : 1, dash: [6, 4])
            )
            .foregroundStyle(isActive ? .cyan : .white.opacity(0.24))
            .frame(height: 34)
            .overlay {
                if isActive {
                    Label("Drop widget here", systemImage: "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(isActive ? "Drop widget here" : "Widget drop position")
    }
}
