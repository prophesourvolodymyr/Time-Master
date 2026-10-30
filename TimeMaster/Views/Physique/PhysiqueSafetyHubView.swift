import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiqueSafetyHubView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @State private var blockedPlayers: [PhysiqueBlockedPlayer] = []
    @State private var unresolvedLocalIDs: [String] = []
    @State private var loadedAccountID: String?
    @State private var hasLoadedBlocks = false
    @State private var blocksLoading = false
    @State private var blocksError: String?
    @State private var blocksUpdatedAt: Date?
    @State private var pendingUnblocks: Set<String> = []
    @State private var unconfirmedUnblocks: [String: String] = [:]
    @State private var retryableUnblockIDs: Set<String> = []
    @State private var unblockAcknowledgement: String?
    @State private var supportFeedback: String?
    @State private var retainedPublicPolicy: PhysiquePolicy?
    @State private var returnError: String?
    @State private var returningToMatch = false
    @State private var refreshID = UUID()
    @State private var privateGeneration = UUID()
    @AccessibilityFocusState private var accessibilityFocus: FocusTarget?

    private enum FocusTarget: Hashable {
        case introduction, blockedHeading, blockedPlayer(String)
    }

    private struct LoadContext: Hashable {
        let accountID: String?
        let active: Bool
        let refreshID: UUID
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var isActive: Bool {
        presentationActive && scenePhase == .active
    }

    private var loadContext: LoadContext {
        LoadContext(accountID: activeAccountID, active: isActive, refreshID: refreshID)
    }

    private var privateDataVisible: Bool {
        isActive && activeAccountID != nil && loadedAccountID == activeAccountID
    }

    private var currentMatch: PhysiqueMatch? {
        privateDataVisible ? store.match : nil
    }

    private var publicPolicy: PhysiquePolicy? {
        store.policy ?? store.snapshot?.policy ?? retainedPublicPolicy
    }

    private var supportURL: URL? {
        guard let value = publicPolicy?.supportURL,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              url.user == nil, url.password == nil else { return nil }
        if scheme == "https", let host = url.host, !host.isEmpty { return url }
        if scheme == "mailto", !url.path.isEmpty, url.query == nil, url.fragment == nil { return url }
        return nil
    }

    var body: some View {
        PhysiqueScreen(title: "Safety") {
            Label("Text-only help. No images required.", systemImage: "shield")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($accessibilityFocus, equals: .introduction)

            restrictionNotice
            destinations
            supportSection
            blockedSection

            Text("Not an emergency service. For immediate danger, contact local emergency help.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let match = currentMatch {
                matchContext(match)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: requestRefresh) {
                    Label("Refresh safety", systemImage: "arrow.clockwise")
                }
                .physiqueToolbarTarget()
                .disabled(blocksLoading || store.loading || store.busy)
                .help("Refresh published support and your blocked players")
            }
        }
        .task(id: loadContext) { await loadSafety(context: loadContext) }
        .onAppear {
            store.suspendCapture()
            accessibilityFocus = .introduction
        }
        .onReceive(store.$policy) { policy in
            if let policy { retainedPublicPolicy = policy }
        }
        .onChange(of: accountStore.accountID) { _ in clearPrivateState() }
        .onChange(of: accountStore.busy) { busy in
            if busy { clearPrivateState() }
        }
        .onChange(of: isActive) { active in
            if !active {
                store.suspendCapture()
                clearPrivateState()
            }
        }
        .onChange(of: store.locallyBlockedIDs) { _ in updateLocalProtection() }
        .onDisappear {
            store.suspendCapture()
            clearPrivateState()
            supportFeedback = nil
        }
    }

    @ViewBuilder
    private var restrictionNotice: some View {
        if privateDataVisible, let reason = store.account?.restrictedReason, !reason.isEmpty {
            PhysiqueCard {
                Label("Participation restricted", systemImage: "hand.raised")
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                Text(reason)
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text("Your own cases, privacy controls and published support remain available.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                PhysiqueAction(title: "View my decisions", systemImage: "tray") { open(.cases) }
            }
        }
        if privateDataVisible, store.isStale {
            PhysiqueStatusView(
                title: "Account status needs refreshing",
                detail: "The last confirmed match or restriction may have changed. Safety information remains available; returning to a match requires a fresh service check.",
                systemImage: "arrow.clockwise",
                retry: requestRefresh
            )
        }
        if let returnError {
            PhysiqueStatusView(title: "Return not confirmed", detail: returnError, systemImage: "pause.circle")
        }
    }

    private var destinations: some View {
        VStack(spacing: ProfileStyle.spacing) {
            if let match = currentMatch, !match.opponent.identity.id.isEmpty {
                PhysiqueSafetyDestinationRow(
                    title: "Report this player",
                    detail: "Current match · \(safeName(match.opponent.identity.displayName))",
                    symbol: "flag"
                ) {
                    open(.report(PhysiqueReportTarget(kind: "player", id: match.opponent.identity.id, matchID: match.id)))
                }
            } else {
                PhysiqueSafetyDestinationRow(
                    title: "Report a concern",
                    detail: activeAccountID == nil
                        ? "Sign in to choose a permitted match. Public support is below."
                        : "Choose a match in History. For a general concern, use published support below.",
                    symbol: "flag"
                ) {
                    open(activeAccountID == nil ? .account : .history)
                }
            }
            PhysiqueSafetyDestinationRow(
                title: "My cases",
                detail: activeAccountID == nil ? "Sign in for your private reports and decisions." : "Your reports, decisions and available appeals.",
                symbol: "tray"
            ) {
                open(activeAccountID == nil ? .account : .cases)
            }
            PhysiqueSafetyDestinationRow(
                title: "Privacy & sharing",
                detail: "Permissions, image removal and in-app account deletion.",
                symbol: "hand.raised"
            ) {
                open(.privacy)
            }
            if let match = currentMatch,
               match.stage == .completed || match.stage == .forfeited || match.stage == .noContest {
                PhysiqueSafetyDestinationRow(
                    title: "Request outcome review",
                    detail: "Challenge this match decision without making a content accusation.",
                    symbol: "checkmark.bubble"
                ) {
                    open(.review(PhysiqueReviewTarget(kind: "dispute", id: match.id, matchID: match.id)))
                }
            }
        }
    }

    private var supportSection: some View {
        PhysiqueSection(title: "Support") {
            PhysiqueCard {
                if let policy = publicPolicy {
                    Text(policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Responsible operator not published"
                         : policy.operatorName)
                        .font(TimeMasterFont.rowTitle())
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if let url = supportURL {
                        Text(url.absoluteString)
                            .font(TimeMasterFont.secondary())
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        PhysiqueAction(title: "Contact support", systemImage: "arrow.up.right.square") {
                            contactSupport(url)
                        }
                        Button { copyContact(url) } label: {
                            Label("Copy contact", systemImage: "doc.on.doc")
                                .frame(minHeight: ProfileStyle.touchTarget)
                        }
                        .buttonStyle(.bordered)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                        Text("Opens the published destination. No photo, case text or match reference is attached, and opening it is not a report receipt.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("A usable public support contact is not published in the available policy.", systemImage: "exclamationmark.circle")
                            .font(TimeMasterFont.secondary())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Staffing hours, time zone and response expectations are not supplied by the available policy. Immediate or continuous human response is not promised.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !policy.ready {
                        Label(policy.unavailableReason ?? "The service has not enabled public Physique participation.", systemImage: "pause.circle")
                            .font(TimeMasterFont.secondary())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Policy version: \(policy.version). Contact freshness could not be independently verified.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Published operator and contact information is unavailable. Refresh to request the public policy; sign-in is not required.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PhysiqueAction(title: "Refresh public information", systemImage: "arrow.clockwise", disabled: blocksLoading || store.loading) {
                        requestRefresh()
                    }
                }
                if let supportFeedback {
                    Text(supportFeedback)
                        .font(TimeMasterFont.secondary())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var blockedSection: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Blocked players")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($accessibilityFocus, equals: .blockedHeading)

            if !isActive {
                PhysiqueStatusView(title: "Private list hidden", detail: "Return to this window to check the current account's blocks.", systemImage: "lock")
            } else if !accountStore.restored || accountStore.busy {
                ProgressView("Resolving account access…")
            } else if activeAccountID == nil {
                PhysiqueStatusView(title: "Sign in to view blocked players", detail: "Public support remains available without signing in.", systemImage: "lock")
                PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { open(.account) }
            } else if privateDataVisible {
                if blocksLoading || (!hasLoadedBlocks && blocksError == nil) {
                    ProgressView(hasLoadedBlocks ? "Refreshing blocked players…" : "Loading blocked players…")
                }
                if let blocksError {
                    PhysiqueStatusView(title: "Blocked list not refreshed", detail: blocksError, retry: requestRefresh)
                }
                if let unblockAcknowledgement {
                    Label(unblockAcknowledgement, systemImage: "checkmark.circle")
                        .font(TimeMasterFont.secondary())
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let blocksUpdatedAt {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Last checked")
                        Text(blocksUpdatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    }
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .accessibilityElement(children: .combine)
                }
                if hasLoadedBlocks, blockedPlayers.isEmpty, unresolvedLocalIDs.isEmpty {
                    Text("No blocked players")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                LazyVStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    ForEach(blockedPlayers) { player in
                        PhysiqueSafetyBlockedRow(
                            name: safeName(player.displayName),
                            isCurrentOpponent: currentMatch?.opponent.identity.id == player.id,
                            pending: pendingUnblocks.contains(player.id),
                            unconfirmedDetail: unconfirmedUnblocks[player.id],
                            canRetry: retryableUnblockIDs.contains(player.id),
                            requestBusy: store.busy,
                            listRefreshing: blocksLoading || store.loading,
                            onUnblock: { Task { await unblock(player) } },
                            onCheck: requestRefresh
                        )
                        .accessibilityFocused($accessibilityFocus, equals: .blockedPlayer(player.id))
                    }
                    ForEach(unresolvedLocalIDs, id: \.self) { _ in
                        PhysiqueCard {
                            Label("Unavailable player", systemImage: "person.crop.circle")
                                .font(TimeMasterFont.rowTitle())
                            Text("Hidden here · Block not confirmed")
                                .font(TimeMasterFont.secondary())
                            Text("This device has protected the local view. Service-wide blocking has not been confirmed.")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(action: requestRefresh) {
                                Label("Check block status", systemImage: "arrow.clockwise")
                                    .frame(minHeight: ProfileStyle.touchTarget)
                            }
                            .buttonStyle(.bordered)
                            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                            .disabled(blocksLoading)
                        }
                    }
                }
                Text("Unblocking does not contact anyone, start a rematch, restore poses or restart the camera.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView("Loading account-scoped safety information…")
            }
        }
    }

    private func matchContext(_ match: PhysiqueMatch) -> some View {
        VStack(spacing: ProfileStyle.spacing) {
            PhysiqueTimerView(clock: clock(for: match))
            Button {
                Task { await returnToMatch(match.id) }
            } label: {
                Label(returningToMatch ? "Checking match…" : "Return to match", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(.bordered)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .disabled(returningToMatch || store.loading)
            Text("Camera stopped. Help does not pause match timing. Leaving the match is a separate action in the match view.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.bottom, ProfileStyle.spacing)
        .frame(maxWidth: ProfileStyle.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
    }

    private func clock(for match: PhysiqueMatch) -> PhysiqueClock {
        switch match.stage {
        case .ready, .countdown:
            return PhysiqueClock(mode: match.startAt == nil ? .unavailable : .countdown, label: match.stage.title, endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture, .submitting:
            return PhysiqueClock(mode: .remaining, label: "Capture time remaining", endpoint: match.deadline, serverOffset: store.serverOffset)
        case .judging:
            return PhysiqueClock(mode: .elapsed, label: "Judging elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        case .completed, .forfeited, .noContest, .cancelled, .noOpponent:
            return PhysiqueClock(mode: .ended, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        default:
            return PhysiqueClock(mode: .unavailable, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        }
    }

    private func open(_ route: PhysiqueRoute) {
        store.suspendCapture()
        onOpen(route)
    }

    private func safeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unavailable player" : trimmed
    }

    private func requestRefresh() {
        guard !blocksLoading, !store.loading else { return }
        refreshID = UUID()
    }

    private func loadSafety(context: LoadContext) async {
        store.suspendCapture()
        guard context.active else {
            clearPrivateState()
            return
        }
        if loadedAccountID != context.accountID {
            clearPrivateState()
            loadedAccountID = context.accountID
        }
        await store.loadPolicy()
        guard context == loadContext, !Task.isCancelled else { return }
        guard context.accountID != nil else { return }
        await store.refresh()
        guard context == loadContext, !Task.isCancelled else { return }
        await loadBlocks(context: context)
    }

    private func loadBlocks(context: LoadContext) async {
        guard let accountID = context.accountID, accountID == activeAccountID,
              context.active, !blocksLoading else { return }
        let generation = privateGeneration
        blocksLoading = true
        blocksError = nil
        defer {
            if generation == privateGeneration { blocksLoading = false }
        }
        do {
            let players = try await store.blocks()
            guard generation == privateGeneration, context == loadContext,
                  accountID == activeAccountID, !Task.isCancelled else { return }
            var seen: Set<String> = []
            blockedPlayers = players.filter { seen.insert($0.id).inserted }
            loadedAccountID = accountID
            hasLoadedBlocks = true
            blocksUpdatedAt = Date()
            let currentIDs = Set(blockedPlayers.map(\.id))
            if case .blockedPlayer(let focusedID)? = accessibilityFocus, !currentIDs.contains(focusedID) {
                accessibilityFocus = .blockedHeading
            }
            retryableUnblockIDs = Set(unconfirmedUnblocks.keys).intersection(currentIDs)
            let resolved = Set(unconfirmedUnblocks.keys).subtracting(currentIDs)
            if !resolved.isEmpty {
                for id in resolved { unconfirmedUnblocks.removeValue(forKey: id) }
                unblockAcknowledgement = "Player no longer appears in your confirmed blocked list. No media has been reopened."
                announce("Blocked list updated. Player no longer appears in your blocked list.")
            }
            updateLocalProtection()
        } catch is CancellationError {
        } catch {
            guard generation == privateGeneration, context == loadContext,
                  accountID == activeAccountID, !Task.isCancelled else { return }
            blocksError = "The current list could not be confirmed. Any displayed rows are the last confirmed list. \(error.localizedDescription)"
            updateLocalProtection()
            announce("Blocked players could not be refreshed.")
        }
    }

    private func unblock(_ player: PhysiqueBlockedPlayer) async {
        guard privateDataVisible, let accountID = activeAccountID,
              !pendingUnblocks.contains(player.id),
              unconfirmedUnblocks[player.id] == nil || retryableUnblockIDs.contains(player.id),
              !blocksLoading, !store.busy else { return }
        let generation = privateGeneration
        pendingUnblocks.insert(player.id)
        retryableUnblockIDs.remove(player.id)
        unblockAcknowledgement = nil
        store.suspendCapture()
        let confirmed = await store.perform("unblock", targetID: player.id)
        guard generation == privateGeneration, accountID == activeAccountID else { return }
        pendingUnblocks.remove(player.id)
        if confirmed {
            let previousFocus = accessibilityFocus
            blockedPlayers.removeAll { $0.id == player.id }
            unconfirmedUnblocks.removeValue(forKey: player.id)
            unblockAcknowledgement = "Player unblocked. Future pairing may be allowed. No contact, rematch or media restoration was started."
            updateLocalProtection()
            if previousFocus == .blockedPlayer(player.id) {
                accessibilityFocus = .blockedHeading
            }
            announce("Player unblocked. No media has been reopened.")
            await loadBlocks(context: loadContext)
        } else {
            unconfirmedUnblocks[player.id] = store.error ?? "The service did not confirm the update. Check status before taking another action."
            announce("Unblock not confirmed. Check status; this view remains protected.")
        }
    }

    private func updateLocalProtection() {
        guard privateDataVisible else {
            unresolvedLocalIDs = []
            return
        }
        let confirmedIDs = Set(blockedPlayers.map(\.id))
        unresolvedLocalIDs = store.locallyBlockedIDs.subtracting(confirmedIDs).sorted()
    }

    private func returnToMatch(_ originalMatchID: String) async {
        guard let accountID = activeAccountID, !returningToMatch, !store.loading else { return }
        let generation = privateGeneration
        returningToMatch = true
        returnError = nil
        store.suspendCapture()
        await store.refresh()
        guard generation == privateGeneration, accountID == activeAccountID else { return }
        returningToMatch = false
        guard !store.isStale, store.error == nil, store.snapshot != nil else {
            returnError = "The service could not confirm the current match. Camera capture remains stopped. Refresh to try again."
            return
        }
        guard let match = store.match, match.id == originalMatchID else {
            open(.history)
            return
        }
        switch match.stage {
        case .ready, .countdown: open(.ready)
        case .capture, .submitting: open(.battle)
        case .judging: open(.judging)
        case .completed, .forfeited, .noContest: open(.result(match.id))
        case .searching: open(.search)
        case .idle, .cancelled, .noOpponent: open(.lobby)
        }
    }

    private func contactSupport(_ url: URL) {
        store.suspendCapture()
        supportFeedback = nil
        openURL(url) { accepted in
            supportFeedback = accepted
                ? "Support destination opened. Tmax has not submitted a report or confirmed message delivery."
                : "The support destination could not be opened. Copy the published contact to use it in another app."
        }
    }

    private func copyContact(_ url: URL) {
        #if os(iOS)
        UIPasteboard.general.string = url.absoluteString
        supportFeedback = "Public contact copied. Nothing was sent."
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setString(url.absoluteString, forType: .string)
        supportFeedback = copied
            ? "Public contact copied. Nothing was sent."
            : "The contact could not be copied. The published address remains selectable above."
        #endif
    }

    private func clearPrivateState() {
        privateGeneration = UUID()
        blockedPlayers = []
        unresolvedLocalIDs = []
        loadedAccountID = nil
        hasLoadedBlocks = false
        blocksLoading = false
        blocksError = nil
        blocksUpdatedAt = nil
        pendingUnblocks = []
        unconfirmedUnblocks = [:]
        retryableUnblockIDs = []
        unblockAcknowledgement = nil
        returnError = nil
        returningToMatch = false
    }

    private func announce(_ message: String) {
        guard isActive else { return }
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
        #endif
    }
}

@MainActor
private struct PhysiqueSafetyDestinationRow: View {
    let title: String
    let detail: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(TimeMasterFont.rowTitle())
                    Text(detail)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ProfileStyle.secondary)
                    .accessibilityHidden(true)
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            .modifier(TimeMasterCardSurface(flat: true))
            .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct PhysiqueSafetyBlockedRow: View {
    let name: String
    let isCurrentOpponent: Bool
    let pending: Bool
    let unconfirmedDetail: String?
    let canRetry: Bool
    let requestBusy: Bool
    let listRefreshing: Bool
    let onUnblock: () -> Void
    let onCheck: () -> Void

    @State private var confirmsUnblock = false

    var body: some View {
        PhysiqueCard {
            Label(name, systemImage: "person.crop.circle")
                .font(TimeMasterFont.rowTitle())
                .fixedSize(horizontal: false, vertical: true)
            if pending {
                ProgressView("Unblocking · waiting for confirmation…")
            } else if let unconfirmedDetail {
                Label("Unblock not confirmed · Protected here", systemImage: "shield")
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
                Text(unconfirmedDetail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The request may have reached the service. Check the current blocked list; another unblock will not be sent automatically.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onCheck) {
                    Label("Check status", systemImage: "arrow.clockwise")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(.bordered)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .disabled(listRefreshing)
                .accessibilityLabel("Check unblock status for \(name)")
                if canRetry {
                    Text("The refreshed list still contains this block. You can explicitly retry the same unblock request.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    unblockButton(title: "Retry unblock")
                }
            } else {
                Text("Blocked · last confirmed by the service")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                unblockButton(title: "Unblock")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func unblockButton(title: String) -> some View {
        Button { confirmsUnblock = true } label: {
            Label(title, systemImage: "person.crop.circle.badge.checkmark")
                .frame(minHeight: ProfileStyle.touchTarget)
        }
        .buttonStyle(.bordered)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .disabled(listRefreshing)
        .accessibilityLabel("\(title) this player, \(name)")
        .alert("Unblock this player?", isPresented: $confirmsUnblock) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .destructive, action: onUnblock)
                .disabled(requestBusy)
                .keyboardShortcut(nil as KeyboardShortcut?)
        } message: {
            Text("\(name)\n\nFuture pairing may be allowed. This will not contact them, rematch, or reopen poses.\(isCurrentOpponent ? " The current match continues; leaving it is separate." : "")")
        }
    }
}
