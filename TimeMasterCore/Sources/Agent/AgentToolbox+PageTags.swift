import Foundation

/// Tags: the options of the Notion-style Select presets a page wears one of. The top folder of a tree keeps the tags of
/// every exercise and note below it; a skill keeps the types of its sub-skills (see `DatabaseManager.skillTypeOwner`).
extension AgentToolbox {
    func runPageTagTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "list_page_tags": return try listPageTags(args)
        case "create_page_tag": return try createPageTag(args, dryRun: dryRun)
        case "update_page_tag": return try updatePageTag(args, dryRun: dryRun)
        case "delete_page_tag": return try deletePageTag(args, dryRun: dryRun)
        default: return nil
        }
    }

    // MARK: - Resolving

    /// The page that keeps the tags `page` can wear.
    func tagOwner(of page: ExercisePageManifest, index: AgentPageIndex) throws -> ExercisePageManifest {
        guard let ownerID = index.tagOwnerID(of: page), let owner = index.byID[ownerID] else {
            throw AgentToolError(
                "no_tags_here",
                "'\(index.titlePath(page.id))' sits at the top of the library and holds no pages, so no folder keeps tags for it.",
                hint: "Move it into a folder first, or pass a folder."
            )
        }
        return owner
    }

    /// The tag `reference` names among `presets`: its id, or its title in any case. Empty text names no tag.
    func resolveTag(_ reference: String, in presets: [SkillTypePreset], ownerPath: String) throws -> SkillType? {
        let clean = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let tags = presets.flatMap(\.types)
        if let byID = tags.first(where: { $0.id.caseInsensitiveCompare(clean) == .orderedSame }) { return byID }
        let wanted = AgentValue.fold(clean)
        let matches = tags.filter { AgentValue.fold($0.title) == wanted }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 {
            let candidates = matches.map { "\($0.title) (\($0.id))" }.joined(separator: "; ")
            throw AgentToolError("ambiguous", "'\(clean)' names \(matches.count) tags of '\(ownerPath)'.", hint: "Use the id: \(candidates).")
        }
        let known = tags.map(\.title)
        throw AgentToolError(
            "unknown_tag",
            "'\(ownerPath)' has no tag '\(clean)'.",
            hint: known.isEmpty
                ? "It has no tags yet; make one with create_page_tag."
                : "Its tags: \(known.joined(separator: ", ")). Make another with create_page_tag."
        )
    }

    /// The tag the `tag` argument asks for on `page` (nil = no tag), checked against the presets of the page that keeps
    /// its tags. A folder wears no tag.
    func requestedTag(_ args: AgentArguments, on page: ExercisePageManifest, index: AgentPageIndex) throws -> SkillType? {
        guard DatabaseManager.wearsType(page) else {
            throw AgentToolError("invalid_page", "'\(page.title)' is a folder; folders wear no tag, the exercises and notes inside them do.", hint: "Tag the pages inside it.")
        }
        guard let reference = cleanedTagText(args.string("tag")) else { return nil }
        let owner = try tagOwner(of: page, index: index)
        return try resolveTag(reference, in: DatabaseManager.renumberedTypePresets(owner.typePresets), ownerPath: index.titlePath(owner.id))
    }

    /// The tag the `tag` argument asks for on a new page of `pageType` about to be made in `parent`. An exercise or a
    /// note takes the tags of the top page of the parent's tree; a skill inside a skill the types of that skill tree; a
    /// skill straight inside a folder starts presets of its own, so it has none to pick from yet.
    func requestedTag(_ args: AgentArguments, forNew pageType: PageType, in parent: ExercisePageManifest?, index: AgentPageIndex) throws -> SkillType? {
        guard let reference = cleanedTagText(args.string("tag")) else { return nil }
        guard let parent else {
            throw AgentToolError("no_tags_here", "A page at the top of the library has no folder to keep its tags.", hint: "Pass a parent folder, or leave tag out.")
        }
        let ownerID: String?
        if pageType == .skill || pageType == .tutorial {
            guard parent.pageType == .skill || parent.pageType == .tutorial else {
                throw AgentToolError(
                    "no_tags_here",
                    "A skill straight inside a folder keeps types of its own and has none yet.",
                    hint: "Create the skill first, then create_page_tag with it as container, then update_page with tag."
                )
            }
            ownerID = index.tagOwnerID(of: parent)
        } else {
            ownerID = index.topPage(of: parent.id)?.id
        }
        guard let ownerID, let owner = index.byID[ownerID] else {
            throw AgentToolError("no_tags_here", "No folder above '\(index.titlePath(parent.id))' keeps tags.")
        }
        return try resolveTag(reference, in: DatabaseManager.renumberedTypePresets(owner.typePresets), ownerPath: index.titlePath(owner.id))
    }

    private func cleanedTagText(_ text: String?) -> String? {
        guard let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return nil }
        return clean
    }

    /// An SF Symbol name is plain ASCII; anything else is taken for an emoji.
    private static func tagIconKind(_ icon: String) -> SkillBoardIconType {
        icon.unicodeScalars.allSatisfy(\.isASCII) ? .system : .emoji
    }

    /// The `color` argument as stored (`RRGGBB`); nil when none was passed.
    private func tagColor(_ args: AgentArguments) throws -> String? {
        guard let raw = cleanedTagText(args.string("color")) else { return nil }
        guard let hex = SkillColors.normalizedHex(raw) else {
            throw AgentToolError("invalid_argument", "'color' must be a colour as RRGGBB, for example 5CE1E6.")
        }
        return hex
    }

    private func tagValue(_ tag: SkillType) -> [String: Any] {
        var out: [String: Any] = ["id": tag.id, "title": tag.title]
        if let color = tag.colorHex { out["color"] = color }
        if let icon = tag.iconName { out["icon"] = icon }
        return out
    }

    /// The pages that take their tags from `owner`: `owner` itself and every page below it that wears tags from it.
    private func taggablePages(of owner: ExercisePageManifest, index: AgentPageIndex) -> [ExercisePageManifest] {
        ([owner] + index.descendants(of: owner.id)).filter { page in
            DatabaseManager.wearsType(page) && index.tagOwnerID(of: page) == owner.id
        }
    }

    // MARK: - Tools

    private func listPageTags(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let owner = try tagOwner(of: try index.resolve(try args.requiredString("container")), index: index)
        let presets = DatabaseManager.renumberedTypePresets(owner.typePresets)
        let known = Set(presets.flatMap(\.types).map(\.id))
        var counts: [String: Int] = [:]
        var untagged = 0
        for page in taggablePages(of: owner, index: index) {
            if let id = page.typeID, known.contains(id) {
                counts[id, default: 0] += 1
            } else {
                untagged += 1
            }
        }
        var value: [String: Any] = [
            "owner": index.titlePath(owner.id),
            "ownerID": owner.id,
            "presets": presets.map { preset -> [String: Any] in
                var item: [String: Any] = [
                    "id": preset.id,
                    "title": preset.title,
                    "tags": preset.types.map { tag -> [String: Any] in
                        var entry = tagValue(tag)
                        entry["pages"] = counts[tag.id] ?? 0
                        return entry
                    },
                ]
                if let icon = preset.iconName { item["icon"] = icon }
                return item
            },
            "untagged": untagged,
        ]
        if presets.isEmpty { value["hint"] = "No tags yet; make one with create_page_tag." }
        return AgentToolOutput(value: value)
    }

    private func createPageTag(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let owner = try tagOwner(of: try index.resolve(try args.requiredString("container")), index: index)
        let ownerPath = index.titlePath(owner.id)
        let title = try args.requiredString("title")
        let presets = DatabaseManager.renumberedTypePresets(owner.typePresets)
        if let existing = presets.flatMap(\.types).first(where: { AgentValue.fold($0.title) == AgentValue.fold(title) }) {
            guard args.string("ifExists") == "reuse" else {
                throw AgentToolError(
                    "already_exists",
                    "'\(ownerPath)' already has a tag titled '\(existing.title)'.",
                    hint: "Pass ifExists \"reuse\" to get it back unchanged.",
                    details: ["existingID": existing.id]
                )
            }
            var value = tagValue(existing)
            value["in"] = ownerPath
            value["reused"] = true
            if let preset = presets.first(where: { $0.types.contains { $0.id == existing.id } }) { value["preset"] = preset.title }
            return AgentToolOutput(value: value)
        }
        let color = try tagColor(args)
        let presetReference = cleanedTagText(args.string("preset"))
        let preset: SkillTypePreset?
        if let presetReference {
            preset = presets.first { $0.id.caseInsensitiveCompare(presetReference) == .orderedSame || AgentValue.fold($0.title) == AgentValue.fold(presetReference) }
        } else {
            preset = presets.first
        }
        let presetTitle = preset?.title ?? presetReference ?? "Tags"
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldCreateTag": title, "in": ownerPath, "preset": presetTitle]
            if preset == nil { preview["newPreset"] = true }
            return AgentToolOutput(value: preview)
        }
        var effects: [AgentEffect] = []
        let presetID: String
        if let preset {
            presetID = preset.id
        } else {
            presetID = try database.addSkillTypePreset(to: owner.id, title: presetTitle).id
            effects.append(.createdTagPreset(ownerID: owner.id, presetID: presetID))
        }
        let icon = cleanedTagText(args.string("icon"))
        let tag: SkillType
        do {
            tag = try database.addSkillType(
                to: owner.id, presetID: presetID, title: title, colorHex: color,
                iconName: icon, iconType: icon.map(Self.tagIconKind) ?? .system
            )
        } catch {
            if preset == nil { try? database.deleteSkillTypePreset(presetID, in: owner.id) }
            throw error
        }
        effects.append(.createdTag(ownerID: owner.id, tagID: tag.id))
        var value = tagValue(tag)
        value["in"] = ownerPath
        value["preset"] = presetTitle
        return AgentToolOutput(value: value, effects: effects)
    }

    private func updatePageTag(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let owner = try tagOwner(of: try index.resolve(try args.requiredString("container")), index: index)
        let ownerPath = index.titlePath(owner.id)
        let presets = DatabaseManager.renumberedTypePresets(owner.typePresets)
        guard let tag = try resolveTag(try args.requiredString("tag"), in: presets, ownerPath: ownerPath) else {
            throw AgentToolError("invalid_argument", "'tag' must not be empty.")
        }
        var changed: [String] = []
        var newTitle: String?
        if args.has("title") {
            let title = try args.requiredString("title")
            if let clash = presets.flatMap(\.types).first(where: { $0.id != tag.id && AgentValue.fold($0.title) == AgentValue.fold(title) }) {
                throw AgentToolError("already_exists", "'\(ownerPath)' already has a tag titled '\(clash.title)'.", details: ["existingID": clash.id])
            }
            newTitle = title
            changed.append("title")
        }
        var color: String?
        if args.has("color") {
            guard let hex = try tagColor(args) else {
                throw AgentToolError("invalid_argument", "'color' must be a colour as RRGGBB, for example 5CE1E6.")
            }
            color = hex
            changed.append("color")
        }
        let icon = args.string("icon").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if icon != nil { changed.append("icon") }
        guard !changed.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass title, color or icon.")
        }
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "tag": tag.title, "in": ownerPath, "wouldChange": changed])
        }
        let saved = try database.updateSkillType(tag.id, in: owner.id) { type in
            if let newTitle { type.title = newTitle }
            if let color { type.colorHex = color }
            if let icon {
                type.iconName = icon.isEmpty ? nil : icon
                type.iconType = icon.isEmpty ? .system : Self.tagIconKind(icon)
            }
        }
        var value = tagValue(saved)
        value["in"] = ownerPath
        value["changed"] = changed
        return AgentToolOutput(value: value)
    }

    private func deletePageTag(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let owner = try tagOwner(of: try index.resolve(try args.requiredString("container")), index: index)
        let ownerPath = index.titlePath(owner.id)
        let presets = DatabaseManager.renumberedTypePresets(owner.typePresets)
        guard let tag = try resolveTag(try args.requiredString("tag"), in: presets, ownerPath: ownerPath) else {
            throw AgentToolError("invalid_argument", "'tag' must not be empty.")
        }
        let wearing = ([owner] + index.descendants(of: owner.id)).filter { $0.typeID == tag.id }.count
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldDeleteTag": tag.title, "in": ownerPath, "untags": wearing])
        }
        try database.deleteSkillType(tag.id, in: owner.id)
        return AgentToolOutput(value: ["deleted": tag.title, "in": ownerPath, "untagged": wearing])
    }
}
