# Phase 1 of F29-G-c — Native Battle Background

## Model and Dispatch Contract

Required implementation-worker assignment: **openai-codex/gpt-6-astra:max**.

The model identifier is **openai-codex/gpt-6-astra** and the thinking level is **max**. Do not silently substitute a different model or lower thinking level. If this assignment cannot be provided, report the dispatch limitation before implementation. This is a UI engineering assignment, not a change to the in-app judging model, provider, rubric, or policy version.

One owner performs this slice. Do not launch nested agents or delegate repository review. Do not generate images, video, audio, 3D assets, or a parallel prototype. The background requires native shapes and colors, not generated artwork.

## Features Included

- **F29-G-c — Battle Background:** the real active battle's matte dark/orange arena apron on native iPhone and native macOS.
- Within that component: measured decorative geometry, neutral event feedback, one bounded ambient layer, lifecycle and energy suppression, accessibility behavior, and public older-OS rendering fallbacks.
- The minimum integration into the reviewed real battle host needed to consume authoritative state, current privacy/capture ownership, measured geometry, and shared motion priority.

Do not absorb the timer, badge rails, player panels, capture system, privacy cover, results, identity catalog, camera picker, or safety sheets into this component. List the implemented responsibilities separately in the final human-review handoff. CYCLES.md is the only project task tracker.

## Context

The user requires native iPhone and native macOS, a real top timer, every public badge above two large vertically stacked participants, and tactile minimal-text sports UI.
F29-G-c specifies a restrained arena backdrop that never alters evidence or suggests a leader.
This prompt authorizes a future connected implementation only after the prerequisites below have been implemented and human-reviewed.

## What You Need to Read First

Read product context as requirements and boundaries, not as an unvalidated implementation recipe:

- features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md — the entire component specification.
- features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md — composition, component ownership, shared motion coordination, and integrated sibling links.
- features/F29-physique-duels/DOCKS.md — current shared contract and user decisions.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — battle host, camera, safe actions, focus, native lifecycle, and recovery.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — accepted inputs, judge blindness, finality, and prohibited provisional appearance scores.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — authoritative Go, one active match, deadlines, exactly-once effects, and corrections.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — immediate hide/block/report protection and pre-/post-Go consequences.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — camera lifecycle, face masking, consent, protected access, and truthful restoration.
- F29-F's canonical identity/country/badge document, reached through the integrated F29 parent. Discover its actual path there; do not invent a second badge catalog or guess a filename.
- CYCLES.md — the current F29-G-c scope and explicit human review of its dependencies. Do not assume checkbox completion means human acceptance.
- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228 — shared near-black/graphite/orange palette and native controls.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38 — shared spacing, readable width, touch target, and Inter typography.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80 — public material availability, Reduce Transparency, and the existing press spring.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188 — action and earned-rating visual vocabulary. Do not copy Dynamic Type clamps or cosmetic authority.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151 — exercise HUD context only, not a physique lead bar or provisional body score.
- TimeMaster/App/TmaxApp.swift, lines 8–19 — native Mac WindowGroup, normal title bar, and 800 by 600 minimum.
- TimeMaster/App/TmaxCommands.swift, lines 6–37 — existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O commands.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109 — local cosmetic previews are not trusted competitive achievements.
- TimeMaster.xcodeproj/project.pbxproj — discover the current app targets and retain iOS 16 and native macOS 14 compatibility. Other targets' versions do not authorize raising the app baseline.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the image. Borrow direct hierarchy and the large top timer, not its side-by-side players, over-body labels, people, footage, purple/brown web pills, or implied publication rights.

Discover and read the **actual reviewed host, shared motion boundary, privacy lifecycle, and capture presentation** under TimeMaster/Views/Physique/, TimeMaster/Services/Physique/, and the feature's models before editing. Source locations may have evolved by implementation time. Do not open guessed future host files or create a new host because a proposed filename is absent.

Relevant installed skill context:

- skill://swiftui-pro, especially references/performance.md and references/accessibility.md.
- skill://swiftui-animation for narrowly scoped, interruptible animation and Reduce Motion.
- skill://apple-hig-reference; read the live Motion and Designing for macOS chapters below.

