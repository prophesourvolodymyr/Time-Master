import SwiftUI
import TimeMasterCore

/// One tile of the strip and what it has to say, read from the stores while the strip draws.
enum PageWidgetItem: Identifiable {
    case clips(PageWidgetClips)
    case folder(PageWidgetFolder)
    case progress(SkillProgress, target: PageWidgetTarget)
    case todos(PageWidgetTodos)
    case milestones(pageID: String, list: [Milestone])
    case learnFirst(PageWidgetLearnFirst)
    case workouts(PageWorkoutUsage)

    var kind: PageWidgetKind {
        switch self {
        case .clips: .clips
        case .folder: .folder
        case .progress: .progress
        case .todos: .todos
        case .milestones: .milestones
        case .learnFirst: .learnFirst
        case .workouts: .workouts
        }
    }

    var id: PageWidgetKind { kind }

    /// The tile has something to say. Automatic leaves out the tiles that would only invite a first item.
    var hasContent: Bool {
        switch self {
        case .clips(let clips): return clips.total > 0
        case .folder(let folder): return folder.pageCount > 0
        case .progress(let progress, _): return progress.total + progress.abandoned > 0
        case .todos(let todos): return todos.openCount > 0
        case .milestones(_, let list): return list.progressTotal > 0
        case .learnFirst(let learnFirst): return learnFirst.total > 0
        case .workouts(let usage): return !usage.isEmpty
        }
    }

    /// The tiles of `page`, in strip order, as its `widgets` setting asks. Left to itself a page shows the tiles that
    /// have something to say: an exercise its clips and the workouts that train it; a skill or a tutorial its clips, its
    /// progress, open to-dos and milestones, what to learn first and the workouts that train it; a folder its clips,
    /// what it holds, the progress of the skills in it and the workouts that use its pages; a note none. A chosen list
    /// shows exactly its tiles, an empty one inviting its first item. A page that needs no skills (`noSkills`) never
    /// shows the tiles about sub-skills.
    @MainActor
    static func items(for page: ExercisePage, store: DatabaseStore, workoutStore: WorkoutStore) -> [PageWidgetItem] {
        items(for: page, selection: page.manifest.widgetSelection, noSkills: page.manifest.hidesSkills, store: store, workoutStore: workoutStore)
    }

    /// The tiles `page` shows with `selection` and `noSkills` in place of its own settings (the edit form asks what
    /// Automatic shows, to start a chosen list from it). Each tile reads the stores once, and only when asked for.
    @MainActor
    static func items(
        for page: ExercisePage,
        selection: PageWidgetSelection,
        noSkills: Bool,
        store: DatabaseStore,
        workoutStore: WorkoutStore
    ) -> [PageWidgetItem] {
        let library = store.skillLibrary
        var made: [PageWidgetKind: PageWidgetItem?] = [:]
        func tile(_ kind: PageWidgetKind) -> PageWidgetItem? {
            if let known = made[kind] { return known }
            let built = make(kind, of: page, library: library, store: store, workoutStore: workoutStore)
            made[kind] = built
            return built
        }
        return selection
            .resolved(for: page.pageType, noSkills: noSkills) { tile($0)?.hasContent == true }
            .compactMap(tile)
    }

    @MainActor
    private static func make(
        _ kind: PageWidgetKind,
        of page: ExercisePage,
        library: SkillLibrary,
        store: DatabaseStore,
        workoutStore: WorkoutStore
    ) -> PageWidgetItem? {
        switch kind {
        case .clips: return .clips(PageWidgetClips(page: page))
        case .folder: return .folder(PageWidgetFolder(page: page, library: library))
        case .progress: return .progress(library.progress(of: page), target: page.isSkillLike ? .subSkills : .children)
        case .todos: return .todos(PageWidgetTodos(page: page, library: library))
        case .milestones: return .milestones(pageID: page.manifest.id, list: page.manifest.milestones)
        case .learnFirst: return PageWidgetLearnFirst(page: page, store: store).map(PageWidgetItem.learnFirst)
        case .workouts: return .workouts(PageWorkoutUsage.of(page, library: library, workoutStore: workoutStore))
        }
    }
}

/// Sorts a page file into what the Clips widget counts and how it draws it.
enum PageWidgetMedia {
    enum Kind {
        case video, photo, file
    }

    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv"]

    static func kind(of url: URL) -> Kind {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext) { return .video }
        if ChecklistMedia.pictureExtensions.contains(ext) { return .photo }
        return .file
    }
}

/// What a page's files add up to, and the one the Clips widget shows: the cover the page chose, else its first file.
struct PageWidgetClips {
    let cover: URL?
    /// Where the cover sits in `ExercisePage.mediaURLs`.
    let coverIndex: Int?
    let videos: Int
    let photos: Int
    let files: Int

    var total: Int { videos + photos + files }

    /// "3 videos · 9 photos · 2 files", leaving out what there is none of.
    var breakdown: String {
        [(videos, "video", "videos"), (photos, "photo", "photos"), (files, "file", "files")]
            .filter { $0.0 > 0 }
            .map { SkillCopy.count($0.0, $0.1, $0.2) }
            .joined(separator: " · ")
    }

    init(page: ExercisePage) {
        var videos = 0
        var photos = 0
        var files = 0
        for url in page.mediaURLs {
            switch PageWidgetMedia.kind(of: url) {
            case .video: videos += 1
            case .photo: photos += 1
            case .file: files += 1
            }
        }
        self.videos = videos
        self.photos = photos
        self.files = files
        cover = page.coverImageURL
        coverIndex = page.coverImageURL.flatMap { page.mediaURLs.firstIndex(of: $0) }
    }
}

