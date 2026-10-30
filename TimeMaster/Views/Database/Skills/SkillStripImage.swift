import SwiftUI
import CoreGraphics
import ImageIO

/// The two colours a strip takes from its picture (`RRGGBB`): the top half's and the bottom half's.
struct SkillStripColors: Equatable {
    var top: String
    var bottom: String
}

/// Picks the colours of a strip from a picture's pixels. Pure logic: the loader below feeds it a tiny bitmap.
enum SkillStripPalette {
    /// `rgba` is `width * height` pixels of 4 bytes (R, G, B, A) in row order, premultiplied or not.
    /// Each half of the picture gives one colour: its pixels averaged, with vivid ones counting more than greys, then
    /// lifted so it reads on the ink background (saturated enough, never dark).
    static func colors(rgba: [UInt8], width: Int, height: Int) -> SkillStripColors? {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return nil }
        let middle = max(1, height / 2)
        guard let top = dominant(rgba: rgba, width: width, rows: 0..<middle),
              let bottom = dominant(rgba: rgba, width: width, rows: (height > 1 ? middle : 0)..<height) else { return nil }
        return SkillStripColors(top: top, bottom: bottom)
    }

    private static func dominant(rgba: [UInt8], width: Int, rows: Range<Int>) -> String? {
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for row in rows {
            for column in 0..<width {
                let offset = (row * width + column) * 4
                let alpha = Double(rgba[offset + 3]) / 255
                guard alpha > 0.1 else { continue }
                let r = Double(rgba[offset]) / 255, g = Double(rgba[offset + 1]) / 255, b = Double(rgba[offset + 2]) / 255
                let high = max(r, g, b), low = min(r, g, b)
                let saturation = high == 0 ? 0 : (high - low) / high
                let vividness = 0.1 + saturation * high * 2   // greys and near-blacks barely count
                red += r * vividness
                green += g * vividness
                blue += b * vividness
                weight += vividness
            }
        }
        guard weight > 0 else { return nil }
        return lifted(red: red / weight, green: green / weight, blue: blue / weight)
    }

    /// A colour that reads on the ink background: brightness at least 0.62, and some saturation kept when the picture
    /// has any (a grey picture stays grey).
    private static func lifted(red: Double, green: Double, blue: Double) -> String {
        let high = max(red, green, blue), low = min(red, green, blue)
        let delta = high - low
        var hue = 0.0
        if delta > 0 {
            if high == red { hue = (green - blue) / delta + (green < blue ? 6 : 0) }
            else if high == green { hue = (blue - red) / delta + 2 }
            else { hue = (red - green) / delta + 4 }
            hue /= 6
        }
        var saturation = high == 0 ? 0 : delta / high
        if saturation > 0.08 { saturation = min(1, max(saturation, 0.45)) }
        let brightness = min(0.95, max(high, 0.62))
        let (r, g, b) = rgb(hue: hue, saturation: saturation, brightness: brightness)
        func byte(_ value: Double) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    private static func rgb(hue: Double, saturation: Double, brightness: Double) -> (Double, Double, Double) {
        let scaled = hue * 6
        let sector = Int(scaled.rounded(.down)) % 6
        let fraction = scaled - scaled.rounded(.down)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        switch sector {
        case 0: return (brightness, t, p)
        case 1: return (q, brightness, p)
        case 2: return (p, brightness, t)
        case 3: return (p, q, brightness)
        case 4: return (t, p, brightness)
        default: return (brightness, p, q)
        }
    }
}

/// Downsampled local pictures for the skill screens (strips, card covers, picture icons). One shared cache keyed by
/// path and size; decoding happens off the main thread.
enum SkillImageCache {
    private static let cache: NSCache<NSString, CGImageBox> = {
        let cache = NSCache<NSString, CGImageBox>()
        cache.countLimit = 300
        return cache
    }()

    private final class CGImageBox {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    static func image(for url: URL, maxPixel: Int) async -> CGImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        let loaded: CGImage? = await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        if let loaded { cache.setObject(CGImageBox(loaded), forKey: key) }
        return loaded
    }
}

/// A local picture filled into whatever frame the caller gives it (cropped, never stretched).
struct SkillLocalImage: View {
    let url: URL?
    var maxPixel = 480
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            let loaded = await SkillImageCache.image(for: url, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

/// Loads the picture of a strip (downsampled) and the colours it gives the group.
@MainActor
final class SkillStripImageModel: ObservableObject {
    @Published private(set) var image: CGImage?
    @Published private(set) var colors: SkillStripColors?

    private static var colorCache: [String: SkillStripColors] = [:]

    func load(_ url: URL?) async {
        guard let url, let loaded = await SkillImageCache.image(for: url, maxPixel: 96) else {
            image = nil
            colors = nil
            return
        }
        image = loaded
        let key = url.path
        if let cached = Self.colorCache[key] {
            colors = cached
        } else if let measured = Self.measure(loaded) {
            Self.colorCache[key] = measured
            colors = measured
        } else {
            colors = nil
        }
    }

    /// The colours of a picture: drawn into a 12 by 12 bitmap, whose pixels `SkillStripPalette` reads.
    nonisolated static func measure(_ cgImage: CGImage) -> SkillStripColors? {
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        // The bitmap's first row is the top of the picture, the order `SkillStripPalette` reads.
        return SkillStripPalette.colors(rgba: pixels, width: side, height: side)
    }
}
