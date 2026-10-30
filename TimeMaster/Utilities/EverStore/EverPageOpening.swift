import SwiftUI

enum EverPageMotion {
    static let duration = 0.24

    static func sample(_ fraction: Double, duration: Double = EverPageMotion.duration,
                       emergence: Bool = false) -> (travel: Float, depth: Float, blur: Float) {
        let time = min(1, max(0, fraction))
        let remaining = 1 - time
        let cube = remaining * remaining * remaining
        let travel = cube * remaining * (emergence ? 1 : 1 + 4 * time)
        let velocity = emergence ? 4 * cube : 20 * time * cube
        let peak = emergence ? 4.0 : 2.109375
        return (Float(travel), Float(velocity / peak * 0.82),
                Float(min(0.085, velocity * 0.012 / duration)))
    }
}

private struct EverPageIsOpeningKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everPageIsOpening: Bool {
        get { self[EverPageIsOpeningKey.self] }
        set { self[EverPageIsOpeningKey.self] = newValue }
    }
}

extension View {
    func everPageOpening(from edge: Edge = .bottom, when trigger: String? = nil) -> some View {
        modifier(EverPageOpeningModifier(edge: edge, trigger: trigger))
    }

    func everSheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                 @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom).keyNavHost() }
    }

    func everSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                     @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom).keyNavHost() }
    }

    func everFullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                           @ViewBuilder content: @escaping () -> Content) -> some View {
#if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom).keyNavHost() }
#else
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom) }
#endif
    }

    func everFullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                               @ViewBuilder content: @escaping (Item) -> Content) -> some View {
#if os(macOS)
        sheet(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom).keyNavHost() }
#else
        fullScreenCover(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom) }
#endif
    }

    func everNavigationDestination<Item: Hashable, Content: View>(for type: Item.Type,
                                                                  @ViewBuilder destination: @escaping (Item) -> Content) -> some View {
        navigationDestination(for: type) { destination($0).everPageOpening() }
    }

    func everNavigationDestination<Content: View>(isPresented: Binding<Bool>,
                                                  @ViewBuilder destination: @escaping () -> Content) -> some View {
        navigationDestination(isPresented: isPresented) { destination().everPageOpening() }
    }
}

private struct EverPageOpeningModifier: ViewModifier {
    let edge: Edge
    let trigger: String?
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.everPageIsOpening) private var parentIsOpening
    @Environment(\.everPageTravelActive) private var pageTravelIsActive
    @State private var progress: CGFloat = 0
    @State private var isOpening = true

    func body(content: Content) -> some View {
        let bypass = parentIsOpening || pageTravelIsActive
        content
            .environment(\.everPageIsOpening, isOpening && !bypass)
            .offset(x: bypass || reduceMotion ? 0 : displacement.width * (1 - progress),
                    y: bypass || reduceMotion ? 0 : displacement.height * (1 - progress))
            .opacity(bypass ? 1 : 0.65 + 0.35 * progress)
            .task(id: trigger) {
                guard !bypass else {
                    progress = 1
                    isOpening = false
                    return
                }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    progress = 0
                    isOpening = true
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.12)
                              : .timingCurve(0.16, 0.8, 0.24, 1, duration: EverPageMotion.duration)) {
                    progress = 1
                }
                try? await Task.sleep(nanoseconds: UInt64(EverPageMotion.duration * 1_000_000_000))
                isOpening = false
            }
    }

    private var displacement: CGSize {
        switch edge {
        case .top: CGSize(width: 0, height: -28)
        case .bottom: CGSize(width: 0, height: 28)
        case .leading: CGSize(width: layoutDirection == .leftToRight ? -28 : 28, height: 0)
        case .trailing: CGSize(width: layoutDirection == .leftToRight ? 28 : -28, height: 0)
        }
    }
}
