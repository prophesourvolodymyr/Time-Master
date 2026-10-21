# Phase 1 of F29-A-k — Submission and Judging

## Assigned Model and Thinking

Execute with **openai-codex/gpt-6.1-sol:max**: model **openai-codex/gpt-6.1-sol**, thinking level **max**. Do not silently substitute another model or reasoning level. If this assignment is unavailable, report the actual dispatch prerequisite rather than claiming the requested specialist ran.

This assignment selects the UI implementation worker. It does not select, upgrade, or change the in-app ranked judge, the service's judging version, provider policy, or either participant's AI Coach settings.

## Features Included

- F29-A-k — One real connected native submission-and-judging presentation, covering submit acknowledgement, upload, checks, opponent wait, actual paired judging, settlement, and recovery of the same match.
- F29-A-k — Own selected/received/accepted counts, authorized opponent stage/count, true phase clocks, truthful slow status, and distinct state-aware actions.
- F29-A-k — Native iPhone and native Mac composition, input, focus, accessibility, immediate privacy protection, and reduced/energy-aware motion.
- F29-A-k — Integration with existing pending-match, result, retake, safety, privacy, and generic-notification routes; no additional custom screens or independent competitive engine.

List each meaningful item separately in the human handoff. This is one end-to-end functional slice, not permission to ship a waiting view before its shared foundations exist.

## Context

Physique Duels is a separate native competition with private redacted pose evidence and service-owned finality. The user requires a top real timer, every public badge above two large vertically stacked players, and animated concise sports presentation on both iPhone and macOS. This phase connects the waiting stage to the real reviewed match lifecycle rather than building a simulated spinner page.

## What You Need to Read First

Read the complete primary product context:

- `AGENTS.md` from the provided project context, plus `CYCLES.md`, especially the current F29 implementation and human-review entries. Do not search for unrelated agent-context files.
- `features/DOCKS.md` — registered feature ownership and dependencies.
- `features/F29-physique-duels/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-k-submission-and-judging/DOCKS.md` — this phase's complete product behavior.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — accepted inputs, valid judgement, absent-score outcomes, blindness, and deadline/finality sections.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — one active match, allowance, interruption, explicit forfeit, and authoritative finality.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — checks, persistent safety access, immediate protection, and moderation precedence.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — stage-specific withdrawal, camera lifecycle, permissions, received-state recovery, thirty-second decision limit, notifications, access, and retention.
- `features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md` — all public badges, self-declared country, current placement/streak, correction, freshness, and legitimate identity.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md`.
- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md`.
- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md`.
- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md`.
- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md`.

Read the relevant destination contracts; do not rebuild these views in this phase:

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-a-lobby/DOCKS.md` — exact pending-match entry and restored navigation.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md` and `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-j-pose-review/DOCKS.md` — selected versions, original time, retakes, explicit camera resume.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-l-result/DOCKS.md` — immediate terminal handoff and no inappropriate gallery.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-s-report-composer/DOCKS.md` and `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md` — contextual routes, draft protection, and withdrawal.

Read source patterns at the supplied anchors, then discover their actual current integration callers before editing:

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing near-black surfaces, orange action treatment, shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter typography, shared spacing, readable content width, iPhone action convention.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material fallbacks, Reduce Transparency, press spring response 0.24 and damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — shared sports action/metric language; do not copy type clamps or fake earned state.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — contextual exercise HUD only; do not import its provisional score, lead meter, movement metrics, or exercise privacy assumptions.
- `TimeMaster/App/TmaxApp.swift:8-19` — native normal-title-bar WindowGroup, existing 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — local cosmetic previews are not competitive badges or verified identity.
- `TimeMaster.xcodeproj/project.pbxproj` — discover the actual native target memberships and settings; retain iPhone iOS 16 and native macOS 14 compatibility, without raising app or extension targets.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the supplied reference image. Borrow the direct timer/player hierarchy, not its horizontal layout, overlay pills, palette, people, footage, text, or presumed rights.

Find and read the actual reviewed Physique match state, transport, capture coordinator, routing, notification integration, and shared components under `TimeMaster/Views/Physique/`, `TimeMaster/Services/Physique/`, and `TimeMaster/Models/`. These directory locations are prospective architecture boundaries, not proof that those files are currently implemented. Use discovered filenames, not guessed alternate coordinators. Read the real service contract and relevant existing contract tests when required to understand receipts, versions, timestamps, and finality; this phase must not manufacture backend behavior inside a view.

Use the inherited UI Skills selection **dimillian/swiftui-ui-patterns**, limited to the available relevant state-driven composition and native presentation patterns; do not repeat catalog setup or install an unrelated visual system. Read relevant installed guidance at `skill://swiftui-pro`, especially accessibility, data ownership, and performance, `skill://swiftui-animation`, and `skill://apple-hig-reference`. Availability-gate modern effects; a skill's newest-platform examples do not override the existing deployment targets. Use only the relevant references rather than loading every skill chapter.

