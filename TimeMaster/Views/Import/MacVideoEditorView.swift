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
    let onBack: () -> Void

    @State private var selectedSegmentID: UUID?
    @State private var selectedDraftID: UUID?
    @State private var selectedDraftIDs: Set<UUID> = []
    @State private var hoveredDraftID: UUID?
    @State private var renamingDraftID: UUID?
    @State private var draftName = ""
    @State private var timelineZoom: CGFloat = 1
    @State private var timelineViewport = CGRect.zero
    @State private var timelineViewportWidth: CGFloat = 1
    @State private var boundaryDragStart: Double?
    @State private var isTrayDropTargeted = false
    @State private var draftDropTargetID: UUID?
    @FocusState private var editorFocused: Bool

    init(
        source: MacVideoSource,
        model: MacVideoEditorModel? = nil,
        onBack: @escaping () -> Void
    ) {
        self.source = source
        self.onBack = onBack
        _model = StateObject(wrappedValue: model ?? MacVideoEditorModel(source: source))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    model.stopPlayback()
                    onBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(TimeMasterFont.rowTitle())
                }
                .buttonStyle(TimeMasterActionButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
                TimeMasterPageTitle("Edit Video", size: 24, relativeTo: .title2)
                Spacer(minLength: 12)
                Text(source.url.deletingPathExtension().lastPathComponent)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.surface)
            Divider().overlay(Theme.separator)
            topWorkspace
                .frame(maxHeight: .infinity)
            Divider().overlay(Theme.separator)
            timeline
                .frame(height: 216)
        }
        .frame(minWidth: 860, minHeight: 600)
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
                Divider().overlay(Theme.separator)
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
            Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                model.togglePlayback()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            Button("Forward 5 Seconds", systemImage: "goforward.5") {
                model.seek(to: model.currentTime + 5)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
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
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isTargeted || isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isTargeted ? 2 : 1)
                .allowsHitTesting(false)
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
    private var timeline: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("Timeline", systemImage: "scissors")
                    .font(TimeMasterFont.rowTitle())
                Text("\(model.segments.count)")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Button("Zoom out", systemImage: "minus.magnifyingglass") { zoomTimeline(by: 1 / 1.5) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .disabled(timelineZoom <= 1)
                    .help("Zoom out (⌘−)")
                Button("\(Int(timelineZoom.rounded()))×") { timelineZoom = 1 }
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .buttonStyle(.plain)
                    .frame(minWidth: 38)
                    .accessibilityLabel("Fit timeline")
                Button("Zoom in", systemImage: "plus.magnifyingglass") { zoomTimeline(by: 1.5) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .disabled(model.duration <= 0 || timelineZoom >= maximumTimelineZoom)
                    .help("Zoom in (⌘+)")
                Divider().frame(height: 22)
                Button("Split", systemImage: "scissors", action: splitAtPlayhead)
                    .buttonStyle(TimeMasterActionButtonStyle())
                    .disabled(!canSplit || model.isProcessing)
                    .help("Split at playhead (X)")
                Button("Still", systemImage: "camera") { Task { await model.addStill() } }
                    .buttonStyle(TimeMasterActionButtonStyle())
                    .disabled(model.duration <= 0 || model.isProcessing)
                Button("Add All", systemImage: "tray.and.arrow.down") { Task { await model.addAllSegmentsToTray() } }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                    .disabled(model.segments.isEmpty || model.isProcessing)
            }
            GeometryReader { geometry in
                let width = max(1, geometry.size.width) * timelineZoom
                MacVideoTimelineScrollView(
                    contentWidth: width,
                    contentHeight: 126,
                    playheadFraction: model.duration > 0 ? model.currentTime / model.duration : 0,
                    onViewportChange: { rect in
                        timelineViewport = rect
                        timelineViewportWidth = max(1, rect.width)
                    },
                    onMagnify: zoomTimeline
                ) {
                    timelineTrack(width: width)
                }
            }
            .frame(height: 140)
            HStack {
                if let message = model.message {
                    Text(message)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
                Text("\(timeString(model.currentTime)) / \(timeString(model.duration))")
                    .monospacedDigit()
            }
            .font(TimeMasterFont.micro())
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var maximumTimelineZoom: CGFloat {
        max(1, CGFloat(model.duration * model.frameRate * 72) / max(1, timelineViewportWidth))
    }

    private func zoomTimeline(by factor: CGFloat) {
        guard factor.isFinite, factor > 0 else { return }
        timelineZoom = min(maximumTimelineZoom, max(1, timelineZoom * factor))
    }

    private func sampleCount(width: CGFloat) -> Int {
        let frameCount = max(1, Int(ceil(model.duration * model.frameRate)))
        return max(1, min(frameCount, Int(ceil(width / 72))))
    }

    private func visibleSamples(width: CGFloat) -> [Int] {
        guard model.duration > 0 else { return [] }
        let count = sampleCount(width: width)
        let cellWidth = width / CGFloat(count)
        let left = max(0, Int(floor(timelineViewport.minX / cellWidth)) - 1)
        let right = min(count - 1, Int(ceil(max(timelineViewport.maxX, timelineViewportWidth) / cellWidth)) + 1)
        return left <= right ? Array(left...right) : []
    }

    private func sampleFrame(_ index: Int, count: Int) -> Int {
        min(max(0, Int(ceil(model.duration * model.frameRate)) - 1),
            Int((Double(index) * model.duration / Double(count) * model.frameRate).rounded(.down)))
    }

    private func timelineTrack(width: CGFloat) -> some View {
        let count = sampleCount(width: width)
        let cellWidth = width / CGFloat(count)
        let samples = visibleSamples(width: width)
        let frames = samples.map { sampleFrame($0, count: count) }
        let playheadX = xPosition(for: model.currentTime, width: width)

        return ZStack(alignment: .topLeading) {
            timelineRuler(width: width)
                .gesture(scrubGesture(width: width))
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.surface2)
                ForEach(samples, id: \.self) { index in
                    Group {
                        if let thumbnail = model.timelineThumbnails[sampleFrame(index, count: count)] {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle()
                                .fill(Theme.surface2)
                                .overlay { Image(systemName: "film").foregroundStyle(Theme.textSecondary.opacity(0.35)) }
                        }
                    }
                    .frame(width: cellWidth, height: 64)
                    .clipped()
                    .offset(x: CGFloat(index) * cellWidth)
                }
            }
            .frame(width: width, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: width))
            .offset(y: 26)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Video timeline")
            .accessibilityValue("\(timeString(model.currentTime)) of \(timeString(model.duration))")
            .accessibilityAdjustableAction { direction in
                model.seek(to: model.currentTime + (direction == .increment ? 1 : -1) / model.frameRate)
            }
            ForEach(model.segments) { segment in
                timelineSegment(segment, trackWidth: width)
                    .offset(x: xPosition(for: segment.startTime, width: width), y: 96)
            }
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 2, height: 124)
                .offset(x: max(0, min(width - 2, playheadX)))
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.toolbarOrange)
                .frame(width: 10, height: 7)
                .offset(x: max(0, min(width - 10, playheadX - 4)))
                .allowsHitTesting(false)
        }
        .frame(width: width, height: 126, alignment: .topLeading)
        .task(id: frames) { model.requestTimelineThumbnails(frames: frames) }
    }

    private func timelineRuler(width: CGFloat) -> some View {
        let targetStep = max(1 / model.frameRate, model.duration * 96 / Double(max(1, width)))
        let magnitude = pow(10, floor(log10(targetStep)))
        let normalized = targetStep / magnitude
        let step = max(1 / model.frameRate, magnitude * (normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10))
        let first = max(0, Int(floor(positionToTime(x: timelineViewport.minX, width: width) / step)))
        let last = max(first, Int(ceil(positionToTime(x: max(timelineViewport.maxX, timelineViewportWidth), width: width) / step)))

        return ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(first...last, id: \.self) { index in
                let time = min(model.duration, Double(index) * step)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString(time))
                        .font(TimeMasterFont.micro().monospacedDigit())
                    Rectangle().frame(width: 1, height: 5)
                }
                .foregroundStyle(Theme.textSecondary)
                .offset(x: min(max(0, width - 58), xPosition(for: time, width: width)))
            }
        }
        .frame(width: width, height: 24)
        .contentShape(Rectangle())
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard model.duration > 0 else { return }
                model.beginScrubbing()
                let time = positionToTime(x: value.location.x, width: width)
                selectedSegmentID = model.segments.first { $0.contains(time) }?.id
                model.updateScrubPosition(time)
            }
            .onEnded { value in
                model.updateScrubPosition(positionToTime(x: value.location.x, width: width))
                model.endScrubbing()
                editorFocused = true
            }
    }

    private func timelineSegment(_ segment: MacVideoTimelineSegment, trackWidth: CGFloat) -> some View {
        let isSelected = selectedSegmentID == segment.id
        let width = max(1, trackWidth * CGFloat(segment.duration / max(model.duration, 0.01)))
        return RoundedRectangle(cornerRadius: 5)
            .fill(isSelected ? Theme.toolbarOrange.opacity(0.25) : Theme.surface2)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: 1)
                Text(segmentNumber(segment.id))
                    .font(TimeMasterFont.black(11, relativeTo: .caption2))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
            }
            .frame(width: width, height: 28)
            .contentShape(Rectangle())
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                selectedSegmentID = segment.id
                model.seek(to: segment.startTime + Double(value.location.x / width) * segment.duration)
                editorFocused = true
            })
            .onDrag { NSItemProvider(object: "segment:\(segment.id.uuidString)" as NSString) }
            .overlay(alignment: .leading) { boundaryHandle(segment, boundary: .start, trackWidth: trackWidth) }
            .overlay(alignment: .trailing) { boundaryHandle(segment, boundary: .end, trackWidth: trackWidth) }
            .contextMenu {
                Button("Add clip to tray", systemImage: "tray.and.arrow.down") {
                    Task { await model.addSegmentToTray(id: segment.id) }
                }
                Button("Set start at playhead", systemImage: "arrow.right.to.line") {
                    model.setBoundary(.start, of: segment.id, to: model.currentTime)
                }
                Button("Set end at playhead", systemImage: "arrow.left.to.line") {
                    model.setBoundary(.end, of: segment.id, to: model.currentTime)
                }
                Button("Delete segment", systemImage: "trash", role: .destructive) {
                    model.removeSegment(id: segment.id)
                    if selectedSegmentID == segment.id { selectedSegmentID = nil }
                }
            }
            .accessibilityLabel("Segment \(segmentNumber(segment.id)), \(timeString(segment.startTime)) to \(timeString(segment.endTime))")
            .accessibilityAction(named: Text("Select segment")) {
                selectedSegmentID = segment.id
                model.seek(to: segment.startTime)
            }
    }

    private func boundaryHandle(
        _ segment: MacVideoTimelineSegment,
        boundary: MacVideoTimelineSegment.Boundary,
        trackWidth: CGFloat
    ) -> some View {
        let boundaryTime = boundary == .start ? segment.startTime : segment.endTime
        return Image(systemName: boundary == .start ? "chevron.compact.left" : "chevron.compact.right")
            .font(.caption.weight(.bold))
            .frame(width: 12, height: 28)
            .background(Theme.toolbarOrange.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if boundaryDragStart == nil { boundaryDragStart = boundaryTime }
                        let time = (boundaryDragStart ?? boundaryTime)
                            + Double(value.translation.width / max(1, trackWidth)) * model.duration
                        selectedSegmentID = segment.id
                        model.setBoundary(boundary, of: segment.id, to: time)
                    }
                    .onEnded { _ in boundaryDragStart = nil }
            )
            .accessibilityLabel(boundary == .start ? "Segment start" : "Segment end")
            .accessibilityValue(timeString(boundaryTime))
            .accessibilityAdjustableAction { direction in
                model.setBoundary(boundary, of: segment.id, to: boundaryTime + (direction == .increment ? 1 : -1) / model.frameRate)
            }
    }
    private func positionToTime(x: CGFloat, width: CGFloat) -> Double {
        guard model.duration > 0 else { return 0 }
        return model.duration * Double(max(0, min(width, x)) / max(width, 1))
    }

    private func splitAtPlayhead() {
        guard let newSegmentID = model.splitSegment(at: model.currentTime) else { return }
        selectedSegmentID = newSegmentID
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let characters = keyPress.characters.lowercased()
        if keyPress.modifiers.contains(.command) {
            switch characters {
            case "+", "=":
                zoomTimeline(by: 1.5)
            case "-", "_":
                zoomTimeline(by: 1 / 1.5)
            case "0":
                timelineZoom = 1
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
        if keyPress.key == .leftArrow || keyPress.key == .rightArrow {
            model.seek(to: model.currentTime + (keyPress.key == .rightArrow ? 1 : -1) / model.frameRate)
            return .handled
        }
        switch characters {
        case "x":
            splitAtPlayhead()
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
    private var canSplit: Bool {
        guard model.duration >= 0.5 else { return false }
        return model.segments.contains {
            model.currentTime > $0.startTime + 0.25 &&
                model.currentTime < $0.endTime - 0.25
        }
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

    private func xPosition(for time: Double, width: CGFloat) -> CGFloat {
        guard model.duration > 0 else { return 0 }
        return width * CGFloat(max(0, min(model.duration, time)) / model.duration)
    }


    private func segmentNumber(_ id: UUID) -> String {
        guard let index = model.segments.firstIndex(where: { $0.id == id }) else {
            return "?"
        }
        return "\(index + 1)"
    }

    private func timeString(_ seconds: Double) -> String {
        let bounded = seconds.isFinite ? max(0, seconds) : 0
        let minutes = Int(bounded) / 60
        let wholeSeconds = Int(bounded) % 60
        let hundredths = Int((bounded - floor(bounded)) * 100)
        return String(format: "%d:%02d.%02d", minutes, wholeSeconds, hundredths)
    }
}

private struct MacVideoTimelineScrollView<Content: View>: NSViewRepresentable {
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let playheadFraction: Double
    let onViewportChange: (CGRect) -> Void
    let onMagnify: (CGFloat) -> Void
    @ViewBuilder let content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MacVideoTimelineNativeScrollView {
        let scrollView = MacVideoTimelineNativeScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.contentView.postsBoundsChangedNotifications = true
        let document = NSHostingView(rootView: content)
        document.sizingOptions = []
        document.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        scrollView.documentView = document
        context.coordinator.document = document
        context.coordinator.width = contentWidth
        context.coordinator.onViewportChange = onViewportChange
        let coordinator = context.coordinator
        coordinator.observer = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator, weak scrollView] _ in
            MainActor.assumeIsolated {
                guard let scrollView else { return }
                coordinator?.reportViewport(scrollView.documentVisibleRect)
            }
        }
        scrollView.onMagnify = onMagnify
        return scrollView
    }

    func updateNSView(_ scrollView: MacVideoTimelineNativeScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onViewportChange = onViewportChange
        scrollView.onMagnify = onMagnify
        let previousWidth = max(1, coordinator.width)
        let viewport = scrollView.documentVisibleRect
        let previousPlayheadX = previousWidth * CGFloat(playheadFraction)
        let playheadIsVisible = viewport.minX <= previousPlayheadX && previousPlayheadX <= viewport.maxX
        let anchorFraction = playheadIsVisible ? CGFloat(playheadFraction) : viewport.midX / previousWidth
        let anchorX = playheadIsVisible ? previousPlayheadX - viewport.minX : viewport.width / 2
        coordinator.document?.rootView = content
        coordinator.document?.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        if previousWidth != contentWidth {
            let origin = min(max(0, contentWidth * anchorFraction - anchorX), max(0, contentWidth - viewport.width))
            scrollView.contentView.scroll(to: NSPoint(x: origin, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        coordinator.width = contentWidth
        coordinator.reportViewport(scrollView.documentVisibleRect)
    }

    static func dismantleNSView(_ nsView: MacVideoTimelineNativeScrollView, coordinator: Coordinator) {
        if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) }
        coordinator.observer = nil
        coordinator.document = nil
        nsView.documentView = nil
        nsView.onMagnify = nil
    }

    final class Coordinator {
        var document: NSHostingView<Content>?
        var observer: NSObjectProtocol?
        var width: CGFloat = 1
        var onViewportChange: ((CGRect) -> Void)?
        private var lastViewport = CGRect.null

        func reportViewport(_ viewport: CGRect) {
            guard viewport.width > 0, viewport != lastViewport else { return }
            lastViewport = viewport
            DispatchQueue.main.async { [weak self] in self?.onViewportChange?(viewport) }
        }
    }
}

private final class MacVideoTimelineNativeScrollView: NSScrollView {
    var onMagnify: ((CGFloat) -> Void)?

    override func magnify(with event: NSEvent) {
        onMagnify?(max(0.05, 1 + event.magnification))
    }
}
#endif
