import Foundation
import TimeMasterCore

/// What a link on a to-do or a milestone points at, as the app finds it now.
enum ChecklistLinkTarget {
    case workout(Workout)
    case page(SkillMaterial)
    /// A file of the entry's page, with its local address.
    case media(filename: String, url: URL)
    case web(URL)
    case missingWorkout
    case missingPage
    case missingMedia(String)
    /// Text that is no link (an older or a hand-written entry).
    case unreadable(String)

    var isMissing: Bool {
        switch self {
        case .missingWorkout, .missingPage, .missingMedia, .unreadable: return true
        default: return false
        }
    }
}

extension DatabaseStore {
    // MARK: - Reading

    /// A page's to-dos (`TodoItem.self`) or milestones (`Milestone.self`) as of the last refresh.
    func checklist<Entry: ChecklistEntry>(_ type: Entry.Type, of pageID: String) -> [Entry] {
        page(manifestID: pageID)?.manifest[keyPath: Entry.pageList] ?? []
    }

    /// The local picture of one of a page's media files; nil when the page does not hold it.
    func checklistPictureURL(_ filename: String?, on pageID: String) -> URL? {
        guard let filename else { return nil }
        return page(manifestID: pageID)?.mediaURL(for: filename)
    }

    /// The picture icon of an entry: one of the page's pictures or a web image.
    func checklistIconURL<Entry: ChecklistEntry>(_ entry: Entry, on pageID: String) -> URL? {
        guard let reference = entry.iconImage else { return nil }
        if let local = checklistPictureURL(reference, on: pageID) { return local }
        guard let url = URL(string: reference), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    /// What `link` points at, found among the workouts and the pages the stores hold now.
    func checklistTarget(of link: TodoLink, on pageID: String, workouts: [Workout]) -> ChecklistLinkTarget {
        guard let target = link.target else { return .unreadable(link.url) }
        return checklistTarget(of: target, on: pageID, workouts: workouts)
    }

    func checklistTarget(of target: TmaxLink, on pageID: String, workouts: [Workout]) -> ChecklistLinkTarget {
        switch target {
        case .workout(let id):
            guard let uuid = UUID(uuidString: id), let workout = workouts.first(where: { $0.id == uuid }) else { return .missingWorkout }
            return .workout(workout)
        case .page(let id):
            guard let material = skillMaterial(id: id) else { return .missingPage }
            return .page(material)
        case .media(let filename):
            guard let url = checklistPictureURL(filename, on: pageID) else { return .missingMedia(filename) }
            return .media(filename: filename, url: url)
        case .web(let text):
            guard let url = URL(string: text) else { return .unreadable(text) }
            return .web(url)
        case .start:
            return .unreadable(target.urlString)
        }
    }

    // MARK: - Writing

    /// Runs a change of a page's lists behind the account guard, shows the saved page at once and then reloads the
    /// library, so a check or a new line appears without waiting for the reload.
    @discardableResult
    func checklistWrite<T>(_ pageID: String, _ body: (DatabaseManager) throws -> T) throws -> T {
        let token = ExerciseLibraryAccess.shared.capture()
        let result = try ExerciseLibraryAccess.shared.perform(token: token) {
            try body(DatabaseManager.shared)
        }
        publishChecklistPage(pageID)
        reload()
        return result
    }

    @discardableResult
    func addChecklistEntry<Entry: ChecklistEntry>(_ entry: Entry, to pageID: String, under parentID: String? = nil, at index: Int? = nil) throws -> Entry {
        try checklistWrite(pageID) { try $0.addChecklistEntry(entry, to: pageID, under: parentID, at: index) }
    }

    /// Adds an entry right after the sibling `afterID` (the end of its level without one).
    @discardableResult
    func addChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, title: String, to pageID: String, under parentID: String?, after afterID: String?) throws -> Entry {
        var index: Int?
        if let afterID {
            let list = checklist(Entry.self, of: pageID)
            let siblings = parentID.flatMap { list.entry($0)?.children } ?? list
            index = siblings.firstIndex { $0.id == afterID }.map { $0 + 1 }
        }
        return try addChecklistEntry(Entry.blank(id: Entry.newID(), title: title), to: pageID, under: parentID, at: index)
    }

