#if os(iOS)
import SwiftUI

struct ReachabilityShelf: View {
    let actions: [ReachabilityAction]
    let onActivate: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var index = 0
    @State private var tickIndex = 0
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let step = ReachabilityGeometry.step(width: width)
            let effectiveIndex = min(index, max(0, actions.count - 1))
            let limitedDrag = resisted(drag, index: effectiveIndex, count: actions.count, step: step)

            ZStack(alignment: .topLeading) {
                ReachabilityShelfShape()
                    .fill(LinearGradient(stops: [
                        .init(color: Theme.surface.opacity(0.96), location: 0),
                        .init(color: Theme.surface.opacity(0.9), location: 0.45),
                        .init(color: Theme.surface.opacity(reduceTransparency ? 1 : 0), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)

                ForEach(actions.indices, id: \.self) { position in
                    let action = actions[position]
                    let x = width / 2 + CGFloat(position - effectiveIndex) * step + limitedDrag
                    let y = ReachabilityGeometry.curveY(x: x, width: width)
                    action.content
                        .id(action.id)
                        .frame(minWidth: ReachabilityGeometry.controlSize, minHeight: ReachabilityGeometry.controlSize)
                        .contentShape(Rectangle())
                        .accessibilityLabel(action.title)
                        .accessibilityIdentifier("reachability.action.\(action.id)")
                        .position(x: x, y: y)
                        .opacity(min(1, max(0, min(x, width - x) / ReachabilityGeometry.controlSize)))
                        .accessibilityHidden(x < 24 || x > width - 24)
                        .simultaneousGesture(TapGesture().onEnded {
                            AppInteractionHaptics.shared.selectionChanged()
                            if action.dismissesOnActivation { onActivate() }
                        })
                }

                HStack(spacing: 12) {
                    Button { move(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(effectiveIndex == 0)
                    .accessibilityLabel("Previous actions")
                    .accessibilityIdentifier("reachability.previous")

                    Text(actions[effectiveIndex].title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Button { move(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(effectiveIndex == actions.count - 1)
                    .accessibilityLabel("Next actions")
                    .accessibilityIdentifier("reachability.next")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, step / 2)
                .offset(y: ReachabilityGeometry.shelfHeight * 0.57)
                .frame(width: width)
            }
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .updating($drag) { value, state, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = value.translation.width
                    }
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let next = ReachabilityGeometry.settledIndex(current: effectiveIndex,
                            translation: value.translation.width, step: step, count: actions.count)
                        if tickIndex != next {
                            tickIndex = next
                            AppInteractionHaptics.shared.selectionChanged()
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let next = ReachabilityGeometry.settledIndex(current: effectiveIndex,
                            translation: value.predictedEndTranslation.width, step: step, count: actions.count)
                        select(next)
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("One-handed actions")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: move(by: 1)
                case .decrement: move(by: -1)
                @unknown default: break
                }
            }
        }
        .onAppear {
            index = min(1, max(0, actions.count - 1))
            tickIndex = index
        }
        .onChange(of: actions.count) { _ in
            index = min(index, max(0, actions.count - 1))
            tickIndex = index
        }
    }

    private func resisted(_ translation: CGFloat, index: Int, count: Int, step: CGFloat) -> CGFloat {
        let upper = CGFloat(index) * step
        let lower = -CGFloat(max(0, count - 1 - index)) * step
        if translation > upper { return upper + (translation - upper) * 0.2 }
        if translation < lower { return lower + (translation - lower) * 0.2 }
        return translation
    }

    private func move(by delta: Int) {
        select(min(max(0, index + delta), actions.count - 1))
    }

    private func select(_ next: Int) {
        if tickIndex != next { AppInteractionHaptics.shared.selectionChanged() }
        tickIndex = next
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.86)) {
            index = next
        }
    }
}

private struct ReachabilityShelfShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.50))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.50),
                          control: CGPoint(x: rect.midX, y: rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
#endif
