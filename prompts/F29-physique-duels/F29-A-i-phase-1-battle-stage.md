# Phase 1 of F29-A-i — Native Battle Stage

## Required Model and Execution Mode

Assigned implementation worker: **openai-codex/gpt-6-astra:max**. The model is **openai-codex/gpt-6-astra** and the thinking level is **max**. Do not silently substitute a different model or reasoning level. If orchestration cannot honor this assignment, report the exact dispatch limitation before implementation. This assignment is for the native UI engineer, not a change to the service's in-app judging model or judging policy.

This is a future implementation brief created during a documentation-only batch. It does not authorize running implementation, builds, tests, generation, formatting, or Git as part of that earlier documentation batch. Execute it only in a separately authorized implementation session after the prerequisites below are real and reviewed.

## Features Included

- **F29-A-i — Battle stage:** the connected live match composition and capture-stage transitions on native iPhone and native macOS.
- The scoped integration of reviewed F29-F identity rails, F29-G shared components, real capture and match state, and the existing F29-A readiness, waiting, result, safety, and privacy routes.

This is one feature slice, not a new camera subsystem, model integration, badge catalog, desktop shell, report form, or result viewer. List each meaningful implemented behavior separately in the human handoff. Record implementation only in the corresponding CYCLES.md todos; do not mark another owner's foundation complete.

## Context

The user requires an animated, minimal-text sports UI on both iPhone and Mac: real timer first, every public battle badge above two large vertical players, You above Opponent.
The stage uses only local own preview and approved opponent identity/progress before finalization; no body scores or early opponent stills.
This work connects the specified composition to reviewed shared foundations without changing competition, consent, privacy, or existing exercise behavior.

## What You Need to Read First

Read the complete battle-stage product context before editing:

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md
- features/F29-physique-duels/DOCKS.md
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md, including the integrated owner inventory and the adjacent readiness, waiting, result, safety, and privacy contexts it links.
- CYCLES.md, specifically the current F29 dependencies, prerequisite reviews, and F29-A-i implementation work. Do not assume a checked documentation item means production implementation is reviewed.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md, especially Accepted Inputs and Judge Blindness, Comparable Evidence and Attire, Accepted Judgements and Non-Scored Outcomes, and metric meaning.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md, especially Pairing Eligibility and Search, Allowance/Cancellation/Interruption Boundaries, and Authoritative Finality.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md, especially capture consent, display boundaries, report states, blocking before/after Go, and review consequences.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md, especially refusal/withdrawal by stage, camera lifecycle, protected data access, result timing, and operational failure states.
- features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-d-score-counters/DOCKS.md, for the terminal handoff boundary, not permission to implement another result renderer.
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md

Inspect the actual reviewed implementation behind each shared contract and every existing caller this integration changes. Use the owner's exact existing types and files rather than inventing equivalent interfaces from these prose documents. Missing real implementation is a prerequisite problem, not a reason to create a production mock.

Read these existing source anchors for conventions and boundaries:

- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228: near-black palette, surfaces, orange action language, and shared controls.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38: Inter Black/Regular, spacing, readable column, and iPhone action size.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80: public material availability, Reduce Transparency, and existing press spring.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188: nearby action and earned-Elo presentation. Do not copy Dynamic Type clamps, minimum text scaling, or exercise-specific badges.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151: camera HUD context only. Do not copy a provisional score, lead bar, exercise clock, or exercise privacy promise.
- TimeMaster/App/TmaxApp.swift, lines 8–19: native Mac WindowGroup, normal title bar, existing 800×600 minimum.
- TimeMaster/App/TmaxCommands.swift, lines 6–37: preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109: editable cosmetic badge previews are not trusted competitive achievements.
- TimeMaster.xcodeproj/project.pbxproj: actual native iPhone and macOS target membership and current deployment constraints; preserve iOS 16 compatibility and native macOS 14 support without raising targets for a visual effect.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png: inspect the supplied image. Borrow hierarchy and directness, not its side-by-side layout, purple/brown pills, faces, footage, text, or implied publication rights.

