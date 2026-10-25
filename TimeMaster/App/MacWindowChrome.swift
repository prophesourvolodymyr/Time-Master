#if os(macOS)
import AppKit
import SwiftUI

struct MacWindowTitlePreferenceKey: PreferenceKey {
    static let defaultValue: String? = nil

    static func reduce(value: inout String?, nextValue: () -> String?) {
        if let title = nextValue() { value = title }
    }
}

struct MacWindowChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(MacWindowTitlePreferenceKey.self) { title in
            MacWindowProbe(title: title ?? "Tmax")
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct MacWindowProbe: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.title = title
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.title = title
        view.apply()
    }

    static func dismantleNSView(_ view: Probe, coordinator: ()) {
        view.disconnect()
    }

    final class Probe: NSView {
        var title = "Tmax"
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
            if displayedTitle != title {
                displayedTitle = title
                window.title = TimeMasterFont.initialCapitalizedTitle(title)
                titleView?.rootView = titleContent
                sizeTitle()
            }
            styleAttachedSheets()
        }

        private var titleContent: AnyView {
            AnyView(TimeMasterPageTitle(title, size: 22, relativeTo: .headline)
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
