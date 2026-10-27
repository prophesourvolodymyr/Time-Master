import SwiftUI

final class MarkdownTextController {
    #if os(iOS)
    weak var view: MarkdownUITextView?
    #else
    weak var view: MarkdownNSTextView?
    #endif

    var selectedRange: NSRange {
        #if os(iOS)
        view?.selectedRange ?? NSRange(location: 0, length: 0)
        #else
        view?.selectedRange() ?? NSRange(location: 0, length: 0)
        #endif
    }

    func perform(_ transform: (inout String, inout NSRange) -> Void) {
        guard let view else { return }
        #if os(iOS)
        var text = view.text ?? ""
        var range = view.selectedRange
        transform(&text, &range)
        view.replaceAll(with: text, selection: range)
        #else
        var text = view.string
        var range = view.selectedRange()
        transform(&text, &range)
        view.replaceAll(with: text, selection: range)
        #endif
    }

    func wrap(prefix: String, suffix: String, placeholder: String) {
        perform { text, range in
            MediaCommentFormatting.wrap(&text, selection: &range, prefix: prefix, suffix: suffix, placeholder: placeholder)
        }
    }

    func insertLink(label: String, url: URL) {
        perform { text, range in
            MediaCommentFormatting.insertLink(&text, selection: &range, label: label, url: url)
        }
    }

    func focus(at location: Int) {
        #if os(iOS)
        guard let view else { return }
        view.becomeFirstResponder()
        view.selectedRange = MediaCommentFormatting.clamped(NSRange(location: location, length: 0), in: view.text ?? "")
        #else
        guard let view else { return }
        view.window?.makeFirstResponder(view)
        view.setSelectedRange(MediaCommentFormatting.clamped(NSRange(location: location, length: 0), in: view.string))
        #endif
    }
}

#if os(iOS)
import UIKit

final class MarkdownUITextView: UITextView {
    var handlers = MarkdownTextHandlers()
    var kind: MarkdownBlock.Kind = .paragraph
    let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = textContainerInset
        placeholderLabel.frame = CGRect(
            x: inset.left + textContainer.lineFragmentPadding,
            y: inset.top,
            width: max(0, bounds.width - inset.left - inset.right - 2 * textContainer.lineFragmentPadding),
            height: placeholderLabel.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
        )
    }

    func replaceAll(with text: String, selection: NSRange) {
        guard let full = textRange(from: beginningOfDocument, to: endOfDocument) else { return }
        replace(full, withText: text)
        selectedRange = MediaCommentFormatting.clamped(selection, in: text)
        handlers.onChange(self.text ?? "", selectedRange)
    }

    override func deleteBackward() {
        if selectedRange.location == 0, selectedRange.length == 0, handlers.onBackspaceAtStart() { return }
        super.deleteBackward()
    }

    override func insertText(_ text: String) {
        if text == "\n", handleReturn() { return }
        super.insertText(text)
    }

    private func handleReturn() -> Bool {
        let range = selectedRange
        if case .code = kind {
            let source = (self.text ?? "") as NSString
            guard range.length == 0, NSMaxRange(range) == source.length, source.hasSuffix("\n") else { return false }
            textStorage.replaceCharacters(in: NSRange(location: source.length - 1, length: 1), with: "")
            handlers.onChange(self.text ?? "", NSRange(location: source.length - 1, length: 0))
            return handlers.onReturn(source.length - 1)
        }
        if range.length > 0 {
            textStorage.replaceCharacters(in: range, with: "")
            handlers.onChange(self.text ?? "", NSRange(location: range.location, length: 0))
        }
        _ = handlers.onReturn(range.location)
        return true
    }

    override func paste(_ sender: Any?) {
        let board = UIPasteboard.general
        if board.hasImages, let image = board.image, let data = image.pngData(), handlers.onPasteImage(data) { return }
        if let string = board.string, handlers.onPasteString(string, selectedRange) { return }
        super.paste(sender)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasStrings || UIPasteboard.general.hasImages
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override var keyCommands: [UIKeyCommand]? {
        let forward = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(tabForward))
        let backward = UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(tabBackward))
        forward.wantsPriorityOverSystemBehavior = true
        backward.wantsPriorityOverSystemBehavior = true
        return (super.keyCommands ?? []) + [forward, backward]
    }

    @objc private func tabForward() { _ = handlers.onTab(false) }
    @objc private func tabBackward() { _ = handlers.onTab(true) }
}

