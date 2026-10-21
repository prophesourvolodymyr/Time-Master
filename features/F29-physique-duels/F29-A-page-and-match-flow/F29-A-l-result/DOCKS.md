# F29-A-l — Result

## Purpose and Scope

This surface delivers the service-confirmed conclusion of one Physique Duel: what happened, both accepted totals when a comparison exists, and the signed-in person's own earned-rating consequence. It remains a respectful sports result, not a judgement of personal worth, a body-transformation prescription, or an invitation to publish someone else's images.

This is product context and a future implementation direction, not an implemented or human-verified screen. It follows the user's native iPhone and native macOS direction in [F29-A](../DOCKS.md): players remain vertically stacked at every width. Numerical judging and rating defaults remain subject to the reviewed policies owned by [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) and [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md); this result design does not approve or recalibrate them.

This child owns result composition, its state-dependent copy, its action hierarchy, and its use of the shared counters, identity rails, participant panels, and rating presentation. It does not create another judge, camera session, badge authority, pose viewer, scoring-review screen, safety form, history list, or new-search destination. Those routes remain with their shared F29 owners.

## Chosen Composition and Tradeoffs

The composition is a final sports scorecard within the same vertical battle stage. The top clock retains spatial continuity; a decisive outcome and compact receipt communicate the result before any decorative motion. Complete public badge rails precede two equally large portrait panels, You above Opponent. Deliberate detail and safety actions accompany one prominent next-search action.

An automatic photo celebration is rejected because finality is not permission to open body evidence. Both player panels initially use the shared neutral athlete presentation, with an authorized public avatar only where the shared identity treatment permits one. They never substitute the local camera's last frame, an early opponent thumbnail, an automatically uploaded local profile photo, or the reference screenshot's people. Actual selected stills appear only in the separately owned, intentionally opened View poses route.

A compact, permanent two-player scoreboard is also rejected. Both accepted totals are immediately available in a small summary, but the participants themselves keep the large vertical stage. The tradeoff is deliberate scrolling in short windows and at large text sizes, rather than smaller people, hidden badges, or a side-by-side Mac matchup.

There is no winner's podium, shrinking or shaking loser, dimmed opponent, confetti wall, body-scanning effect, or taunting caption. Outcome text and a restrained mark in the panel's exterior chrome distinguish a valid winner. Both portrait wells retain equal dimensions, fit treatment, contrast, and visual dignity.

## Exact Reading and Visual Hierarchy

The native navigation or window toolbar contains Close or the conventional return action and a visibly labeled Report action. The content stage then follows this order:

1. The existing top match-clock anchor, in its truthful terminal state. It remains above the result and the badge rails.
2. One clear outcome heading: Won, Lost, Draw, Won by forfeit, Forfeited, or No contest. A small correction or saved-state notice qualifies the heading when necessary; it never replaces it with an ambiguous icon.
3. Two compact, vertically ordered total rows, You then Opponent, for a valid AI-judged result. Each has the accepted one-decimal total, an explicit points-out-of-100 unit, and its participant label. These are numbers, not two side-by-side player cards.
4. The person's own Physique Elo receipt: before, signed change, after, and the actual placement or tier effect. The unit is always Physique Elo, not bare Elo, body score, exercise rating, or a local display level.
5. One concise, neutral explanation of the selected pose-set result, with the judging-version label and a short subjective-score notice. Longer category evidence belongs behind Breakdown.
6. Clearly labeled Breakdown and, when appropriate, View poses actions. Match details replaces Breakdown for non-scored outcomes. Report remains available without entering either route.
7. The complete You identity and public-badge rail, then the complete Opponent rail. Both rails are above both large player panels. Their owner labels remain visible when a long collection wraps.
8. Two large vertically stacked participant panels, You first and Opponent second. Their labels and optional accepted total sit in exterior card chrome, never over a face, limb, or evidence frame. Repeated totals are a visual association, not a second accessibility reading of the same receipt.

The single prominent next-step action is Find another opponent. It stays in the measured safe action region outside the scrolling stage. The rails and player panels can scroll; the top clock, Close, Report, and safe next-step access remain usable. The clock need not be a giant pinned banner, and the complete badge collection is not an unbounded pinned wall.

### Terminal clock truth

The result never starts a new countdown. If the authoritative match snapshot supplies the clock's terminal value and meaning, retain that exact value with a clear label such as Capture ended; an early forfeit must not be displayed as a fabricated zero. A frozen value is not labeled Time left.

