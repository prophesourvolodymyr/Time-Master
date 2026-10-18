import SwiftUI
import UniformTypeIdentifiers
import TimeMasterCore

struct WorkoutMusicTimelineView: View {
    let workout: Workout
    @ObservedObject var library: MusicLibraryStore
    let otherWorkouts: [Workout]
    let onChange: (WorkoutMusicTimeline) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44
    @State private var zoom: Double = 2
    @State private var source: MusicDestination = .general
    @State private var draggedClip: WorkoutMusicClip?
    @State private var draggedItemID: UUID?
    @State private var movingClipID: UUID?
    @State private var ghost: WorkoutMusicClip?
    @State private var resizeID: UUID?
    @State private var resizeDuration: Double?
    @State private var resizeIntent = WorkoutMusicResizeIntent()
    @State private var snapped = false
    @State private var sheet: EditorSheet?
    @State private var importPresented = false
    @State private var importing = false
    @State private var message: String?
    @State private var copyCandidate: Workout?

    private var timeline: WorkoutMusicTimeline { workout.musicTimeline ?? .init() }
    private var items: [MusicLibraryItem] { library.items(for: source) }
    private var plannedEnd: Double { Double(workout.totalDuration) }
    private var canvasEnd: Double { max(plannedEnd, timeline.end) + max(120, plannedEnd * 0.2) }

