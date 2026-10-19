import SwiftUI

struct WorkoutFloatingWidget<Content: View>: View {
    let width: CGFloat
    var respectsNavigationBounds = true
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @State private var anchor = CGPoint(x: 1, y: 1)
    @State private var measuredHeight: CGFloat = 0
    @GestureState private var translation: CGSize = .zero
    @Namespace private var coordinateSpace
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var edgeInset: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let visibleHeight = respectsNavigationBounds ? navigationBounds.map {
                min(geometry.size.height, max(0, $0.maxY - geometry.frame(in: .global).minY - edgeInset))
            } ?? geometry.size.height : geometry.size.height
            let container = CGSize(width: geometry.size.width, height: visibleHeight)
            let size = CGSize(width: min(width, container.width), height: max(controlSize, measuredHeight))
            let origin = WorkoutWidgetPlacement.origin(
                container: container, widget: size, anchor: anchor, translation: translation
            )

            content()
                .frame(width: size.width)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeight = $0 }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named(coordinateSpace))
                        .updating($translation) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            move(to: WorkoutWidgetPlacement.snappedAnchor(
                                anchor, by: value.translation, container: container, widget: size
                            ))
                        }
                )
                .accessibilityAction(named: "Move widget to top") { move(to: CGPoint(x: anchor.x, y: 0)) }
                .accessibilityAction(named: "Move widget to bottom") { move(to: CGPoint(x: anchor.x, y: 1)) }
                .accessibilityAction(named: "Move widget left") { move(to: CGPoint(x: 0, y: anchor.y)) }
                .accessibilityAction(named: "Move widget right") { move(to: CGPoint(x: 1, y: anchor.y)) }
                .position(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        }
        .coordinateSpace(name: coordinateSpace)
        .padding(edgeInset)
    }

    private func move(to anchor: CGPoint) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
            self.anchor = anchor
        }
    }
}
