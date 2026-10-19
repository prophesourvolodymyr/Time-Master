import SwiftUI

struct ProfilePrivacySettingsView: View {
    @EnvironmentObject var profileStore: LocalProfileStore
    @State private var errorMessage: String?

    var body: some View {
        ProfileSettingsPage(title: "Profile Privacy") {
            ProfileSettingsSection(
                title: "On this device",
                footer: "These settings only change the visitor preview on this device. They do not enforce network privacy, approve followers, or share your data. As the owner, you always keep access to every profile tab."
            ) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Local visitor preview")
                        .font(TimeMasterFont.rowTitle())
                    Text("Your profile has no online account or social backend. Changes save immediately on this device.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ProfileStyle.inset)
            }

            if profileStore.isReadOnly {
                ProfileSettingsSection(title: "Profile unavailable") {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text(profileStore.errorMessage ?? "Your saved profile could not be read. Existing data has not been replaced.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Privacy controls are read-only until the saved profile can be loaded.")
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
            }

            ProfileSettingsSection(
                title: "Profile visibility",
                footer: "A private profile hides its content in visitor preview. The visibility choices below are retained for when you turn Private Profile off."
            ) {
                privacyToggle(
                    "Private Profile",
                    detail: "Hide profile content from the visitor preview",
                    keyPath: \.isPrivate
                )
            }
            .disabled(profileStore.isReadOnly)

            ProfileSettingsSection(
                title: "Visitor content",
                footer: "Choose which tabs and details appear when previewing a non-private profile. Only profile-audience posts can appear; Only Me posts remain hidden."
            ) {
                privacyToggle(
                    "Posts",
                    detail: "Show the Posts tab in visitor preview",
                    keyPath: \.showPostsToVisitors
                )
                privacyToggle(
                    "Activity",
                    detail: "Show the Activity tab in visitor preview",
                    keyPath: \.showActivityToVisitors
                )
                privacyToggle(
                    "Reposts",
                    detail: "Show the Reposted tab in visitor preview",
                    keyPath: \.showRepostsToVisitors
                )
                privacyToggle(
                    "Achievements",
                    detail: "Show the achievements placeholder in visitor preview",
                    keyPath: \.showAchievements
                )
                privacyToggle(
                    "Links",
                    detail: "Show your profile links in visitor preview",
                    keyPath: \.showLinks
                )
            }
            .disabled(profileStore.isReadOnly)

            ProfileSettingsSection(
                title: "Replies",
                footer: "This is a local reply preference, not permission for online visitors. Visitor preview is always read-only. Individual posts also have their own reply setting."
            ) {
                privacyToggle(
                    "Allow Replies",
                    detail: "Enable replies in the local profile",
                    keyPath: \.allowReplies
                )
            }
            .disabled(profileStore.isReadOnly)
        }
        .profileErrorAlert($errorMessage)
    }

    private func privacyToggle(
        _ title: String,
        detail: String,
        keyPath: WritableKeyPath<LocalUserProfile, Bool>
    ) -> some View {
        Toggle(isOn: privacyBinding(keyPath)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TimeMasterFont.rowTitle())
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.green)
        .padding(ProfileStyle.inset)
        .frame(minHeight: 56)
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
