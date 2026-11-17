import SwiftUI
import TimeMasterCore

// MARK: - Choices

/// How a container's tab lays its pages out. Remembered per device, one choice per tab.
enum ContainerBrowseLayout: String, CaseIterable, Identifiable {
    case gallery
    case list
    /// The container's own skill board (groups, statuses, quick add); Skills tab only.
    case board

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gallery: "Gallery"
        case .list: "List"
        case .board: "Board"
        }
    }

    var symbolName: String {
        switch self {
        case .gallery: "square.grid.2x2"
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        }
    }

    static func options(for tab: ContainerChildTab) -> [ContainerBrowseLayout] {
        tab == .skills ? [.gallery, .list, .board] : [.gallery, .list]
    }
}

/// How a container's tab orders its pages. Remembered per device, one choice per tab.
enum ContainerBrowseSort: String, CaseIterable, Identifiable {
    /// The container's own order (the board order for skills); a search puts title matches first.
    case manual
    case name
    /// Latest change to the page or to anything inside it first.
    case recent
    /// Most clips (videos) first, then most stills.
    case clips
    /// Most of its sub-skills done first.
    case progress
    /// Most used in the saved workouts and their finished sessions first (`PageUsageIndex`); never used last.
    case used

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Folder order"
        case .name: "Name"
        case .recent: "Recently changed"
        case .clips: "Most clips"
        case .progress: "Progress"
        case .used: "Most used"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "hand.draw"
        case .name: "textformat"
        case .recent: "clock"
        case .clips: "film"
        case .progress: "chart.bar"
        case .used: "flame"
        }
    }

    static func options(for tab: ContainerChildTab) -> [ContainerBrowseSort] {
        tab == .skills ? [.manual, .name, .recent, .progress, .clips, .used] : [.manual, .name, .recent, .clips, .used]
    }
}

/// How the Skills tab groups its skills. Remembered per device.
enum ContainerSkillGrouping: String, CaseIterable, Identifiable {
    case status
    /// By the container (and board group) each skill sits in.
    case folder
    case flat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .folder: "Folder"
        case .flat: "No groups"
        }
    }

    var systemImage: String {
        switch self {
        case .status: "circle.lefthalf.filled"
        case .folder: "folder"
        case .flat: "square.grid.2x2"
        }
    }

    /// Status groups in order: in progress first, then not started, done and abandoned.
    static let statusOrder: [SkillStatus] = [.learning, .notStarted, .completed, .abandoned]
}

/// UserDefaults keys of the container tabs' choices.
enum ContainerBrowseSettings {
    static let exercisesLayoutKey = "tm.containers.exercises.layout"
    static let skillsLayoutKey = "tm.containers.skills.layout"
    static let exercisesSortKey = "tm.containers.exercises.sort"
    static let skillsSortKey = "tm.containers.skills.sort"
    static let skillGroupingKey = "tm.containers.skills.grouping"
}

/// What a page is, as the container cards name and draw it.
enum ContainerPageKind {
    case container
    case exercise
    case skill
    case tutorial
    case note

    init(_ page: ExercisePage) {
        switch page.pageType {
        case .exercise: self = .exercise
        case .skill: self = .skill
        case .tutorial: self = .tutorial
        case .note: self = .note
        case nil: self = .container
        }
    }

    var title: String {
        switch self {
        case .container: "Container"
        case .exercise: "Exercise"
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case .note: "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .container: "folder.fill"
        case .exercise: "figure.run"
        case .skill: "flag.checkered"
        case .tutorial: "book.closed"
        case .note: "note.text"
        }
    }

    /// The words a search finds the kind by, each also in the plural.
    var searchWords: [String] { self == .container ? ["Container", "Folder"] : [title] }
}

/// A page made from its name alone, from a container's add menu.
enum ContainerNewPageKind {
    case skill
    case note
    case container

    var title: String {
        switch self {
        case .skill: "New Skill"
        case .note: "New Note"
        case .container: "New Container"
        }
    }

    var placeholder: String {
        switch self {
        case .skill: "Skill name"
        case .note: "Note title"
        case .container: "Container name"
        }
    }
}

// MARK: - Entries

/// Why a search showed a page whose title did not match: a line of its notes, a comment, a link, a to-do, its type.
struct ContainerMatchReason: Equatable {
    let text: String
    let systemImage: String
}

/// One page a container's tab shows, with the page tree below it (for container covers and counts), where it sits
/// below the container and why a search showed it.
struct ContainerBrowseEntry: Identifiable {
    let page: ExercisePage
    /// Titles of the pages between the container and this page, outermost first; empty for a direct child.
    let path: [String]
    /// The page holding it: the container itself for a direct child.
    let parentID: String
    /// Its group on the holding page's skill board.
    let boardSection: SkillBoardSection?
    /// Place in the container's order (depth first).
    let position: Int
    /// Whether a search found the query in its title.
    var titleMatches = true
    var match: ContainerMatchReason?

