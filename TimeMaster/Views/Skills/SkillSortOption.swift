import Foundation
import TimeMasterCore

/// How the Skills page orders its skills.
enum SkillSortOption: String, CaseIterable, Identifiable {
    case status, recent, name, progress

    /// Status order of the Skills page: in progress first, then not started, done and abandoned.
    static let statusOrder: [SkillStatus] = [.learning, .notStarted, .completed, .abandoned]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .recent: "Recently changed"
        case .name: "Name"
        case .progress: "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .status: "circle.lefthalf.filled"
        case .recent: "clock"
        case .name: "textformat"
        case .progress: "chart.bar"
        }
    }

    /// `entries` in display order. Status puts skills in progress first, then not started, done and abandoned. Ties
    /// go to the most recently changed, then the name.
    func ordered(_ entries: [SkillLibraryEntry]) -> [SkillLibraryEntry] {
        entries.sorted { lhs, rhs in
            switch self {
            case .status:
                let left = Self.rank(lhs.status), right = Self.rank(rhs.status)
                if left != right { return left < right }
            case .recent:
                break
            case .name:
                let order = lhs.page.title.localizedStandardCompare(rhs.page.title)
                if order != .orderedSame { return order == .orderedAscending }
            case .progress:
                if lhs.progress.fraction != rhs.progress.fraction { return lhs.progress.fraction > rhs.progress.fraction }
            }
            if lhs.lastChange != rhs.lastChange { return lhs.lastChange > rhs.lastChange }
            let order = lhs.page.title.localizedStandardCompare(rhs.page.title)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    private static func rank(_ status: SkillStatus) -> Int {
        statusOrder.firstIndex(of: status) ?? statusOrder.count
    }
}

/// Tiles or rows on the Skills page.
enum SkillsViewMode: String {
    case tiles, list
}
