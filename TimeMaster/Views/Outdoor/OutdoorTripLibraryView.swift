#if os(iOS)
import SwiftUI
import CoreLocation
import TimeMasterCore

struct OutdoorTripsMenu: View {
    @ObservedObject var store: OutdoorActivityStore
    var kind: OutdoorActivityKind
    var units: OutdoorUnitSystem
    var canSelect: Bool
    var onSelect: (PlannedRoute) -> Void
    @State private var editing: PlannedRoute?
    @State private var library: TripLibrarySection?
    @State private var error: String?
    @State private var recovery: PlannedRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let recovery {
                    Button { editing = recovery } label: { Label("Resume interrupted edit", systemImage: "arrow.clockwise") }
                        .buttonStyle(OutdoorPineButtonStyle())
                }
                menuButton("Make a Trip", symbol: "point.topleft.down.curvedto.point.bottomright.up") {
                    var route = PlannedRoute(title: "New trip", points: [])
                    route.trip = OutdoorTrip(kind: kind)
                    editing = route
                }
                menuButton("Nearby suggested routes", symbol: "sparkles") { library = .nearby }
                menuButton("Custom suggestions", symbol: "slider.horizontal.3") { library = .custom }
                menuButton("Saved trips", symbol: "map") { library = .saved }
                menuButton("Drafts", symbol: "archivebox") { library = .drafts }
                if !canSelect { Text("Finish the current workout before selecting another trip.").font(.caption).foregroundStyle(Theme.textSecondary) }
            }.padding(14)
        }
        .task { loadRecovery() }
        .fullScreenCover(item: $editing, onDismiss: loadRecovery) { route in
            OutdoorTripPlannerView(route: route, kind: kind, store: store, units: units) { saved in
                if !saved.isDraft, canSelect { onSelect(saved) }
            }
        }
        .sheet(item: $library, onDismiss: loadRecovery) { section in
            OutdoorTripLibraryView(section: section, store: store, kind: kind, units: units, canSelect: canSelect, onSelect: onSelect)
        }
        .alert("Trip recovery", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func menuButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(OutdoorPineButtonStyle())
    }
    private func loadRecovery() {
        do { recovery = try store.loadTripRecovery() }
        catch { self.error = error.localizedDescription }
    }
}

enum TripLibrarySection: String, Identifiable {
    case nearby, custom, saved, drafts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nearby: "Nearby routes"
        case .custom: "Custom suggestions"
        case .saved: "Saved trips"
        case .drafts: "Drafts"
        }
    }
}

struct OutdoorTripLibraryView: View {
    let section: TripLibrarySection
    @ObservedObject var store: OutdoorActivityStore
    let kind: OutdoorActivityKind
    let units: OutdoorUnitSystem
    let canSelect: Bool
    let onSelect: (PlannedRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PlannedRoute?
    @State private var deleting: PlannedRoute?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if section == .nearby || section == .custom {
                    OutdoorTripSuggestionsView(custom: section == .custom, kind: kind, units: units) { editing = $0 }
                } else {
                    List {
                        let routes = store.plannedRoutes.filter { $0.isDraft == (section == .drafts) }
                        if routes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section == .drafts ? "No drafts yet" : "No saved trips yet").font(.headline)
                                Text(section == .drafts ? "Archive an unfinished trip to continue it later." : "Build a trip or choose a suggested route, then save it.").foregroundStyle(.secondary)
                            }.padding(.vertical)
                        }
                        ForEach(routes) { route in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(route.title).font(.headline)
                                if let trip = route.trip {
                                    Text("\(trip.stops.count) stops · \(outdoorDistanceText(trip.ridingDistanceMeters, unitSystem: units, precision: true)) \(trip.kind == .bike ? "riding" : "on foot")")
                                        .font(.subheadline)
                                    if trip.hasBus { Text("\(outdoorDistanceText(trip.totalDistanceMeters, unitSystem: units, precision: true)) total with bus").font(.caption).foregroundStyle(.secondary) }
                                    if route.isDraft && !trip.isRouted { Text("Unfinished route").font(.caption).foregroundStyle(.secondary) }
                                } else { Text("Imported route · original track retained").font(.caption).foregroundStyle(.secondary) }
                                HStack {
                                    if !route.isDraft {
                                        Button("Use trip") { onSelect(route); dismiss() }.disabled(!canSelect)
                                            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                                    }
                                    if route.trip != nil {
                                        Button(route.isDraft ? "Continue" : "Edit") { editing = route }.buttonStyle(OutdoorPineButtonStyle())
                                    }
                                    Spacer()
                                    Button { deleting = route } label: { Image(systemName: "trash") }
                                        .buttonStyle(OutdoorPineButtonStyle(circular: true)).accessibilityLabel("Delete \(route.title)")
                                }
                            }.padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle(section.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Theme.toolbarOrange).preferredColorScheme(.dark)
        .fullScreenCover(item: $editing) { route in
            OutdoorTripPlannerView(route: route, kind: kind, store: store, units: units) { saved in
                if !saved.isDraft, canSelect { onSelect(saved) }
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do { if let deleting { try store.deletePlannedRoute(deleting) }; deleting = nil }
                catch { self.error = error.localizedDescription }
            }
        }
        .alert("Could not delete trip", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
    }
}

