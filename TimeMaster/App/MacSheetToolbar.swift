#if os(macOS)
import AppKit
import SwiftUI

enum AppToolbarPlacement: Equatable {
    case cancellationAction
    case confirmationAction
    case primaryAction

    var isLeading: Bool { self == .cancellationAction }

    fileprivate var nativePlacement: ToolbarItemPlacement {
        switch self {
        case .cancellationAction: return .cancellationAction
        case .confirmationAction: return .confirmationAction
        case .primaryAction: return .primaryAction
        }
    }
}

struct AppToolbarEntry: Identifiable {
    let id: String
    let placement: AppToolbarPlacement
    let content: AnyView
}

protocol AppToolbarContent {
    var appToolbarEntries: [AppToolbarEntry] { get }
}

extension AppToolbarEntry: AppToolbarContent {
    var appToolbarEntries: [AppToolbarEntry] { [self] }
}

extension AppToolbarEntry: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: placement.nativePlacement) { content }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement.nativePlacement) { content }
        }
    }
}

@resultBuilder
enum AppToolbarBuilder {
    static func buildExpression<Content: AppToolbarContent>(_ content: Content) -> [AppToolbarEntry] { content.appToolbarEntries }
    static func buildBlock(_ parts: [AppToolbarEntry]...) -> [AppToolbarEntry] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [AppToolbarEntry]?) -> [AppToolbarEntry] { part ?? [] }
    static func buildEither(first part: [AppToolbarEntry]) -> [AppToolbarEntry] { part }
    static func buildEither(second part: [AppToolbarEntry]) -> [AppToolbarEntry] { part }
    static func buildArray(_ parts: [[AppToolbarEntry]]) -> [AppToolbarEntry] { parts.flatMap { $0 } }
    static func buildLimitedAvailability(_ part: [AppToolbarEntry]) -> [AppToolbarEntry] { part }
}

extension View {
    func toolbar(@AppToolbarBuilder content: () -> [AppToolbarEntry]) -> some View {
        modifier(AppToolbarModifier(entries: content()))
    }
}

enum MacSheetContext {
    static func isSheetLike(_ window: NSWindow) -> Bool {
        let name = NSStringFromClass(type(of: window))
        return name.contains("SheetPresentationWindow")
            || name.contains("Popover")
            || window.styleMask.contains(.docModalWindow)
            || window.sheetParent != nil
    }

    static var isPresentingSheet: Bool {
        guard let app = NSApp else { return false }
        if let key = app.keyWindow, isSheetLike(key) { return true }
        return app.windows.contains { window in
            isSheetLike(window) && !window.isVisible && (window.contentView?.subviews.isEmpty ?? true)
        }
    }
}

private struct AppToolbarModifier: ViewModifier {
    let entries: [AppToolbarEntry]
    @State private var inSheet: Bool

    init(entries: [AppToolbarEntry]) {
        self.entries = entries
        _inSheet = State(initialValue: MacSheetContext.isPresentingSheet)
    }

    func body(content: Content) -> some View {
        content
            .padding(.top, inSheet ? MacSheetActionRow.height : 0)
            .overlay(alignment: .top) {
                if inSheet { MacSheetActionRow(entries: entries) }
            }
            .background(
                MacSheetProbe(inSheet: $inSheet)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
            .toolbar { MacWindowToolbarItems(entries: entries) }
    }
}

private struct MacWindowToolbarItems: ToolbarContent {
    let entries: [AppToolbarEntry]

    var body: some ToolbarContent {
        if entries.contains(where: { $0.placement.isLeading }) {
            group(placement: .navigation, items: entries.filter { $0.placement.isLeading })
        }
        if entries.contains(where: { !$0.placement.isLeading }) {
            group(placement: .primaryAction, items: entries.filter { !$0.placement.isLeading })
        }
    }

    @ToolbarContentBuilder
    private func group(placement: ToolbarItemPlacement, items: [AppToolbarEntry]) -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: placement) { stack(items) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) { stack(items) }
        }
    }

    private func stack(_ items: [AppToolbarEntry]) -> some View {
        HStack(spacing: EverSpacing.x2) {
            ForEach(items) { $0.content }
        }
    }
}

private struct MacSheetActionRow: View {
    static let height: CGFloat = EverLayout.minimumTouchTarget + EverSpacing.x2 + EverSpacing.x1

    let entries: [AppToolbarEntry]

    var body: some View {
        HStack(spacing: EverSpacing.x2) {
            ForEach(entries.filter { $0.placement.isLeading }) { entry in
                entry.content.keyboardShortcut(.cancelAction)
            }
            Spacer(minLength: 0)
            ForEach(entries.filter { !$0.placement.isLeading }) { entry in
                if entry.placement == .confirmationAction {
                    entry.content.keyboardShortcut(.defaultAction)
                } else {
                    entry.content
                }
            }
        }
        .padding(.horizontal, EverSpacing.x3)
        .padding(.top, EverSpacing.x2)
        .padding(.bottom, EverSpacing.x1)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(Theme.background)
        .transaction { $0.animation = nil }
    }
}

private struct MacSheetProbe: NSViewRepresentable {
    @Binding var inSheet: Bool

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.binding = $inSheet
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.binding = $inSheet
    }

    final class Probe: NSView {
        var binding: Binding<Bool>?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            let sheetLike = MacSheetContext.isSheetLike(window)
            guard binding?.wrappedValue != sheetLike else { return }
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                self?.binding?.wrappedValue = sheetLike
            }
        }
    }
}
#endif
