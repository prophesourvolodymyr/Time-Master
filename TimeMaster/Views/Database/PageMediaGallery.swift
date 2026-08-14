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
                    .foregroundColor(Theme.textSecondary)
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
                            .foregroundColor(.white.opacity(0.85))
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
            videoPlayer(url: url)
        } else {
            zoomableImageView(url: url)
        }
    }

    private func videoPlayer(url: URL) -> some View {
        PageGalleryVideoPlayer(url: url)
    }

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
            if let player = player {
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
                            .foregroundColor(.white)
                    }
                    .disabled(selectedIndex == 0)

                    Text("\(selectedIndex + 1) / \(urls.count)")
                        .foregroundColor(.white)
                        .font(.subheadline)

                    Button { selectedIndex = min(urls.count - 1, selectedIndex + 1) } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
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
                .onAppear {
                    let player = AVPlayer(url: url)
                    player.play()
                }
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
                .overlay(Text("Could not load image").foregroundColor(.white.opacity(0.6)))
        }
    }
}
#endif

#if os(iOS)
private struct ZoomableImageView: View {
    let url: URL

    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(currentScale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                currentScale = max(1.0, lastScale * val)
                            }
                            .onEnded { _ in
                                lastScale = currentScale
                                if currentScale <= 1.0 {
                                    withAnimation { offset = .zero; lastOffset = .zero }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { val in
                                guard currentScale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + val.translation.width,
                                    height: lastOffset.height + val.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture {
                        withAnimation {
                            currentScale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Color.gray.opacity(0.3)
                .overlay(Text("Could not load image").foregroundColor(.white.opacity(0.6)))
        }
    }
}
#endif

struct PageMediaGalleryGrid: View {
    let urls: [URL]
    let onTapMedia: (Int) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Media")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    mediaThumbnail(url: url)
                        .onTapGesture { onTapMedia(index) }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaThumbnail(url: URL) -> some View {
        let ext = url.pathExtension.lowercased()
        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext)

        ZStack {
            #if os(iOS)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.surface)
                    .frame(height: 120)
            }
            #elseif os(macOS)
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.surface)
                    .frame(height: 120)
            }
            #endif

            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
    }
}
