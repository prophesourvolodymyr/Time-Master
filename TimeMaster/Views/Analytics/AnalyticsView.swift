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

final class ValueMemo<Key: Equatable, Value>: ObservableObject {
    private var stored: (key: Key, value: Value)?

    func value(for key: Key, make: () -> Value) -> Value {
        if let known = stored, known.key == key { return known.value }
        let made = make()
        stored = (key, made)
        return made
    }
}

final class CachedDateFormatter {
    private let configure: (DateFormatter) -> Void
    private var formatter: DateFormatter?
    private var locale: Locale?
    private var timeZone: TimeZone?
    private var calendar: Calendar?

    init(_ configure: @escaping (DateFormatter) -> Void) {
        self.configure = configure
    }

    func string(from date: Date) -> String {
        let locale = Locale.current
        let timeZone = TimeZone.current
        let calendar = Calendar.current
        if let known = formatter, self.locale == locale, self.timeZone == timeZone, self.calendar == calendar {
            return known.string(from: date)
        }
        let made = DateFormatter()
        configure(made)
        formatter = made
        self.locale = locale
        self.timeZone = timeZone
        self.calendar = calendar
        return made.string(from: date)
    }
}

private struct HistoryRevisionKey: Equatable {
    let store: ObjectIdentifier
    let revision: Int
}

private struct FilteredEntriesKey: Equatable {
    let store: ObjectIdentifier
    let revision: Int
    let type: WorkoutType
}

private enum OutdoorDayCounts {
    private struct Key: Equatable {
        let calendar: Calendar
        let starts: [TimeInterval]
    }

    private final class Memo {
        var key: Key?
        var counts: [Date: Int] = [:]
    }

    private static let memo = Memo()

    static func counts(for activities: [OutdoorActivity], calendar: Calendar) -> [Date: Int] {
        guard !activities.isEmpty else { return [:] }
        let key = Key(calendar: calendar, starts: activities.map { $0.startedAt.timeIntervalSinceReferenceDate })
        if memo.key == key { return memo.counts }
        var counts: [Date: Int] = [:]
        for activity in activities {
            counts[calendar.startOfDay(for: activity.startedAt), default: 0] += 1
        }
        memo.key = key
        memo.counts = counts
        return counts
    }
}

private final class ActivityDayFacts {
    private let store: WorkoutStore
    private let outdoor: [Date: Int]
    private var counts: [Date: Int] = [:]
    private var rests: [Date: Bool] = [:]
    private var schedules: [Date: Bool] = [:]

    init(store: WorkoutStore, outdoor: [Date: Int]) {
        self.store = store
        self.outdoor = outdoor
    }

    func count(on day: Date) -> Int {
        if let known = counts[day] { return known }
        let value = store.scheduleActivityCount(on: day) + (outdoor[day] ?? 0)
        counts[day] = value
        return value
    }

    func isRest(on day: Date) -> Bool {
        if let known = rests[day] { return known }
        let value = store.isRestDay(day)
        rests[day] = value
        return value
    }

    func isScheduled(on day: Date) -> Bool {
        if let known = schedules[day] { return known }
        let value = store.isScheduledDay(day)
        schedules[day] = value
        return value
    }
}

private final class HeatmapWindow {
    private struct Key: Equatable {
        let today: Date
        let calendar: Calendar
        let locale: Locale
        let weeks: Int
    }

    private final class Memo {
        var key: Key?
        var window: HeatmapWindow?
    }

    private static let memo = Memo()

    let calendar: Calendar
    let weeks: Int
    let days: [Date]

    lazy var dayNumbers: [String] = days.map { $0.formatted(.dateTime.day()) }
    lazy var spokenDates: [String] = days.map { $0.formatted(date: .complete, time: .omitted) }
    lazy var dayKeys: [String] = days.map { WeeklyWorkoutSchedule.dayKey($0, calendar: calendar) }
    lazy var monthLabels: [String] = (0..<weeks).map { (week: Int) -> String in
        let date = days[week]
        let startsMonth = week == 0 || !calendar.isDate(date, equalTo: days[week - 1], toGranularity: .month)
        return startsMonth ? date.formatted(.dateTime.month(.abbreviated)) : ""
    }

