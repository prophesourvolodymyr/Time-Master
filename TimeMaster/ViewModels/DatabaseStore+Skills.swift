import Foundation
import TimeMasterCore

/// A skill page or a group as the skill screens see it. A group (a board section opened as a page, id
/// `<board page id>~<section id>`, see `SkillGroupID`) has the synthesized manifest of `SkillBoardSection.asPage`, so
/// notes, media, links, comments and prerequisites read and write the same way for both.
struct SkillMaterial: Identifiable {
    let id: String
    let manifest: ExercisePageManifest
    /// The page's folder, or the group's content folder (`<board page>/Sections/<section id>`).
    let folderURL: URL
    let mediaURLs: [URL]
    /// The page itself; nil for a group.
    let page: ExercisePage?
    /// The board page and section a group stands for; nil for a page.
    let groupContainer: ExercisePage?
    let section: SkillBoardSection?

    var isGroup: Bool { section != nil }
    var title: String { manifest.title }

    func mediaURL(for filename: String) -> URL? {
        mediaURLs.first { $0.lastPathComponent == filename }
    }

    /// Media that are reference material (not prerequisites).
    var referenceMediaURLs: [URL] {
        let dependencies = Set(manifest.dependencyMediaFilenames)
        return mediaURLs.filter { !dependencies.contains($0.lastPathComponent) }
    }

    /// Media flagged as prerequisites, in media order.
    var dependencyMediaURLs: [URL] {
        let dependencies = Set(manifest.dependencyMediaFilenames)
        return mediaURLs.filter { dependencies.contains($0.lastPathComponent) }
    }

    var referenceLinkURLs: [String] {
        let dependencies = Set(manifest.dependencyLinkURLs)
        return manifest.linkURLs.filter { !dependencies.contains($0) }
    }

    var dependencyLinkURLs: [String] {
        let dependencies = Set(manifest.dependencyLinkURLs)
        return manifest.linkURLs.filter { dependencies.contains($0) }
    }

    /// Comments of media by local URL (what `MediaStrip` and `PageMediaGallery` take).
    var mediaCommentsByURL: [URL: String] {
        mediaURLs.reduce(into: [:]) { result, url in
            if let comment = manifest.mediaComments[url.lastPathComponent], !comment.isEmpty { result[url] = comment }
        }
    }

    /// The chosen cover (a group: its strip picture), else the first media item.
    var coverURL: URL? {
        manifest.coverMediaFilename.flatMap(mediaURL(for:)) ?? (isGroup ? nil : mediaURLs.first)
    }
}

/// Where a page sits on a board: its status, group and place inside the group.
struct SkillBoardSpot: Equatable {
    var status: SkillStatus
    /// nil = outside any group.
    var sectionID: String?
}

extension DatabaseStore {
    // MARK: - Reading

    /// A page (by manifest id) or a group (by group id) for the skill screens.
    func skillMaterial(id: String) -> SkillMaterial? {
        if let owner = SkillGroupID.split(id) {
            guard let container = page(manifestID: owner.containerID),
                  let section = container.manifest.skillBoardSection(owner.sectionID) else { return nil }
            let folder = SkillGroupID.contentFolder(containerFolder: folderURL(for: container), sectionID: section.id)
            let media = folder.appendingPathComponent("media", isDirectory: true)
            let childIDs = skillPages(onBoard: container.manifest.id, sectionID: section.id).map(\.manifest.id)
            return SkillMaterial(
                id: id,
                manifest: section.asPage(container: container.manifest, childIDs: childIDs),
                folderURL: folder,
                mediaURLs: section.mediaFilenames.map { media.appendingPathComponent($0) },
                page: nil,
                groupContainer: container,
                section: section
            )
        }
        guard let page = page(manifestID: id) else { return nil }
        return SkillMaterial(
            id: id,
            manifest: page.manifest,
            folderURL: folderURL(for: page),
            mediaURLs: page.mediaURLs,
            page: page,
            groupContainer: nil,
            section: nil
        )
    }

    /// A page by its manifest id (a string, as routes and manifests carry it).
    func page(manifestID: String) -> ExercisePage? {
        if let uuid = UUID(uuidString: manifestID), let found = page(id: uuid) { return found }
        return allPagesFlat.first { $0.manifest.id == manifestID }
    }

