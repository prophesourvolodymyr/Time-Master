import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// The List view of a board: its sub-skills grouped by section (the loose ones first). Every section is a card with a
/// colour strip down its leading edge holding its header, its rows and a quick-add row; sections fold; sub-skills and
/// sections drag to reorder, to move between sections, or to move inside another sub-skill. "Add a section…" closes
/// the list.
struct SkillBoardListView: View {
    let snapshot: SkillBoardSnapshot
    /// Shows only sub-skills with this status (nil = all).
    var statusFilter: SkillStatus?
    let actions: SkillBoardActions
    let onEditSection: (SkillBoardSection) -> Void
    let onDeleteSection: (SkillBoardSection) -> Void
    /// Asks the surrounding scroll view to keep a row visible (quick-add rows move down as items are added).
    var scrollTo: (String) -> Void = { _ in }

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var dragState = SkillBoardDragState()
    @State private var collapsed: Set<String> = []
    @AppStorage(SkillSettings.perGroupKey) private var groupLimit = SkillGroupLimit.standard
    /// Sections whose Expand all was pressed (by lane key), until the page closes.
    @State private var expandedGroups: Set<String> = []
    /// Sections the list has shown, so one that appears later (made anywhere) can be revealed.
    @State private var knownSectionIDs: Set<String> = []
    /// The section that was just made: its card flashes its colour for a moment.
    @State private var highlightedSectionID: String?
    /// The colour the next section gets (not worn by a neighbour); the "Add a section…" row previews it.
    @State private var nextSectionHex = SkillColors.random()

    private var scope: SkillBoardScope { snapshot.scope }

