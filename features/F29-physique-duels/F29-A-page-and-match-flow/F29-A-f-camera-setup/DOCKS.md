# F29-A-f — Camera Setup and Preflight

## Purpose and Boundary

Camera setup lets an eligible participant choose a real camera, arrange a safe full-body view, and understand the exact local face obscuring before starting opponent search. It is a native iPhone and native macOS surface within [F29-A](../DOCKS.md), not a separate camera app, practice competition, image editor, or photo-library submission route.

This document specifies product behavior and the future implementation boundary. It does not claim an implemented camera, calibrated detector, accepted prototype, completed privacy evaluation, or human approval of the earlier proposed competition defaults. [F29](../../DOCKS.md) and its judging, rating, safety, and privacy areas retain authority over the competition.

This component owns the local self-preview, camera authorization and availability presentation, device selection, framing and lighting cues, local privacy review, and camera-specific interruption recovery. Account access, adult and attire declarations, detailed consent, pose instruction, matchmaking, the battle shell, timed rated capture, moderation decisions, and results remain with their respective owners. Setup links to those real routes; it does not create substitute screens or pretend that a local check grants service eligibility.

## Chosen Direction — A Framing Lane, Not a Camera Dashboard

The composition is one large self-view with a quiet perimeter, a short current instruction, and one primary action appropriate to the current step. A compact device row and four named check states sit outside the image. A brief local check holds an exact redacted sample in the same aperture for deliberate privacy review; it is never a rated pose or an upload.

This choice avoids a multistep permission wizard and avoids sports-HUD chips covering shoulders, arms, or legs. It adds a deliberate local review before search, trading one extra action for a clear view of the actual privacy treatment. The local check is not described as verified identity, approved attire, moderation acceptance, anonymity, or a guarantee that subsequent images will be valid.

The existing near-black background, dark elevated surfaces, white or ivory content, orange shared actions, Inter Black headings, and Inter Regular supporting copy remain the visual language. Camera pixels receive no tint, glass, beauty filter, body reshaping, artificial definition, or animated shader. Normal native materials belong only to surrounding controls, with opaque fallbacks. Existing spacing and control styles determine rhythm; this feature does not introduce a new global theme or fixed screen coordinates.

## Visible Hierarchy

### Standalone Preparation on iPhone

The navigation area contains Camera setup, the existing back or close control, and a labeled Pose guide action. There is no countdown, opponent, earned award, or ninety-second clock before a real queue or match exists.

The self-view is the largest content region below the heading. Its container uses the available measured width and the actual correctly oriented frame aspect ratio. A portrait iPhone source fills a portrait-friendly stage; a source with a wider ratio is aspect-fit with honest matte space. The app never crops limbs to make the preview look taller, fills a portrait box by cutting a landscape frame, or enlarges one anatomical region independently. Rotating the phone changes presentation geometry without stretching the source or substituting an earlier frame.

A quiet matte border contains framing corners just outside the evidence image. There are no labels, country flags, badges, checkmarks, progress bars, or controls on the body. A conventional camera or privacy-cover symbol is used when no valid frame is available; it is explicitly not a preview of a person.

Immediately below the aperture, a status line distinguishes Camera active, Camera off, Checking locally, and Local check · not sent. The selected device has a persistent Camera label. Framing, Light, Privacy, and Alone each have a text state and a corresponding symbol. They wrap into readable rows rather than shrink into tiny icon-only chips. The short current correction appears above the action area. All blocking reasons remain discoverable in Setup details, without hiding a privacy stop or the immediate recovery instruction.

The primary action progresses through Start camera, Check setup, and Find opponent. Its label names the current operation; it is not a permanently enabled Continue button. Stop camera remains visibly available while acquisition is running or starting. During a held local review, Adjust setup replaces that stop action because acquisition is already stopped. Close remains reachable in every state.

The body scrolls on short screens, in landscape, and at accessibility text sizes. The primary action, camera stop when relevant, and safe exit use the app's measured safe-area and navigation clearance rather than a fixed bottom spacer. They can wrap without covering the preview. Touch targets follow the existing forty-four-point convention. A large readable preview is allowed to extend through the scrollable stage rather than being compressed to keep every check on one screen.

### Native macOS Preparation

