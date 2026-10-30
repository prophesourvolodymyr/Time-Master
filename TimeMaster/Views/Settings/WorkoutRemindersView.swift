import SwiftUI
import UserNotifications

struct WorkoutRemindersView: View {
    @EnvironmentObject private var store: WorkoutStore

    // MARK: - State

    @State private var preferences: NotificationPreferences = NotificationManager.shared.preferences
    @State private var permissionDenied = false
    @State private var showSettingsAlert  = false
    @State private var testStatus: TestStatus = .idle

    private enum TestStatus: Equatable {
        case idle, sending, scheduled, denied
        case failed(String)
    }

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
                                .font(TimeMasterFont.body())
                                .foregroundColor(.white)
                            Text("Warm, schedule-aware reminders")
                                .font(TimeMasterFont.caption())
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
                    .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 10), action: { handleToggle(!preferences.isEnabled) })
                } header: {
                    Text("Reminders")
                        .foregroundColor(Theme.textSecondary)
                        .font(TimeMasterFont.caption())
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
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
                        .onChange(of: pickerTime) { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            preferences.reminderHour = comps.hour ?? 9
                            preferences.reminderMinute = comps.minute ?? 0
                            commit()
                        }
                    } header: {
                        Text("Workout Time")
                            .foregroundColor(Theme.textSecondary)
                            .font(TimeMasterFont.caption())
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    SwiftUI.Section {
                        Stepper(value: $preferences.reminderLeadMinutes, in: 0...60, step: 5) {
                            Text("Remind \(preferences.reminderLeadMinutes) min before")
                                .foregroundColor(.white)
                        }
                        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { preferences.reminderLeadMinutes = preferences.reminderLeadMinutes >= 60 ? 0 : preferences.reminderLeadMinutes + 5 })
                        .onChange(of: preferences.reminderLeadMinutes) { _ in commit() }
                        Toggle("Streak milestones", isOn: $preferences.streakMotivationEnabled)
                            .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { preferences.streakMotivationEnabled.toggle() })
                            .onChange(of: preferences.streakMotivationEnabled) { _ in commit() }
                        Toggle("Missed-day nudges", isOn: $preferences.missedDayNudgesEnabled)
                            .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { preferences.missedDayNudgesEnabled.toggle() })
                            .onChange(of: preferences.missedDayNudgesEnabled) { _ in commit() }
                        Toggle("Rest-day affirmations", isOn: $preferences.restDayAffirmationsEnabled)
                            .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { preferences.restDayAffirmationsEnabled.toggle() })
                            .onChange(of: preferences.restDayAffirmationsEnabled) { _ in commit() }
                    } header: {
                        Text("Notification Style")
                            .foregroundColor(Theme.textSecondary)
                            .font(TimeMasterFont.caption())
                    }
                    .tint(.white)
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Info footer
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label {
                                Text("Training days come from your per-type schedules.")
                                    .font(TimeMasterFont.caption())
                                    .foregroundColor(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "bell")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Label {
                                Text("Missed-day nudges are checked against completed workouts.")
                                    .font(TimeMasterFont.caption())
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

                SwiftUI.Section {
                    Button(action: sendTest) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "bell.and.waves.left.and.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Send Test Notification")
                                    .font(TimeMasterFont.body())
                                    .foregroundColor(.white)
                                Text(testMessage)
                                    .font(TimeMasterFont.caption())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            if testStatus == .sending {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 10))
                    .disabled(testStatus == .sending)
                    .accessibilityIdentifier("reminders.test")
                    if testStatus == .denied {
                        Button("Open Notification Settings") {
                            NotificationManager.shared.openSystemSettings()
                        }
                        .foregroundColor(.white)
                        .keyNavTarget(shape: .capsule)
                    }
                } header: {
                    Text("Check")
                        .foregroundColor(Theme.textSecondary)
                        .font(TimeMasterFont.caption())
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.separator)
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
        .font(TimeMasterFont.body())
        .timeMasterNavigationTitle("Workout Reminders")
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
        .alert("Notifications Disabled", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                NotificationManager.shared.openSystemSettings()
            }
            Button("Cancel", role: .cancel) {
                preferences.isEnabled = false
                commit()
            }
        } message: {
            Text("Please enable notifications for Tmax in Settings to use this feature.")
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
            restDays: store.restDays,
            history: store.historyEntries
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

    private var testMessage: String {
        switch testStatus {
        case .idle: "Shows a banner within a few seconds"
        case .sending: "Sending…"
        case .scheduled: "Sent. It should appear in a few seconds."
        case .denied: "Notifications are off for Tmax."
        case .failed(let message): message
        }
    }

    private func sendTest() {
        testStatus = .sending
        Task {
            let outcome = await NotificationManager.shared.sendTestNotification()
            await MainActor.run {
                switch outcome {
                case .scheduled: testStatus = .scheduled
                case .denied: testStatus = .denied
                case .failed(let message): testStatus = .failed(message)
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