If the service does not provide a meaningful terminal numeral, the same clock anchor shows the clock symbol and Finished. It does not invent elapsed time, force 00:00, restart the capture timer, or count down a five-second result promise. A judgement timeout is described as such only after the service confirms the no-contest. While finality is unknown, the existing waiting or restoring surface owns the real clock and recovery semantics; this result surface does not manufacture a terminal state.

### Shared visual language

Use the existing near-black background, dark surface hierarchy, white primary ink, readable secondary ink, Inter display and body families, orange primary actions, shared spacing, and shared card and press treatments. Do not add a purple web-pill system, a parallel theme, or a new global font scheme. Increase-contrast and opaque-surface variants remain readable.

Outcome and totals are the strongest content after the top clock. Supporting prose remains ordinary readable text rather than a tiny legal footnote. The own-rating receipt is a compact, clearly scoped band rather than a competing second scoreboard. The orange accent does not turn every badge into a call to action. There is no color-only distinction between gain, loss, draw, no-contest, stale data, or correction.

## Totals, Own Rating, and the Expert Counter

### Accepted totals

Both totals belong to the same service-confirmed accepted judgement and revision. Show one decimal place, including a legitimate zero and its decimal. A missing, rejected, unobservable, unsafe, or unconfirmed score is not zero. Do not independently recompute category weights, choose a winner from rounded display text, infer an opponent's score from a margin, or accept a provider's free-text winner over the settled service result.

Breakdown exposes both accepted category sets, rubric weights, the exact total gap, judging version, and safe supporting explanations. The current proposed policy draws below a three-point gap and has a winner at exactly three points; the result consumes the service's reviewed policy and outcome rather than encoding a second local boundary. A draw does not imply equal displayed totals or unchanged Elo.

### Own rating receipt

The receipt describes this match's actual rating transaction, not the opponent's private transaction or a presumed equal-and-opposite transfer. Before, signed change, and after are readable together. A zero effective change is written as No change with the confirmed value, not disguised as a gain. Loss is identified in text as well as by a minus sign. Large AI score margins do not create a larger rating animation or additional reward.

For a first rated result, the before label reads Unplaced rather than presenting the hidden pairing seed as an earned rating. Show the first confirmed earned after value and the actual signed transaction change. An explanatory seed, if needed, belongs in rating-policy detail, not a public pre-match award.

During provisional placement, show the confirmed completed count and required count with Provisional. Five is the current F29-C proposal, not a number inferred from local history. No placed crest or predicted tier appears early. The result completing placement says Placement complete and shows the actually settled Physique tier. A threshold crossing names the old and new tier without exaggerating it into a population rank. A later correction can remove placement or lower a tier; the presentation follows the current effective service state.

When opened from history after later matches, this match's before/change/after values are explicitly historical. They are not labeled Current rating. Any separately supplied current public or own summary is temporally labeled and does not rewrite the match receipt. Opponent identity includes only permitted match-time Physique rating and placement context; it never exposes the opponent's private Elo adjustment or substitutes a later public rating for the pairing's original value.

### Expert counter composition

Use the shared F29 expert counter, rather than building result-specific digit rolling. The accepted score has no earlier accepted starting value. Its reveal therefore exposes the actual final numeral with the counter's bounded reveal treatment; it does not count up from an invented zero or display random intermediate scores. Both accepted final totals, labels, and units remain available immediately to reading and accessibility.

Own Elo may transition between a real earned before value and its settled after value, with the signed change and final after receipt already readable. The first unplaced result has no earned numeric before endpoint, so it uses reveal-only treatment. No-contests have no score-counter reveal or rating-award motion. Rated forfeits can show the actual own Elo transition but never synthetic physique counters. Saved results and correction receipts use static final numbers or a short content change, not another award.

The counter's visual work cannot gate actions, determine the result, send requests, charge an allowance, apply a rating effect, unlock a badge, or delay a privacy shield. A duplicate update or a second window cannot replay a fresh award. If the shared expert component cannot express these truthful modes, that is a shared prerequisite to resolve before shipping this result, not permission for a second number system.

## Complete Identity and Badge Rails

F29-F, located through the [F29 feature index](../../DOCKS.md), owns which identity and badge facts are public, their trusted source, and their corrections. This screen composes that product; editable local cosmetic badge previews are not competitive achievements or identity verification.

