import Foundation

public final class AgentToolbox {
    public let database: DatabaseManager

    public init(database: DatabaseManager) {
        self.database = database
    }

    public func call(_ name: String, arguments: [String: Any], dryRun: Bool = false) throws -> AgentToolOutput {
        guard let tool = AgentToolRegistry.tool(named: name) else {
            let close = AgentToolRegistry.suggestions(for: name)
            throw AgentToolError("unknown_tool", "Unknown tool '\(name)'.", hint: close.isEmpty ? "Run tools to list what is available." : "Did you mean: \(close.joined(separator: ", "))?")
        }
        guard tool.executor == .core else {
            throw AgentToolError("wrong_executor", "'\(name)' is handled by the app, not the library toolbox.")
        }
        do {
            let args = try AgentArguments(tool: tool, raw: arguments)
            return try run(name, args, dryRun: dryRun)
        } catch {
            throw AgentToolError.translating(error)
        }
    }

    private func run(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        switch name {
        case "context": return try context()
        case "list_pages": return try listPages(args)
        case "search_pages": return try searchPages(args)
        case "get_page": return try getPage(args)
        case "create_container_page": return try createPage(args, exercise: false, dryRun: dryRun)
        case "create_exercise_page": return try createPage(args, exercise: true, dryRun: dryRun)
        case "attach_media": return try attachMedia(args, dryRun: dryRun)
        case "add_page_note": return try addPageNote(args, dryRun: dryRun)
        case "update_page": return try updatePage(args, dryRun: dryRun)
        case "move_page": return try movePage(args, dryRun: dryRun)
        case "delete_page": return try deletePage(args, dryRun: dryRun)
        case "build_workout": return try buildWorkout(args, dryRun: dryRun)
        case "list_workouts": return try listWorkouts()
        case "get_workout": return try getWorkout(args)
        case "delete_workout": return try deleteWorkout(args, dryRun: dryRun)
        case "get_recent_workouts": return try recentWorkouts(args)
        case "get_stats": return try stats(args)
        case "list_types": return try listTypes()
        case "batch": return try batch(args, dryRun: dryRun)
        default:
            if let output = try runBundleTool(name, args, dryRun: dryRun) { return output }
            if let output = try runWorkoutGroupTool(name, args, dryRun: dryRun) { return output }
            if let output = try runWorkoutTypeTool(name, args, dryRun: dryRun) { return output }
            if let output = try runMilestoneTool(name, args, dryRun: dryRun) { return output }
            if let output = try runNoteTool(name, args, dryRun: dryRun) { return output }
            if let output = try runSkillTool(name, args, dryRun: dryRun) { return output }
            if let output = try runPageTagTool(name, args, dryRun: dryRun) { return output }
            if let output = try runSkillTrainingTool(name, args, dryRun: dryRun) { return output }
            if let output = try runScheduleTool(name, args, dryRun: dryRun) { return output }
            if let output = try runPageContentTool(name, args, dryRun: dryRun) { return output }
            if let output = try runOrganizeTool(name, args, dryRun: dryRun) { return output }
            if let output = try runRecordTool(name, args, dryRun: dryRun) { return output }
            throw AgentToolError("unknown_tool", "Unknown tool '\(name)'.")
        }
    }

    func workoutTypes() -> [WorkoutType] {
        WorkoutType.all(custom: (try? database.loadConfig())?.customWorkoutTypes ?? [])
    }

