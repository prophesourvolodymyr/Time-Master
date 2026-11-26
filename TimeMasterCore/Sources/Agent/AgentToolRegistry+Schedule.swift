import Foundation

extension AgentToolRegistry {
    static var scheduleTools: [AgentTool] {
        [
            getSchedule, listSchedulePlans, createSchedulePlan, updateSchedulePlan, deleteSchedulePlan, selectSchedulePlan,
            addScheduleEntry, addScheduleEntries, updateScheduleEntry, removeScheduleEntry, completeScheduleEntry, setTrainingDays,
        ]
    }

    private static let dayText = "A day as YYYY-MM-DD, or today, tomorrow or yesterday."
    private static let weekdayText = "A weekday: Mon to Sun (Monday to Sunday also work), or 1 (Monday) to 7 (Sunday)."
    private static let timeText = "Start time on 24 hours as HH:mm (07:30, 18:00); 7:30am also works. Empty text clears it."
    private static let planRef = "Plan id or exact name (see list_schedule_plans)."
    private static let entryRef = "Entry id, an occurrence id such as 2026-11-25/<entry id> as get_schedule shows it, or the exact title of an entry on that date."
    private static let scopeText = "day changes this day only; plan changes the entry inside the plan in use, from this week on (earlier weeks keep how they were)."

    private static var entryFields: [String: [String: Any]] {
        [
            "workout": AgentSchema.string("Workout id or exact name. Its name, length, exercise count, icon and colour fill the entry."),
            "title": AgentSchema.string("Entry title; defaults to the workout's name. Needed for a custom activity without a workout."),
            "start": AgentSchema.string(timeText),
            "minutes": AgentSchema.integer("Planned length in minutes; 0 clears it.", minimum: 0, maximum: 1440),
            "notes": AgentSchema.string("Notes shown with the entry."),
            "icon": AgentSchema.string("An SF Symbol name."),
            "color": AgentSchema.string("Colour as hex without #, for example FF6A00."),
            "exerciseCount": AgentSchema.integer("How many exercises the entry shows.", minimum: 0, maximum: 500),
        ]
    }

    private static var planEntry: [String: Any] {
        var properties = entryFields
        properties["id"] = AgentSchema.string("An existing entry's id from list_schedule_plans to keep it (fields you leave out stay); omit for a new entry.")
        properties["weekday"] = AgentSchema.string(weekdayText)
        return AgentSchema.object(properties, required: ["weekday"])
    }

