import AVFoundation
import Combine
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Plays one video inside its media card (`MediaStrip`): a click plays or pauses it there, a double click opens the
/// page's in-place viewer (`PageMediaGallery`), which continues the same player from the same moment.
final class MediaInlinePlayback: ObservableObject {
    @Published private(set) var url: URL?
    @Published private(set) var isPlaying = false
    /// Changes when the card has to draw the player again (the viewer showed it in between).
    @Published private(set) var surfaceEpoch = 0
    private(set) var player: AVPlayer?
    /// Playback position of the card's video; only its progress line observes it.
    let progress = MediaInlineProgress()

    private var revision = 0
    private var statusObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var revisionObserver: AnyCancellable?
    private var lastClick: (url: URL, time: TimeInterval)?
    private var cardFrames: [URL: CGRect] = [:]
    private var containerFrame: CGRect = .zero

    static var doubleClickInterval: TimeInterval {
        #if os(macOS)
        return NSEvent.doubleClickInterval
        #else
        return 0.35
        #endif
    }

    init() {
        revisionObserver = MediaRevisions.shared.$values
            .dropFirst()
            .sink { [weak self] values in
                DispatchQueue.main.async { self?.dropIfRewritten(values) }
            }
    }

    deinit {
        tearDown()
    }

    /// Plays `url` here, or pauses it when it is the one playing.
    func toggle(_ url: URL) {
        if let player = player(for: url) {
            if player.timeControlStatus == .paused { resume(player) } else { player.pause() }
        } else {
            start(url)
        }
    }

    /// Plays `url` here (continuing it when it is the current one).
    func play(_ url: URL) {
        if let player = player(for: url) { resume(player) } else { start(url) }
    }

    func pause() {
        player?.pause()
    }

    /// The player of `url` when it is the card's current video.
    func player(for url: URL) -> AVPlayer? {
        self.url == url && revision == MediaRevisions.shared.revision(of: url) ? self.player : nil
    }

    func stop() {
        tearDown()
        url = nil
        isPlaying = false
        progress.value = 0
    }

    /// Makes the card build its player layer again, so it shows the video after the viewer drew it.
    func redrawSurface() {
        surfaceEpoch &+= 1
    }

    /// Counts a click on a card; true when it completes a double click on the same card.
    func registerClick(on url: URL) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastClick, last.url == url, now - last.time <= Self.doubleClickInterval {
            lastClick = nil
            return true
        }
        lastClick = (url, now)
        return false
    }

    func setCardFrame(_ frame: CGRect, for url: URL) {
        cardFrames[url] = frame
    }

    func removeCardFrame(for url: URL) {
        cardFrames[url] = nil
    }

    func setContainerFrame(_ frame: CGRect) {
        containerFrame = frame
    }

    /// Size of the view that hosts the in-place viewer.
    var containerSize: CGSize { containerFrame.size }

    /// The card of `url` in the coordinates of the view that hosts the viewer; nil when it is not on screen.
    func cardRect(for url: URL) -> CGRect? {
        guard let frame = cardFrames[url], containerFrame.width > 0, containerFrame.height > 0 else { return nil }
        let rect = frame.offsetBy(dx: -containerFrame.minX, dy: -containerFrame.minY)
        return CGRect(origin: .zero, size: containerFrame.size).intersects(rect) ? rect : nil
    }

    private func resume(_ player: AVPlayer) {
        if let item = player.currentItem, item.duration.isNumeric,
           item.currentTime().seconds >= item.duration.seconds - 0.05 {
            player.seek(to: .zero)
        }
        player.play()
    }

    private func start(_ url: URL) {
        tearDown()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        self.player = player
        self.url = url
        revision = MediaRevisions.shared.revision(of: url)
        progress.value = 0
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            let playing = observed.timeControlStatus != .paused
            DispatchQueue.main.async {
                guard let self, self.player === observed, self.isPlaying != playing else { return }
                self.isPlaying = playing
            }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: .main
        ) { [weak self, weak player] time in
            guard let self, let duration = player?.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            let value = min(1, max(0, time.seconds / duration))
            if abs(self.progress.value - value) > 0.001 { self.progress.value = value }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
        }
        player.play()
    }

    private func tearDown() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let player {
            if let timeObserver { player.removeTimeObserver(timeObserver) }
            player.pause()
        }
        timeObserver = nil
        player = nil
    }

    private func dropIfRewritten(_ values: [URL: Int]) {
        guard let url, (values[url.standardizedFileURL] ?? 0) != revision else { return }
        stop()
    }
}

