#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripsMenu: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var nearby: OutdoorNearbyRoutes
    var kind: OutdoorActivityKind
    var units: OutdoorUnitSystem
    var canSelect: Bool
    var onOpen: (TripPlannerEntry, PlannedRoute?) -> Void
    var onManageAreas: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @AppStorage("outdoor.trip.sortOrder") private var sortOrder: OutdoorLibrarySortOrder = .recent
    @State private var library: TripLibrarySection?
    @State private var searchPresented = false
    @State private var query = ""
    @State private var typeFilter: OutdoorLibraryTypeFilter = .all
    @State private var error: String?
    @State private var recovery: PlannedRoute?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                header
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if !searchPresented, library == nil {
                                shortcuts(width: geometry.size.width - 28, scroll: scroll)
                                if let recovery {
                                    Button { onOpen(.build, recovery) } label: {
                                        Label("Resume unfinished edit", systemImage: "arrow.clockwise.circle")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(OutdoorPineButtonStyle())
                                }
                            }
                            if searchPresented || library == nil || library == .nearby {
                                sectionTitle("Nearby")
                                    .id(TripLibrarySection.nearby)
                                let routes = filtered(nearby.routes, preservingRank: true)
                                if routes.isEmpty { nearbyStatus } else {
                                    horizontal(routes, width: geometry.size.width)
                                }
                                if library == .nearby, !searchPresented {
                                    Button { onOpen(.custom, nil) } label: {
                                        Label("Adjust distance and places", systemImage: "slider.horizontal.3")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(OutdoorPineButtonStyle())
                                }
                            }
                            if searchPresented || library == nil || library == .yours || library == .saved {
                                sectionTitle(library == .saved && !searchPresented ? "Saved routes" : "Yours")
                                vertical(filtered(store.plannedRoutes.filter { !$0.isDraft }), empty: "No saved routes")
                            }
                            if searchPresented || library == nil {
                                sectionTitle("Starred")
                                let routes = filtered(store.plannedRoutes.filter(\.starred))
                                if routes.isEmpty { emptyState(query.isEmpty ? "Star routes to keep them here" : "No matching starred routes") }
                                else { horizontal(routes, width: geometry.size.width) }
                            }
                            if library == .drafts, !searchPresented {
                                sectionTitle("Drafts")
                                vertical(filtered(store.plannedRoutes.filter(\.isDraft)), empty: "No drafts")
                            }
                            if !canSelect {
                                Label("Finish the workout before starting another route.", systemImage: "figure.run.circle")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .task(id: kind) { nearby.activate(kind: kind) }
        .onDisappear { nearby.deactivate() }
        .task {
            do { recovery = try store.loadTripRecovery() }
            catch { self.error = error.localizedDescription }
        }
        .alert("Route could not be updated", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if library != nil, !searchPresented {
                OutdoorPineIconAction(symbol: "chevron.left", label: "Back to Routes", size: 44) { library = nil }
                Text(library?.title ?? "Routes").font(.headline).lineLimit(1)
            }
            Spacer(minLength: 0)
            SpotlightSearchBar(text: $query, isPresented: $searchPresented, placeholder: "Search routes") {
                OutdoorChoicePicker(
                    title: "Filter route activity", selection: $typeFilter,
                    options: OutdoorLibraryTypeFilter.allCases.map {
                        OutdoorChoiceOption(id: $0, title: $0.title, systemImage: $0.systemImage)
                    }, compact: true
                )
            }
            if !searchPresented {
                OutdoorChoicePicker(
                    title: "Sort routes", selection: $sortOrder,
                    options: OutdoorLibrarySortOrder.allCases.map {
                        OutdoorChoiceOption(id: $0, title: $0.title, systemImage: "arrow.up.arrow.down")
                    }, compact: true
                )
            }
        }
        .padding(.horizontal, 14)
    }

    private func shortcuts(width: CGFloat, scroll: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                OutdoorPineTileAction(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Make trip") { onOpen(.build, nil) }
                OutdoorPineTileAction(symbol: "location.magnifyingglass", title: "Nearby") {
                    library = .nearby
                    scroll.scrollTo(TripLibrarySection.nearby, anchor: .top)
                }
                OutdoorPineTileAction(symbol: "slider.horizontal.3", title: "Custom") { library = .yours }
                OutdoorPineTileAction(symbol: "map.fill", title: "Saved") { library = .saved }
            }
            OutdoorPineTileAction(symbol: "archivebox.fill", title: "Drafts") { library = .drafts }
                .frame(width: max(0, (width - 10) / 2))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
    }

    private func horizontal(_ routes: [PlannedRoute], width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(routes) { route in
                    card(route).frame(width: dynamicTypeSize.isAccessibilitySize ? max(140, width - 40) : max(140, (width - 40) / 2))
                }
            }
        }
    }

    private func vertical(_ routes: [PlannedRoute], empty: String) -> some View {
        Group {
            if routes.isEmpty { emptyState(query.isEmpty ? empty : "No matching routes") }
            else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(routes) { route in card(route) }
                }
            }
        }
    }

    private func card(_ candidate: PlannedRoute) -> some View {
        let route = store.plannedRoutes.first { $0.id == candidate.id } ?? candidate
        return OutdoorPlannedRouteCard(route: route, units: units) {
            onOpen(route.isDraft && route.trip?.isRouted != true ? .build : .preview, route)
        }
        .contextMenu {
            Button(route.starred ? "Unstar" : "Star", systemImage: route.starred ? "star.slash" : "star") {
                do { try store.setStarred(!route.starred, for: route) }
                catch { self.error = error.localizedDescription }
            }
        }
    }

    private var nearbyStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            if nearby.isLoading {
                ProgressView("Finding roads near you…").tint(Theme.toolbarOrange)
            } else if nearby.location == nil {
                Label(nearby.locationDenied ? "Location access is unavailable" : "Waiting for your current location", systemImage: "location")
                Button(nearby.locationDenied ? "Location settings" : "Use current location") {
                    if nearby.locationDenied, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    else { nearby.requestLocation() }
                }
                .frame(minHeight: 44)
            } else if let message = nearby.errorMessage {
                Text(message).font(.caption).foregroundStyle(Theme.textSecondary)
                HStack {
                    Button("Try again") { nearby.refresh(kind: kind) }.frame(minHeight: 44)
                    Spacer()
                    Button("Offline areas", action: onManageAreas).frame(minHeight: 44)
                }
            } else {
                Text(query.isEmpty ? "No nearby routes available in the installed area." : "No matching nearby routes")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private func emptyState(_ title: String) -> some View {
        Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
    }

    private func filtered(_ routes: [PlannedRoute], preservingRank: Bool = false) -> [PlannedRoute] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = routes.filter { route in
            let routeKind = route.trip?.kind
            let matchesKind = !searchPresented || typeFilter == .all || routeKind?.rawValue == typeFilter.rawValue
            return matchesKind && (search.isEmpty || route.title.localizedCaseInsensitiveContains(search)
                || routeKind?.displayName.localizedCaseInsensitiveContains(search) == true
                || route.trip?.stops.contains { $0.name.localizedCaseInsensitiveContains(search) } == true)
        }
        if preservingRank && sortOrder == .recent { return filtered }
        switch sortOrder {
        case .distance:
            var measured = filtered.map { (route: $0, distance: $0.distanceMeters) }
            measured.sort {
                $0.distance == $1.distance ? $0.route.id.uuidString < $1.route.id.uuidString : $0.distance > $1.distance
            }
            return measured.map { $0.route }
        case .recent:
            return filtered.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt }
        case .oldest:
            return filtered.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
        case .name:
            return filtered.sorted {
                let order = $0.title.localizedStandardCompare($1.title)
                return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
            }
        }
    }
}

