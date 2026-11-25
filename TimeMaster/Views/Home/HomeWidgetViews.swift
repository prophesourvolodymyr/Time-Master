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
            HomeWidgetChrome(label: "Today") {
                VStack(spacing: 6) {
                    ForEach(items) { item in todayRow(item) }
                }
            }
        }
    }

    @ViewBuilder
    private var todayEmpty: some View {
        let options = picks
        if options.isEmpty {
            HomeWidgetChrome(art: .calendar, spot: .home(widget.footprint)) {
                HomeInvite(
                    footprint: widget.footprint,
                    headline: "Nothing planned today",
                    action: HomeInviteAction(
                        title: "Create",
                        hint: "Build a workout and Tmax will suggest one for you every day",
                        run: onCreateWorkout
                    )
                )
            }
        } else {
            HomeTodaysPickCard(
                options: options,
                footprint: widget.footprint,
                showsDetails: widget.configuration.showDetails,
                planDate: now,
                kickerOverride: "Free day",
                actions: actions
            )
        }
    }

    @ViewBuilder
    private var quickStart: some View {
        if let workout = quickStartWorkout {
            HomeWidgetChrome(art: .forWorkout(workout), spot: .home(widget.footprint)) {
                HomeFeatureLayout(
                    footprint: widget.footprint,
                    title: WorkoutTitle.short(workout.name),
                    meta: widget.configuration.showDetails ? HomeText.duration(seconds: workout.totalDuration) : nil
                ) {
                    startControl(title: "Start", hint: "Starts \(workout.name)") { onStartWorkout(workout) }
                }
            }
        } else {
            HomeWidgetChrome(art: .dumbbell, spot: .home(widget.footprint)) {
                HomeInvite(
                    footprint: widget.footprint,
                    headline: "No workouts yet",
                    action: HomeInviteAction(title: "Create", hint: "Creates a workout", run: onCreateWorkout)
                )
            }
        }
    }

    private var activityShortcuts: some View {
        let shortcuts = supportedShortcuts
        return HomeWidgetChrome {
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
        }
    }

    private var recentWorkouts: some View {
        let entries = Array(workoutStore.historyEntries.sorted { $0.completedAt > $1.completedAt }.prefix(visibleRowCount))
        return HomeWidgetChrome(label: "Recent") {
            if entries.isEmpty {
                quietEmpty("No workouts yet")
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(entries) { entry in
                        Button {
                            openHistoryEntry(entry)
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Theme.toolbarOrange)
                                    .frame(width: 8, height: 8)
                                Text(WorkoutTitle.short(entry.workoutName))
                                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                if widget.footprint != .compact {
                                    Text(entry.completedAt, style: .relative)
                                        .font(WidgetFont.label())
                                        .monospacedDigit()
                                        .foregroundStyle(WidgetTint.graphite.secondaryInk)
                                }
                            }
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8)) { openHistoryEntry(entry) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resumeWorkout: some View {
        if let state = resumeManager.resumeState, let workout = workoutStore.workout(id: state.workoutId) {
            HomeWidgetChrome(art: .stopwatch, spot: .home(widget.footprint)) {
                HomeFeatureLayout(
                    footprint: widget.footprint,
                    label: "Continue",
                    title: WorkoutTitle.short(state.workoutName),
                    meta: "\(durationText(state.elapsedSeconds)) in"
                ) {
                    startControl(
                        title: "Resume",
                        hint: "\(state.sectionName), \(durationText(state.elapsedSeconds)) elapsed"
                    ) { onStartWorkout(workout) }
                }
            }
        } else {
            HomeWidgetChrome(label: "Continue") {
                quietEmpty("All caught up")
            }
        }
    }

    @ViewBuilder
    private var selectedWorkout: some View {
        if let workout = selectedWorkoutValue {
            HomeWidgetChrome(art: .forWorkout(workout), spot: .home(widget.footprint)) {
                HomeFeatureLayout(
                    footprint: widget.footprint,
                    title: WorkoutTitle.short(workout.name),
                    meta: widget.configuration.showDetails ? HomeText.duration(seconds: workout.totalDuration) : nil
                ) {
                    startControl(title: "Start", hint: "Starts \(workout.name)") { onStartWorkout(workout) }
                }
            }
        } else {
            HomeWidgetChrome(art: .kettlebell, spot: .home(widget.footprint)) {
                HomeInvite(
                    footprint: widget.footprint,
                    headline: "Pick a workout",
                    action: HomeInviteAction(title: "Choose", systemImage: "list.bullet", hint: "Opens your workouts", run: onBrowseWorkouts)
                )
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        let progress = insights.progress
        if progress.hasHistory {
            HomeWidgetChrome(label: widget.footprint == .compact ? nil : "This week") {
                metricBlock {
                    ForEach(widget.configuration.metricFields) { field in
                        metricCell(field)
                    }
                }
            }
        } else {
            HomeWidgetChrome { progressInvite(progress) }
        }
    }

    private var streak: some View {
        let streak = workoutStore.streakInfo()
        let unit = streak.current == 1 ? "day" : "days"
        return HomeWidgetChrome(art: .flame, spot: .home(widget.footprint)) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHero(text: "\(streak.current)", size: widget.footprint == .square ? 72 : 48)
                WidgetLabel(text: unit)
                Spacer(minLength: 0)
                if widget.footprint == .square {
                    WidgetLabel(text: "Best \(streak.best)")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Streak, \(streak.current) \(unit), best \(streak.best)")
        }
    }

    private var weeklyRhythm: some View {
        let types = visibleTypes
        return HomeWidgetChrome(label: "This week") {
            if types.isEmpty {
                quietEmpty("Your week starts here")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(types.prefix(visibleRowCount))) { type in
                        let stats = workoutStore.typeStats(for: type)
                        let goal = max(GoalsManager.shared.goal(for: type), 1)
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WidgetTint.graphite.ink)
                                .frame(width: 27, height: 27)
                                .background(WidgetTint.graphite.softFill, in: Circle())
                            Text(type.name)
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .lineLimit(1)
                            ProgressView(value: min(Double(stats.sessionsThisWeek) / Double(goal), 1))
                                .tint(Theme.toolbarOrange)
                            Text("\(stats.sessionsThisWeek)/\(goal)")
                                .font(WidgetFont.chip())
                                .foregroundStyle(WidgetTint.graphite.secondaryInk)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(type.name), \(stats.sessionsThisWeek) of \(goal) this week")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activityHeatmap: some View {
        if workoutStore.historyEntries.isEmpty && outdoorStore.establishedActivities.isEmpty && workoutStore.typeSchedules.allSatisfy({ !$0.isActive }) {
            HomeWidgetChrome(label: "Activity") { quietEmpty("No activity yet") }
        } else {
            ActivityHeatmap(entries: workoutStore.historyEntries, outdoorActivities: outdoorStore.establishedActivities)
                .environmentObject(workoutStore)
        }
    }

    private var lifetimeStats: some View {
        let minutes = workoutStore.historyEntries.reduce(0) { $0 + $1.durationCompleted } / 60
        return HomeWidgetChrome(art: .trophy, spot: .home(widget.footprint)) {
            artStats {
                metricValue("\(workoutStore.historyEntries.count)", label: "sessions")
                metricValue("\(minutes)m", label: "minutes")
            }
        }
    }

    private var typeBreakdown: some View {
        let types = visibleTypes
        return HomeWidgetChrome(label: "By type") {
            if types.isEmpty {
                quietEmpty("No activity yet")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(types.prefix(visibleRowCount))) { type in
                        let stats = workoutStore.typeStats(for: type)
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundStyle(Theme.toolbarOrange)
                            Text(type.name)
                                .font(TimeMasterFont.rowTitle())
                                .lineLimit(1)
                            Spacer()
                            Text("\(stats.sessionsThisWeek) · \(stats.totalSeconds / 60)m")
                                .font(WidgetFont.chip())
                                .foregroundStyle(WidgetTint.graphite.secondaryInk)
                        }
                    }
                }
            }
        }
    }

    private var outdoorSummary: some View {
        let finished = outdoorStore.establishedActivities
        return HomeWidgetChrome {
            metricBlock {
                metricValue("\(finished.filter { $0.kind != .bike }.count)", label: "on foot")
                metricValue("\(finished.filter { $0.kind == .bike }.count)", label: "rides")
                metricValue(String(format: "%.1f km", finished.reduce(0) { $0 + $1.distanceMeters } / 1000), label: "distance")
            }
        }
    }

    private var outdoorMap: some View {
        HomeWidgetChrome(art: .compass, spot: .home(widget.footprint)) {
            Button {
                onStartOutdoor(.run, nil, nil)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if widget.footprint == .square {
                        Spacer(minLength: 0)
                    }
                    WidgetTitle(text: "Explore", size: widget.footprint == .square ? 36 : 24, lines: 1)
                    if let detail = exploreDetail {
                        WidgetLabel(text: detail)
                    }
                    if widget.footprint != .square {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Open live map")
            .accessibilityHint(exploreLine)
        }
    }

    @ViewBuilder
    private var recoverActivity: some View {
        if let activity = outdoorStore.recoverableActivities.first {
            HomeWidgetChrome(art: .runningShoe, spot: .home(widget.footprint)) {
                HomeFeatureLayout(
                    footprint: widget.footprint,
                    label: activity.finished ? "Ready to save" : "Paused",
                    title: activity.title
                ) {
                    recoverControl(activity)
                }
            }
        } else {
            HomeWidgetChrome(label: "Recover") {
                quietEmpty("All caught up")
            }
        }
    }

    @ViewBuilder
    private func recoverControl(_ activity: OutdoorActivity) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            startControl(
                title: activity.finished ? "Review" : "Resume",
                systemImage: activity.finished ? "checkmark.circle" : "play.fill",
                hint: activity.finished ? "Opens the finished activity to save it" : "Resumes the activity"
            ) {
                onStartOutdoor(activity.kind, outdoorStore.plannedRoute(withID: activity.plannedRouteID ?? ""), activity.id)
            }
        } else {
            WidgetLabel(text: "Resume on iPhone")
        }
        #else
        WidgetLabel(text: "Resume on iPhone")
        #endif
    }

    private var savedRoutes: some View {
        HomeWidgetChrome(label: "Routes") {
            let saved = outdoorStore.plannedRoutes.filter { !$0.isDraft }
            if saved.isEmpty {
                quietEmpty("No saved routes")
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
        HomeWidgetChrome(art: .kettlebell, spot: .home(widget.footprint)) {
            Button(action: onBrowseDatabase) {
                VStack(alignment: .leading, spacing: 0) {
                    if widget.footprint == .square {
                        Spacer(minLength: 0)
                    }
                    WidgetHero(text: "\(databaseCount)", size: widget.footprint == .square ? 72 : 48)
                    WidgetLabel(text: databaseCount == 1 ? "page" : "pages")
                    if widget.footprint != .square {
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Exercise database, \(databaseCount) pages")
            .accessibilityHint("Opens the database")
        }
    }

    private var databaseOverview: some View {
        HomeWidgetChrome {
            metricBlock {
                metricValue("\(databaseStore.rootPages.count)", label: "root pages")
                metricValue("\(databaseCount)", label: "pages")
            }
        }
    }

    private var buildFromDatabase: some View {
        HomeWidgetChrome(art: .dumbbell, spot: .home(widget.footprint)) {
            HomeInvite(
                footprint: widget.footprint,
                headline: "Build a workout",
                action: HomeInviteAction(title: "Browse", hint: "Opens the exercise database", run: onBrowseDatabase)
            )
        }
    }

    private var visibleRowCount: Int {
        let capacity = widget.footprint == .compact ? 1 : (widget.footprint == .wide ? 2 : 5)
        return min(max(1, widget.configuration.visibleCount), capacity)
    }

    private func metricBlock<Metrics: View>(@ViewBuilder _ metrics: () -> Metrics) -> some View {
        let layout = widget.footprint == .wide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: widget.footprint == .compact ? 6 : 14))
        return layout { metrics() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func artStats<Stats: View>(@ViewBuilder _ stats: () -> Stats) -> some View {
        VStack(alignment: .leading, spacing: widget.footprint == .compact ? 6 : 12) {
            if widget.footprint == .square {
                Spacer(minLength: 0)
            }
            stats()
            if widget.footprint != .square {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func quietEmpty(_ text: String) -> some View {
        WidgetTitle(text: text, size: 20, lines: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private func startControl(
        title: String,
        systemImage: String = "play.fill",
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        switch widget.footprint {
        case .compact:
            HomeIconButton(systemImage: systemImage, label: title, hint: hint, prominent: true, action: action)
        case .wide:
            HomePillButton(title: title, systemImage: systemImage, hint: hint, action: action)
                .fixedSize()
        case .square:
            HomePillButton(title: title, systemImage: systemImage, fillsWidth: true, hint: hint, action: action)
        }
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
        picks.first.flatMap { workoutStore.workout(id: $0.workout.id) } ?? suggestableWorkouts.first
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

    private var exploreDetail: String? {
        let outdoor = insights.outdoor
        if outdoor.sessions > 0 {
            let outings = HomeText.count(outdoor.sessions, "outing", "outings")
            return outdoor.distanceKilometers >= 0.1
                ? "\(outings) · \(String(format: "%.1f", outdoor.distanceKilometers)) km"
                : outings
        }
        if outdoor.routes > 0 { return HomeText.count(outdoor.routes, "saved route", "saved routes") }
        return nil
    }

    private var exploreLine: String {
        if let exploreDetail { return exploreDetail }
        return HomeWidgetPlatform.canRecordOutdoor ? "Walk, run or ride. Your first route starts here." : "Open the live map"
    }

    @ViewBuilder
    private func progressInvite(_ progress: HomeProgressSnapshot) -> some View {
        let headline = HomeProgressCopy.message(for: progress).headline
        let pick = picks.first
        let ring = ZStack {
            WidgetRing(fraction: progress.goalFraction, lineWidth: widget.footprint == .square ? 14 : 10)
            WidgetHero(text: HomeProgressCopy.ringLabel(for: progress), size: widget.footprint == .square ? 40 : 28)
                .padding(.horizontal, 18)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headline). \(HomeProgressCopy.ringLabel(for: progress)) this week")
        switch widget.footprint {
        case .compact:
            ring
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .wide:
            HStack(spacing: 16) {
                ring
                VStack(alignment: .leading, spacing: 10) {
                    WidgetTitle(text: headline, size: 20, lines: 3)
                    if let pick {
                        HomePillButton(title: "Start", systemImage: "play.fill", hint: "Starts \(pick.workout.name)") {
                            actions.startWorkout(pick.workout.id)
                        }
                        .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .square:
            VStack(alignment: .leading, spacing: 14) {
                ring
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                WidgetTitle(text: headline, size: 26, lines: 2)
                if let pick {
                    HomePillButton(
                        title: "Start \(WorkoutTitle.short(pick.workout.name))",
                        systemImage: "play.fill",
                        fillsWidth: true,
                        hint: "Starts \(pick.workout.name)"
                    ) {
                        actions.startWorkout(pick.workout.id)
                    }
                }
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
        return suggestableWorkouts.first { $0.id != leading } ?? suggestableWorkouts.first
    }

    private var readyWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.sections.isEmpty }
    }

    private var suggestableWorkouts: [Workout] {
        readyWorkouts.filter { !workoutStore.isArchived($0) }
    }

    private var selectedWorkoutValue: Workout? {
        if let selectedID = widget.configuration.selectedWorkoutID,
           let workout = readyWorkouts.first(where: { $0.id == selectedID }) {
            return workout
        }
        return suggestableWorkouts.first
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(WorkoutTitle.short(item.workout.name))
                        .font(TimeMasterFont.black(17, relativeTo: .headline))
                        .lineLimit(1)
                    if widget.configuration.showScheduledTime {
                        WidgetLabel(text: item.timeRangeText)
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
        let symbol: String
        switch field {
        case .sessions:
            value = "\(weeklyEntries.count)"
            symbol = "checkmark.circle.fill"
        case .streak:
            value = "\(workoutStore.streakInfo().current)"
            symbol = "flame.fill"
        case .activeMinutes:
            value = "\(weeklyMinutes)m"
            symbol = "timer"
        }
        return metricValue(value, label: field.title, systemImage: symbol)
    }

    @ViewBuilder
    private func metricValue(_ value: String, label: String, systemImage: String? = nil) -> some View {
        if widget.footprint == .compact {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.toolbarOrange)
                    WidgetHero(text: value, size: 28)
                        .fixedSize()
                } else {
                    WidgetHero(text: value, size: 28)
                        .fixedSize()
                    WidgetLabel(text: label)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label), \(value)")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    WidgetLabel(text: label)
                }
                WidgetHero(text: value, size: widget.footprint == .square ? 56 : 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label), \(value)")
        }
    }

    private var weeklyEntries: [WorkoutHistoryEntry] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return workoutStore.historyEntries.filter { $0.completedAt >= start }
    }

    private var weeklyMinutes: Int {
        weeklyEntries.reduce(0) { $0 + (($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) / 60) }
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
        case .pending: WidgetTint.graphite.secondaryInk
        case .completed: Theme.toolbarOrange
        case .missed: WidgetTint.peach.base
        }
    }

    private func routeRow(_ route: PlannedRoute) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "map")
                .foregroundStyle(WidgetTint.peach.base)
            Text(route.title)
                .font(TimeMasterFont.rowTitle())
                .lineLimit(1)
            Spacer()
            Text("\(route.points.count) pts")
                .font(WidgetFont.chip())
                .foregroundStyle(WidgetTint.graphite.secondaryInk)
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

struct HomeActivityShortcutCircle: View {
    let shortcut: HomeActivityShortcut
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        let style = Self.style(for: shortcut)
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: shortcut.systemImage)
                    .font(.system(size: min(30, diameter * 0.3), weight: .semibold))
                Text(shortcut.title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(style.ink)
            .frame(width: diameter, height: diameter)
            .background {
                ZStack {
                    Circle().fill(style.fill)
                    Circle().fill(
                        LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)], startPoint: .topLeading, endPoint: .center)
                    )
                }
            }
            .contentShape(Circle())
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .accessibilityLabel(shortcut.title)
        .accessibilityHint("Start \(shortcut.title)")
    }

    private static func style(for shortcut: HomeActivityShortcut) -> (fill: Color, ink: Color) {
        switch shortcut {
        case .workout: (WidgetTint.orange.base, WidgetTint.orange.ink)
        case .runWalk: (WidgetTint.peach.base, WidgetTint.peach.ink)
        case .walk: (Color.white, WidgetTint.peach.ink)
        case .bike: (WidgetTint.graphite.softFill, WidgetTint.graphite.ink)
        }
    }
}
