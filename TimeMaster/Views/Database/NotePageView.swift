import SwiftUI
import TimeMasterCore

@MainActor
enum NoteEditIntent {
    static var pending: Set<String> = []
}

struct NotePageView: View {
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var readableWidth: CGFloat = 760
    @ScaledMetric(relativeTo: .body) private var margin: CGFloat = 20
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var inviteGlyphSize: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var bottomClearance: CGFloat = 96

    let pageID: UUID

    @State private var isEditing = false
    @State private var title = ""
    @State private var text = ""
    @State private var didLoad = false
    @State private var isDirty = false
    @State private var saveError: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var libraryToken = ExerciseLibraryAccess.shared.capture()
    @State private var choosingIcon = false
    @State private var confirmingDelete = false
    @State private var viewerURLs: [URL] = []
    @State private var viewerIndex = 0
    @State private var viewerPresented = false
    @FocusState private var titleFocused: Bool

    private var page: ExercisePage? { store.page(id: pageID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let page {
                content(page)
            } else {
                missingView
            }
        }
        .timeMasterNavigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #else
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            AppToolbar.iconItem(placement: .cancellationAction) {
                TimeMasterBackButton()
                    .oneHandedActionSource()
            }
            if saveError != nil {
                AppToolbar.iconItem(placement: .primaryAction) {
                    retryButton.oneHandedActionSource()
                }
            }
            AppToolbar.iconItem(placement: .primaryAction) {
                moreMenu.oneHandedActionSource()
            }
            AppToolbar.iconItem(placement: .primaryAction) {
                editToggle.oneHandedActionSource()
            }
        }
        .oneHandedActions(id: "note-page-\(pageID)", actions: pageActions)
        .onAppear(perform: load)
        .onChange(of: page == nil) { gone in
            if gone && didLoad { dismiss() }
        }
        .onChange(of: page?.manifest.markdownBody) { stored in
            guard didLoad, !isDirty, !isEditing, let stored, stored != text else { return }
            text = stored
        }
        .onChange(of: page?.manifest.title) { stored in
            guard didLoad, !isDirty, let stored, stored != title else { return }
            title = stored
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { save() }
        }
        .onDisappear { save() }
        .slotNavigationInteractionDisabled(isEditing || titleFocused)
        .sheet(isPresented: $choosingIcon) {
            if let page {
                NoteIconSheet(page: page) { icon in
                    save(icon: icon)
                }
                .environmentObject(store)
            }
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteNote)
            Button("Cancel", role: .cancel) {}
        }
        .mediaViewerCover(isPresented: $viewerPresented) {
            PageMediaGallery(
                urls: viewerURLs,
                selectedIndex: $viewerIndex,
                isPresented: $viewerPresented,
                comments: [:],
                onSaveComment: nil
            )
        }
    }

    @ViewBuilder
    private func content(_ page: ExercisePage) -> some View {
        if isEditing {
            VStack(spacing: 0) {
                titleRow(page)
                    .padding(.horizontal, margin)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .frame(maxWidth: readableWidth)
                MarkdownEditorView(text: $text, assets: store.noteAssets(for: page), autofocus: true)
                    .frame(maxWidth: readableWidth)
                    .onChange(of: text) { _ in scheduleSave() }
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleRow(page)
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        invitation
                    } else {
                        MarkdownDocumentView(markdown: text, assets: store.noteAssets(for: page))
                            .environment(\.markdownImageOpen, { path in openImage(path, page: page) })
                    }
                }
                .padding(.horizontal, margin)
                .padding(.top, 20)
                .padding(.bottom, bottomClearance)
                .frame(maxWidth: readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func titleRow(_ page: ExercisePage) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button { choosingIcon = true } label: {
                Group {
                    if let name = page.manifest.iconName, !name.isEmpty {
                        SkillIconView(iconName: name, iconType: page.manifest.iconType, size: glyphSize * 0.64)
                    } else {
                        Image(systemName: "note.text")
                            .font(.system(size: glyphSize * 0.56, weight: .semibold))
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                }
                .frame(width: glyphSize, height: glyphSize)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: glyphSize * 0.28, style: .continuous))
            }
            .keyNavPlainButtonStyle()
            .accessibilityLabel("Change the icon")
            .help("Change the icon")
            TextField("Untitled", text: $title)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.pageTitle(32, relativeTo: .largeTitle))
                .foregroundStyle(Theme.textPrimary)
                .onChange(of: title) { _ in scheduleSave() }
                .focused($titleFocused)
                .onSubmit { isEditing = true }
                .accessibilityLabel("Note title")
        }
    }

    private var invitation: some View {
        Button { isEditing = true } label: {
            VStack(spacing: 14) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: inviteGlyphSize, weight: .regular))
                    .foregroundStyle(Theme.toolbarOrange.opacity(0.85))
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: inviteGlyphSize * 0.5))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Start writing")
    }

    private var missingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("Note not found")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isEditing.toggle() }
            if !isEditing { save() }
        } label: {
            Image(systemName: isEditing ? "checkmark" : "pencil")
                .font(.system(size: 16, weight: .bold))
        }
        .keyboardShortcut(.return, modifiers: .command)
        .help(isEditing ? "Done" : "Edit")
        .accessibilityLabel(isEditing ? "Done editing" : "Edit note")
    }

    private var retryButton: some View {
        Button { save() } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .help(saveError ?? "")
        .accessibilityLabel("Not saved. Try again")
        .accessibilityValue(saveError ?? "")
    }

    private var moreMenu: some View {
        Menu {
            Button { choosingIcon = true } label: {
                Label("Icon", systemImage: "face.smiling")
            }
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
        }
        .menuStyle(.button)
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .accessibilityLabel("More")
    }

    private var pageActions: [ReachabilityAction] {
        [
            ReachabilityAction("back", title: "Back") { TimeMasterBackButton() },
            ReachabilityAction("edit", title: isEditing ? "Done" : "Edit", dismissesOnActivation: false) {
                editToggle.buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
        ]
    }

    private func load() {
        guard !didLoad, let page else { return }
        title = page.manifest.title
        text = page.manifest.markdownBody
        didLoad = true
        if NoteEditIntent.pending.remove(page.manifest.id) != nil { isEditing = true }
    }

    private func scheduleSave() {
        guard didLoad, let stored = page?.manifest,
              title.trimmingCharacters(in: .whitespacesAndNewlines) != stored.title || text != stored.markdownBody else { return }
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save(icon: NoteIcon? = nil) {
        saveTask?.cancel()
        saveTask = nil
        guard didLoad, isDirty || icon != nil, let page else { return }
        do {
            try store.saveNote(id: page.manifest.id, title: title, body: text, icon: icon, token: libraryToken)
            isDirty = false
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteNote() {
        saveTask?.cancel()
        isDirty = false
        do {
            try store.deletePage(id: pageID.uuidString)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func openImage(_ path: String, page: ExercisePage) {
        let assets = store.noteAssets(for: page)
        let urls = MarkdownDocument(markdown: text).blocks.compactMap { block -> URL? in
            guard case .image(let source) = block.kind, let url = assets.url(for: source), url.isFileURL else { return nil }
            return url
        }
        guard let tapped = assets.url(for: path), let index = urls.firstIndex(of: tapped) else { return }
        viewerURLs = urls
        viewerIndex = index
        viewerPresented = true
    }
}

struct NoteIconSheet: View {
    @Environment(\.dismiss) private var dismiss
    let page: ExercisePage
    let onChoose: (NoteIcon) -> Void

    @State private var iconName: String
    @State private var iconType: SkillBoardIconType

    init(page: ExercisePage, onChoose: @escaping (NoteIcon) -> Void) {
        self.page = page
        self.onChoose = onChoose
        _iconName = State(initialValue: page.manifest.iconName ?? "")
        _iconType = State(initialValue: page.manifest.iconType ?? .system)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        onChoose(NoteIcon(name: nil, type: nil))
                        dismiss()
                    } label: {
                        Image(systemName: "note.text")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.toolbarOrange)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Default note icon")
                    SkillIconPicker(iconName: $iconName, iconType: $iconType)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Use icon") {
                        onChoose(NoteIcon(name: iconName, type: iconType))
                        dismiss()
                    }
                    .disabled(iconName.isEmpty)
                }
            }
        }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 460)
        #endif
    }
}
