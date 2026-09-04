import SwiftUI
import TimeMasterCore

#if os(iOS)

struct BatchConfirmView: View {
    @ObservedObject var vm: VideoEditorViewModel
    @ObservedObject private var databaseStore: DatabaseStore
    let onPreview: (Double) -> Void
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cardNames: [UUID: String] = [:]
    @State private var cardDetails: [UUID: String] = [:]
    @State private var cardDestinationIDs: [UUID: String] = [:]
    @State private var cardDurations: [UUID: Int] = [:]
    @State private var cardRestAfter: [UUID: Int] = [:]
    @State private var isSaving = false
    @State private var saveError: String?

    private enum DestinationKind: String {
        case existing
        case new
    }

    private struct Destination: Identifiable {
        let id: String
        let pageID: String
        let kind: DestinationKind
        let label: String
    }

    init(
        vm: VideoEditorViewModel,
        onPreview: @escaping (Double) -> Void,
        onComplete: @escaping () -> Void,
        databaseStore: DatabaseStore = .shared
    ) {
        _vm = ObservedObject(wrappedValue: vm)
        _databaseStore = ObservedObject(wrappedValue: databaseStore)
        self.onPreview = onPreview
        self.onComplete = onComplete
    }

    private var nonEmptyItems: [TrayItem] {
        vm.trayItems.filter { !$0.mediaList.isEmpty }
    }

    private var destinations: [Destination] {
        let existing = databaseStore.allPagesFlat
            .filter(\.isLeaf)
            .sorted { pageLabel($0) < pageLabel($1) }
            .map { page in
                Destination(
                    id: destinationID(for: page, kind: .existing),
                    pageID: page.manifest.id,
                    kind: .existing,
                    label: pageLabel(page)
                )
            }
        let new = databaseStore.allPagesFlat
            .filter(\.isContainer)
            .sorted { pageLabel($0) < pageLabel($1) }
            .map { page in
                Destination(
                    id: destinationID(for: page, kind: .new),
                    pageID: page.manifest.id,
                    kind: .new,
                    label: pageLabel(page)
                )
            }
        return existing + new
    }

    private var canSave: Bool {
        !isSaving &&
        !nonEmptyItems.isEmpty &&
        nonEmptyItems.allSatisfy { item in
            guard let destination = destination(for: item),
                  let page = databaseStore.allPagesFlat.first(where: { $0.manifest.id == destination.pageID }) else {
                return false
            }
            let existingMediaCount = destination.kind == .existing
                ? page.manifest.mediaFilenames.count
                : 0
            return existingMediaCount + item.mediaList.count <= 20
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if destinations.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(Theme.textSecondary)
                                Text("Create a Database Container First")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Create a container here or in the Database to save the video media.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            Button("Create Video Library", systemImage: "folder.badge.plus") {
                                createVideoLibrary()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        ForEach(nonEmptyItems) { item in
                            itemCard(item)
                        }

                        if let saveError {
                            Text(saveError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }

                    }
                    .padding(16)
                }
            }
            .navigationTitle("Save Video Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .onAppear(perform: initDefaults)
        }
    }