This is a native macOS 14-or-later view inside the existing Tmax title-bar window, not Catalyst, a browser panel, or a full-screen iPhone sheet enlarged to desktop size. It preserves the current 800-by-600 minimum rather than demanding a larger app-wide minimum.

The normal title bar and window controls remain intact. A contextual toolbar names Camera setup and exposes the native Camera pop-up and Setup details. The principal area contains the large aspect-fit self-view and current instruction. A native-density action row below the stage contains the current primary action, Stop camera when relevant, and Close. It does not become a phone-sized floating action capsule.

On laptop and larger windows, secondary framing, light, privacy, and device explanations can occupy a trailing nonmodal setup inspector. The inspector is supplementary: the current blocker, selected camera, stop action, and primary action remain understandable without opening it. At the existing minimum or in a short window, those details move into the stage's ordinary vertical flow or a native disclosure, not a second participant column and not a new modal wizard. Opening an inspector does not create another camera owner.

The preview uses the remaining measured stage geometry while supporting the actual camera's aspect ratio. A Mac's landscape camera is not advertised as a portrait sensor and is not secretly cropped into one. The person can reposition a stable camera to obtain the required body evidence. There is no demand to stand a particular distance away or meet an invented pixel-size target.

Full-screen mode retains window affordances through the platform's normal behavior. Moving between built-in and external displays updates layout and drawing scale without changing the selected camera, reopening authorization, restarting preflight, or resetting a match. Live resize reflows controls and keeps the preview aspect-fit; it does not repeatedly rebuild acquisition. Short windows scroll the central stage while the current real timer, if any, and safe actions remain reachable. Trackpad and wheel scrolling are ordinary native scrolling, not a custom gesture system.

### When Embedded in an Existing Battle

Standalone preflight does not fabricate a second player merely to imitate a battle. If camera recovery appears after a real pairing, it stays in the existing battle composition. The real authoritative timer remains the top visual anchor. Below it are both complete public identity and badge rails, grouped by owner. Below both rails are two large vertically stacked panels, You first and Opponent second, at every iPhone and Mac width, including full screen and external displays.

Camera setup occupies the own-player panel or its immediately associated control lane. It does not overlay the opponent panel, move identities onto body pixels, or replace the matchup with a side-by-side Mac comparison. All public badges from the trusted identity owner remain represented and wrap above the players; no three-slot cap, hidden +N, clipped row, ticker, or hover-only explanation is allowed. The central stage may scroll rather than shrink the players to fit the badge content. Timer and safe actions remain reachable without requiring an unbounded pinned badge wall.

The opponent remains a permitted avatar or neutral silhouette plus actual stage or accepted-pose count. Camera recovery never reveals live opponent video, an early pose image, a provisional appearance score, or a locally invented readiness state. The trusted identity owner supplies any public handle, self-declared country or region, current tier, streak, and earned badges; this component does not derive them from local Profile cosmetics or the camera.

## Preparation Flow

### Entry and Camera Start

Opening rules, browsing the lobby, entering account details, or reading consent does not start acquisition. Camera setup is reached only through the real participation route after its required adult, attire, rules, and sharing decisions. Legal sharing consent remains separate from camera authorization.

The idle surface says Camera off with the practical instruction Fit arms and legs in view. The primary action is Start camera. If authorization is undetermined, this deliberate action opens the real system camera alert directly in the current native context. There is no counterfeit permission alert, reward for accepting, annotated system-alert image, or instruction to choose Allow. A separate permission pre-alert is unnecessary. Already granted camera access permits local startup only; it is not consent to hosted AI processing or counterpart sharing.

While the actual camera starts, the aperture shows an opaque neutral cover and Starting camera. Start is busy, repeated requests do not create sessions, and Stop camera or Close can cancel the pending intention. A late permission answer or device-start callback must not expose a frame or restart acquisition after stop, navigation, inactivity, account change, or loss of ownership. Camera active appears only after fresh frames from the selected authorized source are actually arriving.

### Live Guidance

The live self-view stays on the device and uses local face obscuring. It is not sent as video, archived continuously, or sampled for routine remote analysis. Before a fresh frame can safely be rendered by this processed preview, a neutral cover is used; an earlier frame with a newly misplaced mask is not a substitute.

