import SwiftUI

struct PhysiqueScoreBreakdownView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let matchID: String

    @ObservedObject private var account = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loaded: LoadedDetail?
    @State private var problem: DetailProblem?
    @State private var isLoading = false
    @State private var refreshID = UUID()
    @State private var activeRequestID: UUID?
    @State private var expandedCategory: String?
    @State private var evidenceExpanded = false
    @State private var versionExpanded = false
    @State private var readerIdentity: ReaderIdentity?
    @State private var readingAnchor: String?
    @State private var restoresReadingAnchor = false
    @State private var didFocusHeading = false
    @AccessibilityFocusState private var headingFocused: Bool
    @AccessibilityFocusState private var hiddenExplanationFocused: Bool

    var body: some View {
        ScrollViewReader { reader in
            readerContent
                .onChange(of: loaded?.retrievedAt) { _ in
                    guard restoresReadingAnchor, loaded != nil else { return }
                    restoresReadingAnchor = false
                    if let readingAnchor { reader.scrollTo(readingAnchor, anchor: .top) }
                }
        }
    }

    private var readerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
                Text("Score breakdown")
                    .font(TimeMasterFont.display())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)

                if scenePhase != .active || !presentationActive {
                    PhysiqueStatusView(
                        title: "Score details protected",
                        detail: "Return to this window to retrieve the currently authorized match.",
                        systemImage: "lock.shield"
                    )
                } else if account.accountID == nil {
                    PhysiqueStatusView(
                        title: "Sign in to read score details",
                        detail: "Private results are available only to an authorized participant. No previous account's details are shown.",
                        systemImage: "person.crop.circle"
                    )
                    PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") {
                        onOpen(.account)
                    }
                } else if let loaded, loaded.ownerID == account.accountID, loaded.match.id == matchID {
                    detailContent(loaded)
                } else if let problem, !isLoading {
                    problemContent(problem)
                } else {
                    loadingContent("Loading score details")
                }
            }
            .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle("Score breakdown")
        .privacySensitive()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", role: .cancel) { dismiss() }
                    .accessibilityLabel("Close score breakdown")
                    .keyboardShortcut(.cancelAction)
            }
        }
        .task(id: requestKey) {
            await retrieve(requestKey)
        }
        .onAppear {
            if !didFocusHeading {
                didFocusHeading = true
                headingFocused = true
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { clearPrivateDetail() }
        }
        .onChange(of: presentationActive) { active in
            if !active { clearPrivateDetail() }
        }
        .onReceive(store.$snapshot) { snapshot in
            guard let loaded, loaded.ownerID == account.accountID,
                  let match = snapshot?.match, match.id == matchID else { return }
            activeRequestID = nil
            isLoading = false
            self.loaded = LoadedDetail(match: match, ownerID: loaded.ownerID, retrievedAt: Date(), presentation: Self.presentation(for: match))
        }
        .onDisappear {
            clearPrivateDetail()
        }
    }

    private var requestKey: RequestKey {
        RequestKey(ownerID: account.accountID, matchID: matchID, active: scenePhase == .active && presentationActive, refreshID: refreshID)
    }

    @ViewBuilder
    private func detailContent(_ detail: LoadedDetail) -> some View {
        if isLoading {
            loadingContent("Refreshing score details")
            Text("Showing the complete details retrieved \(detail.retrievedAt.formatted(date: .abbreviated, time: .shortened)) until this request finishes.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if detail.match.result?.corrected == true {
            Label("Corrected result", systemImage: "checkmark.circle")
                .font(TimeMasterFont.label())
                .accessibilityAddTraits(.isHeader)
        }

        switch detail.presentation {
        case .scored(let scorecard):
            scoredContent(detail.match, scorecard: scorecard)
        case .pending:
            PhysiqueStatusView(
                title: "Scores not available yet",
                detail: "Current stage: \(detail.match.stage.title). Only the service can confirm the final outcome.",
                systemImage: "clock"
            )
        case .forfeit:
            unscoredContent(detail.match, title: forfeitTitle(detail.match.result), detail: "No physique scores — this match ended by forfeit. Missing poses are not scored as zero, and no comparison of physique was made.")
            ratingReceiptContent(for: detail.match)
        case .noContest:
            if detail.match.result?.corrected == true {
                unscoredContent(detail.match, title: "Corrected — No contest", detail: "No valid physique scores. The original result was superseded; the service-recorded review adjustment is shown separately from the original rating receipt.")
                ratingReceiptContent(for: detail.match)
            } else {
                unscoredContent(detail.match, title: "No contest", detail: "No physique scores and no Physique Elo change. A no-contest is not a draw, a physique loss, or a zero-point judgement.")
            }
        case .ended:
            unscoredContent(detail.match, title: detail.match.stage.title, detail: "No finalized physique judgement is available for this match. No category scores are substituted.")
        case .incomplete(let reason):
            PhysiqueStatusView(title: "Complete score details unavailable", detail: reason, systemImage: "doc.badge.exclamationmark")
        }

        if let result = detail.match.result, result.corrected, detail.presentation.hasFinalResult {
            correctionContent(for: result)
        }

        if let finalizedAt = detail.match.finalizedAt, finalizedAt.isFinite, finalizedAt > 0 {
            Text("Finalized \(Date(timeIntervalSince1970: finalizedAt).formatted(date: .abbreviated, time: .shortened))")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }

        quietAction("Refresh score details", systemImage: "arrow.clockwise", disabled: isLoading, action: requestRefresh)

        if detail.match.stage.terminal {
            reviewActions(for: detail.match, canReportExplanation: detail.presentation.hasScorecard)
        }
    }

    private func scoredContent(_ match: PhysiqueMatch, scorecard: Scorecard) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
            PhysiqueCard {
                Text(outcomeTitle(scorecard.outcome))
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                scorePair(you: scorecard.you.total, opponent: scorecard.opponent.total, unit: "pts / 100")
                    .textSelection(.enabled)
                Divider()
                PhysiqueScoreValue(value: Double(scorecard.gapTenths) / 10, label: "Gap", unit: "pts", animate: false)
                    .textSelection(.enabled)
                Text("Draw below 3.0 pts; win or loss at 3.0 pts or more.")
                    .fixedSize(horizontal: false, vertical: true)
                Text(scorecard.outcome == "draw"
                     ? "Unequal totals can still be a rated draw. A draw can change Physique Elo."
                     : "The higher accepted total wins outside the draw band. A larger margin is not a larger Elo award.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("AI judgement of these poses, not a health or muscle-mass measurement.")
                .fixedSize(horizontal: false, vertical: true)

            PhysiqueSection(title: "Categories") {
                PhysiqueCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(PhysiqueCategory.allCases) { category in
                            if category != .muscularity {
                                Divider().padding(.vertical, ProfileStyle.inset)
                            }
                            DisclosureGroup(isExpanded: categoryExpansion(category)) {
                                categoryMeaning(category, scorecard: scorecard)
                                    .padding(.top, ProfileStyle.spacing)
                            } label: {
                                PhysiqueCategoryScoreRow(
                                    category: category,
                                    you: scorecard.you.value(for: category),
                                    opponent: scorecard.opponent.value(for: category),
                                    animate: false
                                )
                            }
                            .id(category.rawValue)
                        }
                    }
                }
            }

            ratingReceiptContent(for: match)

            explanationContent(for: match)
            commonEvidenceContent
            versionContent(scorecard.judgeVersion)
        }
    }

    private func ratingReceiptContent(for match: PhysiqueMatch) -> some View {
        PhysiqueSection(title: match.result?.corrected == true ? "Original rating receipt" : "Your rating receipt") {
            PhysiqueRatingReceiptView(receipt: match.result?.rating, isFirstRating: match.result?.rating?.games == 1, animate: false)
            Text(match.result?.corrected == true
                 ? "This is the original finalization receipt, not a second award, today's rating or the review adjustment. Read the separate correction receipt for the settled review effect."
                 : "Physique Elo is separate from pose scores. Only your service-recorded receipt is shown; this view does not calculate or award rating.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func correctionContent(for result: PhysiqueResult) -> some View {
        PhysiqueSection(title: "Review correction") {
            PhysiqueCard {
                if let correction = result.correction {
                    PhysiqueMetric(label: "Original outcome", value: outcomeTitle(correction.originalOutcome))
                    PhysiqueMetric(label: "Original Physique Elo change", value: correction.originalChange.formatted(.number.sign(strategy: .always())))
                    Divider()
                    PhysiqueMetric(label: "Effective outcome after review", value: outcomeTitle(correction.correctedOutcome))
                    PhysiqueMetric(label: "Settled review adjustment · Physique Elo", value: correction.adjustment.formatted(.number.sign(strategy: .always())))
                    PhysiqueMetric(label: "Physique Elo after this review", value: correction.after.formatted())
                    Text("The after-review rating is the recorded settlement at that review, not your current rating today. No adjustment is recomputed here.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if correction.createdAt.isFinite, correction.createdAt > 0 {
                        Text("Reviewed \(Date(timeIntervalSince1970: correction.createdAt).formatted(date: .abbreviated, time: .shortened))")
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Correction date unavailable.")
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    Text(nonempty(correction.reason) ?? "Correction reason not supplied.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Review reference: \(correction.id)")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("The service marked this result corrected but did not supply the correction receipt. No original outcome, review adjustment or after-review rating is inferred.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .textSelection(.enabled)
        }
    }

    private func scorePair(you: Double, opponent: Double, unit: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: ProfileStyle.inset * 2) {
                PhysiqueScoreValue(value: you, label: "You", unit: unit, animate: false)
                    .fixedSize(horizontal: true, vertical: false)
                PhysiqueScoreValue(value: opponent, label: "Opponent", unit: unit, animate: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                PhysiqueScoreValue(value: you, label: "You", unit: unit, animate: false)
                PhysiqueScoreValue(value: opponent, label: "Opponent", unit: unit, animate: false)
            }
        }
    }

    private func categoryMeaning(_ category: PhysiqueCategory, scorecard: Scorecard) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text(meaning(of: category))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text("Weighted contribution")
                .font(TimeMasterFont.rowTitle())
                .accessibilityAddTraits(.isHeader)
            Text("Rubric weight \(category.weight)%")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            scorePair(
                you: Double(scorecard.you.value(for: category) * category.weight) / 100,
                opponent: Double(scorecard.opponent.value(for: category) * category.weight) / 100,
                unit: "pts toward total"
            )
            .textSelection(.enabled)
            Text("Each accepted category score is multiplied by its rubric weight. These contributions explain the total; they are not extra scores or separately rounded awards.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explanationContent(for match: PhysiqueMatch) -> some View {
        PhysiqueSection(title: "Accepted explanation") {
            PhysiqueCard {
                if store.isExplanationHidden(match.id) {
                    Text("Explanation hidden. It stays hidden if you cancel a report; hiding alone does not submit a report or change the result.")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($hiddenExplanationFocused)
                } else if let explanation = nonempty(match.result?.explanation) {
                    Text(explanation)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    quietAction("Hide explanation", systemImage: "eye.slash") {
                        store.hideExplanation(match.id)
                        hiddenExplanationFocused = true
                    }
                } else {
                    Text("Explanation unavailable. The confirmed scores remain separate from any removed or withheld text.")
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var commonEvidenceContent: some View {
        PhysiqueSection(title: "Common evidence") {
            PhysiqueCard {
                Text("Common regions only.").font(TimeMasterFont.label())
                DisclosureGroup(isExpanded: disclosureExpansion($evidenceExpanded, anchor: "common-evidence")) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("At judging, each participant's accepted set contained front double-biceps, side physique and rear double-biceps poses. Acceptance then does not mean those images remain available now.")
                        Text("The common evidence is shoulder, upper-arm, upper-back and leg contours. Definition requires interpretable common upper-arm and calf surface evidence. Clothing can show an outer contour without revealing definition underneath.")
                        Text("Front-chest and abdominal appearance and definition are excluded for both participants, even when visible. Breast, nipple, groin, genital and buttock anatomy are never scoring regions. Facial appearance, skin color, country or region, handles, public badges, Elo, subscription and capture-device prestige are not scoring inputs.")
                        Text("Permitted coverage is not a penalty; extra skin is not a bonus. Required hidden evidence cannot be guessed, replaced with another region or assigned a zero. Missing required evidence prevents a complete scored judgement. Ordinary image expiry after a valid judgement does not invalidate its accepted scores.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.top, ProfileStyle.spacing)
                } label: {
                    Text("What evidence was judged")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .id("common-evidence")
    }

    private func versionContent(_ judgeVersion: String) -> some View {
        PhysiqueSection(title: "Judging version") {
            PhysiqueCard {
                Text(judgeVersion)
                    .font(TimeMasterFont.label())
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityLabel("Recorded judging version, \(judgeVersion)")
                DisclosureGroup(isExpanded: disclosureExpansion($versionExpanded, anchor: "judging-version")) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("Both participants were judged together under the service's fixed match policy. This historical judging version is not replaced by the current app or service default.")
                        ForEach(PhysiqueCategory.allCases) { category in
                            Text("\(category.title): rubric weight \(category.weight)%.")
                        }
                        Text("Categories use whole points out of 100. Accepted totals and the absolute gap use one decimal place. The draw band is below 3.0 points; a gap of exactly 3.0 points is not a draw.")
                        Text("The accepted explanation is a neutral summary of permitted evidence, not private model reasoning, a diagnosis or a guarantee of accuracy or fairness.")
                        Text("Requested provider model: not supplied in this match record. Provider release not supplied. A version label or model alias is not proof of an immutable provider release.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.top, ProfileStyle.spacing)
                } label: {
                    Text("Recorded judging context")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .id("judging-version")
    }

    private func unscoredContent(_ match: PhysiqueMatch, title: String, detail: String) -> some View {
        PhysiqueCard {
            Text(title).font(TimeMasterFont.heading()).accessibilityAddTraits(.isHeader)
            Text(detail).fixedSize(horizontal: false, vertical: true)
            if let reason = nonempty(match.reason) {
                Text(reason)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private func reviewActions(for match: PhysiqueMatch, canReportExplanation: Bool) -> some View {
        PhysiqueSection(title: "Review and safety") {
            quietAction("Request scoring review", systemImage: "text.magnifyingglass") {
                onOpen(.review(PhysiqueReviewTarget(kind: "dispute", id: match.id, matchID: match.id)))
            }
            if canReportExplanation {
                quietAction("Report unsafe explanation", systemImage: "flag") {
                    store.hideExplanation(match.id)
                    onOpen(.report(PhysiqueReportTarget(kind: "explanation", id: match.id, matchID: match.id)))
                }
            }
            quietAction("View private cases", systemImage: "tray") {
                onOpen(.cases)
            }
            Text("Ordinary pose images expire 24 hours after finalization. Expired images cannot be restored. Opening a review or report does not preserve images, rerun judging or reverse the result.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func loadingContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            ProgressView(title)
            Text("Retrieving this match only. No pose images are downloaded.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func problemContent(_ problem: DetailProblem) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            PhysiqueStatusView(title: problem.title, detail: problem.detail, systemImage: problem.symbol)
            quietAction("Retry score details", systemImage: "arrow.clockwise", disabled: isLoading, action: requestRefresh)
            quietAction("Open account", systemImage: "person.crop.circle") { onOpen(.account) }
            quietAction("Safety and support", systemImage: "shield") { onOpen(.safety) }
        }
    }

    private func quietAction(_ title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: actionHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .disabled(disabled)
    }

    private var actionHeight: CGFloat {
#if os(iOS)
        ProfileStyle.touchTarget
#else
        0
#endif
    }

    private var disclosureAnimation: Animation? {
        let process = ProcessInfo.processInfo
        guard !reduceMotion, !process.isLowPowerModeEnabled, process.thermalState != .serious, process.thermalState != .critical else { return nil }
        return .easeInOut(duration: 0.2)
    }

    private func categoryExpansion(_ category: PhysiqueCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategory == category.rawValue },
            set: { expanded in
                withAnimation(disclosureAnimation) {
                    expandedCategory = expanded ? category.rawValue : nil
                    if expanded { readingAnchor = category.rawValue }
                }
            }
        )
    }

    private func disclosureExpansion(_ value: Binding<Bool>, anchor: String) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue },
            set: { expanded in
                withAnimation(disclosureAnimation) {
                    value.wrappedValue = expanded
                    if expanded { readingAnchor = anchor }
                }
            }
        )
    }

    private func meaning(of category: PhysiqueCategory) -> String {
        switch category {
        case .muscularity:
            return "Apparent development in the permitted shoulder, upper-arm, upper-back, thigh and calf contours across the accepted poses. This is not measured muscle size, physical strength or hidden anatomy."
        case .definition:
            return "Supported visible muscle separation in the common upper-arm and calf surface evidence. Fabric edges, shadows, tanning, sweat and extra skin exposure are not muscle separation."
        case .symmetry:
            return "Apparent left-right and upper-lower balance in the required front and rear contours. This is not a preferred gendered silhouette, skeletal ideal, breast-symmetry assessment or diagnosis."
        case .presentation:
            return "Safe, recognizable alignment and consistent presentation of the three prescribed still poses above the evidence floor. This is not endurance, dangerous strain, seductiveness or professional production quality."
        }
    }

    private func outcomeTitle(_ outcome: String) -> String {
        switch outcome {
        case "win": return "Won"
        case "loss": return "Lost"
        case "draw": return "Draw"
        case "forfeitWin": return "Won by forfeit"
        case "forfeitLoss": return "Forfeited"
        case "noContest": return "No contest"
        default: return "Outcome unavailable"
        }
    }

    private func forfeitTitle(_ result: PhysiqueResult?) -> String {
        switch result?.outcome {
        case "forfeitWin": return "Won by forfeit"
        case "forfeitLoss": return "Forfeited"
        default: return "Match ended by forfeit"
        }
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private func requestRefresh() {
        guard !isLoading else { return }
        isLoading = true
        refreshID = UUID()
    }

    private func clearPrivateDetail() {
        if loaded != nil { restoresReadingAnchor = readingAnchor != nil }
        activeRequestID = nil
        loaded = nil
        problem = nil
        isLoading = false
    }

    @MainActor
    private func retrieve(_ key: RequestKey) async {
        guard key.active, let ownerID = key.ownerID else {
            clearPrivateDetail()
            return
        }
        let identity = ReaderIdentity(ownerID: ownerID, matchID: key.matchID)
        if readerIdentity != identity {
            readerIdentity = identity
            loaded = nil
            expandedCategory = nil
            evidenceExpanded = false
            versionExpanded = false
            readingAnchor = nil
            restoresReadingAnchor = false
        }
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        problem = nil
        defer {
            if activeRequestID == requestID { isLoading = false }
        }
        do {
            let match = try await store.getMatch(key.matchID)
            guard !Task.isCancelled, activeRequestID == requestID, account.accountID == ownerID, scenePhase == .active, presentationActive, matchID == key.matchID else { return }
            guard match.id == key.matchID else {
                loaded = nil
                problem = .invalidResponse
                return
            }
            loaded = LoadedDetail(match: match, ownerID: ownerID, retrievedAt: Date(), presentation: Self.presentation(for: match))
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, activeRequestID == requestID, account.accountID == ownerID, scenePhase == .active, presentationActive else { return }
            loaded = nil
            if let connectionError = error as? URLError {
                problem = connectionError.code == .notConnectedToInternet ? .offline : .connection
            } else if error is DecodingError {
                problem = .invalidResponse
            } else if let serviceError = error as? RankedServiceError {
                switch serviceError {
                case .unconfigured, .insecureEndpoint: problem = .serviceUnavailable
                case .signedOut: problem = .accountUnavailable
                case .message: problem = .unavailable
                }
            } else {
                problem = .unavailable
            }
        }
    }

    private static func presentation(for match: PhysiqueMatch) -> Presentation {
        guard match.stage.terminal else { return .pending }
        if let result = match.result, let correction = result.correction {
            guard result.corrected, correction.correctedOutcome == result.outcome,
                  result.rating.map({ $0.change == correction.originalChange }) != false else {
                return .incomplete("The original rating receipt and effective review correction could not be confirmed as one coherent record. No mixed original and corrected values are shown.")
            }
        }
        switch match.stage {
        case .completed:
            guard let result = match.result, let you = result.you, let opponent = result.opponent,
                  result.outcome == "win" || result.outcome == "loss" || result.outcome == "draw" else {
                return .incomplete("The service did not supply both complete accepted score sets and a scored outcome. Missing scores are not zero, a draw or a no-contest.")
            }
            guard let version = result.judgeVersion, !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .incomplete("The required historical judging version was not supplied. Today's policy cannot replace this match's recorded context.")
            }
            guard let finalizedAt = match.finalizedAt, finalizedAt.isFinite, finalizedAt > 0,
                  match.you.acceptedCount == PhysiquePose.allCases.count,
                  match.opponent.acceptedCount == PhysiquePose.allCases.count else {
                return .incomplete("Finalization and the complete three-pose sets for both participants could not be confirmed. Required evidence is never guessed or assigned a zero.")
            }
            guard let youTenths = acceptedTenths(you), let opponentTenths = acceptedTenths(opponent) else {
                return .incomplete("The accepted category points and weighted totals could not be confirmed as a complete, consistent scorecard. No values have been repaired or substituted.")
            }
            let difference = youTenths - opponentTenths
            let gap = abs(difference)
            let consistent: Bool
            switch result.outcome {
            case "win": consistent = difference >= 30
            case "loss": consistent = difference <= -30
            case "draw": consistent = gap < 30
            default: consistent = false
            }
            guard consistent else {
                return .incomplete("The received outcome does not agree with its accepted totals and exact draw boundary. Only the service can confirm or correct this result; no replacement outcome is shown.")
            }
            return .scored(Scorecard(you: you, opponent: opponent, gapTenths: gap, outcome: result.outcome, judgeVersion: version))
        case .forfeited:
            if let result = match.result,
               !(result.outcome == "forfeitWin" || result.outcome == "forfeitLoss") || result.you != nil || result.opponent != nil {
                return .incomplete("The service's forfeit record contains conflicting result details. No physique scores or replacement outcome are shown.")
            }
            return .forfeit
        case .noContest:
            if let result = match.result,
               result.outcome != "noContest" || result.you != nil || result.opponent != nil || (!result.corrected && result.rating.map({ $0.change != 0 }) == true) {
                return .incomplete("The service's no-contest record contains conflicting result details. No scores or rating adjustment are inferred.")
            }
            return .noContest
        default:
            return .ended
        }
    }

    private static func acceptedTenths(_ scores: PhysiqueScores) -> Int? {
        guard scores.total.isFinite, (0...100).contains(scores.total) else { return nil }
        var weighted = 0
        for category in PhysiqueCategory.allCases {
            let value = scores.value(for: category)
            guard (0...100).contains(value) else { return nil }
            weighted += value * category.weight
        }
        guard weighted % 10 == 0 else { return nil }
        let tenths = weighted / 10
        guard scores.total == Double(tenths) / 10 else { return nil }
        return tenths
    }

    private struct RequestKey: Equatable {
        let ownerID: String?
        let matchID: String
        let active: Bool
        let refreshID: UUID
    }

    private struct ReaderIdentity: Equatable {
        let ownerID: String
        let matchID: String
    }

    private struct LoadedDetail {
        let match: PhysiqueMatch
        let ownerID: String
        let retrievedAt: Date
        let presentation: Presentation
    }

    private struct Scorecard {
        let you: PhysiqueScores
        let opponent: PhysiqueScores
        let gapTenths: Int
        let outcome: String
        let judgeVersion: String
    }

    private enum Presentation {
        case scored(Scorecard), pending, forfeit, noContest, ended, incomplete(String)

        var hasScorecard: Bool {
            if case .scored = self { return true }
            return false
        }

        var hasFinalResult: Bool {
            switch self {
            case .scored, .forfeit, .noContest: return true
            default: return false
            }
        }
    }

    private enum DetailProblem {
        case offline, connection, serviceUnavailable, accountUnavailable, invalidResponse, unavailable

        var title: String {
            switch self {
            case .offline: return "You're offline"
            case .connection: return "Connection interrupted"
            case .serviceUnavailable: return "Physique service unavailable"
            case .accountUnavailable: return "Account access unavailable"
            case .invalidResponse: return "Complete score details unavailable"
            case .unavailable: return "Unable to load score details"
            }
        }

        var detail: String {
            switch self {
            case .offline, .connection:
                return "This match could not be refreshed. No authorized saved scorecard is available here. Reconnect and retry the same match; this is not an unscored outcome."
            case .serviceUnavailable:
                return "The configured secure service could not provide score details. Existing match finality is not changed, and no local scores are generated."
            case .accountUnavailable:
                return "The current account could not be authorized. Previous private values have been cleared. Open Account or retry after access is restored."
            case .invalidResponse:
                return "The service response did not contain complete readable details for this match. No partial card, invented zero or replacement outcome is shown."
            case .unavailable:
                return "This match could not be retrieved with current access. It may be unavailable or permission may have changed. Previous private details have been cleared; retry reads this same match without judging again."
            }
        }

        var symbol: String {
            switch self {
            case .offline, .connection: return "wifi.slash"
            case .accountUnavailable: return "lock.shield"
            default: return "exclamationmark.circle"
            }
        }
    }
}
