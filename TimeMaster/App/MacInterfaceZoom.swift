#if os(macOS)
import SwiftUI
import AppKit

final class MacInterfaceZoom: ObservableObject {
    static let shared = MacInterfaceZoom()
    static let levels = [50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200]
    static let defaultLevel = 100
    static let defaultsKey = "tm.mac.interfaceZoomPercent"
    static let minimumLayoutSize = CGSize(width: 600, height: 450)
    fileprivate static let coordinateSpaceName = "tm.mac.interfaceZoom.root"

    @Published private(set) var level: Int
    private var keyMonitor: Any?

    private init() {
        level = Self.nearestLevel(to: UserDefaults.standard.integer(forKey: Self.defaultsKey))
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.perform(event)
        }
    }

    var scale: CGFloat { CGFloat(level) / 100 }
    var canZoomIn: Bool { level < Self.levels[Self.levels.count - 1] }
    var canZoomOut: Bool { level > Self.levels[0] }
    var isActualSize: Bool { level == Self.defaultLevel }

    func zoomIn() {
        if let next = Self.levels.first(where: { $0 > level }) { set(next) }
    }

    func zoomOut() {
        if let previous = Self.levels.last(where: { $0 < level }) { set(previous) }
    }

    func reset() {
        set(Self.defaultLevel)
    }

    func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    static func effectiveScale(level: Int, in size: CGSize) -> CGFloat {
        let requested = CGFloat(level) / 100
        guard size.width > 0, size.height > 0 else { return requested }
        let fit = min(size.width / minimumLayoutSize.width, size.height / minimumLayoutSize.height)
        return max(min(requested, fit), min(requested, 1))
    }

    private func set(_ newLevel: Int) {
        guard newLevel != level else { return }
        level = newLevel
        UserDefaults.standard.set(newLevel, forKey: Self.defaultsKey)
    }

    private static func nearestLevel(to stored: Int) -> Int {
        guard stored > 0 else { return defaultLevel }
        return levels.min { abs($0 - stored) < abs($1 - stored) } ?? defaultLevel
    }

    /// Menu items only refresh their enabled state when the menu opens, so a stale disabled item
    /// would swallow its shortcut. Handling the keys here also covers ⌘= next to ⌘+.
    private func perform(_ event: NSEvent) -> NSEvent? {
        guard event.window?.identifier != MacVideoWindowChrome.windowIdentifier else { return event }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers.contains(.command), modifiers.isDisjoint(with: [.option, .control]),
              let key = event.charactersIgnoringModifiers else { return event }
        let commandOnly = modifiers == .command
        switch key {
        case "+", "=":
            zoomIn()
        case "-" where commandOnly:
            zoomOut()
        case "0" where commandOnly:
            reset()
        default:
            return event
        }
        return nil
    }
}

extension View {
    /// Zooms a window's whole content. Apply once to the root view of each window.
    func macInterfaceZoom() -> some View {
        modifier(MacInterfaceZoomRoot())
    }

    /// Zooms sheet and popover content, which SwiftUI hosts in separate windows. Apply once to the
    /// root view inside the presentation closure, never inside reusable views.
    func macInterfaceZoomSheet() -> some View {
        modifier(MacInterfaceZoomSheetRoot())
    }
}

/// SwiftUI reports global frames after the zoom transform. Interface code is laid out in the
/// zoomed viewport, so global frames and drags are read in the unscaled root space instead; a
/// hierarchy without a zoom root falls back to the real global space.
extension GeometryProxy {
    func frame(in space: GlobalCoordinateSpace) -> CGRect {
        frame(in: .named(MacInterfaceZoom.coordinateSpaceName))
    }
}

extension DragGesture {
    init(minimumDistance: CGFloat = 10, coordinateSpace: GlobalCoordinateSpace) {
        self.init(minimumDistance: minimumDistance, coordinateSpace: .named(MacInterfaceZoom.coordinateSpaceName))
    }
}

private struct MacInterfaceZoomRoot: ViewModifier {
    @ObservedObject private var zoom = MacInterfaceZoom.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let size = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            content
                .modifier(MacInterfaceZoomViewport(
                    scale: MacInterfaceZoom.effectiveScale(level: zoom.level, in: size),
                    size: size,
                    insets: insets
                ))
                .ignoresSafeArea()
                .animation(zoom.animation(reduceMotion: reduceMotion), value: zoom.level)
        }
    }
}

private struct MacInterfaceZoomViewport: ViewModifier, Animatable {
    var scale: CGFloat
    let size: CGSize
    let insets: EdgeInsets

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(EdgeInsets(
                top: insets.top / scale,
                leading: insets.leading / scale,
                bottom: insets.bottom / scale,
                trailing: insets.trailing / scale
            ))
            .coordinateSpace(name: MacInterfaceZoom.coordinateSpaceName)
            .frame(width: size.width / scale, height: size.height / scale)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

private struct MacInterfaceZoomSheetRoot: ViewModifier {
    @ObservedObject private var zoom = MacInterfaceZoom.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        MacInterfaceZoomLayout(scale: zoom.scale) {
            content
                .coordinateSpace(name: MacInterfaceZoom.coordinateSpaceName)
                .scaleEffect(zoom.scale, anchor: .topLeading)
        }
        .animation(zoom.animation(reduceMotion: reduceMotion), value: zoom.level)
    }
}

private struct MacInterfaceZoomLayout: Layout {
    var scale: CGFloat

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(
            width: proposal.width.map { $0 / scale },
            height: proposal.height.map { $0 / scale }
        ))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width / scale, height: bounds.height / scale)
        )
    }
}
#endif
