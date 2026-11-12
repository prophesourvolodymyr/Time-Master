import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Geometry for the collapsing page chrome shared by the Database and Workouts pages.
struct ScrollingChromeMetrics {
    let width: CGFloat
    var horizontalPadding: CGFloat = 20
    /// Height the control row keeps once the chrome has collapsed.
    var collapsedRowHeight: CGFloat = 56
    var compactControlSize: CGFloat = 48
    var controlSpacing: CGFloat = 10
    var expandedControlPadding: CGFloat = 8
    /// Widest an expanded control may grow; `.infinity` lets the controls span the content width.
    var expandedControlWidthCap: CGFloat = .infinity
    /// Tallest an expanded control may grow.
    var expandedControlHeightCap: CGFloat = 108
    var controlCount: Int = 3

    var contentWidth: CGFloat { max(0, width - horizontalPadding * 2) }

    var expandedControlWidth: CGFloat {
        #if os(macOS)
        let cap = min(expandedControlWidthCap, compactControlSize * 3)
        #else
        let cap = expandedControlWidthCap
        #endif
        return min(cap, max(compactControlSize, (contentWidth - controlSpacing * CGFloat(controlCount - 1)) / CGFloat(controlCount)))
    }

    var expandedControlHeight: CGFloat {
        #if os(macOS)
        min(max(expandedControlHeightCap, 120), expandedControlWidth)
        #else
        min(expandedControlHeightCap, expandedControlWidth)
        #endif
    }
    var expandedGroupWidth: CGFloat { expandedControlWidth * CGFloat(controlCount) + controlSpacing * CGFloat(controlCount - 1) }
    var compactGroupWidth: CGFloat { compactControlSize * CGFloat(controlCount) + controlSpacing * CGFloat(controlCount - 1) }

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

private struct ScrollingChromeExpansionKey: EnvironmentKey {
    static let defaultValue: ((Bool) -> Void)? = nil
}

extension EnvironmentValues {
    var scrollingChromeSetExpanded: ((Bool) -> Void)? {
        get { self[ScrollingChromeExpansionKey.self] }
        set { self[ScrollingChromeExpansionKey.self] = newValue }
    }
}

struct ScrollingChromeHeader<Controls: View>: View {
    let title: String
    let progress: CGFloat
    let metrics: ScrollingChromeMetrics
    var leadingControlWidth: CGFloat = 0
    @ViewBuilder let controls: () -> Controls

    @Environment(\.scrollingChromeSetExpanded) private var setExpanded
    @ScaledMetric(relativeTo: .title) private var expandedTitleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .title2) private var compactTitleSize: CGFloat = 22

    /// The widest the title may be drawn (before scaling): the room the controls leave, from the known sizes, so the
    /// title is clipped and faded at the controls whatever the layout proposes.
    private func titleLimit(scale: CGFloat) -> CGFloat {
        let collapse = min(1, max(0, progress))
        let leadingInset = leadingControlWidth > 0 ? leadingControlWidth + metrics.controlSpacing : 0
        let compactRoom = max(1, metrics.contentWidth - leadingInset - metrics.compactGroupWidth - metrics.controlSpacing)
        let expandedRoom = max(1, metrics.contentWidth - leadingInset * 2)
        return (expandedRoom * (1 - collapse) + compactRoom * collapse) / max(0.01, scale)
    }

    var body: some View {
        let compactScale = min(1, compactTitleSize / expandedTitleSize)
        let scale = 1 + (compactScale - 1) * progress

        ScrollingChromeHeaderLayout(
            progress: progress,
            compactTitleScale: compactScale,
            metrics: metrics,
            leadingControlWidth: leadingControlWidth
        ) {
            ScrollingChromeTitle(text: title, limit: titleLimit(scale: scale))
                .foregroundStyle(Theme.textPrimary)
                .scaleEffect(scale, anchor: .topLeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            controls()
                .oneHandedActionSource()
        }
        .padding(.horizontal, metrics.horizontalPadding)
        #if os(macOS)
        .preference(key: MacWindowTitlePreferenceKey.self, value: title)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    guard abs(value.translation.height) > metrics.compactControlSize / 2,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    setExpanded?(value.translation.height > 0)
                }
        )
        .accessibilityAction(named: "Expand page actions") { setExpanded?(true) }
        .accessibilityAction(named: "Collapse page actions") { setExpanded?(false) }
        #endif
    }
}

