#if os(macOS)
import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
import AppKit

struct MacVideoEditorView: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    @StateObject private var model: MacVideoEditorModel

    let source: MacVideoSource
    let onBack: () -> Void

    @State private var selectedSegmentID: UUID?
    @State private var selectedDraftID: UUID?
    @State private var draftForSaving: MacVideoDraft?
    @State private var isTrayDropTargeted = false
    @State private var splitHoverX: CGFloat?
    @State private var isSplitCursorPushed = false
    @State private var playheadDragStartTime: Double?
 @State private var splitToolActive = false
 @State private var isFullscreen = false

    init(
        source: MacVideoSource,
        onBack: @escaping () -> Void
    ) {
        self.source = source
        self.onBack = onBack
        _model = StateObject(wrappedValue: MacVideoEditorModel(url: source.url))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topWorkspace
                    .frame(height: geometry.size.height * 0.65)
                Divider()
                timeline
                    .frame(height: geometry.size.height * 0.35)
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
        .navigationTitle("Edit Video")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", systemImage: "chevron.left", action: onBack)
            }
        }
        .onDisappear(perform: model.stopPlayback)
        .popover(
            item: $draftForSaving,
            attachmentAnchor: .point(.center),
            arrowEdge: .bottom
        ) { draft in
            MacVideoSavePopover(
                draft: draft,
                asset: model.asset,
                onDraftRenamed: { name in
                    model.renameDraft(id: draft.id, to: name)
                },
                onSaved: { targetLabel in
                    model.markDraftSaved(id: draft.id, targetLabel: targetLabel)
                    draftForSaving = nil
                }
            )
            .environmentObject(databaseStore)
        }
        .sheet(isPresented: $isFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                MacVideoPlayerView(player: model.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack {
                    HStack {
                        Spacer()
                        Button("Done") { isFullscreen = false }
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                }
            }
            .onTapGesture { isFullscreen = false }
        }

    }
    private var topWorkspace: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                previewPane
                    .frame(width: geometry.size.width * 0.6)
                Divider()
                mediaTray
                    .frame(width: geometry.size.width * 0.4)
            }
        }
    }

    private var previewPane: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: model.togglePlayback) {
                ZStack(alignment: .bottom) {
                    MacVideoPlayerView(player: model.player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !model.isPlaying {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 8)
                    }
                    if model.isProcessing {
                        Color.black.opacity(0.35)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }

                    // Overlay controls for max video viewing space (almost full but no clip)
                    playbackControls
                        .padding(6)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 4)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isPlaying ? "Pause video" : "Play video")

            Button {
                isFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .padding(6)
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
            }
        }
    }

    private var mediaTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Media Tray", systemImage: "tray.full")
                    .font(.headline)
                Text("\(model.drafts.count) of 20")
                    .foregroundStyle(.secondary)
                Spacer()
                if isTrayDropTargeted {
                    Label("Drop clip", systemImage: "arrow.down.to.line")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    draftSection(
                        title: "Staged",
                        systemImage: "tray",
                        drafts: stagedDrafts,
                        emptyMessage: "Drag a timeline segment here or use Add All."
                    )
                    draftSection(
                        title: "Saved",
                        systemImage: "checkmark.circle",
                        drafts: savedDrafts,
                        emptyMessage: "Saved clips and stills remain here for resaving."
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background(.bar)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isTrayDropTargeted ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
                .padding(8)
        )
        .onDrop(
            of: [UTType.plainText],
            isTargeted: $isTrayDropTargeted,
            perform: receiveTimelineDrop
        )
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
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text("\(drafts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if drafts.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
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
        let isSelected = selectedDraftID == draft.id

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: draft.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 108)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Button("Remove \(draft.title)", systemImage: "xmark.circle.fill") {
                    model.removeDraft(id: draft.id)
                    if selectedDraftID == draft.id {
                        selectedDraftID = nil
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(7)
            }

            HStack(spacing: 8) {
                Image(systemName: draft.systemImage)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.rangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if draft.isSaved, let target = draft.savedTargetLabel {
                        Text("Saved in \(target)")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            TextField(
                draft.kind == .clip ? "Clip name" : "Still name",
                text: Binding(
                    get: { draft.displayName ?? "" },
                    set: { model.renameDraft(id: draft.id, to: $0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Save", systemImage: "square.and.arrow.down") {
                    selectedDraftID = draft.id
                    model.selectDraft(id: draft.id)
                    draftForSaving = draft
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                if draft.sourceSegmentID != nil {
                    Label("Timeline clip", systemImage: "scissors")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Timeline", systemImage: "scissors")
                    .font(.headline)
                Text("\(model.segments.count) segments")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()

                if splitToolActive {
                    Text("move cursor to cut")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }

                Button {
                    splitToolActive.toggle()
                } label: {
                    Label("Split", systemImage: "scissors")
                }
                .buttonStyle(.bordered)
                .tint(splitToolActive ? Color.accentColor : nil)

                Button("Still", systemImage: "camera") {
                    Task { await model.addStill() }
                }
                .disabled(model.duration == 0 || model.isProcessing)

                Button("Add All", systemImage: "tray.and.arrow.down") {
                    Task { await model.addAllSegmentsToTray() }
                }
                .disabled(model.segments.isEmpty || model.isProcessing)
            }

            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 4) {
                    timelineRuler(width: geometry.size.width)
                    timelineTrack(width: geometry.size.width)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .onChange(of: splitToolActive) { _, active in
            if !active {
                splitHoverX = nil
                if isSplitCursorPushed {
                    NSCursor.pop()
                    isSplitCursorPushed = false
                }
            }
        }
    }

    private func timelineRuler(width: CGFloat) -> some View {
        let tickCount = max(2, min(12, Int(width / 100)))

        return HStack(spacing: 0) {
            ForEach(0...tickCount, id: \.self) { index in
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 1, height: 6)
                    Text(timeString(model.duration * Double(index) / Double(tickCount)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            alignment: index == 0
                                ? .leading
                                : (index == tickCount ? .trailing : .center)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 24)
    }

    private func timelineTrack(width: CGFloat) -> some View {
        let trackHeight: CGFloat = 78
        let playheadX = xPosition(for: model.currentTime, width: width)

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(model.segments) { segment in
                    timelineSegment(segment, trackWidth: width)
                }
            }
            .frame(width: width, height: trackHeight)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.07))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2, height: trackHeight + 10)
                .position(
                    x: max(1, min(width - 1, playheadX)),
                    y: (trackHeight + 10) / 2
                )

            Color.clear
                .frame(width: 16, height: trackHeight + 10)
                .contentShape(Rectangle())
                .position(
                    x: max(8, min(width - 8, playheadX)),
                    y: (trackHeight + 10) / 2
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if playheadDragStartTime == nil {
                                playheadDragStartTime = model.currentTime
                            }
                            let startTime = playheadDragStartTime ?? model.currentTime
                            let offset = Double(value.translation.width / max(width, 1)) * model.duration
                            model.seek(to: startTime + offset)
                        }
                        .onEnded { _ in
                            playheadDragStartTime = nil
                        }
                )
                .allowsHitTesting(!splitToolActive)

            if splitToolActive {
                // Full width layer for split tool: follow cursor to scrub video, click to cut
                Color.clear
                    .frame(width: width, height: trackHeight + 10)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                splitHoverX = x
                                let t = positionToTime(x: x, width: width)
                                model.seek(to: t)
                            }
                            .onEnded { value in
                                let x = value.location.x
                                splitHoverX = nil
                                let t = positionToTime(x: x, width: width)
                                model.splitSegment(at: t)
                            }
                    )
                    .onHover { isHovering in
                        if splitToolActive && isHovering {
                            if !isSplitCursorPushed {
                                NSCursor.crosshair.push()
                                isSplitCursorPushed = true
                            }
                        } else if isSplitCursorPushed {
                            NSCursor.pop()
                            isSplitCursorPushed = false
                        }
                    }

                // Visual split preview line following the cursor
                if let x = splitHoverX {
                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 1, height: trackHeight + 10)
                        .position(x: x, y: (trackHeight + 10) / 2)
                }
            }
        }
        .frame(height: trackHeight + 10)
    }
    private func timelineSegment(
        _ segment: MacVideoTimelineSegment,
        trackWidth: CGFloat
    ) -> some View {
        let isSelected = selectedSegmentID == segment.id
        let width = trackWidth * CGFloat(segment.duration / max(model.duration, 0.01))

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.78) : Color.blue.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isSelected ? 0.85 : 0.25), lineWidth: 1)
                )

            VStack(spacing: 2) {
                Text("Segment \(segmentNumber(segment.id))")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(timeString(segment.startTime)) – \(timeString(segment.endTime))")
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
        }
        .frame(width: max(1, width), height: 78)
        .overlay(alignment: .leading) {
            boundaryHandle(
                label: "Adjust start of segment",
                systemImage: "chevron.compact.left"
            ) { translation in
                let newTime = segment.startTime + Double(translation / max(trackWidth, 1)) * model.duration
                model.setBoundary(.start, of: segment.id, to: newTime)
            }
        }
        .overlay(alignment: .trailing) {
            boundaryHandle(
                label: "Adjust end of segment",
                systemImage: "chevron.compact.right"
            ) { translation in
                let newTime = segment.endTime + Double(translation / max(trackWidth, 1)) * model.duration
                model.setBoundary(.end, of: segment.id, to: newTime)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSegmentID = segment.id
            model.seek(to: segment.startTime)
        }
        .onDrag {
            NSItemProvider(object: segment.id.uuidString as NSString)
        }
        .contextMenu {
            Button(role: .destructive) {
                model.removeSegment(id: segment.id)
                if selectedSegmentID == segment.id {
                    selectedSegmentID = nil
                }
            } label: {
                Label("Delete Segment", systemImage: "trash")
            }
        }
    }

    private func boundaryHandle(
        label: String,
        systemImage: String,
        onDrag: @escaping (CGFloat) -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 14, height: 62)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
            )
    }
    private func positionToTime(x: CGFloat, width: CGFloat) -> Double {
        guard model.duration > 0 else { return 0 }
        return model.duration * Double(max(0, min(width, x)) / max(width, 1))
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
                  let segmentID = UUID(uuidString: string) else {
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
        let bounded = max(0, seconds)
        let minutes = Int(bounded) / 60
        let wholeSeconds = Int(bounded) % 60
        let hundredths = Int((bounded - floor(bounded)) * 100)
        return String(format: "%d:%02d.%02d", minutes, wholeSeconds, hundredths)
    }
}
#endif