Consult the actual current Apple sources for the platform-dependent decisions:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices.
- https://developer.apple.com/design/human-interface-guidelines/motion — Best practices and Providing feedback.
- https://developer.apple.com/design/human-interface-guidelines/progress-indicators — Best practices and macOS.
- https://developer.apple.com/design/human-interface-guidelines/notifications — consent, private content, duplicate delivery, foreground behavior.

DOCKS files are plain-language product context, not implementation recipes or proof that their dependencies work. Validate the technical approach through actual source, installed skills, framework availability, and current Apple guidance. Do not put source snippets, payloads, pseudocode, task lists, screenshots, logs, or verification evidence in a DOCKS file.

## What Happened Last Session

The coordinated documentation-only batch selected the vertical animated native UI direction and assigned one specialist to this waiting view. It inspected the supplied screenshot, existing source anchors, relevant SwiftUI guidance, and Apple HIG. The two artifacts are the F29-A-k product context and this future implementation brief. That work did not implement Swift views, a provider, transport, protected media, notifications, or a mock application, and did not run native builds, tests, or camera scenarios.

The shared parent documents describe the intended service-owned match lifecycle and component family. Their presence is not human acceptance of the foundation or proof of a deployed judge. Do not report this implementation phase as having started or passed merely because the brief exists.

## Prerequisites and Human-Review Boundary

Begin production implementation only after the real shared foundations and their relevant contracts are implemented, connected, and human-reviewed. Confirm this from `CYCLES.md`, actual source, and the existing handoff context rather than inferring approval from a checked documentation item.

Required foundations are authenticated account ownership; one active match across devices/windows; protected current-version redacted capture and transport; authoritative selected/received/accepted semantics; trustworthy stage and receipt/deadline information; contextual safety checks; valid paired judging and exactly-once finalization; real allowance/rating consequences; native F29-F/G components; and the existing pending, result, retake, safety, privacy, and notification destinations. A notification action may not be rendered as functional before its real authorized delivery path exists.

Missing actual service information is not permission to fill counts with sample values, start a local thirty-second authority, create a fake opponent, route every error to a guessed no-contest, or leave a dead Notify me button. Name the precise missing prerequisite and complete reachable authorized work without claiming this screen shippable. Do not absorb a whole unreviewed judge, safety operation, or shared shell into a supposedly independent UI phase. Fix clear safe integration errors within the connected slice; do not use ordinary local compiler or routing errors as an external blocker.

## Design Reasoning Outcomes to Preserve

