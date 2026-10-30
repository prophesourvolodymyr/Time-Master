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
}

// MARK: - The four statuses

extension SkillStatus {
    /// Column and filter order.
    static let boardOrder: [SkillStatus] = [.notStarted, .learning, .completed, .abandoned]

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .learning: "Learning"
        case .completed: "Completed"
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

    /// The done toggle: done goes back to not started, anything else becomes done.
    var toggledDone: SkillStatus { self == .completed ? .notStarted : .completed }

    /// Opacity of a page title: abandoned pages sit back.
    var titleOpacity: Double { self == .abandoned ? 0.55 : 1 }
}

// MARK: - Groups opened as pages

/// A board group opened as a page of its own (tapping the title of its header).
struct DatabaseSkillGroupRoute: Hashable {
    let containerID: String
    let sectionID: String

    var groupID: String { SkillGroupID.make(containerID: containerID, sectionID: sectionID) }
}
