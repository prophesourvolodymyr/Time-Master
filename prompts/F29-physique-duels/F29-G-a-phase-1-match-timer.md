# Phase 1 of F29-G-a — Authoritative Native Match Timer

## Required Worker Assignment

Model assignment: **openai-codex/gpt-6-astra:max**.

The model is **openai-codex/gpt-6-astra** and the thinking level is **max**. Do not silently substitute another model or a lower thinking level. If the runner cannot honor this assignment, report that dispatch limitation before implementation. This is the native UI worker's assignment, not the in-app physique judge. It does not change the service's approved judge, provider, judging version, or consent.

Work as the single deeply reasoning native UI owner for F29-G-a. Compare implementation alternatives privately; communicate decisions, evidence, tradeoffs, and risks, not chain-of-thought. No nested agents or unrelated rewrites.

## Features Included

- F29-G-a — The shared authoritative phase-clock presentation for search, readiness/start, capture, processing/judging, reconnect, and terminal handoff.
- F29-G-a — A distinctly labeled three-second local capture self-timer presentation connected to the existing capture owner.
- F29-G-a — iPhone and native macOS integration, accessible timing semantics, real interruption recovery, reduced motion/transparency, and energy-safe resumption.

These are one connected component slice, not new standalone screens. Implemented items must be listed separately for human review. Implementation and human-review tracking belong only in CYCLES.md.

## Context

Physique Duels uses real service-owned deadlines and private local capture; the clock is a presentation of those facts, not a match authority.
The approved hierarchy is top clock, every public identity/badge rail, large You panel, then large Opponent panel on both native platforms.
This brief follows a documentation-only design batch; it authorizes no production substitute for missing foundations.

## What You Need to Read First

Read the complete component product context and the relevant current shared sections before code:

- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md` — complete chosen behavior and animation contract.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md` — coordinated ownership, layout, shared motion, and current sibling boundaries.
- `features/F29-physique-duels/DOCKS.md` — shared match contract, approved direction, existing-app boundaries, and review status.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — Search through Judging, interaction/focus, camera lifecycle, and state-aware exit.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Accepted Judgements and Non-Scored Outcomes; no provisional result.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — Pairing Eligibility and Search; Allowance, Cancellation, and Interruption Boundaries.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — immediate protection, safety access, and Blocking Before and After Go.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — Camera and Device Privacy Lifecycle; Result Timing and Finality; operational failure states.
- `CYCLES.md` — F29 scope, review handoffs, actual shared foundation status, and the approved F29-G-a implementation todo.
- `features/DOCKS.md` — current feature ownership and dependency map. Follow its current F29-F identity/badge link when inspecting a host's public rails; do not invent a second badge model.
- `TimeMaster/Utilities/Theme.swift`, lines 1–81 and 208–228 — near-black background, surfaces, orange actions, and shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift`, lines 1–38 — Inter typography, scaling, spacing, readable width, and iPhone touch targets.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift`, lines 20–80 — public material availability fallback, Reduce Transparency, and existing press spring.
- `TimeMaster/Views/Ranked/RankedComponents.swift`, lines 15–108 and 148–188 — nearby action and earned-rating language. Do not copy its Dynamic Type clamps or treat local cosmetic levels as earned Physique state.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift`, lines 25–151 — existing HUD context only. Do not copy exercise live scores, provisional leads, an exercise duration, or exercise image-sharing assumptions into Physique.
- `TimeMaster/App/TmaxApp.swift`, lines 8–19 — native WindowGroup, normal title bar, current 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift`, lines 6–37 — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift`, lines 23–27 and 99–109 — editable local badge previews are not trusted competitive achievements.
- `TimeMaster.xcodeproj/project.pbxproj` — actual target membership, toolchain conventions, and deployment settings. Preserve iPhone iOS 16 compatibility and native macOS 14 compatibility; do not silently raise targets because a skill demonstrates newer APIs.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual image. Borrow the obvious top timer, not its side-by-side layout, web pills, overlaid labels, people, or assumed image rights.

Relevant installed skill entry points are `skill://swiftui-pro`, `skill://swiftui-animation`, and `skill://apple-hig-reference`. Read only their relevant accessibility, motion, availability, and performance references. The coordinated owner already selected **dimillian/swiftui-ui-patterns** through the UI Skills CLI; do not repeat selection, installation, or project setup. Its selected source is `https://raw.githubusercontent.com/dimillian/Skills/main/swiftui-ui-patterns/SKILL.md` if the installed selection is not available in the runner. Prefer narrow state ownership and iOS-16-compatible observation over a new timer view-model hierarchy.

