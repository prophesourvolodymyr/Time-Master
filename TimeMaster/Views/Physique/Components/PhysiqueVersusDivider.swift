import SwiftUI

struct PhysiqueVersusDivider: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: ProfileStyle.spacing) {
            HStack(spacing: ProfileStyle.inset) {
                rule
                Text("VS")
                    .font(TimeMasterFont.blackItalic(44, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.toolbarOrange)
                    .fixedSize(horizontal: true, vertical: true)
                rule
            }
            Text("\(PhysiquePose.allCases.count) POSES · ONE MATCH")
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .tracking(1.6)
                .foregroundStyle(contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, 24)
        .frame(maxWidth: ProfileStyle.readableWidth, minHeight: 144)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var rule: some View {
        Rectangle()
            .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.65 : 0.2))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
