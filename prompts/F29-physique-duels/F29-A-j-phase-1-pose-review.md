# Phase 1 of F29-A-j — Native Pose Review and Retake

## Assignment and execution boundary

Required worker model: **openai-codex/gpt-6.1-sol:max**. Model is **openai-codex/gpt-6.1-sol**; thinking level is **max**. Do not silently substitute a model or lower the thinking level. If this exact assignment is unavailable, report the dispatch limitation to the main owner before implementation. This is the UI implementation worker assignment, not a change to the in-app ranked judge or a different judge tier.

This is a future implementation brief. The coordinated design batch is documentation-only; do not execute code work, build, test, format, stage, commit, or push merely because this prompt has been created. Its later execution requires explicit implementation authorization and the real reviewed prerequisites below. During the design batch, the main owner integrates and publishes documentation.

## Features Included

- **F29-A-j — Pose review and retake:** the exact selected masked still, distinct Selected/Checking/Accepted/Needs retake states, per-pose replacement budget, invalidation of an old acceptance, deadline-preserving recovery, and native iPhone/macOS presentation inside the active battle.

Implement and hand off this item separately for human verification. Do not implement another lobby, pose guide, final gallery, badge catalog, match service, or result screen as a substitute for this slice.

## Context

Review is an in-place mode of the large You panel in an active battle, not a new modal screen or image editor.
The real top timer, all public badge rails, and two large vertically stacked players remain the battle hierarchy on iPhone and native Mac.
A newly acquired replacement loses the old acceptance; no review action extends capture time or provides body-scoring feedback.

## What You Need to Read First

Read the current integrated files before editing; paths below are repository-relative unless they name an installed skill or a public reference.

### Product and review boundaries

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-j-pose-review/DOCKS.md` — complete owned product specification, including the actual state matrix and platform-specific behavior.
- `features/F29-physique-duels/DOCKS.md` — shared lifecycle, consent, vertical battle composition, safety, and service authority.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — live capture owner, pose order/guide, three slots, final-set lock, lifecycle, exit, and navigation.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — accepted inputs, judge blindness, adequacy versus scoring, permitted evidence, and fixed judging version.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — one active match, service-owned timing, budget/allowance, exactly-once finality, forfeit/no-contest precedence.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — face treatment, bystanders, contextual attire checks, private correction/review, safety and block consequences.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — exact redacted preview, recipients, no fail-open uploads, lifecycle, withdrawal, media expiry, receipt uncertainty.
- `features/DOCKS.md` and the current F29 entries in `CYCLES.md` — dependency ownership and actual human-review boundaries. An implementation checkbox is not evidence of human acceptance.
- The integrated F29-F identity/badge and shared battle/capture documents linked from the current F29 parent. Consume their controls and ordering; do not invent another badge system or guess a sibling's filename.

DOCKS is plain-language product context, not an implementation recipe or proof that a backend exists. Follow the user's latest approved direction over older parent suggestions. In particular, the earlier small-thumbnail review and optional two-column desktop battle do not override this large in-place review and vertical players. Do not copy obsolete fade-only motion as an excuse to omit the specified tactile state feedback.

### Exact existing source anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing 0A0A0A background, 141414/1C1C1C surfaces, FF6A00 actions, shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter Black/Regular helpers, spacing, readable width, and touch-target conventions.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — native public material availability, opaque Reduce Transparency fallback, and press response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — nearby native actions and earned-Elo visual language. Do not import its Dynamic Type clamp, local-level assumptions, or exercise-specific meanings.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise camera/HUD context, not a source of provisional physique points, a lead bar, or a local winner.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, 800 by 600 minimum, normal title bar.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O and normal text editing.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local badge previews are not trusted achievements, placement, or identity verification.
- `TimeMaster.xcodeproj/project.pbxproj` — inspect actual target membership and deployment settings before choosing APIs. Keep native macOS 14 and existing iPhone compatibility, including the project's iOS 16-compatible boundaries; do not raise targets for this view.
- The real integrated battle/capture view and Physique services/models discovered under `TimeMaster/Views/Physique/`, `TimeMaster/Services/Physique/`, and `TimeMaster/Models/PhysiqueDuelModels.swift` once those foundations exist. These are prospective integration locations, not claims that implementation was present in the design batch.

`STYLES.md` was absent in the design context. Use existing source conventions; do not create a global style document or parallel theme.

### Skills and visual/native references

- Read `skill://swiftui-pro`, particularly its accessibility and performance references; `skill://swiftui-animation`; and `skill://apple-hig-reference` selectively for the changed surface.
- The main owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selection, not another setup/install pass. Its public source is `https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns`; asynchronous state ownership is the relevant pattern. Preserve current deployment compatibility rather than blindly adopting iOS 26-only examples.
- Inspect `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png`. Borrow the dominant timer and direct sports hierarchy only. Do not reproduce its left/right arrangement, web pills, text, people's likenesses, footage, or unproven asset rights. Do not generate art for this slice.
- Read current Apple HIG `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` and `https://developer.apple.com/design/human-interface-guidelines/motion` for native window/input and purposeful optional motion. The exact composition and timings are product choices, not Apple-prescribed measurements.

