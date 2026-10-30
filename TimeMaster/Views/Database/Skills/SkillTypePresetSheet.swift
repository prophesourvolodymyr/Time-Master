import SwiftUI
import TimeMasterCore

/// A preset, like a Notion "Select" property: a name, an icon and the options (types) it holds. Made on the spot when a
/// page has no preset to pick a type from: "Create" makes it, then the same sheet takes its first options. Editing one
/// changes its name and icon on "Save"; its options are added, edited and deleted at once, each in its own sheet.
struct SkillTypePresetSheet: View {
    let rootID: String
    /// The page a type made in this sheet goes onto (nil = just make it).
    let assigningTo: String?
    let route: SkillTypeEditorRoute

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var title: String
    @State private var iconName: String
    @State private var iconType: SkillBoardIconType
    /// The preset being edited: known at once when editing, set by "Create" when making one.
    @State private var presetID: String?
    @State private var optionEditor: SkillTypeEditorRoute?
    @State private var confirmsDelete = false
    @FocusState private var titleFocused: Bool

    init(rootID: String, assigningTo: String? = nil, route: SkillTypeEditorRoute) {
        self.rootID = rootID
        self.assigningTo = assigningTo
        self.route = route
        switch route {
        case .editPreset(let preset):
            _title = State(initialValue: preset.title)
            _iconName = State(initialValue: preset.iconName ?? "")
            _iconType = State(initialValue: preset.iconType)
            _presetID = State(initialValue: preset.id)
        default:
            _title = State(initialValue: "")
            _iconName = State(initialValue: SkillTypeStyle.presetFallbackSymbol)
            _iconType = State(initialValue: .system)
            _presetID = State(initialValue: nil)
        }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The preset as the skill has it now (its types change while this sheet is open).
    private var preset: SkillTypePreset? {
        guard let presetID else { return nil }
        return store.skillTypePresets(for: rootID).first { $0.id == presetID }
    }

    /// The preset as it is being edited, for the header.
    private var draft: SkillTypePreset {
        SkillTypePreset(
            id: presetID ?? "draft",
            title: trimmedTitle.isEmpty ? "Preset name" : trimmedTitle,
            iconName: iconName.isEmpty ? nil : iconName,
            iconType: iconType
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    labeled("Name") { nameField }
                    if let preset {
                        labeled("Options") { options(of: preset) }
                    }
                    labeled("Icon") { iconControls }
                    if preset != nil {
                        Button(role: .destructive) {
                            confirmsDelete = true
                        } label: {
                            Label("Delete this preset", systemImage: "trash")
                        }
                    } else {
                        Text("A preset holds the types you pick for your pages, the way a Notion Select property holds its options: Difficulty (Easy, Hard), Kind (Flourish, Move). Make the preset, then add its first types.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(presetID == nil ? "New preset" : "Preset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button(presetID == nil ? "Cancel" : "Close") { dismiss() }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button(presetID == nil ? "Create" : "Save") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .keyNavHost()
        .sheet(item: $optionEditor) { route in
            SkillTypeEditorSheet(rootID: rootID, assigningTo: assigningTo, route: route, onAssigned: { dismiss() })
                .environmentObject(store)
        }
        .confirmationDialog("Delete this preset?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete “\(preset?.title ?? "")”", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 720)
        #endif
        .task {
            guard presetID == nil else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            titleFocused = true
        }
    }

    // MARK: Pieces

    /// The property as it will read: its icon and name over the count of its options.
    private var header: some View {
        let shown = draft
        return HStack(spacing: 12) {
            SkillTypePresetIcon(preset: shown, size: 22)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(shown.title)
                    .font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(countText)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .opacity(trimmedTitle.isEmpty ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private var countText: String {
        guard let preset else { return "Preset" }
        switch preset.types.count {
        case 0: return "Preset · no types yet"
        case 1: return "Preset · 1 type"
        default: return "Preset · \(preset.types.count) types"
        }
    }

    private var nameField: some View {
        TextField("Name, for example Difficulty", text: $title)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.heading())
            .foregroundStyle(Theme.textPrimary)
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { save() }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange.opacity(titleFocused ? 0.9 : 0), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("Preset name")
    }

    private var iconControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                SkillChoicePill(title: "No icon", isSelected: iconName.isEmpty) {
                    iconName = ""
                    iconType = .system
                }
            }
            SkillIconPicker(iconName: $iconName, iconType: $iconType)
        }
    }

    /// Its types, each opening its editor, and the row that adds one.
    private func options(of preset: SkillTypePreset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(preset.orderedTypes) { type in
                Button {
                    optionEditor = .editType(type)
                } label: {
                    HStack(spacing: 10) {
                        SkillTypeChip(type: type)
                        Text("\(SkillTypeStyle.title(type.effect)) · \(SkillTypeStyle.title(type.sortRule))")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }.keyNavPlainButtonStyle()
                .accessibilityLabel("Edit type \(type.title)")
            }
            Button {
                optionEditor = .newType(presetID: preset.id)
            } label: {
                Label("Add an option", systemImage: "plus")
            }
            .foregroundStyle(Theme.toolbarOrange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(TimeMasterFont.caption())
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private var deleteMessage: String {
        guard let preset else { return "" }
        let count = store.skillPageCount(wearing: Set(preset.types.map(\.id)))
        let types = preset.types.count == 1 ? "Its 1 type goes with it" : "Its \(preset.types.count) types go with it"
        switch count {
        case 0: return "\(types); no page wears one of them."
        case 1: return "\(types); 1 page wears one of them and will just lose the type."
        default: return "\(types); \(count) pages wear one of them and will just lose the type."
        }
    }

    // MARK: Actions

    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty else { return }
        let icon = iconName.isEmpty ? nil : iconName
        if let existing = presetID {
            let ok = SkillErrorCenter.shared.attempt("Save the preset") {
                try store.updateSkillTypePreset(existing, in: rootID) { preset in
                    preset.title = name
                    preset.iconName = icon
                    preset.iconType = iconType
                }
            }
            if ok { dismiss() }
        } else {
            var created: SkillTypePreset?
            let ok = SkillErrorCenter.shared.attempt("Make the preset") {
                created = try store.addSkillTypePreset(to: rootID, title: name, iconName: icon, iconType: iconType)
            }
            guard ok, let created else { return }
            presetID = created.id
            // Started from a page's type menu: the next thing it needs is a type of this preset to put on the page.
            if assigningTo != nil { optionEditor = .newType(presetID: created.id) }
        }
    }

    private func delete() {
        guard let presetID else { return }
        if SkillErrorCenter.shared.attempt("Delete the preset", { try store.deleteSkillTypePreset(presetID, in: rootID) }) {
            dismiss()
        }
    }
}
