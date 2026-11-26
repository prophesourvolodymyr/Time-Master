// SlotNavigationContainer.swift
//
// Hosts a destination, the carousel bar and navigation presentations. Part of the
// CarouselNavigation component from the SwiftComponentLibrary, copied into the app, with the
// app's content-bounds hook and Home's page-swipe gate.

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SlotCarouselNavigation<Content: View>: View {
    @Binding private var selection: String?
    private let items: [SlotNavigationItem]
    private let availableItems: [SlotNavigationItem]
    private let configuration: SlotNavigationConfiguration?
    private let onInsert: (String, Int) -> Void
    private let onMove: (String, Int) -> Void
    private let onRemove: (String) -> Void
    private let onConfigure: (String) -> Void
    private let onEditingEnded: () -> Void
    private let barHeight: CGFloat
    private let interactionEnabled: Bool
    private let allowsEditing: Bool
    private let showsEditingGuide: Bool
    private let guideDefaultsKey: String
    private let theme: SlotNavigationTheme
    private let strings: SlotNavigationStrings
    private let content: () -> Content
    private let onPageDrag: (CGFloat) -> Void
    private let onPageDragEnded: () -> Void

    @AppStorage("tm.navigation.placement") private var navigationPlacement = SlotNavigationPlacement.bottom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var clearanceTracker = SlotNavigationClearanceTracker()
    @State private var inlineClearanceContext: SlotNavigationClearanceContext?
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

    init(
        selection: Binding<String?>,
        items: [SlotNavigationItem],
        availableItems: [SlotNavigationItem] = [],
        configuration: SlotNavigationConfiguration? = nil,
        onInsert: @escaping (String, Int) -> Void = { _, _ in },
        onMove: @escaping (String, Int) -> Void = { _, _ in },
        onRemove: @escaping (String) -> Void = { _ in },
        onConfigure: @escaping (String) -> Void = { _ in },
        onEditingEnded: @escaping () -> Void = {},
        barHeight: CGFloat = SlotCarouselNavigationBar.fullHeight,
        interactionEnabled: Bool = true,
        allowsEditing: Bool = true,
        showsEditingGuide: Bool = true,
        guideDefaultsKey: String = "tm.navigation.editorGuideSeen",
        theme: SlotNavigationTheme = .timeMaster,
        strings: SlotNavigationStrings = .timeMaster,
        onPageDrag: @escaping (CGFloat) -> Void = { _ in },
        onPageDragEnded: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        _selection = selection
        self.items = items
        self.availableItems = availableItems
        self.configuration = configuration
        self.onInsert = onInsert
        self.onMove = onMove
        self.onRemove = onRemove
        self.onConfigure = onConfigure
        self.onEditingEnded = onEditingEnded
        self.barHeight = max(SlotCarouselNavigationBar.fullHeight, barHeight)
        self.interactionEnabled = interactionEnabled
        self.allowsEditing = allowsEditing
        self.showsEditingGuide = showsEditingGuide
        self.guideDefaultsKey = guideDefaultsKey
        self.theme = theme
        self.strings = strings
        _hasSeenGuide = State(initialValue: UserDefaults.standard.bool(forKey: guideDefaultsKey))
        self.content = content
        self.onPageDrag = onPageDrag
        self.onPageDragEnded = onPageDragEnded
    }

    var body: some View {
        GeometryReader { proxy in
            let presentation = effectivePresentation
            let frame = proxy.frame(in: .global)
            let clearanceContext = SlotNavigationClearanceContext(
                page: selection, viewport: frame, placement: navigationPlacement, dynamicTypeSize: dynamicTypeSize,
                safeAreaInsets: proxy.safeAreaInsets,
                archedHeight: SlotCarouselNavigationBar.contentHeight(for: .full, barHeight: barHeight)
            )
            let layout = barLayout(in: clearanceContext)
            let restingLayout = contentLayout(in: clearanceContext)
            let barExtent = SlotCarouselNavigationBar.contentHeight(for: layout, barHeight: barHeight)
            let showsNavigation = presentation != .hidden || hiddenNavigation.isVisible
            let restoreHeight: CGFloat = navigationManuallyHidden && navigationInteractionEnabled
                && defaultPresentation != .hidden ? 24 : 0
            let reservedHeight = presentation == .hidden
                ? restoreHeight : SlotCarouselNavigationBar.contentHeight(for: restingLayout, barHeight: barHeight)
            let contentBounds = navigationPlacement.contentBounds(in: frame, reservedHeight: reservedHeight)
            let measuresClearance = presentation == .visible
            let pageGesturesEnabled = navigationInteractionEnabled && !isEditing && !pageSwipesDisabled && !reachabilityIsActive

            ZStack(alignment: .top) {
                content()
                    .environment(\.slotNavigationContentBounds, contentBounds)
                    .environment(\.slotNavigationClearanceScope, measuresClearance ? SlotNavigationClearanceScope(
                        context: clearanceContext, contentBounds: contentBounds, measuresArchedLayout: restingLayout == .full
                    ) : nil)
                    .transformPreference(SlotNavigationContentClearancePreferenceKey.self) { measurement in
                        guard measuresClearance else {
                            measurement = SlotNavigationContentClearance()
                            return
                        }
                        if measurement.context == nil {
                            measurement.context = clearanceContext
                            measurement.measuredArchedLayout = restingLayout == .full
                        }
                    }
                    .environment(\.slotNavigationArcFrame, restingLayout == .full && showsNavigation
                        && !isEditing && !reduceMotion && !reduceTransparency && !lowPower && scenePhase == .active
                        ? CGRect(
                            x: frame.minX,
                            y: navigationPlacement == .bottom ? frame.maxY - barHeight : frame.minY,
                            width: proxy.size.width,
                            height: barHeight
                        ) : .zero)
                    .animation(nil, value: selection)
                    .everPageTravel(scope: selection ?? "", order: items.firstIndex(where: { $0.id == selection }) ?? 0)
                    .blur(radius: isEditing && !reduceTransparency ? 11 : 0)
                    .opacity(isEditing ? 0.48 : 1)
                    .allowsHitTesting(!isEditing)
                    .accessibilityHidden(isEditing)
                    .safeAreaInset(edge: navigationPlacement == .bottom ? .bottom : .top, spacing: 0) {
                        Color.clear
                            .frame(height: reservedHeight)
                            .allowsHitTesting(false)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    #if os(iOS)
                    .background {
                        SlotPageGestureBridge(
                            swipesPages: pageGesturesEnabled,
                            revealsNavigation: pageGesturesEnabled && presentation == .hidden && !hiddenNavigation.isVisible,
                            pageIndex: items.firstIndex(where: { $0.id == selection }),
                            barExtent: showsNavigation ? barExtent : restoreHeight,
                            placement: navigationPlacement,
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
                    navigationOverlay(in: proxy, layout: layout, showsNavigation: showsNavigation, restoreHeight: restoreHeight)
                        .keyNavRole(.excluded)
                        .keyNavObstruction()
                        .transition(navigationPresentationTransition(edge: .bottom))
                }
            }
            .overlay(alignment: .top) {
                if navigationPlacement == .top {
                    navigationOverlay(in: proxy, layout: layout, showsNavigation: showsNavigation, restoreHeight: restoreHeight)
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
            .keyNavYield(isEditing)
            .everEscapeClaim("navigation-editing", isActive: isEditing, perform: finishEditing)
            .onPreferenceChange(SlotNavigationContentClearancePreferenceKey.self) { measurement in
                guard measurement.context == clearanceContext else { return }
                let inlineContext = clearanceTracker.observe(measurement)
                if inlineContext != inlineClearanceContext { inlineClearanceContext = inlineContext }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .onDisappear {
                hiddenNavigationDismissTask?.cancel()
                onPageDragEnded()
                finishEditing()
            }
            .onChange(of: isEditing) { editing in
                if editing {
                    showsGuide = showsEditingGuide && !hasSeenGuide
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
            .onChange(of: navigationInteractionEnabled) { enabled in
                if !enabled {
                    finishEditing()
                    hiddenNavigationDismissTask?.cancel()
                    hiddenNavigation.dismiss()
                    navigationManuallyHidden = false
                    navigationIsExpanded = false
                    interaction.isActive = false
                    interaction.pageIsDragging = false
                    onPageDragEnded()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    AppInteractionHaptics.shared.suspend()
                    hiddenNavigationDismissTask?.cancel()
                    navigationIsExpanded = false
                    interaction.isActive = false
                    interaction.pageIsDragging = false
                    onPageDragEnded()
                } else if effectivePresentation == .hidden, hiddenNavigation.isVisible {
                    hiddenNavigation.interactionChanged(interaction.isActive || isEditing, at: .now)
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onPreferenceChange(SlotNavigationInteractionDisabledPreferenceKey.self) { contentDisablesInteraction = $0 }
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
            .animation(presentationAnimation, value: restingLayout)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: strings.showNavigation) {
                guard navigationInteractionEnabled else { return }
                if effectivePresentation == .hidden {
                    revealHiddenNavigation()
                } else {
                    withAnimation(presentationAnimation) { navigationIsExpanded = true }
                }
            }
            .accessibilityAction(named: "Collapse navigation", collapseNavigation)
            .accessibilityAction(named: strings.editNavigation, beginEditing)
        }
    }

    @ViewBuilder
    private func navigationOverlay(
        in proxy: GeometryProxy,
        layout: SlotNavigationBarLayout,
        showsNavigation: Bool,
        restoreHeight: CGFloat
    ) -> some View {
        if showsNavigation {
            SlotNavigationBarDismissal(
                placement: navigationPlacement,
                isEnabled: !isEditing,
                reduceMotion: reduceMotion,
                onDismiss: hideNavigation,
                bar: SlotCarouselNavigationBar(
                    selection: normalSelection,
                    items: items,
                    placement: navigationPlacement,
                    edgeSafeArea: navigationPlacement == .bottom ? proxy.safeAreaInsets.bottom : proxy.safeAreaInsets.top,
                    theme: theme,
                    strings: strings,
                    barHeight: barHeight,
                    layout: layout,
                    isEditing: $isEditing,
                    showsCatalog: $showsCatalog,
                    availableItems: availableItems,
                    configuration: configuration,
                    onInsert: onInsert,
                    onMove: onMove,
                    onRemove: onRemove,
                    onConfigure: onConfigure,
                    onEditingEnded: finishEditing,
                    onPageDrag: onPageDrag,
                    onPageDragEnded: onPageDragEnded,
                    onInteractionChanged: navigationInteractionChanged
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.56, maximumDistance: 18)
                        .onEnded { _ in beginEditing() },
                    including: allowsEditing && !isEditing ? .all : .subviews
                )
            )
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

    private func beginEditing() {
        guard navigationInteractionEnabled, allowsEditing, !isEditing else { return }
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
        interactionEnabled && !contentDisablesInteraction
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

    private func barLayout(in context: SlotNavigationClearanceContext) -> SlotNavigationBarLayout {
        SlotNavigationBarLayout.resolve(
            isExpanded: navigationIsExpanded,
            isInteracting: false,
            isEditing: isEditing,
            isOverlayVisible: hiddenNavigation.isVisible,
            contentRequiresInline: inlineClearanceContext == context,
            contentPrefersInline: contentPrefersStrip
        )
    }

    private func contentLayout(in context: SlotNavigationClearanceContext) -> SlotNavigationBarLayout {
        SlotNavigationBarLayout.resolve(
            isExpanded: false,
            isInteracting: false,
            isEditing: false,
            isOverlayVisible: false,
            contentRequiresInline: inlineClearanceContext == context,
            contentPrefersInline: contentPrefersStrip
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
        onPageDragEnded()
    }

    private func pageSwipeChanged(_ progress: CGFloat) {
        interaction.pageIsDragging = true
        onPageDrag(progress)
    }

    private func pageSwipeEnded(_ destination: Int?) {
        guard interaction.pageIsDragging else { return }
        interaction.pageIsDragging = false
        if let destination, !isEditing, !reachabilityIsActive, items.indices.contains(destination) {
            selection = items[destination].id
        }
        onPageDragEnded()
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

    #if !os(iOS)
    private func pageSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isEditing, !reachabilityIsActive,
                      let index = items.firstIndex(where: { $0.id == selection }) else { return }
                if let progress = SlotPageSwipeGeometry.progress(
                    index: index, start: value.startLocation, translation: value.translation, width: size.width
                ) {
                    pageSwipeChanged(progress)
                } else {
                    pageSwipeEnded(nil)
                }
            }
            .onEnded { value in
                let index = items.firstIndex(where: { $0.id == selection })
                pageSwipeEnded(index.flatMap {
                    SlotPageSwipeGeometry.destination(
                        index: $0, translation: value.translation,
                        projectedWidth: value.predictedEndTranslation.width, width: size.width
                    )
                })
            }
    }
    #endif

    private func editingGuideOverlay(size: CGSize) -> some View {
        let occupiedHeight = SlotCarouselNavigationBar.contentHeight(for: .full, barHeight: barHeight)
            + SlotCarouselNavigationBar.accessoryHeight(
                barHeight: barHeight, showsCatalog: showsCatalog, hasConfiguration: configuration != nil
            )

        return VStack(spacing: 0) {
            if navigationPlacement == .top {
                Color.clear.frame(height: occupiedHeight).allowsHitTesting(false)
            } else {
                editorControls
            }

            if showsGuide, configuration == nil {
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
                if showsEditingGuide {
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
        guard isEditing || configuration != nil else { return }
        if configuration != nil {
            configuration?.onCancel()
        }
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

private struct SlotNavigationBarDismissal<Bar: View>: View {
    let placement: SlotNavigationPlacement
    let isEnabled: Bool
    let reduceMotion: Bool
    let onDismiss: () -> Void
    let bar: Bar
    @GestureState private var offset: CGFloat = 0

    var body: some View {
        bar
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .updating($offset) { value, state, _ in
                        state = placement.dismissOffset(for: value.translation)
                    }
                    .onEnded { value in
                        guard placement.acceptsDismiss(
                            translation: value.translation, projected: value.predictedEndTranslation
                        ) else { return }
                        onDismiss()
                    },
                including: isEnabled ? .all : .subviews
            )
            .offset(y: reduceMotion ? 0 : offset)
    }
}

#if os(iOS)
private struct SlotPageGestureBridge: UIViewRepresentable {
    var swipesPages: Bool
    var revealsNavigation: Bool
    var pageIndex: Int?
    var barExtent: CGFloat
    var placement: SlotNavigationPlacement
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

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SlotPageGestureBridge
        weak var probe: Probe?
        private lazy var swipe = makeRecognizer(#selector(swiped(_:)))
        private lazy var reveal = makeRecognizer(#selector(revealed(_:)))
        private weak var swipeTouchView: UIView?
        private var swipeStart = CGPoint.zero
        private var swipeIndex: Int?
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
            refresh()
        }

        func detach() {
            swipe.view?.removeGestureRecognizer(swipe)
            reveal.view?.removeGestureRecognizer(reveal)
        }

        func refresh() {
            let swipes = parent.swipesPages && (parent.pageIndex ?? 0) > 0
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
                      SlotPageSwipeGeometry.progress(
                        index: index, start: start, translation: moved, width: probe.bounds.width
                      ) != nil else { return false }
                swipeIndex = index
                swipeStart = start
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
            switch pan.state {
            case .began, .changed:
                if let progress = SlotPageSwipeGeometry.progress(
                    index: index, start: swipeStart, translation: moved, width: probe.bounds.width
                ) {
                    swipeTracks = true
                    parent.onSwipe(progress)
                } else if swipeTracks {
                    swipeTracks = false
                    parent.onSwipeEnded(nil)
                }
            case .ended:
                if swipeTracks {
                    let projected = moved.width + Self.projection(of: pan.velocity(in: probe).x)
                    parent.onSwipeEnded(SlotPageSwipeGeometry.destination(
                        index: index, translation: moved, projectedWidth: projected, width: probe.bounds.width
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

private struct SlotNavigationClearanceScope: Equatable {
    let context: SlotNavigationClearanceContext
    let contentBounds: CGRect
    let measuresArchedLayout: Bool

    func measurement(control: CGRect, primaryAction: Bool, scrollBounds: CGRect?) -> SlotNavigationContentClearance {
        let assessment = SlotNavigationContentClearance.assess(
            control: control, contentBounds: contentBounds, viewport: context.viewport,
            placement: context.placement, primaryAction: primaryAction, scrollBounds: scrollBounds
        )
        return SlotNavigationContentClearance(
            context: context,
            measuredArchedLayout: measuresArchedLayout,
            controlCount: assessment.isRelevant ? 1 : 0,
            controlSize: assessment.isRelevant ? CGSize(width: control.width.rounded(), height: control.height.rounded()) : .zero,
            hasObstruction: assessment.hasObstruction
        )
    }
}

private struct SlotNavigationClearanceScopeKey: EnvironmentKey {
    static let defaultValue: SlotNavigationClearanceScope? = nil
}

private extension EnvironmentValues {
    var slotNavigationClearanceScope: SlotNavigationClearanceScope? {
        get { self[SlotNavigationClearanceScopeKey.self] }
        set { self[SlotNavigationClearanceScopeKey.self] = newValue }
    }
}

private struct SlotNavigationContentClearancePreferenceKey: PreferenceKey {
    static let defaultValue = SlotNavigationContentClearance()

    static func reduce(value: inout SlotNavigationContentClearance, nextValue: () -> SlotNavigationContentClearance) {
        let next = nextValue()
        guard next.context != nil else { return }
        if value.context != next.context {
            value = next
        } else {
            value.controlCount += next.controlCount
            value.controlSize.width += next.controlSize.width
            value.controlSize.height += next.controlSize.height
            value.hasObstruction = value.hasObstruction || next.hasObstruction
            value.measuredArchedLayout = value.measuredArchedLayout || next.measuredArchedLayout
        }
    }
}

struct SlotNavigationContentClearanceReader: View {
    var primaryAction = false
    @Environment(\.slotNavigationClearanceScope) private var scope

    var body: some View {
        Group {
            if let scope {
                if #available(iOS 17.0, macOS 14.0, *) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SlotNavigationContentClearancePreferenceKey.self,
                            value: scope.measurement(
                                control: proxy.slotNavigationLayoutFrame, primaryAction: primaryAction,
                                scrollBounds: proxy.slotNavigationScrollBounds
                            )
                        )
                    }
                } else {
#if os(iOS)
                    if primaryAction {
                        LegacySlotNavigationClearanceReader(scope: scope)
                    }
#endif
                }
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension GeometryProxy {
    var slotNavigationLayoutFrame: CGRect {
        let drawn = frame(in: .global)
        return CGRect(x: drawn.midX - size.width / 2, y: drawn.midY - size.height / 2, width: size.width, height: size.height)
    }

    @available(iOS 17.0, macOS 14.0, *)
    var slotNavigationScrollBounds: CGRect? {
        guard let local = bounds(of: .scrollView(axis: .vertical)) else { return nil }
        let drawn = frame(in: .global)
        let scaleX = size.width > 0 ? drawn.width / size.width : 1
        let scaleY = size.height > 0 ? drawn.height / size.height : 1
        return CGRect(x: drawn.minX + local.minX * scaleX, y: drawn.minY + local.minY * scaleY,
                      width: local.width * scaleX, height: local.height * scaleY)
    }
}

#if os(iOS)
private struct LegacySlotNavigationScrollEnclosure: Equatable {
    var bounds: CGRect?

    func isClose(to other: Self) -> Bool {
        switch (bounds, other.bounds) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.minX - rhs.minX) <= 1 && abs(lhs.minY - rhs.minY) <= 1
                && abs(lhs.maxX - rhs.maxX) <= 1 && abs(lhs.maxY - rhs.maxY) <= 1
        default:
            return false
        }
    }
}

private struct LegacySlotNavigationClearanceReader: View {
    let scope: SlotNavigationClearanceScope
    @State private var enclosure: LegacySlotNavigationScrollEnclosure?

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SlotNavigationContentClearancePreferenceKey.self,
                value: enclosure.map {
                    scope.measurement(control: proxy.slotNavigationLayoutFrame, primaryAction: true, scrollBounds: $0.bounds)
                } ?? SlotNavigationContentClearance()
            )
        }
        .background(LegacySlotNavigationScrollProbe(scope: scope) { enclosure = $0 })
    }
}

private struct LegacySlotNavigationScrollProbe: UIViewRepresentable {
    let scope: SlotNavigationClearanceScope
    let onChange: (LegacySlotNavigationScrollEnclosure) -> Void

    func makeUIView(context: Context) -> LegacySlotNavigationScrollProbeView {
        let view = LegacySlotNavigationScrollProbeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: LegacySlotNavigationScrollProbeView, context: Context) {
        view.onChange = onChange
        view.scope = scope
    }

    static func dismantleUIView(_ view: LegacySlotNavigationScrollProbeView, coordinator: ()) {
        view.onChange = nil
    }
}

private final class LegacySlotNavigationScrollProbeView: UIView {
    var onChange: ((LegacySlotNavigationScrollEnclosure) -> Void)?
    var scope: SlotNavigationClearanceScope? {
        didSet {
            if scope != oldValue { scheduleMeasure() }
        }
    }
    private var reported: LegacySlotNavigationScrollEnclosure?
    private var isScheduled = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleMeasure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleMeasure()
    }

    private func scheduleMeasure() {
        guard !isScheduled, window != nil else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScheduled = false
            self.measure()
        }
    }

    private func measure() {
        guard let window, let onChange else { return }
        let enclosure = LegacySlotNavigationScrollEnclosure(
            bounds: enclosingScrollView().map { $0.convert($0.bounds, to: window) }
        )
        if let reported, reported.isClose(to: enclosure) { return }
        reported = enclosure
        onChange(enclosure)
    }

    private func enclosingScrollView() -> UIScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView,
               scrollView.alwaysBounceVertical || scrollView.contentSize.height > scrollView.bounds.height + 1
                || (!scrollView.alwaysBounceHorizontal && scrollView.contentSize.width <= scrollView.bounds.width + 1) {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }
}
#endif
