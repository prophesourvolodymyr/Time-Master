import SwiftUI

struct PhysiqueBattleBrandHeader: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: ProfileStyle.inset) {
                mark
                appName
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                mark
                appName
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var mark: some View {
        TmaxMark()
            .fill(Theme.toolbarOrange)
            .aspectRatio(TmaxMark.aspectRatio, contentMode: .fit)
            .frame(width: 60, height: 60 / TmaxMark.aspectRatio)
            .accessibilityHidden(true)
    }

    private var appName: some View {
        Text("Tmax")
            .font(TimeMasterFont.pageTitle(36, relativeTo: .title))
            .foregroundStyle(Theme.textPrimary)
    }
}
