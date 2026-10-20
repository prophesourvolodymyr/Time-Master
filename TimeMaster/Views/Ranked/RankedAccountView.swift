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
                        Label(identity.displayName, systemImage: "person.crop.circle.badge.checkmark")
                            .font(TimeMasterFont.title())
                        HStack {
                            RankedInfoButton(label: "Ranked identity", message: "Your workouts, posts, avatar and local profile remain on this device.", symbol: "lock.shield")
                            Spacer()
                            RankedIconAction(symbol: "arrow.clockwise", label: "Refresh earned ratings", id: "ranked-account-refresh") { Task { await account.refresh() } }.disabled(busy)
                        }
                        publicIdentity
                        Button { submitPrivacy() } label: {
                            Image(systemName: "checkmark").frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Save public identity")
                        Button(role: .destructive) {
                            Task {
                                busy = true
                                await account.signOut()
                                error = account.error
                                busy = false
                            }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(busy)
                        .accessibilityLabel("Sign out")
                    } else {
                        RankedInfoButton(label: "Ranked account", message: "Practice needs no account. Competition uses a separate secure identity; your existing local profile is not replaced.", symbol: "person.crop.circle")
                        if !account.configured {
                            RankedServiceNotice(message: "The Ranked service has not been configured for this build. An authorized HTTPS deployment is required before signing in.")
                        }
                        HStack(spacing: ProfileStyle.spacing) {
                            ForEach([false, true], id: \.self) { option in
                                Button { creating = option } label: {
                                    Image(systemName: option ? "person.badge.plus" : "lock.open")
                                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                                }
                                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: creating == option))
                                .accessibilityLabel(option ? "Create account" : "Sign in")
                                .accessibilityAddTraits(creating == option ? .isSelected : [])
                                .accessibilityIdentifier(option ? "ranked-account-create" : "ranked-account-signin")
                            }
                        }
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Private login").font(TimeMasterFont.caption())
                            TextField("Login", text: $login)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .login)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
#if os(iOS)
                                .textInputAutocapitalization(.never)
                                .textContentType(.username)
#endif
                            Text("Password · At least 12 characters").font(TimeMasterFont.caption())
                            SecureField("Password", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(creating ? .next : .done)
                                .onSubmit {
                                    if creating { focusedField = .name }
                                    else if canSubmit { authenticate() }
                                }
#if os(iOS)
                                .textContentType(creating ? .newPassword : .password)
#endif
                            if creating { publicIdentity }
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                        Button { authenticate() } label: {
                            Image(systemName: creating ? "person.badge.plus" : "lock.open")
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle())
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("ranked-account-submit")
                        .accessibilityLabel(creating ? "Create account" : "Sign in")
                    }
                    if busy { TmaxLoadingIndicator().frame(maxWidth: .infinity) }
                    if let error { RankedServiceNotice(message: error) }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton().disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .task {
                await account.restore()
                name = account.identity?.displayName ?? profileStore.profile.displayName
                listed = account.identity?.listed ?? false
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var publicIdentity: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Competitive alias").font(TimeMasterFont.caption())
            TextField("Public display name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    if creating && canSubmit { authenticate() }
                }
            Toggle("Appear in public leaderboards", isOn: $listed)
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
        HStack(spacing: ProfileStyle.spacing) {
            RankedInfoButton(label: "Attention required", message: message, symbol: "exclamationmark.triangle")
                .accessibilityLabel(message)
            Spacer(minLength: 0)
            if let retry { RankedIconAction(symbol: "arrow.clockwise", label: "Retry", action: retry) }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityIdentifier("ranked-service-notice")
    }
}
