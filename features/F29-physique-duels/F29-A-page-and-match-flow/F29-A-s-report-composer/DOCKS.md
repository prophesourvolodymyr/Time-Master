# F29-A-s — Contextual Report Composer

## Purpose and Review Boundary

This child of [F29-A](../DOCKS.md) owns the native contextual Report composer on iPhone and macOS: safe target identification, a required reason, an optional note, the evidence explanation, deliberate submission, truthful receipt and recovery, and the composer's withdrawal interaction. Hide and Block remain independent protections. The private case center, full scoring-review flow, privacy settings, and active-match exit flow remain with their respective owners; this composer hands off to those real destinations instead of creating extra screens.

This is a documentation-only design specification and future implementation brief, not an implemented view, accepted prototype, operating moderation service, or verification claim. The latest user direction requires native iPhone and native macOS, an animated minimal-text sports interface, all public battle badges above two large vertical participants, and a real top timer wherever the battle composition appears. Earlier numerical retention proposals remain subject to product and operational review; this child must not turn a proposal into a false deployed-service promise.

[F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns reporting, hiding, blocking, review, and lawful safety handling. [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns access, draft protection, evidence lifetime, deletion, and processor disclosures. [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) remains the sole competitive contract. Reporting cannot grant Elo, erase a loss, stop a clock, create an evidence gallery, or establish an allegation as fact.

## Chosen Composition and Tradeoffs

Use a single native contextual sheet, not a safety wizard, a body-preview modal, a new navigation destination, or a floating report window. It reads like a compact sports-official incident slip: one title, a neutral item reference, Reason, Note — optional, a short evidence disclosure, independent protection actions, and Submit report. A small flag or shield symbol identifies the task; it is not an achievement or verified-identity mark.

The substantive decision is to make the target recognizable without showing the concerning content. A reference such as Opponent · Side pose, together with the actual match date and permitted participant label, is enough to identify the item. A face, physique thumbnail, abusive username, unsafe explanation quotation, or allegation badge adds exposure without improving this task. A service-valid target reference identifies the exact content version even if its display name later changes.

A one-sheet form avoids a Next/Back sequence while someone may be uncomfortable or on a real match clock. Full-height composition space on iPhone is preferred over a small half-sheet that compresses the note and disclosure behind the keyboard. A window-attached Mac sheet preserves native task scope and other-window interaction; a persistent inspector is not chosen because composing a report is a discrete action, not continuous editing of the duel. Consequence confirmations use standard alerts or confirmation dialogs, not stacked custom sheets.

The sports character comes from the existing Inter hierarchy, orange action emphasis, decisive selection marks, and one short service-confirmed acknowledgement. Reporting is not a celebratory win state. No confetti, punishment animation, red siren, body scan, or decorative countdown belongs here.

## Visual Hierarchy and Concise Copy

The reading order is consistent on both platforms:

1. A native sheet header titled Report with Close. Close means leave the composer, not cancel an active match or retract an in-flight report.
2. During a live match only, a compact pinned match strip repeats the actual service-owned remaining time or truthful unavailable state and exposes Exit match. It says Camera stopped. Match time continues when reporting interrupted local acquisition. This strip is context, not a new report deadline.
3. A safe, non-image target reference. Its primary line is the item kind and pose or text section. Its secondary line is the real match date and permitted participant label, or the limited public account context for a non-match report. A discreet Change item action is available only when other authorized targets already exist in the same context.
4. A persistently labeled Reason control with Choose reason until the person makes a choice. The selected reason remains readable in full. Relevant rule help appears below that selection, not as a warning wall on entry.
5. A multiline Note — optional editor. The supporting line says Add context, not screenshots or personal contact details. Empty text is valid. The editor grows into the available scrolling area; it is not a one-line message composer or a mandatory explanation.
6. The short evidence explanation, visible before Submit, with an Evidence and privacy disclosure for the full bounds. The short explanation is not replaced by a generic privacy-policy link.
7. Independent Hide image or Hide explanation, where applicable, and Block player where there is a real player target. They are labeled secondary actions, not preselected checkboxes and not part of Submit.
8. A stable action footer: Submit report, or the actual recovery action for the current delivery state. Sending feedback occupies the same action area. The sheet never invents a percentage, case number, or review-start time.

Use the shared near-black background, existing dark surfaces, white primary text, and toolbar orange. Reuse the readable secondary ink and shared type/spacing conventions; do not inherit an unreadable low-opacity caption solely because it exists in an older control. Field labels and retention consequences use readable body or secondary text, not microtext. The primary action has the app's shared shape and feedback. Native Mac controls retain native density and visible focus rather than adopting a phone-sized bottom dock.

Submit report is the only submission action. Close remains visible throughout. When receipt is confirmed, the heading becomes Report received, the primary action becomes View case, and Close still returns to the originating context. Received is an automated service acknowledgement, not a claim that a human has begun review. The receipt remains until the person leaves; it does not auto-dismiss.

## Safe Entry and Target Identity

| Entry context | Safe reference and scope | What must not happen |
| --- | --- | --- |
| A selected-still tile, including a hidden placeholder | Opponent or You, the named front, side, or rear pose, and its actual match | No enlargement, thumbnail fetch, screenshot, or request to reopen the pose |
| An already intentionally opened still | The same exact match and pose reference after immediate local protection | No final exposed frame during dismissal or transition |
| Generated explanation | Match explanation and the actual saved result reference | No repetition of the unsafe wording in the form, accessibility label, or receipt |
| Opponent identity, standings, or permitted profile | Player profile or Player name plus authorized account context | No email, private declaration, inferred identity, or automatic copying of a reported offensive name |
| Active-match Safety or match detail | This match, the permitted participant label, and available item kinds | No access to early opponent poses, rejected captures, retakes, or a nonexistent gallery |
| Removed, expired, withdrawn, or deleted content | The remaining authorized match/account/text reference and its truthful unavailable reason | No retrieval from an old link, backup, other device, or processor to manufacture new evidence |
| Capture rejection, enforcement notice, or score disagreement | A clearly named handoff to the already owned safety-appeal or Request scoring review route | No disguising a disagreement as a nudity report or making a safety allegation on the person's behalf |

Opening Report for an image immediately hides that image for this viewer before presentation starts. Cancelling, closing, changing the target, or failing to send does not reveal it again. Opening Report for an unsafe explanation similarly suppresses that explanation locally without changing the underlying result. An account report does not unnecessarily hide every unrelated result or body image.

The initial target is taken from the invoking control, never inferred from body appearance, current scroll position, a screenshot, or a newly typed handle. Change item offers only the already authorized items from that same account or match, using safe text labels. It does not search other people's media. The category and note survive a target change; the new target is made explicit, and an incompatible category is identified for reselection rather than silently changed. Hides already applied remain in place. The person reviews the new target before Submit.

A reported capture version, explanation revision, and account association must not drift when newer data arrives. A removed item can remain referencable for a permitted text-based concern. If no valid reportable reference remains, the form explains Target unavailable, keeps the allowed note draft, disables only submission that cannot be authorized, and exposes published support. It never silently reports the next pose or another participant.

## Reason Selection and Rule Help

No safety allegation is selected by default. A contextual entry can limit item-inapplicable actions, but every applicable safety category remains discoverable through the native selector. A complete list is preferable to guessed accusations. iPhone uses the platform's semantic single-choice picker/menu; macOS uses a native pop-up selector. Neither requires a new category-picker screen. Long labels wrap in the selected summary, and the native choice list is scrollable and keyboard accessible.

| Reason | Meaning and contextual help |
| --- | --- |
| Nudity or prohibited exposure | Explain that nonsexual shirtless adult men are permitted; all participants must keep groin and buttocks covered and follow their privately declared attire rule. A concern can still be reported without reopening the image. Appearance cannot prove a declaration false |
| Sexual or exploitative content | Cover sexualized presentation, solicitation, nonconsensual intimate imagery, or suspected exploitation. Do not ask for attachments or anatomical detail |
| Adult eligibility concern | Accept safe contextual information. Do not ask the reporter, a model, or a reviewer-facing image widget to estimate age from appearance |
| Nonconsensual image, bystander, or privacy | Cover another person, misuse of an image, doxxing, or missing permission. Do not request identity documents or another person's photo |
| Harassment, discrimination, or bullying | Cover unsafe names, text, threats, harassment, and body shaming without repeating that material to the opponent |
| Impersonation or manipulated evidence | Cover substituted people, prerecorded material, and prohibited manipulation. Ordinary local face obscuring is not cheating |
| Unsafe or inappropriate AI explanation | Identify the exact explanation revision, independently of image reports or disagreement with the numerical outcome |
| Urgent personal safety | State This app is not an emergency service. Offer actual published emergency or specialist-help guidance without inferring location or promising continuous monitoring |
| Spam, coordinated abuse, or other safety concern | Permit a relevant concern outside the named categories. The optional note remains optional |

Scoring or outcome disagreement appears as Request scoring review, visually separate from the safety reasons. Selecting it hands off to the real owned review route after resolving any unsent draft; it does not send a safety report or silently reuse a draft as a dispute. A contextual unsafe-explanation entry still requires an explicit reason choice. Public country, badge, tier, body shape, and a lawful outfit are not evidence of misconduct.

A missing reason receives a field-specific Choose a reason to submit message without deleting text. The note follows the real intake contract's published text budget; the form must disclose an actual limit when relevant, preserve over-limit input for editing, and never silently truncate a composed character, paste, or dictation. It does not introduce an invented client-only limit or require a minimum note length. Authentication, category availability, and target authorization errors are distinguished from note errors.

## Evidence Explanation and Privacy Boundaries

Before Submit, the concise disclosure says: Only authorized reviewers receive this report and necessary existing evidence. Ordinary report evidence may be kept for up to 30 days after receipt. Legal or urgent-safety rules may differ. This reflects the current proposed ordinary policy, not an assurance about an unreviewed deployment. If the real approved service has a different lawful policy, its product disclosure must be resolved before implementation or submission, not substituted silently.

Evidence and privacy expands inline to explain all of the following in plain language:

- The report includes the selected target reference, chosen reason, submitted note, and only the relevant existing decision records and minimum necessary lawful evidence. A single-pose complaint does not automatically preserve both full pose sets, every retake, or an account archive.
- Authorized case reviewers and narrowly necessary legal-safety personnel can access that evidence. The opponent does not receive the reporter's note, identity as reporter, or evidence package. This is not an absolute anonymity promise or end-to-end-encryption claim.
- Ordinary pose-media access expires no later than twenty-four hours after match finalization. A received benign report may preserve necessary existing lawful evidence for at most thirty days after the originating receipt, and less when no longer needed. A hold does not extend participant viewing. Duplicates, added context, appeals, or staff delay do not restart the evidence clock.
- A local draft, sending animation, unconfirmed request, or support message without receipt does not prove that an evidence hold exists. Media may expire before a report is actually received. Deleted or expired imagery cannot be restored by reporting later.
- Suspected unlawful or exploitative material uses restricted specialist handling under applicable legal duties, not a routine thirty-day attachment gallery. The person must not download, screenshot, forward, email, or reupload it.
- Routine case correspondence is distinct from images. The current proposed routine case-record ceiling is ninety days after closure; narrowly lawful enforcement or legal records and the separately disclosed processor arrangements follow their actual purposes and bounds. The full F29-E disclosure remains accessible without losing the draft or leaving a hidden camera running.
- Withdrawing a report means no longer pursuing the request. It is not a promise to delete every received record or defeat a justified safety or legal hold.

If the target's imagery is already unavailable, show Image unavailable. We can review the remaining context where possible instead of promising preservation. Submission remains available for an authorized account, match, or text concern when that is supported by real intake. No Attach, Photos, Files, camera, image-drop target, or screenshot requirement appears in this composer. Pasting text never becomes an image attachment. Reporting does not send the draft to the appearance judge or a personal AI provider.

## Delivery, Editing, and Recovery States

| State | Visible surface and available actions | Recovery and authority |
| --- | --- | --- |
| Opening with valid context | Report, safe target, unselected Reason, optional note, disclosure, protection actions | Image/explanation protection happens before motion. Camera acquisition and any pending self-timer stop immediately if opened from capture |
| Resolving authorized context | Safe item kind and Checking item, with Close and local protection | Do not show a stale other-account identity, empty fake case, or fetched body preview. Submit waits for a valid reference |
| Editing | Required reason, optional note, concise disclosure, Submit report and Close | Nothing has been reported. User changes are preserved within the protected draft policy |
| Missing reason or invalid note | A specific adjacent field error and the unchanged draft | Focus the first actionable error on attempted submission; do not use a vague failure banner or shake |
| Ready | Actual target and selected reason are readable; Submit report is available | No extra confirmation step or default Block is required. Submission is deliberate |
| Sending | Sending… with a native indeterminate indicator and a safe summary of what is in flight | Only repeat submission is gated. Close, protection, Exit match, disclosures, and continued text editing remain usable. No received claim or review progress |
| Edited during sending | The submitted snapshot remains identified; later edits are labeled Not sent | Do not mutate the in-flight target, reason, or note. Later edits remain a separate local draft until the existing receipt resolves and the person explicitly sends relevant additional context |
| Received | Report received, the actual service case reference and receipt time, View case, Close | The acknowledged target and submitted snapshot determine what was received. Clear only the acknowledged draft version. No automatic human-review or outcome claim |
| Received with later unsent edits | Receipt plus Your latest changes have not been sent, with a safe path to add context to that case | Preserve the newer draft. Send additional context only by explicit action to the same case; do not quietly append, discard, or create another case |
| Offline before dispatch | Not sent. Draft saved on this device when storage succeeded; Retry when connected, Close, Hide, Block | Never upload the draft automatically on reconnect. No case or hold is implied |
| Definite intake rejection or transport failure before acceptance | Not sent and the specific recoverable reason | Preserve permitted text and target. Retry the same submission context when valid; no new match, charge, or report-vote count |
| Connection lost after possible acceptance | Receipt unknown. Check whether this report was received, with Check status and Close | Do not label it Not sent or issue a fresh independent report. Reconcile the existing submission reference first |
| Checking receipt | Checking status with retained safe summary, Close, Hide, Block | The same service submission is consulted. Failure returns to Receipt unknown rather than inventing a case |
| Retry permitted after reconciliation | Retry report with the unchanged pending submission identity | Service-confirmed retry resolves to one original case. If acceptance is still uncertain, use the existing identity, never a new one |
| Already reported or duplicate | Already reported, the existing confirmed case and View case; optional Add context | A confirmed duplicate is not another complaint vote or retention reset. Do not throw away unsent new context or expose another account's case |
| Intake temporarily unavailable or limited | Reports unavailable or the actual limited state, protected draft status, published support and relevant urgent-help guidance | Do not promise an unscheduled retry or make safety paid. A real abuse limit cannot erase all genuine safety-contact access |
| Session expired | Sign in again to send, with private local protection intact | Reauthenticate only as the same account before restoring the draft. Switching or signing out clears that account's unsent sensitive text; do not expose it behind another account's sign-in |
| Target expired, removed, or sharing withdrawn | Accurate unavailable label and text-only context | Use remaining authorized intake where possible. Never restore an image, replace the target silently, or let a draft extend access |
| Confirmed case status changes while open | Actual latest case status, or Last confirmed status with its time if stale | Receipt is not a progress meter. Review outcomes and corrections come from the case/competition owners |
| Draft storage unavailable | Draft not saved on this device and the retained in-memory form | Do not offer a misleading Keep draft success. Permit send if otherwise valid; explicit closure explains actual text loss |
| Draft expired or discarded | Draft expired or Draft discarded, an empty optional note, and a new authorized form when desired | Hidden media stay hidden. Expiry is not report withdrawal and cannot erase a case that may already have been received |
| Account switched, signed out, or deleted | Private text, receipt, and old-account target disappear; conventional entry/support remains | No prior-account cases, body caches, or drafts leak into a new account. Actual received records follow F29-E rather than a false local deletion claim |

Every send captures one specific authorized target, category, and note. Rapid repeated activation, relaunch, other windows, network retries, and late acknowledgements must resolve against the same real submission or existing case. A late response cannot overwrite a newer local draft, relabel another target, reopen hidden media, or steal focus into an unrelated window. The form's Sending status alone is never evidence of service acceptance.

The service's real duplicate and add-context contract determines the existing case. If the person edits after dispatch, do not automatically send those edits with a retry of the original request. Target changes during an unresolved submission require closing or preserving the separate draft and resolving the pending identity first; an in-flight report cannot be retargeted. Additional context belongs to its acknowledged case and its original evidence clock. Receipt-lookup failure is not permission to create a second case.

## Bounded Draft Preservation

A meaningful draft is a chosen category or user-entered note beyond the untouched contextual form. Persist only safe target references, category, permitted text, expiry information, and the minimum pending receipt reference needed by the reviewed service contract. Never persist an image, signed media URL, quoted offensive content copied by the app, or screenshot in a report draft.

Text drafts remain protected on the current signed-in device for at most twenty-four hours from the draft's original creation, or until discard, sign-out, account switch, or deletion if earlier. Editing, reopening, reconnecting, or changing a category does not silently renew that window. A discreet Saved on this device until followed by the actual local expiry time appears after meaningful edits; it is not a second ticking battle timer and does not imply cloud sync or successful receipt. Privacy shielding covers text during app/window snapshots and inactivity.

Close on an untouched form dismisses directly. Close, swipe dismissal, Escape, or a sheet-close request on a meaningful unsent draft offers Keep draft, Discard draft, and Continue editing through the platform's standard confirmation. Keep draft is offered as successful only when protected storage succeeded and the lifetime remains valid. Discard does not undo Hide or Block. Unsaved in-memory text loss is stated plainly if storage is unavailable. A sent report is not withdrawn by Close.

While delivery may already have occurred, closing preserves the minimum account-scoped receipt lookup required by the real service. Deleting editable local text must not lose the ability to resolve a possibly received report, nor be presented as cancelling delivery. At text-draft expiry the private note is cleared; any lawful minimal pending reference remains only for the service contract's bounded reconciliation purpose. If no receipt can be confirmed, show that limitation and use existing case/support lookup, not a fresh silent submission. No sensitive text survives sign-out under this exception.

Reopening the same authorized target offers its unexpired local draft rather than overwriting it with an empty form. A draft on another device is not promised or fetched. Received case state can be retrieved after authentication under its own access policy; that is not cross-device draft synchronization.

## Independent Hide and Block

Hide image immediately produces Hidden by you. Opening an image report applies the same protection. Until receipt, a secondary label can say Report not sent or Report not confirmed as appropriate; it must not say Reported merely because the sheet was opened. Confirmed receipt may identify the target as Reported without revealing the allegation publicly. Hide explanation uses a neutral text placeholder and keeps permitted score and outcome information intact.

Hide does not submit a complaint, delete the other person's data, preserve evidence, or change a rating. Hide choices can synchronize only after real confirmation. Another device is not described as protected before that confirmation. The composer does not contain View again or an unblur control. The media owner may offer deliberate View again only when the sole barrier is the viewer's own hide choice; a report quarantine, block, expiry, removal, or consent withdrawal cannot be bypassed.

Block player is available only for a real permitted account association, never for the AI explanation as though it were a person. For a system-generated explanation without a relevant player target, omit Block instead of blaming the opponent. A standard confirmation states the current-match consequence before the person confirms:

| Actual match state | Block confirmation and resulting behavior |
| --- | --- |
| Before service-confirmed Go | Block this player and cancel this pairing. No Elo change. Confirm the real cancellation and reservation release; a request racing Go must resolve to the actual service stage |
| After Go, before finality | Block hides this player's media and prevents future matches. This match continues. Leaving may forfeit. Block alone does not leave or settle the match |
| Final judged result or history | Block shields the pair's gallery and prevents future pairing. Your completed result stays unchanged. Keep the permitted own result with a neutral player placeholder |
| Forfeit or no-contest | Preserve the actual record and absence of an opponent gallery; do not imply blocking removes the record |
| Offline or service confirmation unavailable | Hide locally at once. Show Block pending — future pairing and other devices are not yet confirmed. New pairing waits while the block remains unconfirmed |

Block can be used without choosing a reason or submitting. Submit can be used without Block. There is no combined Report and block primary button, automatic block checkbox, accusation notification, or automatic rematch. Unblocking belongs to the existing Safety area and never automatically restores hidden images. A report about a blocked or deleted player remains attached to the permitted stable reference, not to an exposed replacement profile.

## Receipt and Withdrawal

Report received remains a modest confirmation, with the real private case reference and View case. Opening the real case center replaces the composer after resolving any later unsent edits; it never stacks another custom sheet. The case center owns ongoing correspondence, reviewer requests, appeals, actual staffing information, and final decisions. This child does not invent those screens or a review countdown.

A receipt's secondary disclosure offers Withdraw report where the service permits it. The native confirmation says Withdraw this request? Review or a lawful evidence hold may still continue. Hiding and blocking will stay as they are. Keep report is the nondestructive choice. Confirming sends a request against this exact received case, never an instruction to delete the opponent's images or reverse the match.

| Withdrawal state | Visible behavior and recovery |
| --- | --- |
| Requested and in flight | Withdrawing…; gate duplicate withdrawal, retain Close and protection, keep the last confirmed case status |
| Offline before sending | Withdrawal not sent; explicit Retry withdrawal when connected and access to the existing case |
| May have reached the service | Withdrawal not confirmed; Check status for that same request, not a claim that review stopped |
| Confirmed | Request withdrawn with the actual service status and a reminder that necessary safety or lawful handling may continue |
| Rejected or no longer applicable | Explain the real reason, preserve the last confirmed status, and link the existing case/support route; do not pretend success or resubmit a new report |
| Report receipt still unknown | Check receipt first. No report is declared withdrawn until a real case and withdrawal acknowledgement exist |

Closing a sent report, discarding newer unsent edits, stopping the camera, withdrawing AI consent, and withdrawing a report are different actions. No one is forced to restore or continue viewing media to request withdrawal. Withdrawal does not reopen hidden material, unblock a player, restart an evidence clock, erase all received correspondence, or rerate a match.

## iPhone Composition and Interaction

Use a native large-detent composition sheet on iOS 16 and later, with a conventional leading Close control and one scrollable form. The default is not a half-height sheet: text entry, clear category choice, and the necessary evidence explanation are more useful than an exposed strip of body imagery. Do not create a full-screen camera-style custom report flow. Native presentation controls remain adapted to supported system versions.

The title and live-match strip remain outside the form's scrolling content. The form scrolls above a safe-area action footer, which follows the keyboard's actual geometry. The note is not automatically focused on entry; the sheet heading is the first accessibility focus and no keyboard appears until deliberate text entry. Selecting Note scrolls the caret into view without hiding Reason, Close, the live timer, or the submission action. The keyboard's ordinary Done action only ends text entry, not submission. Landscape, smaller iPhones, and accessibility text sizes may require more scrolling; they must never compress the disclosure to illegibility or shrink participants into thumbnails.

At very large text sizes, the footer wraps its status and primary action vertically using the available measured space. All form content remains reachable without horizontal scrolling. Use the existing forty-four-point interaction convention for primary and safety actions and adequate separation between Submit, Hide, and Block. The note supports dictation, native selection and editing, and multiline input without requesting microphone access from this feature.

Swipe dismissal follows the meaningful-draft contract. Outside taps cannot discard text, submit, withdraw, forfeit, or undo local protection. A received sheet closes normally. During sending or receipt uncertainty, Close means return with a pending report status, not cancel the network request. If the source image or row vanished, focus returns to its safe placeholder or the originating match's Safety action, never an invisible control or an automatically reopened pose.

When the battle stage is visible behind or after the sheet, its order stays real top timer, complete owner-grouped public identity and badge rails, large You panel, then large Opponent panel. Every earned public battle badge wraps above the players; no three-badge cap, hidden +N, ticker, or badges on bodies. Short screens scroll the central stage rather than changing to side-by-side or cropping a player. The composer itself is not a miniature battle stage and does not duplicate its badges or players in the target reference.

## Native macOS Composition and Window Lifecycle

Use a native macOS 14-and-later window-attached sheet, not Catalyst, a web form, a stretched iPhone screen, or an always-on-top report panel. Keep the existing normal title bar, traffic lights, menu bar, and app-wide 800-by-600 minimum. The sheet's preferred width follows the existing readable-column convention and is bounded by its actual parent window; its content scrolls inside the space left by the header, live-match strip, and native trailing action row. Do not raise the app minimum to fit report copy.

At 800 by 600, Reason and the target remain readable, the multiline note and disclosure can scroll, and Close, the current recovery/submit action, timer, and Exit match remain reachable. Larger laptop, desktop, full-screen, and external-display windows add comfortable text space rather than a second report column or a horizontal duel. Live resize, display-scale changes, moving between monitors, and keyboard appearance do not drop text, dismiss the sheet, refetch body imagery, or reset service time. A fixed-position overlay over the title bar is not permitted.

The sheet is modal to its parent only. Other Tmax windows remain usable, consistent with the native model; they must not create another active match, second camera owner, duplicate report transaction, or additional allowance charge. Opening the same report target elsewhere returns to the owning sheet or the same service-confirmed case, without copying sensitive text into a second window. Another device does not inherit a local unsent draft.

The parent battle remains vertical at every width, including full screen and external displays: real timer first, all complete owner-grouped public badge rails next, then two equally treated large player panels with You above Opponent. A pre-existing supplementary inspector may show other owned details outside reporting, but this task does not create one or shrink the players to fit one. Short windows scroll the central stage; timer and safe actions remain usable. Do not leave an unsafe image visible through a dimmed sheet background.

Pointer users get ordinary hover feedback and a standard insertion cursor in Note, not a lifting target card or hover-only safety menu. Tab and Shift-Tab traverse semantic controls, the native reason picker supports standard keyboard selection, and Full Keyboard Access exposes every action. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O for their current commands. Return in Note inserts a newline; Space or Return activates a button only when that semantic control is focused. Do not install a global key handler that submits or captures while the person types.

Escape first dismisses an open picker, transient editing interaction, or confirmation. Otherwise it requests the same state-aware composer Close. Cmd-W while the sheet owns interaction requests composer close first and must not pass through to silently close an active-match window. Closing the underlying match window or quitting through normal platform routes invokes the actual pre-Go cancellation or post-Go eligible-forfeit consequences where the platform permits confirmation. The person's report draft is preserved within its existing bound where possible; if it cannot be saved, the same confirmation states that text-loss consequence. Force quit, process termination, device loss, and power loss are not confirmable voluntary forfeits and cannot be prevented or relabeled as deliberate consent.

On app/window inactivity, minimization, lock, or background transition, acquisition and decorative work stop immediately and sensitive report text and media receive a privacy cover. Authoritative clocks, receipt processing, and valid server judging continue. Returning reveals only the same authenticated account after restoring actual service state; it does not replay a sending acknowledgement or automatically expose the gallery. A receipt arriving while inactive is presented once on a safe return, not as a body- or note-bearing notification.

Reporting is not camera-dependent. TCC denial, an absent camera, external-camera removal, Continuity Camera disconnect, permission revocation, or capture-owner loss while the sheet is open must not erase the draft, block text-only intake, or trigger a permission alert. The parent records the actual camera/interruption state. Returning to capture requires an explicit resume with valid permission and ownership; no fake preview, rated file-picker substitute, deadline reset, or silent second camera session is permitted.

## Active-Match Continuity

Opening the composer from capture stops local acquisition and cancels an outstanding self-timer immediately. Show Camera stopped. Match time continues. Reporting alone does not withdraw AI-processing consent or recall an already accepted processor request; previously authorized evidence processing can continue only under its existing permission. Resume camera requires an explicit parent action after restoring the same match. No new still is taken under the sheet.

The displayed match strip uses the real stage and deadline. Search remains bounded by ninety seconds, capture by the same ninety seconds with at most two retakes per pose, and reconnect by twenty seconds without extending deadlines. Judgement remains bounded by thirty seconds after both final pose sets are received. It is never replaced by a five-second result promise or a report-specific clock. An unavailable connection is labeled honestly rather than displaying stale time as a live confirmed state.

Exit match remains available within the sheet during an active match. It uses the existing state-aware exit owner and actual service stage. Before Go, cancellation has no Elo consequence; after Go, only an explicit confirmed otherwise eligible forfeit can create a rated forfeit. A service-established safety abort, invalid evidence, or unavailable service takes no-contest precedence. Report or Block alone establishes none of those outcomes. A cancellation racing Go must present the actual stage, not reinterpret an old Cancel tap as permission to forfeit.

If a result, timeout, cancellation, or no-contest arrives while composing, preserve the safe report target and permitted draft. Update only the compact match strip to the confirmed terminal state; do not dismiss the composer, move focus into a celebration, attach newly exposed poses, or send the report automatically. After closing, return to the actual safe current match state, with the complete vertical battle hierarchy wherever it is still present.

## Focus, Accessibility, and Content Safety

The reading order is header, live-match context if any, safe target, Reason, optional Note, evidence summary and disclosure, independent protection, then primary action. Native sheet focus stays within that sheet while it owns input, with standard confirmation focus handling. The target is an accessible neutral reference such as Opponent side pose, not an intimate visual description. Offensive names or hidden explanations must not survive in an old accessibility label, help tooltip, cached caption, or rotor item.

A category change announces its selected value. A failed submit focuses the actual invalid control and associates the reason with it. A receipt or withdrawal outcome is announced once; if the person is still editing newer unsent text, keep the caret and announce the status without stealing focus. After Hide, focus moves to the protected placeholder or corresponding safe status. Closing returns to the initiating Report action or the nearest safe surviving Safety action. No status or receipt is read repeatedly because an unrelated timer ticks.

Dynamic Type is not clamped. Long handles that are safe to display, localization expansion, right-to-left text, multiline reasons, dictation, marked text, pasted notes, and composed characters must not obscure the target or submit action. Keyboard input follows native text semantics, including canceling an input-method composition before treating Escape as sheet dismissal. VoiceOver, Voice Control, Switch Control, hardware keyboard, and Mac Full Keyboard Access have equivalent named actions without drag, hover, long press, color, sound, or haptics as the only route.

Contrast uses the actual theme/background combination, including Increase Contrast and Reduce Transparency. Disabled Submit has an accessible explanation such as Choose a reason rather than relying on reduced opacity. Received, unknown, unsent, withdrawn, and pending block each have text and a suitable symbol. No emergency help is encoded only as a red icon. Optional haptic acknowledgement can reinforce a real receipt on supporting iPhones; there is no required audio or haptic-only event.

## Animation and Energy Rules

Protection, camera stopping, account clearing, text preservation, and receipt state changes take effect independently of animation completion. The platform controls native sheet and keyboard timing; the numerical values below specify only feature-owned feedback and are not claims about a measured system duration.

| Trigger | Motion and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Open or close composer | Use the platform's native sheet transition. Any feature-owned header/status continuity settles within about 280 milliseconds; no body-to-form shared-element zoom | Native Reduce Motion behavior, with no added travel. New service state and Close are actionable immediately |
| Press a shared action | Reuse the existing press spring, response 0.24 seconds and damping fraction 0.88. Native Mac controls keep their standard feedback | Reduce Motion removes additional scale. No duplicated activation, delayed safety effect, or press animation on the note editor |
| Select a reason | Selection mark and associated short help crossfade over 160 milliseconds; the sheet does not bounce or resize around the selected word | Latest selection wins. Native picker dismissal remains platform-owned. Reduce Motion uses at most a short opacity change |
| Expand Evidence and privacy | Inline content appears with a restrained 180-millisecond opacity and layout settling, without moving the target into a new screen | Preserve reading/scroll anchor and focus; reverse immediately on a second activation. Reduce Motion inserts content statically |
| Hide image or explanation | Replace content with an opaque safe placeholder immediately, before any animation; only the safe status acknowledgement may fade over 140 milliseconds | Never crossfade from the unsafe frame, unblur, or reveal on cancellation. Reduced settings use immediate replacement |
| Start sending or check receipt | Action label/status changes over 160 milliseconds and a native indeterminate indicator runs only while there is actual work | No minimum spinner time, percent, repeating custom halo, or automatic completion. Reduce Motion may use static Sending or Checking status text |
| Real receipt arrives | A neutral acknowledgement symbol settles from no more than 1.04 scale over 180 milliseconds while the receipt section replaces the sending status within 260 milliseconds total | No celebration, staged countdown, or wait before View case. Close or a newer state cancels motion. Reduce Motion shows the final receipt with at most a 100-millisecond fade |
| Delivery becomes unknown, unsent, or unavailable | Replace the status and recovery action with a 180-millisecond crossfade | No shake, red flash, automatic re-send, or spinner that conceals failure. Focus stays put unless an attempted action needs an error target |
| Block confirmation, pending, or completion | Native confirmation first; local shield immediate. Only the resulting safe text/icon changes over 160 milliseconds | Confirmed and pending remain different words. No punishment animation; Reduce Motion uses immediate text |
| Withdrawal is requested or acknowledged | Native confirmation and a 180-millisecond status crossfade tied to the real request/receipt | No visual erasing of case data or reverse-send animation. Unknown receipt remains unknown; reduced behavior is static |
| Active-match timer tick | Reuse the parent timer's stable digit geometry and approximately 180-millisecond digit update per real second | No extra report timer, flashing low-time state, or announcement every second. Reduced behavior uses static numeral replacement |
| Parent stage becomes terminal while composing | Update the compact stage text over 180 milliseconds; preserve the editor and target | No full result reveal or earned-badge celebration behind the report. Safe actions and the actual final status are available immediately |
| Resize, caret movement, note typing, or restored draft | Native text/scroll behavior; no custom keystroke animation, card travel, or replayed acknowledgement | Preserve selection and caret. Reduced Motion requires no special alternate data path |

No ambient loop is added to the composer. Any quiet parent-stage ambient layer pauses while reporting, leaving at most the task's single focal feedback and system activity indicator. The form does not animate the complete public badge wall, pulse the report target, scan a body, or replay earned-result motion. Decorative work stops offscreen, in inactive or minimized windows, under backgrounding, and when low-power or thermal constraints call for reduced activity. Timers and receipt reconciliation remain authoritative; accessibility and safety do not depend on a frame rate.

No per-frame service calls, file writes, image decoding, camera rebuilding, global layout invalidation, or note autosaving is driven by an animation. Necessary draft preservation follows real edits and lifecycle boundaries, not animation ticks. Reduce Transparency gives the form, privacy cover, and placeholders opaque readable surfaces. Low-energy mode removes nonessential transitions instead of lowering the reliability of Hide, Block, submission, or the real clock.

## Dependencies and Ownership

- [F29 parent](../../DOCKS.md) and [F29-A](../DOCKS.md): actual match state, vertical stage hierarchy, sheet routing, safe return, camera ownership, and explicit exit semantics.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md): reportable explanation revisions, no unsafe generated wording, no report text or UI chrome in judge context, and no locally invented verdict.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md): real stages and Go boundary, finality, block exclusions, one active match, and unchanged competitive outcome until an authorized correction.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md): real authenticated intake, categories, receipt lookup, duplicate handling, case/add-context/withdrawal behavior, immediate hiding, block consequences, urgent guidance, and published staffed support.
- [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md): current account authorization, bounded protected drafts, privacy covers, evidence minimization, access revocation, actual retention disclosures, and restricted legal-safety handling.
- F29-F owns the trusted public identity, optional self-declared country/region, and complete public badge rails used by any parent battle stage. Local cosmetic badge previews are not competitive or verified identity. This composer neither creates nor awards a badge and never uses country as safety or scoring evidence.
- Existing account, navigation, protected media, and service foundations must be implemented and human-reviewed before implementation of this dependent connected surface. The private case center, media placeholder owner, scoring-review owner, and exit owner must expose real reviewed handoffs; labels pointing at nonexistent destinations are not acceptable.

