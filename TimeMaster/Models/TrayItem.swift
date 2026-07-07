#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - TrayMedia

#if os(iOS)
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

    static func == (lhs: TrayMedia, rhs: TrayMedia) -> Bool {
        switch (lhs, rhs) {
        case (.screenshot(let a), .screenshot(let b)): return a === b
        case (.clip(let s1, let e1, let t1), .clip(let s2, let e2, let t2)):
            return s1 == s2 && e1 == e2 && t1 === t2
        default: return false
        }
    }
}
#elseif os(macOS)
enum TrayMedia: Equatable {
    case screenshot(NSImage)
    case clip(startTime: Double, endTime: Double, thumbnail: NSImage)

    var thumbnail: NSImage {
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

    static func == (lhs: TrayMedia, rhs: TrayMedia) -> Bool {
        switch (lhs, rhs) {
        case (.screenshot(let a), .screenshot(let b)): return a === b
        case (.clip(let s1, let e1, let t1), .clip(let s2, let e2, let t2)):
            return s1 == s2 && e1 == e2 && t1 === t2
        default: return false
        }
    }
}
#endif

// MARK: - TrayItem

struct TrayItem: Identifiable {
    var id = UUID()
    var name: String = ""
    var details: String = ""
    var mediaList: [TrayMedia] = []

    #if os(iOS)
    var primaryThumbnail: UIImage? { mediaList.first?.thumbnail as? UIImage }
    #elseif os(macOS)
    var primaryThumbnail: NSImage? { mediaList.first?.thumbnail as? NSImage }
    #endif

    var firstClipStartTime: Double? {
        for m in mediaList {
            if case .clip(let s, _, _) = m { return s }
        }
        return nil
    }
}
