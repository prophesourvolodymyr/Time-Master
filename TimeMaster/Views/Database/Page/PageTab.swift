import SwiftUI
import TimeMasterCore

/// The tabs of a library page: Skillmax's sub-skill tabs for skills and tutorials, and the same track for exercises and
/// containers with what they hold.
enum PageTab: String, Hashable, Identifiable {
    case all
    case skills
    case children
    case dependencies
    case attachments
    case todos
    case milestones
    case workout
    case notes
    case links

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .skills: "Skills"
        case .children: "Exercises & Skills"
        case .dependencies: "Dependencies"
        case .attachments: "Attachments"
        case .todos: "To-do"
        case .milestones: "Milestones"
        case .workout: "Workout"
        case .notes: "Notes"
        case .links: "Links"
        }
    }

    /// The glyph on the heading of the part the tab shows.
    var symbol: String {
        switch self {
        case .all: "square.stack"
        case .skills: "square.grid.2x2"
        case .children: "square.stack.3d.up"
        case .dependencies: "arrow.triangle.branch"
        case .attachments: "paperclip"
        case .todos: "checklist"
        case .milestones: "flag.checkered"
        case .workout: "timer"
        case .notes: "note.text"
        case .links: "link"
        }
    }
}

/// A page's tabs, the number beside each and the tab the page opens on, read from the stores once per pass.
///
/// A skill or a tutorial shows All · Skills · Dependencies · Attachments · To-do · Milestones · Notes; one that needs no
/// skills (`noSkills`) All · Attachments · Notes, plus Exercises & Skills when pages sit inside it; an exercise
/// All · Attachments · Notes, plus Workout (its timing and the workouts that train it) and Links when it has them; a
/// container All · Exercises & Skills · Notes, plus Attachments and Links when it has them. All stacks the page's parts
/// with the attachments first and the notes right after them, then the rest in Skillmax's order.
struct PageTabModel {
    private enum Kind {
        case exercise, skill, container
        /// A skill or a tutorial that needs no skills: its files and links, its notes, and the pages inside it.
        case plainSkill
    }

    /// Tabs in display order.
    let tabs: [PageTab]
    /// The parts the All tab stacks, in order.
    let allParts: [PageTab]
    private let kind: Kind
    private let isTopLevelSkill: Bool
    private let subSkills: Int
    private let childPages: Int
    private let dependencies: Int
    private let attachments: Int
    private let links: Int
    private let todos: Int
    private let openTodos: Int
    private let milestones: Int
    private let openMilestones: Int

    /// `linkedPageCount`: the attached pages that still resolve. `hasWorkout`: an exercise with a timing or a workout
    /// that trains it.
    @MainActor
    init(page: ExercisePage, store: DatabaseStore, library: SkillLibrary, linkedPageCount: Int, hasWorkout: Bool) {
        let manifest = page.manifest
        let showsSkills = !manifest.hidesSkills
        let children = store.children(of: page.id)
        childPages = children.count
        subSkills = showsSkills ? children.filter(SkillLibrary.isSkill).count : 0
        todos = showsSkills ? manifest.todos.count : 0
        openTodos = showsSkills ? manifest.todos.openCount : 0
        milestones = showsSkills ? manifest.milestones.count : 0
        openMilestones = showsSkills ? manifest.milestones.openCount : 0
        if page.isSkillLike && showsSkills {
            let flaggedFiles = Set(manifest.dependencyMediaFilenames)
            let flaggedLinks = Set(manifest.dependencyLinkURLs)
            kind = .skill
            isTopLevelSkill = !library.isInsideSkill(page)
            dependencies = store.skillDependencyCount(of: manifest.id)
            attachments = page.mediaURLs.filter { !flaggedFiles.contains($0.lastPathComponent) }.count
                + manifest.linkURLs.filter { !flaggedLinks.contains($0) }.count
                + linkedPageCount
            links = 0
            tabs = [.all, .skills, .dependencies, .attachments, .todos, .milestones, .notes]
            allParts = [.attachments, .notes, .skills, .dependencies, .todos, .milestones]
        } else if page.isSkillLike {
            var plainTabs: [PageTab] = [.all, .attachments, .notes]
            var parts: [PageTab] = [.attachments, .notes]
            if childPages > 0 {
                plainTabs.append(.children)
                parts.append(.children)
            }
            kind = .plainSkill
            isTopLevelSkill = false
            dependencies = 0
            attachments = page.mediaURLs.count + manifest.linkURLs.count + linkedPageCount
            links = 0
            tabs = plainTabs
            allParts = parts
        } else if page.pageType == nil {
            var containerTabs: [PageTab] = [.all, .children]
            var parts: [PageTab] = []
            if page.hasMedia {
                containerTabs.append(.attachments)
                parts.append(.attachments)
            }
            containerTabs.append(.notes)
            parts += [.notes, .children]
            if page.hasLinks {
                containerTabs.append(.links)
                parts.append(.links)
            }
            kind = .container
            isTopLevelSkill = false
            dependencies = 0
            attachments = page.mediaURLs.count + linkedPageCount
            links = manifest.linkURLs.count
            tabs = containerTabs
            allParts = parts
        } else {
            var extras: [PageTab] = []
            if hasWorkout { extras.append(.workout) }
            if page.hasLinks { extras.append(.links) }
            kind = .exercise
            isTopLevelSkill = false
            dependencies = 0
            attachments = page.mediaURLs.count + linkedPageCount
            links = manifest.linkURLs.count
            tabs = [.all, .attachments, .notes] + extras
            allParts = [.attachments, .notes] + extras
        }
    }

