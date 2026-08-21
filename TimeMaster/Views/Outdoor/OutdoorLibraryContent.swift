#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorLibraryContent: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let initialActivityID: UUID?
    let onClose: () -> Void
    let onSelectedActivityIDChange: (UUID?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedActivityID: UUID?
    @State private var typeFilter: OutdoorLibraryTypeFilter = .all
    @State private var sortOrder: OutdoorLibrarySortOrder = .recent
    @State private var searchText = ""
    @State private var routePoints: [UUID: [OutdoorTrackPoint]] = [:]

    init(
        store: OutdoorActivityStore,
        preferences: OutdoorRecordingPreferencesStore,
        initialActivityID: UUID? = nil,
        onClose: @escaping () -> Void,
        onSelectedActivityIDChange: @escaping (UUID?) -> Void
    ) {
        self.store = store
        self.preferences = preferences
        self.initialActivityID = initialActivityID
        self.onClose = onClose
        self.onSelectedActivityIDChange = onSelectedActivityIDChange
        _selectedActivityID = State(initialValue: initialActivityID)
    }

    private var established: [OutdoorActivity] {
        store.establishedActivities
    }

    private var starred: [OutdoorActivity] {
        established.filter(\.starred)
    }

    private var filteredActivities: [OutdoorActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = established.filter { activity in
            let matchesType = typeFilter.matches(activity.kind)
            let matchesSearch = query.isEmpty || activity.title.localizedCaseInsensitiveContains(query) || activity.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesType && matchesSearch
        }
        switch sortOrder {
        case .recent:
            return matching.sorted { ($0.establishedAt ?? $0.startedAt) > ($1.establishedAt ?? $1.startedAt) }
        case .oldest:
            return matching.sorted { ($0.establishedAt ?? $0.startedAt) < ($1.establishedAt ?? $1.startedAt) }
        case .distance:
            return matching.sorted { $0.distanceMeters > $1.distanceMeters }
        case .name:
            return matching.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if let selectedActivityID {
                OutdoorActivityDetailPineContent(
                    store: store,
                    preferences: preferences,
                    activityID: selectedActivityID,
                    points: routePoints[selectedActivityID] ?? [],
                    onBack: { self.selectedActivityID = nil },
                    onDeleted: { self.selectedActivityID = nil }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            } else {
                libraryList
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.22), value: selectedActivityID)
        .onAppear {
            if selectedActivityID == nil, let initialActivityID, established.contains(where: { $0.id == initialActivityID }) {
                selectedActivityID = initialActivityID
            }
            loadRoutePoints()
            onSelectedActivityIDChange(selectedActivityID)
        }
        .onChange(of: store.activities) { _ in
            loadRoutePoints()
            if let selectedActivityID, !established.contains(where: { $0.id == selectedActivityID }) {
                self.selectedActivityID = nil
            }
        }
        .onChange(of: selectedActivityID) { activityID in
            onSelectedActivityIDChange(activityID)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selectedActivityID == nil ? "Outdoor workout library" : "Outdoor workout details")
    }

    private var libraryList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true))
                    .accessibilityLabel("Exit workout library")
                    Text("Routes")
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 4)
                if !starred.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Starred")
                            .font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(starred) { activity in
                                    OutdoorLibraryCard(
                                        activity: activity,
                                        points: routePoints[activity.id] ?? [],
                                        units: preferences.preferences.unitSystem,
                                        compact: true,
                                        onSelect: { selectedActivityID = activity.id }
                                    )
                                    .frame(width: 150)
                                }
                            }
                        }
                    }
                } else {
                    OutdoorLibraryEmptyState(title: "No starred routes", message: "Star a saved route to keep it here.", systemImage: "star")
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("Library")
                        .font(.subheadline.weight(.semibold))
                    TextField("Search routes and tags", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search workout library")
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(OutdoorLibraryTypeFilter.allCases) { filter in
                                Button {
                                    typeFilter = filter
                                } label: {
                                    Label(filter.title, systemImage: typeFilter == filter ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Label(typeFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutdoorPineButtonStyle())
                        .accessibilityLabel("Filter workout type")
                        Menu {
                            ForEach(OutdoorLibrarySortOrder.allCases) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    Label(order.title, systemImage: sortOrder == order ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Label(sortOrder.title, systemImage: "arrow.up.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutdoorPineButtonStyle())
                        .accessibilityLabel("Sort workout library")
                    }
                    if filteredActivities.isEmpty {
                        OutdoorLibraryEmptyState(
                            title: established.isEmpty ? "Your routes will appear here" : "No routes match",
                            message: established.isEmpty ? "Finish and establish a workout to build your Library." : "Try another type, sort, or search term.",
                            systemImage: established.isEmpty ? "figure.run" : "magnifyingglass"
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 14) {
                            ForEach(filteredActivities) { activity in
                                OutdoorLibraryCard(
                                    activity: activity,
                                    points: routePoints[activity.id] ?? [],
                                    units: preferences.preferences.unitSystem,
                                    onSelect: { selectedActivityID = activity.id }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 52)
            .padding(.bottom, 16)
        }
    }

    private func loadRoutePoints() {
        var next = routePoints
        for activity in established where next[activity.id] == nil {
            next[activity.id] = store.trackPoints(for: activity)
        }
        next = next.filter { key, _ in established.contains(where: { activity in activity.id == key }) }
        routePoints = next
    }
}

enum OutdoorLibraryTypeFilter: String, CaseIterable, Identifiable {
    case all
    case run
    case bike
    case walk
    case runWalk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Types"
        case .run: "Run"
        case .bike: "Bike"
        case .walk: "Walk"
        case .runWalk: "Legacy Run & Walk"
        }
    }

    func matches(_ kind: OutdoorActivityKind) -> Bool {
        switch self {
        case .all: true
        case .run: kind == .run
        case .bike: kind == .bike
        case .walk: kind == .walk
        case .runWalk: kind == .runWalk
        }
    }
}

enum OutdoorLibrarySortOrder: String, CaseIterable, Identifiable {
    case recent
    case oldest
    case distance
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "Recent"
        case .oldest: "Oldest"
        case .distance: "Distance"
        case .name: "Name"
        }
    }
}

struct OutdoorLibraryCard: View {
    let activity: OutdoorActivity
    let points: [OutdoorTrackPoint]
    let units: TimeMasterCore.OutdoorUnitSystem
    var compact = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    OutdoorRouteThumbnailView(points: points, compact: compact, cacheKey: activity.id.uuidString)
                    OutdoorTypeIconBadge(kind: activity.kind)
                        .scaleEffect(compact ? 0.78 : 0.9, anchor: .topTrailing)
                        .padding(5)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(activity.title)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if activity.starred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                }
                Text(outdoorDistanceText(activity.distanceMeters, unitSystem: units))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.title), \(activity.kind.displayName), \(outdoorDistanceText(activity.distanceMeters, unitSystem: units))")
    }
}

