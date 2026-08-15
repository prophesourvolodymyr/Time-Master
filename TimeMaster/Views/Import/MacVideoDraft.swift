#if os(macOS)
import AppKit
import Foundation

struct MacVideoDraft: Identifiable {
    enum Kind {
        case screenshot
        case clip
    }

    let id: UUID
    let kind: Kind
    let startTime: Double
    let endTime: Double?
    let thumbnail: NSImage
    let sourceSegmentID: UUID?

    var displayName: String?
    var isSaved = false
    var savedTargetLabel: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        startTime: Double,
        endTime: Double?,
        thumbnail: NSImage,
        sourceSegmentID: UUID? = nil,
        displayName: String? = nil,
        isSaved: Bool = false,
        savedTargetLabel: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startTime = startTime
        self.endTime = endTime
        self.thumbnail = thumbnail
        self.sourceSegmentID = sourceSegmentID
        self.displayName = displayName
        self.isSaved = isSaved
        self.savedTargetLabel = savedTargetLabel
    }

    var title: String {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }

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

    var rangeLabel: String {
        switch kind {
        case .screenshot:
            return "Frame at \(Self.timeString(startTime))"
        case .clip:
            return "\(Self.timeString(startTime)) – \(Self.timeString(endTime ?? startTime))"
        }
    }

    private static func timeString(_ seconds: Double) -> String {
        let bounded = max(0, seconds)
        let minutes = Int(bounded) / 60
        let wholeSeconds = Int(bounded) % 60
        let hundredths = Int((bounded - floor(bounded)) * 100)
        return String(format: "%d:%02d.%02d", minutes, wholeSeconds, hundredths)
    }
}
#endif
