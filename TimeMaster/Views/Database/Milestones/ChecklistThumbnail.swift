import SwiftUI
import TimeMasterCore

/// A square picture of an entry for a row: its cover, or the cover of the workout it links (drawn as the workout list
/// draws it, with a play mark), or a marked placeholder when its picture is not on this device.
struct ChecklistThumbnail: View {
    let cover: ChecklistArtwork.Cover
    var tintHex: String = ChecklistLook.defaultTintHex
    var side: CGFloat = 44
    var marksWorkout = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(12, side * 0.22), style: .continuous)
        Group {
            switch cover {
            case .picture(let url):
                Group {
                    if url.isFileURL {
                        SkillLocalImage(url: url, maxPixel: Int(side * 3))
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Theme.surface2
                        }
                    }
                }
                .frame(width: side, height: side)
                .background(Theme.surface2)
                .clipShape(shape)
            case .workout(let workout):
                WorkoutCoverMosaic(workout: workout, size: side)
            case .missingFile:
                Color(hex: tintHex).opacity(0.22)
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: side * 0.36, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .clipShape(shape)
            case .none:
                EmptyView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if marksWorkout {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: max(12, side * 0.3), weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.toolbarOrange)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(x: 3, y: 3)
            }
        }
        .accessibilityHidden(true)
    }
}
