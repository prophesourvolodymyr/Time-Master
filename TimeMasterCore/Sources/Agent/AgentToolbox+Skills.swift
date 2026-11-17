import Foundation

extension AgentToolbox {
    func runSkillTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "create_skill_page": return try createSkillPage(args, dryRun: dryRun)
        case "create_skill_group": return try createSkillGroup(args, dryRun: dryRun)
        default: return nil
        }
    }

    private func groupMatching(_ title: String, on page: ExercisePageManifest) -> SkillBoardSection? {
        page.skillBoardSections.first { AgentValue.fold($0.title) == AgentValue.fold(title) }
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return nil }
        return clean
    }

    private func requireContainer(_ parent: ExercisePageManifest) throws {
        guard parent.pageKind == .container else {
            throw AgentToolError("invalid_parent", "'\(parent.title)' is \(parent.pageType == .note ? "a note" : "an exercise page") and cannot contain other pages.", hint: "Choose a folder or a skill with list_pages.")
        }
    }

    private func createSkillPage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let title = try args.requiredString("title")
        let parent = try args.string("parent").map { try index.resolve($0) }
        if let parent { try requireContainer(parent) }
        let groupTitle = trimmedOrNil(args.string("group"))
        if groupTitle != nil, parent == nil {
            throw AgentToolError("invalid_argument", "A group lives on the skill board of a parent folder or skill.", hint: "Pass parent, or omit group.")
        }
        if let existing = index.children(of: parent?.id).first(where: { AgentValue.fold($0.title) == AgentValue.fold(title) }) {
            switch args.string("ifExists") ?? "error" {
            case "reuse":
                var value = index.summary(existing, withID: true)
                value["reused"] = true
                return AgentToolOutput(value: value)
            case "duplicate":
                break
            default:
                throw AgentToolError("already_exists", "A page titled '\(title)' already exists here.", hint: "Pass ifExists \"reuse\" to get it back unchanged, or \"duplicate\" to create another.", details: ["existingID": existing.id])
            }
        }
        let pageType: PageType = args.string("pageType") == "tutorial" ? .tutorial : .skill
        let flags = try pageFlags(args, pageType: pageType)
        let attachments = try args.objects("media").map { item -> (url: URL, comment: String?) in
            (try AgentMedia.validate(path: item["path"] as? String ?? ""), (item["comment"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        let limit = DatabaseManager.mediaLimit(for: ExercisePageManifest(title: title, pageType: pageType))
        guard attachments.count <= limit else { throw AgentToolError("media_limit", "A skill page holds up to \(limit) attachments.") }
        let status = SkillStatus(rawValue: args.string("status") ?? "") ?? .notStarted
        var manifest = ExercisePageManifest(
            title: title, pageType: pageType, markdownBody: args.string("markdownBody") ?? "",
            linkURLs: args.strings("linkURLs") ?? [], skillStatus: status, parentID: parent?.id
        )
        if let icon = args.string("icon") { try applyIcon(icon, to: &manifest) }
        flags.apply(to: &manifest)
        let warnings = flags.isEmpty ? [] : pageFlagWarnings(manifest)
        let path = (parent.map { index.titlePath($0.id) + "/" } ?? "") + title
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldCreate": path]
            if let groupTitle { preview["group"] = groupTitle }
            if !attachments.isEmpty { preview["media"] = attachments.count }
            if !warnings.isEmpty { preview["warnings"] = warnings }
            return AgentToolOutput(value: preview)
        }

        var sectionID: String?
        if let groupTitle, let parent {
            sectionID = try groupMatching(groupTitle, on: parent)?.id ?? database.addSkillGroup(to: parent.id, title: groupTitle).id
        }
        let placement = parent.map { parent in sectionID.map { SkillGroupID.make(containerID: parent.id, sectionID: $0) } ?? parent.id }
        try database.createPage(manifest: manifest, parentID: placement)
        var saved = 0
        do {
            for item in attachments {
                let filename = try database.uploadMediaToPage(pageID: manifest.id, sourceURL: item.url)
                saved += 1
                if let comment = item.comment { try database.updateMediaComment(pageID: manifest.id, filename: filename, comment: comment) }
            }
        } catch {
            try? database.deletePage(id: manifest.id)
            throw error
        }
        var value: [String: Any] = ["id": manifest.id, "path": path]
        if let groupTitle { value["group"] = groupTitle }
        if saved > 0 { value["media"] = saved }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: [.createdPage(id: manifest.id)])
    }

    private func createSkillGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let title = try args.requiredString("title")
        let parent = try index.resolve(try args.requiredString("parent"))
        try requireContainer(parent)
        let parentPath = index.titlePath(parent.id)
        if let existing = groupMatching(title, on: parent) {
            guard args.string("ifExists") == "reuse" else {
                throw AgentToolError("already_exists", "'\(parentPath)' already has a group titled '\(title)'.", hint: "Pass ifExists \"reuse\" to get it back unchanged.", details: ["existingID": SkillGroupID.make(containerID: parent.id, sectionID: existing.id)])
            }
            return AgentToolOutput(value: ["id": SkillGroupID.make(containerID: parent.id, sectionID: existing.id), "group": existing.title, "in": parentPath, "reused": true])
        }
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldCreateGroup": title, "in": parentPath]) }
        let icon = trimmedOrNil(args.string("icon"))
        let section = try database.addSkillGroup(
            to: parent.id, title: title, icon: icon,
            iconType: icon.map { value in value.unicodeScalars.allSatisfy { $0.isASCII } ? SkillBoardIconType.system : SkillBoardIconType.emoji },
            colorHex: args.string("color")
        )
        if let body = args.string("markdownBody"), !body.isEmpty {
            try database.updateSkillGroup(containerID: parent.id, sectionID: section.id) { $0.markdownBody = body }
        }
        return AgentToolOutput(value: ["id": SkillGroupID.make(containerID: parent.id, sectionID: section.id), "group": section.title, "in": parentPath])
    }
}