    var body: some View {
        VStack(spacing: 8) {
            header
            GeometryReader { geometry in
                let trayWidth = max(controlSize, geometry.size.width * 0.23)
                HStack(alignment: .top, spacing: 8) {
                    timelineCanvas(viewport: geometry.size.height)
                        .frame(maxWidth: .infinity)
                    tray
                        .frame(width: trayWidth)
                }
            }
        }
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .task {
            library.adoptMusicManagerTracks()
            await library.refreshLocalDurations()
        }
        .sheet(item: $sheet) { destination in editorSheet(destination) }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio, .movie], allowsMultipleSelection: true) { result in
            importMusic(result)
        }
        .alert("Music", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .confirmationDialog("Replace this timeline with a copy?", isPresented: Binding(
            get: { copyCandidate != nil }, set: { if !$0 { copyCandidate = nil } }
        ), titleVisibility: .visible) {
            Button("Copy configuration") {
                if let configuration = copyCandidate?.musicTimeline { onChange(configuration.independentCopy()) }
                copyCandidate = nil
            }
        } message: {
            Text("The source workout stays unchanged. You can freely edit the copy here.")
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button(action: onClose) { Image(systemName: "chevron.right") }
                .buttonStyle(SpotlightCircleButtonStyle())
                .accessibilityLabel("Close music configuration")
            Text("Music").font(.headline).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Menu {
                Button("Zoom in", systemImage: "plus.magnifyingglass") { zoom = min(8, zoom * 1.5) }
                Button("Zoom out", systemImage: "minus.magnifyingglass") { zoom = max(0.5, zoom / 1.5) }
            } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(SpotlightCircleButtonStyle())
                .accessibilityLabel("Timeline zoom")
            Button { sheet = .copy } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(SpotlightCircleButtonStyle())
                .accessibilityLabel("Copy music configuration from another workout")
        }
    }

    private func timelineCanvas(viewport: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("Primary").frame(maxWidth: .infinity)
                Text("Background").frame(maxWidth: .infinity)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            ScrollView(.vertical) {
                GeometryReader { geometry in
                    let laneWidth = geometry.size.width / 2
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            var lines = Path()
                            for minute in 0...Int(canvasEnd / 60) {
                                let y = Double(minute * 60) * zoom
                                lines.move(to: CGPoint(x: 0, y: y))
                                lines.addLine(to: CGPoint(x: size.width, y: y))
                                context.draw(Text(musicTimestamp(Double(minute * 60)))
                                    .font(.caption2.monospacedDigit()).foregroundColor(.gray),
                                    at: CGPoint(x: 3, y: y + 2), anchor: .topLeading)
                            }
                            lines.move(to: CGPoint(x: laneWidth, y: 0))
                            lines.addLine(to: CGPoint(x: laneWidth, y: size.height))
                            context.stroke(lines, with: .color(Theme.separator), lineWidth: 1)
                        }
                        ForEach(WorkoutMusicLane.allCases) { lane in
                            Color.clear
                                .frame(width: laneWidth, height: max(viewport, canvasEnd * zoom))
                                .contentShape(Rectangle())
                                .gesture(SpatialTapGesture().onEnded { value in
                                    sheet = .add(lane, max(0, value.location.y / zoom))
                                })
                                .offset(x: lane == .primary ? 0 : laneWidth)
                        }
                        ForEach(timeline.clips) { clip in
                            clipView(clip, laneWidth: laneWidth)
                        }
                        if let ghost {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.textPrimary.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.textPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4])))
                                .overlay(alignment: .top) {
                                    Text("\(musicTimestamp(ghost.start)) · \(musicTimestamp(ghost.duration))")
                                        .font(.caption2.monospacedDigit()).padding(4)
                                }
                                .frame(width: max(0, laneWidth - 4), height: max(2, ghost.duration * zoom))
                                .offset(x: ghost.lane == .primary ? 2 : laneWidth + 2, y: ghost.start * zoom)
                                .allowsHitTesting(false)
                        }
                        VStack(spacing: 3) {
                            Rectangle().fill(Theme.textSecondary).frame(height: 1)
                            Text("Fallback · \(musicTimestamp(plannedEnd))")
                                .font(.caption2).foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 4).background(Theme.background)
                        }
                        .offset(y: plannedEnd * zoom)
                        .allowsHitTesting(false)
                    }
                    .onDrop(of: [workoutMusicDragType], delegate: TimelineMusicDrop(
                        laneWidth: laneWidth, zoom: zoom,
                        clip: draggedClip, isMoving: movingClipID != nil,
                        preview: { ghost = $0 },
                        commit: { place($0); clearDrag() }
                    ))
                }
                .frame(height: max(viewport, canvasEnd * zoom))
            }
            .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Free-positioned music timeline")
        }
    }

    private func clipView(_ clip: WorkoutMusicClip, laneWidth: CGFloat) -> some View {
        let duration = resizeID == clip.id ? resizeDuration ?? clip.duration : clip.duration
        let height = max(2, duration * zoom)
        return VStack(spacing: 0) {
            if height > controlSize {
                VStack(spacing: 4) {
                    Image(systemName: clip.tracks.count > 1 ? "square.grid.2x2" : "opticaldisc")
                        .font(.title3)
                    Text(clip.title).font(.caption2.weight(.medium)).lineLimit(2)
                    if height > controlSize * 2 {
                        Text(musicTimestamp(duration)).font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(6)
            }
            Spacer(minLength: 0)
        }
        .frame(width: max(0, laneWidth - 6), height: height)
        .background(clip.lane == .primary ? Theme.surface2 : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
            resizeID == clip.id && snapped ? Theme.restAccent : Theme.textPrimary.opacity(clip.lane == .primary ? 0.4 : 0.18), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { sheet = .edit(clip) }
        .contextMenu {
            Button("Edit timing and order", systemImage: "slider.horizontal.3") { sheet = .edit(clip) }
            Button("Replace music", systemImage: "arrow.triangle.2.circlepath") { sheet = .replace(clip.id) }
            Button(clip.lane == .primary ? "Move to background" : "Move to primary", systemImage: "arrow.left.arrow.right") {
                var moved = clip
                moved.lane = clip.lane == .primary ? .background : .primary
                save(moved)
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                var copy = clip
                copy.id = UUID()
                copy.start = clip.end
                save(copy)
            }
            Button("Remove", systemImage: "trash", role: .destructive) { remove(clip.id) }
        }
        .onDrag {
            draggedClip = clip
            movingClipID = clip.id
            draggedItemID = nil
            return workoutMusicDragProvider(clip.id)
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(Theme.textSecondary).frame(width: laneWidth * 0.3, height: 3)
                .frame(width: max(0, laneWidth - 6), height: min(controlSize * 0.6, height))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global).onChanged { value in
                    resizeID = clip.id
                    let proposed = clip.start + min(clip.sourceDuration, max(1, clip.duration + value.translation.height / zoom))
                    let adjusted = resizeIntent.adjustedEnd(proposed, boundaries: workout.musicBoundaries, tolerance: 8 / zoom)
                    let isSnapped = adjusted != proposed
                    if isSnapped && !snapped { musicEditorHaptic() }
                    snapped = isSnapped
                    resizeDuration = min(clip.sourceDuration, max(1, adjusted - clip.start))
                }.onEnded { _ in
                    var resized = clip
                    resized.duration = resizeDuration ?? clip.duration
                    save(resized)
                    resizeID = nil
                    resizeDuration = nil
                    resizeIntent = .init()
                    snapped = false
                })
                .accessibilityHidden(true)
        }
        .offset(x: clip.lane == .primary ? 3 : laneWidth + 3, y: clip.start * zoom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clip.title), \(clip.lane.rawValue), starts \(musicTimestamp(clip.start)), duration \(musicTimestamp(duration))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { sheet = .edit(clip) }
        .accessibilityAction(named: "Replace music") { sheet = .replace(clip.id) }
        .accessibilityAction(named: "Remove") { remove(clip.id) }
    }

    private var tray: some View {
        VStack(spacing: 8) {
            Menu {
                Picker("Music group", selection: $source) {
                    Text("General").tag(MusicDestination.general)
                    SwiftUI.Section("Workout types") { sourceChoices(.type) }
                    SwiftUI.Section("Workouts") { sourceChoices(.mine) }
                    SwiftUI.Section("Outdoor") { sourceChoices(.route) }
                }
                Button("Open Music Settings", systemImage: "gearshape") { sheet = .library }
            } label: {
                VStack(spacing: 4) {
                    Text("Library").font(.caption2.weight(.semibold))
                    Text(library.destinationName(source)).font(.caption2).lineLimit(2)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: controlSize)
            }
            .accessibilityLabel("Music tray source: \(library.destinationName(source))")
            ScrollView {
                LazyVStack(spacing: 12) {
                    if items.isEmpty {
                        Text("No music").font(.caption2).foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(items) { item in
                        Button { addFromTray(item) } label: {
                            VStack(spacing: 4) {
                                trayArtwork(item)
                                Text(item.title).font(.caption2).lineLimit(2)
                                if item.totalDuration > 0 {
                                    Text(musicTimestamp(item.totalDuration)).font(.caption2.monospacedDigit())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onDrag {
                            guard item.totalDuration > 0 else {
                                message = "Import audio with a known duration before adding it to the timeline."
                                return NSItemProvider()
                            }
                            draggedClip = item.musicClip()
                            draggedItemID = item.id
                            movingClipID = nil
                            return workoutMusicDragProvider(item.id)
                        }
                        .onDrop(of: [workoutMusicDragType], isTargeted: nil) { _ in
                            guard let draggedItemID, draggedItemID != item.id else { return false }
                            if item.isCollection {
                                _ = library.add(itemID: draggedItemID, toCollection: item.id)
                            } else {
                                _ = library.createFolder(named: "\(item.title) + \(library.item(id: draggedItemID)?.title ?? "Music")",
                                                         in: source, containing: [item.id, draggedItemID])
                            }
                            clearDrag()
                            musicEditorHaptic()
                            return true
                        }
                        .accessibilityHint("Add to the timeline. Drag onto another track to create a folder.")
                    }
                }.padding(.vertical, 4)
            }
            Button { importPresented = true } label: {
                if importing { ProgressView() } else { Image(systemName: "square.and.arrow.down") }
            }
            .frame(minWidth: controlSize, minHeight: controlSize)
            .disabled(importing)
            .accessibilityLabel("Import music into Settings and this tray")
        }
        .padding(.horizontal, 4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func sourceChoices(_ family: MusicDestinationFamily) -> some View {
        ForEach(library.destinations(for: family).filter {
            !library.itemIDs(for: $0).isEmpty
                || $0 == .workout(id: workout.id)
                || $0 == .workoutType(id: workout.type.id)
        }) { destination in
            Text(library.destinationName(destination)).tag(destination)
        }
    }

    @ViewBuilder
    private func trayArtwork(_ item: MusicLibraryItem) -> some View {
        let icon = item.artwork?.placeholderSystemImage ?? (item.isCollection ? "square.grid.2x2" : "opticaldisc")
        let localURL = item.artwork?.localFilename.map {
            $0.hasPrefix("/") ? URL(fileURLWithPath: $0)
                : MusicManager.shared.localMusicDirectoryURL.appendingPathComponent($0)
        }
        if let url = localURL ?? item.artwork?.remoteURL {
            AsyncCoverImage(url: url, fallbackIcon: icon, height: controlSize, overlayGradient: false)
                .frame(width: controlSize, height: controlSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: icon).font(.title2)
                .frame(width: controlSize, height: controlSize)
        }
    }

    @ViewBuilder
    private func editorSheet(_ destination: EditorSheet) -> some View {
        switch destination {
        case .edit(let clip):
            WorkoutMusicClipEditor(clip: clip) { updated in save(updated); sheet = nil }
        case .replace(let id):
            WorkoutMusicItemPicker(title: "Replace Music", items: library.items) { item in
                guard var existing = timeline.clips.first(where: { $0.id == id }) else { return }
                existing.replaceMusic(with: item.musicClip())
                save(existing)
                sheet = nil
            }
        case .add(let lane, let start):
            WorkoutMusicItemPicker(title: "Add Music", items: library.items) { item in
                save(item.musicClip(lane: lane, start: start))
                sheet = nil
            }
        case .copy:
            NavigationStack {
                List(otherWorkouts.filter { $0.id != workout.id && $0.musicTimeline != nil }) { candidate in
                    Button {
                        sheet = nil
                        if timeline.clips.isEmpty {
                            if let configuration = candidate.musicTimeline { onChange(configuration.independentCopy()) }
                        } else {
                            copyCandidate = candidate
                        }
                    } label: {
                        HStack {
                            Image(systemName: "music.note.list")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.name).foregroundStyle(Theme.textPrimary)
                                Text("\(candidate.musicTimeline?.clips.count ?? 0) clips · \(musicTimestamp(candidate.musicTimeline?.end ?? 0))")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }.padding(.vertical, 6)
                    }.listRowBackground(Theme.surface)
                }
                .overlay {
                    if !otherWorkouts.contains(where: { $0.id != workout.id && $0.musicTimeline != nil }) {
                        Text("Configurations from your other workouts appear here.")
                            .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center).padding()
                    }
                }
                .scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Copy Configuration")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { sheet = nil } } }
            }
            .preferredColorScheme(.dark)
        case .library:
            MusicSettingsView(library: library)
        }
    }

    private func addFromTray(_ item: MusicLibraryItem) {
        guard item.totalDuration > 0 else {
            message = "This item has no available audio duration. Import its audio in Music Settings first."
            return
        }
        sheet = .edit(item.musicClip())
    }

    private func save(_ clip: WorkoutMusicClip) {
        var updated = timeline
        if let index = updated.clips.firstIndex(where: { $0.id == clip.id }) { updated.clips[index] = clip }
        else { updated.clips.append(clip) }
        onChange(updated)
    }

    private func place(_ clip: WorkoutMusicClip) {
        var placed = clip
        if movingClipID == nil { placed.id = UUID() }
        save(placed)
        musicEditorHaptic()
    }

    private func remove(_ id: UUID) {
        var updated = timeline
        updated.clips.removeAll { $0.id == id }
        onChange(updated)
    }

    private func clearDrag() {
        draggedClip = nil
        draggedItemID = nil
        movingClipID = nil
        ghost = nil
    }

    private func importMusic(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): message = error.localizedDescription
        case .success(let urls):
            importing = true
            Task { @MainActor in
                defer { importing = false }
                do {
                    for url in urls {
                        if ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased()) {
                            try await MusicManager.shared.importTrackAsync(from: url)
                        } else {
                            try MusicManager.shared.importTrack(from: url)
                        }
                    }
                } catch { message = error.localizedDescription }
                library.adoptMusicManagerTracks()
                await library.refreshLocalDurations()
                source = .general
            }
        }
    }

    private enum EditorSheet: Identifiable {
        case edit(WorkoutMusicClip), replace(UUID), add(WorkoutMusicLane, Double), copy, library
        var id: String {
            switch self {
            case .edit(let clip): return "edit-\(clip.id)"
            case .replace(let id): return "replace-\(id)"
            case .add(let lane, let time): return "add-\(lane)-\(time)"
            case .copy: return "copy"
            case .library: return "library"
            }
        }
    }
}

private struct TimelineMusicDrop: DropDelegate {
    let laneWidth: CGFloat
    let zoom: Double
    let clip: WorkoutMusicClip?
    let isMoving: Bool
    let preview: (WorkoutMusicClip?) -> Void
    let commit: (WorkoutMusicClip) -> Void

    func validateDrop(info: DropInfo) -> Bool { clip != nil }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        if var proposed = clip {
            proposed.start = max(0, (info.location.y / zoom).rounded())
            proposed.lane = info.location.x < laneWidth ? .primary : .background
            preview(proposed)
        }
        return DropProposal(operation: isMoving ? .move : .copy)
    }
    func dropExited(info: DropInfo) { preview(nil) }
    func performDrop(info: DropInfo) -> Bool {
        guard var placed = clip else { return false }
        placed.start = max(0, (info.location.y / zoom).rounded())
        placed.lane = info.location.x < laneWidth ? .primary : .background
        commit(placed)
        return true
    }
}