The chosen orientation is upright and unmirrored for both the live self-view and every exact review. This sacrifices the familiar selfie-mirror convention to keep side and shoulder meaning consistent between preparation and submitted evidence. Camera details explains The view is not mirrored. There is no mirror toggle, horizontal flip animation, or silent left-right exchange at capture. Platform camera metadata and device orientation must not produce a second, accidental mirror operation.

Four local checks describe evidence adequacy, not body quality:

| Check | Ready meaning | Correction and boundary |
| --- | --- | --- |
| Framing | The required shoulder, arm, upper-back or stance context as applicable, thigh, and calf evidence can fit without material cropping or severe perspective distortion | Show a concrete correction such as Include both arms and lower legs or Keep the camera steady. Do not force facial visibility, reward apparent size, prescribe an exact camera distance, or infer a diagnosis from a pose. |
| Light | The local view has enough ordinary, even illumination to inspect required regions | Use ordinary guidance such as Use more even light or Move the bright light behind the camera. No definition score, body-fat estimate, skin-tone rating, dramatic-shadow recommendation, mandatory flash, or photographic equipment prestige. |
| Privacy | The local pipeline can safely obscure any visible face areas without hiding required scored regions | Checking is distinct from Mask ready. If this cannot be established, show Can't prepare face privacy and block the check or transfer. Do not lower masking strength to expose a shoulder. |
| Alone | Local evidence supports a single participant without another person in the view or an unresolved reflection/background ambiguity | Use Only you in frame or Check mirrors and background. A second person invalidates the view even if their face is masked or the participant says they consent. No age, identity, sex, or gender inference. |

The order of correction priority is privacy or extra-person risk, unavailable or stale camera, framing, then light or steadiness. This is a presentation priority, not permission to hide additional blockers. In a usable state, the instruction becomes Ready for a local check. In an uncertain state, say Can't check this view with a practical adjustment rather than a false all-clear. Readiness never claims that a local detector can prove consent, adulthood, liveness, identity, attire eligibility, or that every bystander has been found.

Cues do not jitter between competing instructions on each frame. A local readiness improvement must be sustained by fresh evidence before the ready cue settles. A newly identified privacy defect, extra person, stale source, or disconnect disables continuation immediately, without waiting for that presentation settling or any animation. The later implementation must use the reviewed capture-validity policy rather than invent a numerical confidence threshold in the UI.

### Exact Local Check

Check setup is enabled only with a current authorized camera, fresh usable local evidence, and the required local privacy pipeline available. Tapping it takes one transient local diagnostic still from the selected source. Acquisition then stops, the live label changes immediately, and the surface says Checking locally while the safe representation is prepared. No raw frame is shown beneath a fake processing indicator.

The sample uses the same actual privacy treatment, upright orientation, evidence dimensions, and clean image preparation that the rated path will use. Every visible face area receives a non-reversible opaque local occlusion, not a translucent cosmetic blur. There is no button to reveal the original, shrink the mask, reshape the body, edit a region, or substitute a different photograph. A rear or face-out-of-frame view does not require exposing a face; the privacy process must distinguish an adequately established absence of a visible face from a failed or uncertain analysis.

A successful sample appears in the same large aperture with Local check · not sent. Its visible masked pixels are the diagnostic representation being reviewed, not a decorative mask drawn by a separate overlay over an unmasked saved image. No badge, country, handle, framing corner, cue, or app chrome is baked into it. The person's scored regions are otherwise unchanged. Face obscuring must not remove a bystander and turn an invalid sample into an eligible one.

The diagnostic sample is not uploaded, scored, stored in Photos, used as a front/side/rear pose slot, charged as an allowance, or counted as a retake. Unnecessary originals and failed local samples are discarded; the successful masked diagnostic is transient local review material, discarded on leaving, backgrounding, switching camera, or restarting setup. It is not a recoverable body-photo archive.

Find opponent is the primary action after a successful review. Adjust setup returns to live local preparation by explicit action and invalidates that review. If a check fails, the sample is not treated as reviewed: show the private reason, an opaque cover when the view is unsafe or unclear, Adjust setup, and Close. A local failure is not a misconduct finding or an Elo result.

### Starting the Real Search

Find opponent means start the real search, not capture a rated image. The action first explicitly resumes the selected camera and establishes fresh local validity. The held diagnostic does not prove that the camera remains connected, the room is unchanged, or consent is current. If anything has changed, return to the live correction state without queueing and explain the actual blocker.

