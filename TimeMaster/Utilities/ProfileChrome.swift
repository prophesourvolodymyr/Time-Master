import SwiftUI

struct ProfileCoverArtwork: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.toolbarOrange.opacity(0.22), Theme.surface2, Theme.background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            EllipticalGradient(
                colors: [TmaxGlow.ember.opacity(0.28), .clear],
                center: .bottom,
                startRadiusFraction: 0,
                endRadiusFraction: 0.6
            )
        }
        .accessibilityHidden(true)
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
