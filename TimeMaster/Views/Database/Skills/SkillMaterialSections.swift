import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

// MARK: - Prerequisites

/// "Learn first", in Skillmax's Dependencies layout: the pages and groups a page or group waits for, in the order to
/// learn them, each as a card with its place, its icon, its status and where it lives. A page that already waits on
/// this one is not offered (no loops).
struct SkillPrerequisitesSection: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState

    /// A page's manifest id, or a group id.
    let materialID: String

    private var candidates: [SkillMaterial] {
        let blocked = store.skillDependencyBlockedIDs(for: materialID)
        let pages = store.allPagesFlat
        var ids = pages.filter(\.isSkillLike).map(\.manifest.id)
        ids += pages.flatMap { page in
            page.manifest.skillBoardSections.map { SkillGroupID.make(containerID: page.manifest.id, sectionID: $0.id) }
        }
        return ids.filter { !blocked.contains($0) }.compactMap(store.skillMaterial(id:))
    }

    var body: some View {
        let dependencies = store.skillDependencies(of: materialID)
        let candidates = self.candidates
        let library = store.skillLibrary
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            PageSectionHeader(symbol: "list.number", title: "Learn first", count: dependencies.count) {
                addMenu(candidates, shape: .circle) {
                    PageSectionAddGlyph()
                }
                .help("Add a page to learn first")
                .accessibilityLabel("Add a page to learn first")
            }
            if dependencies.isEmpty {
                addMenu(candidates, shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius)) {
                    PageEmptyCard(
                        symbol: "arrow.triangle.branch",
                        title: "Nothing to learn first",
                        detail: candidates.isEmpty
                            ? "There is no other skill to learn before this one yet."
                            : "Pick the skills that come before this one. They show here in the order to learn them."
                    )
                }
                .accessibilityLabel("Nothing to learn first. Add a page.")
            } else {
                VStack(spacing: SkillMetrics.s2) {
                    ForEach(Array(dependencies.enumerated()), id: \.element.id) { index, dependency in
                        row(dependency, index: index, in: dependencies, library: library)
                    }
                }
            }
        }
    }

    private func addMenu<Content: View>(_ candidates: [SkillMaterial], shape: KeyNavShape, @ViewBuilder label: () -> Content) -> some View {
        Menu {
            ForEach(candidates) { candidate in
                Button {
                    add(candidate)
                } label: {
                    Label(candidate.title, systemImage: candidate.isGroup ? "square.grid.2x2" : "circle.dashed")
                }
            }
        } label: {
            label()
        }
        .menuStyle(.button)
        .keyNavPlainButtonStyle(shape: shape)
        .menuIndicator(.hidden)
        .disabled(candidates.isEmpty)
    }

    private func row(_ dependency: SkillMaterial, index: Int, in all: [SkillMaterial], library: SkillLibrary) -> some View {
        let status = self.status(of: dependency)
        return HStack(spacing: SkillMetrics.s2) {
            Text("\(index + 1)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Button {
                open(dependency)
            } label: {
                rowLabel(dependency, status: status, path: path(of: dependency, library: library))
            }
            .buttonStyle(SkillPressButtonStyle())
            .accessibilityLabel("\(index + 1). \(dependency.title), \(status.title)")
            .accessibilityHint(dependency.isGroup ? "Opens this group" : "Opens this page")
            Menu {
                actions(for: dependency, index: index, in: all)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .keyNavPlainButtonStyle(shape: .circle)
            .fixedSize()
            .accessibilityLabel("Options for \(dependency.title)")
        }
        .padding(.horizontal, SkillMetrics.s3)
        .padding(.vertical, SkillMetrics.s2)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
        .contextMenu { actions(for: dependency, index: index, in: all) }
    }

    private func rowLabel(_ dependency: SkillMaterial, status: SkillStatus, path: String) -> some View {
        HStack(spacing: SkillMetrics.s3) {
            icon(of: dependency)
            VStack(alignment: .leading, spacing: 4) {
                Text(TimeMasterFont.initialCapitalizedTitle(dependency.title))
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(status.titleOpacity)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: SkillMetrics.s2) {
                    SkillStatusChip(status)
                        .fixedSize()
                    if !path.isEmpty {
                        Text(path)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: SkillMetrics.s2)
        }
        .frame(minHeight: SkillMetrics.touch)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func icon(of dependency: SkillMaterial) -> some View {
        if let page = dependency.page {
            SkillPageIconTile(page: page, size: 40, tilesSymbols: true)
        } else if let section = dependency.section {
            let icon = section.icon.flatMap { $0.isEmpty ? nil : $0 }
            SkillIconView(
                iconName: icon ?? "square.grid.2x2",
                iconType: icon == nil ? SkillBoardIconType.system : section.iconType,
                size: 19
            )
            .frame(width: 40, height: 40)
            .skillTile(cornerRadius: 40 * 0.32)
        }
    }

    @ViewBuilder
    private func actions(for dependency: SkillMaterial, index: Int, in all: [SkillMaterial]) -> some View {
        Button {
            open(dependency)
        } label: {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        Button {
            reorder(all, from: index, to: index - 1)
        } label: {
            Label("Learn earlier", systemImage: "arrow.up")
        }
        .disabled(index == 0)
        Button {
            reorder(all, from: index, to: index + 1)
        } label: {
            Label("Learn later", systemImage: "arrow.down")
        }
        .disabled(index == all.count - 1)
        Divider()
        Button(role: .destructive) {
            remove(dependency)
        } label: {
            Label("Remove from Learn first", systemImage: "minus.circle")
        }
    }

    /// A page's own status; a group is done once every skill in it is, and in progress once any has started.
    private func status(of dependency: SkillMaterial) -> SkillStatus {
        guard dependency.isGroup else { return dependency.manifest.skillStatus ?? .notStarted }
        let progress = store.skillProgress(of: dependency.id)
        if progress.total > 0, progress.completed == progress.total { return .completed }
        return progress.completed + progress.learning > 0 ? .learning : .notStarted
    }

    /// Where it lives: the titles above a page ("Guitar › Chords"), or the page a group sits on.
    private func path(of dependency: SkillMaterial, library: SkillLibrary) -> String {
        if let container = dependency.groupContainer { return container.title }
        guard let page = dependency.page else { return "" }
        return library.ancestors(of: page).reversed().map(\.title).joined(separator: " › ")
    }

    private func add(_ candidate: SkillMaterial) {
        if SkillErrorCenter.shared.attempt("Add the prerequisite", { try store.addSkillDependency(candidate.id, to: materialID) }) {
            EverHaptic.success()
        }
    }

    private func remove(_ dependency: SkillMaterial) {
        if SkillErrorCenter.shared.attempt("Remove the prerequisite", { try store.removeSkillDependency(dependency.id, from: materialID) }) {
            EverHaptic.selection()
        }
    }

    private func reorder(_ items: [SkillMaterial], from: Int, to: Int) {
        guard items.indices.contains(to) else { return }
        var ids = items.map(\.id)
        ids.swapAt(from, to)
        if SkillErrorCenter.shared.attempt("Reorder prerequisites", { try store.reorderSkillDependencies(in: materialID, ids: ids) }) {
            EverHaptic.selection()
        }
    }

    private func open(_ material: SkillMaterial) {
        navigationState.open(skillID: material.id)
    }
}

// MARK: - Notes

/// Markdown notes that edit in place and autosave, under Skillmax's heading with Write, Edit or Done at its end.
/// Double-click (double-tap) the rendered note to edit it; an empty note is one big target that starts it.
struct SkillNotesSection: View {
    @EnvironmentObject private var store: DatabaseStore
    let materialID: String
    var title = "Notes"

    @State private var draft = ""
    @State private var loaded = false
    @State private var saved = ""
    @State private var editing = false

    private var source: String { store.skillMaterial(id: materialID)?.manifest.markdownBody ?? "" }
    private var assets: MarkdownAssets? {
        store.skillMaterial(id: materialID).map { FolderMarkdownAssets(folder: $0.folderURL) }
    }
    private var isBlank: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            PageSectionHeader(symbol: "note.text", title: title) {
                if editing {
                    PageSectionTextButton(title: "Done", action: finishEditing)
                } else {
                    PageSectionTextButton(title: isBlank ? "Write" : "Edit") { editing = true }
                }
            }
            if editing {
                MarkdownEditorView(text: $draft, assets: assets, autofocus: true)
                    .frame(minHeight: 260, maxHeight: 420)
                    .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
                    #if os(macOS)
                    .onExitCommand { finishEditing() }
                    #endif
            } else if isBlank {
                Button {
                    editing = true
                } label: {
                    PageEmptyCard(symbol: "square.and.pencil", title: "Write a note", detail: "It saves as you type.")
                        .contentShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous))
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Write a note")
            } else {
                MarkdownTextView(text: draft, assets: assets)
                    .padding(SkillMetrics.s4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
                    .contentShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous))
                    .onTapGesture(count: 2) { editing = true }
                    .keyNavTarget(id: "notes-\(materialID)", shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius)) {
                        editing = true
                    }
                    .help("Double-click to edit")
                    .accessibilityAction(named: "Edit note") { editing = true }
            }
        }
        .onAppear {
            guard !loaded else { return }
            draft = source
            saved = draft
            loaded = true
        }
        .onChange(of: source) { value in
            guard !editing, draft == saved else { return }
            draft = value
            saved = value
        }
        .task(id: draft) {
            guard loaded, draft != saved else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            flush()
        }
        .onDisappear { flush() }
    }

    private func finishEditing() {
        flush()
        editing = false
    }

    private func flush() {
        guard loaded, draft != saved else { return }
        if SkillErrorCenter.shared.attempt("Save the notes", { try store.updateSkillNotes(materialID, markdown: draft) }) {
            saved = draft
        }
    }
}

