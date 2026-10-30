import Foundation

// Skill boards: groups (sections that open as pages), types and prerequisites.
//
// A board page is a container (an untyped container, or a skill page with skill children). Its groups live in its
// manifest (`skillBoardSections`); a group's media live in `<board page>/Sections/<section id>/media/`. Types live in
// each skill's own presets (`typePresets`); sub-skills share their top skill's types, not those of sibling skills.
extension DatabaseManager {
    // MARK: - Groups

    /// Creates `manifest` on the board page `containerID`, inside group `sectionID`, at the end of the group.
    func createPage(_ manifest: ExercisePageManifest, inGroup sectionID: String, of containerID: String) throws {
        let container = try getPage(id: containerID)
        guard container.skillBoardSection(sectionID) != nil else {
            throw FileSystemHelper.Error.notFound(SkillGroupID.make(containerID: containerID, sectionID: sectionID))
        }
        var page = manifest
        page.parentID = containerID
        if page.pageType == .skill || page.pageType == .tutorial {
            page.skillBoardSectionID = sectionID
            page.skillBoardOrder = try nextSkillBoardOrder(containerID: containerID, sectionID: sectionID)
        }
        try createPage(manifest: page, parentID: containerID)
    }

    /// One past the last place of the board page's skill pages in group `sectionID` (nil = not in a group). A page
    /// placed there lands at the end of that group whatever its status.
    public func nextSkillBoardOrder(containerID: String, sectionID: String?) throws -> Int {
        let container = try getPage(id: containerID)
        let sectionIDs = Set(container.skillBoardSections.map(\.id))
        var last = -1
        for childID in container.childIDs {
            guard let child = try? getPage(id: childID), child.pageType == .skill || child.pageType == .tutorial else { continue }
            let childSection = child.skillBoardSectionID.flatMap { sectionIDs.contains($0) ? $0 : nil }
            guard childSection == sectionID else { continue }
            last = max(last, child.skillBoardOrder ?? 0)
        }
        return last + 1
    }

