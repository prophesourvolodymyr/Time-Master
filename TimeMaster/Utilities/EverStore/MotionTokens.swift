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
    static let scrollBlurMaximumTrail: CGFloat = 10
    static let arcStretchBand: CGFloat = 52
    static let arcStretchMaximum: CGFloat = 6
    static let arcStretchSideways: CGFloat = 0.75
}


private struct EverRasterizedContentKey: EnvironmentKey {
    static let defaultValue = false
}

private struct EverArcStretchAppliedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everArcLensFrame: CGRect {
        get { slotNavigationArcLensFrame }
        set { slotNavigationArcLensFrame = newValue }
    }

    var everRasterizedContent: Bool {
        get { self[EverRasterizedContentKey.self] }
        set { self[EverRasterizedContentKey.self] = newValue }
    }

    var everArcStretchApplied: Bool {
        get { self[EverArcStretchAppliedKey.self] }
        set { self[EverArcStretchAppliedKey.self] = newValue }
    }
}

struct EverArcScrollOverflow: ViewModifier {
    @Environment(\.everArcLensFrame) private var arcFrame
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
    @Environment(\.everArcLensFrame) private var arcFrame
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

struct EverScrollMotion: ViewModifier {
    var appliesSmear = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUserScrolling = false
    @State private var trail: CGFloat = 0
    @State private var effectVisible = false
    @State private var sample = EverScrollBlurSample()

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *), appliesSmear {
            content
                .environment(\.everScrollExposure, EverScrollExposure(
                    trail: trail,
                    isVisible: effectVisible && !reduceMotion && scenePhase == .active
                ))
                .onScrollPhaseChange { oldPhase, phase, context in
                    isUserScrolling = phase == .interacting || phase == .decelerating
                    if !isUserScrolling {
                        clearBlur()
                    } else if oldPhase != .interacting && oldPhase != .decelerating {
                        sample.begin(at: context.geometry.contentOffset.y)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    guard appliesSmear, isUserScrolling, !reduceMotion, scenePhase == .active,
                          let distance = sample.distance(at: offset), distance != trail else { return }
                    if distance != 0 { effectVisible = true }
                    trail = distance
                }
                .task(id: trail != 0) { @MainActor in
                    if trail == 0 {
                        do { try await Task.sleep(nanoseconds: 80_000_000) }
                        catch { return }
                        effectVisible = false
                        return
                    }
                    while !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 100_000_000) }
                        catch { return }
                        if ProcessInfo.processInfo.systemUptime - sample.lastMovement >= 0.10 {
                            clearBlur()
                            return
                        }
                    }
                }
                .onChange(of: reduceMotion) { if $0 { clearBlur() } }
                .onChange(of: scenePhase) { if $0 != .active { clearBlur() } }
                .onDisappear {
                    isUserScrolling = false
                    clearBlur()
                }
        } else {
            content
        }
    }

    private func clearBlur() {
        sample.reset()
        trail = 0
    }
}

private struct EverScrollExposure {
    var trail: CGFloat = 0
    var isVisible = false
}

private struct EverScrollExposureKey: EnvironmentKey {
    static let defaultValue = EverScrollExposure()
}

private extension EnvironmentValues {
    var everScrollExposure: EverScrollExposure {
        get { self[EverScrollExposureKey.self] }
        set { self[EverScrollExposureKey.self] = newValue }
    }
}

struct EverArcStretch: ViewModifier {
    @Environment(\.everRasterizedContent) private var rasterizedContent
    @Environment(\.everArcStretchApplied) private var stretchApplied

    @ViewBuilder func body(content: Content) -> some View {
        if rasterizedContent || stretchApplied {
            content
        } else if #available(iOS 17.0, macOS 14.0, *) {
            content.modifier(EverScrollSmear(appliesSmear: false))
        } else {
            content
                .modifier(EverLegacyArcStretch())
                .environment(\.everArcStretchApplied, true)
        }
    }
}

private struct EverArcStretchSample: Equatable {
    var displacement: CGFloat = 0
    var height: CGFloat = 1

    init() {}

    init(frame: CGRect, arc: CGRect) {
        guard !arc.isEmpty, frame.height > 0 else { return }
        let x = min(1, max(0, (frame.midX - arc.minX) / arc.width))
        var t = x
        for _ in 0..<3 {
            let projected = t * (0.75 + t * (0.75 - 0.5 * t))
            t -= (projected - x) / (0.75 + 1.5 * t * (1 - t))
        }
        let edge = arc.height * 0.72 + 8
        let control = arc.height * 0.12 + 8
        let curve = arc.minY + edge + 3 * (control - edge) * t * (1 - t)
        guard frame.minY < curve, frame.maxY > curve - EverMotion.arcStretchBand else { return }
        let distance = min(1, max(0, (curve - frame.maxY) / EverMotion.arcStretchBand))
        let falloff = 1 - distance * distance * (3 - 2 * distance)
        displacement = (EverMotion.arcStretchMaximum * falloff * falloff * 4).rounded() / 4
        if displacement > 0 { height = frame.height }
    }
}

