import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var showsProfileEditor = false
    @State private var showsCollectibles = false
    @State private var showsRankedRanks = false
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
                detail: "Your profile stays local. Competitive ratings belong to your Ranked account."
            ) {
                Button {
                    showsProfileEditor = true
                } label: {
                    SettingsActionRow(
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
                    showsRankedRanks = true
                } label: {
                    SettingsActionRow(
                        title: "Ranked Ranks",
                        detail: "Earned movement ratings and placement",
                        symbol: "bolt.shield"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-ranked-ranks")
            }

            EverSettingsSection(
                title: "Posts and privacy",
                detail: "Choose what appears in visitor preview. Individual posts keep their own audience and reply settings."
            ) {
                NavigationLink {
                    ProfilePrivacySettingsView()
                } label: {
                    SettingsActionRow(title: "Profile Privacy", symbol: "hand.raised") {
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
                    SettingsActionRow(title: "Collectibles", symbol: "square.stack.3d.up") {
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
                    SettingsActionRow(
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
        .everSheet(isPresented: $showsRankedRanks) {
            RankedTierGalleryView()
        }
        .everSheet(isPresented: $showsVerification) {
            ProfileVerificationView()
        }
        .profileErrorAlert($errorMessage)
    }
}
