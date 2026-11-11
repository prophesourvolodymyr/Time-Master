import SwiftUI
import TimeMasterCore

/// What an entry is drawn with: its own cover and icon and, where it has none, the picture of its first workout or
/// page link (`ChecklistEntry.visualLink`). An entry's own cover or icon always wins.
struct ChecklistArtwork {
    enum Cover {
        /// A local or web picture.
        case picture(URL)
        /// The cover of a linked workout (its picture, first exercises or type icon, as the workout chose).
        case workout(Workout)
        /// The entry names a picture of the page that is not on this device (yet).
        case missingFile
        case none
    }

    enum Icon {
        case picture(URL)
        case glyph(name: String, type: SkillBoardIconType)
        /// A linked workout's type icon on its colour.
        case workout(Workout)
        /// A linked page's own icon.
        case page(ExercisePage)
        case none
    }

    var cover: Cover
    var icon: Icon
    /// The workout the cover or the icon is taken from: the row marks it with a play glyph.
    var workout: Workout?

    var hasCover: Bool {
        if case .none = cover { return false }
        return true
    }

    var hasIcon: Bool {
        if case .none = icon { return false }
        return true
    }

    @MainActor
    static func resolve<Entry: ChecklistEntry>(_ entry: Entry, pageID: String, store: DatabaseStore, workouts: [Workout]) -> ChecklistArtwork {
        var artwork = ChecklistArtwork(cover: .none, icon: .none, workout: nil)
        guard !entry.isSection else {
            if let name = entry.iconName { artwork.icon = .glyph(name: name, type: entry.iconType ?? .emoji) }
            return artwork
        }
        if let filename = entry.coverMediaFilename {
            if let url = store.checklistPictureURL(filename, on: pageID), FileManager.default.fileExists(atPath: url.path) {
                artwork.cover = .picture(url)
            } else {
                artwork.cover = .missingFile
            }
        }
        if let url = store.checklistIconURL(entry, on: pageID) {
            artwork.icon = .picture(url)
        } else if let name = entry.iconName {
            artwork.icon = .glyph(name: name, type: entry.iconType ?? SkillBoardIconType.inferred(from: name))
        }
        guard let link = entry.visualLink, !artwork.hasCover || !artwork.hasIcon else { return artwork }
        switch store.checklistTarget(of: link, on: pageID, workouts: workouts) {
        case .workout(let workout):
            if !artwork.hasCover { artwork.cover = .workout(workout) }
            if !artwork.hasIcon { artwork.icon = .workout(workout) }
            artwork.workout = workout
        case .page(let material):
            if !artwork.hasCover, let url = material.coverURL ?? material.page?.coverImageURL { artwork.cover = .picture(url) }
            if !artwork.hasIcon, let page = material.page { artwork.icon = .page(page) }
        default:
            break
        }
        return artwork
    }
}