The documentation coordinator selected dimillian/swiftui-ui-patterns through UI Skills. Reuse that selected context when available; do not repeat installation/setup or broaden this slice into a skill search. Skill defaults for new iOS 26 projects do not override this existing app's deployment targets.

Live references:

- https://developer.apple.com/design/human-interface-guidelines/motion — Best practices and Providing feedback: purposeful, optional, brief, interruptible motion.
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices: resizable windows, native input/commands, and active/inactive transitions.

If current live guidance cannot be retrieved, name that limitation. Do not attribute the component's exact opacity or timing choices to Apple. There is no STYLES.md requirement to create a new global design file; use existing source conventions.

## What Happened Last Session

The preceding slice was documentation only. It selected an arena-apron composition, defined privacy-safe motion and both platform layouts, and supplied this implementation brief. It did not implement a Swift view, a shared foundation, a model provider, a working camera, a mockup, or an accepted prototype. No build, runtime, accessibility, energy, or physical-camera result is implied by the documents.

The user-directed vertical composition supersedes earlier F29-A language allowing two-column desktop comparisons and treating macOS as secondary. The main documentation owner reconciles shared documents. Do not use stale wording to restore side-by-side players or claim that the current specification proves a real service exists.

## Prerequisites and Human-Review Boundaries

Before code, establish from the repository and the explicit review record that all relevant shared foundations are implemented and human-reviewed:

1. Real authenticated match state, authoritative Go/deadlines/finality, and one active match per account across windows/devices.
2. The actual iPhone and native Mac battle hosts, top timer, complete identity/badge rails, and large vertical participant panels.
3. Capture/redaction lifecycle, exact selected-image preview, immediate privacy cover, safe interruption, and explicit camera resume.
4. Shared identity permission and badge state, safe opponent placeholders, report/block/revocation routes, and terminal media-access boundaries.
5. A way for the host to express foreground focal ownership and the single permitted ambient layer without the background polling services or inventing match state.

A stage built from fake opponents, canned scores, an always-successful permission service, a no-op Capture button, or a local result simulator does not meet these prerequisites. Do not build a replacement backend or camera system in this slice. Complete reachable research and state the exact missing contract if blocked; leave implementation pending rather than committing an unconnected production view as completed work.

A missing provider credential or physical camera is not permission to show a rated mock. Preview-only fixtures, if already useful in the project's established workflow, must be conspicuously preview-only, contain no real private media, and remain impossible to reach from production navigation. No separate production fallback feature or new screen is authorized.

## Design Decisions to Preserve

### Arena apron, not an animated body treatment

Use the existing 0A0A0A base, 141414 graphite well, established 1C1C1C foreground surfaces, and FF6A00 orange. Add a thin shared lintel immediately below the timer region with short static edge returns outside the evidence and controls. It belongs to the entire stage, never one player's border.

One fixed, symmetric diffuse orange wash is visible only in the exposed surrounding chrome. Both participant wells and their letterboxing, timer backing, badge rails, and controls remain opaque and neutral. Do not sample a camera image, tint skin, reshape a body, blur live content, animate a face mask, or decorate according to relative Elo, country, badge count, upload speed, or predicted outcome.

The backdrop reserves no new layout height or width. If safe decorative space disappears, remove decoration rather than shrink a participant, clip badges, or cover an action. Use shared measured geometry and spacing. No screen-coordinate positioning, hardcoded camera rectangle, fixed-size screenshot layout, global theme fork, private rendering API, or new asset dependency.

### Same information order on both platforms

Top timer/honest stage anchor; all You identity/badges; all Opponent identity/badges; large You panel; large Opponent panel. Preserve this order at every width, including wide Mac windows. Public rails wrap without a three-badge cap, hidden extra-count chip, auto-scroll, clipping, or hover-only access. F29-F owns which public claims are valid; this view must not infer them.

On iPhone, preserve safe-area and existing navigation clearance, forty-four-point primary/safety hit regions, Dynamic Type, landscape, keyboard handling, and a scrollable stage with reachable timer/actions. On native Mac, retain the existing 800 by 600 minimum, normal title bar, toolbar/sheets/inspectors, keyboard focus, and window behavior. Laptop and minimum-size windows scroll; large/full-screen/external-display windows retain one centered vertical stage and quiet margins. Any existing supplementary inspector remains supplementary. Do not create a second matchup column.

