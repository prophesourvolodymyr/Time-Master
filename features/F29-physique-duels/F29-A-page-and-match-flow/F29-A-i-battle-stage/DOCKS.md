# F29-A-i — Battle Stage

## Purpose and Review Boundary

The battle stage is the live sports composition for Physique Duels on native iPhone and native macOS. It carries a real paired match from the synchronized start into three guided poses, evidence review, submission, and the handoff to the waiting or final-result owner. It does not create a second matchmaking, camera, judging, safety, or result system.

The user-directed hierarchy is fixed: the real phase timer at the top; both owners' complete public identity and badge rails below it; then two large vertically stacked participant panels, You above Opponent. This applies on Mac as well as iPhone. A wide window, a winning result, or a capture interruption never changes the pair into side-by-side cards.

This is product context for a future implementation, not an implemented surface, an accepted interactive prototype, or a verification record. The composition follows the user's latest direction. Detailed motion, capture-review, and recovery choices below are concrete design proposals within the parent rules; prior numerical service proposals retain their review status. The [parent flow](../DOCKS.md) owns the journey, while [F29-G](../../F29-G-native-ui-components/DOCKS.md) supplies shared presentation mechanisms.

## Ownership and Boundaries

This child owns the arrangement of the live stage, the primary action at each local step, the transition between those steps, and the relationship between visible camera work and the authoritative match. It composes these existing or separately owned surfaces:

- The shared phase clock and distinct local self-timer from F29-G-a.
- The shared large participant panels, safe media framing, and neutral pose illustrations from F29-G-b.
- The shared state-responsive background from F29-G-c.
- The shared Mac window, toolbar, focus, camera-ownership, and lifecycle behavior from F29-G-e.
- The complete trusted identity and badge rails from F29-F.
- The reviewed capture, redaction, consent, protected upload, match-state, and safety foundations constrained by F29-B through F29-E.
- The readiness, uploading/judging, result, safety, and privacy routes registered by F29-A. This child supplies the continuing battle composition where those owners retain it; it does not create competing screens for their work.

Queue search, account entry, consent acquisition, preflight setup, scoring explanations, the post-result still gallery, report forms, privacy controls, and badge detail mechanisms remain with their named owners. Native alerts, menus, sheets, permission prompts, and established buttons are reused. A camera error is a real stage state with recovery, not permission to add an unowned upload-from-library screen.

## Chosen Composition and Tradeoffs

### A single vertical arena

The scene is a dark, readable central stage with three stable regions. The pinned top region contains the shared clock and compact safe actions. The scrollable center begins with all public battle identity and badges, followed by You and Opponent in that order. A persistent action region contains the current primary action and an independently reachable Stop camera control whenever acquisition is active.

The phase label beside the timer is the stage's principal heading. During capture, the current pose and one practical instruction belong immediately outside the upper participant's media well. There is no competing dashboard of metrics, explanatory cards, or giant versus logo. Physique Elo identifies the participants in the rails; there is no appearance scoreboard before finalization.

Both participant panels use the same generous stage-column width and the shared panel's portrait-oriented media presentation. They remain major content surfaces rather than a camera plus a tiny opponent chip. Their useful size follows measured width, safe content bounds, and the shared media treatment, not half of the remaining viewport height. When two large panels and their badges cannot fit simultaneously, they scroll. Do not shrink bodies, crop required regions, or compress type to make a complete screenshot fit.

This intentionally trades simultaneous visibility of both full panels for legible people, honest identity, and usable capture. A permanently pinned badge wall would defeat that goal; badges stay above both participants in document order but scroll with the stage. A pinned timer and reachable safe actions supply continuity while the person scrolls.

### Complete owner-grouped identity rails

The first rail begins with You, the permitted handle, and the optional self-declared country or region. The second begins with Opponent and that person's permitted identity. Every public battle badge supplied by F29-F appears in its owner group, including the truthful placed tier and current streak when applicable. F29-F owns catalog meaning, ordering, corrections, and unlock behavior; the stage does not choose a favorite three or calculate achievements.

Each rail wraps to as many lines as necessary. No clipped final row, horizontal ticker, hidden +N, hover-only badge, selected-three limit, or collapsed More badges control is allowed. Badge details are available through the shared semantic action, not a new stage-specific legend. Long handles and translated labels wrap. Region meaning remains accessible when the flag glyph is absent or unsupported. Missing region information is neutral, not an invented flag or an eligibility defect.

Only confirmed permitted identity is displayed. Unknown badges are labeled unavailable rather than represented by invented locked trophies. Previously confirmed data can remain only when still permitted and explicitly stale. Revoked identity, removed badges, and blocked-player details are removed or replaced according to their owner; preserving scroll position does not justify preserving invalid content. Corrections do not replay an unlock or imply that the current match caused an award.

### The upper player: local evidence, not an audience stream

