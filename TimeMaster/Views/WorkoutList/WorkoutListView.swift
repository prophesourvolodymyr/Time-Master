import SwiftUI
import WidgetKit

struct WorkoutListView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @ObservedObject private var resumeManager = WorkoutResumeManager.shared
    @Binding var requestedWorkoutID: UUID?
    @State private var navigationPath: [Workout] = []
    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutType: WorkoutType = .strength
    @State private var newWorkoutColor: String = "FFFFFF"
    @State private var showingTodayOnly = false
    @State private var selectedTypeID: String?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var playerWorkout: Workout?
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    #endif
    @Namespace private var workoutTransitionNamespace

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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            summaryHeader
                            filterBar

                            if visibleWorkouts.isEmpty {
                                filteredEmptyState
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 300), spacing: 14)],
                                    spacing: 14
                                ) {
                                    ForEach(visibleWorkouts) { workout in
                                        NavigationLink(value: workout) {
                                            workoutCardLabel(for: workout)
                                        }
                                        .buttonStyle(.plain)
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
                        .frame(maxWidth: 980, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                }
            }
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button { showingAddWorkout = true } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                workoutDestination(for: workout)
            }
            .sheet(isPresented: $showingAddWorkout) {
                addWorkoutSheet
            }
            .sheet(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(DatabaseStore.shared)
            }
            #if os(iOS)
            .sheet(item: $activeOutdoorKind) { kind in
                OutdoorRecorderView(kind: kind, store: outdoorStore, plannedRoute: nil)
            }
            #endif
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(outdoorStore)
            }
            .onAppear {
                openRequestedWorkout(requestedWorkoutID)
            }
            .onChange(of: requestedWorkoutID) { workoutID in
                openRequestedWorkout(workoutID)
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

        #if os(iOS)
        if #available(iOS 18.0, *) {
            WorkoutCard(
                workout: workout,
                schedule: schedule,
                sessionsThisWeek: sessionsThisWeek(for: historyEntries),
                lastCompletedAt: historyEntries.max(by: { $0.completedAt < $1.completedAt })?.completedAt,
                isResumable: resumeManager.resumeState?.workoutId == workout.id
            )
            .matchedTransitionSource(id: workout.id, in: workoutTransitionNamespace)
        } else {
            WorkoutCard(
                workout: workout,
                schedule: schedule,
                sessionsThisWeek: sessionsThisWeek(for: historyEntries),
                lastCompletedAt: historyEntries.max(by: { $0.completedAt < $1.completedAt })?.completedAt,
                isResumable: resumeManager.resumeState?.workoutId == workout.id
            )
        }
        #else
        WorkoutCard(
            workout: workout,
            schedule: schedule,
            sessionsThisWeek: sessionsThisWeek(for: historyEntries),
            lastCompletedAt: historyEntries.max(by: { $0.completedAt < $1.completedAt })?.completedAt,
            isResumable: resumeManager.resumeState?.workoutId == workout.id
        )
        #endif
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

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Your training library")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(store.workouts.count) saved \(store.workouts.count == 1 ? "workout" : "workouts")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 10) {
                metricTile(
                    value: "\(completedSessionsThisWeek)",
                    label: "sessions this week",
                    icon: "checkmark.circle"
                )
                metricTile(
                    value: durationText(totalSecondsThisWeek),
                    label: "training this week",
                    icon: "clock"
                )
                metricTile(
                    value: "\(store.streakInfo().current)",
                    label: "day streak",
                    icon: "flame"
                )
            }

            weeklyGoalProgress
            resumeBanner
        }
    }

    private var weeklyGoalProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(completedSessionsThisWeek) of \(store.weeklyGoal)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.surface2)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: proxy.size.width * weeklyGoalProgressValue)
                }
            }
            .frame(height: 6)
        }
        .padding(.top, 2)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white, in: Capsule())
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Workout scope", selection: $showingTodayOnly) {
                Text("All").tag(false)
                Text("Today").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            Menu {
                Button("All Types") {
                    selectedTypeID = nil
                }
                ForEach(WorkoutType.all(custom: store.customWorkoutTypes)) { type in
                    Button {
                        selectedTypeID = type.id
                    } label: {
                        Label(type.name, systemImage: type.icon)
                    }
                }
            } label: {
                Label(selectedTypeName, systemImage: "line.3.horizontal.decrease")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.surface, in: Capsule())
            }
            .menuStyle(.borderlessButton)

            Spacer()
        }
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

    private func metricTile(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 28, height: 28)
                .background(Theme.surface2, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var selectedTypeName: String {
        guard let selectedTypeID,
              let type = WorkoutType.all(custom: store.customWorkoutTypes).first(where: { $0.id == selectedTypeID })
        else {
            return "All types"
        }
        return type.name
    }

    private var completedSessionsThisWeek: Int {
        weekHistoryEntries.count
    }

    private var totalSecondsThisWeek: Int {
        weekHistoryEntries.reduce(0) { total, entry in
            total + (entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted)
        }
    }

    private var weeklyGoalProgressValue: CGFloat {
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


    @ViewBuilder
    private func workoutDestination(for workout: Workout) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            WorkoutDetailView(workout: workout)
                .navigationTransition(.zoom(sourceID: workout.id, in: workoutTransitionNamespace))
        } else {
            WorkoutDetailView(workout: workout)
        }
        #else
        WorkoutDetailView(workout: workout)
        #endif
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
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
            }
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Outdoor activity").font(.headline).foregroundColor(Theme.textPrimary)
                        HStack(spacing: 10) {
                            Button {
                                showingAddWorkout = false
                                activeOutdoorKind = .runWalk
                            } label: { Label("Run & Walk", systemImage: "figure.run") }
                                .buttonStyle(.bordered)
                            Button {
                                showingAddWorkout = false
                                activeOutdoorKind = .bike
                            } label: { Label("Bike", systemImage: "bicycle") }
                                .buttonStyle(.bordered)
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
