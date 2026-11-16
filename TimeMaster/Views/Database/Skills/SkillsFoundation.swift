import SwiftUI
import TimeMasterCore

/// Widths of the skill screens. A big Mac window (full screen included) gets a wide column instead of a phone-sized
/// strip in the middle of empty space; boards and tables may run wider than the reading column.
enum SkillsLayout {
    #if os(macOS)
    static let pageWidth: CGFloat = 1240
    static let tableWidth: CGFloat = 1700
    #else
    static let pageWidth: CGFloat = 820
    static let tableWidth: CGFloat = 1100
    #endif
    /// The page edge inset the Database detail pages use.
    static let inset: CGFloat = 20
}

extension View {
    /// The skill screens' reading column: inset from the screen edge, capped (`SkillsLayout.pageWidth` by default)
    /// and centred.
    func skillsContained(maxWidth: CGFloat = SkillsLayout.pageWidth) -> some View {
        padding(.horizontal, SkillsLayout.inset)
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

/// UserDefaults keys of the skill settings (Settings → Skills).
enum SkillSettings {
    /// Bool, default true: board cards and list rows show the cover a sub-skill chose.
    static let showsCardCoversKey = "tm.skills.cardCovers"
    /// String (`SkillAutoIcon.Style` raw value: emoji, symbol, off), default emoji: the icon a sub-skill without its
    /// own icon takes from its title.
    static let autoIconStyleKey = "tm.skills.autoIcon"
    /// Prefix of the remembered List · Board · Table choice per board (`<prefix><board id>`).
    static let viewModeKeyPrefix = "tm.skills.viewMode."
    /// Int, default `SkillGroupLimit.standard`: how many sub-skills a section or a column shows before its
    /// "Expand all" (0 = every one).
    static let perGroupKey = "tm.skills.perGroup"
    /// `[page id: status raw value]`: what a page was before its done check was ticked, so un-ticking restores it.
    static let statusBeforeDoneKey = "tm.skills.statusBeforeDone"
}

/// The spacing, radii and sizes of the skill board: Skillmax's scale, unchanged.
enum SkillMetrics {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    /// Section groups, columns and tables.
    static let cardRadius: CGFloat = 20
    /// Rows, cards, fields and quick-add rows.
    static let fieldRadius: CGFloat = 14
    static let touch: CGFloat = 44
    static let row: CGFloat = 56
    static let phoneInset: CGFloat = 20
    static let regularInset: CGFloat = 32
}

// MARK: - The four statuses

extension SkillStatus {
    /// Column and filter order: Not started · In progress · Done · Abandoned.
    static let boardOrder: [SkillStatus] = [.notStarted, .learning, .completed, .abandoned]

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .learning: "In progress"
        case .completed: "Done"
        case .abandoned: "Abandoned"
        }
    }

    var symbolName: String {
        switch self {
        case .notStarted: "circle.dashed"
        case .learning: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        case .abandoned: "xmark.circle"
        }
    }

    /// Solid colour for icons, text and strokes.
    var color: Color {
        switch self {
        case .notStarted: Theme.textSecondary
        case .learning: Theme.toolbarOrange
        case .completed: Color(hex: "B6E9BF")
        case .abandoned: Color(hex: "E57373")
        }
    }

    /// Soft fill behind `color` text.
    var tint: Color { color.opacity(0.14) }

    /// Tap cycle of the status chip: not started → in progress → done → not started; abandoned → not started.
    var next: SkillStatus {
        switch self {
        case .notStarted: .learning
        case .learning: .completed
        case .completed: .notStarted
        case .abandoned: .notStarted
        }
    }

    /// Context-menu wording: "Mark done", "In progress", "Not started", "Abandon".
    var quickActionTitle: String {
        switch self {
        case .completed: "Mark done"
        case .learning: "In progress"
        case .notStarted: "Not started"
        case .abandoned: "Abandon"
        }
    }

    /// Opacity of a page title: abandoned pages sit back.
    var titleOpacity: Double { self == .abandoned ? 0.55 : 1 }
}

// MARK: - Opening pages and groups

/// A board group opened as a page of its own (tapping the title of its header).
struct DatabaseSkillGroupRoute: Hashable {
    let containerID: String
    let sectionID: String

    var groupID: String { SkillGroupID.make(containerID: containerID, sectionID: sectionID) }
}

extension DatabaseNavigationState {
    /// Pushes a page (a manifest id) or a group (a group id) onto the stack this state drives: the Database tab's, a
    /// search sheet's or the workout popup's, whichever the board sits in.
    func open(skillID id: String) {
        if let owner = SkillGroupID.split(id) {
            path.append(DatabaseSkillGroupRoute(containerID: owner.containerID, sectionID: owner.sectionID))
        } else {
            path.append(DatabasePageRoute(pageID: id))
        }
    }
}
