import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
enum EverViewSnapshot {
#if canImport(UIKit)
    static func image(of view: UIView, rect: CGRect? = nil, afterUpdates: Bool = false) -> CGImage? {
        let region = rect ?? view.bounds
        guard region.width > 0, region.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(view.window?.screen.scale ?? 2, 1.5)
        format.opaque = false
        return UIGraphicsImageRenderer(size: region.size, format: format).image { context in
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: afterUpdates)
            if !view.bounds.contains(region) {
                context.cgContext.saveGState()
                context.cgContext.addRect(region)
                context.cgContext.addRect(view.bounds)
                context.cgContext.clip(using: .evenOdd)
                view.layer.render(in: context.cgContext)
                context.cgContext.restoreGState()
            }
        }.cgImage
    }
#elseif os(macOS)
    static func image(of view: NSView, rect: CGRect? = nil, afterUpdates: Bool = false) -> CGImage? {
        let region = rect ?? view.bounds
        guard region.width > 0, region.height > 0 else { return nil }
        if afterUpdates {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
        }
        let scale = min(view.window?.backingScaleFactor ?? 2, 1.5)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(ceil(region.width * scale)),
            pixelsHigh: Int(ceil(region.height * scale)), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = region.size
        view.cacheDisplay(in: region, to: bitmap)
        return bitmap.cgImage
    }
#endif
}

private struct EverPageTravelActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everPageTravelActive: Bool {
        get { self[EverPageTravelActiveKey.self] }
        set { self[EverPageTravelActiveKey.self] = newValue }
    }
}
