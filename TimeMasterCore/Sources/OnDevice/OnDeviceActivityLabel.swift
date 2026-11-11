import Foundation

public enum OnDeviceActivityLabel {
    public static func make(tool: String, arguments: [String: Any]) -> (title: String, detail: String?) {
        switch tool {
        case "list_pages": return ("Browsing your exercise library", text(arguments["parent"]))
        case "search_pages": return ("Searching your library", quoted(arguments["query"]))
        case "get_page": return ("Reading an exercise page", text(arguments["page"]))
        case "create_container_page": return ("Creating a folder", text(arguments["title"]))
        case "create_exercise_page": return ("Creating an exercise", text(arguments["title"]))
        case "add_page_note": return ("Adding a note", text(arguments["page"]))
        case "update_page": return ("Updating a page", text(arguments["page"]))
        case "move_page": return ("Moving a page", text(arguments["page"]))
        case "delete_page": return ("Deleting a page", text(arguments["page"]))
        case "build_workout": return ("Building a workout", text(arguments["name"]) ?? text(arguments["title"]))
        case "list_workouts": return ("Looking at your workouts", nil)
        case "get_workout": return ("Reading a workout", text(arguments["workout"]) ?? text(arguments["id"]))
        case "delete_workout": return ("Deleting a workout", text(arguments["workout"]) ?? text(arguments["id"]))
        case "add_workout_section": return ("Adding a workout section", text(arguments["workout"]))
        case "update_workout_section": return ("Changing a workout section", text(arguments["workout"]))
        case "remove_workout_section": return ("Removing a workout section", text(arguments["workout"]))
        case "update_workout": return ("Changing a workout", text(arguments["workout"]))
        case "get_recent_workouts": return ("Checking your recent workouts", nil)
        case "get_stats": return ("Checking your stats", nil)
        case "list_types": return ("Listing workout types", nil)
        case "get_settings": return ("Reading your settings", nil)
        case "update_settings": return ("Changing your settings", nil)
        case "todo_overview": return ("Looking over your to-dos and milestones", nil)
        case "list_todos": return (milestones(arguments) ? "Reading the milestones" : "Reading the to-do list", text(arguments["page"]))
        case "add_todo": return (milestones(arguments) ? "Adding a milestone" : "Adding a to-do", text(arguments["title"]))
        case "update_todo": return (milestones(arguments) ? "Changing a milestone" : "Changing a to-do", text(arguments["item"]))
        case "check_todo": return (milestones(arguments) ? "Marking a milestone" : "Checking off a to-do", text(arguments["item"]))
        case "move_todo": return (milestones(arguments) ? "Moving a milestone" : "Moving a to-do", text(arguments["item"]))
        case "remove_todo": return (milestones(arguments) ? "Deleting a milestone" : "Deleting a to-do", text(arguments["item"]))
        default: return (sentence(tool), nil)
        }
    }

    private static func milestones(_ arguments: [String: Any]) -> Bool {
        (arguments["list"] as? String)?.lowercased() == "milestone"
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : OnDeviceHistory.clipped(trimmed, to: 60)
    }

    private static func quoted(_ value: Any?) -> String? {
        text(value).map { "“\($0)”" }
    }

    private static func sentence(_ name: String) -> String {
        let words = name.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
