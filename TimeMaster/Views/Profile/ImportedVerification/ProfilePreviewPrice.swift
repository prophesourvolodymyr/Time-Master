import SwiftUI

struct ProfilePreviewPrice: View {
    let amount: String
    let period: String
    let periodAccessibilityLabel: String
    let amountFont: Font
    let periodFont: Font

    init(
        amount: String,
        period: String,
        periodAccessibilityLabel: String? = nil,
        amountFont: Font = TimeMasterFont.secondary(),
        periodFont: Font = TimeMasterFont.micro()
    ) {
        self.amount = amount
        self.period = period
        self.periodAccessibilityLabel = periodAccessibilityLabel ?? Self.periodName(for: period)
        self.amountFont = amountFont
        self.periodFont = periodFont
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(amount)
                .font(amountFont)
                .monospacedDigit()
            Text(period)
                .font(periodFont)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) \(periodAccessibilityLabel)")
    }

    private static func periodName(for period: String) -> String {
        switch period.lowercased() {
        case "/mo", "/month":
            return "month"
        case "/yr", "/year":
            return "year"
        default:
            return period.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }
}
