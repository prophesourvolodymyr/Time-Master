#if os(macOS)
import AppKit

/// Key codes the engine reads.
enum KeyNavKey {
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let space: UInt16 = 49
    static let `return`: UInt16 = 36
    static let enter: UInt16 = 76
    static let escape: UInt16 = 53

    static func direction(_ keyCode: UInt16) -> KeyNavDirection? {
        switch keyCode {
        case left: return .left
        case right: return .right
        case down: return .down
        case up: return .up
        default: return nil
        }
    }

    /// Arrows, Space, Return, Enter and Escape: every other key goes straight on.
    static func isNavigationKey(_ keyCode: UInt16) -> Bool {
        direction(keyCode) != nil || [space, `return`, enter, escape].contains(keyCode)
    }
}

/// The one local event monitor (keys, and clicks that hide the ring) plus menu-tracking state, for every window.
@MainActor
final class KeyNavMonitor {
    static let shared = KeyNavMonitor()

    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var trackingMenus = Set<ObjectIdentifier>()

    var isTrackingMenu: Bool { !trackingMenus.isEmpty }

    func installIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { event in
            let consumed = MainActor.assumeIsolated { KeyNavMonitor.shared.handle(event) }
            return consumed ? nil : event
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { note in
            guard let menu = note.object as? NSMenu else { return }
            let id = ObjectIdentifier(menu)
            MainActor.assumeIsolated { _ = KeyNavMonitor.shared.trackingMenus.insert(id) }
        })
        observers.append(center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { note in
            guard let menu = note.object as? NSMenu else { return }
            let id = ObjectIdentifier(menu)
            MainActor.assumeIsolated { _ = KeyNavMonitor.shared.trackingMenus.remove(id) }
        })
    }

    private func handle(_ event: NSEvent) -> Bool {
        if event.type == .keyDown {
            guard let router = KeyNavRouter.router(for: event.window) else { return false }
            if router.handleKey(event) { return true }
            if event.keyCode == KeyNavKey.escape, let window = event.window {
                KeyNavPolicy.releaseKeys(afterEscapeIn: window)
            }
            return false
        }
        if event.eventNumber != KeyNavClicker.marker {
            KeyNavRouter.router(for: event.window)?.pointerDidClick()
        }
        return false
    }
}

/// When the engine must leave the keys alone.
@MainActor
enum KeyNavPolicy {
    /// A first responder inside one of these views (by class name) keeps its keys.
    static var keyOwningClassNames = ["WKWebView", "PDFView", "AVPlayerView", "MKMapView", "QLPreviewView"]

    /// No menu is open, no sheet, modal or popover is up, and the first responder is not a control that uses
    /// arrows, Space or Return itself (text fields and views, lists, pickers, steppers, sliders).
    static func keysAreFree(in window: NSWindow) -> Bool {
        if KeyNavMonitor.shared.isTrackingMenu { return false }
        if window.attachedSheet != nil { return false }
        if let modal = NSApp.modalWindow, modal !== window { return false }
        let popoverIsUp = NSApp.windows.contains { other in
            other !== window && other.isVisible && NSStringFromClass(type(of: other)).contains("Popover")
        }
        if popoverIsUp { return false }
        return !responderOwnsKeys(window.firstResponder)
    }

    static func responderOwnsKeys(_ responder: NSResponder?) -> Bool {
        guard let responder else { return false }
        if responder is NSText || responder is NSTextField || responder is NSTableView
            || responder is NSCollectionView || responder is NSBrowser || responder is NSDatePicker
            || responder is NSSlider || responder is NSStepper || responder is NSSegmentedControl
            || responder is NSPopUpButton || responder is NSColorWell {
            return true
        }
        var view = responder as? NSView
        while let current = view {
            let name = NSStringFromClass(type(of: current))
            if keyOwningClassNames.contains(where: { name.contains($0) }) { return true }
            view = current.superview
        }
        return false
    }