private struct EverArcStretchSampleKey: PreferenceKey {
    static let defaultValue = EverArcStretchSample()
    static func reduce(value: inout EverArcStretchSample, nextValue: () -> EverArcStretchSample) {
        value = nextValue()
    }
}

private struct EverLegacyArcStretch: ViewModifier {
    @Environment(\.everArcLensFrame) private var arcFrame
    @Environment(\.isPresented) private var isPresented
    @State private var sample = EverArcStretchSample()

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    let frame = CGRect(origin: geometry.frame(in: .global).origin, size: geometry.size)
                    Color.clear.preference(
                        key: EverArcStretchSampleKey.self,
                        value: EverArcStretchSample(frame: frame, arc: isPresented ? .zero : arcFrame)
                    )
                }
            }
            .scaleEffect(x: 1, y: 1 + sample.displacement / sample.height, anchor: .top)
            .onPreferenceChange(EverArcStretchSampleKey.self) { value in
                guard sample != value else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { sample = value }
            }
    }
}

struct EverScrollSmear: ViewModifier {
    var appliesSmear = true
    @Environment(\.everArcLensFrame) private var arcFrame
    @Environment(\.isPresented) private var isPresented
    @Environment(\.everScrollExposure) private var exposure

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            let lensEnabled = !arcFrame.isEmpty && !isPresented
            let smearEnabled = appliesSmear && exposure.isVisible
            let arc = arcFrame
            let trail = smearEnabled ? exposure.trail : 0
            let band = Float(EverMotion.arcStretchBand)
            let maximum = Float(EverMotion.arcStretchMaximum)
            let sideways = Float(EverMotion.arcStretchSideways)
            let sampleHeight = (appliesSmear ? EverMotion.scrollBlurMaximumTrail : 0) + (lensEnabled ? EverMotion.arcStretchMaximum : 0)
            let edgeBand = CGRect(x: arc.minX, y: arc.minY - EverMotion.arcStretchBand, width: arc.width, height: arc.height + EverMotion.arcStretchBand)
            content
                .environment(\.everRasterizedContent, true)
                .visualEffect { effect, geometry in
                    let frame = geometry.frame(in: .global)
                    let origin = frame.origin
                    let stretchesEdge = lensEnabled && frame.intersects(edgeBand)
                    return effect.layerEffect(
                        ShaderLibrary.everScrollShutter(
                            .float(Float(trail)),
                            .float4(
                                Float(arc.minX - origin.x),
                                Float(arc.minY - origin.y),
                                Float(stretchesEdge ? arc.width : 0),
                                Float(arc.height)
                            ),
                            .float3(band, maximum, sideways)
                        ),
                        maxSampleOffset: CGSize(
                            width: lensEnabled ? CGFloat(sideways) : 0,
                            height: sampleHeight
                        ),
                        isEnabled: smearEnabled || stretchesEdge
                    )
                }
                .animation(.linear(duration: 0.06), value: exposure.trail)
        } else {
            content
        }
    }
}

private final class EverScrollBlurSample {
    private var offset: CGFloat?
    private var time: TimeInterval = 0
    private var speed: CGFloat = 0
    private(set) var lastMovement: TimeInterval = 0

    func begin(at offset: CGFloat) {
        self.offset = offset
        time = ProcessInfo.processInfo.systemUptime
        lastMovement = time
        speed = 0
    }

    func distance(at offset: CGFloat) -> CGFloat? {
        let now = ProcessInfo.processInfo.systemUptime
        lastMovement = now
        guard let previous = self.offset else {
            begin(at: offset)
            return nil
        }
        let elapsed = now - time
        guard elapsed >= 1.0 / 30.0 else { return nil }
        self.offset = offset
        time = now
        guard elapsed < 0.15 else {
            speed = 0
            return 0
        }
        let velocity = min(6_000, max(-6_000, (offset - previous) / elapsed))
        if velocity * speed < 0 { speed = 0 }
        speed += (velocity - speed) * (1 - exp(-elapsed / 0.045))
        let distance = min(EverMotion.scrollBlurMaximumTrail, max(0, (abs(speed) - 1_000) / 400))
        return (distance * 4).rounded() / 4 * (speed < 0 ? -1 : 1)
    }

    func reset() {
        offset = nil
        speed = 0
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