// MARK: - Files

/// The files of a skill or group under Skillmax's heading: add, open with their comment, mark as a prerequisite,
/// choose a cover or strip, and remove.
struct SkillFilesSection: View {
    @EnvironmentObject private var store: DatabaseStore
    let materialID: String

    @State private var showingImporter = false
    @State private var galleryPresented = false
    @State private var selectedIndex = 0
    @State private var commentTarget: URL?
    @State private var commentText = ""

    private var material: SkillMaterial? { store.skillMaterial(id: materialID) }

    var body: some View {
        let urls = material?.mediaURLs ?? []
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            PageSectionHeader(symbol: "paperclip", title: "Files", count: urls.count) {
                PageSectionAddButton(label: "Add files") { showingImporter = true }
            }
            if urls.isEmpty {
                PageEmptyCard(
                    symbol: "tray.and.arrow.down",
                    title: "No files yet",
                    detail: "Photos, videos, PDFs: whatever helps you learn this."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: SkillMetrics.s2)], spacing: SkillMetrics.s2) {
                    ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                        tile(url, index: index)
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let picked) = result else { return }
            for url in picked {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                SkillErrorCenter.shared.attempt("Add the file") { try store.uploadSkillMedia(url, to: materialID) }
            }
        }
        .alert("Comment", isPresented: Binding(get: { commentTarget != nil }, set: { if !$0 { commentTarget = nil } })) {
            TextField("What is this file for?", text: $commentText)
            Button("Save") {
                if let target = commentTarget {
                    SkillErrorCenter.shared.attempt("Save the comment") {
                        try store.updateMediaComment(pageID: materialID, filename: target.lastPathComponent, comment: commentText)
                    }
                }
                commentTarget = nil
            }
            Button("Cancel", role: .cancel) { commentTarget = nil }
        }
        .mediaViewerCover(isPresented: $galleryPresented) {
            if let material {
                PageMediaGallery(
                    urls: material.mediaURLs,
                    selectedIndex: $selectedIndex,
                    isPresented: $galleryPresented,
                    comments: material.mediaCommentsByURL,
                    onSaveComment: { url, comment in
                        try store.updateMediaComment(pageID: materialID, filename: url.lastPathComponent, comment: comment)
                    },
                    opensEditor: false,
                    notesAssets: { _ in FolderMarkdownAssets(folder: material.folderURL) },
                    workout: nil,
                    liveContext: nil
                )
            }
        }
    }

    private func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    private func tile(_ url: URL, index: Int) -> some View {
        let filename = url.lastPathComponent
        let isPrerequisite = material?.manifest.dependencyMediaFilenames.contains(filename) ?? false
        let isStrip = material?.section?.imageFilename == filename
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        return Button {
            selectedIndex = index
            galleryPresented = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                if isImage(url) {
                    SkillLocalImage(url: url, maxPixel: 360)
                } else {
                    Theme.surface2
                    Image(systemName: "doc")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 4) {
                    if isPrerequisite { Image(systemName: "arrow.turn.down.right") }
                    if isStrip { Image(systemName: "photo") }
                    Text(filename)
                        .lineLimit(1)
                }
                .font(TimeMasterFont.micro())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.55))
            }
            .frame(height: 96)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.separator, lineWidth: 1))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius))
        .contextMenu {
            Button {
                commentText = material?.manifest.mediaComments[filename] ?? ""
                commentTarget = url
            } label: { Label("Comment…", systemImage: "text.bubble") }
            Button {
                SkillErrorCenter.shared.attempt("Change the prerequisite flag") {
                    try store.setSkillMediaIsDependency(filename, in: materialID, !isPrerequisite)
                }
            } label: { Label(isPrerequisite ? "Not a prerequisite" : "Learn this first", systemImage: "arrow.turn.down.right") }
            if isImage(url), let owner = SkillGroupID.split(materialID) {
                Button {
                    SkillErrorCenter.shared.attempt("Set the strip picture") {
                        try store.updateSkillGroup(containerID: owner.containerID, sectionID: owner.sectionID) { $0.imageFilename = isStrip ? nil : filename }
                    }
                } label: { Label(isStrip ? "Remove from the strip" : "Use in the strip", systemImage: "photo") }
            } else if isImage(url) {
                let isCover = material?.manifest.coverMediaFilename == filename
                Button {
                    SkillErrorCenter.shared.attempt("Set the cover") {
                        try store.setSkillCover(materialID, filename: isCover ? nil : filename)
                    }
                } label: { Label(isCover ? "Remove the cover" : "Use as cover", systemImage: "photo") }
                Button {
                    SkillErrorCenter.shared.attempt("Set the icon") {
                        try store.setSkillIcon(materialID, name: nil, type: nil, image: filename)
                    }
                } label: { Label("Use as icon", systemImage: "person.crop.square") }
            }
            Divider()
            Button(role: .destructive) {
                SkillErrorCenter.shared.attempt("Remove the file") { try store.removeSkillMedia(filename, from: materialID) }
            } label: { Label("Remove", systemImage: "trash") }
        }
    }
}

