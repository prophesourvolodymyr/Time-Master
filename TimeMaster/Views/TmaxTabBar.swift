import SwiftUI

/// One tab of a `TmaxTabBar`: its name, an optional SF Symbol before it and an optional count after it.
struct TmaxTab<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var symbol: String?
    var count: Int?
    /// Off: the tab shows its symbol alone; the title stays its tooltip and its VoiceOver name.
    var showsTitle: Bool
    /// The tooltip; a symbol-only tab shows its title without one.
    var help: String?
    var accessibilityIdentifier: String?
    /// Read after the name instead of the count ("12 matches").
    var accessibilityValue: String?
    var accessibilityHint: String?
    /// A second action of the tab: a double-click or a double-tap, its context menu and a VoiceOver action.
    var alternate: TmaxTabAlternate?

    init(
        _ id: ID,
        title: String,
        symbol: String? = nil,
        count: Int? = nil,
        showsTitle: Bool = true,
        help: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityValue: String? = nil,
        accessibilityHint: String? = nil,
        alternate: TmaxTabAlternate? = nil
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.count = count
        self.showsTitle = showsTitle
        self.help = help
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityValue = accessibilityValue
        self.accessibilityHint = accessibilityHint
        self.alternate = alternate
    }

    /// The name VoiceOver reads and UI tests find: "Attachments 3", or the title alone when a value is read after it.
    var accessibilityName: String {
        guard accessibilityValue == nil, let count else { return title }
        return "\(title) \(count)"
    }

    /// The tooltip: `help`, else the title of a tab that shows only its symbol.
    var tooltip: String { help ?? (showsTitle ? "" : title) }
}

/// A tab's second action ("Open as a Page"): what its context menu and VoiceOver call it, and what it does.
struct TmaxTabAlternate {
    let title: String
    var systemImage: String
    let action: () -> Void
}

/// A tab's second action on a double-click or a double-tap, in its context menu and as a VoiceOver action.
private struct TmaxTabAlternateActions: ViewModifier {
    let alternate: TmaxTabAlternate?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let alternate {
            content
                .simultaneousGesture(TapGesture(count: 2).onEnded { alternate.action() })
                .contextMenu {
                    Button(action: alternate.action) {
                        Label(alternate.title, systemImage: alternate.systemImage)
                    }
                }
                .accessibilityAction(named: alternate.title, alternate.action)
        } else {
            content
        }
    }
}

/// The motion and the default layout every `TmaxTabBar` shares.
enum TmaxTabBarStyle {
    /// The swoosh: the spring the selected pill slides on, Skillmax's skill page tabs.
    static let swoosh = Animation.interpolatingSpring(mass: 0.8, stiffness: 420, damping: 26)

    /// The phone's track spans the width; the Mac's hugs its tabs.
    static var fillsWidth: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }

    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : swoosh
    }
}

private let tmaxTabTrackSpace = "tmax-tab-track"

