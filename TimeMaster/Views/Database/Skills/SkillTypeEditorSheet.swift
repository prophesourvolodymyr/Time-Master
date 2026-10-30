import SwiftUI
import TimeMasterCore

/// Makes a type or edits one: a name, a colour, an icon, the effect it gives a card and the rule that moves its pages
/// to the top or bottom of their list. Made while assigning ("New type…"), the new type goes onto the page that asked.
struct SkillTypeEditorSheet: View {
    let rootID: String
    /// The page the new type is put on (nil = just make it).
    let assigningTo: String?
    let route: SkillTypeEditorRoute

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var title: String
    @State private var colorHex: String?
    @State private var iconName: String
    @State private var iconType: SkillBoardIconType
    @State private var effect: SkillTypeEffect
    @State private var sortRule: SkillTypeSortRule
    @State private var presetID: String?
    @State private var confirmsDelete = false
    @State private var didSave = false
    @FocusState private var titleFocused: Bool

    init(rootID: String, assigningTo: String? = nil, route: SkillTypeEditorRoute) {
        self.rootID = rootID
        self.assigningTo = assigningTo
        self.route = route
        switch route {
        case .new(let presetID):
            _title = State(initialValue: "")
            _colorHex = State(initialValue: SkillColors.random())
            _iconName = State(initialValue: "tag.fill")
            _iconType = State(initialValue: .system)
            _effect = State(initialValue: .tint)
            _sortRule = State(initialValue: .none)
            _presetID = State(initialValue: presetID)
        case .edit(let type):
            _title = State(initialValue: type.title)
            _colorHex = State(initialValue: SkillColors.normalizedHex(type.colorHex))
            _iconName = State(initialValue: type.iconName ?? "tag.fill")
            _iconType = State(initialValue: type.iconType)
            _effect = State(initialValue: type.effect)
            _sortRule = State(initialValue: type.sortRule)
            _presetID = State(initialValue: nil)
        }
    }

    private var editedType: SkillType? {
        if case .edit(let type) = route { return type }
        return nil
    }

    private var isNew: Bool { editedType == nil }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var presets: [SkillTypePreset] { store.skillTypePresets(for: rootID) }

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
                    labeled("Name") { nameField }
                    labeled("Colour") { SkillColorPicker(selection: $colorHex, automaticHex: SkillTypeStyle.fallbackHex) }
                    labeled("Icon") { SkillIconPicker(iconName: $iconName, iconType: $iconType) }
                    labeled("Effect on the card") { effectPicker }
                    labeled("When a page has this type") { rulePicker }
                    if isNew, presets.count > 1 {
                        labeled("Preset") { presetPicker }
                    }
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
            Text("Pages that wear it just lose the type.")
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

    private var presetPicker: some View {
        HStack(spacing: 6) {
            ForEach(presets) { preset in
                SkillChoicePill(title: preset.title, isSelected: (presetID ?? presets.first?.id) == preset.id) { presetID = preset.id }
            }
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
            } else {
                let created = try store.addSkillType(
                    to: rootID, presetID: presetID, title: name, colorHex: colorHex,
                    iconName: icon, iconType: iconType, effect: effect, sortRule: sortRule
                )
                if let assigningTo { try store.setSkillType(created.id, for: assigningTo) }
            }
        }
        if ok {
            didSave = true
            dismiss()
        }
    }

    private func delete() {
        guard let existing = editedType else { return }
        if SkillErrorCenter.shared.attempt("Delete the type", { try store.deleteSkillType(existing.id, in: rootID) }) {
            didSave = true
            dismiss()
        }
    }
}

/// Every preset of a skill and the types in it: edit or add a type, add, rename or delete a preset.
struct SkillTypesManagerSheet: View {
    let rootID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var editor: SkillTypeEditorRoute?
    @State private var presetName = ""
    @State private var renamingPreset: SkillTypePreset?
    @State private var addingPreset = false
    @State private var presetToDelete: SkillTypePreset?

    private var presets: [SkillTypePreset] { store.skillTypePresets(for: rootID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Types are tags with a colour, an icon and an effect. A preset is a set of types; every skill keeps its own.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                    if presets.isEmpty {
                        Text("No types yet. Add the first one.")
                            .font(TimeMasterFont.body(15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(presets) { preset in
                        presetCard(preset)
                    }
                    HStack(spacing: 8) {
                        Button {
                            editor = .new(presetID: presets.first?.id)
                        } label: {
                            Label("New type", systemImage: "plus")
                        }
                        Button {
                            presetName = ""
                            addingPreset = true
                        } label: {
                            Label("New preset", systemImage: "square.stack.badge.plus")
                        }
                    }
                    .foregroundStyle(Theme.toolbarOrange)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Types")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .keyNavHost()
        .sheet(item: $editor) { route in
            SkillTypeEditorSheet(rootID: rootID, route: route)
                .environmentObject(store)
        }
        .alert("New preset", isPresented: $addingPreset) {
            TextField("Name", text: $presetName)
            Button("Add") { addPreset() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename preset", isPresented: Binding(get: { renamingPreset != nil }, set: { if !$0 { renamingPreset = nil } })) {
            TextField("Name", text: $presetName)
            Button("Save") { renamePreset() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this preset?",
            isPresented: Binding(get: { presetToDelete != nil }, set: { if !$0 { presetToDelete = nil } }),
            titleVisibility: .visible,
            presenting: presetToDelete
        ) { preset in
            Button("Delete “\(preset.title)”", role: .destructive) { deletePreset(preset) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its types go with it; pages that wear them just lose the type.")
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 520, idealHeight: 680)
        #endif
    }

    private func presetCard(_ preset: SkillTypePreset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(preset.title)
                    .font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                Menu {
                    Button {
                        editor = .new(presetID: preset.id)
                    } label: {
                        Label("New type here", systemImage: "plus")
                    }
                    Button {
                        presetName = preset.title
                        renamingPreset = preset
                    } label: {
                        Label("Rename…", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        presetToDelete = preset
                    } label: {
                        Label("Delete…", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .menuStyle(.button).keyNavPlainButtonStyle()
                .menuIndicator(.hidden)
                .accessibilityLabel("\(preset.title) options")
            }
            if preset.types.isEmpty {
                Text("Empty.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(preset.orderedTypes) { type in
                Button {
                    editor = .edit(type)
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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func addPreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        SkillErrorCenter.shared.attempt("Add the preset") { try store.addSkillTypePreset(to: rootID, title: name) }
    }

    private func renamePreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preset = renamingPreset, !name.isEmpty else { return }
        SkillErrorCenter.shared.attempt("Rename the preset") { try store.renameSkillTypePreset(preset.id, in: rootID, title: name) }
    }

    private func deletePreset(_ preset: SkillTypePreset) {
        SkillErrorCenter.shared.attempt("Delete the preset") { try store.deleteSkillTypePreset(preset.id, in: rootID) }
    }
}
