import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum EverMotion {
    static let press = Animation.easeOut(duration: 0.10)
    static let release = Animation.interpolatingSpring(mass: 0.7, stiffness: 500, damping: 38)
    static let state = Animation.interpolatingSpring(mass: 0.8, stiffness: 420, damping: 42)
    static let disclosure = Animation.interpolatingSpring(mass: 0.8, stiffness: 480, damping: 44)
    static let opacityOnly = Animation.easeOut(duration: 0.15)
}

extension EnvironmentValues {
    var everArcFrame: CGRect {
        get { slotNavigationArcFrame }
        set { slotNavigationArcFrame = newValue }
    }
}

struct EverArcScrollOverflow: ViewModifier {
    @Environment(\.everArcFrame) private var arcFrame
    @Environment(\.isPresented) private var isPresented

    @ViewBuilder func body(content: Content) -> some View {
        let overflow = arcFrame.isEmpty || isPresented ? 0 : arcFrame.height
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .scrollClipDisabled(overflow > 0)
                .clipShape(ScrollContentClip(bottomOverflow: overflow))
        } else {
            content
                .padding(.bottom, -overflow)
                .clipShape(ScrollContentClip(bottomOverflow: overflow))
        }
    }
}

struct EverArcScrollableContent: ViewModifier {
    @Environment(\.everArcFrame) private var arcFrame
    @Environment(\.isPresented) private var isPresented

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
        } else {
            content.padding(.bottom, arcFrame.isEmpty || isPresented ? 0 : arcFrame.height)
        }
    }
}

private struct ScrollContentClip: Shape {
    let bottomOverflow: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + bottomOverflow))
    }
}

struct EverVerticalScrollOffset: ViewModifier {
    @Binding var offset: CGFloat

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                -(geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, value in
                offset = value
            }
        } else {
            content
        }
    }
}

struct EverPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.standard)
    }
}

enum EverHaptic {
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #else
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #else
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #else
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}
