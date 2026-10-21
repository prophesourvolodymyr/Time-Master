# F29-G-c — Battle Background

## Purpose and Ownership

The active battle has a quiet, recognizable sports setting: a matte graphite stage with restrained orange arena lighting. The background makes the timer, complete identity rails, and two large vertical participants feel like one event without suggesting who is winning or changing how either body appears.

This child of [F29-G — Native UI Components](../DOCKS.md) owns the battle's decorative backdrop, its small neutral event accents, and its motion, contrast, energy, and visibility behavior. It does not own the timer, participant cards, badges, capture guidance, camera session, privacy cover, result reveal, permission flow, or safety sheet. Those foreground owners retain their actions and semantics. This is product direction and a future implementation brief, not an implemented screen or a human-verified result.

The [F29 parent](../../DOCKS.md) owns competition and privacy rules. [F29-A](../../F29-A-page-and-match-flow/DOCKS.md) owns the connected match journey. The background cannot pair people, declare Go, approve an image, select a winner, change Elo, reveal a pose, or prolong a deadline.

## Chosen Composition and Tradeoffs

The composition is an **arena apron**: a dark central stage with a narrow exposed surround. One horizontal orange-edged lintel beneath the timer and two short, static edge returns suggest a sports venue without depicting a stadium, gym, crowd, ring, or scoreboard that does not exist.

The choices are deliberate:

- Matte near-black and graphite retain the existing Tmax sports language. Orange is reserved for a small shared stage accent, not used as a different team color for each person.
- The eye travels downward from the real timer, through both owners' complete badge rails, to You and then Opponent. Nothing in the background competes with that order.
- One broad, symmetric orange wash gives the exposed surround depth. Its position and shape stay fixed; only a very small opacity variation may repeat. It never travels down a body or traces a limb.
- Both participant wells are equally opaque and use the same neutral treatment. The upper person's proximity to the timer does not produce brighter skin, a larger body image, or a privileged halo.
- A short, neutral lintel movement can acknowledge the real start when the foreground is not already using the focal motion. Accepted poses, scores, badges, and timer ticks do not each trigger another background celebration.
- Static geometry and ordinary native rendering are preferred to video, particles, camera-dependent shaders, animated meshes, depth maps, parallax, or a second glass system. The tradeoff is less spectacle, with better evidence fidelity, predictable older-OS behavior, and less competing motion.
- The ambient wash is static while the local camera is acquiring. This avoids changing screen illumination during capture and leaves motion emphasis to the real timer and capture controls. Waiting and judging can regain quiet ambient depth without implying analysis progress.

No custom artwork is required for this background. The reference's people, footage, flags, labels, purple pills, and brown overlays are not assets for the app. Any permitted athlete illustration belongs to its foreground owner and requires original or appropriately licensed artwork.

## Visual Hierarchy and Layering

### Fixed reading order

Whenever the two-participant battle composition is present, its order is:

1. The top timer or its honest stage-specific status in the same top anchor.
2. The complete public identity and battle-badge group for You, followed by the complete group for Opponent.
3. The large You participant panel.
4. The equally prominent large Opponent participant panel.
5. The current stage's concise instruction and reachable primary and safety actions in their host-owned positions.

All public badges remain above both participant panels. This includes every earned launch badge supplied by F29-F, the actual placed tier when available, and the truthful current streak when available. First Bell, Placed, Ten Rounds, and Three Straight are not a three-slot selection. F29-F owns eligibility, ordering, corrections, and unknown or stale states. The background neither computes achievements nor turns editable local badge previews into competitive claims.

Rails wrap and grow. There is no hidden extra-badge count, clipping, horizontal ticker, hover-only badge disclosure, or arbitrarily capped row count. The complete rail area may scroll with the stage; it is not an indefinitely growing pinned wall. A short viewport must scroll before either player becomes a thumbnail. A timer cannot be invented merely to preserve the reference's layout: before a real deadline it shows the host's truthful readiness state; during judging it does not promise a five-second result; after finalization the top anchor carries the host's terminal state rather than a running capture clock.

### Palette and surfaces

