import SwiftUI

struct PhysiqueRulesView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var focusedSection: ReadingSection?
    @State private var muscularityExpanded = false
    @State private var definitionExpanded = false
    @State private var symmetryExpanded = false
    @State private var presentationExpanded = false
    @State private var servicePolicyExpanded = false
    @State private var refreshingPolicy = false
    @State private var policyLoadError: String?
    @State private var policyRefreshedAt: Date?
    @State private var refreshedPolicyVersion: String?

    private enum ReadingSection: String, CaseIterable, Hashable {
        case policy = "Service policy"
        case rubric = "Rubric"
        case evidence = "Comparable evidence"
        case attire = "Attire and eligibility"
        case outcomes = "Outcomes and finality"
        case timing = "Timing and recovery"
        case privacy = "Privacy and sharing"
    }

    var body: some View {
        ScrollViewReader { proxy in
            PhysiqueScreen(title: "Rules and rubric", subtitle: "Reading is not consent.") {
                orientation
                policyStatus
                rubric
                evidence
                attire
                outcomes
                timing
                privacy
                destinations
            }
            .textSelection(.enabled)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(ReadingSection.allCases, id: \.self) { section in
                            Button(section.rawValue) {
                                proxy.scrollTo(section, anchor: .top)
                                focusedSection = section
                            }
                        }
                    } label: {
                        Label("Sections", systemImage: "list.bullet")
                            .frame(minHeight: controlHeight)
                    }
                    .accessibilityHint("Jump to a heading in the complete rulebook.")
                }
            }
#if os(macOS)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Reading accepts nothing.")
                        .font(TimeMasterFont.secondary())
                    Spacer()
                    Button("Close rules") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(ProfileStyle.inset)
                .background(Theme.surface)
            }
