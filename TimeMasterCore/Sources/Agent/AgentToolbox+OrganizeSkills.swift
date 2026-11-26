import Foundation

extension AgentToolbox {
    func organizeGroup(_ reference: String, on container: ExercisePageManifest, path: String) throws -> SkillBoardSection {
        var text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let split = SkillGroupID.split(text) {
            guard split.containerID.caseInsensitiveCompare(container.id) == .orderedSame else {
                throw AgentToolError("invalid_argument", "That group belongs to the board of another page, not '\(path)'.", hint: "Use a group of '\(path)': get_page on it lists them.")
            }
            text = split.sectionID
        }
        let sections = container.orderedSkillBoardSections
        if let section = sections.first(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return section }
        let named = sections.filter { AgentValue.fold($0.title) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            let ids = named.map { SkillGroupID.make(containerID: container.id, sectionID: $0.id) }
            throw AgentToolError("ambiguous", "\(named.count) groups of '\(path)' are titled '\(text)'.", hint: "Use one of the ids: \(ids.joined(separator: ", ")).")
        }
        let titles = sections.map(\.title)
        throw AgentToolError("not_found", "'\(path)' has no group '\(text)'.", hint: titles.isEmpty ? "It has no groups yet; create_skill_group makes one." : "Its groups: \(titles.joined(separator: ", ")).")
    }

    func organizeBoardPlacements(
        container: ExercisePageManifest,
        siblings: [ExercisePageManifest],
        moving page: ExercisePageManifest,
        status: SkillStatus,
        sectionID: String?,
        slot: OrganizeBoardSlot
    ) -> (placements: [SkillBoardPlacement], position: Int) {
        let sections = Set(container.skillBoardSections.map(\.id))
        func cell(_ item: ExercisePageManifest) -> String? {
            item.skillBoardSectionID.flatMap { sections.contains($0) ? $0 : nil }
        }
        let members = siblings.enumerated()
            .filter { ($0.element.pageType == .skill || $0.element.pageType == .tutorial) && $0.element.id != page.id && cell($0.element) == sectionID }
            .sorted { ($0.element.skillBoardOrder ?? 0, $0.offset) < ($1.element.skillBoardOrder ?? 0, $1.offset) }
            .map(\.element)
        let column = members.filter { ($0.skillStatus ?? .notStarted) == status }
        var moved = page
        moved.skillStatus = status
        var sequence = members
        switch slot {
        case .end:
            let last = members.map { $0.skillBoardOrder ?? 0 }.max() ?? -1
            return ([SkillBoardPlacement(pageID: page.id, status: status, sectionID: sectionID, order: last + 1)], column.count + 1)
        case .after(let id):
            sequence.insert(moved, at: sequence.firstIndex { $0.id == id }.map { $0 + 1 } ?? sequence.count)
        case .position(let wanted):
            let place = min(max(wanted - 1, 0), column.count)
            var at = sequence.count
            if place < column.count, let found = sequence.firstIndex(where: { $0.id == column[place].id }) {
                at = found
            } else if let last = column.last, let found = sequence.firstIndex(where: { $0.id == last.id }) {
                at = found + 1
            }
            sequence.insert(moved, at: at)
        }
        let placements = sequence.enumerated().map { offset, item in
            SkillBoardPlacement(pageID: item.id, status: item.skillStatus ?? .notStarted, sectionID: sectionID, order: offset)
        }
        let inColumn = sequence.filter { ($0.skillStatus ?? .notStarted) == status }
        return (placements, (inColumn.firstIndex { $0.id == page.id } ?? 0) + 1)
    }

    private func organizeSkillStatus(_ text: String) throws -> SkillStatus {
        switch text.lowercased().filter({ $0.isLetter }) {
        case "notstarted", "todo": return .notStarted
        case "learning", "inprogress": return .learning
        case "completed", "complete", "done", "finished": return .completed
        case "abandoned": return .abandoned
        default:
            throw AgentToolError("invalid_argument", "'\(text)' is not a skill status.", hint: "Use notStarted, learning, completed or abandoned.")
        }
    }

