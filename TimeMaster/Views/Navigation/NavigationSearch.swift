// NavigationSearch.swift
//
// The page wheel's search: the app's pages, workouts and their sections, and every page of the library in one index.
// A query turns the wheel to the page the best match lives on; matches below the wheel's pages come back as a tree
// under that page (Workouts › Week 1 › W1 Mon AM), so the wheel can show where they are and open any level of it.

import Foundation
import TimeMasterCore

/// What the search can open.
enum NavigationSearchTarget: Hashable {
    case page(SlotNavigationDestination)
    case workout(UUID)
    case workoutGroup(UUID)
    /// A library page by manifest id: skills and tutorials open on the Skills page, everything else in the Database.
    case libraryPage(String, destination: SlotNavigationDestination)

    var destination: SlotNavigationDestination {
        switch self {
        case .page(let destination): destination
        case .workout, .workoutGroup: .workouts
        case .libraryPage(_, let destination): destination
        }
    }
}

struct NavigationSearchCrumb: Hashable {
    let id: String
    let title: String
    let symbol: String
    let target: NavigationSearchTarget
}

struct NavigationSearchEntry: Identifiable, Hashable {
    let id: String
    let target: NavigationSearchTarget
    let title: String
    let detail: String
    let symbol: String
    /// The places above the entry inside its page, outermost first (a workout's section, a page's folders).
    let trail: [NavigationSearchCrumb]
    /// Whether the entry can hold more entries (a section of workouts, a folder or skill with pages in it).
    let hasChildren: Bool
    fileprivate let key: String
    fileprivate let aliasKeys: [String]
    fileprivate let contextKey: String
    fileprivate let weight: Double

    init(
        id: String, target: NavigationSearchTarget, title: String, detail: String, symbol: String,
        trail: [NavigationSearchCrumb] = [], hasChildren: Bool = false, aliases: [String] = [], weight: Double = 1
    ) {
        self.id = id
        self.target = target
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.trail = trail
        self.hasChildren = hasChildren
        self.weight = weight
        key = NavigationSearchIndex.normalize(title)
        aliasKeys = aliases.map(NavigationSearchIndex.normalize)
        let trailKey = NavigationSearchIndex.normalize(trail.map(\.title).joined(separator: " "))
        contextKey = trailKey.isEmpty ? "" : trailKey + " " + key
    }

    var destination: SlotNavigationDestination { target.destination }
    var isPage: Bool {
        if case .page = target { return true }
        return false
    }
}

struct NavigationSearchHit: Hashable {
    let entry: NavigationSearchEntry
    let score: Double
}

/// One row of the result tree: a wheel page at the root, then the places inside it, then the matches.
struct NavigationSearchNode: Identifiable, Hashable {
    let id: String
    let title: String
    var detail: String
    let symbol: String
    let target: NavigationSearchTarget
    var isMatch: Bool
    var canExpand: Bool
    var children: [NavigationSearchNode]
}

/// The picture that goes with a result and the symbol kept under it until the picture has loaded.
struct NavigationSearchCover {
    let url: URL
    let symbol: String
}

struct NavigationSearchResults: Equatable {
    var query = ""
    var hits: [NavigationSearchHit] = []
    var tree: [NavigationSearchNode] = []

    static let empty = NavigationSearchResults()

    var isEmpty: Bool { hits.isEmpty }
    /// The wheel page to turn to: the page itself when one matches best, else the page the best match lives on.
    var destination: SlotNavigationDestination? { hits.first?.entry.destination }
    /// The best match, which Return opens.
    var best: NavigationSearchEntry? { hits.first?.entry }
}

struct NavigationSearchIndex {
    let entries: [NavigationSearchEntry]
    static let treeLimit = 8
    /// The letter-by-letter fuzzy pass is the slow one; it only runs when fewer plain matches than this were found.
    static let fuzzyBelow = 6

    init(entries: [NavigationSearchEntry]) {
        self.entries = entries
    }

