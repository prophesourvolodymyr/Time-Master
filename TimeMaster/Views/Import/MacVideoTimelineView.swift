#if os(macOS)
import AppKit
import SwiftUI

private enum TimelineMetrics {
    static let rulerHeight: CGFloat = 26
    static let laneTop: CGFloat = 30
    static let laneHeight: CGFloat = 70
    static let contentHeight: CGFloat = 106
    static let handleWidth: CGFloat = 14
    static let cornerRadius: CGFloat = 9
    static let minimumCellWidth: CGFloat = 72
    static let minimumLabelSpacing: CGFloat = 88
    static let trackSpace = "videoTimelineTrack"
}

final class MacVideoTimelineZoomAnchor {
    struct Point {
        var fraction: CGFloat
        var viewportX: CGFloat
    }

    var pending: Point?
}

private struct TimelineSampleGrid {
    let count: Int
    let cellWidth: CGFloat
    private let duration: Double
    private let frameRate: Double
    private let lastFrame: Int

    init(width: CGFloat, duration: Double, frameRate: Double) {
        let rate = max(frameRate, 1)
        let frames = max(1, Int(ceil(duration * rate)))
        count = max(1, min(frames, Int(ceil(width / TimelineMetrics.minimumCellWidth))))
        cellWidth = width / CGFloat(count)
        self.duration = duration
        self.frameRate = rate
        lastFrame = frames - 1
    }

    func frame(at index: Int) -> Int {
        min(lastFrame, max(0, Int((Double(index) * duration / Double(count) * frameRate).rounded(.down))))
    }

    func indexes(startX: CGFloat, endX: CGFloat, viewport: CGRect, viewportWidth: CGFloat) -> [Int] {
        let low = max(startX, viewport.minX - cellWidth)
        let high = min(endX, max(viewport.maxX, viewportWidth) + cellWidth)
        guard high > low else { return [] }
        let first = max(0, Int(floor(low / cellWidth)))
        let last = min(count - 1, Int(floor((high - 0.01) / cellWidth)))
        return first <= last ? Array(first...last) : []
    }
}

