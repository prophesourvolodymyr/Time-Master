import SwiftUI

/// Geometry for the collapsing page chrome shared by the Database and Workouts pages.
struct ScrollingChromeMetrics {
    let width: CGFloat
    var horizontalPadding: CGFloat = 20
    /// Height the control row keeps once the chrome has collapsed.
    var collapsedRowHeight: CGFloat = 56
    var compactControlSize: CGFloat = 48
    var controlSpacing: CGFloat = 10
    var expandedControlPadding: CGFloat = 8
    /// Widest an expanded control may grow; `.infinity` lets the three controls span the content width.
    var expandedControlWidthCap: CGFloat = 108
    /// Tallest an expanded control may grow.
    var expandedControlHeightCap: CGFloat = 108
    /// Everything the pinned header keeps below the control row: divider, goal line, filter row.
    var pinnedFooterHeight: CGFloat = 49

    var contentWidth: CGFloat { max(0, width - horizontalPadding * 2) }

    /// Three controls share the content width.
    var expandedControlWidth: CGFloat {
        min(expandedControlWidthCap, max(compactControlSize, (contentWidth - controlSpacing * 2) / 3))
    }

    var expandedControlHeight: CGFloat { min(expandedControlHeightCap, expandedControlWidth) }
    var expandedGroupWidth: CGFloat { expandedControlWidth * 3 + controlSpacing * 2 }
    var compactGroupWidth: CGFloat { compactControlSize * 3 + controlSpacing * 2 }
    var collapseDistance: CGFloat { expandedControlHeight + expandedControlPadding * 2 }
    var pinnedHeight: CGFloat { collapsedRowHeight + pinnedFooterHeight }

    func controlWidth(_ progress: CGFloat) -> CGFloat {
        expandedControlWidth + (compactControlSize - expandedControlWidth) * progress
    }

    func controlHeight(_ progress: CGFloat) -> CGFloat {
        expandedControlHeight + (compactControlSize - expandedControlHeight) * progress
    }

    /// Leading inset of the control group: centered when expanded, trailing when collapsed.
    func groupLeading(_ progress: CGFloat) -> CGFloat {
        let expanded = (contentWidth - expandedGroupWidth) / 2
        let compact = contentWidth - compactGroupWidth
        return expanded + (compact - expanded) * progress
    }

    /// Shared collapse curve: the controls settle in size before the group travels.
    func morph(_ progress: CGFloat) -> CGFloat {
        let settling = min(1, max(0, (progress - 0.5) / 0.25))
        return min(progress, 0.5) * 1.6 + 0.2 * settling * (2 - settling)
    }
}

/// One private-glass control of a page chrome. The label fades out as the control collapses.
struct ScrollingChromeControl: View {
    let systemImage: String
    let title: String
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat
    var isInteractive: Bool = true

    var body: some View {
        let labelProgress = min(1, progress / 0.65)
        let cornerRadius = 14 + (min(width, height) / 2 - 14) * progress

        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .offset(y: -12 * (1 - labelProgress))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .opacity(1 - labelProgress)
                .offset(y: 18)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .frame(width: width, height: height)
        .modifier(
            TimeMasterPrivateGlassSurface(
                cornerRadius: cornerRadius,
                isInteractive: isInteractive,
                tint: Theme.toolbarOrange,
                tintOpacity: 0.42
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Theme.toolbarOrange.opacity(0.65), lineWidth: 1)
        }
    }
}

/// Scroll-driven chrome: the header collapses as the content scrolls, then stays pinned above it.
struct ScrollingChrome<Content: View, Header: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsExpanded = false
    @Namespace private var viewport

    let metrics: (CGFloat) -> ScrollingChromeMetrics
    @ViewBuilder let content: (ScrollingChromeMetrics) -> Content
    @ViewBuilder let header: (CGFloat, ScrollingChromeMetrics) -> Header

    var body: some View {
        GeometryReader { proxy in
            let resolved = metrics(proxy.size.width)
            let headerHeight = resolved.pinnedHeight
                + (controlsExpanded ? resolved.collapseDistance : 0)

            VStack(spacing: 0) {
                header(controlsExpanded ? 0 : 1, resolved)
                    .frame(height: headerHeight, alignment: .top)
                    .zIndex(1)
                scrollSurface(
                    metrics: resolved,
                    height: max(0, proxy.size.height - headerHeight)
                )
                .coordinateSpace(name: viewport)
            }
        }
    }

    @ViewBuilder
    private func scrollSurface(metrics: ScrollingChromeMetrics, height: CGFloat) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            ScrollView {
                scrollContent(metrics: metrics, height: height)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                updateControls(offset: offset)
            }
        } else {
            ScrollView {
                scrollContent(metrics: metrics, height: height)
                    .background(alignment: .top) {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollingChromeOffsetKey.self,
                                value: proxy.frame(in: .named(viewport)).minY
                            )
                        }
                    }
            }
            .onPreferenceChange(ScrollingChromeOffsetKey.self) { offset in
                updateControls(offset: -offset)
            }
        }
    }

    private func scrollContent(metrics: ScrollingChromeMetrics, height: CGFloat) -> some View {
        content(metrics)
            .frame(minHeight: height + 1, alignment: .top)
    }

    private func updateControls(offset: CGFloat) {
        let expanded = ScrollingChromeReveal.expanded(current: controlsExpanded, offset: offset)
        guard expanded != controlsExpanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
            controlsExpanded = expanded
        }
    }
}

enum ScrollingChromeReveal {
    static func expanded(current: Bool, offset: CGFloat) -> Bool {
        if offset < -24 { return true }
        if offset > 24 { return false }
        return current
    }
}

private struct ScrollingChromeOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