/// An open to-do as the To-do widget lists it.
struct PageWidgetTodoRow: Identifiable, Equatable {
    let id: String
    /// The page that keeps it: the skill itself or one of its sub-skills.
    let pageID: String
    let title: String
    /// It sits under another to-do.
    let isNested: Bool
    /// The sub-skill it belongs to; nil for the page's own.
    let pageTitle: String?
}

/// The open to-dos of a skill or a tutorial and of the sub-skills below it: the skill's first, then each sub-skill's in
/// tree order (`SkillLibrary.subSkills(below:)`), each list in its own order. Sections never count.
struct PageWidgetTodos {
    /// Most to-dos the widget carries (`openCount` still has them all).
    static let rowLimit = 12

    let rows: [PageWidgetTodoRow]
    let openCount: Int
    /// Every to-do, done or not.
    let total: Int

    init(page: ExercisePage, library: SkillLibrary) {
        var rows: [PageWidgetTodoRow] = []
        var open = 0
        var total = 0
        for owner in [page] + library.subSkills(below: page) {
            for entry in owner.manifest.todos.flattened() where !entry.item.isSection {
                total += 1
                guard !entry.item.isDone else { continue }
                open += 1
                guard rows.count < Self.rowLimit else { continue }
                rows.append(PageWidgetTodoRow(
                    id: entry.item.id,
                    pageID: owner.manifest.id,
                    title: entry.item.title,
                    isNested: entry.depth > 1,
                    pageTitle: owner.manifest.id == page.manifest.id ? nil : owner.title
                ))
            }
        }
        self.rows = rows
        openCount = open
        self.total = total
    }
}

/// What a skill or a tutorial waits for: its pages and groups to learn first (how many are learned, and the next one),
/// and the files and links to have first. A page there that needs no skills cannot be learned from its own page, so it
/// is no step (`SkillMaterial.isLearnable`).
struct PageWidgetLearnFirst {
    /// The title of the first page or group not learned yet (and not set aside), in the order to learn them.
    let next: String?
    let steps: Int
    /// Pages completed, and groups whose skills are all completed.
    let stepsDone: Int
    let files: Int
    let links: Int

    var total: Int { steps + files + links }

    /// "2 files · 1 link", leaving out what there is none of.
    var materials: String {
        [(files, "file", "files"), (links, "link", "links")]
            .filter { $0.0 > 0 }
            .map { SkillCopy.count($0.0, $0.1, $0.2) }
            .joined(separator: " · ")
    }

    /// Nil for a page that is no skill or tutorial; one that waits for nothing has a `total` of 0.
    @MainActor
    init?(page: ExercisePage, store: DatabaseStore) {
        let id = page.manifest.id
        guard page.isSkillLike, let material = store.skillMaterial(id: id) else { return nil }
        let dependencies = store.skillDependencies(of: id).filter(\.isLearnable)
        var next: String?
        var done = 0
        for dependency in dependencies {
            let status: SkillStatus
            if dependency.isGroup {
                let progress = store.skillProgress(of: dependency.id)
                status = progress.total > 0 && progress.completed == progress.total ? .completed : .notStarted
            } else {
                status = dependency.manifest.skillStatus ?? .notStarted
            }
            if status == .completed {
                done += 1
            } else if next == nil, status != .abandoned {
                next = dependency.title
            }
        }
        self.next = next
        steps = dependencies.count
        stepsDone = done
        files = material.dependencyMediaURLs.count
        links = material.dependencyLinkURLs.count
    }
}

/// What a folder holds, counted all the way down: exercises, skills and tutorials, notes, folders, and clips (every
/// file of every page in it, its own included), with the covers of its pages that have a picture, its own pages first.
struct PageWidgetFolder {
    static let coverLimit = 3

    let exercises: Int
    let skills: Int
    let notes: Int
    let folders: Int
    let clips: Int
    let covers: [URL]

    var pageCount: Int { exercises + skills + notes + folders }

    /// "2 folders · 1 note", or nil when it holds neither.
    var extras: String? {
        let parts = [(folders, "folder", "folders"), (notes, "note", "notes")]
            .filter { $0.0 > 0 }
            .map { SkillCopy.count($0.0, $0.1, $0.2) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    init(page: ExercisePage, library: SkillLibrary) {
        var exercises = 0
        var skills = 0
        var notes = 0
        var folders = 0
        var clips = page.mediaURLs.count
        let below = library.pages(below: page)
        for item in below {
            switch item.pageType {
            case .exercise?: exercises += 1
            case .skill?, .tutorial?:
                if item.manifest.hidesSkills { exercises += 1 } else { skills += 1 }
            case .note?: notes += 1
            case nil: folders += 1
            }
            clips += item.mediaURLs.count
        }
        let own = Set(page.manifest.childIDs)
        let nearestFirst = below.filter { own.contains($0.manifest.id) } + below.filter { !own.contains($0.manifest.id) }
        let covers = nearestFirst.lazy
            .compactMap(\.coverImageURL)
            .filter { PageWidgetMedia.kind(of: $0) != .file }
            .prefix(Self.coverLimit)
        self.exercises = exercises
        self.skills = skills
        self.notes = notes
        self.folders = folders
        self.clips = clips
        self.covers = Array(covers)
    }
}
