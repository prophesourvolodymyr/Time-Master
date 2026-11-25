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

enum EverBounceTone: Equatable {
    case dark
    case light

    var wash: Double {
        switch self {
        case .dark: 0.16
        case .light: 0
        }
    }

    var rim: Double {
        switch self {
        case .dark: 0.42
        case .light: 0
        }
    }

    var bloom: Double {
        switch self {
        case .dark: 0
        case .light: 0.4
        }
    }
}

enum EverBounceKind: Equatable {
    case lift(CGFloat)
    case squeeze

    var points: CGFloat {
        switch self {
        case .lift(let points): points
        case .squeeze: -EverBounceMotion.squeezeDepth
        }
    }

    var press: Animation {
        switch self {
        case .lift: EverBounceMotion.liftOn
        case .squeeze: EverBounceMotion.squeezeOn
        }
    }

    var release: Animation {
        switch self {
        case .lift: EverBounceMotion.liftOff
        case .squeeze: EverBounceMotion.squeezeOff
        }
    }
}

enum EverBounceMotion {
    static let liftOn = Animation.spring(response: 0.31, dampingFraction: 0.72)
    static let liftOff = Animation.spring(response: 0.42, dampingFraction: 0.38)
    static let squeezeOn = Animation.easeInOut(duration: 0.18)
    static let squeezeOff = Animation.spring(response: 0.3, dampingFraction: 0.42)
    static let lightOn = Animation.easeOut(duration: 0.12)
    static let lightOff = Animation.easeInOut(duration: 0.34)
    static let hold: TimeInterval = 0.12
    static let lift: CGFloat = 10
    static let compactLift: CGFloat = 8
    static let squeezeDepth: CGFloat = 8
    static let maximumGrowth: CGFloat = 0.3
    static let stretchReach: CGFloat = 24
    static let stretchSwell: CGFloat = 16
}

struct EverBounceEffect: GeometryEffect {
    var press: CGFloat
    var stretch: CGSize
    let lift: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(press, AnimatablePair(stretch.width, stretch.height)) }
        set {
            press = newValue.first
            stretch = CGSize(width: newValue.second.first, height: newValue.second.second)
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let limit = EverBounceMotion.maximumGrowth
        let growth = min(limit, max(-limit, lift / max(width, height)))
        var scaleX = 1 + press * growth
        var scaleY = scaleX
        var shift = CGPoint.zero
        let aspect = width / height
        let pull = CGPoint(x: stretch.width / aspect, y: stretch.height)
        let length = hypot(pull.x, pull.y)
        if length > 0.01 {
            let direction = CGPoint(x: pull.x / length, y: pull.y / length)
            let reach = length / (length + 5 * width)
            let swell = 1 + EverBounceMotion.stretchSwell * reach / height * abs(abs(direction.x) - abs(direction.y))
            if abs(direction.x) > abs(direction.y) {
                scaleX *= swell
                scaleY /= swell
            } else {
                scaleX /= swell
                scaleY *= swell
            }
            shift = CGPoint(x: direction.x * EverBounceMotion.stretchReach * reach, y: direction.y * EverBounceMotion.stretchReach * reach)
        }
        let transform = CGAffineTransform(translationX: width / 2 + shift.x, y: height / 2 + shift.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -width / 2, y: -height / 2)
        return ProjectionTransform(transform)
    }
}

