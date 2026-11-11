import Foundation
import TimeMasterCore

/// What a to-do row can ask of its list.
struct TodoRowActions {
    var toggle: () -> Void = {}
    var toggleCollapse: () -> Void = {}
    var focusChanged: (Bool) -> Void = { _ in }
    /// The text as typed, when the field lost the keyboard.
    var commitTitle: (String) -> Void = { _ in }
    /// Return: save the text and carry on with the next line.
    var submit: (String) -> Void = { _ in }
    var indent: () -> Void = {}
    var outdent: () -> Void = {}
    var addSubTodo: () -> Void = {}
    var edit: () -> Void = {}
    var chooseIcon: () -> Void = {}
    var moveUp: () -> Void = {}
    var moveDown: () -> Void = {}
    var remove: () -> Void = {}
    var openLink: (TodoLink, ChecklistLinkTarget) -> Void = { _, _ in }
    var playWorkout: (Workout) -> Void = { _ in }
    var removeLink: (TodoLink) -> Void = { _ in }
    var openPicture: (URL) -> Void = { _ in }

    /// For a preview: nothing responds.
    static let inert = TodoRowActions()
}
