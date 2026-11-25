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

/// The title of a skill board itself (not of a section): the brand tile above a big title, centered, with how many
/// skills the board holds under it.
struct SkillBoardTitle: View {
    let symbol: String
    let title: String
    var count: Int?

    var body: some View {
        VStack(spacing: SkillMetrics.s2) {
            TmaxBrandIcon(symbol: symbol, size: Self.tileSide)
            Text(title)
                .font(TimeMasterFont.black(Self.titleSize, relativeTo: .largeTitle))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let count, count > 0 {
                Text(SkillCopy.count(count, "skill", "skills"))
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SkillMetrics.s3)
        .padding(.bottom, SkillMetrics.s2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private static var tileSide: CGFloat {
        #if os(macOS)
        return 88
        #else
        return 76
        #endif
    }

    private static var titleSize: CGFloat {
        #if os(macOS)
        return 40
        #else
        return 36
        #endif
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