Read current Apple guidance for the decisions being implemented:

- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — native resizing, desktop space, menu/keyboard integration.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — brief purposeful feedback, alternatives, and interruptibility.

Source positions can move. Locate the named symbols or sections rather than assuming line numbers are permanent. STYLES.md was absent during the design batch; reuse the source conventions and do not create a global design file. DOCKS is plain-language product context, not an instruction to blindly copy an implementation recipe. Confirm public API availability against the actual SDK and supported targets.

## What Happened Last Session

The documentation-only worker inspected the supplied image, native styling and window/command anchors, F29 timing/privacy/safety contracts, installed SwiftUI/HIG guidance, and the relevant live Apple chapters. It wrote the F29-G-a product specification and this future implementation brief. It did not implement Swift, establish a service clock, exercise cameras, run builds/tests, or claim human verification.

The selected composition is a stable opaque scoreboard band with large tabular digits, a short phase label, and one support line. Ordinary seconds crossfade quietly; a real match-start count or deliberately armed local capture count has a small numeral pop. Judging displays elapsed time from receipt of both final sets, never an AI completion countdown. The local delay remains beside Capture, never in place of the match clock.

The user-approved direction supersedes the older F29-A optional wide-window two-column composition and first-iPhone emphasis. Both native platforms and vertical participants are required. Main owns integration of shared documentation and the coordinated batch's publication. This brief does not assume that all earlier numerical proposals, shared foundations, or production operation were human-approved.

## Prerequisites and Review Boundaries

Production implementation begins only when the real shared foundations and contracts are implemented and human-reviewed. Establish that from current source, CYCLES.md, and explicit handoffs; a checked documentation item or a feature specification alone is not implementation evidence.

Required foundations:

1. An authorized authenticated Physique session with one active match per account, accepted phase revisions, real service timing, cancellation/Go boundaries, and exactly-once finality.
2. The shared clock synchronization contract, including a trusted time anchor, search/start/capture deadlines, receipt of both final sets, judgement deadline, and actual reconnect expiry when one is applicable. Reuse their actual field names and validity rules; this brief names meanings, not a new API payload.
3. The human-reviewed capture owner with permission and acquisition state, a real still action, explicit stop/resume behavior, face-redaction failure handling, selected/accepted distinctions, and a cancellable local delayed-capture attempt.
4. The real native hosts for search, ready/countdown, active capture, pending result, and recovery, plus their owned actions and permitted public identities. The clock must be integrated there, not shipped as a disconnected preview.
5. Approved provider/service availability, protected evidence handling, and safety operation for any real rated scenario. This component does not establish public-operation approval or the judge's quality bar.

If these are unavailable, name the exact missing contract, source, review, credential, runtime, or hardware prerequisite and finish the reachable analysis. Do not create simulated production opponents, local Elo, fabricated deadlines, placeholder capture callbacks, fake camera frames, or a duplicate service to make the UI appear complete. Do not broaden this slice into the entire F29 backend, new screens, global navigation, or a competing camera architecture.

The component cannot be independently shipped before its dependencies. Label design-only previews as previews and keep them out of the production route. The inability to run physical capture is an explicit limit, not permission to replace it with a rated file picker or to claim complete native verification.

## Design Decisions to Preserve

