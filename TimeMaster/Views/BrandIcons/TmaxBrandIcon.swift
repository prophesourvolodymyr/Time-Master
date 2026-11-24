import SwiftUI

enum TmaxBrandGlow: Hashable {
    case orange
    case white
}

struct TmaxBrandIcon: View {
    private enum Face {
        case art(TmaxBrandGlyph)
        case symbol(String)
    }

    private let face: Face
    private let size: CGFloat
    private let glow: TmaxBrandGlow?
    private let label: String?

    @Environment(\.tmaxBrandGlow) private var pageGlow
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ glyph: TmaxBrandGlyph, size: CGFloat, glow: TmaxBrandGlow? = nil, label: String? = nil) {
        face = .art(glyph)
        self.size = size
        self.glow = glow
        self.label = label
    }

    init(symbol: String, size: CGFloat, glow: TmaxBrandGlow? = nil, label: String? = nil) {
        face = TmaxBrandGlyph(symbol: symbol).map(Face.art) ?? .symbol(symbol)
        self.size = size
        self.glow = glow
        self.label = label
    }

    var body: some View {
        let glow = self.glow ?? pageGlow
        let shape = RoundedRectangle(cornerRadius: size * Self.cornerRatio, style: .continuous)
        picture(glow)
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(rim(glow), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label ?? ""))
            .accessibilityAddTraits(.isImage)
            .accessibilityHidden(label == nil)
    }

    @ViewBuilder
    private func picture(_ glow: TmaxBrandGlow) -> some View {
        switch face {
        case let .art(glyph):
            Image(glyph.assetName(glow))
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        case let .symbol(name):
            let light = glow == .white ? Self.whiteLight : Self.orangeLight
            ZStack {
                glow == .white ? Self.whiteTile : Self.orangeTile
                RadialGradient(colors: [light.opacity(0.3), light.opacity(0)], center: .center,
                               startRadius: 0, endRadius: size * 0.62)
                Image(systemName: name)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [light, light.opacity(0.7)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: light.opacity(0.55), radius: size * 0.09)
            }
        }
    }

    private func rim(_ glow: TmaxBrandGlow) -> Color {
        if contrast == .increased { return Color.white.opacity(0.5) }
        return glow == .white ? Color.white.opacity(0.14) : Self.orangeRim
    }

    private static let cornerRatio: CGFloat = 0.26
    private static let orangeLight = Color(hex: "FF5A1F")
    private static let orangeTile = Color(hex: "0C0403")
    private static let orangeRim = Color(hex: "4A1408")
    private static let whiteLight = Color(hex: "F2F6FF")
    private static let whiteTile = Color(hex: "0B0B0C")
}

private struct TmaxBrandGlowKey: EnvironmentKey {
    static let defaultValue = TmaxBrandGlow.orange
}

extension EnvironmentValues {
    var tmaxBrandGlow: TmaxBrandGlow {
        get { self[TmaxBrandGlowKey.self] }
        set { self[TmaxBrandGlowKey.self] = newValue }
    }
}

extension View {
    func tmaxBrandGlow(_ glow: TmaxBrandGlow) -> some View {
        environment(\.tmaxBrandGlow, glow)
    }
}
