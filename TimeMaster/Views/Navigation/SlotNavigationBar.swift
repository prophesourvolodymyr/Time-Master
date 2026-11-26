// SlotNavigationBar.swift
//
// The curved navigation bar with its in-place editor: long-press the arc to edit, tap a page's red minus (or drag it
// upward) to remove it, drag the icons to reorder them, tap "+" to add a page from the catalog, and tap the dimmed
// background to finish. Under a finger the arc lights up and gives a little like the app's buttons; pulled up it turns
// into the page wheel.

import SwiftUI

// MARK: - Editor chrome

struct SlotNavigationEditorHeader: View {
    let title: String
    let theme: SlotNavigationTheme

    var body: some View {
        Text(TimeMasterFont.initialCapitalizedTitle(title))
            .font(theme.typography.editorTitle)
            .foregroundStyle(theme.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bar

struct SlotCarouselNavigationBar: View, Animatable {
    static let inlineHeight: CGFloat = 60
    static let fullHeight: CGFloat = 96
    static let switchArchWidth: CGFloat = 2.4
    private static let accessorySpacing: CGFloat = 12
    private static let originalArchWidth: CGFloat = 40.0 / 34.0
    private static let restingScale: CGFloat = 0.88
    private static let restingOpacity: CGFloat = 0.28

    static func accessoryHeight(barHeight: CGFloat, showsCatalog: Bool) -> CGFloat {
        showsCatalog ? max(fullHeight, barHeight) + accessorySpacing : 0
    }

    static func contentHeight(for layout: SlotNavigationBarLayout, barHeight: CGFloat) -> CGFloat {
        guard layout == .full else { return inlineHeight }
        let height = max(fullHeight, barHeight)
        return height + inwardClearance(for: height)
    }

    /// The arc line of a full bar laid out in `frame` (global), as the page wheel grows out of it.
    static func wheelArc(in frame: CGRect, barHeight: CGFloat, placement: SlotNavigationPlacement) -> PageWheelArc {
        let height = max(fullHeight, barHeight)
        let surface = CGRect(x: frame.minX, y: placement == .bottom ? frame.maxY - height : frame.minY,
                             width: frame.width, height: height)
        let peakY = SlotArcGeometry.curveY(at: surface.midX, in: surface, curveOffset: platformCurveOffset, expansion: 1)
        let edgeY = SlotArcGeometry.curveY(at: surface.minX, in: surface, curveOffset: platformCurveOffset, expansion: 1)
        return PageWheelArc(
            peak: CGPoint(x: surface.midX, y: placement == .bottom ? peakY : surface.minY + surface.maxY - peakY),
            width: surface.width,
            sag: max(1, edgeY - peakY),
            pitch: slotWidth(for: surface.width),
            inset: 18
        )
    }

    private static func inwardClearance(for height: CGFloat) -> CGFloat {
        let rect = CGRect(x: 0, y: 0, width: 1, height: height)
        let curveY = SlotArcGeometry.curveY(at: 0.5, in: rect, curveOffset: platformCurveOffset, expansion: 1)
        let dragCurveY = height - (height - curveY) * (1 + switchSurfaceRise)
        let dragCenterY = dragCurveY + 56 - (42 + 15 + 4) / 2 - switchLift(at: 0)
        let dragOverflow = 114 * (switchScale(at: 0) - 0.5) - dragCenterY
        let editCurveY = height - (height - curveY) * 1.25 - 24
        let editCenterY = editCurveY + 56 - (42 + 15 + 4) / 2
        let editOverflow = 90 * (1.06 * 1.12 - 0.5) - editCenterY
        return ceil(max(0, max(dragOverflow, editOverflow)))
    }

    private static var archFlattening: CGFloat { originalArchWidth / switchArchWidth }
    private static var switchSurfaceStretch: CGFloat { 0.15 / archFlattening }
    private static var switchSurfaceRise: CGFloat { 0.35 * archFlattening }

    private static func switchLift(at slots: CGFloat) -> CGFloat {
        let reach = min(slots / switchArchWidth, 1)
        return 40 * archFlattening * (1 + cos(.pi * reach)) / 2
    }

    private static func switchScale(at slots: CGFloat) -> CGFloat {
        max(restingScale, 1.2 - slots * 0.35 * archFlattening)
    }

    private static func switchOpacity(at slots: CGFloat) -> CGFloat {
        max(restingOpacity, 1 - slots * 0.55 * archFlattening)
    }

    private static var platformCurveOffset: CGFloat {
        #if os(iOS)
        8
        #else
        54
        #endif
    }

    static func slotWidth(for viewportWidth: CGFloat) -> CGFloat {
        min(max(viewportWidth.slotFinite() * 0.22, 76), 92)
    }

    @Binding private var selection: Int
    @Binding private var isEditing: Bool
    @Binding private var showsCatalog: Bool
    private let items: [SlotNavigationItem]
    private let availableItems: [SlotNavigationItem]
    private let badges: SlotNavigationBadges
    private let onInsert: (String, Int) -> Void
    private let onMove: (String, Int) -> Void
    private let onRemove: (String) -> Void
    private let onEditingEnded: () -> Void
    private let placement: SlotNavigationPlacement
    private let edgeSafeArea: CGFloat
    private let barHeight: CGFloat
    private var expansion: CGFloat
    private var editingAmount: CGFloat
    private let theme: SlotNavigationTheme
    private let strings: SlotNavigationStrings
    private let isWheelPulling: () -> Bool
    private let onOpenWheel: () -> Void
    private let onWheelPull: (SlotReelWheelPull) -> Void
    private let onPageDrag: (CGFloat) -> Void
    private let onPageDragEnded: (Int?) -> Void
    private let onInteractionChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var reelOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragIntensity: CGFloat = 0
    @State private var isDragging = false
    @State private var hasMeasured = false
    @State private var catalogOffset: CGFloat = 0
    @State private var catalogStartOffset: CGFloat = 0
    @State private var catalogIsScrolling = false
    @State private var catalogHasMeasured = false
    @State private var prependInsertion = false
    @State private var liftedItem: LiftedItem?
    @State private var edgeScrollTask: Task<Void, Never>?
    @State private var edgeDirection = 0
    @State private var jiggle = false
    /// Where the finger came down; the ripple of light spreads from there.
    @State private var press: CGPoint?
    @State private var isPressed = false
    @State private var pressGlow: CGFloat = 0
    @State private var pressRipple: CGFloat = 0
    @State private var pressTracking = false
    @GestureState private var itemGestureActive = false
    @GestureState private var reelIsTracking = false
    @GestureState private var touchIsActive = false
    @State private var holdsExpansion = false
    @State private var reelTicks = SlotReelTicks()
    #if os(macOS)
    /// Moves the strip outside the editor on the Mac: two-finger scrolls, drags, clicks and selections made elsewhere.
    @StateObject private var reel: SlotReel
    @State private var reelDragTranslation: CGFloat = 0
    /// Keeps the editor's scroll position on screen until the reel takes the strip over after editing ends.
    @State private var editorHoldsStrip = false
    #endif
    /// How far above the arc line a scroll still counts as the bar's: the selected icon rises past the line.
    private static let scrollReach: CGFloat = 16
    private static let tapSlop: CGFloat = 14
    private static let settleVelocityLimit: CGFloat = 6

    private static let coordinateSpace = "navigation-arc-editor"
    private enum SlotRole { case page, catalog, prepend, append }
    private struct LiftedItem {
        let item: SlotNavigationItem
        let originalIndex: Int?
        let grabOffset: CGSize
        var location: CGPoint
        var insertion: Int?
        var removes = false
        var center: CGPoint {
            CGPoint(x: location.x - grabOffset.width, y: location.y - grabOffset.height)
        }
    }

    init(
        selection: Binding<Int>,
        items: [SlotNavigationItem],
        badges: SlotNavigationBadges,
        placement: SlotNavigationPlacement = .bottom,
        edgeSafeArea: CGFloat = 0,
        theme: SlotNavigationTheme = .timeMaster,
        strings: SlotNavigationStrings = .timeMaster,
        barHeight: CGFloat = SlotCarouselNavigationBar.fullHeight,
        layout: SlotNavigationBarLayout = .full,
        isEditing: Binding<Bool> = .constant(false),
        showsCatalog: Binding<Bool> = .constant(false),
        availableItems: [SlotNavigationItem] = [],
        onInsert: @escaping (String, Int) -> Void = { _, _ in },
        onMove: @escaping (String, Int) -> Void = { _, _ in },
        onRemove: @escaping (String) -> Void = { _ in },
        onEditingEnded: @escaping () -> Void = {},
        isWheelPulling: @escaping () -> Bool = { false },
        onOpenWheel: @escaping () -> Void = {},
        onWheelPull: @escaping (SlotReelWheelPull) -> Void = { _ in },
        onPageDrag: @escaping (CGFloat) -> Void = { _ in },
        onPageDragEnded: @escaping (Int?) -> Void = { _ in },
        onInteractionChanged: @escaping (Bool) -> Void
    ) {
        _selection = selection
        _isEditing = isEditing
        _showsCatalog = showsCatalog
        self.items = items
        self.badges = badges
        self.availableItems = availableItems
        self.onInsert = onInsert
        self.onMove = onMove
        self.onRemove = onRemove
        self.onEditingEnded = onEditingEnded
        self.placement = placement
        self.edgeSafeArea = max(0, edgeSafeArea)
        self.theme = theme
        self.strings = strings
        self.barHeight = max(Self.fullHeight, barHeight)
        self.expansion = layout == .full ? 1 : 0
        self.editingAmount = isEditing.wrappedValue ? 1 : 0
        self.isWheelPulling = isWheelPulling
        self.onOpenWheel = onOpenWheel
        self.onWheelPull = onWheelPull
        self.onPageDrag = onPageDrag
        self.onPageDragEnded = onPageDragEnded
        self.onInteractionChanged = onInteractionChanged
        #if os(macOS)
        _reel = StateObject(wrappedValue: SlotReel(count: items.count, slot: selection.wrappedValue))
        #endif
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(expansion, editingAmount) }
        set { expansion = newValue.first; editingAmount = newValue.second }
    }

    private var expandedAmount: CGFloat { holdsExpansion ? 1 : min(max(expansion, 0), 1) }
    private var effectiveDragIntensity: CGFloat { reduceMotion ? 0 : dragIntensity * expandedAmount * (1 - editProgress) }
    private var editProgress: CGFloat { reduceMotion ? 0 : min(max(editingAmount, 0), 1) }
    private var arcScaleX: CGFloat { 1 + effectiveDragIntensity * Self.switchSurfaceStretch + editProgress * 0.12 }
    private var arcScaleY: CGFloat { 1 + effectiveDragIntensity * Self.switchSurfaceRise + editProgress * 0.25 }
    private var surfaceHeight: CGFloat { Self.inlineHeight + (barHeight - Self.inlineHeight) * expandedAmount }
    private var inwardClearance: CGFloat { Self.inwardClearance(for: barHeight) * expandedAmount }
    private var mainHeight: CGFloat { surfaceHeight + inwardClearance }
    private var mainOriginY: CGFloat { placement == .bottom ? accessoryHeight : 0 }
    private var catalogOriginY: CGFloat {
        placement == .bottom ? accessoryHeight - barHeight - Self.accessorySpacing : mainHeight + Self.accessorySpacing
    }
    private var scaleAnchor: UnitPoint { placement == .bottom ? .bottom : .top }
    private var accessoryTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: placement.edge).combined(with: .opacity)
    }
    private var accessoryHeight: CGFloat {
        Self.accessoryHeight(barHeight: barHeight, showsCatalog: isEditing && showsCatalog)
    }
    private var editorAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84)
    }
    private var curveOffset: CGFloat { Self.platformCurveOffset }
    /// A press on the bar or, on the Mac, a scroll or drag that holds the strip.
    private var isInteracting: Bool {
        #if os(macOS)
        touchIsActive || reel.isTracking
        #else
        reelIsTracking
        #endif
    }

    private func placedY(_ y: CGFloat, height: CGFloat) -> CGFloat {
        placement == .bottom ? y : height - y
    }

    var body: some View {
        VStack(spacing: Self.accessorySpacing) {
            if placement == .top {
                mainArc.frame(height: mainHeight)
            }
            if isEditing, showsCatalog {
                catalogView
                    .frame(height: barHeight)
                    .transition(accessoryTransition)
            }
            if placement == .bottom {
                mainArc.frame(height: mainHeight)
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .onChange(of: isInteracting) { active in
            withAnimation(active ? dragExpansionAnimation : dragWindDownAnimation) { holdsExpansion = active }
            onInteractionChanged(active)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carousel-navigation")
        .accessibilityValue(isEditing ? strings.editingValue : (expandedAmount < 0.5 ? strings.compactValue : strings.expandedValue))
        .accessibilityAction(named: isEditing ? strings.doneEditing : strings.editNavigation) {
            if isEditing {
                onEditingEnded()
            } else {
                withAnimation(editorAnimation) { isEditing = true }
            }
        }
        .accessibilityAction(named: strings.openWheel) { onOpenWheel() }
        .onChange(of: itemGestureActive) { active in
            guard !active else { return }
            DispatchQueue.main.async {
                if !itemGestureActive { cancelLift() }
            }
        }
        .onChange(of: isEditing) { editing in
            jiggle = false
            if editing, !reduceMotion {
                DispatchQueue.main.async { jiggle = true }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { cancelLift() }
        }
        .onDisappear {
            cancelLift()
            onInteractionChanged(false)
        }
    }

    private var mainArc: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = Self.slotWidth(for: size.width)
            let arcRect = CGRect(x: 0, y: inwardClearance, width: size.width, height: surfaceHeight)
            let centeredOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
            let displayOffset = stripOffset(viewportWidth: size.width, slotWidth: slotWidth, centeredOffset: centeredOffset)

            ZStack {
                SlotArcSurface(
                    theme: theme,
                    edgeSafeArea: (edgeSafeArea + 24 * editProgress) / arcScaleY,
                    placement: placement,
                    curveOffset: curveOffset,
                    expansion: expandedAmount,
                    press: press.map { CGPoint(x: $0.x, y: $0.y - (placement == .bottom ? size.height - surfaceHeight : 0)) },
                    glow: isEditing ? 0 : pressGlow,
                    ripple: pressRipple
                )
                .frame(height: surfaceHeight)
                .scaleEffect(
                    x: arcScaleX * (isPressed && !reduceMotion && !isEditing ? 1.012 : 1),
                    y: arcScaleY * (isPressed && !reduceMotion && !isEditing ? 1.06 : 1),
                    anchor: scaleAnchor
                )
                .offset(y: -24 * editProgress * placement.outwardSign)
                .frame(height: size.height, alignment: placement.alignment)
                .allowsHitTesting(false)

                ZStack {
                    ForEach(items.indices, id: \.self) { index in
                        slotView(item: items[index], index: index, offset: displayOffset,
                                 size: size, arcRect: arcRect, slotWidth: slotWidth)
                    }
                    if isEditing {
                        slotView(item: SlotNavigationItem(id: "navigation.add.begin", icon: .system("plus"), title: strings.addItemTitle),
                                 index: -1, offset: displayOffset, size: size, arcRect: arcRect,
                                 slotWidth: slotWidth, role: .prepend)
                        slotView(item: SlotNavigationItem(id: "navigation.add.end", icon: .system("plus"), title: strings.addItemTitle),
                                 index: visibleItemCount, offset: displayOffset, size: size, arcRect: arcRect,
                                 slotWidth: slotWidth, role: .append)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                if let liftedItem {
                    liftedIcon(liftedItem)
                        .position(x: liftedItem.center.x, y: liftedItem.center.y - mainOriginY)
                        .transaction { $0.animation = nil }
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .contentShape(SlotArcHitShape(
                surfaceHeight: surfaceHeight, curveOffset: curveOffset, expansion: expandedAmount,
                scaleX: arcScaleX, scaleY: arcScaleY, lift: 24 * editProgress,
                reach: Self.scrollReach, placement: placement
            ))
            #if os(macOS)
            .background {
                SlotReelScroll(
                    reel: reel,
                    isEnabled: !isEditing && !editorHoldsStrip && !items.isEmpty,
                    pitch: slotWidth,
                    contains: { point, bounds in scrollReaches(point, in: bounds) },
                    onLand: reelLandingHandler,
                    onWheelPull: onWheelPull
                )
            }
            #endif
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($touchIsActive) { _, active, _ in active = true }
                    .onChanged { value in pressChanged(start: value.startLocation, location: value.location) }
                    .onEnded { _ in pressEnded() }
            )
            .highPriorityGesture(
                reelGesture(size: size, slotWidth: slotWidth, fallbackOffset: centeredOffset),
                including: isEditing ? .subviews : .all
            )
            .gesture(editorScrollGesture(size: size), including: isEditing ? .all : .subviews)
            .onChange(of: touchIsActive) { active in
                if !active { pressEnded() }
            }
            .onChange(of: reelIsTracking) { tracking in
                guard !tracking else { return }
                DispatchQueue.main.async {
                    if !reelIsTracking { cancelReel(size: size, slotWidth: slotWidth) }
                }
            }
            .onAppear {
                if !hasMeasured {
                    reelOffset = centeredOffset
                    hasMeasured = true
                }
                #if os(macOS)
                reel.reduceMotion = reduceMotion
                reel.resize(count: items.count)
                if !reel.isTracking, reel.landing != selection { reel.place(at: selection) }
                #endif
            }
            .onChange(of: size.width) { _ in
                let nextOffset = isEditing ? editorBoundedOffset(reelOffset, size: size)
                    : offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
                if isDragging {
                    reelOffset = nextOffset
                } else if abs(reelOffset - nextOffset) > 0.5 {
                    withAnimation(selectionAnimation) { reelOffset = nextOffset }
                }
            }
            .onChange(of: selection) { newSelection in
                guard !isDragging, !isEditing else { return }
                #if os(macOS)
                reel.resize(count: items.count)
                reel.show(newSelection)
                #endif
                let nextOffset = offset(for: newSelection, viewportWidth: size.width, slotWidth: slotWidth)
                guard abs(reelOffset - nextOffset) > 0.5 else { return }
                withAnimation(selectionAnimation) { reelOffset = nextOffset }
            }
            .onChange(of: isEditing) { editing in
                cancelLift()
                isDragging = false
                dragIntensity = 0
                #if os(macOS)
                if editing {
                    editorHoldsStrip = true
                    reel.place(at: selection)
                } else {
                    handStripToReel(viewportWidth: size.width, slotWidth: slotWidth)
                }
                #else
                if !editing {
                    withAnimation(selectionAnimation) {
                        reelOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
                    }
                }
                #endif
            }
            .onChange(of: items.count) { _ in
                #if os(macOS)
                if !isEditing {
                    reel.resize(count: items.count)
                    reel.show(selection)
                }
                #endif
                guard isEditing, liftedItem == nil else { return }
                withAnimation(editorAnimation) { reelOffset = editorBoundedOffset(reelOffset, size: size) }
            }
            #if os(macOS)
            .onChange(of: reel.isTracking) { tracking in
                withAnimation(tracking ? dragExpansionAnimation : dragWindDownAnimation) {
                    dragIntensity = tracking && !reduceMotion ? 1 : 0
                }
                if !tracking { onPageDragEnded(reel.landing) }
            }
            .onChange(of: reel.position) { position in
                if reel.isTracking { onPageDrag(position) }
            }
            .onChange(of: reduceMotion) { reduce in
                reel.reduceMotion = reduce
            }
            #endif
        }
    }

    /// A finger came down on the bar: the arc lifts a little and a glow blooms where it touched. As soon as the finger
    /// moves (a scrub or a pull) or lifts, the glow ripples out and fades and the arc settles, like a button's light.
    private func pressChanged(start: CGPoint, location: CGPoint) {
        guard start.x.isFinite, start.y.isFinite, location.x.isFinite, location.y.isFinite else { return }
        if !pressTracking {
            pressTracking = true
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                press = start
                pressRipple = 0
            }
            AppInteractionHaptics.shared.preparePress()
            withAnimation(reduceMotion ? nil : EverBounceMotion.lightOn) { pressGlow = 1 }
            withAnimation(reduceMotion ? nil : EverBounceMotion.liftOn) { isPressed = true }
            return
        }
        guard hypot(location.x - start.x, location.y - start.y) > 8 else { return }
        releasePress()
    }

    private func pressEnded() {
        pressTracking = false
        releasePress()
    }

    private func releasePress() {
        guard isPressed || pressGlow > 0 else { return }
        withAnimation(reduceMotion ? nil : EverBounceMotion.liftOff) { isPressed = false }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.5)) {
            pressGlow = 0
            pressRipple = 1
        }
    }

    private var visibleItemCount: Int {
        items.count - (liftedItem?.originalIndex != nil ? 1 : 0)
            + (liftedItem?.insertion != nil ? 1 : 0)
    }

    private func displayIndex(_ index: Int) -> Int {
        guard let liftedItem else { return index }
        var result = index
        if let origin = liftedItem.originalIndex {
            if origin == index { return index }
            if result > origin { result -= 1 }
        }
        if let insertion = liftedItem.insertion, result >= insertion { result += 1 }
        return result
    }

    private func slotView(
        item: SlotNavigationItem, index: Int, offset: CGFloat,
        size: CGSize, arcRect: CGRect, slotWidth: CGFloat, role: SlotRole = .page
    ) -> some View {
        let catalog = role == .catalog
        let add = role == .prepend || role == .append
        let amount: CGFloat = catalog ? 1 : expandedAmount
        let intensity: CGFloat = catalog ? 0 : effectiveDragIntensity
        let styleEdit: CGFloat = catalog ? 1 : min(max(editingAmount, 0), 1)
        let positionIndex = role == .page ? displayIndex(index) : index
        let centerX = size.width / 2
        let itemX = offset + CGFloat(positionIndex) * slotWidth + slotWidth / 2
        let distance = abs(itemX - centerX)
        let focus = max(0, 1 - min(distance / (slotWidth * 0.9), 1))
        let proximity = max(0, 1 - min(distance / (slotWidth * 2.3), 1))
        let norm = distance / slotWidth
        let bubbleFactor = max(0, 1 - distance / 34)
        let baseIconSize = 20 + 4 * focus + (4 + 3 * focus) * amount
        let expandedIconSize = 28 + bubbleFactor * 12
        #if os(macOS)
        let selectionBoost = 8 * focus * focus * amount * (1 - intensity)
        #else
        let selectionBoost: CGFloat = 0
        #endif
        let pressLift: CGFloat = role == .page && isPressed && !isEditing
            ? max(0, 1 - abs((press?.x ?? -999) - itemX) / slotWidth) : 0
        let iconSize = baseIconSize + intensity * (expandedIconSize - baseIconSize) + (add ? 8 : 0) + selectionBoost
            + (reduceMotion ? 0 : 5 * pressLift)
        let baseScale = Self.restingScale + 0.18 * focus
        let expandedScale = Self.switchScale(at: norm)
        let itemScale = (baseScale + intensity * (expandedScale - baseScale)) * (1 + (catalog ? 0 : editProgress) * 0.12)
        let baseOpacity = Self.restingOpacity + (1 - Self.restingOpacity) * proximity
        let expandedOpacity = Self.switchOpacity(at: norm)
        let normalOpacity = max(baseOpacity + intensity * (expandedOpacity - baseOpacity), pressLift * 0.9)
        let itemOpacity = normalOpacity + styleEdit * (max(normalOpacity, 0.72) - normalOpacity)
        let baseLabelOpacity = focus * focus
        let expandedLabelOpacity = max(0, bubbleFactor * 2 - 0.6)
        let normalLabelOpacity = baseLabelOpacity + intensity * (expandedLabelOpacity - baseLabelOpacity)
        let labelOpacity = (normalLabelOpacity + styleEdit * (1 - normalLabelOpacity)) * amount
        let verticalOffset = -intensity * Self.switchLift(at: norm) - (reduceMotion ? 0 : 4 * pressLift)
        let arcY = catalog
            ? SlotArcGeometry.curveY(at: itemX, in: arcRect, curveOffset: curveOffset, expansion: 1)
            : transformedArcY(at: itemX, in: arcRect)
        let itemHeight = min(Self.inlineHeight + 30 * amount + intensity * 24, size.height / itemScale)
        let iconFrameHeight = 28 + 14 * amount + intensity * max(0, expandedIconSize - 42)
        let zIndex = max(0, focus + intensity * (1 - min(norm, 10) - focus))
        let labelHeight = 15 * amount
        let labelSpacing = 4 * amount
        let compactY = Self.inlineHeight / 2
        let expandedY = arcY + 56 - (iconFrameHeight + labelHeight + labelSpacing) / 2 + verticalOffset
        let proposedY = compactY + (expandedY - compactY) * amount
        let lowestY = catalog ? size.height - itemHeight / 2 : size.height + itemHeight
        let boundedY = min(max(proposedY, itemHeight * (max(1, itemScale) - 0.5)), lowestY)
        let itemY = placedY(boundedY, height: size.height)
        let rootY = (catalog ? catalogOriginY : mainOriginY) + itemY
        let selected = role == .page && selection == index
        let lit: CGFloat = role == .page ? (isEditing ? (selected ? 1 : 0) : max(focus, pressLift)) : 0
        let manipulable = isEditing && !item.isPending && !add
        let removable = role == .page && isEditing && !item.isPending && items.count > 1
        let badgeCount = role == .page ? badges.count(for: item.id) : 0
        #if os(macOS)
        let edgeProgress = min(1, distance / max(1, size.width / 2))
        let viewportFade = catalog || isEditing ? 1 : 1 - edgeProgress * edgeProgress * (3 - 2 * edgeProgress)
        #endif

        return VStack(spacing: labelSpacing) {
            SlotNavigationIconImage(icon: add ? .system("plus.circle") : item.icon, size: 31, lit: lit)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(add ? theme.accent : theme.textPrimary)
                .scaleEffect(iconSize / 31)
                .frame(height: iconFrameHeight)
                .overlay(alignment: .topTrailing) {
                    if catalog {
                        Image(systemName: item.isPending ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.isPending ? theme.textSecondary : theme.accent)
                            .background(Circle().fill(theme.surface))
                            .offset(x: 9, y: -2)
                    } else if !isEditing, role == .page {
                        SlotNavigationBadgeView(badges: badges, id: item.id)
                            .offset(x: 12, y: -5)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if removable {
                        SlotNavigationRemoveButton(title: item.title, strings: strings, theme: theme) {
                            AppInteractionHaptics.shared.pressed()
                            withAnimation(editorAnimation) { onRemove(item.id) }
                        }
                        .accessibilityIdentifier("navigation-remove-\(item.id)")
                        .offset(x: -12, y: -6)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }
                .accessibilityHidden(true)
            Text(add ? "" : item.title.uppercased())
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .dynamicTypeSize(.large)
                .tracking(1.6)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: labelHeight)
                .clipped()
                .opacity(labelOpacity)
                .accessibilityHidden(true)
        }
        .frame(width: slotWidth, height: itemHeight)
        .contentShape(Rectangle())
        .rotationEffect(.degrees(removable && jiggle ? (index.isMultiple(of: 2) ? 1.8 : -1.8) : 0))
        .animation(removable && jiggle ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true) : .easeOut(duration: 0.12), value: jiggle)
        .scaleEffect(itemScale, anchor: scaleAnchor)
        .opacity(liftedItem?.item.id == item.id ? 0 : (item.isPending ? (catalog ? 0.55 : 0.4) : itemOpacity))
        #if os(macOS)
        .opacity(viewportFade)
        #endif
        .onTapGesture {
            guard liftedItem == nil, !item.isPending else { return }
            if !isEditing {
                if items.indices.contains(index) { AppInteractionHaptics.shared.settled() }
                settle(on: index, viewportWidth: size.width, slotWidth: slotWidth, projectedTranslation: 0)
            } else {
                switch role {
                case .prepend, .append:
                    withAnimation(editorAnimation) {
                        let prepend = role == .prepend
                        showsCatalog = !showsCatalog || prependInsertion != prepend
                        prependInsertion = prepend
                    }
                case .catalog:
                    withAnimation(editorAnimation) { onInsert(item.id, prependInsertion ? 0 : items.count) }
                case .page:
                    break
                }
            }
        }
        .gesture(
            itemDragGesture(item: item, index: catalog ? nil : index,
                            center: CGPoint(x: itemX, y: rootY), size: CGSize(width: size.width, height: mainHeight)),
            including: manipulable ? .all : .subviews
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(catalog ? "navigation-catalog-\(item.id)" : "navigation-item-\(item.id)")
        .accessibilityLabel(catalog ? strings.addToNavigation(item.title) : (add ? (role == .prepend ? strings.addItemAtStart : strings.addItemAtEnd) : item.title))
        .accessibilityValue(catalog
            ? (item.isPending ? strings.alreadyAddedValue : strings.notSelectedValue)
            : ([selected ? strings.selectedValue : strings.notSelectedValue, SlotNavigationBadge.accessibilityText(badgeCount)]
                .compactMap { $0 }.joined(separator: ", ")))
        .accessibilityHint(item.accessibilityHint)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAdjustableAction { direction in
            guard role == .page else { return }
            let current = isEditing ? index : selection
            let next: Int
            switch direction {
            case .increment: next = min(current + 1, items.count - 1)
            case .decrement: next = max(current - 1, 0)
            @unknown default: return
            }
            if isEditing {
                if manipulable { onMove(item.id, next) }
            } else {
                settle(on: next, viewportWidth: size.width, slotWidth: slotWidth, projectedTranslation: 0)
            }
        }
        .accessibilityAction(named: strings.removeFromNavigation) {
            if removable { onRemove(item.id) }
        }
        .position(x: itemX, y: itemY)
        .zIndex(1 + zIndex)
        .animation(isEditing ? editorAnimation : nil, value: liftedItem?.insertion)
        .animation(isEditing ? editorAnimation : nil, value: liftedItem?.removes)
    }

    private var catalogView: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = Self.slotWidth(for: size.width)
            let initial = offset(for: 0, viewportWidth: size.width, slotWidth: slotWidth)
            ZStack {
                SlotArcSurface(theme: theme, edgeSafeArea: 0, placement: placement, curveOffset: curveOffset, expansion: 1)
                    .allowsHitTesting(false)
                ForEach(availableItems.indices, id: \.self) { index in
                    slotView(item: availableItems[index], index: index,
                             offset: catalogHasMeasured ? catalogOffset : initial,
                             size: size, arcRect: CGRect(origin: .zero, size: size),
                             slotWidth: slotWidth, role: .catalog)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8).onChanged { value in
                guard liftedItem == nil else { return }
                if !catalogIsScrolling {
                    catalogIsScrolling = true
                    catalogStartOffset = catalogOffset
                }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { catalogOffset = catalogStartOffset + value.translation.width.slotFinite() }
            }.onEnded { _ in
                guard liftedItem == nil else { return }
                catalogIsScrolling = false
                withAnimation(editorAnimation) { boundCatalog(width: size.width) }
            })
            .onAppear {
                if !catalogHasMeasured {
                    catalogOffset = initial
                    catalogHasMeasured = true
                }
                boundCatalog(width: size.width)
            }
            .onChange(of: availableItems.count) { _ in
                withAnimation(editorAnimation) { boundCatalog(width: size.width) }
            }
            .onChange(of: size.width) { width in boundCatalog(width: width) }
        }
    }

    private func boundCatalog(width: CGFloat) {
        let slot = Self.slotWidth(for: width)
        let minimum = offset(for: max(availableItems.count - 1, 0), viewportWidth: width, slotWidth: slot)
        let maximum = offset(for: 0, viewportWidth: width, slotWidth: slot)
        catalogOffset = min(max(catalogOffset, minimum), maximum)
    }

    private func editorBoundedOffset(_ value: CGFloat, size: CGSize) -> CGFloat {
        let slot = Self.slotWidth(for: size.width)
        let minimum = offset(for: items.count, viewportWidth: size.width, slotWidth: slot)
        let maximum = offset(for: -1, viewportWidth: size.width, slotWidth: slot)
        return min(max(value, minimum), maximum)
    }

    private func scrollEditor(_ value: DragGesture.Value, size: CGSize) {
        guard liftedItem == nil else { return }
        if !isDragging {
            isDragging = true
            dragStartOffset = reelOffset
        }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) { reelOffset = dragStartOffset + value.translation.width.slotFinite() }
    }

    private func finishEditorScroll(size: CGSize) {
        guard liftedItem == nil else { return }
        isDragging = false
        withAnimation(editorAnimation) { reelOffset = editorBoundedOffset(reelOffset, size: size) }
    }

    private func itemDragGesture(item: SlotNavigationItem, index: Int?, center: CGPoint, size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.34, maximumDistance: 18)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace)))
            .updating($itemGestureActive) { value, active, _ in
                if case .second(true, _) = value { active = true }
            }
            .onChanged { value in
                guard isEditing, case let .second(true, drag?) = value else { return }
                if liftedItem == nil {
                    isDragging = false
                    catalogIsScrolling = false
                    liftedItem = LiftedItem(
                        item: item, originalIndex: index,
                        grabOffset: CGSize(width: drag.startLocation.x.slotFinite() - center.x,
                                           height: drag.startLocation.y.slotFinite() - center.y),
                        location: drag.location.slotFinite, insertion: index
                    )
                }
                updateLift(location: drag.location.slotFinite, size: size)
            }
            .onEnded { value in
                guard case let .second(true, drag?) = value else { cancelLift(); return }
                updateLift(location: drag.location.slotFinite, size: size)
                guard let lifted = liftedItem else { return }
                cancelLift()
                withAnimation(editorAnimation) {
                    if let origin = lifted.originalIndex {
                        if lifted.removes { onRemove(lifted.item.id) }
                        else if let insertion = lifted.insertion, insertion != origin { onMove(lifted.item.id, insertion) }
                    } else if let insertion = lifted.insertion {
                        onInsert(lifted.item.id, insertion)
                    }
                }
            }
    }

    private func updateLift(location: CGPoint, size: CGSize) {
        guard var lifted = liftedItem else { return }
        lifted.location = location
        let point = lifted.center
        let localY = placedY(point.y - mainOriginY, height: size.height)
        lifted.removes = lifted.originalIndex != nil && items.count > 1 && localY < -16
        let column = (point.x - reelOffset) / Self.slotWidth(for: size.width)
        if !lifted.removes, column.isFinite, localY >= -8, localY <= size.height + 32,
           point.x >= -24, point.x <= size.width + 24 {
            let remaining = items.count - (lifted.originalIndex == nil ? 0 : 1)
            lifted.insertion = min(max(Int(floor(column)), 0), max(remaining, 0))
        } else {
            lifted.insertion = nil
        }
        liftedItem = lifted
        let direction = lifted.insertion == nil ? 0 : (point.x < 36 ? 1 : (point.x > size.width - 36 ? -1 : 0))
        updateEdgeScroll(direction: direction, size: size)
    }

    private func updateEdgeScroll(direction: Int, size: CGSize) {
        guard direction != edgeDirection else { return }
        edgeScrollTask?.cancel()
        edgeScrollTask = nil
        edgeDirection = direction
        guard direction != 0 else { return }
        edgeScrollTask = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 16_666_667) } catch { return }
                guard let lifted = liftedItem, isEditing else { return }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    reelOffset = editorBoundedOffset(reelOffset + CGFloat(direction) * 3, size: size)
                    updateLift(location: lifted.location, size: size)
                }
            }
        }
    }

    private func cancelLift() {
        edgeScrollTask?.cancel()
        edgeScrollTask = nil
        edgeDirection = 0
        liftedItem = nil
    }

    private func liftedIcon(_ lifted: LiftedItem) -> some View {
        VStack(spacing: 4) {
            SlotNavigationIconImage(icon: lifted.item.icon, size: 33, lit: 1)
                .frame(height: 42)
                .overlay(alignment: .topTrailing) {
                    if lifted.removes {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, theme.destructive)
                            .offset(x: 12, y: -4)
                    }
                }
            Text(lifted.item.title.uppercased())
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .dynamicTypeSize(.large)
                .tracking(1.6)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 15)
        }
        .foregroundStyle(theme.textPrimary)
        .frame(width: 92, height: 90, alignment: .bottom)
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }

    private func transformedArcY(at x: CGFloat, in rect: CGRect) -> CGFloat {
        let centerX = rect.midX
        let arcSampleX = centerX + (x - centerX) / arcScaleX
        let unscaledY = SlotArcGeometry.curveY(at: arcSampleX, in: rect, curveOffset: curveOffset, expansion: expandedAmount)
        return rect.maxY - (rect.maxY - unscaledY) * arcScaleY - 24 * editProgress
    }

    private func stripOffset(viewportWidth: CGFloat, slotWidth: CGFloat, centeredOffset: CGFloat) -> CGFloat {
        #if os(macOS)
        if !isEditing && !editorHoldsStrip {
            return offset(for: 0, viewportWidth: viewportWidth, slotWidth: slotWidth) - reel.position * slotWidth
        }
        #endif
        return hasMeasured ? reelOffset : centeredOffset
    }

    #if os(macOS)
    /// After editing, the reel picks the strip up where the editor left it and glides to the selection.
    private func handStripToReel(viewportWidth: CGFloat, slotWidth: CGFloat) {
        reel.resize(count: items.count)
        reel.hold(at: (offset(for: 0, viewportWidth: viewportWidth, slotWidth: slotWidth) - reelOffset) / slotWidth)
        reel.select(selection)
        editorHoldsStrip = false
    }

    /// Selects the page the reel lands on. Captures the bindings rather than the bar: the bar owns the reel, so a
    /// callback holding the bar would keep both alive after the bar goes away.
    private var reelLandingHandler: (Int) -> Void {
        let pages = items
        let editing = $isEditing
        let current = $selection
        return { index in
            guard !editing.wrappedValue, pages.indices.contains(index), index != current.wrappedValue else { return }
            current.wrappedValue = index
        }
    }

    /// Scrolls belong to the bar when they start over its surface or just above the arc line; the open space
    /// higher up keeps scrolling the page.
    private func scrollReaches(_ point: CGPoint, in bounds: CGSize) -> Bool {
        let surface = CGRect(x: 0, y: placement == .bottom ? bounds.height - surfaceHeight : 0,
                             width: bounds.width, height: surfaceHeight)
        return SlotArcGeometry.surfaceContains(point, in: surface, curveOffset: curveOffset, expansion: expandedAmount,
                                               placement: placement, reach: Self.scrollReach)
    }
    #endif

    private var selectionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .interpolatingSpring(stiffness: 260, damping: 28)
    }

    private var dragExpansionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var dragWindDownAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.24)
    }

    private func reelGesture(size: CGSize, slotWidth: CGFloat, fallbackOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($reelIsTracking) { value, tracking, _ in
                if !tracking, Self.isSideways(value.translation), !isWheelPulling() { tracking = true }
            }
            .onChanged { value in
                trackReel(value, size: size, slotWidth: slotWidth, fallbackOffset: fallbackOffset)
            }
            .onEnded { value in
                releaseReel(value, size: size, slotWidth: slotWidth, fallbackOffset: fallbackOffset)
            }
    }

    private func editorScrollGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in scrollEditor(value, size: size) }
            .onEnded { _ in finishEditorScroll(size: size) }
    }

    private static func isSideways(_ translation: CGSize) -> Bool {
        translation.width.isFinite && translation.height.isFinite
            && abs(translation.width) > abs(translation.height) * 1.3
    }

    private func trackReel(_ value: DragGesture.Value, size: CGSize, slotWidth: CGFloat, fallbackOffset: CGFloat) {
        guard !isEditing else { return }
        let translation = value.translation.slotFinite
        if !isDragging {
            guard Self.isSideways(translation), !isWheelPulling() else { return }
            isDragging = true
            #if os(macOS)
            reelDragTranslation = 0
            #else
            dragStartOffset = hasMeasured ? reelOffset : fallbackOffset
            reelTicks.begin(at: selection)
            withAnimation(dragExpansionAnimation) {
                dragIntensity = reduceMotion ? 0 : 1
            }
            #endif
        }
        #if os(macOS)
        reel.track((reelDragTranslation - translation.width) / slotWidth)
        reelDragTranslation = translation.width
        #else
        let boundedOffset = rubberBand(
            dragStartOffset + translation.width,
            minimum: minimumOffset(viewportWidth: size.width, slotWidth: slotWidth),
            maximum: maximumOffset(viewportWidth: size.width, slotWidth: slotWidth)
        )
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) { reelOffset = boundedOffset }
        reelTicks.cross(index(for: boundedOffset, viewportWidth: size.width, slotWidth: slotWidth))
        onPageDrag((offset(for: 0, viewportWidth: size.width, slotWidth: slotWidth) - boundedOffset) / slotWidth)
        #endif
    }

    private func releaseReel(_ value: DragGesture.Value, size: CGSize, slotWidth: CGFloat, fallbackOffset: CGFloat) {
        guard !isEditing else { return }
        let translation = value.translation.slotFinite
        guard isDragging else {
            guard !isWheelPulling() else { return }
            selectSlot(at: value.startLocation.x, travel: translation, size: size, slotWidth: slotWidth,
                       fallbackOffset: fallbackOffset)
            return
        }
        #if os(macOS)
        isDragging = false
        reel.release()
        #else
        let reach = CGFloat(max(items.count, 1)) * slotWidth
        let predicted = value.predictedEndTranslation.width.slotFinite(translation.width)
        let projected = min(max(predicted, translation.width - reach), translation.width + reach)
        let targetIndex = index(for: dragStartOffset + projected, viewportWidth: size.width, slotWidth: slotWidth)
        isDragging = false
        withAnimation(dragWindDownAnimation) { dragIntensity = 0 }
        AppInteractionHaptics.shared.settled()
        settle(
            on: targetIndex,
            viewportWidth: size.width,
            slotWidth: slotWidth,
            projectedTranslation: projected - translation.width
        )
        onPageDragEnded(targetIndex)
        #endif
    }

    private func selectSlot(at x: CGFloat, travel: CGSize, size: CGSize, slotWidth: CGFloat, fallbackOffset: CGFloat) {
        guard x.isFinite, slotWidth > 0, hypot(travel.width, travel.height) <= Self.tapSlop else { return }
        let strip = stripOffset(viewportWidth: size.width, slotWidth: slotWidth, centeredOffset: fallbackOffset)
        let column = ((x - strip) / slotWidth).rounded(.down)
        guard column.isFinite, column >= 0, column < CGFloat(items.count) else { return }
        AppInteractionHaptics.shared.settled()
        settle(on: Int(column), viewportWidth: size.width, slotWidth: slotWidth, projectedTranslation: 0)
    }

    private func cancelReel(size: CGSize, slotWidth: CGFloat) {
        guard isDragging, !isEditing else { return }
        isDragging = false
        #if os(macOS)
        reel.release()
        #else
        withAnimation(dragWindDownAnimation) { dragIntensity = 0 }
        let landing = index(for: reelOffset, viewportWidth: size.width, slotWidth: slotWidth)
        settle(on: landing, viewportWidth: size.width, slotWidth: slotWidth, projectedTranslation: 0)
        onPageDragEnded(landing)
        #endif
    }

    private func settle(
        on index: Int,
        viewportWidth: CGFloat,
        slotWidth: CGFloat,
        projectedTranslation: CGFloat
    ) {
        guard items.indices.contains(index) else { return }
        #if os(macOS)
        if !isEditing {
            reel.select(index)
            return
        }
        #endif
        let targetOffset = offset(for: index, viewportWidth: viewportWidth, slotWidth: slotWidth)
        let currentOffset = hasMeasured ? reelOffset : targetOffset
        let remainingDistance = max(abs(targetOffset - currentOffset), 1)
        let normalizedVelocity = min(max((projectedTranslation / remainingDistance).slotFinite(),
                                         -Self.settleVelocityLimit), Self.settleVelocityLimit)
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.16)
            : .interpolatingSpring(stiffness: 260, damping: 28, initialVelocity: Double(normalizedVelocity))

        withAnimation(animation) {
            reelOffset = targetOffset
            hasMeasured = true
        }
        selection = index
    }

    private func offset(for index: Int, viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        viewportWidth / 2 - (CGFloat(index) * slotWidth + slotWidth / 2)
    }

    private func minimumOffset(viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        offset(for: max(items.count - 1, 0), viewportWidth: viewportWidth, slotWidth: slotWidth)
    }

    private func maximumOffset(viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        offset(for: 0, viewportWidth: viewportWidth, slotWidth: slotWidth)
    }

    private func index(for proposedOffset: CGFloat, viewportWidth: CGFloat, slotWidth: CGFloat) -> Int {
        guard !items.isEmpty, slotWidth > 0 else { return 0 }
        let boundedOffset = min(
            max(proposedOffset.slotFinite(reelOffset), minimumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)),
            maximumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)
        )
        let rawIndex = (viewportWidth / 2 - slotWidth / 2 - boundedOffset) / slotWidth
        guard rawIndex.isFinite else { return min(max(selection, 0), items.count - 1) }
        return min(max(Int(rawIndex.rounded()), 0), items.count - 1)
    }

    private func rubberBand(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard value.isFinite else { return maximum }
        if value < minimum { return minimum - (minimum - value) * 0.22 }
        if value > maximum { return maximum + (value - maximum) * 0.22 }
        return value
    }
}

