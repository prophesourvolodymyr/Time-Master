# F29-A-u — Private Case Detail and Decisions

## Purpose and Ownership

Case detail is the signed-in person's private account of one report, scoring dispute, restriction notice, or appeal. It answers three questions in order: what is actually happening, whether the person needs to act, and what the decision changes for them. It is not a public allegation, a second body-comparison screen, or a moderation control panel.

This child owns the case-detail composition, inline safe additional-information response, decision readability, and original-versus-corrected result context. The [case center](../F29-A-t-case-center/DOCKS.md) owns list and selection hosting. [Review composer](../F29-A-v-review-composer/DOCKS.md) alone owns new safety appeals and outcome disputes; this detail routes there rather than creating a competing appeal editor. F29-D owns review authority, F29-C owns correction settlement, and F29-E owns access and lifetime.

This is documentation for future native iPhone and macOS work. It does not authorize implementation, claim that case services exist, record human acceptance, or establish measured response times. The UI-worker model is not the in-app judge. Implementation work and human-review status belong only in CYCLES.md.

## Chosen Composition and Tradeoffs

Use a compact sports dossier rather than a miniature rematch, chat conversation, or multistep progress tracker. The first elevated surface contains a small case-type symbol, a large actual state such as In review, one concise next-step sentence, and the time of the last confirmed update. A fine orange edge identifies the current information; it is not an achievement badge or a finding of guilt. Inter Black establishes the status hierarchy, Inter Regular carries the explanation, and the existing near-black and dark surfaces preserve the rest of Tmax's visual language.

Below that surface, show Latest decision when there is a decision, Your rating when there is a competitive consequence, and a short Updates section. Evidence and case facts are a labeled disclosure on iPhone and can occupy an optional native inspector on Mac. The newest meaningful update is readable without expanding a history of receipts. There is no imagined Received–Reviewed–Resolved path with empty future steps. A case can return to review, close without a conclusive finding, or have a revised decision while a correction is still settling.

Use one prominent action only when an actual service-authorized action is needed or available: Respond, Appeal decision, or Request scoring review, as appropriate to this person's role and case type. When nothing is needed, say No action needed now and omit a decorative filled button. Match details, Contact support, Copy case reference, and a permitted Withdraw request are secondary actions. No section invites contact with the opponent.

The tradeoff is deliberate: a private review view has less athlete imagery and celebration than the battle stage. This prevents an allegation from becoming another body-viewing opportunity and gives the decision and next step room to breathe. Tactility comes from shared press feedback, a brief real-state transition, and a single update marker, not queue animation or animated punishment. Metadata-first evidence adds one disclosure for people who need the detail, while keeping retention and important consequences visible at the relevant action.

## Visual Language and Concise Copy

Reuse the existing background 0A0A0A, elevated surfaces 141414 and 1C1C1C, white primary text, readable secondary text, and FF6A00 action accent. Reuse Theme, ProfileStyle, TimeMasterFont, shared card surfaces, and native controls. Do not establish a parallel safety palette or force glass behind confidential text. Materials are optional navigation chrome with the existing availability and Reduce Transparency behavior, not evidence surfaces.

Use existing spacing relationships: a normal content inset, compact gaps within a fact group, a larger separation between decision and supporting sections, and the shared readable-column constraint. Layout responds to measured content and available geometry rather than fixed screen positions. Case references use a compact monospaced treatment where helpful; state text grows with the supported text size. Long references wrap or have an explicit copy action rather than horizontal scrolling or tiny type.

The navigation title is Case status. The status surface uses the service's actual participant-safe state label. Suggested short next-step copy includes No action needed now, A safe text response is needed, Review could not reach a conclusion, Original decision upheld, and Rating updating after review. Use each only when it accurately describes the current record. A report receipt says Received, not A moderator is reviewing. A confirmed action says Action taken, not Opponent banned. A rating dispute never labels subjective disagreement as an exposure violation.

Keep the latest safe reason and important consequence readable, not buried beneath a generic Details control. Secondary explanations, the person's own submitted safe text, policy context, earlier decisions, and older updates can expand progressively. No arbitrary word budget may remove a response deadline, restriction scope, retention warning, correction label, or recovery instruction.

## Entry, Identity, and Navigation

Enter from the existing private case center, a real service-confirmed report receipt, the person's own restriction notice, an authorized match-detail case link, or a generic notification that resolves after sign-in. Opening an identifier is never proof that the viewer owns the case. Resolve current account authorization before exposing the case title, message, target, rating details, or cached content.