/// Playback position (0...1) of the video playing in a card.
final class MediaInlineProgress: ObservableObject {
    @Published var value: Double = 0
}

/// Content revisions of media files rewritten in place (a trim keeps the file name, so the page's order, notes and
/// links stay). Views showing a file key their picture or player with its revision, so they load the new content.
final class MediaRevisions: ObservableObject {
    static let shared = MediaRevisions()
    @Published private(set) var values: [URL: Int] = [:]

    private init() {}

    func revision(of url: URL) -> Int {
        values[url.standardizedFileURL] ?? 0
    }

    func bump(_ url: URL) {
        PhotoManager.shared.clearCache()
        values[url.standardizedFileURL, default: 0] += 1
    }
}

/// One entry of a media card's menu (its ellipsis button and context menu).
struct MediaCardAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let perform: () -> Void

    init(_ title: String, systemImage: String, role: ButtonRole? = nil, perform: @escaping () -> Void) {
        id = title
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.perform = perform
    }
}

/// A player layer without controls that never takes a click or a touch: the card or page under it keeps them.
#if os(iOS)
struct MediaPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ view: SurfaceView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        if view.playerLayer.videoGravity != gravity { view.playerLayer.videoGravity = gravity }
    }

    static func dismantleUIView(_ view: SurfaceView, coordinator: ()) {
        view.playerLayer.player = nil
    }

    final class SurfaceView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#else
struct MediaPlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeNSView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = gravity
        return view
    }

    func updateNSView(_ view: SurfaceView, context: Context) {
        guard let layer = view.playerLayer else { return }
        if layer.player !== player { layer.player = player }
        if layer.videoGravity != gravity { layer.videoGravity = gravity }
    }

    static func dismantleNSView(_ view: SurfaceView, coordinator: ()) {
        view.playerLayer?.player = nil
    }

    final class SurfaceView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }

        override func makeBackingLayer() -> CALayer { AVPlayerLayer() }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }
}
#endif

/// An in-place media viewer: the panel it opens with and the card it grows out of.
struct MediaViewerPresentation {
    var opensEditor: Bool
    /// The card, in the coordinates of the view the viewer fills; nil when the card is not on screen.
    var source: CGRect?
    var container: CGSize
}

extension AnyTransition {
    /// The viewer grows out of the card at `source` (in the coordinates of the `container` it fills) and shrinks back
    /// into it. Only transforms and a clip animate, so the viewer is never laid out again while it moves.
    static func mediaExpand(from source: CGRect?, in container: CGSize) -> AnyTransition {
        .modifier(
            active: MediaExpandEffect(progress: 0, source: source, container: container),
            identity: MediaExpandEffect(progress: 1, source: source, container: container)
        )
    }
}

private struct MediaExpandEffect: ViewModifier, Animatable {
    var progress: CGFloat
    let source: CGRect?
    let container: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let fraction = min(1, max(0, progress))
        let width = max(container.width, 1)
        let height = max(container.height, 1)
        let card: CGRect? = source.flatMap { $0.width > 1 && $0.height > 1 ? $0 : nil }
        let start: CGFloat = card.map { min(1, max($0.width / width, $0.height / height)) } ?? 0.9
        let startSize = card.map { CGSize(width: $0.width / start, height: $0.height / start) }
            ?? CGSize(width: width, height: height)
        let shift = card.map { CGSize(width: $0.midX - width / 2, height: $0.midY - height / 2) } ?? .zero
        content
            .clipShape(MediaExpandClip(
                startSize: startSize,
                fraction: fraction,
                cornerRadius: card == nil ? 0 : 18 / start * (1 - fraction)
            ))
            .scaleEffect(start + (1 - start) * fraction)
            .offset(x: shift.width * (1 - fraction), y: shift.height * (1 - fraction))
            .opacity(card == nil ? Double(fraction) : 1)
    }
}

/// A rounded rectangle centred in the clipped view, growing from `startSize` to the view's bounds as `fraction`
/// goes from 0 to 1 (at 1 it is exactly the bounds, whatever size the view has by then).
private struct MediaExpandClip: Shape {
    var startSize: CGSize
    var fraction: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = startSize.width + (rect.width - startSize.width) * fraction
        let height = startSize.height + (rect.height - startSize.height) * fraction
        let clip = CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
        return Path(roundedRect: clip, cornerRadius: max(0, cornerRadius), style: .continuous)
    }
}
