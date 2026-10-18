import SwiftUI
import UniformTypeIdentifiers
import TimeMasterCore

struct WorkoutMusicTimelineView: View {
    let workout: Workout
    @ObservedObject var library: MusicLibraryStore
    let onChange: (WorkoutMusicTimeline) -> Void
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
    @State private var duplicateSuggestionID: UUID?
    @State private var sheet: EditorSheet?
    @State private var importPresented = false
    @State private var importing = false
    @State private var message: String?
    @State private var searching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var timeline: WorkoutMusicTimeline { workout.musicTimeline ?? .init() }
    private var items: [MusicLibraryItem] {
        let group = library.items(for: source)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? group : group.filter {
            $0.title.localizedStandardContains(query)
                || $0.tracks.contains { $0.title.localizedStandardContains(query) }
        }
    }
    private var plannedEnd: Double { Double(workout.totalDuration) }
    private var canvasEnd: Double { max(plannedEnd, timeline.end) + max(120, plannedEnd * 0.2) }
    private var editorMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9)
    }

    var body: some View {
        VStack(spacing: 8) {
            if searching {
                HStack {
                    TextField("Search music", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .submitLabel(.search)
                    Button {
                        searching = false
                        searchText = ""
                    } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("Close music search")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: controlSize)
            }
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
        .onChange(of: searching) { searchFocused = $0 }
        .accessibilityAction(named: "Return to workout editor") { onClose() }
        .sheet(item: $sheet) { destination in editorSheet(destination) }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio, .movie], allowsMultipleSelection: true) { result in
            importMusic(result)
        }
        .alert("Music", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }


    private var timelineToolbar: some View {
        floatingSurface(
            ViewThatFits(in: .horizontal) {
                timelineToolbarContent(showScale: true)
                timelineToolbarContent(showScale: false)
            }
            .padding(4)
        )
        .padding(8)
    }

    private func timelineToolbarContent(showScale: Bool) -> some View {
        HStack(spacing: 0) {
            Button(action: onClose) { sidebarIcon("chevron.left") }
                .accessibilityLabel("Return to workout editor")
            Rectangle().fill(Theme.textSecondary.opacity(0.5))
                .frame(width: 1, height: controlSize * 0.45)
                .padding(.horizontal, 3)
            Button { changeZoom(by: 0.5) } label: { sidebarIcon("minus.magnifyingglass") }
                .disabled(zoom <= 0.5 || resizeID != nil || ghost != nil)
                .accessibilityLabel("Zoom out timeline")
            if showScale {
                Text("\(Int(zoom / 2 * 100))%")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                    .accessibilityLabel("Timeline zoom")
            }
            Button { changeZoom(by: 2) } label: { sidebarIcon("plus.magnifyingglass") }
                .disabled(zoom >= 8 || resizeID != nil || ghost != nil)
                .accessibilityLabel("Zoom in timeline")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func floatingSurface<Content: View>(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: controlSize * 0.6, style: .continuous)
        if reduceTransparency {
            content.background(Theme.surface2, in: shape)
                .overlay(shape.strokeBorder(Theme.textSecondary.opacity(0.4), lineWidth: 1))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.textSecondary.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        }
    }

    private func changeZoom(by factor: Double) {
        withAnimation(editorMotion) {
            zoom = min(8, max(0.5, zoom * factor))
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
                            let interval = zoom >= 4 ? 15 : (zoom >= 2 ? 30 : 60)
                            for tick in 0...Int(canvasEnd / Double(interval)) {
                                let seconds = Double(tick * interval)
                                let y = seconds * zoom
                                lines.move(to: CGPoint(x: 0, y: y))
                                lines.addLine(to: CGPoint(x: size.width, y: y))
                                context.draw(Text(musicTimestamp(seconds))
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
                                    if duplicateSuggestionID != nil {
                                        showDuplicateSuggestion(nil)
                                    } else {
                                        sheet = .add(lane, max(0, value.location.y / zoom))
                                    }
                                })
                                .offset(x: lane == .primary ? 0 : laneWidth)
                        }
                        ForEach(timeline.clips) { clip in
                            clipView(clip, laneWidth: laneWidth)
                        }
                        if let ghost {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.toolbarOrange.opacity(0.14))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Theme.toolbarOrange.opacity(0.7), lineWidth: 1))
                                .overlay(alignment: .top) {
                                    clipIdentity(ghost, height: ghost.duration * zoom)
                                }
                                .frame(width: max(0, laneWidth - 4), height: max(2, ghost.duration * zoom))
                                .offset(x: ghost.lane == .primary ? 2 : laneWidth + 2, y: ghost.start * zoom)
                                .animation(editorMotion, value: ghost.lane)
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
                        if let duplicateSuggestionID,
                           let clip = timeline.clips.first(where: { $0.id == duplicateSuggestionID }) {
                            let duration = resizeID == clip.id ? resizeDuration ?? clip.duration : clip.duration
                            Button { duplicateBelow(clip) } label: {
                                Label("Duplicate below", systemImage: "plus.square.on.square")
                                    .font(.caption2.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .padding(6)
                                    .frame(width: max(0, laneWidth - 6))
                                    .frame(minHeight: controlSize)
                                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Theme.toolbarOrange.opacity(0.6), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.toolbarOrange)
                            .offset(x: clip.lane == .primary ? 3 : laneWidth + 3,
                                    y: (clip.start + duration) * zoom + 6)
                            .transition(.opacity)
                            .accessibilityLabel("Duplicate \(clip.title) below")
                        }
                    }
                    .onDrop(of: [workoutMusicDragType], delegate: TimelineMusicDrop(
                        laneWidth: laneWidth, zoom: zoom,
                        clip: draggedClip, isMoving: movingClipID != nil,
                        preview: { ghost = $0 },
                        commit: { clip in
                            withAnimation(editorMotion) { place(clip); clearDrag() }
                        }
                    ))
                }
                .frame(height: max(viewport, canvasEnd * zoom))
            }
            .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Free-positioned music timeline")
            .overlay(alignment: .bottomLeading) { timelineToolbar }
        }
    }

    private func clipView(_ clip: WorkoutMusicClip, laneWidth: CGFloat) -> some View {
        let duration = resizeID == clip.id ? resizeDuration ?? clip.duration : clip.duration
        let height = max(2, duration * zoom)
        return VStack(spacing: 0) {
            clipIdentity(clip, height: height, duration: duration)
            Spacer(minLength: 0)
        }
        .frame(width: max(0, laneWidth - 6), height: height)
        .background(clip.lane == .primary ? Theme.surface2 : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
            resizeID == clip.id && snapped ? Theme.restAccent : Theme.textPrimary.opacity(clip.lane == .primary ? 0.4 : 0.18), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { showDuplicateSuggestion(nil); sheet = .edit(clip) }
        .contextMenu {
            Button("Edit timing and order", systemImage: "slider.horizontal.3") { sheet = .edit(clip) }
            Button("Replace music", systemImage: "arrow.triangle.2.circlepath") { sheet = .replace(clip.id) }
            Button(clip.lane == .primary ? "Move to background" : "Move to primary", systemImage: "arrow.left.arrow.right") {
                var moved = clip
                moved.lane = clip.lane == .primary ? .background : .primary
                save(moved)
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicateBelow(clip) }
            Button("Remove", systemImage: "trash", role: .destructive) { remove(clip.id) }
        }
        .onDrag {
            duplicateSuggestionID = nil
            draggedClip = clip
            movingClipID = clip.id
            draggedItemID = nil
            return workoutMusicDragProvider(clip.id)
        } preview: {
            musicDragPreview(clip)
        }
        .opacity(movingClipID == clip.id && ghost != nil ? 0.35 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: movingClipID == clip.id && ghost != nil)
        .overlay(alignment: .bottom) {
            Capsule().fill(Theme.textSecondary).frame(width: laneWidth * 0.3, height: 3)
                .frame(width: max(0, laneWidth - 6), height: min(controlSize * 0.6, height), alignment: .bottom)
                .padding(.bottom, min(3, height * 0.1))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global).onChanged { value in
                    resizeID = clip.id
                    let requestedDuration = clip.duration + value.translation.height / zoom
                    let maximum = clip.sourceDuration
                    showDuplicateSuggestion(maximum > 0 && requestedDuration > maximum + 10 / zoom ? clip.id : nil)
                    let proposed = clip.start + min(maximum, max(1, requestedDuration))
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
        .overlay(alignment: .top) {
            if resizeID == clip.id && height < controlSize {
                Text(musicTimestamp(duration))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(4)
                    .background(Theme.surface2, in: Capsule())
                    .offset(y: -controlSize * 0.6)
                    .allowsHitTesting(false)
            }
        }
        .offset(x: clip.lane == .primary ? 3 : laneWidth + 3, y: clip.start * zoom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clip.title), \(clip.lane.rawValue), starts \(musicTimestamp(clip.start)), duration \(musicTimestamp(duration))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { sheet = .edit(clip) }
        .accessibilityAction(named: "Replace music") { sheet = .replace(clip.id) }
        .accessibilityAction(named: "Remove") { remove(clip.id) }
        .accessibilityAction(named: "Duplicate below") { duplicateBelow(clip) }
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
                sidebarIcon("music.note.list")
            }
            .accessibilityLabel("Music tray source: \(library.destinationName(source))")
            Button {
                searching.toggle()
                if !searching { searchText = "" }
            } label: { sidebarIcon("magnifyingglass") }
            .accessibilityLabel("Search music")
            sidebarDivider
            ScrollView {
                LazyVStack(spacing: 12) {
                    if items.isEmpty {
                        Text(searchText.isEmpty ? "No music" : "No matches").font(.caption2).foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(items) { item in
                        Button { sheet = .preview(item) } label: {
                            VStack(spacing: 4) {
                                WorkoutMusicCover(artwork: item.artwork ?? item.tracks.first?.artwork,
                                                  isCollection: item.isCollection, size: controlSize)
                                Text(item.title).font(.caption2).lineLimit(1)
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onDrag {
                            duplicateSuggestionID = nil
                            guard item.totalDuration > 0 else {
                                message = "Import audio with a known duration before adding it to the timeline."
                                return NSItemProvider()
                            }
                            draggedClip = item.musicClip()
                            draggedItemID = item.id
                            movingClipID = nil
                            return workoutMusicDragProvider(item.id)
                        } preview: {
                            musicDragPreview(draggedClip ?? item.musicClip())
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
                        .accessibilityHint("Preview music. Hold and drag to place it on the timeline or group it with another track.")
                        .accessibilityAction(named: "Add to timeline") { sheet = .edit(item.musicClip()) }
                    }
                }.padding(.vertical, 4)
            }
            sidebarDivider
            Button { importPresented = true } label: {
                if importing { ProgressView().frame(width: controlSize, height: controlSize) }
                else { sidebarIcon("square.and.arrow.down") }
            }
            .frame(minWidth: controlSize, minHeight: controlSize)
            .disabled(importing)
            .accessibilityLabel("Import music into Settings and this tray")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.separator).frame(width: 1)
        }
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

    private func sidebarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body.weight(.medium))
            .frame(width: controlSize, height: controlSize)
            .contentShape(Rectangle())
    }

    private var sidebarDivider: some View {
        Rectangle().fill(Theme.textSecondary.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 6)
            .accessibilityHidden(true)
    }

    private func musicDragPreview(_ clip: WorkoutMusicClip) -> some View {
        let item = clip.sourceItemID.flatMap { library.item(id: $0) }
        return HStack(spacing: 8) {
            WorkoutMusicCover(artwork: item?.artwork ?? item?.tracks.first?.artwork,
                              isCollection: clip.tracks.count > 1, size: controlSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text(musicTimestamp(clip.duration)).font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(10)
        .frame(width: controlSize * 4, alignment: .leading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.toolbarOrange.opacity(0.5), lineWidth: 1))
    }

    @ViewBuilder
    private func clipIdentity(_ clip: WorkoutMusicClip, height: CGFloat, duration: Double? = nil) -> some View {
        let duration = duration ?? clip.duration
        if height > 36 {
            let item = clip.sourceItemID.flatMap { library.item(id: $0) }
            let compact = height < controlSize * 1.5
            let cover = WorkoutMusicCover(
                artwork: item?.artwork ?? item?.tracks.first?.artwork,
                isCollection: clip.tracks.count > 1,
                size: compact ? min(controlSize * 0.5, height - 20) : min(controlSize, max(12, height - 54))
            )
            let layout = compact ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))
            layout {
                cover
                VStack(spacing: 2) {
                    Text(clip.title).font(.caption2.weight(.medium)).lineLimit(1)
                    Text(musicTimestamp(duration)).font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: max(0, height - 8), alignment: .top)
            .clipped()
        } else {
            Text(musicTimestamp(duration)).font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .frame(height: max(0, height - 8), alignment: .top)
                .clipped()
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
        case .preview(let item):
            WorkoutMusicPreviewSheet(item: item)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
        case .library:
            MusicSettingsView(library: library)
        }
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

    private func showDuplicateSuggestion(_ id: UUID?) {
        guard duplicateSuggestionID != id else { return }
        withAnimation(editorMotion) { duplicateSuggestionID = id }
        if id != nil { musicEditorHaptic() }
    }

    private func duplicateBelow(_ clip: WorkoutMusicClip) {
        var copy = clip
        copy.id = UUID()
        copy.start = clip.end
        withAnimation(editorMotion) {
            save(copy)
            duplicateSuggestionID = nil
        }
        musicEditorHaptic()
    }

    private func remove(_ id: UUID) {
        if duplicateSuggestionID == id { duplicateSuggestionID = nil }
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
        case edit(WorkoutMusicClip), replace(UUID), add(WorkoutMusicLane, Double), preview(MusicLibraryItem), library
        var id: String {
            switch self {
            case .edit(let clip): return "edit-\(clip.id)"
            case .replace(let id): return "replace-\(id)"
            case .add(let lane, let time): return "add-\(lane)-\(time)"
            case .preview(let item): return "preview-\(item.id)"
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
            proposed.start = max(0, info.location.y / zoom)
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
