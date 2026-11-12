import SwiftUI

extension WorkoutPhase {
    var playerCaption: String? {
        switch self {
        case .warmUp: "WARM UP"
        case .prepare: "PREPARATION"
        case .setRest: "REST BETWEEN SETS"
        case .sectionRest: "REST"
        case .active: nil
        }
    }

    var playerSpokenName: String {
        switch self {
        case .warmUp: "Warm up"
        case .prepare: "Get ready"
        case .active: "Work"
        case .setRest: "Rest between exercises"
        case .sectionRest: "Rest between sections"
        }
    }
}

enum PlayerTime {
    static func counter(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, total % 60) : String(format: "%02d", total)
    }

    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func spoken(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let rest = total % 60
        switch (minutes, rest) {
        case (0, _): return "\(rest) second\(rest == 1 ? "" : "s")"
        case (_, 0): return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        default: return "\(minutes) minute\(minutes == 1 ? "" : "s") \(rest) second\(rest == 1 ? "" : "s")"
        }
    }
}

struct PlayerQueueItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let pageID: UUID?
    let mediaItem: MediaItem?
    let coverURL: URL?
    let symbol: String
    let duration: Int
    let repCount: Int?
    var isDrop = false

    var canPreview: Bool { pageID != nil || mediaItem != nil }
}

struct PlayerGlassCircle: ViewModifier {
    var size: CGFloat = 40
    var fill: Double = 0.2

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(Color.white.opacity(fill), in: Circle())
            .foregroundStyle(.white)
    }
}

extension View {
    func playerGlassCircle(size: CGFloat = 40, fill: Double = 0.2) -> some View {
        modifier(PlayerGlassCircle(size: size, fill: fill))
    }
}

struct PlayerPhaseCaption: View {
    let phase: WorkoutPhase

    var body: some View {
        if let caption = phase.playerCaption {
            Text(caption)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .tracking(5)
                .foregroundColor(.white.opacity(0.5))
                .accessibilityHidden(true)
        }
    }
}
