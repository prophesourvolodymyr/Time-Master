import SwiftUI

// MARK: - GoalsManager

final class GoalsManager: ObservableObject {
    static let shared = GoalsManager()
    private let key = "workout_goals_by_type_v2"
    @Published private(set) var goals: [String: Int] = [:]

    private init() { load() }

    func goal(for type: WorkoutType) -> Int { goals[type.rawValue] ?? 0 }

    func setGoal(_ n: Int, for type: WorkoutType) {
        goals[type.rawValue] = n
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
    @StateObject private var goalsManager = GoalsManager.shared
    @State private var selectedType: WorkoutType? = nil
    @State private var showingGoalEditor = false
    @State private var showingClearAlert = false
    @State private var promptDraft: Int = 4

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
                    Divider().background(Theme.separator)
                    if let type = selectedType, currentGoal == 0 {
                        GoalPromptView(
                            typeName: type.rawValue,
                            draft: $promptDraft
                        ) {
                            goalsManager.setGoal(promptDraft, for: type)
                        }
                    } else {
                        analyticsScroll
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { analyticsToolbar }
            .sheet(isPresented: $showingGoalEditor) {
                if let type = selectedType {
                    GoalEditorSheet(
                        typeName: type.rawValue,
                        currentGoal: currentGoal
                    ) { goalsManager.setGoal($0, for: type) }
                }
            }
            .alert("Clear History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { store.clearHistory() }
            } message: { Text("This will delete all workout history.") }
        }
    }

    // MARK: Type picker

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(label: "All", icon: "square.grid.2x2", selected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    typeChip(
                        label: type.rawValue,
                        icon: type.icon,
                        selected: selectedType == type
                    ) {
                        selectedType = type
                        promptDraft = max(goalsManager.goal(for: type), 1)
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
            .foregroundColor(selected ? .black : Color.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.white : Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var analyticsToolbar: some ToolbarContent {
        if let type = selectedType, currentGoal > 0 {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingGoalEditor = true } label: {
                    Text("Goal: \(currentGoal)×/wk")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }
        }
        if !store.historyEntries.isEmpty {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showingClearAlert = true } label: {
                    Image(systemName: "trash")
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
        }
    }

    // MARK: Scroll content

    private var analyticsScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if let type = selectedType {
                    WeeklyGoalCard(
                        entries: filteredEntries,
                        goal: currentGoal,
                        typeName: type.rawValue
                    )
                }
                LifetimeStatsStrip(entries: filteredEntries)
                StreakCard()
                WeeklyGoalSection()
                ActivityHeatmap(entries: filteredEntries)
                HistoryListSection(entries: filteredEntries, store: store)
            }
            .padding(16)
        }
    }
}

// MARK: - GoalPromptView

