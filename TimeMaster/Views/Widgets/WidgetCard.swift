import SwiftUI

private struct WidgetTintKey: EnvironmentKey {
    static let defaultValue = WidgetTint.graphite
}

extension EnvironmentValues {
    var widgetTint: WidgetTint {
        get { self[WidgetTintKey.self] }
        set { self[WidgetTintKey.self] = newValue }
    }
}

enum WidgetFont {
    static func hero(_ size: CGFloat) -> Font {
        TimeMasterFont.black(size, relativeTo: .largeTitle).monospacedDigit()
    }

    static func title(_ size: CGFloat) -> Font {
        TimeMasterFont.black(size, relativeTo: .title3)
    }

    static func label() -> Font {
        TimeMasterFont.body(13, relativeTo: .caption)
    }

    static func chip() -> Font {
        TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit()
    }
}

struct WidgetCard<Content: View>: View {
    private let tint: WidgetTint
    private let art: WidgetArt?
    private let spot: WidgetArtSpot
    private let content: Content

    init(tint: WidgetTint, @ViewBuilder content: () -> Content) {
        self.tint = tint
        art = nil
        spot = .corner
        self.content = content()
    }

    init(art: WidgetArt, spot: WidgetArtSpot, @ViewBuilder content: () -> Content) {
        tint = art.tint
        self.art = art
        self.spot = spot
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.widgetTint, tint)
            .foregroundStyle(tint.ink)
            .background {
                if let art {
                    WidgetTintBackground(art: art, spot: spot)
                } else {
                    WidgetTintBackground(tint: tint)
                }
            }
    }
}

struct WidgetHero: View {
    let text: String
    var size: CGFloat = 44

    @Environment(\.widgetTint) private var tint

    var body: some View {
        Text(text)
            .font(WidgetFont.hero(size))
            .kerning(-size * 0.03)
            .foregroundStyle(tint.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
    }
}

struct WidgetTitle: View {
    let text: String
    var size: CGFloat = 20
    var lines = 2

    @Environment(\.widgetTint) private var tint

    var body: some View {
        TmaxFittingTitle(
            text: text,
            font: WidgetFont.title(size),
            color: tint.ink,
            lines: lines,
            kerning: -size * 0.015
        )
        .multilineTextAlignment(.leading)
    }
}

struct WidgetLabel: View {
    let text: String

    @Environment(\.widgetTint) private var tint

    var body: some View {
        TmaxMarqueeText(text, font: WidgetFont.label(), color: tint.secondaryInk)
    }
}

struct WidgetChip: View {
    let systemImage: String
    var text: String?
    var overPicture = false

    @Environment(\.widgetTint) private var tint

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
            if let text {
                Text(text)
                    .font(WidgetFont.chip())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(overPicture ? Color.white : tint.ink)
        .padding(.horizontal, 9)
        .frame(minWidth: 24, minHeight: 24)
        .background(overPicture ? Color.black.opacity(0.52) : tint.softFill, in: Capsule())
        .accessibilityHidden(true)
    }
}

struct WidgetPillLabel: View {
    let title: String?
    let systemImage: String
    var prominent = true
    var fillsWidth = false
    var diameter: CGFloat = 44

    @Environment(\.widgetTint) private var tint

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: title == nil ? diameter * 0.36 : 13, weight: .bold))
            if let title {
                Text(title)
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundStyle(prominent ? tint.pillInk : tint.ink)
        .padding(.horizontal, title == nil ? 0 : 16)
        .frame(minWidth: diameter, maxWidth: fillsWidth ? .infinity : nil, minHeight: diameter)
        .background(prominent ? tint.pillFill : tint.softFill, in: Capsule())
        .contentShape(Capsule())
    }
}

struct WidgetRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 10

    @Environment(\.widgetTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        ZStack {
            Circle()
                .stroke(tint.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(tint.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.isLight ? .clear : tint.accent.opacity(0.45), radius: lineWidth * 0.6)
                .opacity(clamped > 0 ? 1 : 0)
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: clamped)
        .accessibilityHidden(true)
    }
}

struct WidgetBar: View {
    let fraction: Double
    var height: CGFloat = 8

    @Environment(\.widgetTint) private var tint

    var body: some View {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.track)
                Capsule()
                    .fill(tint.accent)
                    .frame(width: clamped > 0 ? max(height, proxy.size.width * clamped) : 0)
                    .shadow(color: tint.isLight ? .clear : tint.accent.opacity(0.4), radius: height * 0.6)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