## What Happened Last Session

The documentation batch specified the exact masked still as a large in-place review, an explicit Check pose transfer gate, honest current-candidate status, two replacements per pose, and native iPhone/Mac behavior. This assigned task produced product context and this future brief only. It did not implement a view, change a service, generate assets, run an app, or establish human acceptance of code or judging quality. Earlier F29 numerical defaults remain proposals under their own review boundaries.

## Prerequisites and review boundaries

Do not start a disconnected production view. Before implementation, confirm the following in actual code and the main owner's reviewed foundation handoff:

1. A real account/session, adult/attire eligibility, separately recorded current processing and opponent-sharing choices, and authorized protected service exist. Operational moderation and approved judging access are not implied by an account server.
2. One native capture owner provides the live guide, selected still, exact local face obscuring, consistent evidence orientation, privacy cover, and actual camera lifecycle on both platforms. Every candidate must fail closed if masking cannot complete.
3. The trusted evidence contract identifies the current selected candidate independently from superseded candidates and poses. It distinguishes transfer receipt, actual checking, acceptance, and rejection. The service, not a view-local Boolean, controls acceptance.
4. The real contract preserves at most two replacements per pose, invalidates old acceptance on actual replacement, handles an uncertain acquisition/receipt without granting free attempts, and rejects stale responses. Multiple windows/devices cannot obtain independent replacement budgets.
5. The real shared deadline, reconnect recovery, set-lock/submission, finality, allowance, safety, and privacy consequences are available. This component must consume those facts, not create another timer or competition state machine.
6. The shared native battle shell already presents the real top timer, complete owner-grouped public badge rails, and large vertical You/Opponent panels. F29-F supplies trusted identity/badges and optional self-declared country; local cosmetic previews are not a substitute.
7. Parent capture/final-set and safety/privacy navigation are implemented and handed to the human at their defined dependency boundaries. A page preview, a mock service, or a passing build is not that review.

If a prerequisite is genuinely missing, identify the exact missing contract or external requirement to the main owner. Finish reachable authorized integration work, but do not label a static view, local fake acceptance, demo opponent, no-op button, or test fixture as the rated feature. Do not manufacture a second backend or expand into another worker's foundation to hide the gap.

## Concrete design decisions