private enum TripLibrarySection: Hashable {
    case nearby, yours, saved, drafts
    var title: String {
        switch self {
        case .nearby: "Nearby"
        case .yours: "Yours"
        case .saved: "Saved routes"
        case .drafts: "Drafts"
        }
    }
}

struct OutdoorTripSearchView: View {
    var near: TripCoordinate?
    var currentLocation: TripCoordinate?
    var onSelect: (TripPlace) -> Void
    var onMap: () -> Void
    var onCancel: () -> Void
    @Binding var query: String
    @State private var results: [TripPlace] = []
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                OutdoorPineIconAction(symbol: "mappin.and.ellipse", label: "Choose on map", action: onMap)
                OutdoorPineIconAction(symbol: "xmark", label: "Cancel stop search", action: onCancel)
                if let currentLocation {
                    OutdoorPineIconAction(symbol: "location.fill", label: "Use current location") {
                        onSelect(TripPlace(id: "current", name: "Current location", detail: "", coordinate: currentLocation))
                    }
                }
                Spacer(minLength: 8)
                Label("Offline", systemImage: "iphone")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            if loading {
                ProgressView()
                    .accessibilityLabel("Searching offline places")
            }
            if let message { Text(message).font(.caption).foregroundStyle(Theme.textSecondary) }
            if query.isEmpty { Text("Search stays on this device. Places come from your installed areas.").font(.caption).foregroundStyle(Theme.textSecondary) }
            ForEach(results) { place in
                Button { onSelect(place) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(place.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            if !place.detail.isEmpty {
                                Text(place.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .task(id: query) {
            results = []
            message = nil
            loading = false
            let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count >= 2 else { return }
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
                loading = true
                let matches = try await OutdoorTripService().search(value, near: near)
                try Task.checkCancellation()
                results = matches
                loading = false
                if matches.isEmpty {
                    message = "No matching places in your installed areas. Try a nearby street or choose on the map."
                }
            } catch {
                guard !Task.isCancelled else { return }
                loading = false
                message = error.localizedDescription
            }
        }
}
}
#endif