struct MacVideoTimelineView: View {
    @ObservedObject var model: MacVideoEditorModel
    @Binding var selectedSegmentID: UUID?
    let onSplit: () -> Void
    let onInteraction: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var viewport = CGRect.zero
    @State private var viewportWidth: CGFloat = 1
    @State private var boundaryDragStart: Double?
    @State private var zoomAnchor = MacVideoTimelineZoomAnchor()

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            GeometryReader { geometry in
                let width = max(1, geometry.size.width) * zoom
                MacVideoTimelineScrollView(
                    contentWidth: width,
                    contentHeight: TimelineMetrics.contentHeight,
                    playheadFraction: model.duration > 0 ? model.currentTime / model.duration : 0,
                    anchor: zoomAnchor,
                    onViewportChange: { rect in
                        viewport = rect
                        viewportWidth = max(1, rect.width)
                    },
                    onZoom: { factor, anchor in zoomTimeline(by: factor, anchor: anchor) },
                    onResetZoom: { zoom = 1 }
                ) {
                    track(width: width)
                }
            }
            .frame(height: TimelineMetrics.contentHeight + 18)
            footer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Label("Timeline", systemImage: "scissors")
                .font(TimeMasterFont.rowTitle())
            Text("\(model.segments.count)")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Button("Zoom out", systemImage: "minus.magnifyingglass") { zoomTimeline(by: 1 / 1.5) }
                .labelStyle(.iconOnly)
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .disabled(zoom <= 1)
                .help("Zoom out (⌘−, ⌘ + scroll, pinch)")
            Button(zoomLabel) { zoom = 1 }
                .font(TimeMasterFont.caption().monospacedDigit())
                .buttonStyle(.plain)
                .frame(minWidth: 38)
                .accessibilityLabel("Fit timeline")
                .help("Fit timeline (⌘0)")
            Button("Zoom in", systemImage: "plus.magnifyingglass") { zoomTimeline(by: 1.5) }
                .labelStyle(.iconOnly)
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .disabled(model.duration <= 0 || zoom >= maximumZoom)
                .help("Zoom in (⌘+, ⌘ + scroll, pinch)")
            Color.clear.frame(width: 6, height: 1)
            Button("Split", systemImage: "scissors", action: onSplit)
                .buttonStyle(TimeMasterActionButtonStyle())
                .disabled(!canSplit || model.isProcessing)
                .help("Cut at playhead (C)")
            Button("Still", systemImage: "camera") { Task { await model.addStill() } }
                .buttonStyle(TimeMasterActionButtonStyle())
                .disabled(model.duration <= 0 || model.isProcessing)
                .help("Capture a still at the playhead (S)")
            Button("Add All", systemImage: "tray.and.arrow.down") { Task { await model.addAllSegmentsToTray() } }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                .disabled(model.segments.isEmpty || model.isProcessing)
                .help("Add every segment to the media tray (A)")
        }
    }

    private var footer: some View {
        HStack {
            if let message = model.message {
                Text(message)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Text("\(timeString(model.currentTime)) / \(timeString(model.duration))")
                .monospacedDigit()
        }
        .font(TimeMasterFont.micro())
        .foregroundStyle(Theme.textSecondary)
    }

    private var zoomLabel: String {
        if zoom >= 10 { return "\(Int(zoom.rounded()))×" }
        return String(format: "%.1f×", zoom).replacingOccurrences(of: ".0×", with: "×")
    }

    private var maximumZoom: CGFloat {
        max(1, CGFloat(model.duration * model.frameRate) * TimelineMetrics.minimumCellWidth / max(1, viewportWidth))
    }

    private var canSplit: Bool {
        guard model.duration >= 0.5 else { return false }
        return model.segments.contains {
            model.currentTime > $0.startTime + 0.25 && model.currentTime < $0.endTime - 0.25
        }
    }

    private func zoomTimeline(by factor: CGFloat, anchor: MacVideoTimelineZoomAnchor.Point? = nil) {
        guard factor.isFinite, factor > 0 else { return }
        let next = min(maximumZoom, max(1, zoom * factor))
        guard next != zoom else { return }
        zoomAnchor.pending = anchor
        zoom = next
    }

    // MARK: Track

    private func track(width: CGFloat) -> some View {
        let grid = TimelineSampleGrid(width: width, duration: model.duration, frameRate: model.frameRate)
        let frames = drawnFrames(grid: grid, width: width)
        let playheadX = xPosition(for: model.currentTime, width: width)
        let lastIndex = model.segments.count - 1

        return ZStack(alignment: .topLeading) {
            ruler(width: width)
            lane(width: width)
            ForEach(Array(model.segments.enumerated()), id: \.element.id) { index, segment in
                clip(segment, index: index, isLast: index == lastIndex, width: width, grid: grid)
            }
            playhead(x: playheadX, width: width)
        }
        .frame(width: width, height: TimelineMetrics.contentHeight, alignment: .topLeading)
        .coordinateSpace(.named(TimelineMetrics.trackSpace))
        .contentShape(Rectangle())
        .gesture(scrubGesture(width: width))
        .task(id: frames) { model.requestTimelineThumbnails(frames: frames) }
    }

    private func drawnFrames(grid: TimelineSampleGrid, width: CGFloat) -> [Int] {
        var frames = Set<Int>()
        for segment in model.segments {
            let startX = xPosition(for: segment.startTime, width: width)
            let endX = xPosition(for: segment.endTime, width: width)
            for index in grid.indexes(startX: startX, endX: endX, viewport: viewport, viewportWidth: viewportWidth) {
                frames.insert(grid.frame(at: index))
            }
        }
        return frames.sorted()
    }

    private func lane(width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: TimelineMetrics.cornerRadius, style: .continuous)
        return shape
            .fill(Color.white.opacity(0.05))
            .frame(width: width, height: TimelineMetrics.laneHeight)
            .offset(y: TimelineMetrics.laneTop)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Video timeline")
            .accessibilityValue("\(timeString(model.currentTime)) of \(timeString(model.duration))")
            .accessibilityAdjustableAction { direction in
                model.seek(to: model.currentTime + (direction == .increment ? 1 : -1) / model.frameRate)
            }
    }

    private func clip(
        _ segment: MacVideoTimelineSegment,
        index: Int,
        isLast: Bool,
        width: CGFloat,
        grid: TimelineSampleGrid
    ) -> some View {
        let isSelected = selectedSegmentID == segment.id
        let startX = xPosition(for: segment.startTime, width: width)
        let endX = xPosition(for: segment.endTime, width: width)
        let clipWidth = max(2, endX - startX)
        let cells = grid.indexes(startX: startX, endX: endX, viewport: viewport, viewportWidth: viewportWidth)
        let shape = RoundedRectangle(cornerRadius: TimelineMetrics.cornerRadius, style: .continuous)

        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.surface2)
            ForEach(cells, id: \.self) { cell in
                frameCell(grid.frame(at: cell))
                    .frame(width: grid.cellWidth, height: TimelineMetrics.laneHeight)
                    .clipped()
                    .offset(x: CGFloat(cell) * grid.cellWidth - startX)
            }
        }
        .frame(width: clipWidth, height: TimelineMetrics.laneHeight, alignment: .topLeading)
        .clipShape(shape)
        .overlay {
            if isSelected {
                shape
                    .strokeBorder(Theme.toolbarOrange, lineWidth: 2.5)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) { chip(segment, index: index, isSelected: isSelected) }
        .overlay(alignment: .leading) {
            if index == 0 { handle(segment, boundary: .start, isSelected: isSelected, width: width) }
        }
        .overlay(alignment: .trailing) {
            handle(segment, boundary: .end, isSelected: isSelected, width: width)
                .offset(x: isLast ? 0 : TimelineMetrics.handleWidth / 2)
        }
        .offset(x: startX, y: TimelineMetrics.laneTop)
        .contextMenu { clipMenu(segment) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Segment \(index + 1), \(timeString(segment.startTime)) to \(timeString(segment.endTime))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text("Select segment")) {
            selectedSegmentID = segment.id
            model.seek(to: segment.startTime)
        }
    }

    @ViewBuilder
    private func frameCell(_ frame: Int) -> some View {
        if let image = model.timelineThumbnails[frame] {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Theme.surface2)
                .overlay { Image(systemName: "film").foregroundStyle(Theme.textSecondary.opacity(0.35)) }
        }
    }

    private func chip(_ segment: MacVideoTimelineSegment, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 8, weight: .bold))
            Text("\(index + 1)")
                .font(TimeMasterFont.black(10, relativeTo: .caption2))
        }
        .foregroundStyle(isSelected ? Color.black : Color.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(isSelected ? Theme.toolbarOrange : Color.black.opacity(0.62), in: Capsule())
        .padding(.leading, TimelineMetrics.handleWidth + 4)
        .padding(.top, 6)
        .onDrag { NSItemProvider(object: "segment:\(segment.id.uuidString)" as NSString) }
        .help("Drag to the media tray")
        .accessibilityHidden(true)
    }

    private func handle(
        _ segment: MacVideoTimelineSegment,
        boundary: MacVideoTimelineSegment.Boundary,
        isSelected: Bool,
        width: CGFloat
    ) -> some View {
        let boundaryTime = boundary == .start ? segment.startTime : segment.endTime
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Theme.toolbarOrange.opacity(isSelected ? 1 : 0.8))
            .frame(width: TimelineMetrics.handleWidth, height: TimelineMetrics.laneHeight - 14)
            .overlay {
                Image(systemName: boundary == .start ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }
            .frame(
                width: TimelineMetrics.handleWidth + 8,
                height: TimelineMetrics.laneHeight,
                alignment: boundary == .start ? .leading : .trailing
            )
            .contentShape(Rectangle())
            .macResizeCursor()
            .highPriorityGesture(handleDrag(segment, boundary: boundary, width: width))
            .accessibilityLabel(boundary == .start ? "Segment start" : "Segment end")
            .accessibilityValue(timeString(boundaryTime))
            .accessibilityAdjustableAction { direction in
                model.setBoundary(boundary, of: segment.id, to: boundaryTime + (direction == .increment ? 1 : -1) / model.frameRate)
            }
    }

    private func handleDrag(
        _ segment: MacVideoTimelineSegment,
        boundary: MacVideoTimelineSegment.Boundary,
        width: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(TimelineMetrics.trackSpace))
            .onChanged { value in
                if boundaryDragStart == nil {
                    boundaryDragStart = boundary == .start ? segment.startTime : segment.endTime
                    model.pausePlayback()
                }
                let delta = Double(value.translation.width / max(1, width)) * model.duration
                selectedSegmentID = segment.id
                model.setBoundary(boundary, of: segment.id, to: (boundaryDragStart ?? 0) + delta)
                seekToBoundary(of: segment.id, boundary)
            }
            .onEnded { _ in
                boundaryDragStart = nil
                onInteraction()
            }
    }

    private func seekToBoundary(of id: UUID, _ boundary: MacVideoTimelineSegment.Boundary) {
        guard let current = model.segments.first(where: { $0.id == id }) else { return }
        let time = boundary == .start
            ? current.startTime
            : max(0, current.endTime - 1 / max(model.frameRate, 1))
        model.seek(to: time)
    }

    @ViewBuilder
    private func clipMenu(_ segment: MacVideoTimelineSegment) -> some View {
        Button("Add clip to tray", systemImage: "tray.and.arrow.down") {
            Task { await model.addSegmentToTray(id: segment.id) }
        }
        Button("Set start at playhead", systemImage: "arrow.right.to.line") {
            model.setBoundary(.start, of: segment.id, to: model.currentTime)
        }
        Button("Set end at playhead", systemImage: "arrow.left.to.line") {
            model.setBoundary(.end, of: segment.id, to: model.currentTime)
        }
        Button("Delete segment", systemImage: "trash", role: .destructive) {
            model.removeSegment(id: segment.id)
            if selectedSegmentID == segment.id { selectedSegmentID = nil }
        }
    }

    private func playhead(x: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 2, height: TimelineMetrics.laneTop + TimelineMetrics.laneHeight + 4)
                .offset(x: max(0, min(width - 2, x - 1)))
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Theme.toolbarOrange)
                .frame(width: 12, height: 8)
                .offset(x: max(0, min(width - 12, x - 6)))
        }
        .allowsHitTesting(false)
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard model.duration > 0 else { return }
                model.beginScrubbing()
                let time = positionToTime(x: value.location.x, width: width)
                selectedSegmentID = model.segments.first { $0.contains(time) }?.id
                model.updateScrubPosition(time)
            }
            .onEnded { value in
                guard model.duration > 0 else { return }
                model.updateScrubPosition(positionToTime(x: value.location.x, width: width))
                model.endScrubbing()
                onInteraction()
            }
    }

    // MARK: Ruler

    private func rulerStep(width: CGFloat) -> Double {
        let rate = max(model.frameRate, 1)
        guard model.duration > 0 else { return 1 }
        let target = max(1 / rate, model.duration * Double(TimelineMetrics.minimumLabelSpacing / max(1, width)))
        let magnitude = pow(10, floor(log10(target)))
        let normalized = target / magnitude
        let nice: Double = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10
        return max(1 / rate, magnitude * nice)
    }

    private func ruler(width: CGFloat) -> some View {
        let step = rulerStep(width: width)
        let first = max(0, Int(floor(positionToTime(x: viewport.minX, width: width) / step)) - 1)
        let last = max(first, Int(ceil(positionToTime(x: max(viewport.maxX, viewportWidth), width: width) / step)))
        let labelWidth: CGFloat = step >= 1 ? 40 : step >= 0.1 ? 50 : 58

        return ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(first...last), id: \.self) { index in
                let time = Double(index) * step
                if time <= model.duration + 0.0001 {
                    tick(
                        label: rulerLabel(time, step: step),
                        x: xPosition(for: time, width: width),
                        width: width,
                        labelWidth: labelWidth
                    )
                }
            }
        }
        .frame(width: width, height: TimelineMetrics.rulerHeight, alignment: .topLeading)
    }

    private func tick(label: String, x: CGFloat, width: CGFloat, labelWidth: CGFloat) -> some View {
        let flips = x + labelWidth + 6 > width
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.textSecondary.opacity(0.65))
                .frame(width: 1, height: 7)
                .offset(x: x, y: TimelineMetrics.rulerHeight - 7)
            Text(label)
                .font(TimeMasterFont.micro().monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: flips ? .trailing : .leading)
                .offset(x: flips ? x - labelWidth - 3 : x + 4, y: 9)
        }
    }

    private func rulerLabel(_ time: Double, step: Double) -> String {
        let total = max(0, time)
        let minutes = Int(total) / 60
        let seconds = total - Double(minutes * 60)
        if step >= 1 { return String(format: "%d:%02d", minutes, Int(seconds.rounded())) }
        if step >= 0.1 { return String(format: "%d:%04.1f", minutes, seconds) }
        return String(format: "%d:%05.2f", minutes, seconds)
    }

    // MARK: Geometry

    private func xPosition(for time: Double, width: CGFloat) -> CGFloat {
        guard model.duration > 0 else { return 0 }
        return width * CGFloat(max(0, min(model.duration, time)) / model.duration)
    }

    private func positionToTime(x: CGFloat, width: CGFloat) -> Double {
        guard model.duration > 0 else { return 0 }
        return model.duration * Double(max(0, min(width, x)) / max(width, 1))
    }

    private func timeString(_ seconds: Double) -> String {
        let bounded = seconds.isFinite ? max(0, seconds) : 0
        let minutes = Int(bounded) / 60
        let wholeSeconds = Int(bounded) % 60
        let hundredths = Int((bounded - floor(bounded)) * 100)
        return String(format: "%d:%02d.%02d", minutes, wholeSeconds, hundredths)
    }
}

