import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
struct PhysiqueStandingsView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var accessibilityFocus: FocusTarget?
    @State private var dataOwner: String?
    @State private var generation = UUID()
    @State private var isVisible = false
    @State private var isRefreshing = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var boardAuthorized = false
    @State private var standings: [PhysiqueStanding] = []
    @State private var nextCursor: String?
    @State private var consumedCursors: Set<String> = []
    @State private var continuationNeedsRefresh = false
    @State private var latestSectionEmpty = false
    @State private var firstFailure: ReadFailure?
    @State private var pagingFailure: String?
    @State private var ownAccount: PhysiqueAccount?
    @State private var ownStanding: PhysiqueStanding?
    @State private var ownServerTime: Double?
    @State private var ownIsStale = false
    @State private var ownFailure: String?
    @State private var confirmingOwnPosition = false
    @State private var standingsChanged = false
    @State private var selectedPlayerID: String?
    @State private var showsAbout = false

    private enum FocusTarget: Hashable {
        case heading, player(String), paging, end, listing, about
    }

    private struct ReadFailure {
        let title: String
        let detail: String
        let concealsBoard: Bool
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var mayShowAccount: Bool {
        isVisible && scenePhase == .active && activeAccountID != nil && dataOwner == activeAccountID
    }

    private var mayShowBoard: Bool { mayShowAccount && boardAuthorized }

    var body: some View {
        ledger
            .font(TimeMasterFont.body())
            .foregroundStyle(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Physique standings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .physiqueToolbarTarget()
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Label(isRefreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .physiqueToolbarTarget()
                    .disabled(activeAccountID == nil || isRefreshing || isLoadingMore || scenePhase != .active)
                    Button {
                        showsAbout = true
                    } label: {
                        Label("About standings", systemImage: "info.circle")
                    }
                    .physiqueToolbarTarget()
                    .accessibilityFocused($accessibilityFocus, equals: .about)
                }
            }
            .alert("About Physique standings", isPresented: $showsAbout) {
                Button("Physique rules") { onOpen(.rules) }
                Button("Public listing") { onOpen(.privacy) }
                Button("Close", role: .cancel) { }
            } message: {
                Text("This is the separate Physique ladder, ordered by current Physique Elo. Equal Elo shares the service’s position; order within a tie is not an advantage. Five effective rated results complete placement. Only eligible, explicitly listed accounts appear. Privacy and safety settings can omit players without closing position gaps. Listing never publishes poses. Snapshot time and shared-tie details are shown only when supplied by the service.")
            }
            .task(id: activeAccountID) {
                isVisible = true
                if activeAccountID == nil {
                    clearAccount()
                } else {
                    await reload()
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { shield() }
            .onChange(of: accountStore.accountID) { _ in clearAccount() }
            .onChange(of: accountStore.busy) { busy in
                if busy { clearAccount() }
            }
            .onChange(of: store.snapshot?.serverTime) { _ in receiveSnapshot() }
            .onChange(of: store.locallyBlockedIDs) { _ in removeUnavailablePlayers() }
            .onChange(of: store.isStale) { stale in
                if stale, mayShowAccount {
                    concealBoard()
                    ownIsStale = ownAccount != nil
                    firstFailure = ReadFailure(title: "Standings unavailable", detail: store.error ?? "Current access could not be confirmed. Refresh before browsing players.", concealsBoard: true)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    isVisible = true
                    Task { await reload() }
                } else {
                    shield()
                }
            }
    }

    private var ledger: some View {
        Group {
            #if os(macOS)
            List(selection: $selectedPlayerID) {
                ledgerContent
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: String.self) { identifiers in
                if let id = identifiers.first, canOpenPlayer(id) {
                    Button("Player details") { openPlayer(id) }
                    if id != ownAccount?.identity.id {
                        Button("Report player") { openReport(id) }
                        Button("Safety and block…") { openPlayer(id) }
                    }
                }
            } primaryAction: { identifiers in
                if let id = identifiers.first { openPlayer(id) }
            }
            #else
            List {
                ledgerContent
            }
            .listStyle(.insetGrouped)
            #endif
        }
        .refreshable { await reload() }
    }

    @ViewBuilder
    private var ledgerContent: some View {
        if !isVisible || scenePhase != .active {
            PhysiqueStatusView(title: "Standings are private", detail: "Return to confirm current account access and player visibility.", systemImage: "lock")
                .listRowBackground(Theme.background)
        } else if !accountStore.restored || accountStore.busy {
            ProgressView("Restoring account…")
                .listRowBackground(Theme.background)
        } else if activeAccountID == nil {
            PhysiqueStatusView(title: "Sign in to view standings", detail: "Public Physique standings are available through your Tmax account. Browsing uses no camera and does not start a duel.", systemImage: "person.crop.circle")
                .listRowBackground(Theme.background)
            PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { onOpen(.account) }
                .listRowBackground(Theme.background)
        } else if mayShowAccount {
            SwiftUI.Section {
                ownSummary
            } header: {
                Text("Your standing").font(TimeMasterFont.sectionTitle())
            }
            SwiftUI.Section {
                boardContent
            } header: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Public Physique standings").font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($accessibilityFocus, equals: .heading)
                    Text("Position · Player · Physique Elo")
                        .font(TimeMasterFont.caption())
                    Text("Snapshot time unavailable")
                        .font(TimeMasterFont.caption())
                }
                .textCase(nil)
            } footer: {
                Text("Positions come from the Physique service, not the visible row count. Equal Elo shares a position; omitted players may leave gaps. No country filter or exercise ranking is applied.")
                    .font(TimeMasterFont.caption())
                    .fixedSize(horizontal: false, vertical: true)
            }
            SwiftUI.Section {
                Button { onOpen(.privacy) } label: {
                    Label("Public listing and privacy", systemImage: "hand.raised")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                Button { onOpen(.safety) } label: {
                    Label("Safety and blocked players", systemImage: "shield")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                Button { onOpen(.rules) } label: {
                    Label("Physique rules", systemImage: "list.bullet.rectangle")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            }
            .listRowBackground(Theme.surface)
        } else {
            ProgressView("Loading standings…")
                .listRowBackground(Theme.background)
        }
    }

    @ViewBuilder
    private var ownSummary: some View {
        if let account = ownAccount {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Label(ownState(account), systemImage: account.restrictedReason == nil ? "person.crop.circle" : "lock")
                    .font(TimeMasterFont.heading())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let reason = account.restrictedReason {
                    Text(reason).font(TimeMasterFont.secondary())
                    Button("Open safety and review options") { onOpen(.safety) }
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                if account.record.games == 0 {
                    Text("No earned Physique Elo yet. The private pairing seed is not an earned rating.")
                        .font(TimeMasterFont.secondary())
                } else if account.record.games < 5 {
                    Text("Placement needs five effective rated results. Public listing does not reserve a position before placement.")
                        .font(TimeMasterFont.secondary())
                }
                PhysiqueIdentityRail(identity: projectedIdentity(account.identity, record: account.record), ownerLabel: "You") { _ in
                    onOpen(.badges)
                }
                if account.record.games > 0 && account.record.rating == nil {
                    Text("Physique Elo unavailable").font(TimeMasterFont.secondary())
                }
                if account.identity.countryCode?.isEmpty != false {
                    Text("Country not shared").font(TimeMasterFont.caption())
                }
                Text(listingDescription(account))
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
                if confirmingOwnPosition && account.listed && account.record.games >= 5 {
                    ProgressView("Confirming your position…")
                }
                if let ownFailure {
                    Text(ownFailure).font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let ownServerTime {
                    Text("\(ownIsStale ? "Last confirmed account" : "Account as of") \(Date(timeIntervalSince1970: ownServerTime).formatted(date: .abbreviated, time: .shortened))")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                } else {
                    Text("Account confirmation time unavailable").font(TimeMasterFont.caption())
                }
                Button { onOpen(.privacy) } label: {
                    Label("Public listing", systemImage: "hand.raised")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .accessibilityFocused($accessibilityFocus, equals: .listing)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.toolbarOrange).frame(width: 3).offset(x: -12)
                    .accessibilityHidden(true)
            }
            .listRowBackground(Theme.surface)
        } else if isRefreshing || store.loading {
            ProgressView("Loading your standing…")
                .listRowBackground(Theme.surface)
        } else {
            PhysiqueStatusView(title: "Your standing unavailable", detail: ownFailure ?? "Your account’s placement and listing choice have not been confirmed. No position or rating is inferred from the loaded players.")
                .listRowBackground(Theme.background)
        }
    }

    @ViewBuilder
    private var boardContent: some View {
        if let firstFailure {
            PhysiqueStatusView(title: firstFailure.title, detail: firstFailure.detail, systemImage: firstFailure.title == "Standings unavailable offline" ? "wifi.slash" : "exclamationmark.circle", retry: {
                Task { await reload() }
            })
            .listRowBackground(Theme.background)
        } else if !mayShowBoard {
            ProgressView(isRefreshing ? "Loading standings…" : "Confirming player visibility…")
                .listRowBackground(Theme.background)
        } else {
            if standingsChanged {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Standings changed", systemImage: "arrow.clockwise")
                    Text("Refresh for a new board and confirmed own position. Existing positions have not been recalculated locally.")
                        .font(TimeMasterFont.secondary())
                    Button("Refresh standings") { Task { await reload() } }
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                        .disabled(isRefreshing || isLoadingMore)
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .listRowBackground(Theme.surface)
            }
            if isRefreshing {
                ProgressView("Refreshing standings…")
                    .listRowBackground(Theme.background)
            }
            ForEach(standings) { standing in
                PhysiqueStandingsRow(standing: standing, isOwn: standing.identity.id == ownAccount?.identity.id, onDetails: {
                    openPlayer(standing.identity.id)
                }, onReport: {
                    openReport(standing.identity.id)
                })
                .keyNavTarget(id: "physique-standing-\(standing.identity.id)", role: .primary, shape: .roundedRectangle(cornerRadius: 0), action: { openPlayer(standing.identity.id) })
                .tag(standing.identity.id)
                .accessibilityFocused($accessibilityFocus, equals: .player(standing.identity.id))
                .listRowBackground(Theme.surface)
            }
            if standings.isEmpty {
                PhysiqueStatusView(title: nextCursor == nil ? "No players to show" : "No visible players in this section", detail: "No public Physique players are available to you in this response. Privacy and safety settings can omit players. An empty visible section does not establish that the entire ladder is empty.", systemImage: "person.2")
                    .listRowBackground(Theme.background)
            } else if latestSectionEmpty, nextCursor != nil {
                Text("No new visible players in this section. More sections are available.")
                    .font(TimeMasterFont.secondary())
                    .listRowBackground(Theme.background)
            }
            pagingControls
        }
    }

    @ViewBuilder
    private var pagingControls: some View {
        if continuationNeedsRefresh {
            PhysiqueStatusView(title: "Refresh to continue", detail: pagingFailure ?? "The continuation could not be confirmed. A fresh board is needed before loading another section.")
                .listRowBackground(Theme.background)
            Button("Refresh standings") { Task { await reload() } }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .frame(minHeight: ProfileStyle.touchTarget)
                .disabled(isRefreshing)
                .listRowBackground(Theme.surface)
        } else if nextCursor != nil {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                if let pagingFailure {
                    Text("More standings unavailable").font(TimeMasterFont.rowTitle())
                    Text(pagingFailure).font(TimeMasterFont.secondary())
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isLoadingMore {
                    ProgressView("Loading more…")
                }
                Button(pagingFailure == nil ? "Load more" : "Retry loading more") {
                    Task { await loadMore() }
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .frame(minHeight: ProfileStyle.touchTarget)
                .disabled(isLoadingMore || isRefreshing)
                .accessibilityFocused($accessibilityFocus, equals: .paging)
            }
            .listRowBackground(Theme.surface)
        } else if hasLoaded {
            Text("End of standings")
                .font(TimeMasterFont.secondary())
                .accessibilityFocused($accessibilityFocus, equals: .end)
                .listRowBackground(Theme.background)
        }
    }

    private func ownState(_ account: PhysiqueAccount) -> String {
        if account.restrictedReason != nil { return "Standings access restricted" }
        if account.record.games == 0 { return "Unplaced" }
        if account.record.games < 5 { return "Provisional · \(account.record.games.formatted()) of 5 results" }
        if ownIsStale { return "Current standing unavailable" }
        if !account.listed { return "Not publicly listed" }
        if let position = ownStanding?.position { return "Physique position \(position.formatted())" }
        return confirmingOwnPosition ? "Confirming your position…" : "Position unavailable"
    }

    private func listingDescription(_ account: PhysiqueAccount) -> String {
        if ownIsStale { return "This is your last confirmed account record. Current public listing and position must be checked online." }
        if !account.listed { return "Public listing is off. Your earned Physique Elo is retained; no private public position is inferred." }
        if account.record.games < 5 { return "Public listing is on, after placement and while eligible. You are not published or assigned a reserved position yet." }
        if account.restrictedReason != nil { return "Your listing choice does not override the current access restriction." }
        return "Public listing is on. It shares permitted identity and competitive information, never poses."
    }

    private func projectedIdentity(_ identity: PhysiqueIdentity, record: PhysiqueRecord) -> PhysiqueIdentity {
        PhysiqueIdentity(id: identity.id, displayName: identity.displayName, countryCode: identity.countryCode, rating: record.games > 0 ? record.rating : nil, games: record.games, tier: record.games >= 5 ? identity.tier : nil, badges: identity.badges, streak: identity.streak)
    }

    private func reload() async {
        guard let owner = activeAccountID, scenePhase == .active, isVisible else { return }
        guard !isRefreshing && !isLoadingMore else { return }
        if dataOwner != owner {
            clearAccount()
            dataOwner = owner
        }
        let token = UUID()
        generation = token
        isRefreshing = true
        firstFailure = nil
        pagingFailure = nil
        confirmingOwnPosition = true
        ownFailure = nil
        defer {
            if isCurrent(owner, token) {
                isRefreshing = false
                confirmingOwnPosition = false
            }
        }
        await store.refresh()
        guard isCurrent(owner, token) else { return }
        if let snapshot = store.snapshot, !store.isStale {
            ownAccount = snapshot.account
            ownServerTime = snapshot.serverTime
            ownIsStale = false
        } else {
            ownIsStale = ownAccount != nil
            ownFailure = store.error ?? "Your current account record could not be confirmed."
        }
        ownStanding = nil
        do {
            let page = try await store.standings()
            try Task.checkCancellation()
            guard isCurrent(owner, token) else { return }
            standings = authorizedRows(page.items, existing: [])
            nextCursor = page.cursor
            consumedCursors.removeAll()
            continuationNeedsRefresh = false
            latestSectionEmpty = standings.isEmpty
            hasLoaded = true
            boardAuthorized = true
            standingsChanged = false
            repairSelection()
            announce("Standings updated. Showing the first page.")
            if let account = ownAccount, !ownIsStale, account.listed, account.record.games >= 5, account.restrictedReason == nil {
                do {
                    let standing = try await store.player(account.identity.id)
                    try Task.checkCancellation()
                    guard isCurrent(owner, token) else { return }
                    if let current = ownAccount, standing.identity.id == current.identity.id, sameRecord(standing.record, current.record) {
                        ownStanding = standing
                        if standing.position == nil { ownFailure = "The service has not supplied a current public position. Your position is not inferred from these pages." }
                    } else {
                        ownFailure = "Your competitive record changed during loading. Refresh to confirm a coherent position."
                        standingsChanged = true
                    }
                } catch is CancellationError {
                    return
                } catch {
                    guard isCurrent(owner, token) else { return }
                    ownFailure = error.localizedDescription
                }
            }
        } catch is CancellationError {
        } catch {
            guard isCurrent(owner, token) else { return }
            concealBoard()
            firstFailure = readFailure(error)
            ownIsStale = ownAccount != nil
        }
    }

    private func loadMore() async {
        guard let owner = activeAccountID, mayShowBoard, let cursor = nextCursor, !isLoadingMore, !isRefreshing else { return }
        guard !consumedCursors.contains(cursor) else {
            continuationNeedsRefresh = true
            pagingFailure = "The service repeated an already loaded continuation. Refresh rather than combine uncertain sections."
            return
        }
        let token = generation
        isLoadingMore = true
        pagingFailure = nil
        let hadPagingFocus = accessibilityFocus == .paging
        defer { if isCurrent(owner, token) { isLoadingMore = false } }
        do {
            let page = try await store.standings(cursor: cursor)
            try Task.checkCancellation()
            guard isCurrent(owner, token) else { return }
            let additions = authorizedRows(page.items, existing: Set(standings.map { $0.identity.id }))
            standings.append(contentsOf: additions)
            consumedCursors.insert(cursor)
            latestSectionEmpty = additions.isEmpty
            if let continuation = page.cursor, consumedCursors.contains(continuation) {
                continuationNeedsRefresh = true
                pagingFailure = "The service could not confirm a new continuation. Refresh for a new coherent board."
                nextCursor = nil
            } else {
                nextCursor = page.cursor
            }
            if hadPagingFocus { accessibilityFocus = nextCursor == nil ? .end : .paging }
            announce(additions.isEmpty ? "No additional visible players in this section." : "More players loaded.")
        } catch is CancellationError {
        } catch {
            guard isCurrent(owner, token) else { return }
            if let serviceError = error as? RankedServiceError,
               case .message(let detail) = serviceError,
               detail == "This saved Physique page expired or changed. Show latest to continue" {
                continuationNeedsRefresh = true
                pagingFailure = detail
                announce("Standings changed. Refresh to continue.")
                return
            }
            let failure = readFailure(error)
            if failure.concealsBoard {
                concealBoard()
                firstFailure = failure
                ownIsStale = ownAccount != nil
            } else {
                pagingFailure = failure.detail
            }
        }
    }

    private func authorizedRows(_ rows: [PhysiqueStanding], existing: Set<String>) -> [PhysiqueStanding] {
        var seen = existing
        return rows.filter { standing in
            guard !store.locallyBlockedIDs.contains(standing.identity.id), seen.insert(standing.identity.id).inserted else { return false }
            if standing.identity.id == ownAccount?.identity.id {
                return ownAccount?.listed == true && ownAccount?.restrictedReason == nil && (ownAccount?.record.games ?? 0) >= 5
            }
            return true
        }
    }

    private func receiveSnapshot() {
        guard mayShowAccount, let snapshot = store.snapshot else { return }
        let previous = ownAccount
        ownAccount = snapshot.account
        ownServerTime = snapshot.serverTime
        ownIsStale = store.isStale
        if let previous, !sameRecord(previous.record, snapshot.account.record) || previous.listed != snapshot.account.listed || previous.identity != snapshot.account.identity || previous.restrictedReason != snapshot.account.restrictedReason {
            ownStanding = nil
            standings.removeAll { $0.identity.id == snapshot.account.identity.id }
            repairSelection()
        }
        if hasLoaded && !isRefreshing { standingsChanged = true }
    }

    private func removeUnavailablePlayers() {
        guard dataOwner == activeAccountID else { return }
        let focusedID: String?
        if case .player(let id)? = accessibilityFocus {
            focusedID = id
        } else {
            focusedID = nil
        }
        let affectedID = focusedID ?? selectedPlayerID
        let wasRemoved = affectedID.map { store.locallyBlockedIDs.contains($0) } ?? false
        let previousIndex = affectedID.flatMap { id in standings.firstIndex { $0.identity.id == id } }
        standings.removeAll { store.locallyBlockedIDs.contains($0.identity.id) }
        if wasRemoved {
            if let previousIndex, !standings.isEmpty {
                selectedPlayerID = standings[min(previousIndex, standings.count - 1)].identity.id
                accessibilityFocus = selectedPlayerID.map(FocusTarget.player) ?? .heading
            } else {
                selectedPlayerID = nil
                accessibilityFocus = .heading
            }
            announce("Player no longer available.")
        }
    }

    private func repairSelection() {
        if let selectedPlayerID, !standings.contains(where: { $0.identity.id == selectedPlayerID }) {
            self.selectedPlayerID = nil
            accessibilityFocus = .heading
        }
    }

    private func canOpenPlayer(_ id: String) -> Bool {
        mayShowBoard && !store.locallyBlockedIDs.contains(id) && standings.contains { $0.identity.id == id }
    }

    private func openPlayer(_ id: String) {
        guard canOpenPlayer(id) else { return }
        selectedPlayerID = id
        onOpen(.player(id))
    }

    private func openReport(_ id: String) {
        guard canOpenPlayer(id), id != ownAccount?.identity.id else { return }
        selectedPlayerID = id
        onOpen(.report(PhysiqueReportTarget(kind: "player", id: id, matchID: nil)))
    }

    private func sameRecord(_ lhs: PhysiqueRecord, _ rhs: PhysiqueRecord) -> Bool {
        lhs.rating == rhs.rating && lhs.best == rhs.best && lhs.games == rhs.games && lhs.wins == rhs.wins && lhs.losses == rhs.losses && lhs.draws == rhs.draws
    }

    private func isCurrent(_ owner: String, _ token: UUID) -> Bool {
        !Task.isCancelled && isVisible && scenePhase == .active && dataOwner == owner && activeAccountID == owner && generation == token
    }

    private func concealBoard() {
        standings.removeAll()
        nextCursor = nil
        consumedCursors.removeAll()
        boardAuthorized = false
        hasLoaded = false
        continuationNeedsRefresh = false
        latestSectionEmpty = false
        selectedPlayerID = nil
        ownStanding = nil
    }

    private func shield() {
        isVisible = false
        generation = UUID()
        isRefreshing = false
        isLoadingMore = false
        confirmingOwnPosition = false
        boardAuthorized = false
        showsAbout = false
    }

    private func clearAccount() {
        generation = UUID()
        dataOwner = nil
        concealBoard()
        ownAccount = nil
        ownServerTime = nil
        ownIsStale = false
        ownFailure = nil
        firstFailure = nil
        pagingFailure = nil
        standingsChanged = false
        isRefreshing = false
        isLoadingMore = false
        confirmingOwnPosition = false
        showsAbout = false
        accessibilityFocus = nil
    }

    private func readFailure(_ error: Error) -> ReadFailure {
        if let error = error as? URLError {
            if error.code == .notConnectedToInternet {
                return ReadFailure(title: "Standings unavailable offline", detail: error.localizedDescription + " Public player identities are concealed until current access is confirmed.", concealsBoard: true)
            }
            return ReadFailure(title: "Standings connection unavailable", detail: error.localizedDescription, concealsBoard: true)
        }
        if let error = error as? CloudAuthError {
            switch error {
            case .signedOut, .sessionExpired, .superseded:
                return ReadFailure(title: "Standings access unavailable", detail: error.localizedDescription, concealsBoard: true)
            case .service(let status, _) where status == 401 || status == 403:
                return ReadFailure(title: "Standings access denied", detail: error.localizedDescription, concealsBoard: true)
            default: break
            }
        }
        if let error = error as? RankedServiceError, case .signedOut = error {
            return ReadFailure(title: "Standings access unavailable", detail: error.localizedDescription, concealsBoard: true)
        }
        if error is DecodingError {
            return ReadFailure(title: "Standings response unavailable", detail: "The service response could not be read. Retry the requested section.", concealsBoard: false)
        }
        return ReadFailure(title: "Standings unavailable", detail: error.localizedDescription, concealsBoard: true)
    }

    private func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #else
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
        #endif
    }
}

@MainActor
private struct PhysiqueStandingsRow: View {
    let standing: PhysiqueStanding
    let isOwn: Bool
    let onDetails: () -> Void
    let onReport: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if dynamicTypeSize.isAccessibilitySize {
                position
                identity
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: ProfileStyle.inset) {
                        position.frame(minWidth: 76, alignment: .leading)
                        identity
                    }
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        position
                        identity
                    }
                }
            }
            Text("\(standing.record.wins.formatted()) wins · \(standing.record.losses.formatted()) losses · \(standing.record.draws.formatted()) draws")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ProfileStyle.inset) { actions }
                VStack(alignment: .leading, spacing: 6) { actions }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var position: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Position").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Text(standing.position.map { $0.formatted() } ?? "Unavailable")
                .font(TimeMasterFont.heading().monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Physique position")
        .accessibilityValue(standing.position.map { $0.formatted() } ?? "Unavailable")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhysiqueIdentityRail(identity: standing.identity, ownerLabel: isOwn ? "You" : "Player") { _ in onDetails() }
            if standing.identity.rating == nil {
                Text("Physique Elo unavailable").font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            if standing.identity.countryCode?.isEmpty != false {
                Text("Country not shared").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            if standing.identity.streak == 0 {
                Text("Current win streak: 0").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: onDetails) {
            Label("Player details", systemImage: "chevron.right")
                .frame(minHeight: ProfileStyle.touchTarget)
        }
        .buttonStyle(.borderless)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Player details for \(standing.identity.displayName)")
        if !isOwn {
            Menu {
                Button("Report player", action: onReport)
                Button("Safety and block…", action: onDetails)
            } label: {
                Label("Player actions", systemImage: "ellipsis.circle")
                    .frame(minHeight: ProfileStyle.touchTarget)
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .accessibilityLabel("Player actions for \(standing.identity.displayName)")
        }
    }
}
