import Foundation

extension DatabaseManager {
    func bootstrapFeatureSkills() throws {
        try bootstrapBundleSkills()
        try bootstrapMilestoneSkills()
        try bootstrapNoteSkills()
    }

    func bootstrapBundleSkills() throws {}

    func bootstrapMilestoneSkills() throws {}
}
