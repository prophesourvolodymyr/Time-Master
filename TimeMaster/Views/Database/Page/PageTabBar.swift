import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The tabs of a page, Skillmax's skill page tabs in Tmax's colours: one slim debossed track with a raised orange pill
/// on the selected tab that slides to the next one, and each tab's count beside its name. On a phone the track spans
/// the width while the tabs fit and scrolls sideways when they do not, keeping the selected tab in view; on the Mac it
/// hugs its tabs. It scrolls with the page, as on Skillmax.
struct PageTabBar: View {
    let tabs: [PageTab]
    let selection: PageTab
    let badge: (PageTab) -> Int?
    let onSelect: (PageTab) -> Void

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ViewThatFits(in: .horizontal) {
            track(fillsWidth: Self.fillsWidth)
            scrollingTrack
        }
        .skillSegmentTrack()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    private static var fillsWidth: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }

    private var scrollingTrack: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                track(fillsWidth: false)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { value in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func track(fillsWidth: Bool) -> some View {
        PageTabRowLayout(fillsWidth: fillsWidth) {
            ForEach(tabs) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    label(for: tab)
                }
                .buttonStyle(SkillSegmentButtonStyle(isSelected: selection == tab, namespace: namespace))
                .accessibilityLabel(badge(tab).map { "\(tab.title) \($0)" } ?? tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .id(tab)
            }
        }
    }

    private func label(for tab: PageTab) -> some View {
        HStack(spacing: 5) {
            Text(tab.title)
                .font(Self.nameFont)
            if let count = badge(tab) {
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .opacity(0.7)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private static var nameFont: Font {
        #if os(macOS)
        return TimeMasterFont.black(15, relativeTo: .subheadline)
        #else
        return TimeMasterFont.black(14, relativeTo: .subheadline)
        #endif
    }
}

/// Lays the tabs side by side, each as wide as its name and count ask. With `fillsWidth` the room left over is shared
/// equally; when the names do not fit they all shrink in proportion.
private struct PageTabRowLayout: Layout {
    var fillsWidth: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = ideals.map(\.height).max() ?? 0
        let natural = ideals.reduce(0) { $0 + $1.width }
        guard let width = proposal.width, width.isFinite else {
            return CGSize(width: natural, height: height)
        }
        return CGSize(width: fillsWidth ? width : min(width, natural), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }
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

#if os(macOS)
/// ⌥⌘← and ⌥⌘→ on the Mac: the tab before or after the selected one. Plain arrows stay with keyboard navigation,
/// which reaches every tab like any other button; the keys rest while a text field has the keyboard.
struct PageTabStepKeys: View {
    let tabs: [PageTab]
    let selection: PageTab
    let isEnabled: Bool
    let onSelect: (PageTab) -> Void

    var body: some View {
        ZStack {
            Button("Previous tab") { step(-1) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Next tab") { step(1) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
        }
        .disabled(!isEnabled)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSText || responder is NSTextField { return }
        guard let index = tabs.firstIndex(of: selection), tabs.indices.contains(index + delta) else { return }
        onSelect(tabs[index + delta])
    }
}
#endif
