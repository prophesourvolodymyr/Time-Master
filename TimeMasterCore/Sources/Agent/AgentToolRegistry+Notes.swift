import Foundation

extension AgentToolRegistry {
    static var noteTools: [AgentTool] { [createNotePage] }

    private static var createNotePage: AgentTool {
        AgentTool(
            name: "create_note_page", summary: "Create a note page: a title and a Markdown document with pictures inside the text. Notes are never exercises and never go into workouts.",
            risk: .write, executor: .core, coach: true,
            schema: AgentSchema.object([
                "title": AgentSchema.string("Note title."),
                "parent": AgentSchema.string("Folder to place it in. \(pageRef) Omit for the root. Notes cannot live inside exercises, skills or tutorials."),
                "markdownBody": AgentSchema.string("The document in Markdown: headings, lists, - [ ] to-dos, quotes, code, links."),
                "images": AgentSchema.external(AgentSchema.array(of: AgentSchema.path("Absolute path to a local picture (jpg, png, heic, gif, webp)."), "Pictures the app copies into the note and shows after the body, in this order.")),
                "icon": AgentSchema.string("An SF Symbol name or an emoji shown on the note's row."),
                "ifExists": AgentSchema.string("When a sibling with this title exists: error (default), reuse it unchanged, or duplicate.", values: ["error", "reuse", "duplicate"]),
            ], required: ["title"])
        )
    }
}