The You rail and Opponent rail each contain the permitted handle or safe placeholder, optional manually selected country or region, permitted match-time Physique rating and placement context, and every currently authorized public battle badge. A flag appears beside the handle with its accessible region name. Missing or unsupported country uses the shared neutral treatment. No location is guessed from GPS, IP, locale, face, or image background, and country never becomes a judging or rating signal.

Every earned launch badge is represented: First Bell, Placed, Ten Rounds, and Three Straight where actually held. The current placed tier and truthful public current streak also appear when available. Placed and the placed tier may form one clear compound presentation, not two contradictory claims. Keep the shared canonical ordering, with placement/tier and current streak clearly distinguished from historical milestones. Do not let unlock arrival reorder the whole rail while someone is reading it.

First Bell and Ten Rounds depend on effective valid AI-judged results, not forfeits or no-contests. Placement follows the rated-result policy, which can include eligible forfeits. Three Straight is a historical achieved milestone; it is not a claim that today's streak is three. The current streak follows F29-C, including eligible opponent-forfeit wins and the difference between a draw and a no-contest. The client never awards these by counting locally visible history rows.

Rails wrap into as many readable rows as necessary. There is no three-slot cap, +N shortcut, horizontal clipping, moving ticker, hover-only name, or hidden selection of the most flattering badges. The full collection remains above the panels in document order even when scrolling is necessary. Each badge can expose the shared concise meaning through a real accessible action; ordinary names and identity remain discoverable without hovering.

Temporal scope must be explicit. Match-time identity and rating are historical; a refreshed badge or current-streak set is labeled as current public information. If only an authorized saved badge snapshot is available, label its freshness rather than calling an old streak current. Unknown badge data says Badges unavailable; it does not claim no achievements. A confirmed empty collection may use the shared neutral empty treatment without a shaming empty trophy.

A New marker is permitted only for the signed-in person's service-confirmed unlock attributable to this result. Reopening history never re-unlocks it. If badge confirmation arrives later, quietly update the rail and announce the confirmed unlock once without restarting the result reveal or pushing focus away. Corrections remove invalid current Placed/tier/streak claims and other invalidated entitlements when the trusted source says so. An explanation of the person's own badge revision is neutral, never a public allegation about the opponent.

A blocked, deleted, restricted, or unavailable opponent receives the policy-appropriate safe identity and badge placeholders. Complete badges means every badge still authorized for this viewer, not permission to retain a deleted handle, expose an unlisted field, or bypass a block.

## Visible Copy and Outcome Variants

| State | Main wording and receipt | Detail and gallery behavior |
| --- | --- | --- |
| Valid scored win | Won; both accepted totals; actual own Physique Elo and placement/tier effect | Concise neutral evidence summary; Breakdown and eligible View poses |
| Valid scored loss | Lost; the same complete totals and own-rating receipt | Same visual dignity, access, and action hierarchy as a win; no insulting advice or loss shake |
| Valid scored draw | Draw; both accepted totals; actual signed own Elo effect | Explain the applicable draw band concisely; do not say identical bodies or promise zero Elo change |
| Eligible opponent forfeit | Won by forfeit; actual own Elo and placement consequence | Match ended by opponent forfeit; No physique scores; Match details, no pose gallery |
| Own eligible forfeit | Forfeited; actual own Elo and placement consequence | You ended the match by forfeit; No physique scores; no punitive invented score or gallery |
| Confirmed no-contest | No contest; No Elo change; placement and rated count unchanged | A safe reason; allowance restoration only when confirmed; Match details, no pose gallery |
| No-contest, allowance reconciliation pending | No contest; No Elo change; Allowance update pending | Check status retrieves the same allowance state; do not promise an extra slot or restore locally |
| Result retrieval still pending | Awaiting confirmed result or Restoring result | No guessed winner, zero-filled scores, awarded Elo, completed badge, or local timeout verdict; recover the same match |
| Failed initial retrieval without an authorized saved result | Unable to load result, Retry, and Close | Not an empty match and not a no-contest; Report or support remains available using safe match context |
| Confirmed result saved offline | Original confirmed outcome and receipts with Saved and the actual last-updated time | No award replay; no new pairing or offline pose access; Retry refreshes this result rather than rerunning the judge |
| Review pending | Effective outcome plus Under review | Existing settled record remains; private case access does not publish allegations or imply a reversal |
| Correction settling | Rating updating after review with a coherent labeled last-confirmed result | No mixed old score/new rating receipt; no new rated search until the service clears the unsettled seed |
| Correction settled | Corrected, actual effective outcome, correction date, and actual own adjustment | Prior receipt remains distinguishable in authorized detail; no fresh judge, reward celebration, or silent erasure |
| Explanation hidden or removed after finalization | Existing authorized result with Explanation unavailable or Hidden by you | Report and permitted review access remain; unsafe text is not repeated in labels, cached captions, or a notification |
| Pose access expired, withdrawn, hidden, removed, or blocked | Accurate reason-specific availability text | No substitute image, stale thumbnail, regenerated pose, or gallery auto-open; textual result remains where authorized |
| Session expired, signed out, account switched, or result access denied | Private result cleared; conventional sign-in or safe unavailable state | No other account's cache, case, badges, or media survives; reauthenticate and authorize this exact match before restoration |

