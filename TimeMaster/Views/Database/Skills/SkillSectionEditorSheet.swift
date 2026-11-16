import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// Makes a section or edits one: its name, colour, icon and the picture inside its strip, with a live preview of the
/// group it draws. `init(boardID:suggestedColorHex:onCreated:)` adds a section; `init(boardID:section:)` edits one.
struct SkillSectionEditorSheet: View {
    /// The board page that holds the sections.
    let boardID: String
    /// nil = a new section.
    let section: SkillBoardSection?
    let onCreated: (SkillBoardSection) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var title: String
    @State private var iconName: String
    @State private var iconType: SkillBoardIconType
    /// The chosen strip colour (`RRGGBB`); nil = Default (the palette colour of the section's position).
    @State private var colorHex: String?
    /// A picture picked here, copied out of the importer; saved with the section.
    @State private var pictureURL: URL?
    @State private var removesPicture = false
    @State private var showingPicturePicker = false
    /// Set once saved, so a second Return cannot save (and fail as a duplicate) again.
    @State private var didSave = false
    @FocusState private var titleFocused: Bool

    private static let defaultIcon = "square.grid.2x2"

    /// A new section. `suggestedColorHex` starts selected (a palette colour no neighbour wears).
    init(boardID: String, suggestedColorHex: String? = nil, onCreated: @escaping (SkillBoardSection) -> Void = { _ in }) {
        self.boardID = boardID
        self.section = nil
        self.onCreated = onCreated
        _title = State(initialValue: "")
        _iconName = State(initialValue: Self.defaultIcon)
        _iconType = State(initialValue: .system)
        _colorHex = State(initialValue: SkillSectionPalette.usableHex(suggestedColorHex))
    }

    /// An existing section: its name, colour, icon and picture can change.
    init(boardID: String, section: SkillBoardSection) {
        self.boardID = boardID
        self.section = section
        self.onCreated = { _ in }
        _title = State(initialValue: section.title)
        _iconName = State(initialValue: section.icon ?? Self.defaultIcon)
        _iconType = State(initialValue: section.icon == nil ? .system : section.iconType ?? .emoji)
        _colorHex = State(initialValue: SkillSectionPalette.usableHex(section.colorHex))
    }

    private var isNew: Bool { section == nil }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var sections: [SkillBoardSection] { store.skillGroups(of: boardID) }

    /// Where the section sits among the board's sections (a new one goes last); decides its Default colour.
    private var position: Int {
        guard let section else { return sections.count }
        return sections.firstIndex { $0.id == section.id } ?? sections.count
    }

    private var itemCount: Int {
        guard let section else { return 0 }
        return store.skillPages(onBoard: boardID, sectionID: section.id).count
    }