The parent then resolves the current account, required sharing, independent allowance, one-active-match ownership, and service-health state before admitting a real search. During this operation, show the actual named stage, prevent a repeated search request, and keep privacy stop and safe exit usable. A local check never reserves a fictitious slot, starts its own deadline, assigns an opponent, or overrides service denial. The diagnostic sample does not accompany the search request.

A successful search admission transfers presentation to the existing search owner without constructing a second camera session. A failed admission remains an honest error with the permitted Retry, account, consent, or return route. No camera check or retry silently joins a second queue. The live camera remains local and no rated evidence is captured before the authoritative Go boundary.

Each later rated candidate and selected still must independently receive the same fail-closed local face treatment and exact pre-transfer review required by F29-A, F29-D, and F29-E. A successful preflight sample is never standing authorization to upload an unreviewed original later. The timed-capture owner owns that exact candidate review and transfer sequencing; this setup does not relax it to meet a latency target.

## Device Choice and Camera Integrity

On iPhone, the Camera control offers actual supported front and back sources with concise names, plus any other source genuinely supported and exposed by that OS and device. It does not present external-camera or Continuity choices on hardware that cannot use them. The initial choice is the real available source selected by the existing camera policy, visibly named; an explicitly remembered source may be restored only if still present and usable. There is no fake studio preset, body-enhancing lens, digital zoom control, beauty mode, or photo picker.

On Mac, a native pop-up lists the currently enumerated built-in, supported external, and OS-provided Continuity cameras using their actual local display names. Selected state is explicit. A single-camera Mac still shows which camera is in use; it does not show a dead switch button. A missing source is not called permission denial. Connecting Continuity is an operating-system setup task, not an in-app imitation of Apple's pairing UI. Device-name text is not a public competitive identity or judging input.

Selecting another source stops the old acquisition first, covers the aperture immediately, cancels the previous local check and pending continuation, and clears stale readiness. New frames are accepted only from the selected current source. Starting the replacement is a real operation, not a crossfade between cached bodies. The person sees the new source name, fresh guidance, and a new local check before a standalone search can start.

Hot-plugging a source can update the list without stealing the selection. If the selected source disappears, show Camera disconnected and its unavailable selection; do not silently fall back to a built-in camera that may face another room or person. Reconnection makes Retry camera or an explicit replacement choice possible, not automatic acquisition. Continuity interruptions, closing a laptop lid, disconnecting a camera's hub, and a sleeping external camera follow the same fail-closed rule when they stop real frames. The UI does not claim it can diagnose the physical cause unless the operating system actually provides it.

If a platform camera enhancement or virtual source cannot meet the reviewed evidence-integrity contract, explain that the selected source is unsupported for rated capture. Do not invent perfect virtual-camera detection or silently accept an appearance-altering feed. Ordinary privacy occlusion and consistent orientation are not prohibited body manipulation. Available system effects are not ranked bonuses; setup does not add or recommend them.

## Actual States, Actions, and Recovery

