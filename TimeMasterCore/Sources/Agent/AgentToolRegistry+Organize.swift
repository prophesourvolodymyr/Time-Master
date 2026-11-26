import Foundation

extension AgentToolRegistry {
    static var organizeTools: [AgentTool] {
        [reorderPages, updateSkill, updateSkillGroup, deleteSkillGroup, duplicatePage, listTrash, restoreFromTrash]
    }

    private static let boardGroupRef = "Group title or id (get_page on the board's page lists its groups)."
    private static let skillStatusWords = "notStarted, learning, completed or abandoned; the words the app shows (Not Started, Learning, Completed, Abandoned) work too, in any letter case."

    private static var reorderPages: AgentTool {
        AgentTool(
            name: "reorder_pages",
            summary: "Put the pages directly inside one folder (or at the top of the library) in a new order. List the pages you want first, in order; pages you leave out keep their current order after them. A skill's place inside its group on a skill board is set with update_skill instead.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "parent": AgentSchema.string("Container whose pages to order. \(pageRef) Omit for the top level of the library."),
                "order": AgentSchema.strings("Pages directly inside that container, by title or id, in the order wanted."),
            ], required: ["order"])
        )
    }

    private static var updateSkill: AgentTool {
        AgentTool(
            name: "update_skill",
            summary: "Change where a skill or tutorial page stands on its parent's skill board: its status (the board column), its group, or its place inside the group's column. Only what you pass changes. A skill that changes group or status goes to the end of its new column unless position is given.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string("Skill or tutorial page. \(pageRef)"),
                "status": AgentSchema.string("Board column: \(skillStatusWords)"),
                "group": AgentSchema.string("Group of the parent's skill board to put the skill in, by title or id; none or empty text takes it out of every group. A skill at the top of the library has no groups."),
                "position": AgentSchema.integer("Place among the skills of the same group and status, 1 is the first (past the end means last).", minimum: 1),
            ], required: ["page"])
        )
    }

    private static var updateSkillGroup: AgentTool {
        AgentTool(
            name: "update_skill_group",
            summary: "Rename a group of a skill board, change its notes, icon or colour, or move it among the groups. Only what you pass changes.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "container": AgentSchema.string("Folder or skill whose skill board holds the group. \(pageRef)"),
                "group": AgentSchema.string(boardGroupRef),
                "title": AgentSchema.string("New group name."),
                "markdownBody": AgentSchema.string("Replacement notes of the group in Markdown. Empty text clears them."),
                "icon": AgentSchema.string("An SF Symbol name or an emoji. Empty text clears it."),
                "color": AgentSchema.string("Strip colour as RRGGBB, without #. Empty text clears it."),
                "position": AgentSchema.integer("Place among the board's groups, 1 is the first (past the end means last).", minimum: 1),
            ], required: ["container", "group"])
        )
    }

    private static var deleteSkillGroup: AgentTool {
        AgentTool(
            name: "delete_skill_group",
            summary: "Remove a group from a skill board. The skills in it are kept: they move to no group, after the skills already outside any group. The group's own notes, links, clips and pictures are removed with it (its files go to the trash).",
            risk: .delete, executor: .core, coach: false,
            schema: AgentSchema.object([
                "container": AgentSchema.string("Folder or skill whose skill board holds the group. \(pageRef)"),
                "group": AgentSchema.string(boardGroupRef),
            ], required: ["container", "group"])
        )
    }

    private static var duplicatePage: AgentTool {
        AgentTool(
            name: "duplicate_page",
            summary: "Copy a page: new id and dates, same fields, notes, links, clips and pictures. By default the copy sits right after the original and is titled with Copy added; a skill keeps its group and tag when the copy stays on the same board. The sub-pages of a folder or skill are copied only with deep.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "title": AgentSchema.string("Title of the copy. Default: the original title followed by Copy. A number is added when a page there already has the title."),
                "parent": AgentSchema.string("Container for the copy. \(pageRef) Omit to keep the original's container, with the copy right after the original. A copy placed in another container goes to its end and leaves its group; a tag stays only when the new tree has it."),
                "deep": AgentSchema.boolean("Also copy every page inside a folder or skill, at any depth (at most 200 pages in all). Default false copies the page alone."),
            ], required: ["page"])
        )
    }

    private static var listTrash: AgentTool {
        AgentTool(
            name: "list_trash",
            summary: "List the pages and workouts in the trash, newest first: the id to give restore_from_trash, the kind, the title, when it was deleted and, for a page, the path it came from.",
            risk: .read, executor: .core, coach: false,
            schema: AgentSchema.object([
                "limit": AgentSchema.integer("Most entries to return (1-500, default 50). The reply says how many more exist.", minimum: 1, maximum: 500),
            ])
        )
    }

    private static var restoreFromTrash: AgentTool {
        AgentTool(
            name: "restore_from_trash",
            summary: "Bring a page (with everything inside it) or a workout back from the trash. A page returns to the folder it came from when that still exists, otherwise to the top level of the library. Nothing that exists is overwritten.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "item": AgentSchema.string("Entry id from list_trash. The id of the deleted page or workout works too when only one deleted copy exists."),
                "parent": AgentSchema.string("Pages only: container to restore into. \(pageRef) Omit to use the original folder."),
            ], required: ["item"])
        )
    }
}
