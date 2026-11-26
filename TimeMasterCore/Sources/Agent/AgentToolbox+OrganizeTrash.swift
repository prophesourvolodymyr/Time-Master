import Foundation

private struct OrganizeTrashEntry {
    enum Content {
        case page(ExercisePageManifest)
        case workout(id: String, name: String)
    }

    let name: String
    let url: URL
    let content: Content
    let deleted: Date?

    var contentID: String {
        switch content {
        case .page(let page): return page.id
        case .workout(let id, _): return id
        }
    }
}

extension AgentToolbox {
    private func organizeTrashEntry(at url: URL) -> OrganizeTrashEntry? {
        let fs = database.fs
        let name = url.lastPathComponent
        guard !name.hasSuffix("-manifest.json"), fs.directoryExists(at: url),
              let data = try? fs.readRawData(from: url.appendingPathComponent("manifest.json")),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let id = object["id"] as? String else { return nil }
        let digits = name.prefix { $0.isASCII && $0.isNumber }
        var deleted: Date?
        if !digits.isEmpty, name.dropFirst(digits.count).hasPrefix("-"), let seconds = Int(digits) {
            deleted = Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if object["title"] is String, object["startedAt"] == nil {
            guard let page = try? database.readPageManifest(at: url) else { return nil }
            return OrganizeTrashEntry(name: name, url: url, content: .page(page), deleted: deleted)
        }
        if let title = object["name"] as? String, object["sections"] != nil {
            return OrganizeTrashEntry(name: name, url: url, content: .workout(id: id, name: title), deleted: deleted)
        }
        return nil
    }

    private func organizeTrashEntries() -> [OrganizeTrashEntry] {
        let fs = database.fs
        let urls = (try? fs.listDirectory(fs.trashDirectory, skipNonSchema: false)) ?? []
        return urls.compactMap { organizeTrashEntry(at: $0) }.sorted { lhs, rhs in
            switch (lhs.deleted, rhs.deleted) {
            case let (left?, right?): return left != right ? left > right : lhs.name < rhs.name
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.name < rhs.name
            }
        }
    }

    private func organizeInsidePageIDs(in folder: URL) -> [String] {
        let fs = database.fs
        var ids: [String] = []
        for entry in (try? fs.listDirectory(folder, skipNonSchema: false)) ?? [] {
            let name = entry.lastPathComponent
            guard name != "media", name != DatabaseManager.noteAttachmentsFolderName, name != SkillGroupID.folderName,
                  fs.directoryExists(at: entry), fs.fileExists(at: entry.appendingPathComponent("manifest.json")) else { continue }
            ids.append((try? database.readPageManifest(at: entry))?.id ?? name)
            ids += organizeInsidePageIDs(in: entry)
        }
        return ids
    }

    private func organizeCountPages(in folder: URL) -> Int {
        let fs = database.fs
        var total = 0
        for entry in (try? fs.listDirectory(folder, skipNonSchema: false)) ?? [] {
            let name = entry.lastPathComponent
            guard name != "media", name != DatabaseManager.noteAttachmentsFolderName, name != SkillGroupID.folderName,
                  fs.directoryExists(at: entry), fs.fileExists(at: entry.appendingPathComponent("manifest.json")) else { continue }
            total += 1 + organizeCountPages(in: entry)
        }
        return total
    }

    private func organizeTrashOrigin(of page: ExercisePageManifest, index: AgentPageIndex) -> (path: String?, parentMissing: Bool) {
        guard let parentID = page.parentID else { return (page.title, false) }
        guard index.byID[parentID] != nil else { return (nil, true) }
        return (index.titlePath(parentID) + "/" + page.title, false)
    }

    func organizeListTrash(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let entries = organizeTrashEntries()
        let shown = entries.prefix(args.int("limit") ?? 50)
        let items = shown.map { entry -> [String: Any] in
            var item: [String: Any] = ["id": entry.name]
            if let deleted = entry.deleted { item["deleted"] = iso(deleted) }
            switch entry.content {
            case .page(let page):
                item["kind"] = index.kind(page)
                item["title"] = page.title
                let origin = organizeTrashOrigin(of: page, index: index)
                if let path = origin.path { item["from"] = path }
                if origin.parentMissing { item["parentMissing"] = true }
                let inside = organizeCountPages(in: entry.url)
                if inside > 0 { item["inside"] = inside }
            case .workout(_, let name):
                item["kind"] = "workout"
                item["title"] = name
            }
            return item
        }
        var value: [String: Any] = ["total": entries.count, "items": items]
        if entries.count > shown.count {
            value["more"] = entries.count - shown.count
            value["hint"] = "Raise limit to see more."
        }
        return AgentToolOutput(value: value)
    }

    private func organizeFindTrashEntry(_ text: String) throws -> OrganizeTrashEntry {
        let fs = database.fs
        if SyncPaths.isSafeName(text), let entry = organizeTrashEntry(at: fs.trashDirectory.appendingPathComponent(text, isDirectory: true)) {
            return entry
        }
        let matches = organizeTrashEntries().filter { $0.contentID.caseInsensitiveCompare(text) == .orderedSame }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 {
            let names = matches.map { entry in "\(entry.name)\(entry.deleted.map { " (deleted \(iso($0)))" } ?? "")" }
            throw AgentToolError("ambiguous", "\(matches.count) deleted items have the id '\(text)'.", hint: "Use one entry id: \(names.joined(separator: "; ")).")
        }
        throw AgentToolError("not_found", "Nothing in the trash matches '\(text)'.", hint: "list_trash shows what the trash holds and the id to use.")
    }

    func organizeRestoreFromTrash(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let entry = try organizeFindTrashEntry(try args.requiredString("item"))
        switch entry.content {
        case .page(let page):
            return try organizeRestorePage(entry, page, parentReference: args.string("parent"), dryRun: dryRun)
        case .workout(let id, let name):
            if args.has("parent") {
                throw AgentToolError("invalid_argument", "parent applies to pages; a workout goes back to the Workouts page.", hint: "Leave parent out.")
            }
            return try organizeRestoreWorkout(entry, id: id, name: name, dryRun: dryRun)
        }
    }

    private func organizeRestorePage(_ entry: OrganizeTrashEntry, _ stored: ExercisePageManifest, parentReference: String?, dryRun: Bool) throws -> AgentToolOutput {
        let fs = database.fs
        let index = try AgentPageIndex(database: database)
        guard SyncPaths.isSafeName(stored.id), !SkillGroupID.isGroup(stored.id) else {
            throw AgentToolError("invalid_data", "The page in this trash entry has an id that cannot name a folder, so it cannot be restored.")
        }
        let inside = organizeInsidePageIDs(in: entry.url)
        if index.byID[stored.id] != nil || inside.contains(where: { index.byID[$0] != nil }) {
            throw AgentToolError("already_exists", "'\(stored.title)' or a page inside it is already in the library; nothing was overwritten.", hint: "It may already have been restored: search_pages finds it.")
        }
        var destination: ExercisePageManifest?
        var note: String?
        if let parentReference {
            let chosen = try index.resolve(parentReference)
            try organizeRequireContainer(chosen)
            destination = chosen
        } else if let originalID = stored.parentID {
            if let original = index.byID[originalID], original.pageKind == .container {
                destination = original
            } else {
                note = "The folder it came from is no longer in the library, so the page is back at the top level; move_page puts it elsewhere."
            }
        }
        let target = try database.pageFolder(for: stored.id, parentID: destination?.id)
        guard !fs.fileExists(at: target) else {
            throw AgentToolError("already_exists", "The library already has a folder for this page; nothing was overwritten.")
        }
        let path = (destination.map { index.titlePath($0.id) + "/" } ?? "") + stored.title
        var value: [String: Any] = ["id": stored.id, "path": path, "kind": index.kind(stored)]
        if !inside.isEmpty { value["inside"] = inside.count }
        if let note { value["note"] = note }
        if dryRun {
            value["dryRun"] = true
            value["wouldRestore"] = path
            return AgentToolOutput(value: value)
        }
        let manifestURL = entry.url.appendingPathComponent("manifest.json")
        let original = try fs.readRawData(from: manifestURL)
        try fs.ensureDirectory(target.deletingLastPathComponent())
        try FileManager.default.moveItem(at: entry.url, to: target)
        do {
            var restored = try database.readPageManifest(at: target)
            restored.parentID = destination?.id
            restored.updatedAt = Date()
            if destination != nil { restored.workoutType = nil }
            restored.order = try database.nextSiblingOrder(parentID: destination?.id, excluding: restored.id)
            var normalized = database.normalizedPageManifest(restored, parentID: destination?.id)
            if let destination, normalized.pageType == .skill || normalized.pageType == .tutorial {
                normalized.skillBoardOrder = try database.nextSkillBoardOrder(containerID: destination.id, sectionID: normalized.skillBoardSectionID)
            }
            try database.writePageFiles(normalized, in: target)
            let siblings = try database.storedSiblings(parentID: destination?.id)
            try database.persistSiblingOrder(siblings.map { $0.manifest.id }, parentID: destination?.id, siblings: siblings)
        } catch {
            try? fs.writeAtomically(to: target.appendingPathComponent("manifest.json"), data: original)
            try? FileManager.default.moveItem(at: target, to: entry.url)
            throw error
        }
        value["restored"] = true
        return AgentToolOutput(value: value, effects: [.createdPage(id: stored.id)])
    }

    private func organizeRestoreWorkout(_ entry: OrganizeTrashEntry, id: String, name: String, dryRun: Bool) throws -> AgentToolOutput {
        let fs = database.fs
        guard SyncPaths.isSafeName(id) else {
            throw AgentToolError("invalid_data", "The workout in this trash entry has an id that cannot name a folder, so it cannot be restored.")
        }
        let target = fs.workoutsDirectory.appendingPathComponent(id, isDirectory: true)
        guard !fs.fileExists(at: target), !database.workoutExists(id: id) else {
            throw AgentToolError("already_exists", "A workout with this id is already saved; nothing was overwritten.", hint: "It may already have been restored: list_workouts shows it.")
        }
        var value: [String: Any] = ["id": id, "name": name, "kind": "workout"]
        if dryRun {
            value["dryRun"] = true
            value["wouldRestore"] = name
            return AgentToolOutput(value: value)
        }
        try fs.ensureDirectory(fs.workoutsDirectory)
        try FileManager.default.moveItem(at: entry.url, to: target)
        value["restored"] = true
        value["note"] = "It is in no workout group; update_workout_group adds it to one."
        return AgentToolOutput(value: value, effects: [.createdWorkout(id: id)])
    }
}
