import Foundation

extension AgentToolRegistry {
    static var skillTrainingTools: [AgentTool] { [setSkillTraining, getSkillTraining] }

    private static let trainedSkillText = "The skill or tutorial the exercises train. \(pageRef)"

    private static var setSkillTraining: AgentTool {
        AgentTool(
            name: "set_skill_training",
            summary: "Say which exercises train a skill and how well, on a tier from S (the best way to train it) down to D. The skill's Tiers view lists them. An exercise can train several skills; one call fills a whole skill.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "skill": AgentSchema.string(trainedSkillText),
                "exercises": AgentSchema.array(of: AgentSchema.object([
                    "exercise": AgentSchema.string("Exercise, skill or tutorial page that trains the skill. \(pageRef)"),
                    "tier": AgentSchema.string("S, A, B, C or D.", values: ["S", "A", "B", "C", "D"]),
                ], required: ["exercise", "tier"]), "The pages to link, each with its tier. A page already linked gets the new tier."),
                "replace": AgentSchema.boolean("true: pages not in the list stop training this skill. false (default): only the listed pages change."),
            ], required: ["skill", "exercises"])
        )
    }

    private static var getSkillTraining: AgentTool {
        AgentTool(
            name: "get_skill_training",
            summary: "List the exercises that train a skill, grouped by tier from S down to D.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object(["skill": AgentSchema.string(trainedSkillText)], required: ["skill"])
        )
    }
}