The full content backdrop uses the existing near-black 0A0A0A. The common stage uses the existing 141414 graphite family; foreground panels and controls retain the established 1C1C1C elevated surfaces where their owners require them. Orange is the existing FF6A00 action hue. Primary foreground text remains the existing white or ivory sports ink. No competing teal, purple, national-color wash, winner-green field, or loser-red field is introduced.

The background has four visual parts:

- A full, opaque near-black base that always exists, including first render, permission failures, suspended states, and fallback rendering.
- A still graphite stage well aligned to the host's measured central content column. Its modest edge separation produces depth without a moving shadow or a translucent view of a body underneath it.
- A thin lintel just below the timer zone, with short downward returns at its two outer ends. The line uses the existing separator treatment at rest. A restrained orange emphasis belongs to the whole stage after the actual start, never to a participant's border or side.
- One diffuse orange wash, centered above the stage and visible only in exposed decorative surround. It uses a fixed, smooth falloff and a normal opacity range of six to ten percent. It is not a light source inside an image. There is no additive brightening, HDR flare, white flash, animated grain, or blur of live content.

The timer, identity rails, controls, and evidence wells have opaque readable backing. The wash is excluded from their visible content, including image letterboxing. It must not tint a face mask, obscure framing cues, soften a focus ring, or change the apparent definition of skin. Static edge returns stay outside player evidence, badges, and hit targets. They never resemble an extra progress bar, reticle, or capture-validity indicator.

The background reserves no additional strip of layout. The lintel and wash use already available chrome and gutters. If those spaces become too narrow, decoration becomes less visible or disappears; participant width, badge completeness, and safe controls do not pay for it. Shared spacing and corner conventions remain the basis. Position comes from the actual stage bounds, not screen coordinates or an assumed camera aspect ratio.

## Native iPhone Composition

On iPhone, the stage occupies the available content width inside the existing measured safe areas and navigation clearances. The timer remains the top visual anchor. Both complete badge groups follow it, then large portrait-oriented You and Opponent panels in a single vertical sequence. The background never places a decorative shape between a body and its required framing margin.

The timer and safe actions stay reachable while the central stage scrolls. At large accessibility text sizes, the identity groups grow vertically and secondary instructions wrap. No font clamp, minimum text scale, fixed-height badge mask, or reduced body panel is used to force everything onto one screen. A long handle or a large badge catalog changes foreground layout, not the number of background lights or the background's contrast.

Landscape, a short screen, the keyboard, and system sheets do not produce a side-by-side matchup. They reduce the available stage viewport and use normal vertical scrolling. The top and bottom safe regions remain opaque and readable. Decorative space may collapse completely. Rotation and safe-area changes immediately align the backdrop with the new measured stage; they are not a cinematic rotation or a camera zoom.

The host keeps its existing touch-target convention of at least forty-four points for primary and safety actions. The background has no tap target, swipe action, long press, haptic, or audio output. It cannot intercept Capture, Retake, Stop camera, Exit, Safety, scrolling, or the platform's navigation gestures. After Go, the host's explicit state-aware exit remains the route out; dragging the backdrop cannot dismiss or forfeit a match.

## Native macOS Composition

This is a native macOS 14-or-later window, not Catalyst, a web page, or a stretched phone presentation. The existing normal title bar and 800 by 600 minimum remain unchanged. Window traffic lights, full-screen behavior, and normal title-bar dragging stay native. The dark arena begins in the content area; it is not painted over window controls or used to make a new borderless arena window.

At the minimum window size and on short laptop windows, the top timer and safe actions remain usable while the complete badge groups and two large player panels occupy a vertically scrolling central stage. Showing both full bodies simultaneously is less important than showing them at a useful scale. Large text, a tall badge collection, or an open sheet must not force postage-stamp players. The upper panel is always You and the lower is always Opponent.

At large, full-screen, ultrawide, or external-display sizes, the stage remains a centered, readable vertical column using the app's existing readable-width conventions. Surplus width becomes quiet near-black margin, not a second participant column or oversized gradient. Existing supplementary match details may use the host's inspector; this child creates no inspector or extra screen. An inspector never replaces the full above-stage badge rails or moves a participant sideways. The decorative wash stays sized to the stage, not the whole display.