struct EverPressLight<Surface: InsettableShape>: View {
    let shape: Surface
    let tone: EverBounceTone
    var point: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = point.map { UnitPoint(x: $0.x / max(size.width, 1), y: $0.y / max(size.height, 1)) } ?? UnitPoint(x: 0.5, y: 0.4)
            let reach = min(160, max(44, max(size.width, size.height) * 0.8))
            ZStack {
                if tone.wash > 0 {
                    shape
                        .fill(RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(tone.wash), location: 0),
                                .init(color: Color.white.opacity(tone.wash * 0.36), location: 0.45),
                                .init(color: Color.white.opacity(0), location: 1)
                            ],
                            center: center,
                            startRadius: 0,
                            endRadius: reach
                        ))
                        .blendMode(.plusLighter)
                }
                if tone.rim > 0 {
                    shape.strokeBorder(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(tone.rim), location: 0),
                                .init(color: Color.white.opacity(tone.rim * 0.45), location: 0.5),
                                .init(color: Color.white.opacity(0.05), location: 1)
                            ],
                            center: center,
                            startRadius: 0,
                            endRadius: reach * 1.25
                        ),
                        lineWidth: 1
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct EverPressBloom<Surface: Shape>: View {
    let shape: Surface
    let strength: Double

    var body: some View {
        shape
            .fill(Color.white.opacity(strength))
            .blur(radius: 10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct EverBouncePopsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var everBouncePops: Bool {
        get { self[EverBouncePopsKey.self] }
        set { self[EverBouncePopsKey.self] = newValue }
    }
}

struct EverBounceModifier<Surface: InsettableShape>: ViewModifier {
    let isPressed: Bool
    let shape: Surface
    let tone: EverBounceTone
    let kind: EverBounceKind
    let tracks: Bool
    let lights: Bool
    let pops: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.everBouncePops) private var popsAllowed
    @State private var engaged = false
    @State private var lit = false
    @State private var pressedAt: TimeInterval = 0
    @State private var sawPress = false
    @State private var settleTask: Task<Void, Never>?
    @State private var point: CGPoint?
    @GestureState(resetTransaction: Transaction(animation: EverBounceMotion.liftOff)) private var drag = CGSize.zero

    func body(content: Content) -> some View {
        content
            .background {
                if lit, lights, tone.bloom > 0 {
                    EverPressBloom(shape: shape, strength: tone.bloom)
                        .transition(.opacity)
                }
            }
            .overlay {
                if lit, lights, tone.wash > 0 || tone.rim > 0 {
                    EverPressLight(shape: shape, tone: tone, point: point)
                        .transition(.opacity)
                }
            }
            .modifier(EverBounceTracking(gesture: track, isActive: tracks && isEnabled))
            .modifier(EverBounceEffect(
                press: engaged && !reduceMotion ? 1 : 0,
                stretch: tracks && !reduceMotion ? drag : .zero,
                lift: kind.points
            ))
            .modifier(EverBounceChange(value: isPressed, action: respond))
            .onAppear { if pops { AppInteractionHaptics.shared.preparePress() } }
            .onDisappear { reset() }
            .tmaxPointer()
    }

    private var track: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($drag) { value, state, _ in state = value.translation }
            .onChanged { value in point = value.location }
            .onEnded { value in
                let pressed = sawPress
                sawPress = false
                guard !pressed, hypot(value.translation.width, value.translation.height) < 10 else { return }
                respond(true)
                respond(false)
            }
    }

    private func respond(_ pressed: Bool) {
        settleTask?.cancel()
        settleTask = nil
        if pressed {
            sawPress = true
            pressedAt = ProcessInfo.processInfo.systemUptime
            if pops && popsAllowed { AppInteractionHaptics.shared.pressed() }
            withAnimation(kind.press) { engaged = true }
            if lights { withAnimation(EverBounceMotion.lightOn) { lit = true } }
            return
        }
        let wait = EverBounceMotion.hold - (ProcessInfo.processInfo.systemUptime - pressedAt)
        guard wait > 0.01 else {
            settle()
            return
        }
        settleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            settle()
        }
    }

    private func settle() {
        settleTask = nil
        withAnimation(kind.release) { engaged = false }
        withAnimation(EverBounceMotion.lightOff) { lit = false }
    }

    private func reset() {
        settleTask?.cancel()
        settleTask = nil
        engaged = false
        lit = false
        sawPress = false
    }
}

private struct EverBounceChange: ViewModifier {
    let value: Bool
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        content.onChange(of: value) { _, now in action(now) }
        #else
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { _, now in action(now) }
        } else {
            content.onChange(of: value, perform: action)
        }
        #endif
    }
}

extension View {
    func everBounce<Surface: InsettableShape>(
        _ isPressed: Bool,
        in shape: Surface,
        tone: EverBounceTone = .dark,
        kind: EverBounceKind = .lift(EverBounceMotion.lift),
        tracks: Bool = false,
        lights: Bool = true,
        pops: Bool = false
    ) -> some View {
        modifier(EverBounceModifier(isPressed: isPressed, shape: shape, tone: tone, kind: kind, tracks: tracks, lights: lights, pops: pops))
    }
}

private struct EverBounceTracking<Tracker: Gesture>: ViewModifier {
    let gesture: Tracker
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content.simultaneousGesture(gesture, including: isActive ? .all : .none)
        #else
        content
        #endif
    }
}
