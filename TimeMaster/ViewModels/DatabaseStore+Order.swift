import Foundation
import TimeMasterCore

extension DatabaseStore {
    /// Puts page `id` right before its sibling `targetID` (right after it with `after`) for good: the library
    /// renumbers the siblings (`DatabaseManager.placePage`) and the new order shows at once, before the library reloads.
    func placePage(_ id: String, nextTo targetID: String, after: Bool) throws {
        guard id != targetID else { return }
        let parentID = page(manifestID: id)?.manifest.parentID
        let token = ExerciseLibraryAccess.shared.capture()
        let placed = try ExerciseLibraryAccess.shared.perform(token: token) {
            try DatabaseManager.shared.placePage(id: id, nextTo: targetID, after: after)
        }
        publishSiblingOrder(placed, parentID: parentID)
        reload()
    }

    /// Moves page `id` into `parentID` (nil: the top of the Database), after every page already there.
    func movePageToEnd(id: String, parentID: String?) throws {
        let token = ExerciseLibraryAccess.shared.capture()
        try ExerciseLibraryAccess.shared.perform(token: token) {
            try DatabaseManager.shared.movePageToEnd(id: id, parentID: parentID)
        }
        reload()
    }

    /// Each page's place in the library read top to bottom (the page tree depth first, siblings in their stored order),
    /// by manifest id: the Manual order of lists that show pages from all over the library. Built once per library change.
    var libraryOrder: [String: Int] {
        LibraryOrderCache.shared.ranks(of: self)
    }

    /// Shows a new order of siblings right away: each sibling's `order` and the parent's `childIDs`.
    private func publishSiblingOrder(_ ids: [String], parentID: String?) {
        let positions = Dictionary(ids.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var pages = allPagesFlat
        var changed = false
        for index in pages.indices {
            let current = pages[index]
            var manifest = current.manifest
            if let position = positions[manifest.id] {
                guard manifest.order != position else { continue }
                manifest.order = position
            } else if let parentID, manifest.id == parentID, manifest.childIDs != ids {
                manifest.childIDs = ids
            } else {
                continue
            }
            pages[index] = ExercisePage(
                manifest: manifest,
                coverImageURL: current.coverImageURL,
                mediaURLs: current.mediaURLs,
                path: current.path,
                inheritedWorkoutType: current.inheritedWorkoutType
            )
            changed = true
        }
        guard changed else { return }
        allPagesFlat = pages
        rootPages = PageTreeBuilder.build(from: pages)
    }
}

/// `DatabaseStore.libraryOrder`, kept until the library reloads or gains or loses pages. Main thread only.
private final class LibraryOrderCache {
    static let shared = LibraryOrderCache()

    private var key: (store: ObjectIdentifier, revision: Int, count: Int)?
    private var cached: [String: Int] = [:]

    func ranks(of store: DatabaseStore) -> [String: Int] {
        let current = (store: ObjectIdentifier(store), revision: store.libraryRevision, count: store.allPagesFlat.count)
        if let key, key == current { return cached }
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(current.count)
        var pending = Array(store.rootPages.reversed())
        while let page = pending.popLast() {
            if ranks[page.manifest.id] == nil { ranks[page.manifest.id] = ranks.count }
            pending.append(contentsOf: page.children.reversed())
        }
        cached = ranks
        key = current
        return ranks
    }
}
