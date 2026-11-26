import Foundation

extension AgentToolRegistry {
    static var pageContentTools: [AgentTool] { [updateMedia, removeMedia, updateLink, updateLearnFirst, updateLinkedPages] }

    private static let mediaNumberText = "The attachment's number in the page's media list (get_page shows it as index), 1 for the first."
    private static let pageListText = "Pages by id or title path (several allowed)."

    static var dropSetItem: [String: Any] {
        AgentSchema.object([
            "set": AgentSchema.integer("The set it follows, 1 for the first set (default: the page's last set). The page needs at least that many sets.", minimum: 1),
            "name": AgentSchema.string("Name of the drop-set exercise. Needed without exercise; with exercise it defaults to that page's title."),
            "duration": AgentSchema.integer("Seconds it lasts, 5 to 600 (default: the exercise page's duration, else 30).", minimum: 5, maximum: 600),
            "restAfter": AgentSchema.integer("Rest after it in seconds, 0 to 120 (default: the exercise page's rest, else 0).", minimum: 0, maximum: 120),
            "exercise": AgentSchema.string("An exercise page to take the drop from. \(pageRef)"),
        ])
    }

    static let dropSetsText = "Exercise pages only: replace the page's drop sets, the extra exercises played after a set when the page goes into a workout. Pass the complete list; [] clears them."

    private static var updateMedia: AgentTool {
        AgentTool(
            name: "update_media",
            summary: "Change one attachment of a page, found by its number in get_page's media list (1 is the first): its caption, its place (position 1 makes it the first file, which is the cover unless a banner was chosen), whether it is the banner or the icon picture, and on skills and tutorials whether it is a file to learn first. Only what you pass changes. Notes keep their pictures inside the Markdown and have no attachments.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "index": AgentSchema.integer(mediaNumberText, minimum: 1),
                "comment": AgentSchema.string("New caption in Markdown. Empty text clears it."),
                "position": AgentSchema.integer("Move the attachment to this place, 1 for the front. The others shift; a number past the end puts it last.", minimum: 1),
                "learnFirst": AgentSchema.boolean("Skills and tutorials: true flags the file as something to have first (it moves from Attachments to Dependencies), false takes the flag off."),
                "cover": AgentSchema.boolean("True makes it the page's banner (the cover chosen in the app); false takes the banner choice off when this is the chosen one, so the first file is the cover again. Without a chosen banner the first file is the cover."),
                "icon": AgentSchema.boolean("True uses this picture as the page's icon picture (the small tile); false clears the icon picture when this is the one. Pictures only."),
            ], required: ["page", "index"])
        )
    }

    private static var removeMedia: AgentTool {
        AgentTool(
            name: "remove_media",
            summary: "Remove one attachment from a page, found by its number in get_page's media list. The file moves to the library trash (.trash) and the later attachments move up one place. undo brings back the entry and its caption but not the file.",
            risk: .delete, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "index": AgentSchema.integer(mediaNumberText, minimum: 1),
            ], required: ["page", "index"])
        )
    }

    private static var updateLink: AgentTool {
        AgentTool(
            name: "update_link",
            summary: "Change one reference link of a page, found by its address (case and a trailing slash do not matter; get_page lists the links): its comment, whether it is a link to learn first (skills and tutorials), or its address with newURL, which keeps the comment and the flag. Only what you pass changes.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string(pageRef),
                "url": AgentSchema.string("Address of the existing link."),
                "comment": AgentSchema.string("New comment in Markdown. Empty text clears it."),
                "learnFirst": AgentSchema.boolean("Skills and tutorials: true flags the link as something to have first, false takes the flag off."),
                "newURL": AgentSchema.string("Replace the address; the link keeps its place, comment and flag."),
            ], required: ["page", "url"])
        )
    }

    private static var updateLearnFirst: AgentTool {
        AgentTool(
            name: "update_learn_first",
            summary: "Edit the Learn first list of a skill or tutorial: the pages (or skill groups, by the id get_page shows) to learn before it, in the order to learn them. Remove pages, add pages at the end, or give the complete new order. A page cannot wait for itself or for a page that already waits for it, and pages that do not exist are refused. Returns the list afterwards.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string("The skill or tutorial whose list changes. \(pageRef)"),
                "add": AgentSchema.strings("Pages to learn first, added at the end of the list. \(pageListText)"),
                "remove": AgentSchema.strings("Pages to take off the list. \(pageListText)"),
                "order": AgentSchema.strings("The complete list in its new order, after the removals and additions of the same call; every page of the list must appear once."),
            ], required: ["page"])
        )
    }

    private static var updateLinkedPages: AgentTool {
        AgentTool(
            name: "update_linked_pages",
            summary: "Edit the pages attached to a skill or tutorial (what the app's Attach Page sheet edits): remove pages, add pages at the end, or give the complete new order. A page cannot be attached to itself and pages that do not exist are refused. Returns the attached pages afterwards.",
            risk: .write, executor: .core, coach: false,
            schema: AgentSchema.object([
                "page": AgentSchema.string("The skill or tutorial the pages are attached to. \(pageRef)"),
                "add": AgentSchema.strings("Pages to attach, added at the end. \(pageListText)"),
                "remove": AgentSchema.strings("Pages to detach. \(pageListText)"),
                "order": AgentSchema.strings("The complete list in its new order, after the removals and additions of the same call; every attached page must appear once."),
            ], required: ["page"])
        )
    }
}
