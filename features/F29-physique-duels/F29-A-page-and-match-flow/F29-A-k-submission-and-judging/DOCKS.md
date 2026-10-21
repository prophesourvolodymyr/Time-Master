# F29-A-k — Submission and Judging

## Purpose and Scope

This view owns the continuous wait after Submit poses: submission acknowledgement, remaining transfer, checks, waiting for the opponent, paired judging, finalization, and recovery of that same match. It must make the difference between selected, received, accepted, and judged immediately understandable without turning the wait into a dashboard or inventing analysis progress.

Both native iPhone and native macOS are required. This is product context and a future implementation direction, not a running interface, accepted prototype, completed service, or measured latency claim. The shared ninety-second capture period, twenty-second reconnect grace, and thirty-second judgement deadline retain their existing proposed competition meaning. The five-second experience target is unmeasured and is never a countdown.

The [page-flow parent](../DOCKS.md) owns the whole journey. This view does not own another capture screen, result screen, gallery, report form, account flow, privacy editor, badge system, or notification settings screen. It opens their existing contextual routes when needed. Framework confirmations and native details presentation are not additional custom feature screens.

## Chosen Composition and Decisions

The composition is a stable sports stage, not a full-screen spinner. From top to bottom it contains the real phase clock, one concise current-stage heading, the complete owner-grouped identity and badge rails, then a large You panel above a large Opponent panel. Both panels retain the shared battle panel's upright geometry. Status and counts sit in a footer outside each portrait region. Neither player is reduced to a small avatar to accommodate more explanatory text.

The waiting portraits use the shared approved neutral athlete silhouette, or a currently authorized public avatar where appropriate. They are explicitly portrait/illustration states, not frozen camera feeds. Own camera acquisition stops as soon as the submitted set no longer needs capture; waiting must not require the person to maintain a pose. This view does not repeat the person's body stills or display any opponent capture. Exact own-image inspection and a requested retake return to Pose review or Battle stage. This trades repeated photo review during waiting for lower sensitive exposure, stable framing, and an unmistakable camera-off state.

The shared orange-and-ivory athlete treatment, dark stage, strong timer, and short acceptance feedback provide the sports character. There is no anatomy scan, moving skeleton, body glow, comparative lead, confidence gauge, or rotating rubric narration. A still illustration is a legitimate privacy-safe participant representation, not a pretend live preview or a substitute for real evidence.

One status heading and one useful support line describe what is actually pending. Detailed pose states, clock explanations, recovery consequences, and privacy routes use intentional Details. An ordinary healthy wait does not need a disabled Submit button or an artificial task to keep the person busy.

### Shared Visual Language

Use the existing near-black background, dark elevated surfaces, white primary text, readable secondary ink, toolbar orange, Inter Black emphasis, and Inter Regular supporting text. Use the shared action, surface, press, clock, player-panel, atmosphere, and badge treatments. Do not introduce a purple web skin, another global theme, a custom glass renderer, or a requirement for a newer operating system.

Timer digits use stable monospaced geometry and the shared display hierarchy. Concise headings are subordinate to the clock. The current instruction and error reason can wrap. Orange identifies meaningful activity or an action, not a predicted winner. Text and symbols distinguish sending, received, checking, accepted, unavailable, and retake-needed states without relying on color.

### Complete Identity Rails

Both public identity groups appear together above both player panels, in You then Opponent order. Each group contains the permitted handle, optional deliberately selected country/region flag, actual Physique rating or placement state, and every public battle badge authorized by F29-F. All eligible badges wrap visibly in their owner group. There is no three-slot limit, hidden count, ticker, clipping, or hover-only badge explanation. A long handle or large text wraps rather than pushing another person's badges out of view.

F29-F owns badge catalog, ordering, current streak, placed tier, unlocks, stale status, and corrections. Waiting cannot award First Bell, Placed, Ten Rounds, Three Straight, rating, or streak from an unfinished match. Editable local cosmetic previews never become trusted battle achievements. Existing confirmed public badges can remain with an honest freshness label when permitted; unknown badge state is not an empty earned collection.

