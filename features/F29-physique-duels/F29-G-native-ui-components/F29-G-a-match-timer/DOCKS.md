# F29-G-a — Match Timer

## Purpose and Ownership

The match timer is the shared, very legible timing anchor for native iPhone and native macOS Physique Duels. It explains what time means now: time left to search, the synchronized start, time left to capture, an explicitly requested local capture delay, elapsed result processing, or the remaining opportunity to resume. It never makes a competitive decision.

This is product context for a future connected component, not an implemented clock, measured timing result, accepted prototype, or authorization to bypass the shared feature's review gates. The [native component parent](../DOCKS.md) owns composition across the family. [F29-A](../../F29-A-page-and-match-flow/DOCKS.md) owns the surrounding journey and actions; [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) and [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) own timing authority and consequences.

This child owns the clock's hierarchy, labels, numerical meaning, freshness and expiry presentation, local self-timer distinction, accessible timing feedback, and interruption behavior. It does not own another lobby, capture screen, result screen, consent form, camera controller, service clock, or judgement request. Existing native controls and the actual shared match state supply its actions and information.

## Chosen Composition and Tradeoffs

### A quiet scoreboard band

The top of the battle stage contains one flat, near-black scoreboard band. A concise phase label sits above large white tabular digits. One short status line sits below them only when needed. The digits are the largest text in the active stage. They use the existing Inter Black display language, with Inter Regular for phase and recovery text, rather than an unrelated digital-clock font. The colon, baseline, and space occupied by the number remain stable as seconds change.

Normal timed intervals use minutes and seconds, including leading zeroes: 01:30, 00:10, and 00:00. Fractions of a second are not displayed. The synchronized start uses the single large numeral 3, then 2, then 1 inside the same clock band. The visible phase label always distinguishes Search left, Starts in, Capture left, Processing elapsed, and Judging elapsed. An elapsed value is never labeled Time left.

Use the shared background, surfaces, and toolbar-orange accent. White remains the primary numerical ink, including the final seconds; an orange clock symbol and a concise warning can mark urgency without making a flashing red alarm. Necessary phase, stale-state, and recovery text must have readable contrast, not the weakest decorative text opacity. The clock band is opaque so player imagery or a translucent material cannot reduce numeral contrast.

The band has no circular progress ring, completion percentage, moving perimeter, colon blink, continuous shimmer, or slot-machine digit effect. A ring would blur the difference between an actual deadline and unpredictable judging. A flip clock would require attention on every second. The selected design reserves scale motion for the real match-start countdown and a deliberately armed capture self-timer; ordinary seconds change quietly.

Digit sizing grows from the existing scaled display typography and the available measured width. It is visibly larger than the pose heading, not a fixed pixel size copied from a screenshot. Preserve the full time group without clipping or truncation. Do not clamp accessibility text sizes or shrink the players to fit an oversized fixed header. The surrounding layout reflows and scrolls instead.

### Relationship to identities and players

Where a real battle composition is present, the order is invariant: top clock band; complete public identity and badge rails grouped by owner; large You panel; large Opponent panel. Both player panels stay vertically stacked on every width, including a large Mac display. Every public battle badge remains represented in the rails above the players. No three-slot limit, hidden +N, cropped rail, moving ticker, or hover-only disclosure is permitted.

The clock does not absorb badges into its status line or put time over a face, limb, pose guide, or selected evidence. Badge rails may wrap and scroll with the central stage. They are not an unbounded permanently pinned wall. Both player panels retain meaningful portrait presentation and equivalent evidence treatment; a short viewport scrolls instead of turning either person into a thumbnail. Evidence remains aspect-fit without body cropping, warping, or a larger comparison scale for one participant.

Before a real pairing, the search host uses the same clock band but does not fabricate an opponent panel or an opponent identity. Before a valid judged result, the opponent panel contains only an authorized avatar or neutral silhouette and actual stage or accepted-pose information. A clock reaching zero never exposes opponent stills.

### A distinct local capture delay

The capture self-timer is a smaller, explicitly labeled Capture in 3, Capture in 2, Capture in 1 treatment beside the capture action, outside the camera image. It never replaces the large Capture left clock. The primary band continues showing the original match deadline throughout the local delay.

