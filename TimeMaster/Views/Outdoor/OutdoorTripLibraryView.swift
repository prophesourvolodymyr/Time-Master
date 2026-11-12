#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripsMenu: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var nearby: OutdoorNearbyRoutes
    @ObservedObject var areas: OutdoorOfflineAreas
    var kind: OutdoorActivityKind
    var units: OutdoorUnitSystem
    var canSelect: Bool
    var onOpen: (TripPlannerEntry, PlannedRoute?) -> Void
    var onManageAreas: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @AppStorage("outdoor.trip.sortOrder") private var sortOrder: OutdoorLibrarySortOrder = .recent
    @State private var library: TripLibrarySection?
    @State private var searchPresented = false
    @State private var query = ""
    @State private var typeFilter: OutdoorLibraryTypeFilter = .all
    @State private var error: String?
    @State private var recovery: PlannedRoute?

    var body: some View {
        VStack(spacing: 4) {
            header
            OutdoorPanePager(key: library, depth: library == nil ? 0 : 1) {
                page
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
            if !searchPresented {
                if library != nil {
                    OutdoorPineIconAction(symbol: "chevron.left", label: "Back to Routes", size: 44) { show(nil) }
                        .transition(.opacity)
                }
                TimeMasterPageTitle(library?.title ?? "Routes", size: 22, relativeTo: .headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .id(library)
                    .transition(.opacity)
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
        .frame(minHeight: 50)
    }

    private var page: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if !searchPresented, library == nil {
                        shortcuts(width: geometry.size.width - 28)
                        if let recovery {
                            Button { onOpen(.build, recovery) } label: {
                                Label("Resume unfinished edit", systemImage: "arrow.clockwise.circle")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(TimeMasterActionButtonStyle())
                        }
                    }
                    if searchPresented || library == nil || library == .nearby {
                        nearbySection(width: geometry.size.width)
                    }
                    if searchPresented || library == nil || library == .yours || library == .saved {
                        yoursSection
                    }
                    if searchPresented || library == nil {
                        starredSection(width: geometry.size.width)
                    }
                    if library == .drafts, !searchPresented {
                        draftsSection
                    }
                    if !canSelect {
                        Label("Finish the workout before starting another route.", systemImage: "figure.run.circle")
                            .font(TimeMasterFont.caption()).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                    Color.black
                }
            }
        }
    }

    private func shortcuts(width: CGFloat) -> some View {
        let saved = store.plannedRoutes.filter { !$0.isDraft }.count
        let drafts = store.plannedRoutes.filter(\.isDraft).count
        return VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                OutdoorPineTileAction(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Make trip") { onOpen(.build, nil) }
                OutdoorPineTileAction(symbol: "location.magnifyingglass", title: "Nearby", badge: nearby.routes.isEmpty ? nil : nearby.routes.count.formatted()) { show(.nearby) }
                OutdoorPineTileAction(symbol: "slider.horizontal.3", title: "Custom") { show(.yours) }
                OutdoorPineTileAction(symbol: "map.fill", title: "Saved", badge: saved > 0 ? saved.formatted() : nil) { show(.saved) }
            }
            OutdoorPineTileAction(symbol: "archivebox.fill", title: "Drafts", badge: drafts > 0 ? drafts.formatted() : nil) { show(.drafts) }
                .frame(width: max(0, (width - 10) / 2))
        }
    }

    private func nearbySection(width: CGFloat) -> some View {
        let routes = filtered(nearby.routes, preservingRank: true)
        let page = library == .nearby && !searchPresented
        return VStack(alignment: .leading, spacing: 12) {
            if !page {
                OutdoorPaneSectionHeader(
                    title: "Nearby", symbol: "location.magnifyingglass", count: routes.count,
                    onShowAll: library == nil && !searchPresented ? { show(.nearby) } : nil
                )
            }
            if routes.isEmpty {
                nearbyStatus
            } else if page {
                grid(routes)
            } else {
                horizontal(routes, width: width)
            }
            if page {
                Button { onOpen(.custom, nil) } label: {
                    Label("Adjust distance and places", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(TimeMasterActionButtonStyle())
            }
        }
    }

    private var yoursSection: some View {
        let routes = filtered(store.plannedRoutes.filter { !$0.isDraft })
        let page = (library == .yours || library == .saved) && !searchPresented
        return VStack(alignment: .leading, spacing: 12) {
            if !page {
                OutdoorPaneSectionHeader(
                    title: "Yours", symbol: "map.fill", count: routes.count,
                    onShowAll: library == nil && !searchPresented && !routes.isEmpty ? { show(.yours) } : nil
                )
            }
            if routes.isEmpty {
                OutdoorPaneStatusTile(symbol: "map", title: query.isEmpty ? "No saved routes yet" : "No matching routes") {
                    if query.isEmpty { makeTripAction }
                }
            } else {
                grid(routes)
            }
        }
    }

    private func starredSection(width: CGFloat) -> some View {
        let routes = filtered(store.plannedRoutes.filter(\.starred))
        let hasSaved = store.plannedRoutes.contains { !$0.isDraft }
        return VStack(alignment: .leading, spacing: 12) {
            OutdoorPaneSectionHeader(title: "Starred", symbol: "star.fill", count: routes.count)
            if routes.isEmpty {
                OutdoorPaneStatusTile(symbol: "star", title: query.isEmpty ? "Long-press a route to star it" : "No matching starred routes") {
                    if query.isEmpty {
                        if hasSaved {
                            OutdoorPaneLabeledAction(symbol: "map.fill", title: "Yours", accessibilityTitle: "Open your routes") { show(.yours) }
                        } else {
                            makeTripAction
                        }
                    }
                }
            } else {
                horizontal(routes, width: width)
            }
        }
    }

    private var draftsSection: some View {
        let routes = filtered(store.plannedRoutes.filter(\.isDraft))
        return Group {
            if routes.isEmpty {
                OutdoorPaneStatusTile(symbol: "archivebox", title: query.isEmpty ? "No drafts" : "No matching drafts") {
                    if query.isEmpty { makeTripAction }
                }
            } else {
                grid(routes)
            }
        }
    }

    private var makeTripAction: some View {
        OutdoorPaneLabeledAction(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Make trip") { onOpen(.build, nil) }
    }

    @ViewBuilder
    private var nearbyStatus: some View {
        if nearby.isLoading {
            OutdoorPaneStatusTile(symbol: "location.magnifyingglass", title: "Finding roads near you…", loading: true) { EmptyView() }
        } else if nearby.location == nil {
            OutdoorPaneStatusTile(
                symbol: nearby.locationDenied ? "location.slash" : "location",
                title: nearby.locationDenied ? "Location is off" : "Waiting for your location",
                detail: nearby.errorMessage
            ) {
                if nearby.locationDenied {
                    OutdoorPaneLabeledAction(symbol: "gearshape", title: "Settings", accessibilityTitle: "Location settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    OutdoorPaneLabeledAction(symbol: "location.fill", title: "Locate", accessibilityTitle: "Use current location") {
                        nearby.requestLocation()
                    }
                }
            }
        } else if let message = nearby.errorMessage {
            let issue = nearbyIssue
            OutdoorPaneStatusTile(symbol: issue.symbol, title: issue.title, detail: message, stacksActions: true) {
                OutdoorPaneLabeledAction(symbol: "arrow.clockwise", title: "Try again", accessibilityTitle: "Find nearby routes again") {
                    nearby.refresh(kind: kind)
                }
                OutdoorPaneLabeledAction(symbol: "square.and.arrow.down", title: "Offline areas", action: onManageAreas)
            }
        } else {
            OutdoorPaneStatusTile(
                symbol: "point.topleft.down.to.point.bottomright.curvepath",
                title: query.isEmpty ? "No nearby routes in your areas" : "No matching nearby routes"
            ) {
                if query.isEmpty {
                    OutdoorPaneLabeledAction(symbol: "slider.horizontal.3", title: "Adjust", accessibilityTitle: "Adjust distance and places") {
                        onOpen(.custom, nil)
                    }
                }
            }
        }
    }

    private var nearbyIssue: (symbol: String, title: String) {
        guard !areas.isLoading else { return ("exclamationmark.triangle", "Nearby routes unavailable") }
        let compatible = areas.regions.filter(\.compatible)
        if areas.regions.isEmpty { return ("arrow.down.circle", "No offline area installed") }
        if compatible.isEmpty { return ("arrow.triangle.2.circlepath", "Offline areas need an update") }
        if let location = nearby.location, !compatible.contains(where: { $0.manifest.bounds.contains(location) }) {
            return ("location.slash", "You're outside your offline areas")
        }
        return ("exclamationmark.triangle", "Nearby routes unavailable")
    }

    private func show(_ section: TripLibrarySection?) {
        withAnimation(OutdoorPaneMotion.page(reduceMotion: reduceMotion)) { library = section }
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

    private func grid(_ routes: [PlannedRoute]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
            ForEach(routes) { route in card(route) }
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
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            if loading {
                TmaxLoadingIndicator()
                    .accessibilityLabel("Searching offline places")
            }
            if let message { Text(message).font(TimeMasterFont.caption()).foregroundStyle(Theme.textSecondary) }
            if query.isEmpty { Text("Search stays on this device. Places come from your installed areas.").font(TimeMasterFont.caption()).foregroundStyle(Theme.textSecondary) }
            ForEach(results) { place in
                Button { onSelect(place) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(place.name)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Theme.textPrimary)
                            if !place.detail.isEmpty {
                                Text(place.detail)
                                    .font(TimeMasterFont.caption())
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
