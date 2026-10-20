import SwiftUI

struct ProfilePrivacySettingsView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var errorMessage: String?

    var body: some View {
        EverSettingsPage(title: "Profile Privacy") {
            EverSettingsSection(
                title: "On this device",
                detail: "These settings only change the visitor preview on this device. They do not enforce network privacy, approve followers, or share your data. As the owner, you always keep access to every profile tab."
            ) {
                Text("Local visitor preview")
                    .font(TimeMasterFont.rowTitle())
                    .frame(minHeight: EverLayout.standardRowMinimum, alignment: .leading)
                Text("Your Tmax profile has no online account or social backend. Changes save immediately on this device.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(EverColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if profileStore.isReadOnly {
                EverSettingsSection(
                    title: "Profile unavailable",
                    detail: "Privacy controls are read-only until the saved profile can be loaded. Existing data has not been replaced."
                ) {
                    Text(profileStore.errorMessage ?? "Your saved profile could not be read.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(EverColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Retry loading profile") {
                        profileStore.reload()
                        if profileStore.isReadOnly {
                            errorMessage = profileStore.errorMessage
                        }
                    }
                    .buttonStyle(EverPrimaryButtonStyle())
                }
            }

            EverSettingsSection(
                title: "Profile visibility",
                detail: "A private profile hides its content in visitor preview. Your visibility choices are retained when Private Profile is on."
            ) {
                privacyToggle("Private Profile", keyPath: \.isPrivate)
            }
            .disabled(profileStore.isReadOnly)

            EverSettingsSection(
                title: "Visitor content",
                detail: "Choose the tabs and details shown for a non-private profile. Only profile-audience posts can appear; Only Me posts remain hidden."
            ) {
                privacyToggle("Posts", keyPath: \.showPostsToVisitors)
                privacyToggle("Activity", keyPath: \.showActivityToVisitors)
                privacyToggle("Reposts", keyPath: \.showRepostsToVisitors)
                privacyToggle("Achievements", keyPath: \.showAchievements)
                privacyToggle("Links", keyPath: \.showLinks)
            }
            .disabled(profileStore.isReadOnly)

            EverSettingsSection(
                title: "Replies",
                detail: "This is a local reply preference, not permission for online visitors. Visitor preview is always read-only. Individual posts retain their own reply setting."
            ) {
                privacyToggle("Allow Replies", keyPath: \.allowReplies)
            }
            .disabled(profileStore.isReadOnly)
        }
        .profileErrorAlert($errorMessage)
    }

    private func privacyToggle(
        _ title: String,
        keyPath: WritableKeyPath<LocalUserProfile, Bool>
    ) -> some View {
        Toggle(title, isOn: privacyBinding(keyPath))
            .font(TimeMasterFont.rowTitle())
            .tint(EverColor.accent)
            .frame(minHeight: EverLayout.standardRowMinimum)
    }

    private func privacyBinding(_ keyPath: WritableKeyPath<LocalUserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profileStore.profile[keyPath: keyPath] },
            set: { value in
                var updated = profileStore.profile
                updated[keyPath: keyPath] = value
                do {
                    try profileStore.updateProfile(updated)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }
}