The capture-control owner supplies the explicit delayed-capture action and its direct-capture alternative. This child defines the three-second delayed option, not additional delay durations or a second settings screen. During the delay, Cancel timer is a visible, reachable control. Its meaning is only to cancel that pending local shot; it is not Cancel match, Stop camera, or Forfeit and leave.

This uses two labeled times only when there really are two different constraints. That small increase in text is preferable to a large unexplained 3 that could be mistaken for the end of the match.

## Native iPhone Composition

The clock band sits below the system safe area and the host's ordinary navigation or active-match header. Safe actions remain reachable outside the scrolling player stage. The clock stays visible while badges and the vertically ordered players scroll. On short screens, landscape, and accessibility text sizes, controls and status text can wrap into their own rows; there is no hard-coded screen offset or camera overlay.

Use the existing measured content bounds and navigation-clearance conventions, including either position of the app's navigation controls. Keep the primary capture or resume action and Exit or Safety reachable without requiring the person to scroll to the bottom of both players. Primary and safety controls retain the existing minimum forty-four-point interaction area. The timer is informational text, not an invisible full-width button.

If the clock's supporting recovery explanation needs more space, place the complete explanation at the start of the scrollable stage while retaining its concise status and relevant action at the top or safe action area. Do not discard units, connection uncertainty, or consequences to maintain a one-line aesthetic. The single time group remains readable at the person's chosen text size.

Opening a safety, privacy, or exit surface stops and shields acquisition as required by F29-A and F29-E. The visible clock continues to describe the same deadline; the sheet does not create more capture time. Camera denial, restriction, absence, and interruptions use the host's real explanation and available Settings or Retry action. There is no prerecorded rated-image substitute.

## Native macOS Composition

This is a native macOS 14-and-later surface, not Catalyst, an embedded website, or a stretched phone. Preserve Tmax's normal title bar, traffic-light controls, menu bar, and existing minimum window size of 800 by 600. The clock belongs in the content header below the title bar, not in a replacement title bar or an always-on-top floating overlay.

The central battle stage uses the app's readable-column conventions. A laptop window, a large window, full screen, and an external display all retain the top clock, both complete badge rails above the players, You above Opponent, and equivalent evidence sizing. Additional width can give the column breathing room or accommodate the host's existing details inspector. It never creates a side-by-side matchup, stretches the body image, or adds a separate timer inspector. The clock remains the most legible timing element at ordinary desktop viewing distance and does not require hover to reveal its meaning.

At 800 by 600 and other short window heights, the clock and safe actions stay reachable while badge rails and large player panels scroll. Do not increase the app-wide minimum to avoid this work. Live resizing reflows the content without restarting a timer, changing phase, moving keyboard focus, reacquiring the camera, or replaying an entrance animation. Moving a window between displays changes layout and scale only, not timing or capture ownership.

Use native-density toolbar and action controls, pointer hover feedback, visible keyboard focus, native confirmation sheets, and native permission flows. The clock itself is not in the Tab sequence. Supplementary explanations can appear in the already owned host inspector or sheet; the current phase, time meaning, stale state, and recovery action remain visible without it.

TCC denial or restriction, no camera, camera busy, and external or Continuity Camera disconnect remain distinct host states. A disconnected camera cancels a pending self-timer immediately. Switching to an available camera follows the shared rule for discarding that person's selected set and continuing within the original capture deadline; it does not restart time or silently take a new picture. No file picker stands in for a rated camera.

When the app or capturing window becomes inactive, minimized, hidden, or otherwise loses its permitted acquisition state, acquisition and sensitive presentation stop or shield immediately. Decorative timing work stops as well. The trusted service's deadlines and already accepted judging continue. Return reconciles the same match before offering an explicit permitted resume; it does not replay 3, 2, 1, retake a shot, restore a full interval, or consume another allowance.

Only one account-owned active match and one camera owner exist across windows and devices. A secondary window can show the same authorized read-only match state and the host's Bring match window forward action, but cannot start another queue, run a second local self-timer, acquire the camera, or charge another slot. A view disappearing is not a new timing epoch.

## Time Meaning and Service Authority

### What establishes a clock

A timed phase needs the actual service-owned phase and timing information for the same match or search reservation. The usual boundaries are a maximum ninety-second search, a synchronized three-second start, a ninety-second capture period, a twenty-second reconnect grace, and a hard judgement deadline thirty seconds after both final pose sets have reached the service. These remain the shared product defaults, not newly measured or independently approved durations.

