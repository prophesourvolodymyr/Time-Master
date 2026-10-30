import SwiftUI

struct PhysiqueEligibilityConsentView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedSection: FocusSection?
    @State private var draftAccountID: String?
    @State private var initializedAccount = false
    @State private var enteredWithChoices = false
    @State private var recordedConsent: PhysiqueConsent?
    @State private var reviewedPolicy: PhysiquePolicy?
    @State private var previousPolicy: PhysiquePolicy?
    @State private var freshPolicyKey: PolicyKey?
    @State private var requiresFreshPolicyGrants = false
    @State private var draftConsentRevision: Double?
    @State private var adultAnswer = AdultAnswer.unanswered
    @State private var attire = Attire.unanswered
    @State private var rulesGrant = false
    @State private var aiGrant = false
    @State private var opponentGrant = false
    @State private var rulesExpanded = false
    @State private var aiExpanded = false
    @State private var opponentExpanded = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isVisible = false
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var changeMessage: String?
    @State private var saved = false
    @State private var pendingSave: PendingSave?
    @State private var saveTask: Task<Void, Never>?

    private enum AdultAnswer: Hashable {
        case unanswered, eligible, ineligible
    }

    private enum Attire: Hashable {
        case unanswered, top, shirtlessAdultMan
    }

    private enum FocusSection: Hashable {
        case introduction, error, changed, saved
    }

    private struct LoadScope: Equatable {
        let accountID: String?
        let active: Bool
    }

    private struct PolicyKey: Equatable {
        let version: String
        let operatorName: String
        let processor: String
        let region: String
        let retention: String
        let judgeVersion: String
        let supportURL: String?

        init(_ policy: PhysiquePolicy) {
            version = policy.version
            operatorName = policy.operatorName
            processor = policy.processor
            region = policy.region
            retention = policy.retention
            judgeVersion = policy.judgeVersion
            supportURL = policy.supportURL
        }
    }

    private struct PendingSave {
        let accountID: String
        let policyKey: PolicyKey
        let consent: PhysiqueConsent
        let previousConsent: PhysiqueConsent
        let consentRevision: Double
        let privacyRevision: UInt64
        let continueToCamera: Bool
    }

    private var account: PhysiqueAccount? {
        guard initializedAccount, draftAccountID == cloudAccount.accountID,
              cloudAccount.accountID != nil else { return nil }
        return store.account
    }

    private var policyKey: PolicyKey? { store.policy.map(PolicyKey.init) }
    private var hasRecordedChoices: Bool { account?.consent.policyVersion.isEmpty == false }
    private var currentRules: Bool { account?.consent.rulesAccepted == true && consentIsCurrent && !requiresFreshPolicyGrants }
    private var currentAI: Bool { account?.consent.aiProcessing == true && consentIsCurrent && !requiresFreshPolicyGrants && !store.localProcessingStopped }
    private var currentOpponent: Bool { account?.consent.opponentSharing == true && consentIsCurrent && !requiresFreshPolicyGrants && !store.localOwnMediaHidden }
    private var consentIsCurrent: Bool {
        guard let policy = store.policy, let consent = account?.consent else { return false }
        return consent.policyVersion == policy.version && !policy.version.isEmpty
    }

    private var title: String {
        if requiresFreshPolicyGrants || (hasRecordedChoices && !consentIsCurrent) { return "Review sharing changes" }
        return enteredWithChoices || hasRecordedChoices ? "Sharing choices" : "Before you pose"
    }

    private var supportURL: URL? {
        guard let value = store.policy?.supportURL,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        if url.scheme?.lowercased() == "https", url.host?.isEmpty == false { return url }
        if url.scheme?.lowercased() == "mailto", url.path.contains("@") { return url }
        return nil
    }

    private var missingDisclosure: String? {
        guard let policy = store.policy else { return "The current operator-approved sharing notice could not be loaded." }
        if policy.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The current policy version is unavailable." }
        if policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The responsible operator is not disclosed." }
        if policy.processor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The model and safety-processing recipients are not disclosed." }
        if policy.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The processing and storage regions are not disclosed." }
        if policy.retention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The actual processor and service retention terms are not disclosed." }
        if policy.judgeVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "The judging version is not disclosed." }
        if supportURL == nil { return "A valid operator contact is unavailable." }
        if !policy.ready { return policy.unavailableReason ?? "The service has not enabled participation under this sharing notice." }
        return nil
    }

    private var disclosureConfirmed: Bool {
        guard let key = policyKey else { return false }
        return freshPolicyKey == key && missingDisclosure == nil && !isLoading && loadError == nil && !store.isStale
    }

    private var hasActiveMatch: Bool {
        account != nil && store.stage != .idle && !store.stage.terminal
    }

    private var activeClock: PhysiqueClock? {
        guard hasActiveMatch, presentationActive else { return nil }
        let mode: PhysiqueClock.Mode
        let endpoint: Double?
        let label: String
        switch store.stage {
        case .searching:
            mode = .remaining
            endpoint = store.snapshot?.queueDeadline
            label = "Search remaining"
        case .countdown:
            mode = .countdown
            endpoint = store.match?.startAt
            label = "Match starts in"
        case .capture, .submitting:
            mode = .remaining
            endpoint = store.match?.deadline
            label = "Capture remaining"
        case .judging:
            mode = .elapsed
            endpoint = store.match?.judgingStartedAt
            label = "Judging elapsed"
        case .ready:
            mode = .remaining
            endpoint = store.match?.deadline
            label = "Ready room remaining"
        default:
            return nil
        }
        return PhysiqueClock(mode: endpoint == nil ? .unavailable : mode, label: label, endpoint: endpoint, serverOffset: store.serverOffset)
    }

    private var nextRequirement: String? {
        if !disclosureConfirmed { return "A complete, current sharing notice must be confirmed before saving choices." }
        if account == nil { return "Confirm your signed-in account before choosing." }
        if draftConsentRevision == nil { return "The service must confirm the current choice revision before a new grant can be saved." }
        if let reason = account?.restrictedReason, !reason.isEmpty { return "Participation is restricted: \(reason)" }
        if adultAnswer == .unanswered { return "Choose your adult-eligibility answer to continue." }
        if adultAnswer == .ineligible { return "Physique Duels is for eligible adults. Other available Tmax features remain usable." }
        if attire == .unanswered { return "Choose your attire to continue." }
        if !(currentRules || rulesGrant) { return "Accept the Physique rules to continue." }
        if !(currentAI || aiGrant) { return "AI and safety processing requires a separate affirmative choice." }
        if !(currentOpponent || opponentGrant) { return "Opponent still access requires a separate affirmative choice." }
        if !store.canControl(from: windowID) { return "Another window controls this Physique session. Privacy controls remain available here." }
        return nil
    }

    private var unchanged: Bool {
        guard let consent = account?.consent, currentRules, currentAI, currentOpponent else { return false }
        return consent.accepted && adultAnswer == .eligible &&
            (attire == .shirtlessAdultMan) == consent.adultMan && attire != .unanswered
    }

    var body: some View {
        PhysiqueScreen(title: title) {
            if !presentationActive {
                PhysiqueStatusView(title: "Private choices hidden", detail: "Return to this window to review the current account and sharing notice.", systemImage: "lock.fill")
            } else {
                if let clock = activeClock {
                    PhysiqueTimerView(clock: clock)
                    PhysiqueAction(title: "Return to match controls", systemImage: "arrow.left", role: .cancel, action: returnWithoutSaving)
                    Text("Reviewing or closing this form does not confirm a forfeit. The original match deadlines continue.")
                }
                introduction
                if cloudAccount.accountID == nil {
                    PhysiqueStatusView(title: "Sign in to choose", detail: "Your adult declaration and sharing choices belong to your Tmax account. No consent is saved here while signed out.", systemImage: "person.crop.circle")
                    PhysiqueAction(title: "Open Tmax account", systemImage: "person.crop.circle") { onOpen(.account) }
                    PhysiqueAction(title: "Not now", role: .cancel, action: returnWithoutSaving)
                } else {
                    signedInContent
                }
            }
        }
        .task(id: LoadScope(accountID: cloudAccount.accountID, active: presentationActive)) {
            await loadCurrentState()
        }
        .onAppear {
            isVisible = true
            store.suspendCapture()
            focusedSection = .introduction
        }
        .onDisappear {
            isVisible = false
            saveTask?.cancel()
            store.suspendCapture()
        }
        .onChange(of: cloudAccount.accountID) { _ in
            clearAccountDraft()
            draftAccountID = cloudAccount.accountID
            store.suspendCapture()
        }
        .onChange(of: policyKey) { _ in reconcilePolicy() }
        .onChange(of: store.account?.consent) { _ in reconcileConsent() }
        .onChange(of: store.account?.consentRevision) { _ in reconcileConsent() }
        .onChange(of: store.privacyRevision) { _ in
            rulesGrant = false
            aiGrant = false
            opponentGrant = false
            pendingSave = nil
            saved = false
            if initializedAccount {
                changeMessage = "Privacy protection changed while this form was open. Current protections remain active; any new sharing needs a fresh deliberate choice."
            }
        }
        .onChange(of: store.lastRefreshedAt) { _ in
            if presentationActive { reconcileFreshState() }
        }
        .onChange(of: store.loading) { loading in
            if !loading && isLoading && presentationActive { finishLoading() }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Label("Private choices", systemImage: "lock")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedSection, equals: .introduction)
            Text("Three guided poses. Hosted AI judging. Separate Physique Elo.")
                .font(TimeMasterFont.heading())
            Text("Scores are subjective judgements of the selected poses, not measurements of health, strength, body fat, muscle mass or identity. More skin earns no bonus.")
            Text("Live preview stays local. Necessary candidates and selected stills may leave only after local face obscuring and your required sharing choices. You preview the redacted submission. Masking does not guarantee anonymity; a bystander invalidates a capture.")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var signedInContent: some View {
        if isLoading {
            ProgressView("Loading current sharing choices")
        }
        if hasRecordedChoices { savedChoices }
        if let changeMessage {
            PhysiqueStatusView(title: "Sharing details changed", detail: changeMessage, systemImage: "arrow.triangle.2.circlepath")
                .accessibilityFocused($focusedSection, equals: .changed)
        } else if hasRecordedChoices && !consentIsCurrent, let policy = store.policy, let consent = account?.consent {
            PhysiqueCard {
                heading("Review the current notice")
                Text("Your saved choices refer to policy \(consent.policyVersion). The current notice is \(policy.version). Review its operator, recipients, regions, retention and rules before making fresh sharing choices.")
                Text("This does not authorize past transfers or change a match's frozen judging configuration.")
            }
        }
        if let reason = account?.restrictedReason, !reason.isEmpty {
            PhysiqueStatusView(title: "Physique participation restricted · Private", detail: reason, systemImage: "hand.raised")
            Text("Changing a local declaration cannot remove a service restriction. Use the published contact or your safety cases for an available review.")
            PhysiqueAction(title: "Open safety cases", systemImage: "tray") { open(.cases) }
            contactLink
            returnAction
        } else if !disclosureConfirmed {
            if !isLoading {
                PhysiqueStatusView(title: "Sharing details unavailable", detail: loadError ?? missingDisclosure ?? "The current sharing notice has not been confirmed. No new sharing is enabled.", retry: startReload)
                    .accessibilityFocused($focusedSection, equals: .error)
            }
            if let policy = store.policy { policyDisclosure(policy) }
            Text("No new image sharing can be agreed to until the service supplies a complete approved notice. Existing choices are not withdrawn by leaving this form.")
            privacyAction
            returnAction
        } else if account == nil {
            PhysiqueStatusView(title: "Account choices unavailable", detail: "The service has not confirmed the current account's choices. No saved declaration from another account is used.", retry: startReload)
            returnAction
        } else {
            eligibility
            if adultAnswer == .ineligible {
                PhysiqueStatusView(title: "Physique Duels is for eligible adults", detail: "You must be at least 18 and meet any stricter applicable adult requirement. This unsaved answer is private. Other available Tmax features remain usable.", systemImage: "lock")
                secondaryButton("Read Physique rules", systemImage: "list.bullet.rectangle") { open(.rules) }
                PhysiqueAction(title: "Return to Physique", role: .cancel) { open(.lobby) }
            } else {
                attireChoices
                rulesChoices
                aiChoices
                opponentChoices
                actionArea
            }
            privacyAction
        }
    }

    private var savedChoices: some View {
        PhysiqueCard {
            heading("Saved account choices")
            if let consent = account?.consent {
                Text("Confirmed by the service for policy \(consent.policyVersion). These are existing choices, not a new grant or independent age verification.")
                statusRow("Adult declaration", value: consent.adult ? "Declared eligible" : "Not affirmed")
                if consent.adult {
                    statusRow("Attire declaration", value: consent.adultMan ? "Shirtless adult man" : "Athletic top")
                }
                statusRow("Physique rules", value: consent.rulesAccepted ? "Accepted for saved version" : "Not accepted")
                statusRow("AI and safety processing", value: consent.aiProcessing ? "Granted for saved version" : "Not granted")
                statusRow("Opponent still access", value: consent.opponentSharing ? "Granted for saved version" : "Not granted")
                if store.isStale { Text("Last confirmed state; the service is currently unreachable.") }
            }
        }
    }

    private var eligibility: some View {
        PhysiqueCard {
            heading("Adult eligibility · Private")
            Text("At least 18, and any stricter applicable adult requirement. This is your declaration, not verified age. Your public country does not determine eligibility.")
            #if os(macOS)
            Picker("Adult declaration", selection: adultSelection) {
                Text("No answer yet").tag(AdultAnswer.unanswered)
                Text("I meet the adult requirement (18 or older)").tag(AdultAnswer.eligible)
                Text("I don't meet it").tag(AdultAnswer.ineligible)
            }
            .pickerStyle(.radioGroup)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6), action: { changeAdult(adultAnswer == .eligible ? .ineligible : .eligible) })
            #else
            choiceRow("I meet the adult requirement", detail: "18 or older, and any stricter applicable requirement.", selected: adultAnswer == .eligible) { changeAdult(.eligible) }
            choiceRow("I don't meet it", detail: "Leave Physique Duels without saving a new grant.", selected: adultAnswer == .ineligible) { changeAdult(.ineligible) }
            #endif
        }
        .disabled(isSaving)
    }

    private var attireChoices: some View {
        PhysiqueCard {
            heading("Your attire · Private")
            #if os(macOS)
            Picker("Attire declaration", selection: attireSelection) {
                Text("No attire chosen").tag(Attire.unanswered)
                Text("Athletic top — opaque athletic top or sports bra").tag(Attire.top)
                Text("Shirtless adult man — I am an adult man; nonsexual fitness poses only.")
                    .tag(Attire.shirtlessAdultMan)
                    .disabled(adultAnswer != .eligible)
            }
            .pickerStyle(.radioGroup)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6), action: { changeAttire(attire == .top ? .shirtlessAdultMan : .top) })
            #else
            choiceRow("Athletic top", detail: "An opaque athletic top or opaque sports bra.", selected: attire == .top) { changeAttire(.top) }
            choiceRow("Shirtless adult man", detail: "I am an adult man; nonsexual fitness poses only.", selected: attire == .shirtlessAdultMan, disabled: adultAnswer != .eligible) { changeAttire(.shirtlessAdultMan) }
            #endif
            if adultAnswer != .eligible { Text("Affirm adult eligibility before choosing shirtless attire.") }
            Text("Cover groin and buttocks in every pose.").font(TimeMasterFont.label())
            Text("Lower garments must remain opaque during turns and rear poses. No sexualized framing or removal of required coverage. If clothing obscures required evidence, use safe framing, an optional permitted retake, or no contest—not more exposure.")
            Text("These declarations are private participation and safety information. They are not badges, matchmaking filters or judging inputs.")
        }
        .disabled(isSaving)
    }

    private var rulesChoices: some View {
        PhysiqueCard {
            heading("Competition rules")
            Text("Front double biceps, side physique and rear double biceps. A shared 90-second capture period, with at most two retakes per pose.")
            Text("Before Go: cancel without rating or allowance loss. After Go: an intentional, confirmed exit can forfeit an otherwise eligible match. Safety, invalid evidence and service no-contest take precedence.")
            if currentRules {
                Label("Rules already accepted for this version", systemImage: "checkmark.circle")
            } else {
                consentToggle("I accept the Physique rules", selection: rulesSelection)
            }
            DisclosureGroup("Read rules", isExpanded: $rulesExpanded) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("The common rubric uses shoulder, upper-arm, upper-back and leg evidence. Front-chest and abdominal definition are excluded for both participants. Covered anatomy is not invented or scored as zero.")
                    Text("Muscularity 40%, definition 30%, symmetry and balance 20%, pose presentation 10%. These are subjective observations, not physical measurements or a judgement of personal worth.")
                    Text("No live opponent video, microphone or chat. Every still must satisfy the permitted attire, face-obscuring, single-participant and evidence rules. Insufficient comparable evidence or an unavailable judge cannot produce a valid scored outcome.")
                    Text("Report, hide and block are available without enlarging an image. Interruption is not an intentional forfeit; the service controls recovery, deadlines and finality. A consent action does not reserve or consume a match allowance.")
                    secondaryButton("Open full Physique rules", systemImage: "list.bullet.rectangle") { open(.rules) }
                }
                .padding(.top, ProfileStyle.spacing)
                .textSelection(.enabled)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { rulesExpanded.toggle() })
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: rulesExpanded)
        }
    }

    private var aiChoices: some View {
        PhysiqueCard {
            heading("AI and safety processing")
            if let policy = store.policy {
                policyDisclosure(policy)
                Text("Necessary face-obscured candidates go to protected safety checks. The accepted six-still pair and limited neutral pose context go to the disclosed judge for one physique judgement.")
                Text("The scoring judge does not receive handles, Elo, country, badges, private age or attire declarations, payment information or unrelated app history. Safety controls may receive the applicable attire rule without your public identity.")
                Text("App-controlled media ordinarily expires no later than 24 hours after service finalization. Processor retention is separate and follows the actual disclosure above; limited report, safety or legal exceptions are not ordinary opponent access.")
                if currentAI {
                    Label("Existing AI grant · Current version", systemImage: "checkmark.circle")
                    secondaryButton("Withdraw AI sharing…", systemImage: "hand.raised") { open(.privacy) }
                    Text("Opens Privacy & sharing for the canonical withdrawal confirmation and request status.")
                } else {
                    consentToggle("I agree to AI and safety processing", selection: aiSelection)
                }
                DisclosureGroup("AI and retention details", isExpanded: $aiExpanded) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("The operator's recipient, region and retention text above is the current service disclosure, including its processor arrangements and exceptions. App expiry does not by itself erase processor abuse logs, application state, caches, stored files or lawful preservation.")
                        Text("Live preview and transient originals remain local for framing and face obscuring. Necessary protected candidates never become an opponent gallery. Rejected or orphaned uploads expire no later than 24 hours after receipt absent a specific lawful exception; unnecessary candidates are disposed of promptly.")
                        Text("Necessary authorized reviewers may handle a reported case. Only the disclosed limited report or legal-safety scope may preserve media beyond ordinary expiry; that never extends opponent viewing. Nonmedia consent, score, history, case and backup lifetimes are separate from body-image expiry and follow the operator's retention disclosure.")
                        Text("This grant does not authorize research, training-set collection, fine-tuning, advertising, marketing reuse, sale of images or use of your personal provider key. A no-training arrangement is not a promise of no storage or safety review.")
                        Text("You may decline now, or withdraw future processing and remove your own ordinary shared images in Privacy & sharing. An already accepted processor request may not be retractable. Regrant does not resend old images, restore a removed gallery, reset deadlines or reopen a final match.")
                        contactLink
                    }
                    .padding(.top, ProfileStyle.spacing)
                    .textSelection(.enabled)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { aiExpanded.toggle() })
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: aiExpanded)
            }
        }
    }

    private var opponentChoices: some View {
        PhysiqueCard {
            heading("Paired-opponent still access")
            Text("Only your matched participant may intentionally open your three approved stills after a valid AI-judged win, loss or draw. The ordinary 24-hour window starts at service finalization—not first viewing.")
            Text("No live feed, early thumbnail, public body-photo feed, forfeit gallery or no-contest gallery. Current permission, moderation, block, removal and expiry checks still apply.")
            Text("The opponent may copy images they can view.").font(TimeMasterFont.label())
            if currentOpponent {
                Label("Existing opponent-access grant · Current version", systemImage: "checkmark.circle")
                secondaryButton("Withdraw opponent access…", systemImage: "hand.raised") { open(.privacy) }
                Text("Opens Privacy & sharing for the canonical withdrawal confirmation and request status.")
            } else {
                consentToggle("I agree to opponent still access", selection: opponentSelection)
            }
            DisclosureGroup("Who can see my poses?", isExpanded: $opponentExpanded) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("The paired participant sees permitted public identity and match status during participation, not your live camera or private declarations. Only moderated selected stills can be deliberately opened after a valid judged result. Rejected candidates, forfeits and no-contests never supply a gallery.")
                    Text("Face obscuring does not guarantee anonymity. Body features, tattoos, clothing and surroundings can remain recognizable. Screenshots and external recordings cannot be reliably prevented or remotely erased.")
                    Text("Report or hide an image before enlargement, or use Safety to block a player. Withdrawing your own sharing revokes future ordinary access; removing images is separate from hiding another person's image. A limited case-review hold is not permission for continued opponent access.")
                    Text("Reacceptance permits only future authorized use. It does not restore removed galleries, renew the original expiry, reroll ratings or authorize past transfers. Public standings listing and any result-card export remain separate optional choices.")
                    secondaryButton("Open Privacy & sharing", systemImage: "hand.raised") { open(.privacy) }
                    secondaryButton("Open safety controls", systemImage: "shield") { open(.safety) }
                }
                .padding(.top, ProfileStyle.spacing)
                .textSelection(.enabled)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { opponentExpanded.toggle() })
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: opponentExpanded)
        }
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Both sharing choices are required for rated Physique Duels. Other available app features remain usable.")
            if isSaving {
                ProgressView("Saving choices")
                Text("Your local selections are not confirmed account consent until the service acknowledges them.")
            }
            if let saveError {
                PhysiqueStatusView(title: "Choices not confirmed", detail: saveError)
                    .accessibilityFocused($focusedSection, equals: .error)
            }
            if saved {
                Label("Choices confirmed by the service", systemImage: "checkmark.circle")
                    .accessibilityFocused($focusedSection, equals: .saved)
                Text("No camera, image transfer or match was started. Regrant does not resume an active match automatically.")
            }
            if let nextRequirement, !isSaving { Text(nextRequirement) }
            if unchanged && pendingSave == nil && !isSaving {
                PhysiqueAction(title: "Done", systemImage: "checkmark", role: .cancel, action: returnWithoutSaving)
            } else {
                PhysiqueAction(title: pendingSave == nil ? (enteredWithChoices || hasActiveMatch ? "Save choices" : "Continue to camera setup") : "Retry saving choices", systemImage: "checkmark", disabled: nextRequirement != nil || isSaving || store.busy) {
                    saveTask = Task { await saveChoices(retrying: pendingSave != nil) }
                }
                Text("Saving does not open the camera, request system permission, find an opponent, spend an allowance or list you publicly.")
                returnAction
            }
        }
    }

    private var privacyAction: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            secondaryButton("Privacy & sharing", systemImage: "hand.raised") { open(.privacy) }
            Text("Manage existing choices, withdraw each sharing scope, remove your shared images or reach account deletion. Leaving this grant form does not withdraw an existing choice.")
        }
    }

    private var returnAction: some View {
        PhysiqueAction(title: enteredWithChoices || pendingSave != nil || isSaving ? "Return without new consent" : "Not now", role: .cancel, action: returnWithoutSaving)
    }

    @ViewBuilder
    private var contactLink: some View {
        if let supportURL {
            Link(destination: supportURL) {
                Label("Contact \(store.policy?.operatorName ?? "the operator")", systemImage: "arrow.up.right.square")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, contactPadding)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            Text(supportURL.absoluteString).textSelection(.enabled)
        }
    }

    private var contactPadding: CGFloat {
        #if os(iOS)
        return ProfileStyle.spacing
        #else
        return 0
        #endif
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
    }

    private func statusRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TimeMasterFont.label())
            Text(value)
        }
        .accessibilityElement(children: .combine)
    }

    private func policyDisclosure(_ policy: PhysiquePolicy) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            statusRow("Policy version", value: policy.version.isEmpty ? "Unavailable" : policy.version)
            statusRow("Responsible operator", value: policy.operatorName.isEmpty ? "Not disclosed" : policy.operatorName)
            statusRow("Model and safety-processing recipients", value: policy.processor.isEmpty ? "Not disclosed" : policy.processor)
            statusRow("Processing and storage regions", value: policy.region.isEmpty ? "Not disclosed" : policy.region)
            statusRow("Actual retention and exceptions", value: policy.retention.isEmpty ? "Not disclosed" : policy.retention)
            statusRow("Judging version", value: policy.judgeVersion.isEmpty ? "Not disclosed" : policy.judgeVersion)
            if let previousPolicy {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("Policy \(previousPolicy.version)")
                        Text(previousPolicy.operatorName)
                        Text(previousPolicy.processor)
                        Text(previousPolicy.region)
                        Text(previousPolicy.retention)
                        Text("Judging version: \(previousPolicy.judgeVersion)")
                    }
                    .padding(.top, ProfileStyle.spacing)
                } label: {
                    Text("Earlier notice shown during this visit")
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0))
                }
            }
            contactLink
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    private func consentToggle(_ title: String, selection: Binding<Bool>) -> some View {
        Toggle(isOn: selection) {
            Text(title).font(TimeMasterFont.label()).fixedSize(horizontal: false, vertical: true)
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6), action: { selection.wrappedValue.toggle() })
        .disabled(isSaving)
        .accessibilityHint("Separate permission required for rated Physique Duels. Changing this draft does not save it.")
        #if os(macOS)
        .toggleStyle(.checkbox)
        #else
        .frame(minHeight: ProfileStyle.touchTarget)
        #endif
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                #if os(iOS)
                .frame(minHeight: ProfileStyle.touchTarget)
                #endif
        }
        .buttonStyle(.borderless)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
    }

    private func choiceRow(_ title: String, detail: String, selected: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(TimeMasterFont.label())
                    Text(detail)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var adultSelection: Binding<AdultAnswer> {
        Binding(get: { adultAnswer }, set: changeAdult)
    }

    private var attireSelection: Binding<Attire> {
        Binding(get: { attire }, set: changeAttire)
    }

    private var rulesSelection: Binding<Bool> {
        Binding(get: { rulesGrant }, set: { rulesGrant = $0; draftChanged() })
    }

    private var aiSelection: Binding<Bool> {
        Binding(get: { aiGrant }, set: { aiGrant = $0; draftChanged() })
    }

    private var opponentSelection: Binding<Bool> {
        Binding(get: { opponentGrant }, set: { opponentGrant = $0; draftChanged() })
    }

    private func changeAdult(_ answer: AdultAnswer) {
        adultAnswer = answer
        if answer != .eligible && attire == .shirtlessAdultMan { attire = .unanswered }
        draftChanged()
    }

    private func changeAttire(_ choice: Attire) {
        guard choice != .shirtlessAdultMan || adultAnswer == .eligible else { return }
        attire = choice
        draftChanged()
    }

    private func draftChanged() {
        guard !isSaving else { return }
        pendingSave = nil
        saveError = nil
        saved = false
    }

    private func startReload() {
        Task { await loadCurrentState() }
    }

    @MainActor
    private func loadCurrentState() async {
        store.suspendCapture()
        guard presentationActive else { return }
        let owner = cloudAccount.accountID
        if draftAccountID != owner { clearAccountDraft(); draftAccountID = owner }
        isLoading = true
        loadError = nil
        freshPolicyKey = nil
        store.clearError()
        if owner == nil { await store.loadPolicy() }
        else { await store.refresh() }
        guard !Task.isCancelled, owner == cloudAccount.accountID, presentationActive else { return }
        if !store.loading { finishLoading() }
    }

    private func finishLoading() {
        isLoading = false
        loadError = store.error
        if loadError == nil && cloudAccount.accountID != nil && store.account == nil {
            loadError = "The service has not confirmed the current account's sharing choices."
        }
        if loadError == nil { reconcileFreshState() }
    }

    private func reconcileFreshState() {
        guard presentationActive, draftAccountID == cloudAccount.accountID,
              !store.isStale, store.error == nil else { return }
        reconcilePolicy()
        reconcileConsent()
        freshPolicyKey = policyKey
        loadError = nil
    }

    private func reconcilePolicy() {
        guard draftAccountID == cloudAccount.accountID, let policy = store.policy else { return }
        if let reviewedPolicy, PolicyKey(reviewedPolicy) != PolicyKey(policy) {
            previousPolicy = reviewedPolicy
            requiresFreshPolicyGrants = true
            rulesGrant = false
            aiGrant = false
            opponentGrant = false
            pendingSave = nil
            saved = false
            changeMessage = "The notice changed from \(reviewedPolicy.version) to \(policy.version) while this form was open. Review the current recipients, regions, retention and rules. New affected choices remain unselected."
            focusedSection = .changed
        }
        reviewedPolicy = policy
    }

    private func reconcileConsent() {
        guard draftAccountID == cloudAccount.accountID, cloudAccount.accountID != nil,
              let account = store.account else { return }
        let consent = account.consent
        let revisionChanged = initializedAccount && draftConsentRevision != account.consentRevision
        if !initializedAccount {
            initializedAccount = true
            enteredWithChoices = !consent.policyVersion.isEmpty
            if enteredWithChoices {
                adultAnswer = consent.adult ? .eligible : .unanswered
                attire = consent.adult ? (consent.adultMan ? .shirtlessAdultMan : .top) : .unanswered
            }
        } else if let previous = recordedConsent, previous != consent || revisionChanged {
            if previous.adult != consent.adult || previous.adultMan != consent.adultMan {
                adultAnswer = consent.adult ? .eligible : .unanswered
                attire = consent.adult ? (consent.adultMan ? .shirtlessAdultMan : .top) : .unanswered
            }
            if previous.rulesAccepted != consent.rulesAccepted || previous.policyVersion != consent.policyVersion || revisionChanged { rulesGrant = false }
            if previous.aiProcessing != consent.aiProcessing || previous.policyVersion != consent.policyVersion || revisionChanged { aiGrant = false }
            if previous.opponentSharing != consent.opponentSharing || previous.policyVersion != consent.policyVersion || revisionChanged { opponentGrant = false }
            if !isSaving {
                pendingSave = nil
                saved = false
                changeMessage = "Your account choices changed on the service. The current confirmed status is shown; make any new grant deliberately."
            }
        }
        draftConsentRevision = account.consentRevision
        recordedConsent = consent
    }

    @MainActor
    private func saveChoices(retrying: Bool) async {
        guard !isSaving, !store.busy, nextRequirement == nil,
              let owner = cloudAccount.accountID, let policy = store.policy,
              let existing = account?.consent, let revision = draftConsentRevision,
              presentationActive, store.claimControl(for: windowID) else { return }
        let request: PendingSave
        if retrying, let pendingSave {
            request = pendingSave
        } else {
            request = PendingSave(
                accountID: owner,
                policyKey: PolicyKey(policy),
                consent: PhysiqueConsent(adult: adultAnswer == .eligible, adultMan: attire == .shirtlessAdultMan, rulesAccepted: currentRules || rulesGrant, aiProcessing: currentAI || aiGrant, opponentSharing: currentOpponent || opponentGrant, policyVersion: policy.version),
                previousConsent: existing,
                consentRevision: revision,
                privacyRevision: store.privacyRevision,
                continueToCamera: !enteredWithChoices && !hasActiveMatch
            )
        }
        pendingSave = request
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        store.clearError()
        await store.refresh()
        guard request.accountID == cloudAccount.accountID, !Task.isCancelled, isVisible else { return }
        guard request.privacyRevision == store.privacyRevision else {
            pendingSave = nil
            failSave("Privacy protection changed before confirmation. Review the current choices; no stale grant will be sent.")
            return
        }
        guard !store.loading, !store.isStale, store.error == nil else {
            failSave(store.error ?? "Current choices could not be reconciled. Retry when the service is available.")
            return
        }
        reconcileFreshState()
        let reconciledRetry = retrying && confirmed(request)
        guard policyKey == request.policyKey, missingDisclosure == nil,
              reconciledRetry || (store.account?.consent == request.previousConsent &&
                  store.account?.consentRevision == request.consentRevision) else {
            pendingSave = nil
            rulesGrant = false
            aiGrant = false
            opponentGrant = false
            failSave("The policy or saved choices changed. Review the current notice and make fresh sharing choices before saving again.")
            return
        }
        let success = await store.perform("consent", consent: request.consent, expectedRevision: request.consentRevision)
        guard request.accountID == cloudAccount.accountID, !Task.isCancelled, isVisible else { return }
        if success && confirmed(request) {
            completeSave(request)
        } else {
            failSave(store.error ?? "The service did not confirm these choices for the current policy. Nothing here has been treated as a new permission.")
        }
    }

    private func confirmed(_ request: PendingSave) -> Bool {
        request.accountID == cloudAccount.accountID && policyKey == request.policyKey &&
            request.privacyRevision == store.privacyRevision &&
            store.account?.consent == request.consent && store.account?.consent.accepted == true &&
            store.account?.restrictedReason?.isEmpty != false && store.policy?.ready == true &&
            missingDisclosure == nil && !store.isStale && !store.localProcessingStopped && !store.localOwnMediaHidden
    }

    private func completeSave(_ request: PendingSave) {
        pendingSave = nil
        saveError = nil
        requiresFreshPolicyGrants = false
        changeMessage = nil
        saved = true
        reconcileFreshState()
        focusedSection = .saved
        if request.continueToCamera && presentationActive && store.canControl(from: windowID) {
            onOpen(.camera)
        }
    }

    private func failSave(_ message: String) {
        saveError = message
        focusedSection = .error
    }

    private func clearAccountDraft() {
        saveTask?.cancel()
        draftAccountID = nil
        initializedAccount = false
        enteredWithChoices = false
        recordedConsent = nil
        reviewedPolicy = nil
        previousPolicy = nil
        freshPolicyKey = nil
        requiresFreshPolicyGrants = false
        draftConsentRevision = nil
        adultAnswer = .unanswered
        attire = .unanswered
        rulesGrant = false
        aiGrant = false
        opponentGrant = false
        rulesExpanded = false
        aiExpanded = false
        opponentExpanded = false
        isLoading = false
        isSaving = false
        loadError = nil
        saveError = nil
        changeMessage = nil
        pendingSave = nil
        saved = false
    }

    private func open(_ route: PhysiqueRoute) {
        store.suspendCapture()
        onOpen(route)
    }

    private func returnWithoutSaving() {
        store.suspendCapture()
        saveTask?.cancel()
        if enteredWithChoices || hasActiveMatch { dismiss() }
        else { onOpen(.lobby) }
    }
}