    private init(today: Date, calendar: Calendar, weeks: Int) {
        self.calendar = calendar
        self.weeks = weeks
        let weekday = calendar.component(.weekday, from: today)
        let thisMonday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let mondays = (0..<weeks).map { week in
            calendar.date(byAdding: .weekOfYear, value: -(weeks - 1 - week), to: thisMonday) ?? today
        }
        var days: [Date] = []
        days.reserveCapacity(7 * weeks)
        for day in 0..<7 {
            for monday in mondays {
                let date = calendar.date(byAdding: .day, value: day, to: monday) ?? today
                days.append(calendar.startOfDay(for: date))
            }
        }
        self.days = days
    }

    static func current(weeks: Int, now: Date) -> HeatmapWindow {
        let calendar = Calendar.current
        let key = Key(today: calendar.startOfDay(for: now), calendar: calendar, locale: Locale.current, weeks: weeks)
        if let window = memo.window, memo.key == key { return window }
        let window = HeatmapWindow(today: key.today, calendar: calendar, weeks: weeks)
        memo.key = key
        memo.window = window
        return window
    }
}

private final class MonthWindow {
    private struct Key: Hashable {
        let first: Date
        let calendar: Calendar
        let locale: Locale
    }

    private final class Cache {
        var windows: [Key: MonthWindow] = [:]
    }

    private static let cache = Cache()

    let calendar: Calendar
    let days: [Date]
    let leadingBlanks: Int

    var rows: Int { (leadingBlanks + days.count + 6) / 7 }

    lazy var dayNumbers: [Int] = days.map { calendar.component(.day, from: $0) }
    lazy var spokenDates: [String] = days.map { $0.formatted(date: .complete, time: .omitted) }
    lazy var dayKeys: [String] = days.map { WeeklyWorkoutSchedule.dayKey($0, calendar: calendar) }

    private init(first: Date?, calendar: Calendar) {
        self.calendar = calendar
        guard let first, let range = calendar.range(of: .day, in: .month, for: first) else {
            days = []
            leadingBlanks = 0
            return
        }
        leadingBlanks = (calendar.component(.weekday, from: first) + 5) % 7
        days = (0..<range.count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: first).map { calendar.startOfDay(for: $0) }
        }
    }

    static func window(first: Date?, calendar: Calendar) -> MonthWindow {
        guard let first else { return MonthWindow(first: nil, calendar: calendar) }
        let key = Key(first: first, calendar: calendar, locale: Locale.current)
        if let known = cache.windows[key] { return known }
        if cache.windows.count >= 36 { cache.windows.removeAll() }
        let made = MonthWindow(first: first, calendar: calendar)
        cache.windows[key] = made
        return made
    }
}

private struct MonthSummary {
    var workoutDays = 0
    var restDays = 0
    var missedDays = 0
}

private struct CalendarDayContext {
    let now: Date
    let today: Date
    let facts: ActivityDayFacts
    let highlight: (start: Date, end: Date)?

    func isHighlighted(_ day: Date) -> Bool {
        guard let highlight else { return false }
        return day >= highlight.start && day < highlight.end
    }

    func workoutDays(in window: MonthWindow) -> Int {
        window.days.reduce(0) { facts.count(on: $1) > 0 ? $0 + 1 : $0 }
    }

