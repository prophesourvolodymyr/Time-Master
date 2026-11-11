import SwiftUI

/// The page's pictures to pick from (one for a cover, several for a strip), a "none" tile for a cover and a tile that
/// adds a new picture from Photos or Files.
struct ChecklistPictureChooser: View {
    /// The page's pictures.
    let pictures: [URL]
    /// Chosen file names, in order.
    @Binding var selection: [String]
    /// 1 chooses a single picture (a tap replaces it).
    var limit: Int = 1
    var allowsNone = true
    var isImporting = false
    let onAdd: (ChecklistPictureImporter.Source) -> Void

    @ScaledMetric(relativeTo: .body) private var tileHeight: CGFloat = 72

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if allowsNone {
                    plainTile(symbol: "nosign", isSelected: selection.isEmpty, label: "No picture") { selection = [] }
                }
                ForEach(pictures, id: \.self) { url in
                    pictureTile(url)
                }
                Menu {
                    Button { onAdd(.photos) } label: { Label("Photos", systemImage: "photo.on.rectangle") }
                    Button { onAdd(.files) } label: { Label("Files", systemImage: "folder") }
                } label: {
                    plainLabel(symbol: isImporting ? "hourglass" : "plus", isSelected: false)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
                .disabled(isImporting || (limit > 1 && selection.count >= limit))
                .accessibilityLabel("Add a picture")
            }
            .padding(.vertical, 4)
        }
    }

    private func pictureTile(_ url: URL) -> some View {
        let name = url.lastPathComponent
        let position = selection.firstIndex(of: name)
        let isSelected = position != nil
        return Button {
            toggle(name)
        } label: {
            SkillLocalImage(url: url, maxPixel: 320)
                .frame(width: tileHeight * 1.4, height: tileHeight)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isSelected ? 3 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let position, limit > 1 {
                        Text("\(position + 1)")
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(.black)
                            .frame(width: 20, height: 20)
                            .background(Theme.toolbarOrange, in: Circle())
                            .padding(5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Picture \((pictures.firstIndex(of: url) ?? 0) + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ name: String) {
        if limit <= 1 {
            selection = selection == [name] ? [] : [name]
        } else if let index = selection.firstIndex(of: name) {
            selection.remove(at: index)
        } else if selection.count < limit {
            selection.append(name)
        }
    }

    private func plainTile(symbol: String, isSelected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            plainLabel(symbol: symbol, isSelected: isSelected)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func plainLabel(symbol: String, isSelected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isSelected ? Theme.toolbarOrange : Theme.textSecondary)
            .frame(width: tileHeight, height: tileHeight)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isSelected ? 3 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
