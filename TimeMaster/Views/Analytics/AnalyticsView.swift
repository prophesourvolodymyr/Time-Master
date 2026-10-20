import SwiftUI
import TimeMasterCore

// MARK: - GoalsManager

final class GoalsManager: ObservableObject {
    static let shared = GoalsManager()
    private let key = "workout_goals_by_type_v2"
    @Published private(set) var goals: [String: Int] = [:]

    private init() { load() }

    func goal(for type: WorkoutType) -> Int { goals[type.name] ?? 0 }

    func setGoal(_ n: Int, for type: WorkoutType) {
        goals[type.name] = n
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return }
        goals = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var outdoorStore: OutdoorActivityStore
    @StateObject private var goalsManager = GoalsManager.shared
    @Binding var requestedTracker: AnalyticsTracker?
    @State private var selectedType: WorkoutType? = nil
    @State private var showingClearAlert = false

    init(requestedTracker: Binding<AnalyticsTracker?> = .constant(nil)) {
        _requestedTracker = requestedTracker
    }

    private var filteredEntries: [WorkoutHistoryEntry] {
        guard let type = selectedType else { return store.historyEntries }
        return store.historyEntries.filter { $0.workoutType == type }
    }

    private var currentGoal: Int {
        guard let type = selectedType else { return 0 }
        return goalsManager.goal(for: type)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    typePicker
                    analyticsScroll
                }
            }
            .navigationTitle("Analytics")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                if !store.historyEntries.isEmpty {
                    AppToolbar.iconItem(placement: .primaryAction) {
                        clearHistoryButton.oneHandedActionSource()
                    }
                }
            }
            .oneHandedActions(id: "analytics", actions: analyticsActions)
            .alert("Clear History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { store.clearHistory() }
            } message: { Text("This will delete all workout history.") }
        }
    }

    private var analyticsActions: [ReachabilityAction] {
        var actions = [
            ReachabilityAction("filter", title: "Workout Type", dismissesOnActivation: false) {
                Menu {
                    Button("All", systemImage: "square.grid.2x2") {
                        selectType(nil)
                    }
                    ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                        Button(type.name, systemImage: type.icon) {
                            selectType(type)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.white)
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .accessibilityLabel("Filter by workout type")
            }
        ]
        if !store.historyEntries.isEmpty {
            actions.append(ReachabilityAction("clear-history", title: "Clear History") {
                clearHistoryButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
            })
        }
        return actions
    }

    private var clearHistoryButton: some View {
        Button { showingClearAlert = true } label: {
            Image(systemName: "trash")
                .foregroundColor(Color.white.opacity(0.45))
        }
        .accessibilityLabel("Clear History")
    }

    private func selectType(_ type: WorkoutType?) {
        selectedType = type
    }

    // MARK: Type picker

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(label: "All", icon: "square.grid.2x2", selected: selectedType == nil) {
                    selectType(nil)
                }
                ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                    typeChip(
                        label: type.name,
                        icon: type.icon,
                        selected: selectedType == type
                    ) {
                        selectType(type)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func typeChip(
        label: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("analytics.filter.\(label)")
    }

    // MARK: Scroll content

    private var analyticsScroll: some View {
        let week = WorkoutWeekSummary(entries: filteredEntries)
        return ScrollViewReader { scroll in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    WeeklyWorkoutTracker(metric: .sessions, summary: week)
                        .id(AnalyticsTracker.sessions)
                    WeeklyWorkoutTracker(metric: .trainingTime, summary: week)
                        .id(AnalyticsTracker.trainingTime)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(AnalyticsTracker.streak.title)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("analytics.tracker.streak")
                        StreakCard()
                    }
                    .id(AnalyticsTracker.streak)
                    if let type = selectedType, currentGoal == 0 {
                        inlineGoalSetter(for: type)
                    }
                    if let type = selectedType, currentGoal > 0 {
                        WeeklyGoalCard(
                            entries: filteredEntries,
                            goal: currentGoal,
                            typeName: type.name
                        )
                    }
                    LifetimeStatsStrip(entries: filteredEntries)
                    if selectedType == nil, !outdoorStore.establishedActivities.isEmpty {
                        OutdoorAnalyticsSummary(activities: outdoorStore.establishedActivities)
                    }
                    if selectedType == nil {
                        TypeAnalyticsBreakdown()
                    }
                    ActivityHeatmap(entries: filteredEntries, outdoorActivities: outdoorStore.establishedActivities)
                    HistoryListSection(entries: filteredEntries, store: store)
                }
                .padding(16)
            }
            .task(id: requestedTracker) {
                guard let tracker = requestedTracker else { return }
                selectedType = nil
                await Task.yield()
                guard !Task.isCancelled else { return }
                scroll.scrollTo(tracker, anchor: .top)
                requestedTracker = nil
            }
        }
    }

    private func inlineGoalSetter(for type: WorkoutType) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(type.colorHex == "FFFFFF" ? .black : .white)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: type.colorHex))
                    .cornerRadius(8)
                Text("Set your weekly goal for \(type.name)")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { n in
                    Button {
                        goalsManager.setGoal(n, for: type)
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Theme.surface)
                            .cornerRadius(8)
                    }
                }
            }
            Text("You can also set goals in Settings → Workout Types.")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
}