The upper panel is always You. Its header identifies whether it contains Camera active, Review pose, a selected pose, or Camera paused. The live preview remains device-local. Guidance, pose names, countdown labels, and controls sit in the panel's header or footer, never across the face, shoulders, arms, torso, or legs. The shared guide may show unobtrusive framing boundaries, but never a moving anatomical scanner, ideal-body outline to imitate, or provisional body score.

A captured frame replaces the live preview in the same large media well for review. Only the exact face-obscured representation intended for transfer is presented there. The image remains aspect-fit, with stable orientation and neutral letterboxing when needed. Review does not zoom into an intimate region. The upper panel never becomes a tiny thumbnail merely because the opponent has finished.

The three pose controls identify Front, Side, and Rear, with each full pose name available visibly when selected and through accessibility. They show operational states such as Not captured, Selected, Checking, Accepted, or Needs retake. These are pose controls, not additional public achievement badges. They live outside the media well and wrap at large text. Selecting an existing pose inspects that person's own selected evidence in the upper panel; it never fetches an opponent still.

### The lower player: a real person, protected evidence

The lower panel is always Opponent. It uses only an explicitly authorized public avatar or a neutral original or appropriately licensed silhouette. A local Profile photograph is not automatically uploaded or treated as a public avatar. Avatar absence, loading failure, removal, or blocking has a deliberate neutral representation, not a fabricated rival.

The opponent's actual stage and accepted-pose count appear outside that panel's media region: Ready, Capturing, 1 of 3 accepted, Submitted, or an accurate reconnecting or unavailable status. Counts refer to service-confirmed acceptance, not the number of times the other person pressed a shutter. They may decrease after a real replacement or correction. An unknown count stays unknown. Readiness, transfer completion, and accepted evidence remain different concepts.

Before finalization, there is never a live opponent camera, early pose thumbnail, rejected image, chat, microphone channel, provisional score, confidence percentage, lead bar, or inferred physique advantage. The silhouette does not change shape to suggest the opponent's body or score. Completion earns a small operational check, not a victory treatment.

## Native iPhone Composition

Use the existing dark page surface, shared safe-area and navigation-clearance measurements, Inter hierarchy, orange actions, and shared control feedback. Do not recreate the screenshot's purple and brown web pills. The capture stage can suppress distracting page navigation while active, but explicit exit restores the same Physique destination and the user's saved page arrangement.

The top region places the real timer centrally with its short phase label. Safety and the state-aware Exit action remain visible and named. The center is one vertical scroll surface: Your identity rail, Opponent identity rail, You panel, Opponent panel. The current instruction and named pose belong to You; the other panel never steals primary-action emphasis.

The bottom action region is outside the scrolling evidence and respects the home indicator and any measured app controls. The primary label changes with the actual step: Capture · 3s, Use pose, Next pose, Submit poses, Resume camera, or the useful recovery action. Retake is secondary while reviewing a captured image. Stop camera remains independently available while the camera is active and is not buried in overflow. Safety and Exit do not disappear during a disabled or busy primary action.

At short height, landscape orientation, enlarged display settings, or the largest supported Dynamic Type, badge rails and pose controls wrap and the central stage scrolls. Both players remain large and vertical. The timer's phase wording can wrap separately from its stable digits. The action region can use additional rows; labels must not be truncated into ambiguity. Use the established forty-four-point action convention without copying the exercise HUD's Dynamic Type clamps or minimum text scaling.

Do not automatically scroll on every acceptance, timer tick, or incoming opponent update. Initial stage entry begins at the badge rails. An explicit Capture or Resume camera action brings the upper panel into view if necessary. Selecting a pose brings that pose's instruction and review into view. Returning from a sheet restores the invoking control and its scroll location unless a critical stage transition invalidated it.

## Native macOS Composition

This is a native macOS 14-or-later surface, not Catalyst, a browser, or a phone sheet stretched across a window. Retain Tmax's normal title bar, traffic-light controls, menu bar commands, and existing eight-hundred-by-six-hundred minimum. Do not raise the app-wide minimum to compensate for the composition.

Use the native toolbar for named Safety, Exit, and supplementary guide or information access. The real phase clock is the top visual anchor in the content area, not a tiny toolbar ornament. The central participant column uses the app's readable-column convention and measured available width. Both complete badge rails precede both large panels; You stays above Opponent on a laptop, a wide monitor, an external display, and in full screen.

Wider windows may expose a native inspector for the existing pose guide or secondary match information. It must not host the opponent, duplicate the badge rails, move the primary capture action out of reach, or create a new report or privacy screen. At the minimum size or short height, the inspector closes or uses the owning route's normal presentation and the central stage scrolls. Opening an inspector does not force two narrow player columns. Window width is spent on comfortable margins and useful secondary context, not inflated typography or a landscape body crop.