// MARK: - Scroll container

private struct MacVideoTimelineScrollView<Content: View>: NSViewRepresentable {
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let playheadFraction: Double
    let anchor: MacVideoTimelineZoomAnchor
    let onViewportChange: (CGRect) -> Void
    let onZoom: (CGFloat, MacVideoTimelineZoomAnchor.Point?) -> Void
    let onResetZoom: () -> Void
    @ViewBuilder let content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MacVideoTimelineNativeScrollView {
        let scrollView = MacVideoTimelineNativeScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.contentView.postsBoundsChangedNotifications = true
        let document = NSHostingView(rootView: content)
        document.sizingOptions = []
        document.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        scrollView.documentView = document
        let coordinator = context.coordinator
        coordinator.document = document
        coordinator.width = contentWidth
        coordinator.onViewportChange = onViewportChange
        coordinator.observer = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator, weak scrollView] _ in
            MainActor.assumeIsolated {
                guard let scrollView else { return }
                coordinator?.reportViewport(scrollView.documentVisibleRect)
            }
        }
        scrollView.onZoom = onZoom
        scrollView.onResetZoom = onResetZoom
        return scrollView
    }

    func updateNSView(_ scrollView: MacVideoTimelineNativeScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onViewportChange = onViewportChange
        scrollView.onZoom = onZoom
        scrollView.onResetZoom = onResetZoom
        let previousWidth = max(1, coordinator.width)
        let viewport = scrollView.documentVisibleRect
        let previousPlayheadX = previousWidth * CGFloat(playheadFraction)
        let playheadIsVisible = viewport.minX <= previousPlayheadX && previousPlayheadX <= viewport.maxX
        coordinator.document?.rootView = content
        coordinator.document?.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        if previousWidth != contentWidth {
            let fraction: CGFloat
            let viewportX: CGFloat
            if let pending = anchor.pending {
                fraction = pending.fraction
                viewportX = pending.viewportX
            } else if playheadIsVisible {
                fraction = CGFloat(playheadFraction)
                viewportX = previousPlayheadX - viewport.minX
            } else {
                fraction = viewport.midX / previousWidth
                viewportX = viewport.width / 2
            }
            anchor.pending = nil
            let origin = min(max(0, contentWidth * fraction - viewportX), max(0, contentWidth - viewport.width))
            scrollView.contentView.scroll(to: NSPoint(x: origin, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        coordinator.width = contentWidth
        coordinator.reportViewport(scrollView.documentVisibleRect)
    }

    static func dismantleNSView(_ nsView: MacVideoTimelineNativeScrollView, coordinator: Coordinator) {
        if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) }
        coordinator.observer = nil
        coordinator.document = nil
        nsView.documentView = nil
        nsView.onZoom = nil
        nsView.onResetZoom = nil
        nsView.removeEventMonitor()
    }

    final class Coordinator {
        var document: NSHostingView<Content>?
        var observer: NSObjectProtocol?
        var width: CGFloat = 1
        var onViewportChange: ((CGRect) -> Void)?
        private var lastViewport = CGRect.null

        func reportViewport(_ viewport: CGRect) {
            guard viewport.width > 0, viewport != lastViewport else { return }
            lastViewport = viewport
            DispatchQueue.main.async { [weak self] in self?.onViewportChange?(viewport) }
        }
    }
}

