#if os(macOS)
import AVFoundation
import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

struct MacVideoSavePopover: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    let draft: MacVideoDraft
    let asset: AVURLAsset
    let onDraftRenamed: (String) -> Void
    let onSaved: (String) -> Void

    private enum Step {
        case target
        case form
    }

    private struct PendingMedia: Identifiable {
        let id = UUID()
        let url: URL
        let displayName: String
    }

    @State private var step: Step = .target
    @State private var selectedTargetID: String?
    @State private var title: String
    @State private var markdownBody = ""
    @State private var duration = 30
    @State private var prepareTime = 4
    @State private var restAfter = 0
    @State private var sets = 1
    @State private var restBetweenSets = 0
    @State private var dropSetTemplates: [PageDropSetTemplate] = []
    @State private var linkURLsText = ""
    @State private var pendingAdditionalMedia: [PendingMedia] = []
    @State private var showDropSetPicker = false
    @State private var showMediaPicker = false
    @State private var isSaving = false
    @State private var saveChoice: String? = nil // "existing" or "new"
    @State private var saveErrorMessage: String?

    init(
        draft: MacVideoDraft,
        asset: AVURLAsset,
        onDraftRenamed: @escaping (String) -> Void,
        onSaved: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.asset = asset
        self.onDraftRenamed = onDraftRenamed
        self.onSaved = onSaved
        _title = State(initialValue: draft.title)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if step == .target {
                    targetPicker
                } else {
                    form
                }
            }
            .navigationTitle(step == .target ? "Save Media" : "Exercise Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .target ? "Cancel" : "Back") {
                        if step == .target {
                            if saveChoice != nil {
                                saveChoice = nil
                                selectedTargetID = nil
                            } else {
                                dismiss()
                            }
                        } else {
                            step = .target
                            saveErrorMessage = nil
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showMediaPicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                urls.forEach(stageAdditionalMedia)
            }
            .sheet(isPresented: $showDropSetPicker) {
                DatabasePageBrowserSheet(
                    workout: Workout(name: "Drop Set Templates"),
                    onAdd: { page, _, _, _, _, _, _ in
                        dropSetTemplates.append(
                            PageDropSetTemplate(
                                setIndex: max(0, sets - 1),
                                exerciseID: page.manifest.id,
                                name: page.manifest.title,
                                duration: page.manifest.duration ?? 30,
                                restAfter: page.manifest.restAfter ?? 0
                            )
                        )
                        showDropSetPicker = false
                    },
                    onAddBundle: { sources, _, _, _, _, _, _ in
                        for source in sources {
                            guard case .page(let page) = source else { continue }
                            dropSetTemplates.append(
                                PageDropSetTemplate(
                                    setIndex: max(0, sets - 1),
                                    exerciseID: page.manifest.id,
                                    name: page.manifest.title,
                                    duration: page.manifest.duration ?? 30,
                                    restAfter: page.manifest.restAfter ?? 0
                                )
                            )
                        }
                        showDropSetPicker = false
                    }
                )
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
            }
            .onDisappear(perform: cleanupPendingMedia)
        }
        .frame(minWidth: 700, minHeight: 760)
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if saveChoice == nil {
                Text("Save to?")
                    .font(.headline)
                Button("Existing page") {
                    saveChoice = "existing"
                    saveErrorMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("New page") {
                    saveChoice = "new"
                    saveErrorMessage = nil
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredTargets, id: \.manifest.id) { page in
                            targetRow(page)
                        }
                    }
                }
                .frame(maxHeight: 280)
                .background(Theme.surface.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if saveChoice == "new", rootContainers.isEmpty {
                    Button("Create Video Library", systemImage: "folder.badge.plus") {
                        createVideoLibrary()
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("Back") {
                        saveChoice = nil
                        selectedTargetID = nil
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Continue") { continueToForm() }
                        .buttonStyle(.borderedProminent)
                        .disabled(targetPage == nil || isSaving)
                }
            }

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
    }

    private func targetRow(_ page: ExercisePage) -> some View {
        let isSelected = selectedTargetID == page.manifest.id
        let pathLabel = page.path
            .split(separator: "/")
            .map(String.init)
            .joined(separator: " › ")

        return Button {
            selectedTargetID = page.manifest.id
            saveErrorMessage = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: page.isContainer ? "folder.fill" : "figure.run")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                        .lineLimit(1)
                    Text(pathLabel.isEmpty ? page.title : pathLabel)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.75) : Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(page.isContainer ? "New child" : "Attach")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Theme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 20) {
                titleCard
                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                targetSummaryCard
                selectedMediaCard
                additionalMediaCard
                timingCard
                dropSetTemplatesCard
                markdownCard
                linksCard
                saveButton
            }
            .padding(18)
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            TextField("Page title", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var targetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Destination")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                Image(systemName: targetPage?.isContainer == true ? "folder.fill" : "figure.run")
                    .foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(targetPage?.title ?? "No destination")
                        .foregroundStyle(Theme.textPrimary)
                    Text(targetLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Change") {
                    step = .target
                    saveErrorMessage = nil
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }


    private var selectedMediaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Media")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 14) {
                Image(nsImage: draft.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 135)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 5) {
                    Label(draft.title, systemImage: draft.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(draft.rangeLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("First attachment.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var additionalMediaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Additional Media")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(existingMediaCount + 1 + pendingAdditionalMedia.count)/20")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if pendingAdditionalMedia.isEmpty {
                Text("Optional images or movies copied into this page with the selected media.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 145), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(pendingAdditionalMedia) { media in
                        pendingMediaCard(media)
                    }
                }
            }

            if existingMediaCount + 1 + pendingAdditionalMedia.count < 20 {
                Button("Add Media", systemImage: "plus.rectangle.on.rectangle") {
                    showMediaPicker = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func pendingMediaCard(_ media: PendingMedia) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(contentsOf: media.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surface)
                        .overlay {
                            Image(systemName: "film")
                                .font(.title2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                }
            }
            .frame(height: 86)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                removePendingMedia(media)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .bottomLeading) {
            Text(media.displayName)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.55))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Config")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            VStack(spacing: 8) {
                stepperRow(label: "Duration", value: $duration, range: 5...600, step: 5, unit: "s")
                stepperRow(label: "Prepare Time", value: $prepareTime, range: 0...30, step: 1, unit: "s")
                stepperRow(label: "Rest After", value: $restAfter, range: 0...120, step: 5, unit: "s")
                stepperRow(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                stepperRow(label: "Rest Between Sets", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
            }
        }
    }

    private func stepperRow(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(value.wrappedValue)\(unit)")
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 40, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dropSetTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Drop Sets")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showDropSetPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("Add drop set exercise")
            }

            if dropSetTemplates.isEmpty {
                Text("Add a drop-set exercise from the database, then choose the set it follows.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach($dropSetTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.right")
                                .foregroundStyle(Theme.textSecondary)
                            Text(template.name)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                dropSetTemplates.removeAll { $0.id == template.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Text("After set")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Stepper(
                                "\(template.setIndex + 1)",
                                value: $template.setIndex,
                                in: 0...max(0, sets - 1)
                            )
                            .labelsHidden()
                            Text("\(template.setIndex + 1)")
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                                .frame(minWidth: 24, alignment: .trailing)
                        }

                        Text("Duration \(template.duration)s · Rest \(template.restAfter)s")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var markdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Guide (Markdown)")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("CommonMark")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            TextEditor(text: $markdownBody)
                .frame(minHeight: 160)
                .padding(10)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("External Links")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            TextEditor(text: $linkURLsText)
                .frame(minHeight: 80)
                .padding(10)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isSaving ? "Saving…" : "Save Media")
                    .font(.headline)
            }
            .foregroundStyle(canSave && !isSaving ? .black : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSave && !isSaving ? Color.white : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSaving)
    }

    private var targetPage: ExercisePage? {
        guard let selectedTargetID else { return nil }
        return databaseStore.allPagesFlat.first { $0.manifest.id == selectedTargetID }
    }

    private var rootContainers: [ExercisePage] {
        databaseStore.allPagesFlat.filter { $0.isRoot && $0.isContainer }
    }

    private var existingMediaCount: Int {
        targetPage?.isLeaf == true ? (targetPage?.manifest.mediaFilenames.count ?? 0) : 0
    }
    private var filteredTargets: [ExercisePage] {
        guard let choice = saveChoice else { return [] }
        if choice == "existing" {
            return databaseStore.allPagesFlat.filter { $0.isLeaf }
        } else {
            return databaseStore.allPagesFlat.filter { $0.isContainer }
        }
    }

    private var targetLabel: String {
        guard let page = targetPage else { return "No destination selected" }
        let path = page.path
            .split(separator: "/")
            .map(String.init)
            .joined(separator: " › ")
        return path.isEmpty ? page.title : path
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let timingIsValid = (5...600).contains(duration)
            && (0...30).contains(prepareTime)
            && (0...120).contains(restAfter)
            && (1...20).contains(sets)
            && (0...120).contains(restBetweenSets)
        return targetPage != nil
            && !trimmedTitle.isEmpty
            && timingIsValid
            && existingMediaCount + 1 + pendingAdditionalMedia.count <= 20
    }

    private func continueToForm() {
        guard let page = targetPage else { return }
        loadForm(from: page)
        saveErrorMessage = nil
        step = .form
    }

    private func loadForm(from page: ExercisePage) {
        if page.isLeaf {
            title = page.manifest.title
            markdownBody = page.manifest.markdownBody
            duration = page.manifest.duration ?? 30
            prepareTime = page.manifest.prepareTime ?? 4
            restAfter = page.manifest.restAfter ?? 0
            sets = page.manifest.sets ?? 1
            restBetweenSets = page.manifest.restBetweenSets ?? 0
            dropSetTemplates = page.manifest.dropSetTemplates
            linkURLsText = page.manifest.linkURLs.joined(separator: "\n")
        } else {
            title = draft.title
            markdownBody = ""
            duration = 30
            prepareTime = 4
            restAfter = 0
            sets = 1
            restBetweenSets = 0
            dropSetTemplates = []
            linkURLsText = ""
        }
    }

    private func createVideoLibrary() {
        let manifest = ExercisePageManifest(
            title: "Video Library",
            pageKind: .container,
        )

        do {
            try databaseStore.createPage(manifest: manifest, parentID: nil)
            databaseStore.reloadImmediately()
            selectedTargetID = manifest.id
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard canSave, let page = targetPage else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedURLs = linkURLsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedDropSetTemplates = dropSetTemplates.map {
            PageDropSetTemplate(
                id: $0.id,
                setIndex: min(max(0, $0.setIndex), max(0, sets - 1)),
                exerciseID: $0.exerciseID,
                name: $0.name,
                duration: $0.duration,
                restAfter: $0.restAfter
            )
        }
        let manifest = makeManifest(
            for: page,
            title: trimmedTitle,
            parsedURLs: parsedURLs,
            normalizedDropSetTemplates: normalizedDropSetTemplates
        )
        let target: MacVideoDatabaseImporter.Target = page.isLeaf
            ? .attachToLeaf(pageID: page.manifest.id, originalManifest: page.manifest)
            : .createLeaf(parentID: page.manifest.id)

        isSaving = true
        saveErrorMessage = nil
        let extraURLs = pendingAdditionalMedia.map(\.url)
        Task {
            do {
                try await MacVideoDatabaseImporter.save(
                    draft: draft,
                    asset: asset,
                    manifest: manifest,
                    target: target,
                    additionalMediaURLs: extraURLs,
                    reloadDatabase: {
                        databaseStore.reloadImmediately()
                    }
                )
                onDraftRenamed(trimmedTitle)
                cleanupPendingMedia()
                isSaving = false
                onSaved(targetLabel)
                dismiss()
            } catch {
                cleanupPendingMedia()
                isSaving = false
                saveErrorMessage = error.localizedDescription
            }
        }
    }

    private func makeManifest(
        for page: ExercisePage,
        title: String,
        parsedURLs: [String],
        normalizedDropSetTemplates: [PageDropSetTemplate]
    ) -> ExercisePageManifest {
        if page.isLeaf {
            var manifest = page.manifest
            manifest.title = title
            manifest.pageKind = .leaf
            manifest.coverImageFilename = nil
            manifest.markdownBody = markdownBody
            manifest.linkURLs = parsedURLs
            manifest.duration = duration
            manifest.prepareTime = min(30, max(0, prepareTime))
            manifest.restAfter = restAfter
            manifest.sets = sets
            manifest.restBetweenSets = restBetweenSets
            manifest.dropSetTemplates = normalizedDropSetTemplates
            manifest.updatedAt = Date()
            return manifest
        }

        return ExercisePageManifest(
            title: title,
            pageKind: .leaf,
            markdownBody: markdownBody,
            linkURLs: parsedURLs,
            duration: duration,
            restAfter: restAfter,
            prepareTime: min(30, max(0, prepareTime)),
            sets: sets,
            restBetweenSets: restBetweenSets,
            dropSetTemplates: normalizedDropSetTemplates,
            parentID: page.manifest.id
        )
    }

    private func stageAdditionalMedia(_ sourceURL: URL) {
        guard existingMediaCount + 1 + pendingAdditionalMedia.count < 20 else {
            saveErrorMessage = "This page cannot contain more than 20 media items."
            return
        }

        let filename = sourceURL.lastPathComponent.isEmpty ? "media" : sourceURL.lastPathComponent
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster-\(UUID().uuidString)-\(filename)")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            pendingAdditionalMedia.append(
                PendingMedia(url: temporaryURL, displayName: filename)
            )
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Could not stage \(filename)."
        }
    }

    private func removePendingMedia(_ media: PendingMedia) {
        pendingAdditionalMedia.removeAll { $0.id == media.id }
        try? FileManager.default.removeItem(at: media.url)
    }

    private func cleanupPendingMedia() {
        for media in pendingAdditionalMedia {
            try? FileManager.default.removeItem(at: media.url)
        }
        pendingAdditionalMedia.removeAll()
    }
}

#endif