private struct OutdoorAnalyticsSummary: View {
    let activities: [OutdoorActivity]

    var body: some View {
        HStack(spacing: 0) {
            cell(icon: "figure.run", value: "\(activities.filter { $0.kind == .run }.count)", label: "Run")
            Divider().frame(height: 42)
            cell(icon: "figure.walk", value: "\(activities.filter { $0.kind == .walk }.count)", label: "Walk")
            Divider().frame(height: 42)
            cell(icon: "bicycle", value: "\(activities.filter { $0.kind == .bike }.count)", label: "Bike")
            Divider().frame(height: 42)
            cell(icon: "point.topleft.down.curvedto.point.bottomright.up", value: String(format: "%.1f km", activities.reduce(0) { $0 + $1.distanceMeters } / 1000), label: "Distance")
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func cell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(.cyan)
            Text(value).font(.headline.monospacedDigit()).foregroundColor(Theme.textPrimary)
            Text(label).font(.caption2).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - WeeklyGoalCard

private struct WeeklyGoalCard: View {
    let entries: [WorkoutHistoryEntry]
    let goal: Int
    let typeName: String

    private var sessionsThisWeek: Int {
        entries.filter { $0.completedAt >= Self.mondayOfThisWeek }.count
    }

    private var progress: Double {
        min(Double(sessionsThisWeek) / Double(max(goal, 1)), 1.0)
    }

    private var daysElapsedThisWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1  // 1=Mon … 7=Sun
    }

    private var statusInfo: (text: String, color: Color) {
        if sessionsThisWeek >= goal { return ("Goal Met!", .green) }
        let needed = Int(floor(Double(goal) * Double(daysElapsedThisWeek) / 7.0))
        return sessionsThisWeek >= needed
            ? ("On Track", .orange)
            : ("Behind", .red)
    }

    private static var mondayOfThisWeek: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMon, to: today) ?? today
    }

