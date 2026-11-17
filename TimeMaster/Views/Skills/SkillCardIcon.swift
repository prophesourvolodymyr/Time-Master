import SwiftUI
import TimeMasterCore

/// A page's icon on the Skills page, on a small raised tile: its own picture, symbol or emoji; a page without one
/// shows the symbol of its category instead of a stand-in.
struct SkillCardIcon: View {
    let page: ExercisePage
    let category: SkillCategory
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        glyph
            .frame(width: size, height: size)
            .background(Theme.surface2, in: shape)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Theme.separator, lineWidth: 1) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        if let url = page.iconImageURL {
            SkillCardPicture(url: url, maxPixel: Int(size * 3))
        } else if let name = page.manifest.iconName, !name.isEmpty {
            SkillIconView(iconName: name, iconType: page.manifest.iconType ?? .emoji, size: size * 0.5)
        } else {
            Image(systemName: category.systemImage)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
        }
    }
}

/// A picture icon filling the tile the caller frames: a local one decoded off the main thread through the skill
/// screens' image cache, a web one through `AsyncImage`; empty until it arrives.
private struct SkillCardPicture: View {
    let url: URL
    let maxPixel: Int

    @State private var image: CGImage?

    var body: some View {
        if url.isFileURL {
            Group {
                if let image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.clear
                }
            }
            .task(id: url) {
                image = nil
                let loaded = await SkillImageCache.image(for: url, maxPixel: maxPixel)
                guard !Task.isCancelled else { return }
                image = loaded
            }
        } else {
            AsyncImage(url: url) { picture in
                picture.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.clear
            }
        }
    }
}