Read the relevant installed **swiftui-pro**, **swiftui-animation**, and **apple-hig-reference** skill guidance, especially accessibility, performance, native Mac conventions, and scoped state-driven animation. The coordinating owner already selected **dimillian/swiftui-ui-patterns** through the UI Skills CLI; use that supplied or installed context without repeating unrelated setup. Do not claim a skill was loaded when it was unavailable. Newer-OS examples in a skill do not authorize a deployment-target increase.

Use current Apple sources where platform interpretation is needed:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- https://developer.apple.com/design/human-interface-guidelines/motion

There is no project STYLES.md in the documentation batch's source context. Reuse the app's actual theme and components; do not create a parallel global style document or import a web design system.

DOCKS files are plain-language product context, not proof of working code or mandatory technical recipes. Validate their implementation assumptions against current source, skills, and real service contracts. Never add code, pseudocode, payloads, tests, logs, or implementation evidence to a DOCKS.md.

## What Happened Last Session

The documentation specialist read the shared F29 UI contract, relevant F29-A/B/C/D/E context, the new F29-G ownership map, existing native style and window anchors, the supplied reference image, installed SwiftUI guidance, and the live Apple Mac and Motion chapters. The specialist wrote the battle-stage product specification and this future brief only.

That documentation session did not implement app views, services, assets, animations, or a prototype. It did not run builds, tests, native smoke scenarios, formatters, or Git. The coordinating owner owns integrated documentation validation and publication. No runtime result, model quality, camera support, performance measurement, or human acceptance is established by this brief.

The explicit later user direction supersedes older F29-A language that allowed a balanced two-column Mac comparison. Both native platforms are required, all public badges are above the large vertical pair, and motion is tactile but state-bound. Existing numerical policies remain proposed until approved; do not promote them into measured facts.

## Prerequisites and Review Boundaries

Before production code, establish these from the repository and review record:

1. The real account/session, native navigation, and authorized persistent HTTPS foundation is implemented and human-reviewed for this feature's use.
2. The real Physique service exposes authoritative match identity, Go, stage/deadlines, participant ownership, evidence-version receipts, acceptance, permitted retakes, set locking, finality, rating and allowance consequences, and restoration without a duplicate session.
3. Both native capture paths implement permission/resource state, one camera owner, exact local face obscuring, protected candidate transfer, safe stop/resume, and no unmasked fallback. Physical-camera support cannot be inferred from a preview stub or simulator.
4. Current consent, withdrawal, moderation, report/block protection, and data lifetime are connected. The operator's required service and safety operation are available for any real rated flow.
5. F29-F and the required G components are implemented and human-reviewed, with a single set of timer, panel, atmosphere, Mac shell, and identity mechanisms. Read the integrated contracts, not only this prompt's descriptions.
6. The readiness, waiting/result, safety, and privacy owners expose real routes for the same match. There must be no dead buttons or newly invented destination to cover a missing route.
7. The current approved product settings resolve any service-policy proposal relevant to the connection. The UI does not unilaterally change time limits, attempt accounting, finality, consent, or eligibility.

A missing foundation must be named precisely, with the inspected source/review gap and the responsible prerequisite. Do not substitute a fake peer, local judge, preview-only service, sample rating, no-op callback, or guessed success. Finish any reachable authorized work that does not misrepresent a working feature, but do not call the connected stage complete or mark implementation done without its real dependencies. Do not ask the user for information that repository tools or existing contracts can provide.

No runtime implementation is authorized merely because these documentation files now exist. Human review of prerequisite implementations is mandatory; an automated check or a written interface is not human acceptance.

## Design Decisions to Preserve

### 1. One vertical arena, not a split matchup

Keep the real timer as the top visual anchor, then the complete Your and Opponent badge rails, then the two large panels. You is always above Opponent on iPhone, at the Mac minimum, and in wide/full-screen windows. The rails are above both panels, not individually attached below each player's image. A short window scrolls; it does not shrink players into thumbnails to fit both at once.

The tradeoff is deliberate: simultaneous full-panel visibility is less important than legible evidence and complete public identity. Only timer and safe actions need persistent reachability. The badge wall must not become an unbounded pinned header that crowds out the players.

### 2. Honest visual asymmetry

You contains local preview or exact own reviewed evidence. Opponent contains an authorized public avatar or a neutral silhouette and real stage/accepted-pose count. Equal panel prominence does not justify exposing equal body imagery before permission. No AI score, progress-as-score, simulated rival, live video, chat, or microphone is introduced.