- **In-place freeze-and-seat:** keep the selected evidence frame stationary and seat a short status/action shelf below it. Large aspect-fit evidence makes mask/framing inspectable without a new modal or body cropping. Short windows scroll instead of shrinking people.
- **Deliberate sharing gate:** once the exact local masked preview exists, Selected/Not sent exposes Check pose. That action sends this candidate for protected eligibility/safety/evidence checks under existing consent. It is not final submission, not an in-app model switch, and not a request for a body score.
- **No old/new chooser:** Retake opens the existing same-pose live guide. Cancelling before a new still preserves the old choice; acquiring a replacement spends a replacement and invalidates previous acceptance. Even a failed mask/check does not make the old accepted image selectable again.
- **Truth before celebration:** current-candidate acceptance gets one small checkmark settle. No body glow, scan, provisional score, fake confidence, anatomy commentary, comparative tip, or opponent still helps cherry-picking.
- **Native Mac, same vertical sport:** a normal resizable Mac window, native toolbar/sheets, keyboard/pointer focus, and centered readable stage are not a stretched phone. Wider windows never put participants side by side. Optional details remain inline/native; no new custom inspector is needed for review.

## What to Build

### 1. The in-place review surface

Integrate a focused pose-review view into the actual You player panel. Preserve the hierarchy: real timer first; all owner-grouped identity/badge rails next; two large portrait panels, You above Opponent; safe controls remain reachable while the stage scrolls. No labels or controls cover evidence. Use existing theme/type/spacing/readable-column and shared native button treatment. Keep every earned public badge available by wrapping, with no hidden extra-count control or automatic ticker.

Review has one clear heading, full current pose name, three real pose-slot controls, the exact masked image aspect-fit on a neutral matte, and a status shelf below it. The shelf contains the status word/symbol, one practical instruction or private reason, actual remaining retakes, and Masked preview treatment. Compact public identity is not baked into or screenshot-uploaded with the still. The Opponent panel shows only an authorized avatar/silhouette and real stage/count, never early body media.

### 2. Exact privacy preview and honest status

Show a safe preparation placeholder until the exact selected redacted representation exists. Never flash an unmasked frozen original as a placeholder. Stop camera acquisition while reviewing; say Camera off only when actual ownership reports that state. Resume live capture only through the existing explicit guide action.

Implement the distinctions in the product state matrix, including operational overlays:

- Selected/Not sent: Check pose is available only for a current eligible masked candidate with current consent and time.
- Selected/transferring: show actual Sending/progress or receipt uncertainty, not Checking/Accepted based on a tap or elapsed animation.
- Checking: genuine service checking, with native indeterminate activity and no percentage, predicted time, score, or finality claim.
- Accepted: only the current candidate passed the required checks. A checkmark is not identity verification, final-set locking, opponent-view permission, or a competitive verdict.
- Needs retake: pose-specific safe reason or a privacy placeholder, remaining real opportunity, and the appropriate existing correction/review route.

Name actual disclosed transfer recipients before Check pose and keep Privacy and sharing reachable. Do not invent operator names or replace meaningful consent/retention consequences with a tiny icon. Selecting another slot must not silently transmit an unsent image.

### 3. Retake budget and replacement correctness

Initial capture plus at most two replacements per pose. Show 2 retakes left, 1 retake left, or No retakes left only from confirmed authoritative state. If reconciliation is pending, say so and do not offer another acquisition on an assumed budget.

Retake opens the same-pose guide with the concise replacement consequence. Opening/cancelling the guide or cancelling a self-timer does not itself spend an attempt or discard the old still. A successfully acquired replacement spends one permitted replacement even if later masking, transfer, or checking fails. A failure that acquired no image spends none. Uncertain acquisition/receipt blocks duplicate acquisition until reconciled.

On actual replacement, remove old acceptance and update the accepted count immediately; the new current candidate begins unaccepted. Keep submission unavailable while replacement authority is unsettled. A superseded candidate's later acceptance cannot approve the replacement or repopulate an old image. A result for another pose cannot update the open pose just because it occupies the same list position. Do not store old attempts as a selectable gallery or add an undo-to-accepted action. Follow F29-E disposal and any actual lawful case exception rather than promising immediate global erasure of a candidate already received remotely.

### 4. Contextual actions and real parent integration