On Mac, place the primary capture/review action and Stop camera in F29-G-e's reachable in-content action band beside the stable top timing region, with native Mac control density, ordinary focus rings and pointer feedback. Do not duplicate the iPhone bottom action region as another desktop control bar. Trackpad, mouse, keyboard-only, VoiceOver, Voice Control and Switch Control reach the same controls; hover cannot be their only label or action. External displays do not confer camera permission or ownership.

Live resize preserves selected evidence, both participant identities, camera framing, pose selection, focus, and the authoritative deadlines. Panels adapt through measured layout; the camera must not restart and pose art must not replay on every size change. Preserve the current content anchor where possible rather than jumping to the top whenever badge wrapping changes. Real-time resize does not trigger a decorative stage transition.

Camera state names native Mac realities: permission denied in Privacy & Security, managed restriction, no camera, camera in use, external device removed, or Continuity camera disconnected. Offer Open Settings only when it can help, and Retry or Resume only after the resource can actually be reacquired. Do not silently select a different camera after Go. The shared camera contract owns a deliberate change and its evidence-discard consequence. No file picker, recording, fake preview, or physical-camera claim substitutes for a rated live capture.

Only the shared owner window can control the active capture. Another window or device restores authorized match status without a second camera session, queue reservation, or allowance charge. A secondary window offers the shared route to the owning session; it cannot begin an independent countdown. A deliberate owner transfer follows the shared lifecycle contract, including stopping the previous camera before the replacement can acquire it.

## Clock Meaning at Each Boundary

The shared clock owns time calculation and display. This stage chooses its phase placement and surrounding language, not a second local match clock.

| Stage | Top anchor | Boundary and action meaning |
| --- | --- | --- |
| Restoring the paired match | Restoring match, with unavailable time until confirmed | No invented ninety-second start or local Ready state |
| Paired but start not established | Awaiting start; no running invented countdown | The readiness owner controls Ready; Cancel remains pre-Go until the service says otherwise |
| Service-established start countdown | 3, 2, 1 with Starting | The service owns Go; visual zero alone never authorizes evidence or consumes allowance |
| Capture | Actual shared time left from the ninety-second capture period | Every pose, review, retake, and recoverable transfer uses the same deadline |
| Local self-timer | The shared capture clock remains at the top | A separate Capture in 3, 2, 1 cue belongs to the upper panel's instruction area; it cannot replace or extend match time |
| Own set submitted, other participant unfinished | Remaining capture time and Waiting for opponent | The camera is off; accepted local submission does not mean paired judging has started |
| Both final sets received; checks or judging active | The shared clock's truthful elapsed waiting presentation, labeled with the actual stage | No five-second completion promise; the thirty-second service deadline still begins at receipt of both final sets, not model execution |
| Reconnecting | Existing phase time remains primary; real recovery time is secondary when known | Twenty-second grace never extends capture or judgement; unavailable recovery time is not invented |
| Deadline reached without a received final result | Deadline reached or Awaiting confirmed outcome | Stop any disallowed capture or transfer; local timeout does not manufacture a no-contest |
| Confirmed terminal result | The active countdown stops and the result owner receives the actual outcome | No running capture clock, fake remaining analysis time, or second result calculation |

The five-second slow-status threshold changes only the truthful wording of the actual remaining stage. If the other participant is still capturing, say Waiting for opponent. If a transfer is incomplete, say Still uploading. Say Still judging only when that is true. The timer never becomes an analysis percentage or a prediction of when a winner will appear.

## Three-Pose Capture Interaction

### Begin without rushing

The shared countdown establishes anticipation, not consent to an automatic shutter. At authoritative Go the stage identifies Front double-biceps and makes the capture action available only when current permission, camera ownership, evidence conditions, and sharing authorization allow it. The service consumes the match allowance once at Go, not on a visual transition or on each exposure.

The guide's concise instructions are Front double-biceps — Keep arms and legs in frame; Side physique — Turn comfortably; keep your side in frame; Rear double-biceps — Turn safely; keep arms and legs in frame. Full evidence and clothing guidance is available through the existing pose-guide route. The illustration teaches orientation without idealizing anatomy or inviting more skin exposure. No instruction asks for breath-holding, exhaustion, dehydration, painful motion, or exposure of protected areas.

First capture proceeds Front, Side, then Rear. Earlier selections remain inspectable and may be revisited for a permitted retake. A late rejection marks its actual pose without unexpectedly switching the live camera away from a different pose the person is safely capturing.

### Arm the shutter deliberately

The default action is Capture · 3s. The shared timer control offers the existing three-second delay or immediate capture; the choice remains visible and is not reset between poses. There is no automatic series of three exposures, hidden burst, continuous recording, or AI-selected favorable frame.

Arming displays Capture in 3 in the upper panel's instruction region and changes the action to Cancel capture. An optional output-only sound or spoken cue can help someone who has turned away; it does not request microphone access. Silent, visual, and accessible paths remain complete. Cancel capture cancels the armed exposure, not the match, and does not consume a retake when no frame was captured.

