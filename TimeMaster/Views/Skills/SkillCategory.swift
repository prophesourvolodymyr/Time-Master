import Foundation
import TimeMasterCore

/// The fixed sections of the Skills page, in page order. A skill belongs to the one its root Database folder names.
enum SkillCategory: String, CaseIterable, Identifiable {
    case calisthenics, boxing, wrestling, gymnastics, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calisthenics: "Calisthenics"
        case .boxing: "Boxing"
        case .wrestling: "Wrestling"
        case .gymnastics: "Gymnastics"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .calisthenics: "figure.strengthtraining.functional"
        case .boxing: "figure.boxing"
        case .wrestling: "figure.wrestling"
        case .gymnastics: "figure.gymnastics"
        case .other: "square.grid.2x2.fill"
        }
    }

    var brandGlyph: TmaxBrandGlyph {
        switch self {
        case .calisthenics: .calisthenics
        case .boxing: .boxing
        case .wrestling: .wrestling
        case .gymnastics: .gymnastics
        case .other: .skills
        }
    }

    /// Words a root folder's title holds to name a category, checked in page order.
    private static let keywords: [(word: String, category: SkillCategory)] = [
        ("calisthenic", .calisthenics),
        ("boxing", .boxing),
        ("wrestling", .wrestling),
        ("gymnastic", .gymnastics)
    ]

    /// The category a root folder's title names, ignoring case: "calisthenic", "boxing" (Kickboxing too), "wrestling"
    /// (Core & Wrestling too) or "gymnastic", the first of them in page order; any other title is Other.
    init(rootTitle: String) {
        let match = Self.keywords.first { rootTitle.range(of: $0.word, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        self = match?.category ?? .other
    }

    /// The category of `page`: the one its root folder names.
    static func of(_ page: ExercisePage, in index: PageIndex) -> SkillCategory {
        SkillCategory(rootTitle: root(of: page, in: index).title)
    }

    /// The page at the top of `page`'s folders: the one above it with no parent (the highest one found when a parent is
    /// missing or the chain loops), or `page` itself at the top level. Follows parent ids through the index's lookup,
    /// never the whole library.
    static func root(of page: ExercisePage, in index: PageIndex) -> ExercisePage {
        var root = page
        var visited: Set<String> = [page.manifest.id]
        while let parentID = root.manifest.parentID, visited.insert(parentID).inserted,
              let parent = index.byManifestID[parentID] {
            root = parent
        }
        return root
    }

    /// The top-level folder that holds each category's picture: the one whose title names the category, the one titled
    /// exactly like the category when several do. Other has none (any folder may land there), so it has no entry.
    static func anchorPages(in index: PageIndex) -> [SkillCategory: ExercisePage] {
        var anchors: [SkillCategory: ExercisePage] = [:]
        var exact: Set<SkillCategory> = []
        for page in index.pages where page.manifest.parentID == nil && page.isContainer {
            let category = SkillCategory(rootTitle: page.title)
            guard category != .other else { continue }
            let isExact = page.title.compare(category.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            if anchors[category] == nil || (isExact && !exact.contains(category)) {
                anchors[category] = page
                if isExact { exact.insert(category) }
            }
        }
        return anchors
    }
}

/// One section of the Skills page: a category and its skills, in the order the page shows them.
struct SkillCategorySection: Identifiable {
    let category: SkillCategory
    let entries: [SkillLibraryEntry]

    var id: SkillCategory { category }
}

/// What the Skills page lists and how it groups it. Pure: it reads only the entries and the page index it is handed.
enum SkillShelf {
    /// The skills the page lists, in the given order: a page flagged `noSkills` is not a skill and stays out.
    static func listed(_ entries: [SkillLibraryEntry]) -> [SkillLibraryEntry] {
        entries.filter { $0.page.manifest.noSkills != true }
    }

    /// `entries` (listed, in display order) by category: sections in `SkillCategory` order, each keeping the given
    /// order, so sorting before grouping sorts every section; categories with no entry are left out.
    static func sections(of entries: [SkillLibraryEntry], index: PageIndex) -> [SkillCategorySection] {
        var byCategory: [SkillCategory: [SkillLibraryEntry]] = [:]
        for entry in entries {
            byCategory[SkillCategory.of(entry.page, in: index), default: []].append(entry)
        }
        return SkillCategory.allCases.compactMap { category in
            byCategory[category].map { SkillCategorySection(category: category, entries: $0) }
        }
    }
}
