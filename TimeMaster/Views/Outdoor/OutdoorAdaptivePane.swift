#if os(iOS)
import SwiftUI

struct OutdoorAdaptivePane<Content: View, Actions: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @ViewBuilder let actions: (Bool) -> Actions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let sideActions = proxy.size.height < proxy.size.width * 0.9 && !dynamicTypeSize.isAccessibilitySize
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            if !compact { Text(title).lineLimit(1).minimumScaleFactor(0.8) }
        }
        .font(.subheadline.weight(.semibold))
        .frame(width: compact ? 44 : nil)
        .frame(maxWidth: compact ? nil : .infinity, minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
#endif