The shared deadline always wins. If there is not enough confirmed capture time for the chosen delay, explain Not enough time for a 3-second timer and offer the already supported immediate mode deliberately. Do not shorten the delay silently, restart the match clock, or urge an unsafe rush. At the scheduled exposure, capture occurs only if the match, resource, authorization, and evidence conditions still permit it. Otherwise cancel the armed exposure and state the useful reason; do not wait invisibly for the person to wander back into frame and then take a surprise image.

### Review the exact redacted still

After an actual exposure, acquisition pauses while the new still is prepared and reviewed. The upper panel keeps its position and size. A privacy-safe Preparing preview state occupies it until the exact face-obscured image is available; there is no flash of an unmasked original. The original remains transient local processing material.

The review state says Review pose and Not sent. Use pose is the primary action; Retake is secondary if the pose still has an opportunity. Only Use pose authorizes that exact previewed representation for the already consented protected check. This is an image-selection action, not a substitute for prior disclosure of recipients, retention, or paired access. It gives a real chance to inspect the treatment before transmission instead of briefly flashing an image and uploading it automatically.

The extra review tap is intentional. It favors understandable privacy and evidence selection over an automatic fastest-possible capture. Nothing extends the shared deadline to compensate. The guide and self-timer reduce repositioning cost; a person need not continue holding the pose while reviewing or waiting.

Redaction failure has no transferable candidate. State Face protection unavailable and offer a permitted recapture or the state-aware safe exit. An unmasked original, screen capture, or provider-side promise to blur later is not a fallback. A bystander remains an invalid capture even when masking was possible. Local invalidity uses a concrete private explanation and never becomes a low body score.

### Select, check, and continue

After Use pose, the pose is Selected until the protected service actually acknowledges the next stage. Uploading, Checking, and Accepted are distinct. The primary can advance to Next pose while a previous candidate is checked; actual accepted count is not optimistically incremented. Moving to the next capture resumes the authorized local camera deliberately.

The person can inspect the three pose statuses without leaving the stage. A failed check identifies the affected pose and an actionable safe reason. An additional explanation or false-positive review opens its existing owned route, without enlarging potentially prohibited content. Opponent status remains neutral; it does not disclose another person's rejection reason, attire declaration, or moderation allegation.

Retake replaces the relevant selected evidence and invalidates that version's acceptance under the shared capture contract. Only the current selected version can become accepted. A stale check or transfer receipt cannot approve a superseded still. The stage shows the real remaining retakes and respects at most two retakes for each pose; retries of the same transfer are not new poses. Cancelling an armed timer is not a new exposure. The shared capture foundation, not a view-local counter, owns attempt accounting.

A replacement preview needs its own Use pose action. Selecting a retake is not consent to transmit an unseen frame or to reuse approval of the previous version. Discarded versions are handled under F29-E's minimization rules rather than kept as a local gallery. Running out of opportunities shows Retakes used and the real next choice. It never offers a decorative button, a paid extra attempt, or an unlimited reset through navigation.

### Submit one selected set

Submit poses becomes available only when all three current selected poses meet the service's submission conditions, including required acceptance. Pending checks, unknown receipts, or a superseded accepted image are not a completed set. The stage identifies the blocking pose or real transfer state rather than merely dimming the button without explanation.

Submission has a truthful pending state. Repeated activation cannot lock a second set, create another match, or consume another allowance. Receipt uncertainty says Submission not confirmed and reconciles the same attempt. On confirmed submission, the set locks and camera acquisition stops immediately. The upper panel may retain the person's own permitted redacted selection for inspection; the lower panel remains an avatar or silhouette and actual progress. The primary waiting message is Poses submitted — You can relax.

Editing a submitted set is unavailable unless the service explicitly requests a permitted recapture within the original capture period and before paired judgement. Such a request names the exact pose, restores only authorized actions, and never changes the match identifier, deadline, or retake history. A client cannot unlock the set because the opponent is slow or because a local navigation action reopened the camera view.

### Transition to waiting and results

The separate waiting owner receives the same match and accepted evidence state. If it retains the battle shell, the top timer, all public badges, and both large vertical panels remain. Judging replaces instructional content, not participant ownership. The service can finish without the person continuing to pose or keeping the camera running.

Once no more local capture is required and the service permits safe visual dismissal, Return to lobby can hide the waiting view while retaining a real pending-match entry. This is not Forfeit and leave. An explicit competitive exit remains a separate state-aware action. A local view disappearance never decides which of those actions occurred.

A confirmed final result immediately makes its actual outcome and permitted navigation available through the result owner. Stage continuity may resolve around it, but cannot delay safety, close, the final accessible values, or current media permissions. The stage does not decode or prefetch counterpart pose images for an automatic reveal. Only the result owner's intentional View poses action can request moderated stills after a valid AI-judged win, loss, or draw with current access. Forfeit and no-contest never unlock that gallery.

## State, Action, and Recovery Matrix