Country is optional and self-declared, with its accessible region name and a neutral missing or unsupported-glyph state. No country is inferred from the camera, location, network, device locale, or handle. A local profile photograph is not automatically uploaded as a public avatar. If blocking, access withdrawal, or authorization requires the counterpart to be hidden, the protected Opponent identity and portrait state replace the restricted content immediately; retaining every badge never overrides protection.

## Native iPhone Composition

The match presentation respects the actual safe areas, measured app navigation clearance, and existing top-or-bottom navigation preference. The top clock and a compact status area remain reachable while the central stage scrolls. Safety and the explicit Return or Exit control remain reachable outside the scrolling player portraits. The primary recovery action occupies the normal shared action area only when the current state needs one.

The scrollable stage begins with the two complete identity/badge groups, followed by the large You panel and then the large Opponent panel. The badge wall is not permanently pinned over most of the display. Short iPhones, landscape, longer translations, and accessibility text can require scrolling through the second panel; neither portrait nor text is shrunk to fit both players into one screenshot. A panel's status footer grows independently of its portrait area.

Details expands a labeled inline disclosure below the current status or uses the app's existing native detail sheet where the surrounding match shell requires a sheet. It contains only this match's operational explanation and real per-pose status. It does not turn into another body-image viewer. Closing it restores focus to Details and preserves stage scroll position. The keyboard in a shared report or privacy route must not cover that route's real Submit, Cancel, or withdrawal controls.

After Go, incidental swipe dismissal must not abandon the match or issue a forfeit. Explicit Return to Physique is navigation, with the conditional work-interruption explanation below. Explicit Forfeit and leave is a different consequential action. No wait animation prevents either safety access or stopping further authorized sharing.

## Native macOS Composition

This is a native macOS 14-or-later surface in the existing normal-title-bar WindowGroup, not Catalyst, an embedded web page, or an enlarged phone sheet. Preserve the app-wide 800-by-600 minimum. At that size, the phase clock and safe toolbar/actions remain usable above a scrollable central stage; the full badge groups and both substantial portrait panels are reachable by scrolling. Do not raise the minimum or make the players tiny to avoid scrolling.

On laptop, larger, full-screen, and external-display windows, center the stage in the app's established readable content width. Extra width may reveal an optional native Details inspector with pose receipt/check information and recovery explanations. The actual participants remain stacked You above Opponent at every width, including full screen. The inspector is initially closed and supplementary; it never becomes the only location for a required error, deadline meaning, or safety action. At constrained width, Details uses the ordinary native disclosure or sheet rather than consuming the player column.

Use the title bar and standard toolbar for navigation, Details, and Safety. Keep the real timer as the top content anchor rather than hiding it inside a tiny toolbar item. Destructive forfeiture is not the default toolbar action. Native sheets attach to the owning window and leave its match identity unambiguous. Pointer hover can reinforce an available control and supply help, but cannot reveal the only way to retry, report, leave, or understand a badge.

Live resize, display migration, full-screen changes, and opening or closing the inspector preserve the match, remaining time, focus, selected versions, and vertical player order. Reflow uses measured available geometry. Changing window shape does not re-enter submission, rebuild a camera, rerequest judging, or replay acceptance feedback.

## Counts and Progress Meaning

Own progress always distinguishes these three counts, each out of the three named required poses:

| Count | Exact product meaning | What it must not imply |
| --- | --- | --- |
| Selected | The current selected front, side, and rear pose versions belonging to this match, as known by the capture owner | Receipt, moderation acceptance, successful final submission, or a score |
| Received | The protected service has acknowledged the current selected version for that pose | Local transfer completion alone, acceptance, or permission to show an opponent image |
| Accepted | The current selected version has passed the service's required capture, safety, and evidence checks | Judge completion, bodily superiority, or irrevocable future gallery access |

The visible own footer says Selected 3/3, Received 2/3, Accepted 1/3 when those are the actual facts; the values here explain copy, not production seed data. Counts wrap into separate labeled lines when necessary. A real zero remains zero. Unknown information uses a dash and Not confirmed, not zero, three, or a fabricated progress estimate. The three named pose slots in Details identify Front, Side, and Rear with their current actual state.

