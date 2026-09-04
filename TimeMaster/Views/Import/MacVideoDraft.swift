#if os(macOS)
import AppKit
import Foundation

struct MacVideoDraft: Identifiable {
    enum Kind: Equatable {
        case screenshot
        case clip
    }

    struct Media: Identifiable {
        let id: UUID
        let kind: Kind
        let startTime: Double
        let endTime: Double?
        let thumbnail: NSImage
        let sourceSegmentID: UUID?

        init(
            id: UUID = UUID(),
            kind: Kind,
            startTime: Double,
            endTime: Double?,
            thumbnail: NSImage,
            sourceSegmentID: UUID? = nil
        ) {
            self.id = id
            self.kind = kind
            self.startTime = startTime
            self.endTime = endTime
            self.thumbnail = thumbnail
            self.sourceSegmentID = sourceSegmentID
        }
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
    var groupedMedia: [Media]

    init(
        id: UUID = UUID(),
        kind: Kind,
        startTime: Double,
        endTime: Double?,
        thumbnail: NSImage,
        sourceSegmentID: UUID? = nil,
        displayName: String? = nil,
        isSaved: Bool = false,
        savedTargetLabel: String? = nil,
        groupedMedia: [Media] = []
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
        self.groupedMedia = groupedMedia
    }

    var mediaItems: [Media] {
        [
            Media(
                id: id,
                kind: kind,
                startTime: startTime,
                endTime: endTime,
                thumbnail: thumbnail,
                sourceSegmentID: sourceSegmentID
            )
        ] + groupedMedia
    }

    var mediaCount: Int {
        1 + groupedMedia.count
    }

    mutating func append(media: [Media]) {
        groupedMedia.append(contentsOf: media)
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
        mediaCount > 1
            ? "square.stack.3d.up.fill"
            : (kind == .screenshot ? "camera.fill" : "film.fill")
    }

    var rangeLabel: String {
        guard mediaCount == 1 else {
            return "\(mediaCount) media items"
        }

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
