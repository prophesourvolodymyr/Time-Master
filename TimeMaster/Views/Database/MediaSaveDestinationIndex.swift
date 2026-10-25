import Foundation

struct MediaSaveDestinationIndex {
    struct Entry: Identifiable {
        let id: String
        let title: String
        let path: String
        let isContainer: Bool
        fileprivate let searchText: String
        fileprivate let titleSearchText: String
    }

    let entries: [Entry]
    private let pathsByID: [String: String]

    init(pages: [ExercisePage] = []) {
        let lookup = Dictionary(pages.map { ($0.manifest.id, $0) }, uniquingKeysWith: { first, _ in first })
        var paths: [String: String] = [:]
        for page in pages {
            var branch: [ExercisePage] = []
            var visited: Set<String> = []
            var current: ExercisePage? = page
            var parentPath = ""
            while let node = current, visited.insert(node.manifest.id).inserted {
                if let existing = paths[node.manifest.id] {
                    parentPath = existing
                    break
                }
                branch.append(node)
                current = node.manifest.parentID.flatMap { lookup[$0] }
            }
            for node in branch.reversed() {
                parentPath = parentPath.isEmpty ? node.title : parentPath + " › " + node.title
                paths[node.manifest.id] = parentPath
            }
        }
        pathsByID = paths
        entries = pages.map { page in
            let path = paths[page.manifest.id] ?? page.title
            return Entry(id: page.manifest.id, title: page.title, path: path, isContainer: page.isContainer, searchText: Self.searchable(path), titleSearchText: Self.searchable(page.title))
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    func path(for pageID: String) -> String? { pathsByID[pageID] }

    func results(query: String, containers: Bool) -> [Entry] {
        let search = Self.searchable(query)
        let terms = search.split(whereSeparator: \.isWhitespace)
        let matches = entries.filter { entry in
            entry.isContainer == containers && terms.allSatisfy { entry.searchText.contains($0) }
        }
        guard !search.isEmpty else { return matches }
        return matches.sorted { lhs, rhs in
            let leftPriority = lhs.titleSearchText.hasPrefix(search)
            let rightPriority = rhs.titleSearchText.hasPrefix(search)
            if leftPriority != rightPriority { return leftPriority }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private static func searchable(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "›", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ">", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