Only the current selected version contributes once per pose. Superseded candidates, duplicate acknowledgements, retries, or several successful checks of the same image do not increase a count. Replacing a pose invalidates that version's old acceptance. A stale response for a replaced still cannot approve the replacement. If a genuine service invalidation lowers an accepted count, show the changed state and practical private reason; do not keep a false completed meter for visual smoothness.

The opponent panel shows the actual authorized public stage and accepted-pose count, not their local selection metadata, hidden moderation reason, rejected image, or guessed transfer state. If the public status is unavailable, use Status not confirmed and an unknown count. Do not request private opponent fields simply to make both footers identical. This deliberate asymmetry preserves the existing public stage/accepted-count contract while the person's own three counts remain complete.

Counts report evidence status, not a fraction of elapsed processing work. There is no combined analysis percentage, all-six-images progress race, estimated time remaining, provider confidence, streamed appearance score, or decorative meter that slowly fills until completion. The stage can skip quickly through already-completed operations; the view never forces every intermediate label to appear.

## The Top Clock

| Actual service phase | Top clock label and meaning | Boundary behavior |
| --- | --- | --- |
| Own submission or opponent capture still incomplete, and no paired-final-set receipt established | Capture closes, with the remaining original shared capture time | Submitting, switching views, checking, and reconnecting do not create another ninety seconds |
| Both final sets received, including any remaining required checks, queueing, judging, validation, and settlement | Decision limit, with the remainder of thirty seconds measured from receipt of both final sets | The visible caption states Limit, not an estimate; it does not promise a result when the digits reach zero |
| Recoverable interruption while client participation is still required | The same phase deadline remains primary; the smaller connection line describes the actual remaining reconnect opportunity | Twenty seconds of grace cannot exceed or extend a capture or judgement deadline |
| No reliable deadline or time relationship is available | A dash timer and Time not confirmed | Do not start a fresh thirty-second clock, count locally from opening the view, or keep an apparently live stale deadline |
| A known deadline reaches zero but a terminal service record is not yet confirmed | 00:00 with Awaiting confirmed outcome | Request the same authoritative state; do not locally declare a no-contest or animate an award |
| Terminal service outcome confirmed | Running clock stops and the existing result route takes ownership | Do not carry a ticking capture clock into results |

The service's paired receipt milestone starts the decision limit even if screening or model queueing is still pending. Provider start time, first token, last animation, restored window, or device clock changes never restart it. If the service permits a specific recapture before paired judging, it remains inside the original capture opportunity and never resets any already-established decision deadline.

When an authoritative time relationship is available, visible seconds can advance while the view is active without treating each tick as another service operation. Reconciliation can correct the displayed remainder in either direction without inventing extra time. A deadline is a rule enforced by the service, not evidence that the client has received the outcome. A valid result finalized within the service deadline may reach a disconnected client later and remains valid. A genuinely late provider output cannot replace a service-finalized timeout no-contest.

## Actual Stages and Visible Copy

Operations may overlap. Each panel retains its actual status while the shared heading names the next fact preventing progress. A required personal action takes precedence over ordinary activity; a protection or terminal event takes precedence immediately. Missing service information must not be presented as a known provider operation.

