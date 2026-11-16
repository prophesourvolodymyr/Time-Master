import SwiftUI

/// A widget the strip under a page's header can show. Which ones a page gets, and in what order, follows from what the
/// page is and what it holds (`PageWidgetItem.items(for:store:workoutStore:)`).
enum PageWidgetKind: String, CaseIterable, Identifiable {
    case clips, folder, progress, todos, milestones, learnFirst, workouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clips: "Clips"
        case .folder: "In this folder"
        case .progress: "Progress"
        case .todos: "To-do"
        case .milestones: "Milestones"
        case .learnFirst: "Learn first"
        case .workouts: "Workouts"
        }
    }

    var systemImage: String {
        switch self {
        case .clips: "play.rectangle.fill"
        case .folder: "folder.fill"
        case .progress: "circle.dotted"
        case .todos: "checklist"
        case .milestones: "flag.checkered"
        case .learnFirst: "list.number"
        case .workouts: "figure.strengthtraining.traditional"
        }
    }

    /// The tile's width while its row has no room to share out; a roomier row grows every tile in proportion.
    var naturalWidth: CGFloat {
        switch self {
        case .clips: 196
        case .folder: 212
        case .progress: 184
        case .todos: 216
        case .milestones: 192
        case .learnFirst: 168
        case .workouts: 180
        }
    }
}