1. **Stable vertical stage, not a spinner takeover.** Real clock first; concise phase; both complete owner-grouped identity/badge rails above both large upright player panels; You above Opponent at every width. Extra Mac space belongs to details, not a horizontal matchup. Short-window scrolling is preferable to tiny players or a capped badge collection.
2. **Privacy-safe waiting portraits.** Stop acquisition on leaving active capture. Use the shared legitimate silhouette or currently authorized public avatar, never a frozen fake feed or early opponent evidence. Own exact-image inspection stays in Pose review. This deliberately reduces sensitive exposure while waiting.
3. **Evidence facts, not progress theater.** Own Selected, Received, and Accepted are separate current-version counts out of three. Opponent status uses only its authorized stage/accepted-count projection. That deliberate asymmetry is safer than adding private opponent metadata for visual symmetry. Never convert counts into an AI percentage or a completion-time estimate.
4. **A limit is not an ETA.** Before paired-final-set receipt use the original capture deadline. Once both final sets are received, show the remaining thirty-second Decision limit including checks, queueing, judging, validation, and settlement; display Limit, not an estimate. Never start it at provider dispatch or screen appearance. At zero, unconfirmed clients await authority instead of finalizing locally.
5. **Honest slow status.** Five seconds of this person's final-submission wait permits a concise acknowledgement of the actual stage, without changing the shared end-to-end target: Still sending, Checks are taking longer, Opponent still finishing, Still judging, or Confirming result. Still judging is not a blanket label for incomplete receipt or opponent capture. Restore the original waiting milestone rather than restarting it.
6. **Return is not Forfeit.** Ordinary Return to Physique preserves the same pending match. Warn only about real outstanding client work and unchanged deadlines. Explicit confirmed Forfeit and leave is separate, eligibility-aware, and service-acknowledged. Closing a window, reporting, blocking, privacy help, force quit, or an ordinary navigation dismissal is not hidden consent to a rated loss.
7. **Tactile but truthful motion.** Shared press feedback, stable timer digits, one brief current-slot acceptance response, and approximately 280-millisecond stage continuity communicate actual changes. Shared quiet atmosphere remains the only decorative ambient layer. No camera scan, badge wall pulse, fake category sequence, or unconfirmed award. Protection and current final meaning are immediate.
8. **Genuinely native Mac.** Normal title bar, real toolbar, optional inspector, 800-by-600 support, live resize, external displays, actual TCC/peripheral states, keyboard/focus, one camera owner, and window lifecycle are required behavior, not an iPhone layout stretched wider.

## What to Build

### Real connected stage presentation

Create or extend the feature-owned waiting view using the actual reviewed match coordinator and shared components. Do not introduce a second match state machine, global timer, camera service, badge renderer, notification manager, provider client, or competitive-result calculator. Subscribe and navigate through existing patterns. View appearance, recreation, resizing, or notification routing must never submit a new judgement.

Represent concurrent operations rather than a compulsory animated sequence. An own transfer can finish while the opponent is still capturing. Receipt and checking can overlap. An already-complete stage can be skipped. Prefer actual required personal action or protection over ordinary activity; never label unknown server state as known provider reasoning. When restoration finds capture, pre-Go, or finality instead of waiting, navigate to its real owning route.

Keep healthy status concise. Show one heading, one useful support line, own counters, and the actual authorized counterpart projection. Use the exact visible-state distinctions in the DOCKS file. Preserve real zero versus unknown. No dummy roster, fake progress, sample scores, confidence values, guessed rating or allowance effects, or placeholder callback may enter the production path.

### Current-version counts and interruption

Count each of Front, Side, and Rear at most once using its currently selected version. Do not count every candidate, superseded retake, duplicate acknowledgement, or repeated check. A replacement invalidates its earlier acceptance. A stale receipt/check for an old version cannot approve the replacement. Reconcile lost acknowledgements before resending, and use the shared permitted transport recovery for the exact same match/set.

Provide Retry transfer only for genuinely retryable same-set transfer within the original service limits. Provide Retry status for unknown receipts or outcomes. Do not indiscriminately label both Retry or allow a status refresh to trigger another provider vote. If a service-requested exact retake remains eligible, Review pose opens the existing route with original time and attempts; otherwise wait for its real terminal outcome without a dead retake control.

### Authoritative clocks and results

Use the reviewed F29-G clock and true service timing. Preserve the original ninety-second capture deadline and, when client participation is required, the twenty-second reconnect opportunity without extending any deadline. Switch the top clock to the thirty-second decision limit only from confirmed receipt of both final sets, not merely six local selections or two pressed Submit buttons. Remaining checks consume that same thirty seconds.

Missing or unreliable time is visibly unconfirmed. Wall-clock changes, background return, late network delivery, another window, retakes, or status retries do not create more time. A client seeing zero without a terminal record shows Awaiting confirmed outcome and retrieves the same state. A valid result finalized on time but delivered later is different from late provider output; the former remains valid, the latter cannot overwrite an existing no-contest.

Navigate to the existing exact-match result only on service finality. No successful provider payload, first token, local timeout, score interpolation, or animation completion can authorize a verdict, Elo, badge, gallery, or slot restoration. Keep no-contest, valid draw, and explicit eligible forfeit distinct. Do not show invented zero scores or a counterpart gallery for forfeit/no-contest.

### Return, exit, and lifecycle