    var id: String { page.manifest.id }
    var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }
    var pathText: String? { path.isEmpty ? nil : path.joined(separator: " › ") }
}

/// A page's media and size as its card shows them: clips (videos) and stills (photos) on it and on everything inside
/// it, how many pages it holds, and the latest change to it or to anything inside it.
struct ContainerPageStats {
    var clips = 0
    var stills = 0
    var pages = 0
    var lastChange = Date.distantPast
}

/// Skills under one header of the Skills tab: a status, or the container (and board group) they sit in.
struct ContainerSkillSection: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let tint: Color
    let entries: [ContainerBrowseEntry]
}

/// Search hits on a container's other tab, and how to show them.
struct ContainerOtherTabHits {
    let tab: ContainerChildTab
    let count: Int
    let show: () -> Void

    var label: String { "\(count == 1 ? "1 match" : "\(count) matches") in \(tab.title)" }
}

// MARK: - Model

/// A container's pages for its tabs, read from the page tree once per screen update: what each tab lists, search
/// across everything inside, orders and groups, and each page's clips, stills, size and latest change.
struct ContainerBrowseModel {
    /// The container, with the whole page tree below it.
    let container: ExercisePage
    private let statsByID: [String: ContainerPageStats]
    /// Titles of the skill types defined inside the container, by type id (type ids are unique).
    private let typeTitles: [String: String]

    init(container: ExercisePage, roots: [ExercisePage], pages: [ExercisePage]) {
        let tree = Self.node(id: container.manifest.id, in: roots) ?? Self.tree(of: container, in: pages)
        var stats: [String: ContainerPageStats] = [:]
        var typeTitles: [String: String] = [:]
        Self.collect(tree, stats: &stats, typeTitles: &typeTitles)
        self.container = tree
        self.statsByID = stats
        self.typeTitles = typeTitles
    }

    /// Whether the container has a Skills tab: a folder flagged `noSkills` lists everything as ordinary pages.
    var showsSkills: Bool { !container.manifest.hidesSkills }

