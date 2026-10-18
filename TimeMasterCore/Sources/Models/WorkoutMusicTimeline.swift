import Foundation

public enum WorkoutMusicLane: String, Codable, CaseIterable, Identifiable, Sendable {
    case primary, background
    public var id: String { rawValue }
}

public struct WorkoutMusicTrack: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var filename: String?
    public var duration: Double
    public var provider: String?
    public var providerReference: String?

    public init(id: UUID = UUID(), title: String, filename: String?, duration: Double,
                provider: String? = nil, providerReference: String? = nil) {
        self.id = id
        self.title = title
        self.filename = filename
        self.duration = max(0, duration)
        self.provider = provider
        self.providerReference = providerReference
    }
}

public struct WorkoutMusicClip: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sourceItemID: UUID?
    public var title: String
    public var lane: WorkoutMusicLane
    public var start: Double
    public var duration: Double
    public var tracks: [WorkoutMusicTrack]
    public var end: Double { start + duration }
    public var sourceDuration: Double { tracks.reduce(0) { $0 + max(0, $1.duration) } }
    public var audibleDuration: Double { min(duration, sourceDuration) }

    public init(id: UUID = UUID(), sourceItemID: UUID? = nil, title: String,
                lane: WorkoutMusicLane, start: Double, duration: Double,
                tracks: [WorkoutMusicTrack]) {
        self.id = id
        self.sourceItemID = sourceItemID
        self.title = title
        self.lane = lane
        self.start = max(0, start)
        self.duration = max(0, duration)
        self.tracks = tracks
    }

    public mutating func replaceMusic(with replacement: WorkoutMusicClip) {
        sourceItemID = replacement.sourceItemID
        title = replacement.title
        tracks = replacement.tracks
    }
}

public struct WorkoutMusicTimeline: Codable, Equatable, Sendable {
    public var clips: [WorkoutMusicClip]
    public var end: Double { clips.reduce(0) { max($0, $1.end) } }

    public init(clips: [WorkoutMusicClip] = []) { self.clips = clips }

}

public struct WorkoutMusicCursor: Codable, Equatable, Sendable {
    public var elapsed: Double
    public var positions: [UUID: Double]
    public init(elapsed: Double = 0, positions: [UUID: Double] = [:]) {
        self.elapsed = elapsed
        self.positions = positions
    }
}

public struct WorkoutMusicSelection: Equatable, Sendable {
    public var clipID: UUID
    public var track: WorkoutMusicTrack
    public var offset: Double
}

public struct WorkoutMusicScheduler: Sendable {
    public let timeline: WorkoutMusicTimeline
    public private(set) var cursor: WorkoutMusicCursor

    public init(timeline: WorkoutMusicTimeline, cursor: WorkoutMusicCursor = .init()) {
        self.timeline = timeline
        self.cursor = cursor
    }

    public var selection: WorkoutMusicSelection? {
        guard let clip = activeClip(at: cursor.elapsed) else { return nil }
        var offset = cursor.positions[clip.id, default: 0]
        for track in clip.tracks where track.duration > 0 {
            if offset < track.duration {
                return WorkoutMusicSelection(clipID: clip.id, track: track, offset: offset)
            }
            offset -= track.duration
        }
        return nil
    }

    public var exhausted: Bool {
        !timeline.clips.isEmpty && timeline.clips.allSatisfy {
            $0.start <= cursor.elapsed &&
            ($0.end <= cursor.elapsed || cursor.positions[$0.id, default: 0] >= $0.audibleDuration)
        }
    }

    public mutating func advance(to elapsed: Double) {
        guard elapsed.isFinite, elapsed > cursor.elapsed else { return }
        while cursor.elapsed < elapsed {
            let active = activeClip(at: cursor.elapsed)
            var next = elapsed
            for clip in timeline.clips {
                if clip.start > cursor.elapsed { next = min(next, clip.start) }
                if clip.end > cursor.elapsed { next = min(next, clip.end) }
            }
            if let active {
                let position = cursor.positions[active.id, default: 0]
                next = min(next, cursor.elapsed + active.audibleDuration - position)
                cursor.positions[active.id] = min(active.audibleDuration, position + next - cursor.elapsed)
            }
            guard next > cursor.elapsed else { break }
            cursor.elapsed = next
        }
    }

    private func activeClip(at time: Double) -> WorkoutMusicClip? {
        var winner: WorkoutMusicClip?
        for clip in timeline.clips where clip.start <= time && time < clip.end &&
            cursor.positions[clip.id, default: 0] < clip.audibleDuration {
            if let current = winner {
                if current.lane == .primary && clip.lane == .background { continue }
                if current.lane == clip.lane && current.start > clip.start { continue }
            }
            winner = clip
        }
        return winner
    }
}

public struct WorkoutMusicResizeIntent {
    private var candidateBoundary: Double?
    private var previousDelta: Double = 0
    private var reversals = 0

    public init() {}

    public mutating func adjustedEnd(_ proposed: Double, boundaries: [Double], tolerance: Double) -> Double {
        guard let boundary = boundaries.min(by: { abs($0 - proposed) < abs($1 - proposed) }),
              abs(boundary - proposed) <= tolerance else {
            self = Self()
            return proposed
        }
        let delta = proposed - boundary
        if candidateBoundary != boundary {
            candidateBoundary = boundary
            reversals = 0
        } else if delta * previousDelta < 0 {
            reversals += 1
        }
        if abs(delta) > tolerance * 0.1 { previousDelta = delta }
        return reversals >= 2 && abs(delta) <= tolerance * 0.4 ? boundary : proposed
    }
}
