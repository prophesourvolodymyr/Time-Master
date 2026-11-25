import SwiftUI
import TimeMasterCore

enum ComboStyle {
    static let bright = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let deep = Color(red: 0.62, green: 0.05, blue: 0.09)
    static let darkest = Color(red: 0.36, green: 0.02, blue: 0.06)

    static var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bright, location: 0),
                .init(color: Color(red: 0.80, green: 0.10, blue: 0.13), location: 0.45),
                .init(color: deep, location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let defaultIcon = "figure.boxing"
}

struct ComboIconGlyph: View {
    let iconName: String?
    let iconType: SkillBoardIconType?
    var size: CGFloat = 22

    var body: some View {
        Group {
            if let iconName, !iconName.isEmpty, iconType == .emoji {
                Text(iconName).font(.system(size: size))
            } else if let iconName, !iconName.isEmpty {
                Image(systemName: iconName).font(.system(size: size, weight: .bold))
            } else {
                Image(systemName: ComboStyle.defaultIcon).font(.system(size: size, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }
}

struct ComboCornerIcon: View {
    let iconName: String?
    let iconType: SkillBoardIconType?
    var size: CGFloat = 30

    var body: some View {
        ComboIconGlyph(iconName: iconName, iconType: iconType, size: size * 0.5)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.2)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
    }
}

struct ComboCallChip: View {
    let tokens: [String]
    var tone: BuilderTone = .combo
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                let move = ComboMoves.move(for: token)
                HStack(spacing: 3) {
                    if !compact, let move {
                        Image(systemName: move.symbol)
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(token.count <= 1 ? token : token.capitalized)
                        .font(TimeMasterFont.black(compact ? 13 : 15, relativeTo: .subheadline))
                }
                .padding(.horizontal, compact ? 6 : 8)
                .padding(.vertical, compact ? 3 : 5)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.24)))
            }
        }
        .padding(compact ? 3 : 4)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.24)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .foregroundStyle(.white)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ComboCall.spoken(tokens))
    }
}
