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

    @State private var scope: OutdoorMusicEditorScope = .route
    @State private var destinationID = MusicDestination.run.id
    @State private var destinationPreviewID = MusicDestination.run.id
    @State private var searchSourceID = MusicDestination.run.id
    @State private var searchSourcePreviewID = MusicDestination.run.id
    @State private var expandedItems = Set<UUID>()
    @State private var collectionDetailID: UUID?
    @State private var searchOpen = false
    @State private var query = ""
    @State private var searchResults: [MusicLibrarySearchResult] = []
    @State private var showingMainPicker = false
    @State private var showingSearchPicker = false
    @State private var showingCreateCollection = false
    @State private var collectionName = ""
    @State private var collectionKind: MusicCollectionKind = .folder
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
        VStack(spacing: 8) {
            header
            scopeChooser
            if showingMainPicker { mainDestinationPicker }
            if let collectionDetailID {
                collectionDetail(for: collectionDetailID)
            } else {
                libraryList
            }
            if showingCreateCollection { createCollectionPanel }
            if searchOpen { searchTray }
            if let pendingTransfer { transferPanel(for: pendingTransfer) }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OutdoorMusicEditorTotalHeightKey.self,
                    value: proxy.size.height
                )
            }
        }
        .onPreferenceChange(OutdoorMusicEditorTotalHeightKey.self) { height in
            guard height > 1 else { return }
            onMeasuredHeight(min(720, max(188, height)))
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: showingMainPicker)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: showingSearchPicker)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.24), value: searchOpen)
        .onAppear(perform: configureInitialState)
        .onChange(of: scope) { _ in selectFirstDestinationForScope() }
        .onChange(of: resetToken) { _ in
            searchFocused = false
            searchOpen = false
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
                destinationPreviewID = destinationID
                showingMainPicker.toggle()
                showingSearchPicker = false
            } label: {
                HStack(spacing: 4) {
                    Text(library.destinationName(activeDestination).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: showingMainPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .frame(minWidth: 72, minHeight: 40)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Choose music destination")
            .accessibilityValue(library.destinationName(activeDestination))
            Spacer(minLength: 0)
            Button {
                showingCreateCollection.toggle()
                collectionName = ""
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Create folder or collection")
            if musicManager.currentTrack != nil {
                Button { musicManager.stopPlayback() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Stop playback")
                .accessibilityHint("Stops playback and removes the compact player")
            }
            Button {
                searchOpen.toggle()
                if searchOpen { searchFocused = true }
                else { searchFocused = false; showingSearchPicker = false }
            } label: {
                Image(systemName: searchOpen ? "xmark" : "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel(searchOpen ? "Close music search" : "Search music")
        }
        .accessibilityElement(children: .contain)
    }

    private var scopeChooser: some View {
        Picker("Music section", selection: $scope) {
            ForEach(OutdoorMusicEditorScope.allCases) { value in Text(value.title).tag(value) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Music library section")
        .accessibilityValue(scope.title)
    }

    private var mainDestinationPicker: some View {
        VStack(spacing: 5) {
            Picker("Music destination", selection: $destinationPreviewID) {
                ForEach(destinationChoices) { choice in Text(choice.name).tag(choice.id) }
            }
            .pickerStyle(.wheel)
            .frame(height: 142)
            .accessibilityLabel("Music destination wheel")
            .accessibilityValue(destinationChoiceName(destinationPreviewID))
            Button("Use \(destinationChoiceName(destinationPreviewID))") { commitDestination(destinationPreviewID) }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
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
                GeometryReader { proxy in Color.clear.preference(key: OutdoorMusicEditorContentHeightKey.self, value: proxy.size.height) }
            }
            .onDrop(of: [UTType.text], delegate: destinationDropDelegate(destination: activeDestination))
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: min(380, max(112, measuredListHeight)))
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

    private var createCollectionPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Folder or collection name", text: $collectionName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(reduceTransparency ? Theme.surface : Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .submitLabel(.done)
                Menu {
                    Button("Folder") { collectionKind = .folder }
                    Button("Playlist") { collectionKind = .playlist }
                    Button("Album") { collectionKind = .album }
                } label: {
                    Image(systemName: collectionKind == .folder ? "folder" : "rectangle.stack")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Collection kind")
                .accessibilityValue(collectionKind.rawValue.capitalized)
            }
            HStack(spacing: 8) {
                Button("Cancel") {
                    showingCreateCollection = false
                    collectionName = ""
                }
                .buttonStyle(OutdoorPineButtonStyle())
                Spacer(minLength: 0)
                Button("Create") { createCollection() }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            }
        }
        .padding(9)
        .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var searchTray: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                TextField("Search this section", text: $query)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(reduceTransparency ? Theme.surface : Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit(executeSearch)
                    .accessibilityLabel("Search music library")
                Button(action: executeSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                .accessibilityLabel("Search")
                Button {
                    searchSourcePreviewID = searchSourceID
                    showingSearchPicker.toggle()
                    showingMainPicker = false
                } label: {
                    Text(library.destinationName(searchSourceDestination).uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .frame(minWidth: 58, maxWidth: 78, minHeight: 38)
                }
                .buttonStyle(OutdoorPineButtonStyle())
                .accessibilityLabel("Search source section")
                .accessibilityValue(library.destinationName(searchSourceDestination))
            }
            if showingSearchPicker {
                VStack(spacing: 4) {
                    Picker("Search source", selection: $searchSourcePreviewID) {
                        ForEach(library.routeDestinations) { destination in Text(library.destinationName(destination)).tag(destination.id) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 118)
                    Button("Use \(destinationChoiceName(searchSourcePreviewID, in: library.routeDestinations))") {
                        searchSourceID = searchSourcePreviewID
                        showingSearchPicker = false
                        searchResults = []
                    }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    .frame(maxWidth: .infinity)
                }
                .padding(6)
                .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if searchResults.isEmpty {
                Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Search the real music in this section." : "No matching real music in \(library.destinationName(searchSourceDestination)).")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .multilineTextAlignment(.center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) { ForEach(searchResults) { result in searchResult(result) } }
                        .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(8)
        .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inline music search")
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

    private var activeDestination: MusicDestination {
        library.destinations(for: scope.family).first(where: { $0.id == destinationID })
            ?? library.destinations(for: scope.family).first
            ?? .run
    }

    private var searchSourceDestination: MusicDestination {
        library.routeDestinations.first(where: { $0.id == searchSourceID }) ?? .run
    }

    private var destinationChoices: [OutdoorMusicDestinationChoice] {
        library.destinations(for: scope.family).map { OutdoorMusicDestinationChoice(id: $0.id, name: library.destinationName($0), icon: destinationIcon(for: $0)) }
    }

    private func destinationChoiceName(_ id: String) -> String {
        destinationChoices.first(where: { $0.id == id })?.name ?? id
    }

    private func destinationIcon(for destination: MusicDestination) -> String {
        if let route = destination.routeDestination {
            switch route {
            case .run: return "figure.run"
            case .bike: return "figure.outdoor.cycle"
            case .walk: return "figure.walk"
            case .more: return "ellipsis"
            }
        }
        switch destination {
        case .general: return "music.note.list"
        case .workoutType(let id): return library.workoutType(for: id)?.iconName ?? "figure.run"
        case .workout: return "figure.strengthtraining.traditional"
        }
    }

    private func destinationChoiceName(_ id: String, in destinations: [MusicDestination]) -> String {
        destinations.first(where: { $0.id == id }).map(library.destinationName) ?? id
    }

    private func configureInitialState() {
        guard initialItemID == nil else { return }
        initialItemID = initialItem?.id
        let saved = library.selectedDestination(for: .route) ?? .run
        destinationID = saved.id
        destinationPreviewID = saved.id
        searchSourceID = saved.id
        searchSourcePreviewID = saved.id
        if let initialItem, let route = library.routeDestinations.first(where: { library.items(for: $0, includingSessionReferences: true).contains(initialItem) }) {
            destinationID = route.id
            destinationPreviewID = route.id
        }
    }

    private func selectFirstDestinationForScope() {
        let destinations = library.destinations(for: scope.family)
        guard !destinations.isEmpty else { return }
        let saved = library.selectedDestination(for: scope.family)
        let next = saved.flatMap { candidate in destinations.first(where: { $0.id == candidate.id }) } ?? destinations[0]
        destinationID = next.id
        destinationPreviewID = next.id
        library.select(destination: next)
    }

    private func commitDestination(_ id: String) {
        guard let destination = library.destinations(for: scope.family).first(where: { $0.id == id }) else { return }
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

    private func createCollection() {
        let name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        _ = library.createCollection(name: name, in: activeDestination, kind: collectionKind)
        collectionName = ""
        showingCreateCollection = false
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

enum OutdoorMusicEditorScope: String, CaseIterable, Identifiable {
    case route, type, mine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .route: return "Route"
        case .type: return "Type"
        case .mine: return "Mine"
        }
    }
    var family: MusicDestinationFamily {
        switch self {
        case .route: return .route
        case .type: return .type
        case .mine: return .mine
        }
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
