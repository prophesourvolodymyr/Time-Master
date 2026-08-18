import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var outdoorStore: OutdoorActivityStore
    @ObservedObject var serverSettings: ServerSettings = .shared
    @AppStorage("extra_rest_seconds") private var extraRestSeconds: Int = 15

    @State private var showServerSettings = false
    @State private var showMusicSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    // MARK: Backup & Transfer
                    SwiftUI.Section {
                        NavigationLink {
                            BackupView()
                                .environmentObject(workoutStore)
                                .environmentObject(outdoorStore)
                        } label: {
                            settingsRow(
                                icon: "arrow.triangle.2.circlepath.icloud",
                                title: "Backup & Transfer",
                                subtitle: "Export or import all your data"
                            )
                        }
                    } header: {
                        Text("Data")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    #if os(iOS)
                    // MARK: Outdoor Maps
                    SwiftUI.Section {
                        NavigationLink {
                            OutdoorMapOfflineSettingsView()
                        } label: {
                            settingsRow(
                                icon: "map",
                                title: "Offline Maps",
                                subtitle: "Download map areas for outdoor recording"
                            )
                        }
                    } header: {
                        Text("Outdoor")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)
                    #endif

                    // MARK: Motivation + Music
                    SwiftUI.Section {
                        NavigationLink {
                            WorkoutTypesSettingsView()
                        } label: {
                            settingsRow(
                                icon: "list.bullet.rectangle",
                                title: "Workout Types",
                                subtitle: "Customize and create workout categories"
                            )
                        }
                        NavigationLink {
                            MotivationSettingsView()
                        } label: {
                            settingsRow(
                                icon: "quote.bubble",
                                title: "Motivational Quotes",
                                subtitle: "Spoken during workouts"
                            )
                        }
                        Button {
                            showMusicSettings = true
                        } label: {
                            settingsRow(
                                icon: "music.note",
                                title: "Background Music",
                                subtitle: "Plays during workouts"
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            WorkoutRemindersView()
                        } label: {
                            settingsRow(
                                icon: "bell.badge",
                                title: "Workout Reminders",
                                subtitle: "Daily push notifications on training days"
                            )
                        }
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Extra Rest Time")
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text("Seconds added per tap during rest")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Stepper(
                                value: $extraRestSeconds,
                                in: 5...120,
                                step: 5
                            ) {
                                Text("\(extraRestSeconds)s")
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(minWidth: 36, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Workout")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Exercise AI
                    SwiftUI.Section {
                        NavigationLink {
                            ExerciseAISettingsView()
                        } label: {
                            settingsRow(
                                icon: "sparkles",
                                title: "Exercise AI",
                                subtitle: "Name exercises from photos with OpenAI"
                            )
                        }
                    } header: {
                        Text("AI")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: Server Settings
                    SwiftUI.Section {
                        Button {
                            showServerSettings = true
                        } label: {
                            settingsRow(
                                icon: "server.rack",
                                title: "Companion Server",
                                subtitle: serverSettings.host == "localhost"
                                    ? "Simulator mode"
                                    : serverSettings.host
                            )
                        }
                    } header: {
                        Text("Import")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)

                    // MARK: App info
                    SwiftUI.Section {
                        settingsInfoRow(label: "Version", value: appVersion)
                        settingsInfoRow(label: "Build", value: buildNumber)
                    } header: {
                        Text("About")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)
                }
                #if os(iOS)
                #if os(iOS)
#if os(iOS)
#if os(iOS)
.listStyle(.insetGrouped)
#endif
#endif
#endif
                #endif
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showServerSettings) {
                ServerSettingsView(settings: serverSettings)
            }
            .fullScreenCover(isPresented: $showMusicSettings) {
                MusicSettingsView()
                    .environmentObject(workoutStore)
            }
        }
    }

    // MARK: - Row helpers

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func settingsInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    SettingsView()
        .environmentObject(WorkoutStore())
        .environmentObject(OutdoorActivityStore())
        .preferredColorScheme(.dark)
}
