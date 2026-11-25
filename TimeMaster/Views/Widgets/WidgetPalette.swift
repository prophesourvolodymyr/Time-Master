import SwiftUI

enum WidgetTint: String, CaseIterable {
    case graphite
    case orange
    case peach

    var base: Color {
        switch self {
        case .graphite: Self.color(0x1D1D20)
        case .orange: Self.color(0xFF6A00)
        case .peach: Self.color(0xF9C0A4)
        }
    }

    var isLight: Bool { self != .graphite }

    var ink: Color { isLight ? Self.color(0x121214) : .white }

    var secondaryInk: Color {
        switch self {
        case .graphite: ink.opacity(0.55)
        case .orange: ink.opacity(0.76)
        case .peach: ink.opacity(0.68)
        }
    }

    var accent: Color { isLight ? ink : Self.color(0xFF6A00) }
    var track: Color { ink.opacity(isLight ? 0.14 : 0.12) }
    var softFill: Color { ink.opacity(isLight ? 0.1 : 0.12) }
    var pillFill: Color { isLight ? Self.color(0x121214) : .white }
    var pillInk: Color { isLight ? .white : Self.color(0x121214) }
    var accentOnDark: Color { self == .graphite ? Self.orange.base : base }

    static func forTypeColor(hex: String) -> WidgetTint {
        let digits = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return .graphite }
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        let high = max(red, green, blue)
        let chroma = high - min(red, green, blue)
        guard chroma >= 0.2 else { return .graphite }
        let hue: Double
        if high == red {
            hue = (60 * (green - blue) / chroma + 360).truncatingRemainder(dividingBy: 360)
        } else if high == green {
            hue = 60 * (blue - red) / chroma + 120
        } else {
            hue = 60 * (red - green) / chroma + 240
        }
        return hue < 50 || hue >= 330 ? .orange : .peach
    }

    static func color(_ rgb: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum WidgetArt: String, CaseIterable {
    case dumbbell
    case kettlebell
    case gymRings
    case parallettes
    case trophy
    case medal
    case runningShoe
    case compass
    case calendar
    case stopwatch
    case clipboard
    case clapperboard
    case heart
    case waterBottle
    case jumpRope
    case stabilityBall
    case yogaMat
    case flame
    case bolt
    case boxingGlove

    var assetName: String {
        switch self {
        case .dumbbell: "widget_art_dumbbell"
        case .kettlebell: "widget_art_kettlebell"
        case .gymRings: "widget_art_gym_rings"
        case .parallettes: "widget_art_parallettes"
        case .trophy: "widget_art_trophy"
        case .medal: "widget_art_medal"
        case .runningShoe: "widget_art_running_shoe"
        case .compass: "widget_art_compass"
        case .calendar: "widget_art_calendar"
        case .stopwatch: "widget_art_stopwatch"
        case .clipboard: "widget_art_clipboard"
        case .clapperboard: "widget_art_clapperboard"
        case .heart: "widget_art_heart"
        case .waterBottle: "widget_art_water_bottle"
        case .jumpRope: "widget_art_jump_rope"
        case .stabilityBall: "widget_art_stability_ball"
        case .yogaMat: "widget_art_yoga_mat"
        case .flame: "widget_art_flame"
        case .bolt: "widget_art_bolt"
        case .boxingGlove: "widget_art_boxing_glove"
        }
    }

    var tint: WidgetTint {
        switch self {
        case .dumbbell, .kettlebell, .gymRings, .parallettes, .boxingGlove, .clipboard: .orange
        case .trophy, .medal, .runningShoe, .compass, .calendar, .stopwatch, .clapperboard: .peach
        case .heart, .waterBottle, .jumpRope, .stabilityBall, .yogaMat: .peach
        case .flame, .bolt: .graphite
        }
    }

    static func forWorkout(type: String, symbol: String? = nil) -> WidgetArt {
        let words = "\(symbol ?? "") \(type)"
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        func has(_ prefixes: String...) -> Bool {
            words.contains { word in prefixes.contains { word.hasPrefix($0) } }
        }
        if has("boxing", "kickbox", "martial", "punch", "fight", "wrestl", "grappl", "judo", "jiu", "mma") { return .boxingGlove }
        if has("hiit", "highintensity", "interval", "tabata", "bolt", "flame") { return .bolt }
        if has("cardio", "heart") { return .heart }
        if has("run", "walk", "hik", "jog", "sprint", "shoe") { return .runningShoe }
        if has("jump", "rope") { return .jumpRope }
        if has("yoga", "mind") { return .yogaMat }
        if has("stretch", "cooldown", "flexib", "mobility", "pilates") { return .stabilityBall }
        if has("gymnast", "calisthen", "ring", "climb", "pull") { return .gymRings }
        if has("skill", "handstand", "parallette", "balance") { return .parallettes }
        if has("strength", "dumbbell", "weight", "lift") { return .dumbbell }
        if has("swim", "pool", "water", "face") { return .waterBottle }
        if has("cycl", "bicycle", "bike") { return .compass }
        return .kettlebell
    }
}

struct WidgetArtSpot: Equatable {
    var alignment: Alignment
    var scale: CGFloat
    var bleed: CGFloat

    static let corner = WidgetArtSpot(alignment: .bottomTrailing, scale: 0.84, bleed: 0.16)
    static let side = WidgetArtSpot(alignment: .trailing, scale: 0.96, bleed: 0.14)
    static let crown = WidgetArtSpot(alignment: .topTrailing, scale: 0.68, bleed: 0.06)
}

struct WidgetArtImage: View {
    let art: WidgetArt

    var body: some View {
        Image(art.assetName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fit)
            .mask {
                EllipticalGradient(
                    stops: [
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
            }
            .accessibilityHidden(true)
    }
}

struct WidgetArtLayer: View {
    let art: WidgetArt
    var spot: WidgetArtSpot = .corner

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * spot.scale
            let push = side * spot.bleed
            WidgetArtImage(art: art)
                .frame(width: side, height: side)
                .offset(x: Self.direction(spot.alignment.horizontal) * push, y: Self.direction(spot.alignment.vertical) * push)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: spot.alignment)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func direction(_ alignment: HorizontalAlignment) -> CGFloat {
        if alignment == .leading { return -1 }
        if alignment == .trailing { return 1 }
        return 0
    }

    private static func direction(_ alignment: VerticalAlignment) -> CGFloat {
        if alignment == .top { return -1 }
        if alignment == .bottom { return 1 }
        return 0
    }
}

struct WidgetSheen: View {
    let tint: WidgetTint

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(tint.isLight ? 0.22 : 0.07), .white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .center
            )
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(tint.isLight ? 0.07 : 0.2)],
                startPoint: .center,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WidgetTintBackground: View {
    let tint: WidgetTint
    let art: WidgetArt?
    let spot: WidgetArtSpot

    init(tint: WidgetTint) {
        self.tint = tint
        art = nil
        spot = .corner
    }

    init(art: WidgetArt, spot: WidgetArtSpot = .corner) {
        tint = art.tint
        self.art = art
        self.spot = spot
    }

    var body: some View {
        ZStack {
            tint.base
            if let art {
                WidgetArtLayer(art: art, spot: spot)
            }
            WidgetSheen(tint: tint)
        }
        .accessibilityHidden(true)
    }
}
