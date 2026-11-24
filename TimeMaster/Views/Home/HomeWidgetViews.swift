import SwiftUI

#if os(iOS)
import UIKit
#endif

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
    let onStartOutdoor: (OutdoorActivityKind, PlannedRoute?, UUID?) -> Void
    @ObservedObject private var resumeManager = WorkoutResumeManager.shared
    let onSkipScheduledWorkout: (ScheduledWorkout) -> Void
    let insights: HomeInsights
    let onPlanWorkout: (Date, UUID?) -> Void
    let onAddSkill: () -> Void
    let onRemoveWidget: () -> Void

    var body: some View {
        content
            .font(TimeMasterFont.body())
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
        case .outdoorMap:
            outdoorMap
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
        case .todaysPick:
            todaysPick
        case .weekAhead:
            weekAhead
        case .firstSteps:
            firstSteps
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(TimeMasterFont.black(26, relativeTo: .title))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HomeDateLine(date: now, streak: workoutStore.streakInfo().current)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)

    }

    @ViewBuilder
    private var today: some View {
        let items = visibleTodayItems
        if items.isEmpty {
            todayEmpty
        } else {
            HomeWidgetChrome(title: "Today") {
                VStack(spacing: 8) {
                    ForEach(items) { item in todayRow(item) }
                }
            }
        }
    }

    @ViewBuilder
    private var todayEmpty: some View {
        let options = picks
        if options.isEmpty {
            HomeWidgetChrome(title: nil) {
                HomeInvite(
                    footprint: widget.footprint,
                    systemImage: "calendar.badge.plus",
                    headline: "Nothing planned today",
                    detail: "Build a workout and Tmax will suggest one for you every day.",
                    action: HomeInviteAction(title: "Create", run: onCreateWorkout)
                )
            }
        } else {
            HomeTodaysPickCard(
                options: options,
                footprint: widget.footprint,
                showsDetails: widget.configuration.showDetails,
                planDate: now,
                kickerOverride: "Nothing planned today",
                actions: actions
            )
        }
    }

    private var quickStart: some View {
        let workout = quickStartWorkout
        return HomeWidgetChrome(title: "Quick Start", surface: true) {
            if let workout {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(TimeMasterFont.heading())
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if widget.configuration.showDetails && widget.footprint != .compact {
                                Text("\(workout.sectionCount) sections · \(durationText(workout.totalDuration))")
                                    .font(TimeMasterFont.caption())
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    Button {
                        onStartWorkout(workout)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(TimeMasterFont.sectionTitle())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
                }
            } else {
                emptyAction("Create a workout", systemImage: "plus", action: onCreateWorkout)
            }
        }
    }

    private var activityShortcuts: some View {
        let shortcuts = supportedShortcuts
        let caption = shortcuts.contains(.workout) && widget.footprint == .square ? workoutShortcutTarget?.name : nil
        return HomeWidgetChrome(title: "Start") {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let count = widget.footprint == .square ? 2 : max(1, shortcuts.count)
                    let rows = max(1, Int(ceil(Double(shortcuts.count) / Double(count))))
                    let diameter = max(44, min(
                        (proxy.size.width - CGFloat(count - 1) * 12) / CGFloat(count),
                        (proxy.size.height - CGFloat(rows - 1) * 12) / CGFloat(rows)
                    ))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: count), spacing: 12) {
                        ForEach(shortcuts) { shortcut in
                            HomeActivityShortcutCircle(shortcut: shortcut, diameter: diameter, action: { start(shortcut) })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let caption {
                    Text("Workout starts \(caption)")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    private var recentWorkouts: some View {
        let entries = Array(workoutStore.historyEntries.sorted { $0.completedAt > $1.completedAt }.prefix(visibleRowCount))
        return HomeWidgetChrome(title: "Recent workouts") {
            if entries.isEmpty {
                quietEmpty("No workouts yet.")
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(entries) { entry in
                        Button {
                            openHistoryEntry(entry)
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Color(hex: entry.workoutType.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(entry.workoutName)
                                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                if widget.footprint != .compact {
                                    Text(entry.completedAt, style: .relative)
                                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8)) { openHistoryEntry(entry) }
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
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(state.sectionName) · \(durationText(state.elapsedSeconds)) elapsed")
                        .font(TimeMasterFont.caption())
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        onStartWorkout(workout)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(.white, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 11))
                }
            } else {
                quietEmpty("All caught up.")
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
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(durationText(workout.totalDuration))
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 10)) { onStartWorkout(workout) }
            } else {
                emptyAction("Choose a workout", systemImage: "list.bullet", action: onBrowseWorkouts)
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        let progress = insights.progress
        if progress.hasHistory {
            HomeWidgetChrome(title: "Progress", surface: true) {
                metricLayout {
                    ForEach(widget.configuration.metricFields) { field in
                        metricCell(field)
                    }
                }
            }
        } else {
            HomeWidgetChrome(title: nil) { progressInvite(progress) }
        }
    }

    private var streak: some View {
        let streak = workoutStore.streakInfo()
        return HomeWidgetChrome(title: "Streak", surface: true) {
            VStack(spacing: 4) {
                Text("\(streak.current)")
                    .font(TimeMasterFont.black(48, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(streak.current == 1 ? "day" : "days")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                if widget.footprint == .square {
                    Text("Best · \(streak.best)")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var weeklyRhythm: some View {
        let types = visibleTypes
        return HomeWidgetChrome(title: "Weekly rhythm", surface: true) {
            if types.isEmpty {
                quietEmpty("Your week starts here.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(types.prefix(visibleRowCount))) { type in
                        let stats = workoutStore.typeStats(for: type)
                        let goal = max(GoalsManager.shared.goal(for: type), 1)
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 27, height: 27)
                                .background(Color(hex: type.colorHex), in: RoundedRectangle(cornerRadius: 8))
                            Text(type.name)
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .foregroundStyle(.white)
                            ProgressView(value: min(Double(stats.sessionsThisWeek) / Double(goal), 1))
                                .tint(Color(hex: type.colorHex))
                            Text("\(stats.sessionsThisWeek)/\(goal)")
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activityHeatmap: some View {
        if workoutStore.historyEntries.isEmpty && outdoorStore.establishedActivities.isEmpty && workoutStore.typeSchedules.allSatisfy({ !$0.isActive }) {
            HomeWidgetChrome(title: "Activity") { quietEmpty("No activity yet.") }
        } else {
            ActivityHeatmap(entries: workoutStore.historyEntries, outdoorActivities: outdoorStore.establishedActivities)
                .environmentObject(workoutStore)
        }
    }

    private var lifetimeStats: some View {
        let minutes = workoutStore.historyEntries.reduce(0) { $0 + $1.durationCompleted } / 60
        return HomeWidgetChrome(title: "Lifetime", surface: true) {
            metricLayout {
                metricValue("\(workoutStore.historyEntries.count)", label: "sessions")
                metricValue("\(minutes)m", label: "minutes")
            }
        }
    }

    private var typeBreakdown: some View {
        let types = visibleTypes
        return HomeWidgetChrome(title: "By type", surface: true) {
            if types.isEmpty {
                quietEmpty("No activity yet.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(types.prefix(visibleRowCount))) { type in
                        let stats = workoutStore.typeStats(for: type)
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundStyle(Color(hex: type.colorHex))
                            Text(type.name)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(stats.sessionsThisWeek) · \(stats.totalSeconds / 60)m")
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var outdoorSummary: some View {
        let finished = outdoorStore.establishedActivities
        return HomeWidgetChrome(title: "Outdoor", surface: true) {
            metricLayout {
                metricValue("\(finished.filter { $0.kind != .bike }.count)", label: "on foot")
                metricValue("\(finished.filter { $0.kind == .bike }.count)", label: "rides")
                metricValue(String(format: "%.1f km", finished.reduce(0) { $0 + $1.distanceMeters } / 1000), label: "distance")
            }
        }
    }
    private var outdoorMap: some View {
        HomeWidgetChrome(title: nil, surface: true) {
            Button {
                onStartOutdoor(.run, nil, nil)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.cyan)
                    Text("Explore")
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                    Text(exploreLine)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Open live map")
            .accessibilityHint(exploreLine)
        }
    }

    private var recoverActivity: some View {
        HomeWidgetChrome(title: "Recover activity") {
            if let activity = outdoorStore.recoverableActivities.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.title)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(.white)
                    Text(activity.finished ? "Ready to save" : "Paused")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        Button {
                            onStartOutdoor(activity.kind, outdoorStore.plannedRoute(withID: activity.plannedRouteID ?? ""), activity.id)
                        } label: {
                            Label(activity.finished ? "Review" : "Resume", systemImage: activity.finished ? "checkmark.circle" : "play.fill")
                        }
                        .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                    } else {
                        Text("Resume on iPhone")
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    #else
                    Text("Resume on iPhone")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .foregroundStyle(Theme.textSecondary)
                    #endif
                }
            } else {
                quietEmpty("All caught up.")
            }
        }
    }

    private var savedRoutes: some View {
        HomeWidgetChrome(title: "Saved routes") {
            let saved = outdoorStore.plannedRoutes.filter { !$0.isDraft }
            if saved.isEmpty {
                quietEmpty("No saved routes.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(saved.prefix(visibleRowCount))) { route in
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            Button {
                                onStartOutdoor(route.trip?.kind ?? .run, route, nil)
                            } label: {
                                routeRow(route)
                            }
                            .buttonStyle(.plain)
                        } else {
                            routeRow(route)
                        }
                        #else
                        routeRow(route)
                        #endif
                    }
                }
            }
        }
    }

    private var exerciseDatabase: some View {
        HomeWidgetChrome(title: "Exercises") {
            Button(action: onBrowseDatabase) {
                VStack(spacing: 6) {
                    Text("\(databaseCount)")
                        .font(TimeMasterFont.black(36, relativeTo: .largeTitle))
                        .monospacedDigit()
                    Text("Open database")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
        }
    }

    private var databaseOverview: some View {
        return HomeWidgetChrome(title: "Database", surface: true) {
            metricLayout {
                metricValue("\(databaseStore.rootPages.count)", label: "root pages")
                metricValue("\(databaseCount)", label: "pages")
            }
        }
    }

    private var buildFromDatabase: some View {
        HomeWidgetChrome(title: "Build a workout") {
            emptyAction("Browse exercises", systemImage: "plus", action: onBrowseDatabase)
        }
    }

    private var visibleRowCount: Int {
        let capacity = widget.footprint == .compact ? 1 : (widget.footprint == .wide ? 2 : 5)
        return min(max(1, widget.configuration.visibleCount), capacity)
    }

    private var metricLayout: AnyLayout {
        widget.footprint == .compact
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func quietEmpty(_ text: String) -> some View {
        Text(text)
            .font(TimeMasterFont.heading())
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actions: HomeWidgetActions {
        HomeWidgetActions(
            startWorkout: { id in
                if let workout = workoutStore.workout(id: id) { onStartWorkout(workout) }
            },
            planWorkout: onPlanWorkout,
            createWorkout: onCreateWorkout,
            browseWorkouts: onBrowseWorkouts,
            browseDatabase: onBrowseDatabase,
            addSkill: onAddSkill,
            removeWidget: onRemoveWidget
        )
    }

    private var pinnedOption: HomeWorkoutOption? {
        guard let id = widget.configuration.selectedWorkoutID else { return nil }
        if let known = insights.ranked.first(where: { $0.id == id }) { return known }
        return readyWorkouts.first(where: { $0.id == id }).map { HomeInsights.option(for: $0, lastCompletedAt: nil) }
    }

    private var picks: [HomePickOption] {
        HomePickResolver.options(
            planned: insights.today,
            skipped: skippedScheduledInstanceIDs,
            ranked: insights.ranked,
            pinned: widget.kind == .todaysPick ? pinnedOption : nil,
            now: now
        )
    }

    private var workoutShortcutTarget: Workout? {
        picks.first.flatMap { workoutStore.workout(id: $0.workout.id) } ?? readyWorkouts.first
    }

    private var todaysPick: some View {
        HomeTodaysPickCard(
            options: picks,
            footprint: widget.footprint,
            showsDetails: widget.configuration.showDetails,
            planDate: now,
            actions: actions
        )
    }

    private var weekAhead: some View {
        HomeWeekAheadCard(
            days: insights.week,
            footprint: widget.footprint,
            suggestion: insights.ranked.first,
            actions: actions
        )
    }

    private var firstSteps: some View {
        HomeFirstStepsCard(
            progress: insights.steps,
            footprint: widget.footprint,
            pick: picks.first,
            planDate: now,
            actions: actions
        )
    }

    private var exploreLine: String {
        let outdoor = insights.outdoor
        if outdoor.sessions > 0 {
            let outings = HomeText.count(outdoor.sessions, "outing", "outings")
            return outdoor.distanceKilometers >= 0.1
                ? "\(outings) · \(String(format: "%.1f", outdoor.distanceKilometers)) km"
                : outings
        }
        if outdoor.routes > 0 { return HomeText.count(outdoor.routes, "saved route", "saved routes") }
        return HomeWidgetPlatform.canRecordOutdoor ? "Walk, run or ride. Your first route starts here." : "Open the live map"
    }

    @ViewBuilder
    private func progressInvite(_ progress: HomeProgressSnapshot) -> some View {
        let message = HomeProgressCopy.message(for: progress)
        let pick = picks.first
        let ring = HomeRingBadge(
            fraction: progress.goalFraction,
            label: HomeProgressCopy.ringLabel(for: progress),
            diameter: widget.footprint == .compact ? 56 : (widget.footprint == .square ? 96 : 64),
            lineWidth: widget.footprint == .square ? 9 : 6
        )
        switch widget.footprint {
        case .compact:
            VStack(spacing: 8) {
                ring
                Text(message.headline)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .wide:
            HStack(spacing: 14) {
                ring
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.headline)
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(message.detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let pick {
                    HomePillButton(title: "Start", systemImage: "play.fill", hint: "Starts \(pick.workout.name)") {
                        actions.startWorkout(pick.workout.id)
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .square:
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ring
                Text(message.headline)
                    .font(TimeMasterFont.black(22, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(message.detail)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                if let pick {
                    HomePillButton(
                        title: "Start \(pick.workout.name)",
                        systemImage: "play.fill",
                        fillsWidth: true,
                        hint: "Starts \(pick.workout.name)"
                    ) {
                        actions.startWorkout(pick.workout.id)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var visibleTodayItems: [ScheduledWorkout] {
        workoutStore.scheduledWorkouts(for: now)
            .filter { !skippedScheduledInstanceIDs.contains($0.id) }
            .prefix(visibleRowCount)
            .map { $0 }
    }

    private var quickStartWorkout: Workout? {
        let scheduled = workoutStore.scheduledWorkouts(for: now)
            .filter { !skippedScheduledInstanceIDs.contains($0.id) }
        if let pending = scheduled.first(where: { $0.status == .pending }) {
            return pending.workout
        }
        let leading = insights.ranked.first?.id
        return readyWorkouts.first { $0.id != leading } ?? readyWorkouts.first
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
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return widget.configuration.activityShortcuts.filter { $0 == .workout }
        }
        var shortcuts = widget.configuration.activityShortcuts
        if shortcuts.contains(.runWalk), !shortcuts.contains(.walk) {
            shortcuts.append(.walk)
        }
        return shortcuts
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
        Button {
            onStartWorkout(item.workout)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.workout.name)
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if widget.configuration.showScheduledTime {
                        Text(item.timeRangeText)
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(widget.configuration.showStatus ? statusColor(item.status) : .white)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
        .accessibilityLabel("\(item.workout.name), \(item.timeRangeText), \(item.status.title)")
        .accessibilityHint("Start workout")
        .contextMenu {
            if item.status != .completed {
                Button("Skip", role: .destructive) { onSkipScheduledWorkout(item) }
            }
        }
    }

    private func metricCell(_ field: HomeMetricField) -> some View {
        let value: String
        switch field {
        case .sessions: value = "\(weeklyEntries.count)"
        case .streak: value = "\(workoutStore.streakInfo().current)"
        case .activeMinutes: value = "\(weeklyMinutes)m"
        }
        return metricValue(value, label: field.title)
    }

    private func metricValue(_ value: String, label: String) -> some View {
        let layout = widget.footprint == .compact
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            Text(value)
                .font(widget.footprint == .compact ? TimeMasterFont.sectionTitle() : TimeMasterFont.black(28, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
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
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 11))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 11))
    }

    private func start(_ shortcut: HomeActivityShortcut) {
        switch shortcut {
        case .workout:
            if let workout = workoutShortcutTarget { onStartWorkout(workout) } else { onCreateWorkout() }
        case .runWalk:
            onStartOutdoor(.run, nil, nil)
        case .walk:
            onStartOutdoor(.walk, nil, nil)
        case .bike:
            onStartOutdoor(.bike, nil, nil)
        }
    }

    private func openHistoryEntry(_ entry: WorkoutHistoryEntry) {
        if let workout = workoutStore.workout(id: entry.workoutId) {
            onStartWorkout(workout)
        } else {
            onBrowseWorkouts()
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
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(route.points.count) pts")
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .monospacedDigit()
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

private struct HomeActivityShortcutCircle: View {
    let shortcut: HomeActivityShortcut
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: shortcut.systemImage)
                    .font(.title2.weight(.semibold))
                Text(shortcut.title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(shortcutColor.opacity(0.22))
            )
            .overlay(
                Circle()
                    .stroke(shortcutColor.opacity(0.72), lineWidth: 1.5)
            )
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .contentShape(Circle())
        .accessibilityLabel(shortcut.title)
        .accessibilityHint("Start \(shortcut.title)")
    }

    private var shortcutColor: Color {
        switch shortcut {
        case .workout: Theme.toolbarOrange
        case .runWalk: .green
        case .walk: .mint
        case .bike: .cyan
        }
    }
}


struct HomeWidgetChrome<Content: View>: View {
    let title: String?
    let surface: Bool
    let accent: Color?
    let content: Content

    init(
        title: String?,
        surface: Bool = true,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.surface = surface
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            if let title {
                Text(title)
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                if surface {
                    RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                        .fill(Theme.surface)
                }
                if let accent {
                    RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.22), accent.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
        }
    }
}
