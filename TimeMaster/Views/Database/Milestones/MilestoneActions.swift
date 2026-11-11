import Foundation
import TimeMasterCore

/// What a milestone card or row can ask of its page.
struct MilestoneActions {
    var toggle: (Milestone) -> Void
    var edit: (Milestone) -> Void
    var addChild: (Milestone) -> Void
    /// Moves a milestone one place earlier (-1) or later (+1) among its siblings.
    var move: (Milestone, Int) -> Void
    var delete: (Milestone) -> Void
    var openLink: (TodoLink, ChecklistLinkTarget) -> Void
    var playWorkout: (Workout) -> Void
    var removeLink: (Milestone, TodoLink) -> Void
    var openPicture: (URL) -> Void

    /// For the editor's preview: nothing responds.
    static let inert = MilestoneActions(
        toggle: { _ in }, edit: { _ in }, addChild: { _ in }, move: { _, _ in }, delete: { _ in },
        openLink: { _, _ in }, playWorkout: { _ in }, removeLink: { _, _ in }, openPicture: { _ in }
    )
}
