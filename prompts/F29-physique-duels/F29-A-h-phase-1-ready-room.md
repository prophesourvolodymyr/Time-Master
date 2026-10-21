# Phase 1 of F29-A-h — Native Ready Room

## Assigned Model and Mode

Use model **openai-codex/gpt-6.1-sol** with **thinking level max**. The assignment is **openai-codex/gpt-6.1-sol:max**. Max is the worker's reasoning level, not another model, a separate in-app judge, or a change to the ranked judging policy. Do not silently substitute a model or reduce the thinking level. If the requested dispatch is unavailable, report that exact dispatch limitation to the coordinating owner before implementation.

This is a future connected native implementation brief. The documentation-only batch that produced it does not authorize app code, service scaffolding, fake data, generated artwork, or claims that the design or foundations have passed human review. Begin code only when the user/main owner explicitly assigns implementation and the real shared prerequisites below are implemented and human-reviewed.

## Features Included

- F29-A-h — Native iPhone and native macOS Ready-room composition.
- F29-A-h — Independent explicit Ready and Not ready with honest pending/confirmed state.
- F29-A-h — Service-authorized three-second countdown and exactly-once Go handoff.
- F29-A-h — Pre-Go Cancel and Block behavior, including late-Go races and unknown outcomes.
- F29-A-h — Camera/consent interruption presentation, native input and accessibility, resizing, reduced motion, and low-energy behavior within this room.

These are one connected functional slice. List each meaningful implemented item separately for human verification. Do not implement another lobby, country editor, badge catalog, report form, camera setup screen, capture screen, result screen, recovery center, or global visual system under this assignment.

## Context

Ready room sits between a real eligible pairing and the existing guided capture flow. Its invariant is a top timer, complete owner-grouped public rails, then large You and Opponent panels stacked vertically on both platforms. Independent readiness is user-owned; start authorization, Go, deadlines, cancellation, allowance, and outcomes are service-owned.

## What You Need to Read First

Read these exact product files completely for the affected behavior:

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-h-ready-room/DOCKS.md` — the complete Ready-room composition, state/action matrix, native-platform behavior, motion, and privacy specification.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — entry, preflight, routing, capture handoff, safe exit, and focus context.
- `features/F29-physique-duels/DOCKS.md` — shared competition, timing, consent, and finality invariants.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Accepted Inputs and Judge Blindness; no identity, badge, country, rating, or UI screenshot as judging input.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — Unplaced, Provisional, and Placed; Pairing Eligibility and Search; Allowance, Cancellation, and Interruption Boundaries; Authoritative Finality.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — Safety Access; Reporting Interaction and State Contract; Blocking Before and After Go.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — Distinct Permissions and Choices; Camera and Device Privacy Lifecycle; Authentication, Access, and Secret Boundaries; Operational and Privacy Failure States.
- `features/DOCKS.md` and the F29 section of `CYCLES.md` — actual integrated ownership, implementation authorization, and human-review boundary. Documentation checkmarks are not acceptance of the app or service.

Then discover the integrated F29-F identity/country/badge specifications and shared F29 battle-component specifications through the feature index. Read the actual owner documents and reviewed code before choosing symbols. Their directory and source names were not established by this documentation-only worker; do not invent paths or add a parallel implementation because a prospective name differs. Read the actual prepared-pairing caller, readiness/state owner, camera owner, capture destination, safety entry, and recovery routes as they exist at implementation time.

Existing source anchors to inspect and reuse, not mechanically copy:

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — near-black background, dark surfaces, orange actions, shared card/control treatments.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — existing spacing, readable-column convention, Inter typography.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material/native-glass fallback, Reduce Transparency, and shared press feedback with response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — native sports actions and earned-Elo visual language. Do not propagate its Dynamic Type clamps, text shrinking, or exercise-domain assumptions.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only. Do not copy its side-by-side scoreboard, live exercise lead/provisional score, or movement timer into Physique.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable cosmetic badge previews are not trusted competitive achievements or identity verification.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar, and existing 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- `TimeMaster.xcodeproj/project.pbxproj` — inspect actual target membership and deployment settings. Preserve iPhone iOS 16 compatibility and native macOS 14; no target raise or assumption of 26-only APIs.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow large timer and immediate participant hierarchy, not its side-by-side arrangement, over-face labels, web pills, footage, faces, copy, or asset rights.

Relevant installed native skills and live references:

- `skill://swiftui-pro`, especially accessibility, views, data ownership, and performance references.
- `skill://swiftui-animation` for scoped state-driven motion, interruption, and Reduce Motion; choose APIs that actually exist on the deployment targets.
- `skill://apple-hig-reference`; inspect the relevant catalog and live Apple chapters rather than asserting recommendations from memory.
- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — Best practices for resizable windows, large displays, native commands, keyboard and pointer.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — purposeful, optional, brief, cancelable feedback.

