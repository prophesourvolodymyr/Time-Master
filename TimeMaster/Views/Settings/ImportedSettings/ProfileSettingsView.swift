import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var showsProfileEditor = false
    @State private var showsCollectibles = false
    @State private var showsRankedLevels = false
    @State private var errorMessage: String?
    @State private var showsVerification = false

    var body: some View {
        EverSettingsPage(title: "Profile") {
            if profileStore.isReadOnly {
                EverSettingsSection(
                    title: "Profile unavailable",
                    detail: "Existing data has not been replaced. Profile editing is read-only until your saved profile can be loaded."
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
                title: "Profile",
                detail: "Your identity and profile levels are saved locally in TimeMaster."
            ) {
                Button {
                    showsProfileEditor = true
                } label: {
                    EverActionRow(
                        title: "Edit Profile",
                        detail: profileStore.isReadOnly
                            ? "Profile unavailable · read-only"
                            : "\(profileStore.profile.displayName) · @\(profileStore.profile.handle)",
                        symbol: "person.crop.circle"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(profileStore.isReadOnly)
                Button {
                    showsRankedLevels = true
                } label: {
                    EverActionRow(
                        title: "Ranked Elo Levels",
                        detail: profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo · Local profile level" }
                            ?? "Choose your local profile and movement levels",
                        symbol: "bolt.shield"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(profileStore.isReadOnly)
                .accessibilityIdentifier("settings-ranked-levels")
            }

            EverSettingsSection(
                title: "Posts and privacy",
                detail: "Choose what appears in visitor preview. Individual posts keep their own audience and reply settings."
            ) {
                NavigationLink {
                    ProfilePrivacySettingsView()
                } label: {
                    EverActionRow(title: "Profile Privacy", symbol: "hand.raised") {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }


            EverSettingsSection(
                title: "Collectibles",
                detail: "Local cosmetic previews only. No purchases, trading, or blockchain transactions."
            ) {
                Button {
                    showsCollectibles = true
                } label: {
                    EverActionRow(title: "Collectibles", symbol: "square.stack.3d.up") {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            EverSettingsSection(
                title: "Checkmark",
                detail: "Earn a training milestone or preview a badge. Paid plans are Preview only."
            ) {
                Button {
                    showsVerification = true
                } label: {
                    EverActionRow(
                        title: profileStore.snapshot.badgePreview == nil
                            ? "Verification"
                            : "Manage checkmark preview",
                        symbol: "checkmark"
                    ) {
                        if let tier = profileStore.snapshot.badgePreview {
                            ProfileVerificationBadge(tier: tier)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(EverColor.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .everSheet(isPresented: $showsProfileEditor) {
            LocalProfileEditorView()
        }
        .everSheet(isPresented: $showsCollectibles) {
            ProfileCollectiblesView()
        }
        .everSheet(isPresented: $showsRankedLevels) {
            RankedLevelsEditorView()
        }
        .everSheet(isPresented: $showsVerification) {
            ProfileVerificationView()
        }
        .profileErrorAlert($errorMessage)
    }
}
