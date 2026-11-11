import SwiftUI
import TimeMasterCore

/// A section divider: its title centred between two hairlines, with its icon and colour. A tap on the title renames
/// it in place; the context menu moves, edits or deletes it.
struct ChecklistSectionDivider: View {
    let title: String
    var iconName: String?
    var iconType: SkillBoardIconType?
    var colorHex: String?
    var canMoveUp = false
    var canMoveDown = false
    /// Opens the rename field as soon as the divider appears (a section just added).
    var renamesOnAppear = false
    let onRename: (String) -> Void
    let onMove: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var renaming = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let tint = colorHex.flatMap(SkillColors.normalizedHex).map { Color(hex: $0) } ?? Theme.textSecondary
        HStack(spacing: 10) {
            hairline(tint)
            HStack(spacing: 6) {
                if let iconName {
                    SkillIconView(iconName: iconName, iconType: iconType ?? .emoji, colorHex: colorHex, size: 13)
                }
                if renaming {
                    TextField("Section", text: $draft)
                        .textFieldStyle(.plain)
                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textPrimary)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(commit)
                        .fixedSize()
                        #if os(macOS)
                        .onExitCommand { renaming = false }
                        #endif
                } else {
                    Text(title.uppercased())
                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                        .tracking(1.1)
                        .foregroundStyle(colorHex == nil ? Theme.textSecondary : tint)
                        .lineLimit(1)
                        .onTapGesture(perform: beginRenaming)
                }
            }
            .layoutPriority(1)
            hairline(tint)
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .keyNavPlainButtonStyle()
            .fixedSize()
            .accessibilityLabel("\(title) section options")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu { menuItems }
        .onAppear {
            if renamesOnAppear { beginRenaming() }
        }
        .onChange(of: focused) { isFocused in
            if !isFocused, renaming { commit() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Section \(title)")
        .accessibilityAction(named: "Rename") { beginRenaming() }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(action: beginRenaming) { Label("Rename", systemImage: "pencil") }
        Button(action: onEdit) { Label("Icon and colour…", systemImage: "paintpalette") }
        if canMoveUp {
            Button { onMove(-1) } label: { Label("Move up", systemImage: "arrow.up") }
        }
        if canMoveDown {
            Button { onMove(1) } label: { Label("Move down", systemImage: "arrow.down") }
        }
        Divider()
        Button(role: .destructive, action: onDelete) { Label("Delete section", systemImage: "trash") }
    }

    private func hairline(_ tint: Color) -> some View {
        Rectangle()
            .fill(tint.opacity(colorHex == nil ? 0.35 : 0.55))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func beginRenaming() {
        draft = title
        renaming = true
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = false
        guard !clean.isEmpty, clean != title else { return }
        onRename(clean)
    }
}