| State | Main heading and concise support | Actions and consequences |
| --- | --- | --- |
| Submission not yet acknowledged | Submitting poses; the own counts remain visible | Keep the exact selected set locked as appropriate to the actual submit operation. A lost acknowledgement is Not confirmed, not Submitted successfully |
| Remaining current images transferring | Sending poses; Received n/3 | Show only real current transfer/receipt state. Native indeterminate activity indicates work, not measured percentage |
| Current images received but own required checks incomplete | Checking poses; Accepted n/3 | Camera is off. Receipt does not become accepted merely because a transfer finished |
| Own set accepted and opponent not finished | Waiting for opponent; Your set is ready | Opponent remains an authorized avatar or silhouette with actual accepted count. No invitation to hold the pose or keep exposing the body |
| Both final sets received but remaining checks not complete | Checking pose sets; no invented judge activity | The decision limit is already running. Do not say Judging physiques until that is the real service stage |
| Paired judging actually underway | Judging physiques; Your camera is off | One native indeterminate activity treatment. No scores, category animations, early winner, or implied completion fraction |
| Provider output exists but trusted finalization is not confirmed | Confirming result; Awaiting confirmed outcome | No preview of unvalidated output, speculative rating, or premature badge unlock |
| An exact own pose has a permitted recoverable problem | Retake needed; name the pose and safe practical reason | Primary action Review pose opens the existing exact Pose review/capture route, with remaining attempts and unchanged time |
| Recapture unavailable, attempts exhausted, or evidence cannot be made valid | Set could not be accepted; Awaiting confirmed outcome until the service settles | Do not offer a dead Retake, an unrelated replacement image, or a locally declared loss |
| Transfer stopped with receipt known | Sending interrupted; Received n/3 | Retry transfer is available only for the same still versions and only while the service still permits their submission |
| Receipt is unknown after an interruption | Upload not confirmed; Checking this match | Retry status retrieves receipts first. It does not blindly create another set or relabel client completion as service receipt |
| Connection unavailable or session recovering | Reconnecting, or Offline when known; Last confirmed status is identified | Retry status and Return remain available as appropriate. Complete accepted evidence may still be judged without a connected window |
| Service state still unavailable after the expected deadline | Awaiting confirmed outcome; Unable to refresh result | No guessed win, draw, forfeit, no-contest, Elo effect, or restored slot. Preserve the same pending match reference |
| Service confirms invalid, refused, unsafe, failed, or timed-out judging | No contest via the existing result route | No Elo change, no scores, no opponent gallery; allowance restoration is shown only when confirmed |
| Service confirms valid judged result or eligible forfeit | Existing result route for that exact match | Final meaning is available immediately. Forfeit has no fabricated physique breakdown or counterpart gallery |
| Account authorization expires, changes, or is removed | Account-specific restoration or access state | Clear unauthorized private content; never show the previous account's match or resume under another account |

If restoration discovers that the person is still in capture, before Go, or already final, route to that real owning stage rather than forcing it into this waiting view. A vanished local selection cannot be reconstructed from an old thumbnail, another match, or a generated image. The service decides whether eligible same-match capture can still resume; otherwise it supplies the appropriate final outcome.

### Honest Slow Status

Five seconds without a displayed result is a point to acknowledge waiting, not to promise another five seconds or pretend the model began. After this person's final submission has been waiting for five seconds, the support line uses the actual current stage: Still sending, Checks are taking longer, Opponent still finishing, Still judging, or Confirming result. On restoration, use the original available submission timing rather than starting the acknowledgement interval over. This earlier personal-wait acknowledgement does not change the shared final-submission experience target or either authoritative deadline.

The heading remains stage-accurate. Still judging is used only during actual paired judging. An unavailable connection uses Result not confirmed rather than claiming the model is busy. A rapid result bypasses the slow wording and wait animation immediately. Slow status is announced once at a meaningful stage, not on every tick or repeated identical response. There is no Almost done, guaranteed next-second result, fabricated provider queue position, or additional hard limit created by the message.

## Actions, Leaving, and Same-Match Recovery

### Ordinary navigation is not forfeiture

Return to Physique leaves the visual wait and exposes the existing pending-match entry. It does not cancel received evidence, rerun judging, make another match, spend another allowance slot, clear a final result, or record a forfeit. Once all required local work has been acknowledged and no personal action is pending, the action can return directly with the concise explanation This match continues. Open it from Physique.

If sending, receipt reconciliation, or a requested retake still needs this client, an ordinary native confirmation says what may be interrupted and names the real remaining capture opportunity. The choices are Stay and Return to Physique. It states that uploads may pause when the app cannot continue and that resuming does not restart the deadline. It must not promise background completion, a guaranteed recoverable selection after process termination, or a free no-contest. The person is not trapped in the view and is not forced to continue sharing to regain the rest of the app.

