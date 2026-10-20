import SwiftUI

struct EverPillTabLabel: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: EverSpacing.x1) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(TimeMasterFont.rowTitle())
        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.85))
    }
}

struct EverPillTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(prominent: isSelected)
            .makeBody(configuration: configuration)
    }
}
