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
    var hasCover: Bool { manifest.coverImageFilename != nil }
    var hasLinks: Bool { !manifest.linkURLs.isEmpty }
    var hasMedia: Bool { !manifest.mediaFilenames.isEmpty }
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

        if let coverFilename = manifest.coverImageFilename, manifest.pageKind == .container {
            self.coverImageURL = baseURL.appendingPathComponent(coverFilename)
        } else if manifest.pageKind == .leaf, let firstMedia = manifest.mediaFilenames.first {
            self.coverImageURL = baseURL
                .appendingPathComponent("media", isDirectory: true)
                .appendingPathComponent(firstMedia)
        } else {
            self.coverImageURL = nil
        }

        self.mediaURLs = manifest.mediaFilenames.map { filename in
            baseURL.appendingPathComponent("media", isDirectory: true).appendingPathComponent(filename)
        }
    }
}
