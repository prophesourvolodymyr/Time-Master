import Foundation

/// What the entry editor opens on: a new entry (under a parent, at a place of the top level) or an existing one.
enum ChecklistEditorRoute: Identifiable, Equatable {
    case create(parentID: String?, index: Int?)
    case edit(String)

    var id: String {
        switch self {
        case .create(let parentID, let index): return "new/\(parentID ?? "top")/\(index.map(String.init) ?? "end")"
        case .edit(let id): return "edit/\(id)"
        }
    }
}