The main owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse the supplied/installed selected context if available; do not rerun setup or install a second skill suite. This independent documentation worker could read the installed SwiftUI/HIG skills but did not locate a local file for that selected CLI context in its searched skill directories. That is a context-access limitation, not evidence of a failed CLI selection or permission to claim the pattern was read. `STYLES.md` is absent in this design batch; use existing source conventions, not a new global design document.

## What Happened Last Session

The independent native UI worker authored the F29-A-h product specification and this future brief, read the shared contract, the existing F29 boundaries and source anchors, inspected the supplied reference image, and consulted installed SwiftUI/HIG guidance plus the live Apple macOS and Motion chapters. No production Swift, backend, artwork, mockup, runtime verification, human approval, build, test, or publication is claimed by this work. The main owner integrates shared documentation, resolves sibling ownership, validates the documentation batch, and publishes it.

The concrete decisions are large vertical players on every width, complete rails above them, no opponent preview, a timer dash until actual authorization, reversible independent readiness, and no automatic forfeit from a late Cancel or Block. Existing older F29-A language that permits a horizontal desktop comparison or suggests fade-only countdown motion is subordinate to this explicit design direction for the Ready room.

## Prerequisites and Human-Review Boundary

Before implementation, establish from integrated code and the owner's review record that the following real contracts exist:

- Authenticated Physique pairing and restoration for one account-wide reserved/active match, with the existing exercise domain left unchanged.
- Service-confirmed independent readiness, pending/rejected/unknown mutation behavior, readiness withdrawal/invalidation, and rejection of stale starts after prerequisite changes.
- Service-owned start scheduling and authoritative Go, the shared capture deadline, real cancellation/block ordering, reservation accounting, and a way to reconcile the exact same match after connection loss or ambiguous delivery.
- Current eligibility, consent/rules versions, healthy service/judging policy, and permitted public match identity/Physique rating context.
- F29-F public handle/avatar/country/badge entitlement, canonical ordering, freshness, corrections, and access revocation. Optional badge-fetch failure is distinguishable from missing required match identity or eligibility.
- A reviewed camera owner that supports current permission, availability, preflight health, explicit stop/resume, immediate privacy cover, device/window ownership, macOS TCC, and external/Continuity disconnects.
- Reviewed capture, active-match exit, report/block/privacy, details, and recovery/lobby destinations. This room must route to them without owning another workflow.
- Real authorized service operation and moderation where rated participation requires them. A development deployment is not evidence of public launch permission or App Store acceptance.

Do not substitute an exercise service DTO, local Boolean pair, hardcoded Ready flags, local Go scheduler, synthetic opponent, file-picker camera replacement, client rating, personal provider key, mock server fallback, or fixture-backed production screen. Do not implement an unreviewed service or camera architecture under this UI brief. If a required authority is unavailable, establish the exact missing prerequisite from code/tools, report it to the owner, and do not ship a misleading connected-looking surface. Preview fixtures, if useful, remain explicitly labeled and preview-only.

