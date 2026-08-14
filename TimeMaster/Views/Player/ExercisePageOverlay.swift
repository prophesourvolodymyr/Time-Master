import SwiftUI
import TimeMasterCore

struct ExercisePageOverlay: View {
    @EnvironmentObject var databaseStore: DatabaseStore

    let pageID: UUID
    let sectionName: String
    let sectionIndex: Int
    let totalSections: Int
    let timeRemaining: Int
    let elapsedSeconds: Int
    let isPaused: Bool
    let isTimerEnabled: Bool
    let isRest: Bool
    let isMusicPlaying: Bool
    let nextExerciseName: String?
    let onPause: () -> Void
    let onMusicToggle: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @State private var linkMetadata: [LinkMetadata] = []

    private var page: ExercisePage? { databaseStore.page(id: pageID) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let page = page {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        coverSection(page: page)
                        contentSection(page: page)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                emptyPageView
            }

            VStack {
                FloatingControlsBar(
                    sectionName: sectionName,
                    sectionIndex: sectionIndex,
                    totalSections: totalSections,
                    timeRemaining: timeRemaining,
                    elapsedSeconds: elapsedSeconds,
                    isPaused: isPaused,
                    isTimerEnabled: isTimerEnabled,
                    isRest: isRest,
                    isMusicPlaying: isMusicPlaying,
                    nextExerciseName: nextExerciseName,
                    onPause: onPause,
                    onMusicToggle: onMusicToggle,
                    onStop: onStop,
                    onSkip: onSkip,
                    onDismiss: onDismiss
                )
                Spacer()
            }
        }
        .task {
            guard let page = page else { return }
            if !page.manifest.linkURLs.isEmpty {
                linkMetadata = await LinkMetadataFetcher.fetchMetadata(
                    for: page.manifest.linkURLs,
                    existing: page.manifest.linkMetadata
                )
            }
        }
    }

    private func coverSection(page: ExercisePage) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let coverURL = page.coverImageURL {
                coverImageView(url: coverURL)
            } else if let iconName = page.manifest.iconName {
                iconCoverView(iconName: iconName, page: page)
            } else {
                gradientCoverView(page: page)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .lineLimit(2)
                if let wt = page.effectiveWorkoutType {
                    HStack(spacing: 4) {
                        Image(systemName: wt.iconName).font(.caption)
                        Text(wt.name).font(.caption.weight(.medium))
                    }
                    .foregroundColor(Color(hex: wt.colorHex))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: wt.colorHex).opacity(0.2))
                    .cornerRadius(5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 220)
        .clipped()
    }

    private func coverImageView(url: URL) -> some View {
        AsyncCoverImage(url: url, height: 220, overlayGradient: true)
    }

    private func iconCoverView(iconName: String, page: ExercisePage) -> some View {
        let color = page.effectiveWorkoutType?.colorHex ?? "FFFFFF"
        return AnyView(
            ZStack {
                Color(hex: color).opacity(0.3)
                Image(systemName: iconName)
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: color).opacity(0.7))
            }
            .frame(height: 220)
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
        )
    }

    private func gradientCoverView(page: ExercisePage) -> some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 220)
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: page.isContainer ? "folder.fill" : "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.08))
                        Spacer()
                    }
                    Spacer()
                }
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
    }

    private func contentSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if page.hasMarkdown {
                markdownBlock(page: page)
            }

            if page.hasWorkoutConfig {
                configBlock(page: page)
            }

            if page.hasMedia {
                PageMediaGalleryGrid(urls: page.mediaURLs) { _ in }
                    .padding(.horizontal, 0)
            }

            if page.hasLinks {
                VideoEmbedListView(
                    urls: page.manifest.linkURLs,
                    metadata: linkMetadata
                ) { urlString in
                    guard let url = URL(string: urlString) else { return }
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #elseif os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private func markdownBlock(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guide")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            MarkdownTextView(text: page.manifest.markdownBody)
        }
    }

    private func configBlock(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Config")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack(spacing: 10) {
                configBadge(label: "Duration", value: "\(page.manifest.duration ?? 0)s")
                if let rest = page.manifest.restAfter {
                    configBadge(label: "Rest", value: "\(rest)s")
                }
                if let sets = page.manifest.sets {
                    configBadge(label: "Sets", value: "\(sets)")
                }
                if let restSets = page.manifest.restBetweenSets {
                    configBadge(label: "Set Rest", value: "\(restSets)s")
                }
            }
        }
    }

    private func configBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .cornerRadius(10)
    }


    private var emptyPageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("Page not found")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
