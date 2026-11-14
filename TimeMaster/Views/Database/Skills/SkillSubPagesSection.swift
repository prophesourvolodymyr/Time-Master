import SwiftUI
import TimeMasterCore

/// The exercises, notes and folders that live inside a skill or tutorial page. Its skills and tutorials are the
/// Sub-skills board above; everything else a person puts inside the page shows here, in the order they were added.
struct SkillSubPagesSection: View {
    @EnvironmentObject private var store: DatabaseStore

    let skill: ExercisePage

    private var pages: [ExercisePage] {
        store.children(of: skill.id).filter { !$0.isSkillLike }
    }

    var body: some View {
        if !pages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Exercises & notes")
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                ExerciseChildList(pages: pages)
            }
        }
    }
}