### Deliberately bounded animation

The wash has one twelve-second cycle: six seconds from six to ten percent opacity, six seconds back, smooth endpoints, fixed position/shape/color. It has no semantic meaning. Never add a second glow, moving grain, parallax, scan line, body outline, or urgency acceleration.

The wash runs only when the actual nonterminal battle is visible, active, owning, unoccluded, not being interactively resized, not covered by a modal, not acquiring camera frames, and not suppressed by Reduce Motion, low-power mode, or elevated thermal state. Another ambient owner takes precedence. During acquisition the wash remains static at its resting appearance; the foreground timer and controls carry the real feedback.

On authoritative Go, the single lintel accent may extend symmetrically from eighty percent to its full existing span over 280 milliseconds, ease-out without overshoot. The host must have the focal slot free and camera acquisition must not be active. Countdown/Go text, capture, or foreground result motion always wins. If unavailable, apply the static end state immediately; do not defer the accent or wait before starting capture.

Stage entry can share the host's 280-millisecond transition. Terminal settling is at most 180 milliseconds and is immediate when the result owner already has focal motion. There is no separate background accent for Ready, timer ticks, accepted poses, transfer updates, badges, history reopening, corrections, or recovered missed events. Shared final choreography must settle within 900 milliseconds total, with final data and actions accessible immediately.

Reduce Motion uses the complete static state, with at most 120 milliseconds of non-protective opacity change. Low-power mode and fair/serious/critical thermal states also use the static treatment. Protective hiding and camera stop are immediate. New authoritative or privacy state interrupts decoration without waiting for an animation completion.

## What to Build

### 1. One scoped native view

Implement one small PhysiqueBattleBackground component in the established feature structure. Prefer ordinary SwiftUI shapes, fills, a fixed gradient, and narrowly scoped opacity/line animation available on the existing deployment targets. Newer animation APIs must have a genuine availability-safe baseline; there is no need to require PhaseAnimator, KeyframeAnimator, shaders, MeshGradient, or Liquid Glass for this design.

Keep the noninteractive opaque base available on first render, every error, and every visual fallback. Hide decorative content from accessibility and disable hit testing without disabling or obscuring sibling foreground controls. Do not introduce AnyView-based indirection, a generalized particle/rendering engine, or a new app-wide design abstraction for this one component.

### 2. Connect the real host without owning competition

Consume the minimum reviewed presentation facts: current authoritative match stage/identity, actual privacy/capture suppression, foreground focal/ambient ownership, measured stage bounds, and native visibility/energy/accessibility conditions. Reuse the existing match identity and lifecycle. Do not maintain a second match clock, calculate wins, persist a decoration history, or fetch service state from the background.

A local countdown reaching zero is not Go. Unknown finality remains Awaiting confirmed result. Duplicate state delivery, a view rebuild, a window reopening, or account restoration cannot replay a start/award or revive a terminated match. A correction is a separately labeled existing result change, not a background event reward.

During pairing/capture/upload/judging, keep the opponent as permitted identity/avatar/silhouette plus real stage/count. Do not insert early thumbnails or live video. Keep the full badge rails above both large vertical players even when stage scrolling is required. Do not touch badge eligibility logic or local cosmetic models.

### 3. Keep camera and masking geometry independent

Do not attach a background animation transaction, scale, rotation, clipping change, matched-geometry effect, shader, or animated identity to the camera/participant subtree. Keep the actual camera session and redaction coordinate system stable across wash changes, Go, pose acceptance, scrolling, resizing, full-screen changes, and display migration.

Aspect-fit evidence without cropping required body regions, nonuniform stretching, altered relative size, or decorative overlays on the mask. Camera, mask, and exact selected still remain under their existing owner. Judge uploads use clean locally redacted evidence, not composited UI snapshots. No country, badge, name, Elo, backdrop, timer, or decorative flag is added to judge content or context.

### 4. Connect suppression and recovery

Stop decorative work immediately for camera acquisition, an offscreen/covered stage, app inactivity/background, locked phone, minimized/hidden/non-key/occluded Mac owner, interactive resize, Reduce Motion, low-power mode, and elevated thermal conditions. Read existing lifecycle and resource state rather than inventing polling or repeating timers that survive their view.

