#if os(iOS)
import Foundation
import SwiftUI

struct OutdoorCompactPlayerView: View {
    @ObservedObject private var musicManager: MusicManager
    let namespace: Namespace.ID
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var marqueeTitleSize: CGFloat = 9

    init(
        musicManager: MusicManager,
        namespace: Namespace.ID,
        onEdit: @escaping () -> Void
    ) {
        self._musicManager = ObservedObject(wrappedValue: musicManager)
        self.namespace = namespace
        self.onEdit = onEdit
    }

    var body: some View {
        OutdoorPineGlassSurface(
            identity: "route-compact-player",
            namespace: namespace,
            cornerRadius: 22,
            interactive: true
        ) {
            HStack(spacing: 10) {
                OutdoorMusicArtworkView(
                    artworkReference: musicManager.currentTrack?.artworkReference,
                    size: 58
                )
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    MusicMarqueeText(
                        text: musicManager.currentTrack?.title ?? "Music",
                        font: .system(size: min(marqueeTitleSize, 14), weight: .semibold, design: .rounded)
                    )
                    .padding(.horizontal, 5)
                    .padding(.bottom, 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(Text(musicManager.currentTrack?.title ?? "Music"))

                VStack(spacing: 5) {
                    Slider(
                        value: Binding(
                            get: { musicManager.playbackProgress },
                            set: { musicManager.seek(to: $0) }
                        ),
                        in: 0...1
                    )
                    .tint(Theme.textPrimary)
                    .controlSize(.mini)
                    .accessibilityLabel("Playback progress")
                    .accessibilityValue(Text("\(Int((musicManager.playbackProgress * 100).rounded())) percent"))

                    HStack(spacing: 22) {
                        transportButton(systemName: "backward.end.fill", label: "Previous track") {
                            musicManager.skipBackward()
                        }
                        transportButton(
                            systemName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                            label: musicManager.isPlaying ? "Pause" : "Play"
                        ) {
                            musicManager.togglePlayback()
                        }
                        transportButton(systemName: "forward.end.fill", label: "Next track") {
                            musicManager.skipForward()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 54)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Open music editor")
                .accessibilityHint("Edit the route music library")
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .frame(height: 84)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Compact music player")
    }

    private func transportButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .frame(minWidth: 44, minHeight: 38)
        }
        .buttonStyle(OutdoorMusicTransportButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(label)
    }
}

struct OutdoorMusicArtworkView: View {
    let artworkReference: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncCoverImage(
                    url: url,
                    fallbackIcon: "music.note",
                    height: size,
                    overlayGradient: false
                )
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: size * 0.35, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var resolvedURL: URL? {
        guard let artworkReference, !artworkReference.isEmpty else { return nil }
        if let remote = URL(string: artworkReference), remote.scheme != nil {
            return remote
        }
        let direct = URL(fileURLWithPath: artworkReference)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        let local = MusicManager.shared.localMusicDirectoryURL.appendingPathComponent(artworkReference)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    private var fallbackSystemImage: String {
        if let artworkReference, artworkReference.hasPrefix("sf:") {
            return String(artworkReference.dropFirst(3))
        }
        return "music.note"
    }
}


private struct OutdoorMusicTransportButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .opacity(configuration.isPressed ? 0.58 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(
                reduceMotion ? .none : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}
#endif
