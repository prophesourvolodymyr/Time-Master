import SwiftUI

/// A tile's width before its row shares out the room it has (`PageWidgetKind.naturalWidth`).
struct PageWidgetNaturalWidth: LayoutValueKey {
    static let defaultValue: CGFloat = 180
}

/// Lays page widgets out at one height. A row shares out its width: every tile takes the same share of its natural
/// width, from `minScale` (a row a little too narrow) up to `maxStretch` times (the rest of a short row stays empty).
/// With `wraps`, tiles that do not fit one row go into the fewest rows that hold them, cut where the fullest row comes
/// out least full; without, they stay in one row, which the strip's `ViewThatFits` only picks when it fits.
struct PageWidgetRowLayout: Layout {
    var wraps = true
    var spacing: CGFloat = PageWidgetMetrics.spacing
    var height: CGFloat = PageWidgetMetrics.tileHeight
    var minScale: CGFloat = 0.86
    var maxStretch: CGFloat = 2.2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = subviews.map { $0[PageWidgetNaturalWidth.self] }
        guard !widths.isEmpty else { return .zero }
        guard let width = proposal.width, width.isFinite else {
            return CGSize(width: leastSpan(widths[...]), height: height)
        }
        let rowCount = CGFloat(rows(widths, width: width).count)
        return CGSize(width: width, height: rowCount * height + (rowCount - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = subviews.map { $0[PageWidgetNaturalWidth.self] }
        var y = bounds.minY
        for row in rows(widths, width: bounds.width) {
            let natural = widths[row].reduce(0, +)
            let room = max(0, bounds.width - spacing * CGFloat(row.count - 1))
            let factor = natural > 0 ? min(maxStretch, room / natural) : 1
            var x = bounds.minX
            for index in row {
                let width = widths[index] * factor
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: height)
                )
                x += width + spacing
            }
            y += height + spacing
        }
    }

    /// The width tiles need side by side, each squeezed as far as `minScale` lets it.
    private func leastSpan(_ widths: ArraySlice<CGFloat>) -> CGFloat {
        widths.reduce(0, +) * minScale + spacing * CGFloat(max(0, widths.count - 1))
    }

    /// The tiles of each row, in order.
    private func rows(_ widths: [CGFloat], width: CGFloat) -> [Range<Int>] {
        guard !widths.isEmpty else { return [] }
        guard wraps, leastSpan(widths[...]) > width else { return [widths.indices] }
        let greedy = greedyRows(widths, width: width)
        return balancedRows(widths, count: greedy.count, width: width) ?? greedy
    }

    /// Rows filled one after another, each as far as it goes.
    private func greedyRows(_ widths: [CGFloat], width: CGFloat) -> [Range<Int>] {
        var rows: [Range<Int>] = []
        var start = 0
        for index in widths.indices.dropFirst() where leastSpan(widths[start...index]) > width {
            rows.append(start..<index)
            start = index
        }
        rows.append(start..<widths.count)
        return rows
    }

    /// Of every way to cut the tiles, in order, into `count` rows that each fit `width` (a tile too wide for it alone
    /// in its row), the one whose fullest row is least full; nil when there is none.
    private func balancedRows(_ widths: [CGFloat], count: Int, width: CGFloat) -> [Range<Int>]? {
        let total = widths.count
        guard count > 1, count < total else { return nil }
        var best: [Range<Int>]?
        var bestFullest = CGFloat.infinity
        var cuts: [Int] = []
        func choose(after previous: Int, remaining: Int) {
            guard remaining > 0 else {
                let bounds = [0] + cuts + [total]
                let rows = bounds.indices.dropLast().map { bounds[$0]..<bounds[$0 + 1] }
                var fullest: CGFloat = 0
                for row in rows {
                    let rowSpan = leastSpan(widths[row])
                    if rowSpan > width, row.count > 1 { return }
                    fullest = max(fullest, rowSpan)
                }
                if fullest < bestFullest {
                    bestFullest = fullest
                    best = rows
                }
                return
            }
            guard previous + 1 <= total - remaining else { return }
            for cut in (previous + 1)...(total - remaining) {
                cuts.append(cut)
                choose(after: cut, remaining: remaining - 1)
                cuts.removeLast()
            }
        }
        choose(after: 0, remaining: count - 1)
        return best
    }
}

/// Snaps a sideways scroll of tiles to their leading edges and lets the tiles run on past the strip's edge while they
/// scroll (iOS 17 and later; earlier systems scroll freely inside the strip).
struct PageWidgetSnapping: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
        } else {
            content
        }
    }
}

/// Marks the row of tiles `PageWidgetSnapping` snaps to.
struct PageWidgetSnapTargets: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}
