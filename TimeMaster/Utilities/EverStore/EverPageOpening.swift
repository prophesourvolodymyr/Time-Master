import MetalKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum EverPageMotion {
    static let duration = 0.36

    static func sample(_ fraction: Double, duration: Double = EverPageMotion.duration,
                       emergence: Bool = false) -> (travel: Float, depth: Float, blur: Float) {
        let time = min(1, max(0, fraction))
        let remaining = 1 - time
        let cube = remaining * remaining * remaining
        let travel = cube * remaining * (emergence ? 1 : 1 + 4 * time)
        let velocity = emergence ? 4 * cube : 20 * time * cube
        let peak = emergence ? 4.0 : 2.109375
        return (Float(travel), Float(velocity / peak * 0.82),
                Float(min(0.085, velocity * 0.012 / duration)))
    }
}

private struct EverPageIsOpeningKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everPageIsOpening: Bool {
        get { self[EverPageIsOpeningKey.self] }
        set { self[EverPageIsOpeningKey.self] = newValue }
    }
}

extension View {
    func everPageOpening(from edge: Edge = .trailing) -> some View {
        modifier(EverPageOpeningModifier(edge: edge))
    }

    func everSheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                 @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom) }
    }

    func everSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                     @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom) }
    }

    func everFullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                           @ViewBuilder content: @escaping () -> Content) -> some View {
#if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom) }
#else
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) { content().everPageOpening(from: .bottom) }
#endif
    }

    func everFullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                               @ViewBuilder content: @escaping (Item) -> Content) -> some View {
#if os(macOS)
        sheet(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom) }
#else
        fullScreenCover(item: item, onDismiss: onDismiss) { content($0).everPageOpening(from: .bottom) }
#endif
    }

    func everNavigationDestination<Item: Hashable, Content: View>(for type: Item.Type,
                                                                  @ViewBuilder destination: @escaping (Item) -> Content) -> some View {
        navigationDestination(for: type) { destination($0).everPageOpening() }
    }

    func everNavigationDestination<Content: View>(isPresented: Binding<Bool>,
                                                  @ViewBuilder destination: @escaping () -> Content) -> some View {
        navigationDestination(isPresented: isPresented) { destination().everPageOpening() }
    }
}

private struct EverPageOpeningModifier: ViewModifier {
    let edge: Edge
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpening = true

