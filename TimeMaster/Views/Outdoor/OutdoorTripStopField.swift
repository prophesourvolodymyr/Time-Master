#if os(iOS)
import SwiftUI

struct OutdoorTripStopField<Field: View, Accessory: View>: View {
    let index: Int
    let isBus: Bool
    let connectsBelow: Bool
    var symbol = "magnifyingglass"
    var accent = false
    var focused = false
    @ViewBuilder let field: () -> Field
    @ViewBuilder let accessory: () -> Accessory
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = 24.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 10) {
            Image(systemName: index == 0 ? "circle.circle.fill" : isBus ? "bus.fill" : "mappin.circle.fill")
                .font(.system(size: railWidth * 0.85, weight: .semibold))
                .foregroundStyle(isBus ? Color.yellow : Theme.toolbarOrange)
                .frame(width: railWidth)
                .background(Theme.surface, in: Circle())
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent || focused ? Theme.toolbarOrange : Theme.textSecondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                field()
                    .font(TimeMasterFont.secondary())
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessory()
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: 52)
            .background(shape.fill(Color.black.opacity(0.38)))
            .overlay {
                shape
                    .strokeBorder(focused ? Theme.toolbarOrange.opacity(0.9) : Color.white.opacity(0.16), lineWidth: focused ? 1.5 : 1)
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
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = 24.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: railWidth * 0.5, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: railWidth, height: railWidth)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.toolbarOrange.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5])))
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20)
                    Text("Add destination")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.toolbarOrange)
                }
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .frame(minHeight: 52)
                .background(shape.fill(Color.black.opacity(0.38)))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add destination")
        .accessibilityHint("Search for a place or choose one on the map")
        .accessibilityIdentifier("trip.addStop")
    }
}
#endif
