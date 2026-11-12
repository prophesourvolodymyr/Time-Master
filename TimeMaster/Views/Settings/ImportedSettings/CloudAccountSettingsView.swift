import SwiftUI

struct CloudAccountSettingsView: View {
    @ObservedObject private var account = CloudAccountStore.shared
    @ObservedObject private var ranked = RankedAccountStore.shared
    @State private var reconnecting = false
    @State private var showPasswordForm = false
    @State private var newPassword = ""
    @State private var passwordConfirmation = ""
    @State private var alias = ""
    @State private var listed = false
    @State private var legacyLogin = ""
    @State private var legacyPassword = ""
    @State private var showLegacyLink = false
    @State private var confirmDeletion = false
    @State private var savingPrivacy = false
    @State private var privacyError: String?
    private enum Field: Hashable { case newPassword, passwordConfirmation, legacyLogin, legacyPassword }
    @FocusState private var focusedField: Field?

    var body: some View {
        Group {
            if account.session == nil || reconnecting {
                CloudAccountLoginView(reconnecting: $reconnecting, email: account.email ?? "")
                    .transition(.opacity)
            } else {
                accountPage
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: account.session == nil || reconnecting)
        .tint(Theme.toolbarOrange)
        .task {
            await ranked.restore()
            loadRankedIdentity()
            if account.providerSettings == nil { await account.loadProviderSettings() }
        }
        .onChange(of: ranked.identity?.publicID) { _ in loadRankedIdentity() }
        .onChange(of: account.passwordRecovery) { recovery in
            if recovery { focusedField = .newPassword }
        }
        .confirmationDialog("Delete your Tmax account?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Delete cloud account", role: .destructive) { Task { await account.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your cloud exercise database and account, including exercise Ranked and Physique records and ordinary shared media. Narrow lawful safety holds may remain under the published policy. Camera collection stops; an active match follows its service-owned finality. The local library stays on this device. Export a ZIP first if you need a separate backup.")
        }
        .accessibilityIdentifier("cloud-account-settings")
    }

    private var accountPage: some View {
        EverSettingsPage(title: "Tmax Account") {
            EverSettingsSection(title: "One account", detail: "Exercise-database sync and Ranked share this secure account. Your local Profile, workouts, history and music are not synchronized.") {
                if let session = account.session {
                    SettingsActionRow(title: session.email ?? "Signed in", detail: "Tmax account", symbol: "person.crop.circle.badge.checkmark")
                    NavigationLink {
                        DatabaseSyncSettingsView()
                    } label: {
                        SettingsActionRow(title: "Database Sync", symbol: "arrow.triangle.2.circlepath.icloud") {
                            Image(systemName: "chevron.right").foregroundStyle(EverColor.textTertiary)
                        }
                    }.keyNavPlainButtonStyle()
                }
            }

            if let message = account.configurationError { messageSection(title: "Account configuration", message: message, symbol: "exclamationmark.triangle") }
            if !account.restored {
                messageSection(title: "Preparing account", message: "Local startup must finish before connecting an account.", symbol: "hourglass")
            }
            if account.passwordRecovery || showPasswordForm { passwordForm }
            signedInActions; rankedIdentity; legacyLink; deletionSection
            if let error = account.error { messageSection(title: "Account needs attention", message: error, symbol: "exclamationmark.triangle") }
            if let notice = account.notice { messageSection(title: "Account update", message: notice, symbol: "info.circle") }
            if account.busy {
                HStack(spacing: EverSpacing.x2) {
                    TmaxLoadingIndicator()
                    Text("Connecting securely…").font(TimeMasterFont.caption())
                }.accessibilityElement(children: .combine)
            }
            EverSettingsSection(title: "Local backup", detail: "ZIP export is always available, signed in or out and with sync turned off.") {
                NavigationLink { BackupView() } label: {
                    SettingsActionRow(title: "Backup & Transfer", symbol: "archivebox") {
                        Image(systemName: "chevron.right").foregroundStyle(EverColor.textTertiary)
                    }
                }.keyNavPlainButtonStyle()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .slotNavigationInteractionDisabled(focusedField != nil)
    }

    private var passwordForm: some View {
        EverSettingsSection(title: account.passwordRecovery ? "Reset password" : "Change password") {
            Text("New password").font(TimeMasterFont.rowTitle())
            SecureField("At least 12 characters", text: $newPassword)
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next).onSubmit { focusedField = .passwordConfirmation }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            Text("Confirm new password").font(TimeMasterFont.rowTitle())
            SecureField("Repeat new password", text: $passwordConfirmation)
                .focused($focusedField, equals: .passwordConfirmation)
                .submitLabel(.done)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            if !passwordConfirmation.isEmpty && newPassword != passwordConfirmation {
                Text("Passwords do not match.").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
            Button("Save new password") {
                focusedField = nil
                Task {
                    await account.updatePassword(newPassword)
                    if account.error == nil { newPassword = ""; passwordConfirmation = ""; showPasswordForm = false }
                }
            }.buttonStyle(EverPrimaryButtonStyle())
                .disabled(account.busy || newPassword.count < 12 || newPassword != passwordConfirmation || account.session == nil)
        }.textFieldStyle(.roundedBorder).font(TimeMasterFont.body())
    }

    private var signedInActions: some View {
        EverSettingsSection(title: "Account security") {
            Button("Sign in again or switch account") { reconnecting = true }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
            Button("Change password") { showPasswordForm.toggle() }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
            Button("Sign out on this device", role: .destructive) { Task { await account.signOut() } }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
                .accessibilityIdentifier("ranked-account-signout")
            Text("Signing out stops database sync first. Local changes are kept with their original account library.")
                .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
        }
    }

    @ViewBuilder private var rankedIdentity: some View {
        if ranked.identity != nil {
            EverSettingsSection(title: "Ranked identity", detail: "Only the competitive alias and earned exercise ratings are public when you opt in. Local profile and camera media are not uploaded.") {
                Text("Competitive alias").font(TimeMasterFont.rowTitle())
                TextField("Public display name", text: $alias).textFieldStyle(.roundedBorder).font(TimeMasterFont.body()).keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                Toggle("Appear in public leaderboards", isOn: $listed).font(TimeMasterFont.secondary()).keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { listed.toggle() })
                Button("Save public identity") {
                    savingPrivacy = true
                    Task {
                        do { try await ranked.updatePublicIdentity(name: alias, listed: listed); privacyError = nil }
                        catch { privacyError = error.localizedDescription }
                        savingPrivacy = false
                    }
                }.buttonStyle(EverPrimaryButtonStyle())
                    .disabled(account.busy || savingPrivacy || alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let privacyError { Text(privacyError).font(TimeMasterFont.caption()) }
            }
        } else if let error = ranked.error {
            messageSection(title: "Ranked", message: error, symbol: "exclamationmark.triangle")
            Button("Refresh Ranked account") { Task { await ranked.refresh() } }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
        }
    }

    private var legacyLink: some View {
        EverSettingsSection(title: "Existing Ranked account", detail: "Link before playing with a new TimeMaster account. Your old private login and password prove ownership; email or display-name matches are never used to merge accounts.") {
            DisclosureGroup(isExpanded: $showLegacyLink) {
                VStack(alignment: .leading, spacing: EverSpacing.x3) {
                    Text("Old Ranked private login").font(TimeMasterFont.rowTitle())
                    TextField("Private login", text: $legacyLogin)
                        .autocorrectionDisabled().focused($focusedField, equals: .legacyLogin)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                    Text("Old Ranked password").font(TimeMasterFont.rowTitle())
                    SecureField("Password", text: $legacyPassword).focused($focusedField, equals: .legacyPassword).keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                    Button("Verify credentials and link") {
                        focusedField = nil
                        Task {
                            await account.linkRanked(login: legacyLogin, password: legacyPassword)
                            if account.error == nil { legacyPassword = ""; showLegacyLink = false; loadRankedIdentity() }
                        }
                    }.buttonStyle(EverPrimaryButtonStyle())
                        .disabled(account.busy || legacyLogin.isEmpty || legacyPassword.isEmpty)
                    Text("Successful linking preserves existing aliases, earned ratings and match history. Already-linked accounts cannot be linked again.")
                        .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                }.textFieldStyle(.roundedBorder).font(TimeMasterFont.body()).padding(.top, EverSpacing.x2)
            } label: {
                Text("Link existing Ranked account")
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8), action: { showLegacyLink.toggle() })
            }.font(TimeMasterFont.rowTitle())
        }
    }

    private var deletionSection: some View {
        EverSettingsSection(title: "Delete account") {
            Button("Delete cloud account…", role: .destructive) { confirmDeletion = true }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
            Text("Requires a confirmed server response. A failed or pending deletion is never shown as complete.")
                .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
        }
    }

    private func messageSection(title: String, message: String, symbol: String) -> some View {
        EverSettingsSection(title: title) {
            Label(message, systemImage: symbol).font(TimeMasterFont.caption()).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func loadRankedIdentity() {
        alias = ranked.identity?.displayName ?? ""
        listed = ranked.identity?.listed ?? false
    }
}
