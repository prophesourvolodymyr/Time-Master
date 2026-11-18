import Foundation

extension AgentToolRegistry {
    static var skillTools: [AgentTool] { [createSkillPage, createSkillGroup] }

    private static var skillMediaItem: [String: Any] {
        AgentSchema.object([
            "path": AgentSchema.path("Absolute path to a local image (jpg, png, heic, gif, webp) or video (mp4, mov, m4v)."),
            "comment": AgentSchema.string("Markdown comment shown with this attachment: what it shows, who made it, the cues it teaches."),
        ], required: ["path"])
    }

    private static var createSkillPage: AgentTool {
        AgentTool(
            name: "create_skill_page",
            summary: "Create a skill (or tutorial) page: something to learn and progress in. It keeps Markdown notes, many video clips with a comment each, links and sub-pages (sub-skills, exercises, notes). It sits in a group on its parent's skill board.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "title": AgentSchema.string("Skill name."),
                "parent": AgentSchema.string("Folder or skill to place it in. \(pageRef) Omit for the root."),
                "group": AgentSchema.string("Group (section) of the parent's skill board to put the skill in, for example 'Handstand'. Created when it does not exist. Needs a parent."),
                "pageType": AgentSchema.string("skill (default) or tutorial.", values: ["skill", "tutorial"]),
                "status": AgentSchema.string("Column on the skill board: notStarted (default), learning, completed or abandoned.", values: ["notStarted", "learning", "completed", "abandoned"]),
                "markdownBody": AgentSchema.string("Notes in Markdown: what the skill is, how to learn it, cues, mistakes."),
                "linkURLs": AgentSchema.strings("Reference links (videos, articles)."),
                "media": AgentSchema.external(AgentSchema.array(of: skillMediaItem, "Local files to attach (up to 100); the first is the cover. Each can carry a Markdown comment.")),
                "icon": AgentSchema.string("An SF Symbol name or an emoji; without one the app picks an icon from the title."),
                "tag": AgentSchema.string("A type of the parent skill's tree, by title or id (see list_page_tags with the parent as container). A skill straight inside a folder starts its own types: create the page first, then create_page_tag with it as container."),
                "noSkills": AgentSchema.boolean(noSkillsText),
                "widgets": pageWidgets,
                "ifExists": AgentSchema.string("When a sibling with this title exists: error (default), reuse it unchanged, or duplicate.", values: ["error", "reuse", "duplicate"]),
            ], required: ["title"])
        )
    }

    private static var createSkillGroup: AgentTool {
        AgentTool(
            name: "create_skill_group",
            summary: "Create a group (section) on the skill board of a folder or skill, with its own Markdown notes, so skills can be sorted into it.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "parent": AgentSchema.string("Folder or skill whose skill board gets the group. \(pageRef)"),
                "title": AgentSchema.string("Group name."),
                "markdownBody": AgentSchema.string("Notes of the group in Markdown."),
                "icon": AgentSchema.string("An SF Symbol name or an emoji for the group."),
                "color": AgentSchema.string("Strip colour as RRGGBB; without one the app picks a free colour."),
                "ifExists": AgentSchema.string("When the board already has a group with this title: error (default) or reuse it unchanged.", values: ["error", "reuse"]),
            ], required: ["parent", "title"])
        )
    }
}
