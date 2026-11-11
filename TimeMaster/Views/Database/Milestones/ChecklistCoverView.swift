import SwiftUI
import TimeMasterCore

/// The picture across the top of a milestone card. Without one (or while it loads) the entry's colour fills the space
/// with a faint flag, so a card is never an empty box; a picture missing on this device is marked.
struct ChecklistCoverView: View {
    let cover: ChecklistArtwork.Cover
    var tintHex: String = ChecklistLook.defaultTintHex
    var height: CGFloat

    var body: some View {
        let tint = Color(hex: tintHex)
        ZStack {
            LinearGradient(colors: [tint.opacity(0.46), tint.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "flag.checkered")
                .font(.system(size: height * 0.52, weight: .thin))
                .foregroundStyle(tint.opacity(0.2))
                .offset(x: height * 0.5, y: -height * 0.04)
            switch cover {
            case .picture(let url):
                if url.isFileURL {
                    SkillLocalImage(url: url, maxPixel: 1400)
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                }
            case .workout(let workout):
                WorkoutWideCover(workout: workout, height: height)
            case .missingFile:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: height * 0.22, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            case .none:
                EmptyView()
            }
            LinearGradient(colors: [.clear, Theme.surface.opacity(0.85)], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}
