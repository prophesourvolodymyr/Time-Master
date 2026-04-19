import SwiftUI
import AVFoundation

// MARK: - VideoEditorView

struct VideoEditorView: View {
    @StateObject private var vm: VideoEditorViewModel
    let onClose: () -> Void

    @State private var showBatchConfirm = false
    @State private var previewItem: IdentifiableMedia? = nil
    @State private var showPlayHint = false
    @State private var hideHintTask: Task<Void, Never>? = nil

    /// ~50% of screen height for the main video player
    private let videoH: CGFloat = UIScreen.main.bounds.height * 0.50

    init(videoURL: URL, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: VideoEditorViewModel(url: videoURL))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            videoWithOverlays
            timeAndScrubber
            controlsRow
            actionButtonsSection
            Spacer(minLength: 4)
            traySectionView
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showBatchConfirm) {
            batchConfirmSheet
        }
        .fullScreenCover(item: $previewItem) { wrapped in
            MediaPreviewOverlay(media: wrapped.media, asset: vm.asset) {
                previewItem = nil
            }
        }
        .onDisappear { hideHintTask?.cancel() }
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
            // Video player — aspect fit so full video is visible without cropping
            PlayerLayerView(player: vm.player, gravity: .resizeAspect)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    vm.togglePlayPause()
                    flashPlayHint()
                }

            // Top gradient so header text is readable over any video content
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.72), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 88)
                Spacer()
            }
            .allowsHitTesting(false)

            // Header bar (sits over the gradient)
            VStack {
                headerBar
                Spacer()
            }

            // Centered play / pause hint
            if showPlayHint || !vm.isPlaying {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.white.opacity(0.88))
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.18), value: showPlayHint || !vm.isPlaying)
            }

            // Processing spinner
            if vm.isProcessing {
                Color.black.opacity(0.45)
                    .allowsHitTesting(false)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: videoH)
        .clipped()
    }

    private var headerBar: some View {
        HStack {
            Button("Cancel") { onClose() }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("Edit Video")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            reviewButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var reviewButton: some View {
        let hasMedia = vm.trayItems.contains { !$0.mediaList.isEmpty }
        return Button("Review") {
            if hasMedia { showBatchConfirm = true }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(hasMedia ? .white : .white.opacity(0.25))
    }

    // MARK: - Time Labels + Scrubber

    private var timeAndScrubber: some View {
        VStack(spacing: 0) {
            timeLabelsRow
            VideoScrubberView(
                currentTime: $vm.currentTime,
                inPoint: $vm.inPoint,
                outPoint: $vm.outPoint,
                duration: vm.duration,
                mode: vm.mode,
                onSeek: { vm.seek(to: $0) }
            )
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .background(Color.black)
    }

    private var timeLabelsRow: some View {
        HStack {
            Text(formatTime(vm.currentTime))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
            if vm.mode == .clip && vm.duration > 0 {
                Text("  ·  \(formatTime(vm.inPoint)) → \(formatTime(vm.outPoint))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Theme.textSecondary.opacity(0.55))
            }
            Spacer()
            Text(formatTime(vm.duration))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 16) {
            modeToggle
            Spacer()
            playbackControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(label: "Clip",       selected: vm.mode == .clip)       { vm.mode = .clip }
            modeButton(label: "Screenshot", selected: vm.mode == .screenshot) { vm.mode = .screenshot }
        }
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button { vm.skipBackward() } label: {
                Image(systemName: "gobackward.5")
                    .font(.title3).foregroundColor(Theme.textPrimary)
            }
            Button { vm.togglePlayPause() } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2).foregroundColor(Theme.textPrimary)
            }
            Button { vm.skipForward() } label: {
                Image(systemName: "goforward.5")
                    .font(.title3).foregroundColor(Theme.textPrimary)
            }
        }
    }

    private func modeButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
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
            actionBtn("Set In",  icon: "arrow.left.to.line") {
                vm.inPoint = vm.currentTime
                if vm.inPoint >= vm.outPoint { vm.outPoint = min(vm.duration, vm.inPoint + 5) }
            }
            actionBtn("Set Out", icon: "arrow.right.to.line") {
                vm.outPoint = vm.currentTime
                if vm.outPoint <= vm.inPoint { vm.inPoint = max(0, vm.outPoint - 5) }
            }
            actionBtn("Add Clip", icon: "plus.circle") {
                Task { await vm.addClip() }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color.black)
    }

    private var screenshotAction: some View {
        HStack {
            actionBtn("Take Screenshot", icon: "camera") {
                Task { await vm.captureScreenshot() }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color.black)
    }

    private func actionBtn(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.surface)
            .cornerRadius(8)
        }
        .disabled(vm.isProcessing)
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
        HStack {
            Text("TRAY")
                .font(.caption2).fontWeight(.semibold).tracking(1)
                .foregroundColor(Theme.textSecondary)
            if !vm.statusMessage.isEmpty {
                Text("· \(vm.statusMessage)")
                    .font(.caption2).foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var trayScrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
                addCardButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var addCardButton: some View {
        Button { vm.addNewCard() } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.title3)
                Text("New").font(.caption2)
            }
            .foregroundColor(Theme.textSecondary)
            .frame(width: 72, height: 90)
            .background(Theme.surface2)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.separator, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func flashPlayHint() {
        hideHintTask?.cancel()
        showPlayHint = true
        hideHintTask = Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            showPlayHint = false
        }
    }

    private func formatTime(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
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
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let player = clipPlayer {
            PlayerLayerView(player: player, gravity: .resizeAspect)
                .ignoresSafeArea()
        } else if case .clip = media {
            ProgressView().tint(.white).scaleEffect(1.5)
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
        guard case .clip(let start, _, _) = media else { return }
        let item = AVPlayerItem(asset: asset)
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

// MARK: - PlayerLayerView (UIViewRepresentable — hides native VideoPlayer controls)

// PlayerBackingView must be internal (not private) so UIViewRepresentable conformance can reference it.
// Using layerClass override: UIKit owns the layer's frame — do NOT set it in layoutSubviews.
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
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = gravity
    }
}

// MARK: - VideoScrubberView

private struct VideoScrubberView: View {
    @Binding var currentTime: Double
    @Binding var inPoint: Double
    @Binding var outPoint: Double
    let duration: Double
    let mode: EditMode
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Theme.surface2)
                    .frame(height: 5)
                    .offset(y: midY - 2.5)

                // In/Out highlight (clip mode)
                if mode == .clip && duration > 0 {
                    let inX  = CGFloat(inPoint  / duration) * w
                    let outX = CGFloat(outPoint / duration) * w
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: max(0, outX - inX), height: 5)
                        .offset(x: inX, y: midY - 2.5)
                }

                // Playhead thumb
                if duration > 0 {
                    let thumbX = CGFloat(currentTime / duration) * w
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .offset(x: thumbX - 10, y: midY - 10)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let t = Double(value.location.x / w) * duration
                        onSeek(max(0, min(duration, t)))
                    }
            )
        }
    }
}
