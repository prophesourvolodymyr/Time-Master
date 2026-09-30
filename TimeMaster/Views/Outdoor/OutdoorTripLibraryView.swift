#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripsMenu: View {
    @ObservedObject var store: OutdoorActivityStore
    var units: OutdoorUnitSystem
    var canSelect: Bool
    var onOpen: (TripPlannerEntry, PlannedRoute?) -> Void
    var onSelect: (PlannedRoute) -> Void
    @State private var library: TripLibrarySection?
    @State private var error: String?
    @State private var recovery: PlannedRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let library {
                    HStack(spacing: 8) {
                        OutdoorPineIconAction(symbol: "chevron.left", label: "Back to trips", size: 40) {
                            self.library = nil
                        }
                        Text(library.title)
                            .font(.headline)
                        Spacer()
                    }
                    OutdoorTripLibraryView(
                        section: library,
                        store: store,
                        units: units,
                        canSelect: canSelect,
                        onEdit: { onOpen(.build, $0) },
                        onSelect: onSelect
                    )
                } else {
                    let savedCount = store.plannedRoutes.filter { !$0.isDraft }.count
                    let draftCount = store.plannedRoutes.filter(\.isDraft).count
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        if let recovery {
                            OutdoorPineTileAction(symbol: "arrow.clockwise.circle", title: "Resume edit") {
                                onOpen(.build, recovery)
                            }
                        }
                        OutdoorPineTileAction(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Make trip") {
                            onOpen(.build, nil)
                        }
                        OutdoorPineTileAction(symbol: "location.magnifyingglass", title: "Nearby") {
                            onOpen(.nearby, nil)
                        }
                        OutdoorPineTileAction(symbol: "slider.horizontal.3", title: "Custom") {
                            onOpen(.custom, nil)
                        }
                        OutdoorPineTileAction(symbol: "map.fill", title: "Saved", badge: savedCount == 0 ? nil : "\(savedCount)") {
                            library = .saved
                        }
                        OutdoorPineTileAction(symbol: "archivebox.fill", title: "Drafts", badge: draftCount == 0 ? nil : "\(draftCount)") {
                            library = .drafts
                        }
                    }
                    if !canSelect {
                        Label("Finish the workout before choosing another trip.", systemImage: "figure.run.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(14)
        }
        .task {
            do { recovery = try store.loadTripRecovery() }
            catch { self.error = error.localizedDescription }
        }
        .alert("Trip recovery", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

}

enum TripLibrarySection: Equatable {
    case saved, drafts
    var title: String { self == .saved ? "Saved trips" : "Drafts" }
}

struct OutdoorTripLibraryView: View {
    let section: TripLibrarySection
    @ObservedObject var store: OutdoorActivityStore
    let units: OutdoorUnitSystem
    let canSelect: Bool
    let onEdit: (PlannedRoute) -> Void
    let onSelect: (PlannedRoute) -> Void
    @State private var deleting: PlannedRoute?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let routes = store.plannedRoutes.filter { $0.isDraft == (section == .drafts) }
            if routes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: section == .drafts ? "archivebox" : "map")
                        .font(.title2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(section == .drafts ? "No drafts" : "No saved trips")
                        .font(.subheadline.weight(.semibold))
                    Text(section == .drafts ? "Archive an unfinished trip to continue it later." : "Make a trip or choose a nearby suggestion.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            ForEach(routes) { route in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: route.isDraft ? "archivebox.fill" : "map.fill")
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityHidden(true)
                        Text(route.title)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    if let trip = route.trip {
                        Label(
                            "\(trip.stops.count) · \(outdoorDistanceText(trip.activeDistanceMeters, unitSystem: units, precision: true))",
                            systemImage: trip.kind.iconName
                        )
                        .font(.subheadline)
                        if trip.hasBus {
                            Label(
                                "\(outdoorDistanceText(trip.totalDistanceMeters, unitSystem: units, precision: true)) total",
                                systemImage: "bus"
                            )
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        }
                        if route.isDraft && !trip.isRouted {
                            Label("Route unfinished", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Label("Imported track", systemImage: "square.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 8) {
                        if !route.isDraft {
                            OutdoorPineIconAction(
                                symbol: "checkmark",
                                label: "Use \(route.title)",
                                prominent: true,
                                disabled: !canSelect
                            ) { onSelect(route) }
                        }
                        if route.trip != nil {
                            OutdoorPineIconAction(
                                symbol: route.isDraft ? "arrow.right" : "pencil",
                                label: route.isDraft ? "Continue \(route.title)" : "Edit \(route.title)"
                            ) { onEdit(route) }
                        }
                        Spacer()
                        OutdoorPineIconAction(symbol: "trash", label: "Delete \(route.title)", role: .destructive) {
                            deleting = route
                        }
                    }
                }
                .padding(.vertical, 8)
                if route.id != routes.last?.id { Divider().overlay(Theme.separator) }
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do { if let deleting { try store.deletePlannedRoute(deleting) }; deleting = nil }
                catch { self.error = error.localizedDescription }
            }
        }
        .alert("Could not delete trip", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }
}

struct OutdoorTripSearchView: View {
    var near: TripCoordinate?
    var currentLocation: TripCoordinate?
    var onSelect: (TripPlace) -> Void
    var onMap: () -> Void
    var onCancel: () -> Void
    @State private var query = ""
    @State private var results: [TripPlace] = []
    @State private var loading = false
    @State private var message: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
                TextField("Place, address, or landmark", text: $query)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("trip.search")
                OutdoorPineIconAction(symbol: "xmark", label: "Cancel stop search", size: 38, action: onCancel)
            }
            HStack(spacing: 8) {
                OutdoorPineIconAction(symbol: "mappin.and.ellipse", label: "Choose on map", action: onMap)
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
        .task { focused = true }
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
