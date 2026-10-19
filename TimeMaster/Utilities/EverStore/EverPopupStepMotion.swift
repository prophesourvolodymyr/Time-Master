import MetalKit
import SwiftUI
#if canImport(UIKit)
import UIKit
typealias EverPopupNativeView = UIView
#elseif os(macOS)
import AppKit
typealias EverPopupNativeView = NSView
#endif

private struct EverPopupStepMotionKey: EnvironmentKey {
    static let defaultValue: EverPopupStepMotion? = nil
}
private struct EverPopupStepDirectionKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var everPopupStepMotion: EverPopupStepMotion? {
        get { self[EverPopupStepMotionKey.self] }
        set { self[EverPopupStepMotionKey.self] = newValue }
    }
    var everPopupStepDirection: Double {
        get { self[EverPopupStepDirectionKey.self] }
        set { self[EverPopupStepDirectionKey.self] = newValue }
    }
}

#if canImport(UIKit)
struct EverPopupStepAnchor: UIViewRepresentable {
    let id: String
    @Environment(\.everPopupStepMotion) private var motion
    @Environment(\.everPopupStepDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.everPageIsOpening) private var isOpening
    func makeUIView(context: Context) -> EverPopupStepAnchorView { EverPopupStepAnchorView() }
    func updateUIView(_ view: EverPopupStepAnchorView, context: Context) {
        view.changed = { [weak view, weak motion] in
            guard let view, !isOpening else { return }
            motion?.observe(id: id, anchor: view, direction: direction, reduceMotion: reduceMotion)
        }
        view.changed?()
    }
}

final class EverPopupStepAnchorView: UIView {
    var changed: (() -> Void)?
    override func didMoveToWindow() { super.didMoveToWindow(); changed?() }
    override func layoutSubviews() { super.layoutSubviews(); changed?() }
}
#elseif os(macOS)
struct EverPopupStepAnchor: NSViewRepresentable {
    let id: String
    @Environment(\.everPopupStepMotion) private var motion
    @Environment(\.everPopupStepDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.everPageIsOpening) private var isOpening

    func makeNSView(context: Context) -> EverPopupStepAnchorView { EverPopupStepAnchorView() }

    func updateNSView(_ view: EverPopupStepAnchorView, context: Context) {
        view.changed = { [weak view, weak motion] in
            guard let view, !isOpening else { return }
            motion?.observe(id: id, anchor: view, direction: direction, reduceMotion: reduceMotion)
        }
        view.changed?()
    }
}

final class EverPopupStepAnchorView: NSView {
    var changed: (() -> Void)?
    override var isFlipped: Bool { true }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); changed?() }
    override func layout() { super.layout(); changed?() }
}
#endif

@MainActor
final class EverPopupStepMotion {
    weak var host: EverPopupNativeView?
    private var id: String?
    private var image: CGImage?
    private var rect = CGRect.zero
    private var canvas: EverSpacetimeCanvas?
    private var generation = 0
    private var directionOverride: Double?
    private var lastCapture = 0.0

    func back() { directionOverride = -1 }

    func observe(id next: String, anchor: EverPopupNativeView, direction: Double, reduceMotion: Bool) {
        guard anchor.window != nil, !anchor.bounds.isEmpty else { return }
        Task { @MainActor [weak self, weak anchor] in
            guard let self else { return }
            await Task.yield()
            guard let anchor, anchor.window != nil, let host = self.host else { return }
            let nextRect = anchor.convert(anchor.bounds, to: host)
            guard nextRect.width > 0, nextRect.height > 0 else { return }
            let changed = self.id != nil && self.id != next
            if !changed, self.canvas != nil { return }
            if !changed, self.id == next, self.rect == nextRect, CACurrentMediaTime() - self.lastCapture < 0.12 { return }
            let oldImage = self.image
            let oldRect = self.rect
            let opacity = self.opacity(of: host)
            self.setOpacity(1, on: host)
            let nextImage = EverViewSnapshot.image(of: host, rect: nextRect, afterUpdates: true)
            self.setOpacity(opacity, on: host)
            self.id = next
            self.rect = nextRect
            self.image = nextImage
            self.lastCapture = CACurrentMediaTime()
            if changed, let oldImage, let nextImage {
                let travelDirection = self.directionOverride ?? direction
                self.directionOverride = nil
                self.animate(from: oldImage, rect: oldRect, to: nextImage, rect: nextRect,
                             direction: travelDirection, reduceMotion: reduceMotion)
            }
        }
    }

    private func animate(from oldImage: CGImage, rect oldRect: CGRect, to newImage: CGImage, rect newRect: CGRect,
                         direction: Double, reduceMotion: Bool) {
        guard let host, let container = host.superview else { return }
        let interruptedImage = canvas?.snapshot()
        let departureImage = interruptedImage ?? oldImage
        let departureRect = interruptedImage == nil ? oldRect : host.bounds
        stop()
        guard let canvas = EverSpacetimeCanvas(size: host.bounds.size),
              let oldTexture = canvas.gpu.texture(departureImage),
              let newTexture = canvas.gpu.texture(newImage) else { return }
        self.canvas = canvas
        canvas.frame = host.convert(host.bounds, to: container)
        canvas.clearAlpha = 0.64
        container.addSubview(canvas)
        setOpacity(0, on: host)
        let start = CACurrentMediaTime()
        let duration = reduceMotion ? 0.15 : EverPageMotion.duration
        let token = generation
        canvas.onFrame = { [weak self, weak canvas] time in
            guard let self, let canvas, token == self.generation else { return }
            let progress = min(1, max(0, (time - start) / duration))
            let arrival = EverPageMotion.sample(progress, duration: duration)
            let departure = EverPageMotion.sample(1 - progress, duration: duration)
            if interruptedImage != nil { canvas.clearAlpha = 0.64 * Double(departure.travel) }
            canvas.layers.removeAll(keepingCapacity: true)
            canvas.layers.append(EverWarpLayer(
                texture: oldTexture, rect: departureRect, travel: reduceMotion ? 0 : -Float(direction) * departure.travel,
                depth: reduceMotion ? 0 : departure.depth,
                opacity: reduceMotion ? Float(1 - progress) : 1 - departure.travel,
                cornerRadius: interruptedImage == nil ? Float(EverRadius.popup) : 0,
                flat: reduceMotion, blur: reduceMotion ? 0 : departure.blur
            ))
            canvas.layers.append(EverWarpLayer(
                texture: newTexture, rect: newRect, travel: reduceMotion ? 0 : Float(direction) * arrival.travel,
                depth: reduceMotion ? 0 : arrival.depth,
                opacity: reduceMotion ? Float(progress) : 1 - arrival.travel,
                cornerRadius: Float(EverRadius.popup), flat: reduceMotion,
                blur: reduceMotion ? 0 : arrival.blur
            ))
            if progress >= 1 {
                Task { @MainActor [weak self] in
                    guard let self, token == self.generation else { return }
                    self.stop()
                }
            }
        }
        canvas.isPaused = false
    }

    func stop() {
        generation += 1
        if let host { setOpacity(1, on: host) }
        canvas?.stop()
        canvas = nil
    }

    private func opacity(of view: EverPopupNativeView) -> Float {
#if canImport(UIKit)
        view.layer.opacity
#else
        view.wantsLayer = true
        return view.layer?.opacity ?? 1
#endif
    }

    private func setOpacity(_ opacity: Float, on view: EverPopupNativeView) {
#if canImport(UIKit)
        view.layer.opacity = opacity
#else
        view.wantsLayer = true
        view.layer?.opacity = opacity
#endif
    }
}
