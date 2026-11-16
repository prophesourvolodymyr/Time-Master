import SwiftUI

extension View {
    /// The title the window carries (Window menu, page travel) for everything below, replacing titles set deeper in
    /// the tree, e.g. by a header row that a list recycles while scrolling. No effect on iOS.
    @ViewBuilder
    func macWindowTitle(_ title: String) -> some View {
        #if os(macOS)
        transformPreference(MacWindowTitlePreferenceKey.self) { $0 = title }
        #else
        self
        #endif
    }

    /// The pages below draw their own big title, so the window's titlebar stays empty instead of repeating it.
    @ViewBuilder
    func macWindowTitleHidden() -> some View {
        #if os(macOS)
        transformPreference(MacWindowTitleHiddenPreferenceKey.self) { $0 = true }
        #else
        self
        #endif
    }
}

#if os(macOS)
import AppKit

struct MacWindowTitlePreferenceKey: PreferenceKey {
    static let defaultValue: String? = nil

    static func reduce(value: inout String?, nextValue: () -> String?) {
        if let title = nextValue() { value = title }
    }
}

struct MacWindowTitleHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct MacWindowChrome: ViewModifier {
    @State private var titleHidden = false

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(MacWindowTitleHiddenPreferenceKey.self) { titleHidden = $0 }
            .overlayPreferenceValue(MacWindowTitlePreferenceKey.self) { title in
                MacWindowProbe(title: title ?? "Tmax", showsTitle: !titleHidden)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

private struct MacWindowProbe: NSViewRepresentable {
    let title: String
    let showsTitle: Bool

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.title = title
        view.showsTitle = showsTitle
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.title = title
        view.showsTitle = showsTitle
        view.apply()
    }

    static func dismantleNSView(_ view: Probe, coordinator: ()) {
        view.disconnect()
    }

    final class Probe: NSView {
        var title = "Tmax"
        var showsTitle = true
        private var displayedShowsTitle = true
        private weak var styledWindow: NSWindow?
        private var accessory: NSTitlebarAccessoryViewController?
        private var titleView: NSHostingView<AnyView>?
        private var displayedTitle: String?
        private var sheetObserver: NSObjectProtocol?
        private var resizeObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            guard let window else { return }
            if styledWindow !== window {
                disconnect()
                styledWindow = window
                window.backgroundColor = NSColor(Theme.background)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.toolbar?.showsBaselineSeparator = false

                let accessory = NSTitlebarAccessoryViewController()
                let container = NSView()
                let view = NSHostingView(rootView: titleContent)
                view.sizingOptions = [.intrinsicContentSize]
                view.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(view)
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])
                accessory.view = container
                accessory.layoutAttribute = .left
                accessory.fullScreenMinHeight = 0
                self.accessory = accessory
                titleView = view
                window.addTitlebarAccessoryViewController(accessory)

                sheetObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.willBeginSheetNotification, object: nil, queue: .main
                ) { [weak self] notification in
                    guard let self, let parent = notification.object as? NSWindow, self.owns(parent) else { return }
                    DispatchQueue.main.async { self.styleAttachedSheets() }
                }
                resizeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification, object: window, queue: .main
                ) { [weak self] _ in
                    self?.sizeTitle()
                }
            }
            window.titleVisibility = .hidden
            if displayedTitle != title || displayedShowsTitle != showsTitle {
                displayedTitle = title
                displayedShowsTitle = showsTitle
                window.title = TimeMasterFont.initialCapitalizedTitle(title)
                titleView?.rootView = titleContent
                sizeTitle()
            }
            styleAttachedSheets()
        }

        private var titleContent: AnyView {
            guard showsTitle else { return AnyView(EmptyView()) }
            return AnyView(TimeMasterPageTitle(title, size: 22, relativeTo: .headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, EverSpacing.x3)
                .accessibilityIdentifier("mac-window-page-title")
                .environment(\.colorScheme, .dark))
        }

        private func sizeTitle() {
            guard let window = styledWindow, let titleView, let container = accessory?.view else { return }
            let natural = titleView.fittingSize
            container.setFrameSize(NSSize(
                width: min(natural.width, window.frame.width / 2),
                height: window.frame.height - window.contentLayoutRect.height
            ))
        }

        private func owns(_ window: NSWindow) -> Bool {
            var ancestor: NSWindow? = window
            while let current = ancestor {
                if current === styledWindow { return true }
                ancestor = current.sheetParent
            }
            return false
        }

        private func styleAttachedSheets() {
            var sheet = styledWindow?.attachedSheet
            while let current = sheet {
                if !(current is NSSavePanel) {
                    current.backgroundColor = NSColor(Theme.background)
                    current.titlebarAppearsTransparent = true
                    current.titleVisibility = .hidden
                    current.toolbar?.showsBaselineSeparator = false
                    current.contentView?.wantsLayer = true
                    current.contentView?.layer?.backgroundColor = NSColor(Theme.background).cgColor
                }
                sheet = current.attachedSheet
            }
        }

        func disconnect() {
            if let sheetObserver { NotificationCenter.default.removeObserver(sheetObserver) }
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
            if let window = styledWindow, let accessory,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            sheetObserver = nil
            resizeObserver = nil
            accessory = nil
            titleView = nil
            displayedTitle = nil
            styledWindow = nil
        }
    }
}
#endif
