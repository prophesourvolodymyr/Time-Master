import SwiftUI

/// A compact, independent music player surface for the Music screen.
///
/// The view intentionally owns no playback engine. The parent supplies the
/// current state through bindings and performs each control action through the
/// callbacks, which keeps the pane reusable for local and provider-backed items.
struct MusicPlayerPane: View {
    let title: String
    let artworkSystemName: String
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    let destinationName: String
    let destinationIcon: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDestinationTapped: () -> Void

    private let accent = Color(red: 1.0, green: 0.48, blue: 0.0)

    var body: some View {
        HStack(spacing: 10) {
            artwork

            VStack(spacing: 7) {
                Slider(value: $progress, in: 0...1)
                    .tint(accent)
                    .controlSize(.mini)
                    .accessibilityLabel("Playback progress")
                    .accessibilityValue(Text(progressAccessibilityValue))

                HStack(spacing: 13) {
                    transportButton(
                        systemName: "backward.fill",
                        accessibilityLabel: "Previous track",
                        action: onPrevious
                    )

                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 36, height: 36)
                            .background(accent.opacity(0.14), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(accent.opacity(0.30), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    .accessibilityHint("Toggles playback")

                    transportButton(
                        systemName: "forward.fill",
                        accessibilityLabel: "Next track",
                        action: onNext
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            destinationCard
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.055, green: 0.055, blue: 0.065))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(red: 0.105, green: 0.105, blue: 0.12))

            Image(systemName: artworkSystemName.isEmpty ? "music.note" : artworkSystemName)
                .font(.system(size: 27, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white.opacity(0.82))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.80)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            MusicPlayerMarqueeTitle(text: displayTitle)
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(displayTitle))
    }

    private var destinationCard: some View {
        Button(action: onDestinationTapped) {
            VStack(spacing: 3) {
                Image(systemName: destinationIcon.isEmpty ? "folder" : destinationIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(height: 19)

                Text(destinationName.isEmpty ? "General" : destinationName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text("Destination")
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 67, height: 62)
        .accessibilityLabel(Text("Destination: \(destinationName.isEmpty ? "General" : destinationName)"))
        .accessibilityHint("Choose a music destination")
    }

    private func transportButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.90))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.075), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var displayTitle: String {
        title.isEmpty ? "Nothing playing" : title
    }

    private var progressAccessibilityValue: String {
        let boundedProgress = min(max(progress, 0), 1)
        return "\(Int((boundedProgress * 100).rounded())) percent"
    }
}

private struct MusicPlayerMarqueeTitle: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var marqueeActive = false

    private let gap: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if shouldMarquee {
                    HStack(spacing: gap) {
                        titleText
                        titleText
                    }
                    .offset(x: marqueeActive ? -(contentWidth + gap) : 0)
                } else {
                    titleText
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .mask {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.95), .white, .white.opacity(0.95), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .onAppear {
                viewportWidth = proxy.size.width
                updateMarqueeState()
            }
            .onChange(of: proxy.size.width) { newWidth in
                viewportWidth = newWidth
                updateMarqueeState()
            }
        }
        .frame(height: 14)
        .background {
            Text(text)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .hidden()
                .background {
                    GeometryReader { measurement in
                        Color.clear.preference(
                            key: MusicPlayerTextWidthKey.self,
                            value: measurement.size.width
                        )
                    }
                }
        }
        .onPreferenceChange(MusicPlayerTextWidthKey.self) { measuredWidth in
            contentWidth = measuredWidth
            updateMarqueeState()
        }
        .animation(
            shouldMarquee && !reduceMotion
                ? .easeInOut(duration: 4.8).repeatForever(autoreverses: true)
                : nil,
            value: marqueeActive
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }

    private var titleText: some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.96))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var shouldMarquee: Bool {
        !reduceMotion && contentWidth > viewportWidth + 1
    }

    private func updateMarqueeState() {
        marqueeActive = shouldMarquee
    }
}

private struct MusicPlayerTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    MusicPlayerPane(
        title: "A very long track name that needs to move",
        artworkSystemName: "music.note.list",
        isPlaying: .constant(true),
        progress: .constant(0.42),
        destinationName: "Run",
        destinationIcon: "figure.run",
        onPrevious: {},
        onNext: {},
        onDestinationTapped: {}
    )
    .padding()
    .preferredColorScheme(.dark)
    .background(Color.black)
}