    var body: some View {
        VStack(spacing: 20) {
            ringView
            Text(statusInfo.text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(statusInfo.color)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 160, height: 160)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(statusInfo.color,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Text("\(sessionsThisWeek)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("of \(goal) this week")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// MARK: - LifetimeStatsStrip

private struct LifetimeStatsStrip: View {
    let entries: [WorkoutHistoryEntry]

    private var totalSessions: Int { entries.count }
    private var totalMinutes: Int { entries.reduce(0) { $0 + $1.durationCompleted } / 60 }

    var body: some View {
        HStack(spacing: 0) {
            statCell(icon: "checkmark.circle", value: "\(totalSessions)", label: "Total Sessions")
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 44)
            statCell(icon: "clock", value: "\(totalMinutes)m", label: "Total Minutes")
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(Color.white.opacity(0.7))
            Text(value).font(.title2.bold()).foregroundColor(Theme.textPrimary)
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - StreakCard

private struct StreakCard: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var flamePulse = false

    private var streak: (current: Int, best: Int) {
        store.streakInfo()
    }

    var body: some View {
        HStack(spacing: 0) {
            streakItem(value: streak.current, label: "Current Streak", isFlame: true)
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 50)
            streakItem(value: streak.best, label: "Best Streak", isFlame: false)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }

    private func streakItem(value: Int, label: String, isFlame: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if isFlame {
                    Image(systemName: value == 0 ? "flame" : "flame.fill")
                        .font(.system(size: value >= 7 ? 25 : 20, weight: .bold))
                        .foregroundStyle(value == 0 ? AnyShapeStyle(Theme.textSecondary) : AnyShapeStyle(LinearGradient(colors: [.red, .orange, .yellow], startPoint: .bottom, endPoint: .top)))
                        .scaleEffect(flamePulse && value > 0 ? 1.14 : 0.94)
                }
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(isFlame && value > 0 ? AnyShapeStyle(LinearGradient(colors: [.red, .orange, .yellow], startPoint: .bottom, endPoint: .top)) : AnyShapeStyle(Theme.textPrimary))
                Text(value == 1 ? "day" : "days")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TypeAnalyticsBreakdown: View {
    @EnvironmentObject private var store: WorkoutStore
    @StateObject private var goals = GoalsManager.shared

    private var types: [WorkoutType] {
        WorkoutType.all(custom: store.customWorkoutTypes).filter { type in
            store.historyEntries.contains { $0.workoutType.id == type.id } ||
            store.typeSchedules.contains { $0.type.id == type.id && $0.isActive }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Workout Type")
                .font(.headline).foregroundColor(Theme.textPrimary)
            if types.isEmpty {
                Text("Complete a workout or set a type schedule to see a breakdown.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
            } else {
                ForEach(types, id: \.id) { type in
                    row(for: type)
                }
            }
        }
        .padding(16).background(Theme.surface).cornerRadius(16)
    }

    private func row(for type: WorkoutType) -> some View {
        let stats = store.typeStats(for: type)
        let goal = goals.goal(for: type)
        let progress = goal > 0 ? min(Double(stats.sessionsThisWeek) / Double(goal), 1) : 0
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: type.colorHex)).cornerRadius(9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.name).font(.subheadline.weight(.semibold)).foregroundColor(Theme.textPrimary)
                    Text("\(stats.sessionsThisWeek) this week · \(stats.totalSeconds / 60)m total · \(stats.streak)d streak")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if let adherence = stats.adherence {
                    Text("\(Int((adherence * 100).rounded()))%")
                        .font(.caption.weight(.bold)).foregroundColor(Color(hex: type.colorHex))
                }
            }
            if goal > 0 {
                ProgressView(value: progress)
                    .tint(Color(hex: type.colorHex))
                Text("\(stats.sessionsThisWeek) of \(goal) weekly goal")
                    .font(.caption2).foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10).background(Theme.background.opacity(0.6)).cornerRadius(12)
    }
}

// MARK: - Training Schedule Card

private struct TrainingScheduleCard: View {
    @EnvironmentObject var store: WorkoutStore

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Schedule")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(store.trainingDurationMonths) mo")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { idx, label in
                    let day = idx + 1
                    let isActive = store.trainingDays.contains(day)
                    Button {
                        if isActive { store.trainingDays.remove(day) }
                        else { store.trainingDays.insert(day) }
                        store.saveTrainingSchedule()
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: isActive ? .bold : .medium))
                            .foregroundColor(isActive ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isActive ? Color.white : Theme.surface)
                            .cornerRadius(8)
                    }
                }
            }

            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Stepper(value: $store.trainingDurationMonths, in: 1...12) {
                    Text("\(store.trainingDurationMonths) month\(store.trainingDurationMonths == 1 ? "" : "s")")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                }
                .onChange(of: store.trainingDurationMonths) { _ in store.saveTrainingSchedule() }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
}

// MARK: - ActivityHeatmap

struct ActivityHeatmap: View {
    @EnvironmentObject var store: WorkoutStore
    let entries: [WorkoutHistoryEntry]
    let outdoorActivities: [OutdoorActivity]
    var onSelectDate: ((Date) -> Void)?
    @State private var showCalendar = false

    private let weeksCount = 24
    private let gap: CGFloat = 3
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    @State private var cellSize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var monthLabelHeight = 16.0

    private var columns: [GridItem] {
        Array(repeating: GridItem(onSelectDate == nil ? .flexible() : .fixed(44), spacing: gap), count: weeksCount)
    }

    var body: some View {
        Group {
            if onSelectDate != nil {
                card
            } else {
                Button { showCalendar = true } label: { card }
                    .buttonStyle(TimeMasterCardButtonStyle())
            }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarPage(entries: entries, outdoorActivities: outdoorActivities)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(onSelectDate == nil ? "Activity" : "Last 24 weeks")
                    .font(onSelectDate == nil ? .headline : .subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if onSelectDate == nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(alignment: .top, spacing: gap + 2) {
                dayLabelColumn
                    .padding(.top, onSelectDate == nil ? 0 : monthLabelHeight + 8)
                if onSelectDate != nil {
                    ScrollViewReader { scroll in
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: gap) {
                                    ForEach(0..<weeksCount, id: \.self) { week in
                                        let date = dateFor(week: week, day: 0)
                                        let startsMonth = week == 0 || !Calendar.current.isDate(date, equalTo: dateFor(week: week - 1, day: 0), toGranularity: .month)
                                        Text(startsMonth ? date.formatted(.dateTime.month(.abbreviated)) : "")
                                            .font(.caption2)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, height: monthLabelHeight)
                                    }
                                }
                                heatmapGrid
                            }
                        }
                            .onAppear { scroll.scrollTo(7 * weeksCount - 1, anchor: .trailing) }
                    }
                } else {
                    heatmapGrid
                }
            }
        }
        .padding(16)
        .modifier(TimeMasterCardSurface())
    }

    private var dayLabelColumn: some View {
        VStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 12, height: onSelectDate == nil ? cellSize : 44, alignment: .center)
            }
        }
    }

    private var heatmapGrid: some View {
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<(7 * weeksCount), id: \.self) { idx in
                let w = idx % weeksCount
                let d = idx / weeksCount
                let date = dateFor(week: w, day: d)
                let isFuture = date > Date()
                let isRest = store.isRestDay(date)
                let isScheduled = store.isScheduledDay(date)
                let count = isFuture ? 0 : workoutCount(on: date) + outdoorCount(on: date)
                let hasActivity = count > 0

                Group {
                    if let onSelectDate {
                        Button { onSelectDate(date) } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(cellBackground(isFuture: isFuture, isRest: isRest, hasWorkout: hasActivity, count: count, isScheduled: isScheduled))
                                .overlay {
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.caption2.monospacedDigit())
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .disabled(isFuture)
                        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(count) workouts")
                        .accessibilityIdentifier("activity.day.\(WeeklyWorkoutSchedule.dayKey(date))")
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(cellBackground(isFuture: isFuture, isRest: isRest, hasWorkout: hasActivity, count: count, isScheduled: isScheduled))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .id(idx)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { updateCellSize(gridWidth: geo.size.width) }
                    .onChange(of: geo.size.width) { updateCellSize(gridWidth: $0) }
            }
        )
    }

    private func updateCellSize(gridWidth: CGFloat) {
        let computed = (gridWidth - CGFloat(weeksCount - 1) * gap) / CGFloat(weeksCount)
        cellSize = max(computed, 1)
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMon, to: today) ?? today
        let targetMonday = cal.date(byAdding: .weekOfYear, value: -(weeksCount - 1 - week), to: thisMonday) ?? today
        return cal.date(byAdding: .day, value: day, to: targetMonday) ?? today
    }

    private func workoutCount(on date: Date) -> Int {
        store.scheduleActivityCount(on: date)
    }

    private func outdoorCount(on date: Date) -> Int {
        outdoorActivities.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }.count
    }

    private func cellBackground(isFuture: Bool, isRest: Bool, hasWorkout: Bool, count: Int, isScheduled: Bool) -> Color {
        if isFuture { return Color.white.opacity(0.03) }
        if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
        if hasWorkout {
            switch count {
            case 1: return Color(red: 0.1, green: 0.7, blue: 0.35)
            case 2: return Color(red: 0.1, green: 0.6, blue: 0.25)
            default: return Color(red: 0.05, green: 0.45, blue: 0.15)
            }
        }
        if isScheduled { return Color.red.opacity(0.4) }
        return Color.white.opacity(0.06)
    }
}