    func summary(of window: MonthWindow) -> MonthSummary {
        var summary = MonthSummary()
        for day in window.days {
            let count = facts.count(on: day)
            let isRest = facts.isRest(on: day)
            if count > 0 { summary.workoutDays += 1 }
            if isRest { summary.restDays += 1 }
            if day <= now, !isRest, count == 0, facts.isScheduled(on: day) { summary.missedDays += 1 }
        }
        return summary
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
    @StateObject private var entriesMemo = ValueMemo<FilteredEntriesKey, [WorkoutHistoryEntry]>()

    init(requestedTracker: Binding<AnalyticsTracker?> = .constant(nil)) {
        _requestedTracker = requestedTracker
    }

    private var filteredEntries: [WorkoutHistoryEntry] {
        guard let type = selectedType else { return store.historyEntries }
        let key = FilteredEntriesKey(store: ObjectIdentifier(store), revision: store.historyRevision, type: type)
        return entriesMemo.value(for: key) {
            store.historyEntries.filter { $0.workoutType == type }
        }
    }

    private var currentGoal: Int {
        guard let type = selectedType else { return 0 }
        return goalsManager.goal(for: type)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TmaxGlowBackground()
                VStack(spacing: 0) {
                    typePicker
                    analyticsScroll
                }
            }
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("Analytics")
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
                TmaxMenu {
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

    /// All and every workout type as tabs, a `TmaxTabBar` that scrolls sideways when they do not fit.
    private var typePicker: some View {
        let types = WorkoutType.all(custom: store.customWorkoutTypes)
        let all = TmaxTab("", title: "All", symbol: "square.grid.2x2", accessibilityIdentifier: "analytics.filter.All")
        return TmaxTabBar(
            [all] + types.map { TmaxTab($0.id, title: $0.name, symbol: $0.icon, accessibilityIdentifier: "analytics.filter.\($0.name)") },
            selection: selectedType?.id ?? all.id,
            accessibilityLabel: "Workout type"
        ) { id in
            let type = types.first { $0.id == id }
            guard type != selectedType else { return }
            EverHaptic.selection()
            selectType(type)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Scroll content

    private var analyticsScroll: some View {
        let entries = filteredEntries
        let outdoor = outdoorStore.establishedActivities
        let week = WorkoutWeekSummary(entries: entries)
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
                            entries: entries,
                            goal: currentGoal,
                            typeName: type.name
                        )
                    }
                    LifetimeStatsStrip(entries: entries)
                    if selectedType == nil, !outdoor.isEmpty {
                        OutdoorAnalyticsSummary(activities: outdoor)
                    }
                    if selectedType == nil {
                        TypeAnalyticsBreakdown()
                    }
                    ActivityHeatmap(entries: entries, outdoorActivities: outdoor)
                    HistoryListSection(entries: entries)
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
                    .font(TimeMasterFont.secondary())
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { n in
                    Button {
                        goalsManager.setGoal(n, for: type)
                    } label: {
                        Text("\(n)")
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Theme.surface)
                            .cornerRadius(8)
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
                }
            }
            Text("You can also set goals in Settings → Workout Types.")
                .font(TimeMasterFont.micro())
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 16))
    }
}

private struct OutdoorAnalyticsSummary: View {
    let activities: [OutdoorActivity]

    private var totals: (runs: Int, walks: Int, rides: Int, meters: Double) {
        var runs = 0
        var walks = 0
        var rides = 0
        var meters = 0.0
        for activity in activities {
            switch activity.kind {
            case .run: runs += 1
            case .walk: walks += 1
            case .bike: rides += 1
            case .runWalk: break
            }
            meters += activity.distanceMeters
        }
        return (runs, walks, rides, meters)
    }

    var body: some View {
        let totals = self.totals
        HStack(spacing: 0) {
            cell(icon: "figure.run", value: "\(totals.runs)", label: "Run")
            Divider().frame(height: 42)
            cell(icon: "figure.walk", value: "\(totals.walks)", label: "Walk")
            Divider().frame(height: 42)
            cell(icon: "bicycle", value: "\(totals.rides)", label: "Bike")
            Divider().frame(height: 42)
            cell(icon: "point.topleft.down.curvedto.point.bottomright.up", value: String(format: "%.1f km", totals.meters / 1000), label: "Distance")
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func cell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(.cyan)
            Text(value).font(TimeMasterFont.sectionTitle()).monospacedDigit().foregroundColor(Theme.textPrimary)
            Text(label).font(TimeMasterFont.micro()).foregroundColor(Theme.textSecondary)
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
        let monday = Self.mondayOfThisWeek
        return entries.reduce(0) { $1.completedAt >= monday ? $0 + 1 : $0 }
    }

    private func progressFraction(sessions: Int) -> Double {
        min(Double(sessions) / Double(max(goal, 1)), 1.0)
    }

    private var daysElapsedThisWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1  // 1=Mon … 7=Sun
    }

