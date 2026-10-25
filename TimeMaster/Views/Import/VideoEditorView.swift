import SwiftUI
import AVFoundation

// MARK: - VideoEditorView

struct VideoEditorView: View {
    @StateObject private var vm: VideoEditorViewModel
    let onClose: () -> Void

    @State private var showBatchConfirm = false
    @State private var previewItem: IdentifiableMedia? = nil
    @Environment(\.scenePhase) private var scenePhase

    init(videoURL: URL, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: VideoEditorViewModel(url: videoURL))
        self.onClose = onClose
    }

    init(model: VideoEditorViewModel, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: model)
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerBar
                videoWithOverlays
                    .frame(height: geometry.size.height * 0.42)
                ScrollView {
                    VStack(spacing: 16) {
                        playbackControls
                        timeAndScrubber
                        controlsRow
                        traySectionView
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showBatchConfirm) {
            batchConfirmSheet
        }
        .sheet(item: $previewItem) { wrapped in
            MediaPreviewOverlay(media: wrapped.media, asset: vm.asset) {
                previewItem = nil
            }
        }
        .onDisappear { vm.stopPlayback() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { vm.stopPlayback() }
        }
        .onChange(of: showBatchConfirm) { if $0 { vm.stopPlayback() } }
        .onChange(of: previewItem?.id) { if $0 != nil { vm.stopPlayback() } }
    }

    // MARK: - Batch Sheet

    private var batchConfirmSheet: some View {
        BatchConfirmView(
            vm: vm,
            onPreview: { time in
                showBatchConfirm = false
                vm.seek(to: time)
            },
            onComplete: {
                showBatchConfirm = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onClose() }
            }
        )
    }

    // MARK: - Video + Overlays

    private var videoWithOverlays: some View {
        ZStack {
            Button(action: vm.togglePlayPause) {
                ZStack {
                    #if os(iOS)
                    PlayerLayerView(player: vm.player, gravity: .resizeAspect)
                    #else
                    MacVideoPlayerView(player: vm.player)
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vm.isPlaying ? "Pause video preview" : "Play video preview")
            .disabled(vm.duration == 0 || vm.playbackError != nil)

            if let error = vm.playbackError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding()
            } else if vm.duration == 0 || vm.isProcessing {
                TmaxLoadingState(title: vm.isProcessing ? "Preparing media…" : "Loading video…")
                    .allowsHitTesting(false)
            }
        }
        .background(.black)
        .clipped()
    }

    private var headerBar: some View {
        HStack {
            Button {
                vm.stopPlayback()
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            Spacer()
            TimeMasterPageTitle("Edit Video", size: 22, relativeTo: .headline)
                .foregroundColor(.white)
            Spacer()
            reviewButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var reviewButton: some View {
        let hasMedia = vm.trayItems.contains { !$0.mediaList.isEmpty }
        return Button {
            showBatchConfirm = true
        } label: {
            Text("Review \(vm.mediaCount)")
                .font(TimeMasterFont.rowTitle())
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
        .disabled(!hasMedia || vm.isProcessing)
    }

    // MARK: - Time Labels + Scrubber

    private var timeAndScrubber: some View {
        VStack(spacing: 0) {
            timeLabelsRow
            VideoScrubberView(
                currentTime: $vm.currentTime,
                segments: vm.segments,
                selectedSegmentID: vm.selectedSegmentID,
                duration: vm.duration,
                thumbnails: vm.timelineThumbnails,
                onSelectSegment: vm.selectSegment,
                onSeek: vm.seek,
                onScrubBegan: vm.beginScrubbing,
                onScrubEnded: vm.endScrubbing
            )
            .frame(height: 84)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var timeLabelsRow: some View {
        HStack {
            Text(formatTime(vm.currentTime))
                .font(TimeMasterFont.technical())
                .foregroundColor(Theme.textPrimary)
            if let segment = vm.selectedSegment {
                Text("  ·  \(formatTime(segment.startTime)) → \(formatTime(segment.endTime))")
                    .font(TimeMasterFont.technical())
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Text(formatTime(vm.duration))
                .font(TimeMasterFont.technical())
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        VStack(spacing: 12) {
            modeToggle
            actionButtonsSection
        }
        .padding(.horizontal, 16)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(label: "Clips", selected: vm.mode == .clip) { vm.mode = .clip }
            modeButton(label: "Stills", selected: vm.mode == .screenshot) { vm.mode = .screenshot }
        }
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button(action: vm.skipBackward) {
                Label("Back 5 seconds", systemImage: "gobackward.5")
                    .frame(minWidth: 44, minHeight: 44)
            }
            Button(action: vm.togglePlayPause) {
                Label(vm.isPlaying ? "Pause" : "Play", systemImage: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(Theme.surface2, in: Circle())
            }
            Button(action: vm.skipForward) {
                Label("Forward 5 seconds", systemImage: "goforward.5")
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(Theme.textPrimary)
        .disabled(vm.duration == 0 || vm.playbackError != nil)
    }

    private func modeButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TimeMasterFont.rowTitle())
                .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Theme.surface2 : Color.clear)
                .cornerRadius(7)
        }
        .padding(2)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtonsSection: some View {
        if vm.mode == .clip {
            clipActions
        } else {
            screenshotAction
        }
    }

    private var clipActions: some View {
        HStack(spacing: 10) {
            actionBtn(
                "Split",
                icon: "scissors",
                disabled: !vm.canSplit(at: vm.currentTime)
            ) {
                vm.splitSegment(at: vm.currentTime)
            }
            actionBtn("Add Clip", icon: "plus.circle") {
                Task { await vm.addClip() }
            }
        }
        .padding(.vertical, 6)
    }

    private var screenshotAction: some View {
        HStack {
            actionBtn("Capture Still", icon: "camera") {
                Task { await vm.captureScreenshot() }
            }
        }
        .padding(.vertical, 6)
    }

    private func actionBtn(
        _ label: String,
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(label).font(TimeMasterFont.rowTitle())
            }
            .foregroundColor(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(vm.isProcessing || disabled || vm.duration == 0 || vm.playbackError != nil)
    }

    // MARK: - Tray

    private var traySectionView: some View {
        VStack(alignment: .leading, spacing: 6) {
            trayHeader
            trayScrollRow
        }
        .padding(.bottom, 16)
        .background(Theme.surface)
    }

    private var trayHeader: some View {
        HStack(spacing: 8) {
            Text("MEDIA TRAY")
                .font(TimeMasterFont.black(12, relativeTo: .caption)).tracking(1)
                .foregroundColor(Theme.textSecondary)
            Text("\(vm.mediaCount) / 20")
                .font(TimeMasterFont.caption().monospacedDigit())
                .foregroundColor(Theme.textSecondary)
            if !vm.statusMessage.isEmpty {
                Text("· \(vm.statusMessage)")
                    .font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
            } else if vm.trayItems.count > 1 {
                Text("· Drag media onto another to group")
                    .font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var trayScrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if vm.trayItems.isEmpty {
                    Text("Add a clip or still to start")
                        .font(TimeMasterFont.caption())
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 90)
                } else {
                    ForEach(Array(vm.trayItems.enumerated()), id: \.element.id) { idx, item in
                        TrayCardView(
                            item: item,
                            isSelected: idx == vm.selectedTrayIndex,
                            onSelect: { vm.selectedTrayIndex = idx },
                            onRemove: { vm.removeCard(id: item.id) },
                            onMerge: { srcID in vm.mergeCards(sourceID: srcID, intoID: item.id) },
                            onPreview: { media in previewItem = IdentifiableMedia(media: media) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }


    // MARK: - Helpers


    private func formatTime(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d.%01d", t / 60, t % 60, Int(s * 10) % 10)
    }
}

// MARK: - IdentifiableMedia

private struct IdentifiableMedia: Identifiable {
    let id = UUID()
    let media: TrayMedia
}

// MARK: - MediaPreviewOverlay

private struct MediaPreviewOverlay: View {
    let media: TrayMedia
    let asset: AVURLAsset
    let onClose: () -> Void

    @State private var clipPlayer: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mediaContent
            closeOverlay
        }
        .task { await setupClipPlayer() }
        .onDisappear { clipPlayer?.pause(); clipPlayer = nil }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if case .screenshot(let img) = media {
            #if os(iOS)
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #elseif os(macOS)
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        } else if let player = clipPlayer {
            #if os(iOS)
            PlayerLayerView(player: player, gravity: .resizeAspect)
                .ignoresSafeArea()
            #elseif os(macOS)
            MacVideoPlayerView(player: player)
                .aspectRatio(contentMode: .fit)
            #endif
        } else if case .clip = media {
            TmaxLoadingState(title: "Loading video…")
                .allowsHitTesting(false)
        }
    }

    private var closeOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(20)
                }
            }
            Spacer()
        }
    }

    private func setupClipPlayer() async {
        guard case .clip(let start, let end, _) = media else { return }
        let item = AVPlayerItem(asset: asset)
        item.forwardPlaybackEndTime = CMTime(seconds: end, preferredTimescale: 600)
        let player = AVPlayer(playerItem: item)
        let t = CMTime(seconds: start, preferredTimescale: 600)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                cont.resume()
            }
        }
        clipPlayer = player
        player.play()
    }
}

#if os(iOS)
// MARK: - PlayerLayerView (UIViewRepresentable — hides native VideoPlayer controls)

final class PlayerBackingView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerBackingView {
        let v = PlayerBackingView()
        v.backgroundColor = .black
        v.playerLayer.player = player
        v.playerLayer.videoGravity = gravity
        return v
    }

    func updateUIView(_ uiView: PlayerBackingView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        uiView.playerLayer.videoGravity = gravity
    }
}
#endif

// MARK: - VideoScrubberView

private struct VideoScrubberView: View {
    @Binding var currentTime: Double
    let segments: [MacVideoTimelineSegment]
    let selectedSegmentID: UUID?
    let duration: Double
    let thumbnails: [PhotoPlatformImage]
    let onSelectSegment: (UUID) -> Void
    let onSeek: (Double) -> Void
    let onScrubBegan: () -> Void
    let onScrubEnded: () -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let height = geo.size.height
            let playheadX = duration > 0
                ? width * CGFloat(max(0, min(duration, currentTime)) / duration)
                : 0

            ZStack(alignment: .topLeading) {
                if duration > 0 {
                    HStack(spacing: 0) {
                        ForEach(thumbnails.indices, id: \.self) { index in
                            Group {
                                #if os(iOS)
                                Image(uiImage: thumbnails[index]).resizable()
                                #else
                                Image(nsImage: thumbnails[index]).resizable()
                                #endif
                            }
                            .scaledToFill()
                            .frame(width: width / CGFloat(max(1, thumbnails.count)), height: height * 0.6)
                            .clipped()
                        }
                    }
                    .frame(width: width, height: height * 0.6)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(y: height * 0.3)

                    ForEach(0..<5) { index in
                        let fraction = Double(index) / 4
                        Text(formatTimelineTime(duration * fraction))
                            .font(TimeMasterFont.micro().monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .position(x: width * fraction, y: height * 0.12)
                    }

                    ForEach(segments) { segment in
                        let startX = width * CGFloat(segment.startTime / duration)
                        let segmentWidth = width * CGFloat(segment.duration / duration)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(segment.id == selectedSegmentID ? Color.clear : Color.black.opacity(0.4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(segment.id == selectedSegmentID ? Theme.toolbarOrange : Color.white.opacity(0.3), lineWidth: 2)
                            }
                            .frame(width: max(2, segmentWidth), height: height * 0.6)
                            .offset(x: startX, y: height * 0.3)
                    }

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: height)
                        .offset(x: min(width - 1, max(1, playheadX)) - 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 12, height: 8)
                        .offset(x: min(width - 6, max(6, playheadX)) - 6)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        onScrubBegan()
                        let time = max(0, min(duration, Double(value.location.x / width) * duration))
                        if let segment = segments.first(where: { $0.contains(time) }) {
                            onSelectSegment(segment.id)
                        }
                        onSeek(time)
                    }
                    .onEnded { _ in
                        onScrubEnded()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Video timeline")
            .accessibilityValue("\(formatTimelineTime(currentTime)) of \(formatTimelineTime(duration))")
            .accessibilityAdjustableAction { direction in
                onScrubBegan()
                onSeek(max(0, min(duration, currentTime + (direction == .increment ? 1 : -1))))
                onScrubEnded()
            }
        }
    }

    private func formatTimelineTime(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
