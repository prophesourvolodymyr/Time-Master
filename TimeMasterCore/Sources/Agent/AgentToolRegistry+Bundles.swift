import Foundation

extension AgentToolRegistry {
    static var bundleTools: [AgentTool] { [addWorkoutSection, updateWorkoutSection, removeWorkoutSection, updateWorkout, foldRestFillers] }

    private static let workoutRef = "Workout id or exact name."
    private static let sectionRef = "Section position in the workout (1 is the first) or its exact name."

    static var bundleExerciseItem: [String: Any] {
        AgentSchema.object([
            "exercise": AgentSchema.string("Exercise page to run. \(pageRef) Give this or callout."),
            "callout": AgentSchema.string("A spoken phrase instead of an exercise, for example \"Switch stance\"; it plays for duration seconds (default 5) with no rest after it unless restAfter says so."),
            "name": AgentSchema.string("Label shown in the player; defaults to the exercise title."),
            "duration": AgentSchema.integer("Seconds this exercise runs, 1 or more; defaults to the exercise's duration.", minimum: 1),
            "restAfter": AgentSchema.integer("Rest in seconds after this exercise; 0 switches straight to the next one.", minimum: 0),
            "restExercise": AgentSchema.strings("Exercise played during the rest after this exercise; pass several to let the user choose, the first is the default. restAfter must be at least as long as each exercise's duration. \(pageRef) Pass \"\" to remove."),
            "repCount": AgentSchema.integer("Target reps.", minimum: 1),
        ])
    }

    private static let colorText = "Icon color of the workout as six hex digits (RRGGBB), for example FF9500; the app's Icon Color setting."
    private static let coverText = "What the workout card shows: exerciseThumbnails (the first exercises, default) or icon (the workout type's icon). A picture the user chose in the app is kept."

    static var bundleSpec: [String: Any] {
        AgentSchema.object([
            "exercises": AgentSchema.array(of: bundleExerciseItem, "Exercises (or callouts) played back to back in every set."),
            "sets": AgentSchema.integer("Rounds: every set plays all the exercises once (default 1).", minimum: 1, maximum: 50),
            "restBetweenSets": AgentSchema.integer("Rest in seconds between sets (default 30).", minimum: 0),
            "order": AgentSchema.string("ordered (default), or random to reshuffle the exercises each time the workout starts.", values: ["ordered", "random"]),
            "voice": AgentSchema.boolean("Speak each exercise name aloud (default true)."),
            "prepareTime": AgentSchema.integer("Get-ready seconds before each set (0-30, default 4).", minimum: 0, maximum: 30),
        ], "A bundle: several exercises played back to back for a number of sets, for example wrestling drills. Never a bundle for one exercise: use a timed section and its restExercise for a move between sets. Called punches are a combo, not a bundle.")
    }

    static var comboProperties: [String: [String: Any]] {
        [
            "calls": AgentSchema.strings("The calls of every round, one string per call, moves joined by dashes: \"1-2\", \"1-2-3\", \"1-1-2-slip\" (\"1 2 3\", \"123\" and \"1,2,slip\" read the same). Moves: \(AgentCombo.moveGuide); up to \(AgentCombo.longestCall) moves per call. Required when creating; when updating it replaces the calls of every round."),
            "rounds": AgentSchema.integer("Rounds: every round plays all the calls once (default \(AgentCombo.defaultRounds)).", minimum: 1, maximum: 50),
            "secondsPerCall": AgentSchema.integer("Seconds each call lasts (default \(AgentCombo.defaultSeconds)).", minimum: 1, maximum: 120),
            "restBetweenRounds": AgentSchema.integer("Rest in seconds between rounds (default \(AgentCombo.defaultRest)).", minimum: 0, maximum: 120),
            "icon": AgentSchema.string("Corner icon: an SF Symbol name such as flame.fill, or one emoji. Empty text clears it."),
            "name": AgentSchema.string("Section label (default \(AgentCombo.defaultName)); the same as name on the section."),
            "order": AgentSchema.string("ordered (default), or random to reshuffle the calls each time the workout starts.", values: ["ordered", "random"]),
            "voice": AgentSchema.boolean("Say each call aloud (default true)."),
        ]
    }

    static var comboSpec: [String: Any] {
        AgentSchema.object(comboProperties, "A Boxing combo: rounds of called moves such as 1-2 (jab, cross) that the app says aloud. Every round plays all the calls once. Use this, never bundle, for called punches.")
    }