Connect Return to Physique to the existing single pending-match route. If acknowledged local work is complete and no personal action is pending, it returns directly. If client sending/reconciliation/recapture may be interrupted, use the ordinary native Stay/Return confirmation with the actual remaining opportunity and honest possible suspension; this is not a forfeit dialog or a promise that the process will continue in the background. Preserve a route out of the view without forcing continued data sharing.

Expose explicit Forfeit and leave separately, only with the real state-aware confirmation and actual service acknowledgement. Keep waiting is the safe default. Reconcile races where an existing final result, invalid evidence, safety abort, or unavailable service wins the outcome. No optimistic completed-forfeit state after an unsent or unknown request.

Stop acquisition and shield private content immediately on background, inactive/minimized capture, device lock, sign-out, authorization change, or privacy action. Waiting normally requires no camera. Already accepted sets may complete server judging without any open client. Reopen the same match with actual state before offering an intentional permitted camera resume. No relaunch, second device, or secondary window may create another match, charge, provider request, or camera session.

### Safety, privacy, and notifications

Keep contextual Safety and Privacy and sharing accessible without enlarging an image. Report/block/withdraw routes must remain real connected destinations with their own private draft/receipt semantics, not stubs. Block after Go shields/excludes future pairs but does not automatically finish or rerate. Stop new affected processing/transfer immediately on withdrawal; distinguish remote acknowledgement from a local request. Preserve the gallery, deletion, expiry, face-redaction, and bystander rules in B/D/E.

Connect generic result availability only to the actual reviewed notification integration. Request system notification permission solely after an explicit Notify me action, never automatically while waiting. Denial or restriction leaves honest Notifications off and a useful existing settings route, without a no-op action or repeated prompt. Do not promise system delivery.

A confirmed terminal result may issue one deduplicated generic A result is available message through the existing path. Never include a Physique label, image, avatar, opponent, country, badge, body score, Elo, outcome, report reason, or sensitive text. Do not notify redundantly while the exact match is already being viewed. Opening verifies the signed-in owner and fetches that exact match, not poses or a camera. Duplicate delivery cannot rerate, award again, or extend media expiry. Do not add a result-card notification, custom notification view, Live Activity, lock-screen countdown, or notification action to forfeit or rerun judging.

### Native surfaces and motion

On iPhone, maintain measured safe-area/navigation clearance, a reachable clock and safe actions, wrapped full badge rails at the top of the scrollable stage, and two substantial vertical panels. Do not pin an unlimited badge wall or shrink people to fit a short phone. Preserve the existing forty-four-point action convention. Support portrait, constrained landscape, large text, readable errors, and contextual sheet/keyboard behavior.

On native Mac, retain normal title bar/window controls and 800-by-600 minimum. Use the existing readable stage column, toolbar controls, and supplementary native Details inspector where useful. At minimum size or with large text, scroll rather than hide a player, badges, deadline, or action. Keep participants vertical on laptop, large, full-screen, and external-display windows. Preserve focus, selection, deadlines, and camera ownership through live resizing.

Tab/Shift-Tab and visible focus must traverse semantic controls predictably. Return/Space activate the focused control only, never a global capture/submit/forfeit operation while typing. Preserve existing app commands. Escape dismisses the current nondestructive presentation first and uses the same state-aware root navigation guard. Cmd-W/quit confirm actual interruption only where the platform permits; closing or force quit is not a voluntary-forfeit acknowledgement. A disconnected external/Continuity camera or TCC denial matters to a requested recapture, not to already accepted autonomous judging; never substitute a rated file picker or fake feed.

Use the timing and interruption table in the DOCKS file: shared press spring, about 180-millisecond stable timer/status changes, a tiny single current-slot acceptance check within the small-status range, and about 280-millisecond stage continuity. Shared atmosphere is the only quiet approximately twelve-second decorative loop. Do not add a second waiting-specific ambient layer. A result or protection event interrupts immediately; no serial minimum wait or award replay after restore.

Reduce Motion removes scale/travel/repetition and uses immediate or at-most-about-120-millisecond opacity changes with the same information. Reduce Transparency uses existing opaque readable surfaces. Stop decorative work offscreen, backgrounded, inactive, minimized, locked, low power, and under thermal pressure. Service clocks/finality continue independently. No per-frame network/provider/file work, image decoding, camera creation, font measurement, badge sorting, or global layout rebuild. Use coherent public availability fallbacks; no private APIs or target raises.

