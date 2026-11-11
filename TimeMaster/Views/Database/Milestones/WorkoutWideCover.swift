import SwiftUI

/// A workout's cover stretched across a card, following the cover the workout chose: its own picture, its first
/// exercises side by side, or its type icon on its colour.
struct WorkoutWideCover: View {
    let workout: Workout
    var height: CGFloat

    @EnvironmentObject private var store: DatabaseStore

    var body: some View {
        Group {
            switch workout.coverStyle {
            case .customImage:
                if let filename = workout.imageFilename {
                    AsyncCoverImage(
                        url: PhotoManager.shared.photoURL(for: filename),
                        fallbackIcon: workout.type.iconName,
                        fallbackColor: Color(hex: workout.type.colorHex),
                        height: height,
                        contentMode: .fill,
                        overlayGradient: false
                    )
                } else {
                    iconCover
                }
            case .icon:
                iconCover
            case .exerciseThumbnails:
                exerciseStrip
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    private var tiles: [Section] {
        Array(workout.sections.filter { !$0.mediaItems.isEmpty || coverURL(of: $0) != nil }.prefix(4))
    }

    private func coverURL(of section: Section) -> URL? {
        section.pageID.flatMap { store.page(id: $0) }?.coverImageURL
    }

    @ViewBuilder
    private var exerciseStrip: some View {
        let shown = tiles
        if shown.isEmpty {
            iconCover
        } else {
            GeometryReader { proxy in
                let width = (proxy.size.width - CGFloat(shown.count - 1) * 2) / CGFloat(shown.count)
                HStack(spacing: 2) {
                    ForEach(shown) { section in
                        tile(section, width: width)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ section: Section, width: CGFloat) -> some View {
        Group {
            if let url = coverURL(of: section) {
                AsyncCoverImage(url: url, fallbackIcon: workout.type.iconName, fallbackColor: Theme.surface2, height: height, contentMode: .fill, overlayGradient: false)
            } else if let media = section.mediaItems.first {
                MediaThumbnailView(item: media, size: max(width, height), cornerRadius: 0)
            } else {
                Theme.surface2
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var iconCover: some View {
        LinearGradient(
            colors: [Color(hex: workout.type.colorHex).opacity(0.55), Color(hex: workout.type.colorHex).opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: workout.type.iconName)
                .font(.system(size: height * 0.4, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