    static var sectionProperties: [String: [String: Any]] {
        [
            "exercise": AgentSchema.string("Exercise page for a timed section. \(pageRef) Give this, bundle or combo."),
            "bundle": bundleSpec,
            "combo": comboSpec,
            "name": AgentSchema.string("Section label; defaults to the exercise title."),
            "duration": AgentSchema.integer("Seconds per set (timed section); defaults to the exercise's duration. With untimed it is only the estimate used for totals.", minimum: 5),
            "sets": AgentSchema.integer("Number of sets (timed section); defaults to the exercise's sets.", minimum: 1),
            "repCount": AgentSchema.integer("Target reps per set (timed section).", minimum: 1),
            "restBetweenSets": AgentSchema.integer("Rest between sets in seconds (timed section).", minimum: 0),
            "prepareTime": AgentSchema.integer("Preparation seconds before the section (timed section or combo; a combo's default is \(AgentCombo.defaultPrepare)).", minimum: 0, maximum: 30),
            "restAfter": AgentSchema.integer("Rest in seconds after this section, before the next one; defaults to the workout's rest between sections.", minimum: 0),
            "untimed": AgentSchema.boolean("true: no countdown, every set (or bundle exercise) runs until the user taps Done; good for rep-based exercises. false (default): sets count down their duration."),
            "restExercise": AgentSchema.strings("Exercise played during every rest between sets, timed section or bundle; pass several to let the user choose, the first is the default. It needs sets above 1 and restBetweenSets at least as long as each exercise's duration. \(pageRef) Pass \"\" to remove."),
            "restAfterExercise": AgentSchema.strings("Exercise played during the rest after this section (any section); pass several to let the user choose, the first is the default. It needs restAfter at least as long as each exercise's duration; the last section has no rest after it. \(pageRef) Pass \"\" to remove."),
        ]
    }

    static var sectionItem: [String: Any] { AgentSchema.object(sectionProperties) }

    static var buildWorkout: AgentTool {
        AgentTool(
            name: "build_workout",
            summary: "Create a workout from existing exercise pages, in order. A section is one timed exercise (its rests can hold a rest exercise), a bundle: several exercises played back to back for a number of sets, or a Boxing combo of called moves.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "name": AgentSchema.string("Workout name."),
                "type": AgentSchema.string("Workout type name or id. Default Strength."),
                "restBetweenSections": AgentSchema.integer("Rest between sections in seconds (default 30).", minimum: 0),
                "colorHex": AgentSchema.string(colorText),
                "coverStyle": AgentSchema.string(coverText, values: ["exerciseThumbnails", "icon"]),
                "sections": AgentSchema.array(of: sectionItem, "Ordered sections."),
            ], required: ["name", "sections"])
        )
    }

    static var listWorkouts: AgentTool {
        AgentTool(
            name: "list_workouts", summary: "List saved workouts with their duration, section count, bundle count and combo count.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([:])
        )
    }

    static var getWorkout: AgentTool {
        AgentTool(
            name: "get_workout", summary: "Read one workout and its sections in order, including each bundle's sets, order and exercises, and each combo's rounds, calls and timings (kind combo).",
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
            summary: "Add a timed exercise section, a bundle or a Boxing combo to an existing workout.",
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
        properties["combo"] = AgentSchema.object(
            comboProperties,
            "Change a combo section (kind combo in get_workout). Only the keys you pass change; calls replaces the calls of every round and keeps the rounds, rests and icon. Use this instead of bundle for a combo."
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
            summary: "Remove one section (a timed exercise, bundle or combo) from a workout. A workout keeps at least one section.",
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
            summary: "Rename a workout or change its type, the rest between its sections, its icon color or its cover style.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "workout": AgentSchema.string(workoutRef),
                "name": AgentSchema.string("New workout name."),
                "type": AgentSchema.string("Workout type name or id."),
                "restBetweenSections": AgentSchema.integer("Rest between sections in seconds.", minimum: 0),
                "colorHex": AgentSchema.string(colorText),
                "coverStyle": AgentSchema.string(coverText, values: ["exerciseThumbnails", "icon"]),
            ], required: ["workout"])
        )
    }

    static var foldRestFillers: AgentTool {
        AgentTool(
            name: "fold_rest_fillers",
            summary: "Turn filler exercises inside bundles (children named like 'Between sets: Leg Swings') into rest exercises. Each filler moves into the rest after the exercise before it; a bundle left with one exercise per set becomes a timed section.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "workout": AgentSchema.string("Workout id or exact name; omit to go through every workout."),
                "prefix": AgentSchema.string("Filler children start with this text (default \"Between sets\")."),
                "keepNames": AgentSchema.boolean("true: keep section names as they are. false (default): drop a note like '(leg swings between, 60 s)' from the name once the rest holds the exercise."),
            ])
        )
    }
}