struct WorkoutMusicClipEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var clip: WorkoutMusicClip
    let onSave: (WorkoutMusicClip) -> Void
    private let maximumDuration: Double

    init(clip: WorkoutMusicClip, onSave: @escaping (WorkoutMusicClip) -> Void) {
        _clip = State(initialValue: clip)
        maximumDuration = max(clip.sourceDuration, clip.duration)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Timing") {
                    Picker("Layer", selection: $clip.lane) {
                        Text("Primary").tag(WorkoutMusicLane.primary)
                        Text("Background").tag(WorkoutMusicLane.background)
                    }
                    LabeledContent("Start · \(musicTimestamp(clip.start))") {
                        TextField("Seconds", value: $clip.start, format: .number)
                            .multilineTextAlignment(.trailing).accessibilityLabel("Start in seconds")
                    }
                    LabeledContent("Duration · \(musicTimestamp(clip.duration))") {
                        TextField("Seconds", value: $clip.duration, format: .number)
                            .multilineTextAlignment(.trailing).accessibilityLabel("Duration in seconds")
                    }
                    Text("Primary pauses background music. Background resumes where interrupted, within its remaining timeline space. On the same layer, later-starting clips take priority when they overlap.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                    if clip.duration > clip.sourceDuration {
                        Text("This replacement is shorter than the reserved space. Music ends when the audio finishes; the clip’s timing stays unchanged.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }.listRowBackground(Theme.surface)
                SwiftUI.Section("Track order · this clip only") {
                    ForEach(clip.tracks) { track in
                        HStack {
                            Image(systemName: "music.note")
                            Text(track.title)
                            Spacer()
                            Text(musicTimestamp(track.duration)).font(.caption.monospacedDigit())
                        }
                    }
                    .onMove { clip.tracks.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { clip.tracks.remove(atOffsets: $0) }
                }.listRowBackground(Theme.surface)
            }
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle(clip.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(clip) }
                        .disabled(!clip.start.isFinite || clip.start < 0 || !clip.duration.isFinite ||
                                  clip.duration <= 0 || clip.duration > maximumDuration || clip.tracks.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct WorkoutMusicItemPicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [MusicLibraryItem]
    let onSelect: (MusicLibraryItem) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(items.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { item in
                Button { onSelect(item) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isCollection ? "square.grid.2x2" : "opticaldisc")
                        Text(item.title).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(item.totalDuration > 0 ? musicTimestamp(item.totalDuration) : "Unavailable")
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }.padding(.vertical, 6)
                }
                .disabled(item.totalDuration <= 0)
                .listRowBackground(Theme.surface)
            }
            .overlay {
                if items.isEmpty {
                    Text("Import music in Settings or use the tray’s import button.")
                        .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center).padding()
                }
            }
            .searchable(text: $query, prompt: "Music and folders")
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

func musicEditorHaptic() {
    #if os(iOS)
    UISelectionFeedbackGenerator().selectionChanged()
    #endif
}

private let workoutMusicDragType = UTType(exportedAs: "com.timemaster.workout-music")

private func workoutMusicDragProvider(_ id: UUID) -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: workoutMusicDragType.identifier, visibility: .all) { completion in
        completion(Data(id.uuidString.utf8), nil)
        return nil
    }
    return provider
}
