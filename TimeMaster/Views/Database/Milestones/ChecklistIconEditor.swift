import SwiftUI
import TimeMasterCore

/// An entry's icon: none, a symbol or an emoji (the existing icon picker), or one of the page's pictures.
struct ChecklistIconEditor: View {
    @Binding var iconName: String
    @Binding var iconType: SkillBoardIconType
    @Binding var iconImage: String?
    /// The page's pictures, offered as picture icons.
    let pictures: [URL]

    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkillChoicePill(title: "None", isSelected: iconName.isEmpty && iconImage == nil) {
                iconName = ""
                iconImage = nil
            }
            .frame(maxWidth: 160)
            SkillIconPicker(iconName: $iconName, iconType: $iconType)
            if !pictures.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pictures, id: \.self) { url in
                            let isSelected = iconImage == url.lastPathComponent
                            Button {
                                iconImage = isSelected ? nil : url.lastPathComponent
                            } label: {
                                SkillLocalImage(url: url, maxPixel: Int(tile * 3))
                                    .frame(width: tile, height: tile)
                                    .clipShape(RoundedRectangle(cornerRadius: tile * 0.26, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: tile * 0.26, style: .continuous)
                                            .strokeBorder(isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isSelected ? 3 : 1)
                                    )
                            }
                            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: tile * 0.26))
                            .accessibilityLabel("Picture icon \((pictures.firstIndex(of: url) ?? 0) + 1)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onChange(of: iconName) { name in
            if !name.isEmpty { iconImage = nil }
        }
        .onChange(of: iconImage) { image in
            if image != nil { iconName = "" }
        }
    }
}
