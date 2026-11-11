import SwiftUI
import TimeMasterCore

/// Makes or edits a to-do, a milestone or a section: title, note, cover, pictures, icon, colour and links (workouts,
/// pages, files of the page and web addresses), with what it will look like drawn live at the top.
struct ChecklistEditorSheet<Entry: ChecklistEntry>: View {
    let pageID: String
    let route: ChecklistEditorRoute
    /// The entry being edited; nil for a new one.
    let existing: Entry?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    @State private var draft: ChecklistDraft
    @State private var original: ChecklistDraft
    @State private var importSource: ChecklistPictureImporter.Source?
    @State private var importRole: ChecklistPictureRole = .cover
    @State private var showingWorkoutPicker = false
    @State private var showingPagePicker = false
    @State private var showingAttachmentPicker = false
    @State private var webAddress = ""
    @State private var confirmingDiscard = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @FocusState private var titleFocused: Bool

    init(pageID: String, route: ChecklistEditorRoute, existing: Entry?) {
        self.pageID = pageID
        self.route = route
        self.existing = existing
        let start = existing.map { ChecklistDraft($0) } ?? ChecklistDraft()
        _draft = State(initialValue: start)
        _original = State(initialValue: start)
    }

    private var isNew: Bool { existing == nil }
    private var noun: String { draft.isSection ? "section" : Entry.kind.noun }
    private var hasChanges: Bool { draft != original }