    /// Adds a group at the end of a board page. Without a colour the group gets a random palette colour, preferring
    /// one none of the page's other groups wears.
    @discardableResult
    public func addSkillGroup(
        to containerID: String,
        title: String,
        icon: String? = nil,
        iconType: SkillBoardIconType? = nil,
        colorHex: String? = nil
    ) throws -> SkillBoardSection {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw FileSystemHelper.Error.writeFailed("A group needs a name.") }
        let folder = try boardFolder(containerID)
        var container = try readPageManifest(at: folder)
        let strip = SkillColors.normalizedHex(colorHex)
            ?? SkillColors.random(avoiding: container.skillBoardSections.compactMap(\.colorHex))
        let cleanIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let section = SkillBoardSection(
            title: cleanTitle,
            order: container.skillBoardSections.count,
            icon: cleanIcon,
            iconType: cleanIcon == nil ? nil : iconType ?? .emoji,
            colorHex: strip
        )
        container.skillBoardSections = Self.renumberedSections(container.orderedSkillBoardSections + [section])
        container.updatedAt = Date()
        try writePageFiles(container, in: folder)
        return container.skillBoardSection(section.id) ?? section
    }

    /// Edits a group (title, icon, colour, strip picture, material). Its id never changes; the title cannot be empty.
    @discardableResult
    public func updateSkillGroup(
        containerID: String,
        sectionID: String,
        _ change: (inout SkillBoardSection) throws -> Void
    ) throws -> SkillBoardSection {
        let folder = try boardFolder(containerID)
        var container = try readPageManifest(at: folder)
        guard let index = container.skillBoardSections.firstIndex(where: { $0.id == sectionID }) else {
            throw FileSystemHelper.Error.notFound(SkillGroupID.make(containerID: containerID, sectionID: sectionID))
        }
        var section = container.skillBoardSections[index]
        try change(&section)
        section.id = sectionID
        section.title = section.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !section.title.isEmpty else { throw FileSystemHelper.Error.writeFailed("A group needs a name.") }
        section.icon = section.icon?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if section.icon == nil { section.iconType = nil }
        section.dependencyPageIDs.removeAll { $0 == SkillGroupID.make(containerID: containerID, sectionID: sectionID) }
        container.skillBoardSections[index] = section.normalizedMaterial()
        container.skillBoardSections = Self.renumberedSections(container.skillBoardSections)
        container.updatedAt = Date()
        try writePageFiles(container, in: folder)
        return container.skillBoardSection(sectionID) ?? section
    }

    /// Removes a group: its pages stay on the board outside any group (after the ones already there), its media
    /// folder moves to the trash.
    public func deleteSkillGroup(containerID: String, sectionID: String) throws {
        let container = try getPage(id: containerID)
        guard container.skillBoardSection(sectionID) != nil else {
            throw FileSystemHelper.Error.notFound(SkillGroupID.make(containerID: containerID, sectionID: sectionID))
        }
        var next = try nextSkillBoardOrder(containerID: containerID, sectionID: nil)
        var placements: [SkillBoardPlacement] = []
        for childID in container.childIDs {
            guard let child = try? getPage(id: childID),
                  child.pageType == .skill || child.pageType == .tutorial,
                  child.skillBoardSectionID == sectionID else { continue }
            placements.append(SkillBoardPlacement(pageID: childID, status: child.skillStatus ?? .notStarted, sectionID: nil, order: next))
            next += 1
        }
        try updateSkillBoard(
            containerID: containerID,
            sections: container.orderedSkillBoardSections.filter { $0.id != sectionID },
            placements: placements
        )
    }

    /// Puts the board page's groups in the order of `ids`; groups not listed keep their places after them.
    public func reorderSkillGroups(containerID: String, ids: [String]) throws {
        let folder = try boardFolder(containerID)
        var container = try readPageManifest(at: folder)
        let ordered = container.orderedSkillBoardSections
        let byID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let listed = ids.uniqued().compactMap { byID[$0] }
        let rest = ordered.filter { section in !listed.contains { $0.id == section.id } }
        container.skillBoardSections = (listed + rest).enumerated().map { index, section in
            var section = section
            section.order = index
            return section
        }
        container.updatedAt = Date()
        try writePageFiles(container, in: folder)
    }

    /// The folder of a page that can own a board (not a group, not an exercise).
    private func boardFolder(_ containerID: String) throws -> URL {
        guard SkillGroupID.split(containerID) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("a group cannot hold groups")
        }
        let folder = try resolvePageFolder(id: containerID)
        let manifest = try readPageManifest(at: folder)
        guard manifest.pageKind == .container, manifest.pageType != .exercise else {
            throw FileSystemHelper.Error.invalidPageKind("skill boards belong to pages that allow children")
        }
        return folder
    }

    // MARK: - Types

    /// The highest skill in the page's skill chain, even when it lives inside an untyped container. An untyped board
    /// with no skill ancestor can keep its own presets; a group answers for its board page.
    public func skillTypeOwnerID(of pageID: String) throws -> String {
        try skillTypeOwner(of: pageID).manifest.id
    }

    /// The type presets offered to `pageID` (any page of the board, a group, or the owner itself), each with its types,
    /// both by `order`.
    public func skillTypePresets(for pageID: String) throws -> [SkillTypePreset] {
        Self.renumberedTypePresets(try skillTypeOwner(of: pageID).manifest.typePresets)
    }

    /// Adds a preset at the end of the owner's presets. Its icon is optional (an SF Symbol name or an emoji).
    @discardableResult
    public func addSkillTypePreset(
        to pageID: String,
        title: String,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system
    ) throws -> SkillTypePreset {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw FileSystemHelper.Error.writeFailed("A preset needs a name.") }
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        let icon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let preset = SkillTypePreset(title: cleanTitle, iconName: icon, iconType: icon == nil ? .system : iconType, order: presets.count)
        presets.append(preset)
        let saved = try savePresets(presets, owner: owner)
        return saved.first { $0.id == preset.id } ?? preset
    }

    /// Edits a preset's name or icon. Its id, order and types are kept; an empty name is refused.
    @discardableResult
    public func updateSkillTypePreset(
        _ presetID: String,
        in pageID: String,
        _ change: (inout SkillTypePreset) throws -> Void
    ) throws -> SkillTypePreset {
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        guard let index = presets.firstIndex(where: { $0.id == presetID }) else {
            throw FileSystemHelper.Error.notFound(presetID)
        }
        var preset = presets[index]
        try change(&preset)
        preset.id = presets[index].id
        preset.order = presets[index].order
        preset.types = presets[index].types
        preset.title = preset.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preset.title.isEmpty else { throw FileSystemHelper.Error.writeFailed("A preset needs a name.") }
        presets[index] = preset
        let saved = try savePresets(presets, owner: owner)
        return saved.first { $0.id == presetID } ?? preset
    }

    /// Deletes a preset with its types; the pages that wore one of them lose their type.
    public func deleteSkillTypePreset(_ presetID: String, in pageID: String) throws {
        let owner = try skillTypeOwner(of: pageID)
        guard let preset = owner.manifest.typePresets.first(where: { $0.id == presetID }) else {
            throw FileSystemHelper.Error.notFound(presetID)
        }
        _ = try savePresets(owner.manifest.typePresets.filter { $0.id != presetID }, owner: owner)
        try clearSkillTypes(Set(preset.types.map(\.id)), below: owner.folder)
    }

    /// Adds a type at the end of a preset (`presetID` nil = the first preset; one called "Types" is made when there is
    /// none). Without a colour the type gets a random palette colour, preferring one no other type of the owner wears.
    @discardableResult
    public func addSkillType(
        to pageID: String,
        presetID: String? = nil,
        title: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system,
        effect: SkillTypeEffect = .tint,
        sortRule: SkillTypeSortRule = .none
    ) throws -> SkillType {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw FileSystemHelper.Error.writeFailed("A type needs a name.") }
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        let index: Int
        if let presetID {
            guard let found = presets.firstIndex(where: { $0.id == presetID }) else {
                throw FileSystemHelper.Error.notFound(presetID)
            }
            index = found
        } else if presets.isEmpty {
            presets.append(SkillTypePreset(title: "Types", order: 0))
            index = 0
        } else {
            index = 0
        }
        let colour = SkillColors.normalizedHex(colorHex)
            ?? SkillColors.random(avoiding: presets.flatMap(\.types).compactMap(\.colorHex))
        let type = SkillType(
            title: cleanTitle,
            colorHex: colour,
            iconName: iconName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            iconType: iconType,
            effect: effect,
            sortRule: sortRule,
            order: presets[index].types.count
        )
        presets[index].types.append(type)
        let saved = try savePresets(presets, owner: owner)
        return saved.flatMap(\.types).first { $0.id == type.id } ?? type
    }

    /// Edits a type. Its id never changes; a changed `order` moves it inside its preset.
    @discardableResult
    public func updateSkillType(_ typeID: String, in pageID: String, _ change: (inout SkillType) throws -> Void) throws -> SkillType {
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        guard let (p, t) = Self.locate(typeID, in: presets) else { throw FileSystemHelper.Error.notFound(typeID) }
        var type = presets[p].types[t]
        try change(&type)
        type.id = typeID
        type.title = type.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !type.title.isEmpty else { throw FileSystemHelper.Error.writeFailed("A type needs a name.") }
        type.iconName = type.iconName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        presets[p].types[t] = type
        let saved = try savePresets(presets, owner: owner)
        return saved.flatMap(\.types).first { $0.id == typeID } ?? type
    }

    /// Deletes a type; every page below its owner that wore it loses its type.
    public func deleteSkillType(_ typeID: String, in pageID: String) throws {
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        guard let (p, t) = Self.locate(typeID, in: presets) else { throw FileSystemHelper.Error.notFound(typeID) }
        presets[p].types.remove(at: t)
        _ = try savePresets(presets, owner: owner)
        try clearSkillTypes([typeID], below: owner.folder)
    }

    /// Puts the types of a preset in the order of `ids`; types not listed keep their places after them.
    public func reorderSkillTypes(in pageID: String, presetID: String, ids: [String]) throws {
        let owner = try skillTypeOwner(of: pageID)
        var presets = Self.renumberedTypePresets(owner.manifest.typePresets)
        guard let index = presets.firstIndex(where: { $0.id == presetID }) else { throw FileSystemHelper.Error.notFound(presetID) }
        let types = presets[index].orderedTypes
        let listed = ids.uniqued().compactMap { id in types.first { $0.id == id } }
        let rest = types.filter { type in !listed.contains { $0.id == type.id } }
        presets[index].types = (listed + rest).enumerated().map { offset, type in
            var type = type
            type.order = offset
            return type
        }
        _ = try savePresets(presets, owner: owner)
    }

    /// Gives a skill page a type (nil clears it). The type must be one of its owner's; a group has no type.
    public func setSkillType(_ typeID: String?, for pageID: String) throws {
        guard SkillGroupID.split(pageID) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("a group has no type")
        }
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw FileSystemHelper.Error.invalidPageKind("only skills and tutorials wear a type")
        }
        if let typeID {
            guard try skillTypeOwner(of: pageID).manifest.skillType(typeID) != nil else {
                throw FileSystemHelper.Error.notFound(typeID)
            }
        }
        guard page.typeID != typeID else { return }
        page.typeID = typeID
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    func skillTypeOwner(of pageID: String) throws -> (folder: URL, manifest: ExercisePageManifest) {
        var id = SkillGroupID.split(pageID)?.containerID ?? pageID
        var hops = 0
        var skillRoot: (folder: URL, manifest: ExercisePageManifest)?
        while true {
            let folder = try resolvePageFolder(id: id)
            let manifest = try readPageManifest(at: folder)
            if manifest.pageType == .skill || manifest.pageType == .tutorial {
                skillRoot = (folder, manifest)
            } else if manifest.pageKind == .container, manifest.pageType == nil {
                return skillRoot ?? (folder, manifest)
            }
            guard let parentID = manifest.parentID else {
                if let skillRoot { return skillRoot }
                throw FileSystemHelper.Error.invalidPageKind("this page has no skill board above it to keep types")
            }
            hops += 1
            guard hops < 10_000 else { throw FileSystemHelper.Error.invalidPageKind("the page sits too deep to find its board") }
            id = parentID
        }
    }

    private func savePresets(_ presets: [SkillTypePreset], owner: (folder: URL, manifest: ExercisePageManifest)) throws -> [SkillTypePreset] {
        var updated = owner.manifest
        updated.typePresets = Self.renumberedTypePresets(presets)
        updated.updatedAt = Date()
        try writePageManifest(updated, at: owner.folder)
        return updated.typePresets
    }

    /// Clears a deleted type on the owner itself and every descendant that wore it.
    private func clearSkillTypes(_ ids: Set<String>, below folder: URL) throws {
        guard !ids.isEmpty else { return }
        var stack = [folder]
        while let current = stack.popLast() {
            var page = try readPageManifest(at: current)
            if let typeID = page.typeID, ids.contains(typeID) {
                page.typeID = nil
                page.updatedAt = Date()
                try writePageManifest(page, at: current)
            }
            for entry in try fs.listDirectory(current, skipNonSchema: false) {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory), isDirectory.boolValue,
                   fs.fileExists(at: entry.appendingPathComponent("manifest.json")) {
                    stack.append(entry)
                }
            }
        }
    }

    /// Presets and their types sorted by `order` (ties keep their stored order) and numbered 0…n; colours normalised,
    /// empty titles replaced, repeated ids dropped, a preset's icon trimmed (an empty one means none).
    static func renumberedTypePresets(_ presets: [SkillTypePreset]) -> [SkillTypePreset] {
        func ordered<T>(_ items: [T], by order: (T) -> Int) -> [T] {
            items.enumerated().sorted { (order($0.element), $0.offset) < (order($1.element), $1.offset) }.map(\.element)
        }
        var presetIDs = Set<String>()
        var typeIDs = Set<String>()
        return ordered(presets, by: \.order)
            .filter { presetIDs.insert($0.id).inserted }
            .enumerated()
            .map { position, preset in
                var preset = preset
                preset.order = position
                preset.title = preset.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Types"
                preset.iconName = preset.iconName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                if preset.iconName == nil { preset.iconType = .system }
                preset.types = ordered(preset.types, by: \.order)
                    .filter { typeIDs.insert($0.id).inserted }
                    .enumerated()
                    .map { place, type in
                        var type = type
                        type.order = place
                        type.title = type.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Type"
                        type.colorHex = SkillColors.normalizedHex(type.colorHex)
                        return type
                    }
                return preset
            }
    }

    static func locate(_ typeID: String, in presets: [SkillTypePreset]) -> (preset: Int, type: Int)? {
        for (p, preset) in presets.enumerated() {
            if let t = preset.types.firstIndex(where: { $0.id == typeID }) { return (p, t) }
        }
        return nil
    }

    // MARK: - Prerequisites

    /// Adds a page (or group) to learn first at the end of `pageID`'s prerequisites. Throws for the page itself, a page
    /// that does not exist, a page already listed, or one that already waits for `pageID` (a loop).
    public func addSkillDependency(_ dependencyID: String, to pageID: String) throws {
        guard dependencyID != pageID else { throw FileSystemHelper.Error.invalidPageKind("a page cannot come before itself") }
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw FileSystemHelper.Error.invalidPageKind("only skills, tutorials and groups have prerequisites")
        }
        guard !page.dependencyPageIDs.contains(dependencyID) else { return }
        _ = try getPage(id: dependencyID)
        guard try !waitsFor(dependencyID, on: pageID) else {
            throw FileSystemHelper.Error.invalidPageKind("that page already waits for this one")
        }
        page.dependencyPageIDs.append(dependencyID)
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    public func removeSkillDependency(_ dependencyID: String, from pageID: String) throws {
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.dependencyPageIDs.contains(dependencyID) else { return }
        page.dependencyPageIDs.removeAll { $0 == dependencyID }
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    /// Puts the prerequisites in the order of `ids`; prerequisites not listed keep their places after them.
    public func reorderSkillDependencies(in pageID: String, ids: [String]) throws {
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        let current = page.dependencyPageIDs
        let listed = ids.uniqued().filter(current.contains)
        page.dependencyPageIDs = listed + current.filter { !listed.contains($0) }
        guard page.dependencyPageIDs != current else { return }
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    /// Moves one of the page's media between its reference material and its prerequisites.
    public func setMediaIsDependency(pageID: String, filename: String, _ isDependency: Bool) throws {
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.mediaFilenames.contains(filename) else { throw FileSystemHelper.Error.notFound(filename) }
        page.dependencyMediaFilenames.removeAll { $0 == filename }
        if isDependency { page.dependencyMediaFilenames.append(filename) }
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    /// Moves one of the page's links between its reference material and its prerequisites.
    public func setLinkIsDependency(pageID: String, url: String, _ isDependency: Bool) throws {
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.linkURLs.contains(url) else { throw FileSystemHelper.Error.notFound(url) }
        page.dependencyLinkURLs.removeAll { $0 == url }
        if isDependency { page.dependencyLinkURLs.append(url) }
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    /// Sets (or, when empty, removes) the Markdown comment of one of the page's links.
    public func updateLinkComment(pageID: String, url: String, comment: String) throws {
        let folder = try resolvePageFolder(id: pageID)
        var page = try readPageManifest(at: folder)
        guard page.linkURLs.contains(url) else { throw FileSystemHelper.Error.notFound(url) }
        page.linkComments[url] = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
        page.updatedAt = Date()
        try writePageManifest(page, at: folder)
    }

    /// True when `candidateID` (directly or through its own prerequisites) waits for `pageID`.
    private func waitsFor(_ candidateID: String, on pageID: String) throws -> Bool {
        var queue = [candidateID]
        var seen: Set<String> = [candidateID]
        while let current = queue.popLast() {
            guard let manifest = try? getPage(id: current) else { continue }
            for next in manifest.dependencyPageIDs {
                if next == pageID { return true }
                if seen.insert(next).inserted { queue.append(next) }
            }
        }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
