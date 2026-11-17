import SwiftUI
import TimeMasterCore

/// The widgets under a page's header: Skillmax's widget strip in Tmax's colours, for any page, and with nothing that
/// starts a session. Each tile says one thing about the page (its clips, its progress, its to-dos and milestones, what
/// to learn first, the workouts that train it, what a folder holds) and a tap hands `onOpen` the part of the page that
/// says more. A to-do is ticked off right on its tile. The page's `widgets` setting picks the tiles
/// (`PageWidgetItem.items(for:store:workoutStore:)`); with none to show (a note, a page that turned them off, or one
/// with nothing to say yet) there is no strip at all.
///
/// A tile's box is there from the first frame and its content fades in once the page has finished opening, so the
/// strip costs the opening nothing. When the tiles fit the row they share it; narrower, on an iPhone they scroll
/// sideways and snap to a tile, and on the Mac they wrap into balanced rows.
struct PageWidgetStrip: View {
    let pageID: UUID
    let onOpen: (PageWidgetTarget) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.everPageIsOpening) private var pageIsOpening
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    init(pageID: UUID, onOpen: @escaping (PageWidgetTarget) -> Void) {
        self.pageID = pageID
        self.onOpen = onOpen
    }

    var body: some View {
        let items = store.page(id: pageID).map { PageWidgetItem.items(for: $0, store: store, workoutStore: workoutStore) } ?? []
        if !items.isEmpty {
            row(items)
                .environment(\.pageWidgetRevealed, isRevealed)
                .task(id: pageIsOpening) { reveal() }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Widgets")
        }
    }

    @ViewBuilder
    private func row(_ items: [PageWidgetItem]) -> some View {
        #if os(macOS)
        PageWidgetRowLayout(wraps: true) { sharing(items) }
        #else
        ViewThatFits(in: .horizontal) {
            PageWidgetRowLayout(wraps: false) { sharing(items) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PageWidgetMetrics.spacing) {
                    ForEach(items) { item in
                        tile(item)
                            .frame(width: item.kind.naturalWidth, height: PageWidgetMetrics.tileHeight)
                    }
                }
                .modifier(PageWidgetSnapTargets())
            }
            .frame(height: PageWidgetMetrics.tileHeight)
            .modifier(PageWidgetSnapping())
        }
        #endif
    }

    /// The tiles of a row that shares out its width.
    private func sharing(_ items: [PageWidgetItem]) -> some View {
        ForEach(items) { item in
            tile(item)
                .layoutValue(key: PageWidgetNaturalWidth.self, value: item.kind.naturalWidth)
        }
    }

    @ViewBuilder
    private func tile(_ item: PageWidgetItem) -> some View {
        switch item {
        case .clips(let clips):
            PageWidgetClipsTile(clips: clips, onOpen: onOpen)
        case .folder(let folder):
            PageWidgetFolderTile(folder: folder, onOpen: onOpen)
        case .progress(let progress, let target):
            PageWidgetProgressTile(progress: progress, target: target, onOpen: onOpen)
        case .todos(let todos):
            PageWidgetTodoTile(todos: todos, onOpen: onOpen)
        case .milestones(let pageID, let list):
            PageWidgetMilestonesTile(pageID: pageID, milestones: list, onOpen: onOpen)
        case .learnFirst(let learnFirst):
            PageWidgetLearnFirstTile(learnFirst: learnFirst, onOpen: onOpen)
        case .workouts(let usage):
            PageWidgetWorkoutsTile(usage: usage, onOpen: onOpen)
        }
    }

    /// Content waits for the page to finish opening, so drawing it does not land in the middle of the motion.
    private func reveal() {
        guard !pageIsOpening, !isRevealed else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isRevealed = true }
    }
}
