import SwiftUI

/// The title row of one section of a skill page (Skills, Exercises & notes, …): the section's brand icon, the title
/// and, when there is something to count, the count.
struct SkillSectionHeading: View {
    let symbol: String
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: SkillMetrics.s3) {
            SkillSectionIcon(symbol: symbol)
            HStack(alignment: .firstTextBaseline, spacing: SkillMetrics.s2) {
                Text(title)
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: SkillMetrics.touch)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The brand icon tile that opens a section heading. Decorative.
struct SkillSectionIcon: View {
    let symbol: String

    var body: some View {
        TmaxBrandIcon(symbol: symbol, size: Self.side)
    }

    private static var side: CGFloat {
        #if os(macOS)
        return 48
        #else
        return 44
        #endif
    }
}