Opening a view is not the start of any of those intervals. The client must not assume that search, capture, or reconnect has its full nominal duration simply because a screen appeared. If the service supplies no usable deadline, show a dash with Syncing time or Time unavailable, not 01:30, 00:20, or 00:00 guessed locally. No readiness timeout is invented where the shared contract has not established one.

Displayed time follows elapsed time from a trusted synchronization, not the number of timer callbacks that happened to run. Device wall-clock changes, time-zone changes, delayed rendering, an animation, a sleep, or missed callbacks do not add or remove time from the actual match. A still-valid known deadline can continue to be projected while disconnected, with its last-synchronized status made explicit. A lost or unusable time anchor becomes Syncing time rather than an apparently precise promise.

For remaining time, show the next whole second until the actual boundary is reached; show zero only when no time remains. For elapsed time, show completed whole seconds. This rounding affects display only. Capture permission, expiry, cancellation, and finality use the actual service rules, not the rounded numeral.

A newer accepted service state takes precedence over the display. A synchronization correction replaces the time directly; it does not animate through missed seconds or locally smooth the deadline. If a correction changes the expected visible value by two or more whole seconds, the supporting line can say Time synced for two seconds, unless a more important recovery or safety message needs that line. Ordinary whole-second ticks do not produce that notice. The notice is information about correction, not a reset or grant of additional time.

Phase changes can legitimately introduce a different interval, but the new label and number appear together. An out-of-order update must not regress capture to countdown, restart expired search, or resurrect a finalized match. The clock never calculates a winner, Elo change, allowance restoration, or whether a no-contest was finalized.

### Processing time is elapsed, not an ETA

Until the service has received both final sets, retain the real capture deadline and the actual Uploading or Waiting for opponent status. The person's submitted set can be locked while the other person still has capture time. The clock must not switch to Judging merely because the local upload completed.

After confirmed receipt of both final sets, the top number changes to elapsed time since that receipt. While eligibility or safety checks remain, its label is Processing elapsed and its status names the actual stage, such as Checking poses. Once paired AI judging really begins, the label becomes Judging elapsed. The elapsed origin does not reset at that stage change: the thirty-second hard deadline includes checks, provider waiting, judging, and finalization.

At five seconds without a displayed result, the supporting message acknowledges the actual outstanding stage: Still uploading, Waiting for opponent, Still checking, or Still judging. The five-second end-to-end goal is unmeasured and is not a second countdown. Use the shared session's available submission and receipt facts; do not invent another participant's submission time or fabricate a stage to satisfy that threshold.

No shrinking ring, percentage, estimated finish, model-confidence number, predicted winner, or streamed provisional score accompanies elapsed time. The thirty-second boundary is a service failure deadline, not a promise of an AI answer. At that boundary without a confirmed outcome, remove the advancing elapsed number and show a dash with Awaiting confirmed result. The service may already have finalized a valid result before the deadline and merely be unable to deliver it to this device. Only its response can distinguish that case from a timeout no-contest.

### Reconnect time cannot extend the match

During a recoverable capture interruption, keep Capture left as the large top value whenever its deadline can still be projected reliably. Below it, show Reconnecting and, only when the real reconnect expiry is known, Resume within followed by the remaining effective recovery interval. That interval ends at whichever arrives first: the service's reconnect expiry or the existing capture deadline. If capture ends first, say Capture ends first rather than implying that the entire twenty-second grace is available.

For example, an interruption with eight seconds of capture time left cannot offer twenty seconds in which to take more poses. Both the large match clock and the labeled resume opportunity reflect those eight remaining seconds. If the service has not yet established or communicated a grace deadline, show Reconnecting with the known match time marked Last synced; do not invent a local twenty-second grace.

Once both final sets are received, returning is result retrieval, not a new opportunity to capture. Show the appropriate elapsed or awaiting-confirmation state with Reconnecting. Do not show a threatening resume countdown that implies an otherwise valid judgement will be discarded merely because the app is offline. Reopening, Retry, and switching windows fetch the same match; they never restart judging.

## States, Actions, and Recovery