    private func statusInfo(sessions: Int) -> (text: String, color: Color) {
        if sessions >= goal { return ("Goal Met!", .green) }
        let needed = Int(floor(Double(goal) * Double(daysElapsedThisWeek) / 7.0))
        return sessions >= needed
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
        let sessions = sessionsThisWeek
        let info = statusInfo(sessions: sessions)
        VStack(spacing: 20) {
            ringView(sessions: sessions, info: info)
            Text(info.text)
                .font(TimeMasterFont.rowTitle())
                .foregroundColor(info.color)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func ringView(sessions: Int, info: (text: String, color: Color)) -> some View {
        let fraction = progressFraction(sessions: sessions)
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 160, height: 160)
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(info.color,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: fraction)
            VStack(spacing: 2) {
                Text("\(sessions)")
                    .font(TimeMasterFont.black(48, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundColor(Theme.textPrimary)
                Text("of \(goal) this week")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .monospacedDigit()
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
            Text(value).font(TimeMasterFont.black(22, relativeTo: .title2)).monospacedDigit().foregroundColor(Theme.textPrimary)
            Text(label).font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
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
                    .font(TimeMasterFont.black(36, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(isFlame && value > 0 ? AnyShapeStyle(LinearGradient(colors: [.red, .orange, .yellow], startPoint: .bottom, endPoint: .top)) : AnyShapeStyle(Theme.textPrimary))
                Text(value == 1 ? "day" : "days")
                    .font(TimeMasterFont.secondary())
                    .foregroundColor(Theme.textSecondary)
            }
            Text(label).font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TypeAnalyticsBreakdown: View {
    @EnvironmentObject private var store: WorkoutStore
    @StateObject private var goals = GoalsManager.shared
    @StateObject private var presentTypeIDs = ValueMemo<HistoryRevisionKey, Set<String>>()

    private var types: [WorkoutType] {
        let key = HistoryRevisionKey(store: ObjectIdentifier(store), revision: store.historyRevision)
        let present = presentTypeIDs.value(for: key) {
            Set(store.historyEntries.map { $0.workoutType.id })
        }
        return WorkoutType.all(custom: store.customWorkoutTypes).filter { type in
            present.contains(type.id) ||
            store.typeSchedules.contains { $0.type.id == type.id && $0.isActive }
        }
    }

    var body: some View {
        let types = self.types
        VStack(alignment: .leading, spacing: 12) {
            Text("By Workout Type")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
            if types.isEmpty {
                Text("Complete a workout or set a type schedule to see a breakdown.")
                    .font(TimeMasterFont.secondary()).foregroundColor(Theme.textSecondary)
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
                    Text(type.name).font(TimeMasterFont.rowTitle()).foregroundColor(Theme.textPrimary)
                    Text("\(stats.sessionsThisWeek) this week · \(stats.totalSeconds / 60)m total · \(stats.streak)d streak")
                        .font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit().foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if let adherence = stats.adherence {
                    Text("\(Int((adherence * 100).rounded()))%")
                        .font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit().foregroundColor(Color(hex: type.colorHex))
                }
            }
            if goal > 0 {
                ProgressView(value: progress)
                    .tint(Color(hex: type.colorHex))
                Text("\(stats.sessionsThisWeek) of \(goal) weekly goal")
                    .font(TimeMasterFont.black(11, relativeTo: .caption2)).monospacedDigit().foregroundColor(Theme.textSecondary)
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
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(store.trainingDurationMonths) mo")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .monospacedDigit()
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
                            .font(isActive ? TimeMasterFont.black(12, relativeTo: .caption) : TimeMasterFont.body(12, relativeTo: .caption))
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
                    .font(TimeMasterFont.caption())
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Stepper(value: $store.trainingDurationMonths, in: 1...12) {
                    Text("\(store.trainingDurationMonths) month\(store.trainingDurationMonths == 1 ? "" : "s")")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .monospacedDigit()
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
    var home = false
    @State private var showCalendar = false

    private let weeksCount = 24
    private let gap: CGFloat = 3
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    @State private var cellSize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var monthLabelHeight = 16.0

    private struct Cell {
        let date: Date
        let isFuture: Bool
        let count: Int
        let fill: Color
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(onSelectDate == nil ? .flexible() : .fixed(44), spacing: gap), count: weeksCount)
    }

    var body: some View {
        let now = Date()
        let window = HeatmapWindow.current(weeks: weeksCount, now: now)
        let cells = heatmapCells(window: window, now: now)
        Group {
            if onSelectDate != nil {
                card(window: window, cells: cells)
            } else {
                Button { showCalendar = true } label: { card(window: window, cells: cells) }
                    .buttonStyle(TimeMasterCardButtonStyle())
            }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarPage(entries: entries, outdoorActivities: outdoorActivities)
                .keyNavHost()
        }
    }

    private func heatmapCells(window: HeatmapWindow, now: Date) -> [Cell] {
        let outdoor = OutdoorDayCounts.counts(for: outdoorActivities, calendar: window.calendar)
        let facts = ActivityDayFacts(store: store, outdoor: outdoor)
        return window.days.map { day -> Cell in
            if day > now {
                return Cell(date: day, isFuture: true, count: 0, fill: Color.white.opacity(0.03))
            }
            let count = facts.count(on: day)
            return Cell(date: day, isFuture: false, count: count, fill: fill(day: day, count: count, facts: facts))
        }
    }

    @ViewBuilder
    private func card(window: HeatmapWindow, cells: [Cell]) -> some View {
        if home {
            WidgetCard(tint: .graphite) { cardContent(window: window, cells: cells).padding(16) }
        } else {
            cardContent(window: window, cells: cells)
                .padding(16)
                .modifier(TimeMasterCardSurface())
        }
    }

    private func cardContent(window: HeatmapWindow, cells: [Cell]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(onSelectDate == nil ? "Activity" : "Last 24 weeks")
                    .font(onSelectDate == nil ? TimeMasterFont.sectionTitle() : TimeMasterFont.black(15, relativeTo: .subheadline))
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
                                        Text(window.monthLabels[week])
                                            .font(TimeMasterFont.micro())
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, height: monthLabelHeight)
                                    }
                                }
                                heatmapGrid(window: window, cells: cells)
                            }
                        }
                            .onAppear { scroll.scrollTo(7 * weeksCount - 1, anchor: .trailing) }
                    }
                } else {
                    heatmapGrid(window: window, cells: cells)
                }
            }
        }
    }

    private var dayLabelColumn: some View {
        VStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(TimeMasterFont.body(9, relativeTo: .caption2))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 12, height: onSelectDate == nil ? cellSize : 44, alignment: .center)
            }
        }
    }

    private func heatmapGrid(window: HeatmapWindow, cells: [Cell]) -> some View {
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<(7 * weeksCount), id: \.self) { idx in
                let cell = cells[idx]
                Group {
                    if let onSelectDate {
                        Button { onSelectDate(cell.date) } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(cell.fill)
                                .overlay {
                                    Text(window.dayNumbers[idx])
                                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                                        .monospacedDigit()
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .keyNavShape(.roundedRectangle(cornerRadius: 12))
                        .disabled(cell.isFuture)
                        .accessibilityLabel("\(window.spokenDates[idx]), \(cell.count) workouts")
                        .accessibilityIdentifier("activity.day.\(window.dayKeys[idx])")
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(cell.fill)
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

    private func fill(day: Date, count: Int, facts: ActivityDayFacts) -> Color {
        if home { return homeFill(day: day, count: count, facts: facts) }
        if facts.isRest(on: day) { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
        if count > 0 {
            switch count {
            case 1: return Color(red: 0.1, green: 0.7, blue: 0.35)
            case 2: return Color(red: 0.1, green: 0.6, blue: 0.25)
            default: return Color(red: 0.05, green: 0.45, blue: 0.15)
            }
        }
        if facts.isScheduled(on: day) { return Color.red.opacity(0.4) }
        return Color.white.opacity(0.06)
    }

    private func homeFill(day: Date, count: Int, facts: ActivityDayFacts) -> Color {
        if count > 0 {
            switch count {
            case 1: return WidgetTint.orange.base.opacity(0.55)
            case 2: return WidgetTint.orange.base.opacity(0.8)
            default: return WidgetTint.orange.base
            }
        }
        if facts.isRest(on: day) { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.07)
    }
}

private struct CalendarDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct CalendarActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
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
                    HistoryListSection(entries: entries)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("Activity")
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
                    .keyNavHost()
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
    private static let monthNameFormatter = CachedDateFormatter { $0.dateFormat = "MMMM" }

    private var currentYear: Int {
        calendar.component(.year, from: currentMonth)
    }

    private var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        let context = dayContext()
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                    .padding(20)
                ScrollView {
                    VStack(spacing: 20) {
                        periodNavigation
                        if showYearView {
                            yearOverview(context)
                        } else {
                            monthDetail(context)
                        }
                        legendRow
                    }
                    .padding(20)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .font(TimeMasterFont.body())
            .background(Theme.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $showActivity) {
                CalendarActivitySheet(entries: entries, outdoorActivities: outdoorActivities)
                    .keyNavHost()
            }
            .sheet(isPresented: $showVacationSheet) {
                VacationSheet()
                    .keyNavHost()
            }
            .sheet(item: $selectedDay) { selection in
                DayInfoSheet(date: selection.date, entries: entries, outdoorActivities: outdoorActivities)
                    .keyNavHost()
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
                TimeMasterPageTitle("Calendar", size: 29, relativeTo: .title2).fixedSize()
                Spacer(minLength: 0)
                calendarControls
            }
            VStack(alignment: .leading, spacing: 16) {
                TimeMasterPageTitle("Calendar", size: 29, relativeTo: .title2)
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
                .font(TimeMasterFont.heading())
                .monospacedDigit()
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

    private func yearOverview(_ context: CalendarDayContext) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                monthRow(month: month, context: context)
            }
        }
    }

    private func monthRow(month: Int, context: CalendarDayContext) -> some View {
        let first = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1))
        let date = first ?? currentMonth
        let window = MonthWindow.window(first: first, calendar: calendar)
        let monthName = Self.monthNameFormatter.string(from: date)
        let summary = context.summary(of: window)
        let workoutDays = summary.workoutDays
        let restDaysCount = summary.restDays
        let missCount = summary.missedDays

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                currentMonth = date
                showYearView = false
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthName)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 8) {
                        if workoutDays > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 0.1, green: 0.6, blue: 0.25)).frame(width: 6, height: 6)
                                Text("\(workoutDays)").font(TimeMasterFont.black(11, relativeTo: .caption2)).monospacedDigit().foregroundColor(Theme.textSecondary)
                            }
                        }
                        if restDaysCount > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 0.3, green: 0.55, blue: 0.85)).frame(width: 6, height: 6)
                                Text("\(restDaysCount)").font(TimeMasterFont.black(11, relativeTo: .caption2)).monospacedDigit().foregroundColor(Theme.textSecondary)
                            }
                        }
                        if missCount > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("\(missCount)").font(TimeMasterFont.black(11, relativeTo: .caption2)).monospacedDigit().foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                Spacer()
                miniMonthGrid(window: window, context: context)
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

    @ViewBuilder
    private func miniMonthGrid(window: MonthWindow, context: CalendarDayContext) -> some View {
        if window.days.isEmpty {
            Color.clear.frame(width: 70, height: 10)
        } else {
            VStack(spacing: 1) {
                ForEach(0..<window.rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col - window.leadingBlanks
                            if idx >= 0, idx < window.days.count {
                                miniCell(day: window.days[idx], context: context)
                            } else {
                                Color.clear.frame(width: 7, height: 7)
                            }
                        }
                    }
                }
            }
        }
    }

    private func miniCell(day: Date, context: CalendarDayContext) -> some View {
        let fill: Color = {
            if day > context.now { return Color.white.opacity(0.04) }
            if context.facts.isRest(on: day) { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.6) }
            if context.facts.count(on: day) > 0 { return Color(red: 0.1, green: 0.6, blue: 0.25) }
            if context.facts.isScheduled(on: day) { return Color.red.opacity(0.35) }
            return Color.white.opacity(0.06)
        }()
        return RoundedRectangle(cornerRadius: 1)
            .fill(fill)
            .frame(width: 7, height: 7)
            .overlay {
                RoundedRectangle(cornerRadius: 1)
                    .stroke(context.isHighlighted(day) ? Theme.toolbarOrange : .clear, lineWidth: 1)
            }
    }

    // MARK: - Month detail view

    private func monthDetail(_ context: CalendarDayContext) -> some View {
        let window = MonthWindow.window(
            first: calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
            calendar: calendar
        )
        let workoutDays = context.workoutDays(in: window)
        return VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(day + 1) % 7])
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<(window.leadingBlanks + window.days.count), id: \.self) { slot in
                        if slot >= window.leadingBlanks {
                            dayCell(index: slot - window.leadingBlanks, window: window, context: context)
                        } else {
                            Color.clear.frame(minHeight: 52)
                        }
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(12)
            .modifier(TimeMasterCardSurface())

            if workoutDays > 0 {
                Label("\(workoutDays) workout day\(workoutDays == 1 ? "" : "s")", systemImage: "figure.strengthtraining.traditional")
                    .font(TimeMasterFont.secondary())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dayCell(index: Int, window: MonthWindow, context: CalendarDayContext) -> some View {
        let date = window.days[index]
        let isFuture = date > context.now
        let isToday = date == context.today
        let isRest = context.facts.isRest(on: date)
        let count = context.facts.count(on: date)
        let highlighted = context.isHighlighted(date)
        let bg: Color = {
            if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
            if count > 0 {
                switch count {
                case 1: return Color(red: 0.1, green: 0.7, blue: 0.35)
                case 2: return Color(red: 0.1, green: 0.6, blue: 0.25)
                default: return Color(red: 0.05, green: 0.45, blue: 0.15)
                }
            }
            if !isFuture && context.facts.isScheduled(on: date) { return Color.red.opacity(0.35) }
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
                Text("\(window.dayNumbers[index])")
                    .font(TimeMasterFont.black(16, relativeTo: .callout))
                    .monospacedDigit()
                    .foregroundStyle(isFuture && onSelectWeek == nil ? Theme.textSecondary : .white)
                Text(count > 0 ? "\(count)" : " ")
                    .font(TimeMasterFont.black(11, relativeTo: .caption2))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(bg.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .background(highlighted ? Theme.toolbarOrange.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(highlighted ? Theme.toolbarOrange : isToday ? .white.opacity(0.8) : .clear,
                                  lineWidth: highlighted ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: 10))
        .disabled(isFuture && onSelectWeek == nil)
        .accessibilityLabel("\(window.spokenDates[index]), \(count) workouts\(highlighted ? ", selected week" : "")")
        .accessibilityHint(onSelectWeek == nil ? "Open day details" : "Open this week in Schedule")
        .accessibilityIdentifier("calendar.day.\(window.dayKeys[index])")
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
        .font(TimeMasterFont.caption())
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

    private func dayContext() -> CalendarDayContext {
        let now = Date()
        let outdoor = OutdoorDayCounts.counts(for: outdoorActivities, calendar: calendar)
        let highlight = selectedWeek.flatMap { start in
            calendar.date(byAdding: .day, value: 7, to: start).map { (start: start, end: $0) }
        }
        return CalendarDayContext(
            now: now,
            today: calendar.startOfDay(for: now),
            facts: ActivityDayFacts(store: store, outdoor: outdoor),
            highlight: highlight
        )
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

    private struct Detail {
        let entries: [WorkoutHistoryEntry]
        let manual: [WeeklyWorkoutSchedule.Occurrence]
        let outdoor: [OutdoorActivity]
        let totalMinutes: Int
        let isRest: Bool
        let isScheduled: Bool
        let scheduledTypes: [WorkoutType]

        var isEmpty: Bool { entries.isEmpty && manual.isEmpty && outdoor.isEmpty }
        var workoutCount: Int { entries.count + manual.count + outdoor.count }
    }

    private static let fullDateFormatter = CachedDateFormatter { $0.dateFormat = "EEEE, MMMM d" }

    private func loadDetail() -> Detail {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)
        let dayEntries: [WorkoutHistoryEntry] = end.map { limit in
            entries.filter { $0.completedAt >= start && $0.completedAt < limit }
        } ?? []
        let dayOutdoor: [OutdoorActivity] = end.map { limit in
            outdoorActivities.filter { $0.startedAt >= start && $0.startedAt < limit }
        } ?? []
        let manual = store.scheduleOccurrences(on: date).filter { $0.isComplete && $0.matchedSessionID == nil }
        let entrySeconds = dayEntries.reduce(0) { $0 + ($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) }
        let manualSeconds = manual.reduce(0) { $0 + ($1.entry.durationSeconds ?? 0) }
        let outdoorSeconds = dayOutdoor.reduce(0) { $0 + $1.elapsedSeconds }
        return Detail(
            entries: dayEntries,
            manual: manual,
            outdoor: dayOutdoor,
            totalMinutes: (entrySeconds + manualSeconds + outdoorSeconds) / 60,
            isRest: store.isRestDay(date),
            isScheduled: store.isScheduledDay(date),
            scheduledTypes: store.scheduledTypes(for: date)
        )
    }

    var body: some View {
        let detail = loadDetail()
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Text(Self.fullDateFormatter.string(from: date))
                            .font(TimeMasterFont.black(22, relativeTo: .title2))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                        let statsLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 16))
                            : AnyLayout(HStackLayout(spacing: 24))
                        statsLayout {
                            statChip(value: "\(detail.workoutCount)", label: "workouts")
                            statChip(value: "\(detail.totalMinutes)m", label: "total time")
                        }
                        VStack(spacing: 8) {
                            if detail.isRest {
                                Label("Rest day", systemImage: "moon.zzz.fill")
                                    .foregroundStyle(.blue)
                            }
                            ForEach(detail.scheduledTypes, id: \.self) { type in
                                Label(type.name, systemImage: type.icon)
                            }
                            if !detail.isRest && detail.isScheduled && detail.isEmpty {
                                Label("Missed", systemImage: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(TimeMasterFont.secondary())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .modifier(TimeMasterCardSurface())

                    if detail.isEmpty {
                        Label(detail.isRest ? "Rest day" : "No workout logged",
                              systemImage: detail.isRest ? "moon.zzz" : "figure.walk")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(detail.entries) { entry in
                                HistoryRow(entry: entry)
                                    .padding(16)
                                    .modifier(TimeMasterCardSurface())
                            }
                            ForEach(detail.manual) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(item.entry.title, systemImage: item.entry.icon)
                                        .font(TimeMasterFont.sectionTitle())
                                    Text(item.entry.workoutID == nil ? "Custom workout" : "Completed manually")
                                        .font(TimeMasterFont.caption()).foregroundStyle(.secondary)
                                    if let seconds = item.entry.durationSeconds {
                                        Text("\(seconds / 60) min").font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit()
                                    }
                                    if !item.entry.notes.isEmpty {
                                        Text(item.entry.notes).font(TimeMasterFont.secondary()).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .modifier(TimeMasterCardSurface())
                            }
                            ForEach(detail.outdoor) { activity in
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(activity.title, systemImage: activity.kind.iconName)
                                        .font(TimeMasterFont.sectionTitle())
                                    Text("\(activity.elapsedSeconds / 60) min")
                                        .font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit().foregroundStyle(.secondary)
                                    Text(Measurement(value: activity.distanceMeters, unit: UnitLength.meters)
                                        .formatted(.measurement(width: .abbreviated, usage: .road)))
                                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .modifier(TimeMasterCardSurface())
                            }
                        }
                    }
                    Button { store.toggleRestDay(for: date) } label: {
                        Label(detail.isRest ? "Remove rest day" : "Mark as rest day",
                              systemImage: detail.isRest ? "moon.zzz.fill" : "moon.zzz")
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
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("Day details")
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
            Text(value).font(TimeMasterFont.heading()).monospacedDigit().foregroundColor(Theme.textPrimary)
            Text(label).font(TimeMasterFont.micro()).foregroundColor(Theme.textSecondary)
        }
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
                            Text("Duration").font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("From").font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
                                    DatePicker("", selection: $startMonth, displayedComponents: .date)
                                        .labelsHidden().colorScheme(.dark)
                                        .monospacedDigit()
                                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("To").font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
                                    DatePicker("", selection: $endMonth, displayedComponents: .date)
                                        .labelsHidden().colorScheme(.dark)
                                        .monospacedDigit()
                                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(14).background(Theme.surface).cornerRadius(10)

                            Text("\(monthsInRange) month\(monthsInRange == 1 ? "" : "s") selected")
                                .font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit().foregroundColor(Theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Workout Types").font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
                            Text("Select which types to pause during vacation.").font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                                    Button {
                                        if selectedTypes.contains(type) { selectedTypes.remove(type) }
                                        else { selectedTypes.insert(type) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: type.icon).font(.system(size: 11))
                                            Text(type.name)
                                                .font(selectedTypes.contains(type) ? TimeMasterFont.rowTitle() : TimeMasterFont.secondary())
                                        }
                                        .foregroundColor(selectedTypes.contains(type) ? .black : .white)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedTypes.contains(type) ? Color.white : Theme.surface)
                                        .cornerRadius(8)
                                    }
                                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("Set Vacation")
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
    @StateObject private var sortedMemo = ValueMemo<[WorkoutHistoryEntry], [WorkoutHistoryEntry]>()

    var body: some View {
        let sorted = sortedMemo.value(for: entries) {
            entries.sorted { $0.completedAt > $1.completedAt }
        }
        let lastID = sorted.last?.id
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
                Spacer()
                if !entries.isEmpty {
                    let n = entries.count
                    Text("\(n) session\(n == 1 ? "" : "s")")
                        .font(TimeMasterFont.black(12, relativeTo: .caption)).monospacedDigit().foregroundColor(Theme.textSecondary)
                }
            }
            if entries.isEmpty {
                Text("No sessions recorded yet.")
                    .font(TimeMasterFont.secondary())
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sorted) { entry in
                        HistoryRow(entry: entry)
                        if entry.id != lastID {
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