    static var getSchedule: AgentTool {
        AgentTool(
            name: "get_schedule",
            summary: "Read the schedule day by day: each entry with its time, length, whether it is done, the plan in use this week, vacation weeks, the training days and the streak of weeks. Dates default to today.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "date": AgentSchema.string(dayText + " The first day to show; default today."),
                "days": AgentSchema.integer("How many days to show from date (1-31, default 7).", minimum: 1, maximum: 31),
            ])
        )
    }

    static var listSchedulePlans: AgentTool {
        AgentTool(
            name: "list_schedule_plans",
            summary: "List the saved schedule plans (weekly templates) with their entries by weekday, and which plan is in use this week.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "plan": AgentSchema.string("Only this plan. " + planRef),
            ])
        )
    }

    static var createSchedulePlan: AgentTool {
        AgentTool(
            name: "create_schedule_plan",
            summary: "Save a weekly plan: workouts on weekdays with optional times. Pass use to start following it from a week, as the app's Save and use does; earlier weeks never change.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "name": AgentSchema.string("Plan name, for example 'Boxing block'."),
                "icon": AgentSchema.string("An SF Symbol name for the plan."),
                "entries": AgentSchema.array(of: planEntry, "The plan's entries, each on a weekday."),
                "use": AgentSchema.boolean("Follow the plan from the week of from on."),
                "from": AgentSchema.string(dayText + " Any day of the first week the plan applies to when use is true; default this week."),
            ], required: ["name"])
        )
    }

    static var updateSchedulePlan: AgentTool {
        AgentTool(
            name: "update_schedule_plan",
            summary: "Rename a plan, change its icon, or change its entries (replace all, add some, remove some). A changed plan that is in use this week, or has from, is applied from that week on; earlier weeks keep their copy.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "plan": AgentSchema.string(planRef),
                "name": AgentSchema.string("New name."),
                "icon": AgentSchema.string("New SF Symbol name."),
                "entries": AgentSchema.array(of: planEntry, "Replace every entry of the plan."),
                "addEntries": AgentSchema.array(of: planEntry, "Entries to add."),
                "removeEntries": AgentSchema.strings("Ids of entries to take out of the plan."),
                "apply": AgentSchema.boolean("Apply the changed plan to the schedule from the week of from (default true when the plan is in use this week or from is given). false only saves the plan."),
                "from": AgentSchema.string(dayText + " Any day of the week the changed plan applies from; default this week."),
            ], required: ["plan"])
        )
    }

    static var deleteSchedulePlan: AgentTool {
        AgentTool(
            name: "delete_schedule_plan",
            summary: "Delete a saved plan. Weeks that already follow it keep their copy of it.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object(["plan": AgentSchema.string(planRef)], required: ["plan"])
        )
    }

    static var selectSchedulePlan: AgentTool {
        AgentTool(
            name: "select_schedule_plan",
            summary: "Choose the plan the schedule follows from a week on, or make that week and the following ones a vacation (no entries, the streak pauses) until another plan is chosen.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "plan": AgentSchema.string(planRef),
                "vacation": AgentSchema.boolean("Start a vacation instead of a plan."),
                "week": AgentSchema.string(dayText + " Any day of the week to switch from; default this week."),
            ])
        )
    }

    static var addScheduleEntry: AgentTool {
        var properties = entryFields
        properties["date"] = AgentSchema.string(dayText)
        properties["repeat"] = AgentSchema.boolean("Repeat every week on that weekday from that week on (it joins the plan in use; a plan called My Plan is made when none is). Without it the entry is only on that date.")
        properties["done"] = AgentSchema.boolean("Mark it done right away, for a workout already finished.")
        return AgentTool(
            name: "add_schedule_entry",
            summary: "Put a workout (or a custom activity) on a day of the schedule, once or every week.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["date"])
        )
    }

    static var addScheduleEntries: AgentTool {
        var properties = entryFields
        properties["date"] = AgentSchema.string(dayText)
        properties["done"] = AgentSchema.boolean("Mark it done right away.")
        return AgentTool(
            name: "add_schedule_entries",
            summary: "Put many workouts on specific dates of the schedule in one call, for a program spread over weeks (each entry is one-off, on its date). All are added or none; up to 200.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "entries": AgentSchema.array(of: AgentSchema.object(properties, required: ["date"]), "The entries, each with a date and a workout or a title."),
            ], required: ["entries"])
        )
    }

    static var updateScheduleEntry: AgentTool {
        var properties = entryFields
        properties["entry"] = AgentSchema.string(entryRef)
        properties["date"] = AgentSchema.string(dayText + " The day the entry is on; not needed with an occurrence id.")
        properties["scope"] = AgentSchema.string(scopeText, values: ["day", "plan"])
        properties["weekday"] = AgentSchema.string("scope plan only: move the entry to another weekday. " + weekdayText)
        properties["moveTo"] = AgentSchema.string("scope day only: move the entry to this date. " + dayText)
        return AgentTool(
            name: "update_schedule_entry",
            summary: "Change an entry of the schedule: its workout, title, time, length, notes, icon or colour, or move it to another day. Only what you pass changes.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["entry"])
        )
    }

    static var removeScheduleEntry: AgentTool {
        AgentTool(
            name: "remove_schedule_entry",
            summary: "Take an entry off the schedule: off one day only, or out of the plan in use from this week on.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object([
                "entry": AgentSchema.string(entryRef),
                "date": AgentSchema.string(dayText + " The day the entry is on; not needed with an occurrence id."),
                "scope": AgentSchema.string(scopeText, values: ["day", "plan"]),
            ], required: ["entry"])
        )
    }

    static var completeScheduleEntry: AgentTool {
        AgentTool(
            name: "complete_schedule_entry",
            summary: "Mark a schedule entry done or not done by hand. Without a mark an entry is done when a matching workout was completed that day.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "entry": AgentSchema.string(entryRef),
                "date": AgentSchema.string(dayText + " The day the entry is on; not needed with an occurrence id."),
                "done": AgentSchema.boolean("true (default) marks it done, false marks it not done."),
                "clear": AgentSchema.boolean("Forget the hand-made mark so the entry follows the workout history again."),
            ], required: ["entry"])
        )
    }

    static var setTrainingDays: AgentTool {
        AgentTool(
            name: "set_training_days",
            summary: "Choose the weekdays that must be trained to keep the weekly streak, from a week on (the default is Mon, Wed, Fri).",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "days": AgentSchema.strings("The training weekdays, for example [\"Mon\", \"Thu\", \"Sat\"]. " + weekdayText),
                "from": AgentSchema.string(dayText + " Any day of the first week they apply to; default this week."),
            ], required: ["days"])
        )
    }
}
