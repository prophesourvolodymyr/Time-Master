import SwiftUI

struct PhysiqueStatusView: View {
    let title: String
    let detail: String
    var systemImage: String = "exclamationmark.circle"
    var retry: (() -> Void)? = nil
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ProfileStyle.spacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: ProfileStyle.spacing))

        layout {
            Image(systemName: systemImage)
                .font(TimeMasterFont.heading())
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ProfileStyle.spacing * 0.75) {
                Text(title)
                    .font(TimeMasterFont.sectionTitle())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(ProfileStyle.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let retry {
                    PhysiqueAction(title: "Try again", systemImage: "arrow.clockwise", prominent: false, action: retry)
                        .padding(.top, ProfileStyle.spacing / 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.65 : 0.24))
                .frame(width: 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .transition(.identity)
        .transaction { $0.animation = nil }
    }
}