- **Flat clock band, not a ring:** a ring suggests predictable completion and competes with people. The selected band keeps time extremely legible without implying AI progress.
- **One dominant clock:** the top number always states its meaning. Search and capture count down. Start shows 3, 2, 1. Processing/judging count elapsed seconds from a trusted common origin. Untimed readiness and unknown timing do not acquire a fabricated deadline.
- **Local delay is separate:** Capture in 3 appears by Capture while the top Capture left number continues. Cancel timer cancels one pending shot, not the match.
- **Vertical participants on both platforms:** top clock, all public badges grouped by owner, You, Opponent. Short windows scroll; wide windows never place players side by side. No body overlays, hidden +N badges, or shrinking people to fit.
- **Truth over a smooth fiction:** missed ticks and newly accepted service state jump to the correct value. No animation backlog, time drift, reset on appearance, negative number, early zero, or local finality.
- **Tactile only at meaningful moments:** countdown numerals can pop subtly; ordinary ticks do not bounce, flash, orbit, or trigger sound. There is no timer-owned ambient loop.
- **Native Mac, not a phone transplant:** preserve the normal title bar, menu commands, keyboard focus, native sheets and TCC behavior, resizable 800-by-600 minimum, full screen, display moves, and single camera owner.

## What to Build

### 1. One shared authoritative presentation

Create or finish the approved clock component at the prospective path below, using the real session state. Keep the view small and reuse existing data and timing ownership. Do not add a second network poller, independently ticking persisted counter, per-screen deadline store, or service request for every second.

Scope invalidation to the timing presentation. A whole-second value change must not recreate the camera, decode images, recompute every badge, remeasure typography, rebuild the complete player stage, or trigger network/provider work. Derive the displayed value from the trusted time relationship and elapsed monotonic time; do not count scheduled callbacks or trust user-adjustable wall time as match authority. Follow the shared clock's behavior across suspension, sleep, and a lost anchor rather than inventing another synchronization policy.

Use localized whole-second minutes-and-seconds formatting with a stable numeral field. Remaining values round upward until the real boundary, elapsed values round downward, and neither displays negative time. Apply actual subsecond eligibility rules to capture; the displayed whole second is not permission to act.

Consume current accepted phase and revision information so a late packet cannot regress phase, revive a deadline, duplicate Go feedback, or overturn finality. A corrected time replaces the previous value without rolling through skipped numbers. For a correction of at least two visible seconds, show Time synced for two seconds only when no higher-priority status needs that space.

### 2. Correct stage meanings and zero boundaries

Implement every state in the component DOCKS, with these critical boundaries:

- Searching uses the actual service search interval, up to ninety seconds, not a timer started by view appearance. At local zero, show Checking search until the service resolves expiry or an existing pairing. Retry starts a new search only through the host's deliberate action after resolution.
- Waiting for Ready has no invented countdown. The accepted synchronized start shows only the current part of its real three-second interval. A late join does not replay 3. Visual zero without authoritative Go shows Confirming start and does not enable capture or infer allowance consumption.
- Authoritative Go changes the label and value together to the current capture deadline. A Go cue may appear in the support line; it cannot delay usable actions or allow a stale ready state to take pictures.
- Capture, retakes, camera switching, checking a selected image, safety/report sheets, and the own-set-submitted wait all retain the original ninety-second capture deadline. Respect the existing two-retakes-per-pose bound; do not implement another counter here.
- Once both final sets are actually received, show Processing elapsed during checks and Judging elapsed only when judging is real. Both use the same receipt origin. Never restart thirty seconds when the provider begins.
- At the unmeasured five-second target, describe the actual remaining stage. A local upload completion cannot claim that the opponent finished or that the AI is running. No fake percentage, ETA, provisional winner, or confidence meter.
- At capture expiry, immediately cancel pending local capture and disallow new capture. At the processing deadline without a confirmed outcome, replace the advancing value with Awaiting confirmed result. Never locally finalize no-contest, restore allowance, or erase a result finalized in time but delivered late.
- Confirmed terminal state stops every active timing effect. Keep Ended or the actual terminal status in the top region while the battle remains, then let the owned result host take over. Do not invent a final match duration or leave a meaningless running 00:00.

### 3. Wire the existing local capture self-timer