    func resolveType(_ value: String?) throws -> WorkoutType? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let all = workoutTypes()
        if let match = all.first(where: { $0.id.caseInsensitiveCompare(value) == .orderedSame || $0.name.caseInsensitiveCompare(value) == .orderedSame }) {
            return match
        }
        throw AgentToolError("unknown_workout_type", "Unknown workout type '\(value)'.", hint: "Valid types: \(all.map(\.name).joined(separator: ", ")).")
    }

    func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    @discardableResult
    public func revert(_ effects: [AgentEffect]) -> [String] {
        var notes: [String] = []
        for effect in effects.reversed() {
            do {
                switch effect {
                case .createdPage(let id):
                    try database.deletePage(id: id)
                    notes.append("Moved page \(id) to the trash.")
                case .attachedMedia(let pageID, let filename):
                    try database.removeMediaFromPage(pageID: pageID, filename: filename)
                    notes.append("Removed attachment \(filename) from \(pageID).")
                case .createdWorkout(let id):
                    try database.deleteWorkout(id: id)
                    try? removeWorkoutFromGroups(id)
                    notes.append("Moved workout \(id) to the trash.")
                case .createdWorkoutGroup(let id):
                    try removeWorkoutGroup(id: id)
                    notes.append("Removed workout group \(id); its workouts stay saved.")
                case .changedMarkdown(let pageID, let previous):
                    var page = try database.getPage(id: pageID)
                    page.markdownBody = previous
                    try database.updatePage(id: pageID, manifest: page, newParentID: page.parentID)
                    notes.append("Restored the notes of \(pageID).")
                case .addedChecklistEntry(let pageID, let list, let id):
                    try revertChecklistEntry(pageID: pageID, list: list, id: id)
                    notes.append("Removed the \(list) \(id) from \(pageID).")
                case .createdTag(let ownerID, let tagID):
                    try database.deleteSkillType(tagID, in: ownerID)
                    notes.append("Removed tag \(tagID); its pages became untagged.")
                case .createdTagPreset(let ownerID, let presetID):
                    try database.deleteSkillTypePreset(presetID, in: ownerID)
                    notes.append("Removed tag preset \(presetID).")
                case .changedTag(let pageID, let previous):
                    try database.setSkillType(previous, for: pageID)
                    notes.append(previous == nil ? "Took the tag off \(pageID)." : "Put the earlier tag back on \(pageID).")
                case .changedIconImage(let pageID, let previousImage, let previousName, let previousType):
                    var page = try database.getPage(id: pageID)
                    page.iconImage = previousImage
                    page.iconName = previousName
                    page.iconType = previousType
                    try database.updatePage(id: pageID, manifest: page, newParentID: page.parentID)
                    notes.append("Restored the icon picture of \(pageID).")
                case .changedTraining(let pageID, let previous):
                    var page = try database.getPage(id: pageID)
                    page.trains = previous
                    try database.updatePage(id: pageID, manifest: page, newParentID: page.parentID)
                    notes.append("Restored the skills \(pageID) trains.")
                case .changedWorkout(let id, let previous):
                    let manifest = try JSONDecoder().decode(WorkoutManifest.self, from: Data(previous.utf8))
                    try database.updateWorkout(id: id, manifest: manifest)
                    notes.append("Restored workout \(id) to how it was.")
                case .changedSchedule(let previous):
                    var config = try database.loadConfig()
                    config.workoutSchedule = try JSONDecoder().decode(WeeklyWorkoutSchedule.self, from: Data(previous.utf8))
                    try database.saveConfig(config)
                    notes.append("Restored the schedule to how it was.")
                case .changedPage(let id, let previous):
                    let manifest = try JSONDecoder().decode(ExercisePageManifest.self, from: Data(previous.utf8))
                    try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
                    notes.append("Restored page \(id) to how it was.")
                case .loggedHistoryEntry(let id):
                    notes.append(try revertLoggedHistoryEntry(id))
                case .removedHistoryEntry(let entry):
                    notes.append(try revertRemovedHistoryEntry(entry))
                }
            } catch {
                notes.append("Could not reverse \(effect): \(AgentToolError.translating(error).message)")
            }
        }
        return notes
    }
}