    func search(_ query: String, limit: Int = 30) -> NavigationSearchResults {
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty else { return NavigationSearchResults(query: query) }
        let tokens = normalized.split(separator: " ").map(String.init)
        var hits: [NavigationSearchHit] = []
        hits.reserveCapacity(64)
        var unmatched: [Int] = []
        unmatched.reserveCapacity(entries.count)
        for (position, entry) in entries.enumerated() {
            guard let score = Self.score(normalized, tokens: tokens, entry: entry, fuzzy: false) else {
                unmatched.append(position)
                continue
            }
            hits.append(NavigationSearchHit(entry: entry, score: score))
        }
        if hits.count < Self.fuzzyBelow, normalized.count >= 3 {
            for position in unmatched {
                let entry = entries[position]
                guard let score = Self.score(normalized, tokens: tokens, entry: entry, fuzzy: true) else { continue }
                hits.append(NavigationSearchHit(entry: entry, score: score))
            }
        }
        hits.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.entry.title.count != rhs.entry.title.count { return lhs.entry.title.count < rhs.entry.title.count }
            return lhs.entry.id < rhs.entry.id
        }
        if hits.count > limit { hits.removeSubrange(limit...) }
        return NavigationSearchResults(query: query, hits: hits, tree: Self.tree(for: hits))
    }

    // MARK: Scoring

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var result = ""
        result.reserveCapacity(folded.count)
        var pendingSpace = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingSpace, !result.isEmpty { result.append(" ") }
                pendingSpace = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingSpace = true
            }
        }
        return result
    }

    /// How well `query` (normalized, split into `tokens`) names `key`, from 1 for the exact name down; nil when it does
    /// not name it at all.
    static func score(_ query: String, tokens: [String], in key: String, fuzzy: Bool = true) -> Double? {
        guard !query.isEmpty, !key.isEmpty else { return nil }
        if key == query { return 1 }
        if key.hasPrefix(query) {
            return 0.9 - min(0.12, Double(key.count - query.count) * 0.003)
        }
        if key.contains(" " + query) { return 0.78 }
        if tokens.count > 1, tokens.allSatisfy({ key.hasPrefix($0) || key.contains(" " + $0) }) { return 0.72 }
        if let range = key.range(of: query) {
            let start = key.distance(from: key.startIndex, to: range.lowerBound)
            return 0.6 - min(0.12, Double(start) * 0.008)
        }
        if tokens.count > 1, tokens.allSatisfy({ key.contains($0) }) { return 0.5 }
        guard fuzzy, query.count >= 3, let spread = subsequenceSpread(query, in: key) else { return nil }
        return 0.22 + 0.16 * Double(query.count) / Double(max(spread, query.count))
    }

    /// Characters of `key` spanned by the letters of `query` in order, or nil when they are not all there.
    private static func subsequenceSpread(_ query: String, in key: String) -> Int? {
        let needle = Array(query.replacingOccurrences(of: " ", with: ""))
        guard let first = needle.first else { return nil }
        let haystack = Array(key)
        var best: Int?
        for start in haystack.indices where haystack[start] == first {
            var matched = 1
            var position = start + 1
            while matched < needle.count, position < haystack.count {
                if haystack[position] == needle[matched] { matched += 1 }
                position += 1
            }
            guard matched == needle.count else { break }
            let spread = position - start
            if best.map({ spread < $0 }) ?? true { best = spread }
        }
        return best
    }

    private static func score(_ query: String, tokens: [String], entry: NavigationSearchEntry, fuzzy: Bool) -> Double? {
        var best = score(query, tokens: tokens, in: entry.key, fuzzy: fuzzy)
        for alias in entry.aliasKeys {
            guard let aliasScore = score(query, tokens: tokens, in: alias, fuzzy: fuzzy).map({ $0 * 0.92 }) else { continue }
            best = max(best ?? 0, aliasScore)
        }
        if !entry.contextKey.isEmpty,
           let trail = score(query, tokens: tokens, in: entry.contextKey, fuzzy: false).map({ $0 * 0.45 }) {
            best = max(best ?? 0, trail)
        }
        return best.map { $0 * entry.weight }
    }

    // MARK: Tree

    /// The matches that live below a wheel page, as a tree per page in the order of their best match.
    static func tree(for hits: [NavigationSearchHit]) -> [NavigationSearchNode] {
        var roots: [NavigationSearchNode] = []
        var counted = 0
        for hit in hits where !hit.entry.isPage {
            guard counted < treeLimit else { break }
            counted += 1
            let entry = hit.entry
            let destination = entry.destination
            let rootID = "page:\(destination.rawValue)"
            var rootIndex = roots.firstIndex { $0.id == rootID }
            if rootIndex == nil {
                roots.append(NavigationSearchNode(
                    id: rootID, title: destination.title, detail: "", symbol: destination.searchSymbol,
                    target: .page(destination), isMatch: false, canExpand: false, children: []
                ))
                rootIndex = roots.count - 1
            }
            let path = entry.trail.map { crumb in
                NavigationSearchNode(id: crumb.id, title: crumb.title, detail: "", symbol: crumb.symbol,
                                     target: crumb.target, isMatch: false, canExpand: true, children: [])
            }
            let leaf = NavigationSearchNode(id: entry.id, title: entry.title, detail: entry.detail, symbol: entry.symbol,
                                            target: entry.target, isMatch: true, canExpand: entry.hasChildren, children: [])
            insert(path + [leaf], into: &roots[rootIndex!].children)
        }
        return roots
    }

    private static func insert(_ path: [NavigationSearchNode], into nodes: inout [NavigationSearchNode]) {
        guard let head = path.first else { return }
        if let index = nodes.firstIndex(where: { $0.id == head.id }) {
            if head.isMatch {
                nodes[index].isMatch = true
                nodes[index].detail = head.detail
            }
            insert(Array(path.dropFirst()), into: &nodes[index].children)
        } else {
            var node = head
            insert(Array(path.dropFirst()), into: &node.children)
            nodes.append(node)
        }
    }
}