Live resize tracks measured bounds without springing the camera well, cropping evidence, changing its orientation, or moving the face mask independently. The ambient cycle and any background focal movement are suppressed during interactive resize. Resizing can change display fit while preserving the same camera session and source-image relationship. The background cannot cause a camera rebuild, new capture, changed lens, or new evidence version. Changes of display scale, full-screen transition, and external display attachment settle to the same static stage before ambient eligibility resumes.

Native toolbar actions, host-owned sheets, alerts, and existing inspectors retain their normal pointer and keyboard behavior. The background does not add a custom close button, command menu, toolbar replacement, or global keyboard listener. Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their existing meanings. If another existing app command navigates away from an active match, the match owner handles the actual consequences; this background does not silently reinterpret the command.

Camera/TCC denial, a restricted camera, a camera busy in another app, a missing camera, and an external or Continuity Camera disconnect are truthful host states. The matte stage remains available, but there is no simulated preview, rated file-picker substitute, or background image pretending to be a live person. Open Settings, Retry, or a camera-selection action appears only where the host can actually recover. A camera switch after Go discards and restarts that person's selected set inside the original capture deadline under F29-A; it does not reset time or quietly substitute another device's frames.

One account has one authoritative active match and one camera owner across windows and devices. A secondary window may identify the existing session and offer the host's route back to it; it does not acquire a second camera, start another ambient battle independently, reserve another slot, or make another judge request. A non-owning or non-key battle window is static and privacy-shielded where it could otherwise expose sensitive content.

## States, Actions, and Recovery

Visible words and actions in this table belong to the foreground screen. The background introduces no second status label, spinner, error banner, or permission prompt.

