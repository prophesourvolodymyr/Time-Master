import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryScreen: View {
    @ObservedObject var library: MusicLibraryStore
    let importLocalMusic: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = MusicManager.shared
    @State private var isWorkoutFocused = false
    @State private var family: MusicDestinationFamily = .type
    @State private var expandedItems = Set<UUID>()
    @State private var playingItem: MusicLibraryItem?
    @State private var playerProgress = 0.15
    @State private var playingDestination: MusicDestination?
    @State private var selectingItem: MusicLibraryItem?
    @State private var pendingDeletion: MusicLibraryItem?
    @State private var searchPresented = false
    @State private var searchText = ""
    @State private var enabledProviders = Set<MusicProvider>()
    @State private var providerMessage: String?
    @State private var guidePresented = false
    @State private var pendingTransfer: MusicTransfer?
    @State private var dragged: DraggedMusic?
    @State private var dropTarget: MusicDestination?
    @State private var scrollStartedAt: Date?
    @State private var searchCycleIndex = 0

    private let orange = Color(red: 1, green: 0.48, blue: 0)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 8) {
                title
                uploadsPane(height: uploadsHeight)
                generalPane(height: generalHeight)
                workoutPane(height: workoutHeight)
                    if let playingItem {
                        MusicPlayerPane(
                            title: playingItem.title,
                            artworkSystemName: playingItem.artwork?.placeholderSystemImage ?? "music.note",
                            isPlaying: $player.isPlaying,
                            progress: $playerProgress,
                            destinationName: playerDestinationName,
                            destinationIcon: playerDestinationIcon,
                            onPrevious: previousTrack,
                            onNext: nextTrack,
                            onDestinationTapped: { selectingItem = playingItem }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if let item = selectingItem { selectMode(for: item) }
                if let transfer = pendingTransfer { transferConfirmation(transfer) }
                if searchPresented { searchOverlay }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.58, dampingFraction: 0.86), value: isWorkoutFocused)
        .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.88), value: playingItem?.id)
        .alert("Remove Music", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Remove", role: .destructive) {
                if let item = pendingDeletion { library.deleteItem(item.id) }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Remove \(pendingDeletion?.title ?? "this item") from your Music Library?")
        }
        .alert("Music Provider", isPresented: Binding(get: { providerMessage != nil }, set: { if !$0 { providerMessage = nil } })) {
            Button("OK", role: .cancel) { providerMessage = nil }
        } message: { Text(providerMessage ?? "") }
        .overlay {
            MusicGuideOverlay(
                isPresented: $guidePresented,
                targetRects: [:],
                onStep1: {},
                onStep2: {},
                onStep3: { demonstrateOrganization() },
                onFinished: { _ in }
            )
        }
        .onAppear { _ = MusicGuidePersistence.scheduleFirstRunIfNeeded { guidePresented = true } }
        .task(id: reduceMotion) { await runSearchIconCycle() }
    }

    private var title: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.surface2, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Music")
            Text("Music")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            floatingControls
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    private var floatingControls: some View {
        HStack(spacing: 8) {
            MusicGlassCircleButton(systemImage: "info", accessibilityLabel: "Replay Music guide") { guidePresented = true }
            MusicGlassCircleButton(accessibilityLabel: "Search music", action: {
                enabledProviders.removeAll()
                searchText = ""
                searchPresented = true
            }) {
                animatedSearchIcon
                    .frame(width: 18, height: 18)
                    .id(searchCycleIndex)
                    .transition(.opacity.combined(with: .scale(scale: 0.78)))
            }
        }
    }

    @ViewBuilder
    private var animatedSearchIcon: some View {
        switch searchCycleIndex {
        case 1:
            Image("SpotifyLogo").resizable().scaledToFit()
        case 2:
            Image("YouTubeMusicLogo").resizable().scaledToFit()
        case 3:
            Image("SoundCloudLogo").resizable().scaledToFit()
        default:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
        }
    }

    private func runSearchIconCycle() async {
        guard !reduceMotion else {
            searchCycleIndex = 0
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            for index in 1...3 {
                withAnimation(.snappy(duration: 0.18)) { searchCycleIndex = index }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
            }
            withAnimation(.snappy(duration: 0.18)) { searchCycleIndex = 0 }
        }
    }

    private func uploadsPane(height: CGFloat) -> some View {
        pane {
            VStack(alignment: .leading, spacing: 6) {
                paneHeader("Uploads", detail: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        sourceCard(title: "Import", systemImage: "square.and.arrow.down", action: importLocalMusic)
                        sourceCard(title: "Spotify", asset: "SpotifyLogo") { providerTapped(.spotify) }
                        sourceCard(title: "YouTube Music", asset: "YouTubeMusicLogo") { providerTapped(.youtubeMusic) }
                        sourceCard(title: "SoundCloud", asset: "SoundCloudLogo") { providerTapped(.soundCloud) }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollEdgeFade(.horizontal)
            }
        }
        .frame(height: height)
    }

    private func generalPane(height: CGFloat?) -> some View {
        pane(border: !isWorkoutFocused || dropTarget == .general) {
            VStack(spacing: 0) {
                Button {
                    isWorkoutFocused = false
                } label: {
                    paneHeader("General", detail: library.formattedDuration(for: .general))
                }
                .buttonStyle(.plain)
                ScrollView {
                    LazyVStack(spacing: 7) {
                        if library.generalItems.isEmpty {
                            empty("Import music to build your shared shelf")
                        } else {
                            ForEach(library.generalItems) { item in
                                musicRow(item, in: .general)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .scrollEdgeFade(.vertical)
                .simultaneousGesture(generalFocusGesture)
            }
        }
        .frame(minHeight: height ?? 0, maxHeight: height ?? .infinity)
        .onDrop(of: [UTType.text.identifier], isTargeted: dropTargetBinding(for: .general)) { _ in
            drop(dragged, into: .general, at: nil)
        }
    }

    private func workoutPane(height: CGFloat?) -> some View {
        let destination = selectedWorkoutDestination
        return pane(border: isWorkoutFocused || selectingItem != nil || (dropTarget != nil && dropTarget != .general)) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(family == .type ? "Workout Type" : "My Workouts")
                        .font(.system(size: 13, weight: .bold))
                    Spacer(minLength: 0)
                    familySwitch
                    Text(destination.map(library.formattedDuration(for:)) ?? "0m")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(orange)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(orange.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 13).padding(.top, 8).padding(.bottom, 5)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(folders, id: \.id) { folder in folderCard(folder) }
                    }
                    .padding(.horizontal, 8).padding(.bottom, 8)
                }
                .scrollEdgeFade(.horizontal)
                Divider().overlay(Theme.separator)
                if let destination {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            let items = library.items(for: destination)
                            if items.isEmpty { empty("Drop music here") }
                            ForEach(items) { item in musicRow(item, in: destination) }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 10)
                    }
                    .scrollEdgeFade(.vertical)
                    .onDrop(of: [UTType.text.identifier], isTargeted: dropTargetBinding(for: destination)) { _ in
                        drop(dragged, into: destination, at: nil)
                    }
                } else {
                    empty(family == .mine ? "Create a workout to organize its music" : "Choose a workout type")
                }
            }
        }
        .frame(minHeight: height ?? 0, maxHeight: height ?? .infinity)
    }

    private var familySwitch: some View {
        HStack(spacing: 0) {
            familyButton("Type", .type)
            familyButton("Mine", .mine)
        }
        .padding(2)
        .background(Theme.surface2, in: Capsule())
        .gesture(DragGesture(minimumDistance: 4).onEnded { value in
            family = value.translation.width >= 0 ? .mine : .type
        })
        .accessibilityElement(children: .contain)
    }

    private func familyButton(_ title: String, _ value: MusicDestinationFamily) -> some View {
        Button { family = value } label: {
            Text(title).font(.system(size: 9, weight: .bold))
                .foregroundStyle(family == value ? .white : Theme.textSecondary)
                .frame(width: 40, height: 20)
                .background(family == value ? orange.opacity(0.28) : .clear, in: Capsule())
        }.buttonStyle(.plain)
        .accessibilityLabel("Show \(title) folders")
    }

    private var folders: [MusicDestination] { library.destinations(for: family) }
    private var selectedWorkoutDestination: MusicDestination? { library.selectedDestination(for: family) ?? folders.first }

    private func folderCard(_ destination: MusicDestination) -> some View {
        let selected = destination == selectedWorkoutDestination
        return Button {
            library.select(destination: destination)
            isWorkoutFocused = true
        } label: {
            VStack(spacing: 5) {
                Image(systemName: folderIcon(destination)).font(.system(size: 19, weight: .semibold))
                Text(library.destinationName(destination)).lineLimit(1).font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(selected ? orange : Color.white.opacity(0.82))
            .frame(width: 76, height: 68)
            .background(selected ? orange.opacity(0.14) : Theme.surface2, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? orange.opacity(0.65) : Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .shadow(color: selected ? orange.opacity(0.14) : Color.black.opacity(0.18), radius: selected ? 12 : 6, y: 4)
        .onDrop(of: [UTType.text.identifier], isTargeted: dropTargetBinding(for: destination)) { _ in
            library.select(destination: destination)
            isWorkoutFocused = true
            return drop(dragged, into: destination, at: nil)
        }
    }

    private func musicRow(_ item: MusicLibraryItem, in destination: MusicDestination) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                cover(for: item)
                Button { itemTapped(item, destination: destination) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(item.isCollection ? item.kind.rawValue.capitalized : item.source.provider?.displayName ?? "Local")
                            .font(.system(size: 10)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Text(library.formattedDuration(item.totalDuration)).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Button { selectingItem = item } label: { Image(systemName: "plus").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).foregroundStyle(.white).accessibilityLabel("Add \(item.title) to a workout")
                if item.isCollection {
                    Button { toggleExpanded(item.id) } label: { Image(systemName: expandedItems.contains(item.id) ? "chevron.up" : "chevron.down") }
                        .buttonStyle(.plain).foregroundStyle(Theme.textSecondary).accessibilityLabel("Expand \(item.title)")
                } else {
                    Button { itemTapped(item, destination: destination) } label: { Image(systemName: playingItem?.id == item.id ? "pause.fill" : "play.fill") }
                        .buttonStyle(.plain).foregroundStyle(orange).accessibilityLabel("Play \(item.title)")
                }
                Button(role: .destructive) { pendingDeletion = item } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(Theme.textSecondary).accessibilityLabel("Remove \(item.title)")
            }
            .padding(8)
            if expandedItems.contains(item.id) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(item.tracks.enumerated()), id: \.element.id) { offset, track in
                        HStack { Text("\(offset + 1)").foregroundStyle(Theme.textSecondary); Text(track.title).lineLimit(1); Spacer(); Text(library.formattedDuration(track.duration)).foregroundStyle(Theme.textSecondary) }
                            .font(.system(size: 11)).padding(.vertical, 8).padding(.horizontal, 12)
                            .overlay(alignment: .top) { Divider().overlay(Theme.separator) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(dropTarget == destination ? orange.opacity(0.72) : Theme.separator, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 17))
        .onDrag {
            dragged = DraggedMusic(item: item, source: destination)
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text.identifier], isTargeted: dropTargetBinding(for: destination)) { _ in
            drop(dragged, into: destination, at: library.itemIDs(for: destination).firstIndex(of: item.id))
        }
    }

    private func cover(for item: MusicLibraryItem) -> some View {
        ZStack {
            if let image = item.artwork?.placeholderSystemImage { Image(systemName: image) } else { Image(systemName: item.isCollection ? "rectangle.stack.fill" : "music.note") }
        }
        .font(.system(size: 20, weight: .medium)).foregroundStyle(item.isCollection ? .white : orange)
        .frame(width: 46, height: 46).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectMode(for item: MusicLibraryItem) -> some View {
        Color.black.opacity(0.55).ignoresSafeArea().overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add \(item.title)").font(.headline)
                Text("Choose one or more workout destinations. Drag and drop also works.").font(.caption).foregroundStyle(Theme.textSecondary)
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(library.destinations(for: family), id: \.id) { destination in
                            Button {
                                _ = library.add(item, to: destination)
                                library.select(destination: destination)
                            } label: {
                                HStack { Image(systemName: folderIcon(destination)); Text(library.destinationName(destination)); Spacer(); Image(systemName: library.items(for: destination).contains(item) ? "checkmark" : "plus") }
                                    .padding(11).foregroundStyle(library.items(for: destination).contains(item) ? orange : .white)
                                    .background(library.items(for: destination).contains(item) ? orange.opacity(0.12) : Theme.surface2, in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(maxHeight: 210).scrollEdgeFade(.vertical)
                HStack { Button("Cancel") { selectingItem = nil }; Spacer(); Button("Done") { selectingItem = nil }.buttonStyle(.borderedProminent).tint(orange) }
            }
            .padding(16).background(Theme.background, in: RoundedRectangle(cornerRadius: 24)).padding(10)
        }
    }

    private var searchOverlay: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Button { searchPresented = false } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).accessibilityLabel("Back to Music")
                    TextField("Search music", text: $searchText).textFieldStyle(.plain).padding(10).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                    ForEach([MusicProvider.spotify, .youtubeMusic, .soundCloud], id: \.self) { provider in
                        Button { toggle(provider) } label: { providerLogo(provider).padding(6).frame(width: 34, height: 34).background(enabledProviders.contains(provider) ? orange.opacity(0.25) : Theme.surface2, in: Circle()) }.buttonStyle(.plain).accessibilityLabel("Search \(provider.displayName)")
                    }
                }.padding(.horizontal, 14).padding(.top, 10)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        if !searchText.isEmpty {
                            ForEach(enabledProviders.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { provider in providerSearchPane(provider) }
                        }
                        let results = library.search(searchText)
                        if !results.isEmpty { Text("Your Music").font(.headline).padding(.top, 4); ForEach(results) { result in searchResult(result) } }
                        if searchText.isEmpty { empty("Search General, workout types, and your workouts") }
                    }.padding(.horizontal, 12).padding(.bottom, 16)
                }.scrollEdgeFade(.vertical)
            }
        }
    }

    private func providerSearchPane(_ provider: MusicProvider) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { providerLogo(provider).frame(width: 22, height: 22); Text(provider.displayName).font(.headline) }
            Text("Connect \(provider.displayName) to search its available catalog.").font(.caption).foregroundStyle(Theme.textSecondary)
            Button("Connect") { providerTapped(provider) }.buttonStyle(.bordered).tint(orange)
        }.padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.separator, lineWidth: 1))
    }

    private func searchResult(_ result: MusicLibrarySearchResult) -> some View {
        Button {
            searchPresented = false
            library.select(destination: result.destination)
            isWorkoutFocused = result.destination != .general
            if result.item.isCollection { expandedItems.insert(result.item.id) }
        } label: {
            HStack { cover(for: result.item); VStack(alignment: .leading) { Text(result.item.title); Text(library.destinationName(result.destination)).font(.caption).foregroundStyle(Theme.textSecondary) }; Spacer(); Image(systemName: "arrow.right") }
                .padding(9).foregroundStyle(.white).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }

    private func transferConfirmation(_ transfer: MusicTransfer) -> some View {
        Color.black.opacity(0.6).ignoresSafeArea().overlay {
            VStack(spacing: 12) {
                Text("Move or Duplicate?").font(.headline)
                Text("\(library.item(id: transfer.itemID)?.title ?? "Music") → \(library.destinationName(transfer.destination))").font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                HStack { Button("Cancel") { pendingTransfer = nil }; Button("Move") { library.commitWorkoutTransfer(transfer, choice: .move); pendingTransfer = nil }.buttonStyle(.bordered); Button("Duplicate") { library.commitWorkoutTransfer(transfer, choice: .duplicate); pendingTransfer = nil }.buttonStyle(.borderedProminent).tint(orange) }
            }.padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22)).padding(30)
        }
    }

    private var uploadsHeight: CGFloat {
        isWorkoutFocused ? (playingItem == nil ? 86 : 72) : (playingItem == nil ? 138 : 112)
    }

    private var generalHeight: CGFloat? {
        isWorkoutFocused ? (playingItem == nil ? 190 : 142) : nil
    }

    private var workoutHeight: CGFloat? {
        isWorkoutFocused || selectingItem != nil ? nil : (playingItem == nil ? 116 : 104)
    }

    private func pane<Content: View>(border: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 25))
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.025), .clear, Color.black.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(border ? orange.opacity(0.55) : Theme.separator, lineWidth: 1))
            .shadow(color: border ? orange.opacity(0.10) : Color.black.opacity(0.22), radius: border ? 14 : 8, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    private func paneHeader(_ title: String, detail: String?) -> some View { HStack { Text(title).font(.system(size: 13, weight: .bold)); Spacer(); if let detail { Text(detail).font(.system(size: 10, weight: .bold)).foregroundStyle(orange).padding(.horizontal, 7).padding(.vertical, 4).background(orange.opacity(0.12), in: Capsule()) } }.padding(.horizontal, 13).padding(.top, 8).padding(.bottom, 5).foregroundStyle(.white) }
    private func sourceCard(title: String, systemImage: String? = nil, asset: String? = nil, action: @escaping () -> Void) -> some View { Button(action: action) { VStack(spacing: 6) { if let asset { Image(asset).resizable().scaledToFit().frame(width: 46, height: 46) } else { Image(systemName: systemImage ?? "music.note").font(.system(size: 30, weight: .medium)) }; Text(title).font(.system(size: 10, weight: .bold)).lineLimit(1) }.foregroundStyle(.white).frame(width: 104, height: 95).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(Theme.separator, lineWidth: 1)) }.buttonStyle(.plain).accessibilityLabel(title) }
    private func providerLogo(_ provider: MusicProvider) -> some View { Group { switch provider { case .spotify: Image("SpotifyLogo").resizable().scaledToFit(); case .youtubeMusic: Image("YouTubeMusicLogo").resizable().scaledToFit(); case .soundCloud: Image("SoundCloudLogo").resizable().scaledToFit(); default: Image(systemName: "music.note") } } }
    private func empty(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, minHeight: 68).padding(.horizontal, 16).multilineTextAlignment(.center) }
    private func folderIcon(_ destination: MusicDestination) -> String { switch destination { case .general: return "music.note.list"; case .workoutType(let id): return library.workoutType(for: id)?.iconName ?? "figure.run"; case .workout: return "figure.strengthtraining.traditional" } }
    private func toggleExpanded(_ id: UUID) { withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.86)) { if expandedItems.contains(id) { expandedItems.remove(id) } else { expandedItems.insert(id) } } }
    private func itemTapped(_ item: MusicLibraryItem, destination: MusicDestination) { if playingItem?.id == item.id { playingItem = nil; playingDestination = nil; player.stopPlayback(); return }; playingItem = item; playingDestination = destination; library.select(destination: destination); if let filename = item.localReference?.filename { player.startPlayback(tracks: [filename]) } }
    private func previousTrack() { playerProgress = max(0, playerProgress - 0.15) }
    private func nextTrack() { playerProgress = min(1, playerProgress + 0.15) }
    private var playerDestinationName: String { library.destinationName(playingDestination ?? .general) }
    private var playerDestinationIcon: String { folderIcon(playingDestination ?? .general) }
    private func providerTapped(_ provider: MusicProvider) { providerMessage = "\(provider.displayName) requires its official sign-in and app configuration before it can be connected." }
    private func toggle(_ provider: MusicProvider) { if enabledProviders.contains(provider) { enabledProviders.remove(provider) } else { enabledProviders.insert(provider) } }
    private func drop(_ dragged: DraggedMusic?, into destination: MusicDestination, at position: Int?) -> Bool { guard let dragged else { return false }; defer { self.dragged = nil; dropTarget = nil }; if let transfer = library.prepareWorkoutTransfer(itemID: dragged.item.id, from: dragged.source, to: destination, at: position) { pendingTransfer = transfer; return true }; return library.moveItem(dragged.item.id, from: dragged.source, to: destination, at: position) }
    private func dropTargetBinding(for destination: MusicDestination) -> Binding<Bool> { Binding(get: { dropTarget == destination }, set: { targeted in if targeted { dropTarget = destination } else if dropTarget == destination { dropTarget = nil } }) }
    private var generalFocusGesture: some Gesture { DragGesture(minimumDistance: 4).onChanged { value in guard isWorkoutFocused, selectingItem == nil, !guidePresented, abs(value.translation.height) > 2 else { scrollStartedAt = nil; return }; let now = Date(); if let started = scrollStartedAt, now.timeIntervalSince(started) >= 3 { isWorkoutFocused = false; scrollStartedAt = nil } else if scrollStartedAt == nil { scrollStartedAt = now } }.onEnded { _ in scrollStartedAt = nil } }
    private func demonstrateOrganization() { guard let destination = library.destinations(for: .type).first else { return }; let temporary = MusicLibraryItem(name: "Guide music", source: .none, artwork: MusicArtworkReference(placeholderSystemImage: "music.note"), duration: 0); _ = library.add(temporary, to: .general); isWorkoutFocused = false; Task { @MainActor in try? await Task.sleep(nanoseconds: 350_000_000); _ = library.moveItem(temporary.id, from: .general, to: destination); library.select(destination: destination); isWorkoutFocused = true; try? await Task.sleep(nanoseconds: 700_000_000); _ = library.deleteItem(temporary.id) } }
}

private struct DraggedMusic: Equatable {
    let item: MusicLibraryItem
    let source: MusicDestination
}

private extension UTType {
    static let timeMasterMusicItem = UTType(exportedAs: "com.timemaster.music-library-item")
}
