import Foundation

// To-dos and milestones: the two lists of a skill or tutorial page (`ExercisePageManifest.todos` / `.milestones`).
//
// Every change goes through `updateChecklist`, which saves the list the way `ChecklistEntry.normalized` keeps it. The
// functions are generic over the list (`TodoItem.self` or `Milestone.self`), so to-dos and milestones follow one set of
// rules. Groups (`SkillGroupID`) hold neither: a group is a column of a board.

/// What a picture added to an entry in one step becomes.
public enum ChecklistPictureRole: String, CaseIterable, Sendable {
    case cover
    case image
    case icon
    /// Any file of the page, as a chip (`timemaster://media/<file>`).
    case attachment
}

/// Something an entry points at that is no longer there.
public struct ChecklistFinding: Equatable, Sendable {
    public enum Problem: String, Sendable {
        case missingWorkout
        case missingPage
        /// A file of the page the entry names (its cover, icon, strip or a file link) is not on disk.
        case missingFile
    }

    public let pageID: String
    public let pageTitle: String
    public let kind: ChecklistKind
    public let entryID: String
    public let entryTitle: String
    public let problem: Problem
    /// The workout id, page id or file name that is gone.
    public let reference: String
}

extension DatabaseManager {
    // MARK: - Reading

    /// A page's to-dos (`TodoItem.self`) or milestones (`Milestone.self`).
    public func checklist<Entry: ChecklistEntry>(_ type: Entry.Type, of pageID: String) throws -> [Entry] {
        try checklistPage(pageID).page[keyPath: Entry.pageList]
    }

    // MARK: - Changing