    @discardableResult
    func addChecklistSection<Entry: ChecklistEntry>(_ type: Entry.Type, title: String, to pageID: String, at index: Int? = nil) throws -> Entry {
        try checklistWrite(pageID) { try $0.addChecklistSection(Entry.self, title: title, to: pageID, at: index) }
    }

    @discardableResult
    func updateChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String, _ change: (inout Entry) throws -> Void) throws -> Entry {
        try checklistWrite(pageID) { try $0.updateChecklistEntry(Entry.self, entryID, in: pageID, change) }
    }

    func setChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, done: Bool, in pageID: String) throws {
        try checklistWrite(pageID) { _ = try $0.setChecklistEntry(Entry.self, entryID, done: done, in: pageID) }
    }

    func moveChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String, toParent parentID: String?, at index: Int?) throws {
        try checklistWrite(pageID) { _ = try $0.moveChecklistEntry(Entry.self, entryID, in: pageID, toParent: parentID, at: index) }
    }

    func moveChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String, toSection sectionID: String?) throws {
        try checklistWrite(pageID) { _ = try $0.moveChecklistEntry(Entry.self, entryID, in: pageID, toSection: sectionID) }
    }

    /// Moves an entry one place earlier (`step` -1) or later (+1) on its level; false at either end.
    @discardableResult
    func stepChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, by step: Int, in pageID: String) throws -> Bool {
        let list = checklist(Entry.self, of: pageID)
        let siblings = list.siblings(of: entryID)
        guard let position = siblings.firstIndex(where: { $0.id == entryID }), siblings.indices.contains(position + step) else { return false }
        try moveChecklistEntry(Entry.self, entryID, in: pageID, toParent: list.parentID(of: entryID), at: position + step)
        return true
    }

    @discardableResult
    func indentChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String) throws -> Bool {
        try checklistWrite(pageID) { try $0.indentChecklistEntry(Entry.self, entryID, in: pageID) }
    }

    @discardableResult
    func outdentChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, in pageID: String) throws -> Bool {
        try checklistWrite(pageID) { try $0.outdentChecklistEntry(Entry.self, entryID, in: pageID) }
    }

    func removeChecklistEntry<Entry: ChecklistEntry>(_ type: Entry.Type, _ entryID: String, from pageID: String) throws {
        try checklistWrite(pageID) { _ = try $0.removeChecklistEntry(Entry.self, entryID, from: pageID) }
    }

    /// Copies a picture (or any file for `.attachment`) into the page and gives it to the entry in one step.
    @discardableResult
    func attachChecklistFile<Entry: ChecklistEntry>(_ type: Entry.Type, from sourceURL: URL, to entryID: String, in pageID: String, as role: ChecklistPictureRole) throws -> String {
        try checklistWrite(pageID) { try $0.attachChecklistPicture(Entry.self, from: sourceURL, to: entryID, in: pageID, as: role) }
    }

    /// Copies a picture into the page without giving it to an entry yet (the editor sheet saves it with the rest).
    @discardableResult
    func uploadChecklistPicture(_ sourceURL: URL, to pageID: String) throws -> String {
        try checklistWrite(pageID) { try $0.uploadMediaToPage(pageID: pageID, sourceURL: sourceURL) }
    }

    // MARK: - Publishing

    /// Puts the saved manifest of `pageID` in place right away, with its media addresses.
    private func publishChecklistPage(_ pageID: String) {
        guard let manifest = try? DatabaseManager.shared.getPage(id: pageID),
              let index = allPagesFlat.firstIndex(where: { $0.manifest.id == pageID }) else { return }
        let current = allPagesFlat[index]
        var merged = manifest
        merged.childIDs = current.manifest.childIDs
        let refreshed = ExercisePage(
            from: merged,
            baseURL: folderURL(for: current),
            legacyMediaDirectory: DatabaseManager.shared.dataRoot.appendingPathComponent("Media", isDirectory: true),
            path: current.path
        )
        allPagesFlat[index] = ExercisePage(
            manifest: refreshed.manifest,
            coverImageURL: refreshed.coverImageURL,
            mediaURLs: refreshed.mediaURLs,
            path: current.path,
            inheritedWorkoutType: current.inheritedWorkoutType
        )
        rootPages = PageTreeBuilder.build(from: allPagesFlat)
    }
}
