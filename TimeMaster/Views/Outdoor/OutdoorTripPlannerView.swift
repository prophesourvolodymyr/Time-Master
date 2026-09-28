#if os(iOS)
import SwiftUI
import CoreLocation
import TimeMasterCore

struct OutdoorTripPlannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var editor: OutdoorTripEditor
    @Namespace private var glass
    @State private var expanded = true
    @State private var searchPresented = false
    @State private var replacingID: UUID?
    @State private var picking = false
    @State private var servicesPresented = false
    @State private var deletePresented = false
    @State private var directionsPresented = false
    @State private var closePresented = false
    @State private var error: String?
    @State private var focusRequest = 0
    @State private var fitRequest = 0
    @State private var northRequest = 0
    @State private var panelHeight: CGFloat = 0
    @State private var stopsHeight: CGFloat = 44
    @State private var followsUser = false
    @State private var mapMode: OutdoorMapMode = .explore
    let units: OutdoorUnitSystem
    let onSaved: (PlannedRoute) -> Void
    private let mapConfiguration = OutdoorMapProviderConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])

    init(route: PlannedRoute?, kind: OutdoorActivityKind, store: OutdoorActivityStore, units: OutdoorUnitSystem, onSaved: @escaping (PlannedRoute) -> Void) {
        _editor = StateObject(wrappedValue: OutdoorTripEditor(route: route, kind: kind, store: store))
        self.units = units
        self.onSaved = onSaved
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                OutdoorMapLibreView(
                    points: [], followsUser: followsUser, state: .idle,
                    plannedPoints: editor.mapPoints, mode: mapMode,
                    focusRequestID: focusRequest, northRequestID: northRequest, routeFitRequestID: fitRequest,
                    onFollowStateChange: { followsUser = $0 }, onFocusFailure: { error = $0 },
                    tripEditing: TripMapEditing(
                        trip: editor.trip, revision: editor.revision, picking: picking, topInset: panelHeight,
                        onPick: { coordinate in
                            editor.putStop(TripPlace(id: UUID().uuidString, name: "Map point", detail: "", coordinate: coordinate), replacing: replacingID)
                            picking = false
                            replacingID = nil
                        },
                        onBeginDrag: editor.beginDrag, onDrag: editor.updateDrag, onCancelDrag: editor.cancelDrag,
                        onLocation: editor.setCurrentLocation
                    )
                )
                .ignoresSafeArea()
                VStack(spacing: 10) {
                    destinationPanel(maximumHeight: proxy.size.height * 0.42)
                        .background(GeometryReader { geometry in Color.clear.preference(key: TripPanelHeightKey.self, value: geometry.size.height) })
                    mapControls
                    if picking {
                        HStack {
                            Text("Tap a road or path to place this stop").font(.subheadline)
                            Button("Cancel") { picking = false }.font(.subheadline.bold())
                        }
                        .padding(12).background(.regularMaterial, in: Capsule())
                    }
                    Spacer(minLength: 8)
                    bottomBar
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onPreferenceChange(TripPanelHeightKey.self) { panelHeight = $0 }
            .onPreferenceChange(TripStopsHeightKey.self) { stopsHeight = $0 }
        }
        .foregroundStyle(Theme.textPrimary)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .sheet(isPresented: $searchPresented) {
            OutdoorTripSearchView(near: editor.trip.stops.first?.coordinate, onSelect: { place in
                editor.putStop(place, replacing: replacingID)
                replacingID = nil
                searchPresented = false
            }, onMap: { searchPresented = false; picking = true })
        }
        .sheet(isPresented: $servicesPresented) { OutdoorTripServicesView(onSave: { editor.recalculate() }) }
        .sheet(isPresented: $directionsPresented) { directions }
        .confirmationDialog("Delete this trip?", isPresented: $deletePresented, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                do { try editor.delete(); dismiss() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("This removes the saved trip or draft, not any recorded workout.") }
        .confirmationDialog("Keep your trip?", isPresented: $closePresented, titleVisibility: .visible) {
            Button("Keep as draft") { save(draft: true) }
            Button("Discard editing recovery", role: .destructive) {
                do { try editor.discardEdits(); dismiss() } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Trip could not be saved", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .onChange(of: scenePhase) { if $0 != .active { editor.preserve() } }
        .onDisappear { editor.cancelDrag() }
    }

    private func destinationPanel(maximumHeight: CGFloat) -> some View {
        OutdoorPineGlassSurface(identity: "trip-stops", namespace: glass, cornerRadius: 26) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button { closePresented = true } label: { Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("Close trip editor")
                    TextField("Trip name", text: Binding(get: { editor.route.title }, set: editor.rename))
                        .font(.headline).submitLabel(.done).accessibilityIdentifier("trip.title")
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { expanded.toggle() }
                    } label: { Image(systemName: expanded ? "chevron.up" : "chevron.down").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel(expanded ? "Collapse destinations" : "Expand destinations")
                }
                if expanded {
                    if editor.route.trip == nil {
                        Text("Imported track · original geometry retained. Use it as saved, or create a new trip to edit destinations.")
                            .font(.subheadline).padding(.horizontal)
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                if editor.trip.stops.isEmpty {
                                    Button("Choose start or allow current location") { replacingID = nil; searchPresented = true }
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                ForEach(Array(editor.trip.stops.enumerated()), id: \.element.id) { index, stop in
                                    stopRow(stop, index: index)
                                }
                            }
                            .background(GeometryReader { geometry in Color.clear.preference(key: TripStopsHeightKey.self, value: geometry.size.height) })
                        }
                        .frame(height: min(maximumHeight, stopsHeight))
                        HStack {
                            Button { replacingID = nil; searchPresented = true } label: { Label("Destination", systemImage: "plus") }
                                .buttonStyle(OutdoorPineButtonStyle()).accessibilityIdentifier("trip.addStop")
                            Spacer(minLength: 4)
                            Menu {
                                Picker("Workout", selection: Binding(get: { editor.trip.kind }, set: { value in editor.change { $0.kind = value } })) {
                                    ForEach(OutdoorActivityKind.allCases) { Text($0.displayName).tag($0) }
                                }
                                Picker("Routing", selection: Binding(get: { editor.trip.preference }, set: { value in editor.change { $0.preference = value } })) {
                                    ForEach(TripRoutingPreference.allCases) { Text($0.title(for: editor.trip.kind)).tag($0) }
                                }
                                if editor.trip.kind != .bike {
                                    Picker("Running goal", selection: Binding(get: { editor.trip.runningGoal }, set: { value in editor.change { $0.runningGoal = value } })) {
                                        ForEach(TripRunningGoal.allCases) { Text($0.title).tag($0) }
                                    }
                                }
                            } label: { Label(editor.trip.preference.title(for: editor.trip.kind), systemImage: editor.trip.kind.iconName).font(.caption.weight(.semibold)) }
                            .frame(minHeight: 44)
                        }.padding(.horizontal, 12)
                    }
                } else {
                    Text(editor.trip.stops.map(\.name).joined(separator: " → "))
                        .font(.subheadline).lineLimit(1).padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func stopRow(_ stop: TripStop, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(index == 0 ? "S" : String(index)).font(.caption.bold())
                .frame(width: 28, height: 28).background(Color.blue, in: Circle())
            Button { replacingID = stop.id; searchPresented = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if index > 0 {
                        Text(stop.incomingMode == .bus ? "Bus transfer · road estimate" : (stop.incomingPreference ?? editor.trip.preference).title(for: editor.trip.kind))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            Menu {
                if index > 0 {
                    Button(stop.incomingMode == .bus ? "Travel under own power" : "Mark leg as bus transfer", systemImage: "bus") {
                        editor.change { trip in
                            guard let i = trip.stops.firstIndex(where: { $0.id == stop.id }) else { return }
                            trip.stops[i].incomingMode = stop.incomingMode == .bus ? .active : .bus
                            trip.stops[i].shapingPoints = []
                        }
                    }
                    Menu("Leg routing") {
                        Button("Use trip preference") { setPreference(nil, stop: stop) }
                        ForEach(TripRoutingPreference.allCases) { value in Button(value.title(for: editor.trip.kind)) { setPreference(value, stop: stop) } }
                    }
                    if !stop.shapingPoints.isEmpty {
                        Button("Clear route adjustments") { editor.change { trip in
                            if let i = trip.stops.firstIndex(where: { $0.id == stop.id }) { trip.stops[i].shapingPoints = [] }
                        } }
                    }
                }
                Button("Move earlier", systemImage: "arrow.up") { editor.moveStop(stop.id, by: -1) }.disabled(index == 0)
                Button("Move later", systemImage: "arrow.down") { editor.moveStop(stop.id, by: 1) }.disabled(index == editor.trip.stops.count - 1)
                Button("Remove stop", systemImage: "trash", role: .destructive) { editor.deleteStop(stop.id) }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
            .accessibilityLabel("Options for \(stop.name)")
        }
        .padding(.leading, 14).padding(.trailing, 4)
    }

    private var mapControls: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Menu {
                    Button("Explore") { mapMode = .explore }
                    Button("Satellite") { mapMode = .satellite }
                    Button("Trip Services", systemImage: "network") { servicesPresented = true }
                } label: { Image(systemName: "map").frame(width: 44, height: 44) }
                .buttonStyle(OutdoorPineButtonStyle(circular: true)).accessibilityLabel("Map and trip services")
                Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true)).disabled(!editor.canUndo || editor.isDragging).accessibilityLabel("Undo trip edit")
            }
            Spacer()
            HStack(spacing: 8) {
                Button { northRequest += 1 } label: { Image(systemName: "location.north.line") }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true)).accessibilityLabel("North up")
                Button { fitRequest += 1 } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true)).accessibilityLabel("Fit trip route")
                Button { followsUser = true; focusRequest += 1 } label: { Image(systemName: "location") }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true)).accessibilityLabel("Current location")
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let message = editor.errorMessage {
                VStack(spacing: 6) {
                    Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Retry") { editor.recalculate() }
                        Button("Trip Services") { servicesPresented = true }
                    }.font(.subheadline.bold())
                }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            OutdoorPineGlassSurface(identity: "trip-summary", namespace: glass, cornerRadius: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(outdoorDistanceText(editor.trip.ridingDistanceMeters, unitSystem: units, precision: true)) \(editor.trip.kind == .bike ? "riding" : "on foot")")
                            .font(.title3.weight(.bold)).monospacedDigit()
                        if editor.trip.hasBus {
                            Text("\(outdoorDistanceText(editor.trip.totalDistanceMeters, unitSystem: units, precision: true)) total incl. bus")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Text(editor.isRouting ? "Snapping to accessible roads…" : editor.trip.isRouted ? "\(editor.trip.effortTitle) · Hold and drag the blue route" : "Add destinations to build your trip")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if editor.isRouting { ProgressView().accessibilityLabel("Calculating route") }
                    Button { directionsPresented = true } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }
                        .accessibilityLabel("Route details and directions").disabled(editor.trip.legs.isEmpty)
                }.padding(14)
            }
            TripConnectedActions {
                Button { deletePresented = true } label: { Image(systemName: "trash").frame(width: 48) }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 52)).accessibilityLabel("Delete trip")
                Button { save(draft: false) } label: { Text("Save trip").font(.headline).frame(maxWidth: .infinity, minHeight: 52) }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true)).disabled(!editor.canSave).accessibilityIdentifier("trip.save")
                Button { save(draft: true) } label: { Image(systemName: "archivebox").frame(width: 48) }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 52)).accessibilityLabel("Save draft").accessibilityIdentifier("trip.draft")
            }
            HStack(spacing: 4) {
                Link("© OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                Text("·")
                let attribution = mapConfiguration.capability(for: mapMode).attribution
                if let url = attribution.URLs.first {
                    Link(attribution.providerName, destination: url)
                }
            }.font(.caption2).padding(.horizontal, 8).padding(.vertical, 3).background(.regularMaterial, in: Capsule())
        }
    }

    private var directions: some View {
        NavigationStack {
            List {
                SwiftUI.Section("Route assessment") { Text(editor.trip.explanation) }
                if editor.trip.hasBus {
                    SwiftUI.Section("Bus transfers") { Text("Dashed purple legs are road estimates, not timetabled bus services. Confirm stops, service, and bike carriage with the operator. During recording, tap Board bus, then Resume riding when you leave the bus.") }
                }
                ForEach(editor.trip.legs) { leg in
                    SwiftUI.Section(leg.mode == .bus ? "Bus transfer estimate" : "\(editor.trip.kind.displayName) leg") {
                        ForEach(Array(leg.instructions.enumerated()), id: \.offset) { _, text in Text(text) }
                    }
                }
            }.navigationTitle("Trip details")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { directionsPresented = false } } }
        }
    }

    private func setPreference(_ value: TripRoutingPreference?, stop: TripStop) {
        editor.change { trip in if let i = trip.stops.firstIndex(where: { $0.id == stop.id }) { trip.stops[i].incomingPreference = value } }
    }
    private func save(draft: Bool) {
        do { let saved = try editor.save(draft: draft); onSaved(saved); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private struct TripStopsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TripPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TripConnectedActions<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if #available(iOS 26, *), !reduceTransparency {
            GlassEffectContainer(spacing: 16) { HStack(spacing: 8, content: content) }
        } else { HStack(spacing: 8, content: content) }
    }
}
#endif