private struct CalendarDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct CalendarActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore
    let entries: [WorkoutHistoryEntry]
    let outdoorActivities: [OutdoorActivity]
    @State private var selectedDay: CalendarDaySelection?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ActivityHeatmap(entries: entries, outdoorActivities: outdoorActivities) {
                        selectedDay = CalendarDaySelection(date: $0)
                    }
                    if !outdoorActivities.isEmpty {
                        OutdoorAnalyticsSummary(activities: outdoorActivities)
                    }
                    HistoryListSection(entries: entries, store: store)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Activity")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("activity.close")
                }
            }
            .sheet(item: $selectedDay) { selection in
                DayInfoSheet(date: selection.date, entries: entries, outdoorActivities: outdoorActivities)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 480, idealWidth: 640, minHeight: 560, idealHeight: 720)
        #endif
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("calendar.activity.page")
    }
}

// MARK: - Calendar Page

struct CalendarPage: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entries: [WorkoutHistoryEntry]
    let outdoorActivities: [OutdoorActivity]
    let selectedWeek: Date?
    let onSelectWeek: ((Date) -> Void)?

    init(entries: [WorkoutHistoryEntry], outdoorActivities: [OutdoorActivity], selectedWeek: Date? = nil, onSelectWeek: ((Date) -> Void)? = nil) {
        self.entries = entries
        self.outdoorActivities = outdoorActivities
        self.selectedWeek = selectedWeek
        self.onSelectWeek = onSelectWeek
        _currentMonth = State(initialValue: selectedWeek ?? Date())
        _showYearView = State(initialValue: selectedWeek == nil)
    }

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: CalendarDaySelection?
    @State private var showActivity = false
    @State private var showYearView = true
    @State private var showVacationSheet = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var currentYear: Int {
        calendar.component(.year, from: currentMonth)
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in 1...range.count {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: first)!)
        }
        return days
    }

    private var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                    .padding(20)
                ScrollView {
                    VStack(spacing: 20) {
                        periodNavigation
                        if showYearView {
                            yearOverview
                        } else {
                            monthDetail
                        }
                        legendRow
                    }
                    .padding(20)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $showActivity) {
                CalendarActivitySheet(entries: entries, outdoorActivities: outdoorActivities)
            }
            .sheet(isPresented: $showVacationSheet) {
                VacationSheet()
            }
            .sheet(item: $selectedDay) { selection in
                DayInfoSheet(date: selection.date, entries: entries, outdoorActivities: outdoorActivities)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 480, idealWidth: 640, minHeight: 560, idealHeight: 720)
        #endif
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("calendar.page")
    }

    private var calendarHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Text("Calendar").font(.title2.bold()).fixedSize()
                Spacer(minLength: 0)
                calendarControls
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("Calendar").font(.title2.bold())
                calendarControls
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calendarControls: some View {
        HStack(spacing: 12) {
            Button { showActivity = true } label: {
                Label("Activity", systemImage: "chart.bar.xaxis").labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("calendar.activity")
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    showYearView.toggle()
                }
            } label: {
                Label(showYearView ? "Show month" : "Show year",
                      systemImage: showYearView ? "calendar" : "square.grid.2x2").labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("calendar.mode")
            if onSelectWeek == nil {
                Button { showVacationSheet = true } label: {
                    Label("Vacation", systemImage: "moon.zzz.fill").labelStyle(.iconOnly)
                }
            }
            Button { dismiss() } label: {
                Label("Close calendar", systemImage: "xmark").labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("calendar.close")
        }
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .font(.system(size: 17, weight: .semibold))
    }

    private var periodNavigation: some View {
        HStack(spacing: 12) {
            Button { movePeriod(-1) } label: {
                Label(showYearView ? "Previous year" : "Previous month", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .accessibilityIdentifier("calendar.previous")
            Text(showYearView ? String(currentYear) : monthTitle)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("calendar.period")
            Button { movePeriod(1) } label: {
                Label(showYearView ? "Next year" : "Next month", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .accessibilityIdentifier("calendar.next")
        }
        .font(.system(size: 17, weight: .semibold))
    }

    private func movePeriod(_ offset: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            currentMonth = calendar.date(byAdding: showYearView ? .year : .month,
                                        value: offset, to: currentMonth) ?? currentMonth
        }
    }

    // MARK: - Year overview (12-month mini grids)

    private var yearOverview: some View {
        LazyVStack(spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                monthRow(month: month)
            }
        }
    }

    private func monthRow(month: Int) -> some View {
        let date = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1))!
        let monthName: String = {
            let f = DateFormatter()
            f.dateFormat = "MMMM"
            return f.string(from: date)
        }()

        let workoutDays = workoutDaysInMonth(month: month, year: currentYear)
        let restDaysCount = restDaysInMonth(month: month, year: currentYear)
        let missCount = missedDaysInMonth(month: month, year: currentYear)

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                currentMonth = date
                showYearView = false
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 8) {
                        if workoutDays > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 0.1, green: 0.6, blue: 0.25)).frame(width: 6, height: 6)
                                Text("\(workoutDays)").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        if restDaysCount > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 0.3, green: 0.55, blue: 0.85)).frame(width: 6, height: 6)
                                Text("\(restDaysCount)").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        if missCount > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("\(missCount)").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                Spacer()
                miniMonthGrid(month: month)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.4))
            }
            .padding(16)
            .modifier(TimeMasterCardSurface())
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel("\(monthName), \(workoutDays) workout days, \(restDaysCount) rest days, \(missCount) missed days")
        .accessibilityIdentifier("calendar.month.\(month)")
    }

    private func miniMonthGrid(month: Int) -> some View {
        guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: currentYear, month: month, day: 1))!),
              let first = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1))
        else { return AnyView(Color.clear.frame(width: 70, height: 10)) }

        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        let totalSlots = offset + range.count
        let rows = (totalSlots + 6) / 7

        return AnyView(
            VStack(spacing: 1) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col - offset
                            if idx >= 0, idx < range.count,
                               let dayDate = calendar.date(byAdding: .day, value: idx, to: first) {
                                let isFuture = dayDate > Date()
                                let isRest = store.isRestDay(dayDate)
                                let isScheduled = store.isScheduledDay(dayDate)
                                let hasWorkout = workoutCount(on: dayDate) > 0
                                let fill: Color = {
                                    if isFuture { return Color.white.opacity(0.04) }
                                    if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.6) }
                                    if hasWorkout { return Color(red: 0.1, green: 0.6, blue: 0.25) }
                                    if isScheduled { return Color.red.opacity(0.35) }
                                    return Color.white.opacity(0.06)
                                }()
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(fill)
                                    .frame(width: 7, height: 7)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 1)
                                            .stroke(isHighlighted(dayDate) ? Theme.toolbarOrange : .clear, lineWidth: 1)
                                    }
                            } else {
                                Color.clear.frame(width: 7, height: 7)
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: - Month detail view

    private var monthDetail: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(day + 1) % 7])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(minHeight: 52)
                        }
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(12)
            .modifier(TimeMasterCardSurface())

            let workoutDays = workoutDaysInMonth(month: calendar.component(.month, from: currentMonth), year: currentYear)
            if workoutDays > 0 {
                Label("\(workoutDays) workout day\(workoutDays == 1 ? "" : "s")", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isFuture = date > Date()
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isRest = store.isRestDay(date)
        let hasWorkout = workoutCount(on: date) > 0
        let count = workoutCount(on: date)

        let isScheduled = store.isScheduledDay(date)
        let bg: Color = {
            if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
            if hasWorkout {
                switch count {
                case 1: return Color(red: 0.1, green: 0.7, blue: 0.35)
                case 2: return Color(red: 0.1, green: 0.6, blue: 0.25)
                default: return Color(red: 0.05, green: 0.45, blue: 0.15)
                }
            }
            if !isFuture && isScheduled { return Color.red.opacity(0.35) }
            if !isFuture { return Color.clear }
            return Color.clear
        }()

        return Button {
            if let onSelectWeek {
                onSelectWeek(date)
                dismiss()
            } else if !isFuture {
                selectedDay = CalendarDaySelection(date: date)
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isFuture && onSelectWeek == nil ? Theme.textSecondary : .white)
                Text(count > 0 ? "\(count)" : " ")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(bg.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .background(isHighlighted(date) ? Theme.toolbarOrange.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isHighlighted(date) ? Theme.toolbarOrange : isToday ? .white.opacity(0.8) : .clear,
                                  lineWidth: isHighlighted(date) ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .disabled(isFuture && onSelectWeek == nil)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(count) workouts\(isHighlighted(date) ? ", selected week" : "")")
        .accessibilityHint(onSelectWeek == nil ? "Open day details" : "Open this week in Schedule")
        .accessibilityIdentifier("calendar.day.\(WeeklyWorkoutSchedule.dayKey(date))")
    }

    private func isHighlighted(_ date: Date) -> Bool {
        guard let selectedWeek, let end = calendar.date(byAdding: .day, value: 7, to: selectedWeek) else { return false }
        return date >= selectedWeek && date < end
    }

    // MARK: - Legend

    private var legendRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 18))
        return layout {
            legendItem(color: Color(red: 0.1, green: 0.6, blue: 0.25), label: "Workout")
            legendItem(color: Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5), label: "Rest day")
            legendItem(color: Color.red.opacity(0.35), label: "Missed")
        }
        .font(.caption)
        .foregroundColor(Theme.textSecondary)
        .padding(.bottom, 8)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: - Stats helpers

    private func workoutCount(on date: Date) -> Int {
        store.scheduleActivityCount(on: date)
            + outdoorActivities.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.count
    }

    private func workoutDaysInMonth(month: Int, year: Int) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!),
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else { return 0 }
        var count = 0
        for d in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first),
               workoutCount(on: date) > 0 {
                count += 1
            }
        }
        return count
    }

    private func restDaysInMonth(month: Int, year: Int) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!),
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else { return 0 }
        var count = 0
        for d in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first),
               store.isRestDay(date) {
                count += 1
            }
        }
        return count
    }

    private func missedDaysInMonth(month: Int, year: Int) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!),
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else { return 0 }
        var count = 0
        for d in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first),
               date <= Date(),
               !store.isRestDay(date),
               workoutCount(on: date) == 0,
               store.isScheduledDay(date) {
                count += 1
            }
        }
        return count
    }
}

