import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HomeWidgetCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @ScaledMetric private var greetingHeight = 64
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    @Binding var isEditing: Bool
    let insertedWidgetID: UUID?
    let now: Date
    let skippedScheduledInstanceIDs: Set<String>
    let onStartWorkout: (Workout) -> Void
    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?, UUID?) -> Void

    @State private var interaction: HomeWidgetInteraction?
    @State private var previewOrder: [UUID]?
    @State private var previewFootprint: HomeWidgetFootprint?

    var body: some View {
        GeometryReader { viewport in
            let width = max(1, min(viewport.size.width, 760) - HomeWidgetSizing.canvasPadding * 2)
            let widgets = arrangedWidgets
            let grid = HomeWidgetGrid(widgets: widgets, width: width, greetingHeight: greetingHeight)
            let frame = viewport.frame(in: .global)
            let dragViewport = frame.intersection(navigationBounds ?? frame)

            ScrollViewReader { scroll in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("home-top")
                        ZStack(alignment: .topLeading) {
                            if let interaction, let frame = grid.frames[interaction.id] {
                                RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                                    .fill(.white.opacity(0.035))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                                    }
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                                    .animation(layoutAnimation, value: frame)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                            ForEach(widgetStore.widgets) { savedWidget in
                                let widget = widgets.first(where: { $0.id == savedWidget.id }) ?? savedWidget
                                let slot = grid.frames[widget.id] ?? .zero
                                let active = interaction?.id == widget.id
                                let frame = active ? interaction!.frame : slot
                                let leadingGrip = active ? interaction!.originalFrame.minX > 0 : slot.minX > 0
                                HomeWidgetTile(
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
                                    onStartOutdoor: onStartOutdoor
                                )
                                .frame(width: frame.width, height: frame.height)
                                .overlay {
                                    if isEditing {
                                        HomeWidgetGestureSurface(resizing: false, viewport: dragViewport) { phase, translation in
                                            updateInteraction(phase, translation: translation, widget: widget, slot: slot, width: width, resizing: false)
                                        }
                                        .accessibilityHidden(true)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if isEditing {
                                        removeButton(widget)
                                            .offset(x: -10, y: -22)
                                    }
                                }
                                .overlay(alignment: leadingGrip ? .bottomLeading : .bottomTrailing) {
                                    if isEditing && widget.kind.supportedFootprints.count > 1 {
                                        resizeHandle(widget, leading: leadingGrip, viewport: dragViewport) { phase, translation in
                                            updateInteraction(phase, translation: translation, widget: widget, slot: slot, width: width, resizing: true)
                                        }
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if isEditing {
                                        HomeWidgetOptions(
                                            widget: widget,
                                            widgetStore: widgetStore,
                                            workoutStore: workoutStore
                                        )
                                        .offset(x: -8, y: -22)
                                    }
                                }
                                .scaleEffect(active && interaction?.resizing == false && !reduceMotion ? 1.035 : 1)
                                .shadow(color: .black.opacity(active ? 0.32 : 0), radius: active ? 20 : 0, y: active ? 12 : 0)
                                .position(x: frame.midX, y: frame.midY)
                                .animation(active ? nil : layoutAnimation, value: frame)
                                .animation(layoutAnimation, value: active)
                                .zIndex(active ? 2 : 0)
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .offset(y: -70).combined(with: .scale(scale: 1.04)).combined(with: .opacity),
                                    removal: .scale(scale: 0.94).combined(with: .opacity)
                                ))
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("home-widget-\(widget.kind.rawValue)")
                                .accessibilityLabel(widget.kind.title)
                                .accessibilityValue(widget.footprint.accessibilityName)
                                .accessibilityAction(named: "Move earlier") { move(widget, by: -1) }
                                .accessibilityAction(named: "Move later") { move(widget, by: 1) }
                            }
                        }
                        .frame(width: width, height: grid.height, alignment: .topLeading)
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, max(0, frame.maxY - dragViewport.maxY))
                }
                .accessibilityIdentifier("home-canvas")
                .onChange(of: insertedWidgetID) { _ in
                    scroll.scrollTo("home-top", anchor: .top)
                }
                .overlay {
                    if widgetStore.widgets.isEmpty {
                        Text("Make yourself at home.\nAdd your first widget.")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textSecondary)
                            .padding()
                    }
                }
            }
        }
        .clipped()
        .onChange(of: isEditing) { _ in cancelInteraction() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { cancelInteraction() }
        }
        .onDisappear { cancelInteraction() }
    }

    private var arrangedWidgets: [HomeWidgetInstance] {
        let saved = widgetStore.widgets
        var widgets = previewOrder.map { order in
            order.compactMap { id in saved.first { $0.id == id } }
        } ?? saved
        if let interaction, let previewFootprint,
           let index = widgets.firstIndex(where: { $0.id == interaction.id }) {
            widgets[index].footprint = previewFootprint
        }
        return widgets
    }

    private var layoutAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.84)
    }

    private func updateInteraction(
        _ phase: HomeWidgetGesturePhase, translation: CGSize,
        widget: HomeWidgetInstance, slot: CGRect, width: CGFloat, resizing: Bool
    ) {
        guard isEditing else { return }
        switch phase {
        case .began:
            guard interaction == nil else { return }
            previewOrder = widgetStore.widgets.map(\.id)
            interaction = HomeWidgetInteraction(id: widget.id, originalFrame: slot, frame: slot, resizing: resizing)
        case .changed:
            guard var current = interaction, current.id == widget.id else { return }
            if resizing {
                let leading = current.originalFrame.minX > 0
                let sizes = widget.kind.supportedFootprints.map { HomeWidgetGrid.size($0, width: width) }
                let minWidth = sizes.map(\.width).min() ?? slot.width
                let maxHeight = sizes.map(\.height).max() ?? slot.height
                let minHeight = sizes.map(\.height).min() ?? slot.height
                let proposedWidth = current.originalFrame.width + translation.width * (leading ? -1 : 1)
                let proposedHeight = current.originalFrame.height + translation.height
                let size = CGSize(
                    width: rubberBand(proposedWidth, minimum: minWidth, maximum: width),
                    height: rubberBand(proposedHeight, minimum: minHeight, maximum: maxHeight)
                )
                current.frame = CGRect(
                    x: leading ? current.originalFrame.maxX - size.width : current.originalFrame.minX,
                    y: current.originalFrame.minY, width: size.width, height: size.height
                )
                let nearest = HomeWidgetGrid.nearestFootprint(to: size, supported: widget.kind.supportedFootprints, width: width)
                if nearest != previewFootprint { previewFootprint = nearest }
            } else {
                current.frame = current.originalFrame.offsetBy(dx: translation.width, dy: translation.height)
            }
            interaction = current
            if !resizing { updateOrder(for: current, width: width) }
        case .ended:
            guard let current = interaction else { return }
            withAnimation(layoutAnimation) {
                if current.resizing, let previewFootprint {
                    widgetStore.updateFootprint(previewFootprint, for: current.id)
                } else if let index = previewOrder?.firstIndex(of: current.id) {
                    widgetStore.move(id: current.id, toIndex: index)
                }
                cancelInteraction()
            }
        case .cancelled:
            withAnimation(layoutAnimation) { cancelInteraction() }
        }
    }

    private func updateOrder(for current: HomeWidgetInteraction, width: CGFloat) {
        let widgets = arrangedWidgets
        guard let moving = widgets.first(where: { $0.id == current.id }),
              let oldIndex = widgets.firstIndex(where: { $0.id == current.id }) else { return }
        let remaining = widgets.filter { $0.id != current.id }
        var bestIndex = oldIndex
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var currentDistance = bestDistance
        for index in 0...remaining.count {
            var candidate = remaining
            candidate.insert(moving, at: index)
            let grid = HomeWidgetGrid(widgets: candidate, width: width, greetingHeight: greetingHeight)
            guard let target = grid.frames[current.id] else { continue }
            let distance = hypot(target.midX - current.frame.midX, target.midY - current.frame.midY)
            if index == oldIndex { currentDistance = distance }
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        guard bestIndex != oldIndex, bestDistance + HomeWidgetSizing.spacing < currentDistance else { return }
        var order = remaining.map(\.id)
        order.insert(current.id, at: bestIndex)
        previewOrder = order
    }

    private func cancelInteraction() {
        interaction = nil
        previewOrder = nil
        previewFootprint = nil
    }

    private func rubberBand(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        if value < minimum { return minimum + (value - minimum) * 0.12 }
        if value > maximum { return maximum + (value - maximum) * 0.12 }
        return value
    }

    private func move(_ widget: HomeWidgetInstance, by delta: Int) {
        guard let index = widgetStore.widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        withAnimation(layoutAnimation) { widgetStore.move(id: widget.id, toIndex: index + delta) }
    }

    private func removeButton(_ widget: HomeWidgetInstance) -> some View {
        Button(role: .destructive) {
            cancelInteraction()
            withAnimation(layoutAnimation) { widgetStore.remove(id: widget.id) }
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Theme.surface2, in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(widget.kind.title) widget")
    }

    private func resizeHandle(
        _ widget: HomeWidgetInstance, leading: Bool, viewport: CGRect,
        onChange: @escaping (HomeWidgetGesturePhase, CGSize) -> Void
    ) -> some View {
        HomeWidgetResizeGrip(leading: leading)
            .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .padding(12)
            .frame(width: 44, height: 44)
            .background { HomeWidgetGestureSurface(resizing: true, viewport: viewport, onChange: onChange) }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resize \(widget.kind.title)")
            .accessibilityValue(widget.footprint.accessibilityName)
            .accessibilityHint("Drag the corner to change size")
            .accessibilityAdjustableAction { direction in
                let sizes = widget.kind.supportedFootprints
                guard let index = sizes.firstIndex(of: widget.footprint) else { return }
                let next = direction == .increment ? index + 1 : index - 1
                guard sizes.indices.contains(next) else { return }
                withAnimation(layoutAnimation) { widgetStore.updateFootprint(sizes[next], for: widget.id) }
            }
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
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?, UUID?) -> Void

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
            onSkipScheduledWorkout: { widgetStore.skipScheduledInstance(id: $0.id) }
        )
        .padding(.leading, isEditing && widget.kind == .greeting ? 28 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(widget.kind == .greeting ? Color.clear : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(isEditing ? 0.22 : 0.06), lineWidth: 1)
                .opacity(widget.kind == .greeting && !isEditing ? 0 : 1)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(!isEditing)
    }
}

