import SwiftUI

struct CloudAccountSettingsView: View {
    @ObservedObject private var account = CloudAccountStore.shared
    @ObservedObject private var ranked = RankedAccountStore.shared
    @State private var creating = false
    @State private var reconnecting = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showResetRequest = false
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
    private enum Field: Hashable { case email, password, name, newPassword, passwordConfirmation, legacyLogin, legacyPassword }
    @FocusState private var focusedField: Field?

    private var validEmail: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && !value.contains(where: \.isWhitespace)
    }
    private var canAuthenticate: Bool {
        account.configured && account.restored && !account.busy && validEmail && !password.isEmpty
            && (!creating || (password.count >= 12 && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    var body: some View {
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
                } else {
                    SettingsActionRow(title: "Local mode is available", detail: "No account is required for the exercise library or ZIP export.", symbol: "internaldrive")
                }
            }

            if let message = account.configurationError { messageSection(title: "Account configuration", message: message, symbol: "exclamationmark.triangle") }
            if !account.restored {
                messageSection(title: "Preparing account", message: "Local startup must finish before connecting an account.", symbol: "hourglass")
            }
            if account.passwordRecovery || showPasswordForm { passwordForm }
            if account.session == nil || reconnecting { authenticationForm; providerOptions }
            if account.session != nil { signedInActions; rankedIdentity; legacyLink; deletionSection }
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
        .tint(Theme.toolbarOrange)
        .scrollDismissesKeyboard(.interactively)
        .slotNavigationInteractionDisabled(focusedField != nil)
        .task {
            await ranked.restore()
            loadRankedIdentity()
            if account.providerSettings == nil { await account.loadProviderSettings() }
        }
        .onChange(of: ranked.identity?.publicID) { _ in loadRankedIdentity() }
        .onChange(of: creating) { _ in account.clearMessages() }
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

    private var authenticationForm: some View {
        EverSettingsSection(title: creating ? "Create account" : "Sign in") {
            if !reconnecting {
                Picker("Account action", selection: $creating) {
                    Text("Sign in").tag(false)
                    Text("Create account").tag(true)
                }.pickerStyle(.segmented).keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { creating.toggle() }).disabled(account.busy)
            }
            VStack(alignment: .leading, spacing: EverSpacing.x3) {
                Text("Email").font(TimeMasterFont.rowTitle())
                TextField("Email address", text: $email)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityIdentifier("ranked-account-login")
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
#endif
                Text("Password").font(TimeMasterFont.rowTitle())
                SecureField("Password", text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(creating ? .next : .go)
                    .onSubmit { if creating { focusedField = .name } else if canAuthenticate { authenticate() } }
                    .accessibilityIdentifier("ranked-account-password")
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
#if os(iOS)
                    .textContentType(creating ? .newPassword : .password)
#endif
                if creating {
                    Text("At least 12 characters").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                    Text("Display name").font(TimeMasterFont.rowTitle())
                    TextField("Account display name", text: $displayName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.go)
                        .onSubmit { if canAuthenticate { authenticate() } }
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(TimeMasterFont.body())
            .disabled(account.busy)
            Button(creating ? "Create account" : "Sign in") { authenticate() }
                .buttonStyle(EverPrimaryButtonStyle())
                .disabled(!canAuthenticate)
                .accessibilityIdentifier("ranked-account-submit")
            if creating {
                Text("Email confirmation may be required. Creating an account does not mark your email as verified.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
            Button("Resend confirmation email") {
                Task { await account.resendConfirmation(email: email) }
            }.buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(!validEmail || account.busy || !account.configured)
            Button("Forgot password?") { showResetRequest.toggle() }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
            if showResetRequest {
                Text("Enter your account email above. The reset link must be opened on this device.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                Button("Send password-reset email") { Task { await account.requestPasswordReset(email: email) } }
                    .buttonStyle(EverPrimaryButtonStyle()).disabled(!validEmail || account.busy || !account.configured)
            }
        }
    }

    private var providerOptions: some View {
        EverSettingsSection(title: "Other sign-in options") {
            providerButton("apple", title: "Continue with Apple", symbol: "apple.logo")
            providerButton("google", title: "Continue with Google", symbol: "person.crop.circle")
            if let error = account.providerError {
                Text(error).font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
            Button("Check provider availability") { Task { await account.loadProviderSettings() } }
                .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy || !account.configured)
        }
    }

    private func providerButton(_ provider: String, title: String, symbol: String) -> some View {
        let available = account.providerSettings?.external[provider]
        return VStack(alignment: .leading, spacing: EverSpacing.x1) {
            Button { Task { await account.signIn(provider: provider) } } label: {
                HStack(spacing: EverSpacing.x2) {
                    if provider == "google" {
                        Image("RankedGoogleSignIn").renderingMode(.original).resizable().scaledToFit()
                            .frame(width: 24, height: 24).padding(EverSpacing.x1).background(.white, in: Circle())
                    } else { Image(systemName: symbol).font(.title2) }
                    Text(title).font(TimeMasterFont.rowTitle())
                    Spacer(minLength: 0)
                }.frame(minHeight: EverLayout.minimumTouchTarget)
            }
            .buttonStyle(TimeMasterToolbarTextButtonStyle())
            .disabled(available != true || account.busy || !account.restored)
            .accessibilityIdentifier("ranked-account-\(provider)")
            if available == false {
                Text("\(provider.capitalized) is disabled in this project's Supabase Auth provider settings. A configured provider client and credentials are required.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            } else if available == nil {
                Text("Provider availability has not been verified.").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
        }
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
            Button(reconnecting ? "Cancel reconnect" : "Sign in again or switch account") {
                reconnecting.toggle()
                creating = false
                email = account.email ?? ""
                password = ""
            }.buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(account.busy)
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

    private func authenticate() {
        focusedField = nil
        Task {
            if creating { await account.signUp(email: email, password: password, displayName: displayName) }
            else { await account.signIn(email: email, password: password) }
            if account.error == nil {
                password = ""
                if account.session != nil { reconnecting = false }
            }
        }
    }

    private func loadRankedIdentity() {
        alias = ranked.identity?.displayName ?? ""
        listed = ranked.identity?.listed ?? false
    }
}