struct MarkdownBlockTextView: UIViewRepresentable {
    let blockID: UUID
    let text: String
    let kind: MarkdownBlock.Kind
    let placeholder: String
    let controller: MarkdownTextController
    let focus: MarkdownFocusRequest?
    let handlers: MarkdownTextHandlers

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MarkdownUITextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        storage.delegate = context.coordinator
        let view = MarkdownUITextView(frame: .zero, textContainer: container)
        context.coordinator.view = view
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.tintColor = MarkdownStyle.accentColor
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocorrectionType = .default
        view.accessibilityLabel = "Text block"
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.text = text
        context.coordinator.applyKind(view, kind: kind)
        controller.view = view
        return view
    }

    func updateUIView(_ view: MarkdownUITextView, context: Context) {
        context.coordinator.parent = self
        view.handlers = handlers
        view.kind = kind
        controller.view = view
        context.coordinator.isApplying = true
        defer { context.coordinator.isApplying = false }
        let selection = view.selectedRange
        let latest = handlers.liveText() ?? text
        var replaced = false
        if view.markedTextRange == nil {
            if view.text != latest {
                view.text = latest
                replaced = true
            }
            context.coordinator.applyKind(view, kind: kind)
        }
        let target = replaced ? MediaCommentFormatting.clamped(selection, in: latest) : selection
        if view.selectedRange != target { view.selectedRange = target }
        view.placeholderLabel.attributedText = NSAttributedString(string: placeholder, attributes: [
            .font: MarkdownStyle.base(for: kind).font,
            .foregroundColor: MarkdownStyle.dimColor
        ])
        view.placeholderLabel.isHidden = !(view.text ?? "").isEmpty || placeholder.isEmpty
        view.setNeedsLayout()
        if let focus, focus.blockID == blockID, focus.token != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focus.token
            let textAtRequest = view.text ?? ""
            DispatchQueue.main.async {
                let wasEditing = view.isFirstResponder
                view.becomeFirstResponder()
                let current = view.text ?? ""
                if !wasEditing || current == textAtRequest {
                    view.selectedRange = MediaCommentFormatting.clamped(NSRange(location: focus.location, length: 0), in: current)
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownUITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitting.height, 34))
    }

    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownBlockTextView
        var isApplying = false
        var lastFocusToken: UUID?
        weak var view: UITextView?
        private var styledKind: MarkdownBlock.Kind?

        init(_ parent: MarkdownBlockTextView) { self.parent = parent }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters), view?.markedTextRange == nil else { return }
            MarkdownInlineStyler.apply(to: textStorage, kind: parent.kind)
        }

        func applyKind(_ view: UITextView, kind: MarkdownBlock.Kind) {
            guard styledKind != kind else { return }
            styledKind = kind
            let selection = view.selectedRange
            view.textStorage.beginEditing()
            MarkdownInlineStyler.apply(to: view.textStorage, kind: kind)
            view.textStorage.endEditing()
            if view.selectedRange != selection { view.selectedRange = selection }
            let base = MarkdownStyle.base(for: kind)
            view.typingAttributes = [
                .font: base.font,
                .foregroundColor: base.color,
                .paragraphStyle: MarkdownStyle.paragraphStyle()
            ]
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.handlers.onFocus()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplying else { return }
            (textView as? MarkdownUITextView)?.placeholderLabel.isHidden = !textView.text.isEmpty
            parent.handlers.onChange(textView.text, textView.selectedRange)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplying else { return }
            parent.handlers.onSelection(textView.selectedRange)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement == "\n" else { return true }
            if case .code = parent.kind {
                let source = textView.text as NSString
                let atEnd = NSMaxRange(range) == source.length
                if atEnd, range.length == 0, source.hasSuffix("\n") {
                    textView.textStorage.replaceCharacters(in: NSRange(location: source.length - 1, length: 1), with: "")
                    parent.handlers.onChange(textView.text, NSRange(location: source.length - 1, length: 0))
                    return !parent.handlers.onReturn(source.length - 1)
                }
                return true
            }
            if range.length > 0 {
                textView.textStorage.replaceCharacters(in: range, with: "")
                parent.handlers.onChange(textView.text, NSRange(location: range.location, length: 0))
            }
            _ = parent.handlers.onReturn(range.location)
            return false
        }
    }
}

