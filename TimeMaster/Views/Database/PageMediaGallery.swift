import SwiftUI
import AVKit

struct PageMediaGallery: View {
    let urls: [URL]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if urls.isEmpty {
                Text("No media")
                    .foregroundStyle(Theme.textSecondary)
            } else {
                #if os(iOS)
                TabView(selection: $selectedIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        mediaView(for: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                #elseif os(macOS)
                macOSMediaViewer(urls: urls, selectedIndex: $selectedIndex)
                #endif
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 60 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func mediaView(for url: URL) -> some View {
        let ext = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext) {
            PageGalleryVideoPlayer(url: url)
        } else {
            zoomableImageView(url: url)
        }
    }

    @ViewBuilder
    private func zoomableImageView(url: URL) -> some View {
        #if os(iOS)
        ZoomableImageView(url: url)
        #elseif os(macOS)
        MacOSImageView(url: url)
        #endif
    }
}

private struct PageGalleryVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                #if os(iOS)
                PlayerLayerView(player: player, gravity: .resizeAspect)
                #elseif os(macOS)
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            guard player == nil else { return }
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}

#if os(macOS)
private struct macOSMediaViewer: View {
    let urls: [URL]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack {
            mediaView(for: urls[selectedIndex])
            if urls.count > 1 {
                HStack(spacing: 20) {
                    Button { selectedIndex = max(0, selectedIndex - 1) } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .disabled(selectedIndex == 0)

                    Text("\(selectedIndex + 1) / \(urls.count)")
                        .foregroundStyle(.white)
                        .font(.subheadline)

                    Button { selectedIndex = min(urls.count - 1, selectedIndex + 1) } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .disabled(selectedIndex == urls.count - 1)
                }
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func mediaView(for url: URL) -> some View {
        let ext = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext) {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(contentMode: .fit)
        } else {
            MacOSImageView(url: url)
        }
    }
}

private struct MacOSImageView: View {
    let url: URL

    var body: some View {
        if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.gray.opacity(0.3)
                .overlay(Text("Could not load image").foregroundStyle(.white.opacity(0.6)))
        }
    }
}
#endif

#if os(iOS)
private struct ZoomableImageView: View {
    let url: URL

    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            GeometryReader { _ in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(currentScale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                currentScale = max(1, lastScale * value)
                            }
                            .onEnded { _ in
                                lastScale = currentScale
                                if currentScale <= 1 {
                                    withAnimation { offset = .zero; lastOffset = .zero }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard currentScale > 1 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture {
                        withAnimation {
                            currentScale = 1
                            lastScale = 1
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Color.gray.opacity(0.3)
                .overlay(Text("Could not load image").foregroundStyle(.white.opacity(0.6)))
        }
    }
}
#endif

struct PageMediaGalleryGrid: View {
    var title: String = "Media"
    let urls: [URL]
    let onTapMedia: (Int) -> Void
    @ScaledMetric(relativeTo: .caption) private var thumbnailHeight: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(urls.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(urls.indices, id: \.self) { index in
                        mediaThumbnail(index: index)
                            .id(urls[index])
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: thumbnailHeight + 4)
        }
    }

    private func mediaThumbnail(index: Int) -> some View {
        let url = urls[index]
        let isCover = index == 0
        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased())
        let width = thumbnailHeight * 4 / 3

        return Button {
            onTapMedia(index)
        } label: {
            AsyncCoverImage(
                url: url,
                fallbackIcon: isVideo ? "play.rectangle.fill" : "photo",
                fallbackColor: isVideo ? Theme.primary : nil,
                height: thumbnailHeight,
                contentMode: .fill,
                overlayGradient: false
            )
            .frame(width: width, height: thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isCover ? Theme.primary : Theme.separator, lineWidth: isCover ? 2 : 1)
            }
            .overlay(alignment: .topLeading) {
                if isCover {
                    Label("Cover", systemImage: "pin.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: Capsule())
                        .padding(8)
                }
            }
            .overlay {
                if isVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isCover ? "Cover, " : "")\(isVideo ? "Video" : "Photo") \(index + 1) of \(urls.count)")
        .accessibilityHint("Opens the media viewer")
    }
}
