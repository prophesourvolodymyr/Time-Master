import Foundation

public enum AgentToolRisk: String, Codable, CaseIterable {
    case read
    case write
    case delete

    public var isWrite: Bool { self != .read }
}

public enum AgentToolExecutor: String {
    case core
    case app
}

public struct AgentTool {
    public let name: String
    public let summary: String
    public let risk: AgentToolRisk
    public let executor: AgentToolExecutor
    public let coach: Bool
    public let schema: [String: Any]

    public var properties: [String: [String: Any]] {
        schema["properties"] as? [String: [String: Any]] ?? [:]
    }

    public var required: [String] {
        schema["required"] as? [String] ?? []
    }

    public var coachSchema: [String: Any] {
        AgentSchema.sanitizedForCoach(schema)
    }

    public func openAIDefinition() -> [String: Any] {
        ["type": "function", "function": ["name": name, "description": summary, "parameters": coachSchema] as [String: Any]]
    }

    public func anthropicDefinition() -> [String: Any] {
        ["name": name, "description": summary, "input_schema": coachSchema]
    }

    public func catalogEntry() -> [String: Any] {
        ["name": name, "description": summary, "risk": risk.rawValue, "inputSchema": schema]
    }
}

enum AgentSchema {
    static func string(_ description: String, values: [String]? = nil) -> [String: Any] {
        var out: [String: Any] = ["type": "string", "description": description]
        if let values { out["enum"] = values }
        return out
    }

    static func path(_ description: String) -> [String: Any] {
        ["type": "string", "description": description, "x-path": true]
    }

    static func integer(_ description: String, minimum: Int? = nil, maximum: Int? = nil) -> [String: Any] {
        var out: [String: Any] = ["type": "integer", "description": description]
        if let minimum { out["minimum"] = minimum }
        if let maximum { out["maximum"] = maximum }
        return out
    }

    static func boolean(_ description: String) -> [String: Any] {
        ["type": "boolean", "description": description]
    }

    static func strings(_ description: String) -> [String: Any] {
        ["type": "array", "description": description, "items": ["type": "string"] as [String: Any]]
    }

    static func array(of items: [String: Any], _ description: String) -> [String: Any] {
        ["type": "array", "description": description, "items": items]
    }

    static func object(_ properties: [String: [String: Any]], required: [String] = [], _ description: String? = nil) -> [String: Any] {
        var out: [String: Any] = ["type": "object", "properties": properties, "required": required]
        if let description { out["description"] = description }
        return out
    }

    static func external(_ schema: [String: Any]) -> [String: Any] {
        var out = schema
        out["x-external"] = true
        return out
    }

    static func sanitizedForCoach(_ value: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, item) in value where !key.hasPrefix("x-") {
            if key == "properties", let properties = item as? [String: [String: Any]] {
                var kept: [String: [String: Any]] = [:]
                for (name, property) in properties where property["x-external"] as? Bool != true {
                    kept[name] = sanitizedForCoach(property)
                }
                out[key] = kept
            } else if let nested = item as? [String: Any] {
                out[key] = sanitizedForCoach(nested)
            } else if key == "required", let names = item as? [String], let properties = value["properties"] as? [String: [String: Any]] {
                out[key] = names.filter { properties[$0]?["x-external"] as? Bool != true }
            } else {
                out[key] = item
            }
        }
        return out
    }
}

public enum AgentToolRegistry {
    static let pageRef = "Page UUID or title path such as 'Lower Body/Glutes'."
    static let typeText = "Workout type name or id (Strength, Stretch, Cardio, HIIT, Yoga, Face, Other, or a custom type). Applies to root pages; nested pages inherit it."
    static let noSkillsText = "True for a page that needs no sub-skills: it shows no skill board, progress, to-dos, milestones or learn-first list. False brings them back."

    /// The `widgets` argument of the page tools.
    static var pageWidgets: [String: Any] {
        AgentSchema.array(
            of: AgentSchema.string("A widget tile, or auto or none on its own.", values: ["auto", "none"] + PageWidgetKind.allCases.map(\.rawValue)),
            "The widget tiles above the page's tabs, in this order, each shown even when empty. [\"auto\"] (the default) shows only the tiles that have something to show; [] or [\"none\"] shows none. Exercises can show clips and workouts; skills and tutorials clips, progress, todos, milestones, learnFirst and workouts; folders clips, folder, progress and workouts."
        )
    }

