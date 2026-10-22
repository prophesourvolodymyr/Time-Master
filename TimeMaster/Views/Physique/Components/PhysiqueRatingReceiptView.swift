import SwiftUI

struct PhysiqueRatingReceiptView: View {
    let receipt: PhysiqueRatingReceipt?
    var isFirstRating = false
    var revealID: String? = nil
    var animate = false
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var glyphTravel: CGFloat = 10

    private var acceptedReceipt: PhysiqueRatingReceipt? {
        guard let receipt, receipt.games > 0, (0...5_000).contains(receipt.after),
              (-5_000...5_000).contains(receipt.change) else { return nil }
        if let before = receipt.before {
            guard (0...5_000).contains(before) else { return nil }
        } else if receipt.games != 1 {
            return nil
        }
        return receipt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                    Text("Physique Elo")
                        .font(TimeMasterFont.sectionTitle())
                    Text("MATCH RECEIPT")
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
                Text("Physique Elo · Match receipt")
                    .font(TimeMasterFont.sectionTitle())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityAddTraits(.isHeader)
            if let receipt = acceptedReceipt {
                let firstRating = isFirstRating || receipt.before == nil || receipt.games == 1
                let before = firstRating ? "Unplaced" : receipt.before.map { format($0) } ?? "Unavailable"
                let after = format(receipt.after)
                let magnitude = receipt.change.magnitude.formatted(.number.locale(locale))
                let change = receipt.change == 0 ? "Unchanged" : receipt.change > 0 ? "Gained" : "Lost"
                let sign = receipt.change > 0 ? "+" : receipt.change < 0 ? "−" : ""
                let accessibleChange = receipt.change == 0
                    ? "Unchanged, 0 Physique Elo points"
                    : "\(change), \(sign)\(magnitude) Physique Elo points"
                let contentID = "\(receipt.before.map(String.init) ?? "unplaced"):\(receipt.change):\(receipt.after):\(receipt.games):\(firstRating)"
                PhysiqueNumericReveal(
                    revealID: revealID,
                    animate: animate && receipt.change != 0,
                    contentID: contentID,
                    isRating: true
                ) { progress, _ in
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: ProfileStyle.inset * 2) {
                            afterMetric(after, firstRating: firstRating, progress: progress)
                            changeMetric(magnitude, sign: sign, change: change, accessibleChange: accessibleChange, progress: progress)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                            afterMetric(after, firstRating: firstRating, progress: progress)
                            changeMetric(magnitude, sign: sign, change: change, accessibleChange: accessibleChange, progress: progress)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before this match")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                    Text(verbatim: before)
                        .font(TimeMasterFont.label().monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Before this match")
                .accessibilityValue(Text(verbatim: firstRating ? "Unplaced, no earned Physique Elo before this match" : "\(before) Physique Elo points"))
                if receipt.games < 5 {
                    Text("Provisional · \(format(receipt.games)) of \(format(5)) rated matches")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Rating details unavailable")
                    .font(TimeMasterFont.body())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset * 1.25)
        .background(Theme.surface)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 44, height: 3)
                .accessibilityHidden(true)
        }
    }

    private func format(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private func afterMetric(_ after: String, firstRating: Bool, progress: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: after)
                .font(TimeMasterFont.black(52, relativeTo: .largeTitle).monospacedDigit())
                .foregroundStyle(Color(red: 0.97, green: 0.94, blue: 0.87))
                .offset(y: glyphTravel * (1 - progress))
                .scaleEffect(0.96 + 0.04 * progress, anchor: .leading)
                .opacity(0.88 + 0.12 * progress)
                .fixedSize(horizontal: false, vertical: true)
            Text(firstRating ? "First earned rating" : "After this match")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(firstRating ? "First earned rating" : "After this match")
        .accessibilityValue(Text(verbatim: "\(after) Physique Elo points"))
    }

    private func changeMetric(
        _ magnitude: String, sign: String, change: String, accessibleChange: String, progress: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if !sign.isEmpty { Text(verbatim: sign) }
                Text(verbatim: magnitude)
                    .offset(y: glyphTravel * (1 - progress))
                    .opacity(0.88 + 0.12 * progress)
            }
            .font(TimeMasterFont.black(34, relativeTo: .title).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .environment(\.layoutDirection, .leftToRight)
            .fixedSize(horizontal: false, vertical: true)
            Text("\(change) · Physique Elo")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Change")
        .accessibilityValue(Text(verbatim: accessibleChange))
    }
}