Use Check pose before transfer; Next pose when another required pose can be captured; Retake as primary for a recoverable current rejection; and the existing Submit poses only when current complete evidence and real shared eligibility permit locking. Next pose returns to the existing guide, not an extra screen. Allow another pose to be captured while a prior selection is actually transferring/checking.

When all three are selected but some are unsent or pending, keep selected and accepted counts distinct and do not enable Submit from selection count alone. Show an honest waiting state when no useful next action exists instead of a fake Continue. A retry after a genuine transport failure reuses the same candidate and match, does not consume another retake, and follows the existing service retry behavior; do not add an unrelated retry framework.

A confirmed final-set lock prevents voluntary editing. Unknown submission receipt does not unlock the set. Only the existing service-requested specific recoverable recapture can reopen the relevant slot before paired judgement, still inside the original deadline and remaining budget. No review action creates a new allowance charge, judgement, or match.

### 5. Complete correction and recovery

Connect actual mask failure, bystander/coverage/framing/lighting inadequacy, ambiguous safety rejection, false-positive review entry, transfer failure, unavailable checking, late rejection of another slot, exhausted replacements, and deadline expiry. Give neutral private correction, never a humiliating anatomical crop or a request to expose prohibited coverage. Ambiguous permitted attire is not proof of misconduct, age, sex, or gender. False-positive review uses existing protected references, not an unmasked proof photo, and does not pause capture or accept evidence.

An accepted final attempt with no replacements can continue. An invalid exhausted attempt resolves through the service's no-contest path, not a local loss, free win, or automatic forfeiture. While finality/allowance restoration is unconfirmed, label it unconfirmed. At the capture deadline, stop new acquisition/replacement and let the parent route the actual same-match stage; no locally invented outcome or late restart.

Keep the real clock live during review, native sheets, masking/checking, network recovery, and review requests. Twenty-second reconnect grace extends no deadline and restores no retakes. Offline or relaunch recovery reconciles current account, match, candidate, actual budget, stage, and set-lock state before enabling action. Late completion cannot reopen a finalized no-contest or rate twice.

Stop/shield immediately on lifecycle/privacy changes. Sign-out/account change clears prior private presentation. Processing withdrawal stops affected new capture/transfers and follows the actual stage consequence. Opponent-image sharing withdrawal alone is not an automatic forfeit. Report/Block after Go protects immediately but is not a leave action or rerating rule. Use the existing explicit state-aware exit confirmation, with invalid/safety/service-failed no-contest precedence over an otherwise eligible forfeit.

### 6. Both platform compositions and input paths

**iPhone:** timer in the top safe region; wrapping rails and large vertical players in the scrolling stage; contextual primary/secondary actions reachable in the lower safe action region, with Exit/Safety reachable. Use measured navigation clearance and existing forty-four-point action areas. Largest Dynamic Type, short height, and landscape wrap/scroll rather than clamp, clip, overlap, or miniaturize evidence. Do not duplicate the same action as multiple accessibility targets. Swiping, outside taps, and image gestures cannot abandon a battle or recover discarded attempts.

**Native macOS 14+:** preserve the existing normal title bar and 800 by 600 minimum. At minimum/short laptop height, scroll the large stage with timer/actions reachable. At laptop/large/full-screen/external-display sizes, center the same vertical readable column; never side-by-side players. Use native toolbar/sheet/popover and pointer/focus conventions; core status/rejection/budget remains visible inline, never hover-only or inspector-only. Live resize/display movement preserves reviewed candidate, service state, focus, scroll anchor, and image aspect ratio without capture/check restart.

Distinguish Mac TCC denial/restriction, missing/busy camera, external-camera loss, and Continuity disconnect. Already eligible masked evidence can remain reviewable under authorization; camera failure blocks new acquisition, not automatically every existing evidence action. Do not keep a camera running just to submit a completed set. Use the existing recovery owner, no automatic camera substitution. Camera changes after Go obey the parent's discard-set and unchanged-budget/time rules. No rated file-picker or prerecorded alternative.