| State | Clock and concise visible copy | Actions and consequence |
| --- | --- | --- |
| No active timed journey | No live interval in the lobby; the host's ordinary entry remains | Browsing does not create a search, camera session, or clock |
| Restoring or timing unavailable | Dash; Syncing time or Time unavailable | Existing Retry retrieves the same service state; safe return remains available; no fake full interval |
| Search reservation acknowledged | Search left and actual remaining minutes and seconds | Cancel uses the real reservation; no fabricated opponent, queue size, or ETA |
| Search offline or receipt uncertain | Project the known search deadline only if trustworthy; mark Last synced and Reconnecting | Reconcile or cancel the same reservation; do not automatically launch another search |
| Search cancellation pending | Cancelling with any still-relevant known search time | Repeated taps cannot imply repeated cancellation; do not claim release before acknowledgement |
| Search time reached locally | 00:00; Checking search | No local No opponent found claim until the service resolves expiry versus a just-completed pairing |
| Search expiry confirmed | No opponent found in the retained top region; no running clock | Try again intentionally requests a new search; Return has no rated loss |
| Paired, one or both not Ready | Waiting for Ready or Waiting for opponent; no invented countdown | Ready remains explicit and requires the host's valid camera, eligibility, and consent state |
| Synchronized start accepted | Starts in; 3, 2, 1 from the shared start, not a local sequence started on arrival | Cancel match and Safety remain available before authoritative Go |
| Start interrupted or cancelled | Countdown disappears immediately; actual Cancelling, Reconnecting, or preparation explanation | Do not finish the sequence in the background or take evidence from a stale Ready state |
| Visual countdown ends without authoritative Go | Dash; Confirming start | No capture permission or allowance conclusion comes from the display reaching zero |
| Go authorized | Capture left and the actual remaining capture time; a brief Go cue in the supporting line | Capture actions become available according to the real session, without waiting for the cue animation |
| Active capture | Capture left; named pose and its status remain in the host | Capture, retake, stop, and safety actions use the same original capture interval |
| Last ten capture seconds | Same white digits, clock symbol, and once-only 10 seconds left notice | No flashing, extra sound loop, automatic submission, or pressure to hold an unsafe pose |
| Delayed capture armed | Top Capture left remains; separate Capture in 3, 2, 1 beside Capture | Cancel timer cancels only the local attempt; repeated activation cannot queue another shot |
| Local delay completes | The self-timer stops; the host shows actual capture-in-progress or capture result | A still is taken only if the current session, camera, privacy, and deadline still permit it; no Captured claim merely because a number reached zero |
| Insufficient time for a three-second delay | Timer option unavailable with Not enough time for timer | Direct Capture can remain available only while it is otherwise valid; never silently shorten the chosen delay |
| Retake, rejection, or camera change | The same Capture left value continues; host shows pose-specific reason and remaining attempts | No deadline reset, extra retake, early opponent image, or unredacted fallback |
| Camera denied, restricted, absent, busy, or disconnected | Keep the applicable known match clock; show the real host recovery reason | Stop acquisition and cancel the self-timer immediately; Settings or Retry only when useful |
| Own set submitted | Capture left; Uploading or Waiting for opponent from real state | Own set remains locked; the person may relax; no new shot is armed automatically |
| Both final sets received, checks pending | Processing elapsed from both-set receipt; Checking poses | No fresh thirty-second interval when checks finish; safe navigation does not cancel the accepted work |
| AI actually judging | Judging elapsed from the same receipt origin; Judging physiques, then Still judging when appropriate | No provider ETA, invented percent, local winner, or duplicate request |
| Capture deadline reached | 00:00; Capture ended, then Awaiting confirmed result if unresolved | Disable new capture and cancel a pending delay at the real boundary; service decides whether accepted evidence can proceed or requires no-contest |
| Processing deadline reached without confirmation | Dash; Awaiting confirmed result | Retry retrieves existing state; no locally finalized no-contest, loss, refund, or judgement rerun |
| Recoverable interruption before required participation is complete | Original match time stays large; Reconnecting and an authorized, bounded Resume within when known | Resume the same match explicitly; no deadline extension, retake reset, or second charge |
| Recovery opportunity exhausted locally | Known match boundary or dash; Awaiting confirmed result | Do not restore Capture merely because the camera or network reappears; await service eligibility or finality |
| Confirmed safety abort, invalid match, or service failure | No contest in the retained top region; no active clock | Actual private reason and confirmed or pending allowance information belong to the host; no invented rating change |
| Explicit leave pending | Leaving; stop acquisition and the self-timer immediately | Service confirms a valid forfeit, existing final outcome, or higher-priority no-contest; no local guess |
| Final win, loss, draw, or forfeit | Ended in the clock region until the result host takes over; no running or fabricated final-duration number | The actual outcome and rating arrive from the service; reopening never restarts time or awards motion |
| Account switch, sign-out, deletion, or revoked processing | Remove the prior account's timer and private stage; stop pending acquisition immediately | Restore only state authorized for the current account; no leaked identity, media, or countdown |