An insufficient-evidence, safety, integrity, refusal, malformed-output, or service-timeout no-contest never becomes a draw. Show only the safe private reason the service permits this viewer to know. The counterpart receives a neutral match reason, not someone else's attire declaration, report, demographic guess, or supposed misconduct finding. Reporting or blocking alone does not reverse a valid result.

## Corrections and Historical Truth

A correction is a distinct authorized review event. The ordinary final result remains effective while a dispute is pending. Subjective dissatisfaction is not a reroll request, and a late provider response is not a correction.

When a settled correction replaces a result, the heading and receipt reflect the coherent effective outcome. A compact Corrected notice and date make the revision unmistakable. The person's original match transaction and the adjustment applied after review have different labels. If later matches occurred, show the review adjustment's real before/change/after values at settlement time; do not pretend that the original match's historical after value was today's current rating. The authorized detail route explains the original outcome, revised outcome, safe reason, and actual consequences.

A correction to no-contest removes scored-winner treatment and the gallery entry, states No Elo change for the effective match, and separately explains any already-settled reversal or adjustment. It does not leave an old positive match award next to an uncanceled contradictory total. Placement, tier, public badges, streak, record, and allowance use the corresponding effective confirmed state. A rating bound can make the actual correction adjustment smaller; show what settled, not a hypothetical unlimited reversal.

While a correction is settling or refresh fails, retain one labeled last-confirmed snapshot with Rating updating after review. Do not combine revised totals, old placement, a guessed rating, and a presumed badge unlock. Later valid matches keep their own settled results and policies under F29-C; this screen does not imply a league-wide replay. Corrections use restrained update motion, not another victory event.

## Actions and Recovery

### Breakdown or Match details

Breakdown opens the existing match-detail owner at this exact match and revision. It contains both complete category sets, accepted totals and gap, neutral explanations, judging and rating-policy context, and any permitted correction history. It also exposes distinct scoring-review and unsafe-explanation report routes. A report is not mislabeled as a score appeal. Forfeit and no-contest use Match details with the reason and actual transaction consequences; there is no empty four-category score scaffold.

Returning restores the result's reading position and invoking control. A detail-load error is recoverable without hiding the already confirmed result or clearing the person's place. No action rejudges the images or creates another competitive event.

### View poses

View poses is intentional and separate from result arrival. It is offered only within a valid AI-judged win, loss, or draw and uses the existing protected viewer. Current participant authorization, accepted moderation, each image owner's present sharing choice, blocks, removal, and the ordinary twenty-four-hour expiry are checked before exposing any image. Previously granted consent or a copied link is not perpetual access.

An unknown access state can be checked after the deliberate action, with a local activity state on that action and safe navigation still available. A failed check shows its real recovery or unavailability reason; it never flashes a cached photo first. Known fully expired or revoked access is presented as Poses expired, Sharing withdrawn, or the other accurate status rather than an apparently working View poses button with no destination. Partial access follows the shared viewer's reason-specific placeholders. Forfeits and no-contests have no gallery entry at all.

The viewer owns all six selected pose positions, expiry information, exact already-redacted images, and per-image Report and Hide before enlargement. Closing it returns to this result without leaving an opponent still as the result panel's new default background. Images are never decoded or fetched merely to decorate the initial result.

### Report, Hide, Block, and review

