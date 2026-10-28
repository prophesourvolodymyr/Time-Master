import Foundation

struct AgentPageIndex {
    let byID: [String: ExercisePageManifest]
    private let foldedIDs: [String: String]
    private let childrenByParent: [String: [ExercisePageManifest]]
    private let rootPages: [ExercisePageManifest]
    private(set) var pathByID: [String: String] = [:]
    private(set) var duplicatePaths: Set<String> = []

    init(database: DatabaseManager) throws {
        let walked = try database.walkPageTree(in: database.exercisesDatabaseURL)
        var pages: [String: ExercisePageManifest] = [:]
        for (page, _) in walked { pages[page.id] = page }
        byID = pages
        foldedIDs = Dictionary(pages.keys.map { ($0.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var children: [String: [ExercisePageManifest]] = [:]
        var roots: [ExercisePageManifest] = []
        for page in pages.values {
            if let parent = page.parentID, pages[parent] != nil { children[parent, default: []].append(page) }
            else { roots.append(page) }
        }
        let ordered: (ExercisePageManifest, ExercisePageManifest) -> Bool = {
            $0.order != $1.order ? $0.order < $1.order : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        childrenByParent = children.mapValues { $0.sorted(by: ordered) }
        rootPages = roots.sorted(by: ordered)
        var paths: [String: String] = [:]
        for page in pages.values {
            var names: [String] = []
            var current: ExercisePageManifest? = page
            var guardCount = 0
            while let node = current, guardCount < 64 {
                names.insert(node.title, at: 0)
                current = node.parentID.flatMap { pages[$0] }
                guardCount += 1
            }
            paths[page.id] = names.joined(separator: "/")
        }
        pathByID = paths
        var seen = Set<String>()
        var repeated = Set<String>()
        for path in paths.values where !seen.insert(path).inserted { repeated.insert(path) }
        duplicatePaths = repeated
    }

    var count: Int { byID.count }
    var pages: [ExercisePageManifest] { Array(byID.values) }

    func children(of id: String?) -> [ExercisePageManifest] {
        guard let id else { return rootPages }
        return childrenByParent[id] ?? []
    }

    func descendants(of id: String) -> [ExercisePageManifest] {
        var out: [ExercisePageManifest] = []
        var queue = children(of: id)
        while !queue.isEmpty {
            let next = queue.removeFirst()
            out.append(next)
            queue.append(contentsOf: children(of: next.id))
        }
        return out
    }

    func titlePath(_ id: String) -> String { pathByID[id] ?? "" }

    func effectiveType(_ id: String) -> WorkoutType? {
        var current = byID[id]
        var guardCount = 0
        while let page = current, guardCount < 64 {
            if let type = page.workoutType { return type }
            current = page.parentID.flatMap { byID[$0] }
            guardCount += 1
        }
        return nil
    }

    func kind(_ page: ExercisePageManifest) -> String {
        switch page.pageType {
        case .exercise: "exercise"
        case .skill: "skill"
        case .tutorial: "tutorial"
        case nil: "container"
        }
    }

    func summary(_ page: ExercisePageManifest, withID: Bool = false) -> [String: Any] {
        let path = titlePath(page.id)
        var out: [String: Any] = ["path": path]
        if withID || duplicatePaths.contains(path) { out["id"] = page.id }
        switch page.pageType {
        case .exercise: break
        case .skill: out["kind"] = "skill"
        case .tutorial: out["kind"] = "tutorial"
        case nil: out["folder"] = true
        }
        if page.pageType != nil, let duration = page.duration { out["duration"] = duration }
        if let sets = page.sets, sets > 1 { out["sets"] = sets }
        if !page.mediaFilenames.isEmpty { out["media"] = page.mediaFilenames.count }
        if page.parentID.flatMap({ byID[$0] }) == nil, let type = effectiveType(page.id) { out["type"] = type.name }
        if page.pageType == nil {
            let inside = children(of: page.id).count
            if inside > 0 { out["children"] = inside }
        }
        return out
    }

    func resolve(_ reference: String) throws -> ExercisePageManifest {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentToolError("invalid_argument", "A page reference must not be empty.") }
        if let page = byID[text] ?? foldedIDs[text.uppercased()].flatMap({ byID[$0] }) { return page }
        let wanted = AgentValue.fold(text)
        var matches = byID.values.filter { AgentValue.fold(titlePath($0.id)) == wanted }
        if matches.isEmpty { matches = byID.values.filter { AgentValue.fold($0.title) == wanted } }
        if matches.isEmpty, text.contains("/") {
            matches = byID.values.filter { AgentValue.fold(titlePath($0.id)).hasSuffix("/" + wanted) }
        }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            let leaf = wanted.split(separator: "/").last.map(String.init) ?? wanted
            let scored = byID.values.compactMap { page -> (Int, String, ExercisePageManifest)? in
                let title = AgentValue.fold(page.title)
                if !leaf.isEmpty, title.contains(leaf) || leaf.contains(title) { return (0, titlePath(page.id), page) }
                let distance = Self.distance(title, leaf)
                return distance <= max(2, leaf.count / 3) ? (distance, titlePath(page.id), page) : nil
            }
            let near = scored.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(5).map { "\($0.1) (\($0.2.id))" }
            throw AgentToolError("not_found", "No page matches '\(text)'.", hint: near.isEmpty ? "Use list_pages or search_pages to find its id." : "Did you mean: \(near.joined(separator: "; "))?")
        }
        let candidates = matches.sorted { titlePath($0.id) < titlePath($1.id) }.prefix(6).map { "\(titlePath($0.id)) (\($0.id))" }
        throw AgentToolError("ambiguous", "'\(text)' matches \(matches.count) pages.", hint: "Use the id: \(candidates.joined(separator: "; ")).")
    }

    private static func distance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}

enum AgentMedia {
    static let images: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"]
    static let videos: Set<String> = ["mp4", "mov", "m4v"]
    private static let datalessFlag: UInt32 = 0x4000_0000
    private static let maximumBytes: Int64 = 4 * 1024 * 1024 * 1024

    static func kind(ofFilename name: String) -> String {
        videos.contains((name as NSString).pathExtension.lowercased()) ? "video" : "image"
    }

    static func validate(path raw: String) throws -> URL {
        let expanded = (raw.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            throw AgentToolError("invalid_path", "Media paths must be absolute.", hint: "Pass the full path, for example /Users/me/Movies/clip.mp4.")
        }
        var url = URL(fileURLWithPath: expanded)
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            throw AgentToolError("file_not_found", "No file at \(url.path).")
        }
        if info.st_mode & S_IFMT == S_IFLNK {
            url = url.resolvingSymlinksInPath()
            guard lstat(url.path, &info) == 0 else { throw AgentToolError("file_not_found", "The link at \(expanded) points nowhere.") }
        }
        guard info.st_mode & S_IFMT == S_IFREG else {
            throw AgentToolError("invalid_path", "\(url.lastPathComponent) is not a regular file.")
        }
        guard info.st_flags & datalessFlag == 0 else {
            throw AgentToolError("file_not_downloaded", "\(url.lastPathComponent) is stored only in iCloud.", hint: "Download it in Finder first, then retry.")
        }
        guard info.st_size > 0, Int64(info.st_size) <= maximumBytes else {
            throw AgentToolError("invalid_path", "\(url.lastPathComponent) is empty or larger than 4 GB.")
        }
        let ext = url.pathExtension.lowercased()
        guard images.contains(ext) || videos.contains(ext) else {
            throw AgentToolError("unsupported_media", "'.\(ext)' files cannot be attached.", hint: "Use jpg, png, heic, gif, webp, mp4, mov or m4v. Convert other video with ffmpeg first.")
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw AgentToolError("invalid_path", "\(url.lastPathComponent) is not readable.")
        }
        return url
    }
}