## Concrete Design Reasoning Outcomes

- **Vertical fight card:** top timer, You rail, Opponent rail, large You panel, large Opponent panel. On Mac too. The cost is scrolling; the benefit is readable identity, large unclipped framing, and no web/video-call appearance.
- **Pinned essentials, scrolling stage:** timer and safe action areas remain usable while complete badge rails and large player panels scroll. An unbounded pinned badge wall is not an acceptable interpretation of all badges above the players.
- **Honest unscheduled state:** Start in with a dash until the service schedules the start. The ninety-second search/capture durations do not create a Ready-room timer. No separate timeout is invented; a real service reservation expiry is labeled explicitly if it exists in the reviewed contract.
- **Local upper panel, private lower panel:** the upper canvas continues the authorized local preview; the lower canvas is a permitted public avatar or neutral silhouette. No early stranger media is fetched or implied.
- **Ready is reversible and independent:** Sending Ready is not Ready. The opponent's acknowledgement never marks the person ready. Both confirmed checks can coexist with Waiting for start; they do not trigger a client-generated countdown.
- **Details are a reading boundary:** entering Rules, Pose guide, identity/badge details, Safety, or Privacy disarms local readiness. Stop acquisition before covering the preview. Return requires explicit resume/readiness rather than letting a start occur while the person reads. Reuse the existing owners; do not create a Ready-room-only details system.
- **No endless decorative loop:** tactile presses, acknowledged Ready marks, shared countdown pops, and stage continuity provide motion. Constant ambient camera/background/badge animation adds distraction and energy cost without useful state.
- **Consequences depend on the real boundary:** pre-Go Cancel/Block is no-penalty only when accepted before Go. A late request never silently becomes consent to a rated loss. Block after Go protects/excludes future pairs but does not leave.

## What to Build

### 1. Integrate the reviewed match owner

Receive the real prepared pairing and current account-scoped state from the existing flow. Use stable match identity and ownership across refresh, reconnect, window resize, background/return, and a second device/window. Do not create another reservation or camera session when the view appears, its task restarts, or the user inspects details.

Present missing required state as Checking match, not a plausible opponent card. Readiness, start schedules, Go, ended state, cancel/block receipts, and allowance consequences must reflect current authority and ignore stale updates for a different account or pairing. Optional avatar/country/badge unavailability must not be confused with missing eligibility. A sign-out/account change clears the prior account surface and inhibits stale callbacks immediately.

### 2. Build the shared vertical composition on both platforms

Reuse integrated shared timer, identity/badge rail, participant-stage, and action styling rather than forking each as a Ready-room-specific wrapper. Use the existing typography and spacing. No global theme, new app minimum, Dynamic Type clamp, arbitrary screen coordinate, duplicate camera renderer, or unnecessary framework abstraction.

Each owner rail contains the permitted real handle, optional self-declared flag, match-time Physique Elo or Unplaced, actual provisional state, placed tier only when truthful, current streak where supplied, and every earned launch badge in the F29-F canonical order. Preserve Placed meaning when composing it with tier. Distinguish Three Straight's historical milestone from current streak. Do not read `badgePreview` or local display levels as entitlement. Unknown is not empty; removals/corrections cannot linger as permanent claims.

Rail content wraps above both players without a three-slot cap, hidden +N, ticker, horizontal-only access, or hover-only explanation. Handles wrap and flags have accessible full region names. Unsupported/missing flags use the specified neutral state, never inferred nationality. No country editor, geographic inference, country filter, or scoring change belongs here.

Use full-column portrait-friendly canvases with matte aspect-fit framing. Keep You above Opponent at every width. Do not crop or warp a body/authorized avatar to fill a predetermined rectangle, overlay badges on anatomy, or shrink participants just to fit one viewport. A neutral silhouette is a functional absence state, not an unfinished asset. Do not generate artwork or republish reference-image people to fill it.

### 3. Connect independent Ready and Not ready