A host can replace a terminal battle stage with its owned result screen. If it keeps the battle composition visible during that transition, the ended clock region remains above all badges and both vertically ordered players. A meaningless running 00:00 is not retained as a decorative result timer.

## Local Self-Timer Safety

The local three-second delay begins only after the person deliberately invokes that capture option. It has its own attempt identity and must not survive replacement of the pose, cancellation, a retake selection, permission withdrawal, Stop camera, an exit or safety sheet, loss of active acquisition, backgrounding, a camera disconnect, a match transition, or the capture deadline. Cancellation takes effect immediately, independently of any visual fade.

At the end of the delay, the capture owner rechecks the current allowed action. If it cannot take the still, show the concrete host reason and leave the pose unsubmitted. Do not execute a delayed callback after returning to the page. Resumption requires another explicit Capture action and, if selected, a new local three-second delay inside the original match deadline.

The timer has no role in face processing or transmission. An actual selected-image preview must show the exact required local face obscuring. A successful local countdown is not evidence of capture quality, redaction success, moderation acceptance, service receipt, or permission to send an unmasked original.

## Interaction, Keyboard, and Focus

The clock is readable noninteractive information. Tapping its digits does not pause, edit, restart, expand into another screen, or submit a pose. Explanations use the host's existing labeled controls, not hidden gestures or an invented clock settings page.

Tab and Shift-Tab visit the real semantic controls in a stable order. Return and Space activate only the focused applicable control; neither becomes a global shutter or match-exit shortcut. This applies to a Mac keyboard and an external iPhone keyboard. Typing in a report, account field, or native sheet must not trigger a capture behind it. Pointer hover can reinforce an action but is never the only place to see the phase, units, recovery action, or forfeiture consequence.

Escape is state-aware. Within a native sheet or meaningful report draft, follow that surface's dismissal and draft-protection rules. On the unobscured capture surface with an armed self-timer, Escape cancels that local timer first. Otherwise it requests the host's current safe exit behavior: pre-Go cancellation, post-Go explicit consequence confirmation, or closing a final result. It never directly creates a rated forfeit.

Cmd-W and ordinary quit requests use the existing active-match consequence confirmation where macOS permits interception. Before Go, explain cancellation without rating loss. After Go, distinguish leaving an otherwise eligible active match from dismissing a pending-result view after accepted evidence. Do not repurpose Cmd-N, Cmd-Shift-R, Cmd-comma, or Cmd-Option-O. Force quit, a crash, device sleep, network failure, and an operating-system termination cannot be prevented or treated as a confirmable voluntary forfeit.

If the service state changes while a confirmation is open, update the consequence before applying an action. A result that arrived must not be forfeited by a stale dialog. A pre-Go Cancel accepted too late must not be silently converted into consent to Forfeit and leave; show the started match and its real choices instead.

A real phase change can focus the heading or critical new instruction. Ordinary ticks, minor synchronization, badge reflow, and window resizing do not steal focus. Closing a sheet restores its invoking control when still valid, otherwise the current phase heading. A privacy or safety interruption can take priority over a decorative announcement.

## Accessibility and Concise Copy

The phase label and numerical value form one accessibility element with a full meaning: Capture time remaining, one minute twelve seconds; Search time remaining, forty seconds; or Judging elapsed, six seconds. A displayed dash is read as Time unavailable or Awaiting confirmed result, not zero. The self-timer is separately named Local capture delay so that two time values cannot be confused.

Update the element's current value for deliberate inspection, but do not post an announcement for every tick or interpolated value. Announce the start of search, the start of the synchronized countdown once, authoritative Go, entry to a new material stage, the ten-seconds-left capture milestone once while actually active, interruption, and finality. A delayed capture announces Capture in three seconds and its actual success or cancellation, not a spoken 3, 2, 1 series. The host and clock must coordinate so one event is not announced twice.