| State | What is visible | Actions and consequence |
| --- | --- | --- |
| Camera off, permission not yet requested | Camera symbol, Camera off, ordinary setup instruction | Start camera invokes the real system authorization only on deliberate action. Close returns without upload, charge, or rating effect. |
| Authorization unresolved | The system alert and a covered underlying aperture | System choice remains authoritative. Repeated app taps cannot stack alerts. Navigation or a lost active owner prevents a delayed grant from starting acquisition. |
| Authorized, starting | Starting camera and a neutral aperture | Stop camera and Close cancel the intention. Check setup and search are unavailable until fresh usable frames exist. |
| Active, locally checking | Large processed self-view, Camera active, named check states | Check setup is available only when actual gates permit it. Stop camera acts immediately. |
| Ready for local check | Stable framing corners, named usable states, concise ready instruction | Check setup produces only the transient diagnostic described above. No queue or upload. |
| Diagnostic processing | Checking locally; acquisition is stopped; no raw fallback | Close cancels and discards local material. A real failure receives its specific recovery, not fake completion. |
| Successful local review | Large exact masked sample, Local check · not sent | Find opponent explicitly rearms and revalidates before real queue admission. Adjust setup invalidates the diagnostic and resumes local preparation. |
| Framing, light, or steadiness inadequate | Concrete current correction and all named blockers | Adjust position or ordinary lighting, then make a fresh local check. No body score, exposure request, or fake detector percentage. |
| Additional person or ambiguous reflection | Only you in frame or Check mirrors and background; unsafe diagnostic withheld | Remove the extra person or unclear view and retry locally. Masking a bystander, a consent claim, or a manual override cannot approve it. |
| Face privacy unavailable or uncertain | Can't prepare face privacy; opaque cover where required | Adjust setup or Close. No transmitted candidate, raw reveal, weakened mask, or original upload fallback. |
| User denied camera access | Camera access is off and a short explanation | On iPhone, Open Settings uses the supported app-settings route. On Mac, Open System Settings offers the real camera privacy route when available. No repeated system prompt. |
| Camera restricted by policy or device controls | Camera access is restricted, distinct from denial | Explain that device or administrator restrictions must change outside the app. Do not offer a permission retry that cannot work; keep Return and helpful platform instructions. |
| Settings route unavailable or unchanged | Correct current authorization and a readable manual path | Explain Settings or System Settings → Privacy & Security → Camera using the platform's current labels; reopening the same screen is not proof of a grant. Retry only rechecks real state. |
| No supported camera | No usable camera and no person-shaped fake feed | Connect or select a real supported source when possible, Retry camera, or Return. Simulator and unsupported hardware do not receive rated library input. |
| Selected camera busy or failed to start | Camera unavailable with the safe operating-system reason when known | Retry camera or choose another actual source. Do not label another app as the cause without evidence or request microphone permission. |
| Selected external or Continuity camera disconnected | Camera disconnected, source name, immediate neutral cover | Retry the returned source, explicitly choose another source, or Close. No silent fallback or old frame labeled live. |
| Frames stop but connection still appears present | Waiting for camera, cleared local readiness, covered aperture | Retry or switch supported source. A stale image cannot keep Find opponent or Ready eligible. |
| App inactive, minimized, hidden, locked, or backgrounded | Privacy shield instead of camera, diagnostic still, or sensitive account detail | Acquisition and local diagnostic work stop immediately. Returning restores real ownership and service stage before offering Resume camera. |
| Other window or device owns the active session | Session active elsewhere, no local acquisition or second queue | Open the actual owning local window when possible, or continue on the owning device. A real shared restoration policy, not local assumption, decides any later resume. |
| Account, eligibility, consent, or service state changes | Specific upstream requirement or honest service failure | Stop acquisition and prevent new transfer as required. Use the owning account, consent, privacy, or recovery route; do not turn setup into a new consent form. |
| In-match camera interruption | Existing battle shell, real timer, own privacy cover, actual connection state | Resume camera when allowed or use the state-aware Leave route. Local setup does not declare a forfeit, no-contest, restored allowance, or reset deadline. |
| Final set already submitted or match finalized | Parent's actual waiting or result surface; camera off | Do not restart capture, discard valid locked evidence, or trigger no-contest merely because the camera is now absent. |

If the actual native configuration is missing camera capability or a required usage description, it is a product-availability defect, not something the person can cure by repeatedly granting TCC. A supported release must provide correct camera capability and honest recovery. This document does not claim that the current targets already meet that requirement.

## Interruption, Readiness, and Active-Match Recovery

Stop camera, leaving the surface, an operating-system interruption, inactivity, minimization, app hiding, lock, backgrounding, sign-out, and loss of session ownership stop acquisition and shield sensitive content immediately. No closing spring, pending local check, native sheet transition, or provider request may defer protection. Originals and the diagnostic review are not left visible in app-switch snapshots. This is not a promise to prevent screenshots or external recording.

Opening a separate Pose guide, legal information, safety form, or external settings route stops the camera rather than concealing acquisition behind another surface. Returning offers an explicit Resume camera after the real stage is restored. A native device pop-up or the visible nonmodal setup inspector is part of the camera surface and may retain acquisition while that owner stays active and the preview remains visible; dismissing those controls alone does not restart a stopped camera.

