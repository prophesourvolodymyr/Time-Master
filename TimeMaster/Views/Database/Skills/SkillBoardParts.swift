import SwiftUI
import TimeMasterCore

// MARK: - Scope

/// Which board a screen shows: a page's own board, or a group opened as a page (`SkillGroupID`).
struct SkillBoardScope: Equatable {
    /// The page id, or the group id.
    let boardID: String
    /// The page whose children the board shows: the board page itself, or the page that holds the group.
    let containerID: String
    /// The group the board is; nil on a page's own board.
    let groupSectionID: String?

    init(boardID: String) {
        self.boardID = boardID
        if let owner = SkillGroupID.split(boardID) {
            containerID = owner.containerID
            groupSectionID = owner.sectionID
        } else {
            containerID = boardID
            groupSectionID = nil
        }
    }

    var isGroup: Bool { groupSectionID != nil }

    /// The group a page is stored in for a lane: the lane's section, or on a group's page the group itself.
    func storedSectionID(forLane sectionID: String?) -> String? { sectionID ?? groupSectionID }
}

// MARK: - Lanes and items

/// One group of a board: the skills outside every group (on a group's page, the group's own skills), or a section.
struct SkillBoardLane: Identifiable, Equatable {
    static let unsortedKey = "unsorted"

    let key: String
    let section: SkillBoardSection?
    /// Position among the lanes: 0 for the loose skills, then the sections in order.
    let index: Int
    /// Strip colour (`RRGGBB`): the section's own, else its palette colour; nil for the loose skills.
    let colorHex: String?
    /// The picture inside the strip.
    let imageURL: URL?

    var id: String { key }
    var sectionID: String? { section?.id }
    var title: String { section?.title ?? "Unsorted" }

    /// An SF Symbol for menus (an emoji icon falls back to the grid).
    var symbolName: String {
        guard let section else { return "tray" }
        if section.iconType == .system, let icon = section.icon, !icon.isEmpty { return icon }
        return "square.grid.2x2"
    }
}

/// How the sub-skills below a page stand: skill and tutorial pages at any depth (through plain folders too), the page
/// itself left out. `total` leaves abandoned ones out, as the skill cards of the library count.
struct SkillBoardTally: Equatable {
    var completed = 0
    var learning = 0
    var total = 0
    var abandoned = 0

    var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    mutating func count(_ status: SkillStatus) {
        switch status {
        case .completed:
            completed += 1
            total += 1
        case .learning:
            learning += 1
            total += 1
        case .notStarted:
            total += 1
        case .abandoned:
            abandoned += 1
        }
    }
}

/// One sub-skill as the board, the table and the list draw it (or, on a folder's type board, one exercise or note; see
/// `PageTypeBoardSnapshot`), resolved once per render: its lane, place, type, counts and links.
struct SkillBoardItem: Identifiable {
    let page: ExercisePage
    let laneKey: String
    let laneIndex: Int
    let sectionTitle: String?
    let sectionColorHex: String?
    /// "Basics › Scales" for sub-skills nested below the board's own; empty for direct ones.
    let path: String
    /// A direct sub-skill of the board (the only ones whose section can change from it).
    let isDirect: Bool
    let type: SkillType?
    /// Its own sub-skills, in their board order.
    let children: [ExercisePage]
    let progress: SkillBoardTally
    /// Note pages inside it, plus its own notes when it has any.
    let noteCount: Int
    /// What it waits for: pages and groups to learn first, prerequisite files and links.
    let dependencyCount: Int
    let links: [SkillCardLink]

    var id: String { page.manifest.id }
    var title: String { page.title }
    var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }
    var mediaCount: Int { page.mediaURLs.count }
    var linkCount: Int { page.manifest.linkURLs.count }

    /// "Title, In progress, 3 of 8 done, 2 files, 1 link" for VoiceOver.
    var spokenSummary: String {
        var parts = [title, status.title]
        if progress.total > 0 { parts.append("\(progress.completed) of \(progress.total) done") }
        if mediaCount > 0 { parts.append(mediaCount == 1 ? "1 file" : "\(mediaCount) files") }
        if linkCount > 0 { parts.append(linkCount == 1 ? "1 link" : "\(linkCount) links") }
        if noteCount > 0 { parts.append(noteCount == 1 ? "1 note" : "\(noteCount) notes") }
        return parts.joined(separator: ", ")
    }
}

