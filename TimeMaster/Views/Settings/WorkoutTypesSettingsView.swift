import SwiftUI

struct WorkoutTypesSettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @StateObject private var goals = GoalsManager.shared
    @State private var showAddSheet = false
    @State private var goalEditType: WorkoutType?
    @State private var scheduleEditType: WorkoutType?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    builtInGrid
                    if !store.customWorkoutTypes.isEmpty {
                        customGrid
                    }
                    createButton
                }
                .padding(16)
            }
        }
        .navigationTitle("Workout Types")
        .sheet(isPresented: $showAddSheet) {
            TypeEditorSheet { name, icon, color in
                store.addCustomType(name: name, iconName: icon, colorHex: color)
                showAddSheet = false
            }
        }
        .sheet(item: $goalEditType) { type in
            TypeGoalSheet(type: type)
        }
        .sheet(item: $scheduleEditType) { type in
            TypeScheduleSheet(type: type)
                .environmentObject(store)
        }
    }

    // MARK: - Built-in

    private var builtInGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Built-in")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(WorkoutType.builtIn), id: \.id) { type in
                    typeCard(type)
                }
            }
        }
    }

    // MARK: - Custom

    private var customGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(store.customWorkoutTypes), id: \.id) { type in
                    typeCard(type)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteCustomType(id: type.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func typeCard(_ type: WorkoutType) -> some View {
        let goal = goals.goal(for: type)
        return VStack(spacing: 0) {
            Button {
                goalEditType = type
            } label: {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(type.colorHex == "FFFFFF" ? .black : .white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: type.colorHex))
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if goal > 0 {
                        Text("\(goal)×/week")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if goal == 0 {
                    Text("Set goal")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
            }
            .padding(10)
            .background(Theme.surface)
            .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button {
                scheduleEditType = type
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: activeSchedule(for: type) == nil ? "calendar.badge.plus" : "calendar")
                    Text(activeSchedule(for: type) == nil ? "Set Schedule" : scheduleSummary(for: type))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private func activeSchedule(for type: WorkoutType) -> TypeSchedule? {
        store.typeSchedules.last { $0.type.id == type.id && $0.isActive }
    }

    private func scheduleSummary(for type: WorkoutType) -> String {
        guard let schedule = activeSchedule(for: type) else { return "Set Schedule" }
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let days = schedule.daysOfWeek.sorted().map { labels[$0 - 1] }.joined(separator: " ")
        return days.isEmpty ? "No days selected" : days
    }

    // MARK: - Create button

    private var createButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Create New Type")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

private struct TypeScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    let type: WorkoutType
    @State private var selectedDays: Set<Int>
    @State private var startDate: Date
    @State private var durationMonths: Int
    @State private var weeklyGoal: Int
    @State private var hasStartTime = false
    @State private var scheduleStartTime = Date()
    @State private var durationMinutes = 30
    @State private var didLoadSchedule = false

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(type: WorkoutType) {
        self.type = type
        _selectedDays = State(initialValue: [])
        _startDate = State(initialValue: Date())
        _durationMonths = State(initialValue: 3)
        _weeklyGoal = State(initialValue: max(GoalsManager.shared.goal(for: type), 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        dayPicker
                        dateSection
                        scheduleTimeSection
                        templateSection
                        goalSection
                        historySection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("\(type.name) Schedule")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white)
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Save") { save() }
                    .foregroundColor(selectedDays.isEmpty ? Color.white.opacity(0.3) : .white)
                    .disabled(selectedDays.isEmpty)
                                 }
            }
            .onAppear { loadActiveSchedule() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color(hex: type.colorHex))
                .cornerRadius(16)
            VStack(alignment: .leading, spacing: 3) {
                Text(type.name).font(.title3.bold()).foregroundColor(Theme.textPrimary)
                Text("Starting a new schedule archives the active one.")
                    .font(.caption).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training Days").font(.headline).foregroundColor(Theme.textPrimary)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if selectedDays.contains(day) { selectedDays.remove(day) }
                        else { selectedDays.insert(day) }
                    } label: {
                        Text(dayLabels[day - 1])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedDays.contains(day) ? .black : .white)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(selectedDays.contains(day) ? Color.white : Theme.surface)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Window").font(.headline).foregroundColor(Theme.textPrimary)
            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                .colorScheme(.dark).foregroundColor(Theme.textPrimary)
            Stepper(value: $durationMonths, in: 0...24) {
                Text(durationMonths == 0 ? "Runs indefinitely" : "Runs for \(durationMonths) month\(durationMonths == 1 ? "" : "s")")
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(14).background(Theme.surface).cornerRadius(12)
    }
    private var scheduleTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Window")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Toggle("Set a start time", isOn: $hasStartTime)
                .foregroundColor(Theme.textPrimary)
            if hasStartTime {
                DatePicker(
                    "Starts",
                    selection: $scheduleStartTime,
                    displayedComponents: .hourAndMinute
                )
                .colorScheme(.dark)
                .foregroundColor(Theme.textPrimary)
                Stepper(value: $durationMinutes, in: 5...240, step: 5) {
                    Text("Duration \(durationMinutes) min")
                        .foregroundColor(Theme.textPrimary)
                }
                Text(scheduleWindowText)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private var scheduleWindowText: String {
        let calendar = Calendar.current
        let start = scheduleStartTime.formatted(date: .omitted, time: .shortened)
        let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: scheduleStartTime) ?? scheduleStartTime
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }


    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Templates").font(.headline).foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                templateButton("Daily", days: Set(1...7))
                templateButton("Weekdays", days: [1, 2, 3, 4, 5])
                templateButton("Every Other Day", days: [1, 3, 5, 7])
                templateButton("Weekends", days: [6, 7])
            }
            HStack(spacing: 8) {
                durationButton("1 Month", months: 1)
                durationButton("2 Months", months: 2)
                durationButton("3 Months", months: 3)
                durationButton("Indefinite", months: 0)
            }
        }
        .padding(14).background(Theme.surface).cornerRadius(12)
    }

    private func templateButton(_ label: String, days: Set<Int>) -> some View {
        Button {
            selectedDays = days
            weeklyGoal = min(max(days.count, 1), 7)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.background)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func durationButton(_ label: String, months: Int) -> some View {
        Button(label) { durationMonths = months }
            .font(.caption.weight(.semibold))
            .foregroundColor(durationMonths == months ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(durationMonths == months ? Color.white : Theme.background)
            .cornerRadius(8)
            .buttonStyle(.plain)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Goal").font(.headline).foregroundColor(Theme.textPrimary)
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { value in
                    Button { weeklyGoal = value } label: {
                        Text("\(value)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(weeklyGoal == value ? .black : .white)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(weeklyGoal == value ? Color.white : Theme.background)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14).background(Theme.surface).cornerRadius(12)
    }

    private var historySection: some View {
        let history = store.typeSchedules.filter { $0.type.id == type.id && !$0.isActive }
        return Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Previous Schedules").font(.headline).foregroundColor(Theme.textPrimary)
                    ForEach(history) { schedule in
                        Text("\(schedule.startDate.formatted(date: .abbreviated, time: .omitted)) - \(schedule.endedAt?.formatted(date: .abbreviated, time: .omitted) ?? schedule.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(14).background(Theme.surface).cornerRadius(12)
            }
        }
    }

    private func save() {
        let schedule = TypeSchedule(
            folderID: nil,
            type: type,
            daysOfWeek: selectedDays,
            startDate: startDate,
            durationMonths: durationMonths,
            weeklyGoal: weeklyGoal,
            startTime: hasStartTime
                ? TimeOfDay(
                    hour: Calendar.current.component(.hour, from: scheduleStartTime),
                    minute: Calendar.current.component(.minute, from: scheduleStartTime)
                )
                : nil,
            durationMinutes: hasStartTime ? durationMinutes : nil
        )
        GoalsManager.shared.setGoal(weeklyGoal, for: type)
        store.addSchedule(schedule)
        dismiss()
    }

    private func loadActiveSchedule() {
        guard !didLoadSchedule else { return }
        didLoadSchedule = true
        guard let schedule = store.typeSchedules.last(where: { $0.type.id == type.id && $0.isActive }) else { return }
        selectedDays = schedule.daysOfWeek
        startDate = schedule.startDate
        durationMonths = schedule.durationMonths
        weeklyGoal = schedule.weeklyGoal
        if let startTime = schedule.startTime {
            hasStartTime = true
            var components = DateComponents()
            components.hour = startTime.hour
            components.minute = startTime.minute
            scheduleStartTime = Calendar.current.date(from: components) ?? Date()
        }
        durationMinutes = max(5, min(schedule.durationMinutes ?? 30, 240))
    }

}

// MARK: - Type Editor Sheet

private struct TypeEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var colorHex = "FFFFFF"

    private let sfIcons: [String] = [
        "dumbbell.fill", "figure.run", "heart.fill", "flame.fill",
        "figure.mind.and.body", "face.smiling.fill", "figure.cooldown",
        "figure.boxing", "figure.strengthtraining.traditional",
        "figure.step.training", "figure.play", "figure.walk",
        "figure.roll", "figure.jumprope", "figure.climbing",
        "figure.open.water.swim", "figure.indoor.cycle",
        "star.fill", "bolt.fill", "leaf.fill", "sun.max.fill",
        "moon.stars.fill", "snowflake", "water.waves",
    ]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        previewCard
                        nameSection
                        colorSection
                        iconSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Type")
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
                AppToolbar.item(placement: .confirmationAction) { Button("Create") {
                    onSave(name.trimmingCharacters(in: .whitespaces), selectedIcon, colorHex)
                }
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : .white)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                                 }
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(colorHex == "FFFFFF" ? .black : .white)
                .frame(width: 42, height: 42)
                .background(Color(hex: colorHex))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Type Name" : name)
                    .font(.headline)
                    .foregroundColor(name.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("e.g., Boxing", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Color").font(.headline).foregroundColor(Theme.textPrimary)
            IconColorPicker(selectedHex: $colorHex)
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon").font(.headline).foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(sfIcons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(selectedIcon == icon ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? Color.white : Theme.surface)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

// MARK: - Type Goal Sheet

private struct TypeGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let type: WorkoutType
    @State private var draft: Int

    init(type: WorkoutType) {
        self.type = type
        _draft = State(initialValue: max(GoalsManager.shared.goal(for: type), 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 30) {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: type.colorHex))
                            .frame(width: 80, height: 80)
                            .background(Color(hex: type.colorHex).opacity(0.15))
                            .cornerRadius(20)
                        Text(type.name)
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                    VStack(spacing: 10) {
                        Text("Weekly Goal")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { n in
                                Button { draft = n } label: {
                                    Text("\(n)")
                                        .font(.title3.weight(draft == n ? .bold : .medium))
                                        .foregroundColor(draft == n ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(draft == n ? Color.white : Theme.surface)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        Text(draft == 1 ? "Once a week" : "\(draft) times a week")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        GoalsManager.shared.setGoal(draft, for: type)
                        dismiss()
                    } label: {
                        Text("Save Goal")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(32)
            }
            .navigationTitle("Edit Goal")
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutTypesSettingsView()
            .environmentObject(WorkoutStore())
            .preferredColorScheme(.dark)
    }
}