extension AgentToolbox {
    private func context() throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let exercises = index.pages.filter { $0.pageType == .exercise }
        let allRoots = index.children(of: nil)
        let roots = allRoots.prefix(30).map { root -> [String: Any] in
            var out: [String: Any] = [
                "path": root.title,
                "exercises": index.descendants(of: root.id).filter { $0.pageType == .exercise }.count,
            ]
            if let type = index.effectiveType(root.id) { out["type"] = type.name }
            return out
        }
        var library: [String: Any] = ["exercises": exercises.count, "folders": index.pages.filter { $0.pageType == nil }.count, "roots": roots]
        if allRoots.count > 30 { library["moreRoots"] = allRoots.count - 30 }
        let noteCount = index.pages.filter { $0.pageType == .note }.count
        if noteCount > 0 { library["notes"] = noteCount }
        let skillCount = index.pages.filter { $0.pageType == .skill || $0.pageType == .tutorial }.count
        if skillCount > 0 { library["skills"] = skillCount }
        var overview: [String: Any] = [
            "library": library,
            "types": workoutTypes().map(\.name),
            "workouts": (try? database.listWorkouts().count) ?? 0,
            "conventions": [
                "Folders organize pages; exercise pages are workout-ready; note pages are Markdown documents (create_note_page); skill and tutorial pages (create_skill_page) are things to learn, with notes, many clips, links and sub-pages, sorted into groups on their parent's skill board.",
                "A page that needs no sub-skills takes noSkills (no skill board, progress, to-dos, milestones or learn-first list). widgets picks the tiles above a page's tabs: [\"auto\"] (default) for those with something to show, [] for none, or the tiles in order. Set both when creating a page or with update_page.",
                "Reference a page by title path ('Lower Body/Glutes') or id. Lists show paths.",
                "Root folders own the workout type; nested pages inherit it.",
                "Tags are like the options of a Notion Select property: they sort exercise and note pages into the columns of a folder's board (for example Morning flow, Between sets, Evening stretch, Reference). The top folder of a tree keeps them and every page below it shares them: list_page_tags, create_page_tag (ifExists reuse), update_page_tag, delete_page_tag; put one on a page with the tag argument of update_page or the create tools, and find tagged pages with search_pages tag. A tag is not the workout type and not a completion status; a page wears at most one.",
                "Attach media by absolute path; the app copies it. The first item is the cover.",
                "Deletes go to the trash. dryRun previews a write.",
                "A workout section is one timed exercise or a bundle: several exercises played back to back (each with its own seconds and rest) for N sets, in order or shuffled. Build with build_workout, change with add_workout_section, update_workout_section and remove_workout_section.",
                "Workout groups are the titled sections on the Workouts page that hold whole workouts in the user's order (create_workout_group, update_workout_group, list_workout_groups). They are not the sections inside a workout.",
                "A rest between sets (restExercise) or after a section (restAfterExercise) can hold a rest exercise, so a single exercise with a move between its sets is a timed section, never a bundle. Not every rest can hold one: it needs more than one set, a rest above 0 and a rest at least as long as the exercise.",
                "A skill lists the exercises that train it on tiers from S (the best way to train it) down to D: set_skill_training fills a whole skill in one call, get_skill_training reads it. The skill's Tiers view shows them.",
                "The schedule is the Schedule page: plans are weekly templates of workouts on weekdays with optional times; a week follows the plan chosen for it (or is a vacation); single dates can carry one-off entries (add_schedule_entries puts a whole program on dates in one call, remove_schedule_days clears a range); an entry is done by a matching workout in the history or by a hand mark; training days set the weekly streak. Read it with get_schedule and list_schedule_plans; change it with create_schedule_plan, update_schedule_plan, select_schedule_plan, add_schedule_entry, update_schedule_entry, remove_schedule_entry, complete_schedule_entry and set_training_days. Following a plan from a week never rewrites earlier weeks.",
                "Inside a page: get_page numbers its media (index), marks the banner, icon picture and learn-first files, and shows learn-first pages, attached pages, link comments and drop sets. Change them with update_media (caption, place, banner, icon picture, learn-first flag), remove_media, update_link, update_learn_first, update_linked_pages and the dropSets argument of update_page. Symbol and emoji icons (the icon argument) are for notes, skills and tutorials; any page can wear a picture icon through update_media icon.",
                "Records: list_history, log_workout and delete_history_entry manage completed workouts (they feed streaks, stats and the schedule); list_outdoor_activities, get_outdoor_activity, update_outdoor_activity and delete_outdoor_activity manage recorded outdoor activities; validate_library checks the library files and create_backup copies the library; duplicate_workout copies a workout.",
                "A Boxing combo is a workout section whose calls (1-2, 1-2-3, 1-1-2-slip) the phone says aloud as 'one, two, three': build it with the combo argument of build_workout or add_workout_section and change it with update_workout_section; get_workout shows kind combo with its calls.",
                "Order and organization: move_page can place a page before or after a sibling or at a position; reorder_pages sets the order of a container's children; update_skill changes a skill's status, group and place; update_skill_group and delete_skill_group edit the groups of a skill board; duplicate_page copies a page (deep for everything inside it); list_trash and restore_from_trash bring deleted pages and workouts back.",
            ],
        ]
        if let schedule = scheduleOverview() { overview["schedule"] = schedule }
        return AgentToolOutput(value: overview)
    }

    private func listPages(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let parent = try args.string("parent").map { try index.resolve($0) }
        var value: [String: Any] = [:]
        if let parent { value["in"] = index.titlePath(parent.id) }
        if let parent, parent.pageKind == .leaf {
            value["pages"] = [] as [Any]
            return AgentToolOutput(value: value)
        }
        let depth = args.int("depth") ?? 1
        var budget = max(1, min(args.int("limit") ?? 60, 300))
        var skipped = 0
        func nodes(_ id: String?, level: Int) -> [[String: Any]] {
            var out: [[String: Any]] = []
            for page in index.children(of: id) {
                guard budget > 0 else { skipped += 1; continue }
                budget -= 1
                var node = index.summary(page)
                if level < depth, page.pageKind == .container {
                    let inner = nodes(page.id, level: level + 1)
                    if !inner.isEmpty {
                        node["pages"] = inner
                        node.removeValue(forKey: "children")
                    }
                }
                out.append(node)
            }
            return out
        }
        value["pages"] = nodes(parent?.id, level: 1)
        if skipped > 0 {
            value["more"] = skipped
            value["hint"] = "Pass parent to open a folder, or raise limit."
        }
        return AgentToolOutput(value: value)
    }

    private func searchPages(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let type = try resolveType(args.string("type"))
        let tagFilter = (args.string("tag")?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : AgentValue.fold($0) }
        let rawQuery = (args.string("query") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty || tagFilter != nil else {
            throw AgentToolError("invalid_argument", "'query' must not be empty.", hint: "Pass words to find, or an empty query with tag to list the pages wearing a tag.")
        }
        let query = AgentValue.fold(rawQuery)
        let kind = args.string("kind")
        let limit = args.int("limit") ?? 20
        var ranked: [(Int, ExercisePageManifest)] = []
        for page in index.pages {
            if let kind, !index.matches(page, kind: kind) { continue }
            if let type, index.effectiveType(page.id)?.id != type.id { continue }
            if let tagFilter {
                guard let tag = index.tag(of: page),
                      tag.id.caseInsensitiveCompare(tagFilter) == .orderedSame || AgentValue.fold(tag.title) == tagFilter else { continue }
                if query.isEmpty {
                    ranked.append((1, page))
                    continue
                }
            }
            let title = AgentValue.fold(page.title)
            let path = AgentValue.fold(index.titlePath(page.id))
            var score = 0
            if title == query { score = 100 }
            else if title.hasPrefix(query) { score = 80 }
            else if title.contains(query) { score = 60 }
            else if path.contains(query) { score = 40 }
            else if AgentValue.fold(page.markdownBody).contains(query) { score = 20 }
            else if query.split(separator: " ").allSatisfy({ title.contains($0) || path.contains($0) }) { score = 30 }
            else {
                let words = query.split(separator: " ")
                let haystack = AgentValue.fold(([page.markdownBody] + Array(page.mediaComments.values) + page.linkURLs).joined(separator: " "))
                if words.allSatisfy({ title.contains($0) || path.contains($0) || haystack.contains($0) }) { score = 10 }
            }
            if score > 0 { ranked.append((score, page)) }
        }
        ranked.sort { $0.0 != $1.0 ? $0.0 > $1.0 : index.titlePath($0.1.id) < index.titlePath($1.1.id) }
        let shown = ranked.prefix(limit).map { index.summary($0.1) }
        var value: [String: Any] = ["total": ranked.count, "results": Array(shown)]
        if ranked.count > shown.count { value["more"] = ranked.count - shown.count }
        return AgentToolOutput(value: value)
    }

    private func getPage(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        var value = index.summary(page, withID: true)
        if let type = index.effectiveType(page.id) { value["type"] = type.name }
        if page.pageType == .skill || page.pageType == .tutorial {
            if let status = page.skillStatus { value["status"] = status.rawValue }
            if let owner = page.parentID.flatMap({ index.byID[$0] }), let sectionID = page.skillBoardSectionID, let group = owner.skillBoardSection(sectionID) {
                value["group"] = group.title
            }
        }
        if !page.skillBoardSections.isEmpty {
            let inside = index.children(of: page.id)
            value["groups"] = page.orderedSkillBoardSections.map { section -> [String: Any] in
                var item: [String: Any] = ["title": section.title, "id": SkillGroupID.make(containerID: page.id, sectionID: section.id)]
                let count = inside.filter { $0.skillBoardSectionID == section.id }.count
                if count > 0 { item["skills"] = count }
                if !section.markdownBody.isEmpty { item["notes"] = String(section.markdownBody.prefix(1500)) }
                return item
            }
        }
        value.merge(bodyExcerpt(page.markdownBody, offset: args.int("bodyOffset") ?? 0)) { _, new in new }
        if !page.linkURLs.isEmpty { value["linkURLs"] = page.linkURLs }
        if let rest = page.restAfter { value["restAfter"] = rest }
        if let rest = page.restBetweenSets { value["restBetweenSets"] = rest }
        if let prepare = page.prepareTime { value["prepareTime"] = prepare }
        addPageContent(of: page, index: index, to: &value)
        addChecklistCounts(of: page, to: &value)
        if page.hidesSkills { value["noSkills"] = true }
        if let widgets = page.widgets { value["widgets"] = widgets }
        let inside = index.children(of: page.id)
        if !inside.isEmpty {
            value["pages"] = inside.prefix(60).map { index.summary($0) }
            if inside.count > 60 { value["more"] = inside.count - 60 }
            value.removeValue(forKey: "children")
        }
        return AgentToolOutput(value: value)
    }

    private func createPage(_ args: AgentArguments, exercise: Bool, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let title = try args.requiredString("title")
        let parent = try args.string("parent").map { try index.resolve($0) }
        if let parent, parent.pageKind != .container {
            throw AgentToolError("invalid_parent", "'\(parent.title)' is \(parent.pageType == .note ? "a note" : "an exercise page") and cannot contain other pages.", hint: "Choose a container with list_pages.")
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
        var warnings: [String] = []
        let requested = try resolveType(args.string("workoutType"))
        var appliedType: WorkoutType?
        if parent == nil { appliedType = requested }
        else if requested != nil { warnings.append("workoutType ignored: nested pages inherit it from their root container.") }
        let attachments = try args.objects("media").map { item -> (url: URL, comment: String?) in
            (try AgentMedia.validate(path: item["path"] as? String ?? ""), (item["comment"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        guard attachments.count <= 20 else { throw AgentToolError("media_limit", "A page holds up to 20 attachments.") }
        let body = args.string("markdownBody") ?? ""
        let links = args.strings("linkURLs") ?? []
        let flags = try pageFlags(args, pageType: exercise ? .exercise : nil)
        var manifest: ExercisePageManifest
        if exercise {
            manifest = ExercisePageManifest(
                title: title, pageKind: .leaf, markdownBody: body, linkURLs: links, workoutType: appliedType,
                duration: args.int("duration") ?? 30, restAfter: args.int("restAfter"), prepareTime: args.int("prepareTime"),
                sets: args.int("sets"), restBetweenSets: args.int("restBetweenSets"), parentID: parent?.id
            )
        } else {
            manifest = ExercisePageManifest(title: title, pageKind: .container, markdownBody: body, linkURLs: links, workoutType: appliedType, parentID: parent?.id)
        }
        flags.apply(to: &manifest)
        if !flags.isEmpty { warnings += pageFlagWarnings(manifest) }
        let tag = try exercise ? requestedTag(args, forNew: .exercise, in: parent, index: index) : nil
        manifest.typeID = tag?.id
        let path = (parent.map { index.titlePath($0.id) + "/" } ?? "") + title
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldCreate": path]
            if !attachments.isEmpty { preview["media"] = attachments.count }
            if !warnings.isEmpty { preview["warnings"] = warnings }
            return AgentToolOutput(value: preview)
        }
        try database.createPage(manifest: manifest, parentID: parent?.id)
        var saved: [String] = []
        do {
            for item in attachments {
                let filename = try database.uploadMediaToPage(pageID: manifest.id, sourceURL: item.url)
                saved.append(filename)
                if let comment = item.comment { try database.updateMediaComment(pageID: manifest.id, filename: filename, comment: comment) }
            }
        } catch {
            try? database.deletePage(id: manifest.id)
            throw error
        }
        var value: [String: Any] = ["id": manifest.id, "path": path]
        if !saved.isEmpty { value["media"] = saved.count }
        if let tag { value["tag"] = tag.title }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: [.createdPage(id: manifest.id)])
    }

    private func attachMedia(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        if page.pageType == .note { return try attachImageToNote(page, args, titlePath: index.titlePath(page.id), dryRun: dryRun) }
        let url = try AgentMedia.validate(path: try args.requiredString("path"))
        let limit = DatabaseManager.mediaLimit(for: page)
        guard page.mediaFilenames.count < limit else { throw AgentToolError("media_limit", "'\(page.title)' already has \(limit) attachments.") }
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldAttach": url.lastPathComponent, "to": index.titlePath(page.id)])
        }
        let filename = try database.uploadMediaToPage(pageID: page.id, sourceURL: url)
        let effects: [AgentEffect] = [.attachedMedia(pageID: page.id, filename: filename)]
        if let comment = args.string("comment"), !comment.isEmpty {
            try database.updateMediaComment(pageID: page.id, filename: filename, comment: comment)
        }
        if args.bool("makeCover") == true {
            let current = try database.getPage(id: page.id).mediaFilenames
            try database.reorderPageMedia(pageID: page.id, filenames: [filename] + current.filter { $0 != filename })
        }
        return AgentToolOutput(value: ["id": page.id, "path": index.titlePath(page.id), "attached": AgentMedia.kind(ofFilename: filename)], effects: effects)
    }

    private func addPageNote(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        let note = try args.requiredString("note")
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldNote": index.titlePath(page.id)]) }
        var updated = page
        updated.markdownBody = page.pageType == .note
            ? appendedNoteBody(page.markdownBody, adding: note)
            : page.markdownBody + (page.markdownBody.isEmpty ? "" : "\n\n---\n\n") + "**Note** (\(iso(Date()))): \(note)"
        try database.updatePage(id: page.id, manifest: updated, newParentID: page.parentID)
        return AgentToolOutput(value: ["id": page.id, "path": index.titlePath(page.id), "noted": true], effects: [.changedMarkdown(pageID: page.id, previous: page.markdownBody)])
    }

    private func updatePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        var updated = page
        if page.pageType == .note { try rejectNonNoteFields(args) }
        var changed: [String] = []
        if args.has("title") { updated.title = try args.requiredString("title"); changed.append("title") }
        if let body = args.string("markdownBody") { updated.markdownBody = body; changed.append("markdownBody") }
        if let value = args.int("duration") { updated.duration = value; changed.append("duration") }
        if let value = args.int("restAfter") { updated.restAfter = value; changed.append("restAfter") }
        if let value = args.int("sets") { updated.sets = value; changed.append("sets") }
        if let value = args.int("restBetweenSets") { updated.restBetweenSets = value; changed.append("restBetweenSets") }
        if let value = args.int("prepareTime") { updated.prepareTime = value; changed.append("prepareTime") }
        if args.has("dropSets") {
            updated.dropSetTemplates = try dropSetTemplates(from: args.objects("dropSets"), for: updated, index: index)
            changed.append("dropSets")
        }
        if let value = args.strings("linkURLs") { updated.linkURLs = value; changed.append("linkURLs") }
        if let type = try resolveType(args.string("workoutType")) {
            guard page.parentID == nil else {
                throw AgentToolError("invalid_page", "Only root pages own a workout type; '\(page.title)' inherits it.", hint: "Change the type on its root container instead.")
            }
            updated.workoutType = type
            changed.append("workoutType")
        }
        if let icon = args.string("icon") {
            try applyIcon(icon, to: &updated)
            changed.append("icon")
        }
        var tagChange: (previous: String?, next: SkillType?)?
        if args.has("tag") {
            let next = try requestedTag(args, on: page, index: index)
            updated.typeID = next?.id
            tagChange = (page.typeID, next)
            changed.append("tag")
        }
        var iconPicture: AgentIconPicture?
        if let raw = args.string("iconImage") {
            guard page.pageType != .note else {
                throw AgentToolError("invalid_page", "Notes show pictures inline; 'iconImage' does not apply.", hint: "Use attach_media to put a picture in a note.")
            }
            let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty {
                iconPicture = AgentIconPicture(url: nil)
            } else {
                let url = try AgentMedia.validate(path: clean)
                guard AgentMedia.images.contains(url.pathExtension.lowercased()) else {
                    throw AgentToolError("unsupported_media", "An icon picture must be an image; '.\(url.pathExtension.lowercased())' is not.", hint: "Use jpg, png, heic, gif or webp.")
                }
                let limit = DatabaseManager.mediaLimit(for: page)
                guard page.mediaFilenames.count < limit else {
                    throw AgentToolError("media_limit", "'\(page.title)' already has \(limit) attachments.")
                }
                iconPicture = AgentIconPicture(url: url)
            }
            changed.append("iconImage")
        }
        let flags = try pageFlags(args, pageType: page.pageType)
        flags.apply(to: &updated)
        changed += flags.changed
        guard !changed.isEmpty else { throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one field besides page.") }
        let parentPrefix = page.parentID.flatMap { index.byID[$0] == nil ? nil : index.titlePath($0) + "/" } ?? ""
        let path = parentPrefix + updated.title
        let warnings = flags.isEmpty ? [] : pageFlagWarnings(updated)
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "path": path, "wouldChange": changed]
            if !warnings.isEmpty { preview["warnings"] = warnings }
            return AgentToolOutput(value: preview)
        }
        var effects: [AgentEffect] = []
        if let snapshot = pageUndoEffect(try database.getPage(id: page.id)) { effects.append(snapshot) }
        var uploadedIcon: String?
        if let iconPicture {
            if let url = iconPicture.url {
                let filename = try database.uploadMediaToPage(pageID: page.id, sourceURL: url)
                uploadedIcon = filename
                effects.append(.attachedMedia(pageID: page.id, filename: filename))
                updated.mediaFilenames = try database.getPage(id: page.id).mediaFilenames
                updated.iconImage = filename
            } else {
                updated.iconImage = nil
            }
            effects.append(.changedIconImage(pageID: page.id, previousImage: page.iconImage, previousName: page.iconName, previousType: page.iconType))
        }
        do {
            try database.updatePage(id: page.id, manifest: updated, newParentID: page.parentID)
        } catch {
            if let uploadedIcon { try? database.removeMediaFromPage(pageID: page.id, filename: uploadedIcon) }
            throw error
        }
        var value: [String: Any] = ["id": page.id, "path": path, "changed": changed]
        if let tagChange {
            if let next = tagChange.next { value["tag"] = next.title } else { value["untagged"] = true }
            if tagChange.previous != tagChange.next?.id { effects.append(.changedTag(pageID: page.id, previous: tagChange.previous)) }
        }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: effects)
    }

    private func movePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        try organizeMovePage(args, dryRun: dryRun)
    }

    private func deletePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let page = try index.resolve(try args.requiredString("page"))
        let inside = index.descendants(of: page.id).count
        let path = index.titlePath(page.id)
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldTrash": path]
            if inside > 0 { preview["inside"] = inside }
            return AgentToolOutput(value: preview)
        }
        try database.deletePage(id: page.id)
        var value: [String: Any] = ["trashed": path, "id": page.id]
        if inside > 0 { value["inside"] = inside }
        return AgentToolOutput(value: value)
    }

    private func recentWorkouts(_ args: AgentArguments) throws -> AgentToolOutput {
        let days = args.int("days") ?? 7
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let history = try database.readHistory().filter { $0.completedAt >= cutoff }
        let entries = history.suffix(30).reversed().map { entry -> [String: Any] in
            var item: [String: Any] = ["name": entry.workoutName, "at": String(iso(entry.completedAt).prefix(16)), "seconds": entry.durationCompleted, "type": entry.workoutType.name]
            if entry.isPartial { item["partial"] = true }
            return item
        }
        var value: [String: Any] = ["days": days, "total": history.count, "entries": Array(entries)]
        if history.count > 30 { value["more"] = history.count - 30 }
        return AgentToolOutput(value: value)
    }

    private func stats(_ args: AgentArguments) throws -> AgentToolOutput {
        let type = try resolveType(args.string("type"))
        let stats = try database.getStats(type: type, days: args.int("days"))
        let exercises = (try? AgentPageIndex(database: database).pages.filter { $0.pageType == .exercise }.count) ?? 0
        return AgentToolOutput(value: ["workouts": stats.count, "currentStreak": stats.streak, "bestStreak": stats.bestStreak, "totalMinutes": stats.totalDuration / 60, "exercises": exercises])
    }

    private func listTypes() throws -> AgentToolOutput {
        AgentToolOutput(value: ["types": workoutTypes().map(\.name), "details": workoutTypeDetails()])
    }
}