### 3. Review before transfer

Capture is deliberate, with a visible default three-second self-timer and explicit immediate mode. The service start countdown does not take a still automatically. After exposure, show the exact redacted still in the same large upper panel with Not sent and Use pose. Only that explicit selection can transfer that exact candidate under the prior valid consent. A brief automatically disappearing preview is insufficient.

This extra selection action is a privacy and clarity choice, not a separate legal-consent substitute. It does not extend the shared deadline or promise the unmeasured five-second result target.

### 4. Calm, sport-like animation

Use the shared press spring, crisp contained countdown and timer changes, single-slot pose feedback, roughly 300-millisecond stage continuity, and one quiet shared atmosphere. Do not scan or reshape bodies, flash the screen, shake the opponent, imply a winner, or pulse the entire badge wall. Current information, safety, capture stop, and final outcomes cannot wait for choreography.

### 5. Native Mac behavior rather than phone scaling

Preserve real window chrome, toolbars, keyboard focus, close/quit behavior, existing commands, and camera/TCC states. Wider windows may expose an existing guide or secondary-information inspector, never a second player column. The bottom action region uses native Mac density. Live resize preserves state and camera ownership without a rebuild or animation replay.

### 6. Immediate privacy, service-owned consequence

Stop/shield first; reconcile the match separately. Reporting, blocking, withdrawing only counterpart access, going inactive, losing a camera, or force quitting is not an automatically confirmed voluntary forfeit. An explicit Forfeit and leave uses the real service consequence and no-contest precedence. The UI cannot award a win or clear an allowance because a local timer ended.

## What to Build

### A. Connect one stage to the existing authoritative flow

Add the stage at the real readiness-to-countdown/capture boundary. Retain the same authenticated account, match, camera ownership, selected evidence, and routing context through capture, checking, submission, recovery, waiting, and terminal handoff. Use the existing reviewed presentation source and observation patterns; do not mirror them into a second competition state machine.

Keep the Go boundary authoritative. Do not expose capture or charge allowance when a purely visual countdown reaches zero. A cancellation accepted before Go stays a free cancellation; a late cancellation is not rewritten as consent to forfeit. Rejoin or explicit forfeiture requires a fresh, truthful decision when the service confirms Go already occurred.

Handle restoration/loading/error with real state and useful actions. Unknown identity, badge state, accepted count, deadline, receipt, allowance, or outcome must remain unknown rather than being filled with a sample. Unknown avatar data may use the neutral permitted presentation, not a fabricated opponent.

### B. Compose the shared visual components

Use the existing G phase clock, player panels/pose icons, battle atmosphere, native Mac shell, and F identity/badge rail. Do not clone those mechanisms inside the stage. Integrate the G result handoff contract without importing its score renderer into capture.

Build the central scroll order exactly: Your complete rail, Opponent complete rail, large You panel, large Opponent panel. Keep complete owner grouping as rails wrap. Preserve every legitimate public badge, including truthful placed-tier/current-streak presentation; no three-slot cap, +N, clipping, ticker, or hover-only item. Use F's confirmed freshness/removal/correction behavior and do not promote local cosmetic previews into achievements.

Keep labels, pose controls, self-timer cues, statuses, and actions outside evidence framing. Fit images without cropping required anatomy, stretching, visual body enhancement, or player favoritism. The avatar/silhouette is an explicit pre-finalization representation, not a fake captured image.

Use existing theme values, shared materials and public availability fallbacks, typography, measured navigation clearance, and stage readable width. Do not hardcode screen coordinates or increase the minimum Mac window. Do not borrow existing exercise text-size clamps.

### C. Implement the three-pose interaction against the real capture contract

The initial sequence is Front double-biceps, Side physique, Rear double-biceps. Use the shared neutral illustrated guide and one safe instruction for the current pose. Keep the common-region framing and clothing constraints. Do not ask for painful effort, breath-holding, exposure, or an unsafe hurried pose.

The default primary action is Capture · 3s. Reuse the shared timer choice for three seconds or immediate capture. Arming exposes Cancel capture and the distinct local countdown without hiding or replacing the top match clock. At exposure, recheck the reviewed foundation's current eligibility/resource/deadline conditions. Cancellation or failure takes effect immediately; there is no invisible deferred shutter.

