import SwiftUI
import WidgetKit
import TimeMasterCore
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
    let onOpenAnalytics: (AnalyticsTracker) -> Void
    @State private var navigationPath: [Workout] = [] { willSet { if newValue != navigationPath { EverPageTravel.willNavigate(from: navigationPath.count, to: newValue.count) } } }
    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutType: WorkoutType = .strength
    @State private var newWorkoutColor: String = "FFFFFF"
    @State private var showingTodayOnly = false
    @State private var selectedTypeID: String?
    @State private var selectedGroupID: UUID?
    @State private var collapsedSections: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var showingSearch = false
    @FocusState private var searchFieldFocused: Bool
    @State private var playerWorkout: Workout?
    @State private var groupEditor: WorkoutGroupEditorRequest?
    @State private var groupPendingDeletion: WorkoutGroup?
    @State private var dropTargetID: String?
    @State private var heroPresenter = WorkoutPageHeroPresenter()
    @Namespace private var filterNamespace
    @AppStorage("workouts.collapsedSections") private var collapsedSectionsRaw = ""
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    #endif

    init(
        requestedWorkoutID: Binding<UUID?> = .constant(nil),
        onOpenAnalytics: @escaping (AnalyticsTracker) -> Void
    ) {
        _requestedWorkoutID = requestedWorkoutID
        self.onOpenAnalytics = onOpenAnalytics
    }

    var body: some View {
        NavigationStack(path: $navigationPath.everPageTravel()) {
            ZStack {
                TmaxGlowBackground()

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
                addWorkoutSheet.keyNavHost()
            }
            .sheet(item: $groupEditor) { request in
                WorkoutGroupEditorSheet(group: request.group) { title, icon, iconType in
                    saveGroup(request, title: title, icon: icon, iconType: iconType)
                } onCancel: {
                    groupEditor = nil
                }
                .keyNavHost()
            }
            .alert(
                groupPendingDeletion.map { "Delete “\($0.title)”?" } ?? "",
                isPresented: Binding(get: { groupPendingDeletion != nil }, set: { if !$0 { groupPendingDeletion = nil } }),
                presenting: groupPendingDeletion
            ) { group in
                Button("Delete Section", role: .destructive) {
                    withAnimation(.smooth(duration: 0.2)) { store.deleteWorkoutGroup(id: group.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Its workouts stay saved and move out of the section.")
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
                PerfLog.event("workouts list appeared, path \(navigationPath.count)")
                openRequestedWorkout(requestedWorkoutID)
                collapsedSections = Set(collapsedSectionsRaw.split(separator: ",").map(String.init))
            }
            .onDisappear { PerfLog.event("workouts list disappeared") }
            .onChange(of: store.workoutGroups.map(\.id)) { ids in
                if let selected = selectedGroupID, !ids.contains(selected) { selectedGroupID = nil }
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
        .everPageStack(depth: navigationPath.count) { if !navigationPath.isEmpty { navigationPath.removeLast() } }
        .environment(\.workoutPageHeroPresenter, heroPresenter)
        .overlay { WorkoutPageHeroHost(presenter: heroPresenter) }
        .findCommand {
            guard navigationPath.isEmpty, playerWorkout == nil, !showingAddWorkout, groupEditor == nil, !store.workouts.isEmpty else { return false }
            if showingSearch {
                searchFieldFocused = true
            } else {
                withAnimation(.smooth(duration: 0.2)) { showingSearch = true }
            }
            return true
        }
        .macWindowTitleHidden()
        .font(TimeMasterFont.body())
    }

    private func openRequestedWorkout(_ workoutID: UUID?) {
        guard let workoutID else { return }
        defer { requestedWorkoutID = nil }

        guard let workout = store.workout(id: workoutID) else { return }
        navigationPath = [workout]
    }

    @ViewBuilder
    private func workoutCardLabel(for workout: Workout, schedule: ScheduledWorkout?) -> some View {
        WorkoutCard(
            workout: workout,
            schedule: schedule,
            isResumable: resumeManager.resumeState?.workoutId == workout.id
        )
    }

    private func scheduleByWorkoutID() -> [UUID: ScheduledWorkout] {
        store.scheduledWorkouts(for: Date()).reduce(into: [UUID: ScheduledWorkout]()) { result, item in
            result[item.workout.id] = item
        }
    }

    private func visibleWorkouts(schedules: [UUID: ScheduledWorkout]) -> [Workout] {
        let sectionMembers = selectedGroupID.flatMap { id in store.workoutGroups.first { $0.id == id } }.map { Set($0.workoutIDs) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.workouts.filter { workout in
            let matchesToday = !showingTodayOnly || schedules[workout.id] != nil
            let matchesType = selectedTypeID == nil || workout.type.id == selectedTypeID
            let matchesSection = sectionMembers?.contains(workout.id) ?? true
            let matchesSearch = query.isEmpty
                || workout.name.localizedCaseInsensitiveContains(searchText)
                || workout.type.name.localizedCaseInsensitiveContains(searchText)
            return matchesToday && matchesType && matchesSection && matchesSearch
        }
    }

    /// Widest the tracking tiles and chrome controls grow before they stop filling their row.
    private static let trackingControlMaxHeight: CGFloat = 148
    /// Widest the page content and chrome grow on large screens.
    private static let contentMaxWidth: CGFloat = 980

    private var workoutsChrome: some View {
        let week = WorkoutWeekSummary(entries: store.historyEntries)
        return ScrollingChrome(metrics: { width in
            ScrollingChromeMetrics(
                width: min(width, Self.contentMaxWidth),
                collapsedRowHeight: 48,
                expandedControlWidthCap: .infinity,
                expandedControlHeightCap: Self.trackingControlMaxHeight
            )
        }) { metrics in
            workoutsScrollContent(metrics: metrics)
        } header: { progress, metrics in
            workoutsHeader(progress: progress, metrics: metrics, week: week)
        }
    }

    private func workoutsScrollContent(metrics: ScrollingChromeMetrics) -> some View {
        let schedules = scheduleByWorkoutID()
        let visible = visibleWorkouts(schedules: schedules)
        return VStack(alignment: .leading, spacing: 18) {
            if showingSearch {
                searchField
            }

            resumeBanner

            if visible.isEmpty {
                filteredEmptyState
            } else {
                groupedWorkouts(visible: visible, schedules: schedules)
            }
        }
        .frame(maxWidth: Self.contentMaxWidth, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    // MARK: - Sections

    private static let looseSectionKey = "other"

    private var isFiltering: Bool {
        showingTodayOnly || selectedTypeID != nil || selectedGroupID != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var listAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)
    }

    /// While filtering every section is open, so no match hides behind a fold.
    private func isCollapsed(_ key: String) -> Bool {
        !isFiltering && collapsedSections.contains(key)
    }

    private func toggleCollapsed(_ key: String) {
        withAnimation(listAnimation) {
            if collapsedSections.remove(key) == nil { collapsedSections.insert(key) }
        }
        collapsedSectionsRaw = collapsedSections.sorted().joined(separator: ",")
    }

    private var sectionBodyTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .offset(y: -6))
        )
    }

    private func groupedWorkouts(visible: [Workout], schedules: [UUID: ScheduledWorkout]) -> some View {
        let byID = Dictionary(visible.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let grouped = Set(store.workoutGroups.flatMap(\.workoutIDs))
        let loose = visible.filter { !grouped.contains($0.id) }
        let groups = store.workoutGroups

        return LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(groups) { group in
                let members = group.workoutIDs.compactMap { byID[$0] }
                if !isFiltering || !members.isEmpty {
                    groupHeader(group, count: members.count, isFirst: group.id == groups.first?.id, isLast: group.id == groups.last?.id)
                    if !isCollapsed(group.id.uuidString) {
                        VStack(spacing: 12) {
                            if members.isEmpty {
                                WorkoutGroupDropZone(isTargeted: dropTargetID == "zone:\(group.id)")
                                    .dropDestination(for: String.self) { items, _ in
                                        drop(items, onGroup: group.id)
                                    } isTargeted: { setDropTarget("zone:\(group.id)", $0) }
                            }
                            ForEach(members) { workout in
                                workoutRow(workout, in: group, schedule: schedules[workout.id])
                            }
                        }
                        .transition(sectionBodyTransition)
                    }
                }
            }
            if !loose.isEmpty {
                if !groups.isEmpty {
                    looseHeader(count: loose.count)
                }
                if groups.isEmpty || !isCollapsed(Self.looseSectionKey) {
                    VStack(spacing: 12) {
                        ForEach(loose) { workout in
                            workoutRow(workout, in: nil, schedule: schedules[workout.id])
                        }
                    }
                    .transition(sectionBodyTransition)
                }
            }
            if !isFiltering {
                NewWorkoutGroupButton { groupEditor = WorkoutGroupEditorRequest() }
                    .padding(.top, 6)
            }
        }
    }

    private func groupHeader(_ group: WorkoutGroup, count: Int, isFirst: Bool, isLast: Bool) -> some View {
        WorkoutGroupHeader(
            title: group.title,
            icon: group.icon,
            iconType: group.iconType,
            count: count,
            isCollapsed: isCollapsed(group.id.uuidString),
            isDropTarget: dropTargetID == "group:\(group.id)"
        ) {
            toggleCollapsed(group.id.uuidString)
        }
        .padding(.top, isFirst ? 0 : 14)
        .contextMenu {
            Button {
                groupEditor = WorkoutGroupEditorRequest(group: group)
            } label: {
                Label("Edit Section", systemImage: "pencil")
            }
            Button {
                withAnimation(.smooth(duration: 0.2)) { store.moveWorkoutGroup(group.id, by: -1) }
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(isFirst)
            Button {
                withAnimation(.smooth(duration: 0.2)) { store.moveWorkoutGroup(group.id, by: 1) }
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(isLast)
            Divider()
            Button(role: .destructive) {
                groupPendingDeletion = group
            } label: {
                Label("Delete Section", systemImage: "trash")
            }
        }
        .draggable(WorkoutListDrag.group(group.id).payload) {
            dragPreview(title: group.title, systemImage: "square.stack.fill")
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, onGroup: group.id)
        } isTargeted: { setDropTarget("group:\(group.id)", $0) }
    }

    private func looseHeader(count: Int) -> some View {
        WorkoutGroupHeader(
            title: "Other Workouts",
            icon: "tray.fill",
            iconType: .system,
            count: count,
            isCollapsed: isCollapsed(Self.looseSectionKey),
            isDropTarget: dropTargetID == "group:\(Self.looseSectionKey)"
        ) {
            toggleCollapsed(Self.looseSectionKey)
        }
        .padding(.top, 14)
        .dropDestination(for: String.self) { items, _ in
            drop(items, onGroup: nil)
        } isTargeted: { setDropTarget("group:\(Self.looseSectionKey)", $0) }
    }

    private func workoutRow(_ workout: Workout, in group: WorkoutGroup?, schedule: ScheduledWorkout?) -> some View {
        NavigationLink(value: workout) {
            workoutCardLabel(for: workout, schedule: schedule)
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

            moveToSectionMenu(workout, current: group)

            Divider()

            Button(role: .destructive) {
                store.deleteWorkout(workout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .draggable(WorkoutListDrag.workout(workout.id).payload) {
            dragPreview(title: workout.name, systemImage: workout.type.icon)
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, onWorkout: workout.id, in: group?.id)
        } isTargeted: { setDropTarget("workout:\(workout.id)", $0) }
        .overlay(alignment: .top) {
            if dropTargetID == "workout:\(workout.id)" {
                Capsule()
                    .fill(Theme.toolbarOrange)
                    .frame(height: 3)
                    .offset(y: -7)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func moveToSectionMenu(_ workout: Workout, current: WorkoutGroup?) -> some View {
        Menu {
            ForEach(store.workoutGroups) { target in
                Button {
                    withAnimation(.smooth(duration: 0.2)) { store.moveWorkout(workout.id, toGroup: target.id) }
                } label: {
                    if target.id == current?.id {
                        Label(target.title, systemImage: "checkmark")
                    } else {
                        Text(target.title)
                    }
                }
                .disabled(target.id == current?.id)
            }
            if current != nil {
                Divider()
                Button("No Section") {
                    withAnimation(.smooth(duration: 0.2)) { store.moveWorkout(workout.id, toGroup: nil) }
                }
            }
            Divider()
            Button("New Section…") {
                groupEditor = WorkoutGroupEditorRequest(workoutToMove: workout.id)
            }
        } label: {
            Label("Move to Section", systemImage: "rectangle.stack")
        }
    }

    private func dragPreview(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface2, in: Capsule())
    }

    private func setDropTarget(_ key: String, _ isTargeted: Bool) {
        if isTargeted {
            dropTargetID = key
        } else if dropTargetID == key {
            dropTargetID = nil
        }
    }

    /// A workout dropped on a section title goes to the end of that section; a section dropped on another takes its
    /// place. Nil is "Other Workouts": a workout leaves its section, a section moves to the bottom.
    private func drop(_ items: [String], onGroup groupID: UUID?) -> Bool {
        guard let item = items.lazy.compactMap(WorkoutListDrag.init).first else { return false }
        withAnimation(.smooth(duration: 0.2)) {
            switch item {
            case .workout(let id):
                store.moveWorkout(id, toGroup: groupID)
            case .group(let id):
                if let groupID { store.moveWorkoutGroup(id, onto: groupID) } else { store.moveWorkoutGroupToEnd(id) }
            }
        }
        dropTargetID = nil
        return true
    }

    /// A workout dropped on another one takes its place in that workout's section.
    private func drop(_ items: [String], onWorkout targetID: UUID, in groupID: UUID?) -> Bool {
        guard let item = items.lazy.compactMap(WorkoutListDrag.init).first else { return false }
        if case .workout(let id) = item {
            withAnimation(.smooth(duration: 0.2)) { store.moveWorkout(id, toGroup: groupID, at: targetID) }
            dropTargetID = nil
            return true
        }
        return drop(items, onGroup: groupID)
    }

    private func saveGroup(_ request: WorkoutGroupEditorRequest, title: String, icon: String, iconType: SkillBoardIconType?) {
        if let group = request.group {
            store.updateWorkoutGroup(id: group.id, title: title, icon: icon, iconType: iconType)
        } else {
            withAnimation(.smooth(duration: 0.2)) {
                let created = store.addWorkoutGroup(title: title, icon: icon, iconType: iconType)
                if let workoutID = request.workoutToMove {
                    store.moveWorkout(workoutID, toGroup: created.id)
                }
            }
        }
        groupEditor = nil
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

    private func workoutsHeader(progress: CGFloat, metrics: ScrollingChromeMetrics, week: WorkoutWeekSummary) -> some View {
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

            trackingTiles(metrics: metrics, week: week)

            if store.hasWeeklyGoal {
                weeklyGoalRow(metrics: metrics, sessions: week.sessions)
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
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: width, height: height))
        .accessibilityLabel(title)
        .help(title)
    }

    private func trackingTiles(metrics: ScrollingChromeMetrics, week: WorkoutWeekSummary) -> some View {
        HStack(spacing: metrics.controlSpacing) {
            trackingTile(
                tracker: .sessions,
                value: "\(week.sessions)",
                metrics: metrics
            )
            trackingTile(
                tracker: .trainingTime,
                value: durationText(week.seconds),
                metrics: metrics
            )
            trackingTile(
                tracker: .streak,
                value: "\(store.streakInfo().current)",
                metrics: metrics
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func trackingTile(
        tracker: AnalyticsTracker,
        value: String,
        metrics: ScrollingChromeMetrics
    ) -> some View {
        Button {
            onOpenAnalytics(tracker)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tracker.systemImage)
                    .font(.title.weight(.semibold))
                Text(value)
                    .font(TimeMasterFont.heading().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 6)
            .frame(width: metrics.expandedControlWidth, height: statsTileHeight)
            .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: 16))
        .accessibilityLabel(tracker.title)
        .accessibilityValue(value)
        .accessibilityHint("Opens this tracker in Analytics")
        .accessibilityIdentifier("workouts.metric.\(tracker.rawValue)")
    }

    private func weeklyGoalRow(metrics: ScrollingChromeMetrics, sessions: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Weekly goal")
                Spacer(minLength: 8)
                Text("\(sessions) of \(store.weeklyGoal)")
                    .monospacedDigit()
            }
            .font(TimeMasterFont.body(13, relativeTo: .footnote))
            .foregroundStyle(Theme.textSecondary)

            ProgressView(value: min(1, Double(sessions) / Double(max(1, store.weeklyGoal))))
                .tint(Theme.toolbarOrange)
        }
        .padding(12)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly goal")
        .accessibilityValue("\(sessions) of \(store.weeklyGoal)")
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
                .keyNavPlainButtonStyle(shape: .circle)
                .accessibilityLabel("Clear workout search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 14), action: { searchFieldFocused = true })
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
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(state.sectionName) · \(durationText(state.timeRemaining)) remaining")
                        .font(TimeMasterFont.caption())
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
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(
                        label: "All",
                        isSelected: !showingTodayOnly && selectedTypeID == nil && selectedGroupID == nil,
                        matchID: filterMatchID("all")
                    ) {
                        withAnimation(listAnimation) {
                            showingTodayOnly = false
                            selectedTypeID = nil
                            selectedGroupID = nil
                        }
                    }

                    filterChip(
                        label: "Today",
                        isSelected: showingTodayOnly,
                        matchID: filterMatchID("today")
                    ) {
                        withAnimation(listAnimation) { showingTodayOnly.toggle() }
                    }

                    if !store.workoutGroups.isEmpty {
                        filterDivider
                        ForEach(store.workoutGroups) { group in
                            sectionChip(group)
                        }
                        filterDivider
                    }

                    ForEach(WorkoutType.all(custom: store.customWorkoutTypes)) { type in
                        filterChip(
                            label: type.name,
                            isSelected: selectedTypeID == type.id,
                            matchID: filterMatchID("type")
                        ) {
                            withAnimation(listAnimation) {
                                selectedTypeID = selectedTypeID == type.id ? nil : type.id
                            }
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 18)
                .padding(.vertical, 6)
            }
            .mask {
                HStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 18)
                }
            }

            Button {
                groupEditor = WorkoutGroupEditorRequest()
            } label: {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 38))
            .help("New Section")
            .accessibilityLabel("New Section")
            .padding(.leading, 6)
            .padding(.trailing, 20)
        }
        .frame(height: selectorRowHeight)
    }

    private var filterDivider: some View {
        Capsule()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }

    /// Today, a section and a type can be on together. While at most one is on, every chip shares one pill that slides
    /// to the chip tapped; once they combine, each group's chip keeps a pill of its own that fills and empties in place.
    private func filterMatchID(_ group: String) -> String {
        let active = (showingTodayOnly ? 1 : 0) + (selectedTypeID == nil ? 0 : 1) + (selectedGroupID == nil ? 0 : 1)
        return active <= 1 ? "single" : group
    }

    private func sectionChip(_ group: WorkoutGroup) -> some View {
        let isSelected = selectedGroupID == group.id
        return Button {
            withAnimation(listAnimation) {
                selectedGroupID = isSelected ? nil : group.id
            }
        } label: {
            HStack(spacing: 6) {
                if !group.icon.isEmpty {
                    SkillIconView(
                        iconName: group.icon,
                        iconType: group.iconType ?? .emoji,
                        colorHex: isSelected ? "FFFFFF" : nil,
                        size: 13
                    )
                }
                Text(group.title).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(TmaxChipButtonStyle(isSelected: isSelected, namespace: filterNamespace, matchID: filterMatchID("section")))
        .overlay {
            if dropTargetID == "chip:\(group.id)" {
                Capsule(style: .continuous)
                    .stroke(Theme.toolbarOrange, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, onGroup: group.id)
        } isTargeted: { setDropTarget("chip:\(group.id)", $0) }
        .contextMenu {
            Button {
                groupEditor = WorkoutGroupEditorRequest(group: group)
            } label: {
                Label("Edit Section", systemImage: "pencil")
            }
            Button(role: .destructive) {
                groupPendingDeletion = group
            } label: {
                Label("Delete Section", systemImage: "trash")
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows only this section")
    }

    private func filterChip(
        label: String,
        isSelected: Bool,
        matchID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label).lineLimit(1).fixedSize()
        }
        .buttonStyle(TmaxChipButtonStyle(isSelected: isSelected, namespace: filterNamespace, matchID: matchID))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("workouts.filter.\(label)")
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: showingTodayOnly ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textSecondary)
            Text(showingTodayOnly ? "Nothing scheduled today" : "No matching workouts")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            Text(showingTodayOnly
                 ? "Switch to All to browse every saved workout."
                 : "Try another name or workout type.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
            if showingTodayOnly {
                Button("Show all workouts") {
                    showingTodayOnly = false
                }
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
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
                .font(TimeMasterFont.black(22, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
            Text("Create a workout, then add exercises from your database.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                showingAddWorkout = true
            } label: {
                Label("Create Workout", systemImage: "plus")
                    .font(TimeMasterFont.black(17, relativeTo: .headline))
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
                        Text("Outdoor activity").font(TimeMasterFont.black(17, relativeTo: .headline)).foregroundColor(Theme.textPrimary)
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
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                            .foregroundColor(Theme.textPrimary)
                        TextField("e.g., Morning HIIT", text: $newWorkoutName)
                            .padding(16)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .foregroundColor(Theme.textPrimary)
                            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                            .foregroundColor(Theme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                             ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                                 Button {
                                     newWorkoutType = type
                                 } label: {
                                     HStack {
                                         Image(systemName: type.icon)
                                             .font(.subheadline.weight(newWorkoutType == type ? .semibold : .regular))
                                         Text(type.name)
                                     }
                                    .font(newWorkoutType == type
                                          ? TimeMasterFont.black(15, relativeTo: .subheadline)
                                          : TimeMasterFont.body(15, relativeTo: .subheadline))
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
                                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon Color")
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
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
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                            .foregroundColor(newWorkoutName.isEmpty ? Color.white.opacity(0.3) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(newWorkoutName.isEmpty ? Theme.surface : Color.white)
                            .cornerRadius(12)
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
                    .disabled(newWorkoutName.isEmpty)
                }
                .padding(16)
            }
            .timeMasterNavigationTitle("New Workout")
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
    WorkoutListPreview()
}

private struct WorkoutListPreview: View {
    @State private var requestedTracker: AnalyticsTracker?
    @State private var showingAnalytics = false
    @StateObject private var store = WorkoutStore()
    @StateObject private var outdoorStore = OutdoorActivityStore()
    @StateObject private var preferences = OutdoorRecordingPreferencesStore()

    var body: some View {
        WorkoutListView { tracker in
            requestedTracker = tracker
            showingAnalytics = true
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView(requestedTracker: $requestedTracker)
        }
        .environmentObject(store)
        .environmentObject(outdoorStore)
        .environmentObject(preferences)
        .environmentObject(MusicLibraryStore.shared)
        .preferredColorScheme(.dark)
    }
}
