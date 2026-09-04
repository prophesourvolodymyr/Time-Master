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
    let urls: [URL]
    let onTapMedia: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Media")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if urls.count > 1 {
                    Text("Swipe to browse")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        mediaThumbnail(url: url, index: index)
                            .onTapGesture { onTapMedia(index) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func mediaThumbnail(url: URL, index: Int) -> some View {
        let isCover = index == 0
        let width: CGFloat = isCover ? 184 : 154
        let aspectRatio: CGFloat = isCover ? 1 : 1080.0 / 1480.0
        let height = width / aspectRatio
        let ext = url.pathExtension.lowercased()
        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext)

        ZStack(alignment: .topTrailing) {
            Group {
                #if os(iOS)
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
                #elseif os(macOS)
                if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
                #endif
            }
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCover ? Theme.primary : Color.white.opacity(0.1), lineWidth: isCover ? 2 : 1)
            }

            if isCover {
                Label("Cover", systemImage: "pin.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Theme.primary, in: Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .frame(width: width, height: height)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.surface)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Theme.textSecondary.opacity(0.45))
            }
    }
}
