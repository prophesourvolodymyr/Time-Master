import SwiftUI
import TimeMasterCore

/// The rules the to-do list, the milestone cards and their editor share for drawing an entry.
enum ChecklistLook {
    /// What a milestone without an icon is drawn with.
    static let milestoneIconName = "flag.fill"
    /// The accent an entry without a colour of its own wears.
    static let defaultTintHex = "FF6A00"

    static func tintHex<Entry: ChecklistEntry>(_ entry: Entry) -> String {
        SkillColors.normalizedHex(entry.colorHex) ?? defaultTintHex
    }

    static func tint<Entry: ChecklistEntry>(_ entry: Entry) -> Color {
        Color(hex: tintHex(entry))
    }

    /// "3/8" counting every level (sections never count); nil without any entries.
    static func progressText<Entry: ChecklistEntry>(_ list: [Entry]) -> String? {
        list.progressTotal == 0 ? nil : "\(list.progressDone)/\(list.progressTotal)"
    }

    /// What VoiceOver says about an entry instead of the pictures and marks it is drawn with.
    static func spokenSummary<Entry: ChecklistEntry>(_ entry: Entry) -> String {
        var parts = [entry.title]
        if Entry.kind == .milestone { parts.append(entry.isDone ? "reached" : "not reached yet") }
        if !entry.children.isEmpty {
            parts.append("\(entry.children.progressDone) of \(entry.children.progressTotal) inside done")
        }
        if !entry.note.isEmpty { parts.append(entry.note) }
        if !entry.links.isEmpty { parts.append("\(entry.links.count) link\(entry.links.count == 1 ? "" : "s")") }
        if !entry.imageFilenames.isEmpty { parts.append("\(entry.imageFilenames.count) picture\(entry.imageFilenames.count == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    /// The SF Symbol of a page's kind, for chips and pickers.
    static func symbol(for page: ExercisePage) -> String {
        if page.isExercise { return page.effectiveWorkoutType?.iconName ?? "figure.strengthtraining.traditional" }
        if page.isSkillLike { return "sparkles" }
        if page.pageType == .note { return "doc.text" }
        return "folder"
    }

    /// The SF Symbol of a media file by its kind.
    static func symbol(forFile filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ChecklistMedia.isPicture(filename) { return "photo" }
        if ["mp4", "mov", "m4v"].contains(ext) { return "play.rectangle" }
        if ["mp3", "m4a", "wav", "aac"].contains(ext) { return "waveform" }
        if ext == "pdf" { return "doc.richtext" }
        return "doc"
    }
}
