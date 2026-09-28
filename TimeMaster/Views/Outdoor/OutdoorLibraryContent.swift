#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorLibraryContent<Handle: View>: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    @Binding var selectedActivityID: UUID?
    @Binding var isEditing: Bool
    let onClose: () -> Void
    let onShowMap: () -> Void
    let onModalStateChange: (Bool) -> Void
    @ViewBuilder let handle: () -> Handle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var typeFilter: OutdoorLibraryTypeFilter = .all
    @State private var sortOrder: OutdoorLibrarySortOrder = .recent
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var routePoints: [UUID: [OutdoorTrackPoint]] = [:]
    @State private var errorMessage: String?
    @ScaledMetric(relativeTo: .body) private var starredMinimumWidth: CGFloat = 112

    private var filteredActivities: [OutdoorActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = store.establishedActivities.filter { activity in
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
                    isEditing: $isEditing,
                    onShowMap: onShowMap,
                    onDeleted: { self.selectedActivityID = nil },
                    onModalStateChange: onModalStateChange
                )
                .transition(.opacity)
            } else {
                GeometryReader { proxy in
                    let activities = filteredActivities
                    let starred = activities.filter(\.starred)
                    libraryList(activities: activities, starred: starred, width: proxy.size.width)
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selectedActivityID)
        .onAppear { loadRoutePoints() }
        .onChange(of: store.activities) { _ in
            loadRoutePoints()
            if let selectedActivityID, !store.establishedActivities.contains(where: { $0.id == selectedActivityID }) {
                self.selectedActivityID = nil
            }
        }
        .onChange(of: searchPresented) { if !$0 { typeFilter = .all } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selectedActivityID == nil ? "Outdoor workout library" : "Outdoor workout details")
    }

    private func libraryList(activities: [OutdoorActivity], starred: [OutdoorActivity], width: CGFloat) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                handle()
                ZStack {
                    if !searchPresented {
                        Text(starred.isEmpty ? "Recent" : "Starred")
                            .font(.title2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 48 * 2 + 16)
                            .accessibilityAddTraits(.isHeader)
                    }
                    HStack(spacing: 8) {
                        if !searchPresented {
                            Button(action: onClose) { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                                .buttonStyle(SpotlightCircleButtonStyle())
                                .accessibilityLabel("Back to Start")
                        }
                        Spacer(minLength: 0)
                        SpotlightSearchBar(text: $searchText, isPresented: $searchPresented, placeholder: "Search routes") {
                            OutdoorChoicePicker(
                                title: "Filter workout type",
                                selection: $typeFilter,
                                options: OutdoorLibraryTypeFilter.allCases.map {
                                    OutdoorChoiceOption(id: $0, title: $0.title, systemImage: $0.systemImage)
                                },
                                compact: true
                            )
                        }
                        if !searchPresented {
                            OutdoorChoicePicker(
                                title: "Sort workout library",
                                selection: $sortOrder,
                                options: OutdoorLibrarySortOrder.allCases.map {
                                    OutdoorChoiceOption(id: $0, title: $0.title, systemImage: "arrow.up.arrow.down")
                                },
                                compact: true
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .animation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.84), value: searchPresented)
            }
            if let errorMessage { OutdoorInlineError(message: errorMessage).padding(.horizontal, 16) }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    if !starred.isEmpty {
                        VStack(spacing: 12) {
                            if searchPresented { sectionTitle("Starred") }
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(starred) { activity in
                                        card(activity, showsDistance: false)
                                            .frame(width: min(width - 32, max(starredMinimumWidth, (width - 32) / 3)))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .transition(.opacity)
                    }
                    if activities.isEmpty {
                        OutdoorLibraryEmptyState(
                            title: store.establishedActivities.isEmpty ? "Your next ride starts here" : "No matching workouts",
                            message: store.establishedActivities.isEmpty ? "Saved workouts will appear here with their recorded routes." : "Try another name, tag, or activity type.",
                            systemImage: store.establishedActivities.isEmpty ? "map" : "magnifyingglass"
                        )
                        .padding(.horizontal, 20)
                    } else {
                        if !starred.isEmpty || searchPresented { sectionTitle("Recent") }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 16) {
                            ForEach(activities) { activity in card(activity, showsDistance: true) }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 2)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }

    private func card(_ activity: OutdoorActivity, showsDistance: Bool) -> some View {
        OutdoorLibraryCard(
            activity: activity,
            points: routePoints[activity.id] ?? [],
            units: preferences.preferences.unitSystem,
            showsDistance: showsDistance,
            onSelect: { selectedActivityID = activity.id }
        )
        .contextMenu {
            Button {
                do { try store.toggleStarred(for: activity) }
                catch { errorMessage = error.localizedDescription }
            } label: {
                Label(activity.starred ? "Remove star" : "Star workout", systemImage: activity.starred ? "star.slash" : "star")
            }
            Button {
                selectedActivityID = activity.id
                isEditing = true
            } label: {
                Label("Edit workout", systemImage: "pencil")
            }
        }
    }

    private func loadRoutePoints() {
        let established = store.establishedActivities
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
    let showsDistance: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottom) {
                OutdoorRouteThumbnailView(points: points, compact: true, cacheKey: activity.id.uuidString, aspectRatio: 1)
                    .accessibilityHidden(true)
                if showsDistance {
                    let distance = outdoorRouteDistanceParts(activity.distanceMeters, units: units)
                    Text("\(distance.value) \(distance.unit)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.regularMaterial)
                        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.15)) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(activity.title), \(activity.kind.displayName), \(outdoorDistanceText(activity.distanceMeters, unitSystem: units))\(activity.starred ? ", starred" : "")")
        .accessibilityHint("View workout details. More actions are available in the context menu.")
    }
}

struct OutdoorLibraryEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage).font(.title2).foregroundStyle(Theme.restAccent)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }
}
#endif
