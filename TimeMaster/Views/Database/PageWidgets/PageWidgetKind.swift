import SwiftUI
import TimeMasterCore

/// How a widget (`PageWidgetKind`, kept in the page's `widgets` setting) reads on the strip and in the page's settings.
/// Which ones a page shows, and in what order, follows from that setting and what the page holds
/// (`PageWidgetItem.items(for:store:workoutStore:)`).
extension PageWidgetKind {
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