/// The page title on one line. When it is wider than the room the controls leave it, its end fades out and it slowly
/// scrolls to the end and back so all of it can be read; with Reduce Motion it stays still with the fade.
private struct ScrollingChromeTitle: View {
    let text: String
    let limit: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    private let fadeWidth: CGFloat = 28

    private var overflow: CGFloat { max(0, textWidth - boxWidth) }

    var body: some View {
        TimeMasterPageTitle(text, size: 39, relativeTo: .title)
            .lineLimit(1)
            .fixedSize()
            .background(widthReader { textWidth = $0 })
            .offset(x: offset)
            .frame(maxWidth: limit, alignment: .leading)
            .background(widthReader { boxWidth = $0 })
            .clipped()
            .mask {
                HStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: overflow > 1 ? fadeWidth : 0)
                }
            }
            .task(id: "\(Int(overflow))-\(reduceMotion)-\(text)") { await scroll() }
    }

    private func widthReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.width) }
                .onChange(of: proxy.size.width) { update($0) }
        }
    }

    private func scroll() async {
        offset = 0
        guard overflow > 1, !reduceMotion else { return }
        let travel = Double(overflow) / 28
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: travel)) { offset = -overflow }
            try? await Task.sleep(nanoseconds: UInt64((travel + 1.4) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: travel)) { offset = 0 }
            try? await Task.sleep(nanoseconds: UInt64(travel * 1_000_000_000))
        }
    }
}

private struct ScrollingChromeHeaderLayout: Layout {
    var progress: CGFloat
    let compactTitleScale: CGFloat
    let metrics: ScrollingChromeMetrics
    let leadingControlWidth: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private struct Geometry {
        let titleSize: CGSize
        let titleOrigin: CGPoint
        let controlsAnchor: UnitPoint
        let controlsOrigin: CGPoint
        let height: CGFloat
    }

    /// Compact (progress 1): the title and the icon controls share one row, the controls at the right and the title
    /// limited to the room they leave. Expanded (progress 0): the title is centred with the labelled tiles below it.
    /// The controls' measured size is never trusted below the size they are known to be drawn at.
    private func geometry(subviews: Subviews) -> Geometry {
        let collapse = min(1, max(0, progress))
        let expansion = 1 - collapse
        let scale = 1 + (compactTitleScale - 1) * collapse
        let width = metrics.contentWidth
        let leadingInset = leadingControlWidth > 0 ? leadingControlWidth + metrics.controlSpacing : 0
        let measured = subviews[1].sizeThatFits(.unspecified)
        let controlsSize = CGSize(
            width: max(measured.width, metrics.compactGroupWidth),
            height: max(measured.height, metrics.compactControlSize)
        )
        let natural = subviews[0].sizeThatFits(.unspecified)
        let compactRoom = max(1, width - leadingInset - controlsSize.width - metrics.controlSpacing)
        let expandedRoom = max(1, width - leadingInset * 2)
        let titleWidth = min(natural.width, (expandedRoom * expansion + compactRoom * collapse) / scale)
        let titleSize = CGSize(width: titleWidth, height: natural.height)
        let titleHeight = natural.height * scale
        let visibleWidth = titleWidth * scale

        let compactRow = max(metrics.collapsedRowHeight, titleHeight + 8, controlsSize.height + 8)
        let compactTitleY = (compactRow - titleHeight) / 2
        let expandedTitleY = max(4, (metrics.collapsedRowHeight - titleHeight) / 2)
        let expandedRow = max(metrics.collapsedRowHeight, expandedTitleY + titleHeight + 4)
        let compactControlsY = (compactRow - controlsSize.height) / 2
        let expandedControlsY = expandedRow + metrics.expandedControlPadding

        let titleX = leadingInset * collapse + (width - visibleWidth) / 2 * expansion
        let titleY = compactTitleY * collapse + expandedTitleY * expansion
        let anchorX = 0.5 + 0.5 * collapse
        let controlsX = width * (0.5 * expansion + collapse)
        let controlsLeft = controlsX - controlsSize.width * anchorX
        let horizontalGap = max(controlsLeft - (titleX + visibleWidth), titleX - (controlsLeft + controlsSize.width))
        let clearance = min(1, max(0, 1 - horizontalGap / max(1, metrics.controlSpacing)))
        let titleBottom = titleY + titleHeight
        let controlsY = max(
            compactControlsY * collapse + expandedControlsY * expansion,
            compactControlsY + (titleBottom + metrics.expandedControlPadding - compactControlsY) * clearance
        )
        let height = max(
            compactRow * collapse + (expandedControlsY + controlsSize.height + 4) * expansion,
            titleBottom + 4,
            controlsY + controlsSize.height + 4
        )

        return Geometry(
            titleSize: titleSize,
            titleOrigin: CGPoint(x: titleX, y: titleY),
            controlsAnchor: UnitPoint(x: anchorX, y: 0),
            controlsOrigin: CGPoint(x: controlsX, y: controlsY),
            height: height
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: metrics.contentWidth, height: geometry(subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let geometry = geometry(subviews: subviews)
        subviews[0].place(
            at: CGPoint(x: bounds.minX + geometry.titleOrigin.x, y: bounds.minY + geometry.titleOrigin.y),
            anchor: .topLeading,
            proposal: ProposedViewSize(geometry.titleSize)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + geometry.controlsOrigin.x, y: bounds.minY + geometry.controlsOrigin.y),
            anchor: geometry.controlsAnchor,
            proposal: .unspecified
        )
    }
}

struct ScrollingChromeControl: View {
    let systemImage: String
    let title: String
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat
    var isInteractive: Bool = true

