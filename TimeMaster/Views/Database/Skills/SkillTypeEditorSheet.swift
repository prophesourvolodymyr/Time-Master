import SwiftUI
import TimeMasterCore

/// Makes a type (an option of a preset) or edits one: a name, the colour of its text highlight, an icon, the effect it
/// gives a card and the rule that moves its pages to the top or bottom of their list. Made while assigning, the new type
/// goes onto the page that asked for it.
struct SkillTypeEditorSheet: View {
    let rootID: String
    /// The page the new type is put on (nil = just make it).
    let assigningTo: String?
    let route: SkillTypeEditorRoute
    /// Runs after a new type went onto its page, so the sheet that opened this one can close with it.
    var onAssigned: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var title: String
    @State private var colorHex: String?
    @State private var iconName: String
    @State private var iconType: SkillBoardIconType
    @State private var effect: SkillTypeEffect
    @State private var sortRule: SkillTypeSortRule
    @State private var confirmsDelete = false
    @State private var didSave = false
    @FocusState private var titleFocused: Bool

    init(rootID: String, assigningTo: String? = nil, route: SkillTypeEditorRoute, onAssigned: (() -> Void)? = nil) {
        self.rootID = rootID
        self.assigningTo = assigningTo
        self.route = route
        self.onAssigned = onAssigned
        switch route {
        case .editType(let type):
            _title = State(initialValue: type.title)
            _colorHex = State(initialValue: SkillColors.normalizedHex(type.colorHex))
            _iconName = State(initialValue: type.iconName ?? "tag.fill")
            _iconType = State(initialValue: type.iconType)
            _effect = State(initialValue: type.effect)
            _sortRule = State(initialValue: type.sortRule)
        default:
            _title = State(initialValue: "")
            _colorHex = State(initialValue: SkillColors.random())
            _iconName = State(initialValue: "tag.fill")
            _iconType = State(initialValue: .system)
            _effect = State(initialValue: .tint)
            _sortRule = State(initialValue: .none)
        }
    }

    private var editedType: SkillType? {
        if case .editType(let type) = route { return type }
        return nil
    }

    private var isNew: Bool { editedType == nil }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var presets: [SkillTypePreset] { store.skillTypePresets(for: rootID) }

    /// The preset this type belongs to (or will belong to).
    private var preset: SkillTypePreset? {
        switch route {
        case .newType(let presetID): return presets.first { $0.id == presetID }
        case .editType(let type): return presets.first { preset in preset.types.contains { $0.id == type.id } }
        case .newPreset, .editPreset: return nil
        }
    }

    /// The type as it is being edited, for the preview.
    private var draft: SkillType {
        SkillType(
            id: editedType?.id ?? "draft",
            title: trimmedTitle.isEmpty ? "Type name" : trimmedTitle,
            colorHex: colorHex,
            iconName: iconName,
            iconType: iconType,
            effect: effect,
            sortRule: sortRule
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    if let preset {
                        labeled("In the preset") { presetBadge(preset) }
                    }
                    labeled("Name") { nameField }
                    labeled("Colour") { SkillColorPicker(selection: $colorHex, automaticHex: SkillTypeStyle.fallbackHex) }
                    labeled("Icon") { SkillIconPicker(iconName: $iconName, iconType: $iconType) }
                    labeled("Effect on the card") { effectPicker }
                    labeled("When a page has this type") { rulePicker }
                    if !isNew {
                        Button(role: .destructive) {
                            confirmsDelete = true
                        } label: {
                            Label("Delete this type", systemImage: "trash")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(isNew ? "New type" : "Edit type")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button(isNew ? (assigningTo == nil ? "Add type" : "Add and use") : "Save") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .keyNavHost()
        .confirmationDialog("Delete this type?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete “\(editedType?.title ?? "")”", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 600, idealHeight: 760)
        #endif
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            titleFocused = true
        }
    }

    // MARK: Pieces

    /// The chip and a sample card, as they will look.
    private var preview: some View {
        let type = draft
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.textSecondary)
                Text("A page with this type")
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            SkillTypeChip(type: type)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .skillTypeBase(type)
        .opacity(trimmedTitle.isEmpty ? 0.6 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Which preset the type lives in: its icon and name (a type belongs to one preset; it is picked before this sheet opens).
    private func presetBadge(_ preset: SkillTypePreset) -> some View {
        HStack(spacing: 8) {
            SkillTypePresetIcon(preset: preset, size: 16)
            Text(preset.title)
                .font(TimeMasterFont.body(15))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("In the preset \(preset.title)")
    }

    private var nameField: some View {
        TextField("Name, for example Move", text: $title)
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
            .accessibilityLabel("Type name")
    }

    private var effectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(SkillTypeEffect.allCases, id: \.rawValue) { option in
                    SkillChoicePill(title: SkillTypeStyle.title(option), isSelected: effect == option) { effect = option }
                }
            }
            Text(SkillTypeStyle.detail(effect))
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var rulePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(SkillTypeSortRule.allCases, id: \.rawValue) { option in
                    SkillChoicePill(title: SkillTypeStyle.title(option), isSelected: sortRule == option) { sortRule = option }
                }
            }
            Text(SkillTypeStyle.detail(sortRule))
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
        }
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
        let count = editedType.map { store.skillPageCount(wearing: [$0.id]) } ?? 0
        switch count {
        case 0: return "No page wears it."
        case 1: return "1 page wears it and will just lose the type."
        default: return "\(count) pages wear it and will just lose the type."
        }
    }

    // MARK: Save

    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty, !didSave else { return }
        let icon = iconName.isEmpty ? nil : iconName
        let ok = SkillErrorCenter.shared.attempt(isNew ? "Add the type" : "Save the type") {
            if let existing = editedType {
                try store.updateSkillType(existing.id, in: rootID) { type in
                    type.title = name
                    type.colorHex = colorHex
                    type.iconName = icon
                    type.iconType = iconType
                    type.effect = effect
                    type.sortRule = sortRule
                }
            } else if case .newType(let presetID) = route {
                let created = try store.addSkillType(
                    to: rootID, presetID: presetID, title: name, colorHex: colorHex,
                    iconName: icon, iconType: iconType, effect: effect, sortRule: sortRule
                )
                if let assigningTo {
                    try store.setSkillType(created.id, for: assigningTo)
                }
            }
        }
        guard ok else { return }
        didSave = true
        if isNew, assigningTo != nil { onAssigned?() }
        dismiss()
    }

    private func delete() {
        guard let existing = editedType else { return }
        if SkillErrorCenter.shared.attempt("Delete the type", { try store.deleteSkillType(existing.id, in: rootID) }) {
            didSave = true
            dismiss()
        }
    }
}
