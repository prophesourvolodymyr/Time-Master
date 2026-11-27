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

    private var displayedImage: PlatformImage? {
        if let url, let cached = PhotoManager.shared.cachedImage(from: url, maxPixelSize: pixelBudget) { return cached }
        return loadedImage
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = displayedImage {
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
            if let cached = PhotoManager.shared.cachedImage(from: url, maxPixelSize: pixelBudget) {
                if loadedImage !== cached { loadedImage = cached }
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

/// A small square picture for a search row: its symbol shows with the text at once and the cover takes its place a
/// moment later, once it has loaded, so a list of results never waits for pictures.
struct DelayedCoverThumb: View {
    let url: URL?
    let symbol: String
    var side: CGFloat = 30
    var tint: Color = Theme.toolbarOrange
    var delay: Double = 0.45

    @State private var showsCover = false

    var body: some View {
        ZStack {
            Image(systemName: symbol)
                .font(.system(size: side * 0.46, weight: .bold))
                .foregroundStyle(tint)
                .opacity(showsCover ? 0 : 1)
            if showsCover, let url {
                AsyncCoverImage(url: url, fallbackIcon: symbol, height: side, overlayGradient: false)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: side * 0.27, style: .continuous))
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .task(id: url) {
            showsCover = false
            guard url != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { showsCover = true }
        }
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
