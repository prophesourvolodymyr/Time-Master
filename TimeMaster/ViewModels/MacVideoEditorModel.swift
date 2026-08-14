#if os(macOS)
import AVFoundation
import Combine

@MainActor
final class MacVideoEditorModel: ObservableObject {
    let asset: AVURLAsset
    let player: AVPlayer

    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isProcessing = false
    @Published private(set) var message: String?
    @Published private(set) var drafts: [MacVideoDraft] = []

    @Published var clipStart: Double = 0
    @Published var clipEnd: Double = 0

    private var isScrubbing = false
    private var timeObserverToken: Any?
    private var playbackEndObserver: NSObjectProtocol?

    init(url: URL) {
        asset = AVURLAsset(url: url)
        player = AVPlayer(url: url)
        observePlayback()
        loadDuration()
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func beginScrubbing() {
        isScrubbing = true
        player.pause()
        isPlaying = false
    }

    func endScrubbing() {
        isScrubbing = false
        seek(to: currentTime)
    }

    func seek(to seconds: Double) {
        let clampedTime = max(0, min(duration, seconds))
        let time = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
    }

    func setClipStartToCurrentTime() {
        guard duration > 0 else { return }
        clipStart = min(currentTime, max(0, clipEnd - 0.25))
    }

    func setClipEndToCurrentTime() {
        guard duration > 0 else { return }
        clipEnd = max(currentTime, min(duration, clipStart + 0.25))
    }

    func addStill() async {
        guard drafts.count < 20 else {
            message = "A page can contain up to 20 media items."
            return
        }

        let captureTime = currentTime
        isProcessing = true
        defer { isProcessing = false }

        guard let thumbnail = await VideoTrimService.thumbnail(asset: asset, at: captureTime) else {
            message = "Could not capture a still at this time."
            return
        }

        drafts.append(MacVideoDraft(
            kind: .screenshot,
            startTime: captureTime,
            endTime: nil,
            thumbnail: thumbnail
        ))
        message = "Still added to the media tray."
    }

    func addClip() async {
        guard drafts.count < 20 else {
            message = "A page can contain up to 20 media items."
            return
        }
        guard clipEnd - clipStart >= 0.25 else {
            message = "Set a clip end after its start."
            return
        }

        let startTime = clipStart
        let endTime = clipEnd
        isProcessing = true
        defer { isProcessing = false }

        guard let thumbnail = await VideoTrimService.thumbnail(asset: asset, at: startTime) else {
            message = "Could not prepare that clip."
            return
        }

        drafts.append(MacVideoDraft(
            kind: .clip,
            startTime: startTime,
            endTime: endTime,
            thumbnail: thumbnail
        ))
        message = "Clip added to the media tray."
    }

    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        message = drafts.isEmpty ? nil : "Media tray updated."
    }

    func stopPlayback() {
        player.pause()
        isPlaying = false
    }

    private func loadDuration() {
        Task { [weak self, asset] in
            do {
                let loadedDuration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(loadedDuration)
                guard let self else { return }
                guard seconds.isFinite, seconds > 0 else {
                    self.message = "This video has no playable duration."
                    return
                }
                self.duration = seconds
                self.clipEnd = min(seconds, 30)
            } catch {
                self?.message = "TimeMaster could not read this video."
            }
        }
    }

    private func observePlayback() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                self.currentTime = seconds
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
    }
}
#endif