private struct GoalPromptView: View {
    let typeName: String
    @Binding var draft: Int
    let onSet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 64))
                        .foregroundColor(Color.white.opacity(0.85))
                    Text("Set \(typeName) Goal")
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("How many \(typeName) sessions per week?")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    ForEach(1...7, id: \.self) { n in
                        goalCircle(n: n, selected: draft == n) { draft = n }
                    }
                }
                Text(draft == 1 ? "Once a week" : "\(draft) times a week")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Button(action: onSet) {
                    Text("Set Goal")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func goalCircle(n: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(n)")
                .font(.title3.bold())
                .foregroundColor(selected ? .black : .white)
                .frame(width: 42, height: 42)
                .background(selected ? Color.white : Color.white.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

// MARK: - GoalEditorSheet

private struct GoalEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let typeName: String
    let currentGoal: Int
    let onSave: (Int) -> Void
    @State private var draft: Int

    init(typeName: String, currentGoal: Int, onSave: @escaping (Int) -> Void) {
        self.typeName = typeName
        self.currentGoal = currentGoal
        self.onSave = onSave
        _draft = State(initialValue: max(currentGoal, 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(Color.white.opacity(0.8))
                        Text("\(typeName) Weekly Goal")
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("How many sessions per week?")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    HStack(spacing: 10) {
                        ForEach(1...7, id: \.self) { n in
                            Button { draft = n } label: {
                                Text("\(n)")
                                    .font(.title3.bold())
                                    .foregroundColor(draft == n ? .black : .white)
                                    .frame(width: 42, height: 42)
                                    .background(draft == n ? Color.white : Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    Text(draft == 1 ? "Once a week" : "\(draft) times a week")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(32)
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }.foregroundColor(.white)
                }
            }
        }
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

    private var streak: (current: Int, best: Int) {
        store.streakInfo()
    }

    var body: some View {
        HStack(spacing: 0) {
            streakItem(value: streak.current, label: "Current Streak", emoji: "fire")
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 50)
            streakItem(value: streak.best, label: "Best Streak", emoji: "trophy")
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func streakItem(value: Int, label: String, emoji: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(value == 1 ? "day" : "days")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - F04-A: Weekly Goal Section

private struct WeeklyGoalSection: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var goalDraft: Int

    init() {
        _goalDraft = State(initialValue: UserDefaults.standard.integer(forKey: "workout_weekly_goal_saved") > 0
            ? UserDefaults.standard.integer(forKey: "workout_weekly_goal_saved") : 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Workout Goal")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(goalDraft) days/week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }

            HStack(spacing: 8) {
                ForEach(3...7, id: \.self) { n in
                    Button {
                        goalDraft = n
                        store.setWeeklyGoal(n)
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 15, weight: goalDraft == n ? .bold : .medium))
                            .foregroundColor(goalDraft == n ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(goalDraft == n ? Color.white : Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
}

// MARK: - ActivityHeatmap

private struct ActivityHeatmap: View {
    @EnvironmentObject var store: WorkoutStore
    let entries: [WorkoutHistoryEntry]

    private let weeksCount = 24
    private let gap: CGFloat = 3
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    @State private var cellSize: CGFloat = 18
    @State private var selectedDate: Date?
    @State private var showDayInfo = false
    @State private var showSchedulePicker = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gap), count: weeksCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity — Last 24 Weeks")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                legend
                Button {
                    showSchedulePicker = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
            }
            HStack(alignment: .top, spacing: gap + 2) {
                dayLabelColumn
                stretchingGrid
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
        .sheet(isPresented: $showDayInfo) {
            if let date = selectedDate {
                DayInfoSheet(date: date, entries: entries)
            }
        }
        .sheet(isPresented: $showSchedulePicker) {
            SchedulePickerSheet()
        }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less").font(.system(size: 7)).foregroundColor(Theme.textSecondary)
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(activityColor(count: i))
                    .frame(width: 8, height: 8)
            }
            Text("More").font(.system(size: 7)).foregroundColor(Theme.textSecondary)
            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.6)).frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.5)).frame(width: 8, height: 8)
        }
    }

    private var dayLabelColumn: some View {
        VStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 12, height: cellSize, alignment: .center)
            }
        }
    }

    private var stretchingGrid: some View {
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<(7 * weeksCount), id: \.self) { idx in
                let w = idx % weeksCount
                let d = idx / weeksCount
                let date = dateFor(week: w, day: d)
                let isFuture = date > Date()
                let isRest = store.isRestDay(date)
                let isScheduled = store.isScheduledDay(date)
                let hasWorkout = store.hasWorkout(on: date)
                let count = isFuture ? 0 : workoutCount(on: date)
                let isMissedDay = !isFuture && !isRest && isScheduled && count == 0

                RoundedRectangle(cornerRadius: 3)
                    .fill(cellBackground(
                        isFuture: isFuture,
                        isRest: isRest,
                        isMissed: isMissedDay,
                        hasWorkout: hasWorkout,
                        count: count
                    ))
                    .aspectRatio(1, contentMode: .fit)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isFuture {
                            selectedDate = date
                            showDayInfo = true
                        }
                    }
                    .contextMenu {
                        if !isFuture {
                            Button {
                                store.toggleRestDay(for: date)
                            } label: {
                                Label(
                                    store.isRestDay(date) ? "Remove Rest Day" : "Mark as Rest Day",
                                    systemImage: "moon.zzz"
                                )
                            }
                            Button {
                                store.toggleScheduledDay(for: date)
                            } label: {
                                Label(
                                    store.isScheduledDay(date) ? "Remove Scheduled Day" : "Mark as Workout Day",
                                    systemImage: "calendar.badge.plus"
                                )
                            }
                        }
                    }
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
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return entries.filter { $0.completedAt >= start && $0.completedAt < end }.count
    }

    private func activityColor(count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.08)
        case 1: return Color.white.opacity(0.35)
        case 2: return Color.white.opacity(0.65)
        default: return Color.white
        }
    }

    private func cellBackground(isFuture: Bool, isRest: Bool, isMissed: Bool, hasWorkout: Bool, count: Int) -> Color {
        if isFuture { return Color.white.opacity(0.03) }
        if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
        if isMissed { return Color.red.opacity(0.5) }
        if hasWorkout { return activityColor(count: count) }
        return Color.white.opacity(0.06)
    }
}

