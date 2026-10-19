#if os(iOS)
import SwiftUI

struct ReachabilityActionsModifier: ViewModifier {
    let id: String
    let actions: [ReachabilityAction]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var isOpen = false
    @State private var progress: CGFloat = 0
    @State private var anchor: CGFloat = 0
    @State private var crossedThreshold = false

    func body(content: Content) -> some View {
        content
            .environment(\.reachabilityProgress, progress)
            .background {
                GeometryReader { proxy in
                    ReachabilityGestureBridge(
                        enabled: isVisible && !isOpen && !actions.isEmpty && scenePhase == .active,
                        onChange: { location, translation, began in
                            if began {
                                crossedThreshold = false
                                AppInteractionHaptics.shared.beganReveal()
                            }
                            anchor = ReachabilityGeometry.anchorY(location.y, height: proxy.size.height)
                            progress = ReachabilityGeometry.progress(translation: translation)
                            if progress >= 0.62, !crossedThreshold {
                                crossedThreshold = true
                                AppInteractionHaptics.shared.crossedThreshold()
                            }
                        },
                        onEnd: { translation, velocity, cancelled in
                            let opens = !cancelled && ReachabilityGeometry.shouldOpen(translation: translation, velocity: velocity)
                            withAnimation(motion) {
                                isOpen = opens
                                progress = opens ? 1 : 0
                            }
                            if opens { AppInteractionHaptics.shared.opened() }
                            else { AppInteractionHaptics.shared.dismissed() }
                        }
                    )
                }
            }
            .overlay {
                GeometryReader { proxy in
                    if !actions.isEmpty {
                        ZStack(alignment: .top) {
                            Button { dismiss() } label: {
                                Color.clear.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close one-handed actions")
                            .accessibilityIdentifier("reachability.dismiss")
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 20).onEnded { value in
                                    if value.translation.width > 48,
                                       value.translation.width > abs(value.translation.height) * 1.7 {
                                        dismiss()
                                    }
                                }
                            )

                            ReachabilityShelf(actions: actions, onActivate: dismiss)
                                .frame(height: ReachabilityGeometry.shelfHeight)
                                .offset(x: reduceMotion ? 0 : -proxy.size.width * (1 - progress),
                                        y: ReachabilityGeometry.anchorY(anchor == 0 ? proxy.size.height * 0.62 : anchor,
                                                                       height: proxy.size.height)
                                            - ReachabilityGeometry.shelfHeight / 2)
                                .opacity(progress)
                        }
                        .allowsHitTesting(isOpen)
                        .accessibilityHidden(!isOpen)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) { dismiss() }
                    }
                }
            }
            .preference(key: ReachabilityActivePreferenceKey.self, value: progress > 0)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                reset()
            }
            .onChange(of: id) { _ in reset() }
            .onChange(of: actions.isEmpty) { empty in
                if empty { reset() }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { reset() }
            }
            .accessibilityAction(named: "Show one-handed actions") {
                guard !actions.isEmpty else { return }
                anchor = 0
                AppInteractionHaptics.shared.prepare()
                withAnimation(motion) {
                    isOpen = true
                    progress = 1
                }
                AppInteractionHaptics.shared.opened()
            }
    }

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.36, dampingFraction: 0.88)
    }

    private func dismiss() {
        guard progress > 0 else { return }
        AppInteractionHaptics.shared.dismissed()
        withAnimation(motion) {
            isOpen = false
            progress = 0
        }
    }

    private func reset() {
        isOpen = false
        progress = 0
        crossedThreshold = false
    }
}
#endif