The existing pending-match entry opens the same authenticated match and reconciles actual receipts, acceptance, deadlines, and terminal state. It does not offer a new Find opponent while the service still has an unresolved active match. The entry is not a duplicate history row or another unowned custom waiting screen. The lobby and history owners provide those routes; this view provides their exact match context and clear recovery meaning.

### Explicit competitive exit

Forfeit and leave is separate from Return, Retry, closing Details, reporting, blocking, withdrawing only opponent access, or a system interruption. When service eligibility makes it a real possible consequence, the native confirmation explains that a deliberate accepted forfeit loses this match, can change Physique Elo, and consumes the started-match slot. Keep waiting is the safe default. Only the explicitly confirmed consequential action requests forfeiture.

The request is not final until the service acknowledges its actual outcome. A final result arriving first remains final. A safety, invalid-evidence, or unavailable-service no-contest has its documented precedence. If status or eligibility cannot be confirmed, do not label a pending request Forfeit complete, claim a guaranteed loss, or conceal safe navigation. A before-Go restored state uses the pre-Go cancellation contract, not this started-match warning.

### Interruption and relaunch

Backgrounding, device lock, calls, inactive or minimized Mac windows, and leaving a capture surface stop acquisition and shield sensitive local presentation immediately. The waiting view normally has no camera running in the first place. Decorative work pauses. No waiting animation or consent sheet can defer those protections.

If required client participation remains, the twenty-second reconnect opportunity stays within the original deadline. Returning first restores the authoritative same-match state and then offers any explicitly permitted camera resume through its owner. It does not take another still, resume a camera invisibly, reset retakes, automatically upload an unreviewed original, or charge another slot.

When both sets are already sufficiently accepted for server-side judging, closing or losing a window does not invalidate adequate evidence just because the client is absent. A result may settle while the app is closed. On return, retrieve that record; do not rerun the model or start a client timeout outcome. A received-but-unchecked set is still described honestly as pending checks.

There is one account-wide active match and one camera owner across windows and devices. Additional windows restore authorized state without beginning another upload set, acquiring a second camera, or charging a second match. Moving interactive ownership, if supported by the shared shell, is explicit; a secondary window cannot silently seize it. Account switching or signing out clears private state and does not substitute for a sharing-withdrawal request.

## Mac Camera, Input, and Window Consequences

A denied or restricted TCC permission, absent or busy camera, unplugged external camera, or disconnected Continuity camera is not repaired with a file picker, recording, or fake preview. If the final set is already accepted and no recapture is needed, losing camera access does not itself invalidate the pending judgement or prevent viewing a result. Do not prompt for camera permission merely to wait.

If a real service-requested recapture still fits the original limits, Review pose returns to the camera owner with the actual resource failure, remaining attempts, and original deadline. Camera availability never causes a hidden capture restart. Reconnecting a peripheral does not automatically take a new image or replace accepted evidence.

Tab and Shift-Tab follow visible semantic controls, including Return or Exit, Details, Safety, any actual recovery action, badge details, and expanded pose information. VoiceOver reading starts with phase and clock meaning, then status, each full identity group, and the two vertical participants. Routine count changes do not move keyboard focus or reset scroll position.

Return and Space activate only the focused semantic control. They do not globally submit, forfeit, open a camera, or act while a report note or another text field is being edited. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. This feature does not repurpose them as match shortcuts.

Escape first dismisses the current nondestructive disclosure, popover, or sheet according to that surface's actual draft rules. At the match root it requests the same state-aware navigation or exit guard; it is never a hidden forfeiture shortcut. Closing Details returns focus to its invoker. If a focused recovery control disappears after a real state change, move focus to the current stage heading or its replacement action rather than to a destructive control.

Cmd-W and ordinary quit use platform-supported confirmation only when unresolved local participation would really be interrupted. The confirmation explains that consequence and keeps continuing or cancelling the close available; closing is not silently translated to a voluntary forfeit. If only autonomous server judging remains, there is no fabricated need to keep the window open. Force quit cannot be prevented or counted as an explicitly confirmed forfeit. The service's real recovery and finality rules remain authoritative.

## Details, Safety, and Privacy