    /// The picture inside a group's strip (a local image of the group), nil when it has none.
    func skillGroupImageURL(container: ExercisePage, section: SkillBoardSection) -> URL? {
        guard let filename = section.imageFilename, section.mediaFilenames.contains(filename) else { return nil }
        return SkillGroupID.mediaFolder(containerFolder: folderURL(for: container), sectionID: section.id)
            .appendingPathComponent(filename)
    }

    /// The groups of a board page, by order. A group id answers with no groups (groups hold no groups).
    func skillGroups(of boardID: String) -> [SkillBoardSection] {
        guard SkillGroupID.split(boardID) == nil, let board = page(manifestID: boardID) else { return [] }
        return board.manifest.orderedSkillBoardSections
    }

    /// The skill and tutorial pages a board shows: a page's direct skill children, or the pages inside a group.
    func skillBoardPages(of boardID: String) -> [ExercisePage] {
        if let owner = SkillGroupID.split(boardID) {
            return skillPages(onBoard: owner.containerID, sectionID: owner.sectionID)
        }
        return children(ofManifestID: boardID).filter(\.isSkillLike)
    }

    /// The skill pages of board `boardID` inside group `sectionID` (nil = outside every group, including pages whose
    /// group no longer exists), by their place in the group, ties by child order.
    func skillPages(onBoard boardID: String, sectionID: String?) -> [ExercisePage] {
        guard let board = page(manifestID: boardID) else { return [] }
        let known = Set(board.manifest.skillBoardSections.map(\.id))
        return Self.boardOrdered(children(ofManifestID: boardID).filter(\.isSkillLike).filter { page in
            let section = page.manifest.skillBoardSectionID.flatMap { known.contains($0) ? $0 : nil }
            return section == sectionID
        })
    }

    /// The group a board page's child sits in, nil when outside every group (or its group is gone).
    func skillSectionID(of page: ExercisePage) -> String? {
        guard let sectionID = page.manifest.skillBoardSectionID,
              let parentID = page.manifest.parentID,
              let parent = self.page(manifestID: parentID),
              parent.manifest.skillBoardSection(sectionID) != nil else { return nil }
        return sectionID
    }

    /// Direct children of a page by its manifest id, in child order.
    func children(ofManifestID id: String) -> [ExercisePage] {
        guard let parent = page(manifestID: id) else { return [] }
        return parent.manifest.childIDs.compactMap { page(manifestID: $0) }
    }

    /// Every skill page below a board (depth first, child order); a group answers with its pages and theirs.
    func skillDescendants(of boardID: String) -> [ExercisePage] {
        skillBoardPages(of: boardID).flatMap { page in [page] + skillDescendants(of: page.manifest.id) }
    }

    static func boardOrdered(_ pages: [ExercisePage]) -> [ExercisePage] {
        pages.enumerated()
            .sorted { ($0.element.manifest.skillBoardOrder ?? 0, $0.offset) < ($1.element.manifest.skillBoardOrder ?? 0, $1.offset) }
            .map(\.element)
    }

    // MARK: Types

    /// The highest skill in this page's chain. Sibling skills inside an untyped container do not share presets.
    func skillTypeOwner(of id: String) -> ExercisePage? {
        var current = page(manifestID: SkillGroupID.split(id)?.containerID ?? id)
        var root: ExercisePage?
        var hops = 0
        while let candidate = current, hops < 10_000 {
            if candidate.isSkillLike {
                root = candidate
            } else if candidate.isContainer && candidate.pageType == nil {
                return root ?? candidate
            }
            guard let parentID = candidate.manifest.parentID else { return root }
            current = page(manifestID: parentID)
            hops += 1
        }
        return nil
    }

    /// The presets offered below a page's type owner, by order, each with its types by order.
    func skillTypePresets(for id: String) -> [SkillTypePreset] {
        (skillTypeOwner(of: id)?.manifest.typePresets ?? [])
            .sorted { $0.order < $1.order }
            .map { preset in
                var preset = preset
                preset.types = preset.orderedTypes
                return preset
            }
    }

