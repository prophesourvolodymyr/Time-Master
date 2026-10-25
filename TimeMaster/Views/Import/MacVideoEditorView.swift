#if os(macOS)
import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
import AppKit

struct MacVideoEditorView: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: MacVideoEditorModel
    let source: MacVideoSource
    let title: String?
    let onBack: (() -> Void)?

    @State private var selectedSegmentID: UUID?
    @State private var selectedDraftID: UUID?
    @State private var selectedDraftIDs: Set<UUID> = []
    @State private var hoveredDraftID: UUID?
    @State private var renamingDraftID: UUID?
    @State private var draftName = ""
    @State private var isTrayDropTargeted = false
    @State private var draftDropTargetID: UUID?
    @FocusState private var editorFocused: Bool

    init(
        source: MacVideoSource,
        model: MacVideoEditorModel? = nil,
        title: String? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.source = source
        self.title = title
        self.onBack = onBack
        _model = StateObject(wrappedValue: model ?? MacVideoEditorModel(source: source))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let onBack {
                    Button {
                        model.stopPlayback()
                        onBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(TimeMasterFont.rowTitle())
                    }
                    .buttonStyle(TimeMasterActionButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                TimeMasterPageTitle("Edit Video", size: 24, relativeTo: .title2)
                Spacer(minLength: 12)
                Text(title ?? source.url.deletingPathExtension().lastPathComponent)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.surface)
            topWorkspace
                .frame(maxHeight: .infinity)
            MacVideoTimelineView(
                model: model,
                selectedSegmentID: $selectedSegmentID,
                onSplit: splitAtPlayhead,
                onInteraction: { editorFocused = true }
            )
            .frame(height: 224)
        }
        .frame(minWidth: 640, minHeight: 560)
        .background(Theme.background)
        .onDisappear {
            model.stopPlayback()
            model.cancelTimelineThumbnails()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.stopPlayback() }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($editorFocused)
        .onAppear { editorFocused = true }
        .onKeyPress(phases: [.down, .repeat], action: handleKeyPress)
        .alert("Rename media", isPresented: Binding(
            get: { renamingDraftID != nil },
            set: { if !$0 { renamingDraftID = nil } }
        )) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) { renamingDraftID = nil }
            Button("Rename") {
                if let renamingDraftID { model.renameDraft(id: renamingDraftID, to: draftName) }
                renamingDraftID = nil
            }
        }
    }

    private var topWorkspace: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                previewPane
                    .frame(width: geometry.size.width * 0.59)
                mediaTray
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var previewPane: some View {
        VStack(spacing: 10) {
            MacVideoPlayerView(player: model.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if model.isProcessing {
                        ProgressView()
                            .tint(.white)
                            .allowsHitTesting(false)
                    }
                }
            playbackControls
        }
        .padding(12)
        .background(Theme.surface)
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            Button("Back 5 Seconds", systemImage: "gobackward.5") {
                model.seek(to: model.currentTime - 5)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .help("Back 5 seconds (J)")
            Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                model.togglePlayback()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .help(model.isPlaying ? "Pause (Space or K)" : "Play (Space or K)")
            Button("Forward 5 Seconds", systemImage: "goforward.5") {
                model.seek(to: model.currentTime + 5)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .help("Forward 5 seconds (L)")
            Text(timeString(model.currentTime))
                .font(TimeMasterFont.technical())
                .monospacedDigit()
            Slider(
                value: Binding(get: { model.currentTime }, set: { model.updateScrubPosition($0) }),
                in: 0...max(model.duration, 0.01),
                onEditingChanged: { editing in
                    if editing { model.beginScrubbing() } else { model.endScrubbing() }
                }
            )
            .tint(Theme.toolbarOrange)
            .accessibilityLabel("Playback position")
            Text(timeString(model.duration))
                .font(TimeMasterFont.technical())
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            Button("Open preview window", systemImage: "arrow.up.left.and.arrow.down.right") {
                model.pausePlayback()
                MacVideoPreviewWindow.present(
                    url: source.url,
                    onCut: { _ in editorFocused = true },
                    onClose: { withExtendedLifetime(source) {} }
                )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
        }
        .disabled(model.duration <= 0)
    }

    private var mediaTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Media Tray", systemImage: "tray.full")
                    .font(TimeMasterFont.rowTitle())
                Text("\(model.mediaCount) / 20")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 4)
                if selectedDraftIDs.count > 1 {
                    Button("Stack selected", systemImage: "square.stack.3d.up") {
                        groupSelectedDrafts()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .help("Stack \(selectedDraftIDs.count) selected cards (⌘G)")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    draftSection(title: "Staged", systemImage: "tray", drafts: stagedDrafts, emptyMessage: "Add clips or stills")
                    draftSection(title: "Saved", systemImage: "checkmark.circle", drafts: savedDrafts, emptyMessage: "Saved media")
                }
                .padding(2)
            }
        }
        .padding(12)
        .background(Theme.surface2)
        .overlay {
            if isTrayDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.plainText], isTargeted: $isTrayDropTargeted, perform: receiveTimelineDrop)
    }
    private var stagedDrafts: [MacVideoDraft] {
        model.drafts.filter { !$0.isSaved }
    }

    private var savedDrafts: [MacVideoDraft] {
        model.drafts.filter(\.isSaved)
    }

    @ViewBuilder
    private func draftSection(
        title: String,
        systemImage: String,
        drafts: [MacVideoDraft],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(title)
                        .font(TimeMasterFont.rowTitle())
                } icon: {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text("\(drafts.count)")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if drafts.isEmpty {
                Label(emptyMessage, systemImage: systemImage)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 142), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(drafts) { draft in
                        draftCard(draft)
                    }
                }
            }
        }
    }

    private func draftCard(_ draft: MacVideoDraft) -> some View {
        let isSelected = selectedDraftIDs.contains(draft.id)
        let isTargeted = draftDropTargetID == draft.id

        return VStack(alignment: .leading, spacing: 7) {
            ZStack {
                ForEach(Array(draft.groupedMedia.prefix(2).enumerated()), id: \.element.id) { index, media in
                    Image(nsImage: media.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 84)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, CGFloat(2 - index) * 4)
                        .offset(y: -CGFloat(index + 1) * 4)
                }
                Image(nsImage: draft.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 84)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        Label(draft.mediaCount > 1 ? "\(draft.mediaCount)" : draft.rangeLabel, systemImage: draft.systemImage)
                            .font(TimeMasterFont.micro())
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 5))
                            .padding(5)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected || draft.isSaved {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "checkmark.seal.fill")
                                .foregroundStyle(isSelected ? Theme.toolbarOrange : Color.green)
                                .background(.black.opacity(0.5), in: Circle())
                                .padding(6)
                        }
                    }
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.toolbarOrange.opacity(0.78))
                    Label("Stack", systemImage: "square.stack.3d.up.fill")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, draft.mediaCount > 1 ? 8 : 0)
            Text(draft.title)
                .font(TimeMasterFont.caption())
                .lineLimit(1)
                .help(draft.title)
            HStack(spacing: 6) {
                if draft.isSaved, let target = draft.savedTargetLabel {
                    Text(target)
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(draft.mediaCount > 1 ? "\(draft.mediaCount) media" : draft.kind == .clip ? "Clip" : "Still")
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Save \(draft.title)", systemImage: "square.and.arrow.down") { saveDraft(draft) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 30)
                    .background(Theme.toolbarOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(Theme.toolbarOrange)
                Button("Remove \(draft.title)", systemImage: "xmark") { removeDraft(draft.id) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: 26, height: 30)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(7)
        .background(hoveredDraftID == draft.id ? Theme.surface : Theme.background, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
            selectDraft(draft.id, extending: modifiers.contains(.command), range: modifiers.contains(.shift))
        }
        .onHover { hoveredDraftID = $0 ? draft.id : nil }
        .onDrag {
            if !selectedDraftIDs.contains(draft.id) { selectDraft(draft.id) }
            let ids = model.drafts.filter { selectedDraftIDs.contains($0.id) }.map { $0.id.uuidString }
            return NSItemProvider(object: "drafts:\(ids.joined(separator: ","))" as NSString)
        }
        .onDrop(of: [UTType.plainText], isTargeted: Binding(
            get: { draftDropTargetID == draft.id },
            set: { draftDropTargetID = $0 ? draft.id : nil }
        )) { receiveDraftDrop($0, targetID: draft.id) }
        .overlay {
            if isTargeted || isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.toolbarOrange, lineWidth: isTargeted ? 2 : 1)
                    .allowsHitTesting(false)
            }
        }
        .contextMenu {
            Button("Save", systemImage: "square.and.arrow.down") { saveDraft(draft) }
            Button(selectedDraftIDs.contains(draft.id) ? "Deselect" : "Add to selection", systemImage: "checkmark.circle") {
                selectDraft(draft.id, extending: true)
            }
            if selectedDraftIDs.subtracting([draft.id]).count > 0 {
                Button("Stack selected here", systemImage: "square.stack.3d.up") {
                    model.mergeDrafts(sourceIDs: selectedDraftIDs, intoID: draft.id)
                    selectedDraftIDs = [draft.id]
                    selectedDraftID = draft.id
                }
            }
            if draft.mediaCount > 1 {
                Button("Separate stack", systemImage: "square.stack.3d.up.slash") { model.ungroupDraft(id: draft.id) }
            }
            Button("Rename", systemImage: "pencil") {
                draftName = draft.displayName ?? ""
                renamingDraftID = draft.id
            }
            Button("Remove", systemImage: "trash", role: .destructive) { removeDraft(draft.id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(draft.title), \(draft.mediaCount) media\(draft.isSaved ? ", saved" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text("Select")) { selectDraft(draft.id, extending: true) }
        .accessibilityAction(named: Text("Save")) { saveDraft(draft) }
    }

    private func selectDraft(_ id: UUID, extending: Bool = false, range: Bool = false) {
        if range, let anchor = selectedDraftID,
           let start = model.drafts.firstIndex(where: { $0.id == anchor }),
           let end = model.drafts.firstIndex(where: { $0.id == id }) {
            selectedDraftIDs.formUnion(model.drafts[min(start, end)...max(start, end)].map(\.id))
        } else if extending {
            if !selectedDraftIDs.insert(id).inserted { selectedDraftIDs.remove(id) }
        } else {
            selectedDraftIDs = [id]
        }
        selectedDraftID = id
        model.selectDraft(id: id)
        editorFocused = true
    }

    private func removeDraft(_ id: UUID) {
        model.removeDraft(id: id)
        selectedDraftIDs.remove(id)
        if selectedDraftID == id { selectedDraftID = selectedDraftIDs.first }
    }

    private func groupSelectedDrafts() {
        guard selectedDraftIDs.count > 1,
              let target = selectedDraftID ?? selectedDraftIDs.first else { return }
        model.mergeDrafts(sourceIDs: selectedDraftIDs, intoID: target)
        selectedDraftIDs = [target]
        selectedDraftID = target
    }

    private func saveDraft(_ draft: MacVideoDraft) {
        model.pausePlayback()
        model.savingWindowCount += 1
        MacVideoSaveWindowPresenter.present(
            draft: draft,
            asset: model.asset,
            databaseStore: databaseStore,
            workoutStore: workoutStore,
            onDraftRenamed: { [model] name in model.renameDraft(id: draft.id, to: name) },
            onSaved: { [model] target in model.markDraftSaved(id: draft.id, targetLabel: target) },
            onClose: { [model] in model.savingWindowCount = max(0, model.savingWindowCount - 1) }
        )
    }

    private func splitAtPlayhead() {
        guard let newSegmentID = model.splitSegment(at: model.currentTime) else { return }
        selectedSegmentID = newSegmentID
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let characters = keyPress.characters.lowercased()
        if keyPress.modifiers.contains(.command) {
            switch characters {
            case "a":
                selectedDraftIDs = Set(model.drafts.map(\.id))
                selectedDraftID = model.drafts.first?.id
            case "g":
                if keyPress.modifiers.contains(.shift), let selectedDraftID {
                    model.ungroupDraft(id: selectedDraftID)
                } else {
                    groupSelectedDrafts()
                }
            default:
                return .ignored
            }
            return .handled
        }
        guard keyPress.modifiers.isEmpty else { return .ignored }
        guard !(NSApp.keyWindow?.firstResponder is NSText) else { return .ignored }
        if keyPress.key == .leftArrow || keyPress.key == .rightArrow {
            model.seek(to: model.currentTime + (keyPress.key == .rightArrow ? 1 : -1) / model.frameRate)
            return .handled
        }
        switch characters {
        case "x":
            splitAtPlayhead()
        case "c":
            guard keyPress.phase == .down, !model.isProcessing else { return .handled }
            splitAtPlayhead()
        case "k":
            guard keyPress.phase == .down else { return .handled }
            model.togglePlayback()
        case "j", "l":
            model.seek(to: model.currentTime + (characters == "l" ? 5 : -5))
        case "s":
            guard keyPress.phase == .down, model.duration > 0, !model.isProcessing else { return .handled }
            Task { await model.addStill() }
        case "a":
            guard keyPress.phase == .down, !model.segments.isEmpty, !model.isProcessing else { return .handled }
            Task { await model.addAllSegmentsToTray() }
        case "t":
            guard keyPress.phase == .down, !model.isProcessing,
                  let segmentID = selectedSegmentID ?? model.segments.first(where: {
                      model.currentTime >= $0.startTime && model.currentTime <= $0.endTime
                  })?.id else { return .handled }
            Task { await model.addSegmentToTray(id: segmentID) }
        case " ":
            model.togglePlayback()
        case "i", "o":
            guard let selectedSegmentID else { return .ignored }
            model.setBoundary(characters == "i" ? .start : .end, of: selectedSegmentID, to: model.currentTime)
        default:
            return .ignored
        }
        return .handled
    }

    private func receiveTimelineDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String,
                  string.hasPrefix("segment:") else {
                return
            }
            guard let segmentID = UUID(uuidString: String(string.dropFirst("segment:".count))) else {
                Task { @MainActor in
                    model.reportMessage("That drop did not contain a valid timeline segment.")
                }
                return
            }
            Task { @MainActor in
                await model.addSegmentToTray(id: segmentID)
            }
        }
        return true
    }

    private func receiveDraftDrop(
        _ providers: [NSItemProvider],
        targetID: UUID
    ) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, string.hasPrefix("drafts:") else { return }
            let ids = Set(string.dropFirst("drafts:".count).split(separator: ",").compactMap { UUID(uuidString: String($0)) })
            guard !ids.isEmpty else { return }
            Task { @MainActor in
                model.mergeDrafts(sourceIDs: ids, intoID: targetID)
                selectedDraftIDs = [targetID]
                selectedDraftID = targetID
            }
        }
        return true
    }




    private func timeString(_ seconds: Double) -> String {
        let bounded = seconds.isFinite ? max(0, seconds) : 0
        let minutes = Int(bounded) / 60
        let wholeSeconds = Int(bounded) % 60
        let hundredths = Int((bounded - floor(bounded)) * 100)
        return String(format: "%d:%02d.%02d", minutes, wholeSeconds, hundredths)
    }
}

#endif
