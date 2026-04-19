import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var store: WorkoutStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if store.historyEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 20) {
                            overviewCard
                            weeklyChartCard
                            byTypeCard
                            streakCard
                            perWorkoutCard
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Analytics")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            Text("No Data Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            Text("Complete a workout to see analytics")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    // MARK: - Overview Card
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            HStack(spacing: 0) {
                statItem(value: "\(totalWorkouts)", label: "Total\nWorkouts", icon: "figure.run")
                Rectangle()
                    .fill(Theme.textSecondary.opacity(0.2))
                    .frame(width: 1, height: 50)
                statItem(value: "\(totalMinutes)", label: "Total\nMinutes", icon: "clock.fill")
                Rectangle()
                    .fill(Theme.textSecondary.opacity(0.2))
                    .frame(width: 1, height: 50)
                statItem(value: formatDuration(avgDuration), label: "Avg\nDuration", icon: "timer")
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Weekly Chart Card
    
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(weeklyWorkouts) workouts")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Chart {
                ForEach(weeklyData.indices, id: \.self) { index in
                    BarMark(
                        x: .value("Day", weeklyData[index].day),
                        y: .value("Count", weeklyData[index].count)
                    )
                    .foregroundStyle(Theme.primary.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Theme.textSecondary.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - By Type Card (Horizontal Bar Chart)
    
    private var byTypeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Type")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            VStack(spacing: 12) {
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    let count = workoutsByType(type)
                    if count > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .foregroundColor(colorForType(type))
                                .frame(width: 24)
                            
                            Text(type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .frame(width: 70, alignment: .leading)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.surface)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(colorForType(type))
                                        .frame(width: typeProgress(count, totalWidth: geo.size.width))
                                }
                            }
                            .frame(height: 20)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textPrimary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.primary)
                    Text(currentStreak == 1 ? "day" : "days")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundColor(currentStreak > 0 ? Theme.accent : Theme.textSecondary)
                .opacity(currentStreak > 0 ? 1 : 0.3)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Per Workout Card
    
    private var perWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Per Workout")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if topWorkouts.isEmpty {
                Text("No completed workouts yet")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(topWorkouts.prefix(6), id: \.workoutId) { item in
                    HStack {
                        if let workout = store.workouts.first(where: { $0.id == item.workoutId }) {
                            Image(systemName: workout.type.icon)
                                .foregroundColor(colorForType(workout.type))
                                .frame(width: 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text("\(item.completedCount)× • \(item.totalMinutes)m total")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.primary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data
    
    private var totalWorkouts: Int { store.historyEntries.count }
    private var totalMinutes: Int { store.historyEntries.reduce(0) { $0 + $1.durationCompleted } / 60 }
    private var avgDuration: Int { totalWorkouts > 0 ? totalMinutes / totalWorkouts : 0 }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hrs = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hrs)h\(mins)m" : "\(hrs)h"
        }
        return "\(minutes)m"
    }
    
    private var weeklyWorkouts: Int {
        weeklyData.reduce(0) { $0 + $1.count }
    }
    
    private var weeklyData: [DayData] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset - 6, to: today) ?? today
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let count = store.historyEntries.filter { entry in
                entry.completedAt >= startOfDay && entry.completedAt < endOfDay
            }.count
            
            let dayName = calendar.shortWeekdaySymbols[max(0, calendar.component(.weekday, from: date) - 1)]
            
            return DayData(day: dayName, count: count)
        }
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date()
        
        for _ in 0..<365 {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let hasWorkout = store.historyEntries.contains { entry in
                entry.completedAt >= startOfDay && entry.completedAt < endOfDay
            }
            
            if hasWorkout {
                streak += 1
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var topWorkouts: [WorkoutStats] {
        var stats: [WorkoutStats] = []
        
        for workout in store.workouts {
            let entries = store.historyEntries.filter { $0.workoutId == workout.id }
            guard !entries.isEmpty else { continue }
            
            stats.append(WorkoutStats(
                workoutId: workout.id,
                name: workout.name,
                completedCount: entries.count,
                totalMinutes: entries.reduce(0) { $0 + $1.durationCompleted } / 60
            ))
        }
        
        return stats.sorted { $0.completedCount > $1.completedCount }
    }
    
    private func workoutsByType(_ type: WorkoutType) -> Int {
        let workoutIds = store.workouts.filter { $0.type == type }.map { $0.id }
        return store.historyEntries.filter { workoutIds.contains($0.workoutId) }.count
    }
    
    private func typeProgress(_ count: Int, totalWidth: CGFloat) -> CGFloat {
        let maxCount = WorkoutType.allCases.map { workoutsByType($0) }.max() ?? 1
        return CGFloat(count) / CGFloat(maxCount) * totalWidth
    }
    
    private func colorForType(_ type: WorkoutType) -> Color {
        switch type {
        case .strength: return .red
        case .stretch: return .blue
        case .cardio: return .green
        case .hiit: return .orange
        case .yoga: return .purple
        case .face: return .pink
        case .other: return .gray
        }
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

struct WorkoutStats: Identifiable {
    let id = UUID()
    let workoutId: UUID
    let name: String
    let completedCount: Int
    let totalMinutes: Int
}

#Preview {
    AnalyticsView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}