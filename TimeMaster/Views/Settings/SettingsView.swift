import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var outdoorStore: OutdoorActivityStore
    @EnvironmentObject var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject var profileStore: LocalProfileStore
    @ObservedObject var serverSettings: ServerSettings = .shared
    @AppStorage("extra_rest_seconds") private var extraRestSeconds: Int = 15

    private let isPresentedModally: Bool
    @State private var showServerSettings = false
    @State private var showMusicSettings = false
    @State private var showProfileEditor = false
    @State private var showCollectibles = false
    @State private var showVerification = false
    @State private var showRankedLevels = false
    @State private var errorMessage: String?

    init(isPresentedModally: Bool = false) {
        self.isPresentedModally = isPresentedModally
    }

    var body: some View {
        NavigationStack {
            ProfileSettingsPage(title: "Settings") {
                accountSection
                workoutSection
                dataSection
                advancedSection
                aboutSection
            }
            .toolbar {
                if isPresentedModally {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            ProfilePillLabel(title: "Close", symbol: "xmark", isSelected: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
            .sheet(isPresented: $showProfileEditor) {
                LocalProfileEditorView()
            }
            .sheet(isPresented: $showCollectibles) {
                ProfileCollectiblesView()
            }
            .sheet(isPresented: $showVerification) {
                ProfileVerificationView()
            }
            .sheet(isPresented: $showRankedLevels) {
                RankedLevelsEditorView()
            }
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
            .profileErrorAlert($errorMessage)
        }
    }

    private var accountSection: some View {
        ProfileSettingsSection(
            title: "Account & Profile",
            footer: "Your profile is stored on this device. There is no online account, login, or profile sync."
        ) {
            if profileStore.isReadOnly {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Profile storage is read-only")
                        .font(TimeMasterFont.rowTitle())
                    Text(profileStore.errorMessage ?? "Your saved profile could not be read. Existing data has not been replaced.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                    Button("Retry loading profile") {
                        profileStore.reload()
                        if profileStore.isReadOnly {
                            errorMessage = profileStore.errorMessage
                        }
                    }
                    .buttonStyle(ProfilePrimaryButtonStyle())
                }
                .padding(ProfileStyle.inset)
            }
            Button { showProfileEditor = true } label: {
                ProfileSettingsRow(
                    icon: "person.crop.circle",
                    title: "Edit Profile",
                    detail: profileStore.isReadOnly
                        ? "Profile unavailable · read-only"
                        : "\(profileStore.profile.displayName) · @\(profileStore.profile.handle)"
                )
            }
            .disabled(profileStore.isReadOnly)
            Button { showRankedLevels = true } label: {
                ProfileSettingsRow(
                    icon: "bolt.shield",
                    title: "Ranked Elo Levels",
                    detail: profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo · Local profile level" } ?? "Choose your local profile and movement levels"
                )
            }
            .disabled(profileStore.isReadOnly)
            .accessibilityIdentifier("settings-ranked-levels")
            NavigationLink {
                ProfilePrivacySettingsView()
            } label: {
                ProfileSettingsRow(
                    icon: "hand.raised",
                    title: "Profile Privacy",
                    detail: "Choose what appears in your visitor preview"
                )
            }
            Button { showCollectibles = true } label: {
                ProfileSettingsRow(
                    icon: "square.stack.3d.up",
                    title: "Collectibles",
                    detail: "Local cosmetic previews · no purchases or trading"
                )
            }
            Button { showVerification = true } label: {
                ProfileSettingsRow(
                    icon: "checkmark.seal",
                    title: "Verification",
                    detail: "Training milestones and preview-only badges"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var workoutSection: some View {
        ProfileSettingsSection(title: "Workout") {
            NavigationLink {
                WorkoutTypesSettingsView()
            } label: {
                ProfileSettingsRow(
                    icon: "list.bullet.rectangle",
                    title: "Workout Types",
                    detail: "Customize and create workout categories"
                )
            }
            NavigationLink {
                MotivationSettingsView()
            } label: {
                ProfileSettingsRow(
                    icon: "quote.bubble",
                    title: "Motivational Quotes",
                    detail: "Spoken during workouts"
                )
            }
            musicSettingsButton {
                ProfileSettingsRow(
                    icon: "music.note",
                    title: "Background Music",
                    detail: "Plays during workouts"
                )
            }
            NavigationLink {
                WorkoutRemindersView()
            } label: {
                ProfileSettingsRow(
                    icon: "bell.badge",
                    title: "Workout Reminders",
                    detail: "Daily notifications on training days"
                )
            }
            VStack(alignment: .leading, spacing: 0) {
                ProfileSettingsRow(
                    icon: "plus.circle",
                    title: "Extra Rest Time",
                    detail: "Seconds added per tap during rest",
                    showsChevron: false
                )
                Stepper(value: $extraRestSeconds, in: 5...120, step: 5) {
                    Text("\(extraRestSeconds) seconds")
                        .font(TimeMasterFont.body().monospacedDigit())
                }
                .accessibilityLabel("Extra rest time")
                .accessibilityValue("\(extraRestSeconds) seconds")
                .padding(.horizontal, ProfileStyle.inset)
                .padding(.bottom, ProfileStyle.spacing)
            }
        }
        .buttonStyle(.plain)
    }

    private var dataSection: some View {
        ProfileSettingsSection(title: "Data") {
            NavigationLink {
                BackupView()
                    .environmentObject(workoutStore)
                    .environmentObject(outdoorStore)
                    .environmentObject(musicLibraryStore)
                    .environmentObject(profileStore)
            } label: {
                ProfileSettingsRow(
                    icon: "arrow.triangle.2.circlepath.icloud",
                    title: "Backup & Transfer",
                    detail: "Export or import your TimeMaster data"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var advancedSection: some View {
        ProfileSettingsSection(title: "AI & Import") {
            NavigationLink {
                ExerciseAISettingsView()
            } label: {
                ProfileSettingsRow(
                    icon: "sparkles",
                    title: "Exercise AI",
                    detail: "Name exercises from photos with OpenAI"
                )
            }
            serverSettingsButton {
                ProfileSettingsRow(
                    icon: "server.rack",
                    title: "Companion Server",
                    detail: serverSettings.host
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var aboutSection: some View {
        ProfileSettingsSection(title: "About TimeMaster") {
            settingsInfoRow(label: "Version", value: appVersion)
            settingsInfoRow(label: "Build", value: buildNumber)
        }
    }

    private func musicSettingsButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button { showMusicSettings = true } label: { label() }
    }

    private func serverSettingsButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button { showServerSettings = true } label: { label() }
    }

    private func settingsInfoRow(label: String, value: String) -> some View {
        HStack(spacing: ProfileStyle.spacing) {
            Text(label).font(TimeMasterFont.rowTitle())
            Spacer()
            Text(value)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .textSelection(.enabled)
        }
        .padding(ProfileStyle.inset)
        .frame(minHeight: 56)
    }

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
        .environmentObject(MusicLibraryStore())
        .environmentObject(LocalProfileStore())
        .preferredColorScheme(.dark)
}
