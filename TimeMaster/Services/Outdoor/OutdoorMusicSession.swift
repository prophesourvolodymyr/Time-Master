import Foundation
import Combine
import TimeMasterCore

@MainActor
final class OutdoorMusicSession: ObservableObject {
    @Published private(set) var activityID: UUID?
    @Published private(set) var playedTracks: [OutdoorPlayedTrackEvent] = []

    var events: [OutdoorPlayedTrackEvent] { playedTracks }
    var isObserving: Bool { activityID != nil }

    private let musicManager: MusicManager
    private let clock: () -> Date
    private var trackSubscription: AnyCancellable?
    private var lastObservedTrackID: String?

    init(musicManager: MusicManager = .shared, clock: @escaping () -> Date = Date.init) {
        self.musicManager = musicManager
        self.clock = clock
    }

    func start(activityID: UUID, existingEvents: [OutdoorPlayedTrackEvent] = []) {
        if self.activityID != activityID {
            playedTracks = existingEvents
            lastObservedTrackID = existingEvents.last?.trackID
        }
        trackSubscription?.cancel()
        self.activityID = activityID
        trackSubscription = musicManager.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recordCurrentTrackIfPlaying() }
        recordCurrentTrackIfPlaying()
    }

    func start(activityID: String) {
        guard let id = UUID(uuidString: activityID) else { return }
        start(activityID: id)
    }

    func stop() {
        trackSubscription?.cancel()
        trackSubscription = nil
        activityID = nil
    }

    func stopObserving() {
        stop()
    }

    func finish() -> [OutdoorPlayedTrackEvent] {
        let result = playedTracks
        stop()
        return result
    }

    func reset() {
        stop()
        playedTracks = []
        lastObservedTrackID = nil
    }

    private func recordCurrentTrackIfPlaying() {
        guard activityID != nil, musicManager.isPlaying, let track = musicManager.currentTrack else { return }
        guard track.id != lastObservedTrackID else { return }
        let eventID = "\(activityID?.uuidString.lowercased() ?? "activity")/\(playedTracks.count)/\(track.id)"
        let event = OutdoorPlayedTrackEvent(
            id: eventID,
            timestamp: clock(),
            trackID: track.id,
            title: track.title,
            artist: track.artist,
            artworkReference: track.artworkReference
        )
        playedTracks.append(event)
        lastObservedTrackID = track.id
    }
}