VoiceOver receives stage, clock meaning, own named counts, authorized counterpart state, complete badge semantics, meaningful errors, and final availability without every tick, packet, or repeated status being announced. Focus moves on a genuine required action or active unobstructed final transition, not on routine counts. If a report/privacy sheet is being edited, preserve the draft and focus and mark result availability without dismissing the sheet or opening media. Voice Control, Switch Control, silent mode, non-color signals, and absent haptics must remain complete paths.

## Prospective Files to Create or Modify

These are future implementation locations, not assertions that the production sources already exist:

- Create or extend `TimeMaster/Views/Physique/PhysiqueSubmissionJudgingView.swift` — the waiting stage, composed from the reviewed shared clock, identity rails, vertical panels, atmosphere, and native controls.
- Modify only the actual discovered Physique match-presentation/routing caller as necessary to enter, resume, and leave this view with the same match and hand off finality or requested retake. Reuse its existing ownership; do not establish a parallel coordinator.
- Modify only the actual existing receipt/status presentation adapter if a small clear integration change is necessary to expose reviewed state. Do not invent client-authoritative deadlines or silently expand the service's public opponent projection.
- Modify only the actual existing generic-notification and pending-match route integration where this view's connected contract requires it. Do not rebuild the lobby, result, privacy, safety, notification architecture, or shared component library.
- Update relevant existing focused behavior/contract tests when the public behavior genuinely changes. Add a permanent regression only for an uncertain plausible consumer-visible boundary, not to prove wiring, exact copy, mocked forwarding, source structure, or bare non-crashing rendering.
- Modify `TimeMaster.xcodeproj/project.pbxproj` only if the project's existing source-membership mechanism requires connecting this actual file to both native targets. Do not change deployment targets or unrelated build settings.
- Update only the appropriate implementation todos in `CYCLES.md` after connected behavior and focused checks are complete and the handoff is ready. Human review remains pending.

Discover the actual files before opening/editing them. Prefer existing names and patterns over the prospective filename if implementation has already established a compatible view. Do not create another file solely to maintain this brief's suggested spelling. Do not modify shared theme APIs, unrelated app pages, source-system rules, another worker's feature, or an unowned custom screen.

## Observable Acceptance — Both Platforms

The following are required behaviors, not a claim they have been exercised:

1. A real started match enters the wait with current-version counts. With three selected, two acknowledged received, and one accepted, all three own facts are distinguishable; no percentage or score is implied. Unknown differs from zero. The opponent uses only the authorized actual stage/count.
2. Every eligible public battle badge appears in its owner group above both large upright panels. You remains above Opponent on iPhone and Mac at all widths. No badge covers a portrait or evidence, no hidden-count cap exists, and short windows/large text scroll rather than shrink the players.
3. Upload, checks, opponent wait, actual judging, and settlement use their true stages, including concurrency and fast skipped stages. Five-second slow wording describes the real bottleneck and never becomes a five-second result countdown.
4. The primary phase clock is the original capture deadline before paired receipt, then the thirty-second Decision limit from receipt of both final sets. Checks and queueing do not postpone the limit. Reopening, provider start, clock changes, resize, reconnect, or retake cannot reset it.
5. At a local timeout without confirmed finality, the UI remains Awaiting confirmed outcome. A service-finalized no-contest has no Elo change or gallery and shows only confirmed allowance state. A valid on-time final record delivered late is retrieved intact; late provider output cannot replace an existing terminal record.
6. Retry status never reruns judging. Permitted retry transfer reuses the same match and versions. Replacement invalidates old acceptance; old responses, duplicate receipts, multiple windows, and relaunch never double-count poses, spend/restore slots twice, or duplicate rating/badges.
7. Return restores the exact pending match through the existing page entry, without forfeiture or a new queue. Any true outstanding-client-work warning states the unchanged deadline and possible suspension. Explicit Forfeit and leave remains separate and acknowledgement-based; involuntary close/force quit is not relabeled as that action.
8. Camera is off during ordinary waiting. Permission denial or a disconnected external/Continuity camera does not invalidate already accepted autonomous judging. A permitted retake goes to its owner with original limits; no rated library/recording/fake-preview fallback appears.
9. All safety/privacy protections apply immediately and pre-final counterpart evidence never appears. A final result does not auto-open poses. A report/privacy draft is not lost to an incoming result. Account switch, deleted access, and secondary windows do not leak private content or seize capture ownership.
10. A separately authorized real notification is generic, deduplicated, and owner-checked on open. Denial does not block recovery. No local clock completion generates a result notification or a local outcome.
11. iPhone safe areas, large text, keyboard/sheet presentation, VoiceOver, Voice Control, and Switch Control retain full actions. Native Mac works at 800-by-600, laptop, large/full-screen, external display, live resize, keyboard-only traversal, and system window lifecycle without horizontalizing players or overriding existing commands.
12. Tactile motion follows actual events, can be interrupted, and stops when not useful. Reduce Motion/Transparency and energy-constrained/inactive states retain the same information and immediate protection, without camera/network/provider work being driven by animation frames.

