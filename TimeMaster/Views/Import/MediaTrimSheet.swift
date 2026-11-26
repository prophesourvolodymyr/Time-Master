import AVFoundation
import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A video to trim and the page that holds it (nil: the cut can replace the clip but not be added as a new one).
struct MediaTrimTarget: Identifiable {
    let url: URL
    let pageID: String?

    var id: URL { url }
}

/// Quick trim: drag the start and end handles over the filmstrip and press Done, which writes the cut over the clip
/// (same file name, so its place on the page, its notes and every link to it stay). Save as New Clip keeps the
/// original and adds the cut right after it.
struct MediaTrimSheet: View {
    let target: MediaTrimTarget
    var onOpenFullEditor: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MediaTrimModel

    init(target: MediaTrimTarget, onOpenFullEditor: (() -> Void)? = nil) {
        self.target = target
        self.onOpenFullEditor = onOpenFullEditor
        _model = StateObject(wrappedValue: MediaTrimModel(url: target.url))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background.ignoresSafeArea())
                .timeMasterNavigationTitle("Trim Video")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    AppToolbar.item(placement: .cancellationAction) {
                        Button("Cancel") { cancel() }
                    }
                    AppToolbar.item(placement: .confirmationAction) {
                        Button("Done") { save(.replace) }
                            .disabled(!model.canSave)
                    }
                }
        }
        .keyNavHost()
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(model.isExporting)
        .alert("Couldn’t trim the video", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onDisappear { model.tearDown() }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 760, minHeight: 520, idealHeight: 640)
        #endif
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            #if os(macOS)
            Text("Trim video")
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            #endif
            preview
            controls
            MediaTrimTrack(model: model)
                .frame(height: 62)
                .padding(.vertical, 4)
                .disabled(!model.isReady)
            Text("Drag the orange handles to keep only the part you want.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            secondaryActions
        }
        .padding(16)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if let progress = model.exportProgress {
                exportOverlay(progress: progress)
            }
        }
    }

    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack {
            Color.black
            MediaPlayerSurface(player: model.player)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if let error = model.loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                    Text(error)
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(20)
            } else if !model.isReady {
                TmaxLoadingIndicator()
            } else if !model.isPlaying {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { model.togglePlayback() }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 18)) { model.togglePlayback() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video preview")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(model.isPlaying ? "Pauses the video" : "Plays the part you keep")
        .accessibilityAction { model.togglePlayback() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { model.togglePlayback() } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 44))
            .disabled(!model.isReady)
            .help(model.isPlaying ? "Pause" : "Play the part you keep")
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(MediaTrimModel.clock(model.start)) – \(MediaTrimModel.clock(model.end))")
                    .font(TimeMasterFont.black(16, relativeTo: .headline).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text("Keeps \(MediaTrimModel.clock(model.end - model.start)) of \(MediaTrimModel.clock(model.duration))")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            MediaTrimClock(playhead: model.playhead)
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            if target.pageID != nil {
                Button { save(.addNew) } label: {
                    Label("Save as New Clip", systemImage: "plus.rectangle.on.rectangle")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 40, horizontalPadding: 14))
                .disabled(!model.canSave || model.isUntrimmed)
                .help("Keep the original and add the cut right after it")
            }
            Spacer(minLength: 0)
            #if os(macOS)
            if let onOpenFullEditor {
                Button {
                    model.pause()
                    dismiss()
                    onOpenFullEditor()
                } label: {
                    Label("Open Full Editor…", systemImage: "film")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 40, horizontalPadding: 14))
                .disabled(model.isExporting)
                .help("Split, crop and save parts in the full video editor")
            }
            #endif
        }
    }

    private func exportOverlay(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(model.exportMode == .replace ? "Trimming the video…" : "Saving the new clip…")
                    .font(TimeMasterFont.black(16, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                TmaxProgressBar(value: progress)
                    .frame(width: 220)
                Text(verbatim: "\(Int((progress * 100).rounded()))%")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                Button("Stop") { model.cancelExport() }
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 16))
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
            }
            .padding(24)
            .modifier(TimeMasterCardSurface(cornerRadius: 22))
        }
        .accessibilityElement(children: .contain)
    }

    private func save(_ mode: MediaTrimModel.SaveMode) {
        if mode == .replace, model.isUntrimmed {
            dismiss()
            return
        }
        Task {
            if await model.save(mode, pageID: target.pageID) { dismiss() }
        }
    }

    private func cancel() {
        model.cancelExport()
        dismiss()
    }
}

/// The quick trim's state: the clip, the part it keeps, the player looping that part, and the export.
@MainActor
final class MediaTrimModel: ObservableObject {
    enum SaveMode {
        case replace
        case addNew
    }

