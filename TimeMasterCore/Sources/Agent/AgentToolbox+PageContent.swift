import Foundation

extension AgentToolbox {
    static let dropSetLimit = 60

    func runPageContentTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "update_media": return try changeMedia(args, dryRun: dryRun)
        case "remove_media": return try dropMedia(args, dryRun: dryRun)
        case "update_link": return try changeLink(args, dryRun: dryRun)
        case "update_learn_first": return try changeLearnFirst(args, dryRun: dryRun)
        case "update_linked_pages": return try changeLinkedPages(args, dryRun: dryRun)
        default: return nil
        }
    }

    func pageSnapshot(_ manifest: ExercisePageManifest) -> AgentEffect? {
        guard let data = try? JSONEncoder().encode(manifest), let text = String(data: data, encoding: .utf8) else { return nil }
        return .changedPage(id: manifest.id, previous: text)
    }

    func addPageContent(of page: ExercisePageManifest, index: AgentPageIndex, to value: inout [String: Any]) {
        let attachments = mediaEntries(of: page)
        if !attachments.isEmpty { value["media"] = attachments }
        if let links = linkEntries(of: page) { value["links"] = links }
        if !page.dependencyPageIDs.isEmpty { value["learnFirst"] = page.dependencyPageIDs.map { referenceEntry($0, index: index) } }
        if !page.linkedPageIDs.isEmpty { value["linkedPages"] = page.linkedPageIDs.map { referenceEntry($0, index: index) } }
        if let icon = iconEntry(of: page) { value["icon"] = icon }
        if !page.dropSetTemplates.isEmpty { value["dropSets"] = page.dropSetTemplates.map { dropSetEntry($0, index: index) } }
        value["created"] = shortDate(page.createdAt)
        value["updated"] = shortDate(page.updatedAt)
    }

    func dropSetTemplates(from items: [[String: Any]], for page: ExercisePageManifest, index: AgentPageIndex) throws -> [PageDropSetTemplate] {
        guard page.pageType == .exercise else {
            throw AgentToolError("invalid_page", "'\(page.title)' is \(pageNoun(page)); only exercise pages have drop sets.", hint: "Drop sets are extra exercises played after a set when an exercise page goes into a workout.")
        }
        guard items.count <= Self.dropSetLimit else {
            throw AgentToolError("invalid_argument", "A page holds up to \(Self.dropSetLimit) drop sets.")
        }
        let sets = max(1, page.sets ?? 1)
        var reusable = page.dropSetTemplates
        return try items.enumerated().map { offset, item in
            let label = "dropSets[\(offset)]"
            var source: ExercisePageManifest?
            if let reference = (item["exercise"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !reference.isEmpty {
                let found = try index.resolve(reference)
                guard found.pageType == .exercise else {
                    throw AgentToolError("invalid_argument", "'\(label).exercise' must be an exercise page; '\(found.title)' is \(pageNoun(found)).", hint: "Leave exercise out and pass a name to add a drop set that is not a library page.")
                }
                source = found
            }
            let given = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = given.isEmpty ? source?.title ?? "" : given
            guard !name.isEmpty else {
                throw AgentToolError("invalid_argument", "'\(label)' needs a name or an exercise.")
            }
            let set = item["set"] as? Int ?? sets
            guard (1...sets).contains(set) else {
                throw AgentToolError(
                    "invalid_argument", "'\(label).set' is \(set), but '\(page.title)' has \(sets) set\(sets == 1 ? "" : "s").",
                    hint: "Give the page more sets first (update_page sets), in the same call or an earlier one."
                )
            }
            let exerciseID = source?.id ?? ""
            let kept = reusable.firstIndex { $0.setIndex == set - 1 && $0.exerciseID == exerciseID && $0.name == name }.map { reusable.remove(at: $0).id }
            return PageDropSetTemplate(
                id: kept ?? UUID().uuidString, setIndex: set - 1, exerciseID: exerciseID, name: name,
                duration: item["duration"] as? Int ?? source?.duration ?? 30,
                restAfter: item["restAfter"] as? Int ?? source?.restAfter ?? 0
            )
        }
    }

    private func shortDate(_ date: Date) -> String {
        String(iso(date).prefix(10))
    }

    private func coverNumber(of page: ExercisePageManifest) -> Int? {
        guard !page.mediaFilenames.isEmpty else { return nil }
        if let chosen = page.coverMediaFilename, let position = page.mediaFilenames.firstIndex(of: chosen) { return position + 1 }
        return 1
    }

    private func mediaFileExists(pageID: String, filename: String) -> Bool {
        if let url = try? database.pageMediaURL(pageID: pageID, filename: filename), FileManager.default.fileExists(atPath: url.path) { return true }
        return FileManager.default.fileExists(atPath: database.fs.mediaDirectory.appendingPathComponent(filename).path)
    }

    private func mediaEntry(of page: ExercisePageManifest, filename: String, number: Int, cover: Int?) -> [String: Any] {
        var item: [String: Any] = ["index": number, "kind": AgentMedia.kind(ofFilename: filename)]
        if let comment = page.mediaComments[filename] { item["comment"] = comment }
        if cover == number { item["cover"] = true }
        if page.dependencyMediaFilenames.contains(filename) { item["learnFirst"] = true }
        if page.iconImage == filename { item["icon"] = true }
        if !mediaFileExists(pageID: page.id, filename: filename) { item["missing"] = true }
        return item
    }

    private func mediaEntries(of page: ExercisePageManifest) -> [[String: Any]] {
        let cover = coverNumber(of: page)
        return page.mediaFilenames.enumerated().map { offset, filename in
            mediaEntry(of: page, filename: filename, number: offset + 1, cover: cover)
        }
    }

    private func linkEntry(of page: ExercisePageManifest, url: String) -> [String: Any] {
        var item: [String: Any] = ["url": url]
        if let comment = page.linkComments[url], !comment.isEmpty { item["comment"] = comment }
        if page.dependencyLinkURLs.contains(url) { item["learnFirst"] = true }
        return item
    }

    private func linkEntries(of page: ExercisePageManifest) -> [[String: Any]]? {
        let detailed = page.linkURLs.contains { page.dependencyLinkURLs.contains($0) || !(page.linkComments[$0] ?? "").isEmpty }
        return detailed ? page.linkURLs.map { linkEntry(of: page, url: $0) } : nil
    }

    private func iconEntry(of page: ExercisePageManifest) -> [String: Any]? {
        var icon: [String: Any] = [:]
        if let name = page.iconName, !name.isEmpty {
            icon["name"] = name
            icon["type"] = (page.iconType ?? SkillBoardIconType.inferred(from: name)).rawValue
        }
        if let image = page.iconImage, DatabaseManager.isWebImageReference(image) { icon["image"] = image }
        return icon.isEmpty ? nil : icon
    }

    private func dropSetEntry(_ template: PageDropSetTemplate, index: AgentPageIndex) -> [String: Any] {
        var item: [String: Any] = ["set": template.setIndex + 1, "name": template.name, "duration": template.duration, "restAfter": template.restAfter]
        if !template.exerciseID.isEmpty { item["exercise"] = referenceEntry(template.exerciseID, index: index) }
        return item
    }

    private func referenceEntry(_ id: String, index: AgentPageIndex) -> [String: Any] {
        if let group = SkillGroupID.split(id) {
            guard let board = index.byID[group.containerID], let section = board.skillBoardSection(group.sectionID) else {
                return ["id": id, "missing": true]
            }
            return ["id": id, "path": index.titlePath(board.id) + "/" + section.title, "group": true]
        }
        guard index.byID[id] != nil else { return ["id": id, "missing": true] }
        return ["id": id, "path": index.titlePath(id)]
    }

    private func referenceLabel(_ id: String, index: AgentPageIndex) -> String {
        let entry = referenceEntry(id, index: index)
        return entry["path"] as? String ?? id
    }

    private func pageNoun(_ page: ExercisePageManifest) -> String {
        switch page.pageType {
        case .exercise?: return "an exercise page"
        case .skill?: return "a skill page"
        case .tutorial?: return "a tutorial page"
        case .note?: return "a note"
        case nil: return "a folder"
        }
    }

    private struct ContentPage {
        let page: ExercisePageManifest
        let path: String
    }

    private struct AttachmentTarget {
        let page: ExercisePageManifest
        let path: String
        let number: Int
        let filename: String
    }

    private func contentPage(_ args: AgentArguments, index: AgentPageIndex) throws -> ContentPage {
        let found = try index.resolve(try args.requiredString("page"))
        return ContentPage(page: try database.getPage(id: found.id), path: index.titlePath(found.id))
    }

    private func attachmentTarget(_ args: AgentArguments, index: AgentPageIndex) throws -> AttachmentTarget {
        let target = try contentPage(args, index: index)
        guard target.page.pageType != .note else {
            throw AgentToolError("invalid_page", "'\(target.page.title)' is a note; notes keep their pictures inside the Markdown and have no attachments.", hint: "Change the pictures in markdownBody with update_page.")
        }
        let number = args.int("index") ?? 0
        let media = target.page.mediaFilenames
        guard media.indices.contains(number - 1) else {
            throw AgentToolError(
                "not_found", media.isEmpty ? "'\(target.page.title)' has no attachments." : "'\(target.page.title)' has no attachment number \(number).",
                hint: media.isEmpty ? "attach_media adds one." : "It has \(media.count), numbered 1 to \(media.count); get_page lists them."
            )
        }
        return AttachmentTarget(page: target.page, path: target.path, number: number, filename: media[number - 1])
    }

    private func requireLearnFirstPage(_ page: ExercisePageManifest, what: String) throws {
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw AgentToolError("invalid_page", "'\(page.title)' is \(pageNoun(page)); only skill and tutorial pages keep a learn-first list, so \(what) cannot be flagged there.", hint: "Leave learnFirst out.")
        }
    }

    private func hiddenLearnFirstWarning(_ page: ExercisePageManifest) -> [String] {
        page.hidesSkills ? ["noSkills is on, so the page shows no learn-first list; the change is kept for when it is turned off."] : []
    }

    private func changeMedia(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let target = try attachmentTarget(args, index: index)
        guard ["comment", "position", "learnFirst", "cover", "icon"].contains(where: { args.has($0) }) else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one of comment, position, learnFirst, cover or icon besides page and index.")
        }
        let stored = target.page
        let filename = target.filename
        var updated = stored
        var changed: [String] = []
        var warnings: [String] = []
        if let comment = args.string("comment") {
            let text = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
            if updated.mediaComments[filename] != text {
                updated.mediaComments[filename] = text
                changed.append("comment")
            }
        }
        if let flag = args.bool("learnFirst") {
            try requireLearnFirstPage(stored, what: "an attachment")
            if flag != updated.dependencyMediaFilenames.contains(filename) {
                updated.dependencyMediaFilenames.removeAll { $0 == filename }
                if flag { updated.dependencyMediaFilenames.append(filename) }
                changed.append("learnFirst")
            }
            warnings += hiddenLearnFirstWarning(stored)
        }
        if let flag = args.bool("cover"), flag != (updated.coverMediaFilename == filename) {
            updated.coverMediaFilename = flag ? filename : nil
            changed.append("cover")
        }
        if let flag = args.bool("icon") {
            if flag, AgentMedia.kind(ofFilename: filename) != "image" {
                throw AgentToolError("invalid_argument", "Attachment \(target.number) is a video; an icon picture must be an image.", hint: "Use a jpg, png, heic, gif or webp attachment.")
            }
            if flag != (updated.iconImage == filename) {
                updated.iconImage = flag ? filename : nil
                changed.append("icon")
            }
        }
        var number = target.number
        if let position = args.int("position") {
            var order = updated.mediaFilenames
            order.remove(at: number - 1)
            let place = min(max(0, position - 1), order.count)
            order.insert(filename, at: place)
            number = place + 1
            if order != updated.mediaFilenames {
                updated.mediaFilenames = order
                changed.append("position")
            }
            if number == 1, let chosen = updated.coverMediaFilename, chosen != filename, let chosenPlace = order.firstIndex(of: chosen) {
                warnings.append("The page keeps its chosen banner (attachment \(chosenPlace + 1)), so that stays the cover. Pass cover true to use this one.")
            }
        }
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "path": target.path, "index": target.number, "wouldChange": changed]
            if number != target.number { preview["newIndex"] = number }
            if !warnings.isEmpty { preview["warnings"] = warnings }
            return AgentToolOutput(value: preview)
        }
        var effects: [AgentEffect] = []
        if !changed.isEmpty {
            if let snapshot = pageSnapshot(stored) { effects.append(snapshot) }
            try database.updatePage(id: stored.id, manifest: updated, newParentID: stored.parentID)
        }
        let saved = try database.getPage(id: stored.id)
        let savedNumber = (saved.mediaFilenames.firstIndex(of: filename) ?? number - 1) + 1
        let cover = coverNumber(of: saved)
        var value: [String: Any] = [
            "id": stored.id, "path": target.path, "changed": changed,
            "item": mediaEntry(of: saved, filename: filename, number: savedNumber, cover: cover),
        ]
        if changed.isEmpty { value["unchanged"] = true }
        if let cover { value["cover"] = cover }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: effects)
    }

    private func dropMedia(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let target = try attachmentTarget(args, index: index)
        let entry = mediaEntry(of: target.page, filename: target.filename, number: target.number, cover: coverNumber(of: target.page))
        let left = target.page.mediaFilenames.count - 1
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "path": target.path, "wouldRemove": entry, "left": left])
        }
        var effects: [AgentEffect] = []
        if let snapshot = pageSnapshot(target.page) { effects.append(snapshot) }
        try database.removeMediaFromPage(pageID: target.page.id, filename: target.filename)
        var value: [String: Any] = ["id": target.page.id, "path": target.path, "removed": entry, "left": left]
        if entry["missing"] == nil {
            value["warnings"] = ["The file is in the library trash (.trash); undo brings back the entry and its caption but not the file."]
        }
        return AgentToolOutput(value: value, effects: effects)
    }

    private static func linkKey(_ url: String) -> String {
        var text = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }

    private func listedLinks(_ page: ExercisePageManifest) -> String {
        guard !page.linkURLs.isEmpty else { return "The page has no links; update_page linkURLs adds them." }
        let shown = page.linkURLs.prefix(8).map { "'\($0)'" }.joined(separator: ", ")
        return "Its links: \(shown)" + (page.linkURLs.count > 8 ? " and \(page.linkURLs.count - 8) more." : ".")
    }

    private func linkPosition(of address: String, in page: ExercisePageManifest) throws -> Int {
        let wanted = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = page.linkURLs.firstIndex(of: wanted) { return exact }
        let key = Self.linkKey(wanted)
        let matches = page.linkURLs.indices.filter { Self.linkKey(page.linkURLs[$0]) == key }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 {
            throw AgentToolError("ambiguous", "'\(wanted)' matches \(matches.count) links of '\(page.title)'.", hint: "Pass the address exactly as get_page shows it: \(matches.map { page.linkURLs[$0] }.joined(separator: ", ")).")
        }
        throw AgentToolError("not_found", "'\(page.title)' has no link '\(wanted)'.", hint: listedLinks(page))
    }

    private func cleanedAddress(_ raw: String) throws -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else {
            throw AgentToolError("invalid_argument", "'newURL' must be one address without spaces.", hint: "For example https://example.com/video.")
        }
        return text.contains("://") ? text : "https://" + text
    }

    private func changeLink(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let target = try contentPage(args, index: index)
        let stored = target.page
        guard stored.pageType != .note else {
            throw AgentToolError("invalid_page", "'\(stored.title)' is a note; notes keep links inside the Markdown and have none of their own.", hint: "Change them in markdownBody with update_page.")
        }
        guard ["comment", "learnFirst", "newURL"].contains(where: { args.has($0) }) else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one of comment, learnFirst or newURL besides page and url.")
        }
        let position = try linkPosition(of: try args.requiredString("url"), in: stored)
        let original = stored.linkURLs[position]
        var url = original
        var updated = stored
        var changed: [String] = []
        var warnings: [String] = []
        if let raw = args.string("newURL") {
            let fresh = try cleanedAddress(raw)
            if fresh != original {
                let key = Self.linkKey(fresh)
                if let clash = stored.linkURLs.indices.first(where: { $0 != position && Self.linkKey(stored.linkURLs[$0]) == key }) {
                    throw AgentToolError("already_exists", "'\(stored.title)' already has the link '\(stored.linkURLs[clash])'.", hint: "Pick another address, or drop one of the two with update_page linkURLs.")
                }
                updated.linkURLs[position] = fresh
                if let comment = updated.linkComments.removeValue(forKey: original) { updated.linkComments[fresh] = comment }
                updated.dependencyLinkURLs = updated.dependencyLinkURLs.map { $0 == original ? fresh : $0 }
                if let known = updated.linkMetadata.firstIndex(where: { $0.url == original }) { updated.linkMetadata[known] = LinkMetadata(url: fresh) }
                url = fresh
                changed.append("newURL")
            }
        }
        if let comment = args.string("comment") {
            let text = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
            if updated.linkComments[url] != text {
                updated.linkComments[url] = text
                changed.append("comment")
                if stored.pageType != .skill, stored.pageType != .tutorial {
                    warnings.append("The app shows link comments on skill and tutorial pages only.")
                }
            }
        }
        if let flag = args.bool("learnFirst") {
            try requireLearnFirstPage(stored, what: "a link")
            if flag != updated.dependencyLinkURLs.contains(url) {
                updated.dependencyLinkURLs.removeAll { $0 == url }
                if flag { updated.dependencyLinkURLs.append(url) }
                changed.append("learnFirst")
            }
            warnings += hiddenLearnFirstWarning(stored)
        }
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "path": target.path, "wouldChange": changed]
            if !warnings.isEmpty { preview["warnings"] = warnings }
            return AgentToolOutput(value: preview)
        }
        var effects: [AgentEffect] = []
        if !changed.isEmpty {
            if let snapshot = pageSnapshot(stored) { effects.append(snapshot) }
            try database.updatePage(id: stored.id, manifest: updated, newParentID: stored.parentID)
        }
        let saved = try database.getPage(id: stored.id)
        var value: [String: Any] = ["id": stored.id, "path": target.path, "changed": changed, "link": linkEntry(of: saved, url: url)]
        if changed.isEmpty { value["unchanged"] = true }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: effects)
    }

    private struct ReferenceEdit {
        var ids: [String]
        var alreadyListed: [String]
        var notListed: [String]
    }

    private func referencedID(_ reference: String, index: AgentPageIndex, allowsGroups: Bool) throws -> String {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if allowsGroups, let group = SkillGroupID.split(text), let board = try? index.resolve(group.containerID),
           let section = board.skillBoardSections.first(where: { $0.id.caseInsensitiveCompare(group.sectionID) == .orderedSame }) {
            return SkillGroupID.make(containerID: board.id, sectionID: section.id)
        }
        do {
            return try index.resolve(text).id
        } catch let error as AgentToolError where error.code == "not_found" && allowsGroups && SkillGroupID.isGroup(text) {
            throw AgentToolError("not_found", "No page or skill group matches '\(text)'.", hint: "get_page on a skill's board lists its groups with their ids.")
        }
    }

    private func listedID(_ reference: String, in ids: [String], index: AgentPageIndex, allowsGroups: Bool) throws -> String {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = ids.first(where: { $0.caseInsensitiveCompare(text) == .orderedSame }) { return exact }
        return try referencedID(text, index: index, allowsGroups: allowsGroups)
    }

    private func listedPages(_ ids: [String], index: AgentPageIndex) -> String {
        guard !ids.isEmpty else { return "The list is empty." }
        return "The list: " + ids.map { "'\(referenceLabel($0, index: index))'" }.joined(separator: ", ") + "."
    }

    private func editedReferences(
        _ args: AgentArguments, current: [String], index: AgentPageIndex, owner: ExercisePageManifest,
        noun: String, allowsGroups: Bool, check: (String) throws -> Void
    ) throws -> ReferenceEdit {
        guard ["add", "remove", "order"].contains(where: { args.has($0) }) else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one of add, remove or order besides page.")
        }
        var ids = current
        var taken: [String] = []
        var notListed: [String] = []
        for reference in args.strings("remove") ?? [] {
            let id = try listedID(reference, in: ids, index: index, allowsGroups: allowsGroups)
            if ids.contains(id) {
                ids.removeAll { $0 == id }
                taken.append(id)
            } else if !taken.contains(id), !notListed.contains(id) {
                notListed.append(id)
            }
        }
        var alreadyListed: [String] = []
        var added: [String] = []
        for reference in args.strings("add") ?? [] {
            let id = try referencedID(reference, index: index, allowsGroups: allowsGroups)
            guard id != owner.id else {
                throw AgentToolError("invalid_argument", "'\(owner.title)' cannot be in its own \(noun).")
            }
            if added.contains(id) { continue }
            if ids.contains(id) {
                if !alreadyListed.contains(id) { alreadyListed.append(id) }
                continue
            }
            try check(id)
            ids.append(id)
            added.append(id)
        }
        if args.has("order") {
            var ordered: [String] = []
            for reference in args.strings("order") ?? [] {
                let id = try listedID(reference, in: ids, index: index, allowsGroups: allowsGroups)
                guard ids.contains(id) else {
                    throw AgentToolError("invalid_argument", "'\(reference)' is not in the \(noun) of '\(owner.title)'.", hint: "Add it with add, in the same call or an earlier one. " + listedPages(ids, index: index))
                }
                guard !ordered.contains(id) else {
                    throw AgentToolError("invalid_argument", "'\(reference)' appears twice in order.")
                }
                ordered.append(id)
            }
            let missing = ids.filter { !ordered.contains($0) }
            guard missing.isEmpty else {
                throw AgentToolError(
                    "invalid_argument", "order must list every page of the \(noun) of '\(owner.title)' once; \(missing.count) missing.",
                    hint: "Missing: \(missing.map { "'\(referenceLabel($0, index: index))'" }.joined(separator: ", "))."
                )
            }
            ids = ordered
        }
        return ReferenceEdit(ids: ids, alreadyListed: alreadyListed, notListed: notListed)
    }

    private func referenceChanges(from current: [String], to after: [String]) -> [String] {
        var changes: [String] = []
        if current.contains(where: { !after.contains($0) }) { changes.append("remove") }
        if after.contains(where: { !current.contains($0) }) { changes.append("add") }
        if current.filter({ after.contains($0) }) != after.filter({ current.contains($0) }) { changes.append("order") }
        return changes
    }

    private func editReferenceList(
        _ args: AgentArguments, dryRun: Bool, index: AgentPageIndex, target: ContentPage,
        list: WritableKeyPath<ExercisePageManifest, [String]>, key: String, noun: String, allowsGroups: Bool,
        warnings: [String], check: (String) throws -> Void
    ) throws -> AgentToolOutput {
        let stored = target.page
        let current = stored[keyPath: list]
        let edit = try editedReferences(args, current: current, index: index, owner: stored, noun: noun, allowsGroups: allowsGroups, check: check)
        var after = edit.ids
        var effects: [AgentEffect] = []
        if !dryRun, after != current {
            var updated = stored
            updated[keyPath: list] = after
            if let snapshot = pageSnapshot(stored) { effects.append(snapshot) }
            try database.updatePage(id: stored.id, manifest: updated, newParentID: stored.parentID)
            after = try database.getPage(id: stored.id)[keyPath: list]
        }
        let changes = referenceChanges(from: current, to: after)
        var value: [String: Any] = ["path": target.path, key: after.map { referenceEntry($0, index: index) }]
        if dryRun {
            value["dryRun"] = true
            value["wouldChange"] = changes
        } else {
            value["id"] = stored.id
            value["changed"] = changes
            if changes.isEmpty { value["unchanged"] = true }
        }
        if !edit.alreadyListed.isEmpty { value["alreadyListed"] = edit.alreadyListed.map { referenceLabel($0, index: index) } }
        if !edit.notListed.isEmpty { value["notListed"] = edit.notListed.map { referenceLabel($0, index: index) } }
        if !warnings.isEmpty { value["warnings"] = warnings }
        return AgentToolOutput(value: value, effects: effects)
    }

    private func waitsFor(_ candidate: String, on pageID: String, index: AgentPageIndex) -> Bool {
        var queue = [candidate]
        var seen: Set<String> = [candidate]
        while let current = queue.popLast() {
            let waiting: [String]
            if let group = SkillGroupID.split(current) {
                waiting = index.byID[group.containerID]?.skillBoardSection(group.sectionID)?.dependencyPageIDs ?? []
            } else {
                waiting = index.byID[current]?.dependencyPageIDs ?? []
            }
            for next in waiting {
                if next == pageID { return true }
                if seen.insert(next).inserted { queue.append(next) }
            }
        }
        return false
    }

    private func changeLearnFirst(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let target = try contentPage(args, index: index)
        let owner = target.page
        guard owner.pageType == .skill || owner.pageType == .tutorial else {
            throw AgentToolError("invalid_page", "'\(owner.title)' is \(pageNoun(owner)); only skill and tutorial pages keep a learn-first list.")
        }
        return try editReferenceList(
            args, dryRun: dryRun, index: index, target: target, list: \.dependencyPageIDs, key: "learnFirst",
            noun: "learn-first list", allowsGroups: true, warnings: hiddenLearnFirstWarning(owner)
        ) { id in
            guard !waitsFor(id, on: owner.id, index: index) else {
                throw AgentToolError(
                    "invalid_argument", "'\(referenceLabel(id, index: index))' already waits for '\(owner.title)', so it cannot also be learned first.",
                    hint: "Learn-first lists cannot loop. Take '\(owner.title)' off that page's list first, or pick another page."
                )
            }
        }
    }

    private func changeLinkedPages(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let target = try contentPage(args, index: index)
        let owner = target.page
        guard owner.pageType == .skill || owner.pageType == .tutorial else {
            throw AgentToolError(
                "invalid_page", "'\(owner.title)' is \(pageNoun(owner)); only skill and tutorial pages can have attached pages.",
                hint: "The app's Attach Page button is on those pages only, and saving any other page drops its attached pages."
            )
        }
        return try editReferenceList(
            args, dryRun: dryRun, index: index, target: target, list: \.linkedPageIDs, key: "linkedPages",
            noun: "attached pages", allowsGroups: false, warnings: []
        ) { _ in }
    }
}
