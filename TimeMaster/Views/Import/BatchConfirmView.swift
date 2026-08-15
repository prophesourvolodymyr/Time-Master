import SwiftUI

struct BatchConfirmView: View {
    @ObservedObject var vm: VideoEditorViewModel
    let onPreview: (Double) -> Void
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cardNames:     [UUID: String] = [:]
    @State private var cardDetails:   [UUID: String] = [:]
    @State private var cardFolderIDs: [UUID: UUID]   = [:]
    @State private var cardDurations: [UUID: Int]    = [:]
    @State private var cardRestAfter: [UUID: Int]    = [:]
    @State private var isSaving = false
    @State private var saveError: String?

    private var nonEmptyItems: [TrayItem] {
        vm.trayItems.filter { !$0.mediaList.isEmpty }
    }

    private var flatFolders: [(name: String, id: UUID)] {
        flattenFolders(DatabaseStore.shared.rootFolders, prefix: "")
    }

    /// Save is allowed only when every item has a folder selected.
    private var canSave: Bool {
        !isSaving && !nonEmptyItems.isEmpty &&
        nonEmptyItems.allSatisfy { cardFolderIDs[$0.id] != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(nonEmptyItems) { item in
                            itemCard(item)
                        }
                        if let err = saveError {
                            Text(err)
                                .font(.caption).foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Review & Save")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Back") { dismiss() }
                                 }
                AppToolbar.item(placement: .confirmationAction) { saveButton
                                 }
            }
            .onAppear { initDefaults() }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await saveAll() }
        } label: {
            if isSaving {
                ProgressView().tint(Theme.textPrimary)
            } else {
                Text("Save All").fontWeight(.semibold)
            }
        }
        .disabled(!canSave)
    }

    // MARK: - Item Card

    private func itemCard(_ item: TrayItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            thumbnailStrip(item)

            TextField("Exercise name", text: nameBinding(item))
                .padding(12).background(Theme.surface2).cornerRadius(8)
                .foregroundColor(Theme.textPrimary)

            TextField("Description (optional)", text: detailsBinding(item))
                .padding(12).background(Theme.surface2).cornerRadius(8)
                .foregroundColor(Theme.textPrimary)

            folderRow(item)
            durationRow(item)
            restAfterRow(item)

            if let t = item.firstClipStartTime {
                Button {
                    onPreview(t)
                } label: {
                    Label("Preview Clip", systemImage: "play.circle")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - Per-Item Control Rows

    private func folderRow(_ item: TrayItem) -> some View {
        HStack {
            Text("Folder")
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            if flatFolders.isEmpty {
                Text("Create a folder first")
                    .font(.caption).foregroundColor(.red)
            } else {
                Picker("Folder", selection: folderIDBinding(item)) {
                    Text("Select…").tag(UUID?.none)
                    ForEach(flatFolders, id: \.id) { f in
                        Text(f.name).tag(f.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .tint(cardFolderIDs[item.id] == nil ? .red : Theme.textPrimary)
            }
        }
        .padding(12)
        .background(Theme.surface2)
        .cornerRadius(8)
    }

    private func durationRow(_ item: TrayItem) -> some View {
        HStack {
            Text("Duration")
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text("\(cardDurations[item.id] ?? 30)s")
                .foregroundColor(Theme.textSecondary)
            Stepper("", value: durationBinding(item), in: 5...300, step: 5)
                .labelsHidden()
        }
        .padding(12)
        .background(Theme.surface2)
        .cornerRadius(8)
    }

    private func restAfterRow(_ item: TrayItem) -> some View {
        HStack {
            Text("Rest After")
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text("\(cardRestAfter[item.id] ?? 10)s")
                .foregroundColor(Theme.textSecondary)
            Stepper("", value: restAfterBinding(item), in: 0...120, step: 5)
                .labelsHidden()
        }
        .padding(12)
        .background(Theme.surface2)
        .cornerRadius(8)
    }

    // MARK: - Thumbnail Strip

    private func thumbnailStrip(_ item: TrayItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(item.mediaList.enumerated()), id: \.offset) { _, media in
                    mediaThumb(media)
                }
            }
        }
    }

    @ViewBuilder
    private func mediaThumb(_ media: TrayMedia) -> some View {
        ZStack(alignment: .bottomTrailing) {
            #if os(iOS)
            Image(uiImage: media.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(8)
            #elseif os(macOS)
            Image(nsImage: media.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(8)
            #endif

            if media.isClip {
                Image(systemName: "film")
                    .font(.caption2)
                    .padding(3)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(4)
                    .foregroundColor(.white)
                    .padding(4)
            }
        }
    }

    // MARK: - Save

    private func saveAll() async {
        isSaving = true
        saveError = nil

        for item in nonEmptyItems {
            guard let folderID = cardFolderIDs[item.id] else { continue }
            var saved: [MediaItem] = []

            for media in item.mediaList {
                switch media {
                case .screenshot(let image):
                    if let fn = PhotoManager.shared.savePhoto(image) {
                        saved.append(MediaItem(filename: fn, type: .photo))
                    }
                case .clip(let start, let end, _):
                    if let exportURL = await VideoTrimService.export(asset: vm.asset, from: start, to: end),
                       let fn = PhotoManager.shared.saveVideo(from: exportURL) {
                        saved.append(MediaItem(filename: fn, type: .video))
                    }
                }
            }

            let name     = (cardNames[item.id]   ?? "").trimmingCharacters(in: .whitespaces)
            let details  = (cardDetails[item.id] ?? "").trimmingCharacters(in: .whitespaces)
            let duration  = cardDurations[item.id] ?? 30
            let restAfter = cardRestAfter[item.id] ?? 10
            let exercise = Exercise(
                name: name.isEmpty ? "New Exercise" : name,
                description: details,
                duration: duration,
                restAfter: restAfter,
                mediaItems: saved
            )
            DatabaseStore.shared.addExercise(exercise, toFolderID: folderID)
        }

        isSaving = false
        onComplete()
    }

    // MARK: - Init Defaults

    private func initDefaults() {
        let defaultFolderID = flatFolders.first?.id
        for item in vm.trayItems {
            if cardNames[item.id]     == nil { cardNames[item.id]     = item.name }
            if cardDetails[item.id]   == nil { cardDetails[item.id]   = item.details }
            if cardFolderIDs[item.id] == nil { cardFolderIDs[item.id] = defaultFolderID }
            if cardDurations[item.id] == nil { cardDurations[item.id] = 30 }
            if cardRestAfter[item.id] == nil { cardRestAfter[item.id] = 10 }
        }
    }

    // MARK: - Bindings

    private func nameBinding(_ item: TrayItem) -> Binding<String> {
        Binding(get: { cardNames[item.id] ?? "" }, set: { cardNames[item.id] = $0 })
    }

    private func detailsBinding(_ item: TrayItem) -> Binding<String> {
        Binding(get: { cardDetails[item.id] ?? "" }, set: { cardDetails[item.id] = $0 })
    }

    private func folderIDBinding(_ item: TrayItem) -> Binding<UUID?> {
        Binding(get: { cardFolderIDs[item.id] }, set: { cardFolderIDs[item.id] = $0 })
    }

    private func durationBinding(_ item: TrayItem) -> Binding<Int> {
        Binding(get: { cardDurations[item.id] ?? 30 }, set: { cardDurations[item.id] = $0 })
    }

    private func restAfterBinding(_ item: TrayItem) -> Binding<Int> {
        Binding(get: { cardRestAfter[item.id] ?? 10 }, set: { cardRestAfter[item.id] = $0 })
    }

    // MARK: - Helpers

    private func flattenFolders(_ folders: [ExerciseFolder], prefix: String) -> [(name: String, id: UUID)] {
        var result: [(name: String, id: UUID)] = []
        for f in folders {
            let fullName = prefix.isEmpty ? f.name : "\(prefix) › \(f.name)"
            result.append((name: fullName, id: f.id))
            result.append(contentsOf: flattenFolders(f.subfolders, prefix: fullName))
        }
        return result
    }
}
