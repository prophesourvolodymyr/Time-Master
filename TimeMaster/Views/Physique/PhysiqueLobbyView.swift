import SwiftUI

@MainActor
struct PhysiqueLobbyView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @State private var recentMatches: [PhysiqueMatch] = []
    @State private var pendingRecentMatches: [PhysiqueMatch]?
    @State private var recentAccountID: String?
    @State private var recentLoading = false
    @State private var recentLoaded = false
    @State private var recentError: String?
    @State private var recentRequestID: UUID?
    @State private var checkingEntry = false
    @State private var entryRequestID: UUID?
    @State private var recordExpanded = false
    @State private var showsDetailsSheet = false
    @State private var showsInspector = false
    @State private var contextExpanded = false

    private enum EntryAction {
        case open(PhysiqueRoute), prepare, refresh, none
    }

    private struct Entry {
        let title: String
        let symbol: String
        let detail: String?
        let action: EntryAction
        var disabled = false
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
            return Entry(title: "Checking account", symbol: "person.crop.circle", detail: "Restoring your Tmax account.", action: .none, disabled: true)
        }
        guard activeAccountID != nil, store.signedIn else {
            return Entry(title: "Find opponent", symbol: "person.badge.key", detail: "Sign in to keep your own Physique record.", action: .open(.account))
        }
        guard presentationActive, scenePhase == .active else {
            return Entry(title: "Physique is private", symbol: "lock", detail: nil, action: .none, disabled: true)
        }
        if checkingEntry || store.loading {
            return Entry(title: "Checking availability", symbol: "arrow.clockwise", detail: "Confirming your account and active match.", action: .none, disabled: true)
        }
        guard let account = currentAccount else {
            return Entry(title: "Retry status", symbol: "arrow.clockwise", detail: "Record and match availability are unconfirmed.", action: .refresh)
        }
        if store.isStale {
            return Entry(title: "Check status", symbol: "arrow.clockwise", detail: "Saved record. Reconnect to start or resume.", action: .refresh)
        }
        if store.cancellationPending {
            return Entry(title: "Check cancellation", symbol: "arrow.clockwise", detail: "Confirm the previous cancellation before another search.", action: .open(.search))
        }
        if let match = store.match, !match.stage.terminal {
            let anotherWindow = !store.canControl(from: windowID)
            let title = anotherWindow ? "View active match" : match.stage == .judging || match.stage == .submitting ? "View match" : match.stage == .searching ? "Resume search" : "Resume match"
            let detail = anotherWindow ? "Another window controls this session. Review its status to continue." : match.stage.title
            return Entry(title: title, symbol: "arrow.right.circle", detail: detail, action: .open(route(for: match)))
        }
        if store.stage == .searching {
            return Entry(title: "Resume search", symbol: "person.2", detail: "Continue your existing search.", action: .open(.search))
        }
        if let reason = account.restrictedReason, !reason.isEmpty {
            return Entry(title: "View restriction", symbol: "shield", detail: reason, action: .open(.safety))
        }
        guard let policy = currentPolicy, policy.ready else {
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: currentPolicy?.unavailableReason ?? "Rated matches are unavailable until the service confirms participation.", action: .none, disabled: true)
        }
        guard account.allowance.remaining > 0 else {
            return Entry(title: "Find opponent", symbol: "bolt.fill", detail: account.allowance.nextAvailableAt == nil ? "No matches available. Refresh to check the next slot." : "No matches available. Refresh after the next slot to confirm.", action: .none, disabled: true)
        }
        if store.localProcessingStopped || store.localOwnMediaHidden {
            return Entry(title: "Review sharing choices", symbol: "hand.raised", detail: "Processing or sharing is stopped. Review your choices to continue.", action: .prepare)
        }
        guard account.consent.accepted, account.consent.policyVersion == policy.version else {
            return Entry(title: "Review eligibility", symbol: "hand.raised", detail: "Review adult eligibility, rules and image sharing.", action: .prepare)
        }
        let detail: String
        switch store.stage {
        case .noOpponent: detail = "No opponent found. Prepare to try again."
        case .cancelled: detail = "Search cancelled. Prepare when you're ready."
        default: detail = "Camera setup comes next. No search starts here."
        }
        return Entry(title: "Find opponent", symbol: "bolt.fill", detail: detail, action: .prepare)
    }

    var body: some View {
        GeometryReader { viewport in
            let frame = viewport.frame(in: .global)
            let contentBounds = frame.intersection(navigationBounds ?? frame)
            let pinsEntry = contentBounds.height >= ProfileStyle.touchTarget * 10 && !dynamicTypeSize.isAccessibilitySize
            let inspectorFits = viewport.size.width >= ProfileStyle.readableWidth + 300 + ProfileStyle.inset * 3
            let wide = viewport.size.width >= 760 && !showsInspector && !dynamicTypeSize.isAccessibilitySize
            let lobbyWidth: CGFloat = wide ? 1040 : ProfileStyle.readableWidth
            let heroWidth = min(lobbyWidth, max(0, viewport.size.width - ProfileStyle.inset * 2 - (showsInspector ? 360 : 0)))

            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
                    #if os(iOS)
                    phoneHeading
                    #endif
                    PhysiqueLobbyHero(wide: wide, availableWidth: heroWidth)
                    statusSection
                    if !pinsEntry {
                        entryBar(wide: wide)
                    }
                    scoreboard(wide: wide)
                    utilityRoutes
                    recentSection
                    participationContext
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: lobbyWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await refreshLobby() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pinsEntry {
                    entryBar(wide: wide)
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: lobbyWidth)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surface)
                        .overlay(alignment: .top) { Divider() }
                }
            }
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
                        .disabled(store.loading || recentLoading || checkingEntry)
                }
            }
            #endif
        }
        .background(Theme.background.ignoresSafeArea())
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

    private var phoneHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ProfileStyle.spacing) {
                routeButton("Rules", symbol: "list.bullet.clipboard", route: .rules)
                routeButton("Account", symbol: "person.crop.circle", route: .account)
                refreshButton
            }
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                routeButton("Rules", symbol: "list.bullet.clipboard", route: .rules)
                routeButton("Account", symbol: "person.crop.circle", route: .account)
                refreshButton
            }
        }
    }

    private func scoreboard(wide: Bool) -> some View {
        let layout = wide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 40))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        return layout {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                identitySection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let account = currentAccount {
                recordSection(account)
                    .frame(width: wide ? 300 : nil, alignment: .leading)
            }
        }
        .padding(.top, 24)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 48, height: 2)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var identitySection: some View {
        if !presentationActive || scenePhase != .active {
            Label("Private Physique record", systemImage: "lock")
                .font(TimeMasterFont.heading())
        } else if !accountStore.restored || accountStore.busy {
            ProgressView("Restoring account…")
                .font(TimeMasterFont.body())
        } else if activeAccountID == nil || !store.signedIn {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("YOUR CORNER")
                    .font(TimeMasterFont.black(11, relativeTo: .caption))
                    .tracking(1.8)
                    .foregroundStyle(Theme.toolbarOrange)
                Text("Your record starts with you.")
                    .font(TimeMasterFont.heading())
                Text("Sign in for your own Physique Elo and match history.")
                    .font(TimeMasterFont.secondary())
            }
        } else if let account = currentAccount {
            PhysiqueIdentityRail(identity: account.identity, ownerLabel: "Your corner") { _ in onOpen(.badges) }
            freshness
            Button { onOpen(.badges) } label: {
                Label("Your badges and country", systemImage: "medal")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: controlHeight, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .font(TimeMasterFont.secondary())
        } else if store.loading {
            ProgressView("Loading your Physique record…")
                .font(TimeMasterFont.body())
        } else {
            PhysiqueStatusView(title: "Record unavailable", detail: "Your Physique record has not loaded. Check status to retrieve your own rating, badges and allowance.", systemImage: "person.crop.circle.badge.exclamationmark")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let error = store.error, accountStore.restored, !accountStore.busy, presentationActive, scenePhase == .active {
            PhysiqueStatusView(title: store.isStale ? "Using saved record" : "Unable to confirm Physique", detail: error, systemImage: "wifi.exclamationmark")
        }
        if activeAccountID == nil, let policy = currentPolicy, !policy.ready, presentationActive, scenePhase == .active {
            PhysiqueStatusView(title: "Matches unavailable", detail: policy.unavailableReason ?? "The service has not enabled rated participation.", systemImage: "pause.circle")
        }
    }

    private func recordSection(_ account: PhysiqueAccount) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 200 : 84), alignment: .leading)],
                alignment: .leading,
                spacing: ProfileStyle.spacing
            ) {
                PhysiqueMetric(label: "Wins", value: account.record.wins.formatted())
                PhysiqueMetric(label: "Losses", value: account.record.losses.formatted())
                PhysiqueMetric(label: "Draws", value: account.record.draws.formatted())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Best Physique Elo")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(account.record.best.map { $0.formatted() } ?? (account.record.games == 0 ? "Unplaced" : "Unavailable"))
                    .font(TimeMasterFont.rowTitle())
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            #if os(iOS)
            DisclosureGroup("Record details", isExpanded: $recordExpanded) {
                recordDetails(account)
                    .padding(.top, ProfileStyle.spacing)
            }
            .font(TimeMasterFont.secondary())
            .animation(disclosureAnimation, value: recordExpanded)
            #endif
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var utilityRoutes: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: ProfileStyle.spacing) {
            routeButton("Pose guide", symbol: "figure.stand", route: .guide)
            routeButton("Standings", symbol: "list.number", route: .standings)
            routeButton("Safety and support", symbol: "shield", route: .safety)
            routeButton("Privacy and sharing", symbol: "hand.raised", route: .privacy)
        }
    }

    private var participationContext: some View {
        DisclosureGroup(isExpanded: $contextExpanded) {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("Three guided poses, followed by an AI judgement. Physique Elo is a separate competition record, not a health measurement.")
                Text("Images are processed by AI. After a judged result, your paired opponent can intentionally open approved stills. Review the current sharing terms before continuing.")
                Text("Browsing does not start matchmaking or open your camera.")
                routeButton("Read the rules", symbol: "list.bullet.clipboard", route: .rules)
            }
            .font(TimeMasterFont.secondary())
            .foregroundStyle(ProfileStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, ProfileStyle.spacing)
        } label: {
            Label("How a duel works", systemImage: "info.circle")
                .font(TimeMasterFont.rowTitle())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, ProfileStyle.spacing)
        .overlay(alignment: .top) { Divider() }
        .animation(disclosureAnimation, value: contextExpanded)
    }

    private var disclosureAnimation: Animation? {
        let process = ProcessInfo.processInfo
        guard presentationActive, scenePhase == .active, !liveResizing, !reduceMotion,
              !process.isLowPowerModeEnabled,
              process.thermalState != .serious, process.thermalState != .critical else { return nil }
        return .easeInOut(duration: 0.22)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Recent").font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: ProfileStyle.spacing)
                    routeButton("History", symbol: "clock.arrow.circlepath", route: .history)
                }
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Recent").font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
                    routeButton("History", symbol: "clock.arrow.circlepath", route: .history)
                }
            }
            if !presentationActive || scenePhase != .active {
                Text("Private matches are hidden.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            } else if !accountStore.restored || accountStore.busy {
                Text("Checking account…")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            } else if activeAccountID == nil {
                Text("Sign in to view your private matches.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            } else if recentAccountID == activeAccountID {
                if let error = recentError {
                    Label("Recent matches unavailable", systemImage: "wifi.exclamationmark")
                        .font(TimeMasterFont.rowTitle())
                    Text(error).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    if !recentMatches.isEmpty {
                        Text("Saved recent matches").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    }
                    Button("Retry recent matches") { Task { await loadRecentMatches() } }
                        .buttonStyle(.bordered)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                        .disabled(recentLoading)
                }
                if pendingRecentMatches != nil {
                    Button {
                        if let pendingRecentMatches { recentMatches = pendingRecentMatches }
                        pendingRecentMatches = nil
                    } label: {
                        Label("New results available", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                }
                ForEach(recentMatches) { match in
                    recentRow(match)
                }
                if recentMatches.isEmpty, recentLoaded, recentError == nil, pendingRecentMatches == nil {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("No physique matches yet").font(TimeMasterFont.rowTitle())
                        Text("Your started matches will appear here. Searches do not count as matches.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    }
                }
                if recentLoading {
                    ProgressView(recentMatches.isEmpty ? "Loading recent matches…" : "Refreshing recent matches…")
                        .font(TimeMasterFont.secondary())
                }
            } else {
                ProgressView("Loading recent matches…").font(TimeMasterFont.secondary())
            }
        }
    }

    private func recentRow(_ match: PhysiqueMatch) -> some View {
        Button { onOpen(route(for: match)) } label: {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
                Label(match.result?.title ?? (match.stage.terminal ? "Result unavailable" : "Pending"), systemImage: outcomeSymbol(match.result?.outcome))
                    .font(TimeMasterFont.rowTitle())
                Text(opponentName(in: match))
                    .font(TimeMasterFont.secondary())
                Text(Date(timeIntervalSince1970: match.startAt ?? match.createdAt), format: .dateTime.month().day().year().hour().minute())
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                Text(ratingEffect(in: match))
                    .font(TimeMasterFont.secondary()).monospacedDigit()
                if match.result?.corrected == true {
                    Label("Corrected", systemImage: "arrow.triangle.2.circlepath")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, ProfileStyle.spacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: 0))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this exact match. Poses do not open automatically.")
        .overlay(alignment: .bottom) { Divider() }
    }

    private func entryBar(wide: Bool) -> some View {
        let entry = nextStep
        let layout = wide
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 32))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        return VStack(alignment: .leading, spacing: 10) {
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    allowanceSummary
                    if let detail = entry.detail {
                        Text(detail)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PhysiqueAction(title: entry.title, systemImage: entry.symbol, disabled: entry.disabled || store.busy || checkingEntry) {
                    activate(entry.action)
                }
                .frame(width: wide ? 320 : nil)
                .accessibilityHint(entry.detail ?? "")
            }
            if accountStore.restored, !accountStore.busy, currentAccount?.consent.accepted != true || currentAccount?.record.games == 0 {
                Text("AI processing · Opponent sharing after a judged result.")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var allowanceSummary: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                    allowanceLabel
                    Spacer(minLength: 0)
                    allowanceDetailsButton
                }
                VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
                    allowanceLabel
                    allowanceDetailsButton
                }
            }
            if let next = currentAccount?.allowance.nextAvailableAt {
                Text("Next slot: \(Date(timeIntervalSince1970: next).formatted(date: .abbreviated, time: .shortened))")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .accessibilityLabel("Next Physique slot, \(Date(timeIntervalSince1970: next).formatted(.dateTime.year().month().day().hour().minute().timeZone()))")
            }
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

    private var allowanceDetailsButton: some View {
        Button { showsDetailsSheet = true } label: {
            Label("Allowance details", systemImage: "info.circle")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: controlHeight)
        }
        .buttonStyle(.borderless)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .font(TimeMasterFont.caption())
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
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func recordDetails(_ account: PhysiqueAccount) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            PhysiqueMetric(label: "Rated matches", value: account.record.games.formatted())
            PhysiqueMetric(label: "Win rate", value: account.record.games == 0 ? "Not available" : (Double(account.record.wins) / Double(account.record.games)).formatted(.percent.precision(.fractionLength(1))))
            Text("Wins, losses and draws include eligible rated forfeits once. Pending matches and no-contests do not count as rated results. Physique Elo is a competition rating, not an AI appearance score or a health measurement.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            routeButton("View detailed outcomes", symbol: "clock.arrow.circlepath", route: .history)
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
        .disabled(store.loading || recentLoading || checkingEntry || accountStore.busy)
    }

    private var controlHeight: CGFloat {
        #if os(iOS)
        return ProfileStyle.touchTarget
        #else
        return 28
        #endif
    }

    private func routeButton(_ title: String, symbol: String, route: PhysiqueRoute) -> some View {
        Button { onOpen(route) } label: {
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

    private func outcomeSymbol(_ outcome: String?) -> String {
        switch outcome {
        case "win": return "arrow.up.right.circle"
        case "loss": return "arrow.down.right.circle"
        case "draw": return "equal.circle"
        case "forfeitWin", "forfeitLoss": return "flag"
        case "noContest": return "minus.circle"
        default: return "hourglass"
        }
    }

    private func ratingEffect(in match: PhysiqueMatch) -> String {
        if match.result?.outcome == "noContest" || match.stage == .noContest { return "No rating change" }
        guard let receipt = match.result?.rating else { return match.stage.terminal ? "Rating unavailable" : "Pending" }
        return "\(receipt.change > 0 ? "+" : "")\(receipt.change.formatted()) Physique Elo"
    }

    private func clearPrivateState() {
        recentRequestID = nil
        recentMatches.removeAll()
        pendingRecentMatches = nil
        recentAccountID = nil
        recentLoading = false
        recentLoaded = false
        recentError = nil
        entryRequestID = nil
        checkingEntry = false
        recordExpanded = false
        contextExpanded = false
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
            let previousIDs = Set(recentMatches.map(\.id))
            let incomingIDs = Set(matches.map(\.id))
            if !recentMatches.isEmpty, !incomingIDs.subtracting(previousIDs).isEmpty {
                let updatedByID = Dictionary(uniqueKeysWithValues: matches.map { ($0.id, $0) })
                recentMatches = recentMatches.compactMap { updatedByID[$0.id] }
                pendingRecentMatches = matches
            } else {
                recentMatches = matches
                pendingRecentMatches = nil
            }
            recentError = nil
            recentLoaded = true
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, recentRequestID == requestID, activeAccountID == accountID else { return }
            recentError = error.localizedDescription
        }
    }
}
