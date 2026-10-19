import AVFoundation
import Combine
import TimeMasterCore

struct WorkoutMusicCheckpoint: Codable {
    var cursor: WorkoutMusicCursor
    var manualTimeline: WorkoutMusicTimeline?
    var manualCursor: WorkoutMusicCursor?
    var repeats: Bool
    var silenced: Bool
}

@MainActor
final class WorkoutMusicSession: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isManual = false
    @Published private(set) var title: String?
    @Published private(set) var exhausted = false
    @Published var error: String?

    private var scheduler: WorkoutMusicScheduler?
    private var manual: WorkoutMusicScheduler?
    private var repeats = false
    @Published private var silenced = false
    private var paused = false
    private var timer: Timer?
    private var anchor: TimeInterval = 0
    private var anchorElapsed: Double = 0
    private var manualAnchor: TimeInterval = 0
    private var manualElapsed: Double = 0
    private var generation = UUID()
    private var activePlayer: AVAudioPlayer?
    private var outgoingPlayer: AVAudioPlayer?
    private var activeKey: String?
    private var fadedOut = false
    private var volumeSubscription: AnyCancellable?
    private let fadeDuration: Double = 0.4

    var hasTimeline: Bool { scheduler != nil }
    var isSilenced: Bool { silenced }
    @Published private(set) var elapsed: Double = 0
    var timeline: WorkoutMusicTimeline? { (manual ?? scheduler)?.timeline }
    var selection: WorkoutMusicSelection? { manual?.selection ?? (manual == nil ? scheduler?.selection : nil) }
    var activeClip: WorkoutMusicClip? {
        guard let selection else { return nil }
        return (manual ?? scheduler)?.timeline.clips.first { $0.id == selection.clipID }
    }
    var isPlaylist: Bool { (activeClip?.tracks.count ?? 0) > 1 }
    var canSkipForward: Bool {
        guard let clip = activeClip, let selection,
              let index = clip.tracks.firstIndex(where: { $0.id == selection.track.id }) else { return false }
        let nextStart = clip.tracks.prefix(index + 1).reduce(0) { $0 + $1.duration }
        guard nextStart < clip.audibleDuration else { return false }
        return clip.tracks.dropFirst(index + 1).contains { $0.duration > 0 }
    }

    func artwork(in library: MusicLibraryStore) -> MusicArtworkReference? {
        guard let selection else { return nil }
        let item = activeClip?.sourceItemID.flatMap { library.item(id: $0) }
        return item?.tracks.first(where: { $0.id == selection.track.id })?.artwork
            ?? library.item(id: selection.track.id)?.artwork ?? item?.artwork
    }

    func updateTimeline(_ timeline: WorkoutMusicTimeline) {
        render()
        let previous = manual ?? scheduler
        let position = previous?.cursor.elapsed ?? 0
        var rebuilt = WorkoutMusicScheduler(timeline: timeline)
        rebuilt.advance(to: position)
        var cursor = rebuilt.cursor
        if let previous {
            for clip in timeline.clips where previous.timeline.clips.contains(clip) {
                cursor.positions[clip.id] = previous.cursor.positions[clip.id]
            }
        }
        manual = nil
        isManual = false
        scheduler = WorkoutMusicScheduler(timeline: timeline, cursor: cursor)
        anchorElapsed = position
        anchor = ProcessInfo.processInfo.systemUptime
        error = nil
        render()
        if let selection, let activePlayer, abs(activePlayer.currentTime - selection.offset) > 0.5 {
            activePlayer.currentTime = min(selection.offset, activePlayer.duration)
        }
    }

    func togglePlayback() {
        if silenced {
            silenced = false
            render()
        } else {
            silence()
        }
    }

    func skipForward() {
        guard canSkipForward, let clip = activeClip, let selection,
              let index = clip.tracks.firstIndex(where: { $0.id == selection.track.id }),
              let playback = manual ?? scheduler else { return }
        var cursor = playback.cursor
        cursor.positions[clip.id] = clip.tracks.prefix(index + 1).reduce(0) { $0 + $1.duration }
        let updated = WorkoutMusicScheduler(timeline: playback.timeline, cursor: cursor)
        if manual != nil { manual = updated } else { scheduler = updated }
        render()
    }
    var checkpoint: WorkoutMusicCheckpoint? {
        guard let scheduler else { return nil }
        return WorkoutMusicCheckpoint(cursor: scheduler.cursor, manualTimeline: manual?.timeline,
                                      manualCursor: manual?.cursor, repeats: repeats, silenced: silenced)
    }

    init() {
        volumeSubscription = MusicManager.shared.$volume
            .receive(on: RunLoop.main)
            .sink { [weak self] volume in
                Task { @MainActor in
                    guard let self, !self.fadedOut else { return }
                    self.activePlayer?.setVolume(volume, fadeDuration: self.fadeDuration)
                }
            }
    }

    func start(workout: Workout, library: MusicLibraryStore, checkpoint: WorkoutMusicCheckpoint? = nil,
               paused: Bool = false, elapsed: Double = 0) async {
        stop()
        let request = generation
        let started = ProcessInfo.processInfo.systemUptime
        MusicManager.shared.stopPlayback()
        self.paused = paused
        self.silenced = checkpoint?.silenced ?? false
        if let timeline = workout.musicTimeline {
            scheduler = WorkoutMusicScheduler(timeline: timeline, cursor: checkpoint?.cursor ?? .init())
            scheduler?.advance(to: elapsed)
        } else {
            library.adoptMusicManagerTracks()
            await library.refreshLocalDurations()
            guard generation == request else { return }
        }
        if let manualTimeline = checkpoint?.manualTimeline {
            manual = WorkoutMusicScheduler(timeline: manualTimeline, cursor: checkpoint?.manualCursor ?? .init())
            repeats = checkpoint?.repeats ?? false
        } else if workout.musicTimeline == nil {
            let tracks = library.assignedMusic(for: workout).flatMap { $0.musicClip().tracks }
            let clip = WorkoutMusicClip(title: "Workout music", lane: .background, start: 0,
                                        duration: tracks.reduce(0) { $0 + $1.duration }, tracks: tracks)
            manual = WorkoutMusicScheduler(timeline: .init(clips: tracks.isEmpty ? [] : [clip]))
            repeats = true
        }
        isManual = manual != nil
        anchorElapsed = scheduler?.cursor.elapsed ?? 0
        manualElapsed = manual?.cursor.elapsed ?? 0
        anchor = started
        manualAnchor = started
        installTimer()
        render()
    }

    func play(_ clip: WorkoutMusicClip, repeatMusic: Bool) {
        guard !clip.tracks.isEmpty, clip.sourceDuration > 0 else {
            error = "This music has no playable duration. Import its audio in Settings first."
            return
        }
        generation = UUID()
        var selected = clip
        selected.id = UUID()
        selected.start = 0
        selected.duration = selected.sourceDuration
        manual = WorkoutMusicScheduler(timeline: .init(clips: [selected]))
        manualElapsed = 0
        manualAnchor = ProcessInfo.processInfo.systemUptime
        repeats = repeatMusic
        silenced = false
        isManual = true
        exhausted = false
        error = nil
        if timer == nil { installTimer() }
        render()
    }

    func returnToTimeline() {
        manual = nil
        isManual = false
        silenced = false
        error = nil
        render()
    }

    func silence() {
        generation = UUID()
        silenced = true
        transition(to: nil)
    }

    func setPaused(_ value: Bool) {
        guard value != paused else { return }
        if value {
            render()
            anchorElapsed = scheduler?.cursor.elapsed ?? 0
            manualElapsed = manual?.cursor.elapsed ?? 0
            paused = true
            activePlayer?.pause()
            outgoingPlayer?.pause()
            isPlaying = false
        } else {
            paused = false
            anchor = ProcessInfo.processInfo.systemUptime
            manualAnchor = anchor
            if !silenced {
                activePlayer?.play()
                if !fadedOut { activePlayer?.setVolume(MusicManager.shared.volume, fadeDuration: fadeDuration) }
            }
            render()
        }
    }

    func stop() {
        generation = UUID()
        timer?.invalidate()
        timer = nil
        activePlayer?.stop()
        outgoingPlayer?.stop()
        activePlayer = nil
        outgoingPlayer = nil
        activeKey = nil
        scheduler = nil
        manual = nil
        title = nil
        isPlaying = false
        isManual = false
        exhausted = false
        silenced = false
        elapsed = 0
    }

    private func installTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func render() {
        let now = ProcessInfo.processInfo.systemUptime
        if !paused {
            scheduler?.advance(to: anchorElapsed + max(0, now - anchor))
            manual?.advance(to: manualElapsed + max(0, now - manualAnchor))
            if let manual, manual.exhausted, repeats, manual.timeline.end > 0 {
                self.manual = WorkoutMusicScheduler(timeline: manual.timeline)
                manualElapsed = 0
                manualAnchor = now
                activeKey = nil
            }
        }
        let currentElapsed = floor((manual ?? scheduler)?.cursor.elapsed ?? 0)
        if elapsed != currentElapsed { elapsed = currentElapsed }
        let ended = manual?.exhausted ?? scheduler?.exhausted ?? false
        if exhausted != ended { exhausted = ended }
        guard !silenced else { return }
        let selected = manual?.selection ?? (manual == nil ? scheduler?.selection : nil)
        transition(to: selected)
        if let selected {
            let playback = manual ?? scheduler
            let clipEnd = playback?.timeline.clips.first { $0.id == selected.clipID }?.end ?? .infinity
            let remaining = min(selected.track.duration - selected.offset,
                                clipEnd - (playback?.cursor.elapsed ?? 0))
            if remaining <= fadeDuration, !fadedOut {
                activePlayer?.setVolume(0, fadeDuration: max(0, remaining))
                fadedOut = true
            }
        }
        let playing = !paused && activePlayer?.isPlaying == true
        if isPlaying != playing { isPlaying = playing }
    }

    private func transition(to selection: WorkoutMusicSelection?) {
        let key = selection.map { "\($0.clipID)/\($0.track.id)" }
        guard key != activeKey else { return }
        outgoingPlayer?.stop()
        outgoingPlayer = activePlayer
        let outgoing = outgoingPlayer
        outgoing?.setVolume(0, fadeDuration: fadeDuration)
        activePlayer = nil
        activeKey = key
        fadedOut = false
        if let selection {
            title = selection.track.title
            do {
                guard let filename = selection.track.filename,
                      filename == URL(fileURLWithPath: filename).lastPathComponent else {
                    throw PlaybackError.unavailable(selection.track.title)
                }
                let url = MusicManager.shared.localMusicDirectoryURL.appendingPathComponent(filename)
                let player = try AVAudioPlayer(contentsOf: url)
                player.currentTime = min(selection.offset, player.duration)
                player.volume = 0
                player.prepareToPlay()
                activePlayer = player
                if !paused {
                    #if os(iOS)
                    try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
                    try AVAudioSession.sharedInstance().setActive(true)
                    #endif
                    player.play()
                    player.setVolume(MusicManager.shared.volume, fadeDuration: fadeDuration)
                }
            } catch {
                self.error = "Cannot play \(selection.track.title). Its audio is missing or unavailable. Import it in Settings or replace this clip."
            }
        } else {
            title = nil
            isPlaying = false
        }
        Task { @MainActor [weak self, weak outgoing] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.activePlayer !== outgoing else { return }
            outgoing?.stop()
            if self.outgoingPlayer === outgoing { self.outgoingPlayer = nil }
        }
    }

    private enum PlaybackError: Error {
        case unavailable(String)
    }
}
