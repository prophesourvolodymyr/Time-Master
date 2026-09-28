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
    @State private var starredExpanded = true
    @State private var errorMessage: String?

    init(store: OutdoorActivityStore, preferences: OutdoorRecordingPreferencesStore, initialActivityID: UUID? = nil, onClose: @escaping () -> Void, onSelectedActivityIDChange: @escaping (UUID?) -> Void) {
        self.store = store
        self.preferences = preferences
        self.initialActivityID = initialActivityID
        self.onClose = onClose
        self.onSelectedActivityIDChange = onSelectedActivityIDChange
        _selectedActivityID = State(initialValue: initialActivityID)
    }

    private var established: [OutdoorActivity] { store.establishedActivities }
    private var starred: [OutdoorActivity] { established.filter(\.starred) }

    private var filteredActivities: [OutdoorActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = established.filter { activity in
            typeFilter.matches(activity.kind)
                && (query.isEmpty || activity.title.localizedCaseInsensitiveContains(query) || activity.tags.contains { $0.localizedCaseInsensitiveContains(query) })
        }
        switch sortOrder {
        case .recent: return matching.sorted { ($0.establishedAt ?? $0.startedAt) > ($1.establishedAt ?? $1.startedAt) }
        case .oldest: return matching.sorted { ($0.establishedAt ?? $0.startedAt) < ($1.establishedAt ?? $1.startedAt) }
        case .distance: return matching.sorted { $0.distanceMeters > $1.distanceMeters }
        case .name: return matching.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
                .transition(.opacity)
            } else {
                libraryList.transition(.opacity)
            }
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selectedActivityID)
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
        .onChange(of: selectedActivityID, perform: onSelectedActivityIDChange)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selectedActivityID == nil ? "Outdoor workout library" : "Outdoor workout details")
    }

    private var libraryList: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit workout library")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent rides")
                        .font(.title2.weight(.bold))
                    Text("\(established.count) saved workouts")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                OutdoorChoicePicker(
                    title: "Sort workout library",
                    selection: $sortOrder,
                    options: OutdoorLibrarySortOrder.allCases.map {
                        OutdoorChoiceOption(id: $0, title: $0.title, systemImage: "arrow.up.arrow.down")
                    },
                    compact: true
                )
            }
            OutdoorSearchBar(text: $searchText, placeholder: "Search routes and tags") {
                OutdoorChoicePicker(
                    title: "Filter workout type",
                    selection: $typeFilter,
                    options: OutdoorLibraryTypeFilter.allCases.map {
                        OutdoorChoiceOption(id: $0, title: $0.title, systemImage: $0.systemImage)
                    }
                )
            }
            if let errorMessage { OutdoorInlineError(message: errorMessage) }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !starred.isEmpty {
                        DisclosureGroup(isExpanded: $starredExpanded) {
                            VStack(spacing: 10) {
                                ForEach(starred) { activity in card(activity) }
                            }
                            .padding(.top, 8)
                        } label: {
                            Label("Starred · \(starred.count)", systemImage: "star.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(Theme.restAccent)
                        .padding(.bottom, 6)
                    }
                    if filteredActivities.isEmpty {
                        OutdoorLibraryEmptyState(
                            title: established.isEmpty ? "Your next ride starts here" : "No matching workouts",
                            message: established.isEmpty ? "Saved workouts will appear here with their route, time, and distance." : "Try another name, tag, or activity type.",
                            systemImage: established.isEmpty ? "map" : "magnifyingglass"
                        )
                    } else {
                        Text(searchText.isEmpty && typeFilter == .all ? "All workouts" : "Results · \(filteredActivities.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(filteredActivities) { activity in card(activity) }
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func card(_ activity: OutdoorActivity) -> some View {
        OutdoorLibraryCard(
            activity: activity,
            points: routePoints[activity.id] ?? [],
            units: preferences.preferences.unitSystem,
            onSelect: { selectedActivityID = activity.id },
            onVisibilityChange: { value in
                do { try store.setVisibility(value, for: activity) }
                catch { errorMessage = error.localizedDescription }
            }
        )
        .contextMenu {
            Button {
                do { try store.toggleStarred(for: activity) }
                catch { errorMessage = error.localizedDescription }
            } label: {
                Label(activity.starred ? "Remove star" : "Star workout", systemImage: activity.starred ? "star.slash" : "star")
            }
            Button("View and rename workout") { selectedActivityID = activity.id }
        }
    }

    private func loadRoutePoints() {
        let identifiers = Set(established.map(\.id))
        var next = routePoints.filter { identifiers.contains($0.key) }
        for activity in established where next[activity.id] == nil {
            next[activity.id] = store.trackPoints(for: activity)
        }
        routePoints = next
    }
}

enum OutdoorLibraryTypeFilter: String, CaseIterable, Identifiable {
    case all, run, bike, walk, runWalk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All types"
        case .run: "Run"
        case .bike: "Bike"
        case .walk: "Walk"
        case .runWalk: "Run & Walk"
        }
    }
    var systemImage: String {
        switch self {
        case .all: "line.3.horizontal.decrease"
        case .run, .runWalk: "figure.run"
        case .bike: "bicycle"
        case .walk: "figure.walk"
        }
    }
    func matches(_ kind: OutdoorActivityKind) -> Bool {
        self == .all || rawValue == kind.rawValue
    }
}

enum OutdoorLibrarySortOrder: String, CaseIterable, Identifiable {
    case recent, oldest, distance, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: "Most recent"
        case .oldest: "Oldest first"
        case .distance: "Longest distance"
        case .name: "Name"
        }
    }
}

