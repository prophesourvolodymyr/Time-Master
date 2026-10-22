import SwiftUI

struct PhysiqueMetric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
            ViewThatFits(in: .horizontal) {
                Text(value)
                    .font(TimeMasterFont.black(30, relativeTo: .title))
                    .fixedSize()
                Text(value)
                    .font(TimeMasterFont.heading())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .monospacedDigit()
            Text(label)
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
