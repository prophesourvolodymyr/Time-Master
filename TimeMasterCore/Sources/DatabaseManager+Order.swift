import Foundation

/// The stored order of pages that sit side by side (the top-level pages, or the pages directly inside one page): by
/// `order`, then by creation, then by id, the way sync settles them. The library lists siblings in this order, the
/// app's Manual sort shows it, and a page put in a new place renumbers its siblings 0…n so the parent's `childIDs`
/// and every sibling's `order` agree.
public enum PageOrder {
    /// Whether `lhs` comes before its sibling `rhs`.
    public static func precedes(_ lhs: ExercisePageManifest, _ rhs: ExercisePageManifest) -> Bool {
        if lhs.order != rhs.order { return lhs.order < rhs.order }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id < rhs.id
    }

    /// `ids` with `id` taken out and put back right before `targetID` (right after it with `after`); nil when either
    /// is not in `ids`. A page placed next to itself leaves `ids` as they are.
    public static func placing(_ id: String, nextTo targetID: String, after: Bool, in ids: [String]) -> [String]? {
        guard ids.contains(id), ids.contains(targetID) else { return nil }
        guard id != targetID else { return ids }
        var placed = ids.filter { $0 != id }
        guard let index = placed.firstIndex(of: targetID) else { return nil }
        placed.insert(id, at: after ? index + 1 : index)
        return placed
    }
}

extension DatabaseManager {
    /// Puts page `id` right before its sibling `targetID` (right after it with `after`) and renumbers the siblings
    /// 0…n in their new order; the parent's `childIDs` follow. Only the manifests whose place changes are written, and
    /// only their `manifest.json`: a new place is not an edit of the page, so `updatedAt` stays. Returns the
    /// siblings' ids in their new order.
    @discardableResult
    public func placePage(id: String, nextTo targetID: String, after: Bool) throws -> [String] {
        guard SkillGroupID.split(id) == nil, SkillGroupID.split(targetID) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("groups keep their place on their board")
        }
        let parentID = try getPage(id: id).parentID
        guard try getPage(id: targetID).parentID == parentID else {
            throw FileSystemHelper.Error.invalidPageKind("a page can only take a place next to a page in the same place")
        }
        let siblings = try storedSiblings(parentID: parentID)
        let ids = siblings.map { $0.manifest.id }
        guard let placed = PageOrder.placing(id, nextTo: targetID, after: after, in: ids) else {
            throw FileSystemHelper.Error.notFound(ids.contains(id) ? targetID : id)
        }
        try persistSiblingOrder(placed, parentID: parentID, siblings: siblings)
        return placed
    }

    /// Makes `ids` the stored order of the pages directly in `parentID` (nil: the top level): each one's `order` becomes
    /// its place in `ids` and the parent's `childIDs` become `ids`. Only manifests that change are written, and only
    /// their `manifest.json`: a new place is not an edit of the page, so `updatedAt` stays.
    func persistSiblingOrder(
        _ ids: [String],
        parentID: String?,
        siblings: [(manifest: ExercisePageManifest, folder: URL)]
    ) throws {
        let byID = Dictionary(siblings.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (position, siblingID) in ids.enumerated() {
            guard var sibling = byID[siblingID], sibling.manifest.order != position else { continue }
            sibling.manifest.order = position
            try writePageManifest(sibling.manifest, at: sibling.folder)
        }
        if let parentID {
            var parent = try getPage(id: parentID)
            if parent.childIDs != ids {
                parent.childIDs = ids
                try writePageManifest(parent, at: try resolvePageFolder(id: parentID))
            }
        }
    }

    /// One past the highest stored place among the pages directly in `parentID` (nil: the top level), leaving out
    /// `excludedID`; 0 when there are none. Places can have gaps (a deleted page leaves one), so a page put at the end
    /// takes this rather than the number of pages.
    public func nextSiblingOrder(parentID: String?, excluding excludedID: String? = nil) throws -> Int {
        let orders = try storedSiblings(parentID: parentID).lazy
            .filter { $0.manifest.id != excludedID }
            .map { $0.manifest.order }
        return (orders.max() ?? -1) + 1
    }

    /// Moves page `id` into `parentID` (nil: the top level), after every page already there.
    public func movePageToEnd(id: String, parentID: String?) throws {
        let order = try nextSiblingOrder(parentID: parentID, excluding: id)
        try movePage(id: id, newParentID: parentID, newOrder: order)
    }

    /// The pages directly in `parentID` (nil: the top level) as their folders hold them, in `PageOrder`.
    func storedSiblings(parentID: String?) throws -> [(manifest: ExercisePageManifest, folder: URL)] {
        let directory = try parentID.map { try resolvePageFolder(id: $0) } ?? fs.exercisesDatabaseDirectory
        var siblings: [(manifest: ExercisePageManifest, folder: URL)] = []
        for entry in try fs.listDirectory(directory, skipNonSchema: false) {
            let name = entry.lastPathComponent
            guard name != "media", name != "Attachments", name != SkillGroupID.folderName,
                  fs.directoryExists(at: entry),
                  let manifest = try? readPageManifest(at: entry),
                  manifest.parentID == parentID else { continue }
            siblings.append((manifest, entry))
        }
        return siblings.sorted { PageOrder.precedes($0.manifest, $1.manifest) }
    }

    /// Puts every walked page's `childIDs` (its child folders, as the walk found them) in `PageOrder`; a child the walk
    /// could not read goes last, by id.
    static func orderChildIDs(_ walked: inout [(ExercisePageManifest, path: String)]) {
        var byID: [String: ExercisePageManifest] = [:]
        byID.reserveCapacity(walked.count)
        for (manifest, _) in walked where byID[manifest.id] == nil {
            byID[manifest.id] = manifest
        }
        for index in walked.indices where walked[index].0.childIDs.count > 1 {
            walked[index].0.childIDs.sort { lhs, rhs in
                switch (byID[lhs], byID[rhs]) {
                case let (left?, right?): return PageOrder.precedes(left, right)
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return lhs < rhs
                }
            }
        }
    }
}