Preserve the originating case-list position or match-detail position. Back or Close case leaves the request unchanged. Closing is not withdrawal, acceptance of a decision, abandonment of an appeal, or a competitive exit. A copied case reference contains only that reference; it is not a body image, allegation, correspondence export, share card, or authorization token. The copy action gives a brief accessible Copied acknowledgement without a blocking alert.

A case is labeled by its type, safe match date when relevant, and its own reference. Use You and Opponent where sufficient. A blocked, deleted, or no-longer-visible account uses the appropriate neutral label and has no active profile link. Do not recover a hidden identity from an old case message, accessibility label, receipt, or copy operation. Account and content cases need not invent a match or two participants.

## iPhone Composition

Use the existing native navigation stack for a normal case-center or saved-result entry. The navigation bar provides Back and the Case status title; a labeled secondary menu contains Copy case reference, Contact support, and a real permitted Withdraw request. A report opened during an active match uses the existing native safety presentation with Close case rather than opening a second navigation universe.

The scrollable content order is the status surface, the state-specific action and its consequence text when present, Latest decision, Your rating when relevant, Updates, and the Case facts and evidence disclosure. Supporting sections are not a grid of equal-weight cards. The status and newest decision lead; older events are quieter rows. The case reference and case type remain accessible without repeated headings at every section.

A safe additional-information response expands inline beside the actual request, with Your response as its persistent label, the real text limit, safe-content guidance, and keyboard-reachable Cancel and Send response. A new safety appeal or outcome dispute instead opens the canonical F29-A-v composer with the exact decision or match context. This detail never provides a second appeal form. Passive cases have no empty editor footer.

Short screens, landscape, long localized labels, and large accessibility text scroll vertically. No type-size clamp, fixed-height decision card, truncated restriction duration, badge-sized response deadline, or mandatory horizontal table is acceptable. Primary and safety controls retain the existing forty-four-point iPhone interaction convention. Cancellation and secondary actions remain separate enough to avoid accidental withdrawal.

## Native macOS Composition

This is native macOS 14 or later, not Catalyst, a web panel, or an iPhone sheet stretched to fill the window. Preserve Tmax's normal title bar and existing minimum window size of 800 by 600. Use the app's existing detail navigation; do not create a separate case window manager, replace another owner's case list, or increase the app-wide minimum.

At the existing minimum and in short laptop windows, show the status and decision in one readable central column. Case facts and evidence remain an in-column disclosure. A native toolbar carries Back or Close case according to the host, the Case status title, Refresh with an accessible text label, and secondary support/reference actions. The current response or appeal action remains visible in the detail action region without turning every row into a large mobile button. If the editor is taller than the viewport, its content scrolls while Cancel and Send remain reachable.

On larger windows, full screen, and external displays, keep the main dossier readable rather than expanding sentences across the entire screen. An optional native trailing inspector can show the same Case facts and evidence, including dates, evidence availability, and retention information. It is supplementary, not a second participant column. Open it through a named Details control, retain the user's disclosure choice within this navigation context, and move the same information back into the main column when it cannot fit comfortably. There is only one logical copy and one accessibility reading of those facts.

During live resize, preserve the selected case, editor text, insertion point, focused control, disclosure state, and reading position. Do not animate between inspector and inline geometry while the person resizes. Do not squeeze response copy or safe actions into clipped toolbar symbols. Native scrolling, pointer targeting, contextual text selection, keyboard navigation, and visible focus remain available at laptop and large-display sizes. Important explanations are never hover-only.

Case detail requires no camera. TCC denial, a missing camera, or external or Continuity Camera disconnection must not prevent reading a decision, sending safe text, copying a reference, or appealing. No camera permission prompt, live preview, Photos picker, microphone request, or rated file-upload substitute belongs here. If an originating active match loses its camera, that match's owner stops acquisition, shields the preview, and presents its actual recovery state; the case is not changed into a capture-retry screen.

## Active-Match Context and the Battle Composition Invariant

Case detail normally contains no battle composition, no body imagery, and no timer. Do not manufacture a countdown from queue age, a seven-day operating target, an indefinite restriction, or a finished match. A real response deadline is displayed as a dated fact, not as a sports countdown.

When the case is inspected from an in-progress match, the host retains a compact, reachable top anchor with the real match stage and authoritative time remaining, plus Return to match and the actual state-aware Exit. Those controls belong to the existing match shell, not a second timer or local match owner. The case's review state cannot pause the match clock or restart reconnect grace. No case action reserves a match, starts capture, submits poses, charges an allowance, or forfeits.

