import Foundation
import TimeMasterCore

struct ExercisePage: Identifiable {
    let manifest: ExercisePageManifest
    let children: [ExercisePage]
    let coverImageURL: URL?
    let mediaURLs: [URL]
    let path: String
    let inheritedWorkoutType: TimeMasterCore.WorkoutType?

    var id: UUID { UUID(uuidString: manifest.id) ?? UUID() }
    var title: String { manifest.title }
    var isContainer: Bool { manifest.pageKind == .container }
    var isLeaf: Bool { manifest.pageKind == .leaf }
    var isRoot: Bool { manifest.parentID == nil }
    var hasWorkoutConfig: Bool { isLeaf && manifest.duration != nil }
    var hasCover: Bool { coverImageURL != nil }
    var hasLinks: Bool { !manifest.linkURLs.isEmpty }
    var hasMedia: Bool { !mediaURLs.isEmpty }
    var hasMarkdown: Bool { !manifest.markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var effectiveWorkoutType: TimeMasterCore.WorkoutType? { manifest.workoutType ?? inheritedWorkoutType }
    var totalChildCount: Int { children.count + children.reduce(0) { $0 + $1.totalChildCount } }

    init(
        manifest: ExercisePageManifest,
        children: [ExercisePage] = [],
        coverImageURL: URL? = nil,
        mediaURLs: [URL] = [],
        path: String = "",
        inheritedWorkoutType: TimeMasterCore.WorkoutType? = nil
    ) {
        self.manifest = manifest
        self.children = children
        self.coverImageURL = coverImageURL
        self.mediaURLs = mediaURLs
        self.path = path
        self.inheritedWorkoutType = inheritedWorkoutType
    }

    init(from manifest: ExercisePageManifest, baseURL: URL, path: String = "") {
        self.manifest = manifest
        self.children = []
        self.path = path
        self.inheritedWorkoutType = nil

        let mediaDirectory = baseURL.appendingPathComponent("media", isDirectory: true)
        var resolvedMediaURLs: [URL] = []

        if let legacyCover = manifest.coverImageFilename {
            let legacyURL = baseURL.appendingPathComponent(legacyCover)
            let mediaURL = mediaDirectory.appendingPathComponent(legacyCover)
            if manifest.mediaFilenames.first == legacyCover,
               FileManager.default.fileExists(atPath: mediaURL.path) {
                resolvedMediaURLs.append(mediaURL)
            } else if FileManager.default.fileExists(atPath: legacyURL.path) {
                resolvedMediaURLs.append(legacyURL)
            }
        }

        for filename in manifest.mediaFilenames {
            let url = mediaDirectory.appendingPathComponent(filename)
            if !resolvedMediaURLs.contains(url) {
                resolvedMediaURLs.append(url)
            }
        }

        self.mediaURLs = resolvedMediaURLs
        self.coverImageURL = resolvedMediaURLs.first
    }
}