/// Everything one render of a board needs, read from the library once: pages are found through one index instead of
/// a scan of the library per row. A page that needs no skills is no sub-skill (`SkillLibrary.isSkill`): it stays off
/// the board, its counts and its tallies, and lists with the parent's exercises and notes instead.
struct SkillBoardSnapshot {
    let scope: SkillBoardScope
    let container: ExercisePage?
    /// The board page's sections in order; empty on a group's page.
    let sections: [SkillBoardSection]
    /// The loose skills first, then one lane per section.
    let lanes: [SkillBoardLane]
    /// The board's own sub-skills per lane key, in display order (type rules applied).
    let directItems: [String: [SkillBoardItem]]
    /// The board's own sub-skills lane by lane, each followed by the sub-skills below it when built with
    /// `includesNested` (Board and Table show every depth).
    let items: [SkillBoardItem]
    let itemsByID: [String: SkillBoardItem]

    init(store: DatabaseStore, boardID: String, includesNested: Bool) {
        let scope = SkillBoardScope(boardID: boardID)
        var lookup: [String: ExercisePage] = [:]
        lookup.reserveCapacity(store.allPagesFlat.count)
        for page in store.allPagesFlat where lookup[page.manifest.id] == nil {
            lookup[page.manifest.id] = page
        }
        let index = lookup
        let container = index[scope.containerID]
        let allSections = container?.manifest.orderedSkillBoardSections ?? []
        let known = Set(allSections.map(\.id))
        let sections = scope.isGroup ? [] : allSections

        func children(of page: ExercisePage) -> [ExercisePage] {
            page.manifest.childIDs.compactMap { index[$0] }
        }

        func storedSection(of page: ExercisePage) -> String? {
            page.manifest.skillBoardSectionID.flatMap { known.contains($0) ? $0 : nil }
        }

        func tally(below page: ExercisePage) -> SkillBoardTally {
            var result = SkillBoardTally()
            var visited: Set<String> = [page.manifest.id]
            var pending = children(of: page)
            while let next = pending.popLast() {
                guard visited.insert(next.manifest.id).inserted else { continue }
                if next.isSkillLike {
                    guard SkillLibrary.isSkill(next) else { continue }
                    result.count(next.manifest.skillStatus ?? .notStarted)
                    pending.append(contentsOf: children(of: next))
                } else if next.pageType == nil && next.isContainer {
                    pending.append(contentsOf: children(of: next))
                }
            }
            return result
        }

        func dependencyCount(of page: ExercisePage) -> Int {
            let manifest = page.manifest
            var count = manifest.dependencyPageIDs.filter { id in
                if let owner = SkillGroupID.split(id) {
                    return index[owner.containerID]?.manifest.skillBoardSection(owner.sectionID) != nil
                }
                return index[id] != nil
            }.count
            if !manifest.dependencyMediaFilenames.isEmpty {
                let media = Set(manifest.dependencyMediaFilenames)
                count += page.mediaURLs.filter { media.contains($0.lastPathComponent) }.count
            }
            if !manifest.dependencyLinkURLs.isEmpty {
                let links = Set(manifest.dependencyLinkURLs)
                count += manifest.linkURLs.filter { links.contains($0) }.count
            }
            return count
        }

        /// A skill board's pages (at any depth) share the types of its skill tree, read once; a plain folder's skills
        /// each own their types, asked page by page (only pages that wear one).
        let boardTypes: [String: SkillType]? = container?.isSkillLike == true ? store.skillTypesByID(for: boardID) : nil

        func wornType(_ page: ExercisePage) -> SkillType? {
            guard let typeID = page.manifest.typeID else { return nil }
            if let boardTypes { return boardTypes[typeID] }
            return store.skillType(of: page)
        }

        /// The type sort rules applied (top types first, bottom types last), as `orderedByTypeRules` does.
        func ordered(_ pages: [ExercisePage]) -> [ExercisePage] {
            var worn: [String: SkillType] = [:]
            for page in pages {
                if let found = wornType(page) { worn[found.id] = found }
            }
            return SkillTypeOrdering.ordered(pages, types: worn) { $0.manifest.typeID }
        }

        func makeItem(_ page: ExercisePage, lane: SkillBoardLane, path: [String], isDirect: Bool) -> SkillBoardItem {
            let inside = children(of: page)
            return SkillBoardItem(
                page: page,
                laneKey: lane.key,
                laneIndex: lane.index,
                sectionTitle: lane.section?.title,
                sectionColorHex: lane.colorHex,
                path: path.joined(separator: " › "),
                isDirect: isDirect,
                type: wornType(page),
                children: DatabaseStore.boardOrdered(inside.filter(SkillLibrary.isSkill)),
                progress: tally(below: page),
                noteCount: inside.filter(\.isNote).count + (page.hasMarkdown ? 1 : 0),
                dependencyCount: dependencyCount(of: page),
                links: SkillCardLink.openable(in: page.manifest)
            )
        }

        var lanes = [SkillBoardLane(key: SkillBoardLane.unsortedKey, section: nil, index: 0, colorHex: nil, imageURL: nil)]
        for (offset, section) in sections.enumerated() {
            lanes.append(SkillBoardLane(
                key: section.id,
                section: section,
                index: offset + 1,
                colorHex: SkillSectionPalette.resolvedHex(for: section, index: offset),
                imageURL: container.flatMap { store.skillGroupImageURL(container: $0, section: section) }
            ))
        }

        let skillChildren = container.map { children(of: $0).filter(SkillLibrary.isSkill) } ?? []
        var directItems: [String: [SkillBoardItem]] = [:]
        var items: [SkillBoardItem] = []
        var placed: Set<String> = [scope.containerID]

        func appendNested(below page: ExercisePage, lane: SkillBoardLane, path: [String]) {
            for child in DatabaseStore.boardOrdered(children(of: page).filter(SkillLibrary.isSkill))
            where placed.insert(child.manifest.id).inserted {
                items.append(makeItem(child, lane: lane, path: path, isDirect: false))
                appendNested(below: child, lane: lane, path: path + [child.title])
            }
        }

        for lane in lanes {
            let stored = lane.section?.id ?? scope.groupSectionID
            let pages = ordered(DatabaseStore.boardOrdered(skillChildren.filter { storedSection(of: $0) == stored }))
            var laneItems: [SkillBoardItem] = []
            for page in pages where placed.insert(page.manifest.id).inserted {
                let item = makeItem(page, lane: lane, path: [], isDirect: true)
                laneItems.append(item)
                items.append(item)
                if includesNested { appendNested(below: page, lane: lane, path: [page.title]) }
            }
            directItems[lane.key] = laneItems
        }

        self.scope = scope
        self.container = container
        self.sections = sections
        self.lanes = lanes
        self.directItems = directItems
        self.items = items
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var unsortedLane: SkillBoardLane { lanes[0] }
    var sectionLanes: [SkillBoardLane] { Array(lanes.dropFirst()) }
    var hasSections: Bool { !sections.isEmpty }

    /// The board's own sub-skills, lane by lane.
    var direct: [SkillBoardItem] { lanes.flatMap { directItems[$0.key] ?? [] } }

    func direct(inLane key: String) -> [SkillBoardItem] { directItems[key] ?? [] }

    /// Sections that hold at least one sub-skill.
    var sectionsWithPages: Int { sectionLanes.filter { !direct(inLane: $0.key).isEmpty }.count }

    /// Where a menu can move a sub-skill: outside every group, then each group (nothing without groups).
    var moveTargets: [SkillBoardLane] { hasSections ? lanes : [] }

    /// The swimlanes of the status board: the loose skills when there are any, then every section.
    var boardLanes: [SkillBoardLane] {
        lanes.filter { $0.section != nil || !direct(inLane: $0.key).isEmpty || sections.isEmpty }
    }

    /// Every item of a lane (all items for nil).
    func items(inLane key: String?) -> [SkillBoardItem] {
        guard let key else { return items }
        return items.filter { $0.laneKey == key }
    }

    /// Ids, places, statuses and titles of every item: what the board animates when the library moves something.
    var signature: [String] {
        items.map { "\($0.id)|\($0.laneKey)|\($0.status.rawValue)|\($0.title)" }
    }

    /// Items per status, all four keys present.
    static func counts(of items: [SkillBoardItem]) -> [SkillStatus: Int] {
        var counts: [SkillStatus: Int] = [:]
        for status in SkillStatus.boardOrder { counts[status] = 0 }
        for item in items { counts[item.status, default: 0] += 1 }
        return counts
    }
}

// MARK: - Actions

/// What rows, cards and table rows ask the board screen to do; the screen owns the store calls, sheets and dialogs.
struct SkillBoardActions {
    var open: (ExercisePage) -> Void
    var openFromCover: (ExercisePage) -> Void
    var setStatus: (ExercisePage, SkillStatus) -> Void
    var changeIcon: (ExercisePage) -> Void
    var edit: (ExercisePage) -> Void
    /// "Move to…": another page of the library.
    var moveTo: (ExercisePage) -> Void
    /// Another section of this board (`nil` = outside every group).
    var moveToSection: (ExercisePage, String?) -> Void
    var requestDelete: (ExercisePage) -> Void
    var openLink: (URL) -> Void
}

// MARK: - Links on cards

/// One link of a page as a card chip shows it: a short label (its own title, else its host) and the address it opens.
/// Only http(s) addresses with a host qualify.
struct SkillCardLink: Identifiable, Equatable {
    /// A card with more links than this also offers a menu that lists them all.
    static let menuAfter = 2
    static let chipLabelLimit = 28
    static let menuLabelLimit = 40