    /// Every type a page can wear, keyed by id.
    func skillTypesByID(for id: String) -> [String: SkillType] {
        Dictionary(skillTypePresets(for: id).flatMap(\.types).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The type a skill page wears; nil when it has none or its type is gone.
    func skillType(of page: ExercisePage) -> SkillType? {
        guard let typeID = page.manifest.typeID else { return nil }
        return skillTypesByID(for: page.manifest.id)[typeID]
    }

    /// `pages` with the type sort rules applied (top types first, bottom types last).
    func orderedByTypeRules(_ pages: [ExercisePage], boardID: String) -> [ExercisePage] {
        let containerID = SkillGroupID.split(boardID)?.containerID ?? boardID
        if page(manifestID: containerID)?.isSkillLike == true {
            return SkillTypeOrdering.ordered(pages, types: skillTypesByID(for: boardID)) { $0.manifest.typeID }
        }
        var types: [String: SkillType] = [:]
        for page in pages where page.manifest.typeID != nil {
            if let type = skillType(of: page) { types[type.id] = type }
        }
        return SkillTypeOrdering.ordered(pages, types: types) { $0.manifest.typeID }
    }

    // MARK: Prerequisites

    /// The pages and groups to learn first, in order; ids that no longer resolve are skipped.
    func skillDependencies(of id: String) -> [SkillMaterial] {
        (skillMaterial(id: id)?.manifest.dependencyPageIDs ?? []).compactMap(skillMaterial(id:))
    }

    /// Everything to have or learn first: prerequisite pages, media and links.
    func skillDependencyCount(of id: String) -> Int {
        guard let material = skillMaterial(id: id) else { return 0 }
        return skillDependencies(of: id).count + material.dependencyMediaURLs.count + material.dependencyLinkURLs.count
    }

    /// Pages and groups the "Learn first" picker must not offer for `id`: itself, those already listed and every one
    /// that (directly or through others) waits for it.
    func skillDependencyBlockedIDs(for id: String) -> Set<String> {
        var blocked: Set<String> = [id]
        blocked.formUnion(skillMaterial(id: id)?.manifest.dependencyPageIDs ?? [])
        var waits: [String: [String]] = [:]
        for page in allPagesFlat {
            for dependency in page.manifest.dependencyPageIDs { waits[dependency, default: []].append(page.manifest.id) }
            for section in page.manifest.skillBoardSections {
                let groupID = SkillGroupID.make(containerID: page.manifest.id, sectionID: section.id)
                for dependency in section.dependencyPageIDs { waits[dependency, default: []].append(groupID) }
            }
        }
        var queue = [id]
        while let current = queue.popLast() {
            for waiter in waits[current] ?? [] where blocked.insert(waiter).inserted {
                queue.append(waiter)
            }
        }
        return blocked
    }

    // MARK: - Writing

    /// Runs a library write behind the account guard, then reloads the library.
    func skillWrite<T>(_ body: (DatabaseManager) throws -> T) throws -> T {
        let token = ExerciseLibraryAccess.shared.capture()
        let result = try ExerciseLibraryAccess.shared.perform(token: token) {
            try body(DatabaseManager.shared)
        }
        reload()
        return result
    }

    /// Moves a skill page on its board: to `status` (nil keeps it), into `sectionID` (`.some(nil)` = out of every
    /// group, nil keeps its group), before `beforePageID` inside that group (nil = at the end; keeps its place when
    /// neither the group nor `beforePageID` is given).
    func placeSkillPage(_ pageID: String, status: SkillStatus? = nil, sectionID: String?? = nil, before beforePageID: String? = nil) throws {
        guard let moved = page(manifestID: pageID), let boardID = moved.manifest.parentID,
              let board = page(manifestID: boardID) else { throw FileSystemHelper.Error.notFound(pageID) }
        let currentSection = skillSectionID(of: moved)
        let targetSection: String? = sectionID ?? currentSection
        let targetStatus = status ?? moved.manifest.skillStatus ?? .notStarted
        var ids = skillPages(onBoard: boardID, sectionID: targetSection).map(\.manifest.id).filter { $0 != pageID }
        if let beforePageID, let index = ids.firstIndex(of: beforePageID) {
            ids.insert(pageID, at: index)
        } else if sectionID == nil, beforePageID == nil, targetSection == currentSection,
                  let index = skillPages(onBoard: boardID, sectionID: currentSection).map(\.manifest.id).firstIndex(of: pageID) {
            ids.insert(pageID, at: min(index, ids.count))
        } else {
            ids.append(pageID)
        }
        let placements = ids.enumerated().compactMap { order, id -> SkillBoardPlacement? in
            guard let item = page(manifestID: id) else { return nil }
            return SkillBoardPlacement(
                pageID: id,
                status: id == pageID ? targetStatus : item.manifest.skillStatus ?? .notStarted,
                sectionID: targetSection,
                order: order
            )
        }
        try skillWrite { database in
            try database.updateSkillBoard(
                containerID: boardID,
                sections: board.manifest.orderedSkillBoardSections,
                placements: placements
            )
        }
    }

    /// Changes a skill page's status and keeps its group and place.
    func setSkillStatus(_ status: SkillStatus, for pageID: String) throws {
        try placeSkillPage(pageID, status: status)
    }

    /// Renames a page or a group.
    func renameSkillPage(_ id: String, to title: String) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            guard manifest.title != clean else { return }
            manifest.title = clean
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    /// Creates a skill page on a board (a page id or a group id), in `sectionID` when the board is a page, at the end
    /// of its group. Returns the new page's id.
    @discardableResult
    func createSkillPage(title: String, on boardID: String, sectionID: String? = nil) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw FileSystemHelper.Error.writeFailed("A skill needs a name.") }
        let parentID: String
        if SkillGroupID.split(boardID) == nil, let sectionID {
            parentID = SkillGroupID.make(containerID: boardID, sectionID: sectionID)
        } else {
            parentID = boardID
        }
        var manifest = ExercisePageManifest(title: clean, pageType: .skill)
        return try skillWrite { database in
            if SkillGroupID.split(parentID) == nil {
                manifest.skillBoardOrder = try database.nextSkillBoardOrder(containerID: parentID, sectionID: nil)
            }
            try database.createPage(manifest: manifest, parentID: parentID)
            return manifest.id
        }
    }

