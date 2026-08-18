import SwiftUI

struct SlotNavigationContainer<Content: View>: View {
    @Binding private var selection: Int
    let items: [SlotNavigationItem]
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transitionDirection: PageTransitionDirection = .forward
    @State private var lastSelection = 0

    init(
        selection: Binding<Int>,
        items: [SlotNavigationItem] = SlotNavigationItem.timeMaster,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _selection = selection
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content()
                    .id(selection)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(pageSwipeGesture)

            SlotNavigationBar(
                selection: $selection,
                items: items,
                onSelectionChanged: updateTransitionDirection(for:)
            )
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            lastSelection = selection
        }
        .onChange(of: selection) { newSelection in
            updateTransitionDirection(for: newSelection)
            lastSelection = newSelection
        }
        .animation(pageAnimation, value: selection)
        .accessibilityElement(children: .contain)
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

    private func updateTransitionDirection(for newSelection: Int) {
        transitionDirection = newSelection >= lastSelection ? .forward : .backward
    }
}

private enum PageTransitionDirection {
    case forward
    case backward
}
