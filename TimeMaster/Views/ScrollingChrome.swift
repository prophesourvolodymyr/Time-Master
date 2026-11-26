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
/// scrolls to the end and back once each time it appears or changes, so all of it can be read and an idle page then
/// draws nothing; with Reduce Motion it stays still with the fade.
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
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: travel)) { offset = -overflow }
        try? await Task.sleep(nanoseconds: UInt64((travel + 1.4) * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: travel)) { offset = 0 }
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

struct ScrollingChromeButtonStyle: ButtonStyle {
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(TimeMasterActionFeedback(
                isPressed: configuration.isPressed,
                cornerRadius: ScrollingChromeControl.cornerRadius(progress: progress, width: width, height: height)
            ))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: ScrollingChromeControl.cornerRadius(progress: progress, width: width, height: height)))
    }
}

extension View {
    func scrollingChromeRing(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        keyNavShape(.roundedRectangle(cornerRadius: ScrollingChromeControl.cornerRadius(progress: progress, width: width, height: height)))
    }
}

/// The soft edge where content scrolls under pinned chrome: the page background thinning out downward over `height`,
/// so the content dissolves under a header or a toolbar instead of meeting a hard line; `solidHeight` keeps the
/// background whole above the fade (behind a toolbar). It takes no hits and VoiceOver skips it.
struct ScrollingChromeFade: View {
    static let defaultHeight: CGFloat = 28

    var height: CGFloat = ScrollingChromeFade.defaultHeight
    var solidHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Theme.background
                .frame(height: max(0, solidHeight))
            LinearGradient(
                stops: [
                    .init(color: Theme.background, location: 0),
                    .init(color: Theme.background.opacity(0.82), location: 0.3),
                    .init(color: Theme.background.opacity(0.38), location: 0.66),
                    .init(color: Theme.background.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Hangs a `ScrollingChromeFade` under this pinned view, over the content scrolling beneath it (the view needs a
    /// higher `zIndex` than that content). `isVisible` fades it in and out, e.g. only once the content has scrolled.
    func scrollingChromeFadeBelow(height: CGFloat = ScrollingChromeFade.defaultHeight, isVisible: Bool = true) -> some View {
        overlay(alignment: .bottom) {
            ScrollingChromeFade(height: height)
                .offset(y: height)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: isVisible)
        }
    }
}

/// Whether the header shows its labelled controls. Held outside the page, so a toggle redraws the header and never
/// the content below it.
final class ScrollingChromeState: ObservableObject {
    @Published private(set) var expanded = false
    private var reveal = ScrollingChromeReveal()

    func setExpanded(_ expanded: Bool, reduceMotion: Bool) {
        guard expanded != self.expanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
            self.expanded = expanded
        }
    }

    func update(_ scroll: ScrollingChromeScroll, reduceMotion: Bool) {
        setExpanded(reveal.expanded(expanded, after: scroll), reduceMotion: reduceMotion)
    }
}

final class ScrollingChromeEdge: ObservableObject {
    @Published private(set) var isScrolled = false

    func update(offset: CGFloat) {
        let scrolled = isScrolled ? offset > 1 : offset > 4
        guard scrolled != isScrolled else { return }
        isScrolled = scrolled
    }
}

private struct ScrollingChromeHeaderHost<Header: View>: View {
    @ObservedObject var state: ScrollingChromeState
    let metrics: ScrollingChromeMetrics
    let header: (CGFloat, ScrollingChromeMetrics) -> Header
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        header(state.expanded ? 0 : 1, metrics)
            .environment(\.scrollingChromeSetExpanded, { expanded in
                state.setExpanded(expanded, reduceMotion: reduceMotion)
            })
    }
}

private struct ScrollingChromeEdgeHost<Pinned: View>: View {
    @ObservedObject var edge: ScrollingChromeEdge
    let pinned: Pinned