If any shared battle stage remains visible behind or beside the case presentation, its composition is unchanged: the real timer is the top visual anchor, followed by complete owner-grouped public identity and badge rails, followed by two LARGE vertically stacked participant panels, You above Opponent. This order applies on wide Mac windows as well as iPhone. All public badges wrap above the player panels; there is no three-slot cap, hidden +N, ticker, overlay on a body, or hover-only badge explanation. Short windows scroll the stage instead of shrinking participants. A case inspector may sit beside that stage; the players may not sit side by side. Do not duplicate the shared rails inside the private dossier or promote a report status into a public badge.

Any authorized image in a separately entered match viewer remains aspect-fit, consistently framed, and subject to current permissions. Case detail itself never opens that viewer automatically. Country is only the optional self-declared public country or region, with a neutral unsupported or missing state; there is no location inference. Badge, country, rating, and case chrome never enters judge image content or judging context.

## Actual Case States and Next Steps

The visible record separates request state, review state, decision, appeal state, and competitive settlement when more than one is present. They are not forced into a single linear progress value. In particular, a withdrawn request may still require safety handling, and a closed review may still have an eligible appeal or a pending rating adjustment. Use only service-confirmed combinations and explain the distinction in short text.

| Actual state | Visible treatment | Actions and recovery |
| --- | --- | --- |
| Resolving identity or loading an authorized case | Case status heading and ordinary native activity feedback; no last account's content and no assumed Received state | Back or Close case remains available; resolve authentication before private data |
| Received | Received, the confirmed receipt time, and a statement that receipt is not human review | No action needed now when true; permitted extra safe context or withdrawal stays secondary |
| Queued | Queued and the latest confirmed update | No queue position, moving progress bar, or invented wait estimate; read the actual response expectation and use published contact access |
| In review | In review, the latest actual update, and whether anything is needed | Do not claim a named reviewer or independent human review unless the service actually confirms it; no model-derived completion percentage |
| More safe information requested | The exact participant-safe question, why that information is needed when provided, and any genuine response deadline with its time zone | Respond opens the inline safe-text editor; no requirement to expose the body, prove a declaration through appearance, contact the opponent, or attach an image |
| Response being sent | Sending response beside the existing request; entered text stays readable | Disable only duplicate mutation; retain Cancel or close/navigation according to whether a meaningful unsent draft exists; do not show Received before acknowledgement |
| Response unsent or acknowledgement uncertain | Not sent when failure is known, or Not confirmed when receipt is unknown | Preserve the permitted text-only draft; Check status or explicit Retry resolves the same request without duplicate apparent correspondence |
| Response accepted | Response received with its real time and the latest actual case state | Collapse the editor without deleting confirmed correspondence; no automatic claim that review resumed or evidence was held |
| Action taken, reporter perspective | A participant-safe decision summary and any content-access consequence the reporter is permitted to know | Match details or support as appropriate; never reveal the opponent's sanction, duration, private declarations, or full case record |
| Decision affecting this account | The person's own rule category, affected capability, safe reason, actual duration or review condition, and current status | Appeal decision only if genuinely available; state which restrictions remain effective during review |
| No violation found | The safe decision and limited reason supplied for this concern | Do not label the reporter dishonest, infer the other person's eligibility, or treat the finding as permission to reopen quarantined imagery |
| Scoring decision upheld | Original outcome upheld, the safe review reason, and the still-effective competitive record | No reroll, manual score editing, free win, or automatic rating refund |
| Inconclusive | Inconclusive and the specific safe limitation, such as original images no longer being available | Show what remains effective and the supported next step; absence of evidence is not proof of guilt, innocence, or an invalid original match |
| Withdrawal requested | Withdrawing request until acknowledged; the last confirmed case state remains labeled | Do not remove the case or claim the report was erased; safe navigation remains possible |
| Withdrawn | Your request was withdrawn with the confirmed time; separately show continued safety handling when the service reports it | Hide and block choices remain unchanged; withdrawal does not promise deletion, end a legal hold, restore media, or cancel a restriction |
| Closed | Closed with the actual closure date, plus the latest decision or inconclusive reason | Closed alone is not a result explanation or a declaration that appeal access has ended; expose only actually available next steps |
| Appeal received or queued | Appeal received or Appeal queued with its own actual acknowledgement, linked to the original case | The original decision remains readable; no implication that an active restriction or competitive result is suspended |
| Appeal in review | Appeal in review with the real latest update and any safe information request | Same response and contact behavior; no claim of independent human review from a repeated automated check |
| Appeal upheld | Original decision upheld with the safe appeal reason and effective consequence | Explain actual further access, if any; do not invent another appeal round or a countdown |
| Appeal revised | Decision revised with the old and new own consequences, actual effective time, and any distinct competitive correction state | A revised safety decision alone does not invent a scored win or restore expired images |
| Appeal closed without a revised finding | Actual reason, which decision remains effective, and any permitted contact route | Do not silently map this state to Upheld, withdrawal, or misconduct |
| Correction authorized but settling | Rating updating after review; the labeled last confirmed competitive snapshot remains readable | No predicted new rating, mixed old and new summaries, or new rated seed until the service settles the correction |
| Correction settled | Reviewed outcome, separately identified adjustment, actual new settled values, and correction date | Reopening shows settled facts rather than replaying an award; subsequent refreshes cannot apply the correction again |
| Status stale, offline, or temporarily unavailable | Last confirmed state and explicit last-updated time, or Unable to load case when none is available | Retry or Check status and published support; never substitute a cached state as current or turn a fetch error into Closed |
| Signed out, account changed, unauthorized, deleted, or no longer retained | Private content clears; a neutral sign-in or unavailable-case explanation replaces it | Return safely, use the normal account flow or public support; do not reveal whether another account owns the reference |