| Actual state | Background and foreground relationship | Action and recovery boundary |
| --- | --- | --- |
| No actual pairing, including lobby, setup, search, or empty queue | This active-battle treatment is not mounted to manufacture two participants. The owning page keeps its own background and honest search or empty state. | Find opponent, Cancel, Try again, and Return remain the real host actions. No sample rival or decorative count fills absence. |
| Restoring a known match | Opaque base and still graphite well. No start accent, animated skeleton, stale body frame, or pulsing identities. The host says Restoring match. | Resolve authenticated service state before presenting sensitive content. Retry retrieves the same match; it does not create a new one. |
| Real opponent paired, neither or one person Ready | The shared lintel is neutral. Both full identity rails and large vertical participant panels are present; the opponent is an authorized avatar or neutral silhouette. The wash is eligible only if the camera is not acquiring and no other suppression applies. | Ready remains tied to real camera, consent, and eligibility. Cancel before Go has no rating consequence. Background motion cannot count as readiness. |
| Both Ready, synchronized start countdown | The stage stays fixed; ambient modulation stops. The host's real three-second countdown owns focal attention. | A lost requirement cancels or reconciles the countdown through the service. A local numeral reaching zero does not authorize Go. |
| Service-confirmed Go | The shared lintel adopts its active orange treatment. It may use the single brief start latch described below only when no foreground focal animation or capture acquisition is active. Otherwise it changes directly to its final appearance. | Capture and the allowance consequence follow the real start immediately. No animation completion gates capture or consumes a second slot. |
| Capturing a pose or running the capture self-timer | Base, wash, and stage geometry remain static throughout local acquisition. Timer, named pose, and actual pose state remain legible. Nothing moves over evidence. | Capture, timed capture, Retake, Stop camera, and explicit Exit remain available as allowed by the host. Three poses, at most two retakes per pose, and the original ninety-second capture period remain unchanged. |
| Selected image checking or a pose accepted | No new background motion, glow increase, or participant-colored region. Selected, Checking, and Accepted remain different foreground states. | Only the current selected image's real acceptance changes the foreground count. Stale responses and repeated messages do not replay an accent. |
| Framing, attire, bystander, or redaction problem | The same quiet stage remains. A private text-and-symbol explanation names the affected pose; the backdrop does not turn red or scan the person. | Recapture within remaining limits or use the host's exit. Mask failure blocks transmission; an unmasked original is not a fallback. A bystander remains invalid even if masked. |
| Own set locked, waiting for opponent | Both panels remain large and vertical. Opponent content is still an authorized avatar or silhouette plus actual stage/count, never an early still. The wash may resume once camera acquisition has stopped. | Waiting does not require maintaining a pose. Stop, Safety, and safe navigation follow the real state; no background progress estimate appears. |
| Uploading or checking evidence | The background remains neutral; eligible ambient motion is unrelated to byte counts, pose counts, or screening progress. | The host shows only actual progress and Retry when the same submission can resume. Upload completion is not moderation approval or finality. |
| Judging, including more than five seconds | The same slow wash may run, with no new speed or intensity. The host says Judging physiques or Still judging and owns any semantic activity indicator. | Five seconds is an unmeasured target, not a countdown. The service's deadline is thirty seconds after receipt of both final pose sets. No scan, score prediction, or made-up percentage. |
| Deadline passed locally, service finality unknown | Static treatment and Awaiting confirmed result. No winner emphasis or automatic no-contest decoration. | Retry or safe navigation retrieves the real result. Local elapsed time cannot settle the match. |
| Network loss or reconnecting | Ambient and focal background activity stop; capture and sensitive content are handled immediately by the privacy/capture owner. The host shows Reconnecting and the real eligible remaining time. | Resume the same match within the twenty-second reconnect grace where still valid. No deadline reset, extra retake, repeated charge, or replacement opponent. |
| Camera denied, restricted, absent, busy, or disconnected | Static graphite surface behind a safe placeholder, with a concise cause and useful recovery action. No last-frame wallpaper. | Settings only when permission can be changed; Retry only when it can help. External/Continuity recovery must satisfy the real camera and evidence contract before explicit resume. |
| Safety, privacy, consent, or meaningful report sheet open | Decoration stops under the native presentation. Capture cannot continue invisibly behind the sheet. The privacy owner covers sensitive content where required. | Reading, reporting, hiding, blocking, and withdrawal remain immediate or truthfully pending. Closing a sheet does not restart capture automatically or give more match time. |
| Block, hide, consent withdrawal, or safety removal | The affected foreground content is shielded immediately; background accents are cancelled. No dramatic punishment, dissolving body, or reveal-through-blur transition. | Block after Go shields and excludes future pairs but is not automatic leaving or rerating. Service confirmation and explicit exit consequences remain separate. |
| Valid AI-judged win, loss, or draw | The arena settles to a static neutral result setting. Both participants receive identical background treatment. Outcome, final scores, Elo, and safe actions are readable immediately through their owners. | Only an intentional View poses with current permission can expose moderated counterpart stills. No background motion opens them or implies a new award. |
| Valid forfeit or no-contest | The same neutral static setting; no victory flare, defeated-player shade, empty score glow, or inferred body comparison. | Show the real forfeit consequence or confirmed no-contest and allowance state. Neither has an opponent-pose gallery. |
| Result reopened, history restored, or corrected result received | Static arena if the host retains this composition. No start latch, ambient loop, fresh award, or replay of missed events. | A correction is a separately labeled service change, not a second match or celebration. The background does not anticipate its outcome. |
| Media hidden, reported, blocked, expired, removed, or sharing withdrawn | Safe reason-specific placeholders retain their opaque treatment. The wash cannot reveal an old thumbnail through transparency. | Report or privacy actions remain accessible as permitted. Ordinary media expiry is twenty-four hours from finalization and is not extended by reopening. |
| Account switched, signed out, or access lost | Sensitive foreground data is removed or covered immediately; background work stops. | Restore only the current authorized account. No previous person's badges, media, draft, or match state leaks into the next account. |
| Rendering enhancement unavailable | Plain opaque base, graphite well, and a static separator are the complete fallback. Foreground content and actions remain intact. | No user-facing rendering error or retry is needed. This is a visual fallback, never a substitute camera, judge, opponent, or service. |

## Motion Contract

### One bounded ambient layer

