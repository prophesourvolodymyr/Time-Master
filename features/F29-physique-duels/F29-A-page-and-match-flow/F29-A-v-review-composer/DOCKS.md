# F29-A-v — Review Composer

## Purpose and Product Boundary

One private native composer requests review of either the signed-in person's own safety decision or a specific competitive outcome. The entry point determines the mode before the composer opens. The two modes share a familiar form and receipt behavior but never share an ambiguous allegation category, editable target, or promise of the same remedy.

This is product context and a future implementation direction, not an implemented screen, accepted prototype, operational review service, or approval of every earlier F29 numerical proposal. The [page and match flow](../DOCKS.md) owns navigation and active-match presentation. [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns review authority and confidentiality; [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns competitive corrections; [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns access, retention, and deletion.

This component owns the scoped form, its local draft, submission uncertainty, acknowledgement, and withdrawal interaction. It does not create another case center, result screen, image viewer, camera setup, moderation dashboard, or account-recovery screen. Existing owners receive navigation to those destinations. Review is free and consumes no match allowance.

## Chosen Composition and Tradeoffs

The visual idea is a quiet review card within the same orange-and-near-black sports language, not a courtroom, chat thread, punishment celebration, or second judging arena. One heading names the actual task. A compact document-and-review symbol supports the heading without becoming a competitive badge. An original-decision card anchors the request, followed by a short reason list, an optional text field, the necessary private-review disclosure, and one primary send action.

A mode switch at the top is deliberately absent. An appeal about a clothing false positive and a dispute about a forfeit need different reasons, permissions, and consequences. Locking mode and target prevents a draft from silently becoming a nudity report, an accusation about the opponent, or a request against the wrong match. To use a different route, the person leaves this composer through the normal draft guard and deliberately enters the appropriate existing action.

The reference card contains safe text, never an automatically opened pose image, blurred body thumbnail, report screenshot, or preview of a removed explanation. That sacrifices visual comparison inside the form in exchange for safe intake after expiry, during a restriction, and without renewed exposure. Permitted result details remain available through their existing owner; reviewing never requires opening a gallery.

The form stays in one scrollable document rather than a wizard. Reason selection and optional context remain visible together, reducing navigation and making keyboard recovery predictable. Details about the rule, rubric, and evidence can expand inline. Required recipients, evidence consequences, current restrictions, and recovery instructions are not hidden to achieve minimal text.

## Mode and Target Contract

| Mode | Entry and visible title | Locked target and safe context | What review can address |
| --- | --- | --- | --- |
| Safety-decision appeal | Appeal decision from the person's capture rejection, removal, eligibility restriction, sanction notice, or own case detail | The original decision reference, date, affected own pose or capability, safe rule category, and actual restriction scope or duration when known | A false positive, misapplied rule, wrong item, missing relevant context, or unsupported restriction. A successful review may revise the notice or restore an authorized capability. It does not invent scores or restore expired photos |
| Competitive outcome dispute | Dispute result from the exact match detail, including judged win, loss, draw, forfeit, or no-contest | Match reference and date, safe permitted participant labels, original competitive outcome, the person's confirmed rating effect or No rating change, and judging version when one exists | Evidence handling, player assignment, arithmetic, rating settlement, forfeit or finalization, or respectfully recorded subjective disagreement. The confirmed result stays effective unless an authorized correction settles |

Only the person entitled to the decision or match can open a private editable request. A reporter cannot use this component to inspect or appeal another person's confidential sanction. A safety appeal does not disclose the reporting person's identity, complaint text, private declarations, sanctions against other people, or staff-only evidence. A scoring dispute does not require accusing anyone of prohibited content.

The target is not a text field and has no Change player or Change match control. The original reference remains distinguishable from a later decision revision or match correction. If the decision changes while editing, retain the note, show Decision changed, refresh permission, and provide Open decision through its existing owner. Do not silently retarget or send against an obsolete decision. Submission resumes only for a target the real service still permits the person to contest.

A safety restriction that blocks rated play must not block access to its own appeal. Expired media is not by itself an intake deadline. A genuine service-provided review eligibility limit is stated with its actual reason and date; the composer must not invent a universal twenty-four-hour appeal cutoff.

## Visible Content and Hierarchy

### Header and original-decision card

The task heading is Appeal decision or Dispute result. Cancel is visible while editing; Close is used for a receipt or noneditable state. There is no generic Send report title. Under the heading, a single current instruction says Choose a reason. Once a reason is chosen, that line becomes Add context if helpful. A receipt replaces the editing instruction rather than leaving an editable form under a success banner.

The original-decision card uses the shared elevated surface, a concise label such as Original decision or Match result, a readable date, and a selectable reference. An accessible Copy reference action copies only the permitted reference, not a body photo, the private note, a signed media link, or another person's account details. Long references can wrap and have a full accessible value.

For an appeal, the card gives the person's non-graphic decision reason and affected capability. A clothing rejection is described as a decision to review, not an established misconduct badge. A permitted nonsexual adult-man torso is not automatically labeled nudity. Private eligibility and attire information is available only where needed to explain that person's own notice; it is never added to the opponent's stage or the public badge rails.

For a dispute, the card distinguishes original judged results from forfeits and no-contests. No-contest says No rating change. A forfeit shows its actual rating effect but has no category scores or made-up judging version. A judged result uses confirmed units, signed Elo effect, and the original version. A concise current-state line can identify an existing review or correction without rewriting the original outcome.

An inline Decision details disclosure shows the authorized non-graphic notice, rule, or original scoring context. It never reproduces unsafe generated language as an unfiltered quote. No image, attachment well, drag-and-drop media target, capture button, photo picker, body description generator, or identity-document request appears in this composer.

### Required reason

Reason has a persistent visible label and starts unselected. Each reason is a full-width semantic choice with text and a selection mark. Choices wrap; none depend on orange alone. The two modes use different lists.

| Safety-decision appeal reason | Meaning |
| --- | --- |
| Allowed clothing or context | The decision may have missed permitted attire or nonsexual fitness context; review the existing private declaration and evidence where lawfully available, without asking for body-based gender proof |
| Wrong item or decision | The notice may be attached to the wrong pose, account action, or original decision |
| Restriction seems incorrect | The affected capability, duration, or rule application may be unsupported |
| Other decision concern | A safe review request not covered above; optional context remains optional |

| Competitive outcome dispute reason | Meaning |
| --- | --- |
| Evidence or pose handling | Missing, invalid, or mishandled original evidence, including an observable capture-integrity concern |
| Player assignment | The accepted evidence or original result may have been attributed to the wrong participant |
| Score or rating calculation | A suspected total, draw-boundary, duplicate settlement, or rating-effect error, not a request to type a replacement score |
| Forfeit or match ending | A suspected error in voluntary-forfeit, interruption, no-contest, or finalization handling |
| Disagree with judgement | Subjective disagreement, recorded without promising another model run or a replacement human score |
| Other result issue | A different competitive issue, without manufacturing a content allegation |

These are the proposed launch presentation categories for the real review contract, not a new local authority. Service-supported reasons and eligibility must be reconciled before implementation. If a required reason becomes unavailable, preserve the note, explain the change, and require an available choice; never remap it silently to a different allegation. Other does not make the optional note mandatory.

### Optional context

The next label is Context, with Optional stated visibly and accessibly. A short hint says Describe the issue. No new photos needed. The multiline field grows within the scrollable form and remains usable with selection, paste, dictation, undo, spelling tools, and accessibility text input. Do not autofocus it and cover the reason list on entry.

The real service's text limit governs validation. Display the limit and a matching count when approaching or exceeding it, not an arbitrary new local policy. An oversized paste is preserved for editing and clearly marked; do not silently truncate it. Blank optional text is valid. Errors explain the field and repair without deleting valid text or resetting the selected reason.

Notes are private case correspondence, not opponent messages, public comments, judging prompts, or a source of badge claims. Appropriate service screening may route concerning text to authorized staff without automatically discarding the underlying good-faith request. Do not tell the person to include identifying documents, exposed originals, unlawful imagery, or instructions to contact the opponent.

### Required review disclosure and action

Immediately before the send action, identify the actual service operator and authorized review recipients, state that the decision or match reference, selected reason, optional note, and minimum necessary existing lawful evidence may be used for private review, and say that no new photo is needed. Use the real operation's recipient information; do not invent a named reviewer, immediate staffing, or independent review that has not occurred.

The consequence line is mode-specific. An appeal says Review does not pause the match or remove a restriction. A dispute says The confirmed result stays in effect during review. Both make clear that sending does not rerun the judge or promise a reversal. If space is limited, wrap these lines rather than hide them behind an unlabeled icon.

Show the actual evidence availability and end date when the service can confirm them. Necessary lawful evidence for a benign case may be held for no more than thirty days from the originating received request, and less when no longer needed, under F29-D and F29-E. An appeal, duplicate, added note, or staff delay never renews that origin clock. If this is the first received benign case, its real receipt establishes that origin; a draft establishes no hold. A restricted hold is not an extension of the ordinary opponent gallery. Details may expand the full retention explanation, separate processor limits, and lawful exceptions, but cannot replace the visible essentials.

The primary action is Send appeal or Send dispute. It remains inactive until the target is authorized, a supported reason is selected, text is valid, required operational information is available, and no unresolved send is already in progress. A short adjacent explanation names the missing requirement. There is no consent switch authorizing extra images and no paid priority or faster-model option.

A visible secondary Report content route is used only when a person actually needs the existing safety-report flow. It explicitly leaves this review composer, honors its draft guard, and opens the correct contextual owner after dismissing the current sheet. It does not automatically send, copy a private note into another mode, reopen a hidden image, or treat an outcome dispute as a nudity report.

## Native iPhone Composition

Use a native large-height sheet for this scoped text-composition task on iOS 16 and later. The sheet opens directly at useful writing height, not at a half-height crop that buries reasons or required consequences. Its top toolbar has Cancel while editing and the mode title. The scrollable document contains the original-decision card, reasons, optional context, and disclosure. The bottom safe action area contains the single send action. Existing page-navigation and keyboard clearances determine its geometry; no fixed screen coordinates or guessed bottom spacer are introduced.

The send control and Cancel remain reachable when the keyboard appears. Scroll the active field or validation message into view without jumping the entire form on each keystroke. Do not compress the disclosure into unreadable footnotes. At the largest text sizes, the action area can grow and the document scrolls; short landscape windows use the same readable order. Review has no mandatory portrait-only dependency.

Standard sheet dismissal is available for an empty or acknowledged request. A meaningful unsent draft invokes Keep draft, Discard draft, or Continue editing through a native confirmation. An active-match composer must never dismiss into unannounced camera acquisition. On such entries, label its safe return Return to match rather than implying the match ended; the active host follows its explicit capture-resume behavior.

If opened from another modal case or notice, the presentation owner transitions that same presentation into the composer rather than stacking a sheet on a sheet. The acknowledgement also occupies the same presentation. View case replaces or closes it into the already-owned case detail route.

All primary, cancel, return, and safety actions follow the existing forty-four-point iPhone interaction convention. Small sports iconography cannot reduce the action's hit area or accessible name.

## Native macOS Composition

Use a real native macOS 14-or-later window-attached sheet for a single scoped request. Keep the normal Tmax title bar and traffic lights. Do not build a web dialog, Catalyst phone frame, floating custom overlay, new review window type, or independent inspector architecture. A readable-width form, informed by the existing shared readable column, uses available parent-window geometry and is not stretched across an external display.

The sheet heading and original-decision card are followed by a native single-selection reason group, a normal multiline text editor, and the same required disclosure. Cancel and Send appeal or Send dispute sit in the native bottom action row, with the send action visually primary. A receipt uses Done and View case instead. Use native desktop density, pointer affordances, selection, context menus for allowed text, and clear keyboard focus rather than inflating every control to a phone-sized pill.

At the existing 800 by 600 app minimum, the sheet remains within the available content area and its form scrolls independently of its action row. Do not raise the app-wide minimum to make a fixed-height form fit. Laptop, large desktop, full-screen, and external-display use keep one comfortable form column; extra width is not a reason for side-by-side players, duplicated reason columns, or a blank imitation dashboard. Live resizing and moving between displays preserve field selection, draft, scroll position, and focused control. Layout can reflow without resending a request or regenerating media.

This is a modal task for its parent window, not an app-modal lock: other app windows remain usable. There is one editable presentation for the same account, target, and mode on the current device. Opening that request again brings the existing presentation forward where possible, or shows its current pending/received state; it does not create a competing draft or another send authority. A secondary window never starts another match, camera, or allowance charge. Across devices, the service resolves duplicate review requests to the canonical case.

Keep Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O in their existing app command roles. Do not hijack them for review actions. Return and Space activate only the focused semantic control. Return in the note inserts a newline; Space types a space. Neither key is a global submit or capture binding. No default Return action can send while a person is composing or using an input method. Tab and Shift-Tab traverse the reason group, context editor, details, safe actions, and footer according to native keyboard navigation settings; the reason group supports its normal arrow-key selection.

Escape first cancels text composition, a menu, or a disclosure-specific transient interaction as appropriate. Otherwise it uses the same state-aware dismissal and draft guard as Cancel or Return to match. Cmd-W and Quit honor meaningful unsent work and real active-match consequences through the existing lifecycle owner where the platform permits. The composer does not equate window close with confirmed review withdrawal or voluntary forfeit. Force quit cannot be prevented or described as a confirmed voluntary action.

## Active Match, Camera, and Battle Hierarchy

A rejection appeal can be opened during a live match. Stop camera acquisition and new still capture immediately on entry, and shield the preview rather than leaving a camera running behind the form. This does not itself withdraw consent, submit a forfeit, reopen an accepted pose, grant a retake, or tell the service that review was granted. Previously authorized service work follows the existing privacy contract; the composer cannot expand its permission.

In this active state, a compact, clearly labeled live-match strip above the form keeps the real timer as its top visual anchor. The countdown remains service-owned, in stable monospaced geometry, with the current stage and a concise Camera stopped line. Return to match and the state-aware Exit match remain reachable without dismissing a draft or scrolling to the end. Stop remains available whenever any host capture has not yet acknowledged stopping; it takes effect immediately and never waits for a request or transition. An exit confirmation belongs to the existing match owner, not a new review-specific forfeiture policy.

Do not pause or reset search, the three-second start, the ninety-second capture deadline, retakes, the twenty-second reconnect grace, or the judgement deadline when opening, typing, sending, waiting for a receipt, or closing. The timer changes only to match real service stages. A draft has no evidence hold and no extra capture or review countdown. After terminal finality, replace the live strip with the actual final-state label; do not run a decorative timer or show a frozen countdown as live.

If the match ends while editing, retain authorized text and the original decision reference, update the current-match context, and keep intake available where the service permits. A timed-out or safety-aborted match can remain no-contest even if the clothing appeal later succeeds. Return to match restores the same authoritative state first; camera resume is explicit, never automatic from dismissing a sheet.

The composer is not a battle composition and does not insert tiny competing participant cards beside its fields. Wherever the underlying battle stage is present, including a visible parent on Mac, its ordering remains the real timer, then all permitted public identity and badge rails grouped by owner, then two LARGE vertically stacked players, You above Opponent. Both players stay vertical at every width. All public badges wrap above the players; no three-badge cap, clipped rail, hidden +N, auto-scrolling ticker, badge over anatomy, or hover-only disclosure is introduced. In a short window or at large text the stage scrolls instead of shrinking people. Timer and safe actions remain reachable. Authorized evidence uses equal, aspect-fit treatment without cropping or warping.

The underlying stage may be shielded or inert while the sheet is open; the composer does not duplicate its badge rails or create an alternate matchup. Country remains an optional manually selected region with accessible naming and a neutral missing state. Country and badges are public identity context owned by F29-F, never review findings, proof of age, identity verification, or judging inputs. A private appeal status is not a public battle badge.

Camera permission is not needed to appeal or dispute. Denied or restricted iPhone permission, Mac TCC denial, no camera, external-camera loss, and Continuity Camera disconnection must not block the form or trigger a new system prompt. Active-match context may honestly say Camera unavailable. Return uses the existing camera owner and remaining deadline, never a file-picker or prerecorded rated substitute.

On lock, interruption, app backgrounding, Mac inactivity, hiding, or minimization, stop acquisition and shield body media and private review text immediately; no dismissal animation delays protection. Camera or screen permissions are not requested to manufacture evidence. On foreground, verify the same signed-in identity, receipt state, current authorization, and authoritative match before removing the cover. Restore no opponent gallery automatically. If both final sets were already received, the service may finish the same judgement while the client is away.

## Draft, Submission, Receipt, and Recovery States

| State | Visible content and permitted actions | Meaning and recovery |
| --- | --- | --- |
| Resolving target | Mode heading, safe known reference, Loading decision, Cancel or Close | No stale allegation, prior account data, editable target, or guessed send eligibility. Fetch the authorized decision and any canonical existing request |
| Editing, nothing selected | Original-decision card, reason list, optional context, inactive send action | Nothing has been requested. Choosing a reason enables send only after all other real requirements are valid |
| Editing, ready | Selected reason, retained optional note, required recipients and consequences, Send appeal or Send dispute | Explicit send is the only action that requests receipt. Selection, navigation, or leaving the sheet is not submission |
| Missing reason or invalid text | Specific inline instruction linked to the field, preserved note, normal Cancel | On an attempted accessible submit or real service validation failure, move focus to the first actionable error. No generic shaking error or silent reset |
| Offline, never sent | Not sent, protected text-only draft, explicit Retry when reachable, published support access | No server case or evidence hold exists. Do not autosend on network return or app launch |
| Sending | Sending appeal or Sending dispute, ordinary indeterminate feedback, no repeated send or mutable outgoing text | Freeze the submitted reason and note while the outcome is unresolved. Close, Stop, active-match exit, and other safe navigation remain available. Do not claim a human is already reviewing |
| Definite nonacceptance | Not sent with actual safe reason, preserved draft, Repair or Retry as appropriate | Reuse the same intended request safely when supported. A transient failure is not a successful receipt; a permission error requires refreshed authorization |
| Connection lost after possible acceptance | Receipt not confirmed, Check status, Close | Preserve the same submission identity and original text within its permitted local lifetime. Check the existing operation before any resend. No new case, new vote, evidence copy, or fresh hold origin |
| Existing receipt found or retry acknowledged | Appeal received or Dispute received, canonical reference, actual received time, current status, Done, View case | The same logical request resolves once. A late success for an earlier transmission cannot create another acknowledgement or move received time to now |
| Duplicate or another device already filed | Request already received and canonical case reference, View case, Close | Do not resend a changed reason as a second appeal. Safe additional information uses the existing case owner only when the real service allows it; it is never appended silently |
| Target unavailable locally | Unable to load decision, Retry, Close, published support | Do not accept an arbitrary pasted match as proof of ownership. A known authorized nonmedia reference can remain visible, labeled with its freshness |
| Target unauthorized, another account, or removed by deletion | Private request unavailable, correct account/support route, Close | No private body media, note, notice, or case details leak. Account recovery belongs to its existing owner |
| Media expired, removed, hidden, blocked, or sharing withdrawn | Exact safe unavailability reason in the reference context; ordinary permitted review fields | Existing nonmedia records can support intake. Do not restore media, bypass a hide/block, or claim a visual review is still possible |
| Review eligibility changed or original decision revised | Decision changed or actual service restriction, retained permitted draft, Open decision or Refresh | No stale-target submission or automatic mode change. Do not invent a reopened appeal after the service says it is closed |
| Intake unavailable or limited | Review temporarily unavailable, retained permitted draft, actual retry guidance and published operator contact | No fake receipt or promised queue position. Safety help remains reachable; a rate limit is not a local permission to create another account or new target |
| Sent and queued or in review | Received, Queued, In review, or Appeal in review only when confirmed, receipt reference, View case | A status is not a percentage, staffed-attention guarantee, or timer to reversal. Current restriction/result remains effective |
| More safe information requested | Actual safe request summary and Continue in case | The already-owned case detail handles the response. No media attachment or new original case is created |
| Original decision stands | Decision stands, actual private reason, View case, Done | Upheld refers to the original decision, not a successful reversal. No automatic replay, loss deletion, or repeated appeal loop |
| Safety decision revised | Decision revised with actual changed own scope and effective timing, View case | Restore only what the service authorizes. No expired gallery, retroactive score, or automatic AI-judged win |
| Competitive correction authorized but settling | Rating updating after review and labeled last confirmed outcome/rating context, View case or existing match detail | F29-C settles both accounts coherently. The composer neither computes a reward nor presents mixed old/new totals |
| Competitive correction settled | Result corrected with canonical review reference, View updated result, Done | The existing result owner shows original/corrected records and actual settlement. Later matches are not rejudged and a correction is not replayed on reopen |
| Closed or inconclusive | Closed with the actual safe reason, including insufficient retained evidence when applicable | Missing photos are not evidence of a winner, innocence, guilt, or automatic no-contest. No invented scores or restoration offer |
| Status stale or refresh failed | Last confirmed status and update time, Unable to refresh, Check status, Close | Do not turn old In review into a new receipt or silently reopen the editing form |
| Sign-out, account switch, or account deletion | Privacy cover followed by the correct account or unavailable state | Clear that account's unsent drafts and sensitive surface. Never let a late response render under the next account |

A text-only unsent draft can be retained in protected current-account storage on the current device for at most twenty-four hours from its creation, or until discard, sign-out, or account switch if earlier. It contains only the necessary target reference, explicit mode, selected reason, optional text, and minimal recovery context, not pose pixels or screenshots. Editing or opening does not silently renew this lifetime. A restored draft remains Not sent and requires an explicit send.

Keep draft, Discard draft, and Continue editing are meaningful choices only when unsent work would be lost. A blank form closes without a warning. Keep draft is a local preservation choice, not evidence preservation or a notification to staff. If the local draft expires, clear its text and say Draft expired when the same request is revisited; do not promise it was sent.

Closing a sending or uncertain request does not cancel a transmission already accepted by the service. Reopening the same target reconciles that operation before allowing another submission. If local text has expired, status can still be checked using the minimal authorized request reference; there is no silent reconstruction or automatic resend. A service-confirmed absence can permit an explicitly composed new attempt. No unresolved operation is presented as an existing server case without acknowledgement.

The receipt remains on screen until the person chooses Done, View case, or another deliberate navigation. It includes the canonical reference, real received time, actual current status and last-updated context, and published support availability. Published staffed hours, time zone, and response expectations come from the real operation, not a baked-in two-day promise or a seven-day countdown. A receipt is an acknowledgement, not a completed human review. Notifications, if separately allowed, are generic and do not contain the note, accusation, pose, outcome, or restriction.

## Withdrawal of a Received Request

A received request has Withdraw request only while the real case permits it. The action is distinct from Cancel draft, Close, Delete account, Withdraw sharing, and Forfeit and leave. It does not remove a restriction, change a result, unblock a player, restore hidden media, or erase all correspondence.

Use a native confirmation with Withdraw request and Keep request. Explain before confirmation that the person will no longer pursue this request, but authorized safety or legal work and a justified existing hold may continue. The current decision remains effective unless separately revised. A confirmed withdrawal says Request withdrawn, retains the canonical receipt for permitted private history, and provides Done or View case. No confetti or disappearing evidence animation suggests erasure.

While withdrawing, disable repeated withdrawal but keep safe navigation available. If the connection is lost, show Withdrawal not confirmed and the last confirmed case state, with Check status; do not relabel the case Withdrawn locally. Retry reconciles the same requested withdrawal. If the review closes or a decision settles first, show that actual outcome and explain that withdrawal was not applied. Never undo an already settled correction to simulate a successful withdrawal. A new appeal or reopening is offered only when a real authorized service action permits it, not through an automatic new-request shortcut.

## Keyboard, Focus, and Accessibility

On open, move accessibility focus to the task heading, or to the active timer's labeled context when a continuing deadline is the immediate concern; then expose the original decision and reason group in a stable reading order. Do not automatically focus a text editor or announce every timer tick. A normal traversal is heading and live context, original decision, details, reason, optional note, required disclosure, send, and secondary actions. Persistent safe exit controls remain discoverable even while the document scrolls.

Reason choices announce the mode-appropriate label and selected state. The note announces Optional. The send button's accessible name includes its mode and, where helpful, its target. Copy reference confirms copying without reciting a long identifier. There are no anonymous icon-only controls, hover-only meanings, swipe-only actions, forced long presses, or color-only status. Voice Control and Switch Control can select a reason, edit text, submit, cancel, keep/discard a draft, view a receipt, and request withdrawal.

Validation preserves the selected reason and text. Move focus to a safe error summary or affected field once after explicit validation, not on every keystroke or background refresh. A confirmed receipt moves focus to Appeal received or Dispute received. A withdrawn or revised state gets one concise announcement. Background status refresh must not steal the insertion point or interrupt dictation. More information and final decisions remain readable without a timed auto-dismiss.

On dismissal, restore focus to the original Appeal decision or Dispute result control. If it no longer exists, use the safe current notice, case heading, match status, or privacy placeholder, not a hidden image tile. Closing into an active match never focuses a capture control that can fire automatically. Return and Space retain normal text-input meaning on both platforms.

Use shared Inter typography with semantic scaling, readable contrast, wrapping labels, and natural document growth. Do not copy Ranked's Dynamic Type clamps, minimum text scaling, fixed duel heights, or tiny secondary-ink choices when they make required text illegible. Increased Contrast adds appropriate boundaries; Reduce Transparency gives an opaque readable surface. All required disclosure and actions remain accessible at the largest supported text sizes and with desktop accessibility navigation.

## Animation Rules

Motion conveys selection and confirmed state, not a favourable verdict. The composer is deliberately calmer than the battle stage, while still using tactile shared press feedback and a small receipt transition.

| Trigger | Concrete motion and timing | Interruption and accessibility behavior |
| --- | --- | --- |
| Open or close composer | The native sheet transition on each platform; do not layer a second custom slide or matched-body zoom over it | Use native reduced-motion behavior. Camera stop, privacy cover, and authoritative state changes occur immediately, not after presentation completes |
| Press a semantic action | Existing shared response-0.24, damping-0.88 press spring; Mac pointer feedback stays restrained and native | Release never performs another action. Reduced Motion removes added scale; disabled actions do not pulse |
| Select another reason | Selection mark and small orange leading accent change over 160 milliseconds; the text and field position stay stable | A newer selection replaces the old one immediately. No global form animation, moving list, or automatic submit; use immediate state or at most a short opacity change with Reduce Motion |
| Expand decision or evidence details | The inline disclosure expands within the document over 180 milliseconds without moving a body image or footer | Reverse from the current state if interrupted. Preserve field focus and scroll anchor; reduced motion uses immediate layout and a short opacity update |
| Sending begins | Replace only the send label and status symbol over 160 milliseconds with the normal indeterminate indicator | No artificial minimum wait, success delay, or analysis percentage. A fast response is shown immediately. Static Sending text remains sufficient under reduced motion or energy constraints |
| Receipt confirmed for the first time | The form gives way to the receipt within the same presentation over 280 milliseconds; the receipt document symbol makes one small 1.00-to-1.04-to-1.00 settle within the same interval | Real receipt data and navigation are available immediately. Reopen/duplicate/status refresh never replays an award. Reduced Motion uses a brief opacity change of no more than 120 milliseconds, with no travel or scale |
| Validation, failure, or receipt uncertainty | The relevant text and icon change over 160 milliseconds; no shake, red screen flash, or spinning reference | Error meaning is immediate. Do not move the caret or erase context. Reduce Motion can replace the state without animation |
| Real active-match timer tick | Only the stable timer digits update over approximately 180 milliseconds; the form, player geometry, and badge rails do not relayout | Read from authoritative deadlines; no extra review timer. Do not announce each tick. Reduced Motion uses an immediate number change |
| Withdrawal confirmed or actual case status changes | Status symbol and text crossfade over 180 milliseconds; no ceremonial body/score transition | A later authoritative state supersedes the current one without queuing animations. Announce a meaningful milestone once. Reduced Motion uses immediate state or short opacity |
| Safety hide, permission loss, sign-out, inactivity, or deletion | Privacy cover and sensitive-content removal are immediate | Never crossfade through an unsafe frame or wait for a spring, receipt transition, network response, or human review |

No ambient loop is added to the composer. A visible native sending indicator is the only continuous activity feedback and is never treated as review progress. At most one focal transition is active; an existing parent-stage ambient effect is paused while obscured by the sheet. No pulsing badge wall, body scan, camera shader, rank roulette, confetti, punishment celebration, or loser shake is introduced.

Pause decorative work while offscreen, covered, inactive, minimized, or backgrounded. Low Power Mode and elevated thermal conditions remove optional scale/disclosure travel and leave truthful text and essential native feedback. No per-frame network or provider request, evidence decoding, camera reconstruction, font measurement, or whole-stage invalidation is allowed for a reason change, text edit, timer tick, or receipt animation. Clocks and service review continue independently of animation. On return, render the latest confirmed state without replaying missed ticks or status transitions.

## Privacy and Service Invariants

- Only authorized service acknowledgement creates Received. Idempotent submission, duplicate discovery, canonical status, and withdrawal are real shared service capabilities, not optimistic client labels.
- No appeal or dispute calls a new judge, changes the model or rubric for an old match, supplies a custom judging prompt, or rerolls until the person wins. The UI worker's model assignment is unrelated to the in-app judge.
- The original result remains effective while review is pending. A supported correction is separately authorized and audited under F29-C, with exactly-once coherent consequences. The composer does not calculate or award Elo, placement, a refund, a streak, a badge, or a replacement body score.
- A successful safety appeal may revise an unjustified restriction; it does not automatically recreate an aborted rated match, regenerate deleted media, infer eligibility from appearance, or expose another person's report.
- Ordinary raw media and all derivatives expire within twenty-four hours of finalization under F29-E. Held lawful case evidence is restricted to authorized review, not a participant gallery. The existing originating hold deadline is never renewed by this UI.
- Expiry, block, report quarantine, removal, consent withdrawal, and account deletion take precedence over stale reference data. Neither a cached image nor an old signed link is a review shortcut. A score disagreement does not automatically hide media or report the opponent; existing protection choices remain in force.
- No face, age, sex, gender, health, body-fat, muscle-mass, identity, or location inference is added. No new microphone, Photos, camera, location, or screen-capture permission is required. Country, badges, UI chrome, private notes, and account identity do not enter judge images or judging context.
- Review submission, draft cancellation, receipt dismissal, and request withdrawal are separate from sharing withdrawal and account deletion. Privacy and safety help stay reachable through existing owners, without forcing continued capture or an appeal first.
- Suspected unlawful or exploitative content uses F29-D's restricted legal-safety process, not a routine attachment. Do not ask the person to download, screenshot, forward, email, or reupload it. Published urgent-help access must not imply that this form is an emergency service.
- Exercise-duel and Practice image privacy, AI Coach provider selection, general workout records, app-wide commands, and saved navigation remain unchanged.

## Dependencies and Review Boundaries

The [F29 parent](../../DOCKS.md) and [F29-A](../DOCKS.md) define the shared native journey. [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) defines fixed judging versions and prohibits appeal rerolls. [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) defines original finality and separately audited corrections. [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) defines review reasons, operating authority, case confidentiality, and lawful safety handling. [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) defines current account authorization, camera lifecycle, drafts, receipt recovery, access expiry, and retention.

Shared identity/badge presentation belongs to F29-F; this composer only preserves its truthful public rails when a battle stage is present. Shared case-center, contextual report, result/correction detail, camera, active-match exit, and privacy routes remain with their designated owners. Do not create duplicate screens or a second review client to make this view appear independently complete.

Implementation requires explicit implementation authorization and real shared foundations/contracts that are implemented and human-reviewed: authenticated account and target access, mode-specific eligibility and reasons, note validation limits, canonical submission/receipt reconciliation and duplicate handling, actual case status and permitted withdrawal, operational recipients/support, evidence availability and originating expiry, and active-match/camera lifecycle ownership. A page preview or locally fabricated receipt cannot substitute for any of them. [CYCLES.md](../../../../CYCLES.md) owns implementation planning and human-review tracking.

The approved timer, complete rails, and large vertical-player composition supersedes older F29-A wording that allowed balanced two-column battle comparisons. This child applies the approved direction without rewriting shared documents. Detailed original numerical policies remain subject to their owning area and human review; this composer does not settle them by choosing a new local default.

## Files and Ownership

- This document owns the review-composer product experience. The [future implementation brief](../../../../prompts/F29-physique-duels/F29-A-v-phase-1-review-composer.md) owns the prospective connected work slice.
- Prospective TimeMaster/Views/Physique/PhysiqueReviewComposer.swift owns the native mode-locked form and its in-place receipt/withdrawal presentation, reusing shared controls rather than adding another design system.
- The reviewed shared Physique presentation model and case service in TimeMaster/Models/ and TimeMaster/Services/Physique/ supply authorized state. Their exact existing names must be discovered at implementation time; this specification does not claim those files already exist or authorize an independent backend authority.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own the near-black surfaces, orange action language, scalable Inter typography, shared spacing, materials fallback, and press feedback.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) is a visual-pattern reference, not permission to copy text clamps, fake levels, or exercise-specific state.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) own the normal native Mac window and existing commands. This component does not raise deployment targets or the app-wide minimum window size.

## References

- [Supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy/directness reference: the timer's prominence and immediate actions are useful, but side-by-side people, face footage, purple/brown web pills, overlays on bodies, and implied image-publication rights are not adopted.
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), particularly Best practices, iOS/iPadOS, and macOS: a scoped form uses one native presentation; writing gets useful height; Mac modality belongs to the parent window and other windows remain available. The specific mode-locked form and text-only reference are product decisions.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices: native resizable windows, comfortable information density, keyboard/pointer input, and familiar system command behavior inform the Mac composition, not a stretched phone screen.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback: purposeful, brief, optional, interruptible feedback informs the restrained selection and receipt motion. The exact timings above are proposed product choices, not Apple-mandated durations.