private struct TmaxTabFramesKey<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID: CGRect] { [:] }

    static func reduce(value: inout [ID: CGRect], nextValue: () -> [ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Tmax's tab row, the skill page tabs on every page: one slim debossed track with a raised orange pill on the selected
/// tab that swooshes to the next one, each tab's symbol, name and count. While the tabs fit, the track spans the width
/// (`fillsWidth`) or hugs its tabs; when they do not, it scrolls sideways and keeps the selected tab in view. The pill
/// slides however the selection changes (a tap, a key, a widget) and cuts with Reduce Motion. Each tab is a keyboard
/// navigation target, carries the selected trait and reads as its name and count.
struct TmaxTabBar<ID: Hashable, Label: View>: View {
    private let tabs: [TmaxTab<ID>]
    private let selection: ID
    private let fillsWidth: Bool
    private let name: String
    private let onSelect: (ID) -> Void
    private let label: (TmaxTab<ID>) -> Label

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: ID?
    @State private var frames: [ID: CGRect] = [:]
    @State private var isDragging = false
    @State private var fingerX: CGFloat = 0

    /// `onSelect` hears every tap, the selected tab's too, and changes the selection itself.
    init(
        _ tabs: [TmaxTab<ID>],
        selection: ID,
        fillsWidth: Bool = TmaxTabBarStyle.fillsWidth,
        accessibilityLabel: String = "Tabs",
        onSelect: @escaping (ID) -> Void,
        @ViewBuilder label: @escaping (TmaxTab<ID>) -> Label
    ) {
        self.tabs = tabs
        self.selection = selection
        self.fillsWidth = fillsWidth
        self.name = accessibilityLabel
        self.onSelect = onSelect
        self.label = label
    }

    /// Selects the tapped tab, with a selection haptic when it changes.
    init(
        _ tabs: [TmaxTab<ID>],
        selection: Binding<ID>,
        fillsWidth: Bool = TmaxTabBarStyle.fillsWidth,
        accessibilityLabel: String = "Tabs",
        @ViewBuilder label: @escaping (TmaxTab<ID>) -> Label
    ) {
        self.init(
            tabs,
            selection: selection.wrappedValue,
            fillsWidth: fillsWidth,
            accessibilityLabel: accessibilityLabel,
            onSelect: { id in
                guard id != selection.wrappedValue else { return }
                EverHaptic.selection()
                selection.wrappedValue = id
            },
            label: label
        )
    }

    private var current: ID { draft ?? selection }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            track(fillsWidth: fillsWidth)
            scrollingTrack
        }
        .skillSegmentTrack()
        .animation(TmaxTabBarStyle.animation(reduceMotion: reduceMotion), value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .onDisappear {
            draft = nil
            isDragging = false
        }
    }

    private var scrollingTrack: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                track(fillsWidth: false)
            }
            .scrollDisabled(isDragging)
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { value in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func track(fillsWidth: Bool) -> some View {
        TmaxTabRowLayout(fillsWidth: fillsWidth) {
            ForEach(tabs) { tab in
                let isCurrent = tab.id == current
                Button {
                    onSelect(tab.id)
                } label: {
                    label(tab)
                }
                .buttonStyle(SkillSegmentButtonStyle(
                    isSelected: isCurrent,
                    namespace: namespace,
                    isGrabbed: isDragging && isCurrent,
                    pillOffset: isDragging && isCurrent ? pillOffset(for: tab.id) : 0
                ))
                .modifier(TmaxTabAlternateActions(alternate: tab.alternate))
                .help(tab.tooltip)
                .accessibilityLabel(tab.accessibilityName)
                .accessibilityValue(tab.accessibilityValue ?? "")
                .accessibilityHint(tab.accessibilityHint ?? "")
                .accessibilityAddTraits(tab.id == selection ? .isSelected : [])
                .accessibilityIdentifier(tab.accessibilityIdentifier ?? "")
                .id(tab.id)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TmaxTabFramesKey<ID>.self,
                            value: [tab.id: proxy.frame(in: .named(tmaxTabTrackSpace))]
                        )
                    }
                }
            }
        }
        .coordinateSpace(name: tmaxTabTrackSpace)
        .onPreferenceChange(TmaxTabFramesKey<ID>.self) { frames = $0 }
        .simultaneousGesture(pillDrag)
    }

    private var pillDrag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(tmaxTabTrackSpace))
            .onChanged { value in
                if !isDragging {
                    guard abs(value.translation.width) > abs(value.translation.height),
                          let pill = frames[selection],
                          pill.insetBy(dx: -2, dy: -10).contains(value.startLocation) else { return }
                    isDragging = true
                }
                fingerX = value.location.x
                guard let hovered = tab(atX: value.location.x), hovered != current else { return }
                draft = hovered
                EverHaptic.selection()
            }
            .onEnded { _ in
                guard isDragging else { return }
                isDragging = false
                if let target = draft, target != selection { onSelect(target) }
                DispatchQueue.main.async { draft = nil }
            }
    }

    private func tab(atX x: CGFloat) -> ID? {
        var found: ID?
        for tab in tabs {
            guard let frame = frames[tab.id] else { continue }
            if x < frame.minX { return found ?? tab.id }
            found = tab.id
            if x < frame.maxX { return tab.id }
        }
        return found
    }

    private func pillOffset(for id: ID) -> CGFloat {
        guard let frame = frames[id] else { return 0 }
        return min(9, max(-9, (fingerX - frame.midX) * 0.3))
    }
}