A newer revision can arrive while the person is reading or editing. Keep the editor text and scroll position. Announce a meaningful state change once without repeatedly stealing focus. If the requested action is no longer valid, say This request changed, keep the unsent text available to the same account within its allowed lifetime, and show the actual supported action after refreshing. Do not silently submit that text to a different question or a newly created appeal.

## Decisions, Appeals, Withdrawal, and Text Responses

### Safe response

The response section shows the current question above the text field and identifies the recipient as the operator's case-review team, not the opponent. The person's report or appeal text is not forwarded as a direct message. There is no attachment control, photo evidence request, camera activation, or share-to-opponent action.

Use the service's actual permitted text length and validate without erasing useful input. A missing required response has a field-specific error. If the operator's request cannot be answered without unsafe images or inappropriate private disclosure, provide Contact support with the case reference and allow a safe text explanation; the UI must not instruct the person to satisfy an unsafe evidence request. A response deadline, if one exists, includes its actual date, time zone, and disclosed consequence. If it has passed, refresh the real permission to respond instead of assuming the case is closed or extending the deadline locally.

Sending never invents human attention. A successful acknowledgement records one response on the existing case. Lost acknowledgement is reconciled with the same pending operation. Offline text is not a report receipt, an evidence hold, or an extension of the original media window. A protected text-only draft can exist on this account's current device for no more than twenty-four hours, and ends earlier on discard or sign-out. It does not silently roam to another account or survive account deletion. Do not promise cross-device draft synchronization unless the reviewed shared foundation actually supplies it.

### Appeal and scoring review

Offer an appeal only to the person and decision for which the service grants that right. A reporter does not receive an Appeal opponent's sanction action. An affected participant can appeal their own capture rejection, removal, or restriction. A participant can request scoring review for their own saved match, including an actual forfeit or no-contest, without alleging nudity or misconduct.

Label the route according to its question. Appeal decision challenges the person's safety decision. Request scoring review challenges evidence handling, accepted arithmetic, participant identity mapping, finalization, or another competitive decision. Subjective disagreement can be stated respectfully but does not entitle anyone to another model draw or reviewer-invented category scores. Use the real eligibility window and reason if an appeal is unavailable; do not invent a universal deadline or a second level of appeal. Support contact is not falsely labeled a filed appeal.

Appeal decision and Request scoring review open the canonical [F29-A-v Review composer](../F29-A-v-review-composer/DOCKS.md), with the original authorized target, correct mode, and current eligibility. That owner supplies reason selection, recipient/retention disclosure, draft protection and real submission receipts. Returning preserves this case and reading position; an acknowledged linked appeal appears only from service-owned state. This detail supplies no inline appeal editor or invented appeal identifier.

The existing decision remains effective while an appeal is pending unless an authorized service event actually changes it. A successful clothing false-positive appeal may remove an unjustified restriction; it does not resurrect an expired gallery, fabricate scores from an aborted match, or imply that more skin should have been shown. An appeal does not reset any evidence retention clock.

