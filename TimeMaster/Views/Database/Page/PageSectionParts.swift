import SwiftUI

/// The title row of one part of a page: Skillmax's section heading (a small icon tile, the title and its count) with
/// the part's own actions at the end.
struct PageSectionHeader<Actions: View>: View {
    let symbol: String
    let title: String
    var count: Int?
    let actions: Actions

    init(symbol: String, title: String, count: Int? = nil, @ViewBuilder actions: () -> Actions) {
        self.symbol = symbol
        self.title = title
        self.count = count
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: SkillMetrics.s2) {
            SkillSectionHeading(symbol: symbol, title: title, count: count)
            actions
        }
    }
}

extension PageSectionHeader where Actions == EmptyView {
    init(symbol: String, title: String, count: Int? = nil) {
        self.init(symbol: symbol, title: title, count: count) { EmptyView() }
    }
}

/// The orange circle with a plus at the end of a section heading (as on the To-do and Milestones headings); also the
/// label of an add menu.
struct PageSectionAddGlyph: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.black)
            .frame(width: 34, height: 34)
            .background(Theme.toolbarOrange, in: Circle())
            .contentShape(Circle())
    }
}

/// A section heading's add button.
struct PageSectionAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PageSectionAddGlyph()
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A word in orange at the end of a section heading ("Edit", "Done", "Attach").
struct PageSectionTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.toolbarOrange)
                .padding(.horizontal, SkillMetrics.s2)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .capsule)
    }
}

/// The hairline between the parts the All tab stacks.
struct PageSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A quiet card saying a part of the page is empty and what goes there; `actions` invite the first one.
struct PageEmptyCard<Actions: View>: View {
    let symbol: String
    let title: String
    let detail: String
    let actions: Actions

    init(symbol: String, title: String, detail: String, @ViewBuilder actions: () -> Actions) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: SkillMetrics.s2) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !(actions is EmptyView) {
                actions
                    .padding(.top, SkillMetrics.s1)
            }
        }
        .padding(SkillMetrics.s4)
        .frame(maxWidth: .infinity, minHeight: 110)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
    }
}

extension PageEmptyCard where Actions == EmptyView {
    init(symbol: String, title: String, detail: String) {
        self.init(symbol: symbol, title: title, detail: detail) { EmptyView() }
    }
}

/// Chips in rows that wrap to the width they are given, each row centred on its tallest chip.
struct PageChipFlowLayout: Layout {
    var spacing: CGFloat = SkillMetrics.s2
    var rowSpacing: CGFloat = SkillMetrics.s1

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: min(proposal.width ?? widest, widest), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                let width = min(item.size.width, bounds.width)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(width: width, height: item.size.height)
                )
                x += width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append((index: index, size: size))
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