    var body: some View {
        let sectionIDs = snapshot.sections.map(\.id)
        LazyVStack(alignment: .leading, spacing: SkillMetrics.s5) {
            if snapshot.direct.isEmpty && snapshot.sections.isEmpty {
                Text("Break it down. Add the first sub-skill below, then press Return for the next.")
                    .font(TimeMasterFont.body(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            group(snapshot.unsortedLane)
            ForEach(snapshot.sectionLanes) { lane in
                group(lane)
            }
            if !scope.isGroup {
                sectionQuickAdd
            }
        }
        .animation(reduceMotion ? nil : EverMotion.state, value: snapshot.signature)
        .onAppear { knownSectionIDs = Set(sectionIDs) }
        .onChange(of: sectionIDs) { ids in
            noticeSections(ids)
            nextSectionHex = SkillColors.random(avoiding: snapshot.sections.compactMap(\.colorHex))
        }
        .task(id: highlightedSectionID) {
            guard highlightedSectionID != nil else { return }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            highlightedSectionID = nil
        }
        .onDisappear { dragState.reset() }
    }

    /// "Add a section…": the quick-add field dressed as the next, still empty group. Its strip is the colour the new
    /// section will get, and the colour is saved with it so reordering sections later never recolours it.
    private var sectionQuickAdd: some View {
        let hex = nextSectionHex
        return SkillQuickAddRow(
            placeholder: "Add a section…",
            symbol: "rectangle.stack.badge.plus",
            tintHex: hex,
            showsStrip: true
        ) { title in
            let added = SkillErrorCenter.shared.attempt("Add the section") {
                try store.addSkillGroup(to: scope.containerID, title: title, colorHex: hex)
            }
            if added { EverHaptic.success() }
            return added
        }
        .id("quick-sections")
    }

    // MARK: Groups

    private func group(_ lane: SkillBoardLane) -> some View {
        let key = lane.key
        let sectionID = lane.sectionID
        let items = snapshot.direct(inLane: key).filter { statusFilter == nil || $0.status == statusFilter }
        let isCollapsed = collapsed.contains(key)
        let hasHeader = lane.section != nil || snapshot.hasSections
        let isDropTarget = dropLands(in: sectionID, items: items)
        let isExpanded = expandedGroups.contains(key)
        let visible = SkillGroupLimit.split(items, limit: groupLimit, expanded: isExpanded)
        let stack = VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            if let section = lane.section {
                sectionHeader(section, lane: lane, count: items.count, isCollapsed: isCollapsed)
            } else if hasHeader {
                unsortedHeader(count: items.count, isCollapsed: isCollapsed, key: key)
            }
            if !isCollapsed {
                VStack(spacing: SkillMetrics.s3) {
                    ForEach(visible.shown) { item in
                        row(item)
                    }
                    if SkillGroupLimit.isCapped(count: items.count, limit: groupLimit) {
                        SkillGroupMoreButton(hidden: visible.hidden, isExpanded: isExpanded, tintHex: lane.colorHex) {
                            toggleExpanded(key)
                        }
                    }
                    quickAdd(lane, isDropTarget: isDropTarget)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        return grouped(
            stack,
            hasHeader: hasHeader,
            lane: lane,
            isDropTarget: isDropTarget,
            isHighlighted: sectionID != nil && sectionID == highlightedSectionID
        )
        .id("section-\(key)")
        .onDrop(
            of: [UTType.plainText],
            delegate: SkillGroupDropDelegate(sectionID: sectionID, acceptsSections: false, state: dragState, onDrop: perform)
        )
    }

    @ViewBuilder
    private func grouped<Content: View>(
        _ content: Content,
        hasHeader: Bool,
        lane: SkillBoardLane,
        isDropTarget: Bool,
        isHighlighted: Bool
    ) -> some View {
        if hasHeader {
            content.skillSectionGroup(
                colorHex: lane.colorHex,
                stripImageURL: lane.imageURL,
                isDropTarget: isDropTarget,
                isHighlighted: isHighlighted
            )
        } else {
            content
        }
    }

    /// Whether a drop would land in this group right now: the pointer is over the group itself, or beside one of its
    /// rows (the middle of a row moves inside that row instead).
    private func dropLands(in sectionID: String?, items: [SkillBoardItem]) -> Bool {
        switch dragState.hover {
        case .group(let hovered)?:
            return hovered == sectionID
        case .row(let rowID, let zone)?:
            return zone != .into && items.contains { $0.id == rowID }
        case nil:
            return false
        }
    }

    private func sectionHeader(_ section: SkillBoardSection, lane: SkillBoardLane, count: Int, isCollapsed: Bool) -> some View {
        SkillBoardSectionHeader(
            title: section.title,
            iconName: section.icon,
            iconType: section.iconType,
            colorHex: lane.colorHex,
            count: count,
            isCollapsed: isCollapsed,
            showsMenu: true,
            onToggle: { toggle(lane.key) },
            onOpen: { openGroup(section) },
            menu: { sectionMenu(section) }
        )
        .onDrag { dragState.provider(for: .section(section.id)) }
        .onDrop(
            of: [UTType.plainText],
            delegate: SkillGroupDropDelegate(sectionID: section.id, acceptsSections: true, state: dragState, onDrop: perform)
        )
    }

    private func unsortedHeader(count: Int, isCollapsed: Bool, key: String) -> some View {
        SkillBoardSectionHeader(
            title: "Unsorted",
            iconName: "tray",
            iconType: .system,
            colorHex: nil,
            count: count,
            isCollapsed: isCollapsed,
            showsMenu: false,
            onToggle: { toggle(key) },
            menu: { EmptyView() }
        )
    }

    private func quickAdd(_ lane: SkillBoardLane, isDropTarget: Bool) -> some View {
        SkillQuickAddRow(placeholder: "Add a sub-skill…", tintHex: lane.colorHex, isDropTarget: isDropTarget) { title in
            let added = SkillErrorCenter.shared.attempt("Add the sub-skill") {
                try store.createBoardSkill(
                    title: title,
                    on: scope.boardID,
                    sectionID: scope.isGroup ? nil : lane.sectionID,
                    status: statusFilter ?? .notStarted
                )
            }
            if added {
                EverHaptic.selection()
                expandedGroups.insert(lane.key)
                reveal("quick-\(lane.key)")
            }
            return added
        }
        .id("quick-\(lane.key)")
    }

    // MARK: Rows

    private func row(_ item: SkillBoardItem) -> some View {
        SkillBoardRow(
            item: item,
            tintHex: SkillBoardScreen.accentHex,
            hoverZone: dragState.zone(forRow: item.id),
            state: dragState,
            actions: actions,
            moveTargets: snapshot.moveTargets,
            onDrop: perform
        )
    }

    @ViewBuilder
    private func sectionMenu(_ section: SkillBoardSection) -> some View {
        let ids = snapshot.sections.map(\.id)
        let index = ids.firstIndex(of: section.id) ?? 0
        Button {
            openGroup(section)
        } label: {
            Label("Open as page", systemImage: "arrow.up.forward.square")
        }
        Button {
            onEditSection(section)
        } label: {
            Label("Edit section…", systemImage: "pencil")
        }
        Button {
            moveSection(section.id, by: -1, in: ids)
        } label: {
            Label("Move up", systemImage: "arrow.up")
        }
        .disabled(index == 0)
        Button {
            moveSection(section.id, by: 1, in: ids)
        } label: {
            Label("Move down", systemImage: "arrow.down")
        }
        .disabled(index >= ids.count - 1)
        Divider()
        Button(role: .destructive) {
            onDeleteSection(section)
        } label: {
            Label("Delete section…", systemImage: "trash")
        }
    }

    // MARK: Actions

    private func openGroup(_ section: SkillBoardSection) {
        navigationState.open(skillID: SkillGroupID.make(containerID: scope.containerID, sectionID: section.id))
    }

    private func toggle(_ key: String) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if collapsed.contains(key) {
                collapsed.remove(key)
            } else {
                collapsed.insert(key)
            }
        }
    }

    private func toggleExpanded(_ key: String) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if expandedGroups.contains(key) {
                expandedGroups.remove(key)
            } else {
                expandedGroups.insert(key)
            }
        }
    }

    /// A section that appeared (made here, in the sheet, or by another device): flash it and scroll to it.
    private func noticeSections(_ ids: [String]) {
        let added = ids.filter { !knownSectionIDs.contains($0) }
        knownSectionIDs = Set(ids)
        guard let newest = added.last else { return }
        highlightedSectionID = newest
        reveal("section-\(newest)")
    }

    /// Scrolls to `id` once SwiftUI has laid out what was just added (the very next run-loop turn is too early).
    private func reveal(_ id: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { scrollTo(id) }
    }

    private func moveSection(_ id: String, by offset: Int, in ids: [String]) {
        let next = SkillOrdering.shifted(id, by: offset, in: ids)
        guard next != ids else { return }
        if SkillErrorCenter.shared.attempt("Move the section", { try store.reorderSkillGroups(containerID: scope.containerID, ids: next) }) {
            EverHaptic.selection()
        }
    }

    // MARK: Drops

    private func perform(_ drag: SkillBoardDrag, _ placement: SkillBoardDropPlacement) {
        let done = SkillErrorCenter.shared.attempt("Move it") {
            switch (drag, placement) {
            case let (.page(id), .beside(targetID, after)):
                guard id != targetID, let target = snapshot.itemsByID[targetID] else { return }
                let section = scope.storedSectionID(forLane: target.laneKey == SkillBoardLane.unsortedKey ? nil : target.laneKey)
                try store.placeSkillPage(id, beside: targetID, after: after, sectionID: section)
            case let (.page(id), .into(targetID)):
                guard id != targetID else { return }
                try store.moveSkillPage(id, into: targetID)
            case let (.page(id), .endOfGroup(sectionID)):
                try store.placeSkillPage(id, sectionID: .some(scope.storedSectionID(forLane: sectionID)))
            case let (.section(id), .beforeSection(targetID)):
                let ids = snapshot.sections.map(\.id)
                let next = SkillOrdering.moving(id, beside: targetID, after: false, in: ids)
                if next != ids { try store.reorderSkillGroups(containerID: scope.containerID, ids: next) }
            default:
                break
            }
        }
        if done { EverHaptic.selection() }
    }
}
