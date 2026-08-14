#if os(macOS)
import SwiftUI
import TimeMasterCore

struct MacVideoEditorView: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    @StateObject private var model: MacVideoEditorModel

    let source: MacVideoSource
    let onBack: () -> Void
    let onSaved: () -> Void

    @State private var title: String
    @State private var notes = ""
    @State private var destinationID: String?
    @State private var exerciseDuration = 30
    @State private var restAfter = 0
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(
        source: MacVideoSource,
        onBack: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.source = source
        self.onBack = onBack
        self.onSaved = onSaved
        _model = StateObject(wrappedValue: MacVideoEditorModel(url: source.url))
        _title = State(initialValue: source.url.deletingPathExtension().lastPathComponent)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                previewPane
                    .frame(minWidth: 440)
                inspectorPane
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
            }
            Divider()
            mediaTray
        }
        .frame(minWidth: 820, minHeight: 620)
        .navigationTitle("Edit Video")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", systemImage: "chevron.left", action: onBack)
            }
            ToolbarItem(placement: .primaryAction) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Save to Database", systemImage: "square.and.arrow.down", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .onDisappear(perform: model.stopPlayback)
        .alert("Couldn’t save video", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: model.togglePlayback) {
                ZStack {
                    MacVideoPlayerView(player: model.player)
                    if !model.isPlaying {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 8)
                    }
                    if model.isProcessing {
                        Color.black.opacity(0.35)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isPlaying ? "Pause video" : "Play video")

            playbackControls
            clipControls

            if let message = model.message {
                Label(message, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(timeString(model.currentTime))
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                Slider(
                    value: $model.currentTime,
                    in: 0...max(model.duration, 0.01),
                    onEditingChanged: { isEditing in
                        if isEditing {
                            model.beginScrubbing()
                        } else {
                            model.endScrubbing()
                        }
                    }
                )
                .disabled(model.duration == 0)
                Text(timeString(model.duration))
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Back 5 Seconds", systemImage: "gobackward.5") {
                    model.seek(to: model.currentTime - 5)
                }
                .labelStyle(.iconOnly)
                .disabled(model.duration == 0)

                Button(
                    model.isPlaying ? "Pause" : "Play",
                    systemImage: model.isPlaying ? "pause.fill" : "play.fill",
                    action: model.togglePlayback
                )
                .labelStyle(.iconOnly)
                .disabled(model.duration == 0)

                Button("Forward 5 Seconds", systemImage: "goforward.5") {
                    model.seek(to: model.currentTime + 5)
                }
                .labelStyle(.iconOnly)
                .disabled(model.duration == 0)

                Spacer()

                Button("Capture Still", systemImage: "camera") {
                    Task { await model.addStill() }
                }
                .disabled(model.duration == 0 || model.isProcessing)
            }
        }
    }

    private var clipControls: some View {
        GroupBox("Clip Selection") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Start") {
                    HStack {
                        Text(timeString(model.clipStart))
                            .monospacedDigit()
                        Button("Set Start") {
                            model.setClipStartToCurrentTime()
                        }
                        .disabled(model.duration == 0)
                    }
                }
                LabeledContent("End") {
                    HStack {
                        Text(timeString(model.clipEnd))
                            .monospacedDigit()
                        Button("Set End") {
                            model.setClipEndToCurrentTime()
                        }
                        .disabled(model.duration == 0)
                    }
                }
                HStack {
                    Text("Selected duration: \(timeString(max(0, model.clipEnd - model.clipStart)))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Clip", systemImage: "plus") {
                        Task { await model.addClip() }
                    }
                    .disabled(model.duration == 0 || model.isProcessing)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var inspectorPane: some View {
        SwiftUI.Form(content: {
            SwiftUI.Section("Exercise Page") {
                TextField("Name", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)

                if destinationContainers.isEmpty {
                    Label("Exercise pages must be saved inside a container.", systemImage: "folder.badge.questionmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Create Video Library", systemImage: "folder.badge.plus", action: createVideoLibrary)
                } else {
                    Picker("Save in", selection: $destinationID) {
                        Text("Choose a container").tag(String?.none)
                        ForEach(destinationContainers) { page in
                            Text(containerLabel(for: page)).tag(Optional(page.manifest.id))
                        }
                    }
                }
            }

            SwiftUI.Section("Workout Defaults") {
                Stepper("Duration: \(exerciseDuration) seconds", value: $exerciseDuration, in: 5...3_600, step: 5)
                Stepper("Rest after: \(restAfter) seconds", value: $restAfter, in: 0...600, step: 5)
            }

            SwiftUI.Section("Save behavior") {
                Label("The first saved media item becomes the page cover.", systemImage: "photo.on.rectangle")
                Label("Everything is copied into the selected page’s media folder.", systemImage: "externaldrive.fill")
            }
        })
        .formStyle(.grouped)
        .padding(.top)
    }

    private var mediaTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Media Tray", systemImage: "tray.full")
                    .font(.headline)
                Text("\(model.drafts.count) of 20")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if model.drafts.isEmpty {
                ContentUnavailableView(
                    "No Media Added",
                    systemImage: "film.stack",
                    description: Text("Capture a still or add a selected clip to create this exercise page.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(model.drafts) { draft in
                            draftCard(draft)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private func draftCard(_ draft: MacVideoDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: draft.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 132, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Remove \(draft.title)", systemImage: "xmark.circle.fill") {
                    model.removeDraft(id: draft.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(4)
            }
            Label(draft.title, systemImage: draft.systemImage)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 132, alignment: .leading)
    }

    private var destinationContainers: [ExercisePage] {
        databaseStore.allPagesFlat
            .filter(\.isContainer)
            .sorted { containerLabel(for: $0) < containerLabel(for: $1) }
    }

    private var canSave: Bool {
        !isSaving &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        destinationID != nil &&
        !model.drafts.isEmpty
    }

    private func containerLabel(for page: ExercisePage) -> String {
        page.path
            .split(separator: "/")
            .map(String.init)
            .joined(separator: " › ")
    }

    private func createVideoLibrary() {
        let manifest = ExercisePageManifest(
            title: "Video Library",
            pageKind: .container,
            iconName: "video.fill"
        )

        do {
            try databaseStore.createPage(manifest: manifest, parentID: nil)
            databaseStore.reloadImmediately()
            destinationID = manifest.id
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func save() {
        guard let destinationID else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                try await MacVideoDatabaseImporter.save(
                    asset: model.asset,
                    drafts: model.drafts,
                    title: trimmedTitle,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentID: destinationID,
                    duration: exerciseDuration,
                    restAfter: restAfter,
                    reloadDatabase: {
                        databaseStore.reloadImmediately()
                    }
                )
                onSaved()
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }

    private func timeString(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
#endif
