// SlotNavigationBar.swift
//
// The curved navigation bar with its in-place editor: long-press the arc to edit, drag the
// icons to reorder them, drag one upward to remove it, tap "+" to add a page from the
// catalog, and tap the dimmed background to finish. Part of the CarouselNavigation component
// from the SwiftComponentLibrary, copied into the app.

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
    private static let configurationHeight: CGFloat = 156
    private static let accessorySpacing: CGFloat = 12
    private static let originalArchWidth: CGFloat = 40.0 / 34.0
    private static let restingScale: CGFloat = 0.88
    private static let restingOpacity: CGFloat = 0.28
    private static let artScale: CGFloat = 1.15

    static func accessoryHeight(barHeight: CGFloat, showsCatalog: Bool, hasConfiguration: Bool) -> CGFloat {
        (showsCatalog ? max(fullHeight, barHeight) + accessorySpacing : 0)
            + (hasConfiguration ? configurationHeight + accessorySpacing : 0)
    }

    static func contentHeight(for layout: SlotNavigationBarLayout, barHeight: CGFloat) -> CGFloat {
        guard layout == .full else { return inlineHeight }
        let height = max(fullHeight, barHeight)
        return height + inwardClearance(for: height)
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

    @Binding private var selection: Int
    @Binding private var isEditing: Bool
    @Binding private var showsCatalog: Bool
    private let items: [SlotNavigationItem]
    private let availableItems: [SlotNavigationItem]
    private let configuration: SlotNavigationConfiguration?
    private let onInsert: (String, Int) -> Void
    private let onMove: (String, Int) -> Void
    private let onRemove: (String) -> Void
    private let onConfigure: (String) -> Void
    private let onEditingEnded: () -> Void
    private let placement: SlotNavigationPlacement
    private let edgeSafeArea: CGFloat
    private let barHeight: CGFloat
    private var expansion: CGFloat
    private var editingAmount: CGFloat
    private let theme: SlotNavigationTheme
    private let strings: SlotNavigationStrings
    private let onSelectionChanged: (Int) -> Void
    private let onPageDrag: (CGFloat) -> Void
    private let onPageDragEnded: () -> Void
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
    @GestureState private var itemGestureActive = false
    @GestureState private var reelIsTracking = false
    @State private var holdsExpansion = false
    @State private var reelTicks = SlotReelTicks()
    @State private var notificationDismissalToken = 0
    #if os(macOS)
    @GestureState private var touchIsActive = false
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
        placement: SlotNavigationPlacement = .bottom,
        edgeSafeArea: CGFloat = 0,
        theme: SlotNavigationTheme = .timeMaster,
        strings: SlotNavigationStrings = .timeMaster,
        barHeight: CGFloat = SlotCarouselNavigationBar.fullHeight,
        layout: SlotNavigationBarLayout = .full,
        isEditing: Binding<Bool> = .constant(false),
        showsCatalog: Binding<Bool> = .constant(false),
        availableItems: [SlotNavigationItem] = [],
        configuration: SlotNavigationConfiguration? = nil,
        onInsert: @escaping (String, Int) -> Void = { _, _ in },
        onMove: @escaping (String, Int) -> Void = { _, _ in },
        onRemove: @escaping (String) -> Void = { _ in },
        onConfigure: @escaping (String) -> Void = { _ in },
        onEditingEnded: @escaping () -> Void = {},
        onSelectionChanged: @escaping (Int) -> Void = { _ in },
        onPageDrag: @escaping (CGFloat) -> Void = { _ in },
        onPageDragEnded: @escaping () -> Void = {},
        onInteractionChanged: @escaping (Bool) -> Void
    ) {
        _selection = selection
        _isEditing = isEditing
        _showsCatalog = showsCatalog
        self.items = items
        self.availableItems = availableItems
        self.configuration = configuration
        self.onInsert = onInsert
        self.onMove = onMove
        self.onRemove = onRemove
        self.onConfigure = onConfigure
        self.onEditingEnded = onEditingEnded
        self.placement = placement
        self.edgeSafeArea = max(0, edgeSafeArea)
        self.theme = theme
        self.strings = strings
        self.barHeight = max(Self.fullHeight, barHeight)
        self.expansion = layout == .full ? 1 : 0
        self.editingAmount = isEditing.wrappedValue ? 1 : 0
        self.onSelectionChanged = onSelectionChanged
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
        placement == .bottom ? accessoryHeight - barHeight - Self.accessorySpacing
            : mainHeight + Self.accessorySpacing
                + Self.accessoryHeight(barHeight: barHeight, showsCatalog: false, hasConfiguration: configuration != nil)
    }
    private var scaleAnchor: UnitPoint { placement == .bottom ? .bottom : .top }
    private var accessoryTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: placement.edge).combined(with: .opacity)
    }
    private var accessoryHeight: CGFloat {
        Self.accessoryHeight(barHeight: barHeight, showsCatalog: isEditing && showsCatalog,
                             hasConfiguration: isEditing && configuration != nil)
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
            if isEditing, let configuration {
                configurationView(configuration)
                    .frame(height: Self.configurationHeight)
                    .transition(accessoryTransition)
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
        #if os(macOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($touchIsActive) { _, active, _ in active = true }
        )
        #endif
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
        .onChange(of: itemGestureActive) { active in
            guard !active else { return }
            DispatchQueue.main.async {
                if !itemGestureActive { cancelLift() }
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
            let slotWidth = slotWidth(for: size.width)
            let arcRect = CGRect(x: 0, y: inwardClearance, width: size.width, height: surfaceHeight)
            let centeredOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
            let displayOffset = stripOffset(viewportWidth: size.width, slotWidth: slotWidth, centeredOffset: centeredOffset)

            ZStack {
                SlotArcSurface(theme: theme, edgeSafeArea: (edgeSafeArea + 24 * editProgress) / arcScaleY, placement: placement,
                               curveOffset: curveOffset, expansion: expandedAmount)
                    .frame(height: surfaceHeight)
                    .scaleEffect(x: arcScaleX, y: arcScaleY, anchor: scaleAnchor)
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
                    onLand: reelLandingHandler
                )
            }
            #endif
            .highPriorityGesture(
                reelGesture(size: size, slotWidth: slotWidth, fallbackOffset: centeredOffset),
                including: isEditing ? .subviews : .all
            )
            .gesture(editorScrollGesture(size: size), including: isEditing ? .all : .subviews)
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
                if items.indices.contains(newSelection), items[newSelection].badgeCount > 0 {
                    notificationDismissalToken &+= 1
                }
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
                if !tracking { onPageDragEnded() }
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
        let iconSize = baseIconSize + intensity * (expandedIconSize - baseIconSize) + (add ? 8 : 0) + selectionBoost
        let baseScale = Self.restingScale + 0.18 * focus
        let expandedScale = Self.switchScale(at: norm)
        let itemScale = (baseScale + intensity * (expandedScale - baseScale)) * (1 + (catalog ? 0 : editProgress) * 0.12)
        let baseOpacity = Self.restingOpacity + (1 - Self.restingOpacity) * proximity
        let expandedOpacity = Self.switchOpacity(at: norm)
        let normalOpacity = baseOpacity + intensity * (expandedOpacity - baseOpacity)
        let itemOpacity = normalOpacity + styleEdit * (max(normalOpacity, 0.72) - normalOpacity)
        let baseLabelOpacity = focus * focus
        let expandedLabelOpacity = max(0, bubbleFactor * 2 - 0.6)
        let normalLabelOpacity = baseLabelOpacity + intensity * (expandedLabelOpacity - baseLabelOpacity)
        let labelOpacity = (normalLabelOpacity + styleEdit * (1 - normalLabelOpacity)) * amount
        let verticalOffset = -intensity * Self.switchLift(at: norm)
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
        let lit: CGFloat = role == .page ? (isEditing ? (selected ? 1 : 0) : focus) : 0
        let manipulable = isEditing && configuration == nil && !item.isPending && !add
        #if os(macOS)
        let edgeProgress = min(1, distance / max(1, size.width / 2))
        let viewportFade = catalog || isEditing ? 1 : 1 - edgeProgress * edgeProgress * (3 - 2 * edgeProgress)
        #endif

        return VStack(spacing: labelSpacing) {
            iconImage(add ? .system("plus.circle") : item.icon, size: 31, lit: lit)
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
                    } else if isEditing, item.isConfigurable {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .offset(x: 11, y: -2)
                    } else if !isEditing, item.badgeCount > 0 {
                        SlotCarouselNotificationBadge(
                            color: theme.destructive,
                            labelColor: theme.badgeText,
                            count: item.badgeCount,
                            dismissalToken: notificationDismissalToken,
                            isSelected: selected,
                            reduceMotion: reduceMotion
                        )
                        .offset(x: 10, y: -4)
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
            } else if configuration == nil {
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
                    if item.isConfigurable {
                        withAnimation(editorAnimation) {
                            showsCatalog = true
                            onConfigure(item.id)
                        }
                    }
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
            : (selected ? strings.selectedValue : strings.notSelectedValue))
        .accessibilityHint(isEditing && item.isConfigurable ? strings.configurableHint : item.accessibilityHint)
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
            if manipulable && role == .page { onRemove(item.id) }
        }
        .accessibilityAction(named: strings.changeSource) {
            if manipulable && role == .page && item.isConfigurable {
                showsCatalog = true
                onConfigure(item.id)
            }
        }
        .position(x: itemX, y: itemY)
        .zIndex(1 + zIndex)
        .animation(isEditing ? editorAnimation : nil, value: liftedItem?.insertion)
        .animation(isEditing ? editorAnimation : nil, value: liftedItem?.removes)
    }

    @ViewBuilder
    private func iconImage(_ icon: SlotNavigationIcon, size: CGFloat, lit: CGFloat) -> some View {
        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        case let .art(litName, unlitName):
            ZStack {
                Image(unlitName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(1 - lit)
                Image(litName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(lit)
                    .blendMode(.plusLighter)
            }
            .compositingGroup()
            .frame(width: size * Self.artScale, height: size * Self.artScale)
        }
    }

    private var catalogView: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = slotWidth(for: size.width)
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
                guard configuration == nil, liftedItem == nil else { return }
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
        let slot = slotWidth(for: width)
        let minimum = offset(for: max(availableItems.count - 1, 0), viewportWidth: width, slotWidth: slot)
        let maximum = offset(for: 0, viewportWidth: width, slotWidth: slot)
        catalogOffset = min(max(catalogOffset, minimum), maximum)
    }

    private func editorBoundedOffset(_ value: CGFloat, size: CGSize) -> CGFloat {
        let slot = slotWidth(for: size.width)
        let minimum = offset(for: items.count, viewportWidth: size.width, slotWidth: slot)
        let maximum = offset(for: -1, viewportWidth: size.width, slotWidth: slot)
        return min(max(value, minimum), maximum)
    }

    private func scrollEditor(_ value: DragGesture.Value, size: CGSize) {
        guard configuration == nil, liftedItem == nil else { return }
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
                guard isEditing, configuration == nil,
                      case let .second(true, drag?) = value else { return }
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
        lifted.removes = lifted.originalIndex != nil && localY < -16
        let column = (point.x - reelOffset) / slotWidth(for: size.width)
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
            iconImage(lifted.item.icon, size: 33, lit: 1)
                .frame(height: 42)
                .overlay(alignment: .topTrailing) {
                    if lifted.removes {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.destructive)
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

    private func configurationView(_ configuration: SlotNavigationConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(configuration.title)
                    .font(theme.typography.sectionTitle)
                Spacer()
                Button("Cancel", action: configuration.onCancel)
                    .font(theme.typography.buttonLabel)
                    .buttonStyle(TimeMasterActionButtonStyle())
                    .accessibilityIdentifier("navigation-source-cancel")
            }
            Text(configuration.message)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(configuration.choices) { choice in
                        Button { configuration.onSelect(choice.id) } label: {
                            Label {
                                Text(choice.title)
                            } icon: {
                                switch choice.icon {
                                case let .system(name):
                                    Image(systemName: name)
                                case .art:
                                    iconImage(choice.icon, size: 17, lit: 1)
                                }
                            }
                                .font(theme.typography.buttonLabel)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(TimeMasterActionButtonStyle())
                        .accessibilityIdentifier("navigation-source-choice-\(choice.id)")
                    }
                }
            }
        }
        .foregroundStyle(theme.textPrimary)
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
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
        let changed = onSelectionChanged
        return { index in
            guard !editing.wrappedValue, pages.indices.contains(index), index != current.wrappedValue else { return }
            changed(index)
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
                if !tracking, Self.isSideways(value.translation) { tracking = true }
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
            guard Self.isSideways(translation) else { return }
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
        onPageDragEnded()
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
        settle(
            on: index(for: reelOffset, viewportWidth: size.width, slotWidth: slotWidth),
            viewportWidth: size.width,
            slotWidth: slotWidth,
            projectedTranslation: 0
        )
        onPageDragEnded()
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

        onSelectionChanged(index)
        withAnimation(animation) {
            reelOffset = targetOffset
            hasMeasured = true
        }
        selection = index
    }

    private func slotWidth(for viewportWidth: CGFloat) -> CGFloat {
        min(max(viewportWidth.slotFinite() * 0.22, 76), 92)
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

private extension CGFloat {
    func slotFinite(_ fallback: CGFloat = 0) -> CGFloat {
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

private struct SlotCarouselNotificationBadge: View {
    let color: Color
    let labelColor: Color
    let count: Int
    let dismissalToken: Int
    let isSelected: Bool
    let reduceMotion: Bool

    @State private var tension: CGFloat = 0
    @State private var stretch: CGFloat = 0
    @State private var absorption: CGFloat = 0
    @State private var isHidden = false

    var body: some View {
        Group {
            if !isHidden {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.7), lineWidth: 0.7)
                        .frame(
                            width: 3 + (1 - stretch) * 2.5,
                            height: 3 + (1 - stretch) * 2.5
                        )
                        .offset(y: -stretch * 15)
                        .opacity(stretch * (1 - absorption))
                        .blur(radius: 0.25)

                    SlotSpaghettificationShape(progress: stretch)
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .scaleEffect(
                            x: 1 + tension * 0.07,
                            y: 1 - tension * 0.04
                        )
                        .shadow(
                            color: color.opacity(stretch * 0.32),
                            radius: 1.2,
                            x: 0,
                            y: -stretch * 3
                        )
                        .opacity(1 - absorption)

                    Text("\(min(count, 99))")
                        .font(TimeMasterFont.black(10, relativeTo: .caption2))
                        .dynamicTypeSize(.large)
                        .monospacedDigit()
                        .foregroundStyle(labelColor)
                        .opacity(max(0, 1 - stretch * 4))
                }
                .frame(width: 18, height: 18)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
        .task(id: isSelected ? dismissalToken : 0) {
            guard dismissalToken > 0, isSelected else { return }
            resetVisualState()

            if reduceMotion {
                withAnimation(.easeOut(duration: 0.16)) {
                    absorption = 1
                }
                try? await Task.sleep(nanoseconds: 160_000_000)
            } else {
                withAnimation(.easeOut(duration: 0.08)) {
                    tension = 1
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.easeIn(duration: 0.26)) {
                    tension = 0
                    stretch = 1
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.easeIn(duration: 0.14)) {
                    absorption = 1
                }
                try? await Task.sleep(nanoseconds: 140_000_000)
            }

            guard !Task.isCancelled else { return }
            isHidden = true
        }
        .onChange(of: isSelected) { selected in
            guard !selected else { return }
            resetVisualState()
        }
    }

    private func resetVisualState() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tension = 0
            stretch = 0
            absorption = 0
            isHidden = false
        }
    }
}

