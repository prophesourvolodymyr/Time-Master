import SwiftUI

struct PhysiqueScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.75) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    HStack(spacing: ProfileStyle.spacing) {
                        Rectangle()
                            .fill(Theme.toolbarOrange)
                            .frame(width: ProfileStyle.inset * 2, height: 3)
                        Rectangle()
                            .fill(contrast == .increased ? Theme.textPrimary.opacity(0.5) : Theme.separator)
                            .frame(height: 1)
                    }
                    .accessibilityHidden(true)

                    Text(title)
                        .font(TimeMasterFont.black(36, relativeTo: .largeTitle))
                        .tracking(-0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle {
                        Text(subtitle)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, ProfileStyle.spacing / 2)

                content
            }
            .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.top, ProfileStyle.inset * 1.5)
            .padding(.bottom, ProfileStyle.inset * 2)
            .frame(maxWidth: .infinity)
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle(title)
    }
}
