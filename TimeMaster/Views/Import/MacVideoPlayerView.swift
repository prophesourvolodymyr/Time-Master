#if os(macOS)
import AVFoundation
import AppKit
import SwiftUI

/// A lightweight AVPlayerLayer bridge. It avoids AVKit's SwiftUI VideoPlayer,
/// which crashes while SwiftUI builds this editor inside a macOS sheet.
struct MacVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerHostView {
        PlayerLayerHostView(player: player)
    }

    func updateNSView(_ nsView: PlayerLayerHostView, context: Context) {
        nsView.player = player
    }

    final class PlayerLayerHostView: NSView {
        private let playerLayer = AVPlayerLayer()

        var player: AVPlayer? {
            didSet {
                playerLayer.player = player
            }
        }

        init(player: AVPlayer) {
            self.player = player
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }
    }
}
#endif