private struct SlotSpaghettificationShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let stretch = min(max(progress, 0), 1)
        guard stretch > 0.001 else {
            return Path(ellipseIn: rect)
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let verticalPull = radius * 1.65 * stretch
        let sideRadius = radius * (1 - 0.72 * stretch)
        let top = CGPoint(x: center.x, y: center.y - radius - verticalPull)
        let right = CGPoint(x: center.x + sideRadius, y: center.y - radius * 0.06 * stretch)
        let bottom = CGPoint(x: center.x, y: center.y + radius * (1 - 0.35 * stretch))
        let left = CGPoint(x: center.x - sideRadius, y: right.y)
        let curve = radius * 0.55228475
        let neck = curve * (1 - 0.85 * stretch)

        var path = Path()
        path.move(to: top)
        path.addCurve(
            to: right,
            control1: CGPoint(x: center.x + neck, y: top.y + verticalPull * 0.12),
            control2: CGPoint(x: right.x, y: center.y - curve * (1 - 0.28 * stretch))
        )
        path.addCurve(
            to: bottom,
            control1: CGPoint(x: right.x, y: center.y + curve * (1 - 0.52 * stretch)),
            control2: CGPoint(x: center.x + curve * (1 - 0.48 * stretch), y: bottom.y)
        )
        path.addCurve(
            to: left,
            control1: CGPoint(x: center.x - curve * (1 - 0.48 * stretch), y: bottom.y),
            control2: CGPoint(x: left.x, y: center.y + curve * (1 - 0.52 * stretch))
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: left.x, y: center.y - curve * (1 - 0.28 * stretch)),
            control2: CGPoint(x: center.x - neck, y: top.y + verticalPull * 0.12)
        )
        return path
    }
}

// MARK: - Surface

private struct SlotArcSurface: View {
    let theme: SlotNavigationTheme
    let edgeSafeArea: CGFloat
    let placement: SlotNavigationPlacement
    let curveOffset: CGFloat
    let expansion: CGFloat
    #if os(macOS)
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #endif

    var body: some View {
        let shape = SlotArcShape(edgeExtension: edgeSafeArea, placement: placement, curveOffset: curveOffset, expansion: expansion)
        #if os(macOS)
        glassSurface(shape)
        #else
        shape
            .fill(theme.surface)
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: -8 * placement.outwardSign)
            .overlay { rim }
        #endif
    }

    private var rim: some View {
        SlotArcLineShape(curveOffset: curveOffset, placement: placement, expansion: expansion)
            .stroke(theme.rim, lineWidth: 1)
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