private final class SlotReelTicks {
    private var slot: Int?
    private var lastTick: TimeInterval = 0

    func begin(at slot: Int) {
        self.slot = slot
    }

    @MainActor
    func cross(_ next: Int) {
        guard let slot, next != slot else { return }
        self.slot = next
        let now = SlotReel.now
        guard now - lastTick >= SlotReel.tickSpacing else { return }
        lastTick = now
        AppInteractionHaptics.shared.selectionChanged()
    }
}

/// The red minus on a page while the bar is edited, like the one on a jiggling Home Screen icon.
private struct SlotNavigationRemoveButton: View {
    let title: String
    let strings: SlotNavigationStrings
    let theme: SlotNavigationTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(theme.destructive))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.7))
                .padding(2)
                .background(Circle().fill(theme.surface))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(TimeMasterBounceButtonStyle(cornerRadius: 22, inset: 11, lift: 4))
        .accessibilityLabel(strings.removeItem(title))
    }
}

/// A page's badge on the bar, observing the counts by itself so a change redraws only the badge.
private struct SlotNavigationBadgeView: View {
    @ObservedObject var badges: SlotNavigationBadges
    let id: String

    var body: some View {
        let count = badges.count(for: id)
        ZStack {
            if count > 0 {
                SlotNavigationBadge(count: count)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.6), value: count > 0)
    }
}

