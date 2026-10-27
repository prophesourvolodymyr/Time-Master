import SwiftUI

struct DatabaseGroupCover: View {
    private let coverURLs: [URL]

    init(page: ExercisePage) {
        coverURLs = Self.descendantCoverURLs(in: page)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let height = max(0, geometry.size.height)
            let halfWidth = max(0, (width - 2) / 2)
            let halfHeight = max(0, (height - 2) / 2)

            Group {
                switch coverURLs.count {
                case 1:
                    tile(0, width: width, height: height)
                case 2:
                    HStack(spacing: 2) {
                        tile(0, width: halfWidth, height: height)
                        tile(1, width: halfWidth, height: height)
                    }
                case 3:
                    HStack(spacing: 2) {
                        tile(0, width: halfWidth, height: height)
                        VStack(spacing: 2) {
                            tile(1, width: halfWidth, height: halfHeight)
                            tile(2, width: halfWidth, height: halfHeight)
                        }
                    }
                case 4:
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            tile(0, width: halfWidth, height: halfHeight)
                            tile(1, width: halfWidth, height: halfHeight)
                        }
                        HStack(spacing: 2) {
                            tile(2, width: halfWidth, height: halfHeight)
                            tile(3, width: halfWidth, height: halfHeight)
                        }
                    }
                default:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surface2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.separator, lineWidth: 1)
                        }
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .background(Theme.background)
        .accessibilityHidden(true)
    }

    private func tile(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        DatabaseCoverThumbnail(url: coverURLs[index])
            .frame(width: width, height: height)
            .clipped()
            .id(coverURLs[index])
    }

    static func descendantCoverURLs(in page: ExercisePage) -> [URL] {
        var urls: [URL] = []
        var seen = Set<URL>()
        urls.reserveCapacity(4)

        func collect(_ children: [ExercisePage]) {
            for child in children.sorted(by: {
                if $0.manifest.order != $1.manifest.order {
                    return $0.manifest.order < $1.manifest.order
                }
                return $0.manifest.id < $1.manifest.id
            }) {
                if let url = child.coverImageURL, seen.insert(url).inserted {
                    urls.append(url)
                    if urls.count == 4 { return }
                }
                collect(child.children)
                if urls.count == 4 { return }
            }
        }

        collect(page.children)
        if urls.isEmpty, let coverURL = page.coverImageURL {
            urls.append(coverURL)
        }
        return urls
    }
}

private struct DatabaseCoverThumbnail: View {
    let url: URL
    @State private var image: PhotoPlatformImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.surface2
                if let image {
                    Image(platform: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
        }
        .task(id: url) {
            image = nil
            let thumbnail = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: PhotoManager.thumbnailPixelSize)
            guard !Task.isCancelled else { return }
            image = thumbnail
        }
    }
}
