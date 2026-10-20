import SwiftUI

struct StoreCompactButtonStyle: ButtonStyle {
    var isPrimary = true
    var minimumHeight: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(
            prominent: isPrimary,
            minimumSize: max(44, minimumHeight ?? 44),
            horizontalPadding: EverSpacing.x4
        )
        .makeBody(configuration: configuration)
        .font(TimeMasterFont.rowTitle())
    }
}