### Withdrawal and closing

Withdraw request is secondary and appears only when authorized. Its native confirmation explains that the request will no longer be pursued by the person, while received safety information or a lawful hold may still require handling. The choices are Withdraw request and Keep request; do not use a generic destructive Delete that suggests erasure. The state changes only after acknowledgement. If a decision arrives before confirmation, refresh and show the real remaining permission rather than overwriting that decision with a local Withdrawn label.

Closing a sent case requires no warning about losing the report. Closing with meaningful unsent response or appeal text offers the bounded same-device draft or discard behavior supported by the shared foundation. An empty editor closes without ceremony. Closing or withdrawing never reverses a block or immediately displays a previously hidden still.

## Original Result, Effective Result, and Current Rating

The Your rating section exists only when this case actually concerns a competitive result. It leads with the effective reviewed outcome or the last confirmed outcome while settlement is pending. Do not replace an original settled result with speculative appeal success. A safety finding without a competitive correction says No rating correction when that is confirmed; it does not imply a win or point award.

Keep the following meanings separate and visible in labeled vertical groups:

- Original match: the original outcome, match time, judging-version context, and this person's original Physique Elo before, signed match change, and after. These are historical settled values, not today's rating.
- Review decision: the original and effective outcome, safe correction reason, correction reference and date, and the reviewed match's effective rating consequence when supplied. The original remains distinguishable instead of being silently overwritten.
- Adjustment applied: the actual signed correction applied later to this person's then-current confirmed rating, with the confirmed rating immediately before and after that adjustment and its settlement time. If rating bounds limit the adjustment, explain the actual settled amount rather than promising an unbounded reversal.
- Current Physique record: the latest coherent account snapshot and its time, including rating, placement or tier, relevant record contribution, and allowance consequence as supplied. A rating earned in later matches is not relabeled as the original match's After value. If more matches happened after the adjustment, today's rating and the rating immediately after adjustment remain different labeled facts.

No local arithmetic reconstructs an entire alternative league history. Later valid matches keep their original evidence, outcomes, rating inputs, settled effects, and judging versions. The service handles the bounded reviewed-match adjustment and revises this person's effective record, streak, peak, placement, tier, and allowance coherently. A correction can remove placement and return the account to provisional or unplaced status; there is no entitlement to retain a misleading Placed badge. Public badge changes use the shared trusted badge owner, not a locally inferred punishment or achievement.

Do not expose the opponent's current rating transaction, correction amount, private record, appeal contents, or sanction. The paired match's already-permitted historical rating context is not a license to disclose their account ledger. A corrected no-contest has no invented category scores, draw medal, or new gallery. Invalidated original scores, where still authorized in historical detail, are explicitly historical and no longer effective.

While the service settles a correction, retain the last coherent confirmed values with Rating updating after review. A revised decision can be readable separately from a not-yet-settled adjustment. Do not combine a new current outcome with an unlabeled old rating summary, assume zero adjustment on failure, or enable a new rated match from an unsettled seed. A refresh failure keeps this state and offers recovery. Once settled, case, match detail, account summary, and record refer to the same authoritative revision. Case detail reads the correction; it never awards or reapplies it.

## Safe Evidence Metadata, Not a Gallery

Case facts and evidence is text and symbols only. It can show the case type and reference, originating match reference and date when applicable, a safe item label such as Opponent side pose, what existing lawful evidence the service actually received or retained, current availability to authorized reviewers, and the actual retention information the participant may know. It never contains body thumbnails, blurred photo previews, unredacted originals, direct storage links, download buttons, internal reviewer notes, raw classifiers, model reasoning, or an opponent evidence package.

Distinguish Evidence reference received from Evidence retained for review. An acknowledged report does not prove that media was preserved. Distinguish ordinary participant gallery access from restricted reviewer access. Evidence may be lawfully held for review while unavailable to both participants, or unavailable for review because it had already expired. Opening this disclosure cannot fetch a still or turn a hidden image visible.

Ordinary pose media and derivatives expire no later than twenty-four hours after authoritative match finalization. A benign received report can retain only necessary existing lawful evidence for at most thirty days from the originating receipt, and for less time when unnecessary. Replies, appeals, duplicates, reopening the screen, and staff delays do not renew either clock. An unsent draft establishes no hold; a late report cannot recover deleted media. Case metadata and correspondence have their separate purpose-limited lifetime under F29-E, including the proposed routine maximum of ninety days after closure; the UI uses the actual authorized retention policy and does not promise that a case will be available forever.