#endif
        }
        .onAppear { store.suspendCapture() }
        .task { await refreshPolicy() }
    }

    private var policy: PhysiquePolicy? { store.policy ?? store.snapshot?.policy }

    private var controlHeight: CGFloat {
#if os(iOS)
        ProfileStyle.touchTarget
#else
        28
#endif
    }

    private var policyComplete: Bool {
        guard let policy else { return false }
        return supplied(policy.version) != nil
            && supplied(policy.operatorName) != nil
            && supplied(policy.processor) != nil
            && supplied(policy.region) != nil
            && supplied(policy.retention) != nil
            && supplied(policy.judgeVersion) != nil
    }

    private var policyConfirmed: Bool {
        policyLoadError == nil && policyRefreshedAt != nil && refreshedPolicyVersion == policy?.version
    }

    private var configured: Bool { policy?.ready == true && policyComplete }

    private var policyStatus: some View {
        PhysiqueCard {
            Text(configured ? "Service policy" : "Rated play unavailable")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedSection, equals: .policy)
                .id(ReadingSection.policy)
            if refreshingPolicy {
                ProgressView("Refreshing policy")
            } else if policyLoadError != nil {
                paragraph("Refresh failed. Current terms are not confirmed.")
            } else if !configured {
                paragraph("Proposed rules only. Participation is not approved here.")
            } else if !policyConfirmed {
                paragraph("Current policy version is not confirmed.")
            }
            if !policyComplete {
                paragraph("Required sharing information is unavailable.")
            }
            DisclosureGroup(isExpanded: $servicePolicyExpanded) {
                servicePolicyDetails
                    .padding(.top, ProfileStyle.spacing)
            } label: {
                Text("Service policy, recipients and retention")
                    .font(TimeMasterFont.label())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: controlHeight, alignment: .leading)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: servicePolicyExpanded)
            if policyLoadError != nil {
                PhysiqueAction(title: "Retry policy", systemImage: "arrow.clockwise", disabled: refreshingPolicy) {
                    Task { await refreshPolicy() }
                }
            }
            if let notice = readingNotice {
                Label(notice, systemImage: "camera.fill.badge.ellipsis")
                    .font(TimeMasterFont.label())
                paragraph("Reading does not pause the clock or exit. Camera resume must be explicit.")
            }
        }
    }

    private var servicePolicyDetails: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if let policy {
                policyField("Policy version", value: policy.version)
                policyField("Judge configuration", value: policy.judgeVersion)
                if policyConfirmed, let policyRefreshedAt {
                    Text("Policy refreshed \(policyRefreshedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    paragraph("Available policy · Current version not confirmed. Previously supplied terms remain readable, but they are not a new consent grant.")
                }
                if let reason = supplied(policy.unavailableReason) {
                    rule("Availability", reason)
                }
            } else {
                paragraph("No service policy is available. The rulebook explains the proposed format; it is not approval to participate or upload images.")
            }
            policyField("Operator", value: policy?.operatorName)
            policyField("Processor information supplied by the service", value: policy?.processor)
            policyField("Processing region information", value: policy?.region)
            policyField("Actual service retention terms", value: policy?.retention)
            if !policyComplete {
                paragraph("Required recipient, processing-region, retention or version information is missing. Do not start participation on the basis of this reader.")
            }
            if let policyLoadError {
                Text("Could not refresh policy: \(policyLoadError)")
                    .fixedSize(horizontal: false, vertical: true)
                paragraph("Known text stays available. A failed refresh does not confirm that it is still current.")
            }
            PhysiqueAction(title: "Refresh service policy", systemImage: "arrow.clockwise", disabled: refreshingPolicy) {
                Task { await refreshPolicy() }
            }
            paragraph("This reader explains the app's fixed rubric and the service policy shown above. It is not a historical policy archive. A saved result's original rules and sharing terms are not reconstructed from today's policy; use its match details for the recorded result and judge version.")
            paragraph("A service-ready status is not a guarantee of objective fairness, accuracy or response time. The common-region rule and scoring anchors need human calibration across clothing, bodies, skin tones and cameras.")
            if readingNotice != nil {
                paragraph("Opening Rules stops local acquisition, not the service clock. Reading is not an exit. Return through the match host; any permitted camera resume must be explicit and does not reset a deadline.")
            }
        }
    }

    private var readingNotice: String? {
        switch store.stage {
        case .ready: return "Camera stopped · Return to the ready room to continue"
        case .countdown: return "Start countdown continues · Camera stopped"
        case .capture, .submitting, .judging: return "Clock continues · Camera stopped"
        default: return nil
        }
    }

    private var orientation: some View {
        PhysiqueCard {
            Text("Three poses. One rubric.")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            paragraph("Three stills · 90 seconds total · Up to 2 retakes per pose.")
            PhysiqueAction(title: "Open pose guide", systemImage: "figure.stand") { onOpen(.guide) }
            paragraph("Front double biceps, side physique and rear double biceps. Each player supplies one selected still of each pose from the same live capture. The paired comparison uses six accepted stills, not a live stranger stream.")
        }
    }

    private var rubric: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            heading(.rubric)
            PhysiqueCard {
                rubricRow(.muscularity, expanded: $muscularityExpanded)
                Divider()
                rubricRow(.definition, expanded: $definitionExpanded)
                Divider()
                rubricRow(.symmetry, expanded: $symmetryExpanded)
                Divider()
                rubricRow(.presentation, expanded: $presentationExpanded)
            }
            paragraph("Category scores are subjective whole-number points from 0 to 100, not measurements of muscle mass, body-fat percentage, health, strength, attractiveness or human worth. They are not confidence percentages, probabilities, ideal-body percentages or population percentiles.")
            paragraph("A weight is a share of the weighted total, not a player's score. The total is also out of 100 and is shown to one decimal place. It is muscularity × 0.40 + definition × 0.30 + symmetry and balance × 0.20 + pose presentation × 0.10. Separate rounding or hidden model precision must not change the winner boundary.")
            paragraph("Physique Elo is the separate service-owned competitive rating. Category points and total points are not Elo. A larger winning score gap does not multiply the rating award, and exercise ratings are not combined with Physique Elo.")
            paragraph("Both players may have high, low or identical points. Zero can describe an adequate valid low observation; unseen evidence has no score. One hundred is the top of this rubric, not a biologically perfect person. The optional bands are proposed calibration references, not population norms or body-change targets.")
        }
    }

    private func rubricRow(_ category: PhysiqueCategory, expanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                Image(systemName: symbol(for: category))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    if dynamicTypeSize.isAccessibilitySize {
                        categoryHeading(category, stacked: true)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            categoryHeading(category, stacked: false)
                            categoryHeading(category, stacked: true)
                        }
                    }
                    paragraph(summary(for: category))
                }
            }
            DisclosureGroup(isExpanded: expanded) {
                categoryDetails(category)
                    .padding(.top, ProfileStyle.spacing)
            } label: {
                Text("\(title(for: category)) examples and scoring anchors")
                    .font(TimeMasterFont.label())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: controlHeight, alignment: .leading)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: expanded.wrappedValue)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func categoryHeading(_ category: PhysiqueCategory, stacked: Bool) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: category)).font(TimeMasterFont.sectionTitle())
                weight(category)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                Text(title(for: category))
                    .font(TimeMasterFont.sectionTitle())
                    .fixedSize()
                Spacer(minLength: 0)
                weight(category).fixedSize()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private func weight(_ category: PhysiqueCategory) -> some View {
        Text("\(category.weight)% weight")
            .font(TimeMasterFont.label().monospacedDigit())
            .accessibilityLabel("\(category.weight) percent of the weighted total")
    }

    private func title(for category: PhysiqueCategory) -> String {
        category == .symmetry ? "Symmetry and balance" : category.title
    }

    private func symbol(for category: PhysiqueCategory) -> String {
        switch category {
        case .muscularity: return "figure.strengthtraining.traditional"
        case .definition: return "circle.lefthalf.filled"
        case .symmetry: return "arrow.left.and.right"
        case .presentation: return "figure.stand"
        }
    }

    private func summary(for category: PhysiqueCategory) -> String {
        switch category {
        case .muscularity:
            return "Visible muscular contours across shared shoulders, upper arms, upper back, thighs and calves, relative to the visible frame. Not actual muscle mass, pixel size, height, body weight, strength or training claims."
        case .definition:
            return "Supported muscle separation in directly usable upper-arm and calf evidence, not body-fat percentage. Fabric seams, folds, lighting-created edges, oil, sweat, tanning, vascularity as a goal and dehydration earn no points."
        case .symmetry:
            return "Observed left-right and upper-lower muscular balance across front and rear evidence. Not a sex-specific silhouette, skeletal or waist-to-hip ideal, breast or facial symmetry, or diagnosis of a physical difference."
        case .presentation:
            return "Safe, recognizable poses that clearly present required regions above the evidence minimum. Not seductiveness, facial expression, clothing price, theatricality, unsafe strain, pose duration or professional camera production."
        }
    }

    private func categoryDetails(_ category: PhysiqueCategory) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            switch category {
            case .muscularity:
                paragraph("A shoulder or upper-back contour genuinely visible through an opaque top is a contour, not a view of hidden anatomy. Consider the same required regions across all three poses.")
                band("0–24", "Little distinct muscular contour is visible in the required regions despite adequate evidence.")
                band("25–49", "Some muscular contour is visible, but development is limited or uneven across the common regions.")
                band("50–74", "Clearly developed muscular contours are visible across much of the required evidence.")
                band("75–89", "Pronounced muscular contours are consistently supported across the required regions.")
                band("90–100", "Exceptional apparent development across the required regions relative to the calibrated reference set.")
            case .definition:
                paragraph("Adequate visibility with little separation supports a low observation. An obscured upper arm or calf cannot support one. Additional exposed chest, abdomen or back detail is not extra definition evidence.")
                band("0–24", "Little stable muscle separation is visible in the required surface regions despite adequate evidence.")
                band("25–49", "Some supported separation is present, but it is limited or inconsistent across the required regions.")
                band("50–74", "Clear separation is visible across much of the required surface evidence.")
                band("75–89", "Pronounced separation is consistently supported across the required surface regions.")
                band("90–100", "Exceptional visible separation across the required surface regions relative to the calibrated reference set.")
            case .symmetry:
                paragraph("Front and rear stills must support the relevant bilateral contours. One favorable side pose alone cannot establish symmetry, and no stereotyped body shape is required.")
                band("0–24", "Pronounced observable imbalance across the required comparable muscular contours.")
                band("25–49", "Several clear imbalances are visible, alongside some balanced regions.")
                band("50–74", "The required regions are generally balanced, with identifiable but limited differences.")
                band("75–89", "The required muscular contours show strong bilateral and upper-lower balance.")
                band("90–100", "Exceptional observed muscular balance across the required evidence, without requiring a stereotyped body shape.")
            case .presentation:
                paragraph("Clear alignment and consistent placement count only after the required evidence is adequate. A still cannot establish endurance or exercise performance, and presentation points cannot repair an invalid pose.")
                band("0–24", "The poses remain recognizable and adequate, but positioning is inconsistent and only minimally presents the required regions.")
                band("25–49", "The required poses are achieved, with repeated alignment or placement limitations that remain above the evidence floor.")
                band("50–74", "Clear, safe positioning consistently presents most required regions, with minor pose-alignment limitations.")
                band("75–89", "The three poses are consistently aligned and clearly present the required regions without unsafe strain.")
                band("90–100", "Exceptionally clear and consistent execution of the prescribed safe presentation, not theatricality or greater exposure.")
            }
        }
    }

    private func band(_ range: String, _ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(range) points").font(TimeMasterFont.label().monospacedDigit())
            paragraph(explanation)
        }
    }

    private var evidence: some View {
        PhysiqueCard {
            heading(.evidence)
            paragraph("Same regions, both players: shoulders, upper arms, upper-back contours and legs. Chest and abdominal appearance or definition do not count for either player, even when visible. Definition needs directly usable upper-arm and calf surface evidence; a back contour does not reveal muscle separation beneath a top, and exposed back detail gives no extra Definition points.")
            paragraph("More exposed skin earns no bonus. Permitted clothing earns no deduction. Breast, nipple and areola appearance, groin, genital and buttock anatomy, facial attractiveness, skin color, tattoos and clothing cost are not scoring criteria.")
            paragraph("Fabric is not muscle separation. Hidden anatomy is not inferred, scored as zero, replaced with another region or dropped from one player's weights. The fixed weights are never renormalized to rescue inadequate evidence. Insufficient comparable evidence is a private no-contest explanation, not a physique loss.")
            paragraph("Capture quality is an evidence gate, not a fifth category. Cropping, blur, distortion or unusable lighting can require a safe retake; an expensive camera, studio lighting or higher resolution earns no bonus. Adequate evidence with little separation is different from evidence that cannot show separation.")
            paragraph("A physical difference or mobility limitation is not a penalty, diagnosis or disability score. Safe pose adaptations are allowed only when they preserve the same required comparison evidence. Otherwise the service explains insufficiency privately; it does not manufacture a loss or require unsafe strain.")
        }
    }

    private var attire: some View {
        PhysiqueCard {
            heading(.attire)
            paragraph("Adults only: 18 or older, and any stricter applicable local requirement. A privately declared adult man may pose shirtless in a nonsexual fitness context or wear an opaque athletic top. Other participants wear an opaque athletic top or sports bra. Everyone covers the groin and buttocks with opaque sports clothing throughout every pose.")
            paragraph("More skin is not more points. A permitted sports bra or ordinary nonsexual male torso is not automatically a violation. Sheer clothing, prohibited exposure, sexualized presentation, fetish-focused framing or a wardrobe malfunction are not allowed. Rear poses do not relax coverage.")
            paragraph("Adult eligibility and the adult-man attire exception are separate private declarations, not public badges or verified identity. Age, sex, gender, identity or medical facts must not be inferred from an image. Rules does not request ID, a face-verification image or a body image to prove a declaration.")
            paragraph("Only the consenting participant may appear. A bystander invalidates capture even with a masked face; helpers stay outside the frame. Library photographs, recordings, another person's body, synthetic substitutes, body reshaping and appearance filters are not rated evidence. Required face obscuring is permitted privacy protection.")
            paragraph("If permitted clothing hides required evidence, a safe allowed adjustment or recapture may help while time and retakes remain. Never remove required coverage, expose a protected region, tighten clothing over intimate anatomy or ignore pain to obtain points. A rejection can be questioned through Safety without sending an exposed original or proving gender through a body image; review does not promise reversal.")
        }
    }

    private var outcomes: some View {
        PhysiqueCard {
            heading(.outcomes)
            rule("Win or loss", "Both complete accepted pose sets must support all four categories. An absolute weighted-total gap of 3.0 points or more decides the winner. The service validates the scores and outcome; a model's prose cannot override the boundary.")
            rule("Draw", "A valid total gap below 3.0 points is a rated draw: 2.9 is a draw; exactly 3.0 is win/loss. A draw may change Physique Elo between unequal-rated opponents. It is not a refund, an uncertain judgement or a promise of unchanged rating.")
            rule("No contest", "No valid rated comparison and no Elo change. Insufficient evidence, safety or integrity invalidity, a refusal, missing categories, unsafe or contradictory judging, unavailable service or a missed judging deadline cannot become a guessed win, loss or draw. A consumed slot is restored once when the service confirms restoration. No-contests do not advance placement or the competitive streak.")
            rule("Before Go: Cancel", "Go is the service's start, not a local animation. Cancel before Go changes no Elo, costs no started-match allowance and releases the reservation. A late Cancel is not consent to forfeit: return to the started match or use its explicit confirmation.")
            rule("After Go: explicit Forfeit and leave", "An explicitly confirmed voluntary exit can record a rated loss and eligible opponent win only if the service establishes that the started match is otherwise eligible. There are no physique scores or claim of bodily superiority. The slot remains consumed. Independent safety, invalid-evidence or unavailable-service conditions take no-contest precedence.")
            paragraph("Reading, closing Rules, losing the camera, an involuntary interruption or force quitting is not a confirmed voluntary forfeit. Rules never cancels, finalizes, consumes a slot or presents a Forfeit button.")
            rule("Report and Block are not verdicts", "Before Go, Block cancels the pair without Elo change. After Go it shields relevant media and excludes future pairing; it does not itself leave, settle or rerate a match. Reporting does not guarantee a win, refund, no contest or finding against someone. An offline protection action and service acknowledgement remain different.")
            rule("Finality and review", "The current confirmed result remains effective until an authorized correction exists. Scoring review is not a new-model reroll. Subjective disagreement or image expiry does not automatically invalidate a result. A late response, reconnect or repeated request cannot revive a finalized no contest, add another rating event or charge another slot.")
            paragraph("Scoring review is available from the relevant match details, not as a targetless request from Rules.")
        }
    }

    private var timing: some View {
        PhysiqueCard {
            heading(.timing)
            rule("Search and start", "Search lasts at most 90 seconds. Both players explicitly become Ready before the service's shared 3-second start countdown.")
            rule("Capture and retakes", "One shared 90-second capture period contains all three poses and up to 2 retakes per pose. Retakes do not reset or extend capture time.")
            rule("Interruption", "Camera loss, backgrounding or an involuntary interruption stops acquisition immediately. Reconnect grace is at most 20 seconds, within the original deadlines. Restore the same match, not a new allowance charge or reset retake count. If valid participation cannot resume, the service applies no contest rather than a physique loss for absence.")
            rule("Judging", "The proposed hard judging deadline is 30 seconds after both final pose sets are received. Five seconds is only an unmeasured experience target, not a provider guarantee or finish countdown. No valid judgement by the deadline means no contest. Already accepted complete sets may finish while the client is away.")
            paragraph("Authoritative stage and deadlines come from the service. Returning fetches the same state. Reading does not pause timing, and reopening does not restart judging or authorize a camera resume.")
        }
    }

    private var privacy: some View {
        PhysiqueCard {
            heading(.privacy)
            paragraph("Before any transfer, the applicable policy must identify the operator, judging and moderation recipients, their permitted purposes, processing regions and actual retention. Necessary face-obscured stills may be used for safe intake, the paired judgement and narrowly scoped authorized case review only under the separate applicable choices.")
            policyField("Operator", value: policy?.operatorName)
            policyField("Processor information supplied by the service", value: policy?.processor)
            policyField("Processing region information", value: policy?.region)
            policyField("Actual service retention terms", value: policy?.retention)
            if !configured {
                paragraph("Sharing information unavailable or service not ready. Proposed app limits below are not missing processor terms, consent or permission to upload. Refresh the policy and review Privacy and sharing before participation.")
            }
            rule("Local preview and protected transfers", "Live preview stays local. Every transmitted candidate and selected still must first be face-obscured on-device, with the exact protected capture available to inspect. Failed redaction fails closed; an unmasked original is never a fallback. No microphone, live stranger video, early opponent stills, rated library-photo substitute or automatic public profile-photo upload is authorized.")
            paragraph("Face masking does not guarantee anonymity: bodies, tattoos, clothing, backgrounds and paired public identity may remain recognizable. Judge evidence is clean redacted imagery, not a screenshot of the interface. Handles, country or region, badges, Elo, tier, account history and private eligibility or attire declarations are not judging inputs.")
            rule("Intentional opponent viewing", "Only a valid judged win, loss or draw can offer View poses, after moderation, prior consent and a fresh check of each image owner's current permission. No forfeit or no-contest gallery is available. Results never automatically open images. Hide and Report do not require enlargement. Expiry, withdrawal, blocking or removal cannot be bypassed by a stale link or reopening Rules.")
            rule("Media expiry and copying", "Under the app's proposed ordinary limit, media expires no later than 24 hours after finalization. Someone who sees an image may copy or record it. The app cannot guarantee screenshot prevention or recall an external copy.")
            rule("Necessary evidence holds", "A received report or dispute may preserve only necessary lawful evidence for up to 30 days from original receipt. Duplicates and appeals do not restart that ordinary hold; unreceived drafts do not preserve media. A report hold is never continued gallery permission. Legal or urgent-safety exceptions can differ, and unlawful or suspected exploitative content follows restricted handling rather than an ordinary report attachment.")
            paragraph("The app's 24-hour media window is not universal deletion everywhere. Actual processor logs, saved responses, state, caches, any moderation recipients and their purposes must be disclosed in the service terms. Do not assume Zero Data Retention, no authorized human review, a secured processing region, model-training exclusion or any other provider arrangement that the policy has not established.")
            rule("Separate choices", "Adult eligibility, the adult-man attire declaration, rules acceptance, camera permission, hosted-AI and safety processing, and paired-opponent image access are separate decisions. Processing and opponent sharing are separately affirmative and not preselected. Reading, scrolling, expanding details or closing Rules accepts none of them. Declining prevents this rated mode, not unrelated Tmax use.")
            rule("Withdrawal before Go", "Withdrawing required sharing stops further transfers and cancels preparation or pairing without Elo loss; the reservation is released. The owning Privacy and sharing flow records the request and its actual acknowledgement.")
            rule("Processing withdrawal after Go", "New capture and transfers stop immediately. Processing already accepted by a recipient may not be retractable. Intentional departure still follows the eligible explicit-forfeit rule and independent no-contest precedence; withdrawal is not a free win or a requirement to keep posing while seeking help.")
            rule("Opponent-access withdrawal after Go", "Withdrawing only counterpart-image access removes future authorized viewing, including access through existing links. It is not itself a forfeit, cancellation or rating reversal. Otherwise authorized processing can continue, and each gallery still requires current owner permission.")
            rule("After finalization", "Image removal or withdrawal does not reroll a score, reverse a valid result or erase earned Elo. Ordinary app-controlled media is removed subject to a valid hold, but external copies cannot be recalled. Media removal and account deletion remain available in Privacy and sharing; sign-out is not a deletion receipt.")
        }
    }

    private var destinations: some View {
        PhysiqueCard {
            Text("Continue deliberately")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            PhysiqueAction(title: "Privacy and sharing", systemImage: "hand.raised") { onOpen(.privacy) }
            PhysiqueAction(title: "Safety and support", systemImage: "shield") { onOpen(.safety) }
            PhysiqueAction(title: "Match history and review", systemImage: "clock.arrow.circlepath") { onOpen(.history) }
            paragraph("These routes open their existing owners. They do not accept rules, submit a report, withdraw consent, remove media or request a scoring review on your behalf.")
        }
    }

    private func heading(_ section: ReadingSection) -> some View {
        Text(section.rawValue)
            .font(TimeMasterFont.heading())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusedSection, equals: section)
            .id(section)
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            paragraph(detail)
        }
    }

    private func policyField(_ title: String, value: String?) -> some View {
        rule(title, supplied(value) ?? "Not supplied by the service.")
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func supplied(_ value: String?) -> String? {
        guard let value, value.unicodeScalars.contains(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) else { return nil }
        return value
    }

    @MainActor
    private func refreshPolicy() async {
        guard !refreshingPolicy else { return }
        refreshingPolicy = true
        defer { refreshingPolicy = false }
        await store.loadPolicy()
        guard !Task.isCancelled else { return }
        policyLoadError = store.error
        if policyLoadError == nil, let policy = store.policy {
            policyRefreshedAt = Date()
            refreshedPolicyVersion = policy.version
        }
    }
}
