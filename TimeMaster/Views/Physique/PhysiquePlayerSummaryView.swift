import SwiftUI

@MainActor
struct PhysiquePlayerSummaryView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let playerID: String

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPlayer: PhysiqueStanding?
    @State private var loadedAccountID: String?
    @State private var loadedPlayerID: String?
    @State private var loadedAt: Date?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var connectionFailed = false
    @State private var refreshID = UUID()
    @State private var requestID = UUID()
    @State private var selectedBadgeID: String?
    @State private var selectedBadgeScope: String?
    @State private var showsBlockConfirmation = false
    @State private var proposedBlockContext: String?
    @State private var isBlocking = false
    @State private var blockConfirmed = false
    @State private var blockMessage: String?
    @State private var reportMatchID: String?
    @AccessibilityFocusState private var protectionFocused: Bool

    private struct LoadContext: Hashable {
        let accountID: String?
        let playerID: String
        let refreshID: UUID
        let active: Bool
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var isActive: Bool { scenePhase == .active && presentationActive }

    private var loadContext: LoadContext {
        LoadContext(accountID: activeAccountID, playerID: playerID, refreshID: refreshID, active: isActive)
    }

    private var isCurrentViewer: Bool {
        activeAccountID != nil && loadedAccountID == activeAccountID && loadedPlayerID == playerID
    }

    private var isOwnPlayer: Bool {
        activeAccountID != nil && store.account?.identity.id == playerID
    }

    private var isHidden: Bool {
        isCurrentViewer && (blockConfirmed || store.locallyBlockedIDs.contains(playerID))
    }

    private var permittedCurrentPlayer: PhysiqueStanding? {
        guard isActive, isCurrentViewer, !isHidden else { return nil }
        return currentPlayer
    }

    private var contextMatch: PhysiqueMatch? {
        guard isActive, isCurrentViewer, let match = store.match,
              match.you.identity.id == playerID || match.opponent.identity.id == playerID else { return nil }
        return match
    }

    private var contextIdentity: PhysiqueIdentity? {
        guard !isHidden, let match = contextMatch else { return nil }
        return match.you.identity.id == playerID ? match.you.identity : match.opponent.identity
    }

    private var hasStarted: Bool {
        guard let match = contextMatch else { return false }
        switch match.stage {
        case .capture, .submitting, .judging, .completed, .forfeited: return true
        default: return false
        }
    }

    private var pairingTitle: String {
        if contextMatch?.stage == .noContest { return "Match context" }
        return hasStarted ? "At match start" : "This pairing"
    }

    private var blockContext: String {
        guard let match = contextMatch, match.opponent.identity.id == playerID else { return "discovery" }
        if match.stage.terminal { return match.id + ":final" }
        return match.id + (hasStarted ? ":afterGo" : ":beforeGo")
    }

    private var blockConsequence: String {
        guard let match = contextMatch, match.opponent.identity.id == playerID else {
            return "Hide this player here immediately. Once the service confirms the block, this player is excluded from future pairings. Your rating does not change."
        }
        if match.stage.terminal {
            return "Hide this player and remove access to shared poses. Your existing result and rating remain unchanged. Future pairings are excluded once the service confirms the block."
        }
        if hasStarted {
            return "Hide this player and related media, and prevent future pairings once confirmed. Blocking does not leave or end this match and does not change its rating. Leaving remains a separate match action."
        }
        return "Hide this player immediately. Once confirmed before Go, blocking cancels this pairing and releases its reservation without changing Elo. If Go occurs first, blocking only hides the player and prevents future pairings; it never forfeits the match."
    }

    var body: some View {
        PhysiqueScreen(title: "Player", subtitle: "Physique identity and permitted record") {
            if !isActive {
                PhysiqueStatusView(title: "Player details hidden", detail: "Return to check the current permitted player details.", systemImage: "lock")
            } else if !accountStore.restored || accountStore.busy {
                ProgressView("Resolving account access…")
            } else if activeAccountID == nil {
                PhysiqueStatusView(title: "Sign in to view players", detail: "Player details are checked for the current account.", systemImage: "person.crop.circle")
                PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { onOpen(.account) }
                safetyLink
            } else if isHidden {
                protectionStatus
            } else {
                playerContent
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { activeMatchHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) { playerActions }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: close)
                    .physiqueToolbarTarget()
            }
            ToolbarItem(placement: .automatic) {
                Button(action: requestRefresh) {
                    Label("Refresh player", systemImage: "arrow.clockwise")
                }
                .physiqueToolbarTarget()
                .disabled(isLoading || isBlocking || activeAccountID == nil || !isActive)
            }
        }
        .task(id: loadContext) { await loadPlayer(context: loadContext) }
        .refreshable { await loadPlayer(context: loadContext) }
        .onAppear { store.suspendCapture() }
        .onDisappear { store.suspendCapture() }
        .onChange(of: store.match?.stage) { stage in
            if stage?.terminal == true { requestRefresh() }
        }
        .onChange(of: store.locallyBlockedIDs.contains(playerID)) { hidden in
            if hidden {
                currentPlayer = nil
                clearBadgeSelection()
                protectionFocused = true
            }
        }
        .onChange(of: activeAccountID) { accountID in
            if loadedAccountID != accountID { resetPlayer() }
        }
        .onChange(of: playerID) { targetID in
            if loadedPlayerID != targetID { resetPlayer() }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #elseif os(macOS)
        .onExitCommand {
            if selectedBadgeID != nil { clearBadgeSelection() }
            else { close() }
        }
        #endif
    }

    @ViewBuilder
    private var playerContent: some View {
        if let identity = contextIdentity, let match = contextMatch {
            PhysiqueSection(title: pairingTitle) {
                identityCard(identity, scope: "match")
                if let startAt = match.startAt, hasStarted {
                    Text(Date(timeIntervalSince1970: startAt), format: .dateTime.year().month().day().hour().minute())
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .accessibilityLabel("Match start")
                        .accessibilityValue(Date(timeIntervalSince1970: startAt).formatted(date: .abbreviated, time: .shortened))
                }
                Text("This identity and rating belong to this pairing, not the current public record.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        PhysiqueSection(title: "Current public") {
            if let player = permittedCurrentPlayer {
                identityCard(player.identity, scope: "current")
                publicRecord(player.record)
                if let loadedAt {
                    Text("Loaded \(loadedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                if isLoading { ProgressView("Checking current access…") }
            } else if isLoading || !isCurrentViewer {
                ProgressView(contextIdentity == nil ? "Loading player…" : "Loading current public details…")
            } else {
                PhysiqueStatusView(
                    title: connectionFailed ? "Could not load player" : "Player unavailable",
                    detail: connectionFailed
                        ? "Check your connection and try again. No saved public details are being shown."
                        : "Current public details are not available for this account. Only an authorized pairing context, if present, remains visible.",
                    retry: requestRefresh
                )
                if loadFailed {
                    Button("Account and sign-in") { onOpen(.account) }
                        .buttonStyle(TimeMasterActionButtonStyle())
                }
            }
        }
        if isOwnPlayer, store.account?.listed == false {
            Label("You are not listed publicly.", systemImage: "eye.slash")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
        if isOwnPlayer, store.account?.restrictedReason != nil {
            PhysiqueStatusView(title: "Some account actions are limited", detail: "Safety and support remain available. Account restrictions are not public player information.", systemImage: "hand.raised")
            safetyLink
        }
        if let blockMessage {
            Text(blockMessage)
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func identityCard(_ identity: PhysiqueIdentity, scope: String) -> some View {
        PhysiqueCard {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(ProfileStyle.secondary)
                .accessibilityHidden(true)
            PhysiqueIdentityRail(identity: identity, ownerLabel: isOwnPlayer ? "You" : "Player") { badge in
                selectBadge(badge, scope: scope)
            }
            if identity.countryCode?.isEmpty != false {
                Label("Country not shared", systemImage: "globe")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if identity.badges.isEmpty {
                Text("No badges yet")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if selectedBadgeScope == scope,
               let badge = identity.badges.first(where: { $0.id == selectedBadgeID }) {
                Divider()
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text(badge.title)
                        .font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                    Text(badge.detail.isEmpty ? "The service has not supplied an explanation for this badge." : badge.detail)
                        .fixedSize(horizontal: false, vertical: true)
                    if let earnedAt = badge.earnedAt {
                        Text("Earned \(Date(timeIntervalSince1970: earnedAt).formatted(date: .abbreviated, time: .omitted))")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    Text("A Physique achievement is not identity verification.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    Button("Close badge explanation", action: clearBadgeSelection)
                        .buttonStyle(TimeMasterActionButtonStyle())
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func publicRecord(_ record: PhysiqueRecord) -> some View {
        PhysiqueCard {
            Text("Rated record")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            if record.games == 0 {
                Text("No rated matches")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: ProfileStyle.inset) {
                PhysiqueMetric(label: "Wins", value: record.wins.formatted())
                PhysiqueMetric(label: "Losses", value: record.losses.formatted())
                PhysiqueMetric(label: "Draws", value: record.draws.formatted())
                PhysiqueMetric(label: "Rated matches", value: record.games.formatted())
            }
            Text("Rated wins and losses include eligible forfeits. No-contests and pending matches are not included.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var protectionStatus: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            PhysiqueStatusView(
                title: blockConfirmed ? "Blocked player" : "Hidden here · block not confirmed",
                detail: isBlocking
                    ? "This player is hidden here now. Waiting for the service to confirm protection on other devices and future pairings."
                    : blockConfirmed
                        ? "The service confirmed this block. Existing results and ratings remain unchanged. Manage blocks in Safety and support."
                        : "Local protection is active. Other devices and future pairing protection have not been confirmed. Retry to reconcile the same player.",
                systemImage: "person.slash"
            )
            .accessibilityFocused($protectionFocused)
            if isBlocking {
                ProgressView("Confirming block…")
            } else if !blockConfirmed {
                PhysiqueAction(title: "Retry block confirmation", systemImage: "arrow.clockwise") {
                    Task { await blockPlayer() }
                }
            }
            if let blockMessage {
                Text(blockMessage)
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
            if blockConfirmed, contextMatch?.stage == .cancelled {
                PhysiqueAction(title: "Back to lobby", systemImage: "arrow.left") { onOpen(.lobby) }
            }
            safetyLink
        }
    }

    @ViewBuilder
    private var activeMatchHeader: some View {
        if let match = contextMatch, !match.stage.terminal {
            VStack(spacing: ProfileStyle.spacing) {
                if let clock = clock(for: match) {
                    PhysiqueTimerView(clock: clock)
                } else {
                    Text(match.stage.title)
                        .font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                }
                Button(action: returnToMatch) {
                    Label("Return to match", systemImage: "arrow.uturn.backward")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(TimeMasterActionButtonStyle(fillsWidth: true))
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
        }
    }

    private var safetyActionLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(spacing: ProfileStyle.spacing))
        }
        return AnyLayout(HStackLayout(spacing: ProfileStyle.spacing))
    }

    @ViewBuilder
    private var playerActions: some View {
        if isActive, isCurrentViewer, !isOwnPlayer, !playerID.isEmpty {
            safetyActionLayout {
                Button(action: reportPlayer) {
                    Label("Report player", systemImage: "flag")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(TimeMasterActionButtonStyle(fillsWidth: true))
                if !isHidden {
                    Button(role: .destructive, action: beginBlockConfirmation) {
                        Label("Block player", systemImage: "person.slash")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(fillsWidth: true))
                    .confirmationDialog("Block player?", isPresented: $showsBlockConfirmation, titleVisibility: .visible) {
                        Button("Block player", role: .destructive, action: confirmBlock)
                        Button("Cancel", role: .cancel) { proposedBlockContext = nil }
                    } message: {
                        Text(blockConsequence)
                    }
                }
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
        }
    }

    private var safetyLink: some View {
        Button {
            store.suspendCapture()
            onOpen(.safety)
        } label: {
            Label("Safety and support", systemImage: "shield")
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(TimeMasterActionButtonStyle())
    }

    private func clock(for match: PhysiqueMatch) -> PhysiqueClock? {
        switch match.stage {
        case .countdown:
            return PhysiqueClock(mode: match.startAt == nil ? .unavailable : .countdown, label: "Match starts in", endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture, .submitting:
            return PhysiqueClock(mode: match.deadline == nil ? .unavailable : .remaining, label: "Capture time remaining", endpoint: match.deadline, serverOffset: store.serverOffset)
        case .judging:
            return PhysiqueClock(mode: match.judgingStartedAt == nil ? .unavailable : .elapsed, label: "Judging elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        default:
            return nil
        }
    }

    private func loadPlayer(context: LoadContext) async {
        let request = UUID()
        requestID = request
        if loadedAccountID != context.accountID || loadedPlayerID != context.playerID {
            resetPlayer()
        }
        guard context.active, let accountID = context.accountID, !context.playerID.isEmpty else {
            resetPlayer()
            isLoading = false
            return
        }
        loadedAccountID = accountID
        loadedPlayerID = context.playerID
        isLoading = true
        loadFailed = false
        connectionFailed = false
        defer { if requestID == request { isLoading = false } }
        if !isOwnPlayer {
            if let blocks = try? await store.blocks(), requestStillCurrent(request, context: context) {
                blockConfirmed = blocks.contains { $0.id == context.playerID }
            }
            guard requestStillCurrent(request, context: context) else { return }
            if isHidden {
                currentPlayer = nil
                loadedAt = nil
                return
            }
        }
        do {
            let player = try await store.player(context.playerID)
            guard requestStillCurrent(request, context: context), !isHidden else { return }
            guard player.identity.id == context.playerID else {
                currentPlayer = nil
                loadedAt = nil
                loadFailed = true
                return
            }
            currentPlayer = player
            loadedAt = Date()
        } catch is CancellationError {
        } catch {
            guard requestStillCurrent(request, context: context) else { return }
            currentPlayer = nil
            loadedAt = nil
            clearBadgeSelection()
            loadFailed = true
            connectionFailed = error is URLError
        }
    }

    private func requestStillCurrent(_ request: UUID, context: LoadContext) -> Bool {
        requestID == request && !Task.isCancelled && isActive && context.accountID == activeAccountID && context.playerID == playerID
    }

    private func resetPlayer() {
        currentPlayer = nil
        loadedAccountID = nil
        loadedPlayerID = nil
        loadedAt = nil
        loadFailed = false
        connectionFailed = false
        clearBadgeSelection()
        showsBlockConfirmation = false
        proposedBlockContext = nil
        isBlocking = false
        blockConfirmed = false
        blockMessage = nil
        reportMatchID = nil
    }

    private func requestRefresh() { refreshID = UUID() }

    private func selectBadge(_ badge: PhysiqueBadge, scope: String) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            if selectedBadgeID == badge.id && selectedBadgeScope == scope {
                clearBadgeSelection()
            } else {
                selectedBadgeID = badge.id
                selectedBadgeScope = scope
            }
        }
    }

    private func clearBadgeSelection() {
        selectedBadgeID = nil
        selectedBadgeScope = nil
    }

    private func beginBlockConfirmation() {
        guard !isOwnPlayer, isCurrentViewer else { return }
        proposedBlockContext = blockContext
        blockMessage = nil
        showsBlockConfirmation = true
    }

    private func confirmBlock() {
        guard proposedBlockContext == blockContext else {
            blockMessage = "The match changed. Review the current block consequences and confirm again. No block or leave request was sent."
            proposedBlockContext = nil
            return
        }
        proposedBlockContext = nil
        Task { await blockPlayer() }
    }

    private func blockPlayer() async {
        guard let accountID = activeAccountID, isCurrentViewer, !isOwnPlayer, !isBlocking else { return }
        let targetID = playerID
        reportMatchID = contextMatch?.id ?? reportMatchID
        currentPlayer = nil
        loadedAt = nil
        clearBadgeSelection()
        store.suspendCapture()
        isBlocking = true
        blockMessage = nil
        protectionFocused = true
        let confirmed = await store.perform("block", targetID: targetID)
        guard activeAccountID == accountID, loadedAccountID == accountID, playerID == targetID else { return }
        isBlocking = false
        blockConfirmed = confirmed
        if !confirmed {
            blockMessage = "The block was not confirmed by the service. This player remains hidden here. Retry confirms the same target; it does not leave or rerate the match."
        }
        protectionFocused = true
    }

    private func reportPlayer() {
        guard isCurrentViewer, !isOwnPlayer else { return }
        store.suspendCapture()
        onOpen(.report(PhysiqueReportTarget(kind: "player", id: playerID, matchID: contextMatch?.id ?? reportMatchID)))
    }

    private func returnToMatch() {
        guard let match = contextMatch else { return }
        switch match.stage {
        case .ready, .countdown: onOpen(.ready)
        case .capture, .submitting: onOpen(.battle)
        case .judging: onOpen(.judging)
        case .cancelled, .noOpponent: onOpen(.lobby)
        case .completed, .forfeited, .noContest: onOpen(.result(match.id))
        case .idle, .searching: onOpen(.search)
        }
    }

    private func close() {
        clearBadgeSelection()
        dismiss()
    }
}