On Mac, app deactivation, the owning window becoming inactive, minimization, hiding, closure, fast user switching, sleep, and revoked TCC all require the same immediate stop. A secondary window cannot grab the camera because it appeared. There is one camera owner and at most one reserved or active Physique match per account across windows and devices. An owning-window change must follow the reviewed shared ownership contract; it cannot create a second search, allowance charge, or competing capture pipeline.

Before Go, camera failure or stop removes local Ready eligibility and informs the real match coordinator. The service owns whether pairing, cancellation, or the start boundary was accepted. If a cancellation races with Go, the app restores the actual started match and offers its real choices rather than silently treating a pre-start Cancel as consent to a rated loss.

After Go, the original ninety-second capture deadline and at-most-two-retakes-per-pose rule continue. A genuine interruption can resume the same match inside the shared twenty-second reconnect grace, without extending any original deadline, resetting attempts, or consuming another slot. Local estimated time is not authoritative finality. If the client is offline, show Awaiting match status rather than inventing a no-contest or a successful cancellation.

Resuming the same usable camera requires fresh local privacy and adequacy checks but does not itself discard already accepted poses or spend a retake. Changing the physical source after Go is different: while the capture owner still permits editing, the participant must confirm Restart my poses with the explanation that all their selected poses will be discarded and the original deadline remains. Only a real service-supported invalidation of the person's previous set permits that restart. Stale checks or uploads cannot reapprove the old source's selections. There is no source switch after a locked submission or after judging begins. If valid capture cannot be restored in time, the service determines the no-contest and any once-only allowance restoration.

Stop camera is a privacy action, not automatic Forfeit. It immediately stops acquisition and explains Match timer continues when that is true. Resume and the explicit Leave route remain available. A deliberate confirmed eligible Forfeit and leave is distinct from camera loss, window deactivation, or force quit. Safety or invalid-evidence no-contest precedence remains service-owned. Setup never pressures someone to keep posing or keep sharing while resolving a problem.

## Input, Focus, and Accessibility

The reading order is heading, current local or real match status, public rails if present, own preview with its concise state, device selector, current instruction and named checks, primary action, and safe controls. In an existing battle, the opposite player's large panel remains later in the same vertical sequence. Dynamic Type and text expansion wrap content without truncating a device name, reason, consent consequence, or action meaning.

The preview is one accessible element describing Local camera preview, Local masked check, or Camera off and its current relevant state. It does not expose guessed bodily traits, read a list of vision landmarks, announce coordinates of a face, or repeatedly describe video frames. The check group provides discrete readable values such as Light: more even light needed. Mask ready is never voiced as anonymous or identity verified.

On entry, focus moves to Camera setup. User-triggered diagnostic completion moves accessibility focus to the local review heading or a blocking correction. Repeated framing updates do not steal focus from Camera, Stop camera, Setup details, or another control. A sudden privacy or disconnect failure receives one concise announcement; normal stabilization is announced once when it enables the next meaningful action, not on every frame. In-match recovery announces the interruption and the unchanged deadline, not every timer tick.

Every control has a semantic native action and a concise label matching its visible meaning. Camera and Pose guide remain reachable through Voice Control and Switch Control. There is no swipe-only switch, pinch-only zoom, body gesture to accept, hover-only failure reason, long-press-only privacy reveal, or requirement to reach the phone while holding a strenuous pose. The separate pose-guide owner supplies safe instructions and adaptations; setup never converts an unsupported pose into a low score.

Native Mac keyboard focus follows toolbar, stage controls, inspector or details, primary action, and exit in a predictable order, with a visible focus ring. The native device picker supports its normal keyboard and type-selection behavior. Tab and Shift-Tab work according to macOS keyboard navigation settings. Return and Space activate only the focused semantic control; there is no global capture, search, or resume binding while editing a report, typing elsewhere, or using a picker. The existing Command-N, Command-Shift-R, Command-comma, and Command-Option-O commands retain their meanings.

Escape first dismisses an open native pop-up or details sheet and restores its invoking control. During an unfinished local diagnostic it can cancel that local operation without queueing or uploading. At standalone preflight it closes setup and stops acquisition. In a real queue or match it invokes the parent's state-aware cancellation or leave path; it is never a hidden forfeiture shortcut. Outside clicks cannot silently start search, withdraw consent, or confirm a source change after Go.

