#if os(iOS)
import ActivityKit
import Foundation

@available(iOS 17.0, *)
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case warmUp
            case prepare
            case active
            case setRest
            case sectionRest
            case completed
        }

        var phase: Phase
        var title: String
        var subtitle: String
        var isPaused: Bool
        var remainingSeconds: Int
        var phaseDuration: Int
        var phaseEndDate: Date?
        var nextTitle: String?
        var elapsedSeconds: Int
        var itemIndex: Int?
        var itemCount: Int?
        var sectionIndex: Int
        var sectionCount: Int
        var isBundle: Bool
        var nextKind: String?
        var artworkName: String?
        var nextArtworkName: String?

        init(
            phase: Phase,
            title: String,
            subtitle: String,
            isPaused: Bool,
            remainingSeconds: Int,
            phaseDuration: Int,
            phaseEndDate: Date?,
            nextTitle: String?,
            elapsedSeconds: Int,
            itemIndex: Int? = nil,
            itemCount: Int? = nil,
            sectionIndex: Int = 0,
            sectionCount: Int = 0,
            isBundle: Bool = false,
            nextKind: String? = nil,
            artworkName: String? = nil,
            nextArtworkName: String? = nil
        ) {
            self.phase = phase
            self.title = title
            self.subtitle = subtitle
            self.isPaused = isPaused
            self.remainingSeconds = remainingSeconds
            self.phaseDuration = phaseDuration
            self.phaseEndDate = phaseEndDate
            self.nextTitle = nextTitle
            self.elapsedSeconds = elapsedSeconds
            self.itemIndex = itemIndex
            self.itemCount = itemCount
            self.sectionIndex = sectionIndex
            self.sectionCount = sectionCount
            self.isBundle = isBundle
            self.nextKind = nextKind
            self.artworkName = artworkName
            self.nextArtworkName = nextArtworkName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phase = try container.decode(Phase.self, forKey: .phase)
            title = try container.decode(String.self, forKey: .title)
            subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
            isPaused = try container.decode(Bool.self, forKey: .isPaused)
            remainingSeconds = try container.decode(Int.self, forKey: .remainingSeconds)
            phaseDuration = try container.decode(Int.self, forKey: .phaseDuration)
            phaseEndDate = try container.decodeIfPresent(Date.self, forKey: .phaseEndDate)
            nextTitle = try container.decodeIfPresent(String.self, forKey: .nextTitle)
            elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
            itemIndex = try container.decodeIfPresent(Int.self, forKey: .itemIndex)
            itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount)
            sectionIndex = try container.decodeIfPresent(Int.self, forKey: .sectionIndex) ?? 0
            sectionCount = try container.decodeIfPresent(Int.self, forKey: .sectionCount) ?? 0
            isBundle = try container.decodeIfPresent(Bool.self, forKey: .isBundle) ?? false
            nextKind = try container.decodeIfPresent(String.self, forKey: .nextKind)
            artworkName = try container.decodeIfPresent(String.self, forKey: .artworkName)
            nextArtworkName = try container.decodeIfPresent(String.self, forKey: .nextArtworkName)
        }
    }

    var workoutID: String
    var workoutName: String
    var colorHex: String
    var startedAt: Date
}
#endif
