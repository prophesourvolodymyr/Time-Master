import Foundation

extension AgentToolbox {
    static let organizeCopyLimit = 200

    private func organizeCopyTitle(_ base: String, taken: Set<String>, addsCopy: Bool) -> String {
        var candidate = addsCopy ? "\(base) Copy" : base
        var number = 2
        while taken.contains(AgentValue.fold(candidate)) {
            candidate = addsCopy ? "\(base) Copy \(number)" : "\(base) \(number)"
            number += 1
        }
        return candidate
    }

    private func organizeRemapped(_ id: String, _ map: [String: String]) -> String {
        if let mapped = map[id] { return mapped }
        if let group = SkillGroupID.split(id), let mapped = map[group.containerID] {
            return SkillGroupID.make(containerID: mapped, sectionID: group.sectionID)
        }
        return id
    }

    private func organizeCopyFiles(from source: URL, to destination: URL) throws {
        let fs = database.fs
        for entry in try fs.listDirectory(source, skipNonSchema: false) {
            let name = entry.lastPathComponent
            if name == "manifest.json" || name == "guide.md" { continue }
            let isFolder = fs.directoryExists(at: entry)
            if isFolder, fs.fileExists(at: entry.appendingPathComponent("manifest.json")) { continue }
            try fs.copyItem(from: entry, to: destination.appendingPathComponent(name, isDirectory: isFolder))
        }
    }

    private func organizeClearForeignTag(_ id: String) throws -> Bool {
        guard let typeID = try database.getPage(id: id).typeID else { return false }
        if let owner = try? database.skillTypeOwner(of: id), owner.manifest.skillType(typeID) != nil { return false }
        try database.setSkillType(nil, for: id)
        return true
    }

    func organizeDuplicatePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        let originalParent = page.parentID.flatMap { index.byID[$0] }
        let chosen = try args.string("parent").map { try index.resolve($0) }
        let destination = chosen ?? originalParent
        let inPlace = destination?.id == originalParent?.id
        if let destination {
            try organizeRequireContainer(destination)
            guard destination.id != page.id, !index.descendants(of: page.id).contains(where: { $0.id == destination.id }) else {
                throw AgentToolError("invalid_parent", "A page cannot be copied into itself or into one of its own pages.", hint: "Choose another container, or leave parent out to put the copy next to the original.")
            }
        }
        var requested: String?
        if args.has("title") { requested = try args.requiredString("title") }
        let taken = Set(index.children(of: destination?.id).map { AgentValue.fold($0.title) })
        let title = organizeCopyTitle(requested ?? page.title, taken: taken, addsCopy: requested == nil)
        let deep = args.bool("deep") ?? false
        let subtree = [page] + (deep && page.pageKind == .container ? index.descendants(of: page.id) : [])
        guard subtree.count <= Self.organizeCopyLimit else {
            throw AgentToolError(
                "too_many_pages", "'\(index.titlePath(page.id))' holds \(subtree.count - 1) pages inside; a deep copy takes at most \(Self.organizeCopyLimit) pages in all.",
                hint: "Copy a smaller folder, or copy this one without deep and duplicate the parts you need."
            )
        }
        let isSkill = page.pageType == .skill || page.pageType == .tutorial
        let keptGroup = inPlace ? destination.flatMap { board in page.skillBoardSectionID.flatMap { board.skillBoardSection($0) } } : nil
        let path = (destination.map { index.titlePath($0.id) + "/" } ?? "") + title
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldCreate": path]
            if subtree.count > 1 { preview["pages"] = subtree.count }
            return AgentToolOutput(value: preview)
        }
        let now = Date()
        let rootID = UUID().uuidString
        var idMap: [String: String] = [page.id: rootID]
        for old in subtree.dropFirst() { idMap[old.id] = UUID().uuidString }
        var folders: [String: URL] = [:]
        var created: [String] = []
        var untagged: [ExercisePageManifest] = []
        do {
            for old in subtree {
                guard let newID = idMap[old.id] else { continue }
                var source = old.parentID.flatMap { folders[$0] }.map { $0.appendingPathComponent(old.id, isDirectory: true) }
                if source.map({ database.fs.directoryExists(at: $0) }) != true { source = try database.resolvePageFolder(id: old.id) }
                guard let sourceFolder = source else { continue }
                folders[old.id] = sourceFolder
                var copy = old
                copy.id = newID
                copy.childIDs = []
                copy.createdAt = now
                copy.updatedAt = now
                copy.dependencyPageIDs = old.dependencyPageIDs.map { organizeRemapped($0, idMap) }
                copy.linkedPageIDs = old.linkedPageIDs.map { organizeRemapped($0, idMap) }
                copy.trains = old.trains.map { SkillTraining(skillID: organizeRemapped($0.skillID, idMap), tier: $0.tier) }
                copy.skillBoardSections = old.skillBoardSections.map { section in
                    var section = section
                    section.dependencyPageIDs = section.dependencyPageIDs.map { organizeRemapped($0, idMap) }
                    return section
                }
                var placement: String?
                if old.id == page.id {
                    copy.title = title
                    if !inPlace { copy.workoutType = nil }
                    if let destination, let keptGroup {
                        placement = SkillGroupID.make(containerID: destination.id, sectionID: keptGroup.id)
                    } else {
                        placement = destination?.id
                        copy.skillBoardSectionID = nil
                        if let destination, isSkill {
                            copy.skillBoardOrder = try database.nextSkillBoardOrder(containerID: destination.id, sectionID: nil)
                        }
                    }
                } else {
                    placement = old.parentID.flatMap { idMap[$0] }
                }
                copy.parentID = old.id == page.id ? destination?.id : placement
                try database.createPage(manifest: copy, parentID: placement)
                created.append(newID)
                try organizeCopyFiles(from: sourceFolder, to: try database.resolvePageFolder(id: newID))
                if copy.typeID != nil, try organizeClearForeignTag(newID) { untagged.append(old) }
            }
            if inPlace {
                try database.placePage(id: rootID, nextTo: page.id, after: true)
                if isSkill, let destination {
                    let board = try database.getPage(id: destination.id)
                    let siblings = try database.storedSiblings(parentID: destination.id).map(\.manifest)
                    if let copied = siblings.first(where: { $0.id == rootID }) {
                        let result = organizeBoardPlacements(
                            container: board, siblings: siblings, moving: copied, status: copied.skillStatus ?? .notStarted,
                            sectionID: keptGroup?.id, slot: .after(page.id)
                        )
                        try database.updateSkillBoard(containerID: destination.id, sections: board.orderedSkillBoardSections, placements: result.placements)
                    }
                }
            }
        } catch {
            if let first = created.first { try? database.deletePage(id: first) }
            throw error
        }
        var value: [String: Any] = ["id": rootID, "path": path]
        if subtree.count > 1 { value["pages"] = subtree.count }
        if let keptGroup { value["group"] = keptGroup.title }
        var warnings: [String] = []
        if let requested, requested != title {
            warnings.append("A page titled '\(requested)' is already there, so the copy is titled '\(title)'.")
        }
        for old in untagged.prefix(3) {
            let tag = index.tag(of: old).map { "tag '\($0.title)'" } ?? "its tag"
            warnings.append("The copy of '\(old.title)' is untagged: \(tag) does not exist where the copy sits.")
        }
        if untagged.count > 3 { warnings.append("\(untagged.count - 3) more copied pages are untagged for the same reason.") }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: created.map { AgentEffect.createdPage(id: $0) })
    }
}