If less confirmed time remains than the selected self-timer requires, state the actual limitation and offer only the deliberately selected supported alternative. Do not silently shorten the timer or prolong capture. Cancelled arming is not a captured replacement. The shared foundation owns remaining attempts, not a local stage counter.

After exposure, pause acquisition for privacy-safe preparation and exact redacted review. The original is not briefly displayed as the protected version. Show Not sent, Use pose, and permitted Retake. Only Use pose transfers the exact previewed representation; a different replacement frame requires a fresh selection. Fail closed if masking fails; reject bystanders even if masked. No UI screenshot, original, file-picker image, library image, or recording can substitute for protected evidence.

Separate Selected, Uploading, Checking, Accepted, and Needs retake. Allow deliberate next-pose work while an earlier current candidate is being checked. A late rejection marks its own pose and does not interrupt a safely active different capture merely to animate an error. Use one meaningful announcement and a stable return action.

Retake replaces only the relevant selected version and invalidates old acceptance. Ignore stale check/receipt events through the real foundation's version semantics. Show at most two retakes per pose under the same ninety-second capture period, as currently approved by the shared product contract. Do not reset opportunities on navigation, reconnect, camera change, or a different window. Same-transfer recovery is not a new pose or a provider reroll.

Make Submit poses available only when the three current selections satisfy the actual service submission contract. Explain what prevents submission. Submission pending, received, and uncertain are distinct. Confirmed submission locks the set and stops acquisition immediately. Edits after lock require the service's specific allowed recapture request within the original capture period and before paired judgement.

### D. Connect waiting and terminal transitions without false progress

After own submission, show Poses submitted — You can relax and actual opponent progress. Do not leave the camera acquiring or require someone to hold a pose while waiting. Keep the vertical battle shell if the waiting owner uses it.

Distinguish waiting for opponent, transferring, checking, and judging. The thirty-second judgement deadline starts after both final sets are received, not after the provider starts. The five-second target is unmeasured; it changes slow-status copy only. Use the shared clock's truthful phase representation, never an AI completion countdown or fabricated percentage.

After a local deadline or lost connection, show Awaiting confirmed outcome until the service says otherwise. A valid result finalized on time but delivered to an offline client later remains that result. A late model reply cannot resurrect a service-finalized no-contest.

When safe visual dismissal is permitted, Return to lobby preserves the real pending match; it is not the competitive Forfeit and leave action. Terminal service state hands off immediately to the existing result owner. Do not delay the actual outcome, final accessibility values, safe controls, or navigation for animation.

Do not request, prefetch, decode, or display opponent pose thumbnails before the result owner's intentional View poses action, a valid AI-judged win/loss/draw, moderation, and current permission. There is no opponent gallery for forfeit/no-contest. Retain the ordinary twenty-four-hour media boundary and all revocation/removal rules through the owning components.

### E. Keep safety and consent connected in every state

Make Safety, state-aware Exit, and Stop camera while active independently reachable during capture, processing, upload, and waiting. Busy or disabled Capture/Submit must not disable those safe actions. Wire their real existing routes and consequences; no no-op overflow items.

Stop acquisition and shield private content immediately when a safety/privacy presentation obscures capture, a relevant permission is lost, an account changes, or the owning surface is inactive/minimized/backgrounded. Cancel any armed self-timer before native presentation animation. Full-screen dismissal, Escape, navigation, and view disappearance do not implicitly forfeit.

Before Go, use Cancel match. After Go, explicit Forfeit and leave explains the actual potential Elo/allowance effect and respects service-established safety, invalid-evidence, and unavailable-service no-contest precedence. Pending service acknowledgement is not final success. Do not withhold immediate camera/privacy protection while waiting for it.

Blocking before Go cancels the pair according to the service. Blocking after Go shields locally and excludes future pairing when confirmed, but does not itself leave or rerate the match. Offline block confirmation remains pending; do not claim cross-device protection that has not happened. Report submission is not synonymous with immediate local hiding or a final misconduct finding.

Keep distinct processing withdrawal and paired-viewing withdrawal consequences from F29-E. Processing withdrawal stops affected capture/transfers; already accepted processor work may not be retractable. Withdrawing counterpart viewing after Go is not itself a forfeit, cancellation, or automatic rating reversal. Read recipients, retention, and consequences through the full owned route rather than concealing them to keep copy short.