## Files

These are documentation ownership and prospective integration locations, not a claim that new native files or services already exist.

- This DOCKS.md owns the exact report-composer product behavior.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-s-phase-1-report-composer.md) owns the separate implementation instructions and human-review handoff requirements.
- Prospective TimeMaster/Views/Physique/PhysiqueReportComposerView.swift owns the native contextual sheet and adaptive iPhone/Mac presentation.
- Prospective TimeMaster/Models/PhysiqueReportComposerModel.swift owns disposable composer presentation and draft/snapshot distinctions, consuming the reviewed service contracts rather than becoming another case or competition authority.
- Existing or future reviewed report, case, hide, block, draft, match, and account owners under TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift supply actual service state. Reuse their established types and stores; this child does not authorize a parallel network stack or backend rewrite.
- Already implemented F29 image/placeholder, explanation, identity, active-match Safety, and history/detail entry points route to this composer using their exact authorized context. The private case center and scoring-review route remain separate owned surfaces.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own the existing palette, Inter type, readable column, shared press feedback, and material fallback. Do not add another global theme or require version-26-only APIs.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) retain native window and current command ownership. The composer does not raise deployment targets or window minima.

## References and Direction Conflicts

- [Supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): borrow the dominant timer, direct sports hierarchy, and obvious safety access. Do not copy the two-column people layout, overlapping badges, purple/brown web controls, identities, faces, footage, or implied image rights.
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), especially Best practices and iOS/macOS platform considerations: scoped tasks, full-height composing where useful, one sheet at a time, draft-aware dismissal, a parent-modal Mac sheet, and interaction with other windows.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices: resizable windows, large/external displays, native keyboard and pointer interaction, menu commands, and active/inactive lifecycle.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Providing feedback: purposeful brief optional motion, platform familiarity, and cancellation without waiting. The specific 140–280-millisecond composer feedback is this feature's design choice, not an Apple timing requirement.
- Relevant installed SwiftUI engineering, SwiftUI animation, and HIG skills constrain semantic native controls, focus, available APIs, scoped state-driven motion, and accessibility. The selected dimillian/swiftui-ui-patterns context is a pattern reference, not authority to change the real service contract or deployment baseline.

The older F29-A wording permits side-by-side comparisons and describes iPhone as the first surface. The latest user direction requires both native platforms and large vertical players at every width; this child follows that direction. Its report form is not itself a matchup and deliberately contains no badge wall or player images. Any shared-parent reconciliation belongs to the coordinating owner, not this child.

The operating intake, approved retention disclosure, provider/legal-safety handling, published contact, and human review channel are real prerequisites, not decorative copy or assumed infrastructure. Unavailable prerequisites must be reported accurately rather than replaced by a local case receipt, production fixture, fake attachment uploader, no-op View case, or claimed App Store approval.
