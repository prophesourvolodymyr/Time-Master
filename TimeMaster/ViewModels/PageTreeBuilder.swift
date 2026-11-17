import Foundation
import TimeMasterCore

/// The page tree of the library: top-level pages and each page's children in their stored order (`PageOrder`; the
/// library walk already lists every page's `childIDs` that way).
enum PageTreeBuilder {
    static func build(from flatList: [ExercisePage]) -> [ExercisePage] {
        let lookup = Dictionary(flatList.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let roots = flatList
            .filter { $0.manifest.parentID == nil }
            .sorted { PageOrder.precedes($0.manifest, $1.manifest) }
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
}