The optional-in-operation ambient layer is one fixed-position diffuse wash, not a stack of separately animated lights. Its cycle is exactly twelve seconds: a smooth six-second rise from six to ten percent opacity and a smooth six-second return. Position, size, color, falloff, and clipping never oscillate. There is no hard reversal, flashing boundary, moving beam, luminance burst, particle emission, or accelerated last-seconds mode.

The wash can run only on a visible, active, owning battle surface, with live nonterminal match state, normal motion and energy conditions, no covering modal, no interactive resize, and no camera acquisition. During capture it remains at the six-percent resting appearance. The static rendering communicates the entire experience; the loop conveys no progress, urgency, score, camera health, or service availability.

A newly eligible loop starts gently from rest. Foreground return does not fast-forward missed cycles or replay suppressed events. If another F29 component already supplies the permitted quiet ambient layer, this background remains static rather than creating a second loop. A semantic progress indicator still belongs to its actual operation; it is not justification for additional decorative repetition.

### Discrete motion and interruptions

| Trigger | Visible motion and duration | Interruption and priority |
| --- | --- | --- |
| Entering a genuinely paired battle stage | The exposed apron can fade to its final appearance over 280 milliseconds as part of the host's stage transition. No participant, badge rail, or camera surface moves with it. | If the host already owns the entry transition, use that transition rather than adding another. Restoring an existing match uses the final appearance directly. |
| Service-confirmed Go with the focal slot free | The lintel's orange emphasis extends symmetrically from the central eighty percent to its full existing span over 280 milliseconds, with a smooth ease-out and no overshoot. Only the decorative line changes; its layout footprint is unchanged. | Countdown/Go typography, capture, or other foreground focal motion wins. In those cases the lintel adopts its final appearance without moving. Never delay or queue the accent to find a later opening. |
| Real Ready changes, ordinary timer ticks, accepted poses, transfer updates, and badge changes | No background-specific animation. Their owner supplies any concise state feedback. | This prevents a pulsing badge wall or a repeated acceptance celebration from being added behind the real focal event. |
| Transition to a confirmed terminal result | The orange lintel returns to the neutral separator treatment within 180 milliseconds, only if no foreground result animation is active; otherwise the static terminal appearance is immediate. | The result owner has priority. Background changes do not add a serial tail to the shared result reveal, whose total choreography must settle within 900 milliseconds. |
| Ordinary return from a non-sensitive overlay with the same eligible match | The base is already present; an eligible wash restarts at its resting opacity. No start accent. | Resuming camera still requires the host's explicit permitted action. Closing a sheet is not a capture trigger. |
| Reduce Motion, low-power mode, thermal constraint, lost visibility, capture acquisition, or interactive resize begins | Stop decorative repetition and focal travel at once; select the appropriate static appearance. No completion callback or delayed stop. | No attempt to finish a twelve-second cycle. A minor change to the low-opacity surround is preferable to continued unwanted motion. |
| Hide, block, mask failure, withdrawal, app inactivity, or other privacy stop | No protective animation: cover or remove sensitive content immediately through its owner and cancel background activity. | Protection has priority over every transition, countdown, spring, result effect, or backdrop event. |

At most one quiet ambient layer and one focal event may exist across the composed battle. Foreground controls, countdown, capture, result, and accessibility feedback outrank the background. A newer authoritative state replaces a running decorative transition; there is no animation queue. Simultaneous Go and cancellation, recovery and timeout, or finality and safety removal resolve through the service and privacy owners, not the order in which animations finish.

The background emits no haptic or sound and has no press effect. Foreground actions reuse the existing shared press spring rather than adopting new feedback from this child. Timer digit changes, countdown scale, final score reveal, earned Elo, and badge unlock choreography remain outside this ownership.

## Accessibility, Input, and Focus

The entire background is decorative: no accessibility element, focus stop, announced value, hover affordance, selectable text, or hit-testing surface. Removing it from accessibility and interaction must leave the foreground's complete reading order and actions intact.