    func body(content: Content) -> some View {
        content
            .environment(\.everPageIsOpening, isOpening)
            .allowsHitTesting(!isOpening)
            .overlay {
                EverPageOpeningOverlay(reduceMotion: reduceMotion, vertical: edge == .top || edge == .bottom,
                                       direction: direction, isOpening: $isOpening)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private var direction: Float {
        switch edge {
        case .top: -1
        case .bottom: 1
        case .leading: layoutDirection == .leftToRight ? -1 : 1
        case .trailing: layoutDirection == .leftToRight ? 1 : -1
        }
    }
}

#if canImport(UIKit)
private struct EverPageOpeningOverlay: UIViewRepresentable {
    let reduceMotion: Bool
    let vertical: Bool
    let direction: Float
    @Binding var isOpening: Bool

    func makeUIView(context: Context) -> EverPageOpeningSurface { EverPageOpeningSurface() }

    func updateUIView(_ view: EverPageOpeningSurface, context: Context) {
        view.reduceMotion = reduceMotion
        view.vertical = vertical
        view.direction = direction
        view.onCompletion = { isOpening = false }
        view.beginIfVisible()
    }

    static func dismantleUIView(_ view: EverPageOpeningSurface, coordinator: ()) { view.finish() }
}

@MainActor
private final class EverPageOpeningSurface: UIView {
    var reduceMotion = false
    var vertical = false
    var direction: Float = 1
    var onCompletion: (() -> Void)?
    private var captureTask: Task<Void, Never>?
    private var canvas: EverSpacetimeCanvas?
    private var hasRun = false
    private var finished = false

    init() {
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(finish), name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil, hasRun { finish() }
        else { beginIfVisible() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let canvas, canvas.bounds.size != bounds.size { finish() }
        beginIfVisible()
    }

    func beginIfVisible() {
        guard window != nil, !bounds.isEmpty, !hasRun else { return }
        hasRun = true
        captureTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, !self.finished, let window = self.window else { return }
            if self.reduceMotion {
                self.fadeIn()
                return
            }
            var responder: UIResponder? = self
            var controller: UIViewController?
            while let current = responder {
                if let host = current as? UIViewController {
                    controller = host
                    break
                }
                responder = current.next
            }
            let source = controller?.view ?? window
            let transition = controller?.transitionCoordinator
            let transitionDuration = transition?.transitionDuration ?? 0
            let nativeSlide = transition?.isAnimated == true && transitionDuration > 0
            let duration = nativeSlide ? transitionDuration : EverPageMotion.duration
            self.isHidden = true
            let image = EverViewSnapshot.image(of: source, rect: self.convert(self.bounds, to: source), afterUpdates: true)
            self.isHidden = false
            guard let image, let canvas = EverSpacetimeCanvas(size: self.bounds.size),
                  let texture = canvas.gpu.texture(image) else {
                self.fadeIn()
                return
            }
            self.canvas = canvas
            self.addSubview(canvas)
            let start = CACurrentMediaTime()
            canvas.onFrame = { [weak self, weak canvas] time in
                guard let self, let canvas, !self.finished else { return }
                let progress = min(1, max(0, (time - start) / duration))
                let motion = EverPageMotion.sample(progress, duration: duration)
                canvas.layers.removeAll(keepingCapacity: true)
                canvas.layers.append(EverWarpLayer(texture: texture, rect: self.bounds,
                                                   travel: nativeSlide ? 0 : self.direction * motion.travel,
                                                   depth: motion.depth, vertical: self.vertical,
                                                   blur: motion.blur, direction: self.direction))
                if progress >= 1 { self.finish() }
            }
            canvas.isPaused = false
        }
    }

    private func fadeIn() {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { [weak self] _ in self?.finish() }
    }

    @objc func finish() {
        guard !finished else { return }
        finished = true
        hasRun = true
        captureTask?.cancel()
        captureTask = nil
        canvas?.stop()
        canvas = nil
        layer.removeAllAnimations()
        backgroundColor = .clear
        alpha = 1
        Task { @MainActor [weak self] in self?.onCompletion?() }
    }
}
#elseif os(macOS)
private struct EverPageOpeningOverlay: NSViewRepresentable {
    let reduceMotion: Bool
    let vertical: Bool
    let direction: Float
    @Binding var isOpening: Bool

    func makeNSView(context: Context) -> EverPageOpeningSurface { EverPageOpeningSurface() }

    func updateNSView(_ view: EverPageOpeningSurface, context: Context) {
        view.reduceMotion = reduceMotion
        view.vertical = vertical
        view.direction = direction
        view.onCompletion = { isOpening = false }
        view.beginIfVisible()
    }

    static func dismantleNSView(_ view: EverPageOpeningSurface, coordinator: ()) { view.finish() }
}

@MainActor
private final class EverPageOpeningSurface: NSView {
    var reduceMotion = false
    var vertical = false
    var direction: Float = 1
    var onCompletion: (() -> Void)?
    private var captureTask: Task<Void, Never>?
    private var canvas: EverSpacetimeCanvas?
    private var hasRun = false
    private var finished = false

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setAccessibilityElement(false)
        NotificationCenter.default.addObserver(self, selector: #selector(finish), name: NSApplication.didResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil, hasRun { finish() }
        else { beginIfVisible() }
    }

    override func layout() {
        super.layout()
        if let canvas, canvas.bounds.size != bounds.size { finish() }
        beginIfVisible()
    }

    func beginIfVisible() {
        guard window != nil, !bounds.isEmpty, !hasRun else { return }
        hasRun = true
        captureTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, !self.finished, let window = self.window else { return }
            if self.reduceMotion {
                self.fadeIn()
                return
            }
            var responder: NSResponder? = self
            var controller: NSViewController?
            while let current = responder {
                if let host = current as? NSViewController {
                    controller = host
                    break
                }
                responder = current.nextResponder
            }
            guard let source = controller?.view ?? window.contentView else {
                self.fadeIn()
                return
            }
            let duration = EverPageMotion.duration
            self.isHidden = true
            let image = EverViewSnapshot.image(of: source, rect: self.convert(self.bounds, to: source), afterUpdates: true)
            self.isHidden = false
            guard let image, let canvas = EverSpacetimeCanvas(size: self.bounds.size),
                  let texture = canvas.gpu.texture(image) else {
                self.fadeIn()
                return
            }
            self.canvas = canvas
            self.addSubview(canvas)
            let start = CACurrentMediaTime()
            canvas.onFrame = { [weak self, weak canvas] time in
                guard let self, let canvas, !self.finished else { return }
                let progress = min(1, max(0, (time - start) / duration))
                let motion = EverPageMotion.sample(progress, duration: duration)
                canvas.layers.removeAll(keepingCapacity: true)
                canvas.layers.append(EverWarpLayer(texture: texture, rect: self.bounds,
                                                   travel: self.direction * motion.travel,
                                                   depth: motion.depth, vertical: self.vertical,
                                                   blur: motion.blur, direction: self.direction))
                if progress >= 1 { self.finish() }
            }
            canvas.isPaused = false
        }
    }

    private func fadeIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in self?.finish() }
        }
    }

    @objc func finish() {
        guard !finished else { return }
        finished = true
        hasRun = true
        captureTask?.cancel()
        captureTask = nil
        canvas?.stop()
        canvas = nil
        layer?.removeAllAnimations()
        layer?.backgroundColor = NSColor.clear.cgColor
        alphaValue = 1
        Task { @MainActor [weak self] in self?.onCompletion?() }
    }
}
#endif