    /// What each tab lists. With no query: the container's own exercises, notes and containers, and every skill or
    /// tutorial in it or in the containers inside it (a page flagged `noSkills` is not a skill: it is listed with the
    /// exercises). With one: every page anywhere inside that holds it.
    func lists(query: String) -> [ContainerChildTab: [ContainerBrowseEntry]] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return [.exercises: ownPages(), .skills: showsSkills ? skills() : []]
        }
        let hits = search(needle)
        guard showsSkills else { return [.exercises: hits, .skills: []] }
        return [
            .exercises: hits.filter { !SkillLibrary.isSkill($0.page) },
            .skills: hits.filter { SkillLibrary.isSkill($0.page) },
        ]
    }

    /// A page's clips, stills, size and latest change (empty for a page outside the container).
    func stats(of page: ExercisePage) -> ContainerPageStats {
        statsByID[page.manifest.id] ?? ContainerPageStats()
    }

    /// `entries` in `sort` order, ties in the container's order; with `relevance`, title matches first. `usage` ranks
    /// the Most used sort.
    func sorted(
        _ entries: [ContainerBrowseEntry],
        by sort: ContainerBrowseSort,
        relevance: Bool,
        progress: [String: SkillProgress],
        usage: PageUsageIndex = .empty
    ) -> [ContainerBrowseEntry] {
        entries.sorted { lhs, rhs in
            if relevance, lhs.titleMatches != rhs.titleMatches { return lhs.titleMatches }
            switch sort {
            case .manual:
                break
            case .name:
                let order = lhs.page.title.localizedStandardCompare(rhs.page.title)
                if order != .orderedSame { return order == .orderedAscending }
            case .recent:
                let left = stats(of: lhs.page).lastChange
                let right = stats(of: rhs.page).lastChange
                if left != right { return left > right }
            case .clips:
                let left = stats(of: lhs.page)
                let right = stats(of: rhs.page)
                if left.clips != right.clips { return left.clips > right.clips }
                if left.stills != right.stills { return left.stills > right.stills }
            case .progress:
                let left = progress[lhs.id]?.fraction ?? 0
                let right = progress[rhs.id]?.fraction ?? 0
                if left != right { return left > right }
            case .used:
                let left = usage.score(of: lhs.page.id)
                let right = usage.score(of: rhs.page.id)
                if left != right { return left > right }
                let order = lhs.page.title.localizedStandardCompare(rhs.page.title)
                if order != .orderedSame { return order == .orderedAscending }
            }
            return lhs.position < rhs.position
        }
    }

    /// `entries` (already in display order) under headers: by status, in progress first; or by the container and board
    /// group they sit in, in the container's order. `.flat` gives one section without a header.
    func sections(of entries: [ContainerBrowseEntry], by grouping: ContainerSkillGrouping) -> [ContainerSkillSection] {
        switch grouping {
        case .flat:
            return [ContainerSkillSection(id: "all", title: "", symbolName: "", tint: Theme.toolbarOrange, entries: entries)]
        case .status:
            return ContainerSkillGrouping.statusOrder.compactMap { status in
                let members = entries.filter { $0.status == status }
                guard !members.isEmpty else { return nil }
                return ContainerSkillSection(
                    id: "status-\(status.rawValue)",
                    title: status.title,
                    symbolName: status.symbolName,
                    tint: status.color,
                    entries: members
                )
            }
        case .folder:
            var keys: [String] = []
            var members: [String: [ContainerBrowseEntry]] = [:]
            var firstPosition: [String: Int] = [:]
            for entry in entries {
                let key = "\(entry.parentID)/\(entry.boardSection?.id ?? "-")"
                if members[key] == nil { keys.append(key) }
                members[key, default: []].append(entry)
                firstPosition[key] = min(firstPosition[key] ?? entry.position, entry.position)
            }
            return keys
                .sorted { (firstPosition[$0] ?? 0) < (firstPosition[$1] ?? 0) }
                .compactMap { key in
                    guard let group = members[key], let sample = group.first else { return nil }
                    return folderSection(id: key, sample: sample, entries: group)
                }
        }
    }

    /// How many of `entries` sit in each status.
    static func statusCounts(_ entries: [ContainerBrowseEntry]) -> [SkillStatus: Int] {
        entries.reduce(into: [:]) { counts, entry in counts[entry.status, default: 0] += 1 }
    }

    // MARK: Lists

    /// The container's own exercises, notes and containers, in its order, with any page flagged `noSkills`; in a
    /// folder flagged `noSkills` every child.
    private func ownPages() -> [ContainerBrowseEntry] {
        container.children.filter { !showsSkills || !SkillLibrary.isSkill($0) }.enumerated().map { index, page in
            ContainerBrowseEntry(page: page, path: [], parentID: container.manifest.id, boardSection: nil, position: index)
        }
    }

    /// Every skill and tutorial in the container and in the containers inside it (not those inside other skills), each
    /// container's in its board order: outside any group first, then group by group.
    private func skills() -> [ContainerBrowseEntry] {
        var result: [ContainerBrowseEntry] = []
        collectSkills(in: container, path: [], into: &result)
        return result
    }

    private func collectSkills(in folder: ExercisePage, path: [String], into result: inout [ContainerBrowseEntry]) {
        let skills = folder.children.filter(SkillLibrary.isSkill)
        let sections = folder.manifest.orderedSkillBoardSections
        let known = Set(sections.map(\.id))
        let sectionID: (ExercisePage) -> String? = { page in
            page.manifest.skillBoardSectionID.flatMap { known.contains($0) ? $0 : nil }
        }
        for page in DatabaseStore.boardOrdered(skills.filter { sectionID($0) == nil }) {
            let position = result.count
            result.append(ContainerBrowseEntry(page: page, path: path, parentID: folder.manifest.id, boardSection: nil, position: position))
        }
        for section in sections {
            for page in DatabaseStore.boardOrdered(skills.filter { sectionID($0) == section.id }) {
                let position = result.count
                result.append(ContainerBrowseEntry(page: page, path: path, parentID: folder.manifest.id, boardSection: section, position: position))
            }
        }
        for child in folder.children where child.isContainer && child.pageType == nil {
            collectSkills(in: child, path: path + [child.title], into: &result)
        }
    }

    // MARK: Search

    /// Every page anywhere inside the container whose title, notes, comments, links, to-dos, milestones, kind or type
    /// holds `needle`, depth first.
    private func search(_ needle: String) -> [ContainerBrowseEntry] {
        var result: [ContainerBrowseEntry] = []
        var position = 0
        func visit(_ parent: ExercisePage, path: [String]) {
            for page in parent.children {
                if let found = match(page, needle: needle) {
                    let section = page.manifest.skillBoardSectionID.flatMap { parent.manifest.skillBoardSection($0) }
                    result.append(ContainerBrowseEntry(
                        page: page,
                        path: path,
                        parentID: parent.manifest.id,
                        boardSection: section,
                        position: position,
                        titleMatches: found.titleMatches,
                        match: found.reason
                    ))
                }
                position += 1
                if !page.children.isEmpty {
                    visit(page, path: path + [page.title])
                }
            }
        }
        visit(container, path: [])
        return result
    }

    /// Nil when `page` does not hold `needle`; else whether its title does and, when not, why it matched. The notes,
    /// comments, links, to-dos and milestones read as on the Skills page; then its kind (the whole word) and its
    /// workout and skill types.
    private func match(_ page: ExercisePage, needle: String) -> (titleMatches: Bool, reason: ContainerMatchReason?)? {
        if Self.contains(page.title, needle) { return (true, nil) }
        if let snippet = SkillSearchSnippet.make(for: page.manifest, query: needle) {
            return (false, ContainerMatchReason(text: snippet.text, systemImage: snippet.systemImage))
        }
        let kind = ContainerPageKind(page)
        if kind.searchWords.contains(where: { Self.equals($0, needle) || Self.equals($0 + "s", needle) }) {
            return (false, ContainerMatchReason(text: kind.title, systemImage: kind.symbolName))
        }
        if let type = page.effectiveWorkoutType, Self.contains(type.name, needle) {
            return (false, ContainerMatchReason(text: type.name, systemImage: "tag"))
        }
        if let id = page.manifest.typeID, let title = typeTitles[id], Self.contains(title, needle) {
            return (false, ContainerMatchReason(text: title, systemImage: "tag"))
        }
        return nil
    }

    private static let matchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static func contains(_ text: String, _ needle: String) -> Bool {
        text.range(of: needle, options: matchOptions) != nil
    }

    private static func equals(_ text: String, _ needle: String) -> Bool {
        text.compare(needle, options: matchOptions) == .orderedSame
    }

    // MARK: Groups

    private func folderSection(id: String, sample: ContainerBrowseEntry, entries: [ContainerBrowseEntry]) -> ContainerSkillSection {
        let place = sample.path.isEmpty ? container.title : sample.path.joined(separator: " › ")
        if let section = sample.boardSection {
            return ContainerSkillSection(
                id: "folder-\(id)",
                title: sample.path.isEmpty ? section.title : "\(place) › \(section.title)",
                symbolName: "square.grid.2x2",
                tint: SkillColors.normalizedHex(section.colorHex).map { Color(hex: $0) } ?? Theme.toolbarOrange,
                entries: entries
            )
        }
        return ContainerSkillSection(
            id: "folder-\(id)",
            title: place,
            symbolName: sample.path.isEmpty ? "tray.full" : "folder.fill",
            tint: Theme.toolbarOrange,
            entries: entries
        )
    }

    // MARK: Tree

    /// Fills `stats` for `page` and everything below it and gathers the skill types defined there; returns `page`'s.
    @discardableResult
    private static func collect(
        _ page: ExercisePage,
        stats: inout [String: ContainerPageStats],
        typeTitles: inout [String: String]
    ) -> ContainerPageStats {
        var total = ContainerPageStats(lastChange: page.manifest.updatedAt)
        for url in page.mediaURLs {
            if PageMediaKind.isVideo(url) {
                total.clips += 1
            } else {
                total.stills += 1
            }
        }
        for preset in page.manifest.typePresets {
            for type in preset.types {
                typeTitles[type.id] = type.title
            }
        }
        for child in page.children {
            let inner = collect(child, stats: &stats, typeTitles: &typeTitles)
            total.clips += inner.clips
            total.stills += inner.stills
            total.pages += 1 + inner.pages
            total.lastChange = max(total.lastChange, inner.lastChange)
        }
        stats[page.manifest.id] = total
        return total
    }

    /// The page with `id` in the page tree.
    private static func node(id: String, in roots: [ExercisePage]) -> ExercisePage? {
        var stack = roots
        while let page = stack.popLast() {
            if page.manifest.id == id { return page }
            stack.append(contentsOf: page.children)
        }
        return nil
    }

    /// `page` with its tree rebuilt from the flat page list, for a page the tree has not caught up with yet.
    private static func tree(of page: ExercisePage, in pages: [ExercisePage]) -> ExercisePage {
        let byID = Dictionary(pages.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
        var visited: Set<String> = []
        func build(_ page: ExercisePage) -> ExercisePage {
            visited.insert(page.manifest.id)
            let children = page.manifest.childIDs.compactMap { id -> ExercisePage? in
                guard !visited.contains(id), let child = byID[id] else { return nil }
                return build(child)
            }
            return ExercisePage(
                manifest: page.manifest,
                children: children,
                coverImageURL: page.coverImageURL,
                mediaURLs: page.mediaURLs,
                path: page.path,
                inheritedWorkoutType: page.inheritedWorkoutType
            )
        }
        return build(byID[page.manifest.id] ?? page)
    }
}