    private static let baseTools: [AgentTool] = [
        contextTool, listPages, searchPages, getPage,
        createContainerPage, createExercisePage, attachMedia, addPageNote,
        updatePage, movePage, deletePage,
        buildWorkout, listWorkouts, getWorkout, deleteWorkout,
        getRecentWorkouts, getStats, listTypes,
        getSettings, updateSettings,
        importVideo, batch, undo,
    ]

    public static let tools: [AgentTool] = baseTools + bundleTools + workoutGroupTools + workoutTypeTools + milestoneTools + noteTools + skillTools + pageTagTools + skillTrainingTools + scheduleTools + pageContentTools + organizeTools + recordTools

    public static func tool(named name: String) -> AgentTool? {
        tools.first { $0.name == name }
    }

    public static func suggestions(for name: String) -> [String] {
        let lowered = name.lowercased()
        let close = tools.map(\.name).filter { $0.contains(lowered) || lowered.contains($0) || sharedPrefix($0, lowered) >= 4 }
        return Array(close.prefix(4))
    }

    public static func openAIDefinitions() -> [[String: Any]] {
        tools.filter(\.coach).map { $0.openAIDefinition() }
    }

    public static func anthropicDefinitions() -> [[String: Any]] {
        tools.filter(\.coach).map { $0.anthropicDefinition() }
    }

    public static func catalog() -> [[String: Any]] {
        tools.map { $0.catalogEntry() }
    }

    public static let schemaVersion: String = {
        let data = (try? JSONSerialization.data(withJSONObject: catalog(), options: [.sortedKeys])) ?? Data()
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }()

    public static let coachGuidance = """
    ## Tool use
    - Look before you write: call list_pages or search_pages and reference pages by the id they return. Never invent ids.
    - Exercise pages are workout-ready leaves; containers only organize. Put exercises inside the right container.
    - Note pages are Markdown documents with pictures inside the text; they are never exercises and never go into workouts. Write them with create_note_page. A note can sit in a folder or inside a skill or tutorial page.
    - Skill and tutorial pages (create_skill_page) are things to learn: Markdown notes, many video clips with a comment each, links, and sub-pages (sub-skills, exercises, notes). They sit in groups (create_skill_group) on their parent's skill board. Read them with get_page; search_pages also finds words inside notes and clip comments.
    - Tags sort pages into the columns of a folder's board, like the options of a Notion Select property (Morning flow, Evening stretch, Reference). The top folder of a tree keeps them (list_page_tags, create_page_tag) and every exercise and note below it shares them; put one on a page with the tag argument of update_page or the create tools. A tag is neither the workout type nor a completion status.
    - A workout section is one timed exercise or a bundle: several exercises played back to back for N sets. Drills played every few seconds are a bundle with short durations; read it back with get_workout.
    - Rep-based work (for example 12 push-ups) can be untimed: pass untimed true and each set runs until the user taps Done, with duration kept only as the estimate for totals.
    - The schedule is the Schedule page. get_schedule shows days with their entries and whether they are done; plans are weekly templates (create_schedule_plan, update_schedule_plan) that a week follows from select_schedule_plan on; add_schedule_entry, update_schedule_entry, remove_schedule_entry and complete_schedule_entry change single days or, with scope plan, the plan from that week on. Following a plan never rewrites earlier weeks.
    - Creating, editing and moving run immediately. Deleting asks the user to approve first; if the user declines, accept it and offer an alternative.
    - Keep arguments small and valid JSON. If a tool returns an error, read its hint and correct the call instead of repeating it.
    """

    private static func sharedPrefix(_ a: String, _ b: String) -> Int {
        zip(a, b).prefix { $0 == $1 }.count
    }

    private static var contextTool: AgentTool {
        AgentTool(
            name: "context", summary: "Overview of the exercise library, workout types, workouts and the conventions to follow. Call this first.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([:])
        )
    }

