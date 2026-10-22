import SwiftUI

struct PhysiqueCategoryScoreRow: View {
    let category: PhysiqueCategory
    let you: Int
    let opponent: Int
    var animate = false
    var revealID: String? = nil
    @Environment(\.locale) private var locale

    private var validScores: Bool {
        (0...100).contains(you) && (0...100).contains(opponent)
    }

    private var title: String {
        category == .symmetry ? "Symmetry and balance" : category.title
    }

    var body: some View {
        let youValue = you.formatted(.number.locale(locale))
        let opponentValue = opponent.formatted(.number.locale(locale))
        let scale = 100.formatted(.number.locale(locale))
        let weight = (Double(category.weight) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title)
                    .font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("RUBRIC WEIGHT · \(weight)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if validScores {
                PhysiqueNumericReveal(
                    revealID: revealID,
                    animate: animate && revealID != nil,
                    contentID: "\(category.rawValue):\(you):\(opponent):\(locale.identifier)",
                    includesRail: true
                ) { glyphProgress, railProgress in
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        PhysiqueCategoryParticipantScore(
                            participant: "You", category: title, value: you, formattedValue: youValue,
                            scale: scale, weight: weight, color: Theme.toolbarOrange,
                            glyphProgress: glyphProgress, railProgress: railProgress
                        )
                        PhysiqueCategoryParticipantScore(
                            participant: "Opponent", category: title, value: opponent, formattedValue: opponentValue,
                            scale: scale, weight: weight, color: Color(red: 0.97, green: 0.94, blue: 0.87),
                            glyphProgress: glyphProgress, railProgress: railProgress
                        )
                    }
                }
            } else {
                Text("Category score details unavailable")
                    .font(TimeMasterFont.body())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, ProfileStyle.spacing)
    }
}

private struct PhysiqueCategoryParticipantScore: View {
    let participant: String
    let category: String
    let value: Int
    let formattedValue: String
    let scale: String
    let weight: String
    let color: Color
    let glyphProgress: CGFloat
    let railProgress: CGFloat
    @ScaledMetric(relativeTo: .title3) private var glyphTravel: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                    Text(verbatim: participant)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                    score
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: participant)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                    score
                }
            }
            GeometryReader { geometry in
                Rectangle()
                    .fill(Theme.surface2)
                    .overlay(alignment: .leading) {
                        if value > 0 {
                            Rectangle()
                                .fill(color.opacity(0.5))
                                .overlay {
                                    Rectangle()
                                        .fill(color)
                                        .scaleEffect(x: railProgress, y: 1, anchor: .leading)
                                }
                                .overlay { Rectangle().strokeBorder(color, lineWidth: 1) }
                                .frame(width: geometry.size.width * CGFloat(value) / 100)
                        }
                    }
                    .overlay {
                        HStack(spacing: 0) {
                            Rectangle().frame(width: 1)
                            Spacer(minLength: 0)
                            Rectangle().frame(width: 1)
                            Spacer(minLength: 0)
                            Rectangle().frame(width: 1)
                        }
                        .foregroundStyle(ProfileStyle.secondary.opacity(0.45))
                    }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(participant), \(category)"))
        .accessibilityValue(Text(verbatim: "\(formattedValue) points out of \(scale), rubric weight \(weight)"))
    }

    private var score: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                valueText
                unitText
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 2) {
                valueText
                unitText
            }
        }
    }

    private var valueText: some View {
        Text(verbatim: formattedValue)
            .font(TimeMasterFont.black(28, relativeTo: .title2).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .offset(y: glyphTravel * (1 - glyphProgress))
            .opacity(0.9 + 0.1 * glyphProgress)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var unitText: some View {
        Text("pts / \(scale)")
            .font(TimeMasterFont.secondary())
            .foregroundStyle(ProfileStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
