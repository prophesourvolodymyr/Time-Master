import Foundation

public enum OnDeviceToolRouting {
    public static let maximumTools = 4
    public static let parameters: [String: [String]] = [
        "list_pages": ["parent"],
        "search_pages": ["query"],
        "get_page": ["page"],
        "add_page_note": ["page", "note"],
        "list_workouts": [],
        "get_workout": ["workout"],
        "get_recent_workouts": ["days"],
        "get_stats": [],
        "list_types": [],
        "get_settings": [],
    ]
    public static let defaults: [String: [String: Int]] = [
        "list_pages": ["limit": 15],
        "search_pages": ["limit": 10],
    ]
    public static var toolNames: Set<String> { Set(parameters.keys) }
    public static let fallback = ["search_pages", "list_workouts", "get_recent_workouts", "get_stats"]

    private struct Intent {
        let keywords: [String]
        let tools: [String]
    }

    private static let intents: [Intent] = [
        Intent(
            keywords: ["delete", "remove", "trash", "erase", "rename", "change", "update", "edit", "move", "reorder", "create", "build a workout", "make a workout", "add an exercise", "add exercise", "new exercise", "new folder", "new workout", "put together"],
            tools: ["search_pages", "list_workouts"]
        ),
        Intent(
            keywords: ["setting", "preference", "volume", "sound", "haptic", "voice", "countdown", "rest time"],
            tools: ["get_settings"]
        ),
        Intent(
            keywords: ["note", "jot", "remember", "write down"],
            tools: ["add_page_note", "search_pages", "get_page"]
        ),
        Intent(
            keywords: ["history", "recent", "last workout", "yesterday", "today", "this week", "last week", "this month", "streak", "stats", "progress", "how many", "how long", "did i", "have i", "total time"],
            tools: ["get_recent_workouts", "get_stats", "list_workouts"]
        ),
        Intent(
            keywords: ["workout", "routine"],
            tools: ["list_workouts", "get_workout", "get_recent_workouts"]
        ),
        Intent(
            keywords: ["type", "kind of workout"],
            tools: ["list_types", "list_pages"]
        ),
        Intent(
            keywords: ["exercise", "page", "folder", "library", "category", "categories", "stretch", "muscle", "technique", "how do i", "how to"],
            tools: ["search_pages", "get_page", "list_pages"]
        ),
    ]

    public static func tools(for message: String) -> [String] {
        let lowered = message.lowercased()
        let words = lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var chosen: [String] = []
        for intent in intents where intent.keywords.contains(where: { matches($0, in: lowered, words: words) }) {
            for tool in intent.tools where !chosen.contains(tool) {
                chosen.append(tool)
            }
            if chosen.count >= maximumTools { break }
        }
        return Array((chosen.isEmpty ? fallback : chosen).prefix(maximumTools))
    }

    private static func matches(_ keyword: String, in text: String, words: [String]) -> Bool {
        if keyword.contains(" ") { return text.contains(keyword) }
        return words.contains { $0 == keyword || ($0.hasPrefix(keyword) && $0.count <= keyword.count + 2) }
    }
}
