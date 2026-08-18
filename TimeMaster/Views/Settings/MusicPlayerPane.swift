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
    let showsAddToWorkout: Bool
    let onTogglePlayback: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDestinationTapped: () -> Void


    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(spacing: 8) {
                Slider(value: $progress, in: 0...1)
                    .tint(.white.opacity(0.9))
                    .controlSize(.mini)
                    .accessibilityLabel("Playback progress")
                    .accessibilityValue(Text(progressAccessibilityValue))

                HStack(spacing: 24) {
                    transportButton(
                        systemName: "backward.end.fill",
                        accessibilityLabel: "Previous track",
                        action: onPrevious
                    )

                    Button(action: onTogglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 23, weight: .bold))
                            .frame(width: 42, height: 36)
                    }
                    .buttonStyle(MusicPlayerTransportStyle())
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    .accessibilityHint("Pauses or resumes the current track")

                    transportButton(
                        systemName: "forward.end.fill",
                        accessibilityLabel: "Next track",
                        action: onNext
                    )
                }
                .foregroundStyle(.white)
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                Image(systemName: showsAddToWorkout ? "folder.badge.plus" : (destinationIcon.isEmpty ? "folder" : destinationIcon))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)

                Text(showsAddToWorkout ? "Add" : destinationName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(showsAddToWorkout ? "To workout" : "Destination")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
        }
        .buttonStyle(MusicPlayerTransportStyle())
        .frame(width: 64, height: 62)
        .accessibilityLabel(Text(showsAddToWorkout ? "Add current music to a workout" : "Destination: \(destinationName)"))
        .accessibilityHint(showsAddToWorkout ? "Choose a workout destination" : "View the music destination")
    }

    private func transportButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 32, height: 36)
        }
        .buttonStyle(MusicPlayerTransportStyle())
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

private struct MusicPlayerTransportStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.58 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 1), value: configuration.isPressed)
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
        showsAddToWorkout: false,
        onTogglePlayback: {},
        onPrevious: {},
        onNext: {},
        onDestinationTapped: {}
    )
    .padding()
    .preferredColorScheme(.dark)
    .background(Color.black)
}