struct OutdoorTripSearchView: View {
    var near: TripCoordinate?
    var onSelect: (TripPlace) -> Void
    var onMap: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TripPlace] = []
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let onMap {
                    Button(action: onMap) { Label("Choose on map", systemImage: "mappin.and.ellipse") }
                }
                if let near {
                    Button("Use trip start") { onSelect(TripPlace(id: "start", name: "Trip start", detail: "", coordinate: near)) }
                }
                if loading { ProgressView("Searching places…") }
                if let message { Text(message).foregroundStyle(.secondary) }
                ForEach(results) { place in
                    Button { onSelect(place) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).foregroundStyle(.primary)
                            Text(place.detail).font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }
                }
                SwiftUI.Section { Text("Place searches are sent to the Photon service selected in Trip Services. © OpenStreetMap contributors.").font(.caption).foregroundStyle(.secondary) }
            }
            .searchable(text: $query, prompt: "Place, address, or landmark")
            .navigationTitle("Choose a stop")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: query) {
                results = []
                message = nil
                loading = false
                let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count >= 3 else { return }
                do {
                    try await Task.sleep(nanoseconds: 650_000_000)
                    loading = true
                    let found = try await OutdoorTripService().search(text, near: near)
                    try Task.checkCancellation()
                    results = found
                    loading = false
                    if found.isEmpty { message = "No matching places. Try a nearby street or landmark." }
                } catch {
                    guard !Task.isCancelled else { return }
                    loading = false
                    message = error.localizedDescription
                }
            }
        }.tint(Theme.toolbarOrange).preferredColorScheme(.dark)
    }
}

struct OutdoorTripServicesView: View {
    var onSave: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = TripServiceConfiguration.current
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("GraphHopper routing") {
                    TextField("https://your-routing-server", text: $configuration.routingURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Text("Use the routing/graphhopper.yml profiles from this project. No API key is embedded. The server needs map coverage for your area; terrain goals require elevation data.").font(.caption)
                }
                SwiftUI.Section("Place search · Photon") { TextField("HTTPS endpoint", text: $configuration.searchURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL) }
                SwiftUI.Section("Nearby places · Overpass") { TextField("HTTPS endpoint", text: $configuration.placesURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL) }
                SwiftUI.Section("Privacy & availability") {
                    Text("Routing sends your selected stops and route adjustments to the routing server. Searches and suggestions send search text or a search area to their providers. Public Photon and Overpass endpoints are community services with no availability guarantee. Saved geometry and drafts remain on this device and in your backups; new routing requires network access.")
                }
                if let error { SwiftUI.Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Trip Services")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        do { try configuration.save(); onSave(); dismiss() } catch { self.error = error.localizedDescription }
                    } }
                }
        }.tint(Theme.toolbarOrange).preferredColorScheme(.dark)
    }
}

@MainActor
final class OutdoorTripLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: TripCoordinate?
    @Published var message: String?
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: message = "Location is unavailable. Choose a starting place instead."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 500, abs(location.timestamp.timeIntervalSinceNow) < 60 else { message = "Waiting for a more accurate location."; return }
        coordinate = TripCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        message = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = error.localizedDescription }
}

