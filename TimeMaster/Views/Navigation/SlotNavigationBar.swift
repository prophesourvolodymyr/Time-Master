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
        Text(title)
            .font(theme.typography.editorTitle)
            .foregroundStyle(theme.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Quiet pill used by the editor's Cancel button, the source choices and the help glyph.
struct SlotNavigationQuietButtonStyle: ButtonStyle {
    let theme: SlotNavigationTheme
    var horizontalPadding: CGFloat = 12
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.buttonLabel)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(isEnabled ? theme.textPrimary : theme.textSecondary)
            .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 18, style: .circular))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width confirmation button used by the guide's "Got it".
struct SlotNavigationProminentButtonStyle: ButtonStyle {
    let theme: SlotNavigationTheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.buttonLabel)
            .foregroundStyle(isEnabled ? theme.onAccent : theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .background(
                isEnabled ? theme.accent : theme.controlSurface,
                in: RoundedRectangle(cornerRadius: 14, style: .circular)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Bar

struct SlotCarouselNavigationBar: View, Animatable {
    static let inlineHeight: CGFloat = 60
    static let fullHeight: CGFloat = 96
    static let fullBottomExtension: CGFloat = 32

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
    private let bottomSafeArea: CGFloat
    private let barHeight: CGFloat
    private var expansion: CGFloat
    private var editingAmount: CGFloat
    private let theme: SlotNavigationTheme
    private let strings: SlotNavigationStrings
    private let onSelectionChanged: (Int) -> Void
    private let onPageDrag: (CGFloat) -> Void
    private let onPageDragEnded: () -> Void

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
    @State private var notificationDismissalToken = 0

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
        bottomSafeArea: CGFloat = 0,
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
        onPageDragEnded: @escaping () -> Void = {}
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
        self.bottomSafeArea = max(0, bottomSafeArea)
        self.theme = theme
        self.strings = strings
        self.barHeight = max(Self.fullHeight, barHeight)
        self.expansion = layout == .full ? 1 : 0
        self.editingAmount = isEditing.wrappedValue ? 1 : 0
        self.onSelectionChanged = onSelectionChanged
        self.onPageDrag = onPageDrag
        self.onPageDragEnded = onPageDragEnded
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(expansion, editingAmount) }
        set { expansion = newValue.first; editingAmount = newValue.second }
    }

    private var expandedAmount: CGFloat { min(max(expansion, 0), 1) }
    private var effectiveDragIntensity: CGFloat { dragIntensity * expandedAmount }
    private var editProgress: CGFloat { reduceMotion ? 0 : min(max(editingAmount, 0), 1) }
    private var mainHeight: CGFloat { Self.inlineHeight + (barHeight - Self.inlineHeight) * expandedAmount }
    private var accessoryHeight: CGFloat {
        (isEditing && showsCatalog ? barHeight + 12 : 0)
            + (isEditing && configuration != nil ? 156 + 12 : 0)
    }
    private var editorAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.84)
    }
    private var curveOffset: CGFloat {
        #if os(iOS)
        8
        #else
        54
        #endif
    }

    var body: some View {
        VStack(spacing: 12) {
            if isEditing, let configuration {
                configurationView(configuration)
                    .frame(height: 156)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if isEditing, showsCatalog {
                catalogView
                    .frame(height: barHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            mainArc
                .frame(height: mainHeight)
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carousel-navigation")
        .accessibilityValue(isEditing ? strings.editingValue : (expandedAmount < 0.5 ? strings.compactValue : strings.expandedValue))
        .accessibilityAction(named: isEditing ? strings.doneEditing : strings.editNavigation) {
            if isEditing {
                onEditingEnded()
            } else if expandedAmount == 1 {
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
        .onDisappear { cancelLift() }
    }

    private var mainArc: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = slotWidth(for: size.width)
            let arcRect = CGRect(origin: .zero, size: size)
            let centeredOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
            let displayOffset = hasMeasured ? reelOffset : centeredOffset
            let arcScaleX = 1 + effectiveDragIntensity * 0.15 + editProgress * 0.12
            let arcScaleY = 1 + effectiveDragIntensity * 0.35 + editProgress * 0.25

            ZStack {
                SlotArcSurface(theme: theme, bottomSafeArea: bottomSafeArea, curveOffset: curveOffset, expansion: expandedAmount)
                    .scaleEffect(x: arcScaleX, y: arcScaleY, anchor: .bottom)
                    .offset(y: -24 * editProgress)
                    .allowsHitTesting(false)

                ForEach(items.indices, id: \.self) { index in
                    slotView(item: items[index], index: index, offset: displayOffset,
                             size: size, arcRect: arcRect, slotWidth: slotWidth)
                }
                if isEditing {
                    slotView(item: SlotNavigationItem(id: "navigation.add.begin", symbolName: "plus", title: strings.addItemTitle),
                             index: -1, offset: displayOffset, size: size, arcRect: arcRect,
                             slotWidth: slotWidth, role: .prepend)
                    slotView(item: SlotNavigationItem(id: "navigation.add.end", symbolName: "plus", title: strings.addItemTitle),
                             index: visibleItemCount, offset: displayOffset, size: size, arcRect: arcRect,
                             slotWidth: slotWidth, role: .append)
                }
                if let liftedItem {
                    liftedIcon(liftedItem)
                        .position(x: liftedItem.center.x, y: liftedItem.center.y - accessoryHeight)
                        .transaction { $0.animation = nil }
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size, slotWidth: slotWidth, fallbackOffset: centeredOffset))
            .onAppear {
                if !hasMeasured {
                    reelOffset = centeredOffset
                    hasMeasured = true
                }
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
                let nextOffset = offset(for: newSelection, viewportWidth: size.width, slotWidth: slotWidth)
                guard abs(reelOffset - nextOffset) > 0.5 else { return }
                withAnimation(selectionAnimation) { reelOffset = nextOffset }
            }
            .onChange(of: isEditing) { editing in
                cancelLift()
                isDragging = false
                dragIntensity = 0
                if !editing {
                    withAnimation(selectionAnimation) {
                        reelOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
                    }
                }
            }
            .onChange(of: items.count) { _ in
                guard isEditing, liftedItem == nil else { return }
                withAnimation(editorAnimation) { reelOffset = editorBoundedOffset(reelOffset, size: size) }
            }
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
        let iconSize = baseIconSize + intensity * (expandedIconSize - baseIconSize) + (add ? 8 : 0)
        let baseScale = 0.88 + 0.18 * focus
        let expandedScale = max(0.4, 1.2 - norm * 0.35)
        let itemScale = (baseScale + intensity * (expandedScale - baseScale)) * (1 + (catalog ? 0 : editProgress) * 0.12)
        let baseOpacity = 0.28 + 0.72 * proximity
        let expandedOpacity = max(0.1, 1 - norm * 0.55)
        let normalOpacity = baseOpacity + intensity * (expandedOpacity - baseOpacity)
        let itemOpacity = normalOpacity + styleEdit * (max(normalOpacity, 0.72) - normalOpacity)
        let baseLabelOpacity = focus * focus
        let expandedLabelOpacity = max(0, bubbleFactor * 2 - 0.6)
        let normalLabelOpacity = baseLabelOpacity + intensity * (expandedLabelOpacity - baseLabelOpacity)
        let labelOpacity = normalLabelOpacity + styleEdit * (1 - normalLabelOpacity)
        let verticalOffset = intensity * max(-40, -40 + norm * 34)
        let arcY = catalog
            ? SlotArcGeometry.curveY(at: itemX, in: arcRect, curveOffset: curveOffset, expansion: 1)
            : transformedArcY(at: itemX, in: arcRect)
        let itemHeight = Self.inlineHeight + 30 * amount + intensity * 24
        let iconFrameHeight = 28 + 14 * amount + intensity * max(0, expandedIconSize - 42)
        let zIndex = max(0, focus + intensity * (1 - min(norm, 10) - focus))
        let compactY = Self.inlineHeight / 2 - 4
        let expandedY = arcY + 56 - itemHeight / 2 + verticalOffset
        let itemY = compactY + (expandedY - compactY) * amount
        let rootY = catalog ? accessoryHeight - barHeight - 12 + itemY : accessoryHeight + itemY
        let selected = role == .page && selection == index
        let manipulable = isEditing && configuration == nil && !item.isPending && !add

        return VStack(spacing: 4) {
            Image(systemName: add ? "plus.circle" : item.symbolName)
                .font(.system(size: 31, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(add ? theme.success : theme.textPrimary)
                .scaleEffect(iconSize / 31)
                .frame(height: iconFrameHeight)
                .overlay(alignment: .topTrailing) {
                    if catalog {
                        Image(systemName: item.isPending ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.isPending ? theme.textSecondary : theme.success)
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
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 15)
                .opacity(labelOpacity)
                .accessibilityHidden(true)
        }
        .frame(width: slotWidth, height: itemHeight, alignment: .bottom)
        .scaleEffect(itemScale, anchor: .bottom)
        .opacity(liftedItem?.item.id == item.id ? 0 : (item.isPending ? (catalog ? 0.55 : 0.4) : itemOpacity))
        .contentShape(Rectangle())
        .onTapGesture {
            guard liftedItem == nil, !item.isPending else { return }
            if !isEditing {
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

    private var catalogView: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = slotWidth(for: size.width)
            let initial = offset(for: 0, viewportWidth: size.width, slotWidth: slotWidth)
            ZStack {
                SlotArcSurface(theme: theme, bottomSafeArea: 0, curveOffset: curveOffset, expansion: 1)
                    .allowsHitTesting(false)
                ForEach(availableItems.indices, id: \.self) { index in
                    slotView(item: availableItems[index], index: index,
                             offset: catalogHasMeasured ? catalogOffset : initial,
                             size: size, arcRect: CGRect(origin: .zero, size: size),
                             slotWidth: slotWidth, role: .catalog)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8).onChanged { value in
                guard configuration == nil, liftedItem == nil else { return }
                if !catalogIsScrolling {
                    catalogIsScrolling = true
                    catalogStartOffset = catalogOffset
                }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { catalogOffset = catalogStartOffset + value.translation.width }
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
        withTransaction(transaction) { reelOffset = dragStartOffset + value.translation.width }
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
                        grabOffset: CGSize(width: drag.startLocation.x - center.x, height: drag.startLocation.y - center.y),
                        location: drag.location, insertion: index
                    )
                }
                updateLift(location: drag.location, size: size)
            }
            .onEnded { value in
                guard case let .second(true, drag?) = value else { cancelLift(); return }
                updateLift(location: drag.location, size: size)
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
        let localY = point.y - accessoryHeight
        lifted.removes = lifted.originalIndex != nil && localY < -16
        if !lifted.removes, localY >= -8, localY <= size.height + 32,
           point.x >= -24, point.x <= size.width + 24 {
            let remaining = items.count - (lifted.originalIndex == nil ? 0 : 1)
            let raw = Int(floor((point.x - reelOffset) / slotWidth(for: size.width)))
            lifted.insertion = min(max(raw, 0), max(remaining, 0))
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
            Image(systemName: lifted.item.symbolName)
                .font(.system(size: 33, weight: .semibold))
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
                .font(.system(size: 11, weight: .bold, design: .rounded))
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
                    .buttonStyle(SlotNavigationQuietButtonStyle(theme: theme))
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
                            Label(choice.title, systemImage: choice.symbolName)
                                .font(theme.typography.buttonLabel)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(SlotNavigationQuietButtonStyle(theme: theme))
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
        let scaleX = 1 + effectiveDragIntensity * 0.15 + editProgress * 0.12
        let scaleY = 1 + effectiveDragIntensity * 0.35 + editProgress * 0.25
        let centerX = rect.midX
        let arcSampleX = centerX + (x - centerX) / scaleX
        let unscaledY = SlotArcGeometry.curveY(at: arcSampleX, in: rect, curveOffset: curveOffset, expansion: expandedAmount)
        return rect.maxY - (rect.maxY - unscaledY) * scaleY - 24 * editProgress
    }

    private var selectionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .interpolatingSpring(stiffness: 260, damping: 28)
    }

    private var dragExpansionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.18)
    }

    private var dragWindDownAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.24)
    }

    private func dragGesture(size: CGSize, slotWidth: CGFloat, fallbackOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                if isEditing {
                    scrollEditor(value, size: size)
                    return
                }
                if !isDragging {
                    isDragging = true
                    dragStartOffset = hasMeasured ? reelOffset : fallbackOffset
                    withAnimation(dragExpansionAnimation) {
                        dragIntensity = reduceMotion ? 0 : 1
                    }
                }
                let rawOffset = dragStartOffset + value.translation.width
                let boundedOffset = rubberBand(
                    rawOffset,
                    minimum: minimumOffset(viewportWidth: size.width, slotWidth: slotWidth),
                    maximum: maximumOffset(viewportWidth: size.width, slotWidth: slotWidth)
                )
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { reelOffset = boundedOffset }
                onPageDrag((offset(for: 0, viewportWidth: size.width, slotWidth: slotWidth) - boundedOffset) / slotWidth)
            }
            .onEnded { value in
                if isEditing {
                    finishEditorScroll(size: size)
                    return
                }
                let projectedOffset = dragStartOffset + value.predictedEndTranslation.width
                let targetIndex = index(
                    for: projectedOffset,
                    viewportWidth: size.width,
                    slotWidth: slotWidth
                )
                isDragging = false
                withAnimation(dragWindDownAnimation) { dragIntensity = 0 }
                settle(
                    on: targetIndex,
                    viewportWidth: size.width,
                    slotWidth: slotWidth,
                    projectedTranslation: value.predictedEndTranslation.width - value.translation.width
                )
                onPageDragEnded()
            }
    }

    private func settle(
        on index: Int,
        viewportWidth: CGFloat,
        slotWidth: CGFloat,
        projectedTranslation: CGFloat
    ) {
        guard items.indices.contains(index) else { return }
        let targetOffset = offset(for: index, viewportWidth: viewportWidth, slotWidth: slotWidth)
        let currentOffset = hasMeasured ? reelOffset : targetOffset
        let remainingDistance = max(abs(targetOffset - currentOffset), 1)
        let normalizedVelocity = projectedTranslation / remainingDistance
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
        min(max(viewportWidth * 0.22, 76), 92)
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
        guard !items.isEmpty else { return 0 }
        let boundedOffset = min(
            max(proposedOffset, minimumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)),
            maximumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)
        )
        let rawIndex = (viewportWidth / 2 - slotWidth / 2 - boundedOffset) / slotWidth
        return min(max(Int(rawIndex.rounded()), 0), items.count - 1)
    }

    private func rubberBand(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        if value < minimum { return minimum - (minimum - value) * 0.22 }
        if value > maximum { return maximum + (value - maximum) * 0.22 }
        return value
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
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
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
    let bottomSafeArea: CGFloat
    let curveOffset: CGFloat
    let expansion: CGFloat

    var body: some View {
        let shape = SlotArcShape(bottomExtension: bottomSafeArea, curveOffset: curveOffset, expansion: expansion)
        shape
            .fill(theme.surface)
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: -8)
            .overlay {
                SlotArcLineShape(curveOffset: curveOffset, expansion: expansion)
                    .stroke(theme.rim, lineWidth: 1)
            }
    }
}