// MARK: - Schedule Picker Sheet

private struct SchedulePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in 1...range.count {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            days.append(date)
        }
        return days
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }

                        Spacer()

                        Text(monthTitle)
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    HStack(spacing: 4) {
                        ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                            Text(label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                            if let date = date {
                                scheduleDayCell(date)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            legendDot(color: .white, label: "Workout done")
                            legendDot(color: Color(red: 0.3, green: 0.55, blue: 0.85), label: "Rest day")
                            legendDot(color: .red, label: "Missed")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)

                        Text("Tap a day to toggle it as a scheduled workout day.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Schedule Workout Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }

    private func scheduleDayCell(_ date: Date) -> some View {
        let isFuture = date > Date()
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isScheduled = store.isScheduledDay(date)
        let isRest = store.isRestDay(date)
        let hasWorkout = store.hasWorkout(on: date)

        let bgColor: Color = {
            if isRest { return Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.5) }
            if hasWorkout { return Color.white.opacity(0.4) }
            if isScheduled { return Color.white.opacity(0.15) }
            return Color.clear
        }()

        return Button {
            guard !isRest else { return }
            store.toggleScheduledDay(for: date)
        } label: {
            VStack(spacing: 0) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isFuture ? Theme.textSecondary.opacity(0.3)
                        : isRest ? Color(red: 0.3, green: 0.55, blue: 0.85)
                        : hasWorkout ? .white
                        : isScheduled ? .white
                        : Theme.textPrimary.opacity(0.7)
                    )
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isScheduled ? Color.white.opacity(0.5) : Color.clear,
                                lineWidth: isToday ? 2 : 1.5
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .disabled(isFuture)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Day Info Sheet

private struct DayInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    let date: Date
    let entries: [WorkoutHistoryEntry]

    private var dayEntries: [WorkoutHistoryEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return entries.filter { $0.completedAt >= start && $0.completedAt < end }
    }

    private var totalMinutes: Int {
        dayEntries.reduce(0) { $0 + $1.elapsedSeconds } / 60
    }

    private var isRest: Bool { store.isRestDay(date) }
    private var isScheduled: Bool { store.isScheduledDay(date) }
    private var isMissed: Bool { !isRest && isScheduled && dayEntries.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text(formatFullDate(date))
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)

                        HStack(spacing: 20) {
                            statChip(value: "\(dayEntries.count)", label: "workouts")
                            statChip(value: "\(totalMinutes)m", label: "total time")
                        }

                        HStack(spacing: 10) {
                            if isRest {
                                Label("Rest Day", systemImage: "moon.zzz.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.85))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color(red: 0.3, green: 0.55, blue: 0.85).opacity(0.15))
                                    .cornerRadius(6)
                            }
                            if isScheduled && !isRest {
                                Label("Planned", systemImage: "calendar")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            if isMissed {
                                Label("Missed", systemImage: "xmark.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface)

                    if dayEntries.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: isRest ? "moon.zzz" : "figure.walk")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text(isRest ? "Rest day." : isScheduled ? "No workout logged." : "No workouts logged.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(dayEntries) { entry in
                                HistoryRow(entry: entry)
                                    .listRowBackground(Theme.surface)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    VStack(spacing: 10) {
                        Button {
                            store.toggleRestDay(for: date)
                        } label: {
                            Label(
                                isRest ? "Remove Rest Day" : "Mark as Rest Day",
                                systemImage: "moon.zzz"
                            )
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isRest ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                            .cornerRadius(14)
                        }
                        Button {
                            store.toggleScheduledDay(for: date)
                        } label: {
                            Label(
                                isScheduled ? "Remove Scheduled Day" : "Mark as Workout Day",
                                systemImage: isScheduled ? "calendar.badge.minus" : "calendar.badge.plus"
                            )
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isScheduled ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                            .cornerRadius(14)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.white)
                }
            }
        }
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
}
