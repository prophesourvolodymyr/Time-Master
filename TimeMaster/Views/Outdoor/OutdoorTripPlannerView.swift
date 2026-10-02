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
    let onFitLeg: (TripRouteLeg) -> Void
    let onManageAreas: () -> Void
    let onSaved: (PlannedRoute) -> Void
    let onClose: () -> Void
    let onStart: (PlannedRoute) -> Void
    let canStart: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = true
    @State private var searching = false
    @State private var query = ""
    @State private var addingDestination = false
    @FocusState private var focusedField: StopField?

    private enum StopField: Hashable {
        case start, stop(UUID), destination
    }
    @State private var configuring = true
    @State private var contentHeight: CGFloat = 44
    @State private var deletePresented = false
    @State private var detailsPresented = false
    @State private var closePresented = false
    @State private var error: String?
    @State private var previewFraction: CGFloat = 0.78
    @GestureState private var previewDrag: CGFloat = 0
    @State private var shareImage: UIImage?
    @State private var sharePresented = false
    @State private var preparingShare = false
    @State private var shareTask: Task<Void, Never>?
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

    private var showsConfiguration: Bool { entry == .custom && configuring }

    var body: some View {
        GeometryReader { proxy in
            if entry == .preview {
                previewPane(in: proxy.size)
            } else {
            VStack(spacing: 10) {
                VStack(spacing: 10) {
                    destinationPanel(maximumHeight: proxy.size.height * (searching ? 0.70 : 0.36))
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
                }
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: TripPanelHeightKey.self, value: geometry.size.height)
                        .allowsHitTesting(false)
                })
                Spacer(minLength: 0).allowsHitTesting(false)
                if !searching {
                    bottomBar
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: TripBottomHeightKey.self, value: geometry.size.height)
                                .allowsHitTesting(false)
                        })
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.toolbarOrange)
        .onPreferenceChange(TripPanelHeightKey.self, perform: onPanelHeight)
        .onPreferenceChange(TripBottomHeightKey.self, perform: onBottomHeight)
        .onChange(of: focusedField) { field in
            guard let field else { searching = false; return }
            switch field {
            case .start:
                query = ""
                editor.replacingStopID = editor.trip.stops.first?.id
            case .stop(let id):
                query = editor.trip.stops.first { $0.id == id }?.name ?? ""
                editor.replacingStopID = id
            case .destination:
                query = ""
                editor.replacingStopID = nil
            }
            searching = true
            editor.picking = false
            expanded = true
        }
        .onPreferenceChange(TripContentHeightKey.self) { contentHeight = $0 }
        .sheet(isPresented: $detailsPresented) {
            OutdoorTripDetailsView(
                route: editor.route, units: units,
                onShowLeg: { leg in detailsPresented = false; onFitLeg(leg) }
            )
        }
        .sheet(isPresented: $sharePresented) {
            if let shareImage { ShareSheet(activityItems: [shareImage]) }
        }
        .confirmationDialog("Delete this trip?", isPresented: $deletePresented, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                do { try editor.delete(); onClose() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("This removes the saved trip or draft, not any recorded workout.") }
        .confirmationDialog("Keep your trip?", isPresented: $closePresented, titleVisibility: .visible) {
            if entry == .preview, editor.canSave {
                Button("Save changes") { save(draft: false) }
            }
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
            if $0 != .active {
                if entry != .preview || editor.hasChanges { editor.preserve() }
                cancelSuggestions()
                editor.suspend()
            }
            else if editor.route.trip != nil, !editor.trip.isRouted, editor.trip.stops.count >= 2 { editor.recalculate() }
        }
        .onDisappear { cancelSuggestions(); shareTask?.cancel(); editor.suspend() }
    }

    private func destinationPanel(maximumHeight: CGFloat, compact: Bool = false) -> some View {
        Group {
            if entry == .preview { destinationContent(maximumHeight: maximumHeight, compact: compact) }
            else {
                OutdoorPineGlassSurface(identity: "trip-stops", namespace: namespace, cornerRadius: 26) {
                    destinationContent(maximumHeight: maximumHeight)
                }
            }
        }
    }

    private func destinationContent(maximumHeight: CGFloat, compact: Bool = false) -> some View {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    OutdoorPineIconAction(symbol: "chevron.left", label: entry == .preview ? "Back to Routes" : "Close trip editor", size: 44) {
                        if editor.trip.stops.isEmpty || (entry == .preview && !editor.hasChanges) { onClose() }
                        else { closePresented = true }
                    }
                    routingPreferences
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
                        focusedField = nil
                        searching = false
                        addingDestination = false
                        query = ""
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) {
                            expanded.toggle()
                        }
                    }
                }
                if entry == .preview, !searching {
                    OutdoorTripPreviewSummary(route: editor.route, kind: editor.trip.kind, units: units, isRouting: editor.isRouting, compact: compact)
                    if !compact {
                    HStack(spacing: 12) {
                        Button { detailsPresented = true } label: {
                            Label("Road details", systemImage: "road.lanes")
                        }
                        .frame(minHeight: 44)
                        Spacer(minLength: 0)
                        Button(action: onFit) { Image(systemName: "map").frame(width: 44, height: 44) }
                            .accessibilityLabel("Fit road on map")
                    }
                    .font(.caption.weight(.semibold)).padding(.horizontal, 14)
                    }
                }
                if expanded, !compact {
                    ScrollViewReader { scroll in
                        ScrollView {
                            VStack(spacing: 8) {
                                if editor.trip.stops.isEmpty {
                                    pendingField(.start, index: 0, placeholder: "Starting location")
                                    if searching, focusedField == .start { searchResults }
                                }
                                let stops = showsConfiguration ? Array(editor.trip.stops.prefix(1)) : editor.trip.stops
                                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                                    stopRow(stop, index: index).id(StopField.stop(stop.id))
                                    if searching, focusedField == .stop(stop.id) { searchResults }
                                }
                                if showsConfiguration {
                                    suggestionConfiguration
                                } else {
                                    if addingDestination {
                                        pendingField(.destination, index: editor.trip.stops.count, placeholder: "Destination")
                                        if searching, focusedField == .destination { searchResults }
                                    }
                                    OutdoorTripAddDestination {
                                        addingDestination = true
                                        focusedField = .destination
                                    }
                                    .disabled(addingDestination)
                                    .opacity(addingDestination ? 0.45 : 1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .disabled(busy)
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: TripContentHeightKey.self, value: geometry.size.height)
                                    .allowsHitTesting(false)
                            })
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(height: entry == .preview ? nil : min(maximumHeight, contentHeight))
                        .frame(maxHeight: entry == .preview ? maximumHeight : nil)
                        .onChange(of: focusedField) { field in
                            if let field { scroll.scrollTo(field, anchor: .top) }
                        }
                        .onChange(of: maximumHeight) { _ in
                            if let focusedField { scroll.scrollTo(focusedField, anchor: .top) }
                        }
                    }
                } else if !compact {
                    Text(editor.trip.stops.isEmpty ? "Choose a start" : editor.trip.stops.map(\.name).joined(separator: " → "))
                        .font(.subheadline).lineLimit(1).padding(.horizontal, 16)
                }
            }.padding(.bottom, 10)
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
            if entry == .custom, !configuring { Button("Adjust suggestions", systemImage: "slider.horizontal.3") { configuring = true; expanded = true } }
        } label: {
            Image(systemName: editor.trip.kind.iconName)
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
        .accessibilityLabel("Trip routing options")
        .accessibilityValue(editor.trip.preference.title(for: editor.trip.kind))
    }

    private func stopRow(_ stop: TripStop, index: Int) -> some View {
        OutdoorTripStopField(index: index, isBus: index > 0 && stop.incomingMode == .bus, connectsBelow: !showsConfiguration) {
            VStack(alignment: .leading, spacing: 3) {
                Text(index == 0 ? "Start" : "Destination \(index)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                TextField(index == 0 ? "Starting location" : "Destination", text: Binding(
                    get: { focusedField == .stop(stop.id) ? query : stop.name },
                    set: { query = $0 }
                ))
                .focused($focusedField, equals: .stop(stop.id))
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel(index == 0 ? "Starting location" : "Destination \(index)")
                .accessibilityIdentifier(focusedField == .stop(stop.id) ? "trip.search" : "trip.stop.\(index)")
                if index > 0, focusedField != .stop(stop.id) {
                    Text(stop.incomingMode == .bus ? "Bus road estimate" : (stop.incomingPreference ?? editor.trip.preference).title(for: editor.trip.kind))
                        .font(.caption2)
                        .foregroundStyle(stop.incomingMode == .bus ? Color.yellow : Theme.textSecondary)
                }
            }
            .padding(.vertical, 8)
        } accessory: {
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
                .buttonStyle(.plain)
                .accessibilityLabel("Options for \(stop.name)")
            }
        }
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
                    OutdoorTripSummaryView(trip: editor.trip, units: units) {
                        if busy || editor.isRouting {
                            ProgressView().accessibilityLabel("Calculating route")
                        } else {
                            OutdoorPineIconAction(
                                symbol: "chart.xyaxis.line", label: "Route details and directions",
                                disabled: !editor.trip.isRouted
                            ) { focusedField = nil; detailsPresented = true }
                        }
                    } footer: {
                        Text(busy ? "Finding offline routes…" : editor.isRouting ? "Snapping to accessible roads…" : editor.trip.isRouted ? "Hold and drag the blue route" : "Add destinations to build your trip")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(14)
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
                        disabled: !editor.canSave || busy || searching || addingDestination || editor.picking,
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

    private func pendingField(_ field: StopField, index: Int, placeholder: String) -> some View {
        OutdoorTripStopField(index: index, isBus: false, connectsBelow: !showsConfiguration) {
            TextField(placeholder, text: $query)
                .focused($focusedField, equals: field)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel(placeholder)
                .accessibilityIdentifier(focusedField == field ? "trip.search" : "trip.pendingStop")
        } accessory: {
            if field == .destination {
                Button {
                    focusedField = nil
                    searching = false
                    addingDestination = false
                } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel new destination")
            } else {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary).padding(12)
            }
        }
        .id(field)
    }

    private var searchResults: some View {
        OutdoorTripSearchView(
            near: editor.trip.stops.first?.coordinate, currentLocation: editor.currentLocation,
            onSelect: { place in
                let replacement = focusedField == .start ? editor.trip.stops.first?.id : editor.replacingStopID
                editor.putStop(place, replacing: replacement)
                editor.replacingStopID = nil
                focusedField = nil
                searching = false
                addingDestination = false
                query = ""
            },
            onMap: {
                focusedField = nil
                searching = false
                addingDestination = false
                editor.picking = true
            },
            onCancel: {
                focusedField = nil
                searching = false
                editor.replacingStopID = nil
                addingDestination = false
                query = ""
            }, query: $query
        )
    }

    private func previewPane(in size: CGSize) -> some View {
        let fraction = searching ? 0.95 : max(0.32, min(0.95, previewFraction - previewDrag / max(1, size.height)))
        let height = max(1, size.height * fraction - 16)
        return VStack(spacing: 0) {
            Spacer(minLength: 0).allowsHitTesting(false)
            OutdoorPineGlassSurface(identity: "trip-road-preview", namespace: namespace, cornerRadius: 28) {
                VStack(spacing: 8) {
                    Capsule().fill(Theme.textSecondary.opacity(0.55)).frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
                            .updating($previewDrag) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                previewFraction = max(0.32, min(0.95, previewFraction - value.translation.height / max(1, size.height)))
                            })
                        .accessibilityElement()
                        .accessibilityLabel("Road preview pane handle")
                        .accessibilityIdentifier("trip.preview.handle")
                        .accessibilityValue("\(Int(fraction * 100)) percent")
                        .accessibilityAdjustableAction { direction in
                            previewFraction = max(0.32, min(0.95, previewFraction + (direction == .increment ? 0.1 : -0.1)))
                        }
                    destinationPanel(maximumHeight: max(44, height * (searching ? 0.72 : 0.38)), compact: fraction < 0.55)
                    Spacer(minLength: 0)
                    if let message = editor.errorMessage {
                        Text(message).font(.caption).foregroundStyle(.red).padding(.horizontal, 14)
                    }
                    if !searching {
                        OutdoorPineConnectedActions {
                            OutdoorPineIconAction(symbol: preparingShare ? "hourglass" : "square.and.arrow.up", label: "Share planned trip", size: 52, disabled: !editor.canSave || preparingShare || addingDestination || editor.picking) {
                                share()
                            }
                            .accessibilityIdentifier("trip.share")
                            OutdoorPinePrimaryAction(title: "Start", symbol: "play.fill", disabled: !canStart || !editor.canSave || addingDestination || editor.picking, identifier: "trip.start") {
                                do { let route = try editor.save(draft: false); onStart(route) }
                                catch { self.error = error.localizedDescription }
                            }
                            OutdoorPineIconAction(symbol: "trash", label: "Delete trip", role: .destructive, size: 52) {
                                deletePresented = true
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)
                .frame(height: height)
            }
            .background(GeometryReader { geometry in
                Color.clear.preference(key: TripBottomHeightKey.self, value: geometry.size.height + 8)
                    .allowsHitTesting(false)
            })
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear { onPanelHeight(0) }
    }

    private func share() {
        preparingShare = true
        focusedField = nil
        shareTask = Task {
            do {
                let image = try await OutdoorTripImageExportService().image(for: editor.route, units: units)
                try Task.checkCancellation()
                shareImage = image
                preparingShare = false
                sharePresented = true
            } catch {
                guard !Task.isCancelled else { return }
                preparingShare = false
                self.error = error.localizedDescription
            }
        }
    }
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
