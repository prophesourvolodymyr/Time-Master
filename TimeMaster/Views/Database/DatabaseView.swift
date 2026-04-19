import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
                        Image(systemName: item.type == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: size * 0.3))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    )
            }
            if item.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: size * 0.32))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .frame(width: size, height: size)
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        let item = item
        Task.detached(priority: .userInitiated) {
            let img = PhotoManager.shared.thumbnail(for: item)
            await MainActor.run { thumbnail = img }
        }
    }
}

// MARK: - DatabaseView (root)

struct DatabaseView: View {
    @EnvironmentObject var store: DatabaseStore
    @State private var showingAddFolder = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                rootList
            }
            .navigationTitle("Exercise Database")
            .toolbar { rootToolbar }
            .alert("New Folder", isPresented: $showingAddFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") { createRootFolder() }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
        }
    }

    private var rootList: some View {
        List {
            if store.rootFolders.isEmpty {
                emptyState
            } else {
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(Theme.primary)
            Text("No Folders Yet")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Tap + to create your first folder.")
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
            Button { showingAddFolder = true } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
    }

    private func createRootFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { store.addRootFolder(name: trimmed) }
        newFolderName = ""
    }
}

// MARK: - FolderDetailView

struct FolderDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    let folderID: UUID

    @State private var showingAddSubfolder  = false
    @State private var newSubfolderName     = ""
    @State private var showingAddExercise   = false
    @State private var selectedExercise: Exercise?
    @State private var isGalleryMode        = false

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
        .alert("New Subfolder", isPresented: $showingAddSubfolder) {
            TextField("Subfolder name", text: $newSubfolderName)
            Button("Create") { createSubfolder() }
            Button("Cancel", role: .cancel) { newSubfolderName = "" }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(folderID: folderID).environmentObject(store)
        }
        .sheet(item: $selectedExercise) { exercise in
            EditExerciseView(exercise: exercise, folderID: folderID).environmentObject(store)
        }
    }

    // MARK: List Mode

    private func listContent(_ folder: ExerciseFolder) -> some View {
        List {
            subfoldersSection(folder)
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
                Button { showingAddSubfolder = true } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
        }
    }

    private func createSubfolder() {
        let trimmed = newSubfolderName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { store.addSubfolder(name: trimmed, toFolderID: folderID) }
        newSubfolderName = ""
    }
}

// MARK: - FolderRowView

struct FolderRowView: View {
    let folder: ExerciseFolder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3).foregroundColor(Theme.primary).frame(width: 32)
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
        var parts: [String] = []
        if total > 0 { parts.append("\(total) exercise\(total == 1 ? "" : "s")") }
        if subs  > 0 { parts.append("\(subs) subfolder\(subs == 1 ? "" : "s")") }
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
                    .font(.caption2).foregroundColor(Theme.primary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaTop
            infoBottom
        }
        .background(Theme.surface)
        .cornerRadius(14)
        .clipped()
    }

    @ViewBuilder
    private var mediaTop: some View {
        if let item = exercise.mediaItems.first {
            MediaThumbnailView(item: item, size: 0, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipped()
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
                .font(.caption).foregroundColor(Theme.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }
}

// MARK: - AddExerciseView

struct AddExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: DatabaseStore

    let folderID: UUID

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
        store.addExercise(exercise, toFolderID: folderID)
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
    let folderID: UUID

    @State private var name: String
    @State private var details: String
    @State private var duration: Int
    @State private var restAfter: Int
    @State private var mediaItems: [MediaItem]
    @State private var pendingItems: [PhotosPickerItem] = []
    @State private var showingPicker        = false
    @State private var showingDeleteConfirm = false

    private let maxMedia = 10

    init(exercise: Exercise, folderID: UUID) {
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
                store.deleteExercise(id: exercise.id, fromFolderID: folderID)
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
        store.updateExercise(updated, inFolderID: folderID)
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
            // "Add" button is shown by callers via the picker binding
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

#Preview {
    DatabaseView()
        .environmentObject(DatabaseStore.shared)
        .preferredColorScheme(.dark)
}
