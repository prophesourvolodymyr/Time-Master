#if os(macOS)
import AppKit
import SwiftUI

struct HomeWidgetGestureSurface: View {
    let resizing: Bool
    let viewport: CGRect
    let onChange: (HomeWidgetGesturePhase, CGSize) -> Void

    @StateObject private var session = HomeWidgetPointerSession()
    @GestureState private var touching = false
    @State private var hovering = false
    @State private var grabbing = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay {
                if !resizing {
                    RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(grabbing ? 0.5 : hovering ? 0.36 : 0), lineWidth: 1.5)
                        .animation(.easeOut(duration: 0.12), value: hovering)
                        .allowsHitTesting(false)
                }
            }
            .background {
                HomeWidgetPointerBridge(session: session, viewport: viewport, onChange: onChange, grabbing: $grabbing)
            }
            .gesture(
                DragGesture(minimumDistance: resizing ? 0 : 6, coordinateSpace: .global)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { value in
                        session.dragChanged(translation: value.translation, location: value.location)
                    }
                    .onEnded { _ in session.dragEnded() }
            )
            .onChange(of: touching) { _, isTouching in
                if !isTouching { session.gestureLost() }
            }
            .onHover { hovering = $0 }
            .homeWidgetPointer(resizing ? nil : (grabbing ? .grabbing : .grab))
    }
}

struct HomeWidgetResizeGripAffordance: ViewModifier {
    let leading: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                HomeWidgetResizeGrip(leading: leading)
                    .stroke(.white.opacity(hovering ? 0.4 : 0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .padding(12)
                    .blur(radius: 3)
                    .animation(.easeOut(duration: 0.12), value: hovering)
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
            .homeWidgetPointer(.resize(leading: leading))
    }
}

private enum HomeWidgetPointer {
    case grab
    case grabbing
    case resize(leading: Bool)

    @available(macOS 15.0, *)
    var style: PointerStyle {
        switch self {
        case .grab: .grabIdle
        case .grabbing: .grabActive
        case .resize(let leading): .frameResize(position: leading ? .bottomLeading : .bottomTrailing)
        }
    }
}

private extension View {
    @ViewBuilder
    func homeWidgetPointer(_ pointer: HomeWidgetPointer?) -> some View {
        if #available(macOS 15.0, *), let pointer {
            pointerStyle(pointer.style)
        } else {
            self
        }
    }
}

private struct HomeWidgetPointerBridge: NSViewRepresentable {
    let session: HomeWidgetPointerSession
    let viewport: CGRect
    let onChange: (HomeWidgetGesturePhase, CGSize) -> Void
    let grabbing: Binding<Bool>

    func makeNSView(context: Context) -> HomeWidgetPointerProbe {
        let view = HomeWidgetPointerProbe()
        view.session = session
        session.probe = view
        return view
    }

    func updateNSView(_ view: HomeWidgetPointerProbe, context: Context) {
        session.probe = view
        session.viewport = viewport
        session.onChange = onChange
        session.grabbing = grabbing
    }

    static func dismantleNSView(_ view: HomeWidgetPointerProbe, coordinator: ()) {
        guard let session = view.session else { return }
        Task { @MainActor in session.cancel() }
    }
}

private final class HomeWidgetPointerProbe: NSView {
    var session: HomeWidgetPointerSession?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private let homeWidgetEscapeKeyCode: UInt16 = 53
private let homeWidgetAutoscrollSpeed: CGFloat = 420

@MainActor
private final class HomeWidgetPointerSession: ObservableObject {
    weak var probe: NSView?
    var viewport = CGRect.zero
    var onChange: (HomeWidgetGesturePhase, CGSize) -> Void = { _, _ in }
    var grabbing: Binding<Bool>?

    private weak var scrollView: NSScrollView?
    private weak var reference: NSView?
    private var origin: CGPoint?
    private var published = CGSize.zero
    private var location = CGPoint.zero
    private var suppressed = false
    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    func dragChanged(translation: CGSize, location: CGPoint) {
        guard !suppressed else { return }
        self.location = location
        if origin == nil {
            begin(translation: translation)
        } else {
            publish()
        }
    }

    func dragEnded() {
        defer { suppressed = false }
        guard origin != nil else { return }
        publish()
        finish(.ended)
    }

    func gestureLost() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            suppressed = false
            cancel()
        }
    }

    func cancel() {
        guard origin != nil else { return }
        finish(.cancelled)
    }

    private func begin(translation: CGSize) {
        guard let window = probe?.window else {
            suppressed = true
            return
        }
        scrollView = probe?.enclosingScrollView
        reference = scrollView?.documentView ?? window.contentView
        guard let point = pointer() else {
            suppressed = true
            return
        }
        origin = CGPoint(x: point.x - translation.width, y: point.y - translation.height)
        published = .zero
        install(for: window)
        grabbing?.wrappedValue = true
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        onChange(.began, .zero)
        publish()
    }

    private func pointer() -> CGPoint? {
        guard let reference, let window = reference.window else { return nil }
        let point = reference.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return CGPoint(x: point.x, y: reference.isFlipped ? point.y : -point.y)
    }

    private func publish() {
        guard let origin, let point = pointer() else { return }
        let translation = CGSize(width: point.x - origin.x, height: point.y - origin.y)
        guard translation != published else { return }
        published = translation
        onChange(.changed, translation)
    }

    private func finish(_ phase: HomeWidgetGesturePhase) {
        tearDown()
        onChange(phase, .zero)
    }

    private func interrupt() {
        guard origin != nil else { return }
        suppressed = true
        finish(.cancelled)
    }

    private func install(for window: NSWindow) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == homeWidgetEscapeKeyCode else { return event }
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.origin != nil else { return false }
                self.interrupt()
                return true
            }
            return handled ? nil : event
        }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.interrupt() }
            },
            center.addObserver(forName: NSApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.interrupt() }
            },
        ]
        lastTick = 0
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tearDown() {
        timer?.invalidate()
        timer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        origin = nil
        scrollView = nil
        reference = nil
        grabbing?.wrappedValue = false
    }

    private func tick() {
        guard origin != nil else { return }
        autoscroll()
        publish()
    }

    private func autoscroll() {
        guard let scrollView, let window = scrollView.window else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = lastTick == 0 ? 1.0 / 60.0 : min(now - lastTick, 1.0 / 20.0)
        lastTick = now
        let edge = min(80, viewport.height * 0.18)
        guard edge > 0 else { return }
        let local = scrollView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let fromTop = scrollView.isFlipped ? local.y - scrollView.bounds.minY : scrollView.bounds.maxY - local.y
        let fromRail = viewport.maxY - location.y
        let velocity: CGFloat
        if fromTop < edge {
            velocity = -min(1, (edge - fromTop) / edge) * homeWidgetAutoscrollSpeed
        } else if fromRail < edge {
            velocity = min(1, (edge - fromRail) / edge) * homeWidgetAutoscrollSpeed
        } else {
            return
        }
        let clip = scrollView.contentView
        let downward: CGFloat = (scrollView.documentView?.isFlipped ?? true) ? 1 : -1
        var proposed = clip.bounds
        proposed.origin.y += downward * velocity * CGFloat(elapsed)
        let constrained = clip.constrainBoundsRect(proposed)
        guard abs(constrained.origin.y - clip.bounds.origin.y) > 0.01 else { return }
        clip.scroll(to: constrained.origin)
        scrollView.reflectScrolledClipView(clip)
    }
}
#endif
