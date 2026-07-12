import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import TimeMasterCore
#if os(macOS)
import AVKit
#endif

// MARK: - MovieFile (Transferable for video picking — module-wide)

struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) {
            SentTransferredFile($0.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

// MARK: - MediaThumbnailView (module-wide reusable thumbnail)

struct MediaThumbnailView: View {
    let item: MediaItem
    let size: CGFloat
    let cornerRadius: CGFloat

    #if os(iOS)
    @State private var thumbnail: UIImage?
    #elseif os(macOS)
    @State private var thumbnail: NSImage?
    #endif

    var body: some View {
        if size > 0 {
            ZStack {
                if let thumbnail = thumbnail {
#if os(iOS)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
#elseif os(macOS)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
#endif
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Theme.surface)
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: item.type == .video ? "video" : "photo")
                                .font(.system(size: max(size * 0.3, 14)))
                                .foregroundColor(Theme.textSecondary.opacity(0.5))
                        )
                }
                if item.type == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: max(size * 0.32, 14)))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
            .frame(width: size, height: size)
            .onAppear { loadThumbnail() }
        } else {
            // Fill mode: no fixed frame — parent controls size via .frame(maxWidth:).frame(height:)
            ZStack {
                if let thumbnail = thumbnail {
#if os(iOS)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #elseif os(macOS)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                        .overlay(
                            Image(systemName: item.type == .video ? "video" : "photo")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.textSecondary.opacity(0.5))
                        )
                }
                if item.type == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
            .onAppear { loadThumbnail() }
        }
    }

    private func loadThumbnail() {
        let item = item
        Task.detached(priority: .userInitiated) {
            let img = PhotoManager.shared.thumbnail(for: item)
            await MainActor.run { thumbnail = img }
        }
    }
}

// MARK: - MarkdownTextView (module-wide)

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                markdownLine(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.title2.bold()).foregroundColor(Theme.textPrimary)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.title3.weight(.semibold)).foregroundColor(Theme.textPrimary)
        } else if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.headline).foregroundColor(Theme.textPrimary)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•").foregroundColor(Theme.textSecondary).frame(width: 12)
                inlineMarkdownView(String(line.dropFirst(2)))
            }
        } else if line.isEmpty {
            Text(" ").font(.caption2)
        } else {
            inlineMarkdownView(line)
        }
    }

    @ViewBuilder
    private func inlineMarkdownView(_ s: String) -> some View {
        if let attr = try? AttributedString(markdown: s,
                                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attr).foregroundColor(Theme.textPrimary).font(.body)
        } else {
            Text(s).foregroundColor(Theme.textPrimary).font(.body)
        }
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    let note: DatabaseNote

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.title3).foregroundColor(Theme.textSecondary).frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.caption).foregroundColor(Theme.textSecondary).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - NoteDetailView (inline editor — selectable & directly editable)

struct NoteDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    @Environment(\.dismiss) private var dismiss

    let noteID: UUID
    let folderID: UUID?

    @State private var title: String = ""
    @State private var noteBody: String = ""
    @State private var loaded = false

    private var storedNote: DatabaseNote? {
        if let fid = folderID {
            return store.folder(id: fid)?.notes.first(where: { $0.id == noteID })
        } else {
            return store.rootNotes.first(where: { $0.id == noteID })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Title field
                    TextField("Title", text: $title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    Divider().background(Theme.separator)

                    // Body editor — fills remaining space
                    TextEditor(text: $noteBody)
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndDismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                guard !loaded, let n = storedNote else { return }
                title    = n.title
                noteBody = n.body
                loaded   = true
            }
            .onDisappear { persistIfNeeded() }
        }
    }

    private func saveAndDismiss() {
        persistIfNeeded()
        dismiss()
    }

    private func persistIfNeeded() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, let original = storedNote else { return }
        guard trimmedTitle != original.title || noteBody != original.body else { return }
        var updated = original
        updated.title = trimmedTitle
        updated.body  = noteBody
        if let fid = folderID {
            store.updateNote(updated, inFolderID: fid)
        } else {
            store.updateRootNote(updated)
        }
    }
}

// MARK: - NoteEditorView

struct NoteEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: DatabaseStore

    let existingNote: DatabaseNote?
    let folderID: UUID?

    @State private var title: String
    @State private var noteBody: String

    init(note: DatabaseNote? = nil, folderID: UUID? = nil) {
        self.existingNote = note
        self.folderID = folderID
        _title    = State(initialValue: note?.title ?? "")
        _noteBody = State(initialValue: note?.body  ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        titleCard
                        bodyCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNote() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Title").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("Note title…", text: $title)
                .padding(14).background(Theme.surface).cornerRadius(10).foregroundColor(Theme.textPrimary)
        }
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Content").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("Markdown supported")
                    .font(.caption2).foregroundColor(Theme.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if noteBody.isEmpty {
                    Text("Write your note here…\n\nSupports **bold**, *italic*, `code`, # Headings, - lists")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                        .font(.body)
                }
                TextEditor(text: $noteBody)
                    .frame(minHeight: 200).padding(10)
                    .scrollContentBackground(.hidden).foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private func saveNote() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if let existing = existingNote {
            var updated = existing
            updated.title = t
            updated.body  = noteBody
            if let fid = folderID {
                store.updateNote(updated, inFolderID: fid)
            } else {
                store.updateRootNote(updated)
            }
        } else {
            let newNote = DatabaseNote(title: t, body: noteBody)
            if let fid = folderID {
                store.addNote(newNote, toFolderID: fid)
            } else {
                store.addRootNote(newNote)
            }
        }
        dismiss()
    }
}

// MARK: - DatabaseView (root)