/// The icon picture an `update_page` call sets: the local image to copy into the page, or nil to clear the picture.
struct AgentIconPicture {
    let url: URL?
}

/// A page's `noSkills` and `widgets` settings as a create or update call passes them; nil leaves one alone.
struct AgentPageFlags {
    var noSkills: Bool?
    var widgets: PageWidgetSelection?

    var isEmpty: Bool { noSkills == nil && widgets == nil }

    /// The settings the call changes, as `update_page` lists them.
    var changed: [String] { (noSkills == nil ? [] : ["noSkills"]) + (widgets == nil ? [] : ["widgets"]) }

    func apply(to manifest: inout ExercisePageManifest) {
        if let noSkills { manifest.noSkills = noSkills ? true : nil }
        if let widgets { manifest.widgetSelection = widgets }
    }
}

extension AgentToolbox {
    /// Reads `noSkills` and `widgets` for a page of `pageType`. `widgets` lists tiles in order; ["auto"] goes back to
    /// automatic and [] or ["none"] shows none. A tile the page cannot show is refused, naming the ones it can.
    func pageFlags(_ args: AgentArguments, pageType: PageType?) throws -> AgentPageFlags {
        let passed = ["noSkills", "widgets"].filter { args.has($0) }
        if pageType == .note, !passed.isEmpty {
            throw AgentToolError("invalid_page", "Notes show no widgets and no skills; '\(passed.joined(separator: "' and '"))' \(passed.count == 1 ? "does" : "do") not apply.")
        }
        var flags = AgentPageFlags(noSkills: args.bool("noSkills"))
        if let names = args.strings("widgets") { flags.widgets = try widgetSelection(names, for: pageType) }
        return flags
    }