### F. Implement adaptive iPhone and native Mac behavior

On iPhone, use a safe-area-aware top timer and safe-action region, scrolling stage, and persistent primary-action region. Respect the existing navigation placement and measured clearances. Support short/landscape screens, largest Dynamic Type, silent mode, VoiceOver, Voice Control, Switch Control, and external keyboard without shrinking the player pair or losing controls.

On Mac, use the reviewed G shell with native title bar/toolbars, ordinary native sheets/popovers, and optional existing secondary inspector. Support 800×600, laptop sizes, wide/full screen, external displays, live resize, and short-window scrolling. The player pair remains vertical in all of them. Do not implement a Catalyst or embedded web branch.

Keep selected evidence, focus, panel ownership, camera orientation, scroll anchor, and deadlines stable across resize and badge wrapping. Do not rebuild the camera or decode evidence on every geometry update. No automatic stage scroll on an opponent tick or asynchronous badge update. Deliberate capture/pose selection may bring its relevant panel into view.

When the active camera panel becomes entirely offscreen, cancel an armed exposure and pause through the shared camera lifecycle. Show Return to camera; returning requires explicit Resume camera after reconciliation. A partially visible panel or an ordinary layout update must not cause resource thrashing. A native inspector that leaves capture visible does not masquerade as a hidden modal camera session.

Handle TCC denial/restriction, missing/busy hardware, external camera removal, and Continuity disconnection with accurate copy and useful Settings/Retry/Resume actions. No silent device change after Go. A deliberate post-Go camera change warns that the selected set must be discarded and redone within remaining time and opportunities. Do not reset deadline/retakes or imply guaranteed recovery when the shared continuity rules make it impossible.

Use the single reviewed camera owner across windows and devices. Secondary windows show authorized status and an existing route to the owner, not a second acquisition, countdown, queue, or charge. Transfer ownership only through the established explicit contract.

Preserve existing Mac commands. Return/Space activate only the focused semantic control, never a global Capture while typing. Escape first cancels the armed self-timer or handles the top sheet/draft safely; at the stage it invokes the state-aware exit. Cmd-W and normal quit use the shared confirmation where supported. Closing a non-owning status window does not end the match. Force quit is unconfirmable and must not become a fabricated voluntary forfeit.

### G. Wire focus, accessibility, animation, and energy behavior

Use semantic buttons and stable Voice Control action names. Keep the owner-grouped reading order through wrap/scroll. Entering a phase or deliberate pose selection moves focus to its heading; acceptance updates should not continually steal focus. Restore the invoking control after sheets. Announce critical errors, phase transitions, meaningful timer milestones, and finality once, not every tick or interpolated number.

Color is supplementary: distinct text/symbols identify checking, acceptance, missing data, rejection, submission, and stale state. All flags have readable region names and missing/unsupported states. Accessibility descriptions of hidden or rejected media must not expose the content being protected. Use sufficient contrast and shared opaque fallbacks under Reduce Transparency.

Coordinate the specified shared motion: existing press spring; small state/pose feedback about 140–200 ms; stage continuity about 260–320 ms; countdown scale no greater than about 1.08 settling within 220 ms; stable timer digit update about 180 ms; one quiet roughly twelve-second background loop. Scope animations to the actual changed component.

Do not add stage continuity as a serial delay before the result owner's reveal. All result choreography remains within the shared total of 900 ms, with immediate final meaning and no repeat award on history, reopen, reconnect, or window change. The stage never animates an appearance score before finality.

Reduce Motion means static replacement or short opacity, no scale/travel/ambient loop. Low power or thermal pressure suppresses decorative work. Offscreen, inactive, minimized, locked, and backgrounded surfaces stop decoration; the camera stops according to privacy, not animation completion. On return, show the latest stage without replaying missed events. At most one ambient layer and one focal event may run; countdown takes precedence.

No per-frame file/network/provider work, evidence decoding, font measurement, camera re-creation, or global layout invalidation. Timer ticks must not rebuild the camera or all badge rails. Reuse shared behavior instead of wrapping every native control in a new abstraction.

## Prospective Files to Create or Modify