Enable Ready only under current authenticated ownership, eligibility, consent/rules, camera availability, adequate preparation, and active surface conditions. Name the actual missing requirement and route to its existing repair owner. Merely opening the room, granting permission, receiving a flag/avatar, or observing the opponent never acts as consent or Ready.

After activation, immediately show Sending Ready and shared press feedback; show the Ready check only after acknowledgement. Preserve separate opponent state. Expose Not ready after acknowledgement and keep it available before Go. Local withdrawal, camera stop, consent loss, app/window inactivity, or a reading/safety interruption inhibits local capture immediately and reconciles withdrawal with the service. Pending withdrawal is not falsely presented as shared cancellation. Repeated taps cannot generate conflicting matches or start schedules.

A Ready operation rejected or delivered ambiguously reconciles the same match before another attempt. Safe navigation, Safety, and camera stop remain usable during pending work. Do not freeze the whole room behind a blocking spinner.

### 4. Present the real shared countdown and Go

The top well displays a dash before a real schedule. Both ready without authorization says Waiting for start. Use only the service-approved schedule, mapped through the reviewed clock/state owner, to display the remaining 3, 2, 1 beats. A late subscriber skips elapsed beats; background return never resets to three. A display tick or animation completion never authorizes Go, consumes allowance, requests a model judgement, or selects a still.

Loss of trustworthy state removes the confidently presented countdown and shows Checking match or Reconnecting. If scheduled time has elapsed but Go is not confirmed, show Start unconfirmed. If a real reservation or reconnect deadline is displayed, name that interval and show only actual remaining time. Client timeouts do not invent no-contest or restored allowance.

At confirmed Go, hand off once to the reviewed first-pose capture route with the same match, camera owner, and authoritative remaining capture time. Do not restart a ninety-second clock, wait for Go animation, capture automatically, upload a stage screenshot, or show an opponent still. If an interrupted client restores a later stage or ended match, route to that actual state rather than replaying the room.

### 5. Connect Cancel, Block, and safety without race shortcuts

Before Go, Cancel match stops local acquisition/inhibits start and sends cancellation for this pairing. Show Cancelling until confirmed. No fake loss warning, assumed reservation release, started history row, automatic requeue, or local forfeit. Existing lobby navigation during uncertainty must preserve an honest pending-match entry and prevent a second search.

If the service confirms pre-Go cancellation, return to the existing lobby with the actual no-penalty consequence. If Go won, show Match started and offer Resume match plus the existing separate explicit Forfeit and leave confirmation. The original Cancel is not consent to the latter.

Use the existing contextual Report identity and independent Block routes. A report is not a block, leave, verdict, or receipt until its own real acknowledgement. Opening these surfaces obeys the reading/privacy boundary and does not grant extra match time.

Pre-Go Block confirmation states cancellation/future exclusion and the before-Go no-rating condition. Protect the local surface immediately, label unconfirmed service protection Pending, and prohibit another pairing until block state is reconciled. On pre-Go acknowledgement, release the reservation without Elo or consumed allowance. If Go already occurred, protect and exclude future pairings but explain that blocking does not leave; offer the actual active route and separate exit confirmation. Never repurpose a stale no-penalty block confirmation as approval of a rated loss. Keep safety/invalid/service-aborted no-contest precedence with the trusted owner.

### 6. Implement native iPhone behavior

Use the existing app navigation shell and measured safe-area bounds. Preserve directly reachable Cancel match and Safety, a prominent content timer header, a scrolling rail/player stage, and a persistent primary Ready/Not ready action plus real Stop/Resume camera. Always describe ongoing camera activity even when its local panel has scrolled out of view. No pre-Go evidence is selected or transmitted.

Exercise narrow/short portrait, landscape, largest Dynamic Type, long real handles, complete rails, and normal navigation placement. Reflow rather than clamp/shrink text or player panels. Keep at least the existing forty-four-point iPhone primary/safety hit areas. Respect existing floating/menu clearances without guessed bottom spacers.