    enum Handle {
        case start
        case end
        case playhead
    }

    static let minimumLength: Double = 0.5
    static let thumbnailCount = 12

    @Published private(set) var duration: Double = 0
    @Published private(set) var thumbnails: [PhotoPlatformImage] = []
    @Published private(set) var start: Double = 0
    @Published private(set) var end: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var loadError: String?
    @Published private(set) var exportProgress: Double?
    @Published private(set) var exportMode: SaveMode = .replace
    @Published var errorMessage: String?

    let url: URL
    let player: AVPlayer
    let playhead = MediaTrimPlayhead()

    private let asset: AVURLAsset
    private let libraryToken = ExerciseLibraryAccess.shared.capture()
    private var loadTask: Task<Void, Never>?
    private var exportTask: Task<URL, Error>?
    private var timeObserver: Any?
    private var pendingSeek: Double?
    private var isSeeking = false
    private var isScrubbing = false

    init(url: URL) {
        self.url = url
        let asset = AVURLAsset(url: url)
        self.asset = asset
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.actionAtItemEnd = .pause
        observeTime()
        load()
    }

    var isReady: Bool { duration > 0 && loadError == nil }
    var isExporting: Bool { exportProgress != nil }
    var canSave: Bool { isReady && !isExporting }
    var isUntrimmed: Bool { start <= 0.05 && end >= duration - 0.05 }
    private var minimumLength: Double { min(Self.minimumLength, duration) }

    static func clock(_ seconds: Double) -> String {
        let tenths = Int((max(0, seconds.isFinite ? seconds : 0) * 10).rounded())
        return String(format: "%d:%02d.%d", tenths / 600, (tenths % 600) / 10, tenths % 10)
    }

    func togglePlayback() {
        guard isReady else { return }
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard isReady else { return }
        isPlaying = true
        let now = playhead.time
        if now < start || now >= end - 0.05 {
            seek(to: start)
        } else if !isSeeking {
            player.play()
        }
    }

    func pause() {
        isPlaying = false
        player.pause()
    }

    func beginScrub() {
        guard !isScrubbing else { return }
        isScrubbing = true
        pause()
    }

    func move(_ handle: Handle, to time: Double) {
        guard isReady else { return }
        switch handle {
        case .start:
            start = min(max(0, time), end - minimumLength)
            seek(to: start)
        case .end:
            end = max(min(duration, time), start + minimumLength)
            seek(to: end)
        case .playhead:
            seek(to: min(max(start, time), end))
        }
    }

    func endScrub(_ handle: Handle) {
        isScrubbing = false
        if handle == .end { seek(to: start) }
    }

    func nudge(_ handle: Handle, by delta: Double) {
        guard isReady else { return }
        pause()
        switch handle {
        case .start: move(.start, to: start + delta)
        case .end: move(.end, to: end + delta)
        case .playhead: move(.playhead, to: playhead.time + delta)
        }
    }

