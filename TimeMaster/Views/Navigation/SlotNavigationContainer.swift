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
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SlotNavigationBar(
                    selection: $selection,
                    items: items,
                    bottomSafeArea: proxy.safeAreaInsets.bottom,
                    barHeight: barHeight,
                    onSelectionChanged: updateTransitionDirection(for:)
                )
            }
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
                lastSelection = selection
#if os(macOS)
                keyboardFocused = true
#endif
            }
            .onChange(of: selection) { newSelection in
                updateTransitionDirection(for: newSelection)
                lastSelection = newSelection
            }
            .animation(pageAnimation, value: selection)
            .accessibilityElement(children: .contain)
            #if os(macOS)
            .focusable()
            .focusEffectDisabled()
            .focused($keyboardFocused)
            .onKeyPress(phases: [.down, .repeat], action: handleKeyPress)
            #endif
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

                updateTransitionDirection(for: nextSelection)
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
        updateTransitionDirection(for: index)
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
