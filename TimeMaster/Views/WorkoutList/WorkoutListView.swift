import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#endif

struct WorkoutListView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject private var outdoorPreferencesStore: OutdoorRecordingPreferencesStore
    @ObservedObject private var resumeManager = WorkoutResumeManager.shared
    @ScaledMetric(relativeTo: .subheadline) private var selectorRowHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .caption) private var statsTileHeight: CGFloat = 72
    @Binding var requestedWorkoutID: UUID?
    @State private var navigationPath: [Workout] = []
    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutType: WorkoutType = .strength
    @State private var newWorkoutColor: String = "FFFFFF"
    @State private var showingTodayOnly = false
    @State private var selectedTypeID: String?
    @State private var searchText = ""
    @State private var showingSearch = false
    @FocusState private var searchFieldFocused: Bool
    @State private var playerWorkout: Workout?
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    #endif

    init(requestedWorkoutID: Binding<UUID?> = .constant(nil)) {
        _requestedWorkoutID = requestedWorkoutID
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.background.ignoresSafeArea()

                if store.workouts.isEmpty {
                    emptyState
                } else {
                    workoutsChrome
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: Workout.self) { workout in
                workoutDestination(for: workout)
            }
            .oneHandedActions(id: "workouts", actions: oneHandedActions)
            .sheet(isPresented: $showingAddWorkout) {
                addWorkoutSheet
            }
            .workoutPlayerPage(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(DatabaseStore.shared)
            }
            #if os(iOS)
            .fullScreenCover(
                item: Binding(
                    get: { UIDevice.current.userInterfaceIdiom == .phone ? activeOutdoorKind : nil },
                    set: { activeOutdoorKind = $0 }
                )
            ) { kind in
                OutdoorRouteRecordingView(
                    kind: kind,
                    store: outdoorStore,
                    preferences: outdoorPreferencesStore,
                    musicLibrary: musicLibraryStore
                )
            }
            #endif
            .onAppear {
                openRequestedWorkout(requestedWorkoutID)
            }
            .onChange(of: requestedWorkoutID) { workoutID in
                openRequestedWorkout(workoutID)
            }
            .onChange(of: showingSearch) { isShowing in
                searchFieldFocused = isShowing
                if !isShowing {
                    searchText = ""
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newWorkoutCommand)) { _ in
                showingAddWorkout = true
            }
        }
    }

    private func openRequestedWorkout(_ workoutID: UUID?) {
        guard let workoutID else { return }
        defer { requestedWorkoutID = nil }

        guard let workout = store.workouts.first(where: { $0.id == workoutID }) else { return }
        navigationPath = [workout]
    }

    @ViewBuilder
    private func workoutCardLabel(for workout: Workout) -> some View {
        let historyEntries = entries(for: workout)
        let schedule = scheduleByWorkoutID[workout.id]

        WorkoutCard(
            workout: workout,
            schedule: schedule,
            sessionsThisWeek: sessionsThisWeek(for: historyEntries),
            lastCompletedAt: historyEntries.max(by: { $0.completedAt < $1.completedAt })?.completedAt,
            isResumable: resumeManager.resumeState?.workoutId == workout.id
        )
    }
    private var todaySchedules: [ScheduledWorkout] {
        store.scheduledWorkouts(for: Date())
    }

    private var scheduleByWorkoutID: [UUID: ScheduledWorkout] {
        todaySchedules.reduce(into: [UUID: ScheduledWorkout]()) { result, item in
            result[item.workout.id] = item
        }
    }

    private var visibleWorkouts: [Workout] {
        store.workouts.filter { workout in
            let matchesToday = !showingTodayOnly || scheduleByWorkoutID[workout.id] != nil
            let matchesType = selectedTypeID == nil || workout.type.id == selectedTypeID
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || workout.name.localizedCaseInsensitiveContains(searchText)
                || workout.type.name.localizedCaseInsensitiveContains(searchText)
            return matchesToday && matchesType && matchesSearch
        }
    }

    /// Widest the tracking tiles and chrome controls grow before they stop filling their row.
    private static let trackingControlMaxHeight: CGFloat = 148
    /// Widest the page content and chrome grow on large screens.
    private static let contentMaxWidth: CGFloat = 980

    private var workoutsChrome: some View {
        ScrollingChrome(metrics: { width in
            ScrollingChromeMetrics(
                width: min(width, Self.contentMaxWidth),
                collapsedRowHeight: 48,
                expandedControlWidthCap: .infinity,
                expandedControlHeightCap: Self.trackingControlMaxHeight
            )
        }) { metrics in
            workoutsScrollContent(metrics: metrics)
        } header: { progress, metrics in
            workoutsHeader(progress: progress, metrics: metrics)
        }
    }

    private func workoutsScrollContent(metrics: ScrollingChromeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if showingSearch {
                searchField
            }

            resumeBanner

            if visibleWorkouts.isEmpty {
                filteredEmptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleWorkouts) { workout in
                        NavigationLink(value: workout) {
                            workoutCardLabel(for: workout)
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .contextMenu {
                            Button {
                                playerWorkout = workout
                            } label: {
                                Label("Start Workout", systemImage: "play.fill")
                            }
                            .disabled(workout.sections.isEmpty)

                            Button {
                                pinToWidget(workout)
                            } label: {
                                Label("Pin to Widget", systemImage: "pin")
                            }

                            Button {
                                store.cloneWorkout(workout)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }

                            Divider()

                            Button(role: .destructive) {
                                store.deleteWorkout(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: Self.contentMaxWidth, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private var oneHandedActions: [ReachabilityAction] {
        [
            ReachabilityAction("search", title: showingSearch ? "Close Search" : "Search") {
                chromeButton(
                    systemImage: showingSearch ? "xmark" : "magnifyingglass",
                    title: showingSearch ? "Close" : "Search",
                    progress: 1, width: 48, height: 48
                ) {
                    withAnimation(.smooth(duration: 0.2)) {
                        showingSearch.toggle()
                    }
                }
            },
            ReachabilityAction("settings", title: "Settings") {
                chromeButton(systemImage: "gearshape", title: "Settings", progress: 1, width: 48, height: 48) {
                    NotificationCenter.default.post(name: .openSettingsCommand, object: nil)
                }
            },
            ReachabilityAction("add", title: "Add") {
                chromeButton(systemImage: "plus", title: "Add", progress: 1, width: 48, height: 48) {
                    showingAddWorkout = true
                }
            }
        ]
    }

    private func workoutsHeader(progress: CGFloat, metrics: ScrollingChromeMetrics) -> some View {
        let morph = metrics.morph(progress)
        let controlWidth = metrics.controlWidth(morph)
        let controlHeight = metrics.controlHeight(morph)

        return VStack(spacing: 0) {
            ScrollingChromeHeader(title: "Workouts", progress: morph, metrics: metrics) {
                HStack(spacing: metrics.controlSpacing) {
                    chromeButton(
                        systemImage: showingSearch ? "xmark" : "magnifyingglass",
                        title: showingSearch ? "Close" : "Search",
                        progress: morph,
                        width: controlWidth,
                        height: controlHeight
                    ) {
                        withAnimation(.smooth(duration: 0.2)) {
                            showingSearch.toggle()
                        }
                    }
                    chromeButton(
                        systemImage: "gearshape",
                        title: "Settings",
                        progress: morph,
                        width: controlWidth,
                        height: controlHeight
                    ) {
                        NotificationCenter.default.post(name: .openSettingsCommand, object: nil)
                    }
                    chromeButton(
                        systemImage: "plus",
                        title: "Add",
                        progress: morph,
                        width: controlWidth,
                        height: controlHeight
                    ) {
                        showingAddWorkout = true
                    }
                }
            }

            trackingTiles(metrics: metrics)

            if store.hasWeeklyGoal {
                weeklyGoalRow(metrics: metrics)
            }


            filterBar
        }
        .background(Theme.background.ignoresSafeArea(edges: .top))
    }

    private func chromeButton(
        systemImage: String,
        title: String,
        progress: CGFloat,
        width: CGFloat,
        height: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ScrollingChromeControl(
                systemImage: systemImage,
                title: title,
                progress: progress,
                width: width,
                height: height
            )
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel(title)
        .help(title)
    }

    private func trackingTiles(metrics: ScrollingChromeMetrics) -> some View {
        HStack(spacing: metrics.controlSpacing) {
            trackingTile(
                systemImage: "checkmark.circle",
                value: "\(completedSessionsThisWeek)",
                label: "Sessions this week",
                metrics: metrics
            )
            trackingTile(
                systemImage: "clock",
                value: durationText(totalSecondsThisWeek),
                label: "Training this week",
                metrics: metrics
            )
            trackingTile(
                systemImage: "flame",
                value: "\(store.streakInfo().current)",
                label: "Day streak",
                metrics: metrics
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func trackingTile(
        systemImage: String,
        value: String,
        label: String,
        metrics: ScrollingChromeMetrics
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 6)
        .frame(width: metrics.expandedControlWidth, height: statsTileHeight)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func weeklyGoalRow(metrics: ScrollingChromeMetrics) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Weekly goal")
                Spacer(minLength: 8)
                Text("\(completedSessionsThisWeek) of \(store.weeklyGoal)")
                    .monospacedDigit()
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.textSecondary)

            ProgressView(value: weeklyGoalProgress)
                .tint(Theme.toolbarOrange)
        }
        .padding(12)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly goal")
        .accessibilityValue("\(completedSessionsThisWeek) of \(store.weeklyGoal)")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)

            TextField("Search workouts", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .focused($searchFieldFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear workout search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
    }

    @ViewBuilder
    private var resumeBanner: some View {
        if let state = resumeManager.resumeState,
           let workout = store.workout(id: state.workoutId) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue \(workout.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(state.sectionName) · \(durationText(state.timeRemaining)) remaining")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 10)

                Button("Resume") {
                    playerWorkout = workout
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: true))
            }
            .padding(14)
            .modifier(TimeMasterCardSurface(emphasized: true, flat: true))
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    label: "All",
                    isSelected: !showingTodayOnly && selectedTypeID == nil
                ) {
                    showingTodayOnly = false
                    selectedTypeID = nil
                }

                filterChip(
                    label: "Today",
                    isSelected: showingTodayOnly
                ) {
                    showingTodayOnly.toggle()
                }

                ForEach(WorkoutType.all(custom: store.customWorkoutTypes)) { type in
                    filterChip(
                        label: type.name,
                        isSelected: selectedTypeID == type.id
                    ) {
                        selectedTypeID = selectedTypeID == type.id ? nil : type.id
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .frame(height: selectorRowHeight)
    }

    private func filterChip(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label).lineLimit(1).fixedSize()
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: showingTodayOnly ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textSecondary)
            Text(showingTodayOnly ? "Nothing scheduled today" : "No matching workouts")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(showingTodayOnly
                 ? "Switch to All to browse every saved workout."
                 : "Try another name or workout type.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if showingTodayOnly {
                Button("Show all workouts") {
                    showingTodayOnly = false
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }



    private var completedSessionsThisWeek: Int {
        weekHistoryEntries.count
    }

    private var totalSecondsThisWeek: Int {
        weekHistoryEntries.reduce(0) { total, entry in
            total + (entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted)
        }
    }

    private var weeklyGoalProgress: CGFloat {
        CGFloat(min(1, Double(completedSessionsThisWeek) / Double(max(1, store.weeklyGoal))))
    }

    private var weekHistoryEntries: [WorkoutHistoryEntry] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return store.historyEntries.filter { $0.completedAt >= start }
    }

    private func entries(for workout: Workout) -> [WorkoutHistoryEntry] {
        store.historyEntries.filter { $0.workoutId == workout.id }
    }

    private func sessionsThisWeek(for entries: [WorkoutHistoryEntry]) -> Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return entries.filter { $0.completedAt >= start }.count
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 { return "\(remainder)s" }
        if remainder == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainder)s"
    }


    private func workoutDestination(for workout: Workout) -> some View {
        WorkoutDetailView(workout: workout)
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 54))
                .foregroundStyle(Theme.textSecondary)
            Text("No Workouts Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Create a workout, then add exercises from your database.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                showingAddWorkout = true
            } label: {
                Label("Create Workout", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var addWorkoutSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Outdoor activity").font(.headline).foregroundColor(Theme.textPrimary)
                        HStack(spacing: 10) {
                            Button {
                                showingAddWorkout = false
                                activeOutdoorKind = .run
                            } label: { Label("Run", systemImage: "figure.run") }
                                .buttonStyle(TimeMasterActionButtonStyle())
                            Button {
                                showingAddWorkout = false
                                activeOutdoorKind = .walk
                            } label: { Label("Walk", systemImage: "figure.walk") }
                                .buttonStyle(TimeMasterActionButtonStyle())
                            Button {
                                showingAddWorkout = false
                                activeOutdoorKind = .bike
                            } label: { Label("Bike", systemImage: "bicycle") }
                                .buttonStyle(TimeMasterActionButtonStyle())
                        }
                    }
                    }
                    #endif
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        TextField("e.g., Morning HIIT", text: $newWorkoutName)
                            .padding(16)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .foregroundColor(Theme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                             ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                                 Button {
                                     newWorkoutType = type
                                 } label: {
                                     HStack {
                                         Image(systemName: type.icon)
                                         Text(type.name)
                                     }
                                    .font(.subheadline)
                                    .fontWeight(newWorkoutType == type ? .semibold : .regular)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(newWorkoutType == type ? Color.white.opacity(0.2) : Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(newWorkoutType == type ? Color.white : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon Color")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        IconColorPicker(selectedHex: $newWorkoutColor)
                    }

                    Spacer()

                    Button {
                        if !newWorkoutName.isEmpty {
                            let createdWorkout = store.addWorkout(
                                name: newWorkoutName,
                                type: newWorkoutType,
                                colorHex: newWorkoutColor
                            )
                            newWorkoutName = ""
                            newWorkoutType = .strength
                            newWorkoutColor = "FFFFFF"
                            showingAddWorkout = false
                            Task { @MainActor in
                                await Task.yield()
                                navigationPath = [createdWorkout]
                            }
                        }
                    } label: {
                        Text("Create Workout")
                            .font(.headline)
                            .foregroundColor(newWorkoutName.isEmpty ? Color.white.opacity(0.3) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(newWorkoutName.isEmpty ? Theme.surface : Color.white)
                            .cornerRadius(12)
                    }
                    .disabled(newWorkoutName.isEmpty)
                }
                .padding(16)
            }
            .navigationTitle("New Workout")
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") {
                    newWorkoutName = ""
                    newWorkoutType = .strength
                    newWorkoutColor = "FFFFFF"
                    showingAddWorkout = false
                }
                .foregroundColor(.white)
                                 }
            }
        }
    }

    // MARK: - Actions

    private func pinToWidget(_ workout: Workout) {
        let defaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        defaults?.set(workout.name,           forKey: "pinned_workout_name")
        defaults?.set(workout.id.uuidString,  forKey: "pinned_workout_id")
        defaults?.set(workout.colorHex,       forKey: "pinned_workout_color")
        WidgetCenter.shared.reloadAllTimelines()
    }
}


#Preview {
    WorkoutListView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