    private var pictures: [URL] {
        (store.page(manifestID: pageID)?.mediaURLs ?? []).filter { ChecklistMedia.isPicture($0.lastPathComponent) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    field("Title", symbol: "textformat") { titleField }
                    if !draft.isSection {
                        field("Note", symbol: "text.alignleft") { noteField }
                        field("Cover", symbol: "photo") {
                            ChecklistPictureChooser(
                                pictures: pictures,
                                selection: Binding(get: { draft.coverMediaFilename.map { [$0] } ?? [] }, set: { draft.coverMediaFilename = $0.first }),
                                onAdd: { beginImport($0, as: .cover) }
                            )
                        }
                        field("Pictures", symbol: "photo.stack") {
                            ChecklistPictureChooser(
                                pictures: pictures, selection: $draft.imageFilenames, limit: Entry.maxImages, allowsNone: false,
                                onAdd: { beginImport($0, as: .image) }
                            )
                        }
                    }
                    field("Icon", symbol: "face.smiling") {
                        ChecklistIconEditor(
                            iconName: $draft.iconName, iconType: $draft.iconType, iconImage: $draft.iconImage,
                            pictures: draft.isSection ? [] : pictures
                        )
                    }
                    field("Colour", symbol: "paintpalette") {
                        SkillColorPicker(selection: $draft.colorHex, automaticHex: ChecklistLook.defaultTintHex, allowsAutomatic: true)
                    }
                    if !draft.isSection {
                        field("Links", symbol: "link") { linksEditor }
                    }
                    if let errorMessage {
                        ChecklistErrorBanner(message: errorMessage) { self.errorMessage = nil }
                    }
                    if existing != nil {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete \(noun)", systemImage: "trash")
                                .font(TimeMasterFont.label())
                                .foregroundStyle(Color(hex: "E57373"))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(isNew ? "New \(noun)" : draft.trimmedTitle.isEmpty ? noun.capitalized : draft.trimmedTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                        .disabled(draft.trimmedTitle.isEmpty)
                }
            }
        }
        .keyNavHost()
        .interactiveDismissDisabled(hasChanges)
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 640, idealHeight: 780)
        #endif
        .checklistPictureImporter(source: $importSource, anyFile: importRole == .attachment) { url in
            importPicked(url)
        }
        .sheet(isPresented: $showingWorkoutPicker) {
            WorkoutLinkPickerSheet(linkedIDs: Set(draft.links.compactMap { $0.target?.workoutID }.compactMap(UUID.init(uuidString:)))) { workout in
                addLink(TodoLink(target: .workout(id: workout.id.uuidString)))
            }
            .environmentObject(workoutStore)
            .environmentObject(store)
        }
        .sheet(isPresented: $showingPagePicker) {
            PageLinkPickerSheet(excludedIDs: [pageID], linkedIDs: Set(draft.links.compactMap { $0.target?.pageID })) { id in
                addLink(TodoLink(target: .page(id: id)))
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showingAttachmentPicker) {
            ChecklistAttachmentPickerSheet(pageID: pageID, linkedURLs: Set(draft.links.map(\.url)), onAddFile: {
                beginImport(.files, as: .attachment)
            }) { link in
                addLink(link)
            }
            .environmentObject(store)
        }
        .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Delete this \(noun)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let inside = existing?.children.flattened().count ?? 0
            Text(inside == 0 ? "“\(draft.trimmedTitle)”" : "“\(draft.trimmedTitle)” and \(inside) inside")
        }
        .task {
            guard isNew else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            titleFocused = true
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        let entry: Entry = draft.preview(of: existing, placeholder: draft.isSection ? "Section" : "Your \(Entry.kind.noun)")
        Group {
            if entry.isSection {
                ChecklistSectionDivider(
                    title: entry.title, iconName: entry.iconName, iconType: entry.iconType, colorHex: entry.colorHex,
                    onRename: { _ in }, onMove: { _ in }, onEdit: {}, onDelete: {}
                )
            } else if let milestone = entry as? Milestone {
                MilestoneCardView(pageID: pageID, milestone: milestone, actions: .inert, isPreview: true)
            } else if let todo = entry as? TodoItem {
                let workouts = workoutStore.workouts
                TodoRowView(
                    item: todo, depth: 1, hasChildren: !todo.children.isEmpty, isCollapsed: true, canIndent: false, canOutdent: false,
                    canMoveUp: false, canMoveDown: false, isFocused: false,
                    artwork: ChecklistArtwork.resolve(todo, pageID: pageID, store: store, workouts: workouts),
                    targets: Dictionary(todo.links.map { ($0.id, store.checklistTarget(of: $0, on: pageID, workouts: workouts)) }, uniquingKeysWith: { first, _ in first }),
                    pictureURLs: todo.imageFilenames.compactMap { store.checklistPictureURL($0, on: pageID) },
                    isPreview: true,
                    actions: .inert
                )
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .opacity(draft.trimmedTitle.isEmpty ? 0.6 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Fields

    private var titleField: some View {
        TextField(draft.isSection ? "Section" : Entry.kind == .milestone ? "Milestone" : "To-do", text: $draft.title)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.heading())
            .foregroundStyle(Theme.textPrimary)
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { save() }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange.opacity(titleFocused ? 0.9 : 0), lineWidth: 2)
            )
            .accessibilityLabel("Title")
    }

    private var noteField: some View {
        TextField("", text: $draft.note, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(3...8)
            .font(TimeMasterFont.body(16))
            .foregroundStyle(Theme.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("Note")
    }

    private var linksEditor: some View {
        let workouts = workoutStore.workouts
        let page = store.page(manifestID: pageID)
        return VStack(alignment: .leading, spacing: 12) {
            if !draft.links.isEmpty {
                ChecklistFlowLayout(spacing: 8) {
                    ForEach(draft.links) { link in
                        ChecklistLinkChip(
                            link: link,
                            target: store.checklistTarget(of: link, on: pageID, workouts: workouts),
                            linkMetadata: page?.manifest.linkMetadata ?? [],
                            comments: page?.manifest.mediaComments ?? [:],
                            onOpen: {}
                        )
                        .allowsHitTesting(false)
                        .overlay(alignment: .topTrailing) {
                            Button { draft.links.removeAll { $0.id == link.id } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.black.opacity(0.7))
                            }
                            .keyNavPlainButtonStyle(shape: .circle)
                            .offset(x: 6, y: -6)
                            .accessibilityLabel("Remove link")
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                linkButton("Workout", symbol: "figure.strengthtraining.traditional") { showingWorkoutPicker = true }
                linkButton("Page", symbol: "doc.text.image") { showingPagePicker = true }
                linkButton("File", symbol: "paperclip") { showingAttachmentPicker = true }
            }
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(Theme.textSecondary)
                TextField("https://", text: $webAddress)
                    .textFieldStyle(.plain)
                    .font(TimeMasterFont.body(15))
                    .foregroundStyle(Theme.textPrimary)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addWebAddress)
                if !webAddress.isEmpty {
                    Button(action: addWebAddress) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    .keyNavPlainButtonStyle(shape: .circle)
                    .accessibilityLabel("Add the address")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
    }

    private func linkButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                Text(title)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .disabled(draft.links.count >= Entry.maxLinks)
        .accessibilityLabel("Link a \(title.lowercased())")
    }

    private func field<Content: View>(_ label: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label.uppercased(), systemImage: symbol)
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .tracking(1.1)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    // MARK: Changes

    private func addLink(_ link: TodoLink) {
        guard !draft.links.contains(where: { $0.url == link.url }), draft.links.count < Entry.maxLinks else { return }
        draft.links.append(link)
    }

    private func addWebAddress() {
        let clean = webAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let full = clean.contains("://") ? clean : "https://\(clean)"
        guard case .web? = TmaxLink(full) else {
            errorMessage = "“\(clean)” is not a web address."
            return
        }
        addLink(TodoLink(url: full))
        webAddress = ""
    }

    private func beginImport(_ source: ChecklistPictureImporter.Source, as role: ChecklistPictureRole) {
        importRole = role
        importSource = source
    }

    private func importPicked(_ url: URL) {
        do {
            let filename = try store.uploadChecklistPicture(url, to: pageID)
            switch importRole {
            case .cover: draft.coverMediaFilename = filename
            case .image: if draft.imageFilenames.count < Entry.maxImages { draft.imageFilenames.append(filename) }
            case .icon: draft.iconImage = filename
            case .attachment: addLink(TodoLink(target: .media(filename: filename)))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancel() {
        if hasChanges { confirmingDiscard = true } else { dismiss() }
    }

    private func save() {
        guard !draft.trimmedTitle.isEmpty, !didSave else { return }
        do {
            if let existing {
                try store.updateChecklistEntry(Entry.self, existing.id, in: pageID) { draft.apply(to: &$0) }
            } else {
                var entry = Entry.blank(id: Entry.newID(), title: draft.trimmedTitle)
                draft.apply(to: &entry)
                var parentID: String?
                var index: Int?
                if case .create(let parent, let position) = route {
                    parentID = parent
                    index = position
                }
                try store.addChecklistEntry(entry, to: pageID, under: parentID, at: index)
            }
            didSave = true
            EverHaptic.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard let existing else { return }
        do {
            try store.removeChecklistEntry(Entry.self, existing.id, from: pageID)
            didSave = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