Back/interactive dismissal is pre-Go cancellation, not an untracked disappear event. After confirmed Go, accidental dismissal cannot bypass the explicit active-match exit owner. Lock, call, app switch, sign-out, permission loss, and backgrounding immediately stop/shield acquisition and require real state restoration plus explicit resume/readiness. Camera privacy never waits for a sheet or transition animation.

### 7. Implement native macOS behavior

Preserve the normal title bar/traffic lights, WindowGroup, existing minimum 800-by-600 window, native toolbar, menu commands, and target. Do not use Catalyst/web content or an iPhone full-screen cover as the desktop presentation. The content timer is prominent below native chrome; the stage scrolls; the bottom action strip remains usable.

At minimum, laptop, large, full-screen, and external-display sizes, keep the same vertical player order and full rails. An optional native Details inspector contains only already-owned protocol/badge/sharing details. It is not a second matchup column and never hides the only copy of an essential action. At constrained width use the same owned sheet/popover route. Its deliberate reading boundary disarms local readiness; return does not automatically re-ready. Resize/reflow/display moves preserve current pairing, camera ownership, scroll/focus, and clock without entrance replay.

Use real macOS TCC and distinguish denial, restriction, no camera, another app using it, and external/Continuity disconnect. Clear the old frame immediately. Offer actual System Settings/Retry/existing setup actions only where helpful. Device selection before Go requires explicit readiness again and continues the same eligible pair rather than charging or queueing anew. No fake camera, prerecorded rated file, or auto camera takeover.

Only the owning active window can acquire camera or mutate readiness. Secondary windows/devices show the actual same-match state and supported route to the owner. Minimized, hidden, inactive, background, and non-owning surfaces stop/shield acquisition and pause decoration. Resume checks the original service stage/deadlines, never reschedules the start or spends another slot.

Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. Return/Space activate only the focused semantic control; never install a global Ready/capture key that intercepts typing. Use visible native keyboard focus and sensible Tab/Shift-Tab order. Pointer hover/help is supplementary, never required to find a badge meaning or safety action.

Escape dismisses the foremost harmless sheet/popover first and respects a meaningful report draft; otherwise invoke the appropriate match exit. Cmd-W/quit stop capture promptly and use the real state-aware close confirmation where supported. Pre-Go closes cancel without false forfeit threats. Post-Go closes offer explicit active-match consequences. Unknown state is described as unknown and never implies a confirmed forfeit. Force quit cannot be prevented/confirmed; restore it as interruption, not voluntary loss.

### 8. Apply scoped, interruptible motion and accessibility

Implement the product timings from F29-A-h rather than an independent animation system:

- Pairing entrance: shared panel surfaces settle by no more than half a spacing step over about 280 milliseconds; no body zoom, data delay, or replay on resize/reopen.
- Press: existing shared response 0.24/damping 0.88, not another press spring.
- Acknowledged Ready: status-only 160-millisecond replacement, one settle no larger than 1.04, finished within 200 milliseconds; outline about 180 milliseconds. No confirmed effect for a pending request.
- Countdown: real second-aligned beats, maximum 1.06-scale pop settling within 220 milliseconds, about 180 milliseconds of stable-geometry digit replacement. New state interrupts; no queued/replayed beats.
- Go stage continuity: about 280 milliseconds, without delaying actual routing, actions, or deadlines.
- Ordinary status/badge revision: 140–180 milliseconds locally, no wall pulse or re-award. Protection, camera stop, and access removal are immediate.
- No continuous decorative loop. At most one focal event. Optional native activity feedback represents only real pending work.

Scope updates so a timer digit/readiness mark does not rebuild camera layers or reflow the entire stage. No per-frame I/O, provider work, sorting, image decoding, font measurement, global invalidation, or new camera session. Pause decorative/offscreen work and remove optional scale effects for low power/elevated thermal pressure. Real service clocks continue.

