import Foundation

extension AgentToolRegistry {
    static var pageTagTools: [AgentTool] { [listPageTags, createPageTag, updatePageTag, deletePageTag] }

    /// The `tag` argument of the page tools.
    static let tagText = "A tag the page wears, by title or id (see list_page_tags); empty text removes it. Exercise and note pages take the tags of the top folder of their tree, skill and tutorial pages the types of their own skill. A tag is not the workout type."

    private static let tagContainerText = "Folder (or any page inside it) whose tags these are. The top folder of its tree keeps the tags of every exercise and note below it; a skill or a tutorial keeps the types of its sub-skills. \(pageRef)"

    private static var listPageTags: AgentTool {
        AgentTool(
            name: "list_page_tags",
            summary: "List the tags pages can wear, like the options of a Notion Select property: the presets of the page that keeps them, each with its tags (id, title, colour, icon) and how many pages wear each, plus how many are untagged. Tags sort pages into the columns of a folder's board (Morning flow, Evening stretch); they are not workout types and not a completion status.",
            risk: .read, executor: .core, coach: true,
            schema: AgentSchema.object([
                "container": AgentSchema.string(tagContainerText),
            ], required: ["container"])
        )
    }

    private static var createPageTag: AgentTool {
        AgentTool(
            name: "create_page_tag",
            summary: "Create a tag pages can wear. The top folder of the tree keeps it and every exercise and note below that folder shares it. Put it on pages with update_page, create_exercise_page, create_note_page or create_skill_page and their tag argument.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "container": AgentSchema.string(tagContainerText),
                "title": AgentSchema.string("Tag name, for example 'Morning flow'."),
                "color": AgentSchema.string("Colour as RRGGBB; without one the app picks a free colour."),
                "icon": AgentSchema.string("An SF Symbol name or an emoji."),
                "preset": AgentSchema.string("Preset (the Select property, for example 'Routine') to put the tag in, by title or id; created when it does not exist. Omit to use the first preset (one called 'Tags' is made when there is none)."),
                "ifExists": AgentSchema.string("When a tag with this title already exists: error (default) or reuse it unchanged.", values: ["error", "reuse"]),
            ], required: ["container", "title"])
        )
    }

    private static var updatePageTag: AgentTool {
        AgentTool(
            name: "update_page_tag",
            summary: "Rename a tag or change its colour or icon. Pages that wear it keep it.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "container": AgentSchema.string(tagContainerText),
                "tag": AgentSchema.string("The tag to change, by title or id."),
                "title": AgentSchema.string("New name."),
                "color": AgentSchema.string("New colour as RRGGBB."),
                "icon": AgentSchema.string("New SF Symbol name or emoji; empty text removes the icon."),
            ], required: ["container", "tag"])
        )
    }

    private static var deletePageTag: AgentTool {
        AgentTool(
            name: "delete_page_tag",
            summary: "Delete a tag. Every page that wore it becomes untagged; the pages themselves stay.",
            risk: .delete, executor: .core, coach: true,
            schema: AgentSchema.object([
                "container": AgentSchema.string(tagContainerText),
                "tag": AgentSchema.string("The tag to delete, by title or id."),
            ], required: ["container", "tag"])
        )
    }
}
