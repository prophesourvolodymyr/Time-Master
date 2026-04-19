import SwiftUI
import UniformTypeIdentifiers

struct TrayCardView: View {
    let item: TrayItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    /// Called with the UUID of the card being dragged onto this one.
    let onMerge: (UUID) -> Void
    /// Optional: called with the first TrayMedia when the user chooses "Preview" from context menu.
    let onPreview: ((TrayMedia) -> Void)?

    @State private var isDropTargeted = false

    var body: some View {
        cardContent
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isDropTargeted
                            ? Color.white.opacity(0.8)
                            : (isSelected ? Color.white.opacity(0.55) : Color.clear),
                        lineWidth: isDropTargeted ? 2 : 1.5
                    )
            )
            .onTapGesture { onSelect() }
            .onDrag {
                NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.plainText], isTargeted: $isDropTargeted) { providers in
                providers.first?.loadObject(ofClass: NSString.self) { obj, _ in
                    guard let str = obj as? String,
                          let srcID = UUID(uuidString: str) else { return }
                    DispatchQueue.main.async { onMerge(srcID) }
                }
                return true
            }
            .contextMenu {
                contextMenuItems
            }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if let firstMedia = item.mediaList.first, let previewCallback = onPreview {
            Button {
                previewCallback(firstMedia)
            } label: {
                Label(
                    firstMedia.isClip ? "Preview Clip" : "Preview Screenshot",
                    systemImage: firstMedia.isClip ? "play.circle" : "eye"
                )
            }
        }
        Button(role: .destructive) { onRemove() } label: {
            Label("Remove Card", systemImage: "trash")
        }
    }

    // MARK: - Card Visual

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            if let thumb = item.primaryThumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 90)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Theme.surface2)
                    .frame(width: 72, height: 90)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary.opacity(0.4))
                    )
            }

            // Media count badge (bottom-left)
            if item.mediaList.count > 1 {
                Text("\(item.mediaList.count)")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(4)
                    .padding(4)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Clip indicator (top-right) when any media is a clip
            if item.mediaList.contains(where: { $0.isClip }) {
                Image(systemName: "film")
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
                    .padding(5)
            }
        }
        .frame(width: 72, height: 90)
        .cornerRadius(10)
        .clipped()
    }
}