VoiceOver encounters the current stage/timer, You identity and complete badges, Opponent identity and complete badges, You panel, Opponent panel, and applicable actions in the host's logical order. It does not announce ambient cycles, timer ticks, interpolated numbers, or lintel movement. Real milestones and critical recovery instructions remain the host's announcements. A foreground stage change may move focus appropriately; a decorative restart never does.

Pointer hover does not tilt or illuminate the stage, resize a participant, or unlock an action. Keyboard focus rings retain readable opaque backing and must not be clipped by background masks. Tab and Shift-Tab traverse actual controls; Return or Space activates only the focused semantic control. Typing in a report or account field cannot trigger Capture, Ready, Leave, or another background action. Voice Control and Switch Control retain the same named controls without requiring a decorative gesture.

Escape first respects the active native sheet, edit, or confirmation context. Without one, the match host applies the real pre-Go cancellation, active-match exit confirmation, or terminal Close behavior. Cmd-W and ordinary quit requests use the host's real active-match consequence confirmation where the platform permits it. Force quit, process death, and an involuntary disconnect cannot be prevented or represented as a confirmed voluntary forfeit.

Reduce Motion removes the ambient cycle and lintel travel. The complete static state appears immediately; a non-protective state may use an opacity-only change no longer than 120 milliseconds. Protection is always immediate. Reduce Transparency uses fully opaque base and foreground backings; no material samples a camera or body image. Increased Contrast removes the low-contrast wash and relies on solid stage separation and foreground labels. Differentiate Without Color is satisfied because the backdrop conveys no necessary state; the host still supplies text and symbols for every consequential condition.

Minimal text means no decorative slogans, repeated Physique heading, fake audience status, or background labels. It does not remove consent recipients, retention, camera errors, countdown units, forfeiture consequences, safety information, or accessible labels from their actual owners.

## Energy and Window Lifecycle

Low-power mode and elevated thermal conditions, including fair, serious, or critical system thermal states, select the static treatment. Background work does not request a high refresh rate, run a persistent display loop offscreen, or resume because a twelve-second cycle was already scheduled. If the operating system exposes no power-status signal, visibility, capture, and accessibility suppression still apply; the simple static rendering remains available without a hardware-specific enhancement.

On iPhone, app inactivity, locking, backgrounding, or a call stops acquisition and shields sensitive content immediately through the owning lifecycle. On Mac, app inactivity, an owning window becoming non-key, minimization, hiding, full occlusion, or moving to a nonvisible space stops decorative work; sensitive acquisition and presentation follow the same immediate protection rule. Opening an owned permission or safety sheet does not create an exception for a hidden camera.

Returning to the visible owner restores the same authenticated service state before sensitive content can reappear. An explicit permitted resume is required for capture; galleries do not reopen themselves. The twenty-second reconnect grace extends neither capture nor judging deadlines. If both sets were already received, the service can finish judging while every local visual is stopped. A result received on return is presented without a deferred background celebration.

The background must not cause camera reconfiguration, capture or mask-coordinate changes, image decoding, font measurement, provider access, network work, or global page layout on each animation frame. A static stage on a constrained device is the intended experience, not a degraded data mode. This component does not add telemetry or store a history of decorative phases.

## Privacy and Evidence Geometry

The camera preview, face-redaction treatment, and exact selected-image preview are owned together outside the backdrop. They remain aligned throughout a background transition, scroll, rotation, live resize, full-screen change, and return from inactivity. The background never transforms their common ancestor, uses a body-shaped mask, samples camera colors, changes image exposure, or applies a vignette to a person.

Evidence is aspect-fit without cropping required anatomy, nonuniform stretching, body enlargement, or a different comparison treatment for each participant. Resizing may alter the available display rectangle but not the selected image, its mask, or the camera's evidence coordinate system. Decorative clipping is confined to decorative surroundings; it is not the privacy mask and cannot repair a failed mask.

Uploads contain clean, locally face-obscured capture evidence, never a screen composite. Timer, backdrop, name, country flag, country metadata, badge, Elo, local photo, safety status, and UI chrome are excluded from judge images and context. Country is optional and manually self-declared through its identity owner; the arena does not infer it, recolor itself from it, or treat it as verification or a scoring signal.