Only one owning window/device may replace evidence. Secondary windows restore/status the same match without a new camera owner, charge, or budget. Return/Space activate the focused semantic control only. Preserve existing Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O and text editing. Escape closes the current sheet/popover, cancels an unexposed retake/timer, or opens root review's real exit confirmation; it never confirms forfeit. Cmd-W/Quit confirm real active-match consequences where permitted. Force quit cannot be intercepted or classified as explicit voluntary forfeit. Inactive/minimized/hidden/background windows shield media and stop acquisition immediately; return requires real-state reconciliation and explicit camera resume, not a reset.

### 7. Motion, focus, accessibility, and energy

Implement the chosen restrained tactile treatment with deployment-compatible APIs and shared controls:

- Safe preview: stationary evidence frame; reveal from the privacy matte in 160 milliseconds; shelf seats beneath the frame in 280 milliseconds with short movement bounded by existing spacing.
- Button press: existing spring response 0.24 seconds/damping 0.88. Do not build a second global motion system.
- Actual status change: 180-millisecond symbol/text update. Factual eligibility changes immediately, not after the animation completes.
- Current candidate acceptance: one checkmark settle at most about 1.04 scale, done within 180 milliseconds. No replay on re-entry and no badge/win celebration.
- Pose inspection: 180-millisecond active-slot marker, 160-millisecond safe-image replacement in the same frame; no rotating attempt carousel.
- Retake-guide continuity: at most 280 milliseconds; only explicit permitted live-camera resume reveals new live imagery.
- Original timer: stable digits, approximately 180-millisecond update once per actual second, no pulsing urgency or per-tick sound/haptic.
- Checking: native indeterminate activity only. No new ambient loop in review.
- Privacy hide, camera stop, invalidation, access loss, and incoming terminal state: immediate protection; cancel obsolete visual completions and delayed haptics.

Latest real state interrupts prior motion. Never delay a valid action, safety protection, or finality until a transition ends. No body scaling, scanning, flashing, loser shake, or motion suggesting an advantage. Reduce Motion removes travel/scale/repeating decoration, keeping the same information through immediate replacement or at most 120 milliseconds of opacity. Reduce Transparency uses opaque readable surfaces. Low Power Mode/thermal constraint removes decorative settle/travel; offscreen/inactive/background/minimized surfaces do not run decorative loops. Keep camera stopped during review. No per-frame I/O, provider work, image decoding, font measurement, polling, camera reconstruction, or whole-battle layout invalidation from the clock.

Entry focus goes once to current pose/status/remaining retakes. Pose acceptance and private rejection announce meaningful changes once, not every tick or indeterminate rotation. A late rejection names the affected slot without stealing current capture focus. Restore invoking focus after a sheet/cancelled retake; when media becomes unauthorized, focus a safe placeholder/heading. Expose full pose names, status meaning, disabled reason, units, optional region name, badge labels, and stable Voice Control names. Keep semantic reading order and a single accessible instance of anchored actions. Support VoiceOver, full keyboard navigation, Switch Control, Voice Control, large text, contrast settings, silence, and haptics-off. Do not require precise gestures, hover, color, or sound.

## Prospective Files to Create or Modify

These are prospective ownership locations. Discover actual integrated files before touching them and reuse their conventions; do not create an alternative because its name differs.

