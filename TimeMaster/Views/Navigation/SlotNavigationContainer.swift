// SlotNavigationContainer.swift
//
// Hosts a destination, the carousel bar and navigation presentations. Part of the
// CarouselNavigation component from the SwiftComponentLibrary, copied into the app, with the
// app's content-bounds hook and Home's page-swipe gate.

import SwiftUI

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
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var requestedPresentation: SlotNavigationPresentation?
    @State private var contentDisablesInteraction = false
    @State private var hiddenNavigation = SlotNavigationOverlayState()
    @State private var hiddenNavigationDismissTask: Task<Void, Never>?
    @State private var isEditing = false
    @State private var showsCatalog = false
    @State private var hasSeenGuide: Bool
    @State private var showsGuide = false
    @State private var pageIsDragging = false
    @State private var pageSwipesDisabled = false
    @State private var reachabilityIsActive = false
    @State private var navigationIsExpanded = false
    @State private var navigationIsInteracting = false
    @State private var navigationManuallyHidden = false
    @GestureState private var navigationDismissDrag: CGFloat = 0

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
            let layout = barLayout
            let normalHeight = SlotCarouselNavigationBar.contentHeight(for: layout, barHeight: barHeight)
            let showsNavigation = presentation != .hidden || hiddenNavigation.isVisible
            let frame = proxy.frame(in: .global)
            let restoreHeight: CGFloat = navigationManuallyHidden && navigationInteractionEnabled
                && defaultPresentation != .hidden ? 24 : 0
            let reservedHeight = presentation == .hidden ? restoreHeight : normalHeight
            let contentBounds = navigationPlacement.contentBounds(in: frame, reservedHeight: reservedHeight)

            ZStack(alignment: .top) {
                content()
                    .environment(\.slotNavigationContentBounds, contentBounds)
                    .environment(\.slotNavigationArcLensFrame, layout == .full && showsNavigation
                        && !isEditing && !reduceMotion && !reduceTransparency && !lowPower && scenePhase == .active
                        ? CGRect(
                            x: proxy.frame(in: .global).minX,
                            y: navigationPlacement == .bottom ? frame.maxY - barHeight : frame.minY,
                            width: proxy.size.width,
                            height: barHeight
                        ) : .zero)
                    .animation(nil, value: selection)
                    .blur(radius: isEditing && !reduceTransparency ? 11 : 0)
                    .opacity(isEditing ? 0.48 : 1)
                    .allowsHitTesting(!isEditing)
                    .accessibilityHidden(isEditing)
                    .frame(width: contentBounds.width, height: contentBounds.height, alignment: .top)
                    .offset(y: contentBounds.minY - frame.minY)
                    .contentShape(Rectangle())
                    .simultaneousGesture(pageSwipeGesture(in: proxy.size), including: navigationInteractionEnabled && !isEditing && !pageSwipesDisabled && !reachabilityIsActive ? .all : .subviews)
                    .simultaneousGesture(hiddenNavigationRevealGesture(in: proxy.size), including: navigationInteractionEnabled && !isEditing && !pageSwipesDisabled && !reachabilityIsActive ? .all : .subviews)
                    .simultaneousGesture(contentNavigationDismissGesture)

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
                        .transition(navigationPresentationTransition(edge: .bottom))
                }
            }
            .overlay(alignment: .top) {
                if navigationPlacement == .top {
                    navigationOverlay(in: proxy, layout: layout, showsNavigation: showsNavigation, restoreHeight: restoreHeight)
                        .transition(navigationPresentationTransition(edge: .top))
                }
            }
            .overlay {
                if isEditing {
                    editingGuideOverlay(size: proxy.size)
                        .transition(.opacity)
                }
            }
            .background(theme.background.ignoresSafeArea())
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
                if let selection, let destination, selection != destination {
                    AppInteractionHaptics.shared.selectionChanged()
                }
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
                    hiddenNavigation.interactionChanged(navigationIsInteracting || isEditing, at: .now)
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onChange(of: navigationInteractionEnabled) { enabled in
                if !enabled {
                    finishEditing()
                    hiddenNavigationDismissTask?.cancel()
                    hiddenNavigation.dismiss()
                    navigationManuallyHidden = false
                    pageIsDragging = false
                    navigationIsExpanded = false
                    navigationIsInteracting = false
                    onPageDragEnded()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    AppInteractionHaptics.shared.suspend()
                    hiddenNavigationDismissTask?.cancel()
                    navigationIsExpanded = false
                    navigationIsInteracting = false
                    pageIsDragging = false
                    onPageDragEnded()
                } else if effectivePresentation == .hidden, hiddenNavigation.isVisible {
                    hiddenNavigation.interactionChanged(navigationIsInteracting || isEditing, at: .now)
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onPreferenceChange(SlotNavigationInteractionDisabledPreferenceKey.self) { contentDisablesInteraction = $0 }
            .onPreferenceChange(SlotNavigationEditingPreferenceKey.self) { pageSwipesDisabled = $0 }
            .onPreferenceChange(ReachabilityActivePreferenceKey.self) { reachabilityIsActive = $0 }
            .onPreferenceChange(SlotNavigationPresentationPreferenceKey.self) { requested in
                applyPresentation(requested)
            }
            .animation(presentationAnimation, value: effectivePresentation)
            .animation(presentationAnimation, value: isEditing)
            .animation(presentationAnimation, value: navigationIsExpanded)
            .animation(presentationAnimation, value: navigationPlacement)
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
            SlotCarouselNavigationBar(
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
            .simultaneousGesture(navigationDismissGesture)
            .offset(y: reduceMotion ? 0 : navigationDismissDrag)
            .accessibilityAction(named: "Hide navigation", hideNavigation)
            .background(SlotNavigationBarFrameReader())
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
                    hiddenNavigation.reveal(at: .now, interacting: navigationIsInteracting)
                } else {
                    hiddenNavigation.dismiss()
                }
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

    private var barLayout: SlotNavigationBarLayout {
        SlotNavigationBarLayout.resolve(
            isExpanded: navigationIsExpanded,
            isInteracting: navigationIsInteracting,
            isEditing: isEditing,
            isOverlayVisible: hiddenNavigation.isVisible
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
            hiddenNavigation.interactionChanged(navigationIsInteracting || isEditing, at: .now)
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
        guard navigationIsExpanded, !navigationIsInteracting, !isEditing else { return }
        withAnimation(presentationAnimation) { navigationIsExpanded = false }
    }

    private func navigationInteractionChanged(_ active: Bool) {
        withAnimation(presentationAnimation) {
            navigationIsInteracting = active && navigationInteractionEnabled
            if !isEditing {
                navigationIsExpanded = navigationIsInteracting
            }
        }
        if active {
            AppInteractionHaptics.shared.prepareSelection()
        }
        if hiddenNavigation.isVisible {
            hiddenNavigation.interactionChanged(active || isEditing, at: .now)
        }
        if active {
            hiddenNavigationDismissTask?.cancel()
        } else if effectivePresentation == .hidden {
            scheduleHiddenNavigationDismissal()
        }
    }

    private var navigationDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($navigationDismissDrag) { value, offset, _ in
                guard !isEditing else { return }
                offset = navigationPlacement.dismissOffset(for: value.translation)
            }
            .onEnded { value in
                guard !isEditing, navigationPlacement.acceptsDismiss(
                    translation: value.translation, projected: value.predictedEndTranslation
                ) else { return }
                hideNavigation()
            }
    }

    private func hideNavigation() {
        hiddenNavigationDismissTask?.cancel()
        withAnimation(presentationAnimation) {
            navigationManuallyHidden = true
            hiddenNavigation.dismiss()
            navigationIsExpanded = false
            navigationIsInteracting = false
        }
        onPageDragEnded()
    }

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

    private func revealHiddenNavigation() {
        guard navigationInteractionEnabled, effectivePresentation == .hidden else { return }
        hiddenNavigationDismissTask?.cancel()
        withAnimation(presentationAnimation) {
            navigationManuallyHidden = false
            navigationIsExpanded = false
            if effectivePresentation == .hidden {
                hiddenNavigation.reveal(at: .now, interacting: navigationIsInteracting || isEditing)
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
                  !navigationIsInteracting, !isEditing else { return }
            withAnimation(presentationAnimation) {
                if hiddenNavigation.dismissIfExpired(at: .now) {
                    navigationIsExpanded = false
                }
            }
        }
    }

    private func pageSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isEditing, !reachabilityIsActive, let selected = selection,
                      let index = items.firstIndex(where: { $0.id == selected }) else { return }
                guard let progress = SlotPageSwipeGeometry.progress(
                    index: index, start: value.startLocation, translation: value.translation, width: size.width
                ) else {
                    if pageIsDragging {
                        pageIsDragging = false
                        onPageDragEnded()
                    }
                    return
                }
                pageIsDragging = true
                onPageDrag(progress)
            }
            .onEnded { value in
                guard pageIsDragging else { return }
                pageIsDragging = false
                if !reachabilityIsActive, let selected = selection,
                   let index = items.firstIndex(where: { $0.id == selected }),
                   let destination = SlotPageSwipeGeometry.destination(
                    index: index, translation: value.translation,
                    projectedWidth: value.predictedEndTranslation.width, width: size.width
                   ) {
                    selection = items[destination].id
                }
                onPageDragEnded()
            }
    }

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
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(strings.guideSteps.enumerated()), id: \.offset) { _, step in
                            guideStep(step)
                        }
                        Button(strings.guideDismissTitle, action: dismissGuide)
                            .buttonStyle(SlotNavigationProminentButtonStyle(theme: theme))
                            .accessibilityIdentifier("navigation-guide-dismiss")
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: 720, maxHeight: .infinity)
                .padding(.horizontal, 20)
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
                .buttonStyle(SlotNavigationQuietButtonStyle(theme: theme, horizontalPadding: 0))
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
                    .buttonStyle(SlotNavigationQuietButtonStyle(theme: theme, horizontalPadding: 0))
                    .accessibilityLabel(strings.guideAccessibilityLabel)
                    .accessibilityIdentifier("navigation-help")
                }
            }

            HStack(spacing: 8) {
                Text("Position")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                ForEach(SlotNavigationPlacement.allCases, id: \.self) { placement in
                    Button {
                        moveNavigation(to: placement)
                    } label: {
                        Label(
                            placement == .top ? "Top" : "Bottom",
                            systemImage: placement == .top ? "rectangle.topthird.inset.filled" : "rectangle.bottomthird.inset.filled"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            navigationPlacement == placement ? theme.controlSurface : .clear,
                            in: RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
        withAnimation(presentationAnimation) {
            finishEditing()
            navigationIsExpanded = false
            navigationIsInteracting = false
            navigationPlacement = placement
        }
    }

    private func guideStep(_ step: SlotNavigationGuideStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step.symbol)
                .frame(width: 24)
                .accessibilityHidden(true)
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

/// Set by a destination that owns its own drag gestures — the Home canvas while its widgets
/// are being edited. Page swipes stand down until the flag clears.
struct SlotNavigationEditingPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// The rectangle a destination can safely occupy, in the global coordinate space: the
/// container's frame minus the space the bar reserves at the bottom.
private struct SlotNavigationContentBoundsKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var slotNavigationContentBounds: CGRect? {
        get { self[SlotNavigationContentBoundsKey.self] }
        set { self[SlotNavigationContentBoundsKey.self] = newValue }
    }
}