Show the actual end date when it can be disclosed. If the service cannot provide an exact date or a legal-safety duty limits disclosure, say that retention information is limited and offer the published privacy contact. Do not invent a deletion countdown or label an unavailable date as indefinite ordinary retention. A specific lawful hold is not a reason to leave a participant gallery open or hold unrelated account data.

Suspected exploitation, unlawful intimate imagery, or urgent legal-safety material uses the operator's restricted handling. No response, appeal, contact instruction, or keyboard action asks the person to download, forward, screenshot, email, or upload that material. Text can identify the existing reference without redisplaying it. The app is not an emergency service; immediate-danger guidance points to appropriate local emergency or specialist help without promising rescue or continuous monitoring.

The optional Match details link opens the existing authorized nonmedia result detail. It does not auto-select View poses. Only a separately intentional action inside a still-valid judged win, loss, or draw may enter that viewer under current consent and safety rules. A forfeit, no-contest, block, report quarantine, expiry, removal, or sharing withdrawal cannot be bypassed through a case link. Hold metadata does not grant new media permission.

## Response Expectations, Updates, and Contact

The status surface shows the last confirmed update. A supporting Response expectation row uses the operator's actual published staffing hours, time zone, and current estimate, if available. Call it an expectation, not a guarantee. An automated receipt is not a substantive human response. Never convert F29-D's proposed staffed-hour or business-day targets into a client countdown or promise of continuous staffing.

If no estimate is available, say No response estimate available and keep published support accessible. If an estimate has passed without a new update, say Update delayed, preserve the last confirmed expectation with its date, and offer Check status or Contact support. Do not mark the case resolved, create a fake escalation, infer that a reviewer is absent, or silently revise the deadline. Response expectations never extend image retention or a real match deadline.

Updates contains only actual participant-safe events, with meaningful labels and dates: receipt, requested information, accepted response, review update, own decision, withdrawal acknowledgement, appeal event, or correction settlement. Do not include every network retry, an opponent's internal enforcement history, empty future steps, or a percent complete. Earlier decisions remain distinguishable beneath the latest decision. Loading more events preserves reading position and has a named action when needed. A partial event-load error keeps the current decision visible and retries only the missing portion.

Contact support uses the actual published operator channel and accurately indicates whether it opens another app. Copy the case reference only on an explicit action; do not silently put allegation text, images, personal declarations, or raw diagnostics on the clipboard or into an external message. If authenticated status is unavailable, public contact and urgent-safety guidance remain reachable without revealing the case to another account.

## Keyboard, Accessibility, and Focus

On entry, move accessibility focus to Case status and the actual state, not an animated icon or a list of unknown future steps. Reading order follows state, instruction, required action, latest decision, relevant rating facts, updates, and optional supporting facts. Make case type, state, and last-confirmed time understandable as text. Color, orange edges, icons, haptics, and animation are never the only information.

All actions are semantic named controls. Badge explanations in a visible host stage and evidence-retention facts have tap and keyboard access, not hover-only tooltips. Long reason text, localization expansion, right-to-left interface direction, VoiceOver, Voice Control, Switch Control, larger text, Increase Contrast, Differentiate Without Color, and Reduce Transparency preserve the same consequences and available actions. Do not generate intimate image descriptions for evidence that is not displayed.

When Respond or Appeal opens, focus moves to its heading and then follows normal traversal into the labeled field. A validation error is announced once and linked to the field; valid text remains. On success, focus goes to Response received or the actual appeal acknowledgement. When a stale request invalidates the editor, focus goes to the explanatory message, not a newly repurposed Send control. Dismissing a disclosure, sheet, or inspector returns focus to its invoking control or the nearest safe replacement.

On Mac and external iPhone keyboards, Tab and Shift-Tab follow visible semantic order and native keyboard-access settings. Return and Space activate only the focused semantic control; Return in the multiline field inserts a newline. Do not capture Return or Space globally and do not make Send, Withdraw, or Forfeit an accidental default while typing. Use native selection and contextual copying for permitted text. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O and do not hijack them for cases.

Escape first cancels the top native confirmation without mutation, then closes a transient disclosure or safely exits an editor as appropriate. A case sheet closes or a pushed case returns through its host; Escape never withdraws, submits an appeal, unblocks, reveals a photo, or forfeits. Cmd-W closes a passive case window normally. If the host owns a real active match, close and app-quit requests use that match's actual consequence confirmation where the platform permits. Force quit cannot be prevented or called a confirmed voluntary forfeit. Meaningful unsent text uses the bounded draft decision rather than a warning on every navigation.