    var body: some View {
        VStack(spacing: 0) {
            pinned
            ScrollingChromeFade()
                .opacity(edge.isScrolled ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: edge.isScrolled)
        }
    }
}

/// Scroll-driven chrome: the header collapses as the content scrolls, then stays pinned above it.
struct ScrollingChrome<Content: View, Header: View, Pinned: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = ScrollingChromeState()
    @State private var edge = ScrollingChromeEdge()
    @Namespace private var viewport

    var onScrollOffset: ((CGFloat) -> Void)? = nil
    let metrics: (CGFloat) -> ScrollingChromeMetrics
    @ViewBuilder let content: (ScrollingChromeMetrics) -> Content
    @ViewBuilder let header: (CGFloat, ScrollingChromeMetrics) -> Header
    @ViewBuilder let pinned: (ScrollingChromeMetrics) -> Pinned

    var body: some View {
        GeometryReader { proxy in
            let resolved = metrics(proxy.size.width)

            VStack(spacing: 0) {
                ScrollingChromeHeaderHost(state: state, metrics: resolved, header: header)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                Group {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        scrollSurface(metrics: resolved, viewportHeight: nil)
                    } else {
                        GeometryReader { scrollProxy in
                            scrollSurface(metrics: resolved, viewportHeight: scrollProxy.size.height)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    ScrollingChromeEdgeHost(edge: edge, pinned: pinned(resolved))
                }
            }
        }
    }

    private func scrollSurface(metrics: ScrollingChromeMetrics, viewportHeight: CGFloat?) -> some View {
        ScrollView {
            pageContent(metrics: metrics, viewportHeight: viewportHeight)
                .scrollingChromeScrollProbe(in: viewport, unclipsScrollView: true, update)
        }
        .scrollingChromeScrollReader(update)
        .modifier(ScrollingChromeOverflow())
        .coordinateSpace(name: viewport)
    }

    /// The content, at least one point taller than the scroll view so the header can always be pulled. Where the
    /// scroll view's height can be read from the container, the content does not depend on it, so the header
    /// collapsing never re-evaluates the page.
    @ViewBuilder
    private func pageContent(metrics: ScrollingChromeMetrics, viewportHeight: CGFloat?) -> some View {
        if let viewportHeight {
            content(metrics)
                .frame(minHeight: viewportHeight + 1, alignment: .top)
        } else if #available(iOS 17.0, macOS 14.0, *) {
            ZStack(alignment: .top) {
                Color.clear
                    .containerRelativeFrame(.vertical, alignment: .top) { length, _ in length + 1 }
                content(metrics)
            }
        } else {
            content(metrics)
        }
    }

    private func update(_ scroll: ScrollingChromeScroll) {
        onScrollOffset?(scroll.offset)
        edge.update(offset: scroll.offset)
        state.update(scroll, reduceMotion: reduceMotion)
    }
}

extension ScrollingChrome where Pinned == EmptyView {
    init(
        onScrollOffset: ((CGFloat) -> Void)? = nil,
        metrics: @escaping (CGFloat) -> ScrollingChromeMetrics,
        @ViewBuilder content: @escaping (ScrollingChromeMetrics) -> Content,
        @ViewBuilder header: @escaping (CGFloat, ScrollingChromeMetrics) -> Header
    ) {
        self.init(onScrollOffset: onScrollOffset, metrics: metrics, content: content, header: header, pinned: { _ in EmptyView() })
    }
}

struct ScrollingChromeScroll: Equatable {
    var offset: CGFloat
    var isInteracting: Bool
}

struct ScrollingChromeReveal {
    static let pullDistance: CGFloat = 32
    static let collapseDistance: CGFloat = 24
    private static let restingBand: CGFloat = 4
    private static let continuousStep: CGFloat = 64

    private var previousOffset: CGFloat?
    private var pullArmed = false

