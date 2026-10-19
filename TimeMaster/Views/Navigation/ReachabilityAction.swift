import SwiftUI

struct ReachabilityAction: Identifiable {
    let id: String
    let title: String
    let dismissesOnActivation: Bool
    let content: AnyView

    init<V: View>(_ id: String, title: String, dismissesOnActivation: Bool = true, @ViewBuilder content: () -> V) {
        self.id = id
        self.title = title
        self.dismissesOnActivation = dismissesOnActivation
        self.content = AnyView(content())
    }
}

struct ReachabilityActivePreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct ReachabilityProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var reachabilityProgress: CGFloat {
        get { self[ReachabilityProgressKey.self] }
        set { self[ReachabilityProgressKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func oneHandedActions(id: String, actions: [ReachabilityAction]) -> some View {
        #if os(iOS)
        modifier(ReachabilityActionsModifier(id: id, actions: actions))
        #else
        self
        #endif
    }

    func oneHandedActionSource() -> some View {
        modifier(ReachabilitySourceModifier())
    }
}

private struct ReachabilitySourceModifier: ViewModifier {
    @Environment(\.reachabilityProgress) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .offset(y: reduceMotion ? 0 : -64 * progress)
            .allowsHitTesting(progress == 0)
            .accessibilityHidden(progress > 0)
    }
}