- **Create:** `TimeMaster/Views/Physique/PhysiquePoseReviewView.swift` — focused in-place review presentation and native platform adaptations; small internal pieces only where they make ownership clearer.
- **Modify narrowly:** the existing connected battle/capture host under `TimeMaster/Views/Physique/` — present the review inside You, route existing pose/retake/check/submit actions, preserve vertical shell and safe controls.
- **Consume, extend only when this slice actually requires it and ownership is approved:** `TimeMaster/Models/PhysiqueDuelModels.swift` and the existing authoritative presentation/capture services under `TimeMaster/Services/Physique/`. Do not implement acceptance, Elo, budgets, finality, or a second camera owner inside a view.
- **Modify only if source membership requires it:** `TimeMaster.xcodeproj/project.pbxproj`, preserving deployment settings and unrelated target membership.
- **Modify focused existing behavior tests only if needed:** use the real discovered service/model test locations for an unprotected stale-candidate, budget, lock, or deadline edge. No source-text assertions or tests that merely echo forwarded mock values.
- **Update after exercised implementation and clear handoff:** the assigned F29-A-j implementation rows in `CYCLES.md`. Do not change another owner's rows or mark human approval.
- **Update product context only after explicit user acceptance of a changed decision:** the smallest relevant existing DOCKS. No logs, screenshots, implementation checklists, or verification claims belong in DOCKS.

Do not modify global theme, profile's two-side shape, exercise privacy, general provider preferences, unrelated commands, other custom views, or another worker's documentation to accommodate a shortcut.

## Observable Acceptance — Both Native Platforms

1. Active review retains the real dominant top timer, all public badges grouped by owner above both players, and large You-then-Opponent vertical panels at every supported width. Short screens and large type scroll; Mac width never creates side-by-side competitors.
2. The reviewed still is the actual selected redacted evidence, aspect-fit without distortion/cropping or body-overlay chrome. Missing/failed masking never exposes an unmasked frozen fallback or sends an original. The camera is not kept acquiring behind a frozen review.
3. Selected/Not sent, transport uncertainty, real Checking, current Accepted, and Needs retake are observably different. Check pose shares only the inspected masked candidate under current consent. Upload completion and elapsed animation cannot manufacture acceptance.
4. Opening/cancelling a retake preserves an existing acceptance. Acquiring a replacement removes it, consumes the actual replacement opportunity, and cannot be undone by reopening or late old acceptance. Exactly two replacements per pose; a transport retry consumes none.
5. A late rejection names the actual affected pose, preserves another pose's current work, and reveals no score or opponent image. Rejection recovery, ambiguous safety review, exhausted attempts, and service failure have actual connected outcomes.
6. The original clock continues through review, checks, sheets, retake setup, and recovery. Reconnection, permission recovery, resize, multiple windows, or return from background grants no time, retakes, charge, or new match. Local expiry is not a fabricated final result.
7. Submission uses the real current accepted set and shared eligibility, locks on the real protocol, and cannot submit an old accepted candidate during replacement or unlock on an unknown receipt. Reopening this view cannot restart a judge or change Elo.
8. Opponent presentation contains only authorized identity/avatar/silhouette and actual stage/count before finality. Country, badges, rating, and UI screenshots never enter judge evidence. No rejected attempt or early counterpart thumbnail leaks.
9. iPhone short/landscape/large-type layouts retain usable safe actions, complete status/correction copy, and measured navigation clearance. No accidental swipe dismissal/forfeit or icon-only inaccessible recovery.
10. Native Mac at 800 by 600, laptop, large/full-screen, and available external-display sizes remains a native resizable window with the same vertical stage. Keyboard, pointer, focus, title bar, toolbar/sheets, and preserved commands behave conventionally.
11. Actual Mac camera denial/restriction and external/Continuity disconnection do not show a fake feed or file-picker substitute. Existing authorized masked evidence is not erased solely because a camera becomes unavailable. A secondary window does not acquire another camera/budget.
12. Escape, Return, Space, Cmd-W/Quit, native text entry, privacy withdrawal, and interruption preserve real stage consequences. Force quit is not represented as an accepted voluntary forfeit. Account switching/sign-out never shows another account's cached still.
13. The brief shelf/check motion is event-triggered, interruptible, and does not delay actions or imply a body score/win. Reduce Motion/Transparency, large text, VoiceOver, keyboard, Voice Control, and Switch Control retain the same facts and actions. No ticking announcements or queued acceptance celebration.
14. Decorative activity pauses in inactive/offscreen/minimized/background or energy-constrained states, while authoritative timing remains truthful. Review timer updates do not decode images, restart capture, or perform per-frame network/provider work.