Reduce Motion uses static state or short opacity with identical meaning; no scale/travel/loop. Reduce Transparency uses opaque readable surfaces. Increased contrast, the largest type settings, and non-color status recognition remain complete. Respect availability rather than raising targets for modern animation/symbol/material APIs.

Give semantic labels and stable identities to Ready, Not ready, Cancel match, Safety, Stop camera, Resume camera, every owner rail, and meaningful badge details. The timer exposes interval name and unit without a live per-second announcement. Announce real pairing/readiness/start authorization/errors/protection once; ordinary full countdown announces Starting in three seconds once, not each tick. Optional haptics/output cues do not replace text and request no microphone.

Ordinary incoming updates retain focus. Returning from details restores the invoking control or its surviving owner group. Go moves focus once to the first-pose instruction. All controls work with VoiceOver, Voice Control, Switch Control, keyboard, and pointer; no hover-, swipe-, drag-, or long-press-only essential path. Do not commit a report or activate a stale confirmation when authoritative state changes under a sheet.

## Prospective Files and Scope

- Create or reuse the integrated `TimeMaster/Views/Physique/PhysiqueReadyRoomView.swift` for the Ready-room scene. This is a prospective location, not proof that it already exists. If a reviewed owner already supplies the scene, modify that actual file instead of adding an alias or duplicate route.
- Modify only the discovered reviewed Physique match-flow caller and state/presentation integration necessary to route real prepared pairing, readiness, cancellation/block acknowledgement, Go, and recovery into/out of this scene. Record the actual paths before editing.
- Reuse the existing shared F29 timer, badge/identity rail, participant stage, native controls, camera owner, safety/detail routes, and service contracts. Do not create another version because their actual names differ from a proposed document name.
- Add target membership only if the new source needs it under the current Xcode project pattern; preserve deployment targets, signing, and native-platform membership.
- Update only the assigned F29-A-h implementation todos in `CYCLES.md` after connected work and review handoff. Do not change sibling status or treat those checkboxes as human approval.
- After implementation, preserve any new product decision in the smallest relevant product document only as authorized/accepted by the user. Keep engineering evidence out of DOCKS. No README, CHANGELOG, source-directory documentation, generated assets, unrelated app files, or IDE task JSON.

If the current reviewed architecture requires another actual source file, establish ownership and keep it within this functional slice. Do not expand into a shared-foundation remake or silently bypass a missing prerequisite.

## Observable Acceptance — Both Native Platforms

1. A real eligible pairing shows the top timer well, both complete owner-grouped public rails, then two large vertical players; You is always above Opponent. Every supplied earned public badge remains accessible above the players, including the all-badges case. No horizontal comparison appears on a wide Mac.
2. The own preview is device-local and aspect-fit; the opponent shows only a permitted avatar/silhouette plus authoritative state. No body thumbnail, stranger stream, microphone, chat, inferred flag, fake identity, editable local achievement, provisional body score, or UI-bearing judge evidence appears.
3. Before authorization, the timer shows a dash with a truthful instruction. Opponent-ready-first does not mark own Ready or start a local countdown. Own Sending Ready stays distinct from confirmed Ready; Not ready is available before Go.
4. Both confirmed Ready states wait for service authorization. The actual shared three-second schedule drives visible beats. A late schedule delivery or return uses real remaining time and does not reset to three. Missing Go cannot become Go because the local display elapsed.
5. A real Go routes once to the actual capture stage with the original match/deadline and no automatic still or second camera/charge. A restored later/final stage does not replay readiness.
6. Confirmed pre-Go Cancel and Block have no Elo, consumed allowance, or fictitious started history row. Pending acknowledgement is visible. A late-Go race never converts the prior request into a forfeit; after-Go block protects but does not leave, rerate, or manufacture no-contest.
7. Camera loss/stop, consent invalidation, sign-out, details/safety reading, or inactivity immediately inhibits local start and protects the preview. Resume checks actual state and requires the appropriate explicit action. Service deadlines and original retake/allowance state do not reset.
8. Unavailable/unknown/stale identity, badges, camera, readiness mutation, start, cancellation, block, and service state use the specific truthful states and recover through real owned actions. Client timeout does not invent no-contest, cancellation, receipt, or refund. No automatic requeue or mock fallback exists.
9. On iPhone, short/narrow/landscape and maximum text reflow while timer, safe actions, complete rails, and large scrolling players remain usable. Back/dismissal follows current pre-/post-Go authority, and privacy covers the app switcher.
10. On native Mac, the minimum 800-by-600 window, short laptop window, full screen, large/external display, and live resizing preserve vertical players, reachable timer/actions, aspect fit, focus, and same match. Native toolbar/sheets/inspector/titlebar remain native, existing commands are intact, and secondary windows cannot acquire another camera/session.
11. Real Mac TCC denial/restriction and external/Continuity disconnect have working, accurate recovery routes without stale footage, file-picker substitutes, or deadline reset. Close/quit/Escape and Return/Space have the specified semantic/state-aware effects; force quit is not classified as explicit forfeit.
12. VoiceOver/focus, keyboard, Voice Control/Switch Control where available, full text size, contrast, Reduce Motion/Transparency, silent mode, low power/thermal behavior, and inactive/offscreen work preserve the same information/actions. Countdown/motion never gates safety or critical state.