#else
import AppKit

final class MarkdownNSTextView: NSTextView {
    var handlers = MarkdownTextHandlers()
    var kind: MarkdownBlock.Kind = .paragraph
    var placeholder = ""
    var pasteboard = NSPasteboard.general

    func replaceAll(with text: String, selection: NSRange) {
        let range = NSRange(location: 0, length: (string as NSString).length)
        if shouldChangeText(in: range, replacementString: text) {
            textStorage?.replaceCharacters(in: range, with: text)
            didChangeText()
        }
        setSelectedRange(MediaCommentFormatting.clamped(selection, in: text))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncContainerWidth()
    }

    func syncContainerWidth() {
        guard let container = textContainer, frame.width > 1 else { return }
        let width = frame.width - textContainerInset.width * 2
        if container.containerSize.width != width {
            container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: MarkdownStyle.base(for: kind).font,
            .foregroundColor: MarkdownStyle.dimColor
        ]
        let origin = NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: textContainerInset.height)
        (placeholder as NSString).draw(at: origin, withAttributes: attributes)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { handlers.onFocus() }
        return accepted
    }

    override func paste(_ sender: Any?) {
        let board = pasteboard
        if let data = board.data(forType: .png) ?? board.data(forType: .tiff), handlers.onPasteImage(data) { return }
        if let string = board.string(forType: .string) {
            if handlers.onPasteString(string, selectedRange()) { return }
            insertText(string, replacementRange: selectedRange())
            return
        }
        super.paste(sender)
    }

    func caretIsOnFirstLine() -> Bool {
        guard let layout = layoutManager, let container = textContainer, layout.numberOfGlyphs > 0 else { return true }
        layout.ensureLayout(for: container)
        let location = min(selectedRange().location, max(0, (string as NSString).length - 1))
        let glyph = layout.glyphIndexForCharacter(at: location)
        let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return rect.minY <= layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY + 0.5
    }

    func caretIsOnLastLine() -> Bool {
        guard let layout = layoutManager, let container = textContainer, layout.numberOfGlyphs > 0 else { return true }
        layout.ensureLayout(for: container)
        let length = (string as NSString).length
        if selectedRange().location >= length { return true }
        let glyph = layout.glyphIndexForCharacter(at: selectedRange().location)
        let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let last = layout.lineFragmentRect(forGlyphAt: layout.numberOfGlyphs - 1, effectiveRange: nil)
        return rect.minY >= last.minY - 0.5
    }

    static func make() -> MarkdownNSTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = MarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 34), textContainer: container)
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = NSSize(width: 0, height: 5)
        view.insertionPointColor = MarkdownStyle.accentColor
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.setAccessibilityLabel("Text block")
        return view
    }
}

struct MarkdownBlockTextView: NSViewRepresentable {
    let blockID: UUID
    let text: String
    let kind: MarkdownBlock.Kind
    let placeholder: String
    let controller: MarkdownTextController
    let focus: MarkdownFocusRequest?
    let handlers: MarkdownTextHandlers

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> MarkdownNSTextView {
        let view = MarkdownNSTextView.make()
        view.delegate = context.coordinator
        view.string = text
        controller.view = view
        return view
    }