Use existing integrated names if a real battle-stage file already exists; do not create a duplicate for the sake of this proposed filename.

- **Create or complete:** TimeMaster/Views/Physique/PhysiqueBattleStageView.swift — the composition and stage-owned interaction connection described here.
- **Modify only the necessary existing F29-A flow integration file or files:** resolve their exact paths from the reviewed source before editing; connect readiness to this stage and this stage to the existing waiting/result/safety/privacy routes. This prompt does not invent an unimplemented router name.
- **Modify only if required for actual native membership:** TimeMaster.xcodeproj/project.pbxproj — register the owned implementation for both native targets without target raises or unrelated project-file churn.
- **Update:** CYCLES.md — only authorized F29-A-i implementation items and honest handoff status, after connected work and focused checks. Leave missing or unexercised requirements pending.
- **Update after user acceptance:** features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md — only accepted plain-language behavior. Do not place test results or implementation evidence there.

F29-F, G component internals, camera/transport foundations, rating policy, provider/model configuration, and other views remain separately owned. A genuine contract defect must be reported and resolved with that ownership rather than patched by a second local mechanism. Do not edit unrelated Profile shape, navigation order, exercise ratings/quotas/privacy, workout tracking, or app-wide styling.

A small source decomposition is acceptable only when it follows the current architecture and has real stage ownership. Do not create redundant global stores, retry engines, camera managers, clocks, badge registries, framework wrappers, or placeholder screens.

## Observable Acceptance — Both Platforms

These are prospective observations required of the implementation, not claims from the documentation session.

| Scenario | Required observable result |
| --- | --- |
| Normal real paired capture on iPhone | Top authoritative timer, every public badge grouped above both panels, large You above large Opponent, one clear current instruction/action, reachable Safety/Exit/Stop |
| Normal capture on native Mac | Same hierarchy in a true Mac window, native toolbar/focus/control behavior, no web or Catalyst fallback, no second player column |
| All earned badges, placed tier, actual streak, long handles, missing/unsupported region | Every authorized badge remains represented; rails wrap; owner association and region meaning stay clear; no fabricated verification or local cosmetic import |
| Largest iPhone text and short/landscape display | Central scrolling preserves large participants and complete badge labels; timer and safe actions remain reachable; no text-size clamp or shrinking-to-fit shortcut |
| Mac at 800×600, short laptop window, wide/full screen, external display | Vertical player order and complete rails survive; inspector is secondary; safe controls remain usable; no minimum-size increase |
| Mac live resize and badge reflow | No changed selected pose, restarted camera, jumped deadline, swapped player, lost focus, or replayed animation |
| Start countdown and local self-timer | Two visibly distinct meanings; neither visual zero nor local timer invents Go; Cancel capture cancels only an armed exposure |
| Exposure near the capture deadline | No silent timer shortening or late exposure; immediate mode only by deliberate choice when valid; no extended capture period |
| Exact preview before Use pose | The person can inspect the actual masked candidate while Not sent is true; no early transfer, unmasked flash, or UI-screenshot upload |
| Redaction failure, bystander, poor framing, unsafe/ambiguous capture | Fail-closed privacy and useful private recovery; no unmasked fallback, body score, public accusation, or automatic local loss |
| Asynchronous checking and retakes | Selected/Checking/Accepted differ; old acceptance cannot approve a replacement; real retake limit and original deadline persist |
| Submission retry/uncertain receipt | One current selected set, one match, one charge; uncertainty remains visible until confirmed; no duplicate submit effect |
| Own submission while opponent is still working | Camera stops, person may relax, opponent shows only actual permitted avatar/stage/count; no prematurely started model countdown |
| Service judging or slow processing | Actual stage, no fake analysis percent, confidence gauge, body-fat/muscle measure, provisional body score, or streamed winner |
| Local deadline while service unavailable | Awaiting confirmed outcome rather than invented no-contest or rating/allowance update |
| Final result delivered after an offline interval | Same real outcome; no local timeout overwrite, duplicated Elo effect, or replayed original award |
| Forfeit, no-contest, blocked or withdrawn media | Correct terminal owner and current protection; no pose gallery for forfeit/no-contest and no stale-link/cache reveal |
| Safety form, block/report, consent withdrawal | Immediate appropriate protection, current actual match consequence, no forfeiture inferred from opening help or only withdrawing paired access |
| Inactive/minimized/background/lock and return | Acquisition and decoration stop/shield immediately; deadlines continue; same-match reconciliation precedes explicit camera resume |
| TCC denied/restricted, external/Continuity camera loss | Useful real recovery; no fake feed, automatic alternate device, file-picker rated fallback, reset deadline, or extra allowance |
| Multiple native windows/devices | Single account match and camera owner; secondary surface does not acquire, requeue, or charge again |
| Keyboard and assistive technology | Every action reachable and named; visible focus; state-aware Escape; Return/Space do not capture while typing; reserved shortcuts preserved |
| Reduce Motion/Transparency and energy pressure | Equivalent readable state and actions, immediate privacy, no decorative replay or unnecessary continuous offscreen work |
| Existing exercise/profile/navigation use | No change to exercise image privacy, ratings/quotas, saved page ordering, Profile's two-side shape, or existing command meaning |