private struct HomeWidgetOptions: View {
    let widget: HomeWidgetInstance
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore

    var body: some View {
        if widget.kind.supportsOptions || widget.kind.supportedFootprints.count > 1 {
            Menu {
                if widget.kind.supportsOptions { optionsMenu }
                if widget.kind.supportedFootprints.count > 1 { footprintMenu }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Theme.surface2, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Edit \(widget.kind.title) options")
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
        Menu("Size") {
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

private struct HomeWidgetInteraction {
    let id: UUID
    let originalFrame: CGRect
    var frame: CGRect
    let resizing: Bool
}

private struct HomeWidgetResizeGrip: Shape {
    let leading: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edge = leading ? rect.minX : rect.maxX
        let otherEdge = leading ? rect.maxX : rect.minX
        let radius = rect.width * 0.5
        path.move(to: CGPoint(x: edge, y: rect.minY))
        path.addLine(to: CGPoint(x: edge, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: edge + (leading ? radius : -radius), y: rect.maxY),
            control: CGPoint(x: edge, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: otherEdge, y: rect.maxY))
        return path
    }
}

private enum HomeWidgetGesturePhase { case began, changed, ended, cancelled }

#if os(iOS)
private struct HomeWidgetGestureSurface: UIViewRepresentable {
    let resizing: Bool
    let viewport: CGRect
    let onChange: (HomeWidgetGesturePhase, CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let recognizer: UIGestureRecognizer
        if resizing {
            recognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        } else {
            let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
            hold.minimumPressDuration = 0.25
            hold.allowableMovement = 10
            recognizer = hold
        }
        view.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.finish(cancelled: true)
    }

    final class Coordinator: NSObject {
        var parent: HomeWidgetGestureSurface
        weak var recognizer: UIGestureRecognizer?
        private weak var scrollView: UIScrollView?
        private var initialPoint = CGPoint.zero
        private var windowPoint = CGPoint.zero
        private var scrollWasEnabled = true
        private var active = false
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0

        init(parent: HomeWidgetGestureSurface) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func interrupted() { finish(cancelled: true) }

        @objc func handle(_ gesture: UIGestureRecognizer) {
            switch gesture.state {
            case .began:
                var ancestor = gesture.view?.superview
                while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
                scrollView = ancestor as? UIScrollView
                initialPoint = gesture.location(in: scrollView ?? gesture.view?.window)
                windowPoint = gesture.location(in: gesture.view?.window)
                active = true
                if let scrollView {
                    scrollWasEnabled = scrollView.isScrollEnabled
                    scrollView.isScrollEnabled = false
                }
                parent.onChange(.began, .zero)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.add(to: .main, forMode: .common)
                displayLink = link
            case .changed:
                windowPoint = gesture.location(in: gesture.view?.window)
                publishTranslation()
            case .ended:
                publishTranslation()
                finish(cancelled: false)
            case .cancelled, .failed:
                finish(cancelled: true)
            default: break
            }
        }

        private func publishTranslation() {
            guard active, let window = recognizer?.view?.window else { return }
            let point = scrollView?.convert(windowPoint, from: window) ?? windowPoint
            parent.onChange(.changed, CGSize(width: point.x - initialPoint.x, height: point.y - initialPoint.y))
        }

        @objc private func tick(_ link: CADisplayLink) {
            let elapsed = lastTimestamp == 0 ? link.duration : min(link.timestamp - lastTimestamp, 1.0 / 20)
            lastTimestamp = link.timestamp
            guard active, let scrollView else { return }
            let viewport = parent.viewport
            let edge = min(80, viewport.height * 0.18)
            let top = viewport.minY
            let bottom = viewport.maxY
            let velocity: CGFloat
            if windowPoint.y < top + edge {
                velocity = -min(1, max(0, (top + edge - windowPoint.y) / edge)) * 420
            } else if windowPoint.y > bottom - edge {
                velocity = min(1, max(0, (windowPoint.y - bottom + edge) / edge)) * 420
            } else { return }
            let minimum = -scrollView.adjustedContentInset.top
            let maximum = max(minimum, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            let next = min(maximum, max(minimum, scrollView.contentOffset.y + velocity * elapsed))
            guard abs(next - scrollView.contentOffset.y) > 0.01 else { return }
            scrollView.contentOffset.y = next
            publishTranslation()
        }

        func finish(cancelled: Bool) {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = 0
            guard active else { return }
            active = false
            scrollView?.isScrollEnabled = scrollWasEnabled
            scrollView = nil
            parent.onChange(cancelled ? .cancelled : .ended, .zero)
        }
    }
}
#else
private struct HomeWidgetGestureSurface: View {
    let resizing: Bool
    let viewport: CGRect
    let onChange: (HomeWidgetGesturePhase, CGSize) -> Void
    @GestureState private var touching = false
    @State private var active = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: resizing ? 0 : 6)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { value in
                        if !active {
                            active = true
                            onChange(.began, .zero)
                        }
                        onChange(.changed, value.translation)
                    }
                    .onEnded { _ in
                        active = false
                        onChange(.ended, .zero)
                    }
            )
            .onChange(of: touching) { touching in
                if !touching && active {
                    active = false
                    onChange(.cancelled, .zero)
                }
            }
    }
}
#endif