    private static var listPages: AgentTool {
        AgentTool(
            name: "list_pages", summary: "List pages in the exercise library as a tree. Omit parent for the root categories.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "parent": AgentSchema.string("Container to list. \(pageRef) Omit for root."),
                "depth": AgentSchema.integer("How many levels to include (1-6, default 1).", minimum: 1, maximum: 6),
                "limit": AgentSchema.integer("Most entries to return (1-300, default 60). The reply says how many more exist.", minimum: 1, maximum: 300),
            ])
        )
    }

    private static var searchPages: AgentTool {
        AgentTool(
            name: "search_pages", summary: "Search exercises and folders by title, notes or path, or list the pages wearing a tag. Returns ids to use in other tools.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "query": AgentSchema.string("Words to find in the title, notes or path. Pass an empty query together with tag to list every page wearing that tag."),
                "type": AgentSchema.string("Only pages with this workout type."),
                "kind": AgentSchema.string("Only this kind of page.", values: ["exercise", "container", "skill", "tutorial", "note"]),
                "tag": AgentSchema.string("Only pages wearing this tag (title or id, see list_page_tags)."),
                "limit": AgentSchema.integer("Maximum results (1-100, default 20). The reply says how many more matched.", minimum: 1, maximum: 100),
            ], required: ["query"])
        )
    }

    private static var getPage: AgentTool {
        AgentTool(
            name: "get_page", summary: "Read one page: notes, timing, links (with their comments and learn-first flags), media attachments (numbered, with caption, cover, icon picture and learn-first flags), its tag and icon, drop sets, the pages to learn first and the pages attached to it, child pages, dates, and its noSkills and widgets settings when set. Long notes come back in pieces; pass bodyOffset to read on.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "bodyOffset": AgentSchema.integer("Character to start the Markdown body at, from nextOffset of the previous reply (default 0).", minimum: 0),
            ], required: ["page"])
        )
    }

    private static var mediaItem: [String: Any] {
        AgentSchema.object([
            "path": AgentSchema.path("Absolute path to a local image (jpg, png, heic, gif, webp) or video (mp4, mov, m4v)."),
            "comment": AgentSchema.string("Caption shown under this attachment."),
        ], required: ["path"])
    }

    private static var createContainerPage: AgentTool {
        AgentTool(
            name: "create_container_page", summary: "Create a folder page that organizes other pages. Root folders own the workout type.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "title": AgentSchema.string("Folder title."),
                "parent": AgentSchema.string("Parent container. \(pageRef) Omit for a root category."),
                "workoutType": AgentSchema.string(typeText),
                "markdownBody": AgentSchema.string("Notes in Markdown."),
                "linkURLs": AgentSchema.strings("Reference links."),
                "media": AgentSchema.external(AgentSchema.array(of: mediaItem, "Local files to attach; the first is the cover.")),
                "noSkills": AgentSchema.boolean(noSkillsText),
                "widgets": pageWidgets,
                "ifExists": AgentSchema.string("When a sibling with this title exists: error (default), reuse it unchanged, or duplicate.", values: ["error", "reuse", "duplicate"]),
            ], required: ["title"])
        )
    }

    private static var createExercisePage: AgentTool {
        AgentTool(
            name: "create_exercise_page", summary: "Create a workout-ready exercise page with timing, notes and optional media. Its first media item is its cover.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "title": AgentSchema.string("Exercise name."),
                "parent": AgentSchema.string("Container to place it in. \(pageRef) Omit for the root."),
                "duration": AgentSchema.integer("Seconds per set (5 or more, default 30).", minimum: 5),
                "restAfter": AgentSchema.integer("Rest after the exercise in seconds.", minimum: 0),
                "sets": AgentSchema.integer("Default number of sets.", minimum: 1),
                "restBetweenSets": AgentSchema.integer("Rest between sets in seconds.", minimum: 0),
                "prepareTime": AgentSchema.integer("Preparation seconds (0-30).", minimum: 0, maximum: 30),
                "markdownBody": AgentSchema.string("Instructions and notes in Markdown."),
                "linkURLs": AgentSchema.strings("Reference links."),
                "workoutType": AgentSchema.string(typeText),
                "media": AgentSchema.external(AgentSchema.array(of: mediaItem, "Local files to attach; the first is the cover.")),
                "noSkills": AgentSchema.boolean(noSkillsText),
                "tag": AgentSchema.string(tagText),
                "widgets": pageWidgets,
                "ifExists": AgentSchema.string("When a sibling with this title exists: error (default), reuse it unchanged, or duplicate.", values: ["error", "reuse", "duplicate"]),
            ], required: ["title"])
        )
    }

    private static var attachMedia: AgentTool {
        AgentTool(
            name: "attach_media", summary: "Copy a local image or video into a page. Send the path, not the bytes; the app copies it.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "path": AgentSchema.path("Absolute path to the local file."),
                "comment": AgentSchema.string("Caption shown under the attachment."),
                "makeCover": AgentSchema.boolean("Move the attachment to the front so it becomes the cover."),
            ], required: ["page", "path"])
        )
    }

    private static var addPageNote: AgentTool {
        AgentTool(
            name: "add_page_note", summary: "Append a dated note to a page's Markdown notes. Existing text is kept.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "note": AgentSchema.string("Text to append."),
            ], required: ["page", "note"])
        )
    }

    private static var updatePage: AgentTool {
        AgentTool(
            name: "update_page", summary: "Change fields of an existing page. Only the fields you pass are replaced.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "title": AgentSchema.string("New title."),
                "markdownBody": AgentSchema.string("Replacement Markdown notes."),
                "icon": AgentSchema.string("Note, skill and tutorial pages only: an SF Symbol name or an emoji shown as the page's icon (on a note, on its row). Empty text clears it."),
                "iconImage": AgentSchema.external(AgentSchema.path("Absolute path to a local image (jpg, png, heic, gif, webp) the app copies into the page and uses as its icon picture (the small tile). Empty text clears the picture.")),
                "duration": AgentSchema.integer("Seconds per set (exercise pages).", minimum: 5),
                "restAfter": AgentSchema.integer("Rest after the exercise in seconds.", minimum: 0),
                "sets": AgentSchema.integer("Default number of sets.", minimum: 1),
                "restBetweenSets": AgentSchema.integer("Rest between sets in seconds.", minimum: 0),
                "prepareTime": AgentSchema.integer("Preparation seconds (0-30).", minimum: 0, maximum: 30),
                "dropSets": AgentSchema.array(of: dropSetItem, dropSetsText),
                "linkURLs": AgentSchema.strings("Replacement reference links."),
                "workoutType": AgentSchema.string(typeText),
                "tag": AgentSchema.string(tagText),
                "noSkills": AgentSchema.boolean(noSkillsText),
                "widgets": pageWidgets,
            ], required: ["page"])
        )
    }

    private static var movePage: AgentTool {
        AgentTool(
            name: "move_page", summary: "Move a page into another container, or to the root when newParent is omitted.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "newParent": AgentSchema.string("Destination container. \(pageRef) Omit for the root."),
            ], required: ["page"])
        )
    }

    private static var deletePage: AgentTool {
        AgentTool(
            name: "delete_page", summary: "Move a page and everything inside it to the trash. It can be restored from .trash.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object(["page": AgentSchema.string(pageRef)], required: ["page"])
        )
    }

    private static var getRecentWorkouts: AgentTool {
        AgentTool(
            name: "get_recent_workouts", summary: "Completed workouts from history.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object(["days": AgentSchema.integer("Days to look back (default 7).", minimum: 1, maximum: 3650)])
        )
    }

    private static var getStats: AgentTool {
        AgentTool(
            name: "get_stats", summary: "Workout count, current and best streak and total time, plus how many exercises exist.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "type": AgentSchema.string("Only this workout type."),
                "days": AgentSchema.integer("Only the last N days.", minimum: 1, maximum: 3650),
            ])
        )
    }

    private static var listTypes: AgentTool {
        AgentTool(
            name: "list_types", summary: "Built-in and custom workout types.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([:])
        )
    }

    private static var getSettings: AgentTool {
        AgentTool(
            name: "get_settings", summary: "User-safe app settings. API keys, credentials, file paths and music files are never returned.",
            risk: .read, executor: .app, coach: true,
            schema: AgentSchema.object([:])
        )
    }

    private static var updateSettings: AgentTool {
        AgentTool(
            name: "update_settings", summary: "Change supported app settings. Only change what the user explicitly asked for.",
            risk: .write, executor: .app, coach: true,
            schema: AgentSchema.object([
                "extraRestSeconds": AgentSchema.integer("Extra rest in seconds, a multiple of 5 from 5 to 120."),
                "motivationEnabled": AgentSchema.boolean("Speak motivation during workouts."),
                "motivationInterval": AgentSchema.integer("Seconds between motivation, a multiple of 5 from 30 to 120."),
                "notifications": AgentSchema.object([
                    "enabled": AgentSchema.boolean("Workout reminders on or off."),
                    "reminderHour": AgentSchema.integer("0 through 23.", minimum: 0, maximum: 23),
                    "reminderMinute": AgentSchema.integer("0 through 59.", minimum: 0, maximum: 59),
                    "reminderLeadMinutes": AgentSchema.integer("0 to 60 in five-minute steps.", minimum: 0, maximum: 60),
                    "streakMotivationEnabled": AgentSchema.boolean("Streak messages."),
                    "missedDayNudgesEnabled": AgentSchema.boolean("Missed-day nudges."),
                    "restDayAffirmationsEnabled": AgentSchema.boolean("Rest-day affirmations."),
                ]),
            ])
        )
    }

    private static var clipItem: [String: Any] {
        AgentSchema.object([
            "title": AgentSchema.string("Exercise name for this clip."),
            "start": ["type": "number", "description": "Clip start in seconds."] as [String: Any],
            "end": ["type": "number", "description": "Clip end in seconds."] as [String: Any],
            "comment": AgentSchema.string("Caption for the clip."),
            "markdownBody": AgentSchema.string("Notes for the exercise page."),
            "duration": AgentSchema.integer("Seconds per set for the exercise page.", minimum: 5),
            "linkURLs": AgentSchema.strings("Reference links for the exercise page."),
        ], required: ["title", "start", "end"])
    }

    private static var importVideo: AgentTool {
        AgentTool(
            name: "import_video", summary: "Download a video link or read a local video, cut named clips from it, and save each as an exercise page.",
            risk: .write, executor: .app, coach: false,
            schema: AgentSchema.object([
                "source": AgentSchema.path("http(s) video link, or an absolute local video path."),
                "parent": AgentSchema.string("Container for the new pages. \(pageRef) Omit for the root."),
                "clips": AgentSchema.array(of: clipItem, "Clips to cut. Omit to save the whole video as one page (requires title)."),
                "title": AgentSchema.string("Page title when saving the whole video."),
                "workoutType": AgentSchema.string(typeText),
                "ifExists": AgentSchema.string("When a sibling with a clip's title exists: error (default), reuse, or duplicate.", values: ["error", "reuse", "duplicate"]),
            ], required: ["source"])
        )
    }

    private static var batch: AgentTool {
        AgentTool(
            name: "batch", summary: "Run several library tools in order, for example update_page with tag for many pages. Later operations can use earlier results as \"$0.id\" (index) or \"$last.id\". If one fails, everything it created is rolled back, and tags it put on pages go back to what they were.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "operations": AgentSchema.array(of: AgentSchema.object([
                    "tool": AgentSchema.string("Library tool name."),
                    "arguments": AgentSchema.object([:], "Arguments for the tool."),
                ], required: ["tool"]), "Up to 100 operations."),
            ], required: ["operations"])
        )
    }

    private static var undo: AgentTool {
        AgentTool(
            name: "undo", summary: "Reverse the last agent change. Created pages, workouts and history entries are taken out again (pages and workouts go to the trash); edited pages, workouts, the schedule and the history go back to how they were; added media is removed; a deleted history entry is put back. Files already moved to the trash and deleted outdoor activities are not brought back by undo.",
            risk: .write, executor: .app, coach: false,
            schema: AgentSchema.object(["batch": AgentSchema.string("Batch id from an earlier result. Defaults to the most recent.")])
        )
    }
}
