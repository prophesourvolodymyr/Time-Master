import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var databaseStore: DatabaseStore

    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void

    @State private var playerWorkout: Workout?
    @State private var showingWorkoutPicker = false
    @State private var showingSettings = false
    @State private var appeared = false

    private var readyWorkouts: [Workout] {
        store.workouts.filter { !$0.sections.isEmpty }
    }

    private var suggestedWorkout: Workout? {
        guard !readyWorkouts.isEmpty else { return nil }
        if let lastWorkoutID = store.historyEntries.sorted(by: { $0.completedAt > $1.completedAt }).first?.workoutId,
           let match = readyWorkouts.first(where: { $0.id == lastWorkoutID }) {
            return match
        }
        return readyWorkouts.first
    }

    private var weeklyEntries: [WorkoutHistoryEntry] {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return store.historyEntries.filter { $0.completedAt >= weekStart }
    }

    private var weeklyMinutes: Int {
        weeklyEntries.reduce(0) { $0 + (($1.isPartial ? $1.elapsedSeconds : $1.durationCompleted) / 60) }
    }

    private var todayMessage: String {
        if store.isRestDay(Date()) { return "Recovery is part of the plan." }
        let scheduled = store.scheduledTypes(for: Date())
        if scheduled.isEmpty { return "Move how you feel today." }
        return "On your plan: \(scheduled.map(\.name).joined(separator: ", "))."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        if let workout = suggestedWorkout {
                            quickStartCard(workout)
                            metrics
                            typeProgress
                            recentActivity
                        } else {
                            emptyState
                        }
                    }
                    .padding(16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                 ToolbarItem(placement: .primaryAction) {
                     Button(action: onBrowseWorkouts) {
                        Image(systemName: "rectangle.stack")
                            .foregroundColor(.white)
                    }
                     .accessibilityLabel("Browse workouts")
                 }
                 ToolbarItem(placement: .primaryAction) {
                     Button { showingSettings = true } label: {
                         Image(systemName: "gearshape")
                             .foregroundColor(.white)
                     }
                     .accessibilityLabel("Open Settings")
                 }
             }
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            }
            .sheet(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(databaseStore)
            }
             .sheet(isPresented: $showingWorkoutPicker) {
                 workoutPicker
             }
             .sheet(isPresented: $showingSettings) {
                 SettingsView()
                     .environmentObject(store)
             }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(todayMessage)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 7) {
                Image(systemName: store.hasWorkout(on: Date()) ? "checkmark.circle.fill" : "circle.dashed")
                Text(store.hasWorkout(on: Date()) ? "Training logged today" : "Your day is still open")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(store.hasWorkout(on: Date()) ? .green : Theme.textSecondary)
            .padding(.top, 2)
        }
    }

    private func quickStartCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("QUICK START")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: workout.colorHex))
                    Text(workout.name)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text("\(workout.sectionCount) sections · \(durationText(workout.totalDuration))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: workout.type.iconName)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(workout.colorHex == "FFFFFF" ? .black : .white)
                    .frame(width: 54, height: 54)
                    .background(Color(hex: workout.colorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
            }
            HStack(spacing: 10) {
                Button { playerWorkout = workout } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                Button { showingWorkoutPicker = true } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .accessibilityLabel("Choose another workout")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: workout.colorHex).opacity(0.35), Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metric(value: "\(weeklyEntries.count)", label: "this week", icon: "checkmark.seal.fill", tint: .green)
            metric(value: "\(store.streakInfo().current)", label: "day streak", icon: "flame.fill", tint: .orange)
            metric(value: "\(weeklyMinutes)m", label: "active time", icon: "timer", tint: .cyan)
        }
    }

    private func metric(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundColor(tint)
            Text(value).font(.title3.bold()).foregroundColor(.white).monospacedDigit()
            Text(label).font(.caption2).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var typeProgress: some View {
        let types = WorkoutType.all(custom: store.customWorkoutTypes).filter { type in
            weeklyEntries.contains { $0.workoutType.id == type.id } || store.scheduledTypes(for: Date()).contains(type)
        }
        return Group {
            if !types.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly rhythm").font(.headline).foregroundColor(.white)
                    ForEach(types, id: \.id) { type in
                        let completed = weeklyEntries.filter { $0.workoutType.id == type.id }.count
                        let goal = max(GoalsManager.shared.goal(for: type), 1)
                        HStack(spacing: 10) {
                            Image(systemName: type.iconName)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: type.colorHex))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(type.name).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            ProgressView(value: min(Double(completed) / Double(goal), 1))
                                .tint(Color(hex: type.colorHex))
                            Text("\(completed)/\(goal)").font(.caption.monospacedDigit()).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent activity").font(.headline).foregroundColor(.white)
                Spacer()
                Button("See all") { onBrowseWorkouts() }
                    .font(.caption.weight(.semibold)).foregroundColor(Theme.textSecondary)
            }
            if store.historyEntries.isEmpty {
                Text("Finish a workout and your recent activity will appear here.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
            } else {
                ForEach(store.historyEntries.sorted(by: { $0.completedAt > $1.completedAt }).prefix(3)) { entry in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: entry.workoutType.colorHex)).frame(width: 8, height: 8)
                        Text(entry.workoutName).font(.subheadline.weight(.medium)).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        Text(entry.completedAt, style: .relative)
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 48)).foregroundColor(.white)
            Text("Build your first session")
                .font(.title2.bold()).foregroundColor(.white)
            Text("Create a workout from scratch, or collect exercises in your database first. Your dashboard will grow with you.")
                .font(.subheadline).foregroundColor(Theme.textSecondary)
            Button(action: onCreateWorkout) {
                Label("Create workout", systemImage: "plus")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 13).background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            Button(action: onBrowseDatabase) {
                Label("Open exercise database", systemImage: "cylinder.split.1x2")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13).background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
        }
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var workoutPicker: some View {
        NavigationStack {
            List(readyWorkouts) { workout in
                Button {
                    showingWorkoutPicker = false
                    playerWorkout = workout
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.name).foregroundColor(.white)
                            Text("\(workout.sectionCount) sections · \(durationText(workout.totalDuration))")
                                .font(.caption).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: workout.type.iconName).foregroundColor(Color(hex: workout.colorHex))
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Choose workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingWorkoutPicker = false } }
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return "\(minutes) min"
    }
}

#Preview {
    HomeDashboardView(onBrowseWorkouts: {}, onBrowseDatabase: {}, onCreateWorkout: {})
        .environmentObject(WorkoutStore())
        .environmentObject(DatabaseStore.shared)
        .preferredColorScheme(.dark)
}