No acceptance can be satisfied with screenshots of a static prototype, a compiling scaffold, a mocked production opponent, disabled unimplemented controls, or claims of checks that were not run.

## Focused Native Smoke and Verification

Run the changed native surface, not only a test target. Use an authorized real development/staging service and appropriately consented adult test participants. Keep images and private account data out of logs and proof artifacts. Preview-only fixtures must be clearly labeled and must never select a production fallback.

Perform the smallest relevant build/typecheck and existing focused contract checks after connecting the path. Update broken consumer contracts where this integration actually changes them. Permanent tests should cover plausible user-visible defects such as privacy gating, stale-version rejection, cancel/Go race, exactly-once submit, or focus/exit consequences when that behavior is owned here and uncertain. Do not add tests for source text, copied constants, wiring-only mocks, or incidental animation values. No blanket snapshot suite or exhaustive proof package is required.

Then exercise these focused actual scenarios:

1. **iPhone real capture:** enter a real paired session, observe the start, capture each named pose with the self-timer, inspect the exact redacted still before Use pose, make one permitted retake, submit, and observe the real waiting/result handoff. Confirm all live opponent presentation remains avatar/progress-only.
2. **Native Mac real capture:** repeat the connected path in the native target with actual available hardware. Resize through 800×600 and a wide/full-screen state; inspect both full badge groups and the vertical panels; navigate every relevant action by keyboard. Observe that resize does not reacquire the camera or reset the stage.
3. **Capture interruption and privacy:** arm then cancel the timer; obscure capture with safety; fully scroll the active camera out of view; deactivate/minimize/lock or background; return and deliberately resume. Confirm no delayed shutter, background acquisition, hidden live feed, deadline reset, or duplicate charge.
4. **Mac resources and windows:** exercise available permission-denied/busy/disconnect paths, including external or Continuity camera loss when that hardware exists. Open a second window and verify no second owner. Exercise normal close/quit confirmation and restoration; do not equate force termination with an explicit forfeit.
5. **Receipt/finality boundary:** use the real authorized service's supported test or controlled interruption path to observe an uncertain upload/submit or late-delivered result. Verify that the UI reconciles the existing match and selected version instead of inventing success, a score, or timeout finality. Do not add a production failure simulator.
6. **Accessibility and energy:** run the stage with the largest available text, VoiceOver, keyboard focus, Reduce Motion, and Reduce Transparency. Inspect warning/phase announcements rather than every tick. Exercise available low-power/thermal handling and offscreen/inactive lifecycle; verify decorative work stops and essential state stays correct. Do not claim measured thermal performance from code inspection.

Use existing scenario tooling where available; otherwise use a throwaway smoke exercise rather than permanent test scaffolding. Remove throwaway code when finished. Do not generate assets, create a benchmark subsystem, or expand into unrelated feature work to obtain a green report.

If a runtime, physical device, consenting second participant, external camera, credential, or service prerequisite is unavailable, name exactly what could and could not be exercised. Simulator layout is not physical-camera proof. A Mac build is not evidence that its TCC/disconnect path worked. Unavailable evidence remains an explicit limit and cannot be marked complete or described as human verified. Finish all reachable authorized work and do not fabricate an end-to-end result.

## Human Verification Handoff — Required

List each implemented feature/task and changed file separately. At minimum distinguish:

