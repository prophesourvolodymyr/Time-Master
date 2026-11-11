import SwiftUI
import TimeMasterCore

/// An entry's icon on a tile: its picture, its emoji or symbol, a linked workout's type icon or a linked page's icon;
/// `fallbackSymbol` (a milestone's flag) or nothing when it has none.
struct ChecklistIconTile: View {
    let icon: ChecklistArtwork.Icon
    var tintHex: String = ChecklistLook.defaultTintHex
    var side: CGFloat = 36
    var fallbackSymbol: String?
    /// A tile hanging over a cover gets a solid base so it reads on any picture.
    var onCard = false

    var body: some View {
        let tint = Color(hex: tintHex)
        let shape = RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
        Group {
            switch icon {
            case .picture(let url):
                picture(url)
                    .frame(width: side, height: side)
                    .clipShape(shape)
            case .glyph(let name, let type):
                glyph(name: name, type: type, tint: tint)
            case .workout(let workout):
                Color(hex: workout.type.colorHex).opacity(0.32)
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: workout.type.iconName)
                            .font(.system(size: side * 0.44, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .clipShape(shape)
            case .page(let page):
                SkillPageIconTile(page: page, size: side)
            case .none:
                if let fallbackSymbol {
                    glyph(name: fallbackSymbol, type: .system, tint: tint)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func glyph(name: String, type: SkillBoardIconType, tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
        ZStack {
            if onCard {
                shape.fill(Theme.surface2)
                shape.fill(tint.opacity(0.22))
            }
            SkillIconView(iconName: name, iconType: type, colorHex: ChecklistLook.defaultTintHex == tintHex ? nil : tintHex, size: side * (onCard ? 0.46 : 0.6))
        }
        .frame(width: side, height: side)
        .overlay {
            if onCard { shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
        }
    }

    @ViewBuilder
    private func picture(_ url: URL) -> some View {
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
}
