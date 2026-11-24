import AVFoundation
import SwiftUI

@MainActor
final class QuickPreviewVideoModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isShowing = false
    @Published private(set) var failed = false
    @Published private(set) var aspect: CGFloat?

    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var shapeTask: Task<Void, Never>?

    func start(_ url: URL) {
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none
        self.player = player
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                guard let self, self.player?.currentItem === item else { return }
                self.failed = true
                self.isShowing = false
            }
        }
        rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observed, _ in
            guard observed.timeControlStatus == .playing else { return }
            DispatchQueue.main.async {
                guard let self, self.player === observed, !self.failed else { return }
                self.isShowing = true
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        shapeTask = Task { [weak self] in
            let shape = await Self.shape(of: url)
            guard !Task.isCancelled else { return }
            self?.aspect = shape
        }
        player.play()
    }

    func toggle() {
        guard let player, !failed else { return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func stop() {
        shapeTask?.cancel()
        shapeTask = nil
        statusObservation = nil
        rateObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        isShowing = false
        failed = false
        aspect = nil
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    private nonisolated static func shape(of url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return nil }
        let drawn = CGRect(origin: .zero, size: size).applying(transform)
        guard drawn.width > 1, drawn.height > 1 else { return nil }
        return abs(drawn.width) / abs(drawn.height)
    }
}

struct QuickPreviewVideo: View {
    let url: URL
    @Binding var aspect: CGFloat
    @StateObject private var model = QuickPreviewVideoModel()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AsyncCoverImage(url: url, height: proxy.size.height, contentMode: .fit, overlayGradient: false)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                if let player = model.player {
                    MediaPlayerSurface(player: player)
                        .opacity(model.isShowing ? 1 : 0)
                }
                if model.failed {
                    failureNote
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { model.toggle() }
        }
        .onAppear { model.start(url) }
        .onDisappear { model.stop() }
        .onChange(of: model.aspect) { shape in
            if let shape { aspect = shape }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exercise video")
        .accessibilityHint("Tap to pause or play")
    }

    private var failureNote: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("This clip can't play here")
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.65)))
            .padding(.bottom, 10)
        }
    }
}