struct OutdoorLibraryCard: View {
    let activity: OutdoorActivity
    let points: [OutdoorTrackPoint]
    let units: TimeMasterCore.OutdoorUnitSystem
    let onSelect: () -> Void
    let onVisibilityChange: (OutdoorActivityVisibility) -> Void
    @ScaledMetric(relativeTo: .body) private var previewWidth: CGFloat = 76
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: 12) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        OutdoorRouteThumbnailView(points: points, compact: true, cacheKey: activity.id.uuidString)
                            .frame(width: previewWidth)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(activity.title)
                                .font(.headline)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if activity.starred {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.restAccent)
                            }
                        }
                        Text(activity.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { distanceAndTime }
                            VStack(alignment: .leading, spacing: 4) { distanceAndTime }
                        }
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(activity.title), \(activity.kind.displayName), \(outdoorDistanceText(activity.distanceMeters, unitSystem: units)), duration \(outdoorDurationText(activity.elapsedSeconds))")
            HStack {
                Label(activity.kind.displayName, systemImage: activity.kind.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.restAccent)
                Spacer(minLength: 4)
                OutdoorVisibilityPicker(visibility: Binding(get: { activity.visibility }, set: onVisibilityChange))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var distanceAndTime: some View {
        Group {
            Text(outdoorDistanceText(activity.distanceMeters, unitSystem: units))
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Label(outdoorDurationText(activity.elapsedSeconds), systemImage: "clock")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct OutdoorLibraryEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.restAccent)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
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
    @State private var showingRename = false
    @State private var showingDelete = false
    @State private var showingDetails = false
    @State private var errorMessage: String?
    @AccessibilityFocusState private var deleteButtonFocused: Bool

    private var activity: OutdoorActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Group {
            if let activity {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            Label("Recent rides", systemImage: "chevron.left")
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to workout library")
                        Spacer()
                        Button {
                            perform { try store.toggleStarred(for: activity) }
                        } label: {
                            Image(systemName: activity.starred ? "star.fill" : "star")
                                .foregroundStyle(activity.starred ? Theme.restAccent : Theme.textPrimary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(activity.starred ? "Remove star" : "Star workout")
                    }
                    .padding(.horizontal, 16)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            Button {
                                title = activity.title
                                showingRename = true
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(activity.title)
                                        .font(.title2.weight(.bold))
                                        .multilineTextAlignment(.leading)
                                    Image(systemName: "pencil")
                                        .font(.body)
                                        .foregroundStyle(Theme.restAccent)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Rename \(activity.title)")
                            Text(outdoorDateText(activity.startedAt))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) { selectors(activity) }
                                VStack(alignment: .leading, spacing: 8) { selectors(activity) }
                            }
                            OutdoorWorkoutSummary(activity: activity, units: preferences.preferences.unitSystem)
                            OutdoorRouteThumbnailView(points: points, cacheKey: activity.id.uuidString)
                            DisclosureGroup("Notes & privacy", isExpanded: $showingDetails) {
                                OutdoorPublicDetailsFields(description: $description, tagText: $tagText, allowComments: $allowComments, hideStartFinish: $hideStartFinish, endpointPrivacyMeters: $endpointPrivacyMeters, showPlayerTracks: $showPlayerTracks)
                                    .padding(.vertical, 16)
                                Button("Save details") { saveDetails(activity) }
                                    .buttonStyle(OutdoorAccessoryButtonStyle())
                            }
                            .tint(Theme.restAccent)
                            if !activity.playedTracks.isEmpty {
                                OutdoorPlayedTrackSummary(tracks: activity.playedTracks)
                            }
                            if let errorMessage { OutdoorInlineError(message: errorMessage) }
                            HStack(spacing: 12) {
                                OutdoorExportShareControl(activity: activity, points: points, preferences: preferences)
                                Button(role: .destructive) { showingDelete = true } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityFocused($deleteButtonFocused)
                                .accessibilityLabel("Delete workout")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            } else {
                VStack(spacing: 12) {
                    OutdoorInlineError(message: "This route is no longer available.")
                    Button("Back to Recent rides", action: onBack).buttonStyle(OutdoorAccessoryButtonStyle())
                }
                .padding(18)
            }
        }
        .accessibilityHidden(showingDelete)
        .onAppear { syncFromActivity() }
        .onChange(of: showingDelete) { if !$0 { deleteButtonFocused = true } }
        .alert("Rename workout", isPresented: $showingRename) {
            TextField("Workout name", text: $title)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard let activity else { return }
                perform { try store.updateTitle(title, for: activity) }
            }
        }
        .overlay {
            if showingDelete, let activity {
                OutdoorDeletionConfirmation(activity: activity, isPresented: $showingDelete) {
                    perform {
                        try store.delete(activity)
                        onDeleted()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout details")
    }

    private func selectors(_ activity: OutdoorActivity) -> some View {
        Group {
            OutdoorActivityTypePicker(kind: Binding(get: { activity.kind }, set: { kind in
                perform { try store.setKind(kind, for: activity) }
            }))
            OutdoorVisibilityPicker(visibility: Binding(get: { activity.visibility }, set: { visibility in
                perform { try store.setVisibility(visibility, for: activity) }
            }))
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

    private func saveDetails(_ activity: OutdoorActivity) {
        perform {
            try store.updateDetails(for: activity, description: description, tags: outdoorParsedTags(tagText), allowComments: allowComments, hideStartFinish: hideStartFinish, endpointPrivacyMeters: endpointPrivacyMeters, showPlayerTracks: showPlayerTracks)
            showingDetails = false
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
