import Foundation

extension AgentToolRegistry {
    static var milestoneTools: [AgentTool] {
        [todoOverview, listTodos, addTodo, updateTodo, checkTodo, moveTodo, removeTodo]
    }

    static let checklistPageRef = "Skill or tutorial page. \(pageRef)"
    static let checklistItemRef = "The entry: its id or the start of it (list_todos shows #ids), or its exact title."

    private static var listArgument: [String: Any] {
        AgentSchema.string("Which list: todo (the default) or milestone (the big cards).", values: ["todo", "milestone"])
    }

    /// The fields an entry can wear, shared by add_todo and update_todo.
    private static var entryFields: [String: [String: Any]] {
        [
            "note": AgentSchema.string("A few lines about it (plain text)."),
            "icon": AgentSchema.string("An emoji or an SF Symbol name, or a picture of the page (its file name or media number). Empty text clears it."),
            "color": AgentSchema.string("Colour as six hex digits, like FF6A00. Empty text clears it."),
            "cover": AgentSchema.string("A picture of the page as the cover: its file name or its number in the page's media (list_todos shows them). Empty text clears it."),
            "images": AgentSchema.strings("Pictures of the page for the small strip: file names or media numbers (up to 6)."),
            "attachments": AgentSchema.strings("Files or links of the page shown as chips: file names, media numbers or link addresses."),
            "links": AgentSchema.strings("Web addresses (http or https) shown as chips."),
            "workouts": AgentSchema.strings("Workouts to link, by exact name or id. The first workout or page link lends the entry its picture when it has no cover or icon."),
            "pages": AgentSchema.strings("Database pages to link, by \(pageRef)"),
            "coverPath": AgentSchema.external(AgentSchema.path("Absolute path to a local picture the app copies into the page and uses as the cover.")),
            "imagePaths": AgentSchema.external(AgentSchema.array(of: AgentSchema.path("Absolute path to a local picture."), "Local pictures the app copies into the page and adds to the strip.")),
        ]
    }

    private static var todoOverview: AgentTool {
        AgentTool(
            name: "todo_overview", summary: "Every skill and tutorial page that has to-dos or milestones: how many are open, the next one, and links whose workout, page or file is gone.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "list": AgentSchema.string("Only this list: todo or milestone. Omit for both.", values: ["todo", "milestone"]),
                "query": AgentSchema.string("Only pages whose title or path contains these words."),
                "limit": AgentSchema.integer("Most pages to return (1-100, default 30).", minimum: 1, maximum: 100),
            ])
        )
    }

    private static var listTodos: AgentTool {
        AgentTool(
            name: "list_todos", summary: "Read a page's to-do list or milestones as a tree of lines with #ids, sections as '## Title', checked entries as [x], plus the page's media numbers for pictures.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(checklistPageRef),
                "list": listArgument,
                "done": AgentSchema.boolean("Include checked entries (default true)."),
                "limit": AgentSchema.integer("Most lines to return (1-300, default 120). The reply says how many more exist.", minimum: 1, maximum: 300),
            ], required: ["page"])
        )
    }

    private static var addTodo: AgentTool {
        var properties = entryFields
        properties["page"] = AgentSchema.string(checklistPageRef)
        properties["list"] = listArgument
        properties["title"] = AgentSchema.string("What to do, or the milestone's title, or the section's title.")
        properties["section"] = AgentSchema.boolean("Add a section divider (a title that splits the list into parts) instead of an entry.")
        properties["parent"] = AgentSchema.string("Nest it inside this entry. \(checklistItemRef)")
        properties["after"] = AgentSchema.string("Place it right after this entry, on the same level. \(checklistItemRef)")
        properties["inSection"] = AgentSchema.string("Add it at the end of this section's part: the section's id or title.")
        properties["done"] = AgentSchema.boolean("Add it already checked.")
        return AgentTool(
            name: "add_todo", summary: "Add a to-do, a milestone or a section divider to a skill or tutorial page, with optional note, icon, colour, cover, pictures, attachments and links to workouts, pages or the web.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["page", "title"])
        )
    }

    private static var updateTodo: AgentTool {
        var properties = entryFields
        properties["page"] = AgentSchema.string(checklistPageRef)
        properties["list"] = listArgument
        properties["item"] = AgentSchema.string(checklistItemRef)
        properties["title"] = AgentSchema.string("New title (renames a section too).")
        properties["section"] = AgentSchema.boolean("true turns a top-level entry into a section divider, false turns a section back into an entry.")
        return AgentTool(
            name: "update_todo", summary: "Change a to-do, milestone or section: title, note, icon, colour, cover, pictures, attachments or links. Each list you pass (images, attachments, links, workouts, pages) replaces that kind; the rest stays.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object(properties, required: ["page", "item"])
        )
    }

    private static var checkTodo: AgentTool {
        AgentTool(
            name: "check_todo", summary: "Check off a to-do or mark a milestone reached (everything under it too), or open it again (its parents open too).",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(checklistPageRef),
                "list": listArgument,
                "item": AgentSchema.string(checklistItemRef),
                "done": AgentSchema.boolean("true checks it (the default), false opens it again."),
            ], required: ["page", "item"])
        )
    }

    private static var moveTodo: AgentTool {
        AgentTool(
            name: "move_todo", summary: "Reorder, nest or un-nest an entry, or move it into another section's part. Give exactly one of parent, before, after, inSection, indent or outdent.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(checklistPageRef),
                "list": listArgument,
                "item": AgentSchema.string(checklistItemRef),
                "parent": AgentSchema.string("Nest it inside this entry, at its end. \"top\" moves it to the top level, at the end of the list."),
                "before": AgentSchema.string("Put it right before this entry, on that entry's level."),
                "after": AgentSchema.string("Put it right after this entry, on that entry's level."),
                "inSection": AgentSchema.string("Put it at the end of this section's part (section id or title); \"top\" is the part before the first section."),
                "indent": AgentSchema.boolean("Nest it inside the entry right above it."),
                "outdent": AgentSchema.boolean("Bring it back one level, right after the entry it was in."),
            ], required: ["page", "item"])
        )
    }

    private static var removeTodo: AgentTool {
        AgentTool(
            name: "remove_todo", summary: "Delete a to-do, milestone or section divider with everything nested inside it. A section goes alone; its entries join the part above. Pictures stay on the page.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object([
                "page": AgentSchema.string(checklistPageRef),
                "list": listArgument,
                "item": AgentSchema.string(checklistItemRef),
            ], required: ["page", "item"])
        )
    }
}