    let url: URL
    let label: String

    var id: String { url.absoluteString }

    init?(address: String, title: String?) {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let rawHost = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host, !rawHost.isEmpty
        else { return nil }
        self.url = url
        label = Self.chipLabel(title: title, url: url, host: Self.displayHost(rawHost))
    }

    var chipTitle: String { Self.truncated(label, limit: Self.chipLabelLimit) }
    var menuTitle: String { Self.truncated(label, limit: Self.menuLabelLimit) }

    /// Every openable link of a page, in order, each once.
    static func openable(in manifest: ExercisePageManifest) -> [SkillCardLink] {
        guard !manifest.linkURLs.isEmpty else { return [] }
        var seen = Set<String>()
        return manifest.linkURLs.compactMap { address in
            guard seen.insert(address).inserted else { return nil }
            return SkillCardLink(address: address, title: manifest.linkMetadata.first { $0.url == address }?.title)
        }
    }

    static func offersMenu(_ links: [SkillCardLink]) -> Bool { links.count > menuAfter }

    /// "WWW.YouTube.com" becomes "youtube.com".
    static func displayHost(_ host: String) -> String {
        let lowered = host.lowercased()
        guard lowered.hasPrefix("www."), lowered.count > 4 else { return lowered }
        return String(lowered.dropFirst(4))
    }