| State | Visible stage and useful actions | Required recovery or consequence |
| --- | --- | --- |
| Match restoration pending | Stable stage shell, Restoring match, protected media, Safety and Exit | Obtain current permitted identity, stage, ownership, and timing before camera resume; no fake opponent or rating |
| Start not yet confirmed | Awaiting start, real identities if authorized, no running invented countdown | Return to readiness owner if needed; no evidence before Go |
| Start countdown | Shared countdown, both rails, You preview only when eligible, opponent avatar | Cancel remains available; lost eligibility cancels the local countdown and capture readiness |
| Cancel races with Go | Match has started when confirmed, with rejoin or explicit forfeit choice | A pre-Go Cancel cannot be silently converted into consent to an Elo loss |
| Capture ready | Named pose, real shared time, local preview and framing instruction | Capture or the three-second self-timer; only adequate evidence conditions enable exposure |
| Framing or light inadequate | Specific adjustment outside the image, disabled Capture with reason | Improve ordinary framing or light; no appearance score and no exhortation to expose more skin |
| Self-timer armed | Separate upper-panel count, Cancel capture, active shared timer | Cancel on resource, eligibility, visibility, safety, or deadline loss; never take a delayed surprise frame |
| Preparing redacted preview | Privacy-safe upper panel, preparing status, Stop or exit | No original transmitted or briefly displayed as a supposed protected preview |
| Exact preview ready | Review pose, Not sent, Use pose, eligible Retake | Only the reviewed representation can become a candidate |
| Face protection failed | Private actionable error and eligible recapture | Fail closed; no unmasked fallback |
| Bystander or prohibited capture | Safe private explanation; no enlarged violating crop | Recapture alone or resolve through safety/exit; masking does not make the second person valid |
| Selected, transferring, checking | Actual distinct pose state and permitted next-pose action | No optimistic acceptance; same-submission retry only within the real contract |
| Capture rejected | Affected pose, safe reason, real remaining retakes, review access | Keep other valid selections; do not reveal the rejection to the opponent |
| Retake pending | Current pose and replacement step, original shared time | New evidence invalidates old acceptance; no stale callback may reapprove it |
| Retakes exhausted | Retakes used and the real unresolvable evidence state | Service decides no-contest when participation cannot be valid; no fabricated zero or new attempt |
| Submission pending | Submitting poses, relevant repeat action disabled, Safety and Exit usable | Reconcile one selected set and one match; unknown receipt is not success |
| Own set submitted | Camera off, Poses submitted — You can relax, actual opponent status | Set stays locked unless the service authorizes a specific recovery |
| Opponent unfinished or reconnecting | Avatar or silhouette and neutral current or stale progress | No local winner, pressure message, or opponent still |
| Both sets received, checks pending | Real named checking stage and truthful phase clock | Judgement deadline already runs from receipt; no fresh thirty seconds after checks |
| Judging | Honest shared activity and stage, safe visual dismissal when permitted | No provisional body score, streamed verdict, percent, or fake five-second countdown |
| Slow processing | Still uploading, Still checking, or Still judging, according to actual state | Acknowledge delay without inventing progress or promising a finish time |
| Capture or judgement deadline reached | Appropriate deadline message; capture disabled where required | Await the service's final outcome; distinguish unknown outcome from confirmed no-contest |
| Offline or receipt unknown | Reconnecting or Awaiting confirmation; camera shielded | Stop acquisition; reconcile the same match and receipts without resetting clocks or charging again |
| Recoverable interruption | Camera paused, real grace when known, Resume when eligible | Reconcile first, then deliberate resume within both the grace and unchanged phase deadline |
| Camera denied or restricted | Correct permission explanation and helpful Settings or return action | No repeated system prompt, fake feed, or rated library substitute |
| Camera busy, absent, removed, or disconnected | Resource-specific status and useful Retry or deliberate camera-change route | No silent camera substitution; preserve the original time and evidence-continuity rules |
| Stop camera | Immediate shield and Camera paused; Resume when still valid | Stop is not an automatic forfeit or a fabricated grace extension |
| Safety or privacy presentation open | Camera and private evidence shielded; owned sheet or route | Deadlines continue; no unnoticed acquisition behind a form |
| Block pending | Immediate local shield and confirmation-pending language | Do not claim cross-device exclusion before acknowledgement; after Go, block alone does not leave |
| Sharing withdrawal or restriction | Immediate relevant protection and truthful state | Follow F29-E's distinct processing and paired-viewing consequences; no new unconsented transfer |
| Inactive, minimized, locked, or backgrounded | Private cover and no active acquisition or decoration | Restore the same service state; camera never resumes or captures merely because the app becomes active |
| Secondary window or device | Authorized same-match status and route to the owner | No second camera, match, timer source, or allowance reservation |
| Confirmed result, forfeit, or no-contest | Immediate handoff to the actual result owner | No locally calculated outcome, repeated award, or gallery for forfeit/no-contest |
| Sign-out, account switch, or deletion | Private content cleared and appropriate account/exit route | No prior-account preview, selected still, report draft, badge identity, or result leakage |

