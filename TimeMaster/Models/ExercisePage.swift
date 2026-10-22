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
    var pageType: PageType? { manifest.pageType }
    var isContainer: Bool { manifest.pageKind == .container }
    var isLeaf: Bool { manifest.pageKind == .leaf }
    var isRoot: Bool { manifest.parentID == nil }
    var isExercise: Bool { pageType == .exercise }
    var isSkill: Bool { pageType == .skill }
    var isTutorial: Bool { pageType == .tutorial }
    var isSkillLike: Bool { isSkill || isTutorial }
    var isContentPage: Bool { pageType != nil }
    var canContainChildren: Bool { isContainer }
    var isWorkoutAddable: Bool { isExercise || isSkillLike }
    var hasWorkoutConfig: Bool { isExercise && manifest.duration != nil }
    var hasCover: Bool { coverImageURL != nil }
    var hasLinks: Bool { !manifest.linkURLs.isEmpty }
    var hasMedia: Bool { !mediaURLs.isEmpty }
    var hasMarkdown: Bool { !manifest.markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var mediaCommentsByURL: [URL: String] {
        mediaURLs.reduce(into: [:]) { result, url in
            if let comment = manifest.mediaComments[url.lastPathComponent], !comment.isEmpty {
                result[url] = comment
            }
        }
    }
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

    init(from manifest: ExercisePageManifest, baseURL: URL, legacyMediaDirectory: URL, path: String = "") {
        self.manifest = manifest
        self.children = []
        self.path = path
        self.inheritedWorkoutType = nil

        let mediaDirectory = baseURL.appendingPathComponent("media", isDirectory: true)
        let fileManager = FileManager.default
        func resolveMedia(_ filename: String) -> URL {
            let local = mediaDirectory.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: local.path) {
                let legacy = legacyMediaDirectory.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: legacy.path) { return legacy }
            }
            return local
        }
        var resolvedMediaURLs: [URL] = []
        resolvedMediaURLs.reserveCapacity(manifest.mediaFilenames.count + (manifest.coverImageFilename == nil ? 0 : 1))

        if let legacyCover = manifest.coverImageFilename {
            let legacyURL = baseURL.appendingPathComponent(legacyCover)
            let mediaURL = resolveMedia(legacyCover)
            if manifest.mediaFilenames.first == legacyCover,
               fileManager.fileExists(atPath: mediaURL.path) {
                resolvedMediaURLs.append(mediaURL)
            } else if fileManager.fileExists(atPath: legacyURL.path) {
                resolvedMediaURLs.append(legacyURL)
            } else if !manifest.mediaFilenames.contains(legacyCover), fileManager.fileExists(atPath: mediaURL.path) {
                resolvedMediaURLs.append(mediaURL)
            }
        }

        for filename in manifest.mediaFilenames {
            let url = resolveMedia(filename)
            if !resolvedMediaURLs.contains(url) {
                resolvedMediaURLs.append(url)
            }
        }

        self.mediaURLs = resolvedMediaURLs
        self.coverImageURL = resolvedMediaURLs.first
    }
}
