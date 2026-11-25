import Foundation

extension DatabaseManager {
    func bootstrapFeatureSkills() throws {
        try bootstrapBundleSkills()
        try bootstrapMilestoneSkills()
        try bootstrapNoteSkills()
        try bootstrapSkillPageSkills()
        try bootstrapPageTagSkills()
        try bootstrapScheduleSkills()
        try bootstrapPageContentSkills()
        try bootstrapOrganizeSkills()
        try bootstrapRecordSkills()
    }
}
