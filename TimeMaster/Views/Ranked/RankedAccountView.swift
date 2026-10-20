import SwiftUI

struct RankedAccountView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var creating = false
    @State private var login = ""
    @State private var password = ""
    @State private var name = ""
    @State private var listed = false
    @State private var busy = false
    @State private var error: String?
    private enum Field: Hashable { case login, password, name }
    @FocusState private var focusedField: Field?

    private var canSubmit: Bool {
        !busy && account.configured && login.count >= 3 && password.count >= 12
            && (!creating || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    if let identity = account.identity {
                        Text("Ranked account").font(TimeMasterFont.heading())
                        Label(identity.displayName, systemImage: "person.crop.circle.badge.checkmark")
                            .font(TimeMasterFont.title())
                        HStack {
                            RankedInfoButton(label: "Ranked identity", message: "Your workouts, posts, avatar and local profile remain on this device.", symbol: "lock.shield")
                            Spacer()
                            RankedIconAction(symbol: "arrow.clockwise", label: "Refresh earned ratings", id: "ranked-account-refresh") { Task { await account.refresh() } }.disabled(busy)
                        }
                        publicIdentity
                        Button { submitPrivacy() } label: {
                            Label("Save public identity", systemImage: "checkmark")
                                .font(TimeMasterFont.label())
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle())
                        .disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("ranked-account-save")
                        Button(role: .destructive) {
                            Task {
                                busy = true
                                await account.signOut()
                                error = account.error
                                busy = false
                            }
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(TimeMasterFont.rowTitle())
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle()).disabled(busy)
                        .accessibilityIdentifier("ranked-account-signout")
                    } else {
                        VStack(alignment: .leading, spacing: EverSpacing.x2) {
                            Text(creating ? "Create your account" : "Sign in to Ranked")
                                .font(TimeMasterFont.display())
                            Text("Compete, earn Elo and keep your match history. Practice needs no account.")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                        if !account.configured {
                            RankedServiceNotice(message: "The Ranked service has not been configured for this build. An authorized HTTPS deployment is required before signing in.")
                        }
                        authenticationForm
                        providerPlaceholders
                        RankedInfoButton(label: "Your local profile stays yours", message: "Ranked uses a separate secure account. Signing in does not replace your avatar, workouts, posts or local profile.", symbol: "lock.shield")
                    }
                    if busy {
                        HStack(spacing: ProfileStyle.spacing) {
                            TmaxLoadingIndicator()
                            Text("Please wait").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let error, account.identity != nil { RankedServiceNotice(message: error).accessibilityIdentifier("ranked-account-error") }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.item(placement: .confirmationAction) { RankedCloseButton().disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .task {
                await account.restore()
                name = account.identity?.displayName ?? profileStore.profile.displayName
                listed = account.identity?.listed ?? false
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var authenticationForm: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            HStack(spacing: ProfileStyle.spacing) {
                ForEach([false, true], id: \.self) { option in
                    Button { creating = option; error = nil } label: {
                        Text(option ? "Create account" : "Sign in")
                            .font(TimeMasterFont.rowTitle())
                            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                    }
                    .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: creating == option))
                    .accessibilityAddTraits(creating == option ? .isSelected : [])
                    .accessibilityIdentifier(option ? "ranked-account-create" : "ranked-account-signin")
                }
            }
            .disabled(busy)
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("Private login").font(TimeMasterFont.rowTitle())
                TextField("Login", text: $login)
                    .font(TimeMasterFont.body())
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .login)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityIdentifier("ranked-account-login")
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
#endif
                Text("Password").font(TimeMasterFont.rowTitle())
                SecureField("Password", text: $password)
                    .font(TimeMasterFont.body())
                    .focused($focusedField, equals: .password)
                    .submitLabel(creating ? .next : .go)
                    .onSubmit {
                        if creating { focusedField = .name }
                        else if canSubmit { authenticate() }
                    }
                    .accessibilityIdentifier("ranked-account-password")
#if os(iOS)
                    .textContentType(creating ? .newPassword : .password)
#endif
                Text("At least 12 characters")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .textFieldStyle(.roundedBorder)
            .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
            .disabled(busy)
            if creating { publicIdentity.disabled(busy) }
            if let error { RankedServiceNotice(message: error).accessibilityIdentifier("ranked-account-error") }
            Button { authenticate() } label: {
                Label(creating ? "Create account" : "Sign in", systemImage: creating ? "person.badge.plus" : "lock.open")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .disabled(!canSubmit)
            .accessibilityIdentifier("ranked-account-submit")
        }
    }

    private var providerPlaceholders: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Other sign-in options").font(TimeMasterFont.rowTitle())
            VStack(spacing: ProfileStyle.spacing) {
                Button { } label: {
                    Label {
                        Text("Continue with Apple").font(TimeMasterFont.rowTitle())
                    } icon: {
                        Image(systemName: "apple.logo").font(.title2)
                    }
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                    .padding(EverSpacing.x2)
                    .modifier(TimeMasterCardSurface(flat: true))
                }
                .accessibilityIdentifier("ranked-account-apple")
                .accessibilityLabel("Continue with Apple, not connected")
                Button { } label: {
                    Label {
                        Text("Continue with Google").font(TimeMasterFont.rowTitle())
                    } icon: {
                        Image("RankedGoogleSignIn").renderingMode(.original)
                            .resizable().scaledToFit()
                            .frame(width: ProfileStyle.touchTarget / 2, height: ProfileStyle.touchTarget / 2)
                            .padding(EverSpacing.x1)
                            .background(.white, in: Circle())
                    }
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                    .padding(EverSpacing.x2)
                    .modifier(TimeMasterCardSurface(flat: true))
                }
                .accessibilityIdentifier("ranked-account-google")
                .accessibilityLabel("Continue with Google, not connected")
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .disabled(true)
            Text("Not connected · Apple and Google are placeholders. Use your login and password above.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var publicIdentity: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Competitive alias").font(TimeMasterFont.rowTitle())
            TextField("Public display name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(TimeMasterFont.body())
                .accessibilityIdentifier("ranked-account-alias")
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    if creating && canSubmit { authenticate() }
                }
            Toggle("Appear in public leaderboards", isOn: $listed)
                .font(TimeMasterFont.secondary())
            RankedInfoButton(label: "Public leaderboard privacy", message: "Opting in shares only this alias and exercise ratings. Opponents see your alias during a match. Camera images, private posts and account login are never shared.", symbol: "lock.shield")
        }
        .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
    }

    private func authenticate() {
        focusedField = nil
        busy = true
        error = nil
        Task {
            do {
                try await account.authenticate(login: login, password: password, displayName: creating ? name : nil, listed: listed)
                password = ""
                name = account.identity?.displayName ?? name
                listed = account.identity?.listed ?? false
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    private func submitPrivacy() {
        focusedField = nil
        busy = true
        Task {
            do { try await account.updatePublicIdentity(name: name, listed: listed); error = nil }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

struct RankedServiceNotice: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(TimeMasterFont.caption())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry { RankedIconAction(symbol: "arrow.clockwise", label: "Retry", action: retry) }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityIdentifier("ranked-service-notice")
    }
}
