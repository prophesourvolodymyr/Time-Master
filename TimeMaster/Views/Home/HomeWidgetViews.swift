import SwiftUI

struct HomeWidgetContent: View {
    let widget: HomeWidgetInstance
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    let now: Date
    let skippedScheduledInstanceIDs: Set<String>
    let onStartWorkout: (Workout) -> Void
    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?) -> Void
    @ObservedObject private var resumeManager = WorkoutResumeManager.shared
    let onSkipScheduledWorkout: (ScheduledWorkout) -> Void

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch widget.kind {
        case .greeting:
            greeting
        case .today:
            today
        case .quickStart:
            quickStart
        case .activityShortcuts:
            activityShortcuts
        case .recentWorkouts:
            recentWorkouts
        case .resumeWorkout:
            resumeWorkout
        case .selectedWorkout:
            selectedWorkout
        case .metrics:
            metrics
        case .streak:
            streak
        case .weeklyRhythm:
            weeklyRhythm
        case .activityHeatmap:
            activityHeatmap
        case .lifetimeStats:
            lifetimeStats
        case .typeBreakdown:
            typeBreakdown
        case .outdoorSummary:
            outdoorSummary
        case .recoverActivity:
            recoverActivity
        case .savedRoutes:
            savedRoutes
        case .exerciseDatabase:
            exerciseDatabase
        case .databaseOverview:
            databaseOverview
        case .buildFromDatabase:
            buildFromDatabase
        }
    }

    private var greeting: some View {
        HomeWidgetChrome(title: nil) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(now, style: .date)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var today: some View {
        HomeWidgetChrome(title: "Today") {
            let items = visibleTodayItems
            VStack(alignment: .leading, spacing: 9) {
                if items.isEmpty {
                    Text("Nothing scheduled today")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Button("Browse workouts", action: onBrowseWorkouts)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    ForEach(items) { item in
                        todayRow(item)
                    }
                }
            }
        }
    }

    private var quickStart: some View {
        let workout = quickStartWorkout
        return HomeWidgetChrome(title: "Quick Start") {
            if let workout {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if widget.configuration.showDetails {
                                Text("\(workout.sectionCount) sections · \(durationText(workout.totalDuration))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: workout.type.iconName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color(hex: workout.colorHex), in: RoundedRectangle(cornerRadius: 11))
                    }
                    Button {
                        onStartWorkout(workout)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                emptyAction("Create a workout", systemImage: "plus", action: onCreateWorkout)
            }
        }
    }

    private var activityShortcuts: some View {
        let shortcuts = supportedShortcuts
        return HomeWidgetChrome(title: "Start something") {
            if shortcuts.isEmpty {
                Text("Choose an activity in the widget menu.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(shortcuts) { shortcut in
                        Button {
                            start(shortcut)
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: shortcut.systemImage)
                                    .font(.title3.weight(.semibold))
                                Text(shortcut.title)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background(shortcutColor(shortcut).opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(shortcutColor(shortcut).opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentWorkouts: some View {
        let entries = Array(workoutStore.historyEntries.sorted { $0.completedAt > $1.completedAt }.prefix(max(1, widget.configuration.visibleCount)))
        return HomeWidgetChrome(title: "Recent workouts") {
            if entries.isEmpty {
                Text("Finish a workout and it will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(entries) { entry in
                        Button {
                            if let workout = workoutStore.workout(id: entry.workoutId) {
                                onStartWorkout(workout)
                            } else {
                                onBrowseWorkouts()
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Color(hex: entry.workoutType.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(entry.workoutName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(entry.completedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resumeWorkout: some View {
        HomeWidgetChrome(title: "Continue") {
            if let state = resumeManager.resumeState,
               let workout = workoutStore.workout(id: state.workoutId) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.workoutName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(state.sectionName) · \(durationText(state.elapsedSeconds)) elapsed")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        onStartWorkout(workout)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(.white, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No workout is waiting to be resumed.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var selectedWorkout: some View {
        let workout = selectedWorkoutValue
        return HomeWidgetChrome(title: "Workout") {
            if let workout {
                Button {
                    onStartWorkout(workout)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: workout.type.iconName)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(hex: workout.colorHex), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(durationText(workout.totalDuration))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            } else {
                emptyAction("Choose a workout", systemImage: "list.bullet", action: onBrowseWorkouts)
            }
        }
    }

    private var metrics: some View {
        HomeWidgetChrome(title: "Progress") {
            HStack(spacing: 8) {
                ForEach(widget.configuration.metricFields) { field in
                    metricCell(field)
                }
            }
        }
    }

    private var streak: some View {
        let streak = workoutStore.streakInfo()
        return HomeWidgetChrome(title: "Streak") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: streak.current == 0 ? "flame" : "flame.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(streak.current == 0 ? Theme.textSecondary : .orange)
                Text("\(streak.current)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(streak.current == 1 ? "day" : "days")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Best \(streak.best)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var weeklyRhythm: some View {
        let types = visibleTypes
        return HomeWidgetChrome(title: "Weekly rhythm") {
            if types.isEmpty {
                Text("Complete a workout or set a schedule to see progress.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(types) { type in
                        let stats = workoutStore.typeStats(for: type)
                        let goal = max(GoalsManager.shared.goal(for: type), 1)
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 27, height: 27)
                                .background(Color(hex: type.colorHex), in: RoundedRectangle(cornerRadius: 8))
                            Text(type.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            ProgressView(value: min(Double(stats.sessionsThisWeek) / Double(goal), 1))
                                .tint(Color(hex: type.colorHex))
                            Text("\(stats.sessionsThisWeek)/\(goal)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var activityHeatmap: some View {
        ActivityHeatmap(
            entries: workoutStore.historyEntries,
            outdoorActivities: outdoorStore.activities
        )
        .environmentObject(workoutStore)
    }

    private var lifetimeStats: some View {
        let minutes = workoutStore.historyEntries.reduce(0) { $0 + $1.durationCompleted } / 60
        return HomeWidgetChrome(title: "Lifetime") {
            HStack(spacing: 8) {
                metricValue("\(workoutStore.historyEntries.count)", label: "sessions", icon: "checkmark.circle")
                metricValue("\(minutes)m", label: "minutes", icon: "clock")
            }
        }
    }

    private var typeBreakdown: some View {
        let types = visibleTypes
        return HomeWidgetChrome(title: "By type") {
            if types.isEmpty {
                Text("No type data yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(types) { type in
                        let stats = workoutStore.typeStats(for: type)
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundStyle(Color(hex: type.colorHex))
                            Text(type.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(stats.sessionsThisWeek) · \(stats.totalSeconds / 60)m")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var outdoorSummary: some View {
        let finished = outdoorStore.activities.filter(\.finished)
        return HomeWidgetChrome(title: "Outdoor") {
            HStack(spacing: 8) {
                metricValue("\(finished.filter { $0.kind == .runWalk }.count)", label: "runs", icon: "figure.run")
                metricValue("\(finished.filter { $0.kind == .bike }.count)", label: "rides", icon: "bicycle")
                metricValue(String(format: "%.1f km", finished.reduce(0) { $0 + $1.distanceMeters } / 1000), label: "distance", icon: "point.topleft.down.curvedto.point.bottomright.up")
            }
        }
    }

    private var recoverActivity: some View {
        HomeWidgetChrome(title: "Recover activity") {
            if let activity = outdoorStore.recoverableActivities.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("An unfinished \(activity.kind.displayName.lowercased()) is saved.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    #if os(iOS)
                    Button {
                        onStartOutdoor(activity.kind, outdoorStore.plannedRoute(withID: activity.plannedRouteID ?? ""))
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    #else
                    Text("Resume on iPhone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    #endif
                }
            } else {
                Text("No unfinished activity.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var savedRoutes: some View {
        HomeWidgetChrome(title: "Saved routes") {
            if outdoorStore.plannedRoutes.isEmpty {
                Text("Save a route while recording to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(outdoorStore.plannedRoutes.prefix(max(1, widget.configuration.visibleCount)))) { route in
                        #if os(iOS)
                        Button {
                            onStartOutdoor(.runWalk, route)
                        } label: {
                            routeRow(route)
                        }
                        .buttonStyle(.plain)
                        #else
                        routeRow(route)
                        #endif
                    }
                }
            }
        }
    }

    private var exerciseDatabase: some View {
        HomeWidgetChrome(title: "Exercise database") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(databaseCount) exercises and pages ready to use.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Open database", action: onBrowseDatabase)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var databaseOverview: some View {
        HomeWidgetChrome(title: "Database") {
            HStack(spacing: 8) {
                metricValue("\(databaseStore.rootPages.count)", label: "root pages", icon: "square.stack")
                metricValue("\(databaseCount)", label: "pages", icon: "doc.text")
            }
        }
    }

    private var buildFromDatabase: some View {
        HomeWidgetChrome(title: "Build from database") {
            VStack(alignment: .leading, spacing: 9) {
                Text("Turn a saved exercise into your next workout.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Browse exercises", action: onBrowseDatabase)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var visibleTodayItems: [ScheduledWorkout] {
        workoutStore.scheduledWorkouts(for: now)
            .filter { !skippedScheduledInstanceIDs.contains($0.id) }
            .prefix(max(1, widget.configuration.visibleCount))
            .map { $0 }
    }

    private var quickStartWorkout: Workout? {
        let scheduled = workoutStore.scheduledWorkouts(for: now)
            .filter { !skippedScheduledInstanceIDs.contains($0.id) }
        if let pending = scheduled.first(where: { $0.status == .pending }) {
            return pending.workout
        }
        return readyWorkouts.first
    }

    private var readyWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.sections.isEmpty }
    }

    private var selectedWorkoutValue: Workout? {
        if let selectedID = widget.configuration.selectedWorkoutID,
           let workout = readyWorkouts.first(where: { $0.id == selectedID }) {
            return workout
        }
        return readyWorkouts.first
    }

    private var visibleTypes: [WorkoutType] {
        let all = WorkoutType.all(custom: workoutStore.customWorkoutTypes)
        if let selectedTypeID = widget.configuration.selectedTypeID {
            return all.filter { $0.id == selectedTypeID }
        }
        return all.filter { type in
            workoutStore.historyEntries.contains { $0.workoutType.id == type.id } ||
            workoutStore.typeSchedules.contains { $0.type.id == type.id && $0.isActive }
        }
    }

    private var supportedShortcuts: [HomeActivityShortcut] {
        #if os(iOS)
        return widget.configuration.activityShortcuts
        #else
        return widget.configuration.activityShortcuts.filter { $0 == .workout }
        #endif
    }

    private var databaseCount: Int {
        max(databaseStore.allPagesFlat.count, databaseStore.rootExercises.count)
    }

    private var greetingText: String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private func todayRow(_ item: ScheduledWorkout) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.status == .completed ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(item.status == .completed ? .green : Theme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.timeRangeText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 4)
            if widget.configuration.showStatus {
                Text(item.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(item.status))
            }
            Button(item.status == .missed ? "Start Now" : "Start") {
                onStartWorkout(item.workout)
            }
            .font(.caption.weight(.semibold))
            .contextMenu {
                if item.status != .completed {
                    Button("Skip", role: .destructive) {
                        onSkipScheduledWorkout(item)
                    }
                }
            }
        }
    }

    private func metricCell(_ field: HomeMetricField) -> some View {
        let value: String
        let icon: String
        let tint: Color
        switch field {
        case .sessions:
            value = "\(weeklyEntries.count)"
            icon = "checkmark.seal.fill"
            tint = .green
        case .streak:
            value = "\(workoutStore.streakInfo().current)"
            icon = "flame.fill"
            tint = .orange
        case .activeMinutes:
            value = "\(weeklyMinutes)m"
            icon = "timer"
            tint = .cyan
        }
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.title3.bold()).foregroundStyle(.white).monospacedDigit()
            Text(field.title).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricValue(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(.cyan)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyEntries: [WorkoutHistoryEntry] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return workoutStore.historyEntries.filter { $0.completedAt >= start }
    }

    private var weeklyMinutes: Int {
        weeklyEntries.reduce(0) { $0 + (($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) / 60) }
    }

    private func emptyAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private func start(_ shortcut: HomeActivityShortcut) {
        switch shortcut {
        case .workout:
            if let workout = readyWorkouts.first { onStartWorkout(workout) } else { onCreateWorkout() }
        case .runWalk:
            onStartOutdoor(.runWalk, nil)
        case .bike:
            onStartOutdoor(.bike, nil)
        }
    }

    private func shortcutColor(_ shortcut: HomeActivityShortcut) -> Color {
        switch shortcut {
        case .workout: .orange
        case .runWalk: .green
        case .bike: .cyan
        }
    }

    private func statusColor(_ status: ScheduledWorkoutStatus) -> Color {
        switch status {
        case .pending: Theme.textSecondary
        case .completed: .green
        case .missed: .red
        }
    }

    private func routeRow(_ route: PlannedRoute) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "map")
                .foregroundStyle(.cyan)
            Text(route.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(route.points.count) pts")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds / 60)
        let remaining = max(0, seconds % 60)
        if minutes == 0 { return "\(remaining)s" }
        if remaining == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remaining)s"
    }
}

struct HomeWidgetChrome<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
