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
    @Published private(set) var segments: [MacVideoTimelineSegment] = []

    private let minimumSegmentDuration = 0.25
    private let mediaLimit = 20
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

    func splitSegment(at time: Double) {
        guard duration >= minimumSegmentDuration * 2 else {
            message = "This video is too short to split."
            return
        }

        guard let index = segments.firstIndex(where: {
            time > $0.startTime + minimumSegmentDuration &&
                time < $0.endTime - minimumSegmentDuration
        }) else {
            message = "Place the playhead inside a segment to split it."
            return
        }

        let segment = segments[index]
        let splitTime = min(max(time, segment.startTime + minimumSegmentDuration), segment.endTime - minimumSegmentDuration)
        segments[index] = MacVideoTimelineSegment(
            id: segment.id,
            startTime: segment.startTime,
            endTime: splitTime
        )
        segments.insert(
            MacVideoTimelineSegment(startTime: splitTime, endTime: segment.endTime),
            at: index + 1
        )
        message = "Segment split at \(timeString(splitTime))."
    }

    func setBoundary(
        _ boundary: MacVideoTimelineSegment.Boundary,
        of segmentID: UUID,
        to time: Double
    ) {
        guard time.isFinite, let index = segments.firstIndex(where: { $0.id == segmentID }) else {
            message = "That timeline segment is no longer available."
            return
        }

        var segment = segments[index]
        switch boundary {
        case .start:
            let lowerBound = index == 0
                ? 0
                : segments[index - 1].startTime + minimumSegmentDuration
            let upperBound = segment.endTime - minimumSegmentDuration
            guard lowerBound <= upperBound else { return }
            let newBoundary = min(max(time, lowerBound), upperBound)
            segment.startTime = newBoundary
            segments[index] = segment
            if index > 0 {
                segments[index - 1].endTime = newBoundary
            }

        case .end:
            let lowerBound = segment.startTime + minimumSegmentDuration
            let upperBound = index == segments.count - 1
                ? duration
                : segments[index + 1].endTime - minimumSegmentDuration
            guard lowerBound <= upperBound else { return }
            let newBoundary = min(max(time, lowerBound), upperBound)
            segment.endTime = newBoundary
            segments[index] = segment
            if index < segments.count - 1 {
                segments[index + 1].startTime = newBoundary
            }
        }

        message = "Timeline boundary updated."
    }

    func removeSegment(id: UUID) {
        guard segments.count > 1, let index = segments.firstIndex(where: { $0.id == id }) else {
            message = segments.count <= 1
                ? "The timeline must keep one segment."
                : "That timeline segment is no longer available."
            return
        }

        if index > 0 {
            segments[index - 1].endTime = segments[index].endTime
        } else {
            segments[1].startTime = segments[0].startTime
        }
        segments.remove(at: index)
        message = "Timeline segment removed."
    }

    func addSegmentToTray(id: UUID) async {
        guard drafts.count < mediaLimit else {
            message = "A page can contain up to 20 media items."
            return
        }
        guard let segment = segments.first(where: { $0.id == id }) else {
            message = "That timeline segment is no longer available."
            return
        }
        guard !drafts.contains(where: { $0.sourceSegmentID == id }) else {
            message = "That segment is already in the media tray."
            return
        }

        let didStage = await stageSegment(segment)
        if didStage {
            message = "Clip added to the media tray."
        }
    }

    func addAllSegmentsToTray() async {
        let availableSegments = segments.filter { segment in
            !drafts.contains(where: { $0.sourceSegmentID == segment.id })
        }

        guard !availableSegments.isEmpty else {
            message = "All timeline segments are already in the media tray."
            return
        }
        guard drafts.count < mediaLimit else {
            message = "A page can contain up to 20 media items."
            return
        }

        var stagedCount = 0
        for segment in availableSegments where drafts.count < mediaLimit {
            if await stageSegment(segment) {
                stagedCount += 1
            }
        }

        if stagedCount > 0 {
            message = stagedCount == 1
                ? "1 clip added to the media tray."
                : "\(stagedCount) clips added to the media tray."
        }
        if drafts.count >= mediaLimit && availableSegments.count > stagedCount {
            message = "The media tray is full at 20 items."
        }
    }

    func addStill() async {
        guard drafts.count < mediaLimit else {
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

    func selectDraft(id: UUID) {
        guard let draft = drafts.first(where: { $0.id == id }) else { return }
        seek(to: draft.startTime)
    }

    func renameDraft(id: UUID, to name: String) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        drafts[index].displayName = trimmedName.isEmpty ? nil : trimmedName
    }

    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        message = drafts.isEmpty ? nil : "Media tray updated."
    }

    func markDraftSaved(id: UUID, targetLabel: String) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].isSaved = true
        drafts[index].savedTargetLabel = targetLabel
        message = "Saved \(drafts[index].title) to \(targetLabel)."
    }

    func stopPlayback() {
        player.pause()
        isPlaying = false
    }
    func reportMessage(_ text: String) {
        message = text
    }

    private func stageSegment(_ segment: MacVideoTimelineSegment) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        guard let thumbnail = await VideoTrimService.thumbnail(
            asset: asset,
            at: segment.startTime
        ) else {
            message = "Could not prepare that clip."
            return false
        }

        drafts.append(MacVideoDraft(
            kind: .clip,
            startTime: segment.startTime,
            endTime: segment.endTime,
            thumbnail: thumbnail,
            sourceSegmentID: segment.id
        ))
        return true
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
                self.currentTime = 0
                self.segments = [
                    MacVideoTimelineSegment(startTime: 0, endTime: seconds)
                ]
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
                self.currentTime = min(max(0, seconds), self.duration)
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

    private func timeString(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
#endif
