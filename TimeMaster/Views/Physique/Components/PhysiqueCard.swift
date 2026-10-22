import SwiftUI

struct PhysiqueCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.5 : 0.12))
                .frame(height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