## Safety, Exit, and Consent During the Battle

Safety, Exit, and the active-camera stop control remain reachable during every capture, review, upload, and waiting state. Opening safety pauses acquisition and cancels an armed shutter immediately; it does not wait for sheet animation. The person is never required to continue posing or display an objectionable image to reach help. Shared reports and block actions retain their real receipt, offline, and immediate-local-protection behavior.

Before authoritative Go, Exit is Cancel match. Cancellation releases the reservation without a rating or started-match allowance consequence when accepted before Go. Pending cancellation stays pending until confirmed. If Go wins the race, display the started state and request a new deliberate decision rather than translating the old cancellation into a forfeit.

After Go, an explicit competitive departure presents Forfeit and leave only with the actual consequence: an otherwise eligible confirmed forfeit can be rated and consume the slot; service-established invalid evidence, safety abort, or service failure has no-contest precedence. Keep a non-destructive return action. A spinner, Escape key, sheet dismissal, timer expiry, block, report, or operating-system interruption is not a confirmed voluntary forfeit.

Stop camera is immediate and independent of those competitive decisions. If the person resumes, reconcile the match and reacquire deliberately. A local stop, report form, badge detail, or camera-change confirmation never grants extra capture time. If validity cannot be restored, the service supplies the outcome; the interface must not promise a free cancellation or infer a physique loss.

Processing withdrawal stops new acquisition and affected transfers immediately, with the truthful warning that already accepted processor work may not be retractable. Withdrawal of only paired-opponent image access after Go revokes future viewing but does not itself cancel separately authorized judging or alter rating. Privacy help does not force an involuntary forfeit. The owned privacy route supplies the full recipients, retention, copy-risk, and consequence explanation; minimal text on the stage never removes those disclosures.

The stage exposes no pre-result opponent still to hide or report. Its Safety action targets the permitted identity or match context that actually exists. Post-result image reporting remains available beside the image or its unavailable placeholder without requiring enlargement. Local protection takes effect immediately; case submission and cross-device block protection are not claimed until confirmed.

## Lifecycle and Device Recovery

Any app or window deactivation, minimization, screen lock, background transition, capture interruption, or relevant permission loss stops acquisition and shields private content immediately. On iPhone, app-switch snapshots must not retain body stills. On Mac, an inactive or minimized window must not retain an unnoticed acquiring preview. Decorations pause, but authoritative match deadlines continue.

A modal safety, privacy, guide, or badge-detail presentation that obscures the active capture pauses acquisition rather than hiding a live camera behind it. If scrolling takes the upper camera panel entirely out of view, the stage cancels an armed capture and pauses acquisition; the persistent action becomes Return to camera. Returning reveals Camera paused, then requires a deliberate Resume camera action. Ordinary layout updates while the panel remains visible do not restart the resource.

Resume first retrieves the current match, selected versions, acceptance, deadlines, permissions, and camera ownership. It never automatically takes another still or sends an unreviewed candidate. A service-recognized interruption may use the twenty-second grace, but no more than the existing capture or judgement deadline permits. If both complete final sets were already received, the service may finish judging without the client; returning retrieves that outcome rather than turning absence into a new no-contest.

A camera change after Go is deliberate and warns that the person's selected set must be discarded and recaptured in the remaining original period. It does not reset already consumed retakes, charge another match, or present a second participant. If the shared continuity and opportunity rules cannot support a valid new set, the change is not advertised as a recovery that will work. A disconnected external or Continuity camera is first an interruption; it is not consent to this discard-and-switch action.

On Mac, Escape first cancels an armed self-timer or dismisses the top non-destructive presentation. An unsent meaningful report draft follows its own discard confirmation. At the unobstructed stage, Escape invokes the state-aware exit request, never immediate forfeiture. Return and Space activate only the focused semantic control and never a global shutter while a person types in a report or another app field.

Cmd-W, the close control, and normal quit request the shared phase-aware confirmation where the platform permits interception. Closing a non-owning status window does not end the owning match. When judging can safely continue, closing the waiting surface is distinguished from explicitly forfeiting. Force quit, process loss, power loss, and operating-system termination cannot be prevented or recorded as an explicit confirmed forfeit. Recovery reconciles service truth.

Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. If an existing command changes focus or navigates away, the shared lifecycle stops the camera and protects the stage without stealing or redefining the command.

## Accessibility, Focus, and Concise Language

The normal reading order is phase heading and timer, safe actions, Your complete identity and badge group, Opponent's complete identity and badge group, You and the current pose, Opponent and actual stage, then the current action region. Accessibility containers retain that ownership even when visual wrapping changes. Redundant decorative athletes and background layers are not separate focus stops.