Details shows the three own pose names, selected/received/accepted meaning and actual states, the current trusted stage, relevant original deadlines, and how to reopen this match. It can show a minimal match reference for support. It does not show private provider reasoning, credentials, internal traces, raw model text, demographic guesses, body measurements, or another participant's private moderation explanation.

Safety is always reachable without opening an image. It opens the shared contextual reporting or blocking route with the existing match and permitted account context. Reporting is not automatic forfeiture, a result appeal, a received acknowledgement before sending, or evidence of guilt. Block after Go immediately shields the appropriate media/identity and excludes future pairing, but does not itself end or rerate this match. A safety-aborted outcome requires the service's determination.

Privacy and sharing opens the existing stage-aware controls. Withdrawing processing immediately stops new affected capture and transfer; already accepted processor work may not be retractable. An unreachable service is Not confirmed, not a promise of remote revocation or deletion. Withdrawing only future paired-opponent still access is not a forfeit or rating reversal. None of these operations waits for an animation, requires an enlarged image, or forces the person to keep posing.

Only locally face-obscured exact reviewed captures may have been transmitted. Redaction failure remains fail-closed; an unmasked original is never a waiting-view fallback. Bystanders remain invalid even if masked. No country, badge, handle, Elo, public avatar, or UI screenshot enters judge images or judging context. The waiting view does not alter the distinct exercise promise that exercise images stay local.

Even after finalization, this view does not reveal a counterpart still. Only the existing intentional View poses action in a valid judged win/loss/draw, with current authorization and moderation, can open the gallery. Forfeits and no-contests have no counterpart gallery. The ordinary twenty-four-hour media expiry, revocation, report/hide, and deletion restrictions remain independent of pending UI, history restoration, and rating records. There is no automatic Photos save, microphone, chat, live stranger video, or body-image screen replay.

## Generic Notification and Return

A permitted notification uses the system app identity and the body A result is available. It contains no Physique label, photo, avatar, opponent handle, country, badge, score, Elo change, outcome, clothing information, report reason, or sensitive explanation. It is a discreet availability message, not a result card or another custom screen.

Notification consent is separate from capture and sharing. The wait never opens a permission prompt automatically. An explicit Notify me action in Details may use the existing real notification-permission path. A denied or restricted state is Notifications off with the conventional settings route when useful; do not repeat the system prompt or promise delivery. Refusal does not block returning or restoring the match. Permission, system delivery, Focus settings, and network availability can prevent or delay notification; the pending-match entry remains sufficient recovery.

Only a real confirmed terminal record can trigger the result-available message. It is deduplicated for the same match rather than sent on retries, each client tick, both devices' refreshes, or each restored window. When the person is already viewing this match, update that surface rather than issue a duplicate foreground notification. There are no notification actions to forfeit, rerun judging, share a result, or open body media.

Opening the notification verifies the current account and fetches that exact authorized match before displaying its real state. It never opens poses or a camera. An expired session returns through the existing account route; a wrong or removed account receives a safe unavailable state with no leaked record. Delayed delivery cannot reopen a final match, extend media expiry, or apply rating twice. The notification itself is not proof of the currently visible outcome.

## Animation, Interruption, and Energy

The portraits and identity grouping stay geometrically stable throughout the wait. The shared atmosphere supplies the one quiet approximately twelve-second ambient layer when useful and energy-safe. This view adds no separate glow loop, badge breathing, camera shader, or competing progress animation. The native indeterminate activity indicator is status feedback, not a forecast; it stays in the same status location and disappears as soon as that activity ends.