    /// Where the page opens (Skillmax's rule): a page holding nothing countable opens on its To-do, else its
    /// Milestones, else All; a skill on its Skills when it has pages inside it (and always when no skill is above it),
    /// else on what it has of Attachments and Dependencies; a skill that needs no skills on its Attachments, or its pages
    /// when it has no attachments; a container on its pages; an exercise on its Attachments.
    var defaultTab: PageTab {
        if childPages == 0 && attachments == 0 && dependencies == 0 {
            if todos > 0 { return .todos }
            if milestones > 0 { return .milestones }
            return .all
        }
        switch kind {
        case .skill:
            if isTopLevelSkill || childPages > 0 { return .skills }
            return attachments == 0 ? .dependencies : .attachments
        case .plainSkill:
            return attachments == 0 && childPages > 0 ? .children : .attachments
        case .container:
            if childPages > 0 { return .children }
            return tabs.contains(.attachments) ? .attachments : .all
        case .exercise:
            return .attachments
        }
    }

    /// The remembered tab while the page still offers it, otherwise the page's default.
    func resolved(_ selection: PageTab?) -> PageTab {
        if let selection, tabs.contains(selection) { return selection }
        return defaultTab
    }

    /// The number beside a tab's name: the sub-skills, pages, dependencies, attachments and links (All adds up those it
    /// stacks), the open to-dos and milestones. Nil when it would be zero or the tab holds nothing to count.
    func badge(for tab: PageTab) -> Int? {
        let total: Int
        switch tab {
        case .all: total = allParts.reduce(0) { $0 + countable($1) }
        case .todos: total = openTodos
        case .milestones: total = openMilestones
        case .workout, .notes: return nil
        case .skills, .children, .dependencies, .attachments, .links: total = countable(tab)
        }
        return total > 0 ? total : nil
    }

    private func countable(_ tab: PageTab) -> Int {
        switch tab {
        case .skills: subSkills
        case .children: childPages
        case .dependencies: dependencies
        case .attachments: attachments
        case .links: links
        case .all, .todos, .milestones, .workout, .notes: 0
        }
    }
}

/// The tab each page was left on, while the app runs: the page opens there again as long as it still has that tab.
@MainActor
enum PageTabMemory {
    private static var tabs: [String: PageTab] = [:]

    static func tab(for pageID: String) -> PageTab? {
        tabs[pageID]
    }

    static func remember(_ tab: PageTab, for pageID: String) {
        tabs[pageID] = tab
    }
}

/// What a page is, in words and as a glyph (the names and symbols of the new-page sheet).
enum PageKindStyle {
    static func title(_ page: ExercisePage) -> String {
        switch page.pageType {
        case .exercise: "Exercise"
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case .note: "Note"
        case nil: "Container"
        }
    }

    static func symbol(_ page: ExercisePage) -> String {
        switch page.pageType {
        case .exercise: "figure.run"
        case .skill: "flag.checkered"
        case .tutorial: "book.closed"
        case .note: "note.text"
        case nil: "square.stack.3d.up"
        }
    }
}