    static func truncated(_ text: String, limit: Int) -> String {
        guard limit > 1, text.count > limit else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The title when it says more than the address does, on one line; the host otherwise.
    private static func chipLabel(title: String?, url: URL, host: String) -> String {
        guard let title else { return host }
        let text = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty else { return host }
        let bare = bareAddress(text)
        return bare == host || bare == bareAddress(url.absoluteString) ? host : text
    }

    private static func bareAddress(_ text: String) -> String {
        var value = text.lowercased()
        if value.hasPrefix("https://") {
            value.removeFirst(8)
        } else if value.hasPrefix("http://") {
            value.removeFirst(7)
        }
        if value.hasPrefix("www.") { value.removeFirst(4) }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }
}

// MARK: - Context menu

/// The context menu of a sub-skill: open, change icon, links and sub-skills (cards), status, type, edit, move, delete.
struct SkillPageMenuItems: View {
    let item: SkillBoardItem
    let actions: SkillBoardActions
    let moveTargets: [SkillBoardLane]
    /// Status as one submenu (cards, table) instead of a button per status (list rows).
    var statusAsMenu = false
    /// Adds the card's links and its sub-skills.
    var showsContents = false
    @Binding var typeEditor: SkillTypeEditorRoute?
    @Binding var showingTypeManager: Bool

