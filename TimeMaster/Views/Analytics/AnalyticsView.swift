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
                StreakCalendarView()
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

// MARK: - F04-A: Streak Calendar

private struct StreakCalendarView: View {
    @EnvironmentObject var store: WorkoutStore
    private let dayCount = 28
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Streak Calendar")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button { store.toggleRestDay(for: Date()) } label: {
                    Text(store.isRestDay(Date()) ? "Unmark Rest" : "Mark Rest Day")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(store.isRestDay(Date()) ? Color.gray : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(store.isRestDay(Date()) ? Color.white.opacity(0.1) : Color.white.opacity(0.15))
                        .cornerRadius(8)
                }
            }

            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<dayCount, id: \.self) { i in
                    let date = dateFor(daysBack: dayCount - 1 - i)
                    let isFuture = date > Date()
                    let cal = Calendar.current
                    let dayStart = cal.startOfDay(for: date)
                    let hasWorkout = store.historyEntries.contains { cal.isDate($0.completedAt, inSameDayAs: dayStart) }
                    let isRest = store.isRestDay(date)
                    let isPast = !isFuture && !cal.isDate(date, inSameDayAs: Date())

                    Circle()
                        .fill(dayColor(future: isFuture, workout: hasWorkout, rest: isRest, past: isPast))
                        .frame(height: 24)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func dateFor(daysBack: Int) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -daysBack, to: cal.startOfDay(for: Date())) ?? Date()
    }

    private func dayColor(future: Bool, workout: Bool, rest: Bool, past: Bool) -> Color {
        if future { return Color.white.opacity(0.05) }
        if workout { return Color.green }
        if rest { return Color.gray }
        return Color.red.opacity(0.5)
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
    let entries: [WorkoutHistoryEntry]

    private let weeksCount = 12
    private let gap: CGFloat = 3
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    /// Updated after first layout pass via GeometryReader so day labels stay aligned.
    @State private var cellSize: CGFloat = 14

    // GridItem array is a constant — computed once.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gap), count: weeksCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity — Last 12 Weeks")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack(alignment: .top, spacing: gap + 2) {
                dayLabelColumn
                stretchingGrid
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    // MARK: Day label column

    private var dayLabelColumn: some View {
        VStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    // height tracks the measured cell size so labels stay row-aligned
                    .frame(width: 12, height: cellSize, alignment: .center)
            }
        }
    }

    // MARK: Stretching grid

    /// LazyVGrid with flexible columns fills all available width.
    /// Data is indexed so that row = dayIndex, column = weekIndex:
    ///   idx = dayIndex * weeksCount + weekIndex
    /// which matches LazyVGrid's left-to-right, top-to-bottom fill order.
    private var stretchingGrid: some View {
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<(7 * weeksCount), id: \.self) { idx in
                let w = idx % weeksCount
                let d = idx / weeksCount
                let date = dateFor(week: w, day: d)
                let isFuture = date > Date()
                let count = isFuture ? 0 : workoutCount(on: date)
                RoundedRectangle(cornerRadius: 3)
                    .fill(isFuture ? Color.white.opacity(0.04) : cellColor(count: count))
                    .aspectRatio(1, contentMode: .fit) // square cells, size driven by column width
            }
        }
        // Measure actual grid width so we can derive cellSize for label alignment.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        updateCellSize(gridWidth: geo.size.width)
                    }
                    .onChange(of: geo.size.width) { newWidth in
                        updateCellSize(gridWidth: newWidth)
                    }
            }
        )
    }

    private func updateCellSize(gridWidth: CGFloat) {
        let computed = (gridWidth - CGFloat(weeksCount - 1) * gap) / CGFloat(weeksCount)
        cellSize = max(computed, 1)
    }

    // MARK: Helpers

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

    private func cellColor(count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.08)
        case 1: return Color.white.opacity(0.35)
        case 2: return Color.white.opacity(0.65)
        default: return Color.white
        }
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