// MARK: - Day Info Sheet

private struct DayInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let date: Date
    let entries: [WorkoutHistoryEntry]
    let outdoorActivities: [OutdoorActivity]

    private var dayOutdoorActivities: [OutdoorActivity] {
        outdoorActivities.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
    }

    private var dayEntries: [WorkoutHistoryEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return entries.filter { $0.completedAt >= start && $0.completedAt < end }
    }

    private var manualEntries: [WeeklyWorkoutSchedule.Occurrence] {
        store.scheduleOccurrences(on: date).filter { $0.isComplete && $0.matchedSessionID == nil }
    }

    private var totalMinutes: Int {
        (dayEntries.reduce(0) { $0 + ($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) }
            + manualEntries.reduce(0) { $0 + ($1.entry.durationSeconds ?? 0) }
            + dayOutdoorActivities.reduce(0) { $0 + $1.elapsedSeconds }) / 60
    }

    private var isRest: Bool { store.isRestDay(date) }
    private var isScheduled: Bool { store.isScheduledDay(date) }
    private var scheduledTypes: [WorkoutType] { store.scheduledTypes(for: date) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Text(formatFullDate(date))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        let statsLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 16))
                            : AnyLayout(HStackLayout(spacing: 24))
                        statsLayout {
                            statChip(value: "\(dayEntries.count + manualEntries.count + dayOutdoorActivities.count)", label: "workouts")
                            statChip(value: "\(totalMinutes)m", label: "total time")
                        }
                        VStack(spacing: 8) {
                            if isRest {
                                Label("Rest day", systemImage: "moon.zzz.fill")
                                    .foregroundStyle(.blue)
                            }
                            ForEach(scheduledTypes, id: \.self) { type in
                                Label(type.name, systemImage: type.icon)
                            }
                            if !isRest && isScheduled && dayEntries.isEmpty && manualEntries.isEmpty && dayOutdoorActivities.isEmpty {
                                Label("Missed", systemImage: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .modifier(TimeMasterCardSurface())

                    if dayEntries.isEmpty && manualEntries.isEmpty && dayOutdoorActivities.isEmpty {
                        Label(isRest ? "Rest day" : "No workout logged",
                              systemImage: isRest ? "moon.zzz" : "figure.walk")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(dayEntries) { entry in
                                HistoryRow(entry: entry)
                                    .padding(16)
                                    .modifier(TimeMasterCardSurface())
                            }
                            ForEach(manualEntries) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(item.entry.title, systemImage: item.entry.icon)
                                        .font(.headline)
                                    Text(item.entry.workoutID == nil ? "Custom workout" : "Completed manually")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let seconds = item.entry.durationSeconds {
                                        Text("\(seconds / 60) min").font(.caption.monospacedDigit())
                                    }
                                    if !item.entry.notes.isEmpty {
                                        Text(item.entry.notes).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .modifier(TimeMasterCardSurface())
                            }
                            ForEach(dayOutdoorActivities) { activity in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(activity.title, systemImage: activity.kind.iconName)
                                        .font(.headline)
                                    Text("\(activity.elapsedSeconds / 60) min")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(Measurement(value: activity.distanceMeters, unit: UnitLength.meters)
                                        .formatted(.measurement(width: .abbreviated, usage: .road)))
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .modifier(TimeMasterCardSurface())
                            }
                        }
                    }
                    Button { store.toggleRestDay(for: date) } label: {
                        Label(isRest ? "Remove rest day" : "Mark as rest day",
                              systemImage: isRest ? "moon.zzz.fill" : "moon.zzz")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Day details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("activity.day.close")
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #else
        .frame(minWidth: 480, idealWidth: 640, minHeight: 560, idealHeight: 720)
        #endif
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("activity.day.page")
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundColor(Theme.textPrimary)
            Text(label).font(.caption2).foregroundColor(Theme.textSecondary)
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }
}

// MARK: - Vacation Sheet

private struct VacationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore

    @State private var startMonth: Date = Date()
    @State private var endMonth: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedTypes: Set<WorkoutType> = []

    private let calendar = Calendar.current

    private var monthsInRange: Int {
        let diff = calendar.dateComponents([.month], from: startOfMonth(startMonth), to: startOfMonth(endMonth))
        return max(1, (diff.month ?? 0) + 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Duration").font(.headline).foregroundColor(Theme.textPrimary)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("From").font(.caption).foregroundColor(Theme.textSecondary)
                                    DatePicker("", selection: $startMonth, displayedComponents: .date)
                                        .labelsHidden().colorScheme(.dark)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("To").font(.caption).foregroundColor(Theme.textSecondary)
                                    DatePicker("", selection: $endMonth, displayedComponents: .date)
                                        .labelsHidden().colorScheme(.dark)
                                }
                            }
                            .padding(14).background(Theme.surface).cornerRadius(10)

                            Text("\(monthsInRange) month\(monthsInRange == 1 ? "" : "s") selected")
                                .font(.caption).foregroundColor(Theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Workout Types").font(.headline).foregroundColor(Theme.textPrimary)
                            Text("Select which types to pause during vacation.").font(.caption).foregroundColor(Theme.textSecondary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                                    Button {
                                        if selectedTypes.contains(type) { selectedTypes.remove(type) }
                                        else { selectedTypes.insert(type) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: type.icon).font(.system(size: 11))
                                            Text(type.name)
                                        }
                                        .font(.subheadline.weight(selectedTypes.contains(type) ? .semibold : .regular))
                                        .foregroundColor(selectedTypes.contains(type) ? .black : .white)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedTypes.contains(type) ? Color.white : Theme.surface)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Set Vacation")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white)
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Set Vacation") { applyVacation() }
                    .foregroundColor(.white)
                                 }
            }
        }
    }

    private func applyVacation() {
        let start = startOfMonth(startMonth)
        let end = endOfMonth(endMonth)
        var current = start
        let cal = Calendar.current
        while current <= end {
            store.restDays.insert(store.dateKey(from: current))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        store.saveRestDays()
        dismiss()
    }

    private func endOfMonth(_ date: Date) -> Date {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(date)),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth)
        else { return date }
        return lastDay
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

// MARK: - HistoryListSection

private struct HistoryListSection: View {
    let entries: [WorkoutHistoryEntry]
    @ObservedObject var store: WorkoutStore

    private var sorted: [WorkoutHistoryEntry] {
        entries.sorted { $0.completedAt > $1.completedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                if !entries.isEmpty {
                    let n = entries.count
                    Text("\(n) session\(n == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            if entries.isEmpty {
                Text("No sessions recorded yet.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, entry in
                        HistoryRow(entry: entry)
                        if idx < sorted.count - 1 {
                            Divider()
                                .background(Theme.separator)
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
        .environmentObject(OutdoorActivityStore())
}