| Real trigger | Motion and timing | Interruption and equivalent state |
| --- | --- | --- |
| Submit accepted as a real transition into waiting | Status emblem settles gently from slightly smaller to its resting size while the relevant caption changes; the shared stage continuity resolves in about 280 milliseconds | Keep panels and controls stable. Newer state or a final result replaces it immediately; no minimum wait |
| Clock's displayed second actually changes | Shared in-place digit replacement, about 180 milliseconds, with stable header geometry | No accumulated tick animations or focus change. Current time is readable immediately |
| Current selected pose becomes received or accepted | Only the exact slot's symbol/status resolves once over about 180 milliseconds. Acceptance may use a tiny single settled check emphasis, no larger than 1.04 scale | Coalesce simultaneous updates instead of replaying old states. Replaced versions cancel their old feedback. Final text is available immediately |
| Actual stage or slow-status wording changes | A brief 160–180-millisecond text/icon replacement inside stable bounds | Latest real state wins; no serial queue of Sending, Checking, Judging after those stages have already completed |
| Real recoverable interruption | Connection mark and concise recovery instruction replace activity in about 160 milliseconds | Preserve clock meaning and counts. Do not shake portraits, pulse a red deadline, or imply opponent advantage |
| Details or native sheet opens or closes | Existing native disclosure, inspector, or sheet behavior and shared press feedback | Interactive dismissal follows draft/consequence rules; closing does not issue another service operation |
| Confirmed terminal state arrives | Hand off immediately to the existing result route using shared stage continuity, about 280 milliseconds | Outcome and safe controls are available immediately. Result counters belong to their owner; this transition is not added as another serial celebration |
| Hide, block, sign-out, revoked access, camera stop, or background protection | Protected content is removed or shielded immediately | No fade-out interval exposes restricted content; subsequent non-sensitive acknowledgement may be brief |

Reuse the shared press spring with response 0.24 and damping 0.88 rather than a waiting-specific button style. The small acceptance check is the focal event; ambient depth must remain quiet during it. There is no per-second haptic, repeating sound, flashing urgency, humiliation animation, speculative winner highlight, or acceptance ceremony that can be mistaken for an earned result.

Reduce Motion removes scale, travel, check emphasis, repeating atmospheric movement, and decorative numeric motion. Use immediate updates or a short opacity replacement of at most about 120 milliseconds. A static activity symbol plus accurate text provides the same status; no information depends on spinning. Reduce Transparency uses the shared opaque readable surfaces, including the privacy cover. Increased contrast and differentiate-without-color retain explicit labels and symbols.

Offscreen, backgrounded, inactive, minimized, locked, low-power, or thermally constrained presentation suppresses decorative work. Stop the quiet atmosphere and nonessential repeated indicator animation before reducing essential status clarity. Authoritative service work and deadlines continue; the client does not create high-frequency background redraws to imitate a live clock. On return, render the current state without replaying missed ticks, receipt stamps, or an award.

No animation frame performs provider work, networking, file access, image decoding, camera creation, font measurement, badge sorting, or whole-stage reconstruction. Visible timer changes need only second-level updates while active. Reading an already accepted result, returning from Details, or moving a window must not produce another judgement request.

## Accessibility and Focus

Use native controls with concise visible labels, the existing iPhone forty-four-point action convention, native Mac density, visible keyboard focus, and a logical reading order. Dynamic Type and accessibility text expand content without clamps, hidden badges, precision targets, or dependence on hover. Voice Control names remain stable even when counts change; Switch Control can reach recovery, Return, Details, Safety, and explicit exit independently.

Each own counter has an accessible owner, name, actual value, and denominator. The opponent has only its permitted stage/count semantics. Decorative athletes do not acquire an intimate anatomical description, and unknown information is spoken as Not confirmed rather than a numerical zero. A country flag includes its self-declared region name. Details explains Selected versus Received versus Accepted without requiring color recognition.

On first entry, accessibility focus lands on the actual stage heading and clock meaning, not on a decorative spinner or Forfeit. Announce meaningful stage transitions, a genuine retake request, connection failure, and result availability once. Do not announce every timer tick, packet, polling response, badge reflow, or incidental selected-count refresh. A deadline warning, when useful, is a single factual milestone, never a repeated alarm.

Routine updates preserve focus. A necessary personal-action error may move accessibility focus to its concise reason when the match surface is active. A terminal result can transition immediately if the wait is the active unobstructed task. If the person is editing a report, privacy choice, or another owned sheet, do not dismiss it, lose a draft, move keyboard focus into results, or open media; mark the result available and open the result through the existing route after that task closes or the person chooses it. Silent mode and unavailable haptics leave the flow complete.

## Ownership, Dependencies, and Files

