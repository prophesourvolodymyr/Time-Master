import SwiftUI

#if os(iOS)
import UIKit

struct MediaCommentTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let focusRequest: UUID
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = UIColor(Theme.textPrimary)
        view.tintColor = UIColor(Theme.toolbarOrange)
        view.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Markdown source"
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.text = text
        view.selectedRange = MediaCommentFormatting.clamped(selection, in: text)
        context.coordinator.lastFocusRequest = focusRequest
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isApplying = true
        defer { context.coordinator.isApplying = false }
        view.font = UIFont(name: "Manrope-Regular", size: fontSize) ?? UIFont.preferredFont(forTextStyle: .body)
        if view.markedTextRange == nil {
            if view.text != text {
                if let fullRange = view.textRange(from: view.beginningOfDocument, to: view.endOfDocument) {
                    view.replace(fullRange, withText: text)
                }
            }
            let range = MediaCommentFormatting.clamped(selection, in: text)
            if view.selectedRange != range { view.selectedRange = range }
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MediaCommentTextView
        var lastFocusRequest: UUID?
        var isApplying = false

        init(_ parent: MediaCommentTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplying else { return }
            parent.text = textView.text
            parent.selection = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplying, parent.selection != textView.selectedRange else { return }
            parent.selection = textView.selectedRange
        }
    }
}
#elseif os(macOS)
import AppKit

struct MediaCommentTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let focusRequest: UUID
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let view = scrollView.documentView as? NSTextView else { return scrollView }
        view.delegate = context.coordinator
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.textColor = NSColor(Theme.textPrimary)
        view.insertionPointColor = NSColor(Theme.toolbarOrange)
        view.textContainerInset = NSSize(width: 8, height: 10)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.setAccessibilityLabel("Markdown source")
        view.string = text
        view.setSelectedRange(MediaCommentFormatting.clamped(selection, in: text))
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        context.coordinator.lastFocusRequest = focusRequest
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let view = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.isApplying = true
        defer { context.coordinator.isApplying = false }
        view.font = NSFont(name: "Manrope-Regular", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        if !view.hasMarkedText() {
            if view.string != text {
                let range = NSRange(location: 0, length: (view.string as NSString).length)
                if view.shouldChangeText(in: range, replacementString: text) {
                    view.textStorage?.replaceCharacters(in: range, with: text)
                    view.didChangeText()
                }
            }
            let range = MediaCommentFormatting.clamped(selection, in: text)
            if view.selectedRange() != range { view.setSelectedRange(range) }
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            view.window?.makeFirstResponder(view)
            view.scrollRangeToVisible(view.selectedRange())
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MediaCommentTextView
        var lastFocusRequest: UUID?
        var isApplying = false

        init(_ parent: MediaCommentTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            parent.selection = view.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplying, let view = notification.object as? NSTextView, parent.selection != view.selectedRange() else { return }
            parent.selection = view.selectedRange()
        }
    }
}
#endif