    /// The way back out of a text field or picker: once Escape has been delivered, if nothing used it (the field
    /// is still focused: no sheet closed, no search dismissed), the field lets go so the arrows navigate again.
    /// Multi-line text views keep their focus.
    static func releaseKeys(afterEscapeIn window: NSWindow) {
        guard let responder = window.firstResponder, responderOwnsKeys(responder) else { return }
        if let textView = responder as? NSTextView, !textView.isFieldEditor { return }
        guard responder is NSText || responder is NSControl || responder is NSTableView else { return }
        RunLoop.main.perform(inModes: [.common]) { [weak window, weak responder] in
            MainActor.assumeIsolated {
                guard let window, let responder, window.firstResponder === responder else { return }
                window.makeFirstResponder(nil)
            }
        }
    }
}

/// A window's coordinates with the origin at its top-left corner (y grows downward): the one space every host's
/// frames are mapped into.
@MainActor
struct KeyNavWindowSpace {
    let window: NSWindow

    var size: CGSize { window.frame.size }
    var bounds: CGRect { CGRect(origin: .zero, size: size) }

    /// `rect` in `view`'s coordinates (SwiftUI `.global` space for a hosting view) → window space.
    func unified(_ rect: CGRect, from view: NSView) -> CGRect {
        let base = view.convert(rect, to: nil)
        return CGRect(x: base.minX, y: size.height - base.maxY, width: base.width, height: base.height)
    }