- Native iPhone composition and complete rails.
- Native Mac composition, sizing, toolbar/input behavior, camera/window lifecycle.
- Guided capture, self-timer, exact review-before-transfer, retakes, and locked submission.
- Real waiting/finality handoff with no provisional scores or early opponent stills.
- Safety/exit/withdrawal and same-match recovery behavior.
- Accessibility, focus, motion, reduced/energy behavior.
- Existing flow/target integration and any focused contract-test changes.

State only checks and native scenarios actually exercised, with their observed result and any hardware/service/accessibility limits. Ask the user to review the changed code and verify each ready item. Do not claim human approval, completed physical-camera coverage from a simulator, or completion based only on compiling.

Keep implementation tracking in CYCLES.md. DOCKS remains plain-language product context, not a checklist, test log, screenshot collection, or proof package. After the user accepts resulting behavior, update the smallest relevant product context with that accepted decision. Do not rewrite shared product documentation to make an unfinished path look complete.

## Agent Rules — Mandatory

1. **One owner; no nested agents.** Perform this implementation yourself. Do not spawn reviewers or delegate overlapping changes to other workers.
2. **Real connected behavior.** Use real reviewed foundations and service authority. No placeholder screens, fake peers/scores/badges, production fixtures, stub buttons, no-op callbacks, local competitive verdicts, or silent provider/model substitutions.
3. **Respect ownership.** Compose shared F/G mechanisms and adjacent owned routes. No parallel global theme, timer, capture manager, badge registry, desktop shell, or result renderer. No unrelated app changes.
4. **Research before editing.** Read current source, dependencies, relevant skills, and service contracts. Reuse existing patterns and public APIs; preserve iPhone/native Mac deployment compatibility. An old document's technical direction is not an unexamined implementation mandate.
5. **Preserve privacy and finality.** Exact local redaction before every transmitted candidate; no bystander exception; no early counterpart imagery; current authorization for media; service-owned deadlines/outcomes/allowance and versioned evidence.
6. **User direction wins.** Both platforms, every badge above large vertical players, real top timer, animated minimal-text sports presentation. Do not silently revert to side-by-side Mac players or discard disclosure/recovery/accessibility detail to save space.
7. **Focused checks and actual smoke.** Exercise the changed native surface on both platforms where runtime exists, resolve clear failures, and name missing physical-camera proof honestly. Tests alone and static previews are insufficient.
8. **Update only authorized implementation todos.** CYCLES.md is the project tracker. Mark items implemented only after the connected work and relevant checks are complete and a clear human-review handoff is supplied. Keep genuine remaining work pending; no IDE task JSON or second tracker.
9. **No evidence in DOCKS.** Product context contains no code, pseudocode, payloads, project checkboxes, screenshots, test outputs, logs, or implementation claims. Capture accepted product behavior only after user review, unless directly approved beforehand.
10. **Scoped commit and push in the authorized implementation session.** Commit complete owned work slices with clear messages and push to origin/main without force-push or history rewriting. Do not include another worker's or the user's unrelated changes. Report the exact blocker if publication is unavailable; do not claim published work that was not pushed. This rule does not retroactively authorize Git in the earlier documentation-only batch.
11. **Complete the functional slice.** Do not stop at a compileable shell or create a testing-only handoff. Fix clear in-scope failures, update affected callers/contracts, provide the honest human review list, and publish the authorized slice.
12. **No pointless next prompt.** Create another prompt only for genuinely substantial separate implementation work with explicit ownership. Do not defer small fixes, focused verification, docs/status, commit, or push into a new session. Do not invent unrelated future scope.

## When You Finish

Report every implemented item and changed file separately, exercised verification, remaining real limitations, and the scoped commit/push result. Ask for code and behavior review; identify which items are ready for human verification without claiming approval. State whether a next prompt was actually necessary.

## Scope Decision Before Finish

- **Implemented and exercised:** enumerate only connected behavior and observed checks.
- **Remaining:** enumerate actual missing behavior or unavailable proof, not speculative enhancements.
- **Prerequisite or dispatch limits:** identify the precise missing reviewed foundation, runtime/hardware/service access, or assigned-model limitation, if any.
- **Decision:** complete the remaining small owned work now; create a substantial owned follow-on only when genuinely required; otherwise no next prompt.