// MARK: - Links

/// Which links a links section lists.
enum SkillLinkScope {
    /// Every link of the page or group.
    case all
    /// The links that are the page's own attachments (not needed first).
    case reference
    /// The links to have first.
    case dependencies
}

/// The links of a skill or group: add by address, open, comment, move between attachments and what to have first,
/// remove. Under Skillmax's "Links" heading unless the host's own heading covers them.
struct SkillLinksSection: View {
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.openURL) private var openURL
    let materialID: String
    var scope = SkillLinkScope.all
    var showsHeader = true

    @State private var address = ""
    @State private var commentTarget: String?
    @State private var commentText = ""

    private var manifest: ExercisePageManifest? { store.skillMaterial(id: materialID)?.manifest }

    private var links: [String] {
        guard let manifest else { return [] }
        let flagged = Set(manifest.dependencyLinkURLs)
        switch scope {
        case .all: return manifest.linkURLs
        case .reference: return manifest.linkURLs.filter { !flagged.contains($0) }
        case .dependencies: return manifest.linkURLs.filter { flagged.contains($0) }
        }
    }

    var body: some View {
        let links = self.links
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            if showsHeader {
                PageSectionHeader(symbol: "link", title: "Links", count: links.count)
            }
            ForEach(links, id: \.self) { link in
                row(link)
            }
            addField
        }
        .alert("Comment", isPresented: Binding(get: { commentTarget != nil }, set: { if !$0 { commentTarget = nil } })) {
            TextField("What is this link for?", text: $commentText)
            Button("Save") {
                if let target = commentTarget {
                    SkillErrorCenter.shared.attempt("Save the comment") {
                        try store.updateSkillLinkComment(commentText, url: target, in: materialID)
                    }
                }
                commentTarget = nil
            }
            Button("Cancel", role: .cancel) { commentTarget = nil }
        }
    }

    private var addField: some View {
        HStack(spacing: SkillMetrics.s2) {
            Image(systemName: "link")
                .foregroundStyle(Theme.textSecondary)
            TextField(scope == .dependencies ? "Paste an address to have first" : "Paste an address", text: $address)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(15))
                .foregroundStyle(Theme.textPrimary)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(add)
        }
        .padding(.horizontal, SkillMetrics.s3)
        .frame(minHeight: SkillMetrics.touch)
        .overlay {
            RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
                .strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
    }

    private func row(_ link: String) -> some View {
        let title = manifest?.linkMetadata.first { $0.url == link }?.title
        let isPrerequisite = manifest?.dependencyLinkURLs.contains(link) ?? false
        let comment = manifest?.linkComments[link]
        return Button {
            if let url = URL(string: link) { openURL(url) }
        } label: {
            HStack(spacing: SkillMetrics.s3) {
                Image(systemName: isPrerequisite ? "arrow.turn.down.right" : "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 32, height: 32)
                    .skillTile(cornerRadius: 32 * 0.32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? URL(string: link)?.host ?? link)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let comment, !comment.isEmpty {
                        Text(comment)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    } else if title != nil, let host = URL(string: link)?.host {
                        Text(host)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SkillMetrics.s3)
            .padding(.vertical, SkillMetrics.s2)
            .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
            .contentShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius))
        .contextMenu {
            Button {
                commentText = comment ?? ""
                commentTarget = link
            } label: { Label("Comment…", systemImage: "text.bubble") }
            Button {
                if SkillErrorCenter.shared.attempt("Change the prerequisite flag", {
                    try store.setSkillLinkIsDependency(link, in: materialID, !isPrerequisite)
                }) {
                    EverHaptic.selection()
                }
            } label: { flagLabel(isPrerequisite: isPrerequisite) }
            Divider()
            Button(role: .destructive) {
                SkillErrorCenter.shared.attempt("Remove the link") { try store.removeSkillLink(link, from: materialID) }
            } label: { Label("Remove", systemImage: "trash") }
        }
    }

    /// Where the flag sends the link: between Attachments and Dependencies on a page's tabs, on or off "Learn first"
    /// elsewhere.
    private func flagLabel(isPrerequisite: Bool) -> Label<Text, Image> {
        switch scope {
        case .all:
            return Label(isPrerequisite ? "Not a prerequisite" : "Learn this first", systemImage: "arrow.turn.down.right")
        case .reference, .dependencies:
            return isPrerequisite
                ? Label("Move to Attachments", systemImage: "paperclip")
                : Label("Move to Dependencies", systemImage: "arrow.triangle.branch")
        }
    }

    private func add() {
        let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let full = clean.contains("://") ? clean : "https://\(clean)"
        if SkillErrorCenter.shared.attempt("Add the link", { try store.addSkillLink(full, to: materialID, asDependency: scope == .dependencies) }) {
            address = ""
            EverHaptic.success()
        }
    }
}

// MARK: - Icon chooser

/// Picks the icon of a page (or group): a symbol or an emoji, or "Automatic" to take one from the title.
struct SkillIconChooserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    /// A page's manifest id, or a group id.
    let pageID: String

    @State private var iconName = ""
    @State private var iconType: SkillBoardIconType = .emoji
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        apply(name: nil, type: nil)
                    } label: {
                        Label("Automatic: from the title", systemImage: "wand.and.stars")
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.toolbarOrange)
                    }.keyNavPlainButtonStyle()
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
                    Button("Use icon") { apply(name: iconName, type: iconType) }.disabled(iconName.isEmpty)
                }
            }
        }
        .keyNavHost()
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 460)
        #endif
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let manifest = store.skillMaterial(id: pageID)?.manifest, let name = manifest.iconName {
                iconName = name
                iconType = manifest.iconType ?? .emoji
            }
        }
    }

    private func apply(name: String?, type: SkillBoardIconType?) {
        if SkillErrorCenter.shared.attempt("Set the icon", { try store.setSkillIcon(pageID, name: name, type: type) }) {
            dismiss()
        }
    }
}
