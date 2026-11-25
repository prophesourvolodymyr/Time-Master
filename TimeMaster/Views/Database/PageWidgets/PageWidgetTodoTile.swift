import SwiftUI
import TimeMasterCore

struct PageWidgetTodoTile: View {
    let todos: PageWidgetTodos
    let onOpen: (PageWidgetTarget) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// To-dos just ticked, kept in their place with a filled check until they go.
    @State private var settling: [Settling] = []

    /// Lines the tile has room for.
    static let visibleRows = 3
    /// How long a ticked to-do stays before it goes.
    static let settleDelay: UInt64 = 600_000_000

    private struct Settling {
        let row: PageWidgetTodoRow
        let index: Int
    }

    var body: some View {
        let rows = shownRows
        PageWidgetTile(
            kind: .todos,
            target: .todos,
            summary: summary,
            tint: Self.tint,
            art: rows.isEmpty ? .clipboard : nil,
            hasControls: !rows.isEmpty,
            onOpen: onOpen
        ) {
            if rows.isEmpty {
                PageWidgetEmptyState(systemImage: nil, title: todos.total == 0 ? "Nothing to do yet" : "Nothing left to do")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    WidgetHero(text: "\(todos.openCount)", size: 26)
                        .frame(height: 30, alignment: .leading)
                        .accessibilityHidden(true)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        line(row, at: index)
                    }
                    Spacer(minLength: 0)
                }
                .padding(PageWidgetMetrics.inset)
            }
        }
    }

    private static let tint = WidgetTint.orange

    /// The open to-dos, with the ones just ticked back in their places, as many as fit.
    private var shownRows: [PageWidgetTodoRow] {
        var rows = todos.rows
        for item in settling.sorted(by: { $0.index < $1.index }) where !rows.contains(where: { $0.id == item.row.id }) {
            rows.insert(item.row, at: min(item.index, rows.count))
        }
        return Array(rows.prefix(Self.visibleRows))
    }

    private func line(_ row: PageWidgetTodoRow, at index: Int) -> some View {
        let isTicked = settling.contains { $0.row.id == row.id }
        return HStack(spacing: 6) {
            Button {
                tick(row, at: index)
            } label: {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isTicked ? Self.tint.ink : Self.tint.secondaryInk)
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .circle)
            .help("Mark as done")
            .accessibilityLabel(row.pageTitle.map { "\(row.title), in \($0)" } ?? row.title)
            .accessibilityValue(isTicked ? "Done" : "Not done")
            .accessibilityHint("Marks it done")
            Text(row.title)
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                .strikethrough(isTicked, color: Self.tint.secondaryInk)
                .foregroundStyle(isTicked ? Self.tint.secondaryInk : Self.tint.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.leading, row.isNested ? 14 : 0)
        .frame(height: 22)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading)))
    }

    /// Ticks a to-do off. It stays with a filled check for a moment, then goes; a failed save puts it back as it was
    /// and says why.
    private func tick(_ row: PageWidgetTodoRow, at index: Int) {
        guard !settling.contains(where: { $0.row.id == row.id }) else { return }
        let wasLast = todos.openCount <= 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            settling.append(Settling(row: row, index: index))
        }
        let saved = SkillErrorCenter.shared.attempt("Tick the to-do") {
            try store.setChecklistEntry(TodoItem.self, row.id, done: true, in: row.pageID)
        }
        guard saved else {
            EverHaptic.warning()
            settling.removeAll { $0.row.id == row.id }
            return
        }
        if wasLast {
            EverHaptic.success()
        } else {
            EverHaptic.selection()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.settleDelay)
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.86)) {
                settling.removeAll { $0.row.id == row.id }
            }
        }
    }

    private var summary: String {
        if todos.total == 0 { return "To-do: nothing yet" }
        if todos.openCount == 0 { return "To-do: nothing left to do" }
        return "To-do: \(todos.openCount) open"
    }
}
