import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

// MARK: - Shared context

/// What a card or row needs from the board that draws it.
struct SkillBoardContext {
    /// The board's page id, or a group id when the board is a group's own page.
    var boardID: String
    /// The groups a skill can be moved to (empty on a group's page, where the board is the group).
    var groups: [SkillBoardSection]
    var open: (ExercisePage) -> Void
    var requestDelete: (ExercisePage) -> Void
    var beginDrag: (ExercisePage) -> NSItemProvider
    var dropBefore: (ExercisePage) -> Void
}

// MARK: - Group surface and header

/// The tinted panel behind a group: its strip colour, or the two colours its picture gives.
struct SkillGroupSurface<Content: View>: View {
    let section: SkillBoardSection
    let imageURL: URL?
    var cornerRadius: CGFloat = 18
    @ViewBuilder let content: () -> Content

    @StateObject private var model = SkillStripImageModel()

    private var top: Color {
        model.colors.map { Color(hex: $0.top) } ?? section.stripColor ?? Color.white.opacity(0.35)
    }

    private var bottom: Color {
        model.colors.map { Color(hex: $0.bottom) } ?? section.stripColor ?? Color.white.opacity(0.35)
    }

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [top.opacity(0.14), bottom.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [top.opacity(0.45), bottom.opacity(0.22)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .task(id: imageURL) { await model.load(imageURL) }
    }
}

/// The strip of a group: colour (or the picture clipped inside it), icon, title and count. The chevron folds the
/// group; the title opens it as a page.
struct SkillGroupHeader: View {
    @EnvironmentObject private var store: DatabaseStore
    let container: ExercisePage
    let section: SkillBoardSection
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onAddSkill: () -> Void
    let onDelete: () -> Void

    @StateObject private var model = SkillStripImageModel()

    private var imageURL: URL? { store.skillGroupImageURL(container: container, section: section) }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }.keyNavPlainButtonStyle()
            .accessibilityLabel(isCollapsed ? "Show \(section.title)" : "Fold \(section.title)")

            SkillGroupIconView(section: section, size: 18, colorHex: model.colors?.top ?? SkillColors.normalizedHex(section.colorHex))

            SkillEditableTitle(
                pageID: SkillGroupID.make(containerID: container.manifest.id, sectionID: section.id),
                title: section.title,
                font: TimeMasterFont.rowTitle(),
                lineLimit: 1,
                onOpen: onOpen,
                renamesOnPhone: true
            )

            Text("\(count)")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)

            Menu {
                Button(action: onOpen) { Label("Open page", systemImage: "arrow.up.forward.square") }
                Button(action: onAddSkill) { Label("Add skill here", systemImage: "plus") }
                Button(action: onEdit) { Label("Edit group…", systemImage: "pencil") }
                Divider()
                Button(role: .destructive, action: onDelete) { Label("Delete group…", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button).keyNavPlainButtonStyle()
            .menuIndicator(.hidden)
            .accessibilityLabel("\(section.title) options")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            SkillGroupStripBackground(imageURL: imageURL, color: section.stripColor)
        }
        .keyNavTarget(id: section.id, role: .primary, shape: .roundedRectangle(cornerRadius: 14), action: onOpen)
        .task(id: imageURL) { await model.load(imageURL) }
    }
}

/// The strip itself: a colour bar down the left edge, or the picture filling the strip under a dark wash so the title
/// stays readable.
struct SkillGroupStripBackground: View {
    let imageURL: URL?
    let color: Color?
    var cornerRadius: CGFloat = 14