Report is reachable directly from the result toolbar without opening, enlarging, or even downloading an image. It passes the real match context to the shared safety owner, which distinguishes the account, a named selected pose, an explanation, and scoring review. Do not require a screenshot, another revealing photo, a public allegation, or an external download.

Local hiding or shielding is immediate. Opening an image report hides that image before presentation, and cancelling the draft does not reveal it again. Sending, unsent, receipt-unknown, received, and retry states follow F29-D. Offline draft protection is not a submitted report or an evidence hold. Service confirmation is required before describing remote blocking, receipt, or deletion as complete. An unconfirmed block prevents new pairing while the shared owner reconciles it.

Blocking after finalization removes the relevant identity/gallery access and future pairing without altering the settled outcome. A scoring review remains available for no-contests and forfeits as well as scored matches, without promising another judge or a favorable adjustment. Privacy and sharing remains accessible through the existing result-detail route; withdrawing image access is not a rating reset or a return of screenshots already copied.

### Find another opponent

Find another opponent performs a fresh real eligibility check through the existing entry owner: same account, no other reserved or active match, current reviewed rating state, rules and consent, adult access, camera/preflight, allowance, and service readiness. Tapping is not automatic Ready, Go, consent, an allowance charge, or a rematch request. It does not activate the camera while the person is merely reading the result.

Only one attempt can be in progress. During the transition use Checking availability with the repeated search action unavailable; Close, Report, and safe return remain usable. If the service reports an existing active match on another window or device, offer its real resume route rather than a second reservation. On failure remain on this result with the specific recoverable reason and no lost receipt.

Offline, unsettled correction, unresolved required privacy or block state, exhausted allowance, restriction, or unavailable service prevents new pairing. Show the reason and the real appropriate recovery; never a fake opponent or a locally calculated allowance. Camera access missing or denied routes to the existing preparation explanation and Settings where useful, not a fake result-page permission alert. Existing result and safety access do not require a working camera.

### Close and navigation

After confirmed finalization, Close changes no outcome, rating, placement, allowance, or badge. A live result returns to the Physique lobby and refreshes authorized summaries. A result opened from history returns to the same history position. No auto-queue, timed dismissal, forced rematch, or guilt message appears.

If the restored service state is actually active or finality is unknown, hand control back to the shared session owner. Its state-aware exit distinguishes safe navigation during judging, pre-Go cancellation, and an explicit eligible Forfeit and leave. A final-looking local layout is never consent to forfeit.

## Native iPhone Composition

On iPhone the result lives in the feature's native navigation, with system back/close behavior appropriate to its entry. The top terminal clock occupies the established match-clock position. The result receipt, full rails, and portrait panels are one vertically scrolling content stage. You always precedes Opponent, including landscape and accessibility text sizes.

The primary next-search control occupies the app's measured safe bottom action region, respecting the selected navigation-menu edge and current floating controls. Close and Report remain in the native top action region. Secondary detail controls use readable text and symbols, wrapping into separate rows when needed. Primary and safety interactions retain the existing minimum forty-four-point touch convention. The design does not clamp Dynamic Type, compress labels to unreadable digits, or add a guessed bottom spacer.

At short heights, landscape, the largest accessibility text sizes, or a presented system keyboard in a dependent report form, scrolling provides space rather than squeezing the portrait panels or burying safety controls. Each portrait panel retains a generous portrait-oriented fit well derived from available width and shared stage geometry; it is not sized to force both bodies into one viewport. Images and neutral artwork are aspect-fit without warping, comparative favoritism, or cropping relevant evidence.

The result itself has no text entry and does not present a keyboard automatically. A dependent sheet uses native presentation, a visible close/cancel path, and draft protection from its owner. Returning restores focus and reading position. Phone locking, app switching, and backgrounding shield private result details and pause decoration immediately. Returning first restores account and authoritative state; pose galleries never reopen themselves.

## Native macOS Composition and Window Behavior

This is native macOS 14 or later, not Catalyst, a web card, or a stretched iPhone. Preserve Tmax's normal titled WindowGroup, the existing eight-hundred-by-six-hundred minimum window, ordinary traffic-light controls, system full-screen behavior, and existing menu commands. This result does not demand a larger app-wide minimum or a new borderless sports window.

At the minimum window and ordinary laptop sizes, the terminal clock and result summary sit above one centered, readable scrolling stage. The complete rails and two large portrait panels remain vertical. The top toolbar provides conventional Close/back, Report, and named detail access; the primary next-search action uses native Mac control density in a stable measured action region rather than an oversized floating phone capsule. A short window scrolls the stage while the clock and safe actions stay usable.