A background status update does not repeatedly move focus away from reading or typing. Announce a changed information request, decision, or settled correction once. A settled correction announcement includes the actual final own signed adjustment and rating, not interpolated numbers. Reopening a historical case does not announce a new reward. No timer tick, refreshing spinner frame, or update marker is spoken repeatedly.

## Motion, Interruption, and Energy

Motion is scoped to actual actions and confirmed state changes. There is no ambient loop on this private surface; the sports identity comes from typography, hierarchy, and tactile response. A native activity indicator can communicate a real fetch or mutation but cannot masquerade as queue progress. Navigation and safe actions are available immediately, not after choreography.

| Trigger | Visible motion and timing | Interruption and alternative |
| --- | --- | --- |
| Press a semantic action | Existing shared press spring, response 0.24 and damping fraction 0.88 | Releasing or cancelling never sends twice; Reduce Motion removes added scale |
| Enter or leave case detail | Native platform navigation or sheet transition; no extra photo zoom or private-content shared element | Preserve source navigation and focus; follow the system's reduced-motion behavior |
| A newer actual state or decision is received | The state symbol and short status crossfade for about 180 milliseconds; one small edge marker settles with the new information | Latest confirmed state replaces an interrupted transition; do not queue stale states or delay the text and actions |
| A new real update becomes available while reading | A compact New update control appears with a roughly 160-millisecond opacity change | Do not auto-scroll away from the editor or reading location; opening it moves to the actual update and clears the marker |
| Expand case facts, earlier decisions, or safe correspondence | A restrained, nonbouncing continuity transition settles in about 280 milliseconds without moving the whole dossier | Reversal starts from the current presentation; focus and disclosure truth update immediately; Reduce Motion uses immediate layout with at most a 100-millisecond opacity change |
| Start or acknowledge a safe text mutation | Label and status icon change in about 160 milliseconds; only a real request has an activity indicator | Timeout or receipt uncertainty cancels the success presentation and shows the actual recovery; no artificial minimum wait |
| A correction settles while this case is visible | The labeled own adjustment and settled rating facts crossfade together for about 180 milliseconds | Final numbers are immediately accessible; no score roll, Elo counting, coin shower, or replay on history entry |
| Copy a reference | Copied replaces the action feedback briefly using about 140 milliseconds of opacity | Further copying is explicit; do not move focus or block another action |
| Authorization or media permission is revoked, account switches, or the app is protected | Confidential text and any host imagery are shielded or removed immediately | No fade through an unsafe frame and no wait for any animation |
| Window live resize, app restoration, or reduce-motion/energy setting change | Reflow and settle into the actual layout without decorative travel | Do not restart animations, remeasure fonts per frame, or replay old updates |

Reduce Motion removes scale, travel, and repeating symbol effects. It retains current text and exact final numbers immediately, with optional short opacity changes only. Reduce Transparency replaces material chrome with opaque readable shared surfaces. Optional acknowledgement haptics do not fire as celebration for a sanction and are never needed to understand a receipt or decision.

Pause decorative work and nonessential activity animation when offscreen, inactive, minimized, backgrounded, or under low-power or serious thermal constraints. Do not run per-frame network work, provider work, evidence decoding, global layout invalidation, font measurement, or polling driven by animation. Coalesce real updates into the latest authorized state. Real service deadlines continue while decorative work stops. Returning refreshes the same case and active match rather than restarting their clocks.

## Privacy, Window Lifecycle, and Multi-Device Recovery

Case text, restriction reasons, evidence references, and private rating adjustments are confidential. Shield them in app-switcher or restoration snapshots. On Mac, immediately shield the inactive or minimized sensitive surface according to the shared privacy lifecycle; do not confuse that local protection with deletion or withdrawal. On iPhone, app backgrounding and screen lock immediately apply the same protection. Return restores account authorization and current service state before removing the cover; it never auto-opens a gallery or camera.

A case can be read in a secondary window without acquiring the active-match camera lease. One account still has at most one active match and one camera owner across windows and devices. Reading cases, replying, refreshing, appealing, copying, resizing, or opening the inspector cannot start another session or charge another allowance. A restored case reference is not a restored authorization token.