Before finalization, the opponent panel remains an authorized avatar or neutral silhouette plus actual stage/count. It never becomes a live stream, early pose thumbnail, blurred leaking still, or fake preview. A local profile photo is not automatically published as that avatar. After a valid AI-judged win, loss, or draw, current permission and intentional View poses remain necessary. Forfeit/no-contest galleries are prohibited. Hide, report, block, revocation, expiry, and deletion remove access immediately according to their owners, without revealing an old image through the backdrop.

## Compatibility and Rendering Fallback

The complete composition must work on the existing iPhone iOS 16 and native macOS 14 deployment baselines. No deployment-target increase is needed to draw a dark surface, a smooth fixed gradient, and a short line accent. Newer-OS visual features are not prerequisites and must not change match behavior.

The battle itself is matte. If adjacent controls use the app's shared native glass or public material treatment, they keep that shared availability and Reduce Transparency behavior; this child does not replace it or introduce private rendering APIs. Older systems retain the same geometry, foreground order, dark/orange identity, contrast, and safe actions. A static opaque stage is the last rendering fallback. No missing effect may block Ready, Capture, Stop, Safety, a result, or recovery.

## Dependencies and File Boundaries

- [F29-G parent](../DOCKS.md) owns composition, shared choreography priority, and component integration. This child consumes that agreement rather than defining a second visual system.
- [F29-A](../../F29-A-page-and-match-flow/DOCKS.md) owns the real host, timer, safe actions, camera presentation, resize/scroll geometry, focus, and lifecycle recovery.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) prevents progress, confidence, and appearance-score implications before a validated result.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns authoritative Go, one active match, deadlines, finality, allowance, and corrections.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) and [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) own immediate protection, consent, masking, camera stop, access, expiry, and no-contest consequences.
- F29-F owns trusted public identity, optional country, all public badge states, and their complete rails. Its canonical document is linked by the integrated F29 parent; this background does not duplicate its catalog or infer eligibility.
- Prospective TimeMaster/Views/Physique/Components/PhysiqueBattleBackground.swift owns this one visual component. The reviewed real battle host under TimeMaster/Views/Physique/ supplies its stage, visibility, suppression, and measured bounds. These are future locations, not existing implementation claims.
- Existing [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) remain the shared palette, typography, spacing, and public control/material authorities.
- The [future implementation brief](../../../../prompts/F29-physique-duels/F29-G-c-phase-1-battle-background.md) owns engineering work instructions. [CYCLES.md](../../../../CYCLES.md) owns implementation and human-review tracking.

Code may begin only after the real shared match, capture/privacy, identity, and native host contracts are implemented and human-reviewed. This visual component is not an independently shippable competitive feature. A preview does not satisfy those prerequisites and must not become a production fallback.

## References and Precedence

- [Battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): hierarchy and directness only. The large top timer is useful; side-by-side players, over-body labels, purple/brown web pills, people, footage, and publishing rights are not transferred.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift): native action and earned-rating visual vocabulary, not Dynamic Type clamps or cosmetic rating authority.
- [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift): exercise HUD context only. Its lead bar and provisional movement scores are not physique state.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift): native Mac window and existing command boundaries.
- [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift): editable local cosmetic previews are not trusted competitive badges or identity verification.
- [Apple HIG — Motion, Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion): purposeful, brief, optional, interruptible feedback. The arena's exact opacity and duration choices are product decisions, not Apple-prescribed values.
- [Apple HIG — Designing for macOS, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): resizable windows, native commands and input, large-display use, and active/inactive transitions. The vertical player hierarchy remains the user's product decision.

The newer user-directed requirement is native iPhone and native macOS with all public badges above two large vertical participants at every width. It takes precedence over F29-A's earlier optional two-column desktop comparison and iPhone-first platform wording. Earlier fade-only motion defaults do not prohibit the bounded, privacy-safe native motion specified here. Shared documents are reconciled by their owner; this child does not authorize a parallel layout, new screen, public service deployment, or weakening of the existing privacy and finality rules.
