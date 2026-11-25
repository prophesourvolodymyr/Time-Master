import SwiftUI
import WidgetKit

enum TmaxWidgetFont {
    static func black(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Inter-Black", size: size, relativeTo: style)
    }

    static let label = Font.system(size: 13, weight: .semibold)
}

struct TmaxWidgetHero: View {
    let text: String
    var size: CGFloat = 44
    let tint: WidgetTint

    var body: some View {
        Text(text)
            .font(TmaxWidgetFont.black(size, relativeTo: .largeTitle).monospacedDigit())
            .kerning(-size * 0.03)
            .foregroundStyle(tint.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
    }
}

struct TmaxWidgetTitle: View {
    let text: String
    var size: CGFloat = 18
    var lines = 2
    let tint: WidgetTint

    var body: some View {
        Text(text)
            .font(TmaxWidgetFont.black(size, relativeTo: .headline))
            .kerning(-size * 0.015)
            .foregroundStyle(tint.ink)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.leading)
    }
}

struct TmaxWidgetLabel: View {
    let text: String
    let tint: WidgetTint

    var body: some View {
        Text(text)
            .font(TmaxWidgetFont.label)
            .foregroundStyle(tint.secondaryInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct TmaxWidgetPill: View {
    let title: String
    let systemImage: String
    let tint: WidgetTint
    var fillsWidth = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(TmaxWidgetFont.black(15, relativeTo: .subheadline))
                .lineLimit(1)
        }
        .foregroundStyle(tint.pillInk)
        .padding(.horizontal, 16)
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 40)
        .background(tint.pillFill, in: Capsule())
    }
}

struct TmaxWidgetPlayGlyph: View {
    let tint: WidgetTint
    var diameter: CGFloat = 30

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: diameter * 0.38, weight: .bold))
            .foregroundStyle(tint.pillInk)
            .frame(width: diameter, height: diameter)
            .background(tint.pillFill, in: Circle())
            .accessibilityHidden(true)
    }
}

struct TmaxWidgetRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 10
    let tint: WidgetTint

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
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum TmaxWidgetLayout {
    static let sideRoom: CGFloat = 116

    static func spot(for family: WidgetFamily) -> WidgetArtSpot {
        switch family {
        case .systemSmall: .corner
        case .systemMedium: .side
        default: .crown
        }
    }
}

struct TmaxWidgetLook {
    let tint: WidgetTint
    let art: WidgetArt?

    init(tint: WidgetTint) {
        self.tint = tint
        art = nil
    }

    init(art: WidgetArt) {
        tint = art.tint
        self.art = art
    }
}

struct TmaxWidgetBackdrop: View {
    let look: TmaxWidgetLook
    let family: WidgetFamily

    var body: some View {
        if let art = look.art {
            WidgetTintBackground(art: art, spot: TmaxWidgetLayout.spot(for: family))
        } else {
            WidgetTintBackground(tint: look.tint)
        }
    }
}

extension View {
    func tmaxWidgetBackground(_ look: TmaxWidgetLook, family: WidgetFamily) -> some View {
        containerBackground(for: .widget) {
            TmaxWidgetBackdrop(look: look, family: family)
        }
    }
}
