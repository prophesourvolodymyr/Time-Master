import Foundation

enum OrganizeBoardSlot {
    case end
    case after(String)
    case position(Int)
}

extension AgentToolbox {
    func runOrganizeTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "reorder_pages": return try organizeReorderPages(args, dryRun: dryRun)
        case "update_skill": return try organizeUpdateSkill(args, dryRun: dryRun)
        case "update_skill_group": return try organizeUpdateSkillGroup(args, dryRun: dryRun)
        case "delete_skill_group": return try organizeDeleteSkillGroup(args, dryRun: dryRun)
        case "duplicate_page": return try organizeDuplicatePage(args, dryRun: dryRun)
        case "list_trash": return try organizeListTrash(args)
        case "restore_from_trash": return try organizeRestoreFromTrash(args, dryRun: dryRun)
        default: return nil
        }
    }

    func organizeRequireContainer(_ page: ExercisePageManifest) throws {
        guard page.pageKind == .container else {
            throw AgentToolError("invalid_parent", "'\(page.title)' is \(page.pageType == .note ? "a note" : "an exercise page") and cannot contain other pages.", hint: "Choose a folder or a skill with list_pages.")
        }
    }

    func organizeChild(_ reference: String, among children: [ExercisePageManifest], parentPath: String, index: AgentPageIndex) throws -> ExercisePageManifest {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentToolError("invalid_argument", "A page reference must not be empty.") }
        if let page = children.first(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return page }
        let wanted = AgentValue.fold(text)
        var matches = children.filter { AgentValue.fold(index.titlePath($0.id)) == wanted }
        if matches.isEmpty { matches = children.filter { AgentValue.fold($0.title) == wanted } }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 {
            throw AgentToolError("ambiguous", "\(matches.count) pages inside '\(parentPath)' are titled '\(text)'.", hint: "Use the ids: \(matches.map(\.id).joined(separator: ", ")).")
        }
        let found = try index.resolve(text)
        if let page = children.first(where: { $0.id == found.id }) { return page }
        throw AgentToolError("invalid_argument", "'\(index.titlePath(found.id))' is not directly inside '\(parentPath)'.", hint: "Name pages that sit directly inside it; list_pages shows them.")
    }

    func organizeSnapshot(_ page: ExercisePageManifest) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(page) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func organizeCapture(parents: [String?], includingParents: Bool = true) -> [String: ExercisePageManifest] {
        var captured: [String: ExercisePageManifest] = [:]
        for parentID in parents {
            if includingParents, let parentID, let manifest = try? database.getPage(id: parentID) {
                captured[parentID] = manifest
            }
            for sibling in (try? database.storedSiblings(parentID: parentID)) ?? [] {
                captured[sibling.manifest.id] = sibling.manifest
            }
        }
        return captured
    }

    func organizeChanges(from before: [String: ExercisePageManifest], to after: [String: ExercisePageManifest], moved: String? = nil, everything: Bool = false) -> [AgentEffect] {
        var effects: [AgentEffect] = []
        var movedEffect: AgentEffect?
        for id in before.keys.sorted() {
            guard let old = before[id], let new = after[id], let previous = organizeSnapshot(old), everything || previous != organizeSnapshot(new) else { continue }
            let effect = AgentEffect.changedPage(id: id, previous: previous)
            if id == moved { movedEffect = effect } else { effects.append(effect) }
        }
        if let movedEffect { effects = [movedEffect] + effects + [movedEffect] }
        return effects
    }

    func organizeMovePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        let placing = ["before", "after", "position"].filter { args.has($0) }
        guard placing.count <= 1 else {
            throw AgentToolError("invalid_argument", "Pass only one of before, after and position.", hint: "before and after put the page next to another page; position gives its place among the destination's pages.")
        }
        let currentParent = page.parentID.flatMap { index.byID[$0] }
        func checked(_ destination: ExercisePageManifest) throws {
            guard destination.pageKind == .container else {
                throw AgentToolError("invalid_parent", "'\(destination.title)' cannot contain other pages.")
            }
            guard destination.id != page.id, !index.descendants(of: page.id).contains(where: { $0.id == destination.id }) else {
                throw AgentToolError("invalid_parent", "A page cannot be moved inside itself.")
            }
        }
        var destination = try args.string("newParent").map { try index.resolve($0) }
        if let destination { try checked(destination) }
        var neighbour: ExercisePageManifest?
        if let reference = args.string("before") ?? args.string("after") {
            if let destination {
                neighbour = try organizeChild(reference, among: index.children(of: destination.id), parentPath: index.titlePath(destination.id), index: index)
            } else {
                let found = try index.resolve(reference)
                neighbour = found
                destination = found.parentID.flatMap { index.byID[$0] }
                if let destination { try checked(destination) }
            }
        }
        if let neighbour, neighbour.id == page.id {
            throw AgentToolError("invalid_argument", "A page cannot be placed next to itself.")
        }
        if args.has("position"), !args.has("newParent"), let currentParent {
            throw AgentToolError("invalid_argument", "Without newParent, position counts the pages at the top of the library.", hint: "Pass newParent \"\(index.titlePath(currentParent.id))\" to place the page inside its folder, or use reorder_pages.")
        }
        let baseline = try database.storedSiblings(parentID: destination?.id).map { $0.manifest.id }.filter { $0 != page.id }
        var slot = baseline.count
        if let neighbour {
            guard let at = baseline.firstIndex(of: neighbour.id) else {
                throw AgentToolError("not_found", "'\(neighbour.title)' is not stored inside the destination.")
            }
            slot = args.has("after") ? at + 1 : at
        } else if let position = args.int("position") {
            slot = min(max(position - 1, 0), baseline.count)
        }
        let from = index.titlePath(page.id)
        let newPath = (destination.map { index.titlePath($0.id) + "/" } ?? "") + page.title
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldMove": from, "to": newPath]
            if !placing.isEmpty { preview["position"] = slot + 1 }
            return AgentToolOutput(value: preview)
        }
        var parents: [String?] = [currentParent?.id]
        if destination?.id != currentParent?.id { parents.append(destination?.id) }
        let crossing = parents.count > 1
        let before = organizeCapture(parents: parents)
        if placing.isEmpty || crossing {
            try database.movePageToEnd(id: page.id, parentID: destination?.id)
        }
        if !placing.isEmpty {
            var placed = baseline
            placed.insert(page.id, at: slot)
            try database.persistSiblingOrder(placed, parentID: destination?.id, siblings: try database.storedSiblings(parentID: destination?.id))
        }
        var value: [String: Any] = ["id": page.id, "path": newPath, "from": from]
        if !placing.isEmpty { value["position"] = slot + 1 }
        let effects = organizeChanges(from: before, to: organizeCapture(parents: parents), moved: crossing ? page.id : nil, everything: crossing)
        return AgentToolOutput(value: value, effects: effects)
    }

    func organizeReorderPages(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let parent = try args.string("parent").map { try index.resolve($0) }
        if let parent { try organizeRequireContainer(parent) }
        let references = args.strings("order") ?? []
        guard !references.isEmpty else {
            throw AgentToolError("invalid_argument", "'order' must list at least one page.", hint: "Pass the pages in the order you want them, for example --order Jab --order Cross.")
        }
        let parentPath = parent.map { index.titlePath($0.id) } ?? "top level"
        let children = index.children(of: parent?.id)
        var listed: [String] = []
        for reference in references {
            let child = try organizeChild(reference, among: children, parentPath: parentPath, index: index)
            if !listed.contains(child.id) { listed.append(child.id) }
        }
        let siblings = try database.storedSiblings(parentID: parent?.id)
        let current = siblings.map { $0.manifest.id }
        let stored = Set(current)
        guard listed.allSatisfy({ stored.contains($0) }) else {
            throw AgentToolError("invalid_argument", "Some of those pages are not stored directly inside '\(parentPath)'.", hint: "Name pages that sit directly inside it; list_pages shows them.")
        }
        let ordered = listed + current.filter { !listed.contains($0) }
        let titles = Dictionary(siblings.map { ($0.manifest.id, $0.manifest.title) }, uniquingKeysWith: { first, _ in first })
        let names = ordered.compactMap { titles[$0] }
        let moved = ordered.enumerated().filter { current[$0.offset] != $0.element }.count
        var value: [String: Any] = ["in": parentPath, "order": Array(names.prefix(60))]
        if let parent { value["id"] = parent.id }
        if names.count > 60 { value["more"] = names.count - 60 }
        if dryRun {
            value["dryRun"] = true
            value["wouldMove"] = moved
            return AgentToolOutput(value: value)
        }
        guard moved > 0 else {
            value["unchanged"] = true
            return AgentToolOutput(value: value)
        }
        let before = organizeCapture(parents: [parent?.id])
        try database.persistSiblingOrder(ordered, parentID: parent?.id, siblings: siblings)
        value["moved"] = moved
        let skillIDs = Set(children.filter { $0.pageType == .skill || $0.pageType == .tutorial }.map(\.id))
        if let parent, !parent.skillBoardSections.isEmpty, listed.contains(where: skillIDs.contains) {
            value["note"] = "Skills sit in groups on this board; update_skill position sets a skill's place inside its group."
        }
        return AgentToolOutput(value: value, effects: organizeChanges(from: before, to: organizeCapture(parents: [parent?.id])))
    }
}
