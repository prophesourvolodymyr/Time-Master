import SwiftUI

struct RankedAccountView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
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
                        Text("Your workouts, posts, avatar and local profile remain on this device.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        publicIdentity
                        Button("Save public identity") { submitPrivacy() }
                            .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Refresh earned ratings") { Task { await account.refresh() } }
                            .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(busy)
                        Button("Sign out", role: .destructive) {
                            Task {
                                busy = true
                                await account.signOut()
                                error = account.error
                                busy = false
                            }
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(busy)
                    } else {
                        Label("Your Ranked account", systemImage: "person.crop.circle")
                            .font(TimeMasterFont.title())
                        Text("Practice needs no account. Competition uses a separate secure identity; your existing profile is not replaced.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        if !account.configured {
                            RankedServiceNotice(message: "The Ranked service has not been configured for this build. An authorized HTTPS deployment is required before signing in.")
                        }
                        Picker("Account action", selection: $creating) {
                            Text("Sign in").tag(false)
                            Text("Create account").tag(true)
                        }.pickerStyle(.segmented)
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
                            Label(creating ? "Create account" : "Sign in", systemImage: "lock.shield")
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(TimeMasterToolbarWideButtonStyle())
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("ranked-account-submit")
                    }
                    if busy { ProgressView().frame(maxWidth: .infinity) }
                    if let error { RankedServiceNotice(message: error) }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .navigationTitle("Ranked account")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() }.disabled(busy) } }
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
            Text("Opting in shares only this alias and exercise ratings. Opponents see your alias during a match. Camera images, private posts and account login are never shared.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
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
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(TimeMasterFont.secondary()).fixedSize(horizontal: false, vertical: true)
            if let retry { Button("Retry", action: retry).buttonStyle(TimeMasterToolbarWideButtonStyle()) }
        }
        .padding(ProfileStyle.inset).frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityElement(children: .contain)
    }
}