The future waiting presentation belongs under TimeMaster/Views/Physique/, with PhysiqueSubmissionJudgingView.swift as its prospective feature-owned view. Its role is to compose reviewed shared match state and components, not own another competitive engine. Existing or future shared sources supply selected versions, receipt and acceptance state, phase deadlines, recovery, authorized identity, notification routing, and finality. Exact source organization must follow the reviewed project architecture.

Required relationships are:

- [F29 parent](../../DOCKS.md) and [F29-A](../DOCKS.md): overall lifecycle, eligibility, explicit exit, pending-match entry, and navigation boundaries.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md): six-image paired judging, absent-score meaning, validation, version freeze, and no provider-text verdict before service finality.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md): one active match, exactly-once rating/allowance, reconnect, forfeiture precedence, and stable terminal records.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) and [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md): contextual checks, immediate protection, consent, actual data recipients, deadline authority, retention, and service failures.
- [F29-F](../../F29-F-battle-identity-and-badges/DOCKS.md): complete trusted public rails, country meaning, badge order, stale information, and corrected awards.
- [F29-G](../../F29-G-native-ui-components/DOCKS.md): shared timer, upright player panels, pose icons, atmosphere, result transition, native Mac shell, compatibility, and energy behavior.
- [Pose review](../F29-A-j-pose-review/DOCKS.md), [Battle stage](../F29-A-i-battle-stage/DOCKS.md), [Result](../F29-A-l-result/DOCKS.md), [Lobby](../F29-A-a-lobby/DOCKS.md), and [Privacy and sharing](../F29-A-w-privacy-and-sharing/DOCKS.md): own the actual destinations; this view must not recreate them.
- The [future implementation brief](../../../../prompts/F29-physique-duels/F29-A-k-phase-1-submission-and-judging.md) owns the connected implementation assignment, not competitive rules.

Real implementation depends on human-reviewed account/navigation, capture and local redaction, protected same-match transport, status and deadline contracts, valid paired judging, authoritative finalization, operational moderation, F29-F/G components, and destination routes. Independent documentation work does not make this screen independently shippable. Missing real prerequisites remain unavailable prerequisites, never production fixture data or a simulated fallback.

## References and Design Tradeoffs

- [Supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): direct timer/player hierarchy and accessible exit/safety, not its horizontal layout, overlay badges, web styling, photographs, or rights to reuse those people.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), [Profile design](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared glass controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift): existing palette, typography, measured readable columns, public material fallbacks, and press behavior rather than a second global design system.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) and [exercise duel player](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift): nearby native sports vocabulary only; exercise provisional scores, relative lead bars, movement metrics, type clamps, and joint-only privacy assumptions are not physique waiting behavior.
- [Native app shell](../../../../TimeMaster/App/TmaxApp.swift) and [commands](../../../../TimeMaster/App/TmaxCommands.swift): normal native Mac windows, current minimum, and existing command ownership.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices: flexible resizable windows, readable use of larger displays, keyboard/pointer access, and native platform conventions. The selected implementation uses a vertical readable stage with supplementary inspector space, not a horizontal player comparison.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Best practices and Providing feedback: purposeful brief optional motion that can be interrupted. The selected check feedback communicates actual receipt/acceptance; service and privacy actions never wait for it.
- [Apple HIG — Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators), especially Best practices and macOS: distinguish quantifiable progress from indeterminate work and keep status in a consistent location. Here pose counts are quantifiable, while judging duration is not; the Mac heading communicates the match phase without an additional redundant spinner label.
- [Apple HIG — Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications), especially Best practices: consent, sensitive-content minimization, deduplication, and nondisruptive foreground handling. Generic availability and an authenticated return route are chosen instead of a rich result notification.

The principal tradeoffs are deliberate: two large stacked participants require scrolling in short windows; every public badge remains discoverable rather than capped; privacy-safe portraits replace repeated body imagery during waiting; a real decision limit is shown as a limit rather than an ETA; own detailed counts and the opponent's smaller authorized projection are not falsely symmetrical. None changes the separate Physique ladder, service authority, consent, or valid-result media boundary.