    private func itemCard(_ item: TrayItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            thumbnailStrip(item)

            TextField("Exercise name", text: nameBinding(item))
                .padding(12)
                .background(Theme.surface2)
                .cornerRadius(8)
                .foregroundColor(Theme.textPrimary)

            TextField("Guide or notes (optional)", text: detailsBinding(item))
                .padding(12)
                .background(Theme.surface2)
                .cornerRadius(8)
                .foregroundColor(Theme.textPrimary)

            destinationRow(item)
            durationRow(item)
            restAfterRow(item)

            if let time = item.firstClipStartTime {
                Button {
                    onPreview(time)
                } label: {
                    Label("Preview Clip", systemImage: "play.circle")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    private func destinationRow(_ item: TrayItem) -> some View {
        HStack {
            Label("Save in", systemImage: "folder")
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            if destinations.isEmpty {
                Text("No pages")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Picker("Save in", selection: destinationBinding(item)) {
                    Text("Select…").tag(String?.none)
                    let existing = destinations.filter { $0.kind == .existing }
                    if !existing.isEmpty {
                        SwiftUI.Section("Add to existing exercise") {
                            ForEach(existing) { destination in
                                Text(destination.label)
                                    .tag(Optional(destination.id))
                            }
                        }
                    }
                    let new = destinations.filter { $0.kind == .new }
                    if !new.isEmpty {
                        SwiftUI.Section("Create new exercise in") {
                            ForEach(new) { destination in
                                Text(destination.label)
                                    .tag(Optional(destination.id))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(destination(for: item) == nil ? .red : Theme.textPrimary)
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

    private func thumbnailStrip(_ item: TrayItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(item.mediaList.enumerated()), id: \.offset) { _, media in
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: media.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
                            .clipped()
                            .cornerRadius(8)

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
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveAll() }
        } label: {
            if isSaving {
                ProgressView()
                    .tint(Theme.textPrimary)
            } else {
                Text("Save All")
                    .fontWeight(.semibold)
            }
        }
        .disabled(!canSave)
    }

    @MainActor
    private func saveAll() async {
        isSaving = true
        saveError = nil

        for item in nonEmptyItems {
            guard let destination = destination(for: item),
                  let page = databaseStore.allPagesFlat.first(where: { $0.manifest.id == destination.pageID }) else {
                saveError = "Choose a valid destination for every media item."
                isSaving = false
                return
            }

            let title = (cardNames[item.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let details = (cardDetails[item.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let duration = cardDurations[item.id] ?? 30
            let restAfter = cardRestAfter[item.id] ?? 10
            let manifest = makeManifest(
                for: page,
                destination: destination,
                title: title.isEmpty ? "New Exercise" : title,
                details: details,
                duration: duration,
                restAfter: restAfter
            )

            let target: VideoEditorDatabaseImporter.Target
            switch destination.kind {
            case .existing:
                target = .attachToLeaf(
                    pageID: page.manifest.id,
                    originalManifest: page.manifest
                )
            case .new:
                target = .createLeaf(parentID: page.manifest.id)
            }

            do {
                try await VideoEditorDatabaseImporter.save(
                    item: item,
                    asset: vm.asset,
                    manifest: manifest,
                    target: target,
                    reloadDatabase: {
                        databaseStore.reloadImmediately()
                    }
                )
            } catch {
                saveError = error.localizedDescription
                isSaving = false
                return
            }
        }

        databaseStore.reloadImmediately()
        isSaving = false
        onComplete()
    }

    private func makeManifest(
        for page: ExercisePage,
        destination: Destination,
        title: String,
        details: String,
        duration: Int,
        restAfter: Int
    ) -> ExercisePageManifest {
        switch destination.kind {
        case .existing:
            var manifest = page.manifest
            manifest.title = title
            manifest.pageKind = .leaf
            manifest.markdownBody = details
            manifest.duration = duration
            manifest.restAfter = restAfter
            manifest.sets = manifest.sets ?? 1
            manifest.prepareTime = manifest.prepareTime ?? 4
            manifest.restBetweenSets = manifest.restBetweenSets ?? 0
            manifest.updatedAt = Date()
            return manifest
        case .new:
            return ExercisePageManifest(
                title: title,
                pageKind: .leaf,
                markdownBody: details,
                duration: duration,
                restAfter: restAfter,
                prepareTime: 4,
                sets: 1,
                restBetweenSets: 0,
                parentID: page.manifest.id
            )
        }
    }

    private func initDefaults() {
        let firstContainer = destinations.first(where: { $0.kind == .new })
        let firstExisting = destinations.first(where: { $0.kind == .existing })
        let fallback = firstContainer ?? firstExisting

        for item in nonEmptyItems {
            if cardNames[item.id] == nil {
                cardNames[item.id] = item.name
            }
            if cardDetails[item.id] == nil {
                cardDetails[item.id] = item.details
            }
            if cardDestinationIDs[item.id] == nil {
                cardDestinationIDs[item.id] = fallback?.id
            }
            if cardDurations[item.id] == nil {
                cardDurations[item.id] = 30
            }
            if cardRestAfter[item.id] == nil {
                cardRestAfter[item.id] = 10
            }
        }
    }
    private func createVideoLibrary() {
        let manifest = ExercisePageManifest(
            title: "Video Library",
            pageKind: .container
        )
        do {
            try databaseStore.createPage(manifest: manifest, parentID: nil)
            databaseStore.reloadImmediately()
            let destinationID = destinationID(for: manifest.id, kind: .new)
            for item in nonEmptyItems {
                cardDestinationIDs[item.id] = destinationID
            }
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func nameBinding(_ item: TrayItem) -> Binding<String> {
        Binding(
            get: { cardNames[item.id] ?? "" },
            set: { cardNames[item.id] = $0 }
        )
    }

    private func detailsBinding(_ item: TrayItem) -> Binding<String> {
        Binding(
            get: { cardDetails[item.id] ?? "" },
            set: { cardDetails[item.id] = $0 }
        )
    }

    private func destinationBinding(_ item: TrayItem) -> Binding<String?> {
        Binding(
            get: { cardDestinationIDs[item.id] },
            set: { cardDestinationIDs[item.id] = $0 }
        )
    }

    private func durationBinding(_ item: TrayItem) -> Binding<Int> {
        Binding(
            get: { cardDurations[item.id] ?? 30 },
            set: { cardDurations[item.id] = $0 }
        )
    }

    private func restAfterBinding(_ item: TrayItem) -> Binding<Int> {
        Binding(
            get: { cardRestAfter[item.id] ?? 10 },
            set: { cardRestAfter[item.id] = $0 }
        )
    }

    private func destination(for item: TrayItem) -> Destination? {
        guard let destinationID = cardDestinationIDs[item.id] else { return nil }
        return destinations.first { $0.id == destinationID }
    }

    private func destinationID(for page: ExercisePage, kind: DestinationKind) -> String {
        "\(kind.rawValue):\(page.manifest.id)"
    }
    private func destinationID(for pageID: String, kind: DestinationKind) -> String {
        "\(kind.rawValue):\(pageID)"
    }

    private func pageLabel(_ page: ExercisePage) -> String {
        let path = page.path
            .split(separator: "/")
            .map(String.init)
            .joined(separator: " › ")
        return path.isEmpty ? page.title : path
    }
}

#else

struct BatchConfirmView: View {
    @ObservedObject var vm: VideoEditorViewModel
    let onPreview: (Double) -> Void
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cardNames: [UUID: String] = [:]
    @State private var cardDetails: [UUID: String] = [:]
    @State private var cardFolderIDs: [UUID: UUID] = [:]
    @State private var cardDurations: [UUID: Int] = [:]
    @State private var cardRestAfter: [UUID: Int] = [:]
    @State private var isSaving = false
    @State private var saveError: String?

    private var nonEmptyItems: [TrayItem] {
        vm.trayItems.filter { !$0.mediaList.isEmpty }
    }

    private var flatFolders: [(name: String, id: UUID)] {
        flattenFolders(DatabaseStore.shared.rootFolders, prefix: "")
    }

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
                        if let saveError {
                            Text(saveError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Review & Save")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .onAppear { initDefaults() }
        }
    }

    private func itemCard(_ item: TrayItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            thumbnailStrip(item)
            TextField("Exercise name", text: nameBinding(item))
                .padding(12)
                .background(Theme.surface2)
                .cornerRadius(8)
                .foregroundColor(Theme.textPrimary)
            TextField("Description (optional)", text: detailsBinding(item))
                .padding(12)
                .background(Theme.surface2)
                .cornerRadius(8)
                .foregroundColor(Theme.textPrimary)
            folderRow(item)
            durationRow(item)
            restAfterRow(item)
            if let t = item.firstClipStartTime {
                Button { onPreview(t) } label: {
                    Label("Preview Clip", systemImage: "play.circle")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    private func folderRow(_ item: TrayItem) -> some View {
        HStack {
            Text("Folder")
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            if flatFolders.isEmpty {
                Text("Create a folder first")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Picker("Folder", selection: folderIDBinding(item)) {
                    Text("Select…").tag(UUID?.none)
                    ForEach(flatFolders, id: \.id) { folder in
                        Text(folder.name).tag(folder.id as UUID?)
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

    private func thumbnailStrip(_ item: TrayItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(item.mediaList.enumerated()), id: \.offset) { _, media in
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: media.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipped()
                            .cornerRadius(8)
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
            }
        }
    }

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

            let name = (cardNames[item.id] ?? "").trimmingCharacters(in: .whitespaces)
            let details = (cardDetails[item.id] ?? "").trimmingCharacters(in: .whitespaces)
            let exercise = Exercise(
                name: name.isEmpty ? "New Exercise" : name,
                description: details,
                duration: cardDurations[item.id] ?? 30,
                restAfter: cardRestAfter[item.id] ?? 10,
                mediaItems: saved
            )
            DatabaseStore.shared.addExercise(exercise, toFolderID: folderID)
        }

        isSaving = false
        onComplete()
    }

    private func initDefaults() {
        let defaultFolderID = flatFolders.first?.id
        for item in vm.trayItems {
            if cardNames[item.id] == nil { cardNames[item.id] = item.name }
            if cardDetails[item.id] == nil { cardDetails[item.id] = item.details }
            if cardFolderIDs[item.id] == nil { cardFolderIDs[item.id] = defaultFolderID }
            if cardDurations[item.id] == nil { cardDurations[item.id] = 30 }
            if cardRestAfter[item.id] == nil { cardRestAfter[item.id] = 10 }
        }
    }

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

    private func flattenFolders(
        _ folders: [ExerciseFolder],
        prefix: String
    ) -> [(name: String, id: UUID)] {
        var result: [(name: String, id: UUID)] = []
        for folder in folders {
            let fullName = prefix.isEmpty ? folder.name : "\(prefix) › \(folder.name)"
            result.append((name: fullName, id: folder.id))
            result.append(contentsOf: flattenFolders(folder.subfolders, prefix: fullName))
        }
        return result
    }
}

#endif
