import SwiftUI

struct CloudAccountLoginView: View {
    @ObservedObject private var account = CloudAccountStore.shared
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @Environment(\.isPresented) private var isPresented
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var reconnecting: Bool
    @State private var creating = false
    @State private var email: String
    @State private var password = ""
    @State private var displayName = ""
    @State private var showResetRequest = false
    @State private var entered = false
    @Namespace private var modeSelection
    private enum Field: Hashable { case email, password, name }
    @FocusState private var focusedField: Field?

    init(reconnecting: Binding<Bool>, email: String = "") {
        _reconnecting = reconnecting
        _email = State(initialValue: email)
    }

    private var validEmail: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && !value.contains(where: \.isWhitespace)
    }

    private var canAuthenticate: Bool {
        account.configured && account.restored && !account.busy && validEmail && !password.isEmpty
            && (!creating || (password.count >= 12 && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    private var title: String {
        if reconnecting { return "Switch account" }
        return creating ? "Create your account" : "Sign in to Tmax"
    }

    var body: some View {
        GeometryReader { viewport in
            let frame = viewport.frame(in: .global)
            let bounds = isPresented ? nil : navigationBounds
            let topClearance = max(0, (bounds?.minY ?? frame.minY) - frame.minY - viewport.safeAreaInsets.top)
            let bottomClearance = max(0, frame.maxY - (bounds?.maxY ?? frame.maxY) - viewport.safeAreaInsets.bottom)
            ScrollView {
                column
                    .frame(maxWidth: 420)
                    .padding(.horizontal, EverSpacing.x5)
                    .padding(.top, EverSpacing.x4 + topClearance)
                    .padding(.bottom, EverSpacing.x8 + bottomClearance)
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .background(TmaxGlowBackground(intensity: .hero, rises: true))
        .font(TimeMasterFont.body())
        .foregroundStyle(EverColor.textPrimary)
        .timeMasterNavigationTitle("Tmax Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .scrollDismissesKeyboard(.interactively)
        .slotNavigationInteractionDisabled(focusedField != nil)
        .onChange(of: creating) { _ in account.clearMessages() }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.8, dampingFraction: 0.86).delay(0.15)) {
                entered = true
            }
        }
    }

    private var column: some View {
        VStack(spacing: EverSpacing.x6) {
            hero
            VStack(spacing: EverSpacing.x4) {
                if !reconnecting { modePicker }
                fields
                primaryActions
            }
            .opacity(entered ? 1 : 0)
            .offset(y: entered || reduceMotion ? 0 : 18)
            providers
                .opacity(entered ? 1 : 0)
            statusMessages
            localNote
                .opacity(entered ? 1 : 0)
        }
        .multilineTextAlignment(.center)
    }

    private var hero: some View {
        VStack(spacing: EverSpacing.x5) {
            TmaxGlowLogo()
                .frame(width: 104, height: 104)
                .scaleEffect(entered || reduceMotion ? 1 : 0.84)
                .opacity(entered ? 1 : 0)
            VStack(spacing: EverSpacing.x2) {
                Text(title)
                    .font(TimeMasterFont.black(28, relativeTo: .title))
                    .accessibilityAddTraits(.isHeader)
                Text("One secure account for database sync and Ranked.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(EverColor.textSecondary)
                Text("Profile, workouts, history and music stay on this device.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        HStack(spacing: EverSpacing.x1) {
            modeButton("Sign in", creates: false)
            modeButton("Create account", creates: true)
        }
        .padding(EverSpacing.x1)
        .background(Capsule().fill(.black.opacity(0.45)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1).allowsHitTesting(false))
        .disabled(account.busy)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Account action")
    }

    private func modeButton(_ label: String, creates: Bool) -> some View {
        let selected = creating == creates
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) { creating = creates }
        } label: {
            Text(label)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(selected ? EverColor.textPrimary : EverColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: EverLayout.minimumTouchTarget)
                .background {
                    if selected {
                        Capsule()
                            .fill(TmaxGlow.fill)
                            .matchedGeometryEffect(id: "mode", in: modeSelection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyNavTarget(shape: .capsule)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fields: some View {
        VStack(spacing: EverSpacing.x3) {
            inputRow("envelope.fill", focused: focusedField == .email) {
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
            }
            inputRow("lock.fill", focused: focusedField == .password) {
                SecureField(creating ? "Password, at least 12 characters" : "Password", text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(creating ? .next : .go)
                    .onSubmit { if creating { focusedField = .name } else if canAuthenticate { authenticate() } }
                    .accessibilityIdentifier("ranked-account-password")
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                #if os(iOS)
                    .textContentType(creating ? .newPassword : .password)
                #endif
            }
            if creating {
                inputRow("person.fill", focused: focusedField == .name) {
                    TextField("Display name", text: $displayName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.go)
                        .onSubmit { if canAuthenticate { authenticate() } }
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .disabled(account.busy)
    }

    private func inputRow<Input: View>(_ symbol: String, focused: Bool, @ViewBuilder input: () -> Input) -> some View {
        let shape = RoundedRectangle(cornerRadius: EverRadius.field + 4, style: .continuous)
        return HStack(spacing: EverSpacing.x3) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(focused ? TmaxGlow.blaze : EverColor.textTertiary)
                .frame(width: 22)
                .accessibilityHidden(true)
            input()
                .font(TimeMasterFont.body())
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, EverSpacing.x4)
        .frame(minHeight: EverLayout.primaryButtonMinimum + 2)
        .background(shape.fill(.black.opacity(0.5)))
        .overlay(
            shape.strokeBorder(focused ? TmaxGlow.flame.opacity(0.9) : .white.opacity(0.12), lineWidth: focused ? 1.5 : 1)
                .allowsHitTesting(false)
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: focused)
    }

    private var primaryActions: some View {
        VStack(spacing: EverSpacing.x2) {
            Button(creating ? "Create account" : "Sign in") { authenticate() }
                .buttonStyle(EverPrimaryButtonStyle())
                .disabled(!canAuthenticate)
                .accessibilityIdentifier("ranked-account-submit")
            if creating {
                Text("You may need to confirm your email before signing in.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textTertiary)
            }
            HStack(spacing: EverSpacing.x5) {
                linkButton("Forgot password?") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showResetRequest.toggle() }
                }
                .disabled(account.busy)
                linkButton("Resend confirmation") {
                    Task { await account.resendConfirmation(email: email) }
                }
                .disabled(!validEmail || account.busy || !account.configured)
            }
            if showResetRequest {
                VStack(spacing: EverSpacing.x2) {
                    Text("Enter your email above. Open the reset link on this device.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                    Button("Send reset link") { Task { await account.requestPasswordReset(email: email) } }
                        .buttonStyle(EverSecondaryButtonStyle())
                        .disabled(!validEmail || account.busy || !account.configured)
                }
                .transition(.opacity)
            }
            if reconnecting {
                linkButton("Keep current account") { reconnecting = false }
                    .disabled(account.busy)
            }
        }
    }

    private func linkButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                .foregroundStyle(TmaxGlow.blaze)
                .frame(minHeight: EverLayout.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
    }

    private var providers: some View {
        VStack(spacing: EverSpacing.x3) {
            HStack(spacing: EverSpacing.x3) {
                Capsule().fill(.white.opacity(0.14)).frame(height: 1)
                Text("or").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textTertiary)
                Capsule().fill(.white.opacity(0.14)).frame(height: 1)
            }
            .accessibilityHidden(true)
            providerButton("apple", title: "Continue with Apple")
            providerButton("google", title: "Continue with Google")
            if let error = account.providerError {
                Text(error).font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
            if account.providerSettings?.external["apple"] != true || account.providerSettings?.external["google"] != true {
                linkButton("Check sign-in options") { Task { await account.loadProviderSettings() } }
                    .disabled(account.busy || !account.configured)
            }
        }
    }

    private func providerButton(_ provider: String, title: String) -> some View {
        let available = account.providerSettings?.external[provider]
        return Button { Task { await account.signIn(provider: provider) } } label: {
            HStack(spacing: EverSpacing.x3) {
                if provider == "google" {
                    Image("RankedGoogleSignIn").renderingMode(.original).resizable().scaledToFit()
                        .frame(width: 18, height: 18).padding(EverSpacing.x1).background(.white, in: Circle())
                } else {
                    Image(systemName: "apple.logo").font(.system(size: 19, weight: .semibold))
                }
                Text(title).font(TimeMasterFont.rowTitle())
                if available != true {
                    Text(available == false ? "Off" : "Not checked")
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(EverColor.textSecondary)
                        .padding(.horizontal, EverSpacing.x2)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 52, fillsWidth: true, horizontalPadding: EverSpacing.x4, tint: Theme.surface2))
        .disabled(available != true || account.busy || !account.restored)
        .accessibilityIdentifier("ranked-account-\(provider)")
        .accessibilityValue(available == true ? "" : available == false ? "Not enabled on the server" : "Availability not checked")
    }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: EverSpacing.x2) {
            if let message = account.configurationError { statusRow(message, symbol: "exclamationmark.triangle.fill") }
            if !account.restored { statusRow("Preparing your account on this device…", symbol: "hourglass") }
            if let error = account.error { statusRow(error, symbol: "exclamationmark.triangle.fill") }
            if let notice = account.notice { statusRow(notice, symbol: "info.circle.fill") }
            if account.busy {
                HStack(spacing: EverSpacing.x2) {
                    TmaxLoadingIndicator()
                    Text("Connecting securely…").font(TimeMasterFont.caption())
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func statusRow(_ message: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: EverSpacing.x2) {
            Image(systemName: symbol).foregroundStyle(TmaxGlow.blaze).accessibilityHidden(true)
            Text(message)
                .font(TimeMasterFont.caption())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EverSpacing.x3)
        .tmaxGlowSurface(cornerRadius: EverRadius.card, glow: 0.4)
    }

    private var localNote: some View {
        VStack(spacing: EverSpacing.x1) {
            Label("No account needed for your library", systemImage: "internaldrive")
                .font(TimeMasterFont.caption())
                .foregroundStyle(EverColor.textTertiary)
            NavigationLink { BackupView() } label: {
                Label("Backup & Transfer", systemImage: "archivebox")
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    .foregroundStyle(TmaxGlow.blaze)
                    .frame(minHeight: EverLayout.minimumTouchTarget)
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
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
}
