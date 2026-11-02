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
        case "get_recent_workouts": return ("Checking your recent workouts", nil)
        case "get_stats": return ("Checking your stats", nil)
        case "list_types": return ("Listing workout types", nil)
        case "get_settings": return ("Reading your settings", nil)
        case "update_settings": return ("Changing your settings", nil)
        default: return (sentence(tool), nil)
        }
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