    /// The chosen tiles a page that needs no skills keeps hidden, as a warning.
    func pageFlagWarnings(_ manifest: ExercisePageManifest) -> [String] {
        guard manifest.hidesSkills, case .chosen(let kinds) = manifest.widgetSelection else { return [] }
        let hidden = kinds.filter(\.isSkillRelated).map(\.rawValue)
        guard !hidden.isEmpty else { return [] }
        return ["The \(hidden.joined(separator: ", ")) widget\(hidden.count == 1 ? " stays" : "s stay") hidden while noSkills is on."]
    }

    private func widgetSelection(_ names: [String], for pageType: PageType?) throws -> PageWidgetSelection {
        if names.isEmpty || names == ["none"] { return .hidden }
        if names == ["auto"] { return .automatic }
        let available = PageWidgetKind.available(for: pageType)
        var kinds: [PageWidgetKind] = []
        for name in names {
            guard let kind = PageWidgetKind(rawValue: name) else {
                if name == "auto" || name == "none" {
                    throw AgentToolError("invalid_argument", "'\(name)' must be the only entry of widgets.", hint: "Pass [\"auto\"] for automatic, [] or [\"none\"] for no widgets, or the tiles to show.")
                }
                let valid = PageWidgetKind.allCases.map(\.rawValue).joined(separator: ", ")
                throw AgentToolError("invalid_argument", "Unknown widget '\(name)'.", hint: "Valid widgets: \(valid); or [\"auto\"] alone, or [] for none.")
            }
            guard available.contains(kind) else {
                let page: String
                switch pageType {
                case .exercise?: page = "An exercise page"
                case .skill?: page = "A skill page"
                case .tutorial?: page = "A tutorial page"
                case .note?: page = "A note"
                case nil: page = "A folder"
                }
                let hint = available.isEmpty ? "It shows no widgets." : "It can show: \(available.map(\.rawValue).joined(separator: ", "))."
                throw AgentToolError("invalid_argument", "\(page) cannot show the \(kind.rawValue) widget.", hint: hint)
            }
            if !kinds.contains(kind) { kinds.append(kind) }
        }
        return .chosen(kinds)
    }
}

