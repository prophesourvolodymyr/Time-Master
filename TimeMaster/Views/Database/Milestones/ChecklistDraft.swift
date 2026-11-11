import Foundation
import TimeMasterCore

/// The fields of an entry while the editor holds them: what the preview draws and what Save writes.
struct ChecklistDraft: Equatable {
    var title = ""
    var note = ""
    var iconName = ""
    var iconType: SkillBoardIconType = .emoji
    var iconImage: String?
    var colorHex: String?
    var coverMediaFilename: String?
    var imageFilenames: [String] = []
    var links: [TodoLink] = []
    var isSection = false

    init() {}

    init<Entry: ChecklistEntry>(_ entry: Entry) {
        title = entry.title
        note = entry.note
        iconName = entry.iconName ?? ""
        iconType = entry.iconType ?? .emoji
        iconImage = entry.iconImage
        colorHex = entry.colorHex
        coverMediaFilename = entry.coverMediaFilename
        imageFilenames = entry.imageFilenames
        links = entry.links
        isSection = entry.isSection
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Writes the draft into `entry` (its place, children and checked state are not the editor's).
    func apply<Entry: ChecklistEntry>(to entry: inout Entry) {
        entry.title = trimmedTitle
        entry.note = isSection ? "" : note.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.iconName = icon.isEmpty || iconImage != nil ? nil : icon
        entry.iconType = entry.iconName == nil ? nil : iconType
        entry.iconImage = isSection ? nil : iconImage
        entry.colorHex = colorHex
        entry.coverMediaFilename = isSection ? nil : coverMediaFilename
        entry.imageFilenames = isSection ? [] : imageFilenames
        entry.links = isSection ? [] : links
        entry.isSection = isSection
    }

    /// The entry as it would be saved now, for the live preview.
    func preview<Entry: ChecklistEntry>(of existing: Entry?, placeholder: String) -> Entry {
        var entry = existing ?? Entry.blank(id: "draft", title: placeholder)
        apply(to: &entry)
        if entry.title.isEmpty { entry.title = placeholder }
        return entry
    }
}
