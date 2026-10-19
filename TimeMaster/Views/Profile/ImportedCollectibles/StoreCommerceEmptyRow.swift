import SwiftUI

struct StoreCommerceEmptyRow: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        EverSurfaceCard {
            HStack(spacing: EverSpacing.x3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(EverColor.textSecondary)
                VStack(alignment: .leading, spacing: EverSpacing.x1) {
                    Text(title).font(TimeMasterFont.rowTitle())
                    Text(detail).font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(EverColor.textPrimary)
        }
    }
}
