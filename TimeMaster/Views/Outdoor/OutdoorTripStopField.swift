#if os(iOS)
import SwiftUI

struct OutdoorTripStopField<Field: View, Accessory: View>: View {
    let index: Int
    let isBus: Bool
    let connectsBelow: Bool
    @ViewBuilder let field: () -> Field
    @ViewBuilder let accessory: () -> Accessory
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = 24.0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: index == 0 ? "circle.circle.fill" : isBus ? "bus.fill" : "mappin.circle.fill")
                .font(.system(size: railWidth * 0.85, weight: .semibold))
                .foregroundStyle(isBus ? Color.yellow : Theme.toolbarOrange)
                .frame(width: railWidth)
                .background(Theme.surface, in: Circle())
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                field()
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessory()
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: 50)
            .background(Theme.surface2.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .background {
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: railWidth / 2, y: index == 0 ? proxy.size.height / 2 : -4))
                    path.addLine(to: CGPoint(x: railWidth / 2, y: connectsBelow ? proxy.size.height + 4 : proxy.size.height / 2))
                }
                .stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
            }
            .allowsHitTesting(false)
        }
    }
}

struct OutdoorTripAddDestination: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add destination", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Theme.toolbarOrange)
                .background(Theme.toolbarOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.toolbarOrange.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trip.addStop")
    }
}
#endif
