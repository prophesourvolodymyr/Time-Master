import SwiftUI

struct ProfileCoverArtwork: View {
    var body: some View {
        StoreArtwork(style: .mono)
    }
}

private struct VerificationPreviewTierKey: EnvironmentKey {
    static let defaultValue: LocalBadgeTier? = nil
}

extension EnvironmentValues {
    var verificationPreviewTier: LocalBadgeTier? {
        get { self[VerificationPreviewTierKey.self] }
        set { self[VerificationPreviewTierKey.self] = newValue }
    }
}

struct ProfileTabsSurface: Shape {
    func path(in rect: CGRect) -> Path {
        if #available(iOS 17.0, macOS 14.0, *) {
            return UnevenRoundedRectangle(
                topLeadingRadius: EverRadius.card,
                topTrailingRadius: EverRadius.card
            ).path(in: rect)
        }
        let radius = min(EverRadius.card, min(rect.width / 2, rect.height))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
