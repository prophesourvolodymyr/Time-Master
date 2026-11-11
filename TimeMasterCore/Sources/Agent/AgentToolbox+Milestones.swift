import Foundation

extension AgentToolbox {
    func runMilestoneTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        do {
            switch name {
            case "todo_overview":
                return try todoOverview(args)
            case "list_todos", "add_todo", "update_todo", "check_todo", "move_todo", "remove_todo":
                if args.string("list") == ChecklistKind.milestone.rawValue {
                    return try runChecklistTool(Milestone.self, name, args, dryRun: dryRun)
                }
                return try runChecklistTool(TodoItem.self, name, args, dryRun: dryRun)
            default:
                return nil
            }
        } catch let error as ChecklistError {
            switch error {
            case .notFound(let message):
                throw AgentToolError("not_found", message, hint: "list_todos shows each entry with its #id.")
            case .invalid(let message):
                throw AgentToolError("invalid_argument", message)
            }
        }
    }

    /// `get_page`'s counts of the open to-dos and milestones of a skill or tutorial page.
    func addChecklistCounts(of page: ExercisePageManifest, to value: inout [String: Any]) {
        if !page.todos.isEmpty { value["todos"] = ["open": page.todos.openCount, "total": page.todos.progressTotal] }
        if !page.milestones.isEmpty { value["milestones"] = ["open": page.milestones.openCount, "total": page.milestones.progressTotal] }
    }

    /// Takes an entry an agent added back out (`undo`, or a failed batch).
    func revertChecklistEntry(pageID: String, list: String, id: String) throws {
        if list == ChecklistKind.milestone.rawValue {
            try database.removeChecklistEntry(Milestone.self, id, from: pageID)
        } else {
            try database.removeChecklistEntry(TodoItem.self, id, from: pageID)
        }
    }

    // MARK: - Overview

    private func todoOverview(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let wanted: [ChecklistKind] = args.string("list").flatMap(ChecklistKind.init(rawValue:)).map { [$0] } ?? ChecklistKind.allCases
        let query = args.string("query").map(AgentValue.fold).flatMap { $0.isEmpty ? nil : $0 }
        let limit = max(1, min(args.int("limit") ?? 30, 100))
        let findings = try database.checklistFindings().filter { wanted.contains($0.kind) }
        var rows: [(path: String, value: [String: Any])] = []
        for page in index.pages where page.pageType == .skill || page.pageType == .tutorial {
            let path = index.titlePath(page.id)
            if let query, !AgentValue.fold(path).contains(query) { continue }
            var row: [String: Any] = ["page": path]
            if wanted.contains(.todo), !page.todos.isEmpty {
                row["todos"] = "\(page.todos.openCount) open of \(page.todos.progressTotal)"
                if let next = Self.nextOpen(page.todos) { row["nextTodo"] = next.title }
            }
            if wanted.contains(.milestone), !page.milestones.isEmpty {
                row["milestones"] = "\(page.milestones.openCount) open of \(page.milestones.progressTotal)"
                if let next = Self.nextOpen(page.milestones) { row["nextMilestone"] = next.title }
            }
            guard row.count > 1 else { continue }
            if index.duplicatePaths.contains(path) { row["id"] = page.id }
            let gone = findings.filter { $0.pageID == page.id }.count
            if gone > 0 { row["missing"] = gone }
            rows.append((path, row))
        }
        rows.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        var value: [String: Any] = ["pages": rows.prefix(limit).map(\.value)]
        if rows.count > limit { value["more"] = rows.count - limit }
        if rows.isEmpty { value["hint"] = "No skill or tutorial page has to-dos or milestones yet. add_todo starts a list." }
        if !findings.isEmpty {
            value["missing"] = findings.prefix(12).map { finding in
                "\(index.titlePath(finding.pageID)) · \(finding.entryTitle): \(Self.describe(finding))"
            }
            if findings.count > 12 { value["moreMissing"] = findings.count - 12 }
        }
        return AgentToolOutput(value: value)
    }

    private static func nextOpen<Entry: ChecklistEntry>(_ list: [Entry]) -> Entry? {
        list.flattened().first { !$0.item.isSection && !$0.item.isDone }?.item
    }

    private static func describe(_ finding: ChecklistFinding) -> String {
        switch finding.problem {
        case .missingWorkout: return "its workout is gone"
        case .missingPage: return "its linked page is gone"
        case .missingFile: return "the file \(finding.reference) is not on disk"
        }
    }

    // MARK: - One list

    private func runChecklistTool<Entry: ChecklistEntry>(_ type: Entry.Type, _ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw AgentToolError(
                "invalid_page",
                "'\(page.title)' is \(index.kind(page) == "exercise" ? "an" : "a") \(index.kind(page)) page; only skill and tutorial pages keep to-dos and milestones.",
                hint: "search_pages with kind skill or tutorial finds one."
            )
        }
        let list = page[keyPath: Entry.pageList]
        switch name {
        case "list_todos": return listTodos(list, page: page, index: index, args: args)
        case "add_todo": return try addTodo(Entry.self, list, page: page, index: index, args: args, dryRun: dryRun)
        case "update_todo": return try updateTodo(Entry.self, list, page: page, index: index, args: args, dryRun: dryRun)
        case "check_todo": return try checkTodo(Entry.self, list, page: page, index: index, args: args, dryRun: dryRun)
        case "move_todo": return try moveTodo(Entry.self, list, page: page, index: index, args: args, dryRun: dryRun)
        default: return try removeTodo(Entry.self, list, page: page, index: index, args: args, dryRun: dryRun)
        }
    }

    private func listTodos<Entry: ChecklistEntry>(_ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments) -> AgentToolOutput {
        let includeDone = args.bool("done") ?? true
        let limit = max(1, min(args.int("limit") ?? 120, 300))
        let workouts = Dictionary(((try? database.listWorkouts()) ?? []).map { (DatabaseManager.canonicalID($0.id), $0.name) }, uniquingKeysWith: { first, _ in first })
        var lines: [String] = []
        var skipped = 0
        for (entry, depth) in list.flattened() {
            if !includeDone, entry.isDone { continue }
            guard lines.count < limit else { skipped += 1; continue }
            lines.append(line(for: entry, depth: depth, page: page, index: index, workouts: workouts))
        }
        var value: [String: Any] = [
            "page": index.titlePath(page.id),
            "list": Entry.kind.rawValue,
            "open": list.openCount,
            "done": list.progressDone,
            "lines": lines,
        ]
        if skipped > 0 { value["more"] = skipped }
        if list.isEmpty { value["hint"] = "The \(Entry.kind.noun) list is empty; add_todo adds the first \(Entry.kind.noun)." }
        let media = page.mediaFilenames.enumerated().map { offset, name -> String in
            var text = "\(offset + 1) \(AgentMedia.kind(ofFilename: name))"
            if let comment = page.mediaComments[name], !comment.isEmpty { text += " · \(String(comment.prefix(60)))" }
            return text
        }
        if !media.isEmpty { value["media"] = media }
        let findings = ((try? database.checklistFindings(pageID: page.id)) ?? []).filter { $0.kind == Entry.kind }
        if !findings.isEmpty { value["missing"] = findings.map { "\($0.entryTitle): \(Self.describe($0))" } }
        return AgentToolOutput(value: value)
    }

    private func line<Entry: ChecklistEntry>(for entry: Entry, depth: Int, page: ExercisePageManifest, index: AgentPageIndex, workouts: [String: String]) -> String {
        let tag = "#" + Self.shortID(entry.id)
        if entry.isSection {
            return ["## \(entry.title)", entry.iconName, tag].compactMap { $0 }.joined(separator: " ")
        }
        var extras: [String] = []
        if let icon = entry.iconName { extras.append(icon) }
        if let image = entry.iconImage { extras.append("icon " + mediaLabel(image, page: page)) }
        if let cover = entry.coverMediaFilename { extras.append("cover " + mediaLabel(cover, page: page)) }
        if !entry.imageFilenames.isEmpty {
            extras.append("pictures " + entry.imageFilenames.map { mediaLabel($0, page: page) }.joined(separator: ","))
        }
        for link in entry.links {
            switch link.target {
            case .workout(let id)?: extras.append("▶ " + (workouts[DatabaseManager.canonicalID(id)].map { "“\($0)”" } ?? "missing workout"))
            case .page(let id)?: extras.append("→ " + (Self.linkedPagePath(id, index: index) ?? "missing page"))
            case .media(let name)?: extras.append("file " + mediaLabel(name, page: page))
            case .web(let url)?: extras.append(URL(string: url)?.host ?? url)
            default: break
            }
        }
        if !entry.note.isEmpty {
            let flat = entry.note.split(whereSeparator: \.isNewline).joined(separator: " ")
            extras.append("note: " + (flat.count > 80 ? String(flat.prefix(80)) + "…" : flat))
        }
        let head = String(repeating: "  ", count: max(0, depth - 1)) + "[\(entry.isDone ? "x" : " ")] " + entry.title
        return ([head] + extras).joined(separator: " · ") + " " + tag
    }

    /// The media number of a file of the page (`#2`), or its name when it is not one of the page's media.
    private func mediaLabel(_ name: String, page: ExercisePageManifest) -> String {
        page.mediaFilenames.firstIndex(of: name).map { "#\($0 + 1)" } ?? name
    }

    /// The title path of a linked page, or of a group's board page with the group's title; nil when it is gone.
    private static func linkedPagePath(_ id: String, index: AgentPageIndex) -> String? {
        if let group = SkillGroupID.split(id) {
            guard let board = index.byID[group.containerID], let section = board.skillBoardSection(group.sectionID) else { return nil }
            return index.titlePath(board.id) + "/" + section.title
        }
        return index.byID[id].map { index.titlePath($0.id) }
    }

    private static func shortID(_ id: String) -> String { String(id.prefix(8)) }

    private func addTodo<Entry: ChecklistEntry>(
        _ type: Entry.Type, _ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments, dryRun: Bool
    ) throws -> AgentToolOutput {
        let title = try args.requiredString("title")
        let isSection = args.bool("section") == true
        let placements = ["parent", "after", "inSection"].filter { args.has($0) }
        guard placements.count <= 1 else {
            throw AgentToolError("invalid_argument", "Give only one of parent, after or inSection.", hint: "Without any of them the entry goes at the end of the list.")
        }
        var parentID: String?
        var position: Int?
        var placeText = "at the end"
        if let reference = args.string("parent") {
            let parent = try resolveEntry(reference, in: list)
            guard !parent.isSection else {
                throw AgentToolError("invalid_argument", "'\(parent.title)' is a section; nothing goes inside a section.", hint: "Pass inSection to add it to that section's part.")
            }
            guard !isSection else { throw AgentToolError("invalid_argument", "A section stays at the top level.", hint: "Drop parent, or use inSection to place the section.") }
            parentID = parent.id
            placeText = "inside “\(parent.title)”"
        } else if let reference = args.string("after") {
            let anchor = try resolveEntry(reference, in: list)
            parentID = list.parentID(of: anchor.id)
            if isSection, parentID != nil { throw AgentToolError("invalid_argument", "A section stays at the top level; '\(anchor.title)' is nested.") }
            position = (list.siblings(of: anchor.id).firstIndex { $0.id == anchor.id } ?? 0) + 1
            placeText = "after “\(anchor.title)”"
        } else if let reference = args.string("inSection") {
            let section = try resolveSection(reference, in: list)
            position = list.partEnd(of: section?.id)
            placeText = section.map { "in section “\($0.title)”" } ?? "before the first section"
        }
        var entry = Entry.blank(id: Entry.newID(), title: title)
        entry.isSection = isSection
        var changed: [String] = []
        try applyEntryFields(to: &entry, args: args, page: page, index: index, changed: &changed)
        if isSection, let field = changed.first(where: { !["icon", "color"].contains($0) }) {
            throw AgentToolError("invalid_argument", "A section carries only a title, an icon and a colour; '\(field)' does not fit it.")
        }
        if args.bool("done") == true, !isSection {
            entry.isDone = true
            entry.doneAt = Date()
        }
        let pictures = try localPictures(args, entry: entry, page: page)
        let path = index.titlePath(page.id)
        let noun = isSection ? "section" : Entry.kind.noun
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldAdd": "\(noun) “\(title)”", "page": path, "place": placeText]
            if !changed.isEmpty { preview["with"] = changed }
            if !pictures.isEmpty { preview["pictures"] = pictures.count }
            return AgentToolOutput(value: preview)
        }
        let saved = try database.addChecklistEntry(entry, to: page.id, under: parentID, at: position)
        var effects: [AgentEffect] = [.addedChecklistEntry(pageID: page.id, list: Entry.kind.rawValue, id: saved.id)]
        do {
            effects += try attach(Entry.self, pictures, to: saved.id, page: page)
        } catch {
            _ = revert(effects)
            throw error
        }
        var value: [String: Any] = ["id": saved.id, "added": "\(noun) “\(saved.title)”", "page": path, "place": placeText]
        if !isSection { value["open"] = try database.checklist(Entry.self, of: page.id).openCount }
        return AgentToolOutput(value: value, effects: effects)
    }

    private func updateTodo<Entry: ChecklistEntry>(
        _ type: Entry.Type, _ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments, dryRun: Bool
    ) throws -> AgentToolOutput {
        let target = try resolveEntry(try args.requiredString("item"), in: list)
        var draft = target
        var changed: [String] = []
        if args.has("title") {
            draft.title = try args.requiredString("title")
            changed.append("title")
        }
        if let flag = args.bool("section"), flag != target.isSection {
            draft.isSection = flag
            changed.append("section")
        }
        try applyEntryFields(to: &draft, args: args, page: page, index: index, changed: &changed)
        let pictures = try localPictures(args, entry: draft, page: page)
        guard !changed.isEmpty || !pictures.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one field besides page and item.")
        }
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "item": target.title, "wouldChange": changed]
            if !pictures.isEmpty { preview["pictures"] = pictures.count }
            return AgentToolOutput(value: preview)
        }
        let saved = try database.updateChecklistEntry(Entry.self, target.id, in: page.id) { $0 = draft }
        let effects = try attach(Entry.self, pictures, to: saved.id, page: page)
        if !pictures.isEmpty { changed.append("pictures") }
        return AgentToolOutput(value: ["id": saved.id, "item": saved.title, "changed": changed], effects: effects)
    }

    private func checkTodo<Entry: ChecklistEntry>(
        _ type: Entry.Type, _ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments, dryRun: Bool
    ) throws -> AgentToolOutput {
        let target = try resolveEntry(try args.requiredString("item"), in: list)
        let done = args.bool("done") ?? true
        guard !target.isSection else {
            throw AgentToolError("invalid_argument", "'\(target.title)' is a section; sections are not checked.", hint: "Check the entries after it.")
        }
        let inside = target.children.progressTotal
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "item": target.title, "wouldBe": done ? "done" : "open"]
            if done, inside > 0 { preview["inside"] = inside }
            return AgentToolOutput(value: preview)
        }
        let saved = try database.setChecklistEntry(Entry.self, target.id, done: done, in: page.id)
        var value: [String: Any] = ["id": target.id, "item": target.title, "done": done, "open": saved.openCount, "total": saved.progressTotal]
        if done, inside > 0 { value["inside"] = inside }
        return AgentToolOutput(value: value)
    }

    private func moveTodo<Entry: ChecklistEntry>(
        _ type: Entry.Type, _ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments, dryRun: Bool
    ) throws -> AgentToolOutput {
        let target = try resolveEntry(try args.requiredString("item"), in: list)
        let given = ["parent", "before", "after", "inSection"].filter { args.has($0) }
            + ["indent", "outdent"].filter { args.bool($0) == true }
        guard given.count == 1, let how = given.first else {
            throw AgentToolError("invalid_argument", "Give exactly one of parent, before, after, inSection, indent or outdent.")
        }
        var describe = ""
        let perform: () throws -> Bool
        switch how {
        case "parent":
            let reference = args.string("parent") ?? ""
            if Self.isTop(reference) {
                describe = "to the top level"
                perform = { try self.database.moveChecklistEntry(Entry.self, target.id, in: page.id, toParent: nil); return true }
            } else {
                let parent = try resolveEntry(reference, in: list)
                describe = "inside “\(parent.title)”"
                perform = { try self.database.moveChecklistEntry(Entry.self, target.id, in: page.id, toParent: parent.id); return true }
            }
        case "before", "after":
            let anchor = try resolveEntry(args.string(how) ?? "", in: list)
            guard anchor.id != target.id else { throw AgentToolError("invalid_argument", "An entry cannot go \(how) itself.") }
            let parentID = list.parentID(of: anchor.id)
            let siblings = list.siblings(of: anchor.id).filter { $0.id != target.id }
            let position = (siblings.firstIndex { $0.id == anchor.id } ?? siblings.count) + (how == "after" ? 1 : 0)
            describe = "\(how) “\(anchor.title)”"
            perform = { try self.database.moveChecklistEntry(Entry.self, target.id, in: page.id, toParent: parentID, at: position); return true }
        case "inSection":
            let section = try resolveSection(args.string("inSection") ?? "", in: list)
            describe = section.map { "into section “\($0.title)”" } ?? "before the first section"
            perform = { try self.database.moveChecklistEntry(Entry.self, target.id, in: page.id, toSection: section?.id); return true }
        case "indent":
            describe = "one level in"
            perform = { try self.database.indentChecklistEntry(Entry.self, target.id, in: page.id) }
        default:
            describe = "one level out"
            perform = { try self.database.outdentChecklistEntry(Entry.self, target.id, in: page.id) }
        }
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldMove": target.title, "to": describe]) }
        guard try perform() else {
            if how == "indent" {
                throw AgentToolError("invalid_argument", "'\(target.title)' cannot go inside the entry above it.", hint: "It needs an entry (not a section) right above it on its level, and the list nests up to \(Entry.maxDepth) levels.")
            }
            throw AgentToolError("invalid_argument", "'\(target.title)' is already at the top level.")
        }
        let saved = try database.checklist(Entry.self, of: page.id)
        return AgentToolOutput(value: ["id": target.id, "moved": target.title, "to": describe, "level": saved.depth(of: target.id) ?? 1])
    }

    private func removeTodo<Entry: ChecklistEntry>(
        _ type: Entry.Type, _ list: [Entry], page: ExercisePageManifest, index: AgentPageIndex, args: AgentArguments, dryRun: Bool
    ) throws -> AgentToolOutput {
        let target = try resolveEntry(try args.requiredString("item"), in: list)
        let inside = target.children.flattened().count
        let noun = target.isSection ? "section" : Entry.kind.noun
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldRemove": "\(noun) “\(target.title)”"]
            if inside > 0 { preview["inside"] = inside }
            return AgentToolOutput(value: preview)
        }
        try database.removeChecklistEntry(Entry.self, target.id, from: page.id)
        var value: [String: Any] = ["removed": "\(noun) “\(target.title)”", "id": target.id]
        if inside > 0 { value["inside"] = inside }
        return AgentToolOutput(value: value)
    }

    // MARK: - Arguments

    /// An entry by id, by the start of its id (4 characters or more), or by its exact title.
    private func resolveEntry<Entry: ChecklistEntry>(_ reference: String, in list: [Entry]) throws -> Entry {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !text.isEmpty else { throw AgentToolError("invalid_argument", "An entry reference must not be empty.") }
        let all = list.flattened().map(\.item)
        if let exact = all.first(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return exact }
        if text.count >= 4 {
            let prefixed = all.filter { $0.id.uppercased().hasPrefix(text.uppercased()) }
            if prefixed.count == 1 { return prefixed[0] }
        }
        let wanted = AgentValue.fold(text)
        let titled = all.filter { AgentValue.fold($0.title) == wanted }
        if titled.count == 1 { return titled[0] }
        if titled.count > 1 {
            throw AgentToolError("ambiguous", "\(titled.count) \(Entry.kind.plural) are titled '\(text)'.", hint: "Use an id: \(titled.prefix(6).map { "#" + Self.shortID($0.id) }.joined(separator: ", ")).")
        }
        let near = all.filter { AgentValue.fold($0.title).contains(wanted) }.prefix(5)
        throw AgentToolError(
            "not_found",
            "No \(Entry.kind.noun) or section matches '\(text)'.",
            hint: near.isEmpty ? "list_todos shows each entry with its #id." : "Did you mean: \(near.map { "\($0.title) (#\(Self.shortID($0.id)))" }.joined(separator: "; "))?"
        )
    }

    /// A section by id or title; nil for "top" (the part before the first section).
    private func resolveSection<Entry: ChecklistEntry>(_ reference: String, in list: [Entry]) throws -> Entry? {
        if Self.isTop(reference) { return nil }
        let found = try resolveEntry(reference, in: list)
        guard found.isSection, list.contains(where: { $0.id == found.id }) else {
            throw AgentToolError("invalid_argument", "'\(found.title)' is not a section.", hint: "Sections show as '## Title' in list_todos.")
        }
        return found
    }

    private static func isTop(_ reference: String) -> Bool {
        ["top", "root", "none", ""].contains(reference.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Applies the entry fields the arguments carry (`note`, `icon`, `color`, `cover`, `images`, `attachments`,
    /// `links`, `workouts`, `pages`) and lists their names in `changed`. A list replaces the links of its kind.
    private func applyEntryFields<Entry: ChecklistEntry>(
        to entry: inout Entry, args: AgentArguments, page: ExercisePageManifest, index: AgentPageIndex, changed: inout [String]
    ) throws {
        if let note = args.string("note") {
            entry.note = note
            changed.append("note")
        }
        if let icon = args.string("icon") {
            let value = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                entry.iconName = nil
                entry.iconType = nil
                entry.iconImage = nil
            } else if let picture = try? mediaFile(value, page: page, picture: true) {
                entry.iconImage = picture
                entry.iconName = nil
                entry.iconType = nil
            } else {
                entry.iconName = value
                entry.iconType = SkillBoardIconType.inferred(from: value)
                entry.iconImage = nil
            }
            changed.append("icon")
        }
        if let color = args.string("color") {
            let value = color.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                entry.colorHex = nil
            } else {
                guard let hex = SkillColors.normalizedHex(value) else {
                    throw AgentToolError("invalid_argument", "'\(value)' is not a colour.", hint: "Use six hex digits, like FF6A00.")
                }
                entry.colorHex = hex
            }
            changed.append("color")
        }
        if let cover = args.string("cover") {
            let value = cover.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.coverMediaFilename = value.isEmpty ? nil : try mediaFile(value, page: page, picture: true)
            changed.append("cover")
        }
        if let images = args.strings("images") {
            entry.imageFilenames = try images.map { try mediaFile($0, page: page, picture: true) }.uniqued()
            guard entry.imageFilenames.count <= Entry.maxImages else {
                throw AgentToolError("invalid_argument", "A \(Entry.kind.noun) shows up to \(Entry.maxImages) pictures.")
            }
            changed.append("images")
        }
        let pageLinks = Set(page.linkURLs)
        func isAttachment(_ link: TodoLink) -> Bool {
            switch link.target {
            case .media?: return true
            case .web(let url)?: return pageLinks.contains(url)
            default: return false
            }
        }
        var links = entry.links
        var added: [TodoLink] = []
        if let workouts = args.strings("workouts") {
            links.removeAll { $0.target?.workoutID != nil }
            added += try workouts.map { TodoLink(target: .workout(id: try linkedWorkout($0).id)) }
            changed.append("workouts")
        }
        if let pages = args.strings("pages") {
            links.removeAll { $0.target?.pageID != nil }
            added += try pages.map { TodoLink(target: .page(id: try index.resolve($0).id)) }
            changed.append("pages")
        }
        if let attachments = args.strings("attachments") {
            links.removeAll(where: isAttachment)
            added += try attachments.map { reference -> TodoLink in
                let value = reference.trimmingCharacters(in: .whitespacesAndNewlines)
                if case .web? = TmaxLink(value) { return TodoLink(url: value) }
                return TodoLink(target: .media(filename: try mediaFile(value, page: page, picture: false)))
            }
            changed.append("attachments")
        }
        if let web = args.strings("links") {
            links.removeAll { link in
                if case .web? = link.target { return !isAttachment(link) }
                return false
            }
            added += try web.map { address -> TodoLink in
                let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard case .web? = TmaxLink(value) else {
                    throw AgentToolError("invalid_argument", "'\(value)' is not a web address.", hint: "Links take http(s) addresses; use workouts and pages for the library.")
                }
                return TodoLink(url: value)
            }
            changed.append("links")
        }
        let combined = links + added
        guard combined.count <= Entry.maxLinks else {
            throw AgentToolError("invalid_argument", "A \(Entry.kind.noun) holds up to \(Entry.maxLinks) links.")
        }
        entry.links = combined
    }

    /// A file of the page by name or by its number in the page's media (1 = the first).
    private func mediaFile(_ reference: String, page: ExercisePageManifest, picture: Bool) throws -> String {
        let value = reference.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let name: String
        if let number = Int(value), page.mediaFilenames.indices.contains(number - 1) {
            name = page.mediaFilenames[number - 1]
        } else if page.mediaFilenames.contains(value) {
            name = value
        } else {
            throw AgentToolError(
                "not_found", "'\(reference)' is not a file of '\(page.title)'.",
                hint: page.mediaFilenames.isEmpty
                    ? "The page has no media yet; pass coverPath or imagePaths with a local picture."
                    : "Use a number from 1 to \(page.mediaFilenames.count) (list_todos shows the page's media), or coverPath / imagePaths for a new picture."
            )
        }
        if picture, !ChecklistMedia.isPicture(name) {
            throw AgentToolError("invalid_argument", "File \(value) of '\(page.title)' is not a picture.", hint: "Covers, icons and the strip take jpg, png, heic, gif or webp.")
        }
        return name
    }

    /// A workout by id or by exact name.
    private func linkedWorkout(_ reference: String) throws -> WorkoutManifest {
        let all = try database.listWorkouts()
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = all.first(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return match }
        let named = all.filter { AgentValue.fold($0.name) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) workouts are named '\(text)'.", hint: "Use one of the ids: \(named.map(\.id).joined(separator: ", ")).")
        }
        throw AgentToolError("not_found", "No workout matches '\(text)'.", hint: "Use list_workouts to see names and ids.")
    }

    /// The local pictures `coverPath` and `imagePaths` name, checked before anything is saved.
    private func localPictures<Entry: ChecklistEntry>(_ args: AgentArguments, entry: Entry, page: ExercisePageManifest) throws -> [(url: URL, role: ChecklistPictureRole)] {
        var pictures: [(url: URL, role: ChecklistPictureRole)] = []
        if let path = args.string("coverPath") { pictures.append((try AgentMedia.validate(path: path), .cover)) }
        for path in args.strings("imagePaths") ?? [] { pictures.append((try AgentMedia.validate(path: path), .image)) }
        guard !pictures.isEmpty else { return [] }
        if entry.isSection { throw AgentToolError("invalid_argument", "A section has no pictures.") }
        for picture in pictures where !ChecklistMedia.isPicture(picture.url.lastPathComponent) {
            throw AgentToolError("unsupported_media", "\(picture.url.lastPathComponent) is not a picture.", hint: "Covers and the strip take jpg, png, heic, gif or webp.")
        }
        let strip = pictures.filter { $0.role == .image }.count
        guard entry.imageFilenames.count + strip <= Entry.maxImages else {
            throw AgentToolError("invalid_argument", "A \(Entry.kind.noun) shows up to \(Entry.maxImages) pictures.")
        }
        guard page.mediaFilenames.count + pictures.count <= 20 else {
            throw AgentToolError("media_limit", "'\(page.title)' would hold more than 20 media files.", hint: "Reuse a picture it already has with cover or images.")
        }
        return pictures
    }

    private func attach<Entry: ChecklistEntry>(_ type: Entry.Type, _ pictures: [(url: URL, role: ChecklistPictureRole)], to entryID: String, page: ExercisePageManifest) throws -> [AgentEffect] {
        var effects: [AgentEffect] = []
        do {
            for picture in pictures {
                let filename = try database.attachChecklistPicture(Entry.self, from: picture.url, to: entryID, in: page.id, as: picture.role)
                effects.append(.attachedMedia(pageID: page.id, filename: filename))
            }
        } catch {
            _ = revert(effects)
            throw error
        }
        return effects
    }
}