private struct SlotArcHitShape: Shape {
    let surfaceHeight: CGFloat
    let curveOffset: CGFloat
    let expansion: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let lift: CGFloat
    let reach: CGFloat
    let placement: SlotNavigationPlacement

    func path(in rect: CGRect) -> Path {
        let surface = CGRect(
            x: rect.minX, y: placement == .bottom ? rect.maxY - surfaceHeight : rect.minY,
            width: rect.width, height: surfaceHeight
        )
        let anchorY = placement == .bottom ? rect.maxY : rect.minY
        let transform = CGAffineTransform(translationX: rect.midX, y: anchorY - lift * placement.outwardSign)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -rect.midX, y: -anchorY)
        let shape = SlotArcGeometry.surfacePath(
            in: surface, edgeExtension: 0, curveOffset: curveOffset, expansion: expansion, placement: placement
        ).applying(transform)
        var path = shape
        path.addPath(shape.applying(CGAffineTransform(translationX: 0, y: -reach * placement.outwardSign)))
        return path
    }
}

extension CGFloat {
    fileprivate func slotFinite(_ fallback: CGFloat = 0) -> CGFloat {
        isFinite ? self : fallback
    }
}

private extension CGSize {
    var slotFinite: CGSize {
        CGSize(width: width.slotFinite(), height: height.slotFinite())
    }
}

