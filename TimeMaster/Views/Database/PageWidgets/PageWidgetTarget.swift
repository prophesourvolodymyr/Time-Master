import Foundation

/// Where a tap on a page widget leads (`PageWidgetStrip`). The page that shows the strip maps each target to its own
/// tab, section or sheet.
enum PageWidgetTarget: Hashable {
    /// The page's files, opened on the one at `index` of `ExercisePage.mediaURLs`; nil opens the list itself (a page
    /// without files, to add the first).
    case attachments(index: Int?)
    /// The sub-skills of a skill or a tutorial.
    case subSkills
    /// The to-do list.
    case todos
    /// The milestones.
    case milestones
    /// The saved workouts that train the page; `PageWorkoutsList` lists them.
    case workouts
    /// What to learn first.
    case dependencies
    /// The pages of a folder.
    case children

    /// What a tap does, for VoiceOver.
    var hint: String {
        switch self {
        case .attachments(let index): index == nil ? "Opens the attachments to add one" : "Opens the attachments"
        case .subSkills: "Opens the sub-skills"
        case .todos: "Opens the to-do list"
        case .milestones: "Opens the milestones"
        case .workouts: "Lists the workouts"
        case .dependencies: "Opens what to learn first"
        case .children: "Opens the pages in this folder"
        }
    }
}