    mutating func expanded(_ expanded: Bool, after scroll: ScrollingChromeScroll) -> Bool {
        let previous = previousOffset
        previousOffset = scroll.offset
        if !scroll.isInteracting || scroll.offset > Self.restingBand {
            pullArmed = false
        } else if let previous, previous >= -Self.restingBand, previous - scroll.offset <= Self.continuousStep {
            pullArmed = true
        }
        if scroll.offset > Self.collapseDistance { return false }
        if pullArmed, scroll.offset < -Self.pullDistance { return true }
        return expanded
    }
}

extension View {
    @ViewBuilder
    func scrollingChromeScrollReader(_ report: @escaping (ScrollingChromeScroll) -> Void) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            modifier(ScrollingChromeScrollReader(report: report))
        } else {
            self
        }
    }

    func scrollingChromeScrollProbe<Space: Hashable>(
        in space: Space,
        unclipsScrollView: Bool = false,
        _ report: @escaping (ScrollingChromeScroll) -> Void
    ) -> some View {
        modifier(ScrollingChromeScrollProbe(space: AnyHashable(space), unclipsScrollView: unclipsScrollView, report: report))
    }
}

@available(iOS 18.0, macOS 15.0, *)
private struct ScrollingChromeScrollReader: ViewModifier {
    let report: (ScrollingChromeScroll) -> Void
    @State private var interaction = ScrollingChromeInteraction()

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                interaction.isInteracting = phase == .tracking || phase == .interacting
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                report(ScrollingChromeScroll(offset: offset, isInteracting: interaction.isInteracting))
            }
    }
}

private final class ScrollingChromeInteraction {
    var isInteracting = false
}

private struct ScrollingChromeScrollProbe: ViewModifier {
    let space: AnyHashable
    let unclipsScrollView: Bool
    let report: (ScrollingChromeScroll) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            content
        } else if #available(iOS 17.0, *) {
            content.background {
                ScrollingChromeScrollObserver(unclipsScrollView: false, report: report)
            }
        } else {
            content.background {
                ScrollingChromeScrollObserver(unclipsScrollView: unclipsScrollView, report: report)
            }
        }
        #else
        if #available(macOS 15.0, *) {
            content
        } else {
            content.onGeometryChange(for: CGFloat.self) { [space] proxy in
                -proxy.frame(in: .named(space)).minY
            } action: { offset in
                report(ScrollingChromeScroll(offset: offset, isInteracting: true))
            }
        }
        #endif
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
private struct ScrollingChromeScrollObserver: UIViewRepresentable {
    let unclipsScrollView: Bool
    let report: (ScrollingChromeScroll) -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.report = report
        view.unclipsScrollView = unclipsScrollView
        view.connect()
    }

    static func dismantleUIView(_ view: ObserverView, coordinator: ()) {
        view.disconnect()
        view.report = nil
    }

    final class ObserverView: UIView {
        var report: ((ScrollingChromeScroll) -> Void)?
        var unclipsScrollView = false
        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?
        private var originalClipping: Bool?
        private var delivered: ScrollingChromeScroll?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                disconnect()
            } else {
                connect()
            }
        }

        func connect() {
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            guard let scroll = ancestor as? UIScrollView else { return }
            if scroll !== scrollView {
                disconnect()
                scrollView = scroll
                observation = scroll.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scroll, _ in
                    let sample = ScrollingChromeScroll(
                        offset: scroll.contentOffset.y + scroll.adjustedContentInset.top,
                        isInteracting: scroll.isTracking
                    )
                    DispatchQueue.main.async {
                        self?.deliver(sample)
                    }
                }
            }
            if unclipsScrollView {
                if originalClipping == nil { originalClipping = scroll.clipsToBounds }
                scroll.clipsToBounds = false
            }
        }

        func disconnect() {
            observation?.invalidate()
            observation = nil
            if let scrollView, let originalClipping {
                scrollView.clipsToBounds = originalClipping
            }
            originalClipping = nil
            scrollView = nil
            delivered = nil
        }

        private func deliver(_ sample: ScrollingChromeScroll) {
            guard scrollView != nil, sample != delivered else { return }
            delivered = sample
            report?(sample)
        }
    }
}
#endif