    var body: some View {
        ZStack {
            if let imageURL {
                SkillLocalImage(url: imageURL, maxPixel: 900)
                LinearGradient(
                    colors: [Theme.background.opacity(0.88), Theme.background.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Theme.surface
                HStack(spacing: 0) {
                    (color ?? Color.white.opacity(0.25)).frame(width: 4)
                    Spacer(minLength: 0)
                }
                if let color {
                    LinearGradient(colors: [color.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Page menu

/// The context menu of a card or row: open, status, type, move, delete.
struct SkillPageMenu: View {
    @EnvironmentObject private var store: DatabaseStore
    let page: ExercisePage
    let context: SkillBoardContext

    var body: some View {
        let current = page.manifest.skillStatus ?? .notStarted
        Button { context.open(page) } label: { Label("Open", systemImage: "arrow.up.forward.square") }
        Divider()
        Menu {
            ForEach(SkillStatus.boardOrder, id: \.self) { status in
                Button {
                    SkillErrorCenter.shared.attempt("Change the status") { try store.setSkillStatus(status, for: page.manifest.id) }
                } label: {
                    Label(status.title, systemImage: current == status ? "checkmark" : status.symbolName)
                }
            }
        } label: {
            Label("Status", systemImage: "circle.lefthalf.filled")
        }
        Menu {
            let presets = store.skillTypePresets(for: page.manifest.id)
            ForEach(presets) { preset in
                SwiftUI.Section(preset.title) {
                    ForEach(preset.orderedTypes) { type in
                        Button {
                            SkillErrorCenter.shared.attempt("Set the type") { try store.setSkillType(type.id, for: page.manifest.id) }
                        } label: {
                            Label(SkillTypeStyle.menuTitle(type), systemImage: page.manifest.typeID == type.id ? "checkmark" : "tag")
                        }
                    }
                }
            }
            if page.manifest.typeID != nil {
                Button {
                    SkillErrorCenter.shared.attempt("Clear the type") { try store.setSkillType(nil, for: page.manifest.id) }
                } label: {
                    Label("No type", systemImage: "xmark.circle")
                }
            }
            if presets.isEmpty { Text("Use the tag on the card to make the first type") }
        } label: {
            Label("Type", systemImage: "tag")
        }
        if !context.groups.isEmpty {
            Menu {
                Button {
                    move(to: nil)
                } label: {
                    Label("No group", systemImage: store.skillSectionID(of: page) == nil ? "checkmark" : "tray")
                }
                ForEach(context.groups) { group in
                    Button {
                        move(to: group.id)
                    } label: {
                        Label(group.title, systemImage: store.skillSectionID(of: page) == group.id ? "checkmark" : "square.grid.2x2")
                    }
                }
            } label: {
                Label("Move to", systemImage: "arrow.right.square")
            }
        }
        Divider()
        Button(role: .destructive) { context.requestDelete(page) } label: { Label("Delete…", systemImage: "trash") }
    }

    private func move(to sectionID: String?) {
        SkillErrorCenter.shared.attempt("Move the skill") {
            try store.placeSkillPage(page.manifest.id, sectionID: .some(sectionID))
        }
    }
}

// MARK: - Done toggle and chips

private struct SkillDoneButton: View {
    @EnvironmentObject private var store: DatabaseStore
    let page: ExercisePage

    var body: some View {
        let status = page.manifest.skillStatus ?? .notStarted
        Button {
            SkillErrorCenter.shared.attempt("Change the status") {
                try store.setSkillStatus(status.toggledDone, for: page.manifest.id)
            }
        } label: {
            Image(systemName: status.symbolName)
                .font(.system(size: 22))
                .foregroundStyle(status.color)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .accessibilityLabel(status == .completed ? "Mark as not started" : "Mark as completed")
        .help(status == .completed ? "Mark as not started" : "Mark as completed")
    }
}

/// The footer chips of a card or row: the type chip (its menu changes it) and the counts of links and files.
private struct SkillPageFooter: View {
    @EnvironmentObject private var store: DatabaseStore
    let page: ExercisePage

    var body: some View {
        HStack(spacing: 8) {
            SkillTypePicker(pageID: page.manifest.id) {
                if let type = store.skillType(of: page) {
                    SkillTypeChip(type: type, showsChevron: true)
                } else {
                    Image(systemName: "tag")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 22)
                        .overlay(Capsule(style: .continuous).strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        .accessibilityLabel("Add a type")
                }
            }
            if !page.manifest.linkURLs.isEmpty {
                Label("\(page.manifest.linkURLs.count)", systemImage: "link")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel(SkillCopy.count(page.manifest.linkURLs.count, "link", "links"))
            }
            if !page.mediaURLs.isEmpty {
                Label("\(page.mediaURLs.count)", systemImage: "paperclip")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel(SkillCopy.count(page.mediaURLs.count, "file", "files"))
            }
            let waits = store.skillDependencyCount(of: page.manifest.id)
            if waits > 0 {
                Label("\(waits)", systemImage: "arrow.turn.down.right")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Needs \(SkillCopy.count(waits, "thing", "things")) first")
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Card (board)

/// A skill on the board: done toggle, icon, title, the cover it chose, and the chips under it.
struct SkillBoardCard: View {
    @EnvironmentObject private var store: DatabaseStore
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true
    let page: ExercisePage
    let context: SkillBoardContext

    var body: some View {
        let status = page.manifest.skillStatus ?? .notStarted
        let type = store.skillType(of: page)
        VStack(alignment: .leading, spacing: 10) {
            if showsCovers, let cover = page.cardCoverURL {
                SkillLocalImage(url: cover, maxPixel: 640)
                    .frame(height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: 8) {
                SkillDoneButton(page: page)
                SkillPageIconTile(page: page, size: 28)
                SkillEditableTitle(
                    pageID: page.manifest.id,
                    title: page.title,
                    color: Theme.textPrimary.opacity(status.titleOpacity),
                    onOpen: { context.open(page) }
                )
                .padding(.top, 5)
            }
            SkillPageFooter(page: page)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .skillTypeBase(type, cornerRadius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrag { context.beginDrag(page) }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            context.dropBefore(page)
            return true
        }
        .contextMenu { SkillPageMenu(page: page, context: context) }
        .keyNavTarget(id: page.manifest.id, role: .primary, shape: .roundedRectangle(cornerRadius: 14)) {
            context.open(page)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(page.title)
    }
}

// MARK: - Row (list)

/// A skill in the list: the same material as the card on one line.
struct SkillBoardRow: View {
    @EnvironmentObject private var store: DatabaseStore
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true
    let page: ExercisePage
    let context: SkillBoardContext

    var body: some View {
        let status = page.manifest.skillStatus ?? .notStarted
        let type = store.skillType(of: page)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                SkillDoneButton(page: page)
                SkillPageIconTile(page: page, size: 30)
                SkillEditableTitle(
                    pageID: page.manifest.id,
                    title: page.title,
                    color: Theme.textPrimary.opacity(status.titleOpacity),
                    lineLimit: 1,
                    onOpen: { context.open(page) }
                )
                if showsCovers, let cover = page.cardCoverURL {
                    SkillLocalImage(url: cover, maxPixel: 200)
                        .frame(width: 64, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)
                }
                #if os(macOS)
                Text(status.title)
                    .font(TimeMasterFont.black(11, relativeTo: .caption2))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.tint, in: Capsule())
                #endif
                Button { context.open(page) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 34)
                        .contentShape(Rectangle())
                }
                .keyNavPlainButtonStyle()
                .accessibilityLabel("Open \(page.title)")
                .keyNavRole(.excluded)
            }
            SkillPageFooter(page: page)
                .padding(.leading, 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .skillTypeBase(type, cornerRadius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrag { context.beginDrag(page) }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            context.dropBefore(page)
            return true
        }
        .contextMenu { SkillPageMenu(page: page, context: context) }
        .accessibilityValue(status.title)
        .keyNavTarget(id: page.manifest.id, role: .primary, shape: .roundedRectangle(cornerRadius: 14)) {
            context.open(page)
        }
    }
}

// MARK: - Quick add

/// One line to add a skill to a board or a group by typing its name.
struct SkillQuickAddRow: View {
    @EnvironmentObject private var store: DatabaseStore
    let boardID: String
    var sectionID: String?
    var placeholder = "Add a skill"

    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: $title)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(15))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(add)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focused ? Theme.toolbarOrange.opacity(0.8) : Theme.separator, style: StrokeStyle(lineWidth: 1, dash: focused ? [] : [5]))
        }
        .keyNavTarget(id: "add-\(boardID)-\(sectionID ?? "")", shape: .roundedRectangle(cornerRadius: 12)) {
            focused = true
        }
    }

    private func add() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if SkillErrorCenter.shared.attempt("Add the skill", { try store.createSkillPage(title: name, on: boardID, sectionID: sectionID) }) {
            title = ""
            focused = true
        }
    }
}

// MARK: - Group editor

/// Makes a group or edits one: name, icon, strip colour, strip picture.
struct SkillGroupEditorSheet: View {
    enum Mode: Identifiable {
        case new
        case edit(SkillBoardSection)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let section): return section.id
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    let containerID: String
    let mode: Mode

    @State private var title = ""
    @State private var iconName = ""
    @State private var iconType: SkillBoardIconType = .emoji
    @State private var colorHex: String?
    @State private var pictureURL: URL?
    @State private var removesPicture = false
    @State private var showingPicker = false
    @State private var loaded = false
    @State private var createdSectionID: String?
    @FocusState private var titleFocused: Bool

    private var existing: SkillBoardSection? {
        if case .edit(let section) = mode { return section }
        return nil
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var currentPictureURL: URL? {
        if removesPicture { return nil }
        if let pictureURL { return pictureURL }
        guard let existing, let container = store.page(manifestID: containerID) else { return nil }
        return store.skillGroupImageURL(container: container, section: existing)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    field("Name") {
                        TextField("e.g. Foundations", text: $title)
                            .textFieldStyle(.plain)
                            .font(TimeMasterFont.heading())
                            .foregroundStyle(Theme.textPrimary)
                            .focused($titleFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .padding(13)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    field("Colour") { SkillColorPicker(selection: $colorHex, allowsAutomatic: false) }
                    field("Picture in the strip") { pictureRow }
                    field("Icon") {
                        VStack(alignment: .leading, spacing: 10) {
                            SkillIconPicker(iconName: $iconName, iconType: $iconType)
                            if !iconName.isEmpty {
                                Button("No icon") { iconName = "" }
                                    .font(TimeMasterFont.caption())
                                    .foregroundStyle(Theme.textSecondary).keyNavPlainButtonStyle()
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(existing == nil ? "New group" : "Edit group")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .keyNavHost()
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { pictureURL = copyToTemporary(url); removesPicture = false }
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 720)
        #endif
        .onAppear(perform: load)
    }

    private var preview: some View {
        let section = SkillBoardSection(
            id: existing?.id ?? "draft", title: trimmedTitle.isEmpty ? "Group name" : trimmedTitle, order: 0,
            icon: iconName.isEmpty ? nil : iconName, iconType: iconName.isEmpty ? nil : iconType, colorHex: colorHex
        )
        return HStack(spacing: 10) {
            SkillGroupIconView(section: section, size: 18, colorHex: SkillColors.normalizedHex(colorHex))
            Text(section.title)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background { SkillGroupStripBackground(imageURL: currentPictureURL, color: section.stripColor) }
        .accessibilityHidden(true)
    }

    private var pictureRow: some View {
        HStack(spacing: 10) {
            Button {
                showingPicker = true
            } label: {
                Label(currentPictureURL == nil ? "Choose a picture" : "Change picture", systemImage: "photo")
            }
            .foregroundStyle(Theme.toolbarOrange)
            if currentPictureURL != nil {
                Button("Remove") {
                    pictureURL = nil
                    removesPicture = true
                }
                .foregroundStyle(Theme.textSecondary)
            }
        }.keyNavPlainButtonStyle()
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(TimeMasterFont.caption())
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            title = existing.title
            iconName = existing.icon ?? ""
            iconType = existing.iconType ?? .emoji
            colorHex = SkillColors.normalizedHex(existing.colorHex)
        } else {
            let taken = store.skillGroups(of: containerID).compactMap(\.colorHex)
            colorHex = SkillColors.random(avoiding: taken)
            iconType = .emoji
            titleFocused = true
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

    private func save() {
        let name = trimmedTitle
        guard !name.isEmpty else { return }
        let icon = iconName.isEmpty ? nil : iconName
        let ok = SkillErrorCenter.shared.attempt("Save the group") {
            let sectionID: String
            if let id = existing?.id ?? createdSectionID {
                sectionID = id
                try store.updateSkillGroup(containerID: containerID, sectionID: id) { section in
                    section.title = name
                    section.icon = icon
                    section.iconType = icon == nil ? nil : iconType
                    section.colorHex = colorHex
                    if removesPicture { section.imageFilename = nil }
                }
            } else {
                sectionID = try store.addSkillGroup(to: containerID, title: name, icon: icon, iconType: icon == nil ? nil : iconType, colorHex: colorHex).id
                createdSectionID = sectionID
            }
            if let pictureURL {
                try store.setSkillGroupPicture(containerID: containerID, sectionID: sectionID, sourceURL: pictureURL)
            }
        }
        if ok {
            if let pictureURL { try? FileManager.default.removeItem(at: pictureURL) }
            dismiss()
        }
    }
}