struct OutdoorTripSuggestionsView: View {
    let custom: Bool
    let kind: OutdoorActivityKind
    let units: OutdoorUnitSystem
    let onChoose: (PlannedRoute) -> Void
    @StateObject private var location = OutdoorTripLocation()
    @State private var origin: TripStop?
    @State private var distance = 20.0
    @State private var count = 0
    @State private var categories: Set<TripPlaceCategory> = [.parks]
    @State private var preference: TripRoutingPreference = .bikeRoads
    @State private var runningGoal: TripRunningGoal = .balanced
    @State private var routes: [PlannedRoute] = []
    @State private var busy = false
    @State private var message: String?
    @State private var generation = UUID()
    @State private var request: Task<Void, Never>?
    @State private var searchPresented = false
    @State private var servicesPresented = false

    var body: some View {
        List {
            SwiftUI.Section("Starting place") {
                Button(origin?.name ?? "Choose a start") { searchPresented = true }
                Button("Use current location", systemImage: "location") {
                    if let coordinate = location.coordinate { origin = TripStop(name: "Current location", coordinate: coordinate) }
                    else { location.request() }
                }
                if let message = location.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            SwiftUI.Section(custom ? "Route requirements" : "Nearby loops") {
                HStack {
                    Text("Distance (\(units == .metric ? "km" : "mi"))")
                    TextField("Distance", value: $distance, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                if custom {
                    Stepper("\(count) places", value: $count, in: 0...8)
                    if count > 0 {
                        ForEach(TripPlaceCategory.allCases) { category in
                            Toggle(category.title, isOn: Binding(get: { categories.contains(category) }, set: { if $0 { categories.insert(category) } else { categories.remove(category) } }))
                        }
                    }
                    Picker("Routing", selection: $preference) { ForEach(TripRoutingPreference.allCases) { Text($0.title(for: kind)).tag($0) } }
                    if kind != .bike {
                        Picker("Running goal", selection: $runningGoal) { ForEach(TripRunningGoal.allCases) { Text($0.title).tag($0) } }
                    }
                }
                Text("Real road loops, sorted by estimated effort. Distance tolerance: 25%, or 1 km for short trips. Unknown terrain is shown as unknown, never assumed flat or safe.").font(.caption).foregroundStyle(.secondary)
                if busy {
                    HStack { ProgressView("Finding connected routes…"); Spacer(); Button("Cancel") { cancel() } }
                } else {
                    Button("Find routes") { generate() }.disabled(origin == nil || !distance.isFinite || distance <= 0 || (count > 0 && categories.isEmpty))
                }
                Button("Trip Services") { servicesPresented = true }
            }
            if let message { SwiftUI.Section { Text(message).foregroundStyle(.secondary) } }
            ForEach(routes) { route in
                SwiftUI.Section {
                    Button { onChoose(route) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(route.title).font(.headline)
                            if let trip = route.trip {
                                Text(outdoorDistanceText(trip.ridingDistanceMeters, unitSystem: units, precision: true)).font(.title3.bold())
                                Text(trip.explanation).font(.caption).foregroundStyle(.secondary)
                                Text("Preview & adjust").font(.subheadline.weight(.semibold))
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
        .onAppear { if kind != .bike && distance == 20 { distance = 5 }; location.request() }
        .onReceive(location.$coordinate) { coordinate in if origin == nil, let coordinate { origin = TripStop(name: "Current location", coordinate: coordinate) } }
        .onDisappear { cancel() }
        .sheet(isPresented: $searchPresented) {
            OutdoorTripSearchView(near: location.coordinate, onSelect: { origin = TripStop(name: $0.name, coordinate: $0.coordinate); searchPresented = false })
        }
        .sheet(isPresented: $servicesPresented) { OutdoorTripServicesView() }
    }

    private func cancel() { generation = UUID(); request?.cancel(); busy = false }
    private func generate() {
        guard let origin else { return }
        cancel()
        let token = generation
        busy = true
        message = nil
        routes = []
        let meters = distance * (units == .metric ? 1_000 : 1_609.344)
        let stops = custom ? count : 0
        let categories = categories
        let preference = preference
        let runningGoal = runningGoal
        request = Task {
            do {
                let results = try await OutdoorTripService().suggestions(origin: origin, kind: kind, distance: meters, stopCount: stops, categories: categories, preference: preference, runningGoal: runningGoal)
                try Task.checkCancellation()
                guard generation == token else { return }
                routes = results
                busy = false
            } catch {
                guard generation == token, !Task.isCancelled else { return }
                busy = false
                message = error.localizedDescription
            }
        }
    }
}
#endif