extension SlotNavigationDestination {
    /// Other words people use for the page.
    var searchAliases: [String] {
        switch self {
        case .home: ["Dashboard", "Today", "Start"]
        case .workouts: ["Training", "Routines", "Builder", "Sessions"]
        case .database: ["Library", "Exercises", "Exercise database", "Pages"]
        case .skills: ["Progressions", "Moves", "Learning"]
        case .analytics: ["Stats", "Statistics", "Charts", "Progress", "Trends"]
        case .coach: ["Coach", "Chat", "Assistant", "AI", "Agent"]
        case .profile: ["Me", "Account", "History"]
        case .ranked: ["Arena", "Elo", "Leaderboard", "Duel"]
        case .physique: ["Physique duels", "Poses", "Body"]
        case .map: ["Outdoor", "Run", "Ride", "Route", "Walk"]
        case .schedule: ["Calendar", "Plan", "Week", "Streak"]
        case .settings: ["Preferences", "Options", "Sync", "Backup", "Music"]
        }
    }

    var searchSymbol: String {
        switch self {
        case .home: "house.fill"
        case .workouts: "figure.strengthtraining.traditional"
        case .database: "books.vertical.fill"
        case .skills: "star.fill"
        case .analytics: "chart.xyaxis.line"
        case .coach: "sparkles"
        case .profile: "person.crop.circle.fill"
        case .ranked: "trophy.fill"
        case .physique: "figure.arms.open"
        case .map: "map.fill"
        case .schedule: "calendar"
        case .settings: "gearshape.fill"
        }
    }
}

/// Keeps the search index of the stores. The index is built away from the main thread, when the app is idle after
/// launch and again after the library or the workouts change, so opening the wheel never waits for it; a search made
/// while a rebuild runs uses the previous index and is run again when the new one is ready.
@MainActor
final class NavigationSearchModel {
    private struct Signature: Equatable {
        var library: Int
        var pages: Int
        var workouts: Int
        var groups: Int
        var skillsOnWheel: Bool
    }

    /// What an index is built from: plain values copied from the stores on the main thread.
    private struct Source: @unchecked Sendable {
        var pages: [ExercisePage]
        var workouts: [Workout]
        var groups: [WorkoutGroup]
        var skillsOnWheel: Bool
    }

    private let workoutStore: WorkoutStore
    private let databaseStore: DatabaseStore
    private var signature: Signature?
    private var index = NavigationSearchIndex(entries: [])
    private var skillsOnWheel = false
    private var building: Task<Void, Never>?
    /// Told when a new index is ready, so a search on screen can be run again.
    var onIndexChanged: () -> Void = {}

