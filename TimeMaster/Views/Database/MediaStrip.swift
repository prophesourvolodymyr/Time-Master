import SwiftUI
import UniformTypeIdentifiers

enum PageMediaKind {
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv"]

    static func isVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }
}

struct MediaStrip: View {
    var title: String = "Media"
    let urls: [URL]
    var marksCover = true
    let comments: [URL: String]
    let onOpen: (Int) -> Void
    var onOpenNotes: ((Int) -> Void)? = nil
    /// Plays videos inside their card: a click plays or pauses, a double click opens the viewer (`onOpen`).
    var playback: MediaInlinePlayback? = nil
    /// The actions of a card's menu (its ellipsis button and its context menu).
    var cardActions: ((Int) -> [MediaCardAction])? = nil
    /// Adds media: a plus button in the header.
    var onAdd: (() -> Void)? = nil
    /// Draws the header as a page section's heading (Skillmax's icon tile with this symbol, the title, `headerCount`)
    /// with the add button as an orange plus.
    var headerSymbol: String? = nil
    /// The count beside a section heading's title; `urls.count` when nil.
    var headerCount: Int? = nil
    @State private var containerWidth: CGFloat = 0
    @State private var focusedIndex: Int? = 0
    @ObservedObject private var revisions = MediaRevisions.shared

    private var cardWidth: CGFloat {
        let available = containerWidth > 0 ? containerWidth : 340
        return min(max(available * 0.62, 190), 300)
    }

    private var cardHeight: CGFloat { (cardWidth / PageMediaLayout.galleryAspect).rounded() }

    private func tileWidth(at index: Int) -> CGFloat {
        marksCover && index == 0 ? min(cardHeight, max(containerWidth, cardWidth)) : cardWidth
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                header(proxy)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(urls.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                card(index: index)
                                if marksCover, index == 0, urls.count > 1 {
                                    Capsule()
                                        .fill(Theme.toolbarOrange.opacity(0.75))
                                        .frame(width: 3, height: cardHeight * 0.7)
                                        .accessibilityHidden(true)
                                }
                            }
                            .id(index)
                        }
                    }
                    .modifier(MediaStripTargetLayout())
                    .padding(.vertical, 2)
                }
                .modifier(MediaStripSnapping(position: $focusedIndex))
                .frame(height: cardHeight + 4)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .onAppear { startRequestedClip(proxy) }
        }
    }

    @ViewBuilder
    private func header(_ proxy: ScrollViewProxy) -> some View {
        if let headerSymbol {
            PageSectionHeader(symbol: headerSymbol, title: title, count: headerCount ?? urls.count) {
                if urls.count > 1 {
                    position
                }
                stepButtons(proxy)
                if let onAdd {
                    PageSectionAddButton(label: "Add files", action: onAdd)
                }
            }
        } else if !title.isEmpty || urls.count > 1 || onAdd != nil {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !title.isEmpty {
                    Text(title)
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                position
                stepButtons(proxy)
                if let onAdd {
                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus")
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    .keyNavPlainButtonStyle()
                    .help("Add files")
                    .accessibilityLabel("Add files")
                }
            }
        }
    }

    /// Plays the clip a Database cover's viewer asked for when it opened this page (`MediaAutoplayIntent`), scrolled
    /// into view.
    private func startRequestedClip(_ proxy: ScrollViewProxy) {
        guard let playback, let index = MediaAutoplayIntent.take(from: urls) else { return }
        focusedIndex = index
        playback.play(urls[index])
        guard index > 0 else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(index, anchor: .leading)
        }
    }

    private var position: some View {
        Text("\(min((focusedIndex ?? 0) + 1, urls.count)) / \(urls.count)")
            .font(TimeMasterFont.caption().monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("Item \(min((focusedIndex ?? 0) + 1, urls.count)) of \(urls.count)")
    }

    @ViewBuilder
    private func stepButtons(_ proxy: ScrollViewProxy) -> some View {
        #if os(macOS)
        if urls.count > 1 {
            stepButton("chevron.left", label: "Previous media", enabled: (focusedIndex ?? 0) > 0) {
                scroll(proxy, to: (focusedIndex ?? 0) - 1)
            }
            stepButton("chevron.right", label: "Next media", enabled: (focusedIndex ?? 0) < urls.count - 1) {
                scroll(proxy, to: (focusedIndex ?? 0) + 1)
            }
        }
        #endif
    }

    #if os(macOS)
    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 30))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func scroll(_ proxy: ScrollViewProxy, to index: Int) {
        let clamped = max(0, min(urls.count - 1, index))
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(clamped, anchor: .leading)
        }
        focusedIndex = clamped
    }
    #endif

    private func card(index: Int) -> some View {
        let url = urls[index]
        return MediaStripCard(
            url: url,
            index: index,
            count: urls.count,
            width: tileWidth(at: index),
            height: cardHeight,
            isCover: marksCover && index == 0,
            hasNote: comments[url] != nil,
            revision: revisions.revision(of: url),
            playback: playback,
            actions: cardActions?(index) ?? [],
            onOpen: { onOpen(index) },
            onOpenNotes: onOpenNotes.map { open in { open(index) } }
        )
    }
}