Concurrent actions reconcile with current service permission and the same authoritative case. Two windows or devices cannot create apparent duplicate appeals, overwrite a later decision with a stale withdrawal, or apply a correction twice. If another device responds or a reviewer closes the request, refresh and explain the change while preserving any still-permitted local text draft. Unsynced hiding and blocking remain labeled pending until acknowledged elsewhere; case status never claims cross-device protection prematurely.

Sign-out, account switch, deletion, or authorization failure clears the prior account's private case surface and unsent sensitive drafts. Do not show a previous account's cached case while authentication restores. Ordinary network failure can retain only an authorized, labeled last-confirmed view permitted by the shared cache policy; it cannot preserve access after a known revocation. A case removed under retention or deletion uses a neutral unavailable explanation and published contact, not a broken link, recovered backup, or fake empty case.

## Dependencies and Review Boundaries

The real authenticated case read, participant-safe decision projection, safe-response acknowledgement, permitted withdrawal and appeal operations, published staffing/contact information, and bounded evidence handling must be implemented and human-reviewed before this surface is connected. A local array of states, preview fixture, classifier echo, or placeholder support link is not an operational case service.

The shared Physique native shell supplies navigation, active-match timer and exits, account isolation, privacy cover, text drafts, and cross-window camera ownership. The reviewed shared trusted identity and badge product supplies public rails and correction-related badge changes when a battle host is present. This child does not build competing badge authority, camera ownership, report intake, case-list navigation, media viewing, privacy deletion, or rating settlement.

F29-B supplies original judging-version meaning and the prohibition on rerolls, unsafe explanations, and invented confidence. F29-C supplies the immutable original settlement, separately audited current adjustment, effective record, and coherent pending/settled revision. F29-D supplies case roles, permitted decisions, human-review meaning, restrictions, and appeals. F29-E supplies current authorization, data lifetime, retention exceptions, withdrawal, and deletion. Their existing documentation is product context, not proof that these services have passed human review.

The older F29-A allowance for a balanced two-column Mac player comparison is superseded by the user's new vertical-player direction wherever a shared battle stage is visible. This child does not edit that parent. It also does not adopt a skill's newer default deployment target: iPhone iOS 16 compatibility and native macOS 14 remain the project constraint, with availability-safe shared controls.

## Prospective Files and References

These are ownership surfaces for future work, not claims that new app files exist.

- [Future F29-A-u implementation brief](../../../../prompts/F29-physique-duels/F29-A-u-phase-1-case-detail.md) owns the connected work slice and future native acceptance scenarios.
- Prospective TimeMaster/Views/Physique/PhysiqueCaseDetailView.swift owns this case-detail presentation and its inline response and appeal sections, not an extra screen family.
- Prospective TimeMaster/Views/Physique/PhysiqueCaseDetailModel.swift owns presentation and recovery for an already-authoritative case contract, not a second review or rating authority.
- [Physique page context](../DOCKS.md), [F29 parent](../../DOCKS.md), [AI judging](../../F29-B-ai-judging-and-metrics/DOCKS.md), [rating and corrections](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [safety and appeals](../../F29-D-safety-and-reporting/DOCKS.md), and [privacy and lifetime](../../F29-E-privacy-and-service-operation/DOCKS.md) own the shared behavior.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared glass and press controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) are the palette, typography, density, and availability-safe interaction references.
- [Ranked sports components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) and [exercise HUD](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) are sports hierarchy references only; no Dynamic Type clamps, fake levels, exercise scores, or provisional body scores are inherited.
- [Native Mac scene](../../../../TimeMaster/App/TmaxApp.swift), [existing commands](../../../../TimeMaster/App/TmaxCommands.swift), and [project targets](../../../../TimeMaster.xcodeproj/project.pbxproj) define native window, command, and deployment boundaries.
- [Local profile models](../../../../TimeMaster/Models/LocalProfileModels.swift) demonstrate why editable cosmetic badge previews are not competitive achievements or eligibility verification.
- [Supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy and directness reference only. Its side-by-side people, overlay pills, footage, purple/brown treatment, and identifiable faces are not copied or licensed app assets.
- [Apple HIG — Designing for macOS, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) informs resizable windows, comfortable density, keyboard and pointer access, and less unnecessary modality. The central dossier and optional inspector are this feature's concrete design choice.
- [Apple HIG — Motion, Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion) informs purposeful, brief, optional, cancellable feedback. Exact timings here are proposed feature choices, not Apple-mandated constants.