## Focused Native Smoke and Regression Scenarios

Run the actual changed native surface; a build, preview screenshot, mock echo, or source-text assertion is not proof of connected behavior. Use authorized development service accounts and consenting adults for a genuine camera match. Do not seed fake opponents or enter rated public traffic to manufacture a demonstration. Keep focused checks within this slice rather than an exhaustive evidence project.

- **Independent readiness and schedule:** with two real authenticated development participants, enter one pairing. Ready the opponent first, Ready/withdraw/re-ready locally, and observe actual acknowledgement and shared start. Confirm that neither an avatar load nor two UI checkmarks can initiate an unauthorized countdown. Exercise a genuinely delayed schedule/Go acknowledgement using existing supported development fault controls if available; do not add production bypass flags.
- **Boundary races and protection:** observe an accepted pre-Go cancellation and block, then the supported case in which Go is already authoritative when the client exit/block arrives. Observe pending protection, same-match reconciliation, explicit separate forfeit consent, and no second search/charge. Use existing authoritative integration tests for race cases that cannot safely be orchestrated by hand; do not claim unexercised race coverage.
- **Camera and recovery:** stop/resume locally, open/close a real details/safety surface, interrupt the network, background/return, and restore the same match without timer reset. On supported physical hardware, deny/regrant camera permission and unplug/disconnect an external or Continuity camera. Observe immediate frame removal and explicit resume/readiness, not merely an error string.
- **iPhone surface:** launch on an available native iPhone runtime; exercise short portrait, landscape, complete rails, large text, safe actions while scrolling, and app-switch privacy. Use a physical iPhone for proof that needs a real camera/interruption; name missing physical proof explicitly if only a simulator is available.
- **Mac surface:** launch the native macOS target. Resize to 800-by-600, use a short laptop-sized window, enlarge/full-screen, and move across displays when available. Scroll the large panels, open/close the native details inspector, traverse by keyboard, preserve app commands, request Cmd-W/quit/Escape in the relevant states, and inspect a second window's non-owning behavior. Do not report an external-display or Continuity test if that hardware is absent.
- **Accessibility and energy:** with available native tools, inspect VoiceOver reading/focus after readiness, error, detail return, and Go; keyboard activation while typing; largest text; Reduce Motion/Transparency; and status distinction without color or sound. Minimize/background/inactivate the camera-owning surface and observe acquisition/decoration stop. Use supported low-power/thermal inspection/simulation or actual hardware state to observe optional effects removed without deadline changes; do not infer energy behavior from a static screenshot.