private extension CGPoint {
    var slotFinite: CGPoint {
        CGPoint(x: x.slotFinite(), y: y.slotFinite())
    }
}

// MARK: - Surface

/// The arc's surface. Under a finger the glass blooms with warm light around the touch, its rim catches it, and the
/// light ripples outward as it fades.
private struct SlotArcSurface: View {
    let theme: SlotNavigationTheme
    let edgeSafeArea: CGFloat
    let placement: SlotNavigationPlacement
    let curveOffset: CGFloat
    let expansion: CGFloat
    var press: CGPoint?
    var glow: CGFloat = 0
    var ripple: CGFloat = 0
    #if os(macOS)
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #endif

    var body: some View {
        let shape = SlotArcShape(edgeExtension: edgeSafeArea, placement: placement, curveOffset: curveOffset, expansion: expansion)
        #if os(macOS)
        glassSurface(shape)
            .overlay { light(shape) }
        #else
        shape
            .fill(theme.surface)
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: -8 * placement.outwardSign)
            .overlay { rim }
            .overlay { light(shape) }
        #endif
    }

    private var rim: some View {
        SlotArcLineShape(curveOffset: curveOffset, placement: placement, expansion: expansion)
            .stroke(theme.rim, lineWidth: 1)
    }

    @ViewBuilder
    private func light(_ shape: SlotArcShape) -> some View {
        if let press {
            SlotArcPressLight(
                shape: shape,
                line: SlotArcLineShape(curveOffset: curveOffset, placement: placement, expansion: expansion),
                point: press,
                glow: glow,
                ripple: ripple
            )
        }
    }

    #if os(macOS)
    @ViewBuilder
    private func glassSurface(_ shape: SlotArcShape) -> some View {
        let shadow = Color.black.opacity(0.5)
        let lift = -8 * placement.outwardSign
        if reduceTransparency {
            shape
                .fill(theme.surface)
                .shadow(color: shadow, radius: 12, x: 0, y: lift)
                .overlay { rim }
        } else if #available(macOS 26.0, *) {
            shape
                .fill(theme.surface.opacity(0.5))
                .glassEffect(.regular.tint(Color.black.opacity(0.45)), in: shape)
                .shadow(color: shadow, radius: 12, x: 0, y: lift)
                .overlay { rim }
        } else {
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(theme.surface.opacity(0.55)) }
                .shadow(color: shadow, radius: 12, x: 0, y: lift)
                .overlay { rim }
        }
    }
    #endif
}

