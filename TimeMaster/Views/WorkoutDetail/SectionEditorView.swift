import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct SectionEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var databaseStore: DatabaseStore

    let section: Section?
    let onSave: (Section) -> Void

    @State private var name: String
    @State private var duration: Int
    @State private var sets: Int
    @State private var restBetweenSets: Int
    @State private var useCustomRest: Bool
    @State private var customRestAfter: Int
    @State private var mediaItems: [MediaItem]
    @State private var pendingItems: [PhotosPickerItem] = []
    @State private var showingPicker = false
    @State private var showingDatabasePicker = false

    init(section: Section?, onSave: @escaping (Section) -> Void) {
        self.section = section
        self.onSave = onSave
        _name             = State(initialValue: section?.name ?? "")
        _duration         = State(initialValue: section?.duration ?? 30)
        _sets             = State(initialValue: section?.sets ?? 1)
        _restBetweenSets  = State(initialValue: section?.restBetweenSets ?? 10)
        let cra = section?.customRestAfter
        _useCustomRest    = State(initialValue: cra != nil)
        _customRestAfter  = State(initialValue: cra ?? 30)
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
                        setsSection
                        if sets > 1 { restBetweenSetsSection }
                        restAfterSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle(section == nil ? "New Section" : "Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }
                    .foregroundColor(.white),
                trailing: Button("Save") { saveSection() }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? Color.white.opacity(0.3) : .white)
            )
        }
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
        .sheet(isPresented: $showingDatabasePicker) {
            DatabaseSectionPickerView { selected in
                name             = selected.name
                duration         = selected.duration
                sets             = selected.sets
                restBetweenSets  = selected.restBetweenSets
                mediaItems       = selected.mediaItems
                if let cra = selected.customRestAfter {
                    useCustomRest   = true
                    customRestAfter = cra
                } else {
                    useCustomRest = false
                }
            }
            .environmentObject(DatabaseStore.shared)
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
                Button { showingPicker = true } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(mediaItems.isEmpty ? "Add Photo / Video" : "Add More")
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

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise Name")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            TextField("e.g., Burpees", text: $name)
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
                .foregroundColor(Theme.textPrimary)
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
            Text("Duration")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
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

    private func saveSection() {
        var saved = section ?? Section(name: name, duration: duration)
        saved.name            = name
        saved.duration        = duration
        saved.sets            = sets
        saved.restBetweenSets = restBetweenSets
        saved.customRestAfter = useCustomRest ? customRestAfter : nil
        saved.mediaItems      = mediaItems
        onSave(saved)
        dismiss()
    }
}

#Preview {
    SectionEditorView(section: nil) { _ in }
        .environmentObject(DatabaseStore.shared)
        .preferredColorScheme(.dark)
}
