#if os(macOS)
import AppKit
import Foundation

struct MacVideoDraft: Identifiable {
    enum Kind {
        case screenshot
        case clip
    }

    let id = UUID()
    let kind: Kind
    let startTime: Double
    let endTime: Double?
    let thumbnail: NSImage

    var title: String {
        switch kind {
        case .screenshot:
            return "Still at \(Self.timeString(startTime))"
        case .clip:
            return "Clip \(Self.timeString(startTime)) – \(Self.timeString(endTime ?? startTime))"
        }
    }

    var systemImage: String {
        switch kind {
        case .screenshot: "camera.fill"
        case .clip: "film.fill"
        }
    }

    private static func timeString(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
#endif
