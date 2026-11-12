import SwiftUI

enum TmaxGlow {
    static let night = Color(hex: "050302")
    static let umber = Color(hex: "2E1006")
    static let rust = Color(hex: "7A2A08")
    static let ember = Color(hex: "C4480F")
    static let flame = Theme.toolbarOrange
    static let blaze = Color(hex: "FF8A45")
    static let peach = Color(hex: "FFB27A")

    static let fill = LinearGradient(
        colors: [blaze, flame, ember],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func dissolve(_ boundary: Double = 0.62) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: blaze, location: 0),
                .init(color: flame, location: max(0.05, boundary - 0.3)),
                .init(color: ember.opacity(0.55), location: boundary),
                .init(color: ember.opacity(0), location: min(1, boundary + 0.32))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func wave(_ time: TimeInterval, period: Double, phase: Double = 0) -> Double {
        sin(time * 2 * .pi / period + phase)
    }
}

struct TmaxGlowBackground: View {
    enum Intensity { case hero, ambient }

    var intensity: Intensity = .ambient
    var rises = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearedAt: Date?

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || appearedAt == nil || scenePhase != .active)) { timeline in
                TmaxGlowField(
                    intensity: intensity,
                    size: proxy.size,
                    time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                    rise: rise(at: timeline.date)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { appearedAt = .now }
        .onDisappear { appearedAt = nil }
    }

    private func rise(at date: Date) -> Double {
        guard rises, !reduceMotion else { return 1 }
        guard let appearedAt else { return 0 }
        let progress = min(1, max(0, date.timeIntervalSince(appearedAt) / 1.8))
        return 1 - pow(1 - progress, 3)
    }
}

private struct TmaxGlowField: View {
    let intensity: TmaxGlowBackground.Intensity
    let size: CGSize
    let time: TimeInterval
    let rise: Double

