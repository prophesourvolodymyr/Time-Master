#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripPlannerView: View {
    @ObservedObject var editor: OutdoorTripEditor
    let entry: TripPlannerEntry
    let units: OutdoorUnitSystem
    let namespace: Namespace.ID
    let onPanelHeight: (CGFloat) -> Void
    let onBottomHeight: (CGFloat) -> Void
    let onFit: () -> Void
    let onManageAreas: () -> Void
    let onSaved: (PlannedRoute) -> Void
    let onClose: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = true
    @State private var searching = false
    @State private var configuring = true
    @State private var contentHeight: CGFloat = 44
    @State private var deletePresented = false
    @State private var detailsPresented = false
    @State private var closePresented = false
    @State private var error: String?
    @State private var distance = 20.0
    @State private var stopCount = 0
    @State private var categories: Set<TripPlaceCategory> = [.parks]
    @State private var suggestions: [PlannedRoute] = []
    @State private var selectedSuggestion = 0
    private var busy: Bool {
        get { editor.isGenerating }
        nonmutating set { editor.isGenerating = newValue }
    }
    @State private var generation = UUID()
    @State private var suggestionTask: Task<Void, Never>?
    @State private var suggestionError: String?

    private var showsConfiguration: Bool { entry != .build && configuring }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 10) {
                destinationPanel(maximumHeight: proxy.size.height * 0.30)
                    .background(GeometryReader { geometry in Color.clear.preference(key: TripPanelHeightKey.self, value: geometry.size.height) })
                if editor.picking {
                    OutdoorPineGlassSurface(identity: "trip-pick", namespace: namespace, cornerRadius: 22) {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.tap")
                                .foregroundStyle(Theme.toolbarOrange)
                                .accessibilityHidden(true)
                            Text("Tap a road or path")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            OutdoorPineIconAction(symbol: "xmark", label: "Cancel map selection", size: 38) {
                                editor.picking = false
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                    }
                }
                Spacer(minLength: 0)
                bottomBar
                    .background(GeometryReader { geometry in Color.clear.preference(key: TripBottomHeightKey.self, value: geometry.size.height) })
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.toolbarOrange)
        .onPreferenceChange(TripPanelHeightKey.self, perform: onPanelHeight)
        .onPreferenceChange(TripBottomHeightKey.self, perform: onBottomHeight)
        .onPreferenceChange(TripContentHeightKey.self) { contentHeight = $0 }
        .sheet(isPresented: $detailsPresented) { details }
        .confirmationDialog("Delete this trip?", isPresented: $deletePresented, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                do { try editor.delete(); onClose() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("This removes the saved trip or draft, not any recorded workout.") }
        .confirmationDialog("Keep your trip?", isPresented: $closePresented, titleVisibility: .visible) {
            Button("Keep as draft") { save(draft: true) }
            Button("Discard editing recovery", role: .destructive) {
                do { try editor.discardEdits(); onClose() } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Trip could not be saved", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .onAppear { if editor.trip.kind != .bike { distance = units == .metric ? 5 : 3 } else if units != .metric { distance = 12 } }
        .onChange(of: scenePhase) {
            if $0 != .active { editor.preserve(); cancelSuggestions(); editor.suspend() }
            else if !editor.trip.isRouted, editor.trip.stops.count >= 2 { editor.recalculate() }
        }
        .onDisappear { cancelSuggestions(); editor.suspend() }
    }

    private func destinationPanel(maximumHeight: CGFloat) -> some View {
        OutdoorPineGlassSurface(identity: "trip-stops", namespace: namespace, cornerRadius: 26) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    OutdoorPineIconAction(symbol: "xmark", label: "Close trip editor", size: 40) {
                        if editor.trip.stops.isEmpty { onClose() } else { closePresented = true }
                    }
                    TextField("Trip name", text: Binding(get: { editor.route.title }, set: editor.rename))
                        .font(.headline)
                        .submitLabel(.done)
                        .accessibilityIdentifier("trip.title")
                    OutdoorPineIconAction(
                        symbol: "arrow.uturn.backward",
                        label: "Undo trip edit",
                        size: 40,
                        disabled: !editor.canUndo || editor.isDragging || busy
                    ) { editor.undo() }
                    OutdoorPineIconAction(
                        symbol: expanded ? "chevron.up" : "chevron.down",
                        label: expanded ? "Collapse destinations" : "Expand destinations",
                        size: 40
                    ) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) {
                            expanded.toggle()
                        }
                    }
                }
                if expanded {
                    ScrollView {
                        VStack(spacing: 8) {
                            if searching {
                                OutdoorTripSearchView(near: editor.trip.stops.first?.coordinate, currentLocation: editor.currentLocation,
                                    onSelect: { place in
                                        editor.putStop(place, replacing: editor.replacingStopID)
                                        editor.replacingStopID = nil
                                        searching = false
                                    }, onMap: { searching = false; editor.picking = true }, onCancel: { searching = false })
                            } else {
                                if editor.trip.stops.isEmpty {
                                    HStack(spacing: 12) {
                                        OutdoorPineIconAction(symbol: "location.magnifyingglass", label: "Choose starting place", prominent: true) {
                                            search(replacing: nil)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Choose a start")
                                                .font(.subheadline.weight(.semibold))
                                            Text("Search, current location, or map")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 14)
                                }
                                let stops = showsConfiguration ? Array(editor.trip.stops.prefix(1)) : editor.trip.stops
                                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in stopRow(stop, index: index) }
                                if showsConfiguration { suggestionConfiguration }
                                HStack(spacing: 8) {
                                    if !showsConfiguration {
                                        OutdoorPineIconAction(symbol: "plus", label: "Add destination") {
                                            search(replacing: nil)
                                        }
                                        .accessibilityIdentifier("trip.addStop")
                                    }
                                    Spacer(minLength: 4)
                                    routingPreferences
                                }
                                .frame(minHeight: 44)
                                .padding(.horizontal, 8)
                            }
                        }
                        .disabled(busy)
                        .background(GeometryReader { geometry in Color.clear.preference(key: TripContentHeightKey.self, value: geometry.size.height) })
                    }
                    .frame(height: min(maximumHeight, contentHeight))
                } else {
                    Text(editor.trip.stops.isEmpty ? "Choose a start" : editor.trip.stops.map(\.name).joined(separator: " → "))
                        .font(.subheadline).lineLimit(1).padding(.horizontal, 16)
                }
            }.padding(.bottom, 10)
        }
    }

    private var suggestionConfiguration: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "ruler")
                    .foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
                Text("Distance")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                TextField(units == .metric ? "km" : "mi", value: $distance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 92)
                    .accessibilityLabel("Suggested route distance")
                    .accessibilityIdentifier("trip.distance")
            }
            .frame(minHeight: 44)
            if entry == .custom {
                Stepper(value: $stopCount, in: 0...8) {
                    Label("\(stopCount) places", systemImage: "mappin.and.ellipse")
                }
                .frame(minHeight: 44)
                if stopCount > 0 {
                    Menu {
                        ForEach(TripPlaceCategory.allCases) { category in
                            Toggle(category.title, isOn: Binding(get: { categories.contains(category) }, set: {
                                if $0 { categories.insert(category) } else { categories.remove(category) }
                            }))
                        }
                    } label: {
                        Label(
                            categories.isEmpty ? "Places" : categories.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: ", "),
                            systemImage: "leaf"
                        )
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityLabel("Place categories")
                }
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
    }

    private var routingPreferences: some View {
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
            if entry != .build, !configuring { Button("Adjust suggestions", systemImage: "slider.horizontal.3") { configuring = true; expanded = true } }
        } label: {
            Image(systemName: editor.trip.kind.iconName)
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
        .accessibilityLabel("Trip routing options")
        .accessibilityValue(editor.trip.preference.title(for: editor.trip.kind))
    }

    private func stopRow(_ stop: TripStop, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: index == 0 ? "location.fill" : index == editor.trip.stops.count - 1 ? "flag.checkered" : "mappin")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Button { search(replacing: stop.id) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if index > 0 {
                        Label(
                            stop.incomingMode == .bus ? "Bus road estimate" : (stop.incomingPreference ?? editor.trip.preference).title(for: editor.trip.kind),
                            systemImage: stop.incomingMode == .bus ? "bus" : editor.trip.kind.iconName
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            if !showsConfiguration {
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
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
                .accessibilityLabel("Options for \(stop.name)")
            }
        }.padding(.leading, 14).padding(.trailing, 4)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let message = suggestionError ?? editor.errorMessage {
                OutdoorPineGlassSurface(identity: "trip-error", namespace: namespace, cornerRadius: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityHidden(true)
                        Text(message)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        OutdoorPineIconAction(symbol: "arrow.clockwise", label: "Retry route", size: 38) {
                            if showsConfiguration { generate() } else { editor.recalculate() }
                        }
                        OutdoorPineIconAction(symbol: "arrow.down.circle", label: "Manage offline areas", size: 38, action: onManageAreas)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
                }
            }
            if !showsConfiguration || busy {
                OutdoorPineGlassSurface(identity: "trip-summary", namespace: namespace, cornerRadius: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(outdoorDistanceText(editor.trip.activeDistanceMeters, unitSystem: units, precision: true)) \(editor.trip.kind == .bike ? "riding" : "on foot")")
                                .font(.title3.weight(.bold)).monospacedDigit()
                            if editor.trip.hasBus {
                                Text("\(outdoorDistanceText(editor.trip.totalDistanceMeters, unitSystem: units, precision: true)) total incl. bus")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Text(busy ? "Finding offline routes…" : editor.isRouting ? "Snapping to accessible roads…" : editor.trip.isRouted ? "\(editor.trip.effortTitle) · Hold and drag the blue route" : "Add destinations to build your trip")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 8)
                        if busy || editor.isRouting {
                            ProgressView()
                                .accessibilityLabel("Calculating route")
                        } else {
                            OutdoorPineIconAction(
                                symbol: "list.bullet",
                                label: "Route details and directions",
                                disabled: editor.trip.legs.isEmpty
                            ) { detailsPresented = true }
                        }
                    }.padding(14)
                }
            }
            if !showsConfiguration, suggestions.count > 1 {
                OutdoorPineGlassSurface(identity: "trip-suggestions", namespace: namespace, cornerRadius: 22) {
                    HStack(spacing: 8) {
                        OutdoorPineIconAction(
                            symbol: "chevron.left",
                            label: "Previous suggested route",
                            size: 38,
                            disabled: selectedSuggestion == 0
                        ) { chooseSuggestion(selectedSuggestion - 1) }
                        Spacer(minLength: 0)
                        Text("\(selectedSuggestion + 1) / \(suggestions.count)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .accessibilityLabel("Route \(selectedSuggestion + 1) of \(suggestions.count)")
                        Spacer(minLength: 0)
                        OutdoorPineIconAction(
                            symbol: "chevron.right",
                            label: "Next suggested route",
                            size: 38,
                            disabled: selectedSuggestion == suggestions.count - 1
                        ) { chooseSuggestion(selectedSuggestion + 1) }
                    }
                    .padding(4)
                }
            }
            OutdoorPineConnectedActions {
                OutdoorPineIconAction(symbol: "trash", label: "Delete trip", role: .destructive, size: 52) {
                    deletePresented = true
                }
                if showsConfiguration {
                    OutdoorPinePrimaryAction(
                        title: busy ? "Cancel" : "Find routes",
                        symbol: busy ? "xmark" : "arrow.triangle.branch",
                        disabled: !busy && (searching || editor.picking || editor.trip.stops.isEmpty || !distance.isFinite || distance <= 0 || (stopCount > 0 && categories.isEmpty)),
                        identifier: "trip.suggest"
                    ) {
                        if busy { cancelSuggestions() } else { generate() }
                    }
                } else {
                    OutdoorPinePrimaryAction(
                        title: "Save",
                        symbol: "checkmark",
                        disabled: !editor.canSave || busy,
                        identifier: "trip.save"
                    ) { save(draft: false) }
                }
                OutdoorPineIconAction(symbol: "archivebox", label: "Save draft", size: 52) {
                    save(draft: true)
                }
                .accessibilityIdentifier("trip.draft")
            }
        }
    }

    private var details: some View {
        NavigationStack {
            List {
                SwiftUI.Section("Route assessment") { Text(editor.trip.explanation) }
                if entry != .build {
                    SwiftUI.Section("Suggestions") { Text("Connected road loops ranked for the selected distance and terrain goal. Distance tolerance is 25%, or 1 km for short trips. Unknown terrain is never assumed flat or safe.") }
                }
                if editor.trip.hasBus {
                    SwiftUI.Section("Bus transfers") { Text("Dashed purple legs are road estimates, not timetabled bus services. Confirm stops, service, and bike carriage with the operator. During recording, tap Board bus, then Resume riding when you leave the bus.") }
                }
                ForEach(editor.trip.legs) { leg in
                    SwiftUI.Section(leg.mode == .bus ? "Bus transfer estimate" : "\(editor.trip.kind.displayName) leg") {
                        ForEach(Array(leg.instructions.enumerated()), id: \.offset) { _, text in Text(text) }
                    }
                }
            }.navigationTitle("Trip details")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { detailsPresented = false } } }
        }.tint(Theme.toolbarOrange)
    }

    private func search(replacing id: UUID?) { editor.replacingStopID = id; editor.picking = false; searching = true; expanded = true }
    private func setPreference(_ value: TripRoutingPreference?, stop: TripStop) {
        editor.change { trip in if let i = trip.stops.firstIndex(where: { $0.id == stop.id }) { trip.stops[i].incomingPreference = value } }
    }
    private func save(draft: Bool) {
        cancelSuggestions()
        do { let saved = try editor.save(draft: draft); onSaved(saved); onClose() }
        catch { self.error = error.localizedDescription }
    }
    private func cancelSuggestions() { generation = UUID(); suggestionTask?.cancel(); busy = false }
    private func generate() {
        guard let origin = editor.trip.stops.first else { return }
        cancelSuggestions()
        let token = generation
        let input = editor.trip
        let meters = distance * (units == .metric ? 1_000 : 1_609.344)
        let count = entry == .custom ? stopCount : 0
        let selectedCategories = categories
        busy = true
        suggestionError = nil
        suggestionTask = Task {
            do {
                let routes = try await OutdoorTripService().suggestions(origin: origin, kind: input.kind, distance: meters,
                    stopCount: count, categories: selectedCategories, preference: input.preference, runningGoal: input.runningGoal)
                try Task.checkCancellation()
                guard generation == token else { return }
                suggestions = routes
                busy = false
                configuring = false
                chooseSuggestion(0)
            } catch {
                guard generation == token, !Task.isCancelled else { return }
                busy = false
                suggestionError = error.localizedDescription
            }
        }
    }
    private func chooseSuggestion(_ index: Int) {
        guard suggestions.indices.contains(index) else { return }
        selectedSuggestion = index
        editor.useSuggestion(suggestions[index])
        onFit()
    }
}

private struct TripContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct TripPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct TripBottomHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
#endif
