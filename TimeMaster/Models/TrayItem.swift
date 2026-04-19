import UIKit

// MARK: - TrayMedia

/// A single piece of media collected in the editor tray.
/// Either a still screenshot or a defined clip (with in/out times and a thumbnail).
enum TrayMedia: Equatable {
    case screenshot(UIImage)
    case clip(startTime: Double, endTime: Double, thumbnail: UIImage)

    var thumbnail: UIImage {
        switch self {
        case .screenshot(let img): return img
        case .clip(_, _, let thumb): return thumb
        }
    }

    var isClip: Bool {
        if case .clip = self { return true }
        return false
    }

    var startTime: Double? {
        if case .clip(let s, _, _) = self { return s }
        return nil
    }

    var endTime: Double? {
        if case .clip(_, let e, _) = self { return e }
        return nil
    }

    // Manual Equatable (UIImage doesn't conform)
    static func == (lhs: TrayMedia, rhs: TrayMedia) -> Bool {
        switch (lhs, rhs) {
        case (.screenshot(let a), .screenshot(let b)): return a === b
        case (.clip(let s1, let e1, let t1), .clip(let s2, let e2, let t2)):
            return s1 == s2 && e1 == e2 && t1 === t2
        default: return false
        }
    }
}

// MARK: - TrayItem

/// One card in the editor tray — will become one Exercise on save.
struct TrayItem: Identifiable {
    var id = UUID()
    var name: String = ""
    var details: String = ""
    var mediaList: [TrayMedia] = []

    /// The thumbnail of the first media item, used to preview the card.
    var primaryThumbnail: UIImage? { mediaList.first?.thumbnail }

    /// Start time of the first clip in the item (used for the Preview button in BatchConfirmView).
    var firstClipStartTime: Double? {
        for m in mediaList {
            if case .clip(let s, _, _) = m { return s }
        }
        return nil
    }
}
