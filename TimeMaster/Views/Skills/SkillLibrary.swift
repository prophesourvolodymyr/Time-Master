import Foundation
import TimeMasterCore

/// Completion of the sub-skills below a page: every skill and tutorial under it, at any depth (the page itself does
/// not count). Abandoned pages are counted apart and stay out of `total`.
struct SkillProgress: Equatable {
    var completed = 0
    var learning = 0
    var total = 0
    var abandoned = 0

    /// Done share of `total` (0…1); 0 when nothing counts.
    var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    /// No sub-skill counted at all, abandoned ones included (the summary then reads "No sub-skills yet").
    var isEmpty: Bool { total == 0 && abandoned == 0 }

    /// "3 of 12 done"; only abandoned ones: "2 abandoned"; none: "No sub-skills yet".
    var summary: String {
        if total > 0 { return "\(completed) of \(total) done" }
        return abandoned > 0 ? "\(abandoned) abandoned" : "No sub-skills yet"
    }
}

extension SkillProgress {
    /// The tally of `pages`' statuses (a page without one counts as not started).
    init(counting pages: [ExercisePage]) {
        self.init()
        for page in pages {
            switch page.manifest.skillStatus ?? .notStarted {
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
}

/// One skill on the Skills page with what its card and the sort need.
struct SkillLibraryEntry: Identifiable {
    let page: ExercisePage
    let progress: SkillProgress
    /// The latest change to the skill or to any of its sub-skills.
    let lastChange: Date

    var id: String { page.manifest.id }
    var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }
}

/// The library read for the skill screens: every page by id, so walking a skill tree or a page's parents never
/// searches the whole library per step. Build one per pass over `DatabaseStore.allPagesFlat`.
struct SkillLibrary {
    /// Results of the walks below, shared by every copy: the library never changes, so they stay valid.
    private final class Memo {
        var topLevel: [SkillLibraryEntry]?
        var subSkills: [String: [ExercisePage]] = [:]
        var below: [String: [ExercisePage]] = [:]
        var progress: [String: SkillProgress] = [:]
        var listed: [SkillSortOption: [SkillLibraryEntry]] = [:]
        var anchors: [SkillCategory: ExercisePage]?
    }

    private let pages: [ExercisePage]
    private let pagesByID: [String: ExercisePage]
    private let memo = Memo()

    /// Same library, same walks: whether `other` is a copy of this one.
    func isSame(as other: SkillLibrary) -> Bool { memo === other.memo }

    /// Names this snapshot of the library and every copy of it.
    var snapshotToken: ObjectIdentifier { ObjectIdentifier(memo) }

    init(pages: [ExercisePage]) {
        self.pages = pages
        pagesByID = Dictionary(pages.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init(index: PageIndex) {
        pages = index.pages
        pagesByID = index.byManifestID
    }

    func page(_ id: String) -> ExercisePage? { pagesByID[id] }

    /// A skill or a tutorial that is a skill: a page flagged `noSkills` is none anywhere (no Skills page, no board, no
    /// progress count), and the sub-skill walks never go below one.
    static func isSkill(_ page: ExercisePage) -> Bool {
        page.isSkillLike && !page.manifest.hidesSkills
    }

    /// The skills of the Skills page: skill and tutorial pages with no skill or tutorial above them, wherever their
    /// folder is, in library order, each with its progress and last change.
    func topLevelEntries() -> [SkillLibraryEntry] {
        if let known = memo.topLevel { return known }
        let result = pages.filter { Self.isSkill($0) && !isInsideSkill($0) }.map { page in
            let below = subSkills(below: page)
            let lastChange = below.reduce(page.manifest.updatedAt) { max($0, $1.manifest.updatedAt) }
            return SkillLibraryEntry(page: page, progress: SkillProgress(counting: below), lastChange: lastChange)
        }
        memo.topLevel = result
        return result
    }

    func listedEntries(by option: SkillSortOption) -> [SkillLibraryEntry] {
        if let known = memo.listed[option] { return known }
        let result = option.ordered(SkillShelf.listed(topLevelEntries()))
        memo.listed[option] = result
        return result
    }

    func categoryAnchors() -> [SkillCategory: ExercisePage] {
        if let known = memo.anchors { return known }
        let result = SkillCategory.anchorPages(among: pages)
        memo.anchors = result
        return result
    }

    /// Plain folders a new top-level skill can go in (containers without a type, outside every skill), each with its
    /// path ("Music › Strings"), sorted by path.
    func skillFolders() -> [(page: ExercisePage, path: String)] {
        pages.filter { $0.isContainer && $0.pageType == nil && !isInsideSkill($0) }
            .map { (page: $0, path: fullPath(of: $0)) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Whether a skill or tutorial (one that is a skill, see `isSkill`) sits anywhere above `page`.
    func isInsideSkill(_ page: ExercisePage) -> Bool {
        ancestors(of: page).contains { Self.isSkill($0) }
    }

    /// The pages above `page`, its parent first.
    func ancestors(of page: ExercisePage) -> [ExercisePage] {
        var result: [ExercisePage] = []
        var visited: Set<String> = [page.manifest.id]
        var parentID = page.manifest.parentID
        while let id = parentID, visited.insert(id).inserted, let parent = pagesByID[id] {
            result.append(parent)
            parentID = parent.manifest.parentID
        }
        return result
    }

    /// The sub-skills below `page`, depth first in child order: skill and tutorial pages, reached through skills,
    /// tutorials and plain folders. A page that needs no skills has none, and the walk leaves out every page that needs
    /// none together with everything below it.
    func subSkills(below page: ExercisePage) -> [ExercisePage] {
        guard !page.manifest.hidesSkills else { return [] }
        let id = page.manifest.id
        let cacheable = pagesByID[id]?.manifest.childIDs == page.manifest.childIDs
        if cacheable, let known = memo.subSkills[id] { return known }
        var result: [ExercisePage] = []
        var visited: Set<String> = [id]
        func visit(_ parent: ExercisePage) {
            for id in parent.manifest.childIDs where visited.insert(id).inserted {
                guard let child = pagesByID[id] else { continue }
                if child.isSkillLike {
                    guard Self.isSkill(child) else { continue }
                    result.append(child)
                    visit(child)
                } else if child.isContainer, child.pageType == nil {
                    visit(child)
                }
            }
        }
        visit(page)
        if cacheable { memo.subSkills[id] = result }
        return result
    }

    /// Every page below `page`, whatever its kind, depth first in child order.
    func pages(below page: ExercisePage) -> [ExercisePage] {
        let id = page.manifest.id
        let cacheable = pagesByID[id]?.manifest.childIDs == page.manifest.childIDs
        if cacheable, let known = memo.below[id] { return known }
        var result: [ExercisePage] = []
        var visited: Set<String> = [id]
        func visit(_ parent: ExercisePage) {
            for id in parent.manifest.childIDs where visited.insert(id).inserted {
                guard let child = pagesByID[id] else { continue }
                result.append(child)
                visit(child)
            }
        }
        visit(page)
        if cacheable { memo.below[id] = result }
        return result
    }

    /// Progress of the sub-skills below `page`, read from the library's copy of it.
    func progress(of page: ExercisePage) -> SkillProgress {
        let id = page.manifest.id
        if let known = memo.progress[id] { return known }
        let result = SkillProgress(counting: subSkills(below: pagesByID[id] ?? page))
        memo.progress[id] = result
        return result
    }

    /// The titles from `root` down to the parent of `page` ("Guitar › Chords"); empty for `root` itself.
    func pathText(of page: ExercisePage, below root: ExercisePage) -> String {
        guard page.manifest.id != root.manifest.id else { return "" }
        var titles: [String] = []
        for ancestor in ancestors(of: page) {
            titles.append(ancestor.title)
            if ancestor.manifest.id == root.manifest.id { break }
        }
        return titles.reversed().joined(separator: " › ")
    }

    /// The page's title after the titles of every page above it ("Music › Strings").
    func fullPath(of page: ExercisePage) -> String {
        (ancestors(of: page).reversed().map(\.title) + [page.title]).joined(separator: " › ")
    }
}

extension DatabaseStore {
    /// Progress of the sub-skills below a page: a skill, a tutorial or a plain folder.
    func skillProgress(of page: ExercisePage) -> SkillProgress {
        skillLibrary.progress(of: page)
    }

    /// Progress below a page (by manifest id) or a group (by group id, see `SkillGroupID`: the group's skills and
    /// everything below them; its pages that need no skills are none).
    func skillProgress(of id: String) -> SkillProgress {
        let library = skillLibrary
        if let owner = SkillGroupID.split(id) {
            let members = skillPages(onBoard: owner.containerID, sectionID: owner.sectionID).filter(SkillLibrary.isSkill)
            return SkillProgress(counting: members.flatMap { [$0] + library.subSkills(below: $0) })
        }
        guard let page = library.page(id) else { return SkillProgress() }
        return library.progress(of: page)
    }
}