On large windows, full screen, and external displays, extra width becomes breathing room and an optional native inspector for the existing Breakdown destination. The inspector is supplementary information, not the second participant, an unsolicited pose gallery, or another result authority. It opens only from the person's detail action and only where the shared detail owner supports it. At a width where it would cramp the stage, the same action uses the owner's native sheet or detail presentation. The portrait stack never becomes two columns and never expands to arbitrary wall-sized evidence.

Live resize preserves the same participant order, score precision, text reflow, and all badge rows. Do not animate every geometry change, resort badges, restart a counter, fetch images, or rebuild a camera as the divider or window moves. Keep the current meaningful reading anchor where practical. Moving to a Retina or non-Retina external display must not stretch or decode evidence repeatedly as an animation effect.

Pointer hover is subtle native feedback, not the only source of badge meanings, current values, or safety actions. Tab and Shift-Tab traverse real controls in a consistent reading order, including all badges that open details and any inspector controls. Focus rings remain visible. Return or Space activates only the focused semantic control; Find another opponent is not a global Return handler and cannot fire while a person types in a report or system sheet.

Escape closes the most local presented detail, viewer, or report according to that owner's draft rules and returns focus to its invoker. At a confirmed final result it returns through conventional Close without a fake forfeiture confirmation. If recovery discovers an actual active match, the shared session owner's true consequence rules apply. Cmd-W and quit do not penalize closing a finalized result; real active-match consequences are confirmed where platform lifecycle permits. Force quit is not a confirmable voluntary forfeit and cannot be prevented.

Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O for their existing app commands. This result introduces no conflicting global shortcut or capture key interception.

There is no camera acquisition on this screen. macOS TCC denial, a busy camera, an unplugged external camera, or a disconnected Continuity Camera cannot erase a completed result or start a no-contest. A deliberate new search uses the shared camera-preparation owner to resolve the real device state. There is no rated file-picker, prerecorded substitute, or pretend preview.

Minimizing, hiding, backgrounding, becoming inactive, losing account authorization, or switching windows shields sensitive content as required and stops decorative work immediately. Any residual capture from the previous stage must already be stopped; a result animation never keeps it alive. Reopening or restoring retrieves this same match and effective revision without a fresh rating event, camera claim, or new allowance charge. Multiple windows may display authorized non-media result information, but only the account-wide session owner can initiate or resume the one real match and camera session. A secondary result window does not steal it or silently create another.

## Accessibility and Focus

The outcome heading receives accessibility focus once when a newly confirmed result arrives, followed by one concise announcement containing the outcome, both accepted totals when present, and the person's actual rating change. Do not announce every reveal frame, timer digit, badge row insertion, or interpolated rating number. Reopening a saved result announces the saved heading, not a new win or unlock.

Reading order is terminal-clock meaning, outcome and qualifiers, You total, Opponent total, own Physique Elo receipt, neutral summary and version, detail actions, complete owner-grouped rails, and You then Opponent panels. The persistent primary action remains reachable without traversing an entire long badge collection by using normal navigation landmarks or control navigation. Do not create a focus trap in a decorative portrait or group all actionable badges into one inaccessible image.

Every score is read with participant and points out of one hundred. Every Elo change is read as gained, lost, or unchanged Physique Elo points, with before and after. Provisional count, placement completion, tier movement, saved time, correction, and gallery unavailability have meaningful labels. A flag is a self-declared region, not verified nationality. Tier crests and streak symbols have names, not color-only status.

All controls support VoiceOver, Voice Control, Switch Control, Full Keyboard Access where applicable, and ordinary Mac keyboard navigation. Badge details have explicit accessible actions and visible control states. Touch does not require precision gestures, long press, swipe-only discovery, or hover. Large text and localized names wrap without clipping the full badge set or score units. Unsupported region glyphs, unavailable players, and absent data have neutral textual meanings.

Use short participant-and-pose image labels, not unsolicited intimate anatomical descriptions or demographic guesses. Hidden and removed explanation text and media do not remain in accessibility labels. A badge refresh or noncritical correction announcement preserves the person's current focus; a revoked private surface closes or shields immediately and moves focus to the relevant safe notice. Dismissing a dependent route restores the invoking action or its safe replacement if access changed.

