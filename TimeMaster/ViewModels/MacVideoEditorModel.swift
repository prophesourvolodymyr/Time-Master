#if os(macOS)
import AVFoundation
import Combine
import AppKit

@MainActor
final class MacVideoEditorModel: ObservableObject {
    let asset: AVURLAsset
    let player: AVPlayer

    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isProcessing = false
    @Published private(set) var message: String?
    @Published private(set) var frameRate: Double = 30
    @Published private(set) var timelineThumbnails: [Int: NSImage] = [:]
    @Published var savingWindowCount = 0
    @Published private(set) var drafts: [MacVideoDraft] = []
    var mediaCount: Int {
        drafts.reduce(0) { $0 + $1.mediaCount }
    }
    @Published private(set) var segments: [MacVideoTimelineSegment] = []
    var isBusy: Bool { isProcessing || savingWindowCount > 0 }

    private let minimumSegmentDuration = 0.25
    private let mediaLimit = 20
    private var isScrubbing = false
    private var wasPlayingBeforeScrubbing = false
    private var timeObserverToken: Any?
    private var playbackEndObserver: NSObjectProtocol?
    private var playbackFailureObserver: NSObjectProtocol?
    private var pendingSeek: (time: Double, resumePlayback: Bool)?
    private var isSeekInFlight = false
    private var activeSeekResumePlayback = false
    private var playbackGeneration = 0
    private var retainedSource: MacVideoSource?
    private var durationTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var thumbnailGenerator: AVAssetImageGenerator?
    private var requestedThumbnailFrames: [Int] = []
    private var thumbnailAccess: [Int: UInt64] = [:]
    private var thumbnailAccessSequence: UInt64 = 0
    private var playerStatusObserver: NSKeyValueObservation?
    private var hasReleasedResources = false

    convenience init(source: MacVideoSource) {
        self.init(url: source.url)
        retainedSource = source
    }