extension AgentToolbox {
    private static let referencePattern = try! NSRegularExpression(pattern: #"^\$(\d+|last)((?:\.[A-Za-z0-9_]+)*)$"#)

    private func containsReference(_ value: Any) -> Bool {
        if let text = value as? String { return text.hasPrefix("$") && Self.referencePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil }
        if let dictionary = value as? [String: Any] { return dictionary.values.contains { containsReference($0) } }
        if let array = value as? [Any] { return array.contains { containsReference($0) } }
        return false
    }

    private func substitute(_ value: Any, results: [[String: Any]]) throws -> Any {
        if let text = value as? String, let match = Self.referencePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let head = String(text[Range(match.range(at: 1), in: text)!])
            let tail = String(text[Range(match.range(at: 2), in: text)!])
            let position = head == "last" ? results.count - 1 : Int(head) ?? -1
            guard results.indices.contains(position) else {
                throw AgentToolError("bad_reference", "'\(text)' refers to an operation that has not run.")
            }
            var current: Any = results[position]
            for key in tail.split(separator: ".").map(String.init) {
                if let dictionary = current as? [String: Any], let next = dictionary[key] { current = next }
                else if let array = current as? [Any], let offset = Int(key), array.indices.contains(offset) { current = array[offset] }
                else { throw AgentToolError("bad_reference", "'\(text)' has no value at '\(key)'.") }
            }
            return current
        }
        if let dictionary = value as? [String: Any] { return try dictionary.mapValues { try substitute($0, results: results) } }
        if let array = value as? [Any] { return try array.map { try substitute($0, results: results) } }
        return value
    }

