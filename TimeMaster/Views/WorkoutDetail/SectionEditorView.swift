import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
#endif
import UniformTypeIdentifiers

struct SectionEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var databaseStore: DatabaseStore
    @EnvironmentObject var workoutStore: WorkoutStore

    let section: Section?
    let onSave: (Section) -> Void

    @State private var name: String
    @State private var isTimerEnabled: Bool
    @State private var duration: Int
    @State private var sets: Int
    @State private var repCount: Int?
    @State private var restBetweenSets: Int
    @State private var prepareTime: Int
    @State private var useCustomRest: Bool
    @State private var customRestAfter: Int
    @State private var pageID: UUID?
    @State private var mode: SectionMode
    @State private var draftSlots: [SetSlot]
    @State private var mediaItems: [MediaItem]
    #if os(iOS)
    @State private var pendingItems: [PhotosPickerItem] = []
    #endif
    @State private var showingPicker = false
    @State private var showingFilePicker = false
    @State private var showingDatabasePicker = false
    @State private var isSuggestingName = false
    @State private var aiErrorMessage: String? = nil

    init(section: Section?, onSave: @escaping (Section) -> Void) {
        self.section = section
        self.onSave = onSave
        _name             = State(initialValue: section?.name ?? "")
        _isTimerEnabled   = State(initialValue: section?.isTimerEnabled ?? true)
        _duration         = State(initialValue: section?.duration ?? 30)
        _sets             = State(initialValue: section?.sets ?? 1)
        _repCount         = State(initialValue: section?.repCount)
        _restBetweenSets  = State(initialValue: section?.restBetweenSets ?? 10)
        let cra = section?.customRestAfter
        _useCustomRest    = State(initialValue: cra != nil)
        _customRestAfter  = State(initialValue: cra ?? 30)
        _pageID           = State(initialValue: section?.pageID)
        _mode             = State(initialValue: section?.mode ?? .timed)
        _draftSlots       = State(initialValue: section?.effectiveSlots ?? [])
        _prepareTime      = State(initialValue: section?.prepareTime ?? 4)
        _mediaItems       = State(initialValue: section?.mediaItems ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                    mediaSection
                    nameSection
                    fromDatabaseSection
                    durationSection
                    prepareTimeSection
                    setsSection
                    if sets > 1 { restBetweenSetsSection }
                    restAfterSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle(section == nil ? "New Section" : "Edit Section")
            #if os(iOS)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }
                    .foregroundColor(.white),
                trailing: Button("Save") { saveSection() }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? Color.white.opacity(0.3) : .white)
            )
            #elseif os(macOS)
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white)
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Save") { saveSection() }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? Color.white.opacity(0.3) : .white)
                                 }
            }
            #endif
        }
        #if os(iOS)
        .photosPicker(
            isPresented: $showingPicker,
            selection: $pendingItems,
            maxSelectionCount: 5,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pendingItems) { newItems in
            guard !newItems.isEmpty else { return }
            Task { @MainActor in
                for item in newItems {
                    let isVideo = item.supportedContentTypes.contains(where: {
                        $0.conforms(to: UTType.audiovisualContent)
                    })
                    if isVideo {
                        if let movie = try? await item.loadTransferable(type: MovieFile.self),
                           let filename = PhotoManager.shared.saveVideo(from: movie.url) {
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
        .sheet(isPresented: $showingDatabasePicker) {
            DatabasePageBrowserSheet(
                workout: Workout(name: "Section picker"),
                onAdd: { page, dur, selectedSets, reps, restAfter, restBetween, preparation in
                    let configuration = WorkoutSectionImportConfiguration(
                        duration: dur,
                        sets: selectedSets,
                        repCount: reps > 0 ? reps : nil,
                        restAfter: restAfter,
                        restBetweenSets: restBetween,
                        prepareTime: preparation
                    )
                    guard let imported = WorkoutSectionBuilder.makeSection(
                        page: page,
                        configuration: configuration
                    ) else { return }
                    applyImportedSection(imported)
                },
                onAddBundle: { sources, dur, selectedSets, reps, restAfter, restBetween, preparation in
                    let configuration = WorkoutSectionImportConfiguration(
                        duration: dur,
                        sets: selectedSets,
                        repCount: reps > 0 ? reps : nil,
                        restAfter: restAfter,
                        restBetweenSets: restBetween,
                        prepareTime: preparation
                    )
                    guard let imported = WorkoutSectionBuilder.makeBundle(
                        sources: sources,
                        configuration: configuration
                    ) else { return }
                    applyImportedSection(imported)
                }
            )
            .environmentObject(databaseStore)
            .environmentObject(workoutStore)
        }
        .onChange(of: showingDatabasePicker) { isPresented in
            if isPresented {
                databaseStore.reload()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .jpeg, .png, .heic],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Media")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if !mediaItems.isEmpty {
                    Text("\(mediaItems.count)/5")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            if !mediaItems.isEmpty {
                mediaScrollRow(items: mediaItems) { index in removeMedia(at: index) }
            }

            if mediaItems.count < 5 {
                HStack(spacing: 10) {
                    Button { showingPicker = true } label: {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text(mediaItems.isEmpty ? "Photo Library" : "Add More")
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    Button { showingFilePicker = true } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Files")
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Exercise Name")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                // Suggest button — only when at least one photo is present
                if mediaItems.contains(where: { $0.type == .photo }) {
                    Button { suggestNameWithAI() } label: {
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
            TextField("e.g., Burpees", text: $name)
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
                .foregroundColor(Theme.textPrimary)
            if let err = aiErrorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.85))
            }
        }
    }

    // MARK: - From Database

    private var fromDatabaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From Database")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Button { showingDatabasePicker = true } label: {
                HStack {
                    Image(systemName: "cylinder.split.1x2")
                    Text("Select from Database")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
                .foregroundColor(.white)
            }
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timer on/off toggle header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timer")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(isTimerEnabled ? "Countdown enabled" : "No countdown — sets only")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isTimerEnabled)
                    .labelsHidden()
                    .tint(.white)
            }

            // Duration stepper — only shown when timer is on
            if isTimerEnabled {
                HStack {
                    Text("\(duration)s")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Stepper("", value: $duration, in: 5...300, step: 5).labelsHidden()
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Prepare Time

    private var prepareTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prepare Time")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Countdown before this exercise starts.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            HStack {
                Text("\(prepareTime)s")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $prepareTime, in: 0...30, step: 1).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Sets

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sets")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack {
                Text(sets == 1 ? "1 set" : "\(sets) sets")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $sets, in: 1...20).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Rest Between Sets (only shown when sets > 1)

    private var restBetweenSetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rest Between Sets")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack {
                Text("\(restBetweenSets)s")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $restBetweenSets, in: 5...120, step: 5).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Rest After Section

    private var restAfterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Rest After Section")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    if !useCustomRest {
                        Text("Uses workout default")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                Toggle("", isOn: $useCustomRest)
                    .labelsHidden()
                    .tint(.white)
            }
            if useCustomRest {
                HStack {
                    Text("\(customRestAfter)s")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Stepper("", value: $customRestAfter, in: 0...300, step: 5).labelsHidden()
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Actions

    private func removeMedia(at index: Int) {
        guard index < mediaItems.count else { return }
        PhotoManager.shared.deleteMedia(filename: mediaItems[index].filename)
        mediaItems.remove(at: index)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let ext = url.pathExtension.lowercased()
            let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext)
            if isVideo {
                if let filename = PhotoManager.shared.saveVideo(from: url) {
                    mediaItems.append(MediaItem(filename: filename, type: .video))
                }
            } else {
                #if os(iOS)
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data),
                   let filename = PhotoManager.shared.savePhoto(image) {
                    mediaItems.append(MediaItem(filename: filename, type: .photo))
                }
                #elseif os(macOS)
                if let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data),
                   let filename = PhotoManager.shared.savePhoto(image) {
                    mediaItems.append(MediaItem(filename: filename, type: .photo))
                }
                #endif
            }
        }
    }

    private func suggestNameWithAI() {
        let apiKey = UserDefaults.standard.string(forKey: "exercise_ai_api_key") ?? ""
        let model  = UserDefaults.standard.string(forKey: "exercise_ai_model")   ?? "gpt-4o"

        // Grab the first photo item
        guard let photoItem = mediaItems.first(where: { $0.type == .photo }) else { return }
        guard let image = PhotoManager.shared.loadPhoto(filename: photoItem.filename) else {
            aiErrorMessage = "Could not load the image."
            return
        }

        isSuggestingName = true
        aiErrorMessage = nil

        Task {
            do {
                let suggested = try await ExerciseNamingService.suggestName(
                    image: image, apiKey: apiKey, model: model
                )
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

    private func applyImportedSection(_ imported: Section) {
        pageID = imported.pageID
        name = imported.name
        isTimerEnabled = imported.isTimerEnabled
        duration = imported.duration
        sets = imported.sets
        repCount = imported.repCount
        restBetweenSets = imported.restBetweenSets
        prepareTime = imported.prepareTime
        customRestAfter = imported.customRestAfter ?? 0
        useCustomRest = imported.customRestAfter != nil
        mediaItems = imported.mediaItems
        mode = imported.mode
        draftSlots = imported.slots
        showingDatabasePicker = false
    }

    private func saveSection() {
        let configuration = WorkoutSectionImportConfiguration(
            duration: duration,
            sets: sets,
            repCount: repCount,
            restAfter: customRestAfter,
            restBetweenSets: restBetweenSets,
            prepareTime: prepareTime
        )
        let page = pageID.flatMap { databaseStore.page(id: $0) }
        var slots = draftSlots

        if slots.isEmpty,
           let page,
           let imported = WorkoutSectionBuilder.makeSection(
                page: page,
                configuration: configuration
           ) {
            slots = imported.slots
        }

        if slots.count > configuration.sets {
            slots.removeLast(slots.count - configuration.sets)
        }

        let generatedSlots = page.map {
            WorkoutSectionBuilder.makeSlots(
                page: $0,
                duration: configuration.duration,
                sets: configuration.sets,
                repCount: configuration.repCount,
                restBetweenSets: configuration.restBetweenSets
            )
        } ?? []

        while slots.count < configuration.sets {
            if generatedSlots.indices.contains(slots.count) {
                slots.append(generatedSlots[slots.count])
            } else {
                slots.append(
                    SetSlot(
                        exercisePageID: pageID,
                        name: name,
                        duration: configuration.duration,
                        repCount: configuration.repCount,
                        restAfter: 0
                    )
                )
            }
        }

        if let finalSlotIndex = slots.indices.last {
            slots[finalSlotIndex].restAfter = 0
            slots[finalSlotIndex].restRow = nil
            slots[finalSlotIndex].restExercisePageID = nil
        }

        var saved = section ?? Section(name: name, duration: configuration.duration)
        saved.name = name
        saved.isTimerEnabled = isTimerEnabled
        saved.duration = configuration.duration
        saved.prepareTime = configuration.prepareTime
        saved.sets = slots.count
        saved.repCount = configuration.repCount
        saved.restBetweenSets = configuration.restBetweenSets
        saved.customRestAfter = useCustomRest ? configuration.restAfter : nil
        saved.mediaItems = mediaItems
        saved.pageID = pageID
        saved.mode = mode
        saved.slots = slots
        onSave(saved)
        dismiss()
    }
}

#Preview {
    SectionEditorView(section: nil) { _ in }
        .environmentObject(DatabaseStore.shared)
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
