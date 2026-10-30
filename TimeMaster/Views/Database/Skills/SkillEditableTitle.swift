import SwiftUI
import TimeMasterCore

/// A page or group title you can rename where it stands: double-click it (Mac) or double-tap it (iPhone, where a
/// single tap has no other meaning) and type; Return or clicking away saves, Escape keeps the old name. A single
/// click still does what the title's row does (`onOpen`), so putting this in a card does not take the card's click.
struct SkillEditableTitle: View {
    @EnvironmentObject private var store: DatabaseStore

    /// A page's manifest id, or a group id.
    let pageID: String
    let title: String
    var font: Font = TimeMasterFont.rowTitle()
    var color: Color = Theme.textPrimary
    var lineLimit = 2
    /// A single click or tap. nil = nothing.
    var onOpen: (() -> Void)?
    /// Rename with a double tap on iPhone too (only where a single tap has no meaning).
    var renamesOnPhone = false

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if isEditing {
            field
        } else {
            label
        }
    }

    private var label: some View {
        Text(TimeMasterFont.initialCapitalizedTitle(title))
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(SkillRenameGesture(enabled: canRename, onRename: beginEditing, onOpen: onOpen))
            .help(canRename ? "Double-click to rename" : "")
            .accessibilityAction(named: "Rename") { beginEditing() }
    }

    private var field: some View {
        TextField("Title", text: $draft)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(Theme.textPrimary)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(commit)
            #if os(macOS)
            .onExitCommand(perform: cancel)
            #endif
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface2))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.toolbarOrange.opacity(0.9), lineWidth: 2))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: focused) { isFocused in
                if !isFocused, isEditing { commit() }   // clicking away saves
            }
            .task { focused = true }
            .accessibilityLabel("Title")
    }

    private var canRename: Bool {
        #if os(macOS)
        return true
        #else
        return renamesOnPhone
        #endif
    }

    private func beginEditing() {
        draft = title
        isEditing = true
    }

    private func cancel() { isEditing = false }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != title else { return }
        SkillErrorCenter.shared.attempt("Rename") { try store.renameSkillPage(pageID, to: name) }
    }
}

/// Double-click renames, a single click opens (on titles that can rename).
private struct SkillRenameGesture: ViewModifier {
    let enabled: Bool
    let onRename: () -> Void
    let onOpen: (() -> Void)?

    func body(content: Content) -> some View {
        if enabled {
            content
                .onTapGesture(count: 2, perform: onRename)
                .onTapGesture { onOpen?() }
        } else if let onOpen {
            content.onTapGesture(perform: onOpen)
        } else {
            content
        }
    }
}
