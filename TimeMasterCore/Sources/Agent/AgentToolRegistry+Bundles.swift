import Foundation

extension AgentToolRegistry {
    static var bundleTools: [AgentTool] { [addWorkoutSection, updateWorkoutSection, removeWorkoutSection, updateWorkout] }

    private static let workoutRef = "Workout id or exact name."
    private static let sectionRef = "Section position in the workout (1 is the first) or its exact name."

    static var bundleExerciseItem: [String: Any] {
        AgentSchema.object([
            "exercise": AgentSchema.string("Exercise page to run. \(pageRef)"),
            "name": AgentSchema.string("Label shown in the player; defaults to the exercise title."),
            "duration": AgentSchema.integer("Seconds this exercise runs, 1 or more; defaults to the exercise's duration.", minimum: 1),
            "restAfter": AgentSchema.integer("Rest in seconds after this exercise; 0 switches straight to the next one.", minimum: 0),
            "repCount": AgentSchema.integer("Target reps.", minimum: 1),
        ], required: ["exercise"])
    }

    static var bundleSpec: [String: Any] {
        AgentSchema.object([
            "exercises": AgentSchema.array(of: bundleExerciseItem, "Exercises played back to back in every set."),
            "sets": AgentSchema.integer("Rounds: every set plays all the exercises once (default 1).", minimum: 1, maximum: 50),
            "restBetweenSets": AgentSchema.integer("Rest in seconds between sets (default 30).", minimum: 0),
            "order": AgentSchema.string("ordered (default), or random to reshuffle the exercises each time the workout starts.", values: ["ordered", "random"]),
            "voice": AgentSchema.boolean("Speak each exercise name aloud (default true)."),
            "prepareTime": AgentSchema.integer("Get-ready seconds before each set (0-30, default 4).", minimum: 0, maximum: 30),
        ], "A bundle: several exercises played back to back for a number of sets, for example wrestling drills.")
    }

    static var sectionProperties: [String: [String: Any]] {
        [
            "exercise": AgentSchema.string("Exercise page for a timed section. \(pageRef) Give this or bundle."),
            "bundle": bundleSpec,
            "name": AgentSchema.string("Section label; defaults to the exercise title."),
            "duration": AgentSchema.integer("Seconds per set (timed section); defaults to the exercise's duration.", minimum: 5),
            "sets": AgentSchema.integer("Number of sets (timed section); defaults to the exercise's sets.", minimum: 1),
            "repCount": AgentSchema.integer("Target reps per set (timed section).", minimum: 1),
            "restBetweenSets": AgentSchema.integer("Rest between sets in seconds (timed section).", minimum: 0),
            "prepareTime": AgentSchema.integer("Preparation seconds before the section (timed section).", minimum: 0, maximum: 30),
            "restAfter": AgentSchema.integer("Rest in seconds after this section, before the next one; defaults to the workout's rest between sections.", minimum: 0),
        ]
    }

    static var sectionItem: [String: Any] { AgentSchema.object(sectionProperties) }

    static var buildWorkout: AgentTool {
        AgentTool(
            name: "build_workout",
            summary: "Create a workout from existing exercise pages, in order. A section is one timed exercise, or a bundle: several exercises played back to back for a number of sets.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "name": AgentSchema.string("Workout name."),
                "type": AgentSchema.string("Workout type name or id. Default Strength."),
                "restBetweenSections": AgentSchema.integer("Rest between sections in seconds (default 30).", minimum: 0),
                "sections": AgentSchema.array(of: sectionItem, "Ordered sections."),
            ], required: ["name", "sections"])
        )
    }

    static var listWorkouts: AgentTool {
        AgentTool(
            name: "list_workouts", summary: "List saved workouts with their duration, section count and bundle count.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([:])
        )
    }

    static var getWorkout: AgentTool {
        AgentTool(
            name: "get_workout", summary: "Read one workout and its sections in order, including each bundle's sets, order and exercises.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object(["workout": AgentSchema.string(workoutRef)], required: ["workout"])
        )
    }

    static var deleteWorkout: AgentTool {
        AgentTool(
            name: "delete_workout", summary: "Move a workout to the trash.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object(["workout": AgentSchema.string(workoutRef)], required: ["workout"])
        )
    }

    static var addWorkoutSection: AgentTool {
        var properties = sectionProperties
        properties["workout"] = AgentSchema.string(workoutRef)
        properties["position"] = AgentSchema.integer("Where to insert, 1 is first; omit to append.", minimum: 1)
        return AgentTool(
            name: "add_workout_section",
            summary: "Add a timed exercise section or a bundle to an existing workout.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["workout"])
        )
    }

    static var updateWorkoutSection: AgentTool {
        var properties = sectionProperties
        properties.removeValue(forKey: "exercise")
        properties["workout"] = AgentSchema.string(workoutRef)
        properties["section"] = AgentSchema.string(sectionRef)
        properties["position"] = AgentSchema.integer("Move the section to this position, 1 is first.", minimum: 1)
        properties["bundle"] = AgentSchema.object(
            (bundleSpec["properties"] as? [String: [String: Any]]) ?? [:],
            "Change a bundle section. Pass exercises to replace its exercises in every set; pass only sets, restBetweenSets, order, voice or prepareTime to keep them."
        )
        return AgentTool(
            name: "update_workout_section",
            summary: "Change one section of a workout, or move it. Only the fields you pass change.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["workout", "section"])
        )
    }

    static var removeWorkoutSection: AgentTool {
        AgentTool(
            name: "remove_workout_section",
            summary: "Remove one section (or bundle) from a workout. A workout keeps at least one section.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object([
                "workout": AgentSchema.string(workoutRef),
                "section": AgentSchema.string(sectionRef),
            ], required: ["workout", "section"])
        )
    }

    static var updateWorkout: AgentTool {
        AgentTool(
            name: "update_workout",
            summary: "Rename a workout or change its type or the rest between its sections.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "workout": AgentSchema.string(workoutRef),
                "name": AgentSchema.string("New workout name."),
                "type": AgentSchema.string("Workout type name or id."),
                "restBetweenSections": AgentSchema.integer("Rest between sections in seconds.", minimum: 0),
            ], required: ["workout"])
        )
    }
}
