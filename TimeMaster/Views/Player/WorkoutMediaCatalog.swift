import SwiftUI
import TimeMasterCore

struct WorkoutMediaEntry: Identifiable, Equatable {
    enum Owner: Equatable {
        case page(UUID)
        case workout
    }

    let url: URL
    let owner: Owner

    var id: URL { url }
    var isVideo: Bool { PageMediaKind.isVideo(url) }
}

struct WorkoutMediaCatalog {
    let entries: [WorkoutMediaEntry]
    let comments: [URL: String]

    var urls: [URL] { entries.map(\.url) }

    @MainActor
    init(
        pageIDs: [UUID],
        sections: [Section],
        databaseStore: DatabaseStore,
        notes: MediaNotesStore,
        sectionMediaFirst: Bool = false
    ) {
        var pageEntries: [WorkoutMediaEntry] = []
        var sectionEntries: [WorkoutMediaEntry] = []
        var comments: [URL: String] = [:]
        var seen: Set<URL> = []
        func collectSections() {
            for section in sections {
                for item in section.mediaItems {
                    let url = item.type == .video
                        ? PhotoManager.shared.videoURL(for: item.filename)
                        : PhotoManager.shared.photoURL(for: item.filename)
                    guard seen.insert(url).inserted else { continue }
                    sectionEntries.append(WorkoutMediaEntry(url: url, owner: .workout))
                    if let note = notes.note(for: url) { comments[url] = note }
                }
            }
        }
        func collectPages() {
            for id in pageIDs {
                guard let page = databaseStore.page(id: id) else { continue }
                for url in page.mediaURLs where seen.insert(url).inserted {
                    pageEntries.append(WorkoutMediaEntry(url: url, owner: .page(id)))
                }
                for (url, comment) in page.mediaCommentsByURL { comments[url] = comment }
            }
        }
        if sectionMediaFirst {
            collectSections()
            collectPages()
            entries = sectionEntries + pageEntries
        } else {
            collectPages()
            collectSections()
            entries = pageEntries + sectionEntries
        }
        self.comments = comments
    }

    func entry(for url: URL) -> WorkoutMediaEntry? {
        entries.first { $0.url == url }
    }

    func pageID(for url: URL) -> UUID? {
        if case .page(let id) = entry(for: url)?.owner { return id }
        return nil
    }

    var firstPageID: UUID? {
        for entry in entries {
            if case .page(let id) = entry.owner { return id }
        }
        return nil
    }

    @MainActor
    func assets(for url: URL, databaseStore: DatabaseStore, notes: MediaNotesStore) -> MarkdownAssets? {
        switch entry(for: url)?.owner {
        case .page(let id):
            guard let page = databaseStore.page(id: id) else { return nil }
            return FolderMarkdownAssets(folder: databaseStore.folderURL(for: page))
        case .workout:
            return notes.assets
        case nil:
            return nil
        }
    }

    @MainActor
    func save(_ text: String, for url: URL, databaseStore: DatabaseStore, notes: MediaNotesStore) throws {
        switch entry(for: url)?.owner {
        case .page(let id):
            guard let page = databaseStore.page(id: id) else { throw FileSystemHelper.Error.notFound(url.lastPathComponent) }
            try databaseStore.updateMediaComment(pageID: page.manifest.id, filename: url.lastPathComponent, comment: text)
        case .workout:
            try notes.set(text, for: url)
        case nil:
            break
        }
    }

    static func pageIDs(in workout: Workout) -> [UUID] {
        var result: [UUID] = []
        var seen: Set<UUID> = []
        func append(_ id: UUID?) {
            if let id, seen.insert(id).inserted { result.append(id) }
        }
        func appendSlot(_ slot: SetSlot) {
            append(slot.exercisePageID)
            append(slot.restExercisePageID)
            for drop in slot.drops { append(drop.exercisePageID) }
            for content in slot.restRow?.contents ?? [] { append(content.pageID) }
            for child in slot.children { appendSlot(child) }
        }
        for section in workout.sections {
            append(section.pageID)
            for slot in section.effectiveSlots { appendSlot(slot) }
            for content in section.bigRestRow?.contents ?? [] { append(content.pageID) }
        }
        return result
    }
}

struct WorkoutMediaEnvironment {
    let workout: Workout
    let liveContext: WorkoutLiveContext?
}

private struct WorkoutMediaEnvironmentKey: EnvironmentKey {
    static let defaultValue: WorkoutMediaEnvironment? = nil
}

extension EnvironmentValues {
    var workoutMedia: WorkoutMediaEnvironment? {
        get { self[WorkoutMediaEnvironmentKey.self] }
        set { self[WorkoutMediaEnvironmentKey.self] = newValue }
    }
}
