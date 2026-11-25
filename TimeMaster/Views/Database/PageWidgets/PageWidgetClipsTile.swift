import SwiftUI
import AVFoundation
import Combine
import TimeMasterCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct PageWidgetClipsTile: View {
    let clips: PageWidgetClips
    let onOpen: (PageWidgetTarget) -> Void

    var body: some View {
        let cover = clips.total > 0 ? clips.cover : nil
        PageWidgetTile(
            kind: .clips,
            target: .attachments(index: clips.total > 0 ? clips.coverIndex : nil),
            summary: summary,
            art: cover == nil ? .clapperboard : nil,
            onOpen: onOpen
        ) {
            if let cover {
                filled(cover)
            } else if clips.total > 0 {
                countChip(overPicture: false)
                    .padding(PageWidgetMetrics.inset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
            } else {
                PageWidgetEmptyState(systemImage: nil, title: "No clips yet")
            }
        }
    }

    private func filled(_ cover: URL) -> some View {
        ZStack(alignment: .bottomLeading) {
            PageWidgetClipCover(url: cover)
            countChip(overPicture: true)
                .padding(10)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private func countChip(overPicture: Bool) -> some View {
        let symbol = clips.videos > 0 ? "play.fill" : (clips.photos > 0 ? "photo.fill" : "doc.fill")
        return WidgetChip(systemImage: symbol, text: "\(clips.total)", overPicture: overPicture)
    }

    private var summary: String {
        clips.total == 0 ? "Clips: none yet" : "Clips, \(clips.total): \(clips.breakdown)"
    }
}

/// The picture behind the Clips tile. A video plays its first seconds silently on a loop while the strip is revealed,
/// the tile shows on screen and the app is active, unless Reduce Motion, Low Power Mode or (iPhone) the system's video
/// autoplay setting says otherwise; until then, and instead, it shows its first frame. A photo shows as it is, any
/// other file as its symbol.
struct PageWidgetClipCover: View {
    let url: URL

    @Environment(\.pageWidgetRevealed) private var isRevealed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var loop = PageWidgetClipLoop()
    @State private var isVisible = true
    /// Bumped when Low Power Mode or the video autoplay setting changes, so the tile reads them again.
    @State private var settingsChanges = 0
    @State private var isShowingVideo = false

    private struct PlayKey: Equatable {
        let url: URL
        let plays: Bool
        let settingsChanges: Int
    }

    var body: some View {
        let kind = PageWidgetMedia.kind(of: url)
        let mayPlay = kind == .video && isRevealed && !reduceMotion && scenePhase == .active && isVisible
        let key = PlayKey(
            url: url,
            plays: mayPlay && PageWidgetClipLoop.systemAllowsAutoplay,
            settingsChanges: settingsChanges
        )
        ZStack {
            Theme.surface2
            switch kind {
            case .file:
                Image(systemName: ChecklistLook.symbol(forFile: url.lastPathComponent))
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            case .photo:
                PageWidgetPoster(url: url)
            case .video:
                PageWidgetPoster(url: url)
                if let player = loop.player {
                    PageWidgetVideoSurface(player: player)
                        .opacity(isShowingVideo ? 1 : 0)
                        .onReceive(player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main)) { status in
                            guard status == .playing, !isShowingVideo else { return }
                            withAnimation(.easeOut(duration: 0.25)) { isShowingVideo = true }
                        }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .modifier(PageWidgetVisibilityTracker(isVisible: $isVisible))
        .task(id: key) {
            if key.plays {
                await loop.play(key.url)
            } else {
                loop.pause()
            }
        }
        .onDisappear {
            loop.stop()
            isShowingVideo = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: DispatchQueue.main)) { _ in
            settingsChanges += 1
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.videoAutoplayStatusDidChangeNotification)) { _ in
            settingsChanges += 1
        }
        #endif
        .onChange(of: url) { _ in
            isShowingVideo = false
        }
    }
}

/// The silent loop behind a Clips tile: a video's first seconds, without its sound (so it never takes the audio from
/// anything else), played over and over.
@MainActor
final class PageWidgetClipLoop: ObservableObject {
    @Published private(set) var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var url: URL?
    /// Bumped by every start and stop, so a load that finishes after either is dropped.
    private var generation = 0

    /// Seconds of the clip the loop plays.
    static let length: Double = 8

    /// Whether the system lets a page play video by itself: not in Low Power Mode and, on iPhone, not with the video
    /// autoplay setting off.
    static var systemAllowsAutoplay: Bool {
        #if os(iOS)
        return UIAccessibility.isVideoAutoplayEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return !ProcessInfo.processInfo.isLowPowerModeEnabled
        #endif
    }

    func play(_ url: URL) async {
        if self.url == url, let player {
            player.play()
            return
        }
        stop()
        self.url = url
        let current = generation
        guard let item = await Self.silentItem(for: url), !Task.isCancelled, current == generation else { return }
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.allowsExternalPlayback = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        queue.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        generation += 1
        player?.pause()
        looper?.disableLooping()
        player?.removeAllItems()
        looper = nil
        player = nil
        url = nil
    }

    /// The first `length` seconds of the video's picture track alone, turned the way the video is filmed; nil for a
    /// file without one.
    private static func silentItem(for url: URL) async -> AVPlayerItem? {
        let asset = AVURLAsset(url: url)
        do {
            guard let source = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let duration = try await asset.load(.duration)
            let transform = try await source.load(.preferredTransform)
            let seconds = duration.isNumeric ? min(duration.seconds, length) : length
            guard seconds > 0.25 else { return nil }
            let composition = AVMutableComposition()
            guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                return nil
            }
            let range = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
            try track.insertTimeRange(range, of: source, at: .zero)
            track.preferredTransform = transform
            return AVPlayerItem(asset: composition)
        } catch {
            return nil
        }
    }
}

/// Keeps `isVisible` true while at least a third of the view shows in its scroll views (iOS 18 and macOS 15 tell;
/// earlier systems count it as visible all the time it is on the page).
struct PageWidgetVisibilityTracker: ViewModifier {
    @Binding var isVisible: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollVisibilityChange(threshold: 0.33) { visible in
                isVisible = visible
            }
        } else {
            content
        }
    }
}

#if os(iOS)
/// A player's picture filling its frame, cropped, with no controls and no touches.
struct PageWidgetVideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PageWidgetVideoLayerView {
        let view = PageWidgetVideoLayerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PageWidgetVideoLayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    static func dismantleUIView(_ view: PageWidgetVideoLayerView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}

final class PageWidgetVideoLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
#else
/// A player's picture filling its frame, cropped, with no controls and no clicks.
struct PageWidgetVideoSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PageWidgetVideoLayerView {
        let view = PageWidgetVideoLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ view: PageWidgetVideoLayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    static func dismantleNSView(_ view: PageWidgetVideoLayerView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}

final class PageWidgetVideoLayerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        playerLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#endif
