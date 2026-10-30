import SwiftUI
import Combine
import TimeMasterCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiqueHistoryView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var cloud = CloudAccountStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.physiquePresentationActive) private var presentationActive
    @State private var owner: AccountScope?
    @State private var matches: [PhysiqueMatch] = []
    @State private var cursor: String?
    @State private var consumedCursors: Set<String> = []
    @State private var continuationBlocked = false
    @State private var hasLoaded = false
    @State private var needsSignIn = false
    @State private var pageRequest: PageRequest?
    @State private var refreshError: String?
    @State private var pageError: String?
    @State private var fetchedAt: Date?
    @State private var offline = false
    @State private var newMatchesAvailable = false
    @State private var latestAnchor = UUID()
    @State private var selectedID: String?
    @State private var showsDetails = true
    @State private var detail: PhysiqueMatch?
    @State private var detailError: String?
    @State private var detailAttempt = UUID()
    @State private var recordVersions: [String: UInt64] = [:]
    @FocusState private var pagingFocused: Bool
    @FocusState private var listFocused: Bool
    @AccessibilityFocusState private var pagingAccessibilityFocused: Bool
    @AccessibilityFocusState private var accessibleMatchID: String?

    private struct AccountScope: Hashable {
        let cloudID: String
        let physiqueID: String
    }

    private struct PageRequest: Equatable {
        let id = UUID()
        let owner: AccountScope
        let cursor: String?
        let replaces: Bool
        let movesFocus: Bool
    }

    private struct DetailRequest: Equatable {
        let owner: AccountScope
        let matchID: String
        let attempt: UUID
    }

    private struct Outcome {
        let title: String
        let provenance: String
        let symbol: String
    }

    private static let topID = "physique-history-top"
    private static let preciseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        return formatter
    }()

    private var accountScope: AccountScope? {
        guard let cloudID = cloud.accountID, let physiqueID = store.account?.identity.id else { return nil }
        return AccountScope(cloudID: cloudID, physiqueID: physiqueID)
    }

    private var detailRequest: DetailRequest? {
        guard presentationActive, showsDetails, let selectedID, let owner, owner == accountScope,
              matches.contains(where: { $0.id == selectedID }) else { return nil }
        return DetailRequest(owner: owner, matchID: selectedID, attempt: detailAttempt)
    }

    private var hidesOpponentContext: Bool { offline || store.isStale }

    var body: some View {
        Group {
            if cloud.accountID == nil || needsSignIn {
                PhysiqueScreen(title: "History", subtitle: "Only you") {
                    PhysiqueStatusView(title: "Sign in to view history", detail: "Your Physique matches are private to your Tmax account.", systemImage: "lock")
                    PhysiqueAction(title: "Sign in", systemImage: "person.crop.circle") { onOpen(.account) }
                }
            } else if accountScope == nil {
                PhysiqueScreen(title: "History", subtitle: "Only you") {
                    if store.loading {
                        ProgressView("Checking account")
                    } else {
                        PhysiqueStatusView(title: "History unavailable", detail: store.error ?? "Refresh your Physique account to access your private history.", retry: {
                            Task { await store.refresh() }
                        })
                    }
                }
            } else if owner == accountScope {
                history
            } else {
                PhysiqueScreen(title: "History", subtitle: "Only you") {
                    ProgressView("Checking account")
                }
            }
        }
        .navigationTitle("History")
        .tint(Theme.toolbarOrange)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { requestLatest() } label: {
                    Label("Show latest", systemImage: "arrow.clockwise")
                }
                .physiqueToolbarTarget()
                .disabled(needsSignIn || accountScope == nil || pageRequest != nil)
                .accessibilityHint("Replaces the current history pages with the latest matches and returns to the top after success.")
                .accessibilityIdentifier("physique-history-latest")
#if os(macOS)
                Button { showsDetails.toggle() } label: {
                    Label("Details", systemImage: "sidebar.trailing")
                }
                .physiqueToolbarTarget()
                .disabled(selectedID == nil)
                .accessibilityValue(showsDetails ? "Shown" : "Hidden")
#endif
            }
        }
        .onReceive(cloud.$session.map { $0?.userID }.removeDuplicates()) { cloudID in
            if let owner, owner.cloudID != cloudID { clearPrivateState() }
        }
        .onReceive(store.$snapshot) { snapshot in
            guard let snapshot else {
                if owner != nil { clearPrivateState() }
                return
            }
            if let owner, snapshot.account.identity.id != owner.physiqueID {
                clearPrivateState()
            } else {
                acceptCurrentMatch(snapshot)
            }
        }
        .task(id: cloud.accountID) {
            if cloud.accountID != nil, store.account == nil { await store.refresh() }
        }
        .task(id: accountScope) {
            guard let accountScope else {
                clearPrivateState()
                return
            }
            if owner != accountScope {
                clearPrivateState()
                owner = accountScope
            }
            if !hasLoaded, pageRequest == nil { requestLatest() }
        }
        .task(id: pageRequest) {
            if let pageRequest { await loadPage(pageRequest) }
        }
        .task(id: detailRequest) {
            if let detailRequest { await loadDetail(detailRequest) }
        }
        .onChange(of: selectedID) { _ in
            detail = nil
            detailError = nil
            detailAttempt = UUID()
        }
        .onChange(of: presentationActive) { active in
            if active {
                if !hasLoaded { requestLatest() }
            } else {
                pageRequest = nil
            }
        }
        .onDisappear { pageRequest = nil }
    }

    @ViewBuilder
    private var history: some View {
#if os(macOS)
        GeometryReader { geometry in
            let usesInspector = geometry.size.width >= 940 && !dynamicTypeSize.isAccessibilitySize
            ledger(inlineDetails: !usesInspector)
                .inspector(isPresented: Binding(
                    get: { usesInspector && showsDetails && selectedID != nil },
                    set: { if usesInspector { showsDetails = $0 } }
                )) {
                    ScrollView {
                        selectedSummary
                            .padding(ProfileStyle.inset)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .keyNavAccessoryHost()
                    .background(Theme.background)
                    .inspectorColumnWidth(min: 300, ideal: 350, max: 420)
                }
                .onExitCommand {
                    if showsDetails, selectedID != nil { showsDetails = false }
                }
        }
#else
        ledger(inlineDetails: true)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
#endif
    }

    private func ledger(inlineDetails: Bool) -> some View {
        ScrollViewReader { proxy in
            Group {
#if os(macOS)
                List(selection: $selectedID) {
                    ledgerContents(inlineDetails: inlineDetails)
                }
#else
                List {
                    ledgerContents(inlineDetails: inlineDetails)
                }
#endif
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .foregroundStyle(.white)
            .font(TimeMasterFont.body())
            .focused($listFocused)
            .onChange(of: latestAnchor) { _ in
                proxy.scrollTo(Self.topID, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private func ledgerContents(inlineDetails: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Only you", systemImage: "lock")
                .font(TimeMasterFont.caption())
            if let fetchedAt {
                Text("Snapshot fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(TimeMasterFont.caption())
            }
            if newMatchesAvailable {
                Text("New matches available")
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.toolbarOrange)
            }
            if refreshError != nil || offline || store.isStale {
                Text("Not refreshed")
                    .font(TimeMasterFont.rowTitle())
            }
        }
        .foregroundStyle(ProfileStyle.secondary)
        .id(Self.topID)
        .listRowBackground(Theme.background)
        .listRowSeparator(.hidden)

        if pageRequest?.replaces == true {
            ProgressView(hasLoaded ? "Loading latest history" : "Loading history")
                .frame(maxWidth: .infinity)
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)
        }

        if let refreshError {
            PhysiqueStatusView(
                title: matches.isEmpty ? (offline ? "History unavailable offline" : "History unavailable") : "Latest history not refreshed",
                detail: refreshError,
                retry: pageRequest == nil ? { requestLatest() } : nil
            )
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
        }

        if hasLoaded, matches.isEmpty, refreshError == nil {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                PhysiqueStatusView(title: "No physique matches yet", detail: "Your real started matches will appear here. Searching and pre-start cancellations do not create history.", systemImage: "clock.arrow.circlepath")
                PhysiqueAction(title: "Return to Physique", systemImage: "arrow.backward") { onOpen(.lobby) }
            }
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
        }

        ForEach(matches) { match in
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
#if os(macOS)
                rowLabel(match)
                    .keyNavTarget(id: "physique-history-\(match.id)", shape: .roundedRectangle(cornerRadius: 0), action: { selectedID = match.id })
#else
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                        selectedID = selectedID == match.id ? nil : match.id
                    }
                } label: {
                    rowLabel(match)
                }
                .buttonStyle(.plain)
                .accessibilityValue(selectedID == match.id ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows text-only match details.")
#endif
                if inlineDetails, showsDetails, selectedID == match.id {
                    selectedSummary
                        .padding(.vertical, ProfileStyle.spacing)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
            .tag(match.id)
            .id(match.id)
            .listRowBackground(Theme.background)
            .accessibilityFocused($accessibleMatchID, equals: match.id)
            .accessibilityIdentifier("physique-history-match-\(match.id)")
            .contextMenu {
                Button(match.stage.terminal ? "Open result" : "Open match") { onOpen(.result(match.id)) }
                Button("Report a concern") { openReport(match.id) }
            }
        }

        if hasLoaded, !matches.isEmpty {
            pageBoundary
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)
        }
    }

    private func rowLabel(_ match: PhysiqueMatch) -> some View {
        let outcome = outcome(for: match)
        return HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: outcome.symbol)
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityHidden(true)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(opponentName(match))
                    .font(TimeMasterFont.rowTitle())
                Text(outcome.title)
                    .font(TimeMasterFont.label())
                if !outcome.provenance.isEmpty {
                    Text(outcome.provenance)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                Text(startedDate(match.startAt))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("\(ratingLabel(match)) · Your Physique Elo")
                    .font(TimeMasterFont.secondary().monospacedDigit())
                if match.result?.corrected == true {
                    Label("Corrected", systemImage: "arrow.triangle.2.circlepath")
                        .font(TimeMasterFont.caption())
                }
                if let correction = match.result?.correction {
                    Text("Review adjustment: \(signed(correction.adjustment)) Elo")
                        .font(TimeMasterFont.caption().monospacedDigit())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
#if os(iOS)
            Image(systemName: selectedID == match.id ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(ProfileStyle.secondary)
                .accessibilityHidden(true)
#endif
        }
        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            HStack(alignment: .firstTextBaseline) {
                Text("Match details")
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
#if os(macOS)
                    showsDetails = false
#else
                    selectedID = nil
#endif
                } label: {
                    Label("Close details", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: ProfileStyle.touchTarget, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(.borderless)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
            }
            if let detail, detail.id == selectedID {
                matchSummary(detail)
            } else if let detailError {
                PhysiqueStatusView(title: "Match details unavailable", detail: detailError, retry: {
                    self.detailError = nil
                    detailAttempt = UUID()
                })
            } else {
                ProgressView("Loading match")
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func matchSummary(_ match: PhysiqueMatch) -> some View {
        let outcome = outcome(for: match)
        VStack(alignment: .leading, spacing: 6) {
            Text(outcome.title).font(TimeMasterFont.heading())
            Text(opponentName(match)).font(TimeMasterFont.rowTitle())
            if !outcome.provenance.isEmpty {
                Text(outcome.provenance).foregroundStyle(ProfileStyle.secondary)
            }
        }
        summaryFact("Started", preciseTime(match.startAt))
        if match.stage.terminal {
            summaryFact("Finalized", preciseTime(match.finalizedAt))
        }

        if let result = match.result {
            if result.corrected {
                Text("Corrected result").font(TimeMasterFont.sectionTitle())
                if result.correction == nil {
                    Text("Separate review audit details were not supplied.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
            if result.outcome == "noContest" || match.stage == .noContest {
                Text(result.corrected ? "Unrated" : "No rating change")
                    .font(TimeMasterFont.sectionTitle())
                Text("No appearance scores or rated-game contribution. Allowance restoration is not confirmed by this record.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if let receipt = result.rating {
                Text(result.corrected ? "Original match rating receipt" : "Match rating receipt")
                    .font(TimeMasterFont.sectionTitle())
                summaryFact("Before", receipt.before.map { "\($0.formatted()) Elo" } ?? "Not recorded")
                summaryFact("Change", "\(signed(receipt.change)) Elo")
                summaryFact("After", "\(receipt.after.formatted()) Elo")
                Text(result.corrected ? "This is the original match settlement, separate from any later review adjustment or current account rating." : "These are the returned match receipt values, not your current account rating.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            } else if result.outcome != "noContest", match.stage != .noContest {
                summaryFact("Your Physique Elo", match.stage.terminal ? "Receipt not available" : "Not settled")
            }
            if let correction = result.correction {
                Text("Review adjustment").font(TimeMasterFont.sectionTitle())
                summaryFact("Corrected", preciseTime(correction.createdAt))
                summaryFact("Original outcome", recordedOutcome(correction.originalOutcome)?.title ?? "Outcome unavailable")
                summaryFact("Original rating change", "\(signed(correction.originalChange)) Elo")
                summaryFact("Corrected outcome", recordedOutcome(correction.correctedOutcome)?.title ?? "Outcome unavailable")
                summaryFact("Review adjustment", "\(signed(correction.adjustment)) Elo")
                summaryFact("Rating after review", "\(correction.after.formatted()) Elo")
                if !hidesOpponentContext, !correction.reason.isEmpty {
                    summaryFact("Review reason", correction.reason)
                }
                Text("The later adjustment is recorded at the review date. It does not rewrite the original match receipt and is not today’s current rating.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }

            if result.isJudged, let you = result.you, let opponent = result.opponent {
                Text("AI-judged totals").font(TimeMasterFont.sectionTitle())
                summaryFact("You", score(you.total))
                summaryFact("Opponent", score(opponent.total))
                summaryFact("Total gap", score(abs(you.total - opponent.total)))
                summaryFact("Judge version", result.judgeVersion ?? "Not supplied")
                Text("Subjective judgements of the submitted pose set, not body measurements. Full category detail is in the result.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            } else if result.outcome == "forfeitWin" || result.outcome == "forfeitLoss" {
                Text("A forfeit is a match outcome, not an appearance judgement. No physique scores apply.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            } else if ["win", "loss", "draw"].contains(result.outcome) {
                Text("Judged totals were not supplied. Missing scores are not zero.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } else {
            summaryFact("Your Physique Elo", ratingLabel(match))
        }

        if !hidesOpponentContext, !store.locallyBlockedIDs.contains(match.opponent.identity.id),
           let rating = match.opponent.identity.rating {
            summaryFact("Opponent’s match-time Physique Elo", "\(rating.formatted()) Elo")
            Text("Rating recorded for this pairing, not a current profile rating or the opponent’s private rating receipt.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
        }
        if !hidesOpponentContext, let reason = match.reason, !reason.isEmpty {
            summaryFact("Recorded reason", reason)
        }

        PhysiqueAction(title: match.stage.terminal ? "Open result" : "Open match", systemImage: "arrow.up.right") {
            onOpen(.result(match.id))
        }
        PhysiqueAction(title: "Safety and reporting", systemImage: "flag") { openReport(match.id) }
        summaryFact("Match reference", match.id)
            .textSelection(.enabled)
    }

    private func summaryFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Text(value).font(TimeMasterFont.secondary()).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var pageBoundary: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if pageRequest?.replaces == false {
                ProgressView("Loading older matches")
            }
            if let pageError {
                Text(pageError)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if continuationBlocked {
                Text("Show latest to continue").font(TimeMasterFont.rowTitle())
                Button("Show latest") { requestLatest() }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                    .disabled(pageRequest != nil)
            } else if cursor != nil {
                Button { requestMore() } label: {
                    Label(pageError == nil ? "Load more" : "Retry", systemImage: "chevron.down")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .disabled(pageRequest != nil)
                .focused($pagingFocused)
                .accessibilityFocused($pagingAccessibilityFocused)
                .accessibilityIdentifier("physique-history-more")
            } else {
                Text("You’re up to date with this history")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        .buttonStyle(.borderless)
    }

    private func requestLatest() {
        guard presentationActive, !needsSignIn, pageRequest == nil, let owner, owner == accountScope else { return }
        pageRequest = PageRequest(owner: owner, cursor: nil, replaces: true, movesFocus: false)
    }

    private func requestMore() {
        guard presentationActive, !needsSignIn, pageRequest == nil, !continuationBlocked, let cursor, let owner, owner == accountScope else { return }
        guard !consumedCursors.contains(cursor) else {
            continuationBlocked = true
            pageError = "The service returned an already loaded continuation. Existing matches remain available."
            return
        }
        pageRequest = PageRequest(owner: owner, cursor: cursor, replaces: false, movesFocus: pagingFocused || pagingAccessibilityFocused)
    }

    private func loadPage(_ request: PageRequest) async {
        defer { if pageRequest == request { pageRequest = nil } }
        let versionsAtStart = recordVersions
        do {
            let page = try await store.history(cursor: request.cursor)
            guard !Task.isCancelled, pageRequest == request, owner == request.owner, accountScope == request.owner else { return }
            guard page.items.allSatisfy({ $0.you.identity.id == request.owner.physiqueID }) else {
                clearPrivateState()
                owner = request.owner
                refreshError = "History access changed. Refresh your Physique account before trying again."
                return
            }
            var knownIDs = request.replaces ? Set<String>() : Set(matches.map(\.id))
            let unique = page.items.filter { knownIDs.insert($0.id).inserted }
            if request.replaces {
                let previous = Dictionary(uniqueKeysWithValues: matches.lazy.map { ($0.id, $0) })
                matches = unique.map { incoming in
                    guard let existing = previous[incoming.id] else { return incoming }
                    if recordVersions[incoming.id, default: 0] != versionsAtStart[incoming.id, default: 0]
                        || !canReplace(existing, with: incoming) {
                        return existing
                    }
                    return incoming
                }
                consumedCursors.removeAll()
                continuationBlocked = false
                recordVersions.removeAll()
                hasLoaded = true
                refreshError = nil
                pageError = nil
                fetchedAt = Date()
                newMatchesAvailable = false
                if !unique.contains(where: { $0.id == selectedID }) { selectedID = nil }
                detail = nil
                detailError = nil
                detailAttempt = UUID()
                latestAnchor = UUID()
            } else {
                matches.append(contentsOf: unique)
                if let cursor = request.cursor { consumedCursors.insert(cursor) }
                pageError = nil
                if request.movesFocus, let first = unique.first {
#if os(macOS)
                    selectedID = first.id
                    listFocused = true
#endif
                    accessibleMatchID = first.id
                    announce("\(unique.count) older matches loaded.")
                }
            }
            cursor = page.cursor
            if let cursor = page.cursor, consumedCursors.contains(cursor) {
                continuationBlocked = true
                pageError = "The history continuation did not advance. Existing matches remain available."
            }
            offline = false
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, pageRequest == request, owner == request.owner, accountScope == request.owner else { return }
            if requiresSignIn(error) {
                clearPrivateState()
                owner = request.owner
                needsSignIn = true
                return
            }
            if request.replaces {
                refreshError = historyMessage(error)
            } else {
                pageError = historyMessage(error)
                continuationBlocked = isExpiredSnapshot(error)
            }
            offline = isOffline(error)
            if request.movesFocus {
                announce(continuationBlocked ? "Show latest to continue." : "Older matches could not be loaded. Retry is available.")
            }
        }
    }

    private func loadDetail(_ request: DetailRequest) async {
        detail = nil
        detailError = nil
        let version = recordVersions[request.matchID, default: 0]
        do {
            let match = try await store.getMatch(request.matchID)
            guard !Task.isCancelled, detailRequest == request, owner == request.owner, accountScope == request.owner else { return }
            guard match.id == request.matchID, match.you.identity.id == request.owner.physiqueID else {
                detailError = "This match is not available to the current account."
                return
            }
            guard let index = matches.firstIndex(where: { $0.id == request.matchID }) else { return }
            if version == recordVersions[request.matchID, default: 0], canReplace(matches[index], with: match) {
                matches[index] = match
                recordVersions[match.id, default: 0] &+= 1
                detail = match
            } else {
                detail = matches[index]
            }
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, detailRequest == request, owner == request.owner, accountScope == request.owner else { return }
            if requiresSignIn(error) {
                clearPrivateState()
                owner = request.owner
                needsSignIn = true
                return
            }
            detailError = historyMessage(error)
        }
    }

    private func acceptCurrentMatch(_ snapshot: PhysiqueSnapshot) {
        guard let owner, owner.cloudID == cloud.accountID, owner.physiqueID == snapshot.account.identity.id,
              hasLoaded, let current = snapshot.match, current.you.identity.id == owner.physiqueID else { return }
        guard let index = matches.firstIndex(where: { $0.id == current.id }) else {
            if current.startAt != nil, [.capture, .submitting, .judging, .completed, .forfeited, .noContest].contains(current.stage) {
                newMatchesAvailable = true
            }
            return
        }
        guard canReplace(matches[index], with: current), hasVisibleChanges(matches[index], current) else { return }
        matches[index] = current
        recordVersions[current.id, default: 0] &+= 1
        if detail?.id == current.id { detail = current }
    }

    private func canReplace(_ existing: PhysiqueMatch, with incoming: PhysiqueMatch) -> Bool {
        if existing.stage.terminal, !incoming.stage.terminal { return false }
        if existing.result != nil, incoming.result == nil { return false }
        if existing.result?.corrected == true, incoming.result?.corrected != true { return false }
        if let previous = existing.result?.correction {
            guard let next = incoming.result?.correction else { return false }
            if next.createdAt < previous.createdAt { return false }
        }
        if let previous = existing.finalizedAt, let next = incoming.finalizedAt, next < previous { return false }
        return true
    }

    private func hasVisibleChanges(_ lhs: PhysiqueMatch, _ rhs: PhysiqueMatch) -> Bool {
        lhs.stage != rhs.stage || lhs.startAt != rhs.startAt || lhs.finalizedAt != rhs.finalizedAt || lhs.reason != rhs.reason ||
        lhs.opponent.identity != rhs.opponent.identity || lhs.result?.outcome != rhs.result?.outcome ||
        lhs.result?.corrected != rhs.result?.corrected || lhs.result?.judgeVersion != rhs.result?.judgeVersion ||
        lhs.result?.you?.total != rhs.result?.you?.total || lhs.result?.opponent?.total != rhs.result?.opponent?.total ||
        lhs.result?.rating?.before != rhs.result?.rating?.before || lhs.result?.rating?.change != rhs.result?.rating?.change ||
        lhs.result?.rating?.after != rhs.result?.rating?.after || correctionChanged(lhs.result?.correction, rhs.result?.correction)
    }

    private func correctionChanged(_ lhs: PhysiqueCorrection?, _ rhs: PhysiqueCorrection?) -> Bool {
        lhs?.id != rhs?.id || lhs?.createdAt != rhs?.createdAt || lhs?.reason != rhs?.reason ||
        lhs?.originalOutcome != rhs?.originalOutcome || lhs?.correctedOutcome != rhs?.correctedOutcome ||
        lhs?.originalChange != rhs?.originalChange || lhs?.adjustment != rhs?.adjustment || lhs?.after != rhs?.after
    }

    private func clearPrivateState() {
        owner = nil
        matches.removeAll()
        cursor = nil
        consumedCursors.removeAll()
        continuationBlocked = false
        hasLoaded = false
        needsSignIn = false
        pageRequest = nil
        refreshError = nil
        pageError = nil
        fetchedAt = nil
        offline = false
        newMatchesAvailable = false
        selectedID = nil
        detail = nil
        detailError = nil
        detailAttempt = UUID()
        recordVersions.removeAll()
        accessibleMatchID = nil
    }

    private func outcome(for match: PhysiqueMatch) -> Outcome {
        if let outcome = recordedOutcome(match.result?.outcome) { return outcome }
        if match.stage == .noContest { return Outcome(title: "No contest", provenance: "Unrated", symbol: "circle.slash") }
        if match.stage == .forfeited { return Outcome(title: "Forfeit", provenance: "Outcome details unavailable", symbol: "flag") }
        if match.stage.terminal { return Outcome(title: "Result unavailable", provenance: match.stage.title, symbol: "questionmark.circle") }
        return Outcome(title: "Pending", provenance: match.stage.title, symbol: "clock")
    }

    private func recordedOutcome(_ outcome: String?) -> Outcome? {
        switch outcome {
        case "win": return Outcome(title: "Won", provenance: "AI judged", symbol: "checkmark.circle")
        case "loss": return Outcome(title: "Lost", provenance: "AI judged", symbol: "minus.circle")
        case "draw": return Outcome(title: "Draw", provenance: "AI judged", symbol: "equal.circle")
        case "forfeitWin": return Outcome(title: "Won by forfeit", provenance: "No appearance judgement", symbol: "flag.checkered")
        case "forfeitLoss": return Outcome(title: "Forfeited", provenance: "No appearance judgement", symbol: "flag")
        case "noContest": return Outcome(title: "No contest", provenance: "Unrated", symbol: "circle.slash")
        default: return nil
        }
    }

    private func ratingLabel(_ match: PhysiqueMatch) -> String {
        if match.result?.outcome == "noContest" || match.stage == .noContest {
            return match.result?.corrected == true ? "Unrated" : "No rating change"
        }
        if let receipt = match.result?.rating {
            return match.result?.corrected == true ? "Original receipt: \(signed(receipt.change)) Elo" : "\(signed(receipt.change)) Elo"
        }
        return match.stage.terminal ? "Not available" : "Not settled"
    }

    private func opponentName(_ match: PhysiqueMatch) -> String {
        if store.locallyBlockedIDs.contains(match.opponent.identity.id) { return "Blocked player" }
        if hidesOpponentContext { return "Opponent" }
        return match.opponent.identity.displayName.isEmpty ? "Unavailable player" : match.opponent.identity.displayName
    }


    private func openReport(_ matchID: String) {
        onOpen(.report(PhysiqueReportTarget(kind: "match", id: matchID, matchID: matchID)))
    }

    private func startedDate(_ timestamp: Double?) -> String {
        guard let timestamp, timestamp.isFinite else { return "Date unavailable" }
        return Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
    }

    private func preciseTime(_ timestamp: Double?) -> String {
        guard let timestamp, timestamp.isFinite else { return "Date unavailable" }
        return Self.preciseDate.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func signed(_ value: Int) -> String {
        value == 0 ? "0" : value.formatted(.number.sign(strategy: .always()))
    }

    private func score(_ value: Double) -> String {
        value.isFinite ? value.formatted(.number.precision(.fractionLength(1))) : "Not supplied"
    }

    private func historyMessage(_ error: Error) -> String {
        if let serviceError = error as? RankedServiceError {
            switch serviceError {
            case .unconfigured: return "The Physique service has not been configured for this app."
            case .insecureEndpoint: return "Physique history requires a secure service address."
            case .signedOut: return "Sign in to your Tmax account again to read private history."
            case .message(let message): return message
            }
        }
        return error.localizedDescription
    }

    private func requiresSignIn(_ error: Error) -> Bool {
        if let error = error as? RankedServiceError, case .signedOut = error { return true }
        if let error = error as? CloudAuthError {
            switch error {
            case .signedOut, .sessionExpired: return true
            default: return false
            }
        }
        return false
    }

    private func isExpiredSnapshot(_ error: Error) -> Bool {
        guard let error = error as? RankedServiceError, case .message(let message) = error else { return false }
        return message == "This saved Physique page expired or changed. Show latest to continue"
    }

    private func isOffline(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff].contains(error.code)
    }

    private func announce(_ message: String) {
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
