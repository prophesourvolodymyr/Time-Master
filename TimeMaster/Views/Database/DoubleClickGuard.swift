import Foundation
#if os(macOS)
import AppKit
#endif

/// The rest of a double-click whose first click opened something (a page pushed onto a Database stack, the clip viewer
/// of a cover). Left alone, its second click lands on whatever the new screen has under the pointer and opens that
/// too. Plain values and no AppKit, so it can be tested anywhere: `ClickThroughGuard` feeds it the Mac's mouse events
/// and drops the ones it names.
struct DoubleClickGuard {
    /// One event of the left mouse button.
    enum Event: Equatable {
        /// A press; the system counts a press that continues a double-click as 2 (3 for a triple-click, and so on).
        case down(clickCount: Int)
        case dragged
        case up
    }

    /// The click that opened something: how far into its click sequence it was, and the time of the latest click
    /// of that sequence.
    private var opener: (clickCount: Int, time: TimeInterval)?
    /// A press being dropped; its drags and its release go with it.
    private var dropsPress = false

    /// The second (or a later) click of a double-click: a card whose single click does something else (folding a group
    /// open) opens on a double-click.
    static func isDoubleClick(clickCount: Int) -> Bool {
        clickCount >= 2
    }

    /// A click `clickCount` into its sequence, at `time`, just opened something.
    mutating func noteOpening(clickCount: Int, at time: TimeInterval) {
        opener = (clickCount, time)
    }

    /// Whether `event`, at `time`, still belongs to the click sequence that opened something, so it must not reach
    /// what opened: a later press of that sequence that comes within `interval` (the system's double-click interval)
    /// of the click before it, and the drags and release of a press dropped that way. Any other press ends the guard.
    mutating func drops(_ event: Event, at time: TimeInterval, interval: TimeInterval) -> Bool {
        switch event {
        case .down(let clickCount):
            guard let opener, clickCount > opener.clickCount, time - opener.time <= interval else {
                opener = nil
                dropsPress = false
                return false
            }
            self.opener = (clickCount, time)
            dropsPress = true
            return true
        case .dragged:
            return dropsPress
        case .up:
            defer { dropsPress = false }
            return dropsPress
        }
    }
}

/// Keeps the rest of a double-click out of what its first click opened, on the Mac (`DoubleClickGuard`): Database
/// navigation stacks report every push and the cover viewer its opening (`noteOpening`), and the later clicks of that
/// double-click are dropped before any view sees them. On iPhone and iPad it does nothing.
@MainActor
enum ClickThroughGuard {
    #if os(macOS)
    private static var rule = DoubleClickGuard()
    private static var monitor: Any?
    #endif

    /// Something just opened. When a click opened it, the later clicks of that click's double-click go nowhere.
    static func noteOpening() {
        #if os(macOS)
        guard let event = NSApp?.currentEvent, isLeftClick(event) else { return }
        installIfNeeded()
        rule.noteOpening(clickCount: event.clickCount, at: event.timestamp)
        #endif
    }

    /// The click being handled is the second (or a later) click of a double-click. False for a single click, a key,
    /// VoiceOver, and always on iPhone and iPad.
    static var isDoubleClick: Bool {
        #if os(macOS)
        guard let event = NSApp?.currentEvent, isLeftClick(event) else { return false }
        return DoubleClickGuard.isDoubleClick(clickCount: event.clickCount)
        #else
        return false
        #endif
    }

    #if os(macOS)
    private static func isLeftClick(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDown || event.type == .leftMouseUp
    }

    private static func installIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            let dropped = MainActor.assumeIsolated { ClickThroughGuard.drops(event) }
            return dropped ? nil : event
        }
    }

    private static func drops(_ event: NSEvent) -> Bool {
        let kind: DoubleClickGuard.Event
        switch event.type {
        case .leftMouseDown: kind = .down(clickCount: event.clickCount)
        case .leftMouseDragged: kind = .dragged
        default: kind = .up
        }
        return rule.drops(kind, at: event.timestamp, interval: NSEvent.doubleClickInterval)
    }
    #endif
}