    func updateNSView(_ view: MarkdownNSTextView, context: Context) {
        context.coordinator.parent = self
        view.handlers = handlers
        view.kind = kind
        view.placeholder = placeholder
        controller.view = view
        context.coordinator.isApplying = true
        defer { context.coordinator.isApplying = false }
        let latest = handlers.liveText() ?? text
        if !view.hasMarkedText() {
            if view.string != latest {
                let selection = view.selectedRange()
                view.string = latest
                view.setSelectedRange(MediaCommentFormatting.clamped(selection, in: latest))
            }
            context.coordinator.restyle(view)
        }
        view.needsDisplay = true
        if let focus, focus.blockID == blockID, focus.token != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focus.token
            context.coordinator.focus(view, at: focus.location, textAtRequest: view.string, attempts: 6)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarkdownNSTextView, context: Context) -> CGSize? {
        let width = max(40, proposal.width ?? 320)
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else { return CGSize(width: width, height: 34) }
        if !nsView.hasMarkedText() {
            context.coordinator.styleIfNeeded(nsView, kind: kind)
        }
        container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        let height = max(34, ceil(used.height) + nsView.textContainerInset.height * 2)
        nsView.syncContainerWidth()
        return CGSize(width: width, height: height)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownBlockTextView
        var isApplying = false
        var lastFocusToken: UUID?
        private var styledText: String?
        private var styledKind: MarkdownBlock.Kind?

        init(_ parent: MarkdownBlockTextView) { self.parent = parent }

        func styleIfNeeded(_ view: NSTextView, kind: MarkdownBlock.Kind) {
            if styledText == view.string, styledKind == kind { return }
            restyle(view, kind: kind)
        }

        func restyle(_ view: NSTextView, kind: MarkdownBlock.Kind? = nil) {
            guard let storage = view.textStorage else { return }
            let kind = kind ?? parent.kind
            let selection = view.selectedRange()
            storage.beginEditing()
            MarkdownInlineStyler.apply(to: storage, kind: kind)
            storage.endEditing()
            if view.selectedRange() != selection { view.setSelectedRange(selection) }
            let base = MarkdownStyle.base(for: kind)
            view.typingAttributes = [
                .font: base.font,
                .foregroundColor: base.color,
                .paragraphStyle: MarkdownStyle.paragraphStyle()
            ]
            styledText = view.string
            styledKind = kind
        }

        func focus(_ view: NSTextView, at location: Int, textAtRequest: String, attempts: Int) {
            DispatchQueue.main.async {
                if let window = view.window {
                    let wasEditing = window.firstResponder === view
                    window.makeFirstResponder(view)
                    if !wasEditing || view.string == textAtRequest {
                        view.setSelectedRange(MediaCommentFormatting.clamped(NSRange(location: location, length: 0), in: view.string))
                    }
                } else if attempts > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.focus(view, at: location, textAtRequest: textAtRequest, attempts: attempts - 1)
                    }
                }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let view = notification.object as? NSTextView else { return }
            if !view.hasMarkedText() { restyle(view) }
            view.needsDisplay = true
            parent.handlers.onChange(view.string, view.selectedRange())
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplying, let view = notification.object as? NSTextView else { return }
            parent.handlers.onSelection(view.selectedRange())
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let view = textView as? MarkdownNSTextView else { return false }
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                if case .code = parent.kind {
                    let source = view.string as NSString
                    let range = view.selectedRange()
                    if range.length == 0, NSMaxRange(range) == source.length, source.hasSuffix("\n") {
                        view.replaceAll(with: source.substring(to: source.length - 1), selection: NSRange(location: source.length - 1, length: 0))
                        return parent.handlers.onReturn(source.length - 1)
                    }
                    return false
                }
                let range = view.selectedRange()
                if range.length > 0 {
                    view.replaceAll(with: (view.string as NSString).replacingCharacters(in: range, with: ""), selection: NSRange(location: range.location, length: 0))
                }
                _ = parent.handlers.onReturn(range.location)
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                let range = view.selectedRange()
                if range.location == 0, range.length == 0 { return parent.handlers.onBackspaceAtStart() }
                return false
            case #selector(NSResponder.insertTab(_:)):
                return parent.handlers.onTab(false)
            case #selector(NSResponder.insertBacktab(_:)):
                return parent.handlers.onTab(true)
            case #selector(NSResponder.moveUp(_:)):
                return view.caretIsOnFirstLine() ? parent.handlers.onMoveUp() : false
            case #selector(NSResponder.moveDown(_:)):
                return view.caretIsOnLastLine() ? parent.handlers.onMoveDown() : false
            default:
                return false
            }
        }
    }
}
#endif
