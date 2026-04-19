import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

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

    @State private var thumbnail: UIImage?

    var body: some View {
        if size > 0 {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
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
    @State private var showingAddRootNote        = false
    @State private var showingAddRootExercise    = false
    @State private var selectedRootNote: DatabaseNote?
    @State private var selectedRootExercise: Exercise?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                rootList
            }
            .navigationTitle("Exercise Database")
            .toolbar { rootToolbar }
            .sheet(isPresented: $showingNewFolderSheet) {
                NewFolderSheet { name, colorHex in
                    store.addRootFolder(name: name, colorHex: colorHex)
                }
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var rootExercisesSection: some View {
        if !store.rootExercises.isEmpty {
            SwiftUI.Section("Exercises") {
                ForEach(store.rootExercises) { exercise in
                    ExerciseRowView(exercise: exercise)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedRootExercise = exercise }
                        .listRowBackground(Theme.surface)
                }
                .onDelete { indexSet in
                    for i in indexSet { store.deleteRootExercise(id: store.rootExercises[i].id) }
                }
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
                }
                .onDelete { indexSet in
                    for i in indexSet { store.deleteRootNote(id: store.rootNotes[i].id) }
                }
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
                }
                .onDelete { indexSet in
                    for i in indexSet { store.deleteRootFolder(id: store.rootFolders[i].id) }
                }
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
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showingImport = true } label: {
                Image(systemName: "video.badge.plus")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { folderToolbar }
        .sheet(isPresented: $showingNewSubfolderSheet) {
            NewFolderSheet { name, colorHex in
                store.addSubfolder(name: name, toFolderID: folderID, colorHex: colorHex)
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
    }

    // MARK: List Mode

    private func listContent(_ folder: ExerciseFolder) -> some View {
        List {
            subfoldersSection(folder)
            notesSection(folder)
            exercisesSection(folder)
        }
        .listStyle(.insetGrouped)
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
                }
                .onDelete { indexSet in
                    let subs = folder.subfolders
                    for i in indexSet where i < subs.count {
                        store.deleteSubfolder(id: subs[i].id, fromParentID: folderID)
                    }
                }
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
                }
                .onDelete { indexSet in
                    let notes = folder.notes
                    for i in indexSet where i < notes.count {
                        store.deleteNote(id: notes[i].id, fromFolderID: folderID)
                    }
                }
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
                }
                .onDelete { indexSet in
                    let exs = folder.exercises
                    for i in indexSet where i < exs.count {
                        store.deleteExercise(id: exs[i].id, fromFolderID: folderID)
                    }
                }
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
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGalleryMode.toggle() }
            } label: {
                Image(systemName: isGalleryMode ? "list.bullet" : "square.grid.2x2")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showingAddExercise = true } label: {
                    Label("Add Exercise", systemImage: "figure.strengthtraining.traditional")
                }
                Button { showingAddNote = true } label: {
                    Label("New Note", systemImage: "note.text.badge.plus")
                }
                Button { showingNewSubfolderSheet = true } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }            } label: {
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

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
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
        .fullScreenCover(isPresented: $showingVideo) {
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
                PlayerLayerView(player: p, gravity: .resizeAspect)
                    .ignoresSafeArea()
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
    @State private var pendingItems: [PhotosPickerItem] = []
    @State private var showingPicker = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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
    }

    // MARK: Cards

    private var addNameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("e.g., Push-ups", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10).foregroundColor(Theme.textPrimary)
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
            Button { showingPicker = true } label: {
                Label("Add Media", systemImage: "plus.circle")
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

    private func removeMedia(at index: Int) {
        guard index < mediaItems.count else { return }
        PhotoManager.shared.deleteMedia(filename: mediaItems[index].filename)
        mediaItems.remove(at: index)
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
    @State private var pendingItems: [PhotosPickerItem] = []
    @State private var showingPicker        = false
    @State private var showingDeleteConfirm = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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
            Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("e.g., Push-ups", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10).foregroundColor(Theme.textPrimary)
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
            Button { showingPicker = true } label: {
                Label("Add Media", systemImage: "plus.circle")
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
    let onCreate: (String, String) -> Void  // (name, colorHex)

    @State private var name: String = ""
    @State private var colorHex: String = "FFFFFF"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
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

                    Spacer()

                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    Button {
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, colorHex)
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
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    DatabaseView()
        .environmentObject(DatabaseStore.shared)
        .preferredColorScheme(.dark)
}
