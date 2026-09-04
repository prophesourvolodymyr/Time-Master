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

    // MARK: Published State

    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var mode: EditMode = .clip
    @Published private(set) var segments: [MacVideoTimelineSegment] = []
    @Published private(set) var selectedSegmentID: UUID?

    @Published private(set) var trayItems: [TrayItem] = []
    @Published var selectedTrayIndex: Int = 0

    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""

    // MARK: Init

    init(url: URL) {
        let a = AVURLAsset(url: url)
        self.asset = a
        self.player = AVPlayer(url: url)
        setupDuration(asset: a)
        setupTimeObserver()
    }

    // MARK: Setup

    private func setupDuration(asset: AVURLAsset) {
        Task { [weak self] in
            do {
                let dur = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(dur)
                guard let self, seconds.isFinite, seconds > 0 else { return }
                self.duration = seconds
                let segment = MacVideoTimelineSegment(startTime: 0, endTime: seconds)
                self.segments = [segment]
                self.selectedSegmentID = segment.id
            } catch {
                self?.statusMessage = "Could not read video duration"
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
                guard let self, !self.isScrubbing else { return }
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
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func beginScrubbing() {
        guard !isScrubbing else { return }
        isScrubbing = true
        player.pause()
        isPlaying = false
    }

    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        seek(to: currentTime)
    }

    func seek(to time: Double) {
        let clampedTime = max(0, min(duration, time))
        let t = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
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

        #if os(iOS)
        let thumbnail = await VideoTrimService.thumbnail(
            asset: asset,
            at: segment.startTime
        ) ?? UIImage()
        #elseif os(macOS)
        let thumbnail = await VideoTrimService.thumbnail(
            asset: asset,
            at: segment.startTime
        ) ?? NSImage()
        #endif

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

        if trayItems.isEmpty {
            selectedTrayIndex = 0
        } else if index < selectedTrayIndex {
            selectedTrayIndex -= 1
        } else {
            selectedTrayIndex = min(selectedTrayIndex, trayItems.count - 1)
        }
    }

    /// Move all media from the source card into the target card, then remove source.
    func mergeCards(sourceID: UUID, intoID targetID: UUID) {
        guard sourceID != targetID,
              let sourceIndex = trayItems.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = trayItems.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        trayItems[targetIndex].mediaList.append(contentsOf: trayItems[sourceIndex].mediaList)
        trayItems.remove(at: sourceIndex)
        let remainingTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        selectedTrayIndex = remainingTargetIndex
        statusMessage = "Media items grouped"
        scheduleStatusClear()
    }

    var selectedSegment: MacVideoTimelineSegment? {
        guard let selectedSegmentID else { return nil }
        return segments.first { $0.id == selectedSegmentID }
    }

    private func appendMedia(_ media: TrayMedia) {
        trayItems.append(TrayItem(mediaList: [media]))
        selectedTrayIndex = trayItems.count - 1
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