    /// Notes of a page or a group (Markdown).
    func updateSkillNotes(_ id: String, markdown: String) throws {
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            guard manifest.markdownBody != markdown else { return }
            manifest.markdownBody = markdown
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    /// Adds a link to a page or a group (no-op when it is already there).
    func addSkillLink(_ url: String, to id: String, asDependency: Bool = false) throws {
        let clean = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            if !manifest.linkURLs.contains(clean) { manifest.linkURLs.append(clean) }
            if asDependency, !manifest.dependencyLinkURLs.contains(clean) { manifest.dependencyLinkURLs.append(clean) }
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    func removeSkillLink(_ url: String, from id: String) throws {
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            manifest.linkURLs.removeAll { $0 == url }
            manifest.linkMetadata.removeAll { $0.url == url }
            manifest.linkComments.removeValue(forKey: url)
            manifest.dependencyLinkURLs.removeAll { $0 == url }
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    func updateSkillLinkComment(_ comment: String, url: String, in id: String) throws {
        try skillWrite { try $0.updateLinkComment(pageID: id, url: url, comment: comment) }
    }

    /// Copies a file into a page's or a group's media. Returns the stored file name.
    @discardableResult
    func uploadSkillMedia(_ sourceURL: URL, to id: String, asDependency: Bool = false) throws -> String {
        try skillWrite { database in
            let filename = try database.uploadMediaToPage(pageID: id, sourceURL: sourceURL)
            if asDependency { try database.setMediaIsDependency(pageID: id, filename: filename, true) }
            return filename
        }
    }

    func removeSkillMedia(_ filename: String, from id: String) throws {
        try skillWrite { try $0.removeMediaFromPage(pageID: id, filename: filename) }
    }

    func setSkillMediaIsDependency(_ filename: String, in id: String, _ isDependency: Bool) throws {
        try skillWrite { try $0.setMediaIsDependency(pageID: id, filename: filename, isDependency) }
    }

    func setSkillLinkIsDependency(_ url: String, in id: String, _ isDependency: Bool) throws {
        try skillWrite { try $0.setLinkIsDependency(pageID: id, url: url, isDependency) }
    }

    func addSkillDependency(_ dependencyID: String, to id: String) throws {
        try skillWrite { try $0.addSkillDependency(dependencyID, to: id) }
    }

    func removeSkillDependency(_ dependencyID: String, from id: String) throws {
        try skillWrite { try $0.removeSkillDependency(dependencyID, from: id) }
    }

    func reorderSkillDependencies(in id: String, ids: [String]) throws {
        try skillWrite { try $0.reorderSkillDependencies(in: id, ids: ids) }
    }

    /// Sets a page's icon: an SF Symbol or emoji (`name` + `type`), or a picture (`image`: one of its media file names or
    /// an http(s) address). All nil = automatic. A group keeps only a symbol or emoji.
    func setSkillIcon(_ id: String, name: String?, type: SkillBoardIconType?, image: String? = nil) throws {
        if let owner = SkillGroupID.split(id) {
            try skillWrite { database in
                try database.updateSkillGroup(containerID: owner.containerID, sectionID: owner.sectionID) { section in
                    section.icon = name
                    section.iconType = name == nil ? nil : type ?? .emoji
                }
            }
            return
        }
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            manifest.iconName = name
            manifest.iconType = name == nil ? nil : type ?? .emoji
            manifest.iconImage = image
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    /// Chooses the cover of a page (one of its media; nil = none chosen) or the strip picture of a group.
    func setSkillCover(_ id: String, filename: String?) throws {
        try skillWrite { database in
            var manifest = try database.getPage(id: id)
            manifest.coverMediaFilename = filename
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
        }
    }

    // MARK: Groups

    /// Adds a group to a board page; without a colour it gets a random palette colour none of its other groups wears.
    @discardableResult
    func addSkillGroup(to boardID: String, title: String, icon: String? = nil, iconType: SkillBoardIconType? = nil, colorHex: String? = nil) throws -> SkillBoardSection {
        try skillWrite { try $0.addSkillGroup(to: boardID, title: title, icon: icon, iconType: iconType, colorHex: colorHex) }
    }

    @discardableResult
    func updateSkillGroup(containerID: String, sectionID: String, _ change: (inout SkillBoardSection) throws -> Void) throws -> SkillBoardSection {
        try skillWrite { try $0.updateSkillGroup(containerID: containerID, sectionID: sectionID, change) }
    }

    func deleteSkillGroup(containerID: String, sectionID: String) throws {
        try skillWrite { try $0.deleteSkillGroup(containerID: containerID, sectionID: sectionID) }
    }

    func reorderSkillGroups(containerID: String, ids: [String]) throws {
        try skillWrite { try $0.reorderSkillGroups(containerID: containerID, ids: ids) }
    }

    /// Copies a picture into a group's media and puts it inside the group's strip.
    func setSkillGroupPicture(containerID: String, sectionID: String, sourceURL: URL) throws {
        let groupID = SkillGroupID.make(containerID: containerID, sectionID: sectionID)
        try skillWrite { database in
            let filename = try database.uploadMediaToPage(pageID: groupID, sourceURL: sourceURL)
            try database.updateSkillGroup(containerID: containerID, sectionID: sectionID) { $0.imageFilename = filename }
        }
    }

    // MARK: Types

    func setSkillType(_ typeID: String?, for pageID: String) throws {
        try skillWrite { try $0.setSkillType(typeID, for: pageID) }
    }

    @discardableResult
    func addSkillType(
        to id: String,
        presetID: String? = nil,
        title: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system,
        effect: SkillTypeEffect = .tint,
        sortRule: SkillTypeSortRule = .none
    ) throws -> SkillType {
        try skillWrite { database in
            try database.addSkillType(
                to: id, presetID: presetID, title: title, colorHex: colorHex, iconName: iconName,
                iconType: iconType, effect: effect, sortRule: sortRule
            )
        }
    }

    @discardableResult
    func updateSkillType(_ typeID: String, in id: String, _ change: (inout SkillType) throws -> Void) throws -> SkillType {
        try skillWrite { try $0.updateSkillType(typeID, in: id, change) }
    }

    func deleteSkillType(_ typeID: String, in id: String) throws {
        try skillWrite { try $0.deleteSkillType(typeID, in: id) }
    }

    func reorderSkillTypes(in id: String, presetID: String, ids: [String]) throws {
        try skillWrite { try $0.reorderSkillTypes(in: id, presetID: presetID, ids: ids) }
    }

    @discardableResult
    func addSkillTypePreset(
        to id: String,
        title: String,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system
    ) throws -> SkillTypePreset {
        try skillWrite { try $0.addSkillTypePreset(to: id, title: title, iconName: iconName, iconType: iconType) }
    }

    /// Changes a preset's name or icon (its types stay).
    @discardableResult
    func updateSkillTypePreset(_ presetID: String, in id: String, _ change: (inout SkillTypePreset) throws -> Void) throws -> SkillTypePreset {
        try skillWrite { try $0.updateSkillTypePreset(presetID, in: id, change) }
    }

    func deleteSkillTypePreset(_ presetID: String, in id: String) throws {
        try skillWrite { try $0.deleteSkillTypePreset(presetID, in: id) }
    }

    /// How many pages wear one of `typeIDs` (type ids are unique, so this counts the pages of the skill that owns them):
    /// what deleting a type or a preset takes away.
    func skillPageCount(wearing typeIDs: Set<String>) -> Int {
        guard !typeIDs.isEmpty else { return 0 }
        return allPagesFlat.filter { page in page.manifest.typeID.map(typeIDs.contains) ?? false }.count
    }
}
