import Foundation
import TimeMasterCore

struct NoteIcon: Equatable {
    var name: String?
    var type: SkillBoardIconType?
}

extension DatabaseStore {
    @discardableResult
    func createNote(title: String, parentID: String? = nil) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let manifest = ExercisePageManifest(title: clean.isEmpty ? "Untitled" : clean, pageType: .note, parentID: parentID)
        try createPage(manifest: manifest, parentID: parentID)
        return manifest.id
    }

    func saveNote(id: String, title: String, body: String, icon: NoteIcon? = nil, token: ExerciseLibraryAccess.Token) throws {
        let changed = try ExerciseLibraryAccess.shared.perform(token: token) { () -> Bool in
            let database = DatabaseManager.shared
            var manifest = try database.getPage(id: id)
            guard manifest.pageType == .note else { return false }
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            var updated = manifest
            if !clean.isEmpty { updated.title = clean }
            updated.markdownBody = body
            if let icon {
                updated.iconName = icon.name
                updated.iconType = icon.type
            }
            guard updated.title != manifest.title
                    || updated.markdownBody != manifest.markdownBody
                    || updated.iconName != manifest.iconName
                    || updated.iconType != manifest.iconType else { return false }
            manifest = updated
            try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
            return true
        }
        if changed { reload() }
    }

    func noteAssets(for page: ExercisePage) -> MarkdownAssets {
        FolderMarkdownAssets(folder: folderURL(for: page))
    }

    func copyNoteAttachments(from source: ExercisePage, to newID: String) {
        let from = folderURL(for: source).appendingPathComponent(DatabaseManager.noteAttachmentsFolderName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: from.path),
              let target = try? DatabaseManager.shared.noteAttachmentsURL(pageID: newID) else { return }
        try? FileManager.default.copyItem(at: from, to: target)
    }
}