extension TmaxTabBar where Label == TmaxTabLabel {
    /// `onSelect` hears every tap, the selected tab's too, and changes the selection itself.
    init(
        _ tabs: [TmaxTab<ID>],
        selection: ID,
        fillsWidth: Bool = TmaxTabBarStyle.fillsWidth,
        accessibilityLabel: String = "Tabs",
        onSelect: @escaping (ID) -> Void
    ) {
        self.init(tabs, selection: selection, fillsWidth: fillsWidth, accessibilityLabel: accessibilityLabel, onSelect: onSelect) {
            TmaxTabLabel(tab: $0)
        }
    }

    /// Selects the tapped tab, with a selection haptic when it changes.
    init(
        _ tabs: [TmaxTab<ID>],
        selection: Binding<ID>,
        fillsWidth: Bool = TmaxTabBarStyle.fillsWidth,
        accessibilityLabel: String = "Tabs"
    ) {
        self.init(tabs, selection: selection, fillsWidth: fillsWidth, accessibilityLabel: accessibilityLabel) {
            TmaxTabLabel(tab: $0)
        }
    }
}

/// The face of a tab: its symbol, its name and its count in the skill page tab type.
struct TmaxTabLabel: View {
    let title: String
    var symbol: String?
    var count: Int?
    var showsTitle = true

    init(title: String, symbol: String? = nil, count: Int? = nil, showsTitle: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.count = count
        self.showsTitle = showsTitle
    }

    init<ID: Hashable>(tab: TmaxTab<ID>) {
        self.init(title: tab.title, symbol: tab.symbol, count: tab.count, showsTitle: tab.showsTitle)
    }

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: Self.symbolSize, weight: .semibold))
                    .accessibilityHidden(true)
            }
            if showsTitle || symbol == nil {
                Text(title)
                    .font(Self.nameFont)
            }
            if let count {
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .opacity(0.7)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private static var symbolSize: CGFloat {
        #if os(macOS)
        return 14
        #else
        return 13
        #endif
    }

    static var nameFont: Font {
        #if os(macOS)
        return TimeMasterFont.black(15, relativeTo: .subheadline)
        #else
        return TimeMasterFont.black(14, relativeTo: .subheadline)
        #endif
    }
}

/// A filter chip in the tab bar's look: a small debossed track of its own, with the tabs' raised orange pill inside
/// while it is on, filled and emptied on the swoosh spring. Chips that share `namespace` and `matchID` slide one pill
/// between them, so a choice that moves within a group (All to a type, one section to another) swooshes like the
/// tabs; chips that can be on together need different ids (or no namespace) and fill and empty in place.
struct TmaxChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    var namespace: Namespace.ID? = nil
    var matchID: AnyHashable = "selection"

    func makeBody(configuration: Configuration) -> some View {
        SkillSegmentButtonStyle(isSelected: isSelected, namespace: namespace, fillsWidth: false, matchID: matchID)
            .makeBody(configuration: configuration)
            .font(TmaxTabLabel.nameFont)
            .lineLimit(1)
            .skillSegmentTrack()
            .modifier(TmaxSwoosh(value: isSelected))
    }
}

/// Runs the changes of `value` below on the swoosh spring, or cuts them with Reduce Motion.
private struct TmaxSwoosh<Value: Equatable>: ViewModifier {
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(TmaxTabBarStyle.animation(reduceMotion: reduceMotion), value: value)
    }
}

/// Lays the tabs side by side, each as wide as its label asks. With `fillsWidth` the room left over is shared equally;
/// when the labels do not fit they all shrink in proportion.
private struct TmaxTabRowLayout: Layout {
    var fillsWidth: Bool

    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func updateCache(_ cache: inout [CGSize], subviews: Subviews) {
        cache = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        let height = cache.map(\.height).max() ?? 0
        let natural = cache.reduce(0) { $0 + $1.width }
        guard let width = proposal.width, width.isFinite else {
            return CGSize(width: natural, height: height)
        }
        return CGSize(width: fillsWidth ? width : min(width, natural), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        let ideal = cache.map(\.width)
        let total = ideal.reduce(0, +)
        let widths: [CGFloat]
        if total > 0, bounds.width < total {
            widths = ideal.map { $0 * bounds.width / total }
        } else if fillsWidth, !ideal.isEmpty {
            let extra = (bounds.width - total) / CGFloat(ideal.count)
            widths = ideal.map { $0 + extra }
        } else {
            widths = ideal
        }
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width
        }
    }
}
