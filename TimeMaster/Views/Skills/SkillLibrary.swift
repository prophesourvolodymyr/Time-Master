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
    private let pages: [ExercisePage]
    private let pagesByID: [String: ExercisePage]

    init(pages: [ExercisePage]) {
        self.pages = pages
        pagesByID = Dictionary(pages.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func page(_ id: String) -> ExercisePage? { pagesByID[id] }

    /// The skills of the Skills page: skill and tutorial pages with no skill or tutorial above them, wherever their
    /// folder is, in library order, each with its progress and last change.
    func topLevelEntries() -> [SkillLibraryEntry] {
        pages.filter { $0.isSkillLike && !isInsideSkill($0) }.map { page in
            let below = subSkills(below: page)
            let lastChange = below.reduce(page.manifest.updatedAt) { max($0, $1.manifest.updatedAt) }
            return SkillLibraryEntry(page: page, progress: SkillProgress(counting: below), lastChange: lastChange)
        }
    }

    /// Plain folders a new top-level skill can go in (containers without a type, outside every skill), each with its
    /// path ("Music › Strings"), sorted by path.
    func skillFolders() -> [(page: ExercisePage, path: String)] {
        pages.filter { $0.isContainer && $0.pageType == nil && !isInsideSkill($0) }
            .map { (page: $0, path: fullPath(of: $0)) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Whether a skill or tutorial sits anywhere above `page`.
    func isInsideSkill(_ page: ExercisePage) -> Bool {
        ancestors(of: page).contains { $0.isSkillLike }
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
    /// tutorials and plain folders.
    func subSkills(below page: ExercisePage) -> [ExercisePage] {
        var result: [ExercisePage] = []
        var visited: Set<String> = [page.manifest.id]
        func visit(_ parent: ExercisePage) {
            for id in parent.manifest.childIDs where visited.insert(id).inserted {
                guard let child = pagesByID[id] else { continue }
                if child.isSkillLike {
                    result.append(child)
                    visit(child)
                } else if child.isContainer, child.pageType == nil {
                    visit(child)
                }
            }
        }
        visit(page)
        return result
    }

    /// Every page below `page`, whatever its kind, depth first in child order.
    func pages(below page: ExercisePage) -> [ExercisePage] {
        var result: [ExercisePage] = []
        var visited: Set<String> = [page.manifest.id]
        func visit(_ parent: ExercisePage) {
            for id in parent.manifest.childIDs where visited.insert(id).inserted {
                guard let child = pagesByID[id] else { continue }
                result.append(child)
                visit(child)
            }
        }
        visit(page)
        return result
    }

    /// Progress of the sub-skills below `page`, read from the library's copy of it.
    func progress(of page: ExercisePage) -> SkillProgress {
        SkillProgress(counting: subSkills(below: pagesByID[page.manifest.id] ?? page))
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
        SkillLibrary(pages: allPagesFlat).progress(of: page)
    }

    /// Progress below a page (by manifest id) or a group (by group id, see `SkillGroupID`: the group's pages and
    /// everything below them).
    func skillProgress(of id: String) -> SkillProgress {
        let library = SkillLibrary(pages: allPagesFlat)
        if let owner = SkillGroupID.split(id) {
            let members = skillPages(onBoard: owner.containerID, sectionID: owner.sectionID)
            return SkillProgress(counting: members.flatMap { [$0] + library.subSkills(below: $0) })
        }
        guard let page = library.page(id) else { return SkillProgress() }
        return library.progress(of: page)
    }
}
