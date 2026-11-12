import SwiftUI

@MainActor
struct PhysiqueLobbyView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var recentMatches: [PhysiqueMatch] = []
    @State private var recentAccountID: String?
    @State private var recentLoading = false
    @State private var recentError: String?
    @State private var recentRequestID: UUID?
    @State private var checkingEntry = false
    @State private var entryRequestID: UUID?
    @State private var showsDetailsSheet = false
    @State private var showsInspector = false
    private let artSize = ProfileStyle.touchTarget * 1.35

    private enum EntryAction {
        case open(PhysiqueRoute), prepare, refresh, none
    }

    private struct Entry {
        let title: String
        let symbol: String
        let detail: String?
        let status: String
        let statusSymbol: String
        let action: EntryAction
        var disabled = false
        var busy = false
    }

    private struct Notice {
        let title: String
        let detail: String
        let symbol: String
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var sessionScope: String {
        guard accountStore.restored, !accountStore.busy else { return "restoring" }
        return accountStore.accountID ?? "signed-out"
    }

    private var canShowPrivateData: Bool {
        activeAccountID != nil && store.signedIn && presentationActive && scenePhase == .active
    }

    private var currentAccount: PhysiqueAccount? {
        canShowPrivateData ? store.account : nil
    }

    private var currentPolicy: PhysiquePolicy? {
        store.policy ?? (canShowPrivateData ? store.snapshot?.policy : nil)
    }

    private var nextStep: Entry {
        guard accountStore.restored, !accountStore.busy else {
            return Entry(title: "Checking account", symbol: "person.crop.circle", detail: "Restoring your Tmax account.", status: "Restoring account", statusSymbol: "person.crop.circle", action: .none, disabled: true, busy: true)
        }
        guard activeAccountID != nil, store.signedIn else {
            return Entry(title: "Sign in to compete", symbol: "person.badge.key", detail: "Sign in to keep your own Physique record.", status: "Sign in for your own record", statusSymbol: "person.badge.key", action: .open(.account))
        }
        guard presentationActive, scenePhase == .active else {
            return Entry(title: "Physique is private", symbol: "lock", detail: nil, status: "Private", statusSymbol: "lock", action: .none, disabled: true)
        }
        if checkingEntry || store.loading {
            return Entry(title: "Checking availability", symbol: "arrow.clockwise", detail: "Confirming your account and active match.", status: "Checking availability", statusSymbol: "arrow.clockwise", action: .none, disabled: true, busy: true)
        }
        guard let account = currentAccount else {
            return Entry(title: "Retry status", symbol: "arrow.clockwise", detail: "Record and match availability are unconfirmed.", status: "Status not confirmed", statusSymbol: "exclamationmark.circle", action: .refresh)
        }
        if store.isStale {
            return Entry(title: "Check status", symbol: "arrow.clockwise", detail: "Saved record. Reconnect to start or resume.", status: "Saved record · offline", statusSymbol: "wifi.exclamationmark", action: .refresh)
        }
        if store.cancellationPending {
            return Entry(title: "Check cancellation", symbol: "arrow.clockwise", detail: "Confirm the previous cancellation before another search.", status: "Cancellation pending", statusSymbol: "xmark.circle", action: .open(.search))
        }
        if let match = store.match, !match.stage.terminal {
            let anotherWindow = !store.canControl(from: windowID)
            let title = anotherWindow ? "View active match" : match.stage == .judging || match.stage == .submitting ? "View match" : match.stage == .searching ? "Resume search" : "Resume match"
            let detail = anotherWindow ? "Another window controls this session. Review its status to continue." : match.stage.title
            return Entry(title: title, symbol: "arrow.right.circle", detail: detail, status: anotherWindow ? "Open in another window" : match.stage.title, statusSymbol: anotherWindow ? "macwindow.on.rectangle" : "bolt.circle", action: .open(route(for: match)))
        }
        if store.stage == .searching {
            return Entry(title: "Resume search", symbol: "person.2", detail: "Continue your existing search.", status: "Search running", statusSymbol: "person.2", action: .open(.search))
        }
        if let reason = account.restrictedReason, !reason.isEmpty {
            return Entry(title: "View restriction", symbol: "shield", detail: reason, status: "Account restricted", statusSymbol: "exclamationmark.shield", action: .open(.safety))
        }
        guard let policy = currentPolicy, policy.ready else {
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: currentPolicy?.unavailableReason ?? "Rated matches are unavailable until the service confirms participation.", status: "Matches paused", statusSymbol: "pause.circle", action: .none, disabled: true)
        }
        guard account.allowance.remaining > 0 else {
            let next = account.allowance.nextAvailableAt.map { "No matches left · next \(slotTime($0))" } ?? "No matches left"
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: account.allowance.nextAvailableAt == nil ? "No matches available. Refresh to check the next slot." : "No matches available. Refresh after the next slot to confirm.", status: next, statusSymbol: "hourglass", action: .none, disabled: true)
        }
        if store.localProcessingStopped || store.localOwnMediaHidden {
            return Entry(title: "Review sharing choices", symbol: "hand.raised", detail: "Processing or sharing is stopped. Review your choices to continue.", status: "Sharing paused", statusSymbol: "hand.raised", action: .prepare)
        }
        guard account.consent.accepted, account.consent.policyVersion == policy.version else {
            return Entry(title: "Review eligibility", symbol: "checkmark.shield", detail: "Review adult eligibility, rules and image sharing.", status: "Eligibility check first", statusSymbol: "checkmark.shield", action: .prepare)
        }
        switch store.stage {
        case .noOpponent:
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: "No opponent found. Prepare to try again.", status: "No opponent last time", statusSymbol: "person.fill.questionmark", action: .prepare)
        case .cancelled:
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: "Search cancelled. Prepare when you're ready.", status: "Search cancelled", statusSymbol: "xmark.circle", action: .prepare)
        default:
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: "Camera setup comes next. No search starts here.", status: "Camera setup comes next", statusSymbol: "camera", action: .prepare)
        }
    }

    private var notice: Notice? {
        guard accountStore.restored, !accountStore.busy, presentationActive, scenePhase == .active else { return nil }
        if let error = store.error {
            return Notice(title: store.isStale ? "Using saved record" : "Unable to confirm Physique", detail: error, symbol: "wifi.exclamationmark")
        }
        if let policy = currentPolicy, !policy.ready {
            return Notice(title: "Matches unavailable", detail: policy.unavailableReason ?? "The service has not enabled rated participation.", symbol: "pause.circle")
        }
        if let reason = currentAccount?.restrictedReason, !reason.isEmpty {
            return Notice(title: "Account restricted", detail: reason, symbol: "exclamationmark.shield")
        }
        if activeAccountID != nil, store.signedIn, currentAccount == nil, !store.loading, !checkingEntry {
            return Notice(title: "Record unavailable", detail: "Your Physique record has not loaded. Check status to retrieve your own rating, badges and allowance.", symbol: "person.crop.circle.badge.exclamationmark")
        }
        return nil
    }

    var body: some View {
        GeometryReader { viewport in
            let frame = viewport.frame(in: .global)
            let contentBounds = frame.intersection(navigationBounds ?? frame)
            #if os(macOS)
            let inspectorFits = viewport.size.width >= ProfileStyle.readableWidth + 300 + ProfileStyle.inset * 3
            #endif

            Group {
                if dynamicTypeSize >= .xxLarge {
                    scrollingLobby
                } else {
                    ViewThatFits(in: .vertical) {
                        lobby(scrolls: false)
                        scrollingLobby
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(1, contentBounds.height), alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            #if os(macOS)
            .inspector(isPresented: $showsInspector) {
                ScrollView {
                    detailsContent
                        .padding(ProfileStyle.inset)
                }
                .keyNavAccessoryHost()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
                .background(Theme.background)
            }
            .onChange(of: inspectorFits) { fits in
                if !fits { showsInspector = false }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button { onOpen(.rules) } label: { Label("Rules", systemImage: "list.bullet.clipboard") }
                        .physiqueToolbarTarget()
                    Button { onOpen(.account) } label: { Label("Account", systemImage: "person.crop.circle") }
                        .physiqueToolbarTarget()
                    Button {
                        if inspectorFits { showsInspector.toggle() }
                        else { showsDetailsSheet = true }
                    } label: { Label("Details", systemImage: "sidebar.right") }
                        .physiqueToolbarTarget()
                    Button { Task { await refreshLobby() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .physiqueToolbarTarget()
                        .disabled(refreshDisabled)
                }
            }
            #endif
        }
        .background(TmaxGlowBackground(intensity: .ambient))
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.toolbarOrange)
        #if os(iOS)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        #else
        .navigationTitle("Physique")
        #endif
        .sheet(isPresented: $showsDetailsSheet) {
            NavigationStack {
                ScrollView {
                    detailsContent
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .background(Theme.background.ignoresSafeArea())
                .foregroundStyle(Theme.textPrimary)
                .navigationTitle("Physique details")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showsDetailsSheet = false }
                            .physiqueToolbarTarget()
                    }
                }
            }
            .tint(Theme.toolbarOrange)
            #if os(macOS)
            .frame(minWidth: 320, idealWidth: 420, minHeight: 400)
            #endif
            .keyNavHost()
        }
        .task(id: sessionScope) {
            if recentAccountID != activeAccountID { clearPrivateState() }
            guard accountStore.restored, !accountStore.busy else { return }
            await refreshLobby()
        }
        .onChange(of: accountStore.accountID) { _ in clearPrivateState() }
        .onChange(of: accountStore.busy) { busy in
            if busy { clearPrivateState() }
        }
        .onChange(of: store.privacyRevision) { _ in
            entryRequestID = nil
            checkingEntry = false
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, presentationActive {
                Task { await refreshLobby() }
            }
        }
        .onChange(of: presentationActive) { active in
            if active, scenePhase == .active {
                Task { await refreshLobby() }
            }
        }
        .onDisappear {
            entryRequestID = nil
            checkingEntry = false
            recentRequestID = nil
            recentLoading = false
            showsDetailsSheet = false
            showsInspector = false
        }
    }

    private func lobby(scrolls: Bool) -> some View {
        VStack(spacing: ProfileStyle.spacing) {
            identityBar
            if let notice {
                PhysiqueLobbyNotice(title: notice.title, detail: notice.detail, systemImage: notice.symbol)
                    .id(notice.title + notice.detail)
            }
            stage
                .frame(minHeight: artSize * 3.5, maxHeight: scrolls ? nil : .infinity)
            battleDock
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth, maxHeight: scrolls ? nil : .infinity)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var scrollingLobby: some View {
        ScrollView { lobby(scrolls: true) }
            .scrollIndicators(.hidden)
            .refreshable { await refreshLobby() }
    }

    private var identityBar: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Button(action: openIdentity) {
                HStack(spacing: EverSpacing.x2) {
                    ProfileStyledAvatar(profile: profileStore.profile, size: ProfileStyle.touchTarget)
                    VStack(alignment: .leading, spacing: EverSpacing.x1) {
                        Text(eloTitle)
                            .font(TimeMasterFont.rowTitle().monospacedDigit())
                            .foregroundStyle(TmaxGlow.flame)
                        Text(identityName)
                            .font(TimeMasterFont.caption())
                    }
                    .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(currentAccount == nil ? "Physique account" : "Your battle identity")
            .accessibilityValue("\(identityName), \(eloAccessibilityValue)")
            .accessibilityHint(currentAccount == nil ? "Opens Physique account" : "Opens your badges and country")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("physique-identity")
            Spacer(minLength: 0)
            RankedIconAction(symbol: accountSymbol, label: activeAccountID == nil ? "Sign in" : "Account", id: "physique-account") { onOpen(.account) }
                .accessibilityValue(activeAccountID == nil ? "Signed out" : store.isStale ? "Reconnecting" : "Connected")
            RankedIconAction(symbol: "arrow.clockwise", label: "Refresh", id: "physique-refresh") {
                Task { await refreshLobby() }
            }
            .disabled(refreshDisabled)
        }
    }

    private var stage: some View {
        PhysiqueLobbyHero(artTopInset: artSize * 0.5) {
            allowanceMetric
        } trailing: {
            rankBadge
        } footer: {
            recentStrip
        }
    }

    private var allowanceMetric: some View {
        let allowance = currentAccount?.allowance
        return Button { showsDetailsSheet = true } label: {
            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                HStack(spacing: EverSpacing.x1) {
                    Text("Matches")
                    Image(systemName: "info.circle")
                        .font(.caption2.weight(.semibold))
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                RankedMetric(
                    value: allowance.map { $0.remaining.formatted() } ?? "—",
                    unit: allowance.map { "of \($0.limit.formatted())" } ?? "",
                    emphasized: (allowance?.remaining ?? 0) > 0
                )
                if let next = allowance?.nextAvailableAt {
                    Label(slotTime(next), systemImage: "clock")
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(ProfileStyle.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: ProfileStyle.touchTarget, minHeight: ProfileStyle.touchTarget, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Physique match allowance")
        .accessibilityValue(allowanceAccessibilityValue)
        .accessibilityHint("Opens your record and allowance details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("physique-allowance")
    }

    private var rankBadge: some View {
        Button { onOpen(.standings) } label: {
            VStack(spacing: EverSpacing.x1) {
                PhysiqueRankCrest(rating: crestRating, caption: crestCaption)
                    .frame(width: artSize * 1.65, height: artSize * 1.65)
                Text("Standings")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
            }
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel("Physique standings")
        .accessibilityValue(eloAccessibilityValue)
        .accessibilityIdentifier("physique-standings")
    }

    @ViewBuilder
    private var recentStrip: some View {
        if canShowRecent, !recentMatches.isEmpty || recentError != nil {
            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                Text("Recent")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                HStack(spacing: 0) {
                    ForEach(recentMatches) { match in
                        Button { onOpen(route(for: match)) } label: {
                            PhysiqueResultPip(systemImage: outcomeSymbol(match), highlighted: isWin(match))
                                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityLabel(recentLabel(match))
                        .accessibilityHint("Opens this exact match. Poses do not open automatically.")
                    }
                    if recentError != nil {
                        Button { Task { await loadRecentMatches() } } label: {
                            PhysiqueResultPip(systemImage: "wifi.exclamationmark")
                                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .disabled(recentLoading)
                        .accessibilityLabel("Recent matches unavailable")
                        .accessibilityValue(recentError ?? "")
                        .accessibilityHint("Tries loading your recent matches again")
                    }
                }
            }
        }
    }

    private var battleDock: some View {
        let entry = nextStep
        return VStack(spacing: ProfileStyle.spacing) {
            Button { onOpen(.guide) } label: {
                PhysiquePoseLoadout(showsSharing: showsSharingNote)
            }
            .buttonStyle(PhysiqueGlowCardButtonStyle())
            .accessibilityLabel("Pose guide")
            .accessibilityValue(showsSharingNote ? "Three poses: front, side and rear. AI judged. Approved stills are shared with your opponent after a judged result." : "Three poses: front, side and rear. AI judged.")
            .accessibilityIdentifier("physique-pose-guide")
            HStack(spacing: ProfileStyle.spacing) {
                RankedIconAction(symbol: "list.bullet.clipboard", label: "Rules") { onOpen(.rules) }
                    .frame(maxWidth: .infinity)
                RankedIconAction(symbol: "clock.arrow.circlepath", label: "History", id: "physique-history") { onOpen(.history) }
                    .frame(maxWidth: .infinity)
                RankedIconAction(symbol: "shield", label: "Safety", id: "physique-safety") { onOpen(.safety) }
                    .frame(maxWidth: .infinity)
                RankedIconAction(symbol: "hand.raised", label: "Privacy", id: "physique-privacy") { onOpen(.privacy) }
                    .frame(maxWidth: .infinity)
            }
            VStack(spacing: EverSpacing.x2) {
                PhysiqueLobbyChip(entry.status, systemImage: entry.statusSymbol, busy: entry.busy)
                Button { activate(entry.action) } label: {
                    Label(entry.title, systemImage: entry.symbol)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(PhysiqueGlowButtonStyle())
                .disabled(entry.disabled || store.busy || checkingEntry)
                .accessibilityHint(entry.detail ?? "")
                .accessibilityIdentifier("physique-entry")
            }
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
            Text("Record and allowance")
                .font(TimeMasterFont.heading()).accessibilityAddTraits(.isHeader)
            if let account = currentAccount {
                recordDetails(account)
                freshness
            } else if !presentationActive || scenePhase != .active {
                Label("Private record hidden", systemImage: "lock").font(TimeMasterFont.body())
            } else {
                Text(activeAccountID == nil ? "Sign in to see your own record and allowance." : "Your record and allowance have not been confirmed.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            Divider()
            Text("Physique matches")
                .font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
            allowanceLabel
            if let next = currentAccount?.allowance.nextAvailableAt {
                Text("Next slot: \(Date(timeIntervalSince1970: next).formatted(.dateTime.year().month().day().hour().minute().timeZone()))")
                    .font(TimeMasterFont.secondary())
            }
            Text("This allowance is separate from exercise duels. Browsing does not use a match. Only the service confirms reservations, started matches and restored slots; a displayed time does not grant a slot locally.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            if let policy = currentPolicy, !policy.ready {
                Text(policy.unavailableReason ?? "Rated participation is not enabled by the service.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            refreshButton
            Divider()
            Label("How a duel works", systemImage: "info.circle")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("Three guided poses, followed by an AI judgement. Physique Elo is a separate competition record, not a health measurement.")
                Text("Images are processed by AI. After a judged result, your paired opponent can intentionally open approved stills. Review the current sharing terms before continuing.")
                Text("Browsing does not start matchmaking or open your camera.")
                routeButton("Read the rules", symbol: "list.bullet.clipboard", route: .rules)
            }
            .font(TimeMasterFont.secondary())
            .foregroundStyle(ProfileStyle.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func recordDetails(_ account: PhysiqueAccount) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84), alignment: .leading)],
                alignment: .leading,
                spacing: ProfileStyle.spacing
            ) {
                PhysiqueMetric(label: "Wins", value: account.record.wins.formatted())
                PhysiqueMetric(label: "Losses", value: account.record.losses.formatted())
                PhysiqueMetric(label: "Draws", value: account.record.draws.formatted())
            }
            PhysiqueMetric(label: "Best Physique Elo", value: account.record.best.map { $0.formatted() } ?? (account.record.games == 0 ? "Unplaced" : "Unavailable"))
            PhysiqueMetric(label: "Rated matches", value: account.record.games.formatted())
            PhysiqueMetric(label: "Win rate", value: account.record.games == 0 ? "Not available" : (Double(account.record.wins) / Double(account.record.games)).formatted(.percent.precision(.fractionLength(1))))
            Text("Wins, losses and draws include eligible rated forfeits once. Pending matches and no-contests do not count as rated results. Physique Elo is a competition rating, not an AI appearance score or a health measurement.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            routeButton("View detailed outcomes", symbol: "clock.arrow.circlepath", route: .history)
        }
    }

    private var allowanceLabel: some View {
        Group {
            if let allowance = currentAccount?.allowance {
                Text("\(allowance.remaining.formatted()) / \(allowance.limit.formatted()) matches available\(store.isStale ? " · Saved" : "")")
                    .accessibilityLabel("\(allowance.remaining.formatted()) of \(allowance.limit.formatted()) Physique matches available\(store.isStale ? ", saved record" : "")")
            } else if !accountStore.restored || accountStore.busy {
                Text("Checking match allowance")
            } else if activeAccountID == nil {
                Text("Match allowance · Sign in")
            } else {
                Text("Match allowance · Unavailable")
            }
        }
        .font(TimeMasterFont.caption())
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var freshness: some View {
        if let updated = store.lastRefreshedAt {
            Label("\(store.isStale ? "Saved" : "Updated") \(updated.formatted(date: .abbreviated, time: .shortened))", systemImage: store.isStale ? "wifi.exclamationmark" : "clock")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if store.loading {
            ProgressView("Refreshing record…").font(TimeMasterFont.caption())
        }
    }

    private var refreshButton: some View {
        Button { Task { await refreshLobby() } } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: controlHeight)
        }
        .buttonStyle(.borderless)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .font(TimeMasterFont.secondary())
        .disabled(refreshDisabled)
    }

    private var controlHeight: CGFloat {
        #if os(iOS)
        return ProfileStyle.touchTarget
        #else
        return 28
        #endif
    }

    private func routeButton(_ title: String, symbol: String, route: PhysiqueRoute) -> some View {
        Button {
            showsDetailsSheet = false
            onOpen(route)
        } label: {
            Label {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: controlHeight, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .font(TimeMasterFont.secondary())
    }

    private var refreshDisabled: Bool {
        store.loading || recentLoading || checkingEntry || accountStore.busy
    }

    private var canShowRecent: Bool {
        presentationActive && scenePhase == .active && activeAccountID != nil && recentAccountID == activeAccountID
    }

    private var showsSharingNote: Bool {
        accountStore.restored && !accountStore.busy
            && (currentAccount?.consent.accepted != true || currentAccount?.record.games == 0)
    }

    private var accountSymbol: String {
        guard accountStore.restored, !accountStore.busy else { return "person.crop.circle" }
        if activeAccountID == nil { return "person.badge.key" }
        return store.isStale ? "wifi.exclamationmark" : "person.crop.circle.badge.checkmark"
    }

    private var eloTitle: String {
        guard accountStore.restored, !accountStore.busy else { return "Checking…" }
        guard let identity = currentAccount?.identity else { return "— Elo" }
        if identity.games == 0 { return "Unplaced" }
        return identity.rating.map { "\($0.formatted()) Elo" } ?? "— Elo"
    }

    private var identityName: String {
        if let name = currentAccount?.identity.displayName, !name.isEmpty { return name }
        return profileStore.profile.displayName
    }

    private var crestRating: Int? {
        guard let identity = currentAccount?.identity, identity.games > 0 else { return nil }
        return identity.rating
    }

    private var crestCaption: String {
        guard let identity = currentAccount?.identity else { return "Elo" }
        if identity.games == 0 { return "Unplaced" }
        if identity.games < 5 { return "Provisional" }
        if let tier = identity.tier, !tier.isEmpty { return tier }
        return "Elo"
    }

    private var eloAccessibilityValue: String {
        guard let identity = currentAccount?.identity else {
            return activeAccountID == nil ? "Signed out" : "Physique Elo unavailable"
        }
        if identity.games == 0 { return "Unplaced" }
        let rating = identity.rating.map { "Physique Elo \($0.formatted())" } ?? "Physique Elo unavailable"
        return identity.games < 5 ? "\(rating), \(identity.placementLabel)" : rating
    }

    private var allowanceAccessibilityValue: String {
        if let allowance = currentAccount?.allowance {
            var value = "\(allowance.remaining.formatted()) of \(allowance.limit.formatted()) matches available"
            if let next = allowance.nextAvailableAt {
                value += ", next slot \(Date(timeIntervalSince1970: next).formatted(.dateTime.year().month().day().hour().minute().timeZone()))"
            }
            return store.isStale ? value + ", saved record" : value
        }
        if !accountStore.restored || accountStore.busy { return "Checking" }
        return activeAccountID == nil ? "Sign in to load" : "Unavailable"
    }

    private func slotTime(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        return Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func openIdentity() {
        onOpen(currentAccount == nil ? .account : .badges)
    }

    private func activate(_ action: EntryAction) {
        switch action {
        case .open(let route): onOpen(route)
        case .prepare: Task { await openPreparation() }
        case .refresh: Task { await store.refresh() }
        case .none: break
        }
    }

    private func openPreparation() async {
        guard let accountID = activeAccountID, !checkingEntry, !store.busy, !store.loading else { return }
        let requestID = UUID()
        entryRequestID = requestID
        let privacyRevision = store.privacyRevision
        checkingEntry = true
        defer {
            if entryRequestID == requestID {
                entryRequestID = nil
                checkingEntry = false
            }
        }
        await store.refresh()
        guard !Task.isCancelled, entryRequestID == requestID, activeAccountID == accountID, privacyRevision == store.privacyRevision, presentationActive, scenePhase == .active, !store.isStale, store.error == nil, !store.loading else { return }
        checkingEntry = false
        switch nextStep.action {
        case .open(let route): onOpen(route)
        case .prepare:
            guard let account = currentAccount, let policy = currentPolicy else { return }
            let sharingConfirmed = account.consent.accepted && account.consent.policyVersion == policy.version && !store.localProcessingStopped && !store.localOwnMediaHidden
            onOpen(sharingConfirmed ? .camera : .consent)
        case .refresh, .none: break
        }
    }

    private func route(for match: PhysiqueMatch) -> PhysiqueRoute {
        guard !match.stage.terminal, store.match?.id == match.id else { return .result(match.id) }
        switch match.stage {
        case .searching: return .search
        case .ready: return .ready
        case .countdown, .capture: return .battle
        case .submitting, .judging: return .judging
        default: return .result(match.id)
        }
    }

    private func opponentName(in match: PhysiqueMatch) -> String {
        if store.locallyBlockedIDs.contains(match.opponent.identity.id) { return "Blocked player" }
        return match.opponent.identity.displayName.isEmpty ? "Unavailable player" : match.opponent.identity.displayName
    }

    private func isWin(_ match: PhysiqueMatch) -> Bool {
        match.result?.outcome == "win" || match.result?.outcome == "forfeitWin"
    }

    private func outcomeSymbol(_ match: PhysiqueMatch) -> String {
        switch match.result?.outcome {
        case "win": return "arrow.up.right"
        case "loss": return "arrow.down.right"
        case "draw": return "equal"
        case "forfeitWin": return "flag.fill"
        case "forfeitLoss": return "flag"
        case "noContest": return "minus"
        default: return match.stage.terminal ? "questionmark" : "hourglass"
        }
    }

    private func recentLabel(_ match: PhysiqueMatch) -> String {
        let outcome = match.result?.title ?? (match.stage.terminal ? "Result unavailable" : "Pending")
        let date = Date(timeIntervalSince1970: match.startAt ?? match.createdAt).formatted(date: .abbreviated, time: .shortened)
        let corrected = match.result?.corrected == true ? ", corrected" : ""
        return "\(outcome) against \(opponentName(in: match)), \(date), \(ratingEffect(in: match))\(corrected)"
    }

    private func ratingEffect(in match: PhysiqueMatch) -> String {
        if match.result?.outcome == "noContest" || match.stage == .noContest { return "No rating change" }
        guard let receipt = match.result?.rating else { return match.stage.terminal ? "Rating unavailable" : "Pending" }
        return "\(receipt.change > 0 ? "+" : "")\(receipt.change.formatted()) Physique Elo"
    }

    private func clearPrivateState() {
        recentRequestID = nil
        recentMatches.removeAll()
        recentAccountID = nil
        recentLoading = false
        recentError = nil
        entryRequestID = nil
        checkingEntry = false
        showsDetailsSheet = false
        showsInspector = false
    }

    private func refreshLobby() async {
        guard accountStore.restored, !accountStore.busy, presentationActive, scenePhase == .active else { return }
        guard activeAccountID != nil, store.signedIn else {
            await store.loadPolicy()
            return
        }
        async let summary: Void = store.refresh()
        async let history: Void = loadRecentMatches()
        _ = await (summary, history)
    }

    private func loadRecentMatches() async {
        guard let accountID = activeAccountID, store.signedIn, !recentLoading else { return }
        let requestID = UUID()
        recentRequestID = requestID
        recentAccountID = accountID
        recentLoading = true
        defer {
            if recentRequestID == requestID { recentLoading = false }
        }
        do {
            var matches: [PhysiqueMatch] = []
            var cursor: String?
            var visitedCursors: Set<String> = []
            repeat {
                let page = try await store.history(cursor: cursor)
                guard !Task.isCancelled, recentRequestID == requestID, activeAccountID == accountID else { return }
                for match in page.items where match.startAt != nil {
                    guard match.stage != .cancelled, match.stage != .noOpponent, match.stage != .ready, match.stage != .countdown, match.stage != .searching, match.stage != .idle else { continue }
                    if !matches.contains(where: { $0.id == match.id }) { matches.append(match) }
                    if matches.count == 3 { break }
                }
                cursor = page.cursor
                if let cursor, !visitedCursors.insert(cursor).inserted { break }
            } while matches.count < 3 && cursor != nil
            guard !Task.isCancelled, recentRequestID == requestID, activeAccountID == accountID else { return }
            recentMatches = matches
            recentError = nil
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, recentRequestID == requestID, activeAccountID == accountID else { return }
            recentError = error.localizedDescription
        }
    }
}
