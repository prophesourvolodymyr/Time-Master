import SwiftUI
import AVKit

struct WorkoutMediaPager: View {
    let entries: [WorkoutMediaEntry]
    let comments: [URL: String]
    @Binding var index: Int
    let onOpen: (Int) -> Void
    let onSwipeUp: (Int) -> Void
    let isPaused: Bool
    @State private var position: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let dotsHeight: CGFloat = entries.count > 1 ? 24 : 0
            let hintHeight: CGFloat = 20
            let cardHeight = max(140, min(proxy.size.height - dotsHeight - hintHeight - 16, 380))
            let cardWidth = min(max(140, proxy.size.width - 64), cardHeight * 0.9)
            VStack(spacing: 8) {
                pager(cardWidth: cardWidth, cardHeight: cardHeight, container: proxy.size.width)
                    .frame(height: cardHeight)
                if entries.count > 1 {
                    pageControls
                }
                Label("Swipe up for notes", systemImage: "chevron.up")
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(.white.opacity(0.45))
                    .labelStyle(.titleAndIcon)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 440)
        .layoutPriority(1)
        .onAppear { position = clampedIndex }
        .onChange(of: entries.count) { _ in
            if index >= entries.count { index = max(0, entries.count - 1) }
        }
    }

    private var clampedIndex: Int {
        entries.isEmpty ? 0 : min(max(0, index), entries.count - 1)
    }

    @ViewBuilder
    private func pager(cardWidth: CGFloat, cardHeight: CGFloat, container: CGFloat) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            modernPager(cardWidth: cardWidth, cardHeight: cardHeight, container: container)
        } else {
            legacyPager(cardWidth: cardWidth, cardHeight: cardHeight)
        }
        #else
        modernPager(cardWidth: cardWidth, cardHeight: cardHeight, container: container)
        #endif
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func modernPager(cardWidth: CGFloat, cardHeight: CGFloat, container: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(entries.indices, id: \.self) { i in
                    card(i, width: cardWidth, height: cardHeight)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (container - cardWidth) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position)
        .scrollClipDisabled()
        .onChange(of: position) { _, newValue in
            if let newValue, newValue != index { index = newValue }
        }
        .onChange(of: index) { _, newValue in
            if position != newValue {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { position = newValue }
            }
        }
    }

    #if os(iOS)
    private func legacyPager(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        TabView(selection: $index) {
            ForEach(entries.indices, id: \.self) { i in
                card(i, width: cardWidth, height: cardHeight)
                    .frame(maxWidth: .infinity)
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    #endif

    private func card(_ i: Int, width: CGFloat, height: CGFloat) -> some View {
        let entry = entries[i]
        let isActive = i == index
        return ZStack {
            AsyncCoverImage(
                url: entry.url,
                fallbackIcon: entry.isVideo ? "play.rectangle.fill" : "photo",
                fallbackColor: entry.isVideo ? Theme.toolbarOrange : nil,
                height: height,
                contentMode: .fill,
                overlayGradient: false
            )
            .frame(width: width, height: height)
            if entry.isVideo {
                if isActive {
                    WorkoutLoopingVideo(url: entry.url, isPaused: isPaused)
                        .frame(width: width, height: height)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if entries.count > 1 {
                Text("\(i + 1)/\(entries.count)")
                    .font(TimeMasterFont.black(11, relativeTo: .caption2).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if comments[entry.url] != nil {
                Image(systemName: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.65), in: Circle())
                    .padding(12)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { onOpen(i) }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 24), action: { onOpen(i) })
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dy = value.translation.height
                    if dy < -64, abs(dy) > abs(value.translation.width) * 1.4 { onSwipeUp(i) }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.isVideo ? "Video" : "Photo") \(i + 1) of \(entries.count)")
        .accessibilityHint("Opens the media viewer")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Open notes") { onSwipeUp(i) }
    }

    private var pageControls: some View {
        HStack(spacing: 12) {
            #if os(macOS)
            stepButton("chevron.left", label: "Previous media", enabled: index > 0) { index = max(0, index - 1) }
            #endif
            HStack(spacing: 5) {
                ForEach(entries.indices, id: \.self) { i in
                    let active = i == index
                    Capsule()
                        .fill(active ? Color.white : Color.white.opacity(0.35))
                        .frame(
                            width: entries[i].isVideo ? (active ? 18 : 12) : (active ? 7 : 5),
                            height: active ? 7 : 5
                        )
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: index)
                }
            }
            #if os(macOS)
            stepButton("chevron.right", label: "Next media", enabled: index < entries.count - 1) { index = min(entries.count - 1, index + 1) }
            #endif
        }
        .accessibilityHidden(true)
    }

    #if os(macOS)
    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.16), in: Circle())
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
    #endif
}

private struct WorkoutLoopingVideo: View {
    let url: URL
    let isPaused: Bool
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let player {
                WorkoutVideoSurface(player: player)
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .onAppear { start() }
        .onChange(of: isPaused) { paused in
            if paused { player?.pause() } else { player?.play() }
        }
        .onDisappear { stop() }
    }

    private func start() {
        guard player == nil, FileManager.default.fileExists(atPath: url.path) else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(items: [item])
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        if !isPaused { queue.play() }
    }

    private func stop() {
        player?.pause()
        player?.removeAllItems()
        looper = nil
        player = nil
    }
}

#if os(iOS)
private struct WorkoutVideoSurface: View {
    let player: AVPlayer

    var body: some View {
        PlayerLayerView(player: player, gravity: .resizeAspectFill)
    }
}
#else
private struct WorkoutVideoSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: SurfaceView, context: Context) {
        if nsView.playerLayer.player !== player { nsView.playerLayer.player = player }
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

        var playerLayer: AVPlayerLayer {
            guard let layer = layer as? AVPlayerLayer else {
                let created = AVPlayerLayer()
                self.layer = created
                return created
            }
            return layer
        }
    }
}
#endif