Capture and privacy owners stop acquisition/shield media immediately for the actual privacy/interruption conditions; the background is not itself a privacy mask. Native permission or safety sheets cannot conceal a continuing camera. When the app returns, reconcile the same service state and require explicit permitted capture resume; no automatic still, upload, gallery reopen, start animation, or missed-cycle catch-up.

Search remains bounded by ninety seconds, countdown by the service's three seconds, capture by the original ninety seconds with at most two retakes per pose, reconnect by twenty seconds without deadline extension, and judgement by thirty seconds after receipt of both final sets. Five seconds remains an unmeasured result target. The background creates no countdown or progress percentage of its own.

### 5. Preserve native input and window contracts

No gesture, hover, focusable element, global Return/Space binding, or keyboard monitor belongs to this backdrop. Keep all foreground focus rings unobscured. Return/Space activates only the focused semantic control, never Capture while typing a report. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.

Escape first respects native sheet/edit context and then the host's state-aware exit. Cmd-W and ordinary quit use real active-match confirmation where the platform permits; force quit/process death remain involuntary interruption, not a fabricated confirmed forfeit. A secondary window cannot become another camera owner or active session. Restore/focus the existing owner through its reviewed route rather than adding a new takeover UI.

TCC denial/restriction, camera busy/missing, and external/Continuity disconnect use the real safe placeholder and useful Settings/Retry/camera recovery actions. No fake camera, rated file picker, or silent camera switch. Do not reset the match deadline or retained retake count during recovery.

### 6. Preserve truthful failure and terminal states

Connection loss, an unknown deadline outcome, mask failure, invalid evidence, safety abort, forfeit, no-contest, and a valid judged result remain distinct. Their text and recovery actions come from their owners; this view introduces no extra alert or competing status copy.

Hide/report/block/revocation removes sensitive display immediately, without animated unblur or a dissolving exposed body. Block after Go does not automatically leave or rerate. Only a valid AI-judged win/loss/draw plus current permission and intentional View poses may expose counterpart stills; forfeits/no-contests have no gallery. Ordinary twenty-four-hour media expiry, corrections, and account switching are unaffected.

A rendering enhancement failure selects the opaque static stage. This legitimate rendering fallback cannot become a no-op substitute for real data, camera, consent, safety, provider, or service behavior.

## Prospective Files and Scope