## Focused Native Smoke and Accessibility Scenarios

These are future engineering checks, not claims made by the design batch. Run the actual changed native surface; compiling, snapshot previews, or unit tests alone are not proof of the behavior. Use the authorized real service and consenting adult participants for actual matches. Never use a production fake peer or mock-rated result to make a smoke run pass.

1. **iPhone selection and check:** enter a real active pose capture, acquire a safe still, inspect the exact masked preview before Check pose, and observe actual transport/check acceptance. Continue to a different pose while the first check is running. Observe the top clock, complete rails, vertical panels, primary action, and stopped camera during review.
2. **Replacement and race:** replace an accepted pose, observe accepted progress drop, and reconcile the service's remaining budget. Exercise an already-supported isolated service integration scenario in which the superseded candidate completes late; the current candidate must not become accepted. This is an uncertain consumer-visible authority edge, not a source/wiring assertion. Add a permanent regression only if existing coverage does not protect it.
3. **Budget boundary:** cancel an unexposed retake/self-timer, then acquire the permitted replacements. Observe no charge for cancellation, the actual two/one/zero opportunity transitions, no third capture, no old-image restore, and distinct behavior for an accepted versus rejected final attempt. A same-candidate transfer retry must not consume a replacement or another allowance slot.
4. **Private recovery:** exercise safe mask-failure and actual recoverable transfer/check failure paths through established isolated service/capture test support where necessary, without sending an unsafe original or using harmful media. In the native app, observe the protected placeholder, genuine Retry/Retake availability, late rejection of a named slot, and no body-score feedback. Label isolated harness results separately from actual camera proof.
5. **Timing and restore:** review near the real capture deadline; open an existing native sheet, interrupt connectivity/background, and return within the actual grace if still eligible. Observe the same candidate, spent budget, original deadline, and service-confirmed terminal/wait state. Do not infer no-contest/allowance restoration from client time alone.
6. **Native Mac surface:** launch the actual macOS app at its existing 800 by 600 minimum; resize to laptop/large/full-screen sizes, and use an external display if available. Scroll the stage, inspect every badge, and traverse actions with keyboard and pointer. Verify no side-by-side participants, no layout-driven capture/check restart, and safe controls remain reachable. Name unavailable display hardware honestly rather than claiming it was covered.
7. **Mac device/window lifecycle:** exercise TCC denial/recovery and an available external/Continuity camera disconnect through the real camera owner. Observe that an existing masked still is preserved when authorized while acquisition is unavailable. Open a second window; confirm same-match restoration with one owner. Exercise Escape, focused Return/Space, existing commands, native text entry, close confirmation, and inactive/minimized return without a reset. Do not force quit a participant's match merely to create a fake forfeit result.
8. **Accessibility and energy:** use VoiceOver and the largest available text, Reduce Motion, Reduce Transparency, Increase Contrast, keyboard-only traversal, and available Voice Control/Switch Control paths on the native surfaces. Observe current-pose entry focus, a single acceptance/rejection announcement, no per-second speech, and focus restoration. Enable available Low Power Mode and background/minimize review; observe stopped camera/decorative activity and unchanged service timing. Do not invent battery, frame-rate, or thermal measurements.

Run the smallest relevant existing build/check and behavior regression for touched code after the native path works; fix clear reproducible failures. Do not rerun a user-reported failure merely to confirm their observation. Keep permanent tests focused on real behavior, races, boundaries, and privacy/authority invariants; no tests of copy, forwarding, source text, incidental layout constants, mock echoes, or bare non-crashing.