/// The light of a press on the arc: a warm bloom on the glass and an orange-lit rim around the touch. `glow` fades it
/// and `ripple` spreads it outward as it goes; at rest it draws nothing.
private struct SlotArcPressLight: View, Animatable {
    let shape: SlotArcShape
    let line: SlotArcLineShape
    let point: CGPoint
    var glow: CGFloat
    var ripple: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(glow, ripple) }
        set {
            glow = newValue.first
            ripple = newValue.second
        }
    }

    var body: some View {
        if glow > 0.001 {
            GeometryReader { proxy in
                let size = proxy.size
                let center = UnitPoint(x: point.x / max(size.width, 1), y: point.y / max(size.height, 1))
                let reach = 110 + 170 * ripple
                ZStack {
                    shape.fill(RadialGradient(
                        stops: [
                            .init(color: Theme.toolbarOrange.opacity(0.3 * glow), location: 0),
                            .init(color: Theme.toolbarOrange.opacity(0.1 * glow), location: 0.45),
                            .init(color: Theme.toolbarOrange.opacity(0), location: 1)
                        ],
                        center: center, startRadius: 0, endRadius: reach
                    ))
                    .blendMode(.plusLighter)
                    line.stroke(RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.65 * glow), location: 0),
                            .init(color: Theme.toolbarOrange.opacity(0.55 * glow), location: 0.35),
                            .init(color: Theme.toolbarOrange.opacity(0), location: 1)
                        ],
                        center: center, startRadius: 0, endRadius: reach * 1.15
                    ), lineWidth: 1.6)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