/// Scroll view that turns pinch, ⌘ + scroll and ⌘ +/−/0 into timeline zoom. Events are
/// intercepted with a window-scoped monitor so they work wherever the pointer sits over
/// the SwiftUI timeline, regardless of what the hosted views do with the responder chain.
private final class MacVideoTimelineNativeScrollView: NSScrollView {
    var onZoom: ((CGFloat, MacVideoTimelineZoomAnchor.Point?) -> Void)?
    var onResetZoom: (() -> Void)?
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitor()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .keyDown]) { [weak self] event in
            self?.route(event) ?? event
        }
    }

    deinit {
        removeEventMonitor()
    }

    func removeEventMonitor() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }

    private func route(_ event: NSEvent) -> NSEvent? {
        guard let window, event.window == nil || event.window === window else { return event }
        if event.type == .keyDown, event.window !== window { return event }
        switch event.type {
        case .magnify:
            guard let point = pointerPosition(of: event) else { return event }
            onZoom?(max(0.2, 1 + event.magnification), anchorPoint(for: point))
            return nil
        case .scrollWheel:
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command) || flags.contains(.option),
                  let point = pointerPosition(of: event) else { return event }
            let raw = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX
            let delta = event.hasPreciseScrollingDeltas ? raw : raw * 10
            if delta != 0 {
                onZoom?(CGFloat(exp(Double(delta) * 0.0075)), anchorPoint(for: point))
            }
            return nil
        case .keyDown:
            guard window.isKeyWindow, !(window.firstResponder is NSText) else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command), flags.subtracting([.command, .shift]).isEmpty else { return event }
            let characters = event.charactersIgnoringModifiers ?? ""
            if characters == "=" || characters == "+" || event.keyCode == 24 || event.keyCode == 69 {
                onZoom?(1.5, nil)
            } else if characters == "-" || characters == "_" || event.keyCode == 27 || event.keyCode == 78 {
                onZoom?(1 / 1.5, nil)
            } else if characters == "0" || event.keyCode == 29 {
                onResetZoom?()
            } else {
                return event
            }
            return nil
        default:
            return event
        }
    }

    private func pointerPosition(of event: NSEvent) -> NSPoint? {
        guard let window else { return nil }
        let windowPoint = event.window == nil ? window.convertPoint(fromScreen: event.locationInWindow) : event.locationInWindow
        let point = convert(windowPoint, from: nil)
        return bounds.contains(point) ? point : nil
    }

    private func anchorPoint(for point: NSPoint) -> MacVideoTimelineZoomAnchor.Point? {
        guard let document = documentView, document.frame.width > 0 else { return nil }
        let fraction = (documentVisibleRect.minX + point.x) / document.frame.width
        return MacVideoTimelineZoomAnchor.Point(fraction: max(0, min(1, fraction)), viewportX: point.x)
    }
}
#endif