If either native runtime, login, paired participant, authorized service, physical camera, external display, or device-specific path is unavailable, first exhaust reachable existing tooling/context, then name exactly the missing prerequisite and which narrower scenario was actually exercised. An isolated smoke script may exercise state boundaries but is not native layout, TCC, physical camera, or accessibility proof. Do not claim both-platform verification from one simulator or a preview. No screenshots, recordings, extended proof package, or sensitive image logs are required.

## Human Verification Handoff — REQUIRED

List F29-A-j and each meaningful implemented task separately: in-place exact review, current-candidate states/transfer gate, retake invalidation/budget, recovery/deadline/lock integration, iPhone composition, native Mac lifecycle/input, and accessibility/motion/energy behavior. List every actually changed file separately.

Ask the user to review the code changes and state that each implemented item is ready for human verification. Report only checks and scenarios actually exercised, and identify remaining physical-camera/platform/service limitations plainly. Do not claim a human accepted the behavior. No implementation completion evidence or task checkboxes go into DOCKS. After the user accepts an altered product decision, update the smallest relevant plain-language product context.

## Agent Rules — Mandatory

1. **Single owner; no nested agents.** Do the assigned implementation yourself. Do not spawn reviewers, generators, or other workers. Preserve coordinated ownership and unrelated concurrent changes.
2. **Real connected behavior.** No mock production service, fake participant, hardcoded acceptance, simulated rated result, no-op control, demo gallery, silent provider fallback, or local Elo. Preview-only fixtures must be explicitly isolated and labeled, never used as the shipped path.
3. **Reviewed foundations first.** Resolve actual dependencies through code and context. Missing documentation is not permission to invent authority; a genuinely missing reviewed service/capture contract is not solved by a view-local substitute.
4. **No unrelated changes.** Reuse existing style, camera, routing, state, native controls, and trusted service. No new global theme, framework wrapper, third profile side, general retry system, target raise, or parallel battle host.
5. **Respect privacy immediately.** No unmasked upload, UI screenshot evidence, early opponent pose, unsafe reveal, secret in client/logs, extra permission, or image-bearing diagnostics. Protection and camera stop never wait for motion.
6. **Exercise the actual surface.** Run focused native smoke/accessibility/energy scenarios on both platforms wherever runtime exists. Tests/builds alone do not prove this UI. Report missing physical-device proof honestly.
7. **Fix clear failures in scope.** Diagnose using existing source/contracts; repair clear local build, state, integration, or runtime failures. Avoid speculative debugging and broad unrelated refactors.
8. **Implementation tracking only in CYCLES.md.** Mark only actually implemented assigned todos after connected behavior and focused checks, with a clear human-review handoff. Do not mark human approval or create an IDE-specific duplicate task list.
9. **Scoped commit and push on later implementation.** Once this future prompt is authorized and executed, inspect each complete functional work slice, commit only owned intended files with a clear message, and push to `origin/main` before yielding. Never stage another worker's changes, force-push, rewrite history, or leave publication falsely claimed. State exact commit/push blockers. This instruction does not authorize git during the present documentation-only batch.
10. **User direction wins.** Direct user decisions override stale documents. State a concrete conflict briefly, implement the authorized direction, and document accepted behavior at the proper review boundary. Never demand that the user rewrite DOCKS before acting.
11. **Honest product documentation.** DOCKS stays plain-language purpose, composition, states, interactions, motion, privacy, and dependencies; no code, payloads, implementation recipes, todos, logs, screenshots, or verification claims.
12. **Complete this connected slice.** Do not stop at a compiling scaffold or leave obvious checks/fixes, wiring, tracking, commit, or push for another prompt. Do not execute an unapproved protocol or generate an unrelated next phase.

## When You Finish

Return implemented items and changed files separately, exact exercised native/check evidence, actual blockers/limitations, and the review request. State publication status truthfully. Clarify that human verification is pending. Evaluate actual remaining work: no next prompt is needed for a completed F29-A-j slice, and no next prompt may exist merely for testing, obvious fixes, documentation, or publishing. A later substantial feature remains with its assigned owner rather than being silently absorbed into pose review.