## Animation, Interruption, and Energy Rules

The result has one bounded focal event, not multiple competing celebrations. No ambient loop is needed after finality. At most the shared stage's quiet ambient layer may persist briefly during continuity, and it stops when the result settles. Outcome, exact final values, all safe actions, and navigation are available at the start, not after animation completion.

| Trigger | Chosen motion | Timing, interruption, and repeat policy | Reduced or constrained behavior |
| --- | --- | --- | --- |
| Newly confirmed result replaces judging | The existing stage settles into result chrome; portrait geometry and owner order stay stable | About 280 milliseconds, ease-out continuity; no body zoom, card swap, or delay of the result heading | Immediate layout or a brief opacity change; never travel or scale |
| Accepted scored totals first appear | Shared expert reveal of the actual final glyphs; a single restrained exterior score accent settles with them | About 650 milliseconds, starting with the result, no random digits or zero seed; settle the whole result choreography within 900 milliseconds total | Static exact final totals; at most a short opacity change |
| Actual own Elo settlement | Shared counter moves only from a real earned before endpoint to its confirmed after endpoint; the signed change and final receipt are already readable | About 450 milliseconds, concurrent with score reveal, not after it; a first earned result uses reveal-only; duplicates and revisits do not replay | Static before/change/after and no count-up |
| Confirmed own placement, tier change, or result-attributed badge unlock | One small crest or mark settles in place, without pulsing the full rail | About 180 milliseconds within the same 900-millisecond result window; later badge confirmation gets only this local update | Static mark and one concise announcement |
| Button press | Existing shared tactile press feedback | Existing spring response 0.24 and damping fraction 0.88; release cannot issue a second request | Existing reduced-motion feedback without added scale |
| Disclosure, freshness, gallery-access status, or case status changes | Local text and icon crossfade; no movement of a body or badge wall | About 180 milliseconds; the latest actual state replaces the earlier transition | Immediate content or short opacity change |
| Authorized correction settles | Coherent effective text and receipt replace the labeled last-confirmed snapshot | About 180 milliseconds after settlement; no winner celebration or recreation of old earned motion | Immediate coherent update and one correction announcement |
| Report, Hide, Block, revocation, account loss, or privacy cover | Sensitive content is removed or shielded first | Immediate; decorative work is cancelled and cannot postpone protection | Same immediate protection |
| Close, new-search navigation, or a native dependent sheet | Existing native navigation and sheet behavior | Interrupt the result event; no completion handler may reopen it, start search twice, or steal focus | Native reduced-motion presentation |

All result motion is scoped to actual identity, match, and revision changes, not to a generic appearance callback or every service refresh. Leaving halfway through snaps remaining presentation to the confirmed final state. Foregrounding or reopening does not play the missing half later. A newer correction, revoked gallery, sign-out, or account switch cancels old visual work before displaying the new authorized state.

Reduce Motion removes number travel, scale, count-up, repeated decoration, and any simulated depth. Reduce Transparency uses opaque, high-contrast readable surfaces. Increased contrast and Differentiate Without Color retain explicit labels and marks. Sound is not required; an existing permitted light haptic may reinforce a newly settled result without differentiating a person's worth or replaying on history access.

Low Power Mode, serious thermal pressure, inactive or occluded windows, minimization, backgrounding, and offscreen content stop decorative work and use static final values. No per-frame provider calls, I/O, image decoding, badge fetching, camera rebuilding, global layout measurement, or font measurement is allowed for the reveal. Clock authority and permitted service updates do not depend on rendering frames. A completed result needs no repeating timer tick or display-link loop.

## Authority, Privacy, and Safety Invariants

The service owns finality, accepted totals, outcome, judging version, rating and placement transactions, badge entitlements, allowance, current permissions, and authorized corrections. The view renders those facts. A provider response, client animation, cached receipt, report, or local timeout cannot settle or rerate a match. Retry always retrieves the same match and current authorized revision; it never submits another vote.

Only a valid AI-judged win, loss, or draw can offer paired selected-still access. Current permissions, moderation, blocks, withdrawal, deletion, and the original twenty-four-hour expiry override any prior download or link. A report hold allows restricted case review, not a longer participant gallery. No-contest and forfeit never expose opponent candidates even if some uploads existed. No notification, sharing preview, initial result panel, session replay, diagnostic image, or app-switch snapshot exposes a body still.