struct DatabaseView: View {
    @EnvironmentObject var store: DatabaseStore
    @State private var showingNewFolderSheet     = false
    @State private var showingImport             = false
    @State private var showingDatabaseImport     = false
    @State private var showingAddRootNote        = false
    @State private var showingAddRootExercise    = false
    @State private var selectedRootNote: DatabaseNote?
    @State private var selectedRootExercise: Exercise?
    @State private var exerciseToMove: Exercise?
    @State private var noteToMove: DatabaseNote?
    @State private var folderToExport: ExerciseFolder?
    @State private var showingCreatePage = false
    @State private var selectedPage: ExercisePage?
    @State private var pageToMove: ExercisePage?

    var body: some View {
        let isV2 = MigrationManager.isV2PageMigrationComplete

        return NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if isV2 && !store.rootPages.isEmpty {
                    pageTreeView
                } else if !isV2 {
                    rootList
                } else {
                    v2EmptyState
                }
            }
            .navigationTitle("Exercise Database")
            .toolbar {
                if isV2 {
                    #if os(iOS)
                    EditButton().foregroundColor(.white)
                    #endif
                } else {
                    #if os(iOS)
                    EditButton().foregroundColor(.white)
                    #endif
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingImport = true } label: {
                        Image(systemName: "video.badge.plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingDatabaseImport = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if isV2 {
                            Button { showingCreatePage = true } label: {
                                Label("New Page", systemImage: "doc.badge.plus")
                            }
                        } else {
                            Button { showingNewFolderSheet = true } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                            Button { showingAddRootNote = true } label: {
                                Label("New Note", systemImage: "note.text.badge.plus")
                            }
                            Button { showingAddRootExercise = true } label: {
                                Label("New Exercise", systemImage: "figure.strengthtraining.traditional")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewFolderSheet) {
                NewFolderSheet { name, colorHex, workoutType in
                    store.addRootFolder(name: name, colorHex: colorHex, workoutType: workoutType)
                }
            }
            .sheet(isPresented: $showingCreatePage) {
                PageCreationSheet(parentID: nil) { manifest, _ in
                    try? store.createPage(manifest: manifest, parentID: nil)
                }
                .environmentObject(WorkoutStore())
            }
            .sheet(isPresented: $showingImport) {
                ImportSheetView()
            }
            .sheet(isPresented: $showingAddRootNote) {
                NoteEditorView(folderID: nil).environmentObject(store)
            }
            .sheet(isPresented: $showingAddRootExercise) {
                AddExerciseView(folderID: nil).environmentObject(store)
            }
            .sheet(item: $selectedRootNote) { note in
                NoteDetailView(noteID: note.id, folderID: nil).environmentObject(store)
            }
            .sheet(item: $selectedRootExercise) { exercise in
                EditExerciseView(exercise: exercise, folderID: nil).environmentObject(store)
            }
            .sheet(item: $exerciseToMove) { exercise in
                FolderPickerSheet(currentFolderID: nil) { destID in
                    store.moveExercise(id: exercise.id, fromFolderID: nil, toFolderID: destID)
                }
                .environmentObject(store)
            }
            .sheet(item: $noteToMove) { note in
                FolderPickerSheet(currentFolderID: nil) { destID in
                    store.moveNote(id: note.id, fromFolderID: nil, toFolderID: destID)
                }
                .environmentObject(store)
            }
            .sheet(item: $folderToExport) { f in
                FolderExportSheet(folder: f)
            }
            .fileImporter(
                isPresented: $showingDatabaseImport,
                allowedContentTypes: [UTType("public.zip-archive") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleDatabaseImport(result)
            }
        }
    }

    private func handleDatabaseImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let workoutStore = WorkoutStore()
        Task.detached {
            do {
                let summary = try BackupManager.shared.importBackup(
                    from: url,
                    workoutStore: workoutStore,
                    databaseStore: store
                )
                await MainActor.run {
                    print("[DatabaseView] Import complete: \(summary.exercisesImported) exercises, \(summary.workoutsImported) workouts, \(summary.historyImported) history, \(summary.mediaImported) media, \(summary.duplicatesSkipped) duplicates skipped")
                }
            } catch {
                print("Database import error: \(error)")
            }
        }
    }

    private var rootList: some View {
        List {
            let hasContent = !store.rootFolders.isEmpty || !store.rootExercises.isEmpty || !store.rootNotes.isEmpty
            if !hasContent {
                emptyState
            } else {
                rootExercisesSection
                rootNotesSection
                rootFoldersSection
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var rootExercisesSection: some View {
        if !store.rootExercises.isEmpty {
            SwiftUI.Section("Ungrouped") {
                ForEach(store.rootExercises) { exercise in
                    HStack {
                        ExerciseRowView(exercise: exercise)
                        Spacer()
                        Text("Ungrouped")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedRootExercise = exercise }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { exerciseToMove = exercise } label: {
                            Label("Move", systemImage: "folder")
                        }
                        .tint(Color.white.opacity(0.8))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteRootExercise(id: exercise.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .onMove { store.moveRootExercise(from: $0, to: $1) }
            }
        }
    }

    @ViewBuilder
    private var rootNotesSection: some View {
        if !store.rootNotes.isEmpty {
            SwiftUI.Section("Notes") {
                ForEach(store.rootNotes) { note in
                    NoteRowView(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedRootNote = note }
                        .listRowBackground(Theme.surface)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { noteToMove = note } label: {
                                Label("Move", systemImage: "folder")
                            }
                            .tint(Color.white.opacity(0.8))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteRootNote(id: note.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
                .onMove { store.moveRootNote(from: $0, to: $1) }
            }
        }
    }

    @ViewBuilder
    private var rootFoldersSection: some View {
        if !store.rootFolders.isEmpty {
            SwiftUI.Section("Folders") {
                ForEach(store.rootFolders) { folder in
                    NavigationLink(destination: FolderDetailView(folderID: folder.id)) {
                        FolderRowView(folder: folder)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { folderToExport = folder } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(Color.white.opacity(0.8))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteRootFolder(id: folder.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .onMove { store.moveRootFolder(from: $0, to: $1) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(Theme.textSecondary)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Tap + to add a folder, note, or exercise.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
    }

    @ToolbarContentBuilder
    private var rootToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            #if os(iOS)
            EditButton().foregroundColor(.white)
            #endif
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showingImport = true } label: {
                Image(systemName: "video.badge.plus")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showingDatabaseImport = true } label: {
                Image(systemName: "square.and.arrow.down")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showingNewFolderSheet = true } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button { showingAddRootNote = true } label: {
                    Label("New Note", systemImage: "note.text.badge.plus")
                }
                Button { showingAddRootExercise = true } label: {
                    Label("New Exercise", systemImage: "figure.strengthtraining.traditional")
                }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
        }
    }

    // createRootFolder handled inline by NewFolderSheet callback

    // MARK: - V2 Page Tree

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .primaryAction) {
                #if os(iOS)
                EditButton().foregroundColor(.white)
                #endif
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingImport = true } label: {
                    Image(systemName: "video.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingDatabaseImport = true } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingCreatePage = true } label: {
                        Label("New Page", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
    }

    private var pageTreeView: some View {
        List {
            ForEach(store.rootPages) { page in
                pageRow(page)
            }
            .onMove { indices, offset in
                store.rootPages.move(fromOffsets: indices, toOffset: offset)
                store.persistRootPageOrder()
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func pageRow(_ page: ExercisePage) -> some View {
        if page.isContainer {
            NavigationLink(destination: ExercisePageDetailView(pageID: page.id)) {
                PageCardView(page: page)
            }
            .listRowBackground(Theme.surface)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { pageToMove = page } label: {
                    Label("Move", systemImage: "folder")
                }
                .tint(Color.white.opacity(0.8))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    try? store.deletePage(id: page.manifest.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        } else {
            NavigationLink(destination: ExercisePageDetailView(pageID: page.id)) {
                PageCardView(page: page)
            }
            .listRowBackground(Theme.surface)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { pageToMove = page } label: {
                    Label("Move", systemImage: "folder")
                }
                .tint(Color.white.opacity(0.8))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    try? store.deletePage(id: page.manifest.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }

    private var v2EmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(Theme.textSecondary)
            Text("No pages yet")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Tap + to create your first page.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showingCreatePage = true
            } label: {
                Text("Create First Page")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - V2 Sheets (continued in body extensions)
}

// MARK: - FolderDetailView

struct FolderDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    let folderID: UUID

    @State private var showingNewSubfolderSheet = false
    @State private var showingAddExercise       = false
    @State private var showingAddNote           = false
    @State private var selectedExercise: Exercise?
    @State private var selectedNote: DatabaseNote?
    @State private var isGalleryMode            = false
    @State private var exerciseToMove: Exercise?
    @State private var noteToMove: DatabaseNote?
    @State private var folderForExport: ExerciseFolder?

    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var folder: ExerciseFolder? { store.folder(id: folderID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let folder = folder {
                if isGalleryMode {
                    galleryContent(folder)
                } else {
                    listContent(folder)
                }
            }
        }
        .navigationTitle(folder?.name ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { folderToolbar }
        .sheet(isPresented: $showingNewSubfolderSheet) {
            NewFolderSheet { name, colorHex, workoutType in
                store.addSubfolder(name: name, toFolderID: folderID, colorHex: colorHex, workoutType: workoutType)
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(folderID: folderID).environmentObject(store)
        }
        .sheet(isPresented: $showingAddNote) {
            NoteEditorView(folderID: folderID).environmentObject(store)
        }
        .sheet(item: $selectedExercise) { exercise in
            EditExerciseView(exercise: exercise, folderID: folderID).environmentObject(store)
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView(noteID: note.id, folderID: folderID).environmentObject(store)
        }
        .sheet(item: $exerciseToMove) { exercise in
            FolderPickerSheet(currentFolderID: folderID) { destID in
                store.moveExercise(id: exercise.id, fromFolderID: folderID, toFolderID: destID)
            }
            .environmentObject(store)
        }
        .sheet(item: $noteToMove) { note in
            FolderPickerSheet(currentFolderID: folderID) { destID in
                store.moveNote(id: note.id, fromFolderID: folderID, toFolderID: destID)
            }
            .environmentObject(store)
        }
        .sheet(item: $folderForExport) { f in
            FolderExportSheet(folder: f)
        }
    }

    // MARK: List Mode

    private func listContent(_ folder: ExerciseFolder) -> some View {
        List {
            subfoldersSection(folder)
            notesSection(folder)
            exercisesSection(folder)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func subfoldersSection(_ folder: ExerciseFolder) -> some View {
        if !folder.subfolders.isEmpty {
            SwiftUI.Section("Folders") {
                ForEach(folder.subfolders) { sub in
                    NavigationLink(destination: FolderDetailView(folderID: sub.id)) {
                        FolderRowView(folder: sub)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteSubfolder(id: sub.id, fromParentID: folderID)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .onMove { store.moveSubfolder(from: $0, to: $1, inParentID: folderID) }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ folder: ExerciseFolder) -> some View {
        if !folder.notes.isEmpty {
            SwiftUI.Section("Notes") {
                ForEach(folder.notes) { note in
                    NoteRowView(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNote = note }
                        .listRowBackground(Theme.surface)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { noteToMove = note } label: {
                                Label("Move", systemImage: "folder")
                            }
                            .tint(Color.white.opacity(0.8))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteNote(id: note.id, fromFolderID: folderID)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
                .onMove { store.moveFolderNote(from: $0, to: $1, inFolderID: folderID) }
            }
        }
    }

    @ViewBuilder
    private func exercisesSection(_ folder: ExerciseFolder) -> some View {
        SwiftUI.Section("Exercises") {
            if folder.exercises.isEmpty {
                Text("No exercises — tap + to add one")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(folder.exercises) { exercise in
                    ExerciseRowView(exercise: exercise)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedExercise = exercise }
                        .listRowBackground(Theme.surface)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { exerciseToMove = exercise } label: {
                                Label("Move", systemImage: "folder")
                            }
                            .tint(Color.white.opacity(0.8))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteExercise(id: exercise.id, fromFolderID: folderID)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
                .onMove { store.moveFolderExercise(from: $0, to: $1, inFolderID: folderID) }
            }
        }
    }

    // MARK: Gallery Mode

    private func galleryContent(_ folder: ExerciseFolder) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !folder.subfolders.isEmpty {
                    galleryFoldersSection(folder.subfolders)
                }
                if !folder.notes.isEmpty {
                    galleryNotesSection(folder.notes)
                }
                galleryExercisesSection(folder.exercises)
            }
            .padding(.vertical, 16)
        }
    }

    private func galleryFoldersSection(_ subfolders: [ExerciseFolder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOLDERS")
                .font(.caption).fontWeight(.semibold).tracking(1)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 16)
            ForEach(subfolders) { sub in
                NavigationLink(destination: FolderDetailView(folderID: sub.id)) {
                    FolderRowView(folder: sub)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func galleryNotesSection(_ notes: [DatabaseNote]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTES")
                .font(.caption).fontWeight(.semibold).tracking(1)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 16)
            ForEach(notes) { note in
                NoteRowView(note: note)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNote = note }
            }
        }
    }

    private func galleryExercisesSection(_ exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXERCISES")
                .font(.caption).fontWeight(.semibold).tracking(1)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 16)
            if exercises.isEmpty {
                Text("No exercises — tap + to add one")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.top, 24)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(exercises) { exercise in
                        ExerciseGalleryCard(exercise: exercise)
                            .onTapGesture { selectedExercise = exercise }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var folderToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            #if os(iOS)
            EditButton().foregroundColor(.white)
            #endif
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGalleryMode.toggle() }
            } label: {
                Image(systemName: isGalleryMode ? "list.bullet" : "square.grid.2x2")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showingAddExercise = true } label: {
                    Label("Add Exercise", systemImage: "figure.strengthtraining.traditional")
                }
                Button { showingAddNote = true } label: {
                    Label("New Note", systemImage: "note.text.badge.plus")
                }
                Button { showingNewSubfolderSheet = true } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button {
                    if let f = folder { folderForExport = f }
                } label: {
                    Label("Export Folder…", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
        }
    }

    // createSubfolder handled inline by NewFolderSheet callback
}

// MARK: - FolderRowView

struct FolderRowView: View {
    let folder: ExerciseFolder

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: folder.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(folder.colorHex == "FFFFFF" ? .black : .white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name).font(.headline).foregroundColor(Theme.textPrimary)
                Text(subtitleText).font(.caption).foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitleText: String {
        let total = folder.totalExerciseCount
        let subs  = folder.subfolders.count
        let notes = folder.notes.count
        var parts: [String] = []
        if total > 0 { parts.append("\(total) exercise\(total == 1 ? "" : "s")") }
        if subs  > 0 { parts.append("\(subs) subfolder\(subs == 1 ? "" : "s")") }
        if notes > 0 { parts.append("\(notes) note\(notes == 1 ? "" : "s")") }
        return parts.isEmpty ? "Empty" : parts.joined(separator: " • ")
    }
}

// MARK: - ExerciseRowView

struct ExerciseRowView: View {
    let exercise: Exercise
    @State private var showPreview = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .onTapGesture {
                    if !exercise.mediaItems.isEmpty { showPreview = true }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(Theme.textPrimary)
                if !exercise.details.isEmpty {
                    Text(exercise.details)
                        .font(.caption).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Text("\(exercise.duration)s work · \(exercise.restAfter)s rest")
                    .font(.caption2).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 3)
        .sheet(isPresented: $showPreview) {
            MediaPreviewSheet(items: exercise.mediaItems)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let item = exercise.mediaItems.first {
            MediaThumbnailView(item: item, size: 44, cornerRadius: 8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface).frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                )
        }
    }
}

// MARK: - ExerciseGalleryCard

struct ExerciseGalleryCard: View {
    let exercise: Exercise
    @State private var showingVideo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaTop
            infoBottom
        }
        .background(Theme.surface)
        .cornerRadius(14)
        .clipped()
        .sheet(isPresented: $showingVideo) {
            videoPlayerCover
        }
    }

    @ViewBuilder
    private var videoPlayerCover: some View {
        if let item = exercise.mediaItems.first, item.type == .video {
            let url = PhotoManager.shared.videoURL(for: item.filename)
            GalleryVideoPlayer(url: url)
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mediaTop: some View {
        if let item = exercise.mediaItems.first {
            if item.type == .video {
                MediaThumbnailView(item: item, size: 0, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .onTapGesture { showingVideo = true }
            } else {
                MediaThumbnailView(item: item, size: 0, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
            }
        } else {
            Rectangle()
                .fill(Theme.background).frame(height: 110)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                )
        }
    }

    private var infoBottom: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary).lineLimit(1)
            Text("\(exercise.duration)s · \(exercise.restAfter)s rest")
                .font(.caption).foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }
}

// MARK: - GalleryVideoPlayer

private struct GalleryVideoPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let p = player {
                #if os(iOS)
                PlayerLayerView(player: p, gravity: .resizeAspect)
                #elseif os(macOS)
                VideoPlayer(player: p)
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ProgressView().tint(.white).scaleEffect(1.4)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - AddExerciseView

struct AddExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: DatabaseStore

    let folderID: UUID?   // nil = root level

    @State private var name          = ""
    @State private var details       = ""
    @State private var duration      = 30
    @State private var restAfter     = 10
    @State private var mediaItems: [MediaItem] = []
    #if os(iOS)
    @State private var pendingItems: [PhotosPickerItem] = []
    #endif
    @State private var showingPicker = false
    @State private var showingFilePicker = false
    @State private var isSuggestingName = false
    @State private var aiErrorMessage: String? = nil

    private let maxMedia = 10

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        addNameCard
                        addDescriptionCard
                        addTimingCard
                        addMediaCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(iOS)
        .photosPicker(
            isPresented: $showingPicker,
            selection: $pendingItems,
            maxSelectionCount: maxMedia,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pendingItems) { newItems in
            guard !newItems.isEmpty else { return }
            loadPickedItems(newItems)
        }
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .jpeg, .png, .heic],
            allowsMultipleSelection: true
        ) { result in
            handleFileImportForExercise(result, mediaItems: $mediaItems)
        }
    }

    // MARK: Cards

    private var addNameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                if mediaItems.contains(where: { $0.type == .photo }) {
                    Button { addSuggestNameWithAI() } label: {
                        HStack(spacing: 4) {
                            if isSuggestingName {
                                ProgressView().tint(.white).scaleEffect(0.75)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.semibold))
                            }
                            Text("Suggest")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(isSuggestingName ? Color.white.opacity(0.35) : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .disabled(isSuggestingName)
                }
            }
            TextField("e.g., Push-ups", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10).foregroundColor(Theme.textPrimary)
            if let err = aiErrorMessage {
                Text(err).font(.caption).foregroundColor(.red.opacity(0.85))
            }
        }
    }

    private var addDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Description").font(.headline).foregroundColor(Theme.textPrimary)
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text("How to perform this exercise…")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $details)
                    .frame(minHeight: 80).padding(10)
                    .scrollContentBackground(.hidden).foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private var addTimingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timing").font(.headline).foregroundColor(Theme.textPrimary)
            VStack(spacing: 8) {
                HStack {
                    Text("Duration").foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(duration)s").foregroundColor(Theme.textSecondary)
                    Stepper("", value: $duration, in: 5...300, step: 5).labelsHidden()
                }
                .padding(14).background(Theme.surface).cornerRadius(10)
                HStack {
                    Text("Rest After").foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(restAfter)s").foregroundColor(Theme.textSecondary)
                    Stepper("", value: $restAfter, in: 0...120, step: 5).labelsHidden()
                }
                .padding(14).background(Theme.surface).cornerRadius(10)
            }
        }
    }

    private var addMediaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos & Videos").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                if !mediaItems.isEmpty {
                    Text("\(mediaItems.count)/\(maxMedia)").font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            mediaScrollRow(items: mediaItems, onRemove: removeMedia)
            HStack(spacing: 10) {
                Button { showingPicker = true } label: {
                    Label("Photos", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(10)
                }
                .disabled(mediaItems.count >= maxMedia)
                Button { showingFilePicker = true } label: {
                    Label("Files", systemImage: "folder.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(10)
                }
                .disabled(mediaItems.count >= maxMedia)
            }
        }
    }

    private func removeMedia(at index: Int) {
        guard index < mediaItems.count else { return }
        PhotoManager.shared.deleteMedia(filename: mediaItems[index].filename)
        mediaItems.remove(at: index)
    }

    private func addSuggestNameWithAI() {
        let apiKey = UserDefaults.standard.string(forKey: "exercise_ai_api_key") ?? ""
        let model  = UserDefaults.standard.string(forKey: "exercise_ai_model")   ?? "gpt-4o"
        guard let photoItem = mediaItems.first(where: { $0.type == .photo }) else { return }
        guard let image = PhotoManager.shared.loadPhoto(filename: photoItem.filename) else {
            aiErrorMessage = "Could not load the image."
            return
        }
        isSuggestingName = true
        aiErrorMessage = nil
        Task {
            do {
                let suggested = try await ExerciseNamingService.suggestName(image: image, apiKey: apiKey, model: model)
                await MainActor.run {
                    if !suggested.isEmpty { name = suggested }
                    isSuggestingName = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    isSuggestingName = false
                }
            }
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            description: details.trimmingCharacters(in: .whitespaces),
            duration: duration,
            restAfter: restAfter,
            mediaItems: mediaItems
        )
        if let fid = folderID {
            store.addExercise(exercise, toFolderID: fid)
        } else {
            store.addRootExercise(exercise)
        }
        dismiss()
    }

    #if os(iOS)
    private func loadPickedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            for item in items {
                let isVideo = item.supportedContentTypes.contains(where: {
                    $0.conforms(to: UTType.audiovisualContent)
                })
                if isVideo {
                    if let file = try? await item.loadTransferable(type: MovieFile.self),
                       let filename = PhotoManager.shared.saveVideo(from: file.url) {
                        mediaItems.append(MediaItem(filename: filename, type: .video))
                    }
                } else {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let filename = PhotoManager.shared.savePhoto(image) {
                        mediaItems.append(MediaItem(filename: filename, type: .photo))
                    }
                }
            }
            pendingItems = []
        }
    }
    #endif
}

// MARK: - EditExerciseView

struct EditExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: DatabaseStore

    let exercise: Exercise
    let folderID: UUID?   // nil = root level

    @State private var name: String
    @State private var details: String
    @State private var duration: Int
    @State private var restAfter: Int
    @State private var mediaItems: [MediaItem]
    #if os(iOS)
    @State private var pendingItems: [PhotosPickerItem] = []
    #endif
    @State private var showingPicker        = false
    @State private var showingFilePicker    = false
    @State private var showingDeleteConfirm = false
    @State private var isSuggestingName     = false
    @State private var aiErrorMessage: String? = nil

    private let maxMedia = 10

    init(exercise: Exercise, folderID: UUID?) {
        self.exercise = exercise
        self.folderID = folderID
        _name       = State(initialValue: exercise.name)
        _details    = State(initialValue: exercise.details)
        _duration   = State(initialValue: exercise.duration)
        _restAfter  = State(initialValue: exercise.restAfter)
        _mediaItems = State(initialValue: exercise.mediaItems)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        editNameCard
                        editDescriptionCard
                        editTimingCard
                        editMediaCard
                        editDeleteCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(iOS)
        .photosPicker(
            isPresented: $showingPicker,
            selection: $pendingItems,
            maxSelectionCount: maxMedia,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pendingItems) { newItems in
            guard !newItems.isEmpty else { return }
            loadPickedItems(newItems)
        }
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .jpeg, .png, .heic],
            allowsMultipleSelection: true
        ) { result in
            handleFileImportForExercise(result, mediaItems: $mediaItems)
        }
        .confirmationDialog(
            "Delete \"\(exercise.name)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let fid = folderID {
                    store.deleteExercise(id: exercise.id, fromFolderID: fid)
                } else {
                    store.deleteRootExercise(id: exercise.id)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: Cards

    private var editNameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                if mediaItems.contains(where: { $0.type == .photo }) {
                    Button { editSuggestNameWithAI() } label: {
                        HStack(spacing: 4) {
                            if isSuggestingName {
                                ProgressView().tint(.white).scaleEffect(0.75)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.semibold))
                            }
                            Text("Suggest")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(isSuggestingName ? Color.white.opacity(0.35) : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .disabled(isSuggestingName)
                }
            }
            TextField("e.g., Push-ups", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10).foregroundColor(Theme.textPrimary)
            if let err = aiErrorMessage {
                Text(err).font(.caption).foregroundColor(.red.opacity(0.85))
            }
        }
    }

    private var editDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Description").font(.headline).foregroundColor(Theme.textPrimary)
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text("How to perform this exercise…")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $details)
                    .frame(minHeight: 80).padding(10)
                    .scrollContentBackground(.hidden).foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private var editTimingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timing").font(.headline).foregroundColor(Theme.textPrimary)
            VStack(spacing: 8) {
                HStack {
                    Text("Duration").foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(duration)s").foregroundColor(Theme.textSecondary)
                    Stepper("", value: $duration, in: 5...300, step: 5).labelsHidden()
                }
                .padding(14).background(Theme.surface).cornerRadius(10)
                HStack {
                    Text("Rest After").foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(restAfter)s").foregroundColor(Theme.textSecondary)
                    Stepper("", value: $restAfter, in: 0...120, step: 5).labelsHidden()
                }
                .padding(14).background(Theme.surface).cornerRadius(10)
            }
        }
    }

    private var editMediaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos & Videos").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                if !mediaItems.isEmpty {
                    Text("\(mediaItems.count)/\(maxMedia)").font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            mediaScrollRow(items: mediaItems, onRemove: editRemoveMedia)
            HStack(spacing: 10) {
                Button { showingPicker = true } label: {
                    Label("Photos", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(10)
                }
                .disabled(mediaItems.count >= maxMedia)
                Button { showingFilePicker = true } label: {
                    Label("Files", systemImage: "folder.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(10)
                }
                .disabled(mediaItems.count >= maxMedia)
            }
        }
    }

    private var editDeleteCard: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Text("Delete Exercise")
                .font(.headline).foregroundColor(.red)
                .frame(maxWidth: .infinity).padding(16)
                .background(Theme.surface).cornerRadius(12)
        }
    }

    private func editSuggestNameWithAI() {
        let apiKey = UserDefaults.standard.string(forKey: "exercise_ai_api_key") ?? ""
        let model  = UserDefaults.standard.string(forKey: "exercise_ai_model")   ?? "gpt-4o"
        guard let photoItem = mediaItems.first(where: { $0.type == .photo }) else { return }
        guard let image = PhotoManager.shared.loadPhoto(filename: photoItem.filename) else {
            aiErrorMessage = "Could not load the image."
            return
        }
        isSuggestingName = true
        aiErrorMessage = nil
        Task {
            do {
                let suggested = try await ExerciseNamingService.suggestName(image: image, apiKey: apiKey, model: model)
                await MainActor.run {
                    if !suggested.isEmpty { name = suggested }
                    isSuggestingName = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    isSuggestingName = false
                }
            }
        }
    }

    private func editRemoveMedia(at index: Int) {
        guard index < mediaItems.count else { return }
        PhotoManager.shared.deleteMedia(filename: mediaItems[index].filename)
        mediaItems.remove(at: index)
    }

    private func updateExercise() {
        var updated = exercise
        updated.name       = name.trimmingCharacters(in: .whitespaces)
        updated.details    = details.trimmingCharacters(in: .whitespaces)
        updated.duration   = duration
        updated.restAfter  = restAfter
        updated.mediaItems = mediaItems
        if let fid = folderID {
            store.updateExercise(updated, inFolderID: fid)
        } else {
            store.updateRootExercise(updated)
        }
        dismiss()
    }

    #if os(iOS)
    private func loadPickedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            for item in items {
                let isVideo = item.supportedContentTypes.contains(where: {
                    $0.conforms(to: UTType.audiovisualContent)
                })
                if isVideo {
                    if let file = try? await item.loadTransferable(type: MovieFile.self),
                       let filename = PhotoManager.shared.saveVideo(from: file.url) {
                        mediaItems.append(MediaItem(filename: filename, type: .video))
                    }
                } else {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let filename = PhotoManager.shared.savePhoto(image) {
                        mediaItems.append(MediaItem(filename: filename, type: .photo))
                    }
                }
            }
            pendingItems = []
        }
    }
    #endif
}

// MARK: - Shared file import handler (module-wide)

func handleFileImportForExercise(_ result: Result<[URL], Error>, mediaItems: Binding<[MediaItem]>) {
    guard case .success(let urls) = result else { return }
    for url in urls {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext)
        if isVideo {
            if let filename = PhotoManager.shared.saveVideo(from: url) {
                mediaItems.wrappedValue.append(MediaItem(filename: filename, type: .video))
            }
        } else {
            #if os(iOS)
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data),
               let filename = PhotoManager.shared.savePhoto(image) {
                mediaItems.wrappedValue.append(MediaItem(filename: filename, type: .photo))
            }
            #elseif os(macOS)
            if let data = try? Data(contentsOf: url),
               let image = NSImage(data: data),
               let filename = PhotoManager.shared.savePhoto(image) {
                mediaItems.wrappedValue.append(MediaItem(filename: filename, type: .photo))
            }
            #endif
        }
    }
}

