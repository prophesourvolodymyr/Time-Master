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
                    SettingsMenuSection(title: "Profile") {
                        SettingsDestinationLink(destination: .profile)
                        SettingsDestinationLink(destination: .privacy)
                    }

                    SettingsMenuSection(title: "Account & Sync") {
                        SettingsDestinationLink(destination: .account)
                        SettingsDestinationLink(destination: .databaseSync)
                    }

                    SettingsMenuSection(title: "Workout") {
                        SettingsDestinationLink(destination: .workoutTypes)
                        SettingsDestinationLink(destination: .motivation)
                        musicSettingsButton {
                            SettingsMenuCard {
                                SettingsActionRow(title: "Background Music", symbol: "music.note") {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(EverColor.textTertiary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        SettingsDestinationLink(destination: .notifications)
                        SettingsMenuCard {
                            VStack(alignment: .leading, spacing: EverSpacing.x3) {
                                SettingsActionRow(title: "Extra Rest Time", symbol: "plus.circle")
                                Stepper(value: $extraRestSeconds, in: 5...120, step: 5) {
                                    Text("\(extraRestSeconds) sec per tap")
                                        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                                        .foregroundStyle(EverColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(minHeight: EverLayout.minimumTouchTarget)
                                .accessibilityLabel("Extra rest time")
                                .accessibilityValue("\(extraRestSeconds) seconds")
                            }
                        }
                    }

                    SettingsMenuSection(title: "Data") {
                        SettingsDestinationLink(destination: .backup)
                    }

                    SettingsMenuSection(title: "AI & Import") {
                        SettingsDestinationLink(destination: .exerciseAI)
#if os(macOS)
                        SettingsDestinationLink(destination: .agentAccess)
#endif
                        serverSettingsButton {
                            SettingsMenuCard {
                                SettingsActionRow(
                                    title: "Companion Server",
                                    detail: serverSettings.host,
                                    symbol: "server.rack"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(EverColor.textTertiary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                    }

                    SettingsMenuSection(title: "About") {
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
                #if os(macOS)
                .frame(
                    minWidth: EverLayout.popupMaximumWidth,
                    idealWidth: EverLayout.popupMaximumWidth,
                    minHeight: EverLayout.standardRowMinimum * 10,
                    idealHeight: EverLayout.standardRowMinimum * 12
                )
                #endif
                .everSheetBackground()
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
                .frame(
                    minWidth: EverLayout.popupMaximumWidth,
                    idealWidth: EverLayout.maximumReadableWidth,
                    minHeight: EverLayout.standardRowMinimum * 10,
                    idealHeight: EverLayout.standardRowMinimum * 12
                )
                .everSheetBackground()
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
            SettingsMenuCard {
                SettingsActionRow(title: destination.title, symbol: destination.symbol) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EverColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityIdentifier("settings-destination-\(destination.rawValue)")
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
        case .agentAccess:
            AgentAccessSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
