import SwiftUI

struct SettingsActionRow<Trailing: View>: View {
    let title: String
    var detail: String?
    let symbol: String
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var symbolSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 64

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: EverSpacing.x3) {
                    HStack {
                        icon
                        Spacer(minLength: EverSpacing.x2)
                        trailing()
                    }
                    text
                }
            } else {
                HStack(spacing: EverSpacing.x4) {
                    icon
                    text
                    Spacer(minLength: 0)
                    trailing()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: min(symbolSize, 40), weight: .regular))
            .foregroundStyle(EverColor.accent)
            .frame(width: min(iconSize, 76), height: min(iconSize, 76))
            .modifier(TimeMasterCardSurface(cornerRadius: EverRadius.card, emphasized: true))
            .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x1) {
            Text(title)
                .font(TimeMasterFont.black(18, relativeTo: .body))
                .foregroundStyle(EverColor.textPrimary)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
    }
}

extension SettingsActionRow where Trailing == EmptyView {
    init(title: String, detail: String? = nil, symbol: String) {
        self.init(title: title, detail: detail, symbol: symbol) {
            EmptyView()
        }
    }
}

struct SettingsMenuCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        EverSurfaceCard {
            content()
        }
        .contentShape(RoundedRectangle(cornerRadius: EverRadius.card, style: .continuous))
    }
}

struct SettingsMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x3) {
            Text(title.uppercased())
                .font(TimeMasterFont.caption())
                .foregroundStyle(EverColor.textTertiary)
                .tracking(0.4)
                .padding(.horizontal, EverSpacing.x1)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