/// One media card. A video with `playback` plays right in the card on a click and grows into the viewer on a double
/// click (or its expand button); anything else opens the viewer on a click.
private struct MediaStripCard: View {
    let url: URL
    let index: Int
    let count: Int
    let width: CGFloat
    let height: CGFloat
    let isCover: Bool
    let hasNote: Bool
    let revision: Int
    let playback: MediaInlinePlayback?
    let actions: [MediaCardAction]
    let onOpen: () -> Void
    let onOpenNotes: (() -> Void)?

    private var isVideo: Bool { PageMediaKind.isVideo(url) }
    private var isImage: Bool { UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true }
    private var playsInline: Bool { isVideo && playback != nil }
    private var kindName: String { isVideo ? "Video" : (isImage ? "Photo" : "File") }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    private var hint: String {
        if playsInline { return "Plays or pauses the video here" }
        return hasNote ? "Opens the media viewer and its notes" : "Opens the media viewer"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: click) {
                face
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(isCover ? "Cover, " : "")\(kindName) \(index + 1) of \(count)")
            .accessibilityHint(hint)
            .modifier(MediaCardViewerAction(enabled: playsInline) { openViewer() })
            .help(playsInline ? "Click to play or pause, double-click to expand" : "Open in the viewer")
            .modifier(MediaCardContextMenu(actions: actions))

            if let onOpenNotes {
                Button(action: onOpenNotes) {
                    Label {
                        Text(hasNote ? "Notes" : "Add notes")
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                    } icon: {
                        Image(systemName: "square.and.pencil")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.65), in: Capsule())
                }
                .keyNavPlainButtonStyle(shape: .capsule)
                .padding(10)
                .accessibilityLabel(hasNote ? "Open notes for media \(index + 1)" : "Add notes to media \(index + 1)")
            }
        }
        .overlay(alignment: .topLeading) {
            if isCover { coverBadge }
        }
        .overlay(alignment: .topTrailing) { topTrailing }
        .overlay(alignment: .bottomTrailing) { bottomTrailing }
        .frame(width: width, height: height)
        .modifier(MediaCardFrameReporter(url: url, playback: playback))
    }

    private var face: some View {
        ZStack {
            AsyncCoverImage(
                url: url,
                fallbackIcon: isVideo ? "play.rectangle.fill" : (isImage ? "photo" : "doc"),
                fallbackColor: isVideo ? Theme.toolbarOrange : nil,
                height: height,
                contentMode: .fill,
                overlayGradient: false
            )
            .frame(width: width, height: height)
            .id(revision)
            if isVideo {
                if let playback {
                    MediaInlineVideoLayer(playback: playback, url: url)
                } else {
                    MediaPlayGlyph()
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(isCover ? Theme.toolbarOrange : Theme.separator, lineWidth: isCover ? 2 : 1)
        }
        .contentShape(shape)
    }

    private var coverBadge: some View {
        Label {
            Text("Cover")
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
        } icon: {
            Image(systemName: "pin.fill")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.7), in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topTrailing: some View {
        HStack(spacing: 6) {
            if count > 1 {
                Text("\(index + 1)/\(count)")
                    .font(TimeMasterFont.black(11, relativeTo: .caption2).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6), in: Capsule())
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if !actions.isEmpty {
                TmaxMenu {
                    MediaCardMenuItems(actions: actions)
                } label: {
                    roundGlyph("ellipsis")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .keyNavPlainButtonStyle(shape: .circle)
                .help("More")
                .accessibilityLabel("\(kindName) \(index + 1) options")
            }
        }
        .padding(10)
    }

    private var bottomTrailing: some View {
        HStack(spacing: 6) {
            if hasNote {
                Image(systemName: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.65), in: Circle())
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if playsInline {
                Button(action: openViewer) {
                    roundGlyph("arrow.up.left.and.arrow.down.right")
                }
                .keyNavPlainButtonStyle(shape: .circle)
                .help("Expand (or double-click the video)")
                .accessibilityLabel("Open video \(index + 1) in the viewer")
            }
        }
        .padding(10)
    }

    private func roundGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(.black.opacity(0.65), in: Circle())
            .contentShape(Circle())
    }

    private func click() {
        guard playsInline, let playback else {
            onOpen()
            return
        }
        if playback.registerClick(on: url) {
            openViewer()
        } else {
            playback.toggle(url)
        }
    }

    private func openViewer() {
        if playsInline { playback?.play(url) }
        onOpen()
    }
}

/// The card's video: the inline player once it started, the play glyph while it does not play, and its progress.
private struct MediaInlineVideoLayer: View {
    @ObservedObject var playback: MediaInlinePlayback
    let url: URL

    var body: some View {
        let isActive = playback.url == url
        let isPlaying = isActive && playback.isPlaying
        ZStack(alignment: .bottom) {
            if isActive, let player = playback.player {
                MediaPlayerSurface(player: player, gravity: .resizeAspectFill)
                    .id(playback.surfaceEpoch)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            MediaPlayGlyph()
                .opacity(isPlaying ? 0 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if isActive {
                MediaInlineProgressLine(progress: playback.progress)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPlaying)
        .onDisappear {
            if playback.url == url { playback.pause() }
        }
    }
}

private struct MediaPlayGlyph: View {
    var body: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct MediaInlineProgressLine: View {
    @ObservedObject var progress: MediaInlineProgress

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
            Rectangle()
                .fill(Theme.toolbarOrange)
                .scaleEffect(x: max(0.001, progress.value), y: 1, anchor: .leading)
        }
        .frame(height: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MediaCardMenuItems: View {
    let actions: [MediaCardAction]

    var body: some View {
        ForEach(actions.filter { $0.role != .destructive }) { action in
            Button(action: action.perform) {
                Label(action.title, systemImage: action.systemImage)
            }
        }
        let destructive = actions.filter { $0.role == .destructive }
        if !destructive.isEmpty {
            Divider()
            ForEach(destructive) { action in
                Button(role: .destructive, action: action.perform) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
    }
}

private struct MediaCardContextMenu: ViewModifier {
    let actions: [MediaCardAction]

    func body(content: Content) -> some View {
        if actions.isEmpty {
            content
        } else {
            content.contextMenu {
                MediaCardMenuItems(actions: actions)
            }
        }
    }
}

private struct MediaCardViewerAction: ViewModifier {
    let enabled: Bool
    let open: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: "Open in viewer", open)
        } else {
            content
        }
    }
}

/// Keeps the page's inline playback told where the card is, so the viewer can grow out of it.
private struct MediaCardFrameReporter: ViewModifier {
    let url: URL
    let playback: MediaInlinePlayback?

    func body(content: Content) -> some View {
        if let playback {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    playback.setCardFrame(frame, for: url)
                }
                .onDisappear { playback.removeCardFrame(for: url) }
        } else {
            content
        }
    }
}

private struct MediaStripTargetLayout: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

private struct MediaStripSnapping: ViewModifier {
    @Binding var position: Int?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position)
        } else {
            content
        }
    }
}
