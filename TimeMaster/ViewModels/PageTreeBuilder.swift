import Foundation

enum PageTreeBuilder {
    static func build(from flatList: [ExercisePage]) -> [ExercisePage] {
        let lookup = Dictionary(uniqueKeysWithValues: flatList.map { ($0.id, $0) })
        let roots = flatList.filter { $0.manifest.parentID == nil }
        return roots.map { buildBranch(root: $0, lookup: lookup) }
    }

    private static func buildBranch(root: ExercisePage, lookup: [UUID: ExercisePage]) -> ExercisePage {
        let children = root.manifest.childIDs.compactMap { childID in
            guard let childUUID = UUID(uuidString: childID), let child = lookup[childUUID] else { return nil as ExercisePage? }
            return buildBranch(root: child, lookup: lookup)
        }
        return ExercisePage(
            manifest: root.manifest,
            children: children,
            coverImageURL: root.coverImageURL,
            mediaURLs: root.mediaURLs,
            path: root.path,
            inheritedWorkoutType: root.inheritedWorkoutType
        )
    }

    static func breadcrumbs(for pageID: UUID, in flatList: [ExercisePage]) -> [ExercisePage] {
        var crumbs: [ExercisePage] = []
        var current = flatList.first { $0.id == pageID }
        let lookup = Dictionary(uniqueKeysWithValues: flatList.map { ($0.id, $0) })
        while let page = current {
            crumbs.insert(page, at: 0)
            if let parentIDStr = page.manifest.parentID, let parentUUID = UUID(uuidString: parentIDStr) {
                current = lookup[parentUUID]
            } else {
                current = nil
            }
        }
        return crumbs
    }
}
