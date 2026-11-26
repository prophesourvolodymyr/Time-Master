// SlotNavigationContainer.swift
//
// Hosts the pages, the curved bar, the page wheel and the navigation gestures. Pages live in the page deck, which
// answers every switch at once with the page's shell and builds the real page behind it half way through the slide.
// Pulling the bar up turns it into the wheel; swiping in from either edge of a root page brings the page beside it on
// the bar with the same slide; inside a pushed page the left edge goes back.

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SlotCarouselNavigation<Content: View>: View {
    @Binding private var selection: String?
    private let items: [SlotNavigationItem]
    private let availableItems: [SlotNavigationItem]
    private let badges: SlotNavigationBadges
    private let wheel: PageWheelController
    private let onInsert: (String, Int) -> Void
    private let onMove: (String, Int) -> Void
    private let onRemove: (String) -> Void
    private let onEditingEnded: () -> Void
    private let onOpenSearchTarget: (NavigationSearchTarget) -> Void
    private let barHeight: CGFloat
    private let guideDefaultsKey: String
    private let theme: SlotNavigationTheme
    private let strings: SlotNavigationStrings
    private let page: (String) -> Content

    @AppStorage("tm.navigation.placement") private var navigationPlacement = SlotNavigationPlacement.bottom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var requestedPresentation: SlotNavigationPresentation?
    @State private var contentDisablesInteraction = false
    @State private var contentPrefersStrip = false
    @State private var hiddenNavigation = SlotNavigationOverlayState()
    @State private var hiddenNavigationDismissTask: Task<Void, Never>?
    @State private var isEditing = false
    @State private var showsCatalog = false
    @State private var hasSeenGuide: Bool
    @State private var showsGuide = false
    @State private var interaction = SlotNavigationInteraction()
    @State private var pageSwipesDisabled = false
    @State private var reachabilityIsActive = false
    @State private var navigationIsExpanded = false
    @State private var navigationManuallyHidden = false
    @State private var wheelIsActive = false
    @State private var globalFrame = CGRect.zero
    @State private var deck: PageDeck

    init(
        selection: Binding<String?>,
        items: [SlotNavigationItem],
        availableItems: [SlotNavigationItem] = [],
        badges: SlotNavigationBadges,
        wheel: PageWheelController,
        onInsert: @escaping (String, Int) -> Void = { _, _ in },
        onMove: @escaping (String, Int) -> Void = { _, _ in },
        onRemove: @escaping (String) -> Void = { _ in },
        onEditingEnded: @escaping () -> Void = {},
        onOpenSearchTarget: @escaping (NavigationSearchTarget) -> Void = { _ in },
        barHeight: CGFloat = SlotCarouselNavigationBar.fullHeight,
        guideDefaultsKey: String = "tm.navigation.editorGuideSeen",
        theme: SlotNavigationTheme = .timeMaster,
        strings: SlotNavigationStrings = .timeMaster,
        @ViewBuilder page: @escaping (String) -> Content
    ) {
        _selection = selection
        self.items = items
        self.availableItems = availableItems
        self.badges = badges
        self.wheel = wheel
        self.onInsert = onInsert
        self.onMove = onMove
        self.onRemove = onRemove
        self.onEditingEnded = onEditingEnded
        self.onOpenSearchTarget = onOpenSearchTarget
        self.barHeight = max(SlotCarouselNavigationBar.fullHeight, barHeight)
        self.guideDefaultsKey = guideDefaultsKey
        self.theme = theme
        self.strings = strings
        self.page = page
        _hasSeenGuide = State(initialValue: UserDefaults.standard.bool(forKey: guideDefaultsKey))
        _deck = State(initialValue: PageDeck(page: selection.wrappedValue ?? items.first?.id ?? ""))
    }

    private var order: [String] { items.map(\.id) }

    var body: some View {
        GeometryReader { proxy in
            let presentation = effectivePresentation
            let frame = proxy.frame(in: .global)
            let layout = barLayout
            let restingLayout = SlotNavigationBarLayout.resolve(
                isExpanded: false, isEditing: false, isOverlayVisible: false, prefersInline: contentPrefersStrip
            )
            let barExtent = SlotCarouselNavigationBar.contentHeight(for: layout, barHeight: barHeight)
            let showsNavigation = presentation != .hidden || hiddenNavigation.isVisible
            let restoreHeight: CGFloat = navigationManuallyHidden && navigationInteractionEnabled
                && defaultPresentation != .hidden ? 24 : 0
            let reservedHeight = presentation == .hidden
                ? restoreHeight : SlotCarouselNavigationBar.contentHeight(for: restingLayout, barHeight: barHeight)
            let contentBounds = navigationPlacement.contentBounds(in: frame, reservedHeight: reservedHeight)
            let pageGesturesEnabled = navigationInteractionEnabled && !isEditing && !pageSwipesDisabled
                && !reachabilityIsActive && !wheelIsActive

            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    PageDeckShells(deck: deck)
                    PageDeckPages(roster: deck.roster, deck: deck, order: order, page: page)
                }
                .environment(\.slotNavigationContentBounds, contentBounds)
                .environment(\.slotNavigationArcFrame, restingLayout == .full && showsNavigation
                    && !isEditing && !wheelIsActive && !reduceMotion && !reduceTransparency && !lowPower && scenePhase == .active
                    ? CGRect(
                        x: frame.minX,
                        y: navigationPlacement == .bottom ? frame.maxY - barHeight : frame.minY,
                        width: proxy.size.width,
                        height: barHeight
                    ) : .zero)
                .animation(nil, value: selection)
                .blur(radius: isEditing && !reduceTransparency ? 11 : 0)
                .opacity(isEditing ? 0.48 : 1)
                .allowsHitTesting(!isEditing && !wheelIsActive)
                .accessibilityHidden(isEditing || wheelIsActive)
                .safeAreaInset(edge: navigationPlacement == .bottom ? .bottom : .top, spacing: 0) {
                    Color.clear
                        .frame(height: reservedHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                #if os(iOS)
                .background {
                    SlotPageGestureBridge(
                        swipesPages: pageGesturesEnabled,
                        revealsNavigation: pageGesturesEnabled && presentation == .hidden && !hiddenNavigation.isVisible,
                        pageIndex: items.firstIndex(where: { $0.id == selection }),
                        pageCount: items.count,
                        barExtent: showsNavigation ? barExtent : restoreHeight,
                        placement: navigationPlacement,
                        onSwipeBegan: pageSwipeBegan,
                        onSwipe: pageSwipeChanged,
                        onSwipeEnded: pageSwipeEnded,
                        onReveal: revealHiddenNavigation
                    )
                }
                #else
                .simultaneousGesture(pageSwipeGesture(in: proxy.size), including: pageGesturesEnabled ? .all : .subviews)
                .simultaneousGesture(hiddenNavigationRevealGesture(in: proxy.size), including: pageGesturesEnabled ? .all : .subviews)
                #endif
                .simultaneousGesture(contentNavigationDismissGesture, including: navigationIsExpanded && !isEditing ? .all : .subviews)

                if isEditing {
                    theme.scrim.opacity(reduceTransparency ? 1 : theme.scrimOpacity)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: finishEditing)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .overlay(alignment: .bottom) {
                if navigationPlacement == .bottom {
                    navigationOverlay(in: proxy, frame: frame, layout: layout, showsNavigation: showsNavigation,
                                      restoreHeight: restoreHeight)
                        .keyNavRole(.excluded)
                        .keyNavObstruction()
                        .transition(navigationPresentationTransition(edge: .bottom))
                }
            }
            .overlay(alignment: .top) {
                if navigationPlacement == .top {
                    navigationOverlay(in: proxy, frame: frame, layout: layout, showsNavigation: showsNavigation,
                                      restoreHeight: restoreHeight)
                        .keyNavRole(.excluded)
                        .keyNavObstruction()
                        .transition(navigationPresentationTransition(edge: .top))
                }
            }
            .overlay {
                if isEditing {
                    editingGuideOverlay(size: proxy.size)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .overlay {
                PageWheelOverlay(wheel: wheel, badges: badges, theme: theme)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .keyNavYield(isEditing || wheelIsActive)
            .everEscapeClaim("navigation-editing", isActive: isEditing, perform: finishEditing)
            .everEscapeClaim("page-wheel", isActive: wheelIsActive, perform: wheel.dismiss)
            .onAppear {
                globalFrame = frame
                prepare(size: proxy.size)
            }
            .onChange(of: proxy.size) { size in
                globalFrame = proxy.frame(in: .global)
                prepare(size: size)
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                keyboardChanged(note, hiding: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
                keyboardChanged(note, hiding: true)
            }
            #endif
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .onDisappear {
                hiddenNavigationDismissTask?.cancel()
                finishEditing()
                wheel.dismiss()
            }
            .onChange(of: isEditing) { editing in
                if editing {
                    showsGuide = !hasSeenGuide
                } else {
                    markGuideSeen()
                    showsGuide = false
                }
            }
            .onChange(of: selection) { [selection] destination in
                if let selection, let destination, selection != destination, !interaction.barSelects {
                    AppInteractionHaptics.shared.selectionChanged()
                }
                interaction.barSelects = false
                if let destination, deck.target != destination || deck.isResting {
                    deck.go(to: destination, order: order)
                }
                badges.pageShown(destination)
                hiddenNavigationDismissTask?.cancel()
                withAnimation(presentationAnimation) {
                    requestedPresentation = nil
                    navigationIsExpanded = false
                    navigationManuallyHidden = false
                    if defaultPresentation != .hidden {
                        hiddenNavigation.dismiss()
                    }
                }
                if effectivePresentation == .hidden, hiddenNavigation.isVisible {
                    hiddenNavigation.interactionChanged(interaction.isActive || isEditing, at: .now)
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onChange(of: items) { next in
                wheel.update(items: next)
            }
            .onChange(of: navigationInteractionEnabled) { enabled in
                if !enabled {
                    finishEditing()
                    wheel.dismiss()
                    hiddenNavigationDismissTask?.cancel()
                    hiddenNavigation.dismiss()
                    navigationManuallyHidden = false
                    navigationIsExpanded = false
                    interaction.isActive = false
                    interaction.pageIsDragging = false
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    AppInteractionHaptics.shared.suspend()
                    hiddenNavigationDismissTask?.cancel()
                    navigationIsExpanded = false
                    interaction.isActive = false
                    if interaction.pageIsDragging {
                        interaction.pageIsDragging = false
                        deck.cancelDrag()
                    }
                } else if effectivePresentation == .hidden, hiddenNavigation.isVisible {
                    hiddenNavigation.interactionChanged(interaction.isActive || isEditing, at: .now)
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onChange(of: reduceMotion) { reduce in
                deck.reduceMotion = reduce
                wheel.reduceMotion = reduce
            }
            .onPreferenceChange(SlotNavigationInteractionDisabledPreferenceKey.self) { disabled in
                contentDisablesInteraction = disabled
                #if os(iOS)
                SlotBackSwipe.isBlocked = disabled
                #endif
            }
            .onPreferenceChange(SlotNavigationEditingPreferenceKey.self) { pageSwipesDisabled = $0 }
            .onPreferenceChange(ReachabilityActivePreferenceKey.self) { reachabilityIsActive = $0 }
            .onPreferenceChange(SlotNavigationStripPreferenceKey.self) { contentPrefersStrip = $0 }
            .onPreferenceChange(SlotNavigationPresentationPreferenceKey.self) { requested in
                applyPresentation(requested)
            }
            .animation(presentationAnimation, value: effectivePresentation)
            .animation(presentationAnimation, value: isEditing)
            .animation(presentationAnimation, value: navigationIsExpanded)
            .animation(presentationAnimation, value: navigationPlacement)
            .animation(presentationAnimation, value: layout)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: strings.showNavigation) {
                guard navigationInteractionEnabled else { return }
                if effectivePresentation == .hidden {
                    revealHiddenNavigation()
                } else {
                    withAnimation(presentationAnimation) { navigationIsExpanded = true }
                }
            }
            .accessibilityAction(named: strings.openWheel) { openWheel(searching: false) }
            .accessibilityAction(named: "Collapse navigation", collapseNavigation)
            .accessibilityAction(named: strings.editNavigation, beginEditing)
        }
        .ignoresSafeArea(.keyboard, edges: wheelIsActive ? .bottom : [])
    }

    @ViewBuilder
    private func navigationOverlay(
        in proxy: GeometryProxy,
        frame: CGRect,
        layout: SlotNavigationBarLayout,
        showsNavigation: Bool,
        restoreHeight: CGFloat
    ) -> some View {
        if showsNavigation {
            SlotNavigationBarGestures(
                placement: navigationPlacement,
                isEnabled: !isEditing,
                pullsWheel: !isEditing && !items.isEmpty,
                reduceMotion: reduceMotion,
                onDismiss: hideNavigation,
                onPull: { pull in wheelPulled(pull, origin: frame.origin) },
                bar: SlotCarouselNavigationBar(
                    selection: normalSelection,
                    items: items,
                    badges: badges,
                    placement: navigationPlacement,
                    edgeSafeArea: navigationPlacement == .bottom ? proxy.safeAreaInsets.bottom : proxy.safeAreaInsets.top,
                    theme: theme,
                    strings: strings,
                    barHeight: barHeight,
                    layout: layout,
                    isEditing: $isEditing,
                    showsCatalog: $showsCatalog,
                    availableItems: availableItems,
                    onInsert: onInsert,
                    onMove: onMove,
                    onRemove: onRemove,
                    onEditingEnded: finishEditing,
                    isWheelPulling: { [wheel] in wheel.phase == .pulling },
                    onOpenWheel: { openWheel(searching: false) },
                    onWheelPull: macWheelPulled,
                    onPageDrag: reelScrubbed,
                    onPageDragEnded: reelReleased,
                    onInteractionChanged: navigationInteractionChanged
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.56, maximumDistance: 18)
                        .onEnded { _ in beginEditing() },
                    including: !isEditing ? .all : .subviews
                )
            )
            .opacity(wheelIsActive ? 0 : 1)
            .allowsHitTesting(!wheelIsActive || wheel.phase == .pulling)
            .accessibilityAction(named: "Hide navigation", hideNavigation)
            .transition(navigationPresentationTransition(edge: navigationPlacement.edge))
        } else if restoreHeight > 0 {
            Button(action: revealHiddenNavigation) {
                Image(systemName: navigationPlacement == .bottom ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: restoreHeight)
                    .background(theme.background)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .accessibilityLabel("Show navigation")
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        guard value.translation.height * navigationPlacement.outwardSign < -40,
                              abs(value.translation.height) > abs(value.translation.width) * 1.3 else { return }
                        revealHiddenNavigation()
                    }
            )
        }
    }

    private var normalSelection: Binding<Int> {
        Binding(
            get: { items.firstIndex(where: { $0.id == selection }) ?? 0 },
            set: { index in
                guard !isEditing, items.indices.contains(index) else { return }
                guard selection != items[index].id else { return }
                hiddenNavigationDismissTask?.cancel()
                if items[index].presentation == .hidden {
                    hiddenNavigation.reveal(at: .now, interacting: interaction.isActive)
                } else {
                    hiddenNavigation.dismiss()
                }
                interaction.barSelects = true
                selection = items[index].id
            }
        )
    }

    // MARK: Wheel

    private func prepare(size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        wheel.bounds = bounds
        wheel.arc = SlotCarouselNavigationBar.wheelArc(in: bounds, barHeight: barHeight, placement: navigationPlacement)
        wheel.reduceMotion = reduceMotion
        wheel.update(items: items)
        deck.reduceMotion = reduceMotion
        let deck = deck
        let wheel = wheel
        let selection = $selection
        let interaction = interaction
        let open = onOpenSearchTarget
        wheel.onPreview = { id in deck.go(to: id, order: wheel.items.map(\.id)) }
        wheel.onCommit = { id in
            guard selection.wrappedValue != id else { return }
            interaction.barSelects = true
            selection.wrappedValue = id
        }
        wheel.onCancel = {
            guard let current = selection.wrappedValue, deck.target != current else { return }
            deck.go(to: current, order: wheel.items.map(\.id))
        }
        wheel.onOpenTarget = { target in
            interaction.barSelects = true
            open(target)
        }
        wheel.onPhaseChange = { phase in
            let active = phase != .closed
            if wheelIsActive != active { wheelIsActive = active }
        }
    }

    private func openWheel(searching: Bool) {
        guard navigationInteractionEnabled, !items.isEmpty else { return }
        finishEditing()
        wheel.present(selection: items.firstIndex(where: { $0.id == selection }) ?? 0, searching: searching)
    }

    private func wheelPulled(_ pull: SlotNavigationPull, origin: CGPoint) {
        guard navigationInteractionEnabled else { return }
        switch pull {
        case .began:
            wheel.beginPull(selection: items.firstIndex(where: { $0.id == selection }) ?? 0)
        case let .changed(translation, location):
            wheel.pull(translation: translation, location: CGPoint(x: location.x - origin.x, y: location.y - origin.y))
        case let .ended(translation, predicted):
            wheel.endPull(translation: translation, predicted: predicted)
        case .cancelled:
            wheel.endPull(translation: .zero, predicted: .zero)
        }
    }

    /// A two-finger swipe up over the bar on the Mac: the same pull, measured in points of finger travel.
    private func macWheelPulled(_ pull: SlotReelWheelPull) {
        guard navigationInteractionEnabled, !isEditing else { return }
        let center = CGPoint(x: wheel.bounds.midX, y: wheel.bounds.midY)
        switch pull {
        case .began:
            wheel.beginPull(selection: items.firstIndex(where: { $0.id == selection }) ?? 0)
        case .changed(let upward):
            wheel.pull(translation: CGSize(width: 0, height: -upward * 1.6), location: center)
        case .ended(let upward):
            wheel.endPull(translation: CGSize(width: 0, height: -upward * 1.6), predicted: CGSize(width: 0, height: -upward * 2.2))
        }
    }

    #if os(iOS)
    private func keyboardChanged(_ note: Notification, hiding: Bool) {
        guard wheelIsActive else {
            if wheel.keyboardTop != nil { wheel.keyboardTop = nil }
            return
        }
        let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let visible = !hiding && end.height >= 60 && end.minY < globalFrame.maxY
        let top: CGFloat? = visible ? end.minY - globalFrame.minY : nil
        guard top != wheel.keyboardTop else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
            wheel.keyboardTop = top
        }
    }
    #endif

    // MARK: Deck

    private func reelScrubbed(_ position: CGFloat) {
        guard !wheelIsActive else { return }
        interaction.pageIsDragging = true
        deck.scrub(to: position, order: order)
    }

    private func reelReleased(_ landing: Int?) {
        guard interaction.pageIsDragging else { return }
        interaction.pageIsDragging = false
        let index = landing ?? items.firstIndex(where: { $0.id == selection }) ?? 0
        guard items.indices.contains(index) else { return }
        deck.go(to: items[index].id, order: order)
    }

    private func pageSwipeBegan(_ neighbour: Int, _ direction: CGFloat) {
        guard items.indices.contains(neighbour) else { return }
        interaction.pageIsDragging = true
        deck.beginDrag(to: items[neighbour].id, direction: direction)
    }

    private func pageSwipeChanged(_ fraction: CGFloat) {
        guard interaction.pageIsDragging else { return }
        deck.drag(fraction: fraction)
    }

    private func pageSwipeEnded(_ destination: Int?) {
        guard interaction.pageIsDragging else { return }
        interaction.pageIsDragging = false
        guard let destination, !isEditing, !reachabilityIsActive, items.indices.contains(destination) else {
            deck.cancelDrag()
            return
        }
        AppInteractionHaptics.shared.settled()
        deck.go(to: items[destination].id, order: order)
        interaction.barSelects = true
        selection = items[destination].id
    }

    // MARK: Presentation

    private func beginEditing() {
        guard navigationInteractionEnabled, !isEditing, !wheelIsActive else { return }
        hiddenNavigationDismissTask?.cancel()
        withAnimation(presentationAnimation) {
            navigationManuallyHidden = false
            if effectivePresentation == .hidden {
                hiddenNavigation.reveal(at: .now, interacting: true)
            }
            navigationIsExpanded = true
            isEditing = true
        }
    }

    private var navigationInteractionEnabled: Bool {
        !contentDisablesInteraction
    }

    private var effectivePresentation: SlotNavigationPresentation {
        guard navigationInteractionEnabled else { return .hidden }
        if items.isEmpty { return .visible }
        if navigationManuallyHidden { return .hidden }
        return requestedPresentation ?? defaultPresentation
    }

    private var defaultPresentation: SlotNavigationPresentation {
        guard let selected = selection,
              let item = items.first(where: { $0.id == selected }) else {
            return .visible
        }
        return item.presentation
    }

    private var presentationAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)
    }

    private func navigationPresentationTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    private var barLayout: SlotNavigationBarLayout {
        SlotNavigationBarLayout.resolve(
            isExpanded: navigationIsExpanded,
            isEditing: isEditing,
            isOverlayVisible: hiddenNavigation.isVisible,
            prefersInline: contentPrefersStrip
        )
    }

    private func applyPresentation(_ requested: SlotNavigationPresentation?) {
        guard requestedPresentation != requested else { return }
        if requested == .hidden { finishEditing() }
        hiddenNavigationDismissTask?.cancel()
        withAnimation(presentationAnimation) {
            requestedPresentation = requested
            navigationManuallyHidden = false
            navigationIsExpanded = false
            if effectivePresentation != .hidden {
                hiddenNavigation.dismiss()
            }
        }
        if effectivePresentation == .hidden, hiddenNavigation.isVisible {
            hiddenNavigation.interactionChanged(interaction.isActive || isEditing, at: .now)
            scheduleHiddenNavigationDismissal()
        }
    }

    private var contentNavigationDismissGesture: some Gesture {
        TapGesture()
            .onEnded { collapseNavigation() }
            .simultaneously(with:
                DragGesture(minimumDistance: 12)
                    .onChanged { _ in collapseNavigation() }
            )
    }

    private func collapseNavigation() {
        guard navigationIsExpanded, !interaction.isActive, !isEditing else { return }
        withAnimation(presentationAnimation) { navigationIsExpanded = false }
    }

    private func navigationInteractionChanged(_ active: Bool) {
        interaction.isActive = active && navigationInteractionEnabled
        if active {
            AppInteractionHaptics.shared.prepareSelection()
            hiddenNavigationDismissTask?.cancel()
        }
        if hiddenNavigation.isVisible {
            hiddenNavigation.interactionChanged(active || isEditing, at: .now)
        }
        if !active, effectivePresentation == .hidden {
            scheduleHiddenNavigationDismissal()
        }
    }

    private func hideNavigation() {
        hiddenNavigationDismissTask?.cancel()
        interaction.isActive = false
        withAnimation(presentationAnimation) {
            navigationManuallyHidden = true
            hiddenNavigation.dismiss()
            navigationIsExpanded = false
        }
    }

    #if !os(iOS)
    private func hiddenNavigationRevealGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onEnded { value in
                guard effectivePresentation == .hidden,
                      !hiddenNavigation.isVisible,
                      SlotNavigationOverlayState.acceptsReveal(
                        start: value.startLocation, translation: value.translation,
                        viewportHeight: size.height
                      ) else {
                    return
                }
                revealHiddenNavigation()
            }
    }

    private func pageSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isEditing, !reachabilityIsActive,
                      let index = items.firstIndex(where: { $0.id == selection }) else { return }
                if let swipe = SlotPageSwipeGeometry.swipe(
                    index: index, count: items.count, start: value.startLocation,
                    translation: value.translation, width: size.width
                ) {
                    if !interaction.pageIsDragging { pageSwipeBegan(swipe.neighbour, swipe.direction) }
                    pageSwipeChanged(swipe.fraction)
                } else if interaction.pageIsDragging {
                    pageSwipeEnded(nil)
                }
            }
            .onEnded { value in
                let index = items.firstIndex(where: { $0.id == selection })
                pageSwipeEnded(index.flatMap {
                    SlotPageSwipeGeometry.destination(
                        index: $0, count: items.count, start: value.startLocation, translation: value.translation,
                        projectedWidth: value.predictedEndTranslation.width, width: size.width
                    )
                })
            }
    }
    #endif

    private func revealHiddenNavigation() {
        guard navigationInteractionEnabled, effectivePresentation == .hidden else { return }
        hiddenNavigationDismissTask?.cancel()
        withAnimation(presentationAnimation) {
            navigationManuallyHidden = false
            navigationIsExpanded = false
            if effectivePresentation == .hidden {
                hiddenNavigation.reveal(at: .now, interacting: interaction.isActive || isEditing)
            }
        }
        scheduleHiddenNavigationDismissal()
    }

    private func scheduleHiddenNavigationDismissal() {
        hiddenNavigationDismissTask?.cancel()
        guard effectivePresentation == .hidden, !isEditing,
              let deadline = hiddenNavigation.dismissalDeadline else { return }
        hiddenNavigationDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(until: deadline, clock: .continuous)
            } catch {
                return
            }
            guard !Task.isCancelled, effectivePresentation == .hidden,
                  !interaction.isActive, !isEditing else { return }
            withAnimation(presentationAnimation) {
                if hiddenNavigation.dismissIfExpired(at: .now) {
                    navigationIsExpanded = false
                }
            }
        }
    }

    // MARK: Editor

    private func editingGuideOverlay(size: CGSize) -> some View {
        let occupiedHeight = SlotCarouselNavigationBar.contentHeight(for: .full, barHeight: barHeight)
            + SlotCarouselNavigationBar.accessoryHeight(barHeight: barHeight, showsCatalog: showsCatalog)

        return VStack(spacing: 0) {
            if navigationPlacement == .top {
                Color.clear.frame(height: occupiedHeight).allowsHitTesting(false)
            } else {
                editorControls
            }

            if showsGuide {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(strings.guideSteps.enumerated()), id: \.offset) { _, step in
                                guideStep(step)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    Button(action: dismissGuide) {
                        Text(strings.guideDismissTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
                    .accessibilityIdentifier("navigation-guide-dismiss")
                    .padding(.vertical, 12)
                    .zIndex(1)
                }
                .frame(maxWidth: 720, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }

            if navigationPlacement == .bottom {
                Color.clear.frame(height: occupiedHeight).allowsHitTesting(false)
            } else {
                editorControls
            }
        }
        .foregroundStyle(theme.textPrimary)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var editorControls: some View {
        VStack(spacing: 8) {
            HStack {
                SlotNavigationEditorHeader(title: strings.editorTitle, theme: theme)
                Button {
                    withAnimation(presentationAnimation) { showsCatalog.toggle() }
                } label: {
                    Image(systemName: showsCatalog ? "xmark" : "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true))
                .accessibilityLabel(showsCatalog ? strings.doneEditing : strings.addItemTitle)
                .accessibilityIdentifier("navigation-add")
                Button {
                    if showsGuide {
                        dismissGuide()
                    } else {
                        withAnimation(presentationAnimation) { showsGuide = true }
                    }
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true))
                .accessibilityLabel(strings.guideAccessibilityLabel)
                .accessibilityIdentifier("navigation-help")
            }

            HStack(spacing: 8) {
                Text("Position")
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(theme.textSecondary)
                ForEach(SlotNavigationPlacement.allCases, id: \.self) { placement in
                    Button {
                        moveNavigation(to: placement)
                    } label: {
                        Label(
                            placement == .top ? "Top" : "Bottom",
                            systemImage: placement == .top ? "rectangle.topthird.inset.filled" : "rectangle.bottomthird.inset.filled"
                        )
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: navigationPlacement == placement))
                    .accessibilityLabel("Place navigation at the \(placement.rawValue)")
                    .accessibilityAddTraits(navigationPlacement == placement ? .isSelected : [])
                    .accessibilityIdentifier("navigation-position-\(placement.rawValue)")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func moveNavigation(to placement: SlotNavigationPlacement) {
        guard placement != navigationPlacement else { return }
        interaction.isActive = false
        withAnimation(presentationAnimation) {
            finishEditing()
            navigationIsExpanded = false
            navigationPlacement = placement
        }
    }

    private func guideStep(_ step: SlotNavigationGuideStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            SlotNavigationGuideMarker(symbol: step.symbol, tint: theme.accent)
            Text(step.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(theme.typography.body)
        .foregroundStyle(theme.textSecondary)
        .lineSpacing(3)
    }

    private func dismissGuide() {
        markGuideSeen()
        withAnimation(presentationAnimation) { showsGuide = false }
    }

    private func markGuideSeen() {
        hasSeenGuide = true
        UserDefaults.standard.set(true, forKey: guideDefaultsKey)
    }

    private func finishEditing() {
        guard isEditing else { return }
        withAnimation(presentationAnimation) {
            isEditing = false
            showsCatalog = false
            navigationIsExpanded = false
        }
        onEditingEnded()
        if effectivePresentation == .hidden, hiddenNavigation.isVisible {
            hiddenNavigation.interactionChanged(false, at: .now)
            scheduleHiddenNavigationDismissal()
        }
    }
}

private final class SlotNavigationInteraction {
    var isActive = false
    var pageIsDragging = false
    var barSelects = false
}

/// A vertical drag on the bar: outward hides it, inward pulls the page wheel out of it.
enum SlotNavigationPull {
    case began
    case changed(translation: CGSize, location: CGPoint)
    case ended(translation: CGSize, predicted: CGSize)
    case cancelled
}

private struct SlotNavigationBarGestures<Bar: View>: View {
    let placement: SlotNavigationPlacement
    let isEnabled: Bool
    let pullsWheel: Bool
    let reduceMotion: Bool
    let onDismiss: () -> Void
    let onPull: (SlotNavigationPull) -> Void
    let bar: Bar
    @GestureState private var offset: CGFloat = 0
    @GestureState private var isTracking = false
    @State private var pulling = false

    var body: some View {
        bar
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .updating($offset) { value, state, _ in
                        state = placement.dismissOffset(for: value.translation)
                    }
                    .updating($isTracking) { _, state, _ in state = true }
                    .onChanged { value in
                        if !pulling, pullsWheel, placement.beginsWheelPull(translation: value.translation) {
                            pulling = true
                            onPull(.began)
                        }
                        if pulling {
                            onPull(.changed(translation: value.translation, location: value.location))
                        }
                    }
                    .onEnded { value in
                        if pulling {
                            pulling = false
                            onPull(.ended(translation: value.translation, predicted: value.predictedEndTranslation))
                            return
                        }
                        guard placement.acceptsDismiss(
                            translation: value.translation, projected: value.predictedEndTranslation
                        ) else { return }
                        onDismiss()
                    },
                including: isEnabled ? .all : .subviews
            )
            .onChange(of: isTracking) { tracking in
                guard !tracking, pulling else { return }
                DispatchQueue.main.async {
                    guard pulling else { return }
                    pulling = false
                    onPull(.cancelled)
                }
            }
            .offset(y: reduceMotion || pulling ? 0 : offset)
    }
}

#if os(iOS)
private struct SlotPageGestureBridge: UIViewRepresentable {
    var swipesPages: Bool
    var revealsNavigation: Bool
    var pageIndex: Int?
    var pageCount: Int
    var barExtent: CGFloat
    var placement: SlotNavigationPlacement
    var onSwipeBegan: (Int, CGFloat) -> Void
    var onSwipe: (CGFloat) -> Void
    var onSwipeEnded: (Int?) -> Void
    var onReveal: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.onWindowChanged = { [weak coordinator = context.coordinator] probe in
            coordinator?.attach(to: probe)
        }
        context.coordinator.probe = view
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refresh()
    }

    static func dismantleUIView(_ uiView: Probe, coordinator: Coordinator) {
        coordinator.detach()
        uiView.onWindowChanged = nil
    }

    final class Probe: UIView {
        var onWindowChanged: ((Probe) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(self)
        }
    }

    /// Readies the back swipe of a pushed page as a finger lands near the left edge; never recognizes anything.
    private final class BackSwipeHook: UIGestureRecognizer, UIGestureRecognizerDelegate {
        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            delegate = self
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first, let window = view?.window, touch.location(in: window).x <= 30 {
                MainActor.assumeIsolated { SlotBackSwipe.prepare(for: touch.view) }
            }
            state = .failed
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SlotPageGestureBridge
        weak var probe: Probe?
        private lazy var swipe = makeRecognizer(#selector(swiped(_:)))
        private lazy var reveal = makeRecognizer(#selector(revealed(_:)))
        private lazy var backHook = BackSwipeHook(target: nil, action: nil)
        private weak var swipeTouchView: UIView?
        private var swipeStart = CGPoint.zero
        private var swipeIndex: Int?
        private var swipeDirection: CGFloat = 0
        private var swipeTracks = false
        private var revealStart = CGPoint.zero
        private var revealSent = false

        init(_ parent: SlotPageGestureBridge) {
            self.parent = parent
        }

        private func makeRecognizer(_ action: Selector) -> UIPanGestureRecognizer {
            let pan = UIPanGestureRecognizer(target: self, action: action)
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
            pan.delegate = self
            return pan
        }

        func attach(to probe: Probe) {
            self.probe = probe
            detach()
            guard let window = probe.window else { return }
            window.addGestureRecognizer(swipe)
            window.addGestureRecognizer(reveal)
            window.addGestureRecognizer(backHook)
            refresh()
        }

        func detach() {
            swipe.view?.removeGestureRecognizer(swipe)
            reveal.view?.removeGestureRecognizer(reveal)
            backHook.view?.removeGestureRecognizer(backHook)
        }

        func refresh() {
            let swipes = parent.swipesPages && parent.pageCount > 1
            if swipe.isEnabled != swipes { swipe.isEnabled = swipes }
            if reveal.isEnabled != parent.revealsNavigation { reveal.isEnabled = parent.revealsNavigation }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let probe, touch.window === probe.window else { return false }
            let point = touch.location(in: probe)
            guard probe.bounds.contains(point) else { return false }
            guard gestureRecognizer === swipe else { return true }
            swipeTouchView = touch.view
            let extent = max(0, parent.barExtent)
            return parent.placement == .bottom ? point.y <= probe.bounds.maxY - extent : point.y >= probe.bounds.minY + extent
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let probe, let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let window = probe.window, !Self.presents(window.rootViewController) else { return false }
            let translation = pan.translation(in: probe)
            let location = pan.location(in: probe)
            let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            let moved = CGSize(width: translation.x, height: translation.y)
            if pan === swipe {
                guard let index = parent.pageIndex, !Self.isInPushedStack(swipeTouchView),
                      let begun = SlotPageSwipeGeometry.swipe(
                        index: index, count: parent.pageCount, start: start, translation: moved, width: probe.bounds.width
                      ) else { return false }
                swipeIndex = index
                swipeStart = start
                swipeDirection = begun.direction
                swipeTracks = false
                return true
            }
            guard SlotNavigationOverlayState.beginsReveal(
                start: start, translation: moved, viewportHeight: probe.bounds.height
            ) else { return false }
            revealStart = start
            revealSent = false
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func swiped(_ pan: UIPanGestureRecognizer) {
            guard let probe, let index = swipeIndex else { return }
            let translation = pan.translation(in: probe)
            let moved = CGSize(width: translation.x, height: translation.y)
            let current = SlotPageSwipeGeometry.swipe(
                index: index, count: parent.pageCount, start: swipeStart, translation: moved, width: probe.bounds.width
            )
            switch pan.state {
            case .began, .changed:
                if let current, current.direction == swipeDirection {
                    if !swipeTracks {
                        swipeTracks = true
                        parent.onSwipeBegan(current.neighbour, current.direction)
                    }
                    parent.onSwipe(current.fraction)
                } else if swipeTracks {
                    swipeTracks = false
                    parent.onSwipeEnded(nil)
                }
            case .ended:
                if swipeTracks {
                    let projected = moved.width + Self.projection(of: pan.velocity(in: probe).x)
                    parent.onSwipeEnded(SlotPageSwipeGeometry.destination(
                        index: index, count: parent.pageCount, start: swipeStart, translation: moved,
                        projectedWidth: projected, width: probe.bounds.width
                    ))
                }
                swipeTracks = false
                swipeIndex = nil
            case .cancelled, .failed:
                if swipeTracks { parent.onSwipeEnded(nil) }
                swipeTracks = false
                swipeIndex = nil
            default:
                break
            }
        }

        @objc private func revealed(_ pan: UIPanGestureRecognizer) {
            guard let probe, !revealSent else { return }
            switch pan.state {
            case .began, .changed, .ended:
                let translation = pan.translation(in: probe)
                guard SlotNavigationOverlayState.acceptsReveal(
                    start: revealStart, translation: CGSize(width: translation.x, height: translation.y),
                    viewportHeight: probe.bounds.height
                ) else { return }
                revealSent = true
                parent.onReveal()
            default:
                break
            }
        }

        private static func projection(of velocity: CGFloat) -> CGFloat {
            guard velocity.isFinite else { return 0 }
            let rate = UIScrollView.DecelerationRate.normal.rawValue
            return velocity / 1000 * rate / (1 - rate)
        }

        private static func presents(_ controller: UIViewController?) -> Bool {
            guard let controller else { return false }
            return controller.presentedViewController != nil || controller.children.contains { presents($0) }
        }

        private static func isInPushedStack(_ view: UIView?) -> Bool {
            var responder: UIResponder? = view
            while let current = responder {
                if let navigation = current as? UINavigationController {
                    return navigation.viewControllers.count > 1
                }
                responder = current.next
            }
            return false
        }
    }
}
#endif

/// The orange ring that marks each step of the editing guide, drawn like the app's other count and status
/// markers; its symbol sits on the first line of the step's text.
private struct SlotNavigationGuideMarker: View {
    let symbol: String
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.2)))
            .overlay(Circle().strokeBorder(tint.opacity(0.65), lineWidth: 1.2))
            .accessibilityHidden(true)
    }
}

/// Set by a destination that owns its own drag gestures — the Home canvas while its widgets
/// are being edited. Page swipes stand down until the flag clears.
struct SlotNavigationEditingPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// The rectangle a destination can safely occupy, in the global coordinate space: the
/// container's frame minus the space reserved at the saved navigation edge.
private struct SlotNavigationContentBoundsKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var slotNavigationContentBounds: CGRect? {
        get { self[SlotNavigationContentBoundsKey.self] }
        set { self[SlotNavigationContentBoundsKey.self] = newValue }
    }
}
