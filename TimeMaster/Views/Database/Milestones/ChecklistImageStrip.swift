import SwiftUI

/// An entry's pictures as a small strip; a tap opens the picture in the page's viewer. A picture the page names but
/// this device does not hold yet shows as a marked tile.
struct ChecklistImageStrip: View {
    let urls: [URL]
    var side: CGFloat = 44
    let onOpen: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(urls, id: \.self) { url in
                    Button { onOpen(url) } label: {
                        Group {
                            if FileManager.default.fileExists(atPath: url.path) {
                                SkillLocalImage(url: url, maxPixel: Int(side * 3))
                            } else {
                                Theme.surface2.overlay {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .font(.system(size: side * 0.32))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 9))
                    .accessibilityLabel("Picture \((urls.firstIndex(of: url) ?? 0) + 1) of \(urls.count)")
                }
            }
            .padding(.vertical, 1)
        }
    }
}