## Focused Actual Native Smoke, Accessibility, and Energy Scenarios

Run the smallest relevant available build/typecheck/test path for files actually changed, fix clear failures, and then launch the real changed native surface. A build or unit test alone is not the smoke proof. Do not repeat an already user-reported failing check merely to confirm their observation; diagnose it and rerun only after a meaningful fix.

Use authorized real service behavior and consenting adult participants for rated physical-camera work. Use existing deterministic service fault controls where already provided. Clearly labeled isolated development fixtures or an existing preview can help inspect layout but are not production fallbacks, service proof, or substitutes for a real connected match. Do not authorize paid evaluation, deploy a server, generate assets, upload unsolicited images, or alter credentials as part of this UI phase.

Exercise the focused changed paths rather than assembling an exhaustive proof package:

- **Connected iPhone path:** capture/submit a genuine eligible set; observe current own counts and authorized opponent count, incomplete upload/check distinction, opponent wait, real paired judging, and exact-match terminal navigation. Return through the pending entry during a wait, restore the same match, and observe unchanged timing and no additional slot/rating operation.
- **Timing and failure path:** use available existing fault controls for a lost receipt acknowledgement, one retryable transfer, a permitted exact-pose rejection, slow checks/judging, a deadline with uncertain client delivery, and a finalized result delivered after reconnect. Observe the actual service record and visible outcome, not a local timer assumption. Cover late response after terminal no-contest and duplicated refresh through existing contract coverage where available.
- **Connected Mac path:** launch the native macOS target, not a browser or Catalyst substitute. Observe the same waiting journey at 800-by-600, an ordinary laptop window, a large/full-screen window, live resize, and an external display when available. Both players remain large and vertical; full rails are reachable, and clock/actions survive short-window scroll and inspector changes.
- **Camera/lifecycle path:** while the set is accepted, disconnect a real external/Continuity camera if available and confirm waiting remains camera-free. During an eligible recapture, observe the actual denial/disconnect and correct owner route. Background/lock iPhone; deactivate/minimize/close and reopen Mac as appropriate; restore the same record without invisible capture or a reset deadline. Open a secondary window/device only if the real shared foundation supports it; verify no new capture owner or charge.
- **Keyboard/focus path:** traverse the Mac wait and Details with keyboard only. Return/Space affect the focused control; Escape obeys its current layer; report-note typing does not submit or capture; Cmd-W/quit convey only actual consequences. Existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their meaning. An arriving result must not dismiss an edited report/privacy route or steal its focus.
- **Accessibility/layout path:** inspect the actual surface at largest supported accessibility text and long localized content. Reach every wrapped badge and both panels without truncation/caps or type clamps. Use VoiceOver to inspect clock meaning, Selected/Received/Accepted, real unknown state, counterpart projection, retake action, Return, and Safety; confirm no every-second announcement. Use available Voice Control/Switch Control paths and verify symbols/text remain meaningful without color, sound, or haptics.
- **Reduced/energy path:** enable Reduce Motion and Reduce Transparency, then background/deactivate/minimize the surface and use an available real low-power/thermal condition or existing system-level energy test facility. Observe no decorative loop while inactive, no camera activity during waiting, immediate privacy protection, unchanged deadlines after resume, and no backlog of receipt/timer/award animation. Do not claim measured smoothness or an energy improvement from source inspection alone.
- **Notification/privacy path:** with actual separately granted notification permission, let a real terminal result arrive while away; inspect the generic system notification, authenticated exact-match return, and absence of pose auto-opening. Exercise denial and a stale/wrong-account route using available account tools. No duplicate notification or finalization on reopen/refresh. Do not treat a preview notification or simulated fixture as proof of real delivery.

