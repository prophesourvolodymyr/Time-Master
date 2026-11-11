import SwiftUI
import TimeMasterCore

/// The menu of a milestone card or row (right-click, or press and hold).
struct MilestoneMenu: View {
    let milestone: Milestone
    let actions: MilestoneActions

    var body: some View {
        Button { actions.edit(milestone) } label: { Label("Edit…", systemImage: "pencil") }
        Button { actions.addChild(milestone) } label: { Label("Add sub-milestone…", systemImage: "plus") }
        Button { actions.toggle(milestone) } label: {
            Label(milestone.isDone ? "Reopen" : "Mark as reached", systemImage: milestone.isDone ? "arrow.uturn.backward" : "checkmark.circle")
        }
        Divider()
        Button { actions.move(milestone, -1) } label: { Label("Move earlier", systemImage: "arrow.up") }
        Button { actions.move(milestone, 1) } label: { Label("Move later", systemImage: "arrow.down") }
        Divider()
        Button(role: .destructive) { actions.delete(milestone) } label: { Label("Delete…", systemImage: "trash") }
    }
}