Before fixing a discovered bug, reproduce it from the real changed path or a focused authoritative regression. Do not rerun a user-reported failure merely to confirm it. Keep a permanent regression only for a plausible consumer-visible uncertain boundary, such as stale Ready/Go precedence or late cancellation being mistaken for forfeit, using the project's existing test conventions. Do not add wiring, source-text, mock-forwarding, incidental wording/default, or bare not-throw tests. Remove throwaway scripts after their smoke use.

Report only actual exercised build/test/native smoke results, and name missing runtimes, credentials, participants, fault controls, camera hardware, accessibility modes, or display proof precisely. If either platform cannot run, finish reachable work and state that platform's validation limit; do not claim it passed or hide a required prerequisite behind a polished preview.

## Human Verification Handoff — Required

List every implemented feature, sub-feature, meaningful task, and changed file separately. Explain the actual connected behavior and any known unresolved prerequisite/limitation. Ask the user to review the code changes and state which items are ready for human verification. Engineering checks are not human acceptance; never claim the user approved an unreviewed behavior.

Keep implementation tracking only in `CYCLES.md`. DOCKS contains plain-language product behavior, not checkboxes, completion claims, screenshots, logs, device-review records, source recipes, or verification evidence. Update the smallest relevant product context after the user accepts a new behavior, unless the user directly approved that decision before implementation. Do not create a screenshot/recording/evidence package as a substitute for a clear handoff.

## Mandatory Single-Owner Rules

1. Work as one owner. No nested agents, generation calls, unrelated reviews, or hidden delegated work.
2. User direction wins over older docs. Preserve the explicit both-platform, complete-rail, large-vertical-player direction and the shared privacy/service invariants. Do not silently narrow to iPhone, a static preview, or a horizontal desktop layout.
3. Use relevant installed skills and current native documentation; reuse actual reviewed source patterns. Product documents are context, not proof of an implementation or permission to follow a technically wrong recipe.
4. No production mocks, fake peers, placeholder buttons, no-op safety controls, local rated authority, demo fallback, unsupported settings links, leaked secrets, broad new permissions, or reference-face assets. Every displayed action must reach its real owner and error path.
5. Do not edit sibling targets or unrelated app behavior. Preserve unexpected user changes. Shared-contract gaps go to the coordinating owner instead of being patched through an unreviewed parallel architecture.
6. Complete the whole authorized functional slice: connected UI, actual focused native smoke, clear failures fixed, affected callers/contracts updated, implementation tracking, and human-review handoff. Compilation alone is insufficient. Do not generate a testing-only or obvious-fix-only follow-up prompt.
7. For this future implementation session, commit each completed coherent authorized work slice with a clear message and push scoped changes to `origin/main`. No force push, history rewrite, destructive git, secrets, unrelated staging, or claiming publication if push fails. This instruction does not authorize the earlier documentation worker to commit the coordinated batch; its main owner handles integration/publication.
8. Update only the assigned implementation todos in `CYCLES.md` after connected work and a review handoff. Do not mark human approval, sibling completion, or an unavailable foundation as done. No duplicate IDE task system.
9. Do not add unrequested abstractions, retries, telemetry, new screens, file upload, profile redesign, camera architecture, moderation policy, scoring rules, or app-wide platform changes. Genuine prerequisite/contract errors are resolved with the owner, never hidden by a UI special case.
10. No pointless next prompt. Finish small remaining work in the current slice. Create another brief only for a genuinely substantial separately owned implementation scope and only within the user's approved plan; never use it to defer a build, obvious fix, documentation correction, commit, push, or human handoff.

## When You Finish

Report the implemented items and exact changed files, real focused verification on each native platform, any missing proof/prerequisite, and scoped publication result. Ask for code review and human verification without claiming acceptance. State whether another prompt was actually necessary; do not write one solely to end the session.

The current handoff contains a product specification and a future implementation assignment only. It contains no production implementation or runtime verification claim.