    init(workoutStore: WorkoutStore, databaseStore: DatabaseStore) {
        self.workoutStore = workoutStore
        self.databaseStore = databaseStore
    }

    /// Brings the index up to date for the pages on the wheel, building it in the background when anything changed.
    func prepare(wheelPages: [String]) {
        let onWheel = Set(wheelPages.compactMap(SlotNavigationDestination.init(rawValue:)))
        let next = Signature(
            library: databaseStore.libraryRevision,
            pages: databaseStore.allPagesFlat.count,
            workouts: workoutsSignature(),
            groups: groupsSignature(),
            skillsOnWheel: onWheel.contains(.skills)
        )
        guard next != signature else { return }
        signature = next
        skillsOnWheel = next.skillsOnWheel
        let source = Source(
            pages: databaseStore.allPagesFlat,
            workouts: workoutStore.workouts,
            groups: workoutStore.workoutGroups,
            skillsOnWheel: next.skillsOnWheel
        )
        building?.cancel()
        building = Task { [weak self] in
            let entries = await Task.detached(priority: .userInitiated) { Self.entries(from: source) }.value
            guard let self, !Task.isCancelled else { return }
            self.index = NavigationSearchIndex(entries: entries)
            self.building = nil
            self.onIndexChanged()
        }
    }

    func search(_ query: String) -> NavigationSearchResults {
        index.search(query)
    }

    /// The index as it stands, for running a search away from the main thread.
    func snapshot() -> NavigationSearchIndex { index }

    /// Whether there is anything to search yet; the first index of a launch is built in the background.
    var hasIndex: Bool { !index.entries.isEmpty }

    /// The picture to show beside a result (a library page's cover, a workout's first exercise cover) and the symbol to
    /// keep under it while it loads; nil when the result has no picture of its own.
    func cover(for target: NavigationSearchTarget) -> NavigationSearchCover? {
        switch target {
        case .libraryPage(let id, _):
            guard let page = databaseStore.page(manifestID: id), let url = page.coverImageURL else { return nil }
            return NavigationSearchCover(url: url, symbol: Self.symbol(for: page))
        case .workout(let id):
            guard let workout = workoutStore.workout(id: id) else { return nil }
            let library = databaseStore
            let url = workout.sections.lazy
                .compactMap { section in section.pageID.flatMap { library.page(id: $0)?.coverImageURL } }
                .first
            return url.map { NavigationSearchCover(url: $0, symbol: Self.workoutSymbol) }
        case .page, .workoutGroup:
            return nil
        }
    }

    /// What sits inside `target` one level down, for opening a level of the result tree further.
    func children(of target: NavigationSearchTarget) -> [NavigationSearchNode] {
        switch target {
        case .workoutGroup(let id):
            guard let group = workoutStore.workoutGroups.first(where: { $0.id == id }) else { return [] }
            return group.workoutIDs.prefix(40).compactMap { workoutID in
                workoutStore.workout(id: workoutID).map { workout in
                    NavigationSearchNode(id: "workout:\(workout.id)", title: workout.name, detail: workout.type.name,
                                         symbol: Self.workoutSymbol, target: .workout(workout.id),
                                         isMatch: false, canExpand: false, children: [])
                }
            }
        case .libraryPage(let id, _):
            guard let uuid = UUID(uuidString: id) else { return [] }
            return databaseStore.children(of: uuid).prefix(40).map { page in
                NavigationSearchNode(id: "library:\(page.manifest.id)", title: page.title, detail: Self.detail(for: page),
                                     symbol: Self.symbol(for: page),
                                     target: .libraryPage(page.manifest.id,
                                                          destination: Self.destination(for: page, skillsOnWheel: skillsOnWheel)),
                                     isMatch: false, canExpand: !page.manifest.childIDs.isEmpty, children: [])
            }
        case .page, .workout:
            return []
        }
    }

    private func workoutsSignature() -> Int {
        var hasher = Hasher()
        for workout in workoutStore.workouts {
            hasher.combine(workout.id)
            hasher.combine(workout.name)
            hasher.combine(workout.type.name)
        }
        return hasher.finalize()
    }

