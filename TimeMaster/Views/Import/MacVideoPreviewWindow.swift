#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum MacVideoPreviewWindow {
    private static var controllers: [URL: MacVideoPreviewWindowController] = [:]

    @discardableResult
    static func present(
        url: URL,
        title: String? = nil,
        comment: String? = nil,
        onSaveComment: ((String) throws -> Void)? = nil,
        onCut: @escaping (URL) -> Void,
        onClose: (() -> Void)? = nil
    ) -> NSWindow {
        let key = url.standardizedFileURL
        if let controller = controllers[key], let window = controller.window {
            controller.onCut = onCut
            controller.onClose = onClose
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return window
        }
        let controller = MacVideoPreviewWindowController(
            url: url,
            title: title,
            comment: comment,
            onSaveComment: onSaveComment,
            onCut: onCut,
            onClose: onClose,
            onReleased: { controllers.removeValue(forKey: key) }
        )
        controllers[key] = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return controller.window!
    }
}

@MainActor
private final class MacVideoPreviewWindowController: NSWindowController, NSWindowDelegate {
    let url: URL
    let model: MacVideoEditorModel
    var onCut: (URL) -> Void
    var onClose: (() -> Void)?
    private var onReleased: (() -> Void)?
    private var scopedAccess: Bool

    init(
        url: URL,
        title: String?,
        comment: String?,
        onSaveComment: ((String) throws -> Void)?,
        onCut: @escaping (URL) -> Void,
        onClose: (() -> Void)?,
        onReleased: @escaping () -> Void
    ) {
        self.url = url
        self.onCut = onCut
        self.onClose = onClose
        self.onReleased = onReleased
        scopedAccess = url.startAccessingSecurityScopedResource()
        model = MacVideoEditorModel(url: url)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title ?? url.deletingPathExtension().lastPathComponent
        window.minSize = NSSize(width: 480, height: 360)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        MacVideoWindowChrome.apply(to: window)
        super.init(window: window)
        window.delegate = self
        let hosting = NSHostingController(rootView: MacVideoPreviewContent(
            model: model,
            url: url,
            comment: comment,
            onSaveComment: onSaveComment,
            onCut: { [weak self] in self?.cut() }
        ))
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 860, height: 600))
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func windowWillClose(_ notification: Notification) {
        model.releaseResources()
        window?.contentViewController = nil
        if scopedAccess {
            url.stopAccessingSecurityScopedResource()
            scopedAccess = false
        }
        let closed = onClose
        onClose = nil
        let released = onReleased
        onReleased = nil
        onCut = { _ in }
        closed?()
        released?()
    }

    private func cut() {
        let action = onCut
        let sourceURL = url
        model.pausePlayback()
        action(sourceURL)
        close()
    }
}

private struct MacVideoPreviewContent: View {
    @ObservedObject var model: MacVideoEditorModel
    let url: URL
    let onSaveComment: ((String) throws -> Void)?
    let onCut: () -> Void
    @State private var comment: String
    @State private var isEditingComment = false

    init(
        model: MacVideoEditorModel,
        url: URL,
        comment: String?,
        onSaveComment: ((String) throws -> Void)?,
        onCut: @escaping () -> Void
    ) {
        self.model = model
        self.url = url
        self.onSaveComment = onSaveComment
        self.onCut = onCut
        _comment = State(initialValue: comment ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "film")
                    .foregroundStyle(Theme.textSecondary)
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(TimeMasterFont.rowTitle())
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Cut", systemImage: "scissors", action: onCut)
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                    .keyboardShortcut("e", modifiers: .command)
                    .help("Cut (C or ⌘E)")
            }
            .padding(12)
            .background(Theme.surface)

            MacVideoPlayerView(player: model.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if model.duration == 0, model.message == nil {
                        ProgressView().tint(.white)
                    }
                }
                .padding(12)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                        model.togglePlayback()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(model.duration <= 0)
                    Text(timeString(model.currentTime))
                        .font(TimeMasterFont.technical())
                        .monospacedDigit()
                    Slider(
                        value: Binding(get: { model.currentTime }, set: { model.updateScrubPosition($0) }),
                        in: 0...max(model.duration, 0.01),
                        onEditingChanged: { editing in
                            if editing { model.beginScrubbing() } else { model.endScrubbing() }
                        }
                    )
                    .tint(Theme.toolbarOrange)
                    .disabled(model.duration <= 0)
                    .accessibilityLabel("Preview position")
                    Text(timeString(model.duration))
                        .font(TimeMasterFont.technical())
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
                if let message = model.message {
                    Text(message)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                if !comment.isEmpty || onSaveComment != nil {
                    HStack(alignment: .top, spacing: 10) {
                        if !comment.isEmpty {
                            MediaCommentBubble(text: comment)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer(minLength: 0)
                        }
                        if onSaveComment != nil {
                            Button(comment.isEmpty ? "Add comment" : "Edit comment", systemImage: "text.bubble") {
                                model.pausePlayback()
                                isEditingComment = true
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(TimeMasterToolbarIconButtonStyle())
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.surface)
        }
        .background(Theme.background)
        .background { MacVideoPreviewShortcuts(model: model, onCut: onCut) }
        .sheet(isPresented: $isEditingComment) {
            MediaCommentEditor(mediaURL: url, comment: comment) { updated in
                try onSaveComment?(updated)
                comment = updated
            }
            .id(url)
        }
        .onDisappear(perform: model.pausePlayback)
    }

    private func timeString(_ value: Double) -> String {
        let seconds = value.isFinite ? max(0, Int(value)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct MacVideoPreviewShortcuts: View {
    @ObservedObject var model: MacVideoEditorModel
    let onCut: () -> Void

    var body: some View {
        Group {
            Button("Cut", action: onCut)
                .keyboardShortcut("c", modifiers: [])
            Button("Play or pause") { model.togglePlayback() }
                .keyboardShortcut("k", modifiers: [])
                .disabled(model.duration <= 0)
            Button("Back 5 seconds") { model.seek(to: model.currentTime - 5) }
                .keyboardShortcut("j", modifiers: [])
                .disabled(model.duration <= 0)
            Button("Forward 5 seconds") { model.seek(to: model.currentTime + 5) }
                .keyboardShortcut("l", modifiers: [])
                .disabled(model.duration <= 0)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
#endif