    var body: some View {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let drift = TmaxGlow.wave(time, period: 19)
        let breathe = (TmaxGlow.wave(time, period: 11, phase: 0.8) + 1) / 2
        let wander = TmaxGlow.wave(time, period: 27, phase: 1.7)
        let hero = intensity == .hero
        let strength = hero ? 1.0 : 0.5
        let reach = (hero ? 1.0 : 0.6) * (0.3 + 0.7 * rise)

        ZStack {
            hero ? Color.black : Theme.background
            glow([
                .init(color: TmaxGlow.umber.opacity(0.9 * strength), location: 0),
                .init(color: TmaxGlow.umber.opacity(0), location: 1)
            ])
            .frame(width: width * 2.4, height: height * 1.4 * reach)
            .position(x: width * 0.5, y: height)
            glow([
                .init(color: TmaxGlow.flame.opacity(0.85 * strength), location: 0),
                .init(color: TmaxGlow.ember.opacity(0.62 * strength), location: 0.28),
                .init(color: TmaxGlow.rust.opacity(0.38 * strength), location: 0.55),
                .init(color: TmaxGlow.umber.opacity(0), location: 1)
            ])
            .frame(width: width * 1.9, height: height * 0.82 * reach * (0.94 + 0.06 * breathe))
            .position(x: width * (0.5 + 0.06 * drift), y: height * 1.03)
            glow([
                .init(color: TmaxGlow.peach.opacity(0.9 * strength), location: 0),
                .init(color: TmaxGlow.blaze.opacity(0.55 * strength), location: 0.4),
                .init(color: TmaxGlow.flame.opacity(0), location: 1)
            ])
            .frame(width: width * 1.25, height: height * 0.26 * reach * (0.88 + 0.12 * breathe))
            .position(x: width * (0.5 - 0.07 * drift), y: height * 1.01)
            glow([
                .init(color: TmaxGlow.blaze.opacity(0.3 * strength), location: 0),
                .init(color: TmaxGlow.ember.opacity(0.12 * strength), location: 0.5),
                .init(color: TmaxGlow.ember.opacity(0), location: 1)
            ])
            .frame(width: width * 1.1, height: height * 0.5 * reach)
            .position(x: width * (0.5 + 0.34 * wander), y: height * (0.9 + 0.03 * breathe))
            if !hero {
                glow([
                    .init(color: TmaxGlow.umber.opacity(0.55), location: 0),
                    .init(color: TmaxGlow.umber.opacity(0), location: 1)
                ])
                .frame(width: width * 1.4, height: height * 0.55)
                .position(x: width * (0.85 + 0.05 * wander), y: 0)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func glow(_ stops: [Gradient.Stop]) -> EllipticalGradient {
        EllipticalGradient(stops: stops, center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
    }
}

struct TmaxGlowSurface: ViewModifier {
    var cornerRadius: CGFloat = 20
    var glow: Double = 1

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape.fill(LinearGradient(colors: [Theme.surface2, Theme.surface], startPoint: .top, endPoint: .bottom))
                shape.fill(EllipticalGradient(
                    stops: [
                        .init(color: TmaxGlow.flame.opacity(0.34 * glow), location: 0),
                        .init(color: TmaxGlow.ember.opacity(0.16 * glow), location: 0.45),
                        .init(color: TmaxGlow.ember.opacity(0), location: 1)
                    ],
                    center: UnitPoint(x: 0.5, y: 1.15),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.85
                ))
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(contrast == .increased ? 0.4 : 0.1),
                            TmaxGlow.peach.opacity((contrast == .increased ? 0.8 : 0.45) * glow)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func tmaxGlowBackground(_ intensity: TmaxGlowBackground.Intensity = .ambient, rises: Bool = false) -> some View {
        background(TmaxGlowBackground(intensity: intensity, rises: rises))
    }

    func tmaxGlowSurface(cornerRadius: CGFloat = 20, glow: Double = 1) -> some View {
        modifier(TmaxGlowSurface(cornerRadius: cornerRadius, glow: glow))
    }
}

struct TmaxGlowTile: View {
    let side: CGFloat
    var breathe: Double = 0.5
    var cornerRadiusFraction: CGFloat = 0.235
    var showsRim = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * cornerRadiusFraction, style: .continuous)
        let markWidth = side * 0.6
        ZStack {
            shape.fill(LinearGradient(
                stops: [
                    .init(color: Color(hex: "0D0705"), location: 0),
                    .init(color: Color(hex: "120805"), location: 0.4),
                    .init(color: Color(hex: "2A0E05"), location: 0.62),
                    .init(color: Color(hex: "6E260A"), location: 0.78),
                    .init(color: Color(hex: "C9531A"), location: 0.9),
                    .init(color: Color(hex: "F08C4C"), location: 0.97),
                    .init(color: TmaxGlow.peach, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            shape.fill(EllipticalGradient(
                stops: [
                    .init(color: TmaxGlow.peach.opacity(0.42 + 0.18 * breathe), location: 0),
                    .init(color: TmaxGlow.flame.opacity(0.3 + 0.1 * breathe), location: 0.32),
                    .init(color: TmaxGlow.flame.opacity(0), location: 1)
                ],
                center: UnitPoint(x: 0.5, y: 1.02),
                startRadiusFraction: 0,
                endRadiusFraction: 0.72
            ))
            TmaxMark()
                .fill(TmaxGlow.dissolve(0.6 + 0.08 * breathe))
                .frame(width: markWidth, height: markWidth / TmaxMark.aspectRatio)
                .offset(y: -side * 0.07)
            if showsRim {
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.12), location: 0),
                            .init(color: .white.opacity(0.03), location: 0.55),
                            .init(color: TmaxGlow.peach.opacity(0.95), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: max(1, side * 0.012)
                )
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
    }
}

struct TmaxGlowLogo: View {
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var onScreen = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated || reduceMotion || !onScreen || scenePhase != .active)) { timeline in
                let breathe = animated && !reduceMotion
                    ? (TmaxGlow.wave(timeline.date.timeIntervalSinceReferenceDate, period: 6.5) + 1) / 2
                    : 0.5
                TmaxGlowTile(side: side, breathe: breathe)
                    .background {
                        RoundedRectangle(cornerRadius: side * 0.235, style: .continuous)
                            .fill(TmaxGlow.flame.opacity(0.26 + 0.14 * breathe))
                            .scaleEffect(0.86)
                            .blur(radius: side * 0.16)
                            .offset(y: side * 0.12)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tmax")
    }
}
