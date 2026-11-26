import Foundation

extension AgentToolRegistry {
    static var recordTools: [AgentTool] {
        [
            listHistory, logWorkout, deleteHistoryEntry,
            listOutdoorActivities, getOutdoorActivity, updateOutdoorActivity, deleteOutdoorActivity,
            validateLibrary, createBackup, duplicateWorkout,
        ]
    }

    private static let outdoorRef = "Outdoor activity id from list_outdoor_activities."

    private static var listHistory: AgentTool {
        AgentTool(
            name: "list_history",
            summary: "List the workout history (completed workouts), newest first, each with the id delete_history_entry takes. at is local time with its UTC offset; seconds is the time actually trained; workout is the saved workout's id while that workout still exists; partial marks a workout stopped early.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([
                "days": AgentSchema.integer("Days to look back (default 30).", minimum: 1, maximum: 3650),
                "type": AgentSchema.string("Only this workout type (name or id)."),
                "limit": AgentSchema.integer("Most entries to return (1-200, default 30). The reply says how many more matched.", minimum: 1, maximum: 200),
            ])
        )
    }

    private static var logWorkout: AgentTool {
        AgentTool(
            name: "log_workout",
            summary: "Record a workout the user finished without the app, so it counts in the history, streaks and stats. Pass a saved workout (its name, type and length are filled in) or a name with the seconds. Undo takes the entry out again.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "workout": AgentSchema.string("Saved workout that was done: id or exact name."),
                "name": AgentSchema.string("Name to record. Defaults to the workout's name; required without a workout."),
                "completedAt": AgentSchema.string("When it was finished, ISO 8601: 2026-11-24T18:30 (local time), 2026-11-24T18:30+02:00, or a date alone for noon that day. Default now; a time in the future is refused."),
                "seconds": AgentSchema.integer("How long it took in seconds (1-86400). Defaults to the workout's planned length; required without a workout and for a partial one.", minimum: 1, maximum: 86400),
                "type": AgentSchema.string("Workout type name or id. Defaults to the workout's type, or Other."),
                "partial": AgentSchema.boolean("true when the user stopped early: seconds is then the time actually done."),
            ])
        )
    }

    private static var deleteHistoryEntry: AgentTool {
        AgentTool(
            name: "delete_history_entry",
            summary: "Delete one entry from the workout history. It stops counting for streaks and stats, and other devices drop it on the next sync. Undo puts it back where it was.",
            risk: .delete, executor: .core, coach: false,
            schema: AgentSchema.object(["id": AgentSchema.string("History entry id from list_history.")], required: ["id"])
        )
    }

    private static var listOutdoorActivities: AgentTool {
        AgentTool(
            name: "list_outdoor_activities",
            summary: "List recorded outdoor activities (runs, walks, bike rides), newest first: id, kind, title when it was renamed, start time (local, with its UTC offset), distance in km, elapsed seconds, starred, and finished false while one is unfinished.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([
                "kind": AgentSchema.string("Only this kind.", values: ["run", "walk", "runWalk", "bike"]),
                "days": AgentSchema.integer("Only the last N days.", minimum: 1, maximum: 3650),
                "limit": AgentSchema.integer("Most activities to return (1-200, default 30). The reply says how many more matched.", minimum: 1, maximum: 200),
            ])
        )
    }

    private static var getOutdoorActivity: AgentTool {
        AgentTool(
            name: "get_outdoor_activity",
            summary: "Read one outdoor activity: every field that is set, in compact form, and how many route points it recorded. The points themselves are listed only with points true, and then only an even sample.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([
                "id": AgentSchema.string(outdoorRef),
                "points": AgentSchema.boolean("true: add a sample of the route points (t seconds since the start, lat, lon, ele, speed)."),
                "limit": AgentSchema.integer("Points in the sample, spread evenly from the first to the last (1-200, default 20).", minimum: 1, maximum: 200),
            ], required: ["id"])
        )
    }

    private static var updateOutdoorActivity: AgentTool {
        AgentTool(
            name: "update_outdoor_activity",
            summary: "Change what the user can edit on a finished outdoor activity: title, kind, star, description and tags. Only what you pass changes. Visibility and the privacy settings stay in the app. Undo does not cover it.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "id": AgentSchema.string(outdoorRef),
                "title": AgentSchema.string("New title. Empty text goes back to the kind's name, such as Run."),
                "kind": AgentSchema.string("Change a run, walk or bike ride to another of the three.", values: ["run", "walk", "bike"]),
                "starred": AgentSchema.boolean("Star or unstar the activity."),
                "description": AgentSchema.string("Notes about the activity. Empty text clears them."),
                "tags": AgentSchema.strings("Replacement tags; [] clears them."),
            ], required: ["id"])
        )
    }

    private static var deleteOutdoorActivity: AgentTool {
        AgentTool(
            name: "delete_outdoor_activity",
            summary: "Move one outdoor activity and its recorded route to the library's .trash folder, so it leaves the Outdoor lists. It is not erased: restore it by moving its folder back out of .trash. Undo does not cover it.",
            risk: .delete, executor: .core, coach: false,
            schema: AgentSchema.object(["id": AgentSchema.string(outdoorRef)], required: ["id"])
        )
    }

    private static var validateLibrary: AgentTool {
        AgentTool(
            name: "validate_library",
            summary: "Check the manifest of every page and workout and report the totals and the first 50 problems: a manifest that cannot be read, or one that lacks a required field. Fields that are simply not set are not problems. History, settings and outdoor activities are not checked.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([:])
        )
    }

    private static var createBackup: AgentTool {
        AgentTool(
            name: "create_backup",
            summary: "Copy the library's data (pages with their media, workouts, outdoor activities, routes, history and the settings file) into a new folder under Backups, as a space-saving clone where the disk allows it. Returns the folder's name. Music and the legacy Media folder are not copied; old backups are never deleted automatically.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "label": AgentSchema.string("Short name added to the folder, for example before-cleanup (letters, digits and dashes, up to 40; default tmax)."),
            ])
        )
    }

    private static var duplicateWorkout: AgentTool {
        AgentTool(
            name: "duplicate_workout",
            summary: "Copy a workout under a new name: the same sections, sets and rests, with fresh ids. The copy lands in no group unless group is passed; the original and the groups stay as they were. Undo moves the copy to the trash.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "workout": AgentSchema.string("Workout id or exact name."),
                "name": AgentSchema.string("Name of the copy. Default '<name> Copy' (numbered when taken); a name you give must not exist yet."),
                "group": AgentSchema.string("Workout group id or exact title to put the copy at the end of (see list_workout_groups)."),
            ], required: ["workout"])
        )
    }
}