- Create or, if the reviewed foundation already supplies it, modify **TimeMaster/Views/Physique/Components/PhysiqueBattleBackground.swift**. Reuse the actual established component location if it differs; report the resolved path rather than creating a duplicate convention.
- Modify only the **actual reviewed battle host under TimeMaster/Views/Physique/** and its existing narrowly scoped presentation/motion boundary as needed to embed this background and provide real state. Discover exact filenames first. Do not scaffold a host or create a second state store.
- Update **CYCLES.md** only for this slice's actual implementation and remaining human review, after the component is connected and focused checks pass.
- Update the smallest relevant **features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md** only for a subsequently accepted product change. Do not put code, todos, logs, screenshots, test results, or completion claims there.
- Existing native test files may change only for a necessary consumer-visible regression under established conventions. Do not add a permanent test just to assert source text, color constants, forwarding, or that a view exists.

Do not change global theme values, existing app commands, app-wide minimum window dimensions, deployment targets, exercise scoring/privacy, provider configuration, service schema, badge catalog, unrelated F29 screens, or other workers' targets. Change target membership only if the actual project requires it for this one source file; do not regenerate unrelated project configuration.

## Observable Acceptance — Both Native Platforms

### Composition and evidence

- With a real pairing, the top timer/honest stage anchor appears before complete owner-grouped public badge rails, followed by large vertical You and Opponent panels. Every public badge is reachable without an extra-count chip, ticker, hidden row, or hover requirement.
- Small iPhones, landscape, large accessibility text, a keyboard, and an 800 by 600 native Mac window preserve readable timer/actions and scroll the central stage rather than shrinking players. Wide/full-screen/external-display Mac layouts never switch to side-by-side players.
- Orange lighting stays outside opaque foreground wells and letterboxing. Changing motion state cannot tint skin, cover masks, move evidence, restart the camera, or change capture orientation.
- A permission, service, or renderer failure retains real recovery controls. No action is a placeholder and no fake peer/camera/score appears.

### State and motion

- Only the single specified wash can repeat, and only in its permitted conditions. Observe a complete twelve-second cycle during a real eligible waiting state; no extra lights, particles, flicker, or inferred progress.
- Countdown and real capture suppress the wash. An actual Go cannot be generated by local animation. A foreground focal event suppresses the optional background latch without delaying the real state or queuing a replay.
- An interrupted transition stops immediately when privacy, capture, visibility, energy, or accessibility state changes. Reopening and reconnecting do not replay start/award effects or extend deadlines.
- Win, loss, draw, forfeit, no-contest, corrected history, and unknown finality never receive winner-biased lighting or invented scores. Final numbers and safe actions remain immediately available through their owner.

### Accessibility, lifecycle, and compatibility

- VoiceOver/keyboard/Switch Control skip the decorative layer and retain foreground order and controls. No timer-tick or ambient announcement; no clipped focus ring or global Return/Space capture while editing.
- Reduce Motion gives a complete static interface; Reduce Transparency gives opaque backing; Increased Contrast removes low-contrast decoration while preserving useful boundaries and labels.
- Low-power and elevated thermal modes stop repeating work. Inactive/minimized/hidden/offscreen Mac windows and backgrounded iPhones do not continue decorative animation or sensitive acquisition. Service deadlines continue.
- Camera/TCC denial, external/Continuity disconnect, and resume use real causes and permitted actions. Return needs authoritative restoration and explicit permitted capture resume. A secondary window cannot acquire another session or charge.
- Existing iOS 16/native macOS 14 paths render the complete static/native treatment through public APIs. The normal Mac title bar, 800 by 600 minimum, commands, native sheets, full-screen behavior, and live resizing remain intact.

## Focused Native Checks and Smoke Scenarios

Run the smallest relevant build/typecheck or existing focused regression path after implementation and fix clear failures. Compilation is not proof of this visual slice. Launch and exercise the **actual changed native surface on both platforms wherever runtime is available**; report which configurations were exercised and which were not. Do not run unrelated suites or paid judging evaluations merely for decoration.

1. **Real connected path:** with authorized consenting adult accounts and the reviewed service, exercise pairing, Ready/countdown, capture, waiting/upload, and final state. Observe the background's actual suppression and foreground hierarchy. If a required service cannot be reached, identify that missing prerequisite instead of substituting a production mock or claiming end-to-end completion.
2. **iPhone geometry/accessibility:** small available iPhone configuration, landscape, largest relevant Dynamic Type, Reduce Motion during the loop and an event, Reduce Transparency, VoiceOver, and a keyboard-visible report sheet. Reach timer, Stop/Exit, and Safety while rails and players scroll. Opening the sheet must not hide an active camera.
3. **Native Mac geometry/input:** actual app at 800 by 600, laptop size, large/full-screen, and live resize. Use keyboard-only focus, Space/Return on focused controls, text editing, Escape, Cmd-W/ordinary quit confirmation, and existing commands. Move to an external display if one is available; report its absence rather than claiming it was covered.
4. **Resource and lifecycle:** start eligible ambient work, then background/lock the phone and minimize/hide/deactivate the owning Mac window. Observe cessation of repeating decoration and the real privacy/camera stop, not merely a hidden visible layer. Return to the same service state without replay or deadline reset. Open a secondary Mac window and confirm it does not acquire a second active camera/match.
5. **Camera boundary:** use actual hardware for camera-session and face-mask alignment, permission denial/recovery, and external/Continuity disconnect where available. A simulator is useful for layout and lifecycle but cannot prove physical capture, TCC-device behavior, optical alignment, or Continuity recovery. State missing physical-camera proof precisely.
6. **Motion/energy:** observe the full twelve-second wash only in an eligible noncapture state and inspect that foreground focal work suppresses the background accent. Change Reduce Motion and available low-power settings mid-effect. Exercise thermal suppression through the project's established diagnostic path if available; do not manufacture a thermal claim or add a permanent user-facing debug control. Use focused native profiling when needed to establish that stopped/covered views cease decorative updates and that animation causes no camera rebuild, per-frame I/O, decode, font measurement, or global layout churn.
7. **Failure and restoration:** exercise actual permission/network interruption, same-match resume, and available terminal result paths. Unknown service finality must stay unknown; a no-contest/forfeit must not unlock poses. Reopen a result and observe no background award/start replay. Respect image privacy throughout; use no real participant images in routine logs or screen-replay tooling.

Keep any diagnostic/throwaway harness outside production and remove it after use. Add a permanent regression only for a plausible consumer-visible behavior that is uncertain or was actually broken, following existing deterministic isolated conventions. No source-string assertions, mock echoes, incidental color/timing-default tests, wiring-only tests, or bare not-throw checks. Screenshots and recordings are not required and do not substitute for exercised native interaction.

If only one native runtime is available, complete its reachable checks and name the unavailable platform/hardware precisely. Do not claim both-platform verification or mark the feature human-verified from a preview, build, unrun scenario, or document.

## Human Verification Handoff — Required

List each meaningful implemented item and every changed file separately. At minimum distinguish:

- Native arena-apron visual component and measured geometry integration.
- Real stage/event connection and one-ambient/one-focal priority.
- Camera/privacy independence, interruption, and recovery behavior.
- iPhone/native Mac layout, input, accessibility, energy, and baseline rendering behavior actually exercised.

State concrete limitations and any unavailable service, OS, display, or physical-camera proof. Ask the user to review the code changes and the native behavior of each item. Human acceptance remains pending until the user explicitly provides it. Do not claim the judge, badge system, camera foundation, or entire F29 is implemented by this component.

Record implementation only in CYCLES.md after connected behavior, focused checks, and a clear handoff. Accepted product decisions belong in the smallest relevant DOCKS.md after user acceptance; verification evidence does not. Report only observed checks in the final response.

## Mandatory Agent Rules

1. **Exact assignment:** openai-codex/gpt-6-astra, thinking=max; no silent fallback. UI-worker selection does not select an in-app judge.
2. **Single owner:** no nested agents, no delegated repository review, no unrelated changes, no generation calls, no new app-wide rendering/theme framework.
3. **Real connected behavior:** no fake peers, provisional appearance scores, mocked production service, no-op control, placeholder implementation, or unauthenticated media fallback. Preview fixtures never become production behavior.
4. **User direction wins:** preserve both native platforms, all public badges above large vertical players, minimal text with essential privacy/safety information, and current product decisions. Surface a concrete conflict rather than silently changing the requested result.
5. **Independent engineering:** use existing source patterns and relevant skills; preserve iOS 16/macOS 14 public fallbacks despite newer defaults in skill examples. DOCKS is plain-language product context, not an implementation recipe.
6. **Privacy and authority first:** protection and camera stop never wait for motion. Service state owns match timing, finality, exactly-once Elo/allowance, and corrections. Background state never owns them.
7. **Focused checks and actual smoke:** exercise the changed native path and fix clear failures. No compilation-only completion, invented check output, exhaustive evidence package, or speculative unrelated debugging.
8. **Scoped publication:** after a complete working slice, commit only your authorized changes with a clear message and push to origin/main without force or rewriting history. Preserve unexpected user/coordinator changes; do not sweep another worker's files into your commit. Report exact commit/push blockers honestly.
9. **One tracker:** update only the relevant CYCLES.md implementation todos and pending human-review record. No IDE task JSON, extra project checklists, or completion evidence in DOCKS. Do not mark a prerequisite accepted on the user's behalf.
10. **Complete this slice:** leave no stub, duplicate legacy rendering path, unused effect helper, temporary debug scaffold, or disconnected production component. Do not generate a next prompt merely for checks, an obvious fix, docs, commit, or push.

## When You Finish

Return the itemized human-review handoff, actual changed paths, exercised native checks, known limits, publication result, and whether any genuinely necessary next scope remains. Ask for review of the code and native behavior. Do not claim human approval or App Store acceptance.

## Scope Decision Before Finish

Describe completed connected responsibilities and checks, any exact remaining prerequisite, and the decision: no next prompt, a genuinely separate substantial implementation slice, or a specific external/review blocker. Small remaining work belongs in this slice. Do not create a testing-only or publication-only handoff.
