import SwiftUI

struct SlotNavigationContainer<Content: View>: View {
    @Binding private var selection: Int
    let items: [SlotNavigationItem]
    @ViewBuilder let content: () -> Content
    private let barHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#if os(macOS)
    @FocusState private var keyboardFocused: Bool
#endif
    @State private var transitionDirection: PageTransitionDirection = .forward
    @State private var lastSelection = 0
    @State private var navigationPresentation: SlotNavigationPresentation = .full
    @State private var hiddenNavigationIsRevealed = false
    @State private var hiddenNavigationDismissTask: Task<Void, Never>?

    private var arcCurveOffset: CGFloat {
#if os(iOS)
        8
#else
        54
#endif
    }

    init(
        selection: Binding<Int>,
        items: [SlotNavigationItem] = SlotNavigationItem.timeMaster,
        barHeight: CGFloat = 126,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _selection = selection
        self.items = items
        self.barHeight = max(126, barHeight)
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                content()
                    .id(selection)
                    .transition(pageTransition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(pageSwipeGesture)
                    .simultaneousGesture(hiddenNavigationRevealGesture(in: proxy.size))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if effectiveNavigationPresentation != .hidden {
                    navigationBar(
                        bottomSafeArea: proxy.safeAreaInsets.bottom,
                        layout: barLayout(for: effectiveNavigationPresentation)
                    )
                }
            }
#if os(iOS)
            .overlay(alignment: .bottom) {
                if effectiveNavigationPresentation == .hidden, hiddenNavigationIsRevealed {
                    navigationBar(
                        bottomSafeArea: proxy.safeAreaInsets.bottom,
                        layout: .inline
                    )
                    .padding(.bottom, proxy.safeAreaInsets.bottom)
                    .transition(navigationPresentationTransition)
                }
            }
#endif
#if os(macOS)
            .overlay(alignment: .bottom) {
                SlotNavigationArcLineShape(curveOffset: arcCurveOffset)
                    .stroke(Color.black.opacity(0.72), lineWidth: 8)
                    .frame(height: barHeight)
                    .blur(radius: 9)
                    .allowsHitTesting(false)
            }
#endif
            .background(Theme.background.ignoresSafeArea())
            .onAppear {
                navigationPresentation = defaultNavigationPresentation(for: selection)
                lastSelection = selection
#if os(macOS)
                keyboardFocused = true
#endif
            }
            .onDisappear {
                hiddenNavigationDismissTask?.cancel()
            }
            .onChange(of: selection) { newSelection in
                updateTransitionDirection(for: newSelection)
                applyNavigationPresentation(defaultNavigationPresentation(for: newSelection))
                lastSelection = newSelection
                if effectiveNavigationPresentation == .hidden, hiddenNavigationIsRevealed {
                    scheduleHiddenNavigationDismissal()
                }
            }
            .onPreferenceChange(SlotNavigationPresentationPreferenceKey.self) { requestedPresentation in
                applyNavigationPresentation(resolvedNavigationPresentation(requestedPresentation))
            }
            .animation(pageAnimation, value: selection)
            .animation(navigationPresentationAnimation, value: effectiveNavigationPresentation)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Show navigation") {
                revealHiddenNavigation()
            }
            #if os(macOS)
            .focusable()
            .focusEffectDisabled()
            .focused($keyboardFocused)
            .onKeyPress(phases: [.down, .repeat], action: handleKeyPress)
            #endif
        }
    }

    private var effectiveNavigationPresentation: SlotNavigationPresentation {
#if os(iOS)
        navigationPresentation
#else
        .full
#endif
    }

    private var navigationPresentationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.9)
    }

    private var navigationPresentationTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private func barLayout(for presentation: SlotNavigationPresentation) -> SlotNavigationBarLayout {
        presentation == .full ? .full : .inline
    }
    private func defaultNavigationPresentation(for index: Int) -> SlotNavigationPresentation {
        guard items.indices.contains(index) else { return .full }
        return items[index].presentation
    }
    private func resolvedNavigationPresentation(
        _ requestedPresentation: SlotNavigationPresentation?
    ) -> SlotNavigationPresentation {
        let destinationPresentation = defaultNavigationPresentation(for: selection)
        guard let requestedPresentation else { return destinationPresentation }

        if destinationPresentation == .full, requestedPresentation != .full {
            return .full
        }
        if destinationPresentation == .inline, requestedPresentation == .full {
            return .inline
        }
        if destinationPresentation == .hidden {
            return .hidden
        }
        return requestedPresentation
    }

    private func navigationBar(
        bottomSafeArea: CGFloat,
        layout: SlotNavigationBarLayout
    ) -> some View {
        SlotNavigationBar(
            selection: $selection,
            items: items,
            bottomSafeArea: bottomSafeArea,
            barHeight: barHeight,
            layout: layout,
            onSelectionChanged: handleNavigationSelection(_:))
        .transition(navigationPresentationTransition)
    }

    private func applyNavigationPresentation(_ requestedPresentation: SlotNavigationPresentation) {
        guard navigationPresentation != requestedPresentation else { return }

        hiddenNavigationDismissTask?.cancel()
        withAnimation(navigationPresentationAnimation) {
            navigationPresentation = requestedPresentation
            if requestedPresentation != .hidden {
                hiddenNavigationIsRevealed = false
            }
        }
    }

    private func handleNavigationSelection(_ index: Int) {
        updateTransitionDirection(for: index)
        applyNavigationPresentation(defaultNavigationPresentation(for: index))
        if effectiveNavigationPresentation == .hidden, hiddenNavigationIsRevealed {
            scheduleHiddenNavigationDismissal()
        }
    }

    private func hiddenNavigationRevealGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onEnded { value in
                guard effectiveNavigationPresentation == .hidden,
                      !hiddenNavigationIsRevealed,
                      value.startLocation.y >= size.height - 88,
                      (value.startLocation.x <= 44 || value.startLocation.x >= size.width - 44),
                      value.translation.height <= -42,
                      abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }

                revealHiddenNavigation()
            }
    }

    private func revealHiddenNavigation() {
        guard effectiveNavigationPresentation == .hidden else { return }

        hiddenNavigationDismissTask?.cancel()
        withAnimation(navigationPresentationAnimation) {
            hiddenNavigationIsRevealed = true
        }
        scheduleHiddenNavigationDismissal()
    }

    private func scheduleHiddenNavigationDismissal() {
        hiddenNavigationDismissTask?.cancel()
        hiddenNavigationDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(navigationPresentationAnimation) {
                hiddenNavigationIsRevealed = false
            }
        }
    }

    private var pageAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.16)
        }
        return .easeOut(duration: 0.28)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        let insertionEdge: Edge = transitionDirection == .forward ? .trailing : .leading
        let removalEdge: Edge = transitionDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)
                guard abs(horizontalDistance) > 56,
                      abs(horizontalDistance) > verticalDistance * 1.25 else { return }

                let direction = horizontalDistance < 0 ? 1 : -1
                let nextSelection = min(
                    max(selection + direction, 0),
                    items.count - 1
                )
                guard nextSelection != selection else { return }

                handleNavigationSelection(nextSelection)
                withAnimation(pageAnimation) {
                    selection = nextSelection
                }
            }
    }

#if os(macOS)
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            moveKeyboardSelection(by: -1)
            return .handled
        case .rightArrow:
            moveKeyboardSelection(by: 1)
            return .handled
        default:
            break
        }

        guard let character = keyPress.characters.first,
              let number = Int(String(character)),
              number > 0 else {
            return .ignored
        }

        let destinationID = number - 1
        guard let index = items.firstIndex(where: { $0.id == destinationID }) else { return .ignored }
        selectFromKeyboard(index)
        return .handled
    }

    private func moveKeyboardSelection(by delta: Int) {
        let nextSelection = min(max(selection + delta, 0), items.count - 1)
        guard nextSelection != selection else { return }
        selectFromKeyboard(nextSelection)
    }

    private func selectFromKeyboard(_ index: Int) {
        guard items.indices.contains(index), index != selection else { return }
        handleNavigationSelection(index)
        withAnimation(pageAnimation) {
            selection = index
        }
    }
#endif
    private func updateTransitionDirection(for newSelection: Int) {
        transitionDirection = newSelection >= lastSelection ? .forward : .backward
    }
}

private enum PageTransitionDirection {
    case forward
    case backward
}