    static func cornerRadius(progress: CGFloat, width: CGFloat, height: CGFloat) -> CGFloat {
        Theme.controlCornerRadius + (min(width, height) / 2 - Theme.controlCornerRadius) * progress
    }

    var body: some View {
        let labelProgress = min(1, progress / 0.65)
        let cornerRadius = Self.cornerRadius(progress: progress, width: width, height: height)

        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .offset(y: -12 * (1 - labelProgress))
            Text(title)
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(width: max(1, width - 12), height: max(1, height / 2 - 6))
                .opacity(1 - labelProgress)
                .offset(y: 18)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .frame(width: width, height: height)
        .modifier(TimeMasterGlassSurface(
            cornerRadius: cornerRadius,
            isInteractive: isInteractive
        ))
    }
}

extension View {
    func scrollingChromeRing(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        keyNavShape(.roundedRectangle(cornerRadius: ScrollingChromeControl.cornerRadius(progress: progress, width: width, height: height)))
    }
}

/// Scroll-driven chrome: the header collapses as the content scrolls, then stays pinned above it.
struct ScrollingChrome<Content: View, Header: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsExpanded = false
    @Namespace private var viewport

    var onScrollOffset: ((CGFloat) -> Void)? = nil
    let metrics: (CGFloat) -> ScrollingChromeMetrics
    @ViewBuilder let content: (ScrollingChromeMetrics) -> Content
    @ViewBuilder let header: (CGFloat, ScrollingChromeMetrics) -> Header

    var body: some View {
        GeometryReader { proxy in
            let resolved = metrics(proxy.size.width)

            VStack(spacing: 0) {
                header(controlsExpanded ? 0 : 1, resolved)
                    .environment(\.scrollingChromeSetExpanded, setControlsExpanded)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                GeometryReader { scrollProxy in
                    scrollSurface(metrics: resolved, height: scrollProxy.size.height)
                        .modifier(ScrollingChromeOverflow())
                        .coordinateSpace(name: viewport)
                }
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
            .background {
                #if os(iOS)
                if #unavailable(iOS 17.0) {
                    ScrollingChromeLegacyOverflow()
                }
                #endif
            }
    }

    private func updateControls(offset: CGFloat) {
        onScrollOffset?(offset)
        let expanded = ScrollingChromeReveal.expanded(current: controlsExpanded, offset: offset)
        setControlsExpanded(expanded)
    }

    private func setControlsExpanded(_ expanded: Bool) {
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

private struct ScrollingChromeOverflow: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

#if os(iOS)
private struct ScrollingChromeLegacyOverflow: UIViewRepresentable {
    func makeUIView(context: Context) -> ScrollOverflowProbe {
        let view = ScrollOverflowProbe()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ScrollOverflowProbe, context: Context) {
        uiView.connect()
    }

    static func dismantleUIView(_ uiView: ScrollOverflowProbe, coordinator: ()) {
        uiView.restore()
    }

    final class ScrollOverflowProbe: UIView {
        private weak var scrollView: UIScrollView?
        private var originalClipping = true

        override func didMoveToWindow() {
            super.didMoveToWindow()
            connect()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            connect()
        }

        func connect() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    if scrollView !== scroll {
                        restore()
                        scrollView = scroll
                        originalClipping = scroll.clipsToBounds
                    }
                    scroll.clipsToBounds = false
                    return
                }
                ancestor = view.superview
            }
        }

        func restore() {
            scrollView?.clipsToBounds = originalClipping
            scrollView = nil
        }
    }
}
#endif