On a late join or resume, announce the current stage and remaining time once rather than replaying missed milestones. Do not interrupt a person's report text or queue obsolete countdown speech over a privacy warning. The clock should not ask someone to keep posing once capture is locked or interrupted.

Optional existing haptic or output-only cue support can signal Go and a completed capture where the device supports it. No microphone permission, continuous ticking sound, or new per-second audio behavior belongs to this component. Silent mode, VoiceOver, Voice Control, Switch Control, keyboard operation, and motion-reduced operation all retain the same meaningful actions. Haptics and color are never the only signal.

Visible copy uses the short labels specified above. Recovery, permissions, consent recipients, retention, safety, and real forfeiture consequences remain explicit in their owning surface. Minimal text is not permission to remove those disclosures. Localized labels can wrap; durations use locale-appropriate readable formatting and accessibility units without changing the underlying interval. Bidirectional layouts preserve the intended time group and You-above-Opponent order.

## Motion Rules

| Trigger | Visible motion | Duration and interruption | Reduced-motion and energy behavior |
| --- | --- | --- | --- |
| A real whole-second change in an active interval | Number content crossfades in its stable field; the band, baseline, colon position, rails, and players do not move | 180 milliseconds, once for the new value; a newer state replaces the old value rather than queuing transitions | Immediate replacement when Reduce Motion or constrained-energy mode is active |
| Accepted synchronized countdown enters 3, 2, or 1 | The current single numeral grows from normal size to at most 1.06 and settles; no surrounding content scales | Entire event settles within 220 milliseconds, tied to that real second; late entry shows only the current number | Static replacement; no replay of earlier numbers |
| Explicit local self-timer advances | The small Capture in numeral uses the same restrained scale event in its own control region | At most 1.06, settled within 220 milliseconds; cancellation or privacy loss removes the event immediately | Static number with the same label and Cancel timer action |
| Search, readiness, capture, processing, or recovery meaning changes | Phase and support text crossfade while the clock retains its location | 160 milliseconds for labels; if the host needs a stage transition, it completes within 280 milliseconds and never delays authority or actions | Immediate replacement or a short opacity change; no travel |
| Go is authorized | Go appears briefly in the support line while the actual capture clock and actions are already live | 180-millisecond appearance; cue clears after no more than 600 milliseconds; a safety or recovery message replaces it immediately | Immediate concise cue; no scale or mandatory dwell |
| Ten seconds of capture remain | Orange clock symbol and 10 seconds left notice appear once; digits stay white | 160-millisecond appearance; no pulse, flash, shaking, or repeated haptic event | Static symbol and text |
| Time synchronization changes the expected value materially | Direct replacement of the value; supporting Time synced notice when no higher-priority message is present | No count-through animation; notice lasts two seconds, interrupted by the next meaningful state | Same direct replacement |
| Finality or privacy stop arrives | All active clock and self-timer effects stop; authoritative terminal text or protected state is available immediately | Optional 160-millisecond text fade after the state is already effective; no fade delays camera stop or hiding | Immediate state |
| The user presses Cancel timer, Resume, or another host action | Existing shared button feedback only | Existing press spring, response 0.24 and damping fraction 0.88; no duplicate timer-specific bounce | Existing reduced-motion feedback |

Ordinary number replacement is deliberately quieter than the start and capture-delay events. There is no independent ambient loop in this component. If the host uses the family's single quiet ambient layer, the clock does not add another. A result reveal owned by another component takes priority; the timer does not replay Go or a countdown during it.

The base presentation and scale/opacity feedback work on iPhone iOS 16 and native macOS 14. Newer symbol, phase-animation, observation, or glass facilities are not prerequisites. Use the established native material fallbacks for neighboring shared controls; the timer itself remains opaque. Reduce Transparency therefore never makes a number harder to read. Increased Contrast and Differentiate Without Color preserve explicit labels and symbols.

## Energy-Safe Resumption

The visible display needs whole-second updates, not a continuously refreshed fractional clock. Offscreen, backgrounded, minimized, hidden, or inactive copies stop their presentation updates and all decorative effects. No frame of timer animation requires service I/O, provider calls, image decoding, font measurement, badge sorting, camera recreation, or layout of the complete player stage.

Low Power Mode or significant thermal constraint removes numeral transitions and optional cues before sacrificing truthful timing. The clock still updates at the necessary whole-second boundaries while visible. It does not spin a display-rate loop to maintain apparent smoothness. The host's necessary service reconciliation is separate from visual animation and must not be disabled merely because decoration is suspended.