    /// The picture inside the strip as it will be after saving.
    private var currentPictureURL: URL? {
        if removesPicture { return nil }
        if let pictureURL { return pictureURL }
        guard let section, let container = store.page(manifestID: boardID),
              let live = container.manifest.skillBoardSection(section.id) else { return nil }
        return store.skillGroupImageURL(container: container, section: live)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SkillMetrics.s6) {
                    preview
                    labeled("Name") { nameField }
                    labeled("Colour") {
                        SkillSectionColorPicker(selection: $colorHex, automaticHex: SkillSectionPalette.hex(forIndex: position))
                    }
                    labeled("Icon") {
                        SkillIconPicker(iconName: $iconName, iconType: $iconType)
                    }
                    labeled("Picture") { pictureRow }
                }
                .padding(SkillMetrics.s5)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(isNew ? "New section" : "Edit section")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button(isNew ? "Add section" : "Save", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .keyNavHost()
        .fileImporter(isPresented: $showingPicturePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result, let copy = copyToTemporary(url) {
                pictureURL = copy
                removesPicture = false
            }
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 700)
        #endif
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            titleFocused = true
        }
    }

    // MARK: Pieces

    /// The group header as it will look on the board.
    private var preview: some View {
        let hex = SkillSectionPalette.resolvedHex(explicit: colorHex, index: position)
        return SkillBoardSectionHeader(
            title: trimmedTitle.isEmpty ? "Section name" : trimmedTitle,
            iconName: iconName.isEmpty ? nil : iconName,
            iconType: iconType,
            colorHex: hex,
            count: itemCount,
            isCollapsed: false,
            showsMenu: false,
            onToggle: {},
            menu: { EmptyView() }
        )
        .opacity(trimmedTitle.isEmpty ? 0.55 : 1)
        .skillSectionGroup(colorHex: hex, stripImageURL: currentPictureURL)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var nameField: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        return TextField("Name, for example Chords", text: $title)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.heading())
            .foregroundStyle(Theme.textPrimary)
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit(save)
            .padding(.horizontal, SkillMetrics.s4)
            .frame(minHeight: 58)
            .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
            .overlay {
                shape
                    .strokeBorder(Theme.toolbarOrange.opacity(titleFocused ? 0.9 : 0), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("Section name")
    }

    /// A picture inside the strip: the strip and the group take its colours.
    private var pictureRow: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            HStack(spacing: SkillMetrics.s2) {
                Button {
                    showingPicturePicker = true
                } label: {
                    Label(currentPictureURL == nil ? "Choose picture…" : "Change picture…", systemImage: "photo")
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: SkillMetrics.touch))
                if currentPictureURL != nil {
                    Button {
                        pictureURL = nil
                        removesPicture = true
                        EverHaptic.selection()
                    } label: {
                        Label("Remove", systemImage: "rectangle.slash")
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: SkillMetrics.touch))
                }
            }
            Text(currentPictureURL == nil
                 ? "The picture goes inside the strip, and the group takes its colours."
                 : "Removing it keeps the picture among the group's files.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            Text(label.uppercased())
                .font(TimeMasterFont.caption())
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    /// The importer's URL is security-scoped and short-lived; the picture is copied out before the store reads it.
    private func copyToTemporary(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            return target
        } catch {
            SkillErrorCenter.shared.report("Read the picture", error)
            return nil
        }
    }

    // MARK: Save

    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty, !didSave else { return }
        let icon = iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : iconName
        var created: SkillBoardSection?
        let saved = SkillErrorCenter.shared.attempt(isNew ? "Add the section" : "Save the section") {
            let sectionID: String
            if let section {
                sectionID = section.id
                try store.updateSkillGroup(containerID: boardID, sectionID: section.id) { edited in
                    edited.title = name
                    edited.icon = icon
                    edited.iconType = icon == nil ? nil : iconType
                    edited.colorHex = colorHex
                    if removesPicture { edited.imageFilename = nil }
                }
            } else {
                let made = try store.addSkillGroup(
                    to: boardID,
                    title: name,
                    icon: icon,
                    iconType: icon == nil ? nil : iconType,
                    colorHex: colorHex ?? SkillSectionPalette.hex(forIndex: position)
                )
                sectionID = made.id
                created = made
            }
            if let pictureURL {
                try store.setSkillGroupPicture(containerID: boardID, sectionID: sectionID, sourceURL: pictureURL)
            }
        }
        guard saved else { return }
        if let pictureURL { try? FileManager.default.removeItem(at: pictureURL) }
        didSave = true
        if let created { onCreated(created) }
        EverHaptic.success()
        dismiss()
    }
}

/// The strip colour of a section: "Default" (the palette colour of its position) or one of the eight swatches.
struct SkillSectionColorPicker: View {
    /// `RRGGBB` of the chosen colour; nil = Default.
    @Binding var selection: String?
    /// The colour Default gives this section right now (drawn on the Default swatch).
    let automaticHex: String

    private let columns = [GridItem(.adaptive(minimum: SkillMetrics.touch), spacing: SkillMetrics.s1)]

    private var chosen: String? { SkillSectionPalette.usableHex(selection) }

    /// A colour set elsewhere (an agent, another device) that is not one of the swatches: shown so it stays selectable.
    private var customHex: String? {
        guard let chosen, SkillSectionPalette.name(of: chosen) == nil else { return nil }
        return chosen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: SkillMetrics.s1) {
                defaultSwatch
                if let customHex {
                    swatch(hex: customHex, name: "Custom colour")
                }
                ForEach(SkillSectionPalette.swatches) { entry in
                    swatch(hex: entry.hex, name: entry.name)
                }
            }
            Text(caption)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caption: String {
        guard let chosen else { return "Default colour: picked for you, so neighbouring sections never match." }
        return SkillSectionPalette.name(of: chosen) ?? "Custom colour"
    }

    private var defaultSwatch: some View {
        let tint = Color(hex: automaticHex)
        let isSelected = chosen == nil
        return Button {
            select(nil)
        } label: {
            ZStack {
                Circle().fill(tint.opacity(0.22))
                Circle().strokeBorder(tint, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)
            .modifier(SkillSwatchSelection(isSelected: isSelected))
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel("Default colour")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("Default colour")
    }

    private func swatch(hex: String, name: String) -> some View {
        let isSelected = chosen == hex
        return Button {
            select(hex)
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 30, height: 30)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.background)
                    }
                }
                .modifier(SkillSwatchSelection(isSelected: isSelected))
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(name)
    }

    private func select(_ hex: String?) {
        guard chosen != hex else { return }
        selection = hex
        EverHaptic.selection()
    }
}

/// A white ring around the chosen swatch, inside a 44 pt hit area.
private struct SkillSwatchSelection: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
            }
            .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
            .contentShape(Rectangle())
    }
}