// MARK: - Shared media scroll row helper (free function, module-wide)

@ViewBuilder
func mediaScrollRow(items: [MediaItem], onRemove: @escaping (Int) -> Void) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                ZStack(alignment: .topTrailing) {
                    MediaThumbnailView(item: item, size: 90, cornerRadius: 10)
                    Button { onRemove(index) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    .padding(4)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - NewFolderSheet

struct NewFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStore: WorkoutStore
    let onCreate: (String, String, WorkoutType?) -> Void

    @State private var name: String = ""
    @State private var colorHex: String = "FFFFFF"
    @State private var workoutType: WorkoutType? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            TextField("Folder name", text: $name)
                                .padding(14)
                                .background(Theme.surface)
                                .cornerRadius(10)
                                .foregroundColor(Theme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon Color")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            IconColorPicker(selectedHex: $colorHex)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Workout Type")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                Button {
                                    workoutType = nil
                                } label: {
                                    Text("None")
                                        .font(.subheadline.weight(workoutType == nil ? .semibold : .regular))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(workoutType == nil ? Color.white.opacity(0.2) : Theme.surface)
                                        .cornerRadius(8)
                                }
                                ForEach(WorkoutType.all(custom: workoutStore.customWorkoutTypes), id: \.id) { type in
                                    Button {
                                        workoutType = type
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: type.icon).font(.system(size: 11))
                                            Text(type.name)
                                        }
                                        .font(.subheadline.weight(workoutType == type ? .semibold : .regular))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(workoutType == type ? Color.white.opacity(0.2) : Theme.surface)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }

                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        Button {
                            guard !trimmed.isEmpty else { return }
                            onCreate(trimmed, colorHex, workoutType)
                            dismiss()
                        } label: {
                            Text("Create Folder")
                                .font(.headline)
                                .foregroundColor(trimmed.isEmpty ? Color.white.opacity(0.3) : .black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(trimmed.isEmpty ? Theme.surface : Color.white)
                                .cornerRadius(12)
                        }
                        .disabled(trimmed.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Folder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - FolderPickerSheet

struct FolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DatabaseStore
    let currentFolderID: UUID?
    let onSelect: (UUID?) -> Void

    private struct FolderItem: Identifiable {
        let id: UUID
        let folder: ExerciseFolder
        let depth: Int
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    // Root option
                    Button {
                        guard currentFolderID != nil else { return }
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tray")
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 28)
                            Text("Root").foregroundColor(Theme.textPrimary)
                            Spacer()
                            if currentFolderID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.textSecondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .disabled(currentFolderID == nil)
                    .listRowBackground(Theme.surface)

                    ForEach(flatFolderList) { item in
                        Button {
                            guard item.folder.id != currentFolderID else { return }
                            onSelect(item.folder.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                if item.depth > 0 {
                                    Spacer().frame(width: CGFloat(item.depth) * 16)
                                }
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Color(hex: item.folder.colorHex))
                                    .frame(width: 28)
                                Text(item.folder.name).foregroundColor(Theme.textPrimary)
                                Spacer()
                                if item.folder.id == currentFolderID {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.textSecondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .disabled(item.folder.id == currentFolderID)
                        .listRowBackground(Theme.surface)
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Move To")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }

    private var flatFolderList: [FolderItem] {
        buildList(from: store.rootFolders, depth: 0)
    }

    private func buildList(from folders: [ExerciseFolder], depth: Int) -> [FolderItem] {
        var result: [FolderItem] = []
        for f in folders {
            result.append(FolderItem(id: f.id, folder: f, depth: depth))
            result += buildList(from: f.subfolders, depth: depth + 1)
        }
        return result
    }
}

// MARK: - FolderExportSheet

struct FolderExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let folder: ExerciseFolder

    @State private var zipName: String
    @State private var selectedExerciseIDs: Set<UUID>
    @State private var selectedNoteIDs: Set<UUID>
    @State private var selectedSubfolderIDs: Set<UUID>
    @State private var isExporting    = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showShareSheet = false

    init(folder: ExerciseFolder) {
        self.folder = folder
        _zipName              = State(initialValue: folder.name)
        _selectedExerciseIDs  = State(initialValue: Set(folder.exercises.map(\.id)))
        _selectedNoteIDs      = State(initialValue: Set(folder.notes.map(\.id)))
        _selectedSubfolderIDs = State(initialValue: Set(folder.subfolders.map(\.id)))
    }

    private var selectedCount: Int {
        selectedExerciseIDs.count + selectedNoteIDs.count + selectedSubfolderIDs.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                exportList
            }
            .navigationTitle("Export Folder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { exportToolbar }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet, onDismiss: { dismiss() }) {
                if let url = exportURL { ShareSheet(activityItems: [url]) }
            }
            #endif
            .alert("Export Failed",
                   isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                   )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private var exportToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }.foregroundColor(.white)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button { startExport() } label: {
                if isExporting { ProgressView().tint(.white) }
                else { Text("Export").fontWeight(.semibold) }
            }
            .foregroundColor(.white)
            .disabled(isExporting || selectedCount == 0
                      || zipName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var exportList: some View {
        List {
            zipNameSection
            if !folder.exercises.isEmpty  { exercisesSection }
            if !folder.notes.isEmpty      { notesSection }
            if !folder.subfolders.isEmpty { subfoldersSection }
            selectionFooter
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }

    private var zipNameSection: some View {
        SwiftUI.Section {
            TextField("File name", text: $zipName)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .listRowBackground(Theme.surface)
        } header: {
            Text("File Name (.zip)").foregroundColor(Theme.textSecondary)
        }
    }

    private var exercisesSection: some View {
        let allIDs = Set(folder.exercises.map(\.id))
        let allOn  = !allIDs.isEmpty && allIDs.isSubset(of: selectedExerciseIDs)
        return SwiftUI.Section {
            ForEach(folder.exercises) { ex in
                ExportToggleRow(
                    title: ex.name,
                    subtitle: "\(ex.duration)s · \(ex.mediaItems.count) media",
                    icon: "figure.strengthtraining.traditional",
                    isOn: Binding(
                        get: { selectedExerciseIDs.contains(ex.id) },
                        set: { on in
                            if on { selectedExerciseIDs.insert(ex.id) }
                            else  { selectedExerciseIDs.remove(ex.id) }
                        }
                    )
                )
                .listRowBackground(Theme.surface)
            }
        } header: {
            ExportSectionHeader(title: "Exercises", allSelected: allOn) {
                if allOn { selectedExerciseIDs.subtract(allIDs) }
                else     { selectedExerciseIDs.formUnion(allIDs) }
            }
        }
    }

    private var notesSection: some View {
        let allIDs = Set(folder.notes.map(\.id))
        let allOn  = !allIDs.isEmpty && allIDs.isSubset(of: selectedNoteIDs)
        return SwiftUI.Section {
            ForEach(folder.notes) { note in
                ExportToggleRow(
                    title: note.title,
                    subtitle: note.body.isEmpty ? "No content" : String(note.body.prefix(60)),
                    icon: "note.text",
                    isOn: Binding(
                        get: { selectedNoteIDs.contains(note.id) },
                        set: { on in
                            if on { selectedNoteIDs.insert(note.id) }
                            else  { selectedNoteIDs.remove(note.id) }
                        }
                    )
                )
                .listRowBackground(Theme.surface)
            }
        } header: {
            ExportSectionHeader(title: "Notes", allSelected: allOn) {
                if allOn { selectedNoteIDs.subtract(allIDs) }
                else     { selectedNoteIDs.formUnion(allIDs) }
            }
        }
    }

    private var subfoldersSection: some View {
        let allIDs = Set(folder.subfolders.map(\.id))
        let allOn  = !allIDs.isEmpty && allIDs.isSubset(of: selectedSubfolderIDs)
        return SwiftUI.Section {
            ForEach(folder.subfolders) { sub in
                let exCount   = sub.totalExerciseCount
                let noteCount = sub.notes.count
                ExportToggleRow(
                    title: sub.name,
                    subtitle: "\(exCount) exercise\(exCount == 1 ? "" : "s") · \(noteCount) note\(noteCount == 1 ? "" : "s")",
                    icon: "folder.fill",
                    isOn: Binding(
                        get: { selectedSubfolderIDs.contains(sub.id) },
                        set: { on in
                            if on { selectedSubfolderIDs.insert(sub.id) }
                            else  { selectedSubfolderIDs.remove(sub.id) }
                        }
                    )
                )
                .listRowBackground(Theme.surface)
            }
        } header: {
            ExportSectionHeader(title: "Subfolders", allSelected: allOn) {
                if allOn { selectedSubfolderIDs.subtract(allIDs) }
                else     { selectedSubfolderIDs.formUnion(allIDs) }
            }
        }
    }

    private var selectionFooter: some View {
        let allCount = folder.exercises.count + folder.notes.count + folder.subfolders.count
        let allOn    = allCount > 0 && selectedCount == allCount
        return SwiftUI.Section {
            HStack {
                Text("\(selectedCount) item\(selectedCount == 1 ? "" : "s") selected")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                Spacer()
                Button(allOn ? "Deselect All" : "Select All") {
                    if allOn {
                        selectedExerciseIDs = []
                        selectedNoteIDs     = []
                        selectedSubfolderIDs = []
                    } else {
                        selectedExerciseIDs  = Set(folder.exercises.map(\.id))
                        selectedNoteIDs      = Set(folder.notes.map(\.id))
                        selectedSubfolderIDs = Set(folder.subfolders.map(\.id))
                    }
                }
                .font(.subheadline).foregroundColor(.white)
            }
            .listRowBackground(Theme.surface)
        }
    }

    private func startExport() {
        isExporting = true
        let name  = zipName.trimmingCharacters(in: .whitespaces)
        let exIDs = selectedExerciseIDs
        let nIDs  = selectedNoteIDs
        let sIDs  = selectedSubfolderIDs
        let f     = folder
        Task.detached {
            do {
                let url = try BackupManager.shared.exportFolder(
                    f,
                    selectedExerciseIDs: exIDs,
                    selectedNoteIDs: nIDs,
                    selectedSubfolderIDs: sIDs,
                    zipName: name
                )
                // Copy to tmp so the share sheet can access it outside the app sandbox
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tmpURL)
                try FileManager.default.copyItem(at: url, to: tmpURL)
                await MainActor.run {
                    exportURL      = tmpURL
                    showShareSheet = true
                    isExporting    = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - ExportToggleRow

private struct ExportToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isOn ? .white : Color.white.opacity(0.28))
                    .frame(width: 26)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExportSectionHeader

private struct ExportSectionHeader: View {
    let title: String
    let allSelected: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                .font(.caption).foregroundColor(.white).textCase(nil)
        }
    }
}

#Preview {
    DatabaseView()
        .environmentObject(DatabaseStore.shared)
        .preferredColorScheme(.dark)
}
