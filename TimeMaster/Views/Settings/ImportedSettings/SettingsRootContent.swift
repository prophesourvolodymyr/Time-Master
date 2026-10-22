import SwiftUI

struct SettingsRootContent: View {
    let initialDestination: SettingsDestination?
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @ObservedObject private var serverSettings = ServerSettings.shared
    @AppStorage("extra_rest_seconds") private var extraRestSeconds = 15
    @State private var showMusicSettings = false
    @State private var showServerSettings = false

    var body: some View {
        Group {
            if let initialDestination {
                SettingsDestinationContent(destination: initialDestination)
            } else {
                EverSettingsPage(title: "Settings") {
                    EverSettingsSection(
                        title: "Profile",
                        detail: "Your profile is stored on this device. Account sign-in does not synchronize your local profile."
                    ) {
                        SettingsDestinationLink(destination: .profile)
                        SettingsDestinationLink(destination: .privacy)
                    }

                    EverSettingsSection(title: "Account & Sync") {
                        SettingsDestinationLink(destination: .account)
                        SettingsDestinationLink(destination: .databaseSync)
                    }

                    EverSettingsSection(title: "Workout") {
                        SettingsDestinationLink(destination: .workoutTypes)
                        SettingsDestinationLink(destination: .motivation)
                        musicSettingsButton {
                            EverActionRow(title: "Background Music", symbol: "music.note") {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(EverColor.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        SettingsDestinationLink(destination: .notifications)
                        Stepper(value: $extraRestSeconds, in: 5...120, step: 5) {
                            EverActionRow(
                                title: "Extra Rest Time",
                                detail: "\(extraRestSeconds) seconds added per tap during rest",
                                symbol: "plus.circle"
                            )
                        }
                        .font(TimeMasterFont.rowTitle())
                        .frame(minHeight: EverLayout.standardRowMinimum)
                        .accessibilityLabel("Extra rest time")
                        .accessibilityValue("\(extraRestSeconds) seconds")
                    }

                    EverSettingsSection(title: "Data") {
                        SettingsDestinationLink(destination: .backup)
                    }

                    EverSettingsSection(title: "AI & Import") {
                        SettingsDestinationLink(destination: .exerciseAI)
                        serverSettingsButton {
                            EverActionRow(
                                title: "Companion Server",
                                detail: serverSettings.host,
                                symbol: "server.rack"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(EverColor.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    EverSettingsSection(title: "About") {
                        SettingsDestinationLink(destination: .about)
                    }
                }
                .accessibilityIdentifier("settings-root")
            }
        }
        .navigationDestination(for: SettingsDestination.self) { destination in
            SettingsDestinationContent(destination: destination)
        }
        .oneHandedActions(id: "settings", actions: [
            ReachabilityAction("music", title: "Background Music") {
                musicSettingsButton {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .accessibilityLabel("Background Music")
            },
            ReachabilityAction("server", title: "Companion Server") {
                serverSettingsButton {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.white)
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .accessibilityLabel("Companion Server")
            }
        ])
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsView(settings: serverSettings)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showMusicSettings) {
            MusicSettingsView(library: musicLibraryStore)
                .environmentObject(workoutStore)
        }
        #else
        .sheet(isPresented: $showMusicSettings) {
            MusicSettingsView(library: musicLibraryStore)
                .environmentObject(workoutStore)
        }
        #endif
    }

    private func musicSettingsButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button { showMusicSettings = true } label: { label() }
    }

    private func serverSettingsButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button { showServerSettings = true } label: { label() }
    }
}

private struct SettingsDestinationLink: View {
    let destination: SettingsDestination

    var body: some View {
        NavigationLink(value: destination) {
            EverActionRow(title: destination.title, symbol: destination.symbol) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EverColor.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDestinationContent: View {
    let destination: SettingsDestination
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject private var profileStore: LocalProfileStore

    @ViewBuilder
    var body: some View {
        switch destination {
        case .profile:
            ProfileSettingsView()
        case .account:
            CloudAccountSettingsView()
        case .databaseSync:
            DatabaseSyncSettingsView()
        case .workoutTypes:
            WorkoutTypesSettingsView()
        case .motivation:
            MotivationSettingsView()
        case .backup:
            BackupView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
                .environmentObject(musicLibraryStore)
                .environmentObject(profileStore)
        case .notifications:
            WorkoutRemindersView()
        case .privacy:
            ProfilePrivacySettingsView()
        case .exerciseAI:
            ExerciseAISettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