    /// Window space → AppKit window coordinates (origin bottom-left).
    func windowPoint(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: size.height - point.y)
    }

    /// The pointer, when it is over the window.
    var pointer: CGPoint? {
        let location = window.mouseLocationOutsideOfEventStream
        let point = CGPoint(x: location.x, y: size.height - location.y)
        return bounds.contains(point) ? point : nil
    }

    /// The part of the window not covered by the title bar and toolbar.
    var contentLayoutRect: CGRect {
        let rect = window.contentLayoutRect
        return CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// The window's scroll views (a SwiftUI `ScrollView` is an `NSScrollView` on the Mac) with what each one shows.
@MainActor
struct KeyNavScrollMap {
    struct Entry {
        let view: NSScrollView
        /// What the clip view shows, in window space.
        let visibleFrame: CGRect
    }

    let space: KeyNavWindowSpace
    let entries: [Entry]

    init(window: NSWindow) {
        let space = KeyNavWindowSpace(window: window)
        var found: [Entry] = []
        var stack: [NSView] = window.contentView.map { [$0] } ?? []
        while let view = stack.popLast() {
            if let scrollView = view as? NSScrollView, !scrollView.isHiddenOrHasHiddenAncestor {
                let clip = scrollView.contentView
                found.append(Entry(view: scrollView, visibleFrame: space.unified(clip.bounds, from: clip)))
            }
            stack.append(contentsOf: view.subviews)
        }
        self.space = space
        entries = found
    }

    /// The scroll view showing `viewport` (a SwiftUI scroll view's visible area): the best overlap, at least half.
    func scrollView(showing viewport: CGRect) -> NSScrollView? {
        var best: (view: NSScrollView, score: CGFloat)?
        for entry in entries {
            let common = entry.visibleFrame.intersection(viewport)
            guard !common.isNull else { continue }
            let union = entry.visibleFrame.union(viewport)
            let score = (common.width * common.height) / max(1, union.width * union.height)
            if score >= 0.5, score > (best?.score ?? 0) {
                best = (entry.view, score)
            }
        }
        return best?.view
    }
}

/// Scrolls the window's scroll views to show a focused target. Instant, like a terminal UI: nothing moves on its
/// own, and a click right after lands on target.
@MainActor
enum KeyNavScroller {
    /// Space kept between a revealed target and the edge of what is visible.
    static let margin: CGFloat = 16

    /// Scrolls the target's scroll views (horizontal strip first, then the page) until it shows clear of the title
    /// bar and `obstructions`; returns how far it moved on screen. All in window space.
    @discardableResult
    static func reveal(_ placement: KeyNavPlacement, in window: NSWindow, obstructions: [CGRect]) -> CGVector {
        let viewports = placement.viewports
        guard !viewports.isEmpty else { return CGVector(dx: 0, dy: 0) }
        let map = KeyNavScrollMap(window: window)
        let space = map.space
        let rect = placement.frame
        var target = rect
        for viewport in viewports {
            guard let scrollView = map.scrollView(showing: viewport), let document = scrollView.documentView else { continue }
            let clip = scrollView.contentView
            let visible = trimmed(viewport.intersection(space.contentLayoutRect), by: obstructions)
                .insetBy(dx: margin, dy: margin)
            guard !visible.isNull, visible.width > 0, visible.height > 0 else { continue }
            let dx = document.frame.width > clip.bounds.width + 0.5
                ? offset(target.minX, target.maxX, visible.minX, visible.maxX) : 0
            let dy = document.frame.height > clip.bounds.height + 0.5
                ? offset(target.minY, target.maxY, visible.minY, visible.maxY) : 0
            guard dx != 0 || dy != 0 else { continue }
            let from = clip.convert(space.windowPoint(target.origin), from: nil)
            let to = clip.convert(space.windowPoint(CGPoint(x: target.minX + dx, y: target.minY + dy)), from: nil)
            let proposed = NSRect(
                x: clip.bounds.minX + to.x - from.x,
                y: clip.bounds.minY + to.y - from.y,
                width: clip.bounds.width,
                height: clip.bounds.height
            )
            let origin = clip.constrainBoundsRect(proposed).origin
            guard origin != clip.bounds.origin else { continue }
            // Follow one document point through the scroll to learn the real (constrained) displacement.
            let pinned = document.convert(space.windowPoint(target.origin), from: nil)
            clip.scroll(to: origin)
            scrollView.reflectScrolledClipView(clip)
            let landed = document.convert(pinned, to: nil)
            let now = CGPoint(x: landed.x, y: space.size.height - landed.y)
            target = target.offsetBy(dx: now.x - target.minX, dy: now.y - target.minY)
        }
        return CGVector(dx: rect.minX - target.minX, dy: rect.minY - target.minY)
    }

    /// `rect` with every obstruction that crosses it cut off its nearer end (top or bottom).
    static func trimmed(_ rect: CGRect, by obstructions: [CGRect]) -> CGRect {
        guard !rect.isNull else { return rect }
        var rect = rect
        for obstruction in obstructions where obstruction.intersects(rect) {
            if obstruction.midY > rect.midY {
                rect.size.height = max(0, obstruction.minY - rect.minY)
            } else {
                let top = min(rect.maxY, obstruction.maxY)
                rect.size.height = max(0, rect.maxY - top)
                rect.origin.y = top
            }
        }
        return rect
    }

    /// How far content must move along one axis so `lower...upper` fits in `visibleLower...visibleUpper`
    /// (a target larger than the view aligns its leading edge).
    static func offset(_ lower: CGFloat, _ upper: CGFloat, _ visibleLower: CGFloat, _ visibleUpper: CGFloat) -> CGFloat {
        if upper - lower > visibleUpper - visibleLower || lower < visibleLower { return lower - visibleLower }
        if upper > visibleUpper { return upper - visibleUpper }
        return 0
    }
}

/// Clicks a point the way the pointer would: the activation of targets without an action (menus, tap gestures).
@MainActor
enum KeyNavClicker {
    /// Marks synthetic clicks so they do not hide the focus ring.
    static let marker = 0x4B4E

    static func click(at point: CGPoint, in window: NSWindow) {
        let location = KeyNavWindowSpace(window: window).windowPoint(point)
        let time = ProcessInfo.processInfo.systemUptime
        let phases: [(type: NSEvent.EventType, pressure: Float)] = [(.leftMouseDown, 1), (.leftMouseUp, 0)]
        for phase in phases {
            guard let event = NSEvent.mouseEvent(
                with: phase.type,
                location: location,
                modifierFlags: [],
                timestamp: time,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: marker,
                clickCount: 1,
                pressure: phase.pressure
            ) else { continue }
            NSApp.postEvent(event, atStart: false)
        }
    }
}
#endif
