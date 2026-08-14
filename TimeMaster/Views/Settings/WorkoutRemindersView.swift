import SwiftUI
import UserNotifications

struct WorkoutRemindersView: View {
    @EnvironmentObject private var store: WorkoutStore

    // MARK: - State

    @State private var preferences: NotificationPreferences = NotificationManager.shared.preferences
    @State private var permissionDenied = false
    @State private var showSettingsAlert  = false

    // Binding-style DatePicker helper
    @State private var pickerTime: Date = {
        let s = NotificationManager.shared.preferences
        var c = DateComponents()
        c.hour   = s.reminderHour
        c.minute = s.reminderMinute
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
                            Text("Warm, schedule-aware reminders")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { preferences.isEnabled },
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
                if preferences.isEnabled {
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
                            preferences.reminderHour = comps.hour ?? 9
                            preferences.reminderMinute = comps.minute ?? 0
                            commit()
                        }
                    } header: {
                        Text("Workout Time")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    SwiftUI.Section {
                        Stepper(value: $preferences.reminderLeadMinutes, in: 0...60, step: 5) {
                            Text("Remind \(preferences.reminderLeadMinutes) min before")
                                .foregroundColor(.white)
                        }
                        .onChange(of: preferences.reminderLeadMinutes) { _ in commit() }
                        Toggle("Streak milestones", isOn: $preferences.streakMotivationEnabled)
                            .onChange(of: preferences.streakMotivationEnabled) { _ in commit() }
                        Toggle("Missed-day nudges", isOn: $preferences.missedDayNudgesEnabled)
                            .onChange(of: preferences.missedDayNudgesEnabled) { _ in commit() }
                        Toggle("Rest-day affirmations", isOn: $preferences.restDayAffirmationsEnabled)
                            .onChange(of: preferences.restDayAffirmationsEnabled) { _ in commit() }
                    } header: {
                        Text("Notification Style")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .tint(.white)
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Info footer
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label {
                                Text("Training days come from your per-type schedules.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "bell")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Label {
                                Text("Missed-day nudges are checked against completed workouts.")
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
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.listStyle(.insetGrouped)
#endif
#endif
#endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Workout Reminders")
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
        .alert("Notifications Disabled", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            Button("Cancel", role: .cancel) {
                preferences.isEnabled = false
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
            preferences.isEnabled = false
            commit()
            return
        }
        NotificationManager.shared.requestPermission { granted in
            if granted {
                preferences.isEnabled = true
                commit()
            } else {
                showSettingsAlert = true
            }
        }
    }

    private func commit() {
        NotificationManager.shared.applyPreferences(
            preferences,
            schedules: store.typeSchedules,
            restDays: store.restDays
        )
    }

    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied, preferences.isEnabled {
                    preferences.isEnabled = false
                    commit()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutRemindersView()
            .preferredColorScheme(.dark)
    }
}