Entering capture announces the phase and current pose once. Entering review moves focus to Review pose and makes Not sent and Use pose discoverable. A deliberate next-pose action moves focus to that pose's heading. Asynchronous acceptance updates the exact slot without repeatedly stealing focus. A rejection announces the named affected pose once and leaves a stable route back to it. A critical stop, permission loss, or terminal result can move focus to its new heading because the former action no longer exists.

The top timer has an accessible phase and time value but is not a per-second live announcement. Announce the start, meaningful shared warning milestones, armed-capture start, interruption, and final stage once under F29-G-a. Optional spoken shutter cues do not duplicate VoiceOver speech. The interface never reads every interpolated counter or shouts an urgency message on every tick.

Named controls preserve stable Voice Control phrases such as Capture, Cancel capture, Use pose, Retake, Submit poses, Stop camera, Resume camera, Safety, and Exit even when their visible supporting time or count changes. Keyboard and Switch Control users can reach every pose, badge detail, recovery action, and safe exit without swiping or hovering. Focus is visible and is restored to the correct invoking control after a native sheet or popover closes.

Missing, stale, checking, accepted, rejected, and submitted evidence use distinct text and symbols, not color alone. Use readable primary or secondary ink rather than dimming a necessary error into background decoration. Reduced Transparency uses opaque surfaces; increased contrast retains meaningful boundaries. Enlarged text does not cap earned badges, hide an instruction, or shrink the entire stage.

A person unable to perform the required comparable pose receives a private evidence limitation and can stop safely. There is no disability inference, body-score penalty for missing evidence, or false claim that any arbitrary substitution supports the same comparison. Detailed fairness and eligibility remain with F29-B and F29-D.

## Animation and Interruption Contract

Motion communicates real stage changes while the player's frame, timer placement, and ownership remain stable. This child coordinates the shared components; it does not implement a second background, digit animator, press style, or camera transition engine.

| Trigger | Visible response and proposed timing | Interruption, accessibility, and energy behavior |
| --- | --- | --- |
| Stage entry from the real paired start | The same owner rails and large panels settle into place over about 300 milliseconds; no body scaling or swapping | Current state and safe controls are available immediately; Reduce Motion uses an immediate layout or short opacity |
| Button press | Existing tactile spring, response 0.24 and damping fraction 0.88 | Shared behavior only; disabled actions do not press and reduced motion adds no scale |
| Each real start-countdown second | Shared numeral emphasis no greater than about 1.08 scale, settled within 220 milliseconds | Lost eligibility cancels the sequence; no accumulated or replayed ticks after resume |
| Authoritative capture-time change | Stable timer digits change over about 180 milliseconds | No header relayout, per-second VoiceOver interruption, or stage-wide animation |
| Armed local self-timer tick | A contained cue in the upper instruction region, using the shared countdown vocabulary | Top match clock stays unchanged; cancellation is immediate; no body flash, screen strobe, or camera shader |
| Current pose selected | Pose name and neutral guide replace within about 180 milliseconds; the media frame does not travel | New selection cancels old cue; Reduce Motion replaces it statically; no automated pose carousel |
| Captured review becomes ready | Exact redacted still replaces the safe preparation surface with at most a 160-millisecond opacity change | Never fade through an unmasked original; image work finishes outside animation; rejection can shield immediately |
| Actual acceptance or rejection | The affected slot's symbol and label respond once within 180 milliseconds | No provisional success; stale versions trigger nothing; a newer state replaces unfinished feedback |
| Submission confirmed or waiting phase changed | Header/footer content resolves over about 280 milliseconds, keeping rails and panel geometry stable | Camera stop and set locking are immediate; no animation completion is required to navigate |
| Real reconnect or resource loss | Sensitive imagery shields immediately; the safe status may replace over up to 160 milliseconds | Protection has zero decorative delay; resume never replays the original Ready or Go ceremony |
| Quiet active-stage atmosphere | At most one low-contrast shared ambient layer, approximately a twelve-second cycle | Never affects bodies or framing; pause for focal countdown events and stop offscreen, inactive, minimized, backgrounded, low-power, or thermally constrained |
| Confirmed final-result handoff | About 300 milliseconds of stage continuity into the result owner's arrangement | Outcome and safety appear immediately; score and Elo choreography belongs to F29-G-d and fits its single sub-900-millisecond result window, not an extra serial ceremony |
| Badge unlock or correction | Delegate the actual confirmed event to F29-F | No pulsing badge wall, duplicate award, or new unlock triggered by reopening the stage |
| Hide, block, consent revocation, stop, or account change | Immediate protective replacement | Never waits for the preceding transition, a countdown completion, or focus announcement |

At most one quiet ambient layer and one focal event are active. The countdown takes priority over atmosphere. Retake feedback does not shake a body or imply blame. Results do not humiliate the opponent, animate them smaller, or project a winner before finality.

Reduce Motion removes scale, travel, ambient repetition, and decorative counter motion. Necessary state changes use static replacement or a brief opacity response of roughly 120 milliseconds or less; privacy removal stays immediate. Reduced Transparency uses the shared opaque fallback. Optional audio and haptics never carry information alone.