After sleep, a call, a dropped connection, navigation, resize, or a returned window, display the newest permissible value directly. Missed seconds and animation completions are not replayed. The local self-timer remains cancelled. If time authority is not trustworthy after return, show Syncing time, reconcile the same match, and expose only the actions that current state authorizes. An accepted result may arrive immediately; the UI must not force the person through countdown, capture, or judging screens to reach it.

## Data, Privacy, and Fairness Invariants

The clock consumes only the current authorized phase, relevant timing facts, freshness, and action eligibility. It needs no body images, public-country inference, private eligibility declarations, judge reasoning, microphone access, appearance score, or profile-photo upload. It must not fetch or retain media to render time.

Public country is optional and self-declared; trusted public badges belong to F29-F and the host identity rails. The timer neither hides earned badges to gain space nor promotes editable local cosmetic badge previews into trusted achievements. Country, identity, badges, timer digits, and other UI chrome never enter judge imagery or context. The upload remains the clean locally redacted capture, not a screenshot of the battle stage.

The opponent's stills remain unavailable before a valid judged win, loss, or draw, current permission, and intentional View poses. Forfeits and no-contests have no opponent gallery. Expiry, withdrawal, report/hide, or block protection does not wait for a clock transition. Blocking after Go shields and prevents future pairing; it does not itself stop the match clock, finalize a result, or create a free win.

Every countdown is subordinate to privacy, safety, real service finality, and the existing deadlines. No UI timeout creates Elo, erases a valid result, grants an extra retake, restores an allowance, renews media access, or sends additional evidence. Repetition, reopening, and a second window have no competitive effects.

## Dependencies and Future Files

The component requires the human-reviewed account/session foundation and the approved shared Physique lifecycle, synchronized timing, capture eligibility, redaction, and result-retrieval contracts. Real shared foundations must be implemented and human-reviewed before production clock work begins. A timer preview is not a shippable competitive feature.

- [F29 parent](../../DOCKS.md): eligibility, privacy, core durations, finality, and independent Physique scope.
- [F29-A](../../F29-A-page-and-match-flow/DOCKS.md): host screens, camera/self-timer actions, navigation, focus, and safe exit.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md): no provisional judge result, valid evidence, and non-scored outcomes.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md): real search, Go, one active match, allowance, reconnect, and result authority.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md): immediate protection and safety/no-contest precedence.
- [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md): permissions, lifecycle, receipt-based judgement deadline, provider uncertainty, and late delivery.
- [F29-G parent](../DOCKS.md): top-clock/all-badges/vertical-player layout and coordination with the identity, capture, reconnect, and result owners. F29-F remains the authority for public identity and badges through the parent product map.
- Prospective component: TimeMaster/Views/Physique/Components/PhysiqueMatchTimer.swift. This is a future location, not an existing implementation.
- Future integration: the approved hosts under TimeMaster/Views/Physique/ and their existing shared session owner under TimeMaster/Services/Physique/. Reuse their authoritative state rather than creating a second clock store, request loop, or camera owner.
- Existing visual references: [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift). No new global theme is needed.
- Existing platform boundaries: [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift).
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-G-a-phase-1-match-timer.md) owns technical work and prospective verification. [CYCLES.md](../../../../CYCLES.md) alone owns implementation and review tracking.

## Reference and Decision Precedence

The supplied [battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy and immediacy reference: a conspicuous timer above participants. It is not a source for side-by-side layout, purple or brown web pills, overlays on people, image rights, or app assets. This component requires no generated artwork.

[Apple's Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), particularly Best practices, informs resizable native windows, keyboard and menu integration, and using desktop space without unnecessary modality. [Apple's Motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion), particularly Best practices and Providing feedback, informs short purposeful feedback, alternatives to motion, and interruptibility. The particular hierarchy and timings above are product decisions, not Apple-prescribed measurements.

The approved direction supersedes F29-A's earlier first-iPhone emphasis, optional wide-window two-column comparison, and fade-only start countdown. Both native iPhone and native Mac are required; battle players remain vertical; a restrained real-event numeral pop is allowed. This child does not edit those shared files or alter F29-B through F29-E's service and privacy rules. The coordinated parent owner reconciles shared wording. The five-second target remains unmeasured, and the listed numerical service defaults retain their existing product-review status.
