import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The text of one to-do (or of the line that adds one): one line that wraps when it is long.
///
/// - Return saves it (`onSubmit`) and the list moves on to the next line.
/// - Tab makes it a sub-to-do of the one above (`onIndent`), Shift-Tab brings it back out (`onOutdent`).
/// - Backspace in an empty field (`onDeleteWhenEmpty`) and Esc (`onCancel`) are the list's to answer.
///
/// `isFocused` is driven by the list, which keeps the focus on the same to-do while it moves between levels.
struct TodoTextField: View {
    @Binding var text: String
    let placeholder: String
    var isDone = false
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    var onDeleteWhenEmpty: () -> Void = {}
    var onCancel: () -> Void = {}

    #if os(iOS)
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(1...5)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.body(16))
            .foregroundStyle(isDone ? Theme.textSecondary : Theme.textPrimary)
            .strikethrough(isDone, color: Theme.textSecondary)
            .focused($focused)
            .submitLabel(.next)
            // A multi-line field takes Return as a new line; a to-do is one line, so Return saves it instead.
            .onChange(of: text) { newValue in
                guard newValue.contains("\n") else { return }
                text = newValue.replacingOccurrences(of: "\n", with: "")
                onSubmit()
            }
            .onChange(of: isFocused) { wanted in
                if wanted != focused { focused = wanted }
            }
            .onChange(of: focused) { value in
                onFocusChange(value)
            }
            .onAppear {
                if isFocused { focused = true }
            }
            .modifier(TodoHardwareKeys(onIndent: onIndent, onOutdent: onOutdent, onDeleteWhenEmpty: onDeleteWhenEmpty, onCancel: onCancel, isEmpty: text.isEmpty))
    }
    #else
    var body: some View {
        TodoNSField(
            text: $text, placeholder: placeholder, isDone: isDone, isFocused: isFocused,
            onFocusChange: onFocusChange, onSubmit: onSubmit, onIndent: onIndent, onOutdent: onOutdent,
            onDeleteWhenEmpty: onDeleteWhenEmpty, onCancel: onCancel
        )
    }
    #endif
}

#if os(iOS)
/// Tab and Shift-Tab, Backspace on an empty line and Esc from a hardware keyboard (iOS 17 and later).
private struct TodoHardwareKeys: ViewModifier {
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onDeleteWhenEmpty: () -> Void
    let onCancel: () -> Void
    let isEmpty: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .onKeyPress(keys: [.tab]) { press in
                    if press.modifiers.contains(.shift) { onOutdent() } else { onIndent() }
                    return .handled
                }
                .onKeyPress(.delete) {
                    guard isEmpty else { return .ignored }
                    onDeleteWhenEmpty()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
        } else {
            content
        }
    }
}
#endif

#if os(macOS)
/// An `NSTextField` that reports when it takes the keyboard.
final class TodoNSTextField: NSTextField {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onBecomeFirstResponder?() }
        return accepted
    }
}

/// The Mac field: reports Return, Tab and Shift-Tab (the field editor would otherwise move the focus on Tab).
private struct TodoNSField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isDone: Bool
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onDeleteWhenEmpty: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> TodoNSTextField {
        let field = TodoNSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onFocusChange(true)
        }
        field.setAccessibilityLabel(placeholder)
        Self.style(field, placeholder: placeholder, isDone: isDone, text: text, editing: false)
        return field
    }

    func updateNSView(_ field: TodoNSTextField, context: Context) {
        context.coordinator.parent = self
        let editing = field.currentEditor() != nil
        if !editing || field.stringValue != text {
            Self.style(field, placeholder: placeholder, isDone: isDone, text: text, editing: editing)
        }
        if isFocused, !editing {
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window, field.currentEditor() == nil else { return }
                window.makeFirstResponder(field)
            }
        } else if !isFocused, editing {
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window, field.currentEditor() != nil else { return }
                window.makeFirstResponder(nil)
            }
        }
    }

    /// Wraps to the width SwiftUI proposes, so a long to-do grows downwards instead of being cut off.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: TodoNSTextField, context: Context) -> CGSize? {
        let width = max(proposal.width ?? 320, 40)
        let bounds = NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        let measured = field.cell?.cellSize(forBounds: bounds) ?? CGSize(width: width, height: 20)
        return CGSize(width: width, height: max(ceil(measured.height), 22))
    }

    private static func font() -> NSFont {
        NSFont(name: "Manrope-Regular", size: 15) ?? .systemFont(ofSize: 15)
    }

    private static func style(_ field: NSTextField, placeholder: String, isDone: Bool, text: String, editing: Bool) {
        let color = NSColor(isDone ? Theme.textSecondary : Theme.textPrimary)
        var attributes: [NSAttributedString.Key: Any] = [.font: font(), .foregroundColor: color]
        if isDone && !editing {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = NSColor(Theme.textSecondary)
        }
        field.font = font()
        field.textColor = color
        if editing {
            if field.stringValue != text { field.stringValue = text }
        } else {
            field.attributedStringValue = NSAttributedString(string: text, attributes: attributes)
        }
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.font: font(), .foregroundColor: NSColor(Theme.textSecondary)]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TodoNSField

        init(_ parent: TodoNSField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.insertTab(_:)):
                parent.onIndent()
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                parent.onOutdent()
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                guard textView.string.isEmpty else { return false }
                parent.onDeleteWhenEmpty()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            default:
                return false
            }
        }
    }
}
#endif