    /// Runs `change` on a page's list (with the page at hand) and saves the result as `ChecklistEntry.normalized`
    /// keeps it. Returns the saved list; an unchanged list is not written.
    @discardableResult
    public func updateChecklist<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        of pageID: String,
        _ change: (inout [Entry], ExercisePageManifest) throws -> Void
    ) throws -> [Entry] {
        let (folder, page) = try checklistPage(pageID)
        var list = page[keyPath: Entry.pageList]
        try change(&list, page)
        let cleaned = try Entry.normalized(list, mediaFilenames: Set(page.mediaFilenames))
        guard cleaned != page[keyPath: Entry.pageList] else { return cleaned }
        var updated = page
        updated[keyPath: Entry.pageList] = cleaned
        updated.updatedAt = Date()
        try writePageManifest(updated, at: folder)
        return cleaned
    }

    /// Adds `entry` under `parentID` (the top level without one) at `index` (default: the end of that level). Its
    /// pictures and file links must be media of the page; nothing goes inside a section and a section stays at the
    /// top level.
    @discardableResult
    public func addChecklistEntry<Entry: ChecklistEntry>(
        _ entry: Entry,
        to pageID: String,
        under parentID: String? = nil,
        at index: Int? = nil
    ) throws -> Entry {
        let saved = try updateChecklist(Entry.self, of: pageID) { list, page in
            guard list.entry(entry.id) == nil else {
                throw ChecklistError.invalid("The \(Entry.kind.noun) id \(entry.id) is used twice.")
            }
            if let parentID {
                guard let parent = list.entry(parentID) else { throw Self.missing(Entry.self, parentID) }
                guard !parent.isSection else {
                    throw ChecklistError.invalid("Nothing goes inside a section; add the \(Entry.kind.noun) after it instead.")
                }
                guard !entry.isSection else { throw ChecklistError.invalid("A section stays at the top level.") }
            }
            try Self.requireReferences(of: entry, on: page)
            guard list.insertEntry(entry, under: parentID, at: index) else { throw Self.missing(Entry.self, parentID ?? "") }
        }
        return saved.entry(entry.id) ?? entry
    }

    /// Adds a section divider (a title, optionally an icon and a colour) at the top level, at `index` (default: the
    /// end of the list).
    @discardableResult
    public func addChecklistSection<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        title: String,
        iconName: String? = nil,
        iconType: SkillBoardIconType? = nil,
        colorHex: String? = nil,
        to pageID: String,
        at index: Int? = nil
    ) throws -> Entry {
        var section = Entry.blank(id: Entry.newID(), title: title)
        section.isSection = true
        section.iconName = iconName
        section.iconType = iconType
        section.colorHex = colorHex
        return try addChecklistEntry(section, to: pageID, at: index)
    }

    /// Changes an entry's own fields (title, note, icon, colour, pictures, links, section flag). Its place, its
    /// children and its checked state stay: those change with `moveChecklistEntry` and `setChecklistEntry`. New
    /// pictures and file links must be media of the page.
    @discardableResult
    public func updateChecklistEntry<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        _ entryID: String,
        in pageID: String,
        _ change: (inout Entry) throws -> Void
    ) throws -> Entry {
        let list = try updateChecklist(Entry.self, of: pageID) { list, page in
            guard let before = list.entry(entryID) else { throw Self.missing(Entry.self, entryID) }
            var item = before
            try change(&item)
            item.id = entryID
            item.children = before.children
            item.isDone = before.isDone
            item.doneAt = before.doneAt
            item.createdAt = before.createdAt
            if item.isSection, !before.isSection {
                guard list.parentID(of: entryID) == nil else {
                    throw ChecklistError.invalid("Only a \(Entry.kind.noun) at the top level can become a section.")
                }
                guard before.children.isEmpty else {
                    throw ChecklistError.invalid("A \(Entry.kind.noun) with \(Entry.kind.plural) inside cannot become a section; move them out first.")
                }
            }
            try Self.requireReferences(of: item, comparedTo: before, on: page)
            list.mutateEntry(entryID) { $0 = item }
        }
        guard let result = list.entry(entryID) else { throw Self.missing(Entry.self, entryID) }
        return result
    }

    /// Checks or opens an entry. Checking also checks everything under it; opening one under a checked entry opens
    /// that one too. A section is never checked.
    @discardableResult
    public func setChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, done: Bool, in pageID: String) throws -> [Entry] {
        let now = Date()
        return try updateChecklist(Entry.self, of: pageID) { list, _ in
            guard let item = list.entry(entryID) else { throw Self.missing(Entry.self, entryID) }
            guard !item.isSection else {
                throw ChecklistError.invalid("A section is not checked; check the \(Entry.kind.plural) after it.")
            }
            list.mutateEntry(entryID) { item in
                if done { Entry.markDone(&item, at: now) } else { item.isDone = false }
            }
        }
    }

    /// Puts an entry (with everything under it) under another one (the top level for nil) at `index` (default: the
    /// end), counted among the destination's entries without the moved one. Moving across a section divider is a
    /// move at the top level.
    @discardableResult
    public func moveChecklistEntry<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        _ entryID: String,
        in pageID: String,
        toParent parentID: String?,
        at index: Int? = nil
    ) throws -> [Entry] {
        try updateChecklist(Entry.self, of: pageID) { list, _ in
            guard let subtree = list.entry(entryID) else { throw Self.missing(Entry.self, entryID) }
            if let parentID {
                guard parentID != entryID, !subtree.flattenedIDs.contains(parentID) else {
                    throw ChecklistError.invalid("A \(Entry.kind.noun) cannot go inside itself.")
                }
                guard let parent = list.entry(parentID) else { throw Self.missing(Entry.self, parentID) }
                guard !parent.isSection else {
                    throw ChecklistError.invalid("Nothing goes inside a section; move the \(Entry.kind.noun) after it instead.")
                }
                guard !subtree.isSection else { throw ChecklistError.invalid("A section stays at the top level.") }
            }
            _ = list.removeEntry(entryID)
            guard list.insertEntry(subtree, under: parentID, at: index) else { throw Self.missing(Entry.self, parentID ?? "") }
        }
    }

    /// Puts an entry at the top level, at the end of a section's part (`sectionID` nil = the part before the first
    /// section). A section moved this way goes right before the next section.
    @discardableResult
    public func moveChecklistEntry<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        _ entryID: String,
        in pageID: String,
        toSection sectionID: String?
    ) throws -> [Entry] {
        try updateChecklist(Entry.self, of: pageID) { list, _ in
            guard let subtree = list.entry(entryID) else { throw Self.missing(Entry.self, entryID) }
            if let sectionID {
                guard sectionID != entryID else { throw ChecklistError.invalid("A section cannot go after itself.") }
                guard list.entry(sectionID)?.isSection == true, list.contains(where: { $0.id == sectionID }) else {
                    throw ChecklistError.notFound("There is no section with id \(sectionID) on this page.")
                }
            }
            _ = list.removeEntry(entryID)
            list.insert(subtree, at: list.partEnd(of: sectionID))
        }
    }

    /// Makes an entry a child of the one right above it on its level (Tab). False when there is none above, the one
    /// above is a section, the entry is a section, or the list would nest too deep.
    @discardableResult
    public func indentChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String) throws -> Bool {
        var moved = false
        try updateChecklist(Entry.self, of: pageID) { list, _ in
            guard let subtree = list.entry(entryID), !subtree.isSection,
                  let target = Self.indentTarget(of: entryID, in: list),
                  let above = list.entry(target), !above.isSection else { return }
            guard (list.depth(of: target) ?? 0) + [Entry].height(of: subtree) <= Entry.maxDepth else { return }
            _ = list.removeEntry(entryID)
            moved = list.insertEntry(subtree, under: target)
        }
        return moved
    }

    /// Brings a child entry back one level (Shift-Tab): it goes right after the entry it was in. False at the top level.
    @discardableResult
    public func outdentChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String) throws -> Bool {
        var moved = false
        try updateChecklist(Entry.self, of: pageID) { list, _ in
            guard let parentID = list.parentID(of: entryID), let subtree = list.entry(entryID) else { return }
            let grandparent = list.parentID(of: parentID)
            let siblings = grandparent.flatMap { list.entry($0)?.children } ?? list
            guard let position = siblings.firstIndex(where: { $0.id == parentID }) else { return }
            _ = list.removeEntry(entryID)
            moved = list.insertEntry(subtree, under: grandparent, at: position + 1)
        }
        return moved
    }

    /// Deletes an entry with everything under it and returns it. A section goes alone: the entries of its part join
    /// the part above. Its pictures stay on the page.
    @discardableResult
    public func removeChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, from pageID: String) throws -> Entry {
        var removed: Entry?
        try updateChecklist(Entry.self, of: pageID) { list, _ in
            removed = list.removeEntry(entryID)
            if removed == nil { throw Self.missing(Entry.self, entryID) }
        }
        guard let removed else { throw Self.missing(Entry.self, entryID) }
        return removed
    }

    /// Copies a file into the page's media and makes it the entry's cover, picture icon, one of its strip pictures or
    /// a file chip, in one step. If the entry cannot take it the file leaves the page again. Returns the file name.
    @discardableResult
    public func attachChecklistPicture<Entry: ChecklistEntry>(
        _ type: Entry.Type,
        from sourceURL: URL,
        to entryID: String,
        in pageID: String,
        as role: ChecklistPictureRole
    ) throws -> String {
        let page = try checklistPage(pageID).page
        guard let entry = page[keyPath: Entry.pageList].entry(entryID) else { throw Self.missing(Entry.self, entryID) }
        guard !entry.isSection else { throw ChecklistError.invalid("A section has no pictures or files.") }
        if role != .attachment, !ChecklistMedia.isPicture(sourceURL.lastPathComponent) {
            throw ChecklistError.invalid("Only a picture (jpg, png, heic, gif or webp) can be a cover, an icon or part of the strip.")
        }
        if role == .image, entry.imageFilenames.count >= Entry.maxImages {
            throw ChecklistError.invalid("A \(Entry.kind.noun) shows up to \(Entry.maxImages) pictures.")
        }
        if role == .attachment, entry.links.count >= Entry.maxLinks {
            throw ChecklistError.invalid("A \(Entry.kind.noun) holds up to \(Entry.maxLinks) links.")
        }
        let filename = try uploadMediaToPage(pageID: pageID, sourceURL: sourceURL)
        do {
            try updateChecklistEntry(Entry.self, entryID, in: pageID) { item in
                switch role {
                case .cover: item.coverMediaFilename = filename
                case .image: item.imageFilenames.append(filename)
                case .icon:
                    item.iconImage = filename
                case .attachment: item.links.append(TodoLink(target: .media(filename: filename)))
                }
            }
        } catch {
            try? removeMediaFromPage(pageID: pageID, filename: filename)
            throw error
        }
        return filename
    }

    // MARK: - Findings

    /// Links and pictures of the lists that point at nothing: a deleted workout or page, or a file of the page that is
    /// not on disk. `pageID` nil checks every skill and tutorial page. Reported, never repaired (the lists are the
    /// user's).
    public func checklistFindings(pageID: String? = nil) throws -> [ChecklistFinding] {
        let walked = try walkPageTree(in: fs.exercisesDatabaseDirectory)
        let pages = Dictionary(walked.map { (Self.canonicalID($0.0.id), $0.0) }, uniquingKeysWith: { first, _ in first })
        let workouts = Set(((try? listWorkouts()) ?? []).map { Self.canonicalID($0.id) })
        func pageExists(_ id: String) -> Bool {
            if let group = SkillGroupID.split(id) {
                return pages[Self.canonicalID(group.containerID)]?.skillBoardSection(group.sectionID) != nil
            }
            return pages[Self.canonicalID(id)] != nil
        }
        var findings: [ChecklistFinding] = []
        for (page, path) in walked where page.pageType == .skill || page.pageType == .tutorial {
            if let pageID, Self.canonicalID(pageID) != Self.canonicalID(page.id) { continue }
            let media = fs.exercisesDatabaseDirectory.appendingPathComponent(path, isDirectory: true)
                .appendingPathComponent("media", isDirectory: true)
            func onDisk(_ name: String) -> Bool { fs.fileExists(at: media.appendingPathComponent(name)) }
            func scan<Entry: ChecklistEntry>(_ list: [Entry]) {
                for (entry, _) in list.flattened() {
                    func add(_ problem: ChecklistFinding.Problem, _ reference: String) {
                        findings.append(ChecklistFinding(
                            pageID: page.id, pageTitle: page.title, kind: Entry.kind, entryID: entry.id,
                            entryTitle: entry.title, problem: problem, reference: reference
                        ))
                    }
                    for link in entry.links {
                        switch link.target {
                        case .workout(let id)?: if !workouts.contains(Self.canonicalID(id)) { add(.missingWorkout, id) }
                        case .page(let id)?: if !pageExists(id) { add(.missingPage, id) }
                        case .media(let name)?: if !onDisk(name) { add(.missingFile, name) }
                        default: break
                        }
                    }
                    var pictures = entry.imageFilenames
                    if let cover = entry.coverMediaFilename { pictures.insert(cover, at: 0) }
                    if let icon = entry.iconImage, !Entry.isWebImage(icon) { pictures.append(icon) }
                    for name in pictures.uniqued() where !onDisk(name) { add(.missingFile, name) }
                }
            }
            scan(page.todos)
            scan(page.milestones)
        }
        return findings
    }

    // MARK: - Rules

    /// The folder and manifest of a page that keeps to-dos and milestones: a skill or tutorial page, not a group.
    func checklistPage(_ pageID: String) throws -> (folder: URL, page: ExercisePageManifest) {
        guard !SkillGroupID.isGroup(pageID) else {
            throw ChecklistError.invalid("A group has no to-dos or milestones. Put them on a page inside it.")
        }
        let folder = try resolvePageFolder(id: pageID)
        guard fs.directoryExists(at: folder) else { throw ChecklistError.notFound("There is no page with id \(pageID).") }
        let page = try readPageManifest(at: folder)
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw ChecklistError.invalid("Only skill and tutorial pages keep to-dos and milestones; “\(page.title)” is not one.")
        }
        return (folder, page)
    }

    /// The entry directly above `entryID` on its level (the one it would go into when indented).
    static func indentTarget<Entry: ChecklistEntry>(of entryID: String, in list: [Entry]) -> String? {
        let siblings = list.siblings(of: entryID)
        guard let position = siblings.firstIndex(where: { $0.id == entryID }), position > 0 else { return nil }
        return siblings[position - 1].id
    }

    /// The pictures and file links of `entry` that were not on it before must be media of the page; a cover, an icon
    /// and the strip take pictures only.
    static func requireReferences<Entry: ChecklistEntry>(of entry: Entry, comparedTo before: Entry? = nil, on page: ExercisePageManifest) throws {
        let media = Set(page.mediaFilenames)
        let known = before?.mediaReferences ?? []
        func require(_ name: String, picture: Bool) throws {
            guard !known.contains(name) else { return }
            guard media.contains(name) else { throw ChecklistError.notFound("“\(name)” is not a file of \(page.title).") }
            if picture, !ChecklistMedia.isPicture(name) {
                throw ChecklistError.invalid("“\(name)” is not a picture; a cover, an icon or the strip takes jpg, png, heic, gif or webp.")
            }
        }
        if let cover = entry.coverMediaFilename { try require(cover, picture: true) }
        if let icon = entry.iconImage, !Entry.isWebImage(icon) { try require(icon, picture: true) }
        for name in entry.imageFilenames { try require(name, picture: true) }
        for link in entry.links {
            guard let target = link.target else { continue }
            if let name = target.mediaFilename { try require(name, picture: false) }
        }
    }

    /// The lists as `normalizedPageManifest` keeps them: tidied with `ChecklistEntry.repaired` on skill and tutorial
    /// pages, gone from every other page.
    static func normalizedChecklists(_ manifest: inout ExercisePageManifest) {
        guard manifest.pageType == .skill || manifest.pageType == .tutorial, !SkillGroupID.isGroup(manifest.id) else {
            manifest.todos = []
            manifest.milestones = []
            return
        }
        let media = Set(manifest.mediaFilenames)
        if !manifest.todos.isEmpty { manifest.todos = TodoItem.repaired(manifest.todos, mediaFilenames: media) }
        if !manifest.milestones.isEmpty { manifest.milestones = Milestone.repaired(manifest.milestones, mediaFilenames: media) }
    }

    static func missing<Entry: ChecklistEntry>(_ type: Entry.Type, _ id: String) -> ChecklistError {
        ChecklistError.notFound("There is no \(Entry.kind.noun) with id \(id) on this page.")
    }

    static func canonicalID(_ id: String) -> String {
        UUID(uuidString: id)?.uuidString ?? id
    }
}

extension ExercisePageManifest {
    /// Takes every to-do and milestone reference to the media file `filename` off (the file is leaving the page).
    mutating func dropChecklistMedia(_ filename: String) {
        todos = todos.droppingMedia(filename)
        milestones = milestones.droppingMedia(filename)
    }
}
