import SwiftUI
import AVKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Entry point

/// Full-screen media carousel. Tap × or swipe down to dismiss.
struct MediaPreviewSheet: View {
    let items: [MediaItem]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                Color.black.ignoresSafeArea()
            } else if items.count == 1 {
                MediaPreviewPage(item: items[0])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        MediaPreviewPage(item: item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(idx)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                #endif
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.white.opacity(0.25))
                    .padding(20)
            }
        }
    }
}

// MARK: - Per-item page

private struct MediaPreviewPage: View {
    let item: MediaItem

    var body: some View {
        if item.type == .photo {
            PhotoPreviewPage(filename: item.filename)
        } else {
            VideoPreviewPage(filename: item.filename)
        }
    }
}

// MARK: - Photo page

private struct PhotoPreviewPage: View {
    let filename: String
    #if os(iOS)
    @State private var image: UIImage? = nil
    #elseif os(macOS)
    @State private var image: NSImage? = nil
    #endif

    var body: some View {
        ZStack {
            Color.black
            if let img = image {
                #if os(iOS)
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                #elseif os(macOS)
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            let fn = filename
            image = await Task.detached(priority: .userInitiated) {
                PhotoManager.shared.loadPhoto(filename: fn)
            }.value
        }
    }
}

// MARK: - Video page

private struct VideoPreviewPage: View {
    let filename: String
    @State private var player: AVPlayer? = nil
    @State private var loopObserver: NSObjectProtocol? = nil

    var body: some View {
        ZStack {
            Color.black
            if let p = player {
                VideoPlayer(player: p)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() {
        let url = PhotoManager.shared.videoURL(for: filename)
        let p = AVPlayer(url: url)
        p.play()
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        player = p
        loopObserver = obs
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
    }
}