    private func groupsSignature() -> Int {
        var hasher = Hasher()
        for group in workoutStore.workoutGroups {
            hasher.combine(group.id)
            hasher.combine(group.title)
            hasher.combine(group.workoutIDs)
        }
        return hasher.finalize()
    }

    private nonisolated static func entries(from source: Source) -> [NavigationSearchEntry] {
        var entries: [NavigationSearchEntry] = []
        entries.reserveCapacity(source.pages.count + source.workouts.count + source.groups.count + 16)
        for destination in SlotNavigationDestination.allCases where destination.isAvailable {
            entries.append(NavigationSearchEntry(
                id: "page:\(destination.rawValue)", target: .page(destination), title: destination.title,
                detail: "Page", symbol: destination.searchSymbol, aliases: destination.searchAliases, weight: 1.3
            ))
        }

        var groupOfWorkout: [UUID: WorkoutGroup] = [:]
        for group in source.groups {
            for id in group.workoutIDs where groupOfWorkout[id] == nil { groupOfWorkout[id] = group }
            entries.append(NavigationSearchEntry(
                id: "group:\(group.id)", target: .workoutGroup(group.id), title: group.title,
                detail: group.workoutIDs.count == 1 ? "1 workout" : "\(group.workoutIDs.count) workouts",
                symbol: groupSymbol, hasChildren: !group.workoutIDs.isEmpty, weight: 1.05
            ))
        }
        for workout in source.workouts {
            let group = groupOfWorkout[workout.id]
            let trail = group.map { [NavigationSearchCrumb(id: "group:\($0.id)", title: $0.title, symbol: groupSymbol,
                                                           target: .workoutGroup($0.id))] } ?? []
            let archived = WorkoutTitle.isArchived(workout.name, groupTitle: group?.title)
            entries.append(NavigationSearchEntry(
                id: "workout:\(workout.id)", target: .workout(workout.id), title: workout.name,
                detail: "Workout · \(workout.type.name)", symbol: workoutSymbol, trail: trail,
                aliases: [workout.type.name], weight: archived ? 0.8 : 1.1
            ))
        }

        let index = PageIndex(pages: source.pages)
        for page in index.pages {
            let crumbs = index.breadcrumbs(for: page.id).dropLast().map { ancestor in
                NavigationSearchCrumb(
                    id: "library:\(ancestor.manifest.id)", title: ancestor.title, symbol: symbol(for: ancestor),
                    target: .libraryPage(ancestor.manifest.id,
                                         destination: destination(for: ancestor, skillsOnWheel: source.skillsOnWheel))
                )
            }
            entries.append(NavigationSearchEntry(
                id: "library:\(page.manifest.id)",
                target: .libraryPage(page.manifest.id, destination: destination(for: page, skillsOnWheel: source.skillsOnWheel)),
                title: page.title, detail: detail(for: page), symbol: symbol(for: page), trail: Array(crumbs),
                hasChildren: !page.manifest.childIDs.isEmpty, weight: weight(for: page)
            ))
        }
        return entries
    }

    private nonisolated static func destination(for page: ExercisePage, skillsOnWheel: Bool) -> SlotNavigationDestination {
        page.isSkillLike && page.manifest.noSkills != true && skillsOnWheel ? .skills : .database
    }

    private nonisolated static let workoutSymbol = "figure.strengthtraining.traditional"
    private nonisolated static let groupSymbol = "square.stack.3d.up.fill"

    private nonisolated static func symbol(for page: ExercisePage) -> String {
        switch page.pageType {
        case .exercise: "figure.mixed.cardio"
        case .skill: "star.fill"
        case .tutorial: "graduationcap.fill"
        case .note: "note.text"
        default: page.isContainer ? "folder.fill" : "doc.text.fill"
        }
    }

    private nonisolated static func detail(for page: ExercisePage) -> String {
        switch page.pageType {
        case .exercise: "Exercise"
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case .note: "Note"
        default: page.isContainer ? "Folder" : "Page"
        }
    }

    private nonisolated static func weight(for page: ExercisePage) -> Double {
        switch page.pageType {
        case .skill: 1.08
        case .exercise: 1
        case .tutorial: 1
        case .note: 0.94
        default: page.isContainer ? 1.02 : 0.96
        }
    }
}
