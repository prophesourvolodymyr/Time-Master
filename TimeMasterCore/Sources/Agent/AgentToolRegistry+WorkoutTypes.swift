import Foundation

extension AgentToolRegistry {
    static var workoutTypeTools: [AgentTool] { [createWorkoutType, updateWorkoutType, deleteWorkoutType] }

    private static let typeRef = "Workout type id or exact name (a custom type; the built-in ones cannot change)."
    private static let typeIcon = "An SF Symbol name, for example figure.boxing or dumbbell.fill."
    private static let typeColor = "A six-digit hex colour such as FF3B30."

    static var createWorkoutType: AgentTool {
        AgentTool(
            name: "create_workout_type",
            summary: "Create a custom workout type (for example Boxing or Wrestling). Workouts and pages can then be set to it with their type option; it appears in the app's type lists.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "name": AgentSchema.string("The type's name, shown in the app."),
                "icon": AgentSchema.string(typeIcon + " Default star.fill."),
                "color": AgentSchema.string(typeColor + " Default: the next colour of the palette."),
                "ifExists": AgentSchema.string("When a type with this name exists: error (default), or reuse it.", values: ["error", "reuse"]),
            ], required: ["name"])
        )
    }

    static var updateWorkoutType: AgentTool {
        AgentTool(
            name: "update_workout_type",
            summary: "Rename a custom workout type or change its icon or colour. Workouts that already use it keep the look they had.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "type": AgentSchema.string(typeRef),
                "name": AgentSchema.string("New name."),
                "icon": AgentSchema.string(typeIcon),
                "color": AgentSchema.string(typeColor),
            ], required: ["type"])
        )
    }

    static var deleteWorkoutType: AgentTool {
        AgentTool(
            name: "delete_workout_type",
            summary: "Remove a custom workout type from the lists. Workouts that already use it keep it.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object(["type": AgentSchema.string(typeRef)], required: ["type"])
        )
    }
}
