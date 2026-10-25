import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Combine

// MARK: - Edit Mode

enum EditMode {
    case clip
    case screenshot
}

// MARK: - VideoEditorViewModel

@MainActor
final class VideoEditorViewModel: ObservableObject {

    // MARK: Asset & Player

    let asset: AVURLAsset
    let player: AVPlayer

    private var timeObserverToken: Any?
    private var notificationObserver: NSObjectProtocol?
    private let minimumSegmentDuration = 0.25
    private let mediaLimit = 20
    private var isScrubbing = false
    private var resumesAfterScrubbing = false
    private var pendingSeekTime: Double?
    private var isSeeking = false
    private var playerStatusObserver: NSKeyValueObservation?
    private var durationTask: Task<Void, Never>?
    private var thumbnailGenerator: AVAssetImageGenerator?

    // MARK: Published State

    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var mode: EditMode = .clip
    @Published private(set) var segments: [MacVideoTimelineSegment] = []
    @Published private(set) var selectedSegmentID: UUID?
    @Published private(set) var playbackError: String?
    #if os(iOS)
    @Published private(set) var timelineThumbnails: [UIImage] = []
    #else
    @Published private(set) var timelineThumbnails: [NSImage] = []
    #endif

    @Published private(set) var trayItems: [TrayItem] = []
    @Published var selectedTrayIndex: Int = 0
    @Published private(set) var selectedTrayIDs: Set<UUID> = []

    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""

    // MARK: Init

