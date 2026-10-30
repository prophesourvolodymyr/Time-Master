import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

private func skillSectionHeader(_ title: String) -> some View {
    Text(title)
        .font(TimeMasterFont.sectionTitle())
        .foregroundStyle(Theme.textPrimary)
}

// MARK: - Prerequisites

/// "Learn first": the pages and groups a page or group waits for, in order. A page that already waits on this one
/// is not offered (no loops).
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                skillSectionHeader("Learn first")
                Spacer()
                Menu {
                    ForEach(candidates) { candidate in
                        Button {
                            SkillErrorCenter.shared.attempt("Add the prerequisite") {
                                try store.addSkillDependency(candidate.id, to: materialID)
                            }
                        } label: {
                            Label(candidate.title, systemImage: candidate.isGroup ? "square.grid.2x2" : "circle.dashed")
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(candidates.isEmpty ? Theme.textSecondary : Theme.toolbarOrange)
                }
                .menuStyle(.button).keyNavPlainButtonStyle()
                .menuIndicator(.hidden)
                .disabled(candidates.isEmpty)
            }
            if dependencies.isEmpty {
                Text("Nothing to learn first.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(dependencies.enumerated()), id: \.element.id) { index, dependency in
                HStack(spacing: 10) {
                    Image(systemName: dependency.isGroup ? "square.grid.2x2" : (dependency.manifest.skillStatus ?? .notStarted).symbolName)
                        .foregroundStyle((dependency.manifest.skillStatus ?? .notStarted).color)
                        .frame(width: 24)
                    Button {
                        open(dependency)
                    } label: {
                        Text(dependency.title)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyNavRole(.excluded)
                    Menu {
                        Button {
                            reorder(dependencies, from: index, to: index - 1)
                        } label: { Label("Move up", systemImage: "arrow.up") }
                        .disabled(index == 0)
                        Button {
                            reorder(dependencies, from: index, to: index + 1)
                        } label: { Label("Move down", systemImage: "arrow.down") }
                        .disabled(index == dependencies.count - 1)
                        Button(role: .destructive) {
                            SkillErrorCenter.shared.attempt("Remove the prerequisite") {
                                try store.removeSkillDependency(dependency.id, from: materialID)
                            }
                        } label: {
                            Label("Remove", systemImage: "xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 30, height: 30)
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .keyNavPlainButtonStyle()
                    .accessibilityLabel("\(dependency.title) options")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .keyNavTarget(id: dependency.id, role: .primary, shape: .roundedRectangle(cornerRadius: 12)) {
                    open(dependency)
                }
            }
        }
    }

    private func reorder(_ items: [SkillMaterial], from: Int, to: Int) {
        guard items.indices.contains(to) else { return }
        var ids = items.map(\.id)
        ids.swapAt(from, to)
        SkillErrorCenter.shared.attempt("Reorder prerequisites") {
            try store.reorderSkillDependencies(in: materialID, ids: ids)
        }
    }

    private func open(_ material: SkillMaterial) {
        if let owner = SkillGroupID.split(material.id) {
            navigationState.path.append(DatabaseSkillGroupRoute(containerID: owner.containerID, sectionID: owner.sectionID))
        } else {
            navigationState.path.append(DatabasePageRoute(pageID: material.id))
        }
    }
}

// MARK: - Notes

/// Markdown notes that edit in place and autosave. Double-click the rendered note, or click an empty note.
struct SkillNotesSection: View {
    @EnvironmentObject private var store: DatabaseStore
    let materialID: String

    @State private var draft = ""
    @State private var loaded = false
    @State private var saved = ""
    @State private var editing = false

    private var source: String { store.skillMaterial(id: materialID)?.manifest.markdownBody ?? "" }
    private var assets: MarkdownAssets? {
        store.skillMaterial(id: materialID).map { FolderMarkdownAssets(folder: $0.folderURL) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                skillSectionHeader("Notes")
                Spacer()
                if editing {
                    Button("Done") { finishEditing() }
                        .foregroundStyle(Theme.toolbarOrange)
                        .keyNavPlainButtonStyle()
                }
            }
            if editing {
                MarkdownEditorView(text: $draft, assets: assets, autofocus: true)
                    .frame(minHeight: 260, maxHeight: 420)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    #if os(macOS)
                    .onExitCommand { finishEditing() }
                    #endif
            } else {
                Group {
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Write a note…")
                            .font(TimeMasterFont.body(15))
                            .foregroundStyle(Theme.textSecondary)
                            .onTapGesture { editing = true }
                    } else {
                        MarkdownTextView(text: draft, assets: assets)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture(count: 2) { editing = true }
                .keyNavTarget(id: "notes-\(materialID)", shape: .roundedRectangle(cornerRadius: 12)) { editing = true }
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

/// The files of a skill or group: add, open with their comment, mark as a prerequisite, choose a cover or strip,
/// and remove.
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                skillSectionHeader("Files")
                Spacer()
                Button { showingImporter = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.toolbarOrange)
                }.keyNavPlainButtonStyle()
            }
            if urls.isEmpty {
                Text("No files yet.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 10)], spacing: 10) {
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.keyNavPlainButtonStyle()
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

/// The links of a skill or group: add by address, open, comment, mark as a prerequisite, remove.
struct SkillLinksSection: View {
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.openURL) private var openURL
    let materialID: String

    @State private var address = ""
    @State private var commentTarget: String?
    @State private var commentText = ""

    private var manifest: ExercisePageManifest? { store.skillMaterial(id: materialID)?.manifest }

    var body: some View {
        let links = manifest?.linkURLs ?? []
        VStack(alignment: .leading, spacing: 8) {
            skillSectionHeader("Links")
            ForEach(links, id: \.self) { link in
                row(link)
            }
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(Theme.textSecondary)
                TextField("Paste an address", text: $address)
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
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
            }
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

    private func row(_ link: String) -> some View {
        let title = manifest?.linkMetadata.first { $0.url == link }?.title
        let isPrerequisite = manifest?.dependencyLinkURLs.contains(link) ?? false
        let comment = manifest?.linkComments[link]
        return Button {
            if let url = URL(string: link) { openURL(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPrerequisite ? "arrow.turn.down.right" : "link")
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 22)
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }.keyNavPlainButtonStyle()
        .contextMenu {
            Button {
                commentText = comment ?? ""
                commentTarget = link
            } label: { Label("Comment…", systemImage: "text.bubble") }
            Button {
                SkillErrorCenter.shared.attempt("Change the prerequisite flag") {
                    try store.setSkillLinkIsDependency(link, in: materialID, !isPrerequisite)
                }
            } label: { Label(isPrerequisite ? "Not a prerequisite" : "Learn this first", systemImage: "arrow.turn.down.right") }
            Divider()
            Button(role: .destructive) {
                SkillErrorCenter.shared.attempt("Remove the link") { try store.removeSkillLink(link, from: materialID) }
            } label: { Label("Remove", systemImage: "trash") }
        }
    }

    private func add() {
        let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let full = clean.contains("://") ? clean : "https://\(clean)"
        if SkillErrorCenter.shared.attempt("Add the link", { try store.addSkillLink(full, to: materialID) }) {
            address = ""
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