    private static let inlineMenuLinks = 3

    var body: some View {
        openItems
        Divider()
        statusItems
        Divider()
        moveItems
        Divider()
        Button(role: .destructive) {
            actions.requestDelete(item.page)
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var openItems: some View {
        Button {
            actions.open(item.page)
        } label: {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        Button {
            actions.changeIcon(item.page)
        } label: {
            Label("Change icon…", systemImage: "face.smiling")
        }
        if showsContents {
            linkItems
            if !item.children.isEmpty {
                Menu {
                    ForEach(item.children, id: \.manifest.id) { child in
                        Button {
                            actions.open(child)
                        } label: {
                            Label(child.title, systemImage: "arrow.turn.down.right")
                        }
                    }
                } label: {
                    Label("Sub-skills", systemImage: "arrow.turn.down.right")
                }
            }
        }
    }

    @ViewBuilder
    private var statusItems: some View {
        if statusAsMenu {
            SkillStatusMenu(status: item.status, onChange: { actions.setStatus(item.page, $0) }) {
                Label("Status", systemImage: "flag")
            }
        } else {
            SkillStatusQuickActions(status: item.status) { actions.setStatus(item.page, $0) }
        }
        Menu {
            SkillTypeMenuItems(pageID: item.id, editor: $typeEditor, showingManager: $showingTypeManager)
        } label: {
            Label("Type", systemImage: "tag")
        }
    }

    @ViewBuilder
    private var moveItems: some View {
        Button {
            actions.edit(item.page)
        } label: {
            Label("Edit…", systemImage: "pencil")
        }
        if item.isDirect, !moveTargets.isEmpty {
            Menu {
                ForEach(moveTargets) { lane in
                    Button {
                        actions.moveToSection(item.page, lane.sectionID)
                    } label: {
                        Label(lane.title, systemImage: lane.key == item.laneKey ? "checkmark" : lane.symbolName)
                    }
                }
            } label: {
                Label("Move to section", systemImage: "rectangle.stack")
            }
        }
        Button {
            actions.moveTo(item.page)
        } label: {
            Label("Move to…", systemImage: "arrow.turn.up.right")
        }
    }

    /// An "Open link" entry per link; one submenu once the page holds more than a few.
    @ViewBuilder
    private var linkItems: some View {
        if item.links.count > Self.inlineMenuLinks {
            Menu {
                ForEach(item.links) { link in
                    Button {
                        actions.openLink(link.url)
                    } label: {
                        Label(link.menuTitle, systemImage: "link")
                    }
                }
            } label: {
                Label("Open link", systemImage: "link")
            }
        } else {
            ForEach(item.links) { link in
                Button {
                    actions.openLink(link.url)
                } label: {
                    Label("Open link · \(link.menuTitle)", systemImage: "link")
                }
            }
        }
    }
}

// MARK: - Quick add

/// "Sub-skill" and "Section" as small buttons in the corner that open into the quick-add field: Return adds and keeps the
/// field focused, so ten sub-skills take ten seconds, and the field closes again once it is left empty. The same row
/// adds sections (with a strip in the colour the new section will wear).
struct SkillQuickAddRow: View {
    let placeholder: String
    /// Leading glyph: a plus unless the row adds something other than a sub-skill.
    var symbol = "plus"
    /// Colour (`RRGGBB`) of the glyph, the outline and the Return button; nil = Tmax orange.
    var tintHex: String?
    /// Draws a colour strip on the leading edge: the row stands in for a section that does not exist yet.
    var showsStrip = false
    var isDropTarget = false
    /// Receives the trimmed text. True when it was taken (the field clears); false keeps the text to fix it.
    let onAdd: (String) -> Bool

    @State private var text = ""
    @State private var isOpen = false
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var shortTitle: String {
        let name = placeholder.replacingOccurrences(of: "Add a ", with: "").replacingOccurrences(of: "…", with: "")
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    var body: some View {
        Group {
            if isOpen || focused || !trimmed.isEmpty {
                field
            } else {
                cornerButton
            }
        }
        .onChange(of: focused) { isFocused in
            if !isFocused && trimmed.isEmpty { isOpen = false }
        }
    }

    private func open() {
        isOpen = true
        DispatchQueue.main.async { focused = true }
    }

    private var cornerButton: some View {
        let tint = tintHex.map { Color(hex: $0) } ?? Theme.toolbarOrange
        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(action: open) {
                HStack(spacing: SkillMetrics.s2) {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                    Text(shortTitle)
                        .font(TimeMasterFont.rowTitle())
                }
                .foregroundStyle(isDropTarget ? tint : tint.opacity(0.9))
                .padding(.horizontal, SkillMetrics.s4)
                .frame(minHeight: SkillMetrics.touch)
                .background(Capsule(style: .continuous).fill(tint.opacity(isDropTarget ? 0.2 : 0.08)))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            tint.opacity(isDropTarget ? 0.9 : 0.45),
                            style: StrokeStyle(lineWidth: 1.5, dash: isDropTarget ? [] : [5, 4])
                        )
                        .allowsHitTesting(false)
                }
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(SkillPressButtonStyle())
            .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: SkillMetrics.touch / 2), action: open)
            .accessibilityLabel(placeholder)
        }
    }