Connect the separate Capture in 3, 2, 1 presentation to the actual capture owner's explicit delayed action. Do not add new delay durations, a settings screen, or a second capture scheduler. The direct-capture alternative remains an explicit host action, never a silent fallback from a failed delay.

Allow the full three-second delay only when it can end before the actual capture deadline; inspect real remaining time, not its rounded display. At the end, the capture owner must revalidate current permission, session eligibility, camera ownership, privacy, and deadline before acting. A delayed callback reaching the deadline does not win a race against expiry. Display actual camera capture success or the real error, not success based on animation completion.

Cancel the attempt immediately on Cancel timer, Stop camera, pose replacement, retake selection, capture expiry, finality, privacy/permission loss, camera disconnect, safety/exit presentation, account change, disappearance from the permitted acquisition state, or background/inactive transition. An interrupted attempt never automatically fires or restarts on return. Double activation cannot queue two shots. A new attempt requires a new explicit action inside the unchanged match interval.

### 4. Honest reconnect and lifecycle behavior

Keep the original known capture time as the large value. Show Reconnecting and a subordinate Resume within only when the actual service reconnect expiry is known. Bound that resume interval by the earlier active match deadline; if capture ends first, state it. Do not fabricate twenty seconds at the moment a client first notices a network error.

When the clock anchor is still reliable but state is disconnected, mark the known timing Last synced. If it is no longer trustworthy, use Syncing time instead of precise-looking invented digits. The server remains the authority for recovery eligibility and finality. Resume continues the same evidence and retakes and consumes no second slot.

When both final sets are already received, show result-retrieval state, not a new capture countdown or an offline-forfeit threat. Judging may complete without the client. Retry fetches the same result and cannot submit another judge request.

Stop/shield acquisition and cancel the local timer immediately on iPhone background/lock/call interruption and Mac inactive/minimized/hidden or interrupted acquisition states. Stop decorative rendering without pausing the authoritative deadline. Return installs the current permitted state without replaying missed seconds, Go, or a self-timer. Secondary windows/devices do not create a second active match, self-timer, camera, or allowance charge.

### 5. Integrate both native layouts and input paths

On iPhone, preserve safe areas, measured navigation clearance, large text, the pinned legible timing anchor, and reachable primary and safe actions. Badge rails and the two large portrait panels scroll below; never put timer text on the evidence. The local delay sits beside Capture in a non-image control area. Use existing forty-four-point primary and safety interaction areas.

On native macOS, keep the normal title bar and toolbar, 800-by-600 minimum, measured readable stage, native-density controls, and native sheets. Confirm laptop, larger/full-screen, external-display, short-window, and live-resize behavior. An existing host inspector can expose secondary explanation; it never hides current timing/recovery or turns into a side-by-side matchup.

Treat the timer as information, not a tappable pause/edit control or a keyboard Tab stop. Return/Space act only on the focused semantic control, never a global shutter while typing. Escape dismisses the current native surface according to its rules; on the unobscured capture stage it cancels an armed self-timer first, otherwise requests the host's state-aware exit. Do not forfeit directly from Escape.

Preserve existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. Ordinary Cmd-W/quit requests confirm actual active-match consequences where supported. Force quit/crash is not a confirmed voluntary forfeit. Reconcile a phase change while a confirmation is open so a stale pre-Go Cancel or completed result cannot silently become a rated loss.

Use the host's distinct camera/TCC denied, restricted, absent, busy, external-disconnected, and Continuity-disconnected states. Settings and Retry appear only when useful. No fake preview or rated upload-from-file fallback.

### 6. Accessible motion and energy behavior

Implement the exact component motion contract, scoped narrowly:

- Whole-second number change: 180-millisecond opacity transition in a stable field; no band, badge, player, or baseline movement.
- Real start and deliberately armed self-timer numerals: peak scale no greater than 1.06, settled within 220 milliseconds; no loop or replay.
- Phase/support label changes: 160 milliseconds. Necessary host stage continuity: at most 280 milliseconds and never an action gate.
- Go support cue: 180-millisecond appearance, gone within 600 milliseconds, immediately preemptible by safety or recovery.
- Ten-seconds-left capture notice: once, 160 milliseconds, static white digits with a symbol/text signal, no flashing or repeated alerts.
- Existing action feedback only: press spring response 0.24, damping fraction 0.88; no additional competing press effect.

