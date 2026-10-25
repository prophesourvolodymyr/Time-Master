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

extension View {
    func everPageTravel(scope: String, order: Int) -> some View {
        modifier(EverPageTravelModifier(scope: scope, order: order))
    }
}

private struct EverPageTravelModifier: ViewModifier {
    let scope: String
    let order: Int
#if os(macOS)
    @State private var title = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#endif

    func body(content: Content) -> some View {
#if os(macOS)
        content
            .environment(\.everPageTravelActive, true)
            .overlay {
                EverMacPageTravelAnchor(scope: scope, route: title, order: order, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onPreferenceChange(MacWindowTitlePreferenceKey.self) { title = $0 ?? "" }
#else
        content.everPageOpening(when: scope)
#endif
    }
}

#if os(macOS)
private struct EverMacPageTravelAnchor: NSViewRepresentable {
    let scope: String
    let route: String
    let order: Int
    let reduceMotion: Bool

    func makeCoordinator() -> EverMacPageTravelMotion { EverMacPageTravelMotion() }
    func makeNSView(context: Context) -> EverMacPageTravelView { EverMacPageTravelView() }

    func updateNSView(_ view: EverMacPageTravelView, context: Context) {
        view.changed = { [weak view, weak motion = context.coordinator] in
            guard let view else { return }
            motion?.observe(anchor: view, scope: scope, route: route, order: order, reduceMotion: reduceMotion)
        }
        view.changed?()
    }

    static func dismantleNSView(_ view: EverMacPageTravelView, coordinator: EverMacPageTravelMotion) {
        view.changed = nil
        coordinator.stop()
    }
}

private final class EverMacPageTravelView: NSView {
    var changed: (() -> Void)?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); changed?() }
    override func layout() { super.layout(); changed?() }
}

@MainActor
private final class EverMacPageTravelMotion {
    private var scope: String?
    private var route = ""
    private var order = 0
    private var history: [String] = []
    private var image: CGImage?
    private var size = CGSize.zero
    private var canvas: EverSpacetimeCanvas?
    private var captureTask: Task<Void, Never>?
    private var generation = 0

    func observe(anchor: NSView, scope: String, route: String, order: Int, reduceMotion: Bool) {
        guard anchor.window != nil, !anchor.bounds.isEmpty else { return }
        guard self.scope != scope || self.route != route || size != anchor.bounds.size || image == nil else { return }
        captureTask?.cancel()
        captureTask = Task { @MainActor [weak self, weak anchor] in
            await Task.yield()
            guard !Task.isCancelled, let self, let anchor, let host = anchor.window?.contentView else { return }
            let previous = self.canvas?.snapshot() ?? self.image
            let changed = self.scope != nil && (self.scope != scope || self.route != route)
            let direction: Float
            if self.scope != scope {
                direction = order < self.order ? -1 : 1
                self.history = [route]
            } else if let index = self.history.firstIndex(of: route) {
                direction = -1
                self.history.removeSubrange((index + 1)...)
            } else {
                direction = 1
                self.history.append(route)
            }
            anchor.isHidden = true
            let nextImage = EverViewSnapshot.image(of: host, rect: anchor.convert(anchor.bounds, to: host), afterUpdates: true)
            anchor.isHidden = false
            self.scope = scope
            self.route = route
            self.order = order
            self.size = anchor.bounds.size
            self.image = nextImage
            self.stopAnimation()
            guard changed, let previous, let nextImage,
                  let canvas = EverSpacetimeCanvas(size: anchor.bounds.size),
                  let oldTexture = canvas.gpu.texture(previous),
                  let newTexture = canvas.gpu.texture(nextImage) else { return }
            self.canvas = canvas
            anchor.addSubview(canvas)
            let start = CACurrentMediaTime()
            let duration = reduceMotion ? 0.12 : EverPageMotion.duration
            let token = self.generation
            canvas.onFrame = { [weak self, weak canvas, weak anchor] time in
                guard let self, let canvas, let anchor, token == self.generation else { return }
                guard anchor.window != nil, anchor.bounds.size == self.size else { self.stopAnimation(); return }
                let progress = min(1, max(0, (time - start) / duration))
                let remaining = Float(pow(1 - progress, 3))
                let outgoing = Float(pow(progress, 3))
                let blur = reduceMotion ? Float(0) : Float(sin(progress * .pi) * 0.018)
                canvas.layers.removeAll(keepingCapacity: true)
                canvas.layers.append(EverWarpLayer(
                    texture: oldTexture, rect: anchor.bounds, travel: reduceMotion ? 0 : -direction * outgoing,
                    opacity: Float(1 - progress), flat: true, blur: blur, direction: direction
                ))
                canvas.layers.append(EverWarpLayer(
                    texture: newTexture, rect: anchor.bounds.offsetBy(dx: 0, dy: reduceMotion ? 0 : CGFloat(remaining) * 28),
                    travel: reduceMotion ? 0 : direction * remaining,
                    opacity: reduceMotion ? Float(progress) : 1, flat: true, blur: blur, direction: direction
                ))
                if progress >= 1 { self.stopAnimation() }
            }
            canvas.isPaused = false
        }
    }

    private func stopAnimation() {
        generation += 1
        canvas?.stop()
        canvas = nil
    }

    func stop() {
        captureTask?.cancel()
        captureTask = nil
        stopAnimation()
        image = nil
    }
}
#endif
