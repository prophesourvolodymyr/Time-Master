import SwiftUI

/// The to-do list and the milestones of a skill or tutorial page, one under the other.
struct SkillChecklistSections: View {
    let pageID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SkillTodoSection(pageID: pageID)
            SkillMilestonesSection(pageID: pageID)
        }
    }
}