Basic scale and opacity are sufficient for iOS 16 and macOS 14. Do not require 26-only glass, newer animation engines, or an iOS-17-only observation model without a supported path. Neighboring shared controls retain their current public material and Reduce Transparency fallbacks; the timer's own band is opaque.

Reduce Motion uses immediate number replacement and no scale/travel/ambient effect. Reduce Transparency and Increased Contrast keep all numerical and recovery information readable. Low Power Mode or significant thermal constraints remove numeral transitions and optional decoration, not truthful timing or safe actions.

The active visible clock needs whole-second display updates, not display-rate polling. Suspend timing presentation for invisible/inactive copies. Never do service I/O, provider work, image decoding, font measurement, or camera rebuilding in an animation callback. Resume with one current value, not a backlog.

Expose the phase and full units as one readable accessibility element. The local timer is a distinct Local capture delay element. Do not announce every ticking or animated value. Coordinate single announcements for material phase changes, the initial countdown, Go, the ten-second capture milestone, interruption, and finality. Local delayed capture announces its start and actual success/cancellation, not every numeral. Preserve focus on ticks and resizing; restore it correctly after sheets. Silent, VoiceOver, Voice Control, Switch Control, and keyboard paths must remain complete.

## Prospective Files and Edit Boundaries

- Create or finish `TimeMaster/Views/Physique/Components/PhysiqueMatchTimer.swift` after checking the approved component location and existing code. If the human-reviewed foundation already chose a canonical clock file, use that file instead of a duplicate and report the exact path.
- Integrate the already implemented search, readiness/countdown, capture, processing/judging, and recovery hosts under `TimeMaster/Views/Physique/`. Inventory their actual filenames first. Do not create guessed replacement host screens to satisfy this list.
- Reuse the approved session/capture owners under `TimeMaster/Services/Physique/` and the canonical `TimeMaster/Models/PhysiqueDuelModels.swift` contract if that is its current location. A narrowly necessary presentation or cancellation change belongs in that owner, not in a second clock service. Missing authority is a prerequisite gap, not a reason to invent fields or endpoints in this UI slice.
- Use existing `TimeMaster/Utilities/Theme.swift`, `ProfileDesign.swift`, and `TimeMasterGlassControls.swift` unchanged unless a scoped actual compatibility defect is demonstrated. Do not establish another global visual system.
- Preserve `TimeMaster/App/TmaxApp.swift`, `TimeMaster/App/TmaxCommands.swift`, and existing deployment targets. Any necessary narrow lifecycle integration must preserve all existing commands, windows, and unrelated flows; no app-wide redesign.
- Add a deterministic behavior regression to the existing applicable test target only when it covers a genuine timing/capture boundary. Discover the current test location instead of inventing a parallel test architecture.
- Update only the applicable implementation/handoff items in `CYCLES.md`. The smallest product DOCKS changes only for directly approved decisions or after the user accepts resulting behavior; no verification logs, code, payloads, or checkboxes in DOCKS.

List every actual changed file in the final handoff. Files outside this component and its necessary real host/session integration remain owned by their existing features. Do not overwrite another worker's changes or use this task to redesign badges, players, judging, navigation, or a result screen.

## Observable Acceptance — Both Platforms

