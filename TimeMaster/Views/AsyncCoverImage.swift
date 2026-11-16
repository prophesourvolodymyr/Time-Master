import SwiftUI

struct AsyncCoverImage: View {
    let url: URL?
    var fallbackIcon: String = "doc.text.fill"
    var fallbackColor: Color? = nil
    var height: CGFloat = 220
    var contentMode: ContentMode = .fill
    var overlayGradient: Bool = true

    @State private var loadedImage: PlatformImage?
    @Environment(\.displayScale) private var displayScale

    /// Twice the drawn size, so a wide poster filling a square tile still has enough pixels on its short side.
    private var pixelBudget: CGFloat {
        let ceiling: CGFloat = height < 420 ? 1280 : PhotoManager.fullPhotoPixelSize
        return min(ceiling, max(160, height * displayScale * 2))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if loadedImage != nil, let img = loadedImage {
                Image(platform: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(height: height)
                    .clipped()
            } else {
                fallbackView
            }

            if overlayGradient {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .task(id: url) {
            guard let url = url else {
                loadedImage = nil
                return
            }
            let image = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: pixelBudget)
            if !Task.isCancelled { loadedImage = image }
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        gradientFallback(icon: fallbackIcon.nilIfEmpty ?? "doc.text.fill", color: fallbackColor)
    }

    private func gradientFallback(icon: String, color: Color?) -> some View {
        ZStack {
            if let color = color {
                color.opacity(0.3)
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.08))
        }
        .frame(height: height)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#if os(iOS)
private typealias PlatformImage = UIImage

extension Image {
    init(platform image: UIImage) { self.init(uiImage: image) }
}
#elseif os(macOS)
private typealias PlatformImage = NSImage

extension Image {
    init(platform image: NSImage) { self.init(nsImage: image) }
}
#endif
