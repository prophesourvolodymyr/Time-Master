import SwiftUI
import UserNotifications

struct WorkoutRemindersView: View {

    // MARK: - State

    @State private var schedule: WorkoutSchedule = NotificationManager.shared.schedule
    @State private var permissionDenied = false
    @State private var showSettingsAlert  = false

    // Day labels: Calendar weekday 1=Sun … 7=Sat, displayed Mon–Sun
    private let dayOrder: [Int]    = [2, 3, 4, 5, 6, 7, 1]
    private let dayLabels: [Int: String] = [
        1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"
    ]

    // Binding-style DatePicker helper
    @State private var pickerTime: Date = {
        let s = NotificationManager.shared.schedule
        var c = DateComponents()
        c.hour   = s.hour
        c.minute = s.minute
        return Calendar.current.date(from: c) ?? Date()
    }()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                // MARK: Enable toggle
                SwiftUI.Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 34, height: 34)
                            Image(systemName: "bell.badge")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workout Reminders")
                                .font(.body)
                                .foregroundColor(.white)
                            Text("Daily push notifications on training days")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { schedule.isEnabled },
                            set: { newValue in handleToggle(newValue) }
                        ))
                        .labelsHidden()
                        .tint(.white)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Reminders")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.separator)

                // MARK: Day picker (only when enabled)
                if schedule.isEnabled {
                    SwiftUI.Section {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                            spacing: 0
                        ) {
                            ForEach(dayOrder, id: \.self) { day in
                                DayButton(
                                    label: dayLabels[day] ?? "",
                                    selected: schedule.days.contains(day)
                                ) {
                                    toggleDay(day)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Active Days")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Time picker
                    SwiftUI.Section {
                        DatePicker(
                            "Workout time",
                            selection: $pickerTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .foregroundColor(.white)
                        .onChange(of: pickerTime) { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            schedule.hour   = comps.hour   ?? 9
                            schedule.minute = comps.minute ?? 0
                            commit()
                        }
                    } header: {
                        Text("Workout Time")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Info footer
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label {
                                Text("At workout time: \"Time to Train\"")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "bell")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Label {
                                Text("2 hours later: \"Imagine the feeling now.\"")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "bell.badge")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Workout Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications Disabled", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                schedule.isEnabled = false
                commit()
            }
        } message: {
            Text("Please enable notifications for TimeMaster in Settings to use this feature.")
        }
        .onAppear { checkPermissionStatus() }
    }

    // MARK: - Helpers

    private func handleToggle(_ newValue: Bool) {
        guard newValue else {
            schedule.isEnabled = false
            commit()
            return
        }
        NotificationManager.shared.requestPermission { granted in
            if granted {
                schedule.isEnabled = true
                commit()
            } else {
                showSettingsAlert = true
            }
        }
    }

    private func toggleDay(_ day: Int) {
        if schedule.days.contains(day) {
            schedule.days.remove(day)
        } else {
            schedule.days.insert(day)
        }
        commit()
    }

    private func commit() {
        NotificationManager.shared.schedule = schedule
        NotificationManager.shared.scheduleWorkoutNotifications(schedule)
    }

    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied, schedule.isEnabled {
                    schedule.isEnabled = false
                    commit()
                }
            }
        }
    }
}

// MARK: - DayButton

private struct DayButton: View {
    let label:    String
    let selected: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(selected ? .black : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.white : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        WorkoutRemindersView()
            .preferredColorScheme(.dark)
    }
}