    init(url: URL) {
        let a = AVURLAsset(url: url)
        self.asset = a
        self.player = AVPlayer(url: url)
        setupDuration(asset: a)
        setupTimeObserver()
        playerStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "This video cannot be played."
            Task { @MainActor [weak self] in
                self?.playbackError = message
                self?.stopPlayback()
            }
        }
    }

    // MARK: Setup

    private func setupDuration(asset: AVURLAsset) {
        durationTask = Task { [weak self] in
            do {
                let dur = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(dur)
                guard !Task.isCancelled, let self else { return }
                guard seconds.isFinite, seconds > 0 else {
                    self.playbackError = "This video has no playable duration."
                    return
                }
                self.duration = seconds
                let segment = MacVideoTimelineSegment(startTime: 0, endTime: seconds)
                self.segments = [segment]
                self.selectedSegmentID = segment.id
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 160, height: 160)
                self.thumbnailGenerator = generator
                for index in 0..<12 {
                    guard !Task.isCancelled else { return }
                    let time = CMTime(seconds: seconds * Double(index) / 12, preferredTimescale: 600)
                    guard let (image, _) = try? await generator.image(at: time) else { continue }
                    guard !Task.isCancelled else { return }
                    #if os(iOS)
                    self.timelineThumbnails.append(UIImage(cgImage: image))
                    #else
                    self.timelineThumbnails.append(NSImage(cgImage: image, size: .zero))
                    #endif
                }
            } catch {
                self?.playbackError = "Could not read video duration. \(error.localizedDescription)"
            }
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isScrubbing, !self.isSeeking else { return }
                self.currentTime = min(max(0, seconds), self.duration)
            }
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
            }
        }
    }

    deinit {
        durationTask?.cancel()
        thumbnailGenerator?.cancelAllCGImageGeneration()
        playerStatusObserver?.invalidate()
        player.pause()
        if let token = timeObserverToken {
            let p = player
            DispatchQueue.main.async { p.removeTimeObserver(token) }
        }
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: Playback

    func togglePlayPause() {
        guard duration > 0, playbackError == nil else { return }
        if isPlaying || resumesAfterScrubbing {
            stopPlayback()
        } else {
            isPlaying = true
            if currentTime >= duration - 0.05 {
                seek(to: 0)
            } else if !isSeeking {
                player.play()
            }
        }
    }

    func stopPlayback() {
        resumesAfterScrubbing = false
        isPlaying = false
        player.pause()
    }

    func beginScrubbing() {
        guard !isScrubbing else { return }
        resumesAfterScrubbing = isPlaying
        isScrubbing = true
        player.pause()
        isPlaying = false
    }

    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        isPlaying = resumesAfterScrubbing
        resumesAfterScrubbing = false
        seek(to: currentTime)
    }

    func seek(to time: Double) {
        guard time.isFinite, duration > 0, playbackError == nil else { return }
        let clampedTime = max(0, min(duration, time))
        currentTime = clampedTime
        pendingSeekTime = clampedTime
        performPendingSeek()
    }

    private func performPendingSeek() {
        guard !isSeeking, let target = pendingSeekTime else { return }
        pendingSeekTime = nil
        isSeeking = true
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSeeking = false
                if self.pendingSeekTime != nil {
                    self.performPendingSeek()
                } else if !self.isScrubbing, self.isPlaying, finished {
                    self.player.play()
                }
            }
        }
    }

    func skipBackward() { seek(to: currentTime - 5) }
    func skipForward() { seek(to: currentTime + 5) }

    // MARK: Timeline

    func selectSegment(id: UUID) {
        guard segments.contains(where: { $0.id == id }) else { return }
        selectedSegmentID = id
    }

    @discardableResult
    func splitSegment(at time: Double) -> UUID? {
        guard duration >= minimumSegmentDuration * 2 else {
            statusMessage = "This video is too short to split"
            scheduleStatusClear()
            return nil
        }

        guard let index = segments.firstIndex(where: {
            time > $0.startTime + minimumSegmentDuration &&
                time < $0.endTime - minimumSegmentDuration
        }) else {
            statusMessage = "Place the playhead inside a segment to split it"
            scheduleStatusClear()
            return nil
        }

        let segment = segments[index]
        let splitTime = min(
            max(time, segment.startTime + minimumSegmentDuration),
            segment.endTime - minimumSegmentDuration
        )
        segments[index] = MacVideoTimelineSegment(
            id: segment.id,
            startTime: segment.startTime,
            endTime: splitTime
        )
        let newSegment = MacVideoTimelineSegment(
            startTime: splitTime,
            endTime: segment.endTime
        )
        segments.insert(newSegment, at: index + 1)
        selectedSegmentID = newSegment.id
        statusMessage = "Segment split at \(formatTime(splitTime))"
        scheduleStatusClear()
        return newSegment.id
    }

    func canSplit(at time: Double) -> Bool {
        duration >= minimumSegmentDuration * 2 &&
        segments.contains {
            time > $0.startTime + minimumSegmentDuration &&
                time < $0.endTime - minimumSegmentDuration
        }
    }

    // MARK: Actions

    func captureScreenshot() async {
        guard !isProcessing, duration > 0, playbackError == nil else { return }
        guard mediaCount < mediaLimit else {
            statusMessage = "The media tray is full"
            scheduleStatusClear()
            return
        }

        isProcessing = true
        statusMessage = "Capturing…"
        defer {
            isProcessing = false
            scheduleStatusClear()
        }

        guard let image = await VideoTrimService.thumbnail(asset: asset, at: currentTime) else {
            statusMessage = "Could not capture a still"
            return
        }

        appendMedia(.screenshot(image))
        statusMessage = "Still added"
    }

    func addClip() async {
        guard !isProcessing, duration > 0, playbackError == nil else { return }
        guard mediaCount < mediaLimit else {
            statusMessage = "The media tray is full"
            scheduleStatusClear()
            return
        }

        guard let segment = selectedSegment ?? segments.first(where: { $0.contains(currentTime) }) else {
            statusMessage = "Select a timeline segment first"
            scheduleStatusClear()
            return
        }

        isProcessing = true
        statusMessage = "Preparing clip…"
        defer {
            isProcessing = false
            scheduleStatusClear()
        }

        guard let thumbnail = await VideoTrimService.thumbnail(asset: asset, at: segment.startTime) else {
            statusMessage = "Could not prepare that clip"
            return
        }

        appendMedia(
            .clip(
                startTime: segment.startTime,
                endTime: segment.endTime,
                thumbnail: thumbnail
            )
        )
        statusMessage = "Clip added"
    }

    // MARK: Tray Management

    var mediaCount: Int {
        trayItems.reduce(0) { $0 + $1.mediaList.count }
    }

    func removeCard(id: UUID) {
        guard let index = trayItems.firstIndex(where: { $0.id == id }) else { return }
        trayItems.remove(at: index)
        selectedTrayIDs.remove(id)

        if trayItems.isEmpty {
            selectedTrayIndex = 0
        } else if index < selectedTrayIndex {
            selectedTrayIndex -= 1
        } else {
            selectedTrayIndex = min(selectedTrayIndex, trayItems.count - 1)
        }
    }

    func selectCard(id: UUID, extending: Bool = false) {
        guard let index = trayItems.firstIndex(where: { $0.id == id }) else { return }
        selectedTrayIndex = index
        if extending {
            if !selectedTrayIDs.insert(id).inserted { selectedTrayIDs.remove(id) }
        } else {
            selectedTrayIDs = [id]
        }
    }

    func mergeCards(sourceID: UUID, intoID targetID: UUID) {
        mergeCards(sourceIDs: [sourceID], intoID: targetID)
    }

    func mergeCards(sourceIDs: Set<UUID>, intoID targetID: UUID) {
        let sources = trayItems.filter { sourceIDs.contains($0.id) && $0.id != targetID }
        guard !sources.isEmpty,
              let targetIndex = trayItems.firstIndex(where: { $0.id == targetID }) else { return }
        trayItems[targetIndex].mediaList.append(contentsOf: sources.flatMap(\.mediaList))
        let removedIDs = Set(sources.map(\.id))
        trayItems.removeAll { removedIDs.contains($0.id) }
        selectedTrayIndex = trayItems.firstIndex(where: { $0.id == targetID }) ?? 0
        selectedTrayIDs = [targetID]
        statusMessage = "Media items grouped"
        scheduleStatusClear()
    }

    func ungroupCard(id: UUID) {
        guard let index = trayItems.firstIndex(where: { $0.id == id }),
              trayItems[index].mediaList.count > 1 else { return }
        let remaining = trayItems[index].mediaList.dropFirst()
        trayItems[index].mediaList = Array(trayItems[index].mediaList.prefix(1))
        trayItems.insert(contentsOf: remaining.map { TrayItem(mediaList: [$0]) }, at: index + 1)
        selectedTrayIDs = [id]
        selectedTrayIndex = index
        statusMessage = "Media stack separated"
        scheduleStatusClear()
    }

    var selectedSegment: MacVideoTimelineSegment? {
        guard let selectedSegmentID else { return nil }
        return segments.first { $0.id == selectedSegmentID }
    }

    private func appendMedia(_ media: TrayMedia) {
        trayItems.append(TrayItem(mediaList: [media]))
        selectedTrayIndex = trayItems.count - 1
        selectedTrayIDs = [trayItems[selectedTrayIndex].id]
    }

    // MARK: Helpers

    private func scheduleStatusClear() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !isProcessing { statusMessage = "" }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