Low power, thermal pressure, inactivity, minimization, and offscreen presentation suppress decorative work before essential state clarity. Do not decode images, measure fonts, rebuild camera sessions, access files, or make provider/network calls on animation frames or every digit tick. Timer updates affect the timer; pose acceptance affects the named pose; neither invalidates the entire live-camera composition. On return, display the latest real state without replaying missed animation events.

## Data and Privacy Invariants

The trusted service owns the match, Go, deadlines, receipts, accepted versions, locked set, outcomes, Elo, allowance, and corrections. The local camera foundation owns permitted acquisition and exact redaction. The stage owns neither a shadow competition state nor an optimistic outcome.

Only clean face-obscured capture content and the authorized evidence context reach the protected pipeline. Country, handles, flags, badges, Elo, screen text, and stage chrome never become judge images or judging context. Uploading a screenshot of this battle stage is not an evidence path. Privacy masking never reshapes scored regions, and mirrored self-positioning never silently changes the orientation of submitted evidence.

No image-based age, sex, gender, ethnicity, identity, health, body-fat, or muscle-mass inference is part of guidance. Private adult and attire declarations remain private. Permitted clothing is not a scoring bonus or penalty; all groin and buttock coverage rules remain in force. No ordinary absence or unknown state becomes a numerical zero.

No counterpart still is fetched or displayed during this live stage. Finalized still access is intentional, current-permission gated, moderated, and ordinarily expires twenty-four hours after finalization. Block, report protection, deletion, withdrawal, and expiry cannot be bypassed with a cached thumbnail, another window, or an old link. Privacy protection does not promise anonymity or prevention of screenshots and external recording.

## Dependencies, Files, and References

### Required reviewed foundations

The real account/session and navigation foundations, authorized HTTPS service, camera and local redaction path on both platforms, accepted evidence and timing contract, protected uploads, judging configuration, safety operation, identity/badge authority, and shared native components must be implemented and human-reviewed before this stage is integrated as a rated feature. A preview fixture, an inactive button, or a simulated opponent is not that foundation. Independent documentation ownership does not make this view independently shippable.

- [F29 parent](../../DOCKS.md), [F29-A flow](../DOCKS.md), [F29-B judging and evidence](../../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-C match authority](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety](../../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy and operation](../../F29-E-privacy-and-service-operation/DOCKS.md).
- [F29-F identity and badges](../../F29-F-battle-identity-and-badges/DOCKS.md) owns every public badge's meaning, order, freshness, and correction.
- [F29-G native components](../../F29-G-native-ui-components/DOCKS.md), including [phase clock](../../F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md), [player panels and pose icons](../../F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md), [battle atmosphere](../../F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md), [result counters](../../F29-G-native-ui-components/F29-G-d-score-counters/DOCKS.md), and [Mac shell](../../F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md).

### Owned documentation and prospective integration

- This document owns battle-stage product behavior.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-i-phase-1-battle-stage.md) owns the prospective connected implementation and human-review handoff.
- The prospective TimeMaster/Views/Physique/PhysiqueBattleStageView.swift owns this composition under the established feature architecture. Existing integrated flow and shared component files remain with their owners; no parallel camera, timer, badge, safety, or result mechanism is established here.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), [Profile design](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared glass controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) supply palette, typography, spacing, native material fallback, and press feedback.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) and [exercise duel HUD](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) are visual-language references only. Their exercise scoring, provisional lead, image-privacy promise, fixed dimensions, and text clamps are not copied into Physique.
- [Native app shell](../../../../TimeMaster/App/TmaxApp.swift), [Mac commands](../../../../TimeMaster/App/TmaxCommands.swift), and the [project configuration](../../../../TimeMaster.xcodeproj/project.pbxproj) define existing native windows, reserved shortcuts, and deployment compatibility. Retain iPhone iOS 16 compatibility and native macOS 14 support; newer effects use public availability fallbacks.

### Design references and precedence

The [supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) contributes an obvious timer, direct participant hierarchy, and accessible exit/report access. Its side-by-side layout, faces, footage, purple/brown badges, captions, and implied rights are not adopted. Future pose art uses original or appropriately licensed neutral fitness figures or the app's ivory-and-orange athlete family; this document does not claim those assets exist.

[Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices, supports flexible native windows, useful wide-screen context, keyboard and pointer input, and standard menu access. [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Providing feedback, supports purposeful, brief, cancellable motion with equivalent non-motion information. The specific vertical arrangement and timings here are product decisions, not claims that Apple mandates this sports layout.

The user's newer vertical-only, native-Mac, all-badges, tactile-motion direction supersedes older F29-A wording that permits a balanced two-column Mac comparison or treats Mac as incidental. This child does not authorize changes to unrelated result-detail layouts. The main F29 owner reconciles shared wording and component contracts; no global style file, target increase, web implementation, or policy-approval claim follows from this design.