    @ViewBuilder
    private var field: some View {
        let tint = tintHex.map { Color(hex: $0) } ?? Theme.toolbarOrange
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        let isActive = focused || isDropTarget
        HStack(spacing: SkillMetrics.s3) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? tint : tint.opacity(0.8))
                .frame(width: 24)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(Theme.textSecondary))
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(16))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .submitLabel(.next)
                .onSubmit(commit)
            if !trimmed.isEmpty {
                Button(action: commit) {
                    Image(systemName: "return")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.background)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(tint))
                        .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Add")
                .help("Add")
            }
        }
        .padding(.leading, showsStrip ? SkillSectionGroupSurface.contentLeading : SkillMetrics.s4)
        .padding(.trailing, trimmed.isEmpty ? SkillMetrics.s4 : SkillMetrics.s1)
        .frame(minHeight: SkillMetrics.touch + SkillMetrics.s2)
        .background(shape.fill(Color.white.opacity(isDropTarget ? 0.08 : 0.03)))
        .overlay {
            shape
                .strokeBorder(
                    tint.opacity(isActive ? 0.9 : 0.45),
                    style: StrokeStyle(lineWidth: isActive ? 2 : 1.5, dash: isActive ? [] : [6, 4])
                )
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            if showsStrip {
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: SkillSectionGroupSurface.stripWidth)
                    .padding(.vertical, SkillMetrics.s3)
                    .padding(.leading, SkillSectionGroupSurface.stripInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius), action: { focused = true })
        .onTapGesture { focused = true }
    }

    private func commit() {
        let title = trimmed
        guard !title.isEmpty, onAdd(title) else { return }
        text = ""
        DispatchQueue.main.async { focused = true }
    }
}

// MARK: - Long groups

/// How many sub-skills one section of the list or one column of the board shows before the rest wait behind
/// "Expand all". 0 means no limit.
enum SkillGroupLimit {
    static let standard = 10

    /// What to draw now and how many were left out.
    static func split<Item>(_ items: [Item], limit: Int, expanded: Bool) -> (shown: [Item], hidden: Int) {
        guard isCapped(count: items.count, limit: limit), !expanded else { return (items, 0) }
        return (Array(items.prefix(limit)), items.count - limit)
    }

    static func isCapped(count: Int, limit: Int) -> Bool {
        limit > 0 && count > limit
    }
}

/// The foot of a capped group: "Expand all" with how many are hidden, and "Show fewer" once they all show.
struct SkillGroupMoreButton: View {
    let hidden: Int
    let isExpanded: Bool
    var tintHex: String?
    /// The words of the collapsed button; a board that reveals a page at a time names the step instead.
    var moreTitle = "Expand all"
    let action: () -> Void

