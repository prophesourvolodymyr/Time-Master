import AVFoundation
import UIKit
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

    // MARK: Published State

    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var mode: EditMode = .clip

    /// In-point for clip selection (seconds)
    @Published var inPoint: Double = 0
    /// Out-point for clip selection (seconds)
    @Published var outPoint: Double = 30

    /// Tray — starts with one empty card
    @Published var trayItems: [TrayItem] = [TrayItem()]
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
                self.outPoint = min(seconds, 30)
            } catch {
                print("VideoEditorViewModel: duration load error \(error)")
            }
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let t = CMTimeGetSeconds(time)
            if t.isFinite { self.currentTime = t }
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

    func seek(to time: Double) {
        let t = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func skipBackward() { seek(to: max(0, currentTime - 5)) }
    func skipForward()  { seek(to: min(duration, currentTime + 5)) }

    // MARK: Actions

    func captureScreenshot() async {
        isProcessing = true
        statusMessage = "Capturing…"
        if let img = await VideoTrimService.thumbnail(asset: asset, at: currentTime) {
            guard selectedTrayIndex < trayItems.count else {
                isProcessing = false; statusMessage = "No card selected"; return
            }
            trayItems[selectedTrayIndex].mediaList.append(.screenshot(img))
            statusMessage = "Screenshot added"
        } else {
            statusMessage = "Failed to capture"
        }
        isProcessing = false
        scheduleStatusClear()
    }

    func addClip() async {
        guard inPoint < outPoint else {
            statusMessage = "In-point must be before out-point"
            scheduleStatusClear()
            return
        }
        isProcessing = true
        statusMessage = "Extracting clip…"

        let thumb = await VideoTrimService.thumbnail(asset: asset, at: inPoint) ?? UIImage()

        guard selectedTrayIndex < trayItems.count else {
            isProcessing = false; statusMessage = "No card selected"; return
        }
        trayItems[selectedTrayIndex].mediaList.append(
            .clip(startTime: inPoint, endTime: outPoint, thumbnail: thumb)
        )
        statusMessage = "Clip added"
        isProcessing = false
        scheduleStatusClear()
    }

    // MARK: Tray Management

    func addNewCard() {
        trayItems.append(TrayItem())
        selectedTrayIndex = trayItems.count - 1
    }

    func removeCard(id: UUID) {
        guard trayItems.count > 1,
              let idx = trayItems.firstIndex(where: { $0.id == id }) else { return }
        trayItems.remove(at: idx)
        selectedTrayIndex = max(0, min(selectedTrayIndex, trayItems.count - 1))
    }

    /// Move all media from the source card into the target card, then remove source.
    func mergeCards(sourceID: UUID, intoID targetID: UUID) {
        guard sourceID != targetID,
              let srcIdx = trayItems.firstIndex(where: { $0.id == sourceID }),
              let dstIdx = trayItems.firstIndex(where: { $0.id == targetID }) else { return }
        trayItems[dstIdx].mediaList.append(contentsOf: trayItems[srcIdx].mediaList)
        trayItems.remove(at: srcIdx)
        selectedTrayIndex = max(0, min(selectedTrayIndex, trayItems.count - 1))
    }

    func seekToClip(in item: TrayItem) {
        if let t = item.firstClipStartTime { seek(to: t) }
    }

    // MARK: Helpers

    private func scheduleStatusClear() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !isProcessing { statusMessage = "" }
        }
    }
}
