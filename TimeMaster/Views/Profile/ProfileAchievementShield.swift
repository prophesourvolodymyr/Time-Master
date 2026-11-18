import SwiftUI

struct ProfileAchievementShield: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    let palette: StoreProfilePalette
    let compactProgress: CGFloat
    let collectible: CollectibleItem?
    let artworkActive: Bool
    var body: some View {
        let shape = ProfileAchievementShieldShape()
        ZStack {
            if let collectible {
                CollectibleBadgeSkin(item: collectible, active: artworkActive)
                    .opacity(0.28)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            VStack(spacing: EverSpacing.x1) {
                Text(title.uppercased())
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                if let detail {
                    Text(detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .opacity(1 - compactProgress)

            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -EverSpacing.x1 * compactProgress)
                .opacity(compactProgress)
        }
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, EverSpacing.x3 - EverSpacing.x2 * compactProgress)
        .padding(.vertical, EverSpacing.x2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            shape.fill(LinearGradient(colors: [Theme.surface2, palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            shape.stroke(
                LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Achievement placeholder, coming later.")
    }
}

private struct ProfileAchievementShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard !rect.isEmpty else { return Path() }
        let corner = min(18, rect.height * 0.22)
        let tip = min(14, rect.height * 0.22)
        let shoulder = rect.maxY - tip
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + corner),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: shoulder - corner))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - corner, y: shoulder),
            control: CGPoint(x: rect.maxX, y: shoulder)
        )
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: shoulder - corner),
            control: CGPoint(x: rect.minX, y: shoulder)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + corner, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