    var body: some View {
        let tint = tintHex.map { Color(hex: $0) } ?? Theme.toolbarOrange
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: SkillMetrics.s2) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(isExpanded ? "Show fewer" : moreTitle)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                if !isExpanded {
                    Text("\(hidden) more")
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SkillMetrics.s4)
            .frame(maxWidth: .infinity, minHeight: SkillMetrics.touch, alignment: .leading)
            .background(shape.fill(Color.white.opacity(0.03)))
            .overlay { shape.strokeBorder(Theme.separator, lineWidth: 1).allowsHitTesting(false) }
            .contentShape(shape)
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel(isExpanded ? "Show fewer" : "\(moreTitle), \(hidden) more")
    }
}

// MARK: - Header controls

/// The corner button of a board: it holds the view switch, the filter chips and "New section", and opens them in place.
/// A dot on it says a status filter is on while the chips are folded away.
struct SkillBoardControlsToggle: View {
    @Binding var isOpen: Bool
    let modeSymbol: String
    let isFiltered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : EverMotion.state) { isOpen.toggle() }
            EverHaptic.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: modeSymbol)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 14, weight: .semibold))
            .overlay(alignment: .topTrailing) {
                if isFiltered {
                    Circle()
                        .fill(Theme.toolbarOrange)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .accessibilityLabel(isOpen ? "Hide board controls" : "Show board controls")
        .accessibilityValue(isFiltered ? "A status filter is on" : "")
        .help(isOpen ? "Hide board controls" : "Show board controls")
    }
}

/// The "New section" call to action: a plus and the words on an orange pill, at least 44 pt tall.
struct SkillNewSectionButton: View {
    var showsTitle = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SkillMetrics.s2) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                if showsTitle {
                    Text("New section")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: true, horizontalPadding: showsTitle ? SkillMetrics.s4 : SkillMetrics.s3))
        .accessibilityLabel("New section")
        .accessibilityHint("Adds a coloured group for your sub-skills")
        .help("New section")
    }
}

/// List · Board · Table (and Tiers on a skill) as a slim track of glyphs, a `TmaxTabBar`; the names show as tooltips and
/// are read by VoiceOver.
struct SkillViewModePicker: View {
    @Binding var selection: SkillBoardMode
    var modes: [SkillBoardMode] = SkillBoardMode.allCases

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TmaxTabBar(
            modes.map { TmaxTab($0, title: $0.title, symbol: $0.symbolName, showsTitle: false, help: $0.helpText) },
            selection: selection,
            fillsWidth: false,
            accessibilityLabel: "View"
        ) { mode in
            select(mode)
        }
        .fixedSize()
        #if os(macOS)
        .background(shortcuts)
        #endif
    }

    private func select(_ mode: SkillBoardMode) {
        guard mode != selection else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            selection = mode
        }
        EverHaptic.selection()
    }

    #if os(macOS)
    private var shortcuts: some View {
        ZStack {
            ForEach(modes) { mode in
                Button("") { select(mode) }
                    .keyboardShortcut(mode.shortcutKey, modifiers: .command)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
    #endif
}

// MARK: - Icons on rows and cards

/// A sub-skill's icon on a row or a card as a button that opens its icon picker. A real `Button`, so it wins over the
/// card's own tap (open the page) and drag; a pencil shows on its corner under the pointer.
struct SkillIconChangeButton: View {
    let page: ExercisePage
    let side: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            SkillPageIconTile(page: page, size: side, tilesSymbols: true)
                .overlay(alignment: .bottomTrailing) {
                    if isHovering { badge }
                }
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(SkillPressButtonStyle())
        .onHover { isHovering = $0 }
        .help("Change icon")
        .accessibilityLabel("Change icon of \(page.title)")
        .accessibilityHint("Opens the icon picker")
    }

    private var badge: some View {
        Image(systemName: "pencil")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Theme.background)
            .frame(width: 16, height: 16)
            .background(Circle().fill(Theme.toolbarOrange))
            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 1.5))
            .offset(x: 3, y: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
