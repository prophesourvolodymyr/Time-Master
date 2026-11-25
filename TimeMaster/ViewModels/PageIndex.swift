import Foundation

/// Immutable lookups over one library snapshot: pages by id, children in manifest order, parents and breadcrumbs.
struct PageIndex {
    let pages: [ExercisePage]
    let byID: [UUID: ExercisePage]
    let byManifestID: [String: ExercisePage]
    /// Children of each page, ordered like the parent's `manifest.childIDs`.
    let childrenByParent: [UUID: [ExercisePage]]
    let parentByID: [UUID: UUID]

    init(pages: [ExercisePage]) {
        var byID: [UUID: ExercisePage] = [:]
        var byManifestID: [String: ExercisePage] = [:]
        var parentByID: [UUID: UUID] = [:]
        byID.reserveCapacity(pages.count)
        byManifestID.reserveCapacity(pages.count)
        for page in pages {
            if byManifestID[page.manifest.id] == nil { byManifestID[page.manifest.id] = page }
            guard let uuid = UUID(uuidString: page.manifest.id), byID[uuid] == nil else { continue }
            byID[uuid] = page
            if let parent = page.manifest.parentID.flatMap(UUID.init(uuidString:)) { parentByID[uuid] = parent }
        }
        var childrenByParent: [UUID: [ExercisePage]] = [:]
        for (uuid, page) in byID where !page.manifest.childIDs.isEmpty {
            childrenByParent[uuid] = page.manifest.childIDs.compactMap { childID in
                UUID(uuidString: childID).flatMap { byID[$0] }
            }
        }
        self.pages = pages
        self.byID = byID
        self.byManifestID = byManifestID
        self.childrenByParent = childrenByParent
        self.parentByID = parentByID
    }

    /// The page and its parents, root first; empty when the page is unknown.
    func breadcrumbs(for id: UUID) -> [ExercisePage] {
        var crumbs: [ExercisePage] = []
        var seen: Set<UUID> = []
        var current: UUID? = id
        while let uuid = current, seen.insert(uuid).inserted, let page = byID[uuid] {
            crumbs.append(page)
            current = parentByID[uuid]
        }
        crumbs.reverse()
        return crumbs
    }
}

/// Derived library data kept until the next change of `DatabaseStore.allPagesFlat` or `rootPages`. Main thread only.
final class LibraryDerivedCache {
    var index: PageIndex?
    var skillLibrary: SkillLibrary?
    var pageTree: [ExercisePage]?
    var containerModels: [String: ContainerBrowseModel] = [:]
    var prerequisiteCandidates: [String: [SkillMaterial]] = [:]
    var workoutTypeChips: [FilterTypeChip]?

    func reset() {
        index = nil
        skillLibrary = nil
        pageTree = nil
        containerModels.removeAll(keepingCapacity: true)
        prerequisiteCandidates.removeAll(keepingCapacity: true)
        workoutTypeChips = nil
    }
}