    func batch(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let operations = args.objects("operations")
        guard !operations.isEmpty, operations.count <= 100 else {
            throw AgentToolError("invalid_argument", "A batch needs between 1 and 100 operations.")
        }
        var results: [[String: Any]] = []
        var effects: [AgentEffect] = []
        for (position, operation) in operations.enumerated() {
            let name = operation["tool"] as? String ?? ""
            do {
                guard let tool = AgentToolRegistry.tool(named: name), tool.executor == .core, name != "batch" else {
                    throw AgentToolError("invalid_argument", "'\(name)' cannot run inside a batch.", hint: "Batches run library tools only.")
                }
                let raw = operation["arguments"] as? [String: Any] ?? [:]
                if dryRun && containsReference(raw) {
                    _ = try AgentArguments(tool: tool, raw: raw, allowReferences: true)
                    results.append(["dryRun": true, "deferred": true])
                    continue
                }
                let resolved = try substitute(raw, results: results) as? [String: Any] ?? raw
                let output = try call(name, arguments: resolved, dryRun: dryRun)
                results.append(output.value)
                effects.append(contentsOf: output.effects)
            } catch {
                let failure = AgentToolError.translating(error)
                let rolledBack = dryRun ? [] : revert(effects)
                throw AgentToolError(
                    "batch_failed",
                    "Operation \(position) (\(name)) failed: \(failure.message)",
                    hint: failure.hint,
                    details: ["index": position, "completed": results.count, "cause": failure.code, "rolledBack": rolledBack.count]
                )
            }
        }
        var value: [String: Any] = ["results": results]
        if dryRun { value["dryRun"] = true }
        return AgentToolOutput(value: value, effects: effects)
    }
}
