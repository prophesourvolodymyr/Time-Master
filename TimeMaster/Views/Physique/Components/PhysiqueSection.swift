import SwiftUI

struct PhysiqueSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, ProfileStyle.spacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.5 : 0.18))
                        .frame(height: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