Command-W, ordinary window closure, navigation away, and quit requests use the shared active-match consequence confirmation where the platform allows it. A real post-Go eligible forfeit is not the default keyboard action; the safe stay or cancel choice receives initial focus. Camera protection happens immediately even while the confirmation is open, and staying offers explicit resume rather than automatic reacquisition. Force quit and involuntary process death cannot be prevented or confirmed as voluntary forfeits; the service's interruption policy applies.

Color, sound, and haptics are supplementary. Orange may emphasize the next action or usable frame perimeter, but a text state and symbol distinguish readiness, caution, and failure. Respect Increased Contrast and Differentiate Without Color. Reduce Transparency uses opaque readable surfaces behind controls; the evidence and matte remain visually separate. Optional brief haptics acknowledge a successful local check on supported iPhones, respect system settings, and are never repeated per camera frame. Mac interaction does not depend on haptic hardware or audio. No microphone is requested.

## Motion and Energy Rules

The live self-view already provides continuous motion. Setup adds no ambient loop, moving body scan, badge-wall pulse, particle layer, artificial camera sweep, or animated body filter. Sports tactility comes from the shared press spring, a restrained perimeter latch, and genuine step continuity.

| Trigger | Chosen motion | Timing, interruption, and invariants | Reduced-motion equivalent |
| --- | --- | --- | --- |
| Press or release of an enabled action | Existing shared control press feedback | Shared spring response 0.24 and damping fraction 0.88. Disabled or busy actions never fire twice. Stop takes effect before visual release finishes. | No extra scale; native highlight or brief opacity only. |
| Fresh usable framing first settles | The small framing-corner accents settle into a closed perimeter outside the image; the ready symbol changes once | About 200 milliseconds, quick ease-out with no overshoot onto the body. Latest real state wins. A failure clears readiness immediately rather than finishing the latch. | Static corners and an immediate or at-most-100-millisecond opacity change. |
| A normal instruction or check state changes | Only its text and symbol crossfade; aperture geometry stays stable | About 160 milliseconds. Coalesce repeated identical guidance, not privacy failures. No sliding instruction carousel. | Immediate text or a short opacity replacement. |
| Check setup enters or leaves local review | The surrounding status and control lane settle into their new layout; the image is held without scale or distortion | About 280 milliseconds, smooth non-bouncy continuity. The safe sample may appear only when actually ready. No artificial minimum processing wait, image flip, or animation-gated action. | Static layout change with at most 100 milliseconds of opacity. |
| Authorized source change or explicit resume obtains its first fresh safe frame | A neutral covered aperture reveals the correctly oriented new preview | About 180 milliseconds after the safe frame exists. Stop or failure instantly restores the cover. Never crossfade an unmasked or stale source through another person's frame. | Immediate safe replacement or short opacity. |
| Disconnect, failed masking, stop, inactivity, or ownership loss | Immediate opaque privacy cover; status then updates | Protection has no animation delay. A harmless status symbol may fade for about 140 milliseconds afterward. Pending transitions are cancelled. | Same immediate protection and static status. |
| Embedded real battle timer advances | Existing shared timer's stable digit change only | About 180 milliseconds per real change. A missed interval jumps to the actual remaining time; no catch-up playback, countdown reset, or local finality. | Static actual time; no per-second spoken announcements. |
| Native picker, disclosure, guide, settings, or system alert opens | The platform's ordinary transition | No custom overlay choreography. Return restores focus; camera state follows the privacy rules above rather than animation completion. | Native accessibility behavior. |

A readiness latch indicates local framing usability, not a moderation award, badge unlock, face match, or competitive advantage. All actions become usable according to real state immediately, without waiting for the 280-millisecond continuity. Changing Reduce Motion while a transition runs settles to the current static state. A new fault replaces an in-flight success; delayed callbacks cannot replay success or resurrect a stopped preview.

Acquisition, local analysis, and diagnostic work stop when the owner is offscreen, inactive, minimized, hidden, locked, or backgrounded. Decorative work is absent there too. On low power or elevated thermal state, omit the perimeter travel and use the reduced-motion equivalents for optional effects. The capture pipeline may reduce live-preview or guidance work only through its reviewed policy and only while preserving fresh evidence and fail-closed privacy; it must not weaken redaction, invent a usable result, alter the accepted still contract, or extend service deadlines. If safe operation is unavailable, show Camera paused with an honest recovery instead of a stale live view.