    func organizeUpdateSkill(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        let path = index.titlePath(page.id)
        guard page.pageType == .skill || page.pageType == .tutorial else {
            let kind = page.pageType == nil ? "a folder" : page.pageType == .note ? "a note" : "an exercise page"
            throw AgentToolError("invalid_page", "'\(path)' is \(kind), not a skill or tutorial.", hint: "Only skill and tutorial pages have a status, a group and a place on a skill board.")
        }
        guard args.has("status") || args.has("group") || args.has("position") else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one of status, group and position besides page.")
        }
        let currentStatus = page.skillStatus ?? .notStarted
        var status = currentStatus
        if let words = args.string("status") { status = try organizeSkillStatus(words) }
        let position = args.int("position")
        let container = page.parentID.flatMap { index.byID[$0] }
        let currentSection = container.flatMap { board in page.skillBoardSectionID.flatMap { board.skillBoardSection($0) } }
        var targetSection = currentSection
        if args.has("group") {
            let word = (args.string("group") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let clearing = word.isEmpty || word.lowercased() == "none"
            if let container {
                if clearing && !container.skillBoardSections.contains(where: { AgentValue.fold($0.title) == AgentValue.fold(word) }) {
                    targetSection = nil
                } else {
                    targetSection = try organizeGroup(word, on: container, path: index.titlePath(container.id))
                }
            } else if !clearing {
                throw AgentToolError("invalid_argument", "'\(path)' sits at the top of the library, so it has no skill board with groups.", hint: "Move it into a folder or a skill with move_page first.")
            }
        }
        if container == nil, position != nil {
            throw AgentToolError("invalid_argument", "'\(path)' sits at the top of the library, so it has no group column to take a position in.", hint: "reorder_pages orders the pages at the top of the library.")
        }
        let stored = try database.getPage(id: page.id)
        var value: [String: Any] = ["id": page.id, "path": path]
        guard let container else {
            value["status"] = status.rawValue
            guard status != currentStatus else {
                value["unchanged"] = true
                return AgentToolOutput(value: value)
            }
            if dryRun {
                value["dryRun"] = true
                value["wouldChange"] = ["status"]
                return AgentToolOutput(value: value)
            }
            var updated = stored
            updated.skillStatus = status
            try database.updatePage(id: page.id, manifest: updated, newParentID: stored.parentID)
            value["changed"] = ["status"]
            return AgentToolOutput(value: value, effects: organizeSnapshot(stored).map { [.changedPage(id: page.id, previous: $0)] } ?? [])
        }
        let sectionID = targetSection?.id
        var changed: [String] = []
        if status != currentStatus { changed.append("status") }
        if sectionID != currentSection?.id { changed.append("group") }
        if position != nil { changed.append("position") }
        value["status"] = status.rawValue
        if let targetSection { value["group"] = targetSection.title }
        let storedBoard = try database.getPage(id: container.id)
        let siblings = try database.storedSiblings(parentID: container.id).map(\.manifest)
        let before = Dictionary(siblings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let slot: OrganizeBoardSlot = position.map { OrganizeBoardSlot.position($0) } ?? .end
        let result = organizeBoardPlacements(container: storedBoard, siblings: siblings, moving: stored, status: status, sectionID: sectionID, slot: slot)
        let differing = result.placements.filter { placement in
            guard let item = before[placement.pageID] else { return true }
            return (item.skillStatus ?? .notStarted) != placement.status || item.skillBoardSectionID != placement.sectionID || (item.skillBoardOrder ?? 0) != placement.order
        }
        guard !changed.isEmpty, !differing.isEmpty else {
            value["unchanged"] = true
            return AgentToolOutput(value: value)
        }
        value["position"] = result.position
        if dryRun {
            value["dryRun"] = true
            value["wouldChange"] = changed
            return AgentToolOutput(value: value)
        }
        try database.updateSkillBoard(containerID: container.id, sections: storedBoard.orderedSkillBoardSections, placements: result.placements)
        value["changed"] = changed
        let effects = organizeChanges(from: before, to: organizeCapture(parents: [container.id], includingParents: false))
        return AgentToolOutput(value: value, effects: effects)
    }

    func organizeUpdateSkillGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let container = try index.resolve(try args.requiredString("container"))
        try organizeRequireContainer(container)
        let path = index.titlePath(container.id)
        let section = try organizeGroup(try args.requiredString("group"), on: container, path: path)
        var changed: [String] = []
        var title: String?
        if args.has("title") {
            let text = try args.requiredString("title")
            if container.skillBoardSections.contains(where: { $0.id != section.id && AgentValue.fold($0.title) == AgentValue.fold(text) }) {
                throw AgentToolError("already_exists", "'\(path)' already has another group titled '\(text)'.", hint: "Choose a title no other group of the board has.")
            }
            title = text
            changed.append("title")
        }
        let notes = args.string("markdownBody")
        if notes != nil { changed.append("markdownBody") }
        let icon = args.string("icon")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if icon != nil { changed.append("icon") }
        let colorText = args.string("color")?.trimmingCharacters(in: .whitespacesAndNewlines)
        var colorHex: String?
        if let colorText, !colorText.isEmpty {
            guard let normalized = SkillColors.normalizedHex(colorText) else {
                throw AgentToolError("invalid_argument", "'\(colorText)' is not a colour.", hint: "Use RRGGBB, for example FF6A00.")
            }
            colorHex = normalized
        }
        if colorText != nil { changed.append("color") }
        let position = args.int("position")
        if position != nil { changed.append("position") }
        guard !changed.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one field besides container and group.")
        }
        let groupID = SkillGroupID.make(containerID: container.id, sectionID: section.id)
        var value: [String: Any] = ["id": groupID, "group": title ?? section.title, "in": path]
        if dryRun {
            value["dryRun"] = true
            value["wouldChange"] = changed
            return AgentToolOutput(value: value)
        }
        let stored = try database.getPage(id: container.id)
        let snapshot = organizeSnapshot(stored)
        try database.updateSkillGroup(containerID: container.id, sectionID: section.id) { edited in
            if let title { edited.title = title }
            if let notes { edited.markdownBody = notes }
            if let icon {
                edited.icon = icon.isEmpty ? nil : icon
                edited.iconType = icon.isEmpty ? nil : (icon.unicodeScalars.allSatisfy { $0.isASCII } ? SkillBoardIconType.system : SkillBoardIconType.emoji)
            }
            if colorText != nil { edited.colorHex = colorHex }
        }
        if let position {
            var ids = stored.orderedSkillBoardSections.map(\.id).filter { $0 != section.id }
            ids.insert(section.id, at: min(max(position - 1, 0), ids.count))
            try database.reorderSkillGroups(containerID: container.id, ids: ids)
        }
        let groups = try database.getPage(id: container.id).orderedSkillBoardSections
        value["position"] = (groups.firstIndex { $0.id == section.id } ?? 0) + 1
        value["changed"] = changed
        return AgentToolOutput(value: value, effects: snapshot.map { [.changedPage(id: container.id, previous: $0)] } ?? [])
    }

    func organizeDeleteSkillGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let container = try index.resolve(try args.requiredString("container"))
        try organizeRequireContainer(container)
        let path = index.titlePath(container.id)
        let section = try organizeGroup(try args.requiredString("group"), on: container, path: path)
        let kept = index.children(of: container.id).filter { ($0.pageType == .skill || $0.pageType == .tutorial) && $0.skillBoardSectionID == section.id }
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldRemoveGroup": section.title, "in": path, "skillsKept": kept.count])
        }
        let stored = try database.getPage(id: container.id)
        let before = organizeCapture(parents: [container.id], includingParents: false)
        try database.deleteSkillGroup(containerID: container.id, sectionID: section.id)
        var value: [String: Any] = ["removed": section.title, "in": path, "skillsKept": kept.count]
        guard section.mediaFilenames.isEmpty, section.imageFilename == nil, let snapshot = organizeSnapshot(stored) else {
            value["note"] = "The group's clips and pictures went to the trash, so undo does not bring the group back."
            return AgentToolOutput(value: value)
        }
        let effects = organizeChanges(from: before, to: organizeCapture(parents: [container.id], includingParents: false)) + [AgentEffect.changedPage(id: container.id, previous: snapshot)]
        return AgentToolOutput(value: value, effects: effects)
    }
}