| Scenario | Required observable behavior |
| --- | --- |
| Real search already partly elapsed | The clock shows the existing service interval, not a fresh 01:30; expiry does not invent an opponent or a result |
| Readiness and late countdown delivery | No fabricated readiness deadline; join at the current 2 or 1 rather than replaying 3; no capture from visual zero alone |
| Capture at normal and accessibility sizes | Legible top Capture left, every public badge above both large vertical panels, reachable Capture/Exit/Safety, no body overlay |
| Mac 800 by 600, laptop, full screen, large/external display | Native title bar/menu/focus intact; stage scrolls rather than shrinking people; players never become side by side; live resize never resets time |
| Three-second local capture delay | Separate Capture in number by Capture, main match clock uninterrupted, Cancel timer works, one actual still at most, no delayed shot after interruption |
| Boundary shorter than the selected delay | No silently shortened timer; only genuinely valid explicit capture actions remain; zero cannot send a late photo |
| Own submission before the opponent | Actual Uploading or Waiting for opponent, same capture time; no premature Judging or opponent pose |
| Both final sets received | Elapsed processing starts from actual receipt, survives transition to Judging without reset, actual stage at the five-second soft target |
| Thirty-second processing boundary while offline | Awaiting confirmed result, not a local no-contest; an on-time result delivered later is shown correctly |
| Twenty-second grace versus eight seconds of capture | Original Capture left remains eight seconds; Resume within cannot offer twenty; no new evidence after the actual capture deadline |
| Unknown grace or lost anchor | No invented 00:20; Last synced only for a reliable projection, otherwise Syncing time; one match and no extra charge |
| Permission/TCC loss, external/Continuity disconnect, background/minimize | Immediate acquisition stop and self-timer cancellation; honest recovery; no fake camera or library substitute; same deadline on return |
| Privacy/safety during any animation | Protection immediate, no camera left running behind a sheet, no opponent images revealed by expiry, no automatic block-driven result |
| Keyboard, VoiceOver, Voice Control, Switch Control | Stable focus and accessible units, no per-tick speech, no global shutter while typing, state-aware Escape and ordinary close/quit handling |
| Reduced motion/transparency, low power/thermal constraint | Correct static numerical state and opaque readable surfaces; no decorative timers offscreen or during inactive ownership |
| Finality, reopening, second window/account change | No countdown replay, judgement retry, allowance duplication, or local rerating; old account state cleared and camera ownership singular |

All visible times and actions must be connected to real authority. A static preview, successful compilation, mocked callback echo, or a passing source-text assertion is not acceptance.

## Focused Verification to Perform During Implementation

These are future checks, not checks already performed by the documentation worker.

1. Discover and run the smallest existing build/check path for the touched iPhone and native Mac targets. Resolve clear failures introduced or exposed by this slice. Do not run an unrelated full-repository cleanup, formatter sweep, or speculative audit.
2. Exercise the real changed native surfaces on both platforms where a runtime exists. Use authorized test accounts and the approved service. Observe a real search/start/capture/submission/result flow, not only an isolated preview. A nonproduction service must still execute the actual contracts; production fake peers or local result fallbacks are forbidden.
3. Use a focused throwaway timing scenario to exercise delayed callbacks, a trusted anchor after sleep, a wall-clock change, phase revision ordering, real zero, and a late-delivered final result. Remove throwaway scaffolding after proof. Permanent tests, if needed, must cover consumer-visible timing, cancellation, precedence, or identity boundaries rather than constant strings or view wiring.
4. In the native host, arm the local timer and cancel it through Cancel timer, Escape, safety presentation, background/inactivity, camera interruption, and capture expiry. Confirm no late still is taken on return. This needs the actual capture path; an assertion that a mock closure was called is not sufficient physical-camera proof.
5. Exercise reconnect near the capture deadline, unknown grace, and offline result retrieval after both final sets are accepted. Observe that no deadline or allowance resets and that the client does not finalize locally. Use existing controlled transport/failure tools; do not add a production failure simulator.
6. On iPhone, inspect short viewport, landscape where supported, largest text sizes, VoiceOver, silent operation, Reduce Motion, and Reduce Transparency. On Mac, inspect 800-by-600, ordinary laptop size, larger/full-screen and external display when available, live resize, keyboard-only operation, meaningful text entry in a native sheet, and menu-command preservation.
7. Exercise actual native camera/TCC denied or unavailable behavior and external/Continuity disconnection where hardware permits. Name every missing physical-device or camera proof explicitly. A simulator cannot establish real framing, redaction, capture timing, or external-camera recovery.
8. Observe presentation work while visible, hidden, minimized, and inactive, and when low-power or thermal policy is applied through the supported path. Confirm that the timer stops decorative work without pausing service time or restarting the camera. Do not claim measured energy savings without measurement.