    /// Exports the kept part and writes it back: over the clip (`replace`) or as a new clip after it on the page
    /// `pageID` (`addNew`). True once it is saved.
    func save(_ mode: SaveMode, pageID: String?) async -> Bool {
        guard canSave else { return false }
        pause()
        exportMode = mode
        exportProgress = 0
        let source = url
        let asset = asset
        let range = (start: start, end: end)
        let token = libraryToken
        let task = Task<URL, Error> {
            try await VideoTrimService.export(
                asset: asset,
                from: range.start,
                to: range.end,
                fileType: VideoTrimService.fileType(matching: source)
            ) { [weak self] value in
                self?.exportProgress = value
            }
        }
        exportTask = task
        defer {
            exportTask = nil
            exportProgress = nil
        }
        do {
            let trimmed = try await task.value
            defer { try? FileManager.default.removeItem(at: trimmed) }
            switch mode {
            case .replace:
                try await Task.detached(priority: .userInitiated) {
                    try MediaClipWriter.replace(source, with: trimmed, token: token)
                }.value
                MediaRevisions.shared.bump(source)
            case .addNew:
                guard let pageID else { return false }
                try await Task.detached(priority: .userInitiated) {
                    try MediaClipWriter.addClip(trimmed, after: source, toPage: pageID, token: token)
                }.value
                DatabaseStore.shared.reload()
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    func tearDown() {
        loadTask?.cancel()
        exportTask?.cancel()
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func load() {
        loadTask = Task { [weak self] in
            guard let asset = self?.asset else { return }
            do {
                let seconds = try await asset.load(.duration).seconds
                guard let self, !Task.isCancelled else { return }
                guard seconds.isFinite, seconds > 0 else {
                    self.loadError = "This video has no playable length."
                    return
                }
                self.duration = seconds
                self.end = seconds
                if MediaTrimModel.autoplays { self.play() }
                await self.makeThumbnails()
            } catch {
                self?.loadError = error.localizedDescription
            }
        }
    }

    /// The preview starts playing as the sheet opens, unless the person turned video autoplay off (iPhone).
    private static var autoplays: Bool {
        #if os(iOS)
        return UIAccessibility.isVideoAutoplayEnabled
        #else
        return true
        #endif
    }

    private func makeThumbnails() async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        let count = Self.thumbnailCount
        let tolerance = CMTime(seconds: max(0.05, duration / Double(count) / 2), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        var images: [PhotoPlatformImage] = []
        for index in 0..<count {
            guard !Task.isCancelled else { return }
            let time = CMTime(seconds: duration * (Double(index) + 0.5) / Double(count), preferredTimescale: 600)
            guard let (cgImage, _) = try? await generator.image(at: time) else { continue }
            #if os(iOS)
            images.append(UIImage(cgImage: cgImage))
            #else
            images.append(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
            #endif
            thumbnails = images
        }
    }

    private func observeTime() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                self?.tick(seconds)
            }
        }
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite, !isScrubbing, !isSeeking else { return }
        playhead.time = seconds
        if isPlaying, seconds >= end - 0.03 {
            seek(to: start)
        }
    }

    private func seek(to time: Double) {
        playhead.time = time
        pendingSeek = time
        performPendingSeek()
    }

    private func performPendingSeek() {
        guard !isSeeking, let target = pendingSeek else { return }
        pendingSeek = nil
        isSeeking = true
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSeeking = false
                if self.pendingSeek != nil {
                    self.performPendingSeek()
                } else if self.isPlaying, !self.isScrubbing {
                    self.player.play()
                }
            }
        }
    }
}

/// Where the trim preview is; only the playhead and the clock observe it.
final class MediaTrimPlayhead: ObservableObject {
    @Published var time: Double = 0
}

private struct MediaTrimClock: View {
    @ObservedObject var playhead: MediaTrimPlayhead

    var body: some View {
        Text(MediaTrimModel.clock(playhead.time))
            .font(TimeMasterFont.caption().monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("Playhead at \(MediaTrimModel.clock(playhead.time))")
    }
}

/// The filmstrip with the kept part framed in orange between two handles; the rest is dimmed. Dragging a handle
/// moves that end and shows its frame, dragging anywhere else moves the playhead inside the kept part.
private struct MediaTrimTrack: View {
    @ObservedObject var model: MediaTrimModel
    @State private var dragged: MediaTrimModel.Handle?
    @State private var grabOffset: CGFloat = 0
    private let handleWidth: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let strip = max(1, proxy.size.width - handleWidth * 2)
            let height = proxy.size.height
            let startX = handleWidth + strip * fraction(model.start)
            let endX = handleWidth + strip * fraction(model.end)
            ZStack(alignment: .topLeading) {
                filmstrip(width: strip, height: height)
                    .offset(x: handleWidth)
                Rectangle()
                    .fill(Color.black.opacity(0.62))
                    .frame(width: max(0, startX - handleWidth), height: height)
                    .offset(x: handleWidth)
                Rectangle()
                    .fill(Color.black.opacity(0.62))
                    .frame(width: max(0, handleWidth + strip - endX), height: height)
                    .offset(x: endX)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange, lineWidth: 3)
                    .frame(width: endX - startX + handleWidth * 2, height: height)
                    .offset(x: startX - handleWidth)
                handle(.start, x: startX - handleWidth, height: height)
                handle(.end, x: endX, height: height)
                MediaTrimPlayheadLine(
                    playhead: model.playhead,
                    duration: model.duration,
                    strip: strip,
                    inset: handleWidth,
                    height: height
                )
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(drag(strip: strip, startX: startX, endX: endX))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trim range")
    }

    private func filmstrip(width: CGFloat, height: CGFloat) -> some View {
        let images = model.thumbnails
        let count = MediaTrimModel.thumbnailCount
        return HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                Group {
                    if images.indices.contains(index) {
                        platformImage(images[index])
                            .resizable()
                            .scaledToFill()
                    } else {
                        Theme.surface2
                    }
                }
                .frame(width: width / CGFloat(count), height: height)
                .clipped()
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }

    private func handle(_ which: MediaTrimModel.Handle, x: CGFloat, height: CGFloat) -> some View {
        let isStart = which == .start
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.toolbarOrange)
            .frame(width: handleWidth, height: height)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: height * 0.36)
            }
            .offset(x: x)
            .accessibilityElement()
            .accessibilityLabel(isStart ? "Trim start" : "Trim end")
            .accessibilityValue(MediaTrimModel.clock(isStart ? model.start : model.end))
            .accessibilityAdjustableAction { direction in
                model.nudge(which, by: direction == .increment ? 0.5 : -0.5)
            }
    }

    private func drag(strip: CGFloat, startX: CGFloat, endX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragged == nil {
                    let x = value.startLocation.x
                    let toStart = abs(x - (startX - handleWidth / 2))
                    let toEnd = abs(x - (endX + handleWidth / 2))
                    if min(toStart, toEnd) <= 30 {
                        let takesStart = toStart <= toEnd
                        dragged = takesStart ? .start : .end
                        grabOffset = x - (takesStart ? startX : endX)
                    } else {
                        dragged = .playhead
                        grabOffset = 0
                    }
                    model.beginScrub()
                }
                guard let dragged else { return }
                model.move(dragged, to: time(at: value.location.x - grabOffset, strip: strip))
            }
            .onEnded { _ in
                if let dragged { model.endScrub(dragged) }
                dragged = nil
            }
    }

    private func time(at x: CGFloat, strip: CGFloat) -> Double {
        Double(min(max(0, (x - handleWidth) / strip), 1)) * model.duration
    }

    private func fraction(_ time: Double) -> CGFloat {
        model.duration > 0 ? CGFloat(min(max(0, time / model.duration), 1)) : 0
    }
}

private struct MediaTrimPlayheadLine: View {
    @ObservedObject var playhead: MediaTrimPlayhead
    let duration: Double
    let strip: CGFloat
    let inset: CGFloat
    let height: CGFloat

    var body: some View {
        let fraction = duration > 0 ? CGFloat(min(max(0, playhead.time / duration), 1)) : 0
        Capsule()
            .fill(Color.white)
            .frame(width: 3, height: height + 8)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .offset(x: inset + strip * fraction - 1.5, y: -4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Writes a trimmed clip back to the library.
enum MediaClipWriter {
    enum WriteError: LocalizedError {
        case formatChanged

        var errorDescription: String? {
            "This video’s format can’t be written back in place. Use Save as New Clip instead."
        }
    }

    /// Puts `trimmed` in place of the file at `original`, keeping its name, so the page's order, the clip's notes and
    /// every link to it stay. On the Mac the untrimmed file goes to the Trash.
    static func replace(_ original: URL, with trimmed: URL, token: ExerciseLibraryAccess.Token) throws {
        guard keepsContainer(trimmed, of: original) else { throw WriteError.formatChanged }
        try ExerciseLibraryAccess.shared.perform(token: token) {
            let fileManager = FileManager.default
            let staged = original.deletingLastPathComponent()
                .appendingPathComponent(".trim-\(UUID().uuidString)")
                .appendingPathExtension(trimmed.pathExtension)
            try fileManager.copyItem(at: trimmed, to: staged)
            do {
                #if os(macOS)
                var trashed: NSURL?
                let inTrash = (try? fileManager.trashItem(at: original, resultingItemURL: &trashed)) != nil
                #else
                let inTrash = false
                #endif
                if inTrash {
                    do {
                        try fileManager.moveItem(at: staged, to: original)
                    } catch {
                        #if os(macOS)
                        if let trashed { try? fileManager.moveItem(at: trashed as URL, to: original) }
                        #endif
                        throw error
                    }
                } else {
                    _ = try fileManager.replaceItemAt(original, withItemAt: staged)
                }
            } catch {
                try? fileManager.removeItem(at: staged)
                throw error
            }
        }
    }

    /// Adds `trimmed` to the page `pageID` as a new clip, right after `original` (last when the page does not hold it).
    static func addClip(_ trimmed: URL, after original: URL, toPage pageID: String, token: ExerciseLibraryAccess.Token) throws {
        try ExerciseLibraryAccess.shared.perform(token: token) {
            let database = DatabaseManager.shared
            let filename = try database.uploadMediaToPage(pageID: pageID, sourceURL: trimmed)
            var order = try database.getPage(id: pageID).mediaFilenames.filter { $0 != filename }
            guard let index = order.firstIndex(of: original.lastPathComponent) else { return }
            order.insert(filename, at: index + 1)
            try database.reorderPageMedia(pageID: pageID, filenames: order)
        }
    }

    private static func keepsContainer(_ trimmed: URL, of original: URL) -> Bool {
        let kept = trimmed.pathExtension.lowercased()
        switch original.pathExtension.lowercased() {
        case "mov", "qt": return kept == "mov"
        case "mp4": return kept == "mp4"
        case "m4v": return kept == "m4v"
        default: return false
        }
    }
}