struct OutdoorLibraryEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.restAccent)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }
}

struct OutdoorActivityDetailPineContent: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let activityID: UUID
    let points: [OutdoorTrackPoint]
    let onBack: () -> Void
    let onDeleted: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var tagText = ""
    @State private var allowComments = true
    @State private var hideStartFinish = true
    @State private var endpointPrivacyMeters = 200
    @State private var showPlayerTracks = true
    @State private var showingDelete = false
    @State private var errorMessage: String?
    @State private var isEditingDetails = false
    @State private var titleSaveTask: Task<Void, Never>?
    @AccessibilityFocusState private var deleteButtonFocused: Bool

    private var activity: OutdoorActivity? {
        store.activities.first(where: { $0.id == activityID })
    }

    var body: some View {
        Group {
            if let activity {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header(activity)
                        OutdoorRouteThumbnailView(points: points, cacheKey: activity.id.uuidString)
                        stats(activity)
                        if activity.visibility == .publicVisibility || activity.hasPublicMetadata || isEditingDetails {
                            metadata(activity)
                        }
                        OutdoorPlayedTrackSummary(tracks: activity.playedTracks, visible: activity.showPlayerTracks || !activity.playedTracks.isEmpty)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let errorMessage {
                            OutdoorInlineError(message: errorMessage)
                        }
                        HStack(spacing: 8) {
                            OutdoorExportShareControl(activity: activity, points: points, preferences: preferences)
                            Button {
                                showingDelete = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(OutdoorPineButtonStyle(circular: true))
                            .accessibilityFocused($deleteButtonFocused)
                            .accessibilityLabel("Delete workout")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 52)
                    .padding(.bottom, 16)
                }
            } else {
                VStack(spacing: 12) {
                    OutdoorInlineError(message: "This route is no longer available.")
                    Button("Back to Library", action: onBack)
                        .buttonStyle(OutdoorPineButtonStyle())
                }
                .padding(18)
            }
        }
        .accessibilityHidden(showingDelete)
        .onAppear { syncFromActivity() }
        .onDisappear {
            titleSaveTask?.cancel()
            guard let activity else { return }
            saveTitle()
            saveTags(activity)
        }
        .onChange(of: showingDelete) { isShowing in
            if !isShowing { deleteButtonFocused = true }
        }
        .overlay {
            if showingDelete, let activity {
                OutdoorDeletionConfirmation(activity: activity, isPresented: $showingDelete) {
                    delete(activity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout details")
    }

    private func header(_ activity: OutdoorActivity) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: true))
                .accessibilityLabel("Back to workout library")
                Spacer()
                Button {
                    if isEditingDetails {
                        saveTitle()
                        saveTags(activity)
                    }
                    isEditingDetails.toggle()
                } label: {
                    Image(systemName: isEditingDetails ? "checkmark" : "pencil")
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: true))
                .accessibilityLabel(isEditingDetails ? "Finish editing workout" : "Edit workout details")
            }
            HStack(spacing: 8) {
                TextField("Workout title", text: $title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .disabled(!isEditingDetails)
                    .onSubmit { saveTitle() }
                    .onChange(of: title) { _ in
                        guard isEditingDetails else { return }
                        scheduleTitleSave()
                    }
                    .accessibilityLabel("Workout title")
                Button {
                    toggleStar(activity)
                } label: {
                    Image(systemName: activity.starred ? "star.fill" : "star")
                        .foregroundStyle(activity.starred ? .yellow : Theme.textSecondary)
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: true))
                .accessibilityLabel(activity.starred ? "Remove star" : "Star workout")
                .accessibilityValue(activity.starred ? "Starred" : "Not starred")
            }
            Picker("Visibility", selection: Binding(
                get: { activity.visibility },
                set: { updateVisibility($0, activity: activity) }
            )) {
                Text("Private").tag(OutdoorActivityVisibility.privateVisibility)
                Text("Public").tag(OutdoorActivityVisibility.publicVisibility)
            }
            .pickerStyle(.segmented)
            .disabled(!isEditingDetails)
            .accessibilityLabel("Workout visibility")
            OutdoorTypeBadge(kind: activity.kind)
            Text(outdoorDateText(activity.startedAt))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func stats(_ activity: OutdoorActivity) -> some View {
        let units = preferences.preferences.unitSystem
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                OutdoorMetricTile(label: "Distance", value: outdoorDistanceText(activity.distanceMeters, unitSystem: units))
                OutdoorMetricTile(label: "Elapsed", value: outdoorDurationText(activity.elapsedSeconds))
                OutdoorMetricTile(label: "Moving", value: outdoorDurationText(activity.movingSeconds))
            }
            HStack(alignment: .top, spacing: 10) {
                OutdoorMetricTile(label: "Elevation gain", value: outdoorElevationText(activity.elevationGainMeters, unitSystem: units))
                OutdoorMetricTile(label: "Highest", value: outdoorElevationText(activity.highestElevationMeters, unitSystem: units))
                OutdoorMetricTile(label: "Top speed", value: outdoorSpeedText(activity.maxSpeedMetersPerSecond, unitSystem: units))
            }
            OutdoorMetricTile(label: "Average pace", value: outdoorPaceText(activity.averagePaceSecondsPerKilometer, unitSystem: units))
        }
    }

    private func metadata(_ activity: OutdoorActivity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Public details")
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $description)
                .frame(minHeight: 82)
                .padding(8)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(!isEditingDetails)
                .onChange(of: description) { value in
                    guard isEditingDetails else { return }
                    do { try store.setPublicDescription(value, for: activity) } catch { errorMessage = error.localizedDescription }
                }
                .accessibilityLabel("Workout description")
            TextField("Tags separated by commas", text: $tagText)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditingDetails)
                .onSubmit { saveTags(activity) }
                .accessibilityLabel("Workout tags")
            Toggle("Allow Comments", isOn: Binding(
                get: { allowComments },
                set: { value in allowComments = value; guard isEditingDetails else { return }; updateComments(value, activity: activity) }
            ))
            .disabled(!isEditingDetails)
            Toggle("Hide Start & Finish", isOn: Binding(
                get: { hideStartFinish },
                set: { value in hideStartFinish = value; guard isEditingDetails else { return }; updateHideStartFinish(value, activity: activity) }
            ))
            .disabled(!isEditingDetails)
            if hideStartFinish {
                Picker("Endpoint privacy", selection: $endpointPrivacyMeters) {
                    ForEach(OutdoorPrivacyService.supportedEndpointDistancesMeters, id: \.self) { meters in
                        Text("\(meters) m").tag(meters)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!isEditingDetails)
                .onChange(of: endpointPrivacyMeters) { value in
                    guard isEditingDetails else { return }
                    do { try store.setEndpointPrivacyMeters(value, for: activity) } catch { errorMessage = error.localizedDescription }
                }
            }
            Toggle("Show Player Tracks", isOn: Binding(
                get: { showPlayerTracks },
                set: { value in showPlayerTracks = value; guard isEditingDetails else { return }; updateShowTracks(value, activity: activity) }
            ))
            .disabled(!isEditingDetails)
        }
    }

    private func syncFromActivity() {
        guard let activity else { return }
        title = activity.title
        description = activity.publicDescription
        tagText = activity.tags.joined(separator: ", ")
        allowComments = activity.allowComments
        hideStartFinish = activity.hideStartFinish
        endpointPrivacyMeters = activity.endpointPrivacyMeters
        showPlayerTracks = activity.showPlayerTracks
    }

    private func scheduleTitleSave() {
        titleSaveTask?.cancel()
        guard let activity else { return }
        let value = title
        titleSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do { try store.updateTitle(value, for: activity) } catch { errorMessage = error.localizedDescription }
        }
    }

    private func saveTitle() {
        titleSaveTask?.cancel()
        guard let activity else { return }
        do { try store.updateTitle(title, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func saveTags(_ activity: OutdoorActivity) {
        let tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var uniqueTags: [String] = []
        for tag in tags where !uniqueTags.contains(tag) { uniqueTags.append(tag) }
        do { try store.setTags(uniqueTags, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func toggleStar(_ activity: OutdoorActivity) {
        do { try store.toggleStarred(for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func updateVisibility(_ value: OutdoorActivityVisibility, activity: OutdoorActivity) {
        do { try store.setVisibility(value, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func updateComments(_ value: Bool, activity: OutdoorActivity) {
        do { try store.setAllowComments(value, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func updateHideStartFinish(_ value: Bool, activity: OutdoorActivity) {
        do { try store.setHideStartFinish(value, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func updateShowTracks(_ value: Bool, activity: OutdoorActivity) {
        do { try store.setShowPlayerTracks(value, for: activity) } catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ activity: OutdoorActivity) {
        do {
            try store.delete(activity)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