If a required platform runtime is unavailable, use a focused throwaway logic smoke only for what it can prove and state the missing native visual/input or physical-camera evidence. Do not report the whole slice as complete based only on that substitute, compilation, or unrun checks. Do not rerun a user-reported failure merely to confirm it; use the report as evidence and verify the changed path after the fix.

## Human Verification Handoff — Required

List these implemented areas separately, with their actual changed files and observed verification:

- Shared phase-clock projection and service-boundary behavior.
- Distinct local capture-delay presentation and interruption cancellation.
- iPhone composition, accessibility, and safe-action reachability.
- Native macOS composition, keyboard/window lifecycle, and camera recovery integration.
- Motion, reduced settings, and energy-safe resumption.

Ask the user to review the code changes and state which items are ready for human verification. A human remains the final verifier; no automated check constitutes human approval. Name any prerequisite, platform runtime, hardware, or unresolved product decision that prevented proof. Do not conceal missing physical capture behind a simulator result.

CYCLES.md records implementation and the handoff, not invented human acceptance. DOCKS remains plain-language product context with no test output, screenshots, logs, payloads, completion claims, or implementation checklist. No screenshot/recording evidence package is required. Update accepted product decisions in the smallest relevant DOCKS only after the user's acceptance, unless the decision was directly approved before implementation.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Perform this component slice yourself. Do not delegate reviews or create competing native variants.
2. **No silent model fallback.** Honor openai-codex/gpt-6-astra with thinking max; report dispatch inability honestly. Do not confuse the worker with the in-app judge.
3. **User direction wins.** Preserve both native platforms, the top clock, every public badge, and two large vertical participants. Report an actual conflict; do not revert to the older optional two-column design.
4. **Research before editing.** Use current code, relevant installed guidance, and public API availability. Reuse existing ownership and visual patterns; do not blindly follow recipes or upgrade targets to fit them.
5. **Real connected behavior only.** No stub actions, no-op capture, fabricated timestamps, fake peers, unvalidated scores, local Elo, second judge request, unredacted fallback, or production mock. Preview fixtures must be unmistakably preview-only.
6. **Privacy and service authority outrank animation.** Stop/shield immediately. Timers do not grant permission, finalize results, alter quota, or extend deadlines.
7. **No unrelated changes.** Inventory actual callsites and scope the necessary integration. Preserve the user's and other workers' changes, existing commands, Profile's two-side shape, exercise privacy, and unrelated feature behavior.
8. **Focused real smoke.** Run the changed native surface on iPhone and Mac where available, observe the critical paths, fix clear failures, and report limits. Tests alone are not proof. Do not create wording, forwarding, mock-echo, source-text, or bare-not-throw tests.
9. **Update only the relevant CYCLES implementation todos.** Mark implementation complete only when connected behavior and focused checks support the human-review handoff. No duplicate IDE todo JSON; no assertion of human approval.
10. **Scoped commit and push for the future implementation.** Once a coherent implementation slice is checked and handed off, commit only its authorized files with a clear message and push to origin/main. Preserve others' changes; no destructive history rewrite or force-push. If commit/push is unavailable or fails, state the exact blocker and do not claim publication. This rule applies to the future implementation session, not a license to publish another worker's coordinated documentation batch.
11. **Complete the reachable functional slice.** Do not stop at a disconnected clock preview, compiling scaffold, or a tests-only handoff. Missing real prerequisites must be named instead of hidden by a replacement implementation.
12. **No pointless next prompt.** Do not generate another prompt solely for obvious fixes, smoke checks, CYCLES updates, a commit, or a push. A new prompt is warranted only for an actually separate substantial approved feature slice with its own dependencies.

## When You Finish

Report the implemented items and actual changed paths, exercised native checks and their limits, human-review request, publication result, and any real remaining prerequisite. State whether a next prompt was necessary. Keep the scope decision factual: what is connected and checked, what remains genuinely blocked, and what the user needs to review. Do not substitute a plausible timer animation for the specified authoritative behavior.
