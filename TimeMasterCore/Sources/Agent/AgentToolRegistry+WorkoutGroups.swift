import Foundation

extension AgentToolRegistry {
    static var workoutGroupTools: [AgentTool] { [listWorkoutGroups, createWorkoutGroup, updateWorkoutGroup, deleteWorkoutGroup] }

    private static let groupRef = "Workout group id or exact title."
    private static let groupIcon = "An SF Symbol name (for example 1.circle.fill) or one emoji."
    private static let groupWorkouts = "Workouts by id or exact name, in the order they should appear. A workout lives in one group, so it leaves its old group."

    static var listWorkoutGroups: AgentTool {
        AgentTool(
            name: "list_workout_groups",
            summary: "List the titled groups on the Workouts page (the user calls them sections) in their order, with each group's workouts in order, plus the workouts in no group.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([:])
        )
    }

    static var createWorkoutGroup: AgentTool {
        AgentTool(
            name: "create_workout_group",
            summary: "Create a titled group on the Workouts page (the user calls it a section) and optionally put workouts into it. These groups organize whole workouts; they are not the sections inside a workout.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "title": AgentSchema.string("Group title, for example 'Week 1'."),
                "icon": AgentSchema.string(groupIcon),
                "workouts": AgentSchema.strings(groupWorkouts),
                "position": AgentSchema.integer("Where the group goes among the groups, 1 is the top; omit to add it at the bottom.", minimum: 1),
                "ifExists": AgentSchema.string("When a group with this title exists: error (default), or reuse it (its workouts are added).", values: ["error", "reuse"]),
            ], required: ["title"])
        )
    }

    static var updateWorkoutGroup: AgentTool {
        AgentTool(
            name: "update_workout_group",
            summary: "Rename a group on the Workouts page, change its icon, move it, or add and remove workouts. Only what you pass changes.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "group": AgentSchema.string(groupRef),
                "title": AgentSchema.string("New title."),
                "icon": AgentSchema.string(groupIcon + " Empty text clears it."),
                "position": AgentSchema.integer("Move the group to this place among the groups, 1 is the top.", minimum: 1),
                "addWorkouts": AgentSchema.strings(groupWorkouts + " They are added at the end."),
                "removeWorkouts": AgentSchema.strings("Workouts to take out of the group; they stay saved, in no group."),
                "workoutOrder": AgentSchema.strings("The group's workouts in their new order; every workout of the group must be listed."),
            ], required: ["group"])
        )
    }

    static var deleteWorkoutGroup: AgentTool {
        AgentTool(
            name: "delete_workout_group",
            summary: "Remove a group from the Workouts page. Its workouts are kept and move to no group.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object(["group": AgentSchema.string(groupRef)], required: ["group"])
        )
    }
}
