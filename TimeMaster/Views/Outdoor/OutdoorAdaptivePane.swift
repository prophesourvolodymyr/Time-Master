#if os(iOS)
import SwiftUI

struct OutdoorAdaptivePane<Content: View, Actions: View>: View {
    var prefersBottomActions = false
    @ViewBuilder let content: (Bool) -> Content
    @ViewBuilder let actions: (Bool) -> Actions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let sideActions = !prefersBottomActions && proxy.size.height < proxy.size.width * 0.9 && !dynamicTypeSize.isAccessibilitySize
            let layout = sideActions
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 10))
                : AnyLayout(VStackLayout(spacing: 10))
            layout {
                content(sideActions)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                actions(sideActions)
                    .fixedSize(horizontal: sideActions, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(reduceMotion ? .none : .spring(response: 0.32, dampingFraction: 0.9), value: sideActions)
        }
    }
}

struct OutdoorPaneActionLabel: View {
    let title: String
    let systemImage: String
    let compact: Bool
    var vertical = false
    var labelProgress: CGFloat = 1
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 32

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 6 * labelProgress) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17 + 5 * labelProgress, weight: .semibold))
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(height: labelHeight * labelProgress)
                        .opacity(labelProgress)
                        .clipped()
                }
                .padding(.vertical, 8 * labelProgress)
                .frame(maxWidth: .infinity, minHeight: 44 + labelHeight * labelProgress)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                    if !compact { Text(title).lineLimit(1).minimumScaleFactor(0.8) }
                }
                .font(.subheadline.weight(.semibold))
                .frame(width: compact ? 44 : nil)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
#endif
