import Foundation

/// A tile of the widget strip under a page's header. `ExercisePageManifest.widgets` stores these raw values, so a name
/// never changes once released; a name a build does not know reads as no tile.
public enum PageWidgetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case clips
    case folder
    case progress
    case todos
    case milestones
    case learnFirst
    case workouts

    public var id: String { rawValue }

    /// The tiles about sub-skills: progress, to-dos, milestones and what to learn first. A page with `noSkills` shows
    /// none of them.
    public var isSkillRelated: Bool {
        switch self {
        case .progress, .todos, .milestones, .learnFirst: return true
        case .clips, .folder, .workouts: return false
        }
    }

    /// The tiles a page of `pageType` can show, in the strip's own order: an exercise its clips and the workouts that
    /// train it; a skill or a tutorial also its progress, to-dos, milestones and what to learn first; a folder its
    /// clips, what it holds, the progress of the skills in it and the workouts that use its pages; a note none. With
    /// `noSkills` the tiles about sub-skills are left out.
    public static func available(for pageType: PageType?, noSkills: Bool = false) -> [PageWidgetKind] {
        let kinds: [PageWidgetKind]
        switch pageType {
        case .note?: kinds = []
        case .exercise?: kinds = [.clips, .workouts]
        case .skill?, .tutorial?: kinds = [.clips, .progress, .todos, .milestones, .learnFirst, .workouts]
        case nil: kinds = [.clips, .folder, .progress, .workouts]
        }
        return noSkills ? kinds.filter { !$0.isSkillRelated } : kinds
    }
}

/// What a page's `widgets` setting asks for.
public enum PageWidgetSelection: Equatable, Sendable {
    /// No setting (nil): the tiles that have something to show, none of them empty.
    case automatic
    /// An empty list: no strip at all.
    case hidden
    /// Exactly these tiles in this order, the empty ones too (each inviting its first item).
    case chosen([PageWidgetKind])

    /// Reads a stored setting. Names this build does not know are skipped and a repeat keeps its first place.
    public init(stored: [String]?) {
        switch stored {
        case nil:
            self = .automatic
        case let names? where names.isEmpty:
            self = .hidden
        case let names?:
            self = .chosen(names.compactMap(PageWidgetKind.init(rawValue:)).uniqued())
        }
    }

    /// The setting as `ExercisePageManifest.widgets` stores it.
    public var stored: [String]? {
        switch self {
        case .automatic: return nil
        case .hidden: return []
        case .chosen(let kinds): return kinds.uniqued().map(\.rawValue)
        }
    }

    /// The tiles the strip shows for a page of `pageType`, in order. Automatic keeps the page's own tiles that
    /// `hasContent` says have something to show; a chosen list keeps its order and its empty tiles. Either way only the
    /// tiles that page can show count, and `noSkills` leaves out the ones about sub-skills.
    public func resolved(for pageType: PageType?, noSkills: Bool, hasContent: (PageWidgetKind) -> Bool) -> [PageWidgetKind] {
        let available = PageWidgetKind.available(for: pageType, noSkills: noSkills)
        switch self {
        case .automatic:
            return available.filter { hasContent($0) }
        case .hidden:
            return []
        case .chosen(let kinds):
            return kinds.uniqued().filter { available.contains($0) }
        }
    }
}

extension Array where Element == PageWidgetKind {
    /// The list with `kind` switched on or off. A tile switched on goes in after the listed tiles that come before it in
    /// the strip's own order, so a list in that order stays in it and a list in an order of its own keeps that order.
    public func settingWidget(_ kind: PageWidgetKind, shown: Bool) -> [PageWidgetKind] {
        var kinds = filter { $0 != kind }
        guard shown else { return kinds }
        let earlier = PageWidgetKind.allCases.prefix { $0 != kind }
        let index = kinds.lastIndex { earlier.contains($0) }.map { $0 + 1 } ?? 0
        kinds.insert(kind, at: index)
        return kinds
    }
}

extension ExercisePageManifest {
    /// `noSkills` as a plain flag: the page shows no sub-skills, progress, to-dos, milestones or learn-first list.
    public var hidesSkills: Bool { noSkills == true }

    /// The `widgets` setting, read and written as a selection.
    public var widgetSelection: PageWidgetSelection {
        get { PageWidgetSelection(stored: widgets) }
        set { widgets = newValue.stored }
    }
}