Result export is not a new control owned by this screen. If the shared feature offers its separately approved system share route, it includes only the sharing person's own permitted identity and result, never an opponent pose or unconsented private information. There is no automatic save to Photos or claim that screenshots and external copies are impossible.

No country, badge, handle, Elo, placement, streak, private eligibility declaration, or UI chrome enters judge imagery or judging context. No image-based age, sex, gender, identity, health, body-fat, steroid, or attractiveness inference appears in copy or accessibility. The reference is hierarchy inspiration, not a license to use its faces or a precedent for humiliating comparison.

The existing exercise image-local privacy promise, exercise Elo, Profile's two-side shape, saved navigation, and unrelated app access remain unchanged.

## Dependencies and Review Boundaries

- [F29-A page and match flow](../DOCKS.md) owns the shared session, waiting and recovery presentation, safe navigation, result routing, detail viewer, and next-search preparation. The shared battle-stage, terminal-clock, participant-panel, and expert-counter owners must be identified through the integrated F29 index and reused.
- [F29-B AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) supplies complete accepted score meaning, precision, explanation safety, and judging-version context. Missing accepted evidence is not a zero.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns exactly-once finality, own transaction receipts, temporal rating scope, placement, tiers, records, allowance, and bounded authorized corrections.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) owns contextual report, immediate hide, block, scoring review, case status, and lawful evidence handling. This screen exposes those real routes without reimplementing their forms.
- [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) owns authentication, current access checks, processor and sharing consent, media expiry and revocation, privacy shielding, deletion, and operational readiness.
- F29-F's trusted country, identity, full badge catalog, snapshots, unlocks, and corrections are consumed through its integrated parent-index entry. Editable local profile badge previews cannot satisfy this dependency.
- The existing shared account, authorized persistent HTTPS service, reviewed judging configuration and quality gate, protected media system, and operational human-safety routes are real prerequisites. These result requirements do not authorize production work before those foundations and shared contracts are implemented and human-reviewed.

The shared F29-A and F29-G contexts own the vertical-player composition and tactile-motion vocabulary consumed here. This child does not redefine another view or imply acceptance of unrelated numerical proposals.

## Files and References

Product ownership:

- [This result specification](DOCKS.md) owns the decisions above.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-l-phase-1-result.md) owns the future connected implementation scope and human-review handoff.
- Prospective TimeMaster/Views/Physique/PhysiqueResultView.swift owns this native composition. A small result-owned rating-receipt view may be separated where existing shared composition does not already provide it; shared counters, rails, stage, and safety routes retain their existing owners.
- Prospective TimeMaster/Models/PhysiqueDuelModels.swift and TimeMaster/Services/Physique/ supply reviewed real result and revision state. This product document does not prescribe a second local settlement system.

Source and pattern references:

- [Theme and shared controls](../../../../TimeMaster/Utilities/Theme.swift), [Profile typography and spacing](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared material and press behavior](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) supply the established appearance, compatibility fallbacks, and tactile control behavior.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supply native action and earned-rating visual language, not Dynamic Type clamps, fixed tiny numerals, or authority to copy an exercise Elo. [The exercise duel HUD](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) is stage context, not permission for live provisional physique scores.
- [Native app window](../../../../TimeMaster/App/TmaxApp.swift) and [app commands](../../../../TimeMaster/App/TmaxCommands.swift) establish the ordinary Mac window and existing shortcuts. [Project configuration](../../../../TimeMaster.xcodeproj/project.pbxproj) establishes existing iPhone iOS 16 and native macOS 14 compatibility; no deployment-target raise is part of this view.
- [Local profile models](../../../../TimeMaster/Models/LocalProfileModels.swift) contain cosmetic badge previews, not trusted battle achievements.
- [Supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) supplies direct timer-and-player hierarchy only. Its side-by-side people, image-overlaid pills, purple and brown palette, mocking context, and assets are not adopted.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices, informs native window resizing, full-screen, keyboard commands, display use, and density. The persistent vertical player order is this product's decision, not a claim that Apple mandates it.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Best practices and Providing feedback, informs purposeful brief motion, equivalent information without motion, and interruption without waiting.
- Installed SwiftUI Pro accessibility and performance guidance and SwiftUI Animation guidance inform scalable type, scoped state-driven motion, immediate accessible final values, and cancellation of offscreen decorative work. Availability is constrained by the existing targets, not the skills' newer default deployment suggestions.