Live resize, timer changes, focus rings, and guidance animation must not cause new camera sessions, full-image decoding, device discovery, face work, network calls, or global layout invalidation on each animation frame. There is no artificial high-refresh requirement or continuous hidden render loop. Exact privacy processing and source continuity take priority over a decorative transition.

## Data and Service Authority

Only local frames and the transient diagnostic are involved in preflight. The camera resource permission does not authorize image sharing. No microphone, broad Photos access, location, Contacts, HealthKit, face recognition, identity embedding, demographic estimate, medical inference, or body-composition measurement is part of setup. Required private adult and attire declarations remain upstream and are never guessed from the preview.

A second body is invalid even when masked. Ordinary face occlusion cannot hide scored evidence or become a body-editing tool. Metadata that is unnecessary for judging, including embedded location and personal device details, does not accompany later transmitted stills. The canonical image is the clean redacted capture, not a screenshot containing the timer, badges, handle, country, local checks, or native controls.

The service owns account eligibility, active-match ownership, readiness acceptance, queue timing, Go, deadlines, moderation, finality, allowance changes, Elo, and badge awards. Setup displays actual state but cannot mint authority through a local check. Server unavailable, stale status, and disconnected camera are different states. There is no mock competitor, rated photo-library fallback, local judge, or made-up recovery outcome.

## Dependencies and File Boundaries

- [F29-A — Page and match flow](../DOCKS.md) owns the real entry, pose guide, match shell, capture review, safe exit, and route restoration.
- [F29-B — AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns required comparable regions, evidence integrity, the fixed rubric, and the fact that capture adequacy is a gate rather than a fifth score.
- [F29-C — Rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns one reserved or active match per account, readiness and Go authority, independent allowance, deadlines, reconnect, and finality.
- [F29-D — Safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) owns attire rules, extra-person rejection, safety decisions, practical rejection language, and review access.
- [F29-E — Privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) owns consent, exact local face treatment, resource lifetime, data retention, withdrawal, and protected transfers.
- F29-F's trusted public identity and badge presentation and the parent's shared native foundations are consumed where the existing battle shell is present. Their real contracts must be implemented and human-reviewed before this surface is considered connected; editable local badge previews are not a substitute.
- Prospective TimeMaster/Views/Physique/PhysiqueCameraSetupView.swift owns this composition and its feature-local presentation. The reviewed shared Physique camera-preview and local camera/privacy owner supply acquisition, redaction, source freshness, and ownership; this surface must not create a second pipeline or repeat the exercise camera's joint-only privacy copy.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) remain the shared style and control authority.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) remain the existing native Mac window and command integration points; this component does not redesign them.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-f-phase-1-camera-setup.md) owns the engineering assignment, observable acceptance, and proposed native exercise scenarios. Product behavior stays here; implementation planning remains in CYCLES.md.

## References and Direction Precedence

- [Supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) supplies direct timer-and-participant hierarchy, not licensed people, footage, purple/brown web pills, overlay badges, or a side-by-side layout to copy.
- [RankedMatchPreparationView.swift](../../../../TimeMaster/Views/Ranked/RankedMatchPreparationView.swift) is a nearby pattern for labeled setup actions and permission recovery. Its exercise-only joint-estimate privacy promise, invented suitability for Physique, and calibration values are not imported.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supplies existing sports-control and earned-rating visual language, not Dynamic Type clamps, local competitive levels, or provisional appearance scores.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices, informs native resizable windows, comfortable information density, keyboard and pointer input, full-screen support, and less unnecessary modality.
- [Apple HIG — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), especially Requesting permission, informs a contextual real camera request, precise purpose, on-device processing, and separate legal sharing choices.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Best practices and Providing feedback, informs brief purposeful optional motion and interruption without waiting for decoration. The exact perimeter and timing choices above are product decisions, not Apple-mandated measurements.

The user's newer direction requires both native iPhone and native Mac, complete public badges above the players, and vertical players at every width. It supersedes the older parent's iPhone-first wording and optional balanced two-column Mac comparison. Camera setup itself remains a single-participant surface before pairing; only a real match can supply the second player and timer. Neither this direction nor a successful local check resolves the parent feature's App Store objectification risk or establishes the fairness of its proposed judging rubric.
