#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct OutdoorMusicEditorView: View {
    @ObservedObject private var library: MusicLibraryStore
    let initialItem: MusicLibraryItem?
    let resetToken: Int
    let onMeasuredHeight: (CGFloat) -> Void
    let onImportLocalMusic: (() -> Void)?

    @ObservedObject private var musicManager: MusicManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .caption2) private var compactTitleSize: CGFloat = 9
    @FocusState private var searchFocused: Bool

    @State private var destinationID = ""
    @State private var destinationPreviewID = ""
    @State private var searchSourceID = ""
    @State private var searchSourcePreviewID = ""
    @State private var expandedItems = Set<UUID>()
    @State private var collectionDetailID: UUID?
    @State private var searchOpen = false
    @State private var query = ""
    @State private var searchResults: [MusicLibrarySearchResult] = []
    @State private var showingMainPicker = false
    @State private var showingSearchPicker = false
    @State private var searchTrayOffset: CGFloat = 0
    @State private var pendingRemovalItem: MusicLibraryItem?
    @State private var pendingRemovalDestination: MusicDestination?
    @State private var unavailableMessage: String?
    @State private var pendingTransfer: MusicTransfer?
    @State private var draggedPayload: OutdoorMusicDragPayload?
    @State private var dropTargetID: UUID?
    @State private var dropZone: OutdoorMusicDropZone = .center
    @State private var folderTargetID: UUID?
    @State private var dwellWorkItem: DispatchWorkItem?
    @State private var initialItemID: UUID?
    @State private var measuredListHeight: CGFloat = 0

    init(
        library: MusicLibraryStore,
        musicManager: MusicManager,
        initialItem: MusicLibraryItem? = nil,
        resetToken: Int = 0,
        onMeasuredHeight: @escaping (CGFloat) -> Void,
        onImportLocalMusic: (() -> Void)? = nil
    ) {
        self.initialItem = initialItem
        self.resetToken = resetToken
        self.onMeasuredHeight = onMeasuredHeight
        self._library = ObservedObject(wrappedValue: library)
        self.onImportLocalMusic = onImportLocalMusic
        self._musicManager = ObservedObject(wrappedValue: musicManager)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                header
                if let collectionDetailID {
                    collectionDetail(for: collectionDetailID)
                        .frame(maxHeight: .infinity)
                } else {
                    libraryList
                        .frame(maxHeight: .infinity)
                }
                if searchOpen {
                    searchTray
                        .layoutPriority(1)
                        .offset(y: searchTrayOffset)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                }
                if let pendingTransfer {
                    transferPanel(for: pendingTransfer)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showingMainPicker {
                mainDestinationPicker
                    .padding(.top, 40)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.84, anchor: .topLeading).combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .preference(key: OutdoorMusicEditorTotalHeightKey.self, value: desiredEditorHeight)
        .onPreferenceChange(OutdoorMusicEditorTotalHeightKey.self) { height in
            guard height > 1 else { return }
            onMeasuredHeight(min(720, max(188, height)))
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: showingMainPicker)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: showingSearchPicker)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: searchOpen)
        .onAppear(perform: configureInitialState)
        .onChange(of: resetToken) { _ in
            searchFocused = false
            searchOpen = false
            searchTrayOffset = 0
            showingMainPicker = false
            showingSearchPicker = false
        }
        .onDisappear { dwellWorkItem?.cancel() }
        .alert(
            "Remove Music",
            isPresented: Binding(
                get: { pendingRemovalItem != nil },
                set: { if !$0 { pendingRemovalItem = nil; pendingRemovalDestination = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let item = pendingRemovalItem, let destination = pendingRemovalDestination {
                    _ = library.remove(itemID: item.id, from: destination)
                }
                pendingRemovalItem = nil
                pendingRemovalDestination = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRemovalItem = nil
                pendingRemovalDestination = nil
            }
        } message: {
            Text("Remove \(pendingRemovalItem?.title ?? "this item") from \(pendingRemovalDestination.map(library.destinationName) ?? "this section")?")
        }
        .alert(
            "Music unavailable",
            isPresented: Binding(
                get: { unavailableMessage != nil },
                set: { if !$0 { unavailableMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { unavailableMessage = nil }
        } message: {
            Text(unavailableMessage ?? "This item cannot play right now.")
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Button {
                destinationPreviewID = activeDestination.id
                showingMainPicker.toggle()
                showingSearchPicker = false
                if searchOpen {
                    closeSearchTray()
                }
                searchFocused = false
            } label: {
                Text(library.destinationName(activeDestination).uppercased())
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(minWidth: 60, maxWidth: 118, minHeight: 36)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Choose music section")
            .accessibilityValue(library.destinationName(activeDestination))
            .accessibilityHint("Choose a section from Music Settings.")

            Spacer(minLength: 0)

            if musicManager.currentTrack != nil {
                Button { musicManager.stopPlayback() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Stop playback")
                .accessibilityHint("Stops playback and removes the compact player")
            }

            Button {
                showingMainPicker = false
                showingSearchPicker = false
                if searchOpen {
                    closeSearchTray()
                } else {
                    withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) {
                        searchOpen = true
                        searchTrayOffset = 0
                    }
                    searchFocused = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel(searchOpen ? "Close music search tray" : "Search music")
            .accessibilityHint("Opens inline search in the music editor.")
        }
        .accessibilityElement(children: .contain)
    }
    private var mainDestinationPicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Music section")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                Button {
                    showingMainPicker = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Close music section chooser")
            }

            Picker("Music section", selection: $destinationPreviewID) {
                ForEach(destinationChoices) { choice in
                    Text(choice.name).tag(choice.id)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 118)
            .accessibilityLabel("Music section wheel")
            .accessibilityValue(destinationChoiceName(destinationPreviewID))

            Button("Use \(destinationChoiceName(destinationPreviewID))") {
                commitDestination(destinationPreviewID)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .frame(maxWidth: .infinity)
            .disabled(destinationChoices.isEmpty)
        }
        .padding(9)
        .frame(width: 184)
        .background(
            reduceTransparency ? Theme.surface2 : Color.black.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Music section chooser")
    }

    private var libraryList: some View {
        let items = library.items(for: activeDestination, includingSessionReferences: true)
        return ScrollView {
            VStack(spacing: 8) {
                if items.isEmpty { emptyDestination }
                else { ForEach(items) { item in musicRow(item, destination: activeDestination) } }
            }
            .padding(.vertical, 4)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: OutdoorMusicEditorContentHeightKey.self, value: proxy.size.height)
                }
            }
            .onDrop(of: [UTType.text], delegate: destinationDropDelegate(destination: activeDestination))
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(OutdoorMusicEditorContentHeightKey.self) { height in
            measuredListHeight = height
        }
        .accessibilityLabel("Music in \(library.destinationName(activeDestination))")
    }

    private var emptyDestination: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("No music in \(library.destinationName(activeDestination))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(onImportLocalMusic == nil ? "Add real music in Music Settings, or search another section." : "Import local music or add a real item from another section.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let onImportLocalMusic {
                Button("Import Local Music", action: onImportLocalMusic).buttonStyle(OutdoorPineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private func musicRow(_ item: MusicLibraryItem, destination: MusicDestination) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                OutdoorMusicArtworkView(artworkReference: artworkString(item.artwork), size: 44)
                Button {
                    if item.isCollection { collectionDetailID = item.id } else { play(item) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(item.isCollection ? item.kind.rawValue.capitalized : sourceName(for: item))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        if let status = unavailableStatus(for: item) {
                            Text(status)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.restAccent)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCollection ? "Open \(item.title)" : "Play \(item.title)")
                Text(library.formattedDuration(item.totalDuration))
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Drag \(item.title)")
                    .accessibilityHint("Drag to reorder, move, or group this music item.")
                if item.isCollection {
                    Button { toggleExpanded(item.id) } label: {
                        Image(systemName: expandedItems.contains(item.id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel(expandedItems.contains(item.id) ? "Collapse \(item.title)" : "Expand \(item.title)")
                    .accessibilityValue(expandedItems.contains(item.id) ? "Expanded" : "Collapsed")
                } else {
                    Button { play(item) } label: {
                        Image(systemName: musicManager.currentTrackID == item.id.uuidString.lowercased() && musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.restAccent)
                    .accessibilityLabel(musicManager.currentTrackID == item.id.uuidString.lowercased() && musicManager.isPlaying ? "Pause \(item.title)" : "Play \(item.title)")
                }
                Button {
                    pendingRemovalItem = item
                    pendingRemovalDestination = destination
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Remove \(item.title) from \(library.destinationName(destination))")
            }
            .padding(7)
            if expandedItems.contains(item.id), item.isCollection {
                VStack(spacing: 0) {
                    ForEach(Array(item.tracks.enumerated()), id: \.element.id) { index, track in collectionTrackRow(track, collection: item, index: index) }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 7)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(rowBorderColor(for: item), lineWidth: folderTargetID == item.id ? 1.4 : 1)
        }
        .overlay(alignment: .top) {
            if dropTargetID == item.id && dropZone == .before { Capsule().fill(Theme.restAccent).frame(height: 2).padding(.horizontal, 9).offset(y: -2) }
        }
        .overlay(alignment: .bottom) {
            if dropTargetID == item.id && dropZone == .after { Capsule().fill(Theme.restAccent).frame(height: 2).padding(.horizontal, 9).offset(y: 2) }
        }
        .overlay(alignment: .topTrailing) {
            if folderTargetID == item.id {
                Text("Group")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.restAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.restAccent.opacity(0.15), in: Capsule())
                    .padding(.top, 5)
                    .padding(.trailing, 48)
            }
        }
        .opacity(draggedPayload?.itemID == item.id ? 0.3 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onDrag {
            let payload = OutdoorMusicDragPayload(itemID: item.id, sourceID: destination.id, isSearchResult: false)
            draggedPayload = payload
            return NSItemProvider(object: payload.encoded as NSString)
        } preview: {
            HStack(spacing: 8) {
                OutdoorMusicArtworkView(artworkReference: artworkString(item.artwork), size: 40)
                Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
            }
            .padding(7)
            .frame(width: 210, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onDrop(of: [UTType.text], delegate: rowDropDelegate(item: item, destination: destination))
        .accessibilityElement(children: .contain)
    }

    private func collectionTrackRow(_ track: MusicCollectionTrack, collection: MusicLibraryItem, index: Int) -> some View {
        HStack(spacing: 8) {
            OutdoorMusicArtworkView(artworkReference: artworkString(track.artwork), size: 38)
            Button { play(collection, startingAt: index) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Track \(index + 1)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Text(library.formattedDuration(track.duration))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            Button { play(collection, startingAt: index) } label: {
                Image(systemName: musicManager.currentTrackID == track.id.uuidString.lowercased() && musicManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.restAccent)
            .accessibilityLabel("Play \(track.title)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(reduceTransparency ? Theme.surface : Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func collectionDetail(for id: UUID) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { collectionDetailID = nil } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Back to music destination")
                Text(library.item(id: id)?.title ?? "Collection")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if let collection = library.item(id: id) {
                ScrollView {
                    VStack(spacing: 7) {
                        if collection.tracks.isEmpty {
                            Text("This collection has no real tracks yet.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 90)
                        } else {
                            ForEach(Array(collection.tracks.enumerated()), id: \.element.id) { index, track in collectionTrackRow(track, collection: collection, index: index) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collection detail")
    }


    private var searchTray: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Theme.textPrimary.opacity(0.62))
                .frame(width: 44, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                TextField("Search music", text: $query)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 9)
                    .frame(height: 32)
                    .background(
                        reduceTransparency ? Theme.surface : Color.black.opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit(executeSearch)
                    .accessibilityLabel("Search music library")

                Button(action: executeSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                .accessibilityLabel("Search")

                if importSourceDestinations.isEmpty {
                    Text("No sections")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .frame(minWidth: 54, maxWidth: 92, minHeight: 32)
                } else {
                    Button {
                        searchSourcePreviewID = searchSourceID
                        showingSearchPicker.toggle()
                        showingMainPicker = false
                    } label: {
                        Text(library.destinationName(searchSourceDestination).uppercased())
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .frame(minWidth: 54, maxWidth: 92, minHeight: 32)
                    }
                    .buttonStyle(OutdoorPineButtonStyle())
                    .accessibilityLabel("Choose music import source")
                    .accessibilityValue(library.destinationName(searchSourceDestination))
                }
            }

            if showingSearchPicker, !importSourceDestinations.isEmpty {
                VStack(spacing: 4) {
                    Picker("Music import source", selection: $searchSourcePreviewID) {
                        ForEach(importSourceDestinations) { destination in
                            Text(library.destinationName(destination)).tag(destination.id)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 118)
                    .accessibilityLabel("Music import source wheel")
                    .accessibilityValue(destinationChoiceName(searchSourcePreviewID, in: importSourceDestinations))

                    Button("Use \(destinationChoiceName(searchSourcePreviewID, in: importSourceDestinations))") {
                        searchSourceID = searchSourcePreviewID
                        showingSearchPicker = false
                        searchResults = []
                    }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    .frame(maxWidth: .infinity)
                }
                .padding(6)
                .background(
                    reduceTransparency ? Theme.surface2 : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }

            if searchResults.isEmpty {
                Text(
                    importSourceDestinations.isEmpty
                        ? "Add music to a workout type in Music Settings to search it."
                        : query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Search \(library.destinationName(searchSourceDestination)) music."
                            : "No matching music in \(library.destinationName(searchSourceDestination))."
                )
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .multilineTextAlignment(.center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(searchResults) { result in
                            searchResult(result)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(8)
        .background(
            reduceTransparency ? Theme.surface2 : Color.black.opacity(0.76),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Music search tray")
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    guard value.translation.height > 0,
                          value.translation.height > abs(value.translation.width)
                    else { return }
                    searchTrayOffset = min(260, value.translation.height)
                }
                .onEnded { value in
                    let momentum = max(0, value.predictedEndTranslation.height - value.translation.height)
                    let projected = searchTrayOffset + momentum
                    if projected > 90 {
                        closeSearchTray()
                    } else {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.9)) {
                            searchTrayOffset = 0
                        }
                    }
                }
        )
    }

    private func closeSearchTray() {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) {
            searchOpen = false
            searchFocused = false
            showingSearchPicker = false
            searchTrayOffset = 0
        }
    }

    private func searchResult(_ result: MusicLibrarySearchResult) -> some View {
        Button {
            play(result.item)
        } label: {
            VStack(spacing: 5) {
                OutdoorMusicArtworkView(
                    artworkReference: artworkString(result.item.artwork),
                    size: 52
                )
                OutdoorMusicMarqueeText(
                    text: result.item.title,
                    font: .system(size: min(compactTitleSize, 15), weight: .semibold, design: .rounded)
                )
                .frame(width: 76)
            }
            .frame(width: 86)
            .padding(5)
            .background(reduceTransparency ? Theme.surface : Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(result.item.title)")
        .onDrag {
            let payload = OutdoorMusicDragPayload(
                itemID: result.item.id,
                sourceID: result.destination.id,
                isSearchResult: true
            )
            draggedPayload = payload
            return NSItemProvider(object: payload.encoded as NSString)
        } preview: {
            HStack(spacing: 8) {
                OutdoorMusicArtworkView(artworkReference: artworkString(result.item.artwork), size: 40)
                Text(result.item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(7)
            .frame(width: 210, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityHint("Double tap to play. Drag to import this item into another music section for this workout.")
    }

    private var desiredEditorHeight: CGFloat {
        let libraryHeight = collectionDetailID == nil
            ? min(380, max(112, measuredListHeight))
            : 280
        let trayHeight: CGFloat
        if searchOpen {
            trayHeight = showingSearchPicker && !importSourceDestinations.isEmpty ? 280 : 112
        } else {
            trayHeight = 0
        }
        let transferHeight: CGFloat = pendingTransfer == nil ? 0 : 112
        return 8 + 36 + 8 + libraryHeight + trayHeight + transferHeight + 20
    }

    private var editorSectionDestinations: [MusicDestination] {
        let destinations = library.destinations(for: .type)
        let populated = destinations.filter { !library.items(for: $0).isEmpty }
        return populated.isEmpty ? destinations : populated
    }

    private var activeDestination: MusicDestination {
        if let destination = editorSectionDestinations.first(where: { $0.id == destinationID }) {
            return destination
        }
        if let selected = library.selectedDestination(for: .type),
           editorSectionDestinations.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return editorSectionDestinations.first ?? .general
    }

    private var searchSourceDestination: MusicDestination {
        importSourceDestinations.first(where: { $0.id == searchSourceID })
            ?? importSourceDestinations.first(where: { $0.id == activeDestination.id })
            ?? importSourceDestinations.first
            ?? activeDestination
    }

    private var importSourceDestinations: [MusicDestination] {
        library.destinations(for: .type)
            .filter { !library.items(for: $0).isEmpty }
    }

    private var destinationChoices: [OutdoorMusicDestinationChoice] {
        editorSectionDestinations.map {
            OutdoorMusicDestinationChoice(
                id: $0.id,
                name: library.destinationName($0),
                icon: destinationIcon(for: $0)
            )
        }
    }

    private func destinationChoiceName(_ id: String) -> String {
        destinationChoices.first(where: { $0.id == id })?.name
            ?? library.destinationName(activeDestination)
    }

    private func destinationIcon(for destination: MusicDestination) -> String {
        switch destination {
        case .general:
            return "music.note.list"
        case .workoutType(let id):
            return library.workoutType(for: id)?.iconName ?? "figure.run"
        case .workout:
            return "figure.strengthtraining.traditional"
        }
    }

    private func destinationChoiceName(_ id: String, in destinations: [MusicDestination]) -> String {
        destinations.first(where: { $0.id == id }).map(library.destinationName)
            ?? library.destinationName(activeDestination)
    }

    private func configureInitialState() {
        guard initialItemID == nil else { return }
        initialItemID = initialItem?.id

        let selectedID = library.selectedDestination(for: .type)?.id
        let section = editorSectionDestinations.first(where: { $0.id == selectedID })
            ?? editorSectionDestinations.first
        if let section {
            destinationID = section.id
            destinationPreviewID = section.id
            library.select(destination: section)
        }

        let source = importSourceDestinations.first(where: { $0.id == section?.id })
            ?? importSourceDestinations.first
        searchSourceID = source?.id ?? ""
        searchSourcePreviewID = source?.id ?? ""
    }

    private func commitDestination(_ id: String) {
        guard let destination = editorSectionDestinations.first(where: { $0.id == id }) else { return }
        destinationID = id
        destinationPreviewID = id
        library.select(destination: destination)
        showingMainPicker = false
        collectionDetailID = nil
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.28)) {
            if expandedItems.contains(id) { expandedItems.remove(id) }
            else { expandedItems.insert(id) }
        }
    }

    private func transferPanel(for transfer: MusicTransfer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move \(library.item(id: transfer.itemID)?.title ?? "music")?")
                .font(.subheadline.weight(.semibold))
            Text("Choose whether to remove it from \(library.destinationName(transfer.source)) or keep it in both sections.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                Button("Move") {
                    _ = library.commitWorkoutTransfer(transfer, choice: .move)
                    pendingTransfer = nil
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                Button("Keep Both") {
                    _ = library.commitWorkoutTransfer(transfer, choice: .duplicate)
                    pendingTransfer = nil
                }
                .buttonStyle(OutdoorPineButtonStyle())
                Button("Cancel") {
                    pendingTransfer = nil
                }
                .buttonStyle(OutdoorPineButtonStyle())
            }
        }
        .padding(10)
        .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Music transfer decision")
    }


    private func executeSearch() {
        let normalized = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { searchResults = []; return }
        let destination = searchSourceDestination
        searchResults = library.items(for: destination, includingSessionReferences: false).compactMap { item in
            let itemMatch = item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased().contains(normalized)
            let matchingTracks = item.tracks.filter { track in track.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased().contains(normalized) }.map(\.id)
            guard itemMatch || !matchingTracks.isEmpty else { return nil }
            return MusicLibrarySearchResult(item: item, destination: destination, matchingTrackIDs: matchingTracks, matchesFolder: itemMatch && item.isCollection)
        }
    }

    private func play(_ item: MusicLibraryItem, startingAt index: Int = 0) {
        switch musicManager.play(item, startingAt: index) {
        case .started: unavailableMessage = nil
        case .unavailable(let reason): unavailableMessage = unavailableMessage(for: reason, item: item)
        }
    }

    private func unavailableMessage(for reason: MusicPlaybackUnavailableReason, item: MusicLibraryItem) -> String {
        switch reason {
        case .missingLocalFile: return "\(item.title) is still in your library, but its local file is missing."
        case .providerUnavailable(let provider): return "\(provider.displayName) is not configured for playback on this device."
        case .unsupportedSource: return "\(item.title) is not playable from its current source."
        case .noPlayableSource: return "\(item.title) has no playable source yet."
        }
    }

    private func unavailableStatus(for item: MusicLibraryItem) -> String? {
        switch musicManager.availability(for: item) {
        case .idle, .playable: return nil
        case .unavailable(let reason):
            switch reason {
            case .providerUnavailable(let provider): return "Unavailable · \(provider.displayName)"
            case .missingLocalFile: return "Unavailable · file missing"
            case .unsupportedSource: return "Unavailable · unsupported"
            case .noPlayableSource: return "Unavailable · no playable source"
            }
        }
    }

    private func sourceName(for item: MusicLibraryItem) -> String {
        if let provider = item.source.provider { return provider.displayName }
        return item.localReference == nil ? "Unavailable source" : "Local"
    }

    private func artworkString(_ artwork: MusicArtworkReference?) -> String? {
        if let local = artwork?.localFilename { return local }
        if let remote = artwork?.remoteURL { return remote.absoluteString }
        return artwork?.placeholderSystemImage.map { "sf:\($0)" }
    }


    private func rowBorderColor(for item: MusicLibraryItem) -> Color {
        if folderTargetID == item.id { return Theme.restAccent.opacity(0.78) }
        if initialItemID == item.id { return Theme.restAccent.opacity(0.5) }
        return Color.white.opacity(0.1)
    }

    private func rowDropDelegate(item: MusicLibraryItem, destination: MusicDestination) -> OutdoorMusicDropDelegate {
        OutdoorMusicDropDelegate(
            onEntered: { beginDropTarget(item.id, destination: destination) },
            onUpdated: { updateDropTarget(item.id, destination: destination, location: $0) },
            onExited: { clearDropTarget(item.id) },
            onPerform: { providers, location in performDrop(providers, destination: destination, target: item, location: location) }
        )
    }

    private func destinationDropDelegate(destination: MusicDestination) -> OutdoorMusicDropDelegate {
        OutdoorMusicDropDelegate(
            onEntered: { dropTargetID = nil; folderTargetID = nil },
            onUpdated: { _ in dropZone = .append },
            onExited: { clearDropTarget(nil) },
            onPerform: { providers, _ in performDrop(providers, destination: destination, target: nil, location: .zero) }
        )
    }

    private func beginDropTarget(_ id: UUID, destination: MusicDestination) {
        dropTargetID = id
        dropZone = .center
        folderTargetID = nil
        dwellWorkItem?.cancel()
        guard canGroupDraggedItem(with: id, in: destination) else { return }
        let work = DispatchWorkItem {
            guard dropTargetID == id, dropZone == .center else { return }
            folderTargetID = id
        }
        dwellWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: work)
    }

    private func updateDropTarget(_ id: UUID, destination: MusicDestination, location: CGPoint) {
        guard dropTargetID == id else {
            beginDropTarget(id, destination: destination)
            return
        }
        let nextZone: OutdoorMusicDropZone
        if location.y < 19 { nextZone = .before }
        else if location.y > 47 { nextZone = .after }
        else { nextZone = .center }
        if nextZone != dropZone {
            dropZone = nextZone
            folderTargetID = nil
            dwellWorkItem?.cancel()
            if nextZone == .center, canGroupDraggedItem(with: id, in: destination) {
                let work = DispatchWorkItem {
                    guard dropTargetID == id, dropZone == .center else { return }
                    folderTargetID = id
                }
                dwellWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: work)
            }
        }
    }

    private func canGroupDraggedItem(with targetID: UUID, in destination: MusicDestination) -> Bool {
        guard let payload = draggedPayload,
              !payload.isSearchResult,
              payload.itemID != targetID,
              self.destination(for: payload.sourceID) == destination else {
            return false
        }
        return true
    }
    private func clearDropTarget(_ id: UUID?) {
        if let id, dropTargetID != id { return }
        dwellWorkItem?.cancel()
        dwellWorkItem = nil
        dropTargetID = nil
        folderTargetID = nil
        dropZone = .center
        draggedPayload = nil
    }

    private func performDrop(_ providers: [NSItemProvider], destination: MusicDestination, target: MusicLibraryItem?, location: CGPoint) {
        decodePayload(providers) { payload in
            let position = insertionPosition(destination: destination, target: target)
            applyDrop(payload, destination: destination, target: target, position: position)
            clearDropTarget(nil)
        }
    }

    private func insertionPosition(destination: MusicDestination, target: MusicLibraryItem?) -> Int? {
        let ids = library.itemIDs(for: destination)
        guard let target else { return ids.count }
        guard let index = ids.firstIndex(of: target.id) else { return ids.count }
        switch dropZone {
        case .before: return index
        case .after: return index + 1
        case .center: return index
        case .append: return ids.count
        }
    }

    private func applyDrop(_ payload: OutdoorMusicDragPayload, destination: MusicDestination, target: MusicLibraryItem?, position: Int?) {
        guard let source = self.destination(for: payload.sourceID), let item = library.item(id: payload.itemID) else { return }
        if payload.isSearchResult {
            guard source != destination else { return }
            _ = library.importForSession(itemID: item.id, from: source, to: destination, at: position)
            return
        }
        if folderTargetID == target?.id,
           let target,
           payload.itemID != target.id,
           source == destination {
            merge(item: item, into: target, destination: destination)
            return
        }
        let insertion = position ?? library.itemIDs(for: destination).count
        if source == destination {
            let oldIndex = library.itemIDs(for: destination).firstIndex(of: item.id) ?? insertion
            let adjusted = oldIndex < insertion ? max(0, insertion - 1) : insertion
            _ = library.reorder(itemID: item.id, in: destination, to: adjusted)
        } else if let transfer = library.prepareWorkoutTransfer(itemID: item.id, from: source, to: destination, at: insertion) {
            pendingTransfer = transfer
        } else {
            _ = library.moveItem(item.id, from: source, to: destination, at: insertion)
        }
    }

    private func merge(item: MusicLibraryItem, into target: MusicLibraryItem, destination: MusicDestination) {
        if target.isCollection { _ = library.add(itemID: item.id, toCollection: target.id) }
        else { _ = library.createFolder(named: "\(target.title) and \(item.title)", in: destination, containing: [target.id, item.id]) }
    }

    private func decodePayload(_ providers: [NSItemProvider], completion: @escaping (OutdoorMusicDragPayload) -> Void) {
        guard let provider = providers.first else { return }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.text.identifier) { data, _ in
            guard let data, let encoded = String(data: data, encoding: .utf8), let payloadData = Data(base64Encoded: encoded), let payload = try? JSONDecoder().decode(OutdoorMusicDragPayload.self, from: payloadData) else { return }
            DispatchQueue.main.async { completion(payload) }
        }
    }

    private func destination(for id: String) -> MusicDestination? {
        let all = [.general] + library.routeDestinations + library.destinations(for: .type) + library.destinations(for: .mine)
        return all.first(where: { $0.id == id })
    }
}


private struct OutdoorMusicDestinationChoice: Identifiable {
    let id: String
    let name: String
    let icon: String
}

private struct OutdoorMusicDragPayload: Codable, Equatable {
    let itemID: UUID
    let sourceID: String
    let isSearchResult: Bool

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }

    init(itemID: UUID, sourceID: String, isSearchResult: Bool) {
        self.itemID = itemID
        self.sourceID = sourceID
        self.isSearchResult = isSearchResult
    }
}

private enum OutdoorMusicDropZone: Equatable {
    case before, after, center, append
}

private struct OutdoorMusicDropDelegate: DropDelegate {
    let onEntered: () -> Void
    let onUpdated: (CGPoint) -> Void
    let onExited: () -> Void
    let onPerform: ([NSItemProvider], CGPoint) -> Void
    func dropEntered(info: DropInfo) { onEntered() }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        onUpdated(info.location)
        return DropProposal(operation: .move)
    }
    func dropExited(info: DropInfo) { onExited() }
    func performDrop(info: DropInfo) -> Bool {
        onPerform(info.itemProviders(for: [UTType.text.identifier]), info.location)
        return true
    }
}

private struct OutdoorMusicEditorTotalHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct OutdoorMusicEditorContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
#endif