    init(url: URL) {
        asset = AVURLAsset(url: url)
        player = AVPlayer(url: url)
        observePlayback()
        playerStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) {
            [weak self] item, _ in
            guard item.status == .failed else { return }
            let error = item.error?.localizedDescription ?? "Tmax could not play this video."
            Task { @MainActor [weak self] in
                self?.pausePlayback()
                self?.message = error
            }
        }
        loadDuration()
    }

    deinit {
        durationTask?.cancel()
        thumbnailTask?.cancel()
        thumbnailGenerator?.cancelAllCGImageGeneration()
        player.pause()
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
        }
    }

    func togglePlayback() {
        guard duration > 0 else { return }

        if isPlaying {
            pausePlayback()
            return
        }

        if currentTime >= duration - 0.05 {
            isPlaying = true
            requestSeek(to: 0, resumePlayback: true)
        } else {
            player.play()
            isPlaying = true
        }
    }

    func beginScrubbing() {
        guard !isScrubbing else { return }
        isScrubbing = true
        wasPlayingBeforeScrubbing = isPlaying
        if isPlaying {
            player.pause()
            isPlaying = false
        }
    }

    func updateScrubPosition(_ seconds: Double) {
        guard isScrubbing else {
            seek(to: seconds)
            return
        }
        requestSeek(to: seconds, resumePlayback: false)
    }

    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        let shouldResumePlayback = wasPlayingBeforeScrubbing
        wasPlayingBeforeScrubbing = false
        requestSeek(to: currentTime, resumePlayback: shouldResumePlayback)
    }

    func seek(to seconds: Double) {
        requestSeek(to: seconds, resumePlayback: false)
    }

    @discardableResult
    private func requestSeek(to seconds: Double, resumePlayback: Bool) -> Double {
        let clampedTime = max(0, min(duration, seconds.isFinite ? seconds : 0))
        currentTime = clampedTime
        pendingSeek = (time: clampedTime, resumePlayback: resumePlayback)
        startNextSeekIfNeeded()
        return clampedTime
    }

    private func startNextSeekIfNeeded() {
        guard !isSeekInFlight, let pendingSeek else { return }
        self.pendingSeek = nil
        isSeekInFlight = true
        activeSeekResumePlayback = pendingSeek.resumePlayback
        let generation = playbackGeneration
        let time = CMTime(
            seconds: pendingSeek.time,
            preferredTimescale: 600
        )

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.playbackGeneration == generation else {
                    self.isSeekInFlight = false
                    self.activeSeekResumePlayback = false
                    self.startNextSeekIfNeeded()
                    return
                }
                self.isSeekInFlight = false
                if self.pendingSeek != nil {
                    self.startNextSeekIfNeeded()
                    return
                }
                guard self.activeSeekResumePlayback, !self.isScrubbing else { return }
                self.player.play()
                self.isPlaying = true
            }
        }
    }

    @discardableResult
    func splitSegment(at time: Double) -> UUID? {
        guard duration >= minimumSegmentDuration * 2 else {
            message = "This video is too short to split."
            return nil
        }

        guard let index = segments.firstIndex(where: {
            time > $0.startTime + minimumSegmentDuration &&
                time < $0.endTime - minimumSegmentDuration
        }) else {
            message = "Place the playhead inside a segment to split it."
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
        message = "Segment split at \(timeString(splitTime))."
        return newSegment.id
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
        guard mediaCount < mediaLimit else {
            message = "A page can contain up to 20 media items."
            return
        }
        guard let segment = segments.first(where: { $0.id == id }) else {
            message = "That timeline segment is no longer available."
            return
        }
        guard !drafts.contains(where: { draft in
            draft.mediaItems.contains { $0.sourceSegmentID == id }
        }) else {
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
            !drafts.contains { draft in
                draft.mediaItems.contains { $0.sourceSegmentID == segment.id }
            }
        }

        guard !availableSegments.isEmpty else {
            message = "All timeline segments are already in the media tray."
            return
        }
        guard mediaCount < mediaLimit else {
            message = "A page can contain up to 20 media items."
            return
        }

        var stagedCount = 0
        for segment in availableSegments where mediaCount < mediaLimit {
            if await stageSegment(segment) {
                stagedCount += 1
            }
        }

        if stagedCount > 0 {
            message = stagedCount == 1
                ? "1 clip added to the media tray."
                : "\(stagedCount) clips added to the media tray."
        }
        if mediaCount >= mediaLimit && availableSegments.count > stagedCount {
            message = "The media tray is full at 20 items."
        }
    }

    func addStill() async {
        guard mediaCount < mediaLimit else {
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

    func mergeDrafts(sourceID: UUID, intoID targetID: UUID) {
        mergeDrafts(sourceIDs: [sourceID], intoID: targetID)
    }

    func mergeDrafts(sourceIDs: Set<UUID>, intoID targetID: UUID) {
        let sources = drafts.filter { sourceIDs.contains($0.id) && $0.id != targetID }
        guard !sources.isEmpty,
              let targetIndex = drafts.firstIndex(where: { $0.id == targetID }) else { return }
        drafts[targetIndex].append(media: sources.flatMap(\.mediaItems))
        drafts[targetIndex].isSaved = false
        drafts[targetIndex].savedTargetLabel = nil
        let mergedIDs = Set(sources.map(\.id))
        drafts.removeAll { mergedIDs.contains($0.id) }
        message = "Media items grouped."
    }

    func ungroupDraft(id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }),
              drafts[index].mediaCount > 1 else { return }
        let draft = drafts[index]
        drafts[index].groupedMedia = []
        let separated = draft.groupedMedia.map { media in
            MacVideoDraft(
                id: media.id,
                kind: media.kind,
                startTime: media.startTime,
                endTime: media.endTime,
                thumbnail: media.thumbnail,
                sourceSegmentID: media.sourceSegmentID,
                isSaved: draft.isSaved,
                savedTargetLabel: draft.savedTargetLabel
            )
        }
        drafts.insert(contentsOf: separated, at: index + 1)
        message = "Media stack separated."
    }

    func markDraftSaved(id: UUID, targetLabel: String) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].isSaved = true
        drafts[index].savedTargetLabel = targetLabel
        message = "Saved \(drafts[index].title) to \(targetLabel)."
    }

    func pausePlayback() {
        activeSeekResumePlayback = false
        wasPlayingBeforeScrubbing = false
        if let pendingSeek {
            self.pendingSeek = (time: pendingSeek.time, resumePlayback: false)
        }
        player.pause()
        isPlaying = false
    }

    func stopPlayback() {
        playbackGeneration &+= 1
        pendingSeek = nil
        isScrubbing = false
        wasPlayingBeforeScrubbing = false
        activeSeekResumePlayback = false
        player.pause()
        isPlaying = false
    }

    func requestTimelineThumbnails(frames: [Int]) {
        let frames = Array(frames.prefix(160))
        guard frames != requestedThumbnailFrames, !hasReleasedResources else { return }
        cancelTimelineThumbnails()
        requestedThumbnailFrames = frames
        thumbnailAccess = thumbnailAccess.filter { timelineThumbnails[$0.key] != nil || frames.contains($0.key) }
        let missing = frames.filter { timelineThumbnails[$0] == nil }
        for frame in frames {
            thumbnailAccessSequence &+= 1
            thumbnailAccess[frame] = thumbnailAccessSequence
        }
        guard !missing.isEmpty else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 192, height: 128)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        thumbnailGenerator = generator
        let rate = frameRate
        let lastTime = max(0, duration - 1 / rate)
        thumbnailTask = Task { [weak self] in
            for frame in missing {
                guard !Task.isCancelled else { return }
                let time = CMTime(seconds: min(Double(frame) / rate, lastTime), preferredTimescale: 60_000)
                guard let (image, _) = try? await generator.image(at: time) else { continue }
                guard !Task.isCancelled, let self else { return }
                if self.timelineThumbnails.count >= 160,
                   let oldest = self.thumbnailAccess
                    .filter({ self.timelineThumbnails[$0.key] != nil && !frames.contains($0.key) })
                    .min(by: { $0.value < $1.value })?.key {
                    self.timelineThumbnails.removeValue(forKey: oldest)
                    self.thumbnailAccess.removeValue(forKey: oldest)
                }
                self.timelineThumbnails[frame] = NSImage(cgImage: image, size: .zero)
            }
        }
    }

    func cancelTimelineThumbnails() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        thumbnailGenerator?.cancelAllCGImageGeneration()
        thumbnailGenerator = nil
        requestedThumbnailFrames = []
    }

    func releaseResources() {
        guard !hasReleasedResources else { return }
        hasReleasedResources = true
        stopPlayback()
        durationTask?.cancel()
        durationTask = nil
        cancelTimelineThumbnails()
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        for observer in [playbackEndObserver, playbackFailureObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        playbackEndObserver = nil
        playbackFailureObserver = nil
        player.replaceCurrentItem(with: nil)
        timelineThumbnails.removeAll()
        retainedSource = nil
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
        durationTask = Task { [weak self, asset] in
            do {
                let loadedDuration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(loadedDuration)
                var loadedFrameRate: Double = 30
                if let track = try? await asset.loadTracks(withMediaType: .video).first,
                   let nominalRate = try? await track.load(.nominalFrameRate),
                   nominalRate.isFinite, nominalRate > 0 {
                    loadedFrameRate = Double(nominalRate)
                }
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard seconds.isFinite, seconds > 0 else {
                    self.message = "This video has no playable duration."
                    return
                }
                self.duration = seconds
                self.frameRate = loadedFrameRate
                self.currentTime = 0
                self.segments = [
                    MacVideoTimelineSegment(startTime: 0, endTime: seconds)
                ]
            } catch {
                self?.message = "Tmax could not read this video."
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
            MainActor.assumeIsolated {
                guard let self,
                      seconds.isFinite,
                      !self.isScrubbing,
                      !self.isSeekInFlight,
                      self.pendingSeek == nil else { return }
                self.currentTime = min(max(0, seconds), self.duration)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.duration
                self.isPlaying = false
            }
        }

        playbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.player.pause()
                self?.isPlaying = false
                self?.message = "Tmax could not play this video."
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
#endif