If a native runtime, physical iPhone, two consenting participants, real camera/peripheral, external display, service fault control, or authorized notification path is unavailable, name exactly which surface/scenario could not be exercised and which narrower checks actually ran. Do not fabricate observation, call simulator layout a physical-camera match, or hide a meaningful platform limitation. Complete all reachable authorized integration and focused verification before reporting a true external prerequisite. Do not create a testing-only follow-up prompt.

## Human Verification Handoff — Required

List every implemented meaningful item separately: real stage/count presentation; clocks and slow status; same-match transfer/status recovery; return versus explicit forfeit; final-result handoff; safety/privacy/notification integration; iPhone composition; native Mac composition/input/window/camera behavior; and motion/accessibility/energy behavior. Distinguish intentionally unchanged shared contracts from changed source.

List every changed file separately with its role. Report only checks and native scenarios actually exercised, with concrete visible behavior and explicit runtime/hardware/service limits. State that each implemented item is ready for human verification, ask the user to review the code changes, and keep human acceptance pending. No screenshot package, recording, log bundle, or completion-evidence document is required.

Do not claim human approval, a measured five-second result guarantee, a fairness score, App Store approval, measured frame rate, unavailable camera proof, or complete end-to-end readiness from compilation. Do not put implementation evidence or checklists in DOCKS. After the user accepts resulting behavior, update the smallest relevant DOCKS with accepted product decisions in plain language only.

## Agent Rules — Mandatory

1. **Single owner, no nested agents.** Perform this slice yourself. Do not spawn agents to design, implement, review, or inspect this repository. Do not silently change the assigned model or thinking level.
2. **Real foundations first.** Start code only after the required shared contracts and foundations are real, connected, and human-reviewed. No fake backend, static rated demo, hardcoded opponent/count, generated body substitute, mock production fallback, dead callback, or TODO implementation is acceptable.
3. **User direction wins.** Preserve native iPhone plus native Mac, timer first, every public badge above both large vertical participants, concise animated sports UI, and the full privacy/service authority. If documentation conflicts, state the concrete conflict and follow the user. Do not silently narrow to iPhone or a happy-path spinner.
4. **Independent technical judgment.** Read current source and relevant skills; reuse established ownership and controls. Do not establish parallel global state, timing, camera, theme, badge, notification, or service abstractions. No unowned new custom screens, unrelated refactors, destructive git actions, private APIs, target raises, or secret commits.
5. **Complete the connected slice.** Build, connect real callers, exercise changed native behavior, fix clear failures, preserve affected contracts, update implementation tracking, and hand off in this phase. Compilation or a preview alone is not completion. Ordinary local errors are yours to fix safely.
6. **Focused consumer-visible coverage.** Reuse focused existing tests. Permanent new tests must protect a plausible boundary or transition, such as current-version acceptance or nondestructive same-match return, not source text, wording, copies, wiring, mocked echoes, or bare non-throw. Remove throwaway scaffolding after actual proof.
7. **Only CYCLES tracks work.** Mark appropriate implementation todos only after connected code/checks/handoff are ready; never mark human acceptance. No duplicate IDE task files or task checklists in DOCKS, prompts, or audit artifacts. Product documents remain plain-language context.
8. **Scoped commit and publication.** Preserve user and other-worker changes. Commit only this connected implementation slice with a clear message and push it to `origin/main` without force-push or history rewriting. Do not leave your changes staged, unstaged, or only local. If commit/push is unavailable or fails, report the exact blocker and do not claim publication or completion.
9. **Honest evidence and review.** State only observed checks; label actual missing hardware/runtime/service prerequisites. Do not rerun user-reported failures just to confirm them. Fix what is clear, verify changed paths, and ask for human code review without claiming it occurred.
10. **No pointless next prompt.** Complete small reachable remainder now. Generate a next prompt only for a genuinely separate substantial authorized implementation slice, never solely for checking, obvious fixes, documentation, a commit, or a push. Do not use a phase boundary to abandon actionable work.

## When You Finish

Report implemented items and changed files separately, the actual focused checks/native behaviors, any exact external prerequisite or unresolved decision, the scoped commit and push result, and whether a next prompt was genuinely necessary. Ask for human review of the code changes and state each implemented item is ready for human verification. Do not present this documentation brief, a local fake match, an unrun check, or a scaffold as the implemented feature.
