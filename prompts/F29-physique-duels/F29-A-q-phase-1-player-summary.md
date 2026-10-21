# Phase 1 of F29-A-q — Native Player Summary

## Assigned Model and Execution Mode

Required coding model: **openai-codex/gpt-6.1-sol**. Required thinking level: **max**. Dispatch notation: **openai-codex/gpt-6.1-sol:max**. The suffix is the worker's thinking level, not another model identifier or an in-app judging configuration. Do not silently substitute another worker model. If exact dispatch is unavailable, state that limitation before implementation and return it to the coordinating owner.

This is a future implementation assignment produced in a documentation-only batch. Its presence does not authorize app changes today or prove that its service, UI, catalog, or prerequisites exist. Begin code only after the owner authorizes this slice and the real shared foundations/contracts below are implemented and human-reviewed. No client-only mock makes this feature independently shippable.

## Features Included

- F29-A-q — One permitted player-summary component, opened from real pairing identities and permitted Physique standings rows on native iPhone and native macOS.
- Context-correct identity, optional self-declared country, all permitted public badges, actual pairing/match-start rating, separate current public rating and allowed concise record.
- Shared Report player and Block player entry, real permission/revocation/error recovery, return focus, accessibility, tactile supporting motion, and native lifecycle integration.

Implement and list these meaningful tasks separately for human verification. This assignment does not own the full public-profile product, shared badge/catalog authority, global Profile shape, standings algorithm, camera pipeline, judging, report form, or match engine.

## Context

Player summary is a small sports credential, not a body-photo profile or private-history browser. Pairing context and present-day public data have different permissions and time meanings. The approved battle direction is a real top timer, complete badge rails, and two LARGE VERTICAL players on both platforms.

## What You Need to Read First

Read these exact repository paths before selecting implementation patterns:

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md` — complete scoped UX, states, copy, transitions, privacy, and native platform behavior.
- `features/F29-physique-duels/DOCKS.md` — shared competition, publication, privacy, and existing-app boundaries.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — entry hosts, readiness, stage/clock, camera visibility, safe exit, and result routing.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — keep all player-summary data and chrome out of judge evidence/context.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — placement and record meaning, match-time snapshots, public listing, coherent corrections, blocking exclusions, and finality.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — independent reports/blocks, actual acknowledgement, immediate protection, receipt uncertainty, bounded drafts, and no-contest precedence.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — current access, account switching, cache/media lifetime, camera lifecycle, and real service readiness.
- `features/DOCKS.md` and the active F29 sections of `CYCLES.md` — current ownership map, implementation status, and human-review prerequisites. Neither documentation placement nor an implementation checkbox is human approval.
- F29-F's canonical identity/country/avatar/badge context and implementation identified by the integrated F29 ownership map. Its exact directory was not yet present when this child was authored; locate it through the real index or file discovery, do not invent a filename or create a competing catalog. If it is still absent, the prerequisite remains missing.
- The actual pairing, standings, safety, public-identity, and shared-state source files discovered under the future `TimeMaster/Views/Physique/`, `TimeMaster/Services/Physique/`, and feature-model locations. Do not assume these prospective directories already contain implementation or open guessed source filenames.
- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — shared near-black/surface/orange language and native controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — shared Inter type, measured spacing, touch convention, and readable width.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material availability, Reduce Transparency fallback, and press spring response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — existing action and earned-Elo language; do not copy text-size clamps, fake levels, or exercise scope.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only; its live provisional exercise score is not a Physique feature.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local cosmetic state is not trusted public avatar or achievement authority.
- `TimeMaster/App/TmaxApp.swift:8-19` and `TimeMaster/App/TmaxCommands.swift:6-37` — native Mac WindowGroup, title bar, existing 800 by 600 minimum, and commands.
- `TimeMaster.xcodeproj/project.pbxproj` — discover actual iPhone/Mac schemes, target membership, and deployment settings. Preserve iOS 16 and native macOS 14 compatibility; do not raise targets to use a preferred animation or inspector API.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image, not merely its filename. Borrow direct clock/identity/safety hierarchy, not side-by-side players, footage, faces, purple/brown pills, labels over people, or publishing rights.

Use relevant installed `swiftui-pro`, `swiftui-animation`, and `apple-hig-reference` guidance selectively. The documentation owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI; reuse that selected context where available instead of restarting broad setup. Check framework availability independently: newer skill defaults do not override the repo's deployment floors. `STYLES.md` was absent during this design pass; use source conventions and do not create a new global design file.

Read current Apple HIG only for the decisions being implemented:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — resize/full-screen, nonmodal information, keyboard/pointer, active/inactive transitions.
- https://developer.apple.com/design/human-interface-guidelines/sheets — scoped phone presentation, clear Close, one sheet at a time, and Mac modality differences.
- https://developer.apple.com/design/human-interface-guidelines/motion — brief, purposeful, cancellable motion with equivalent static meaning.

DOCKS files contain product context, not source authority or a copyable implementation recipe. Validate actual APIs, contracts, source patterns, and service permissions before editing.

## What Happened Last Session

The documentation-only worker read the shared batch contract, F29-A/B/C/D/E context, supplied native source anchors, installed SwiftUI/HIG guidance, and the reference image. It authored the player-summary product context and this future brief only. No Swift implementation, generated artwork, judge request, runtime smoke, automated check, commit, push, or human approval resulted from that worker's slice. The coordinating owner owns integrated documentation validation and publication.

## Prerequisites and Review Boundaries

Production work starts only after these real contracts are implemented, connected, and human-reviewed:

1. Authenticated account/navigation foundations and current-viewer authorization, including account-switch clearing and one-account/one-active-match ownership across devices/windows.
2. F29-F's canonical public identity, explicitly permitted avatar, optional self-declared country, complete badge catalog/order, service-confirmed awards/removals, and safe unavailable states. Local Profile photographs and badge previews cannot fill any gap.
3. F29-C's authorized current-public summary and pairing/start snapshots, coherent rating/record/placement revisions, visibility withdrawal, and correction semantics. The UI does not derive them from private histories.
4. Shared pairing/standings hosts with real target routing, top-clock/readiness/camera ownership, vertical battle composition, safe exit, and focus restoration.
5. F29-D/E's working contextual reports, state-aware block confirmation, local shielding, service exclusion/acknowledgement, receipt reconciliation, bounded drafts, and published support.

Use the existing owners. A missing catalog, permission, summary endpoint, safety flow, or active-match owner is a concrete prerequisite to finish with its owner, not permission to ship local data, a disabled Report button, a fake success toast, an unmoderated avatar, or a production fixture. Complete reachable authorized work without claiming an end-to-end feature if an external prerequisite is missing. Do not expand this UI slice into an unapproved backend/schema or app-wide Profile rewrite.

## Design Decisions to Preserve

- **Credential, not social profile.** Modest permitted avatar/silhouette, readable handle and optional country, complete badge rail, contextual Elo, compact record. No body/pose media, avatar enlargement/upload, private matches, average appearance score, chat, follow, share, rematch invitation, or third Profile side/indicator.
- **Two time scopes.** This pairing before Go; At match start after authoritative Go. Current public is a separately authorized and timestamped present-day snapshot. Even equal ratings keep both labels. Do not animate one scope into the other or infer intervening transactions from their difference.
- **All awards, always represented.** Wrap every permitted public award above the record. No three-slot cap, +N, carousel, ticker, hover-only detail, or selected-badge preference. Placed/tier can be composite; current streak is distinct from historical Three Straight. Use one F29-F canonical order and actual service state.
- **Native phone sheet.** A large native sheet is the selected default because all awards and readable safety matter more than a half-height peek. Use a measured scrolling body and reachable close/safety controls. The same real timed stage, if one exists, remains available at the top; idle standings have no fake clock.
- **Native Mac details.** A nonmodal trailing inspector when measured readability permits; otherwise the same content is an expanded full-width section within the existing host. At 800 by 600 it must remain usable without raising the minimum. In a paired host, inline details sit after all owner-grouped rails and before the vertical players; in standings, after the selected row. A persistent Hide player details action remains reachable.
- **Protect first.** Revocation, local block shielding, sign-out, and camera privacy apply immediately, not at animation completion. Block after Go does not leave or rerate. Safety forms do not pause deadlines.
- **Tactile but subordinate.** Shared press spring, 160–180-millisecond local changes, about 280-millisecond inspector continuity; native sheet transitions. No extra ambient loop or repeated unlock celebration during profile browsing.

The earlier F29-A text allowing balanced two-column comparisons is superseded by the direct user decision for LARGE VERTICAL players on both platforms. Preserve that direction when integrating the summary. Do not silently solve the older, easier layout.

## What to Build

### 1. Connect legitimate entries and one scoped presentation

Connect the real pairing identity and permitted standings row to one shared summary using the trusted target identity and actual entry context. Repeated activation must not stack sheets or spawn windows. Do not route by mutable handle, use a row index as identity, expose raw identifiers, or guess that being paired grants public listing.

Use the existing presentation owner. Report flow replaces the phone summary presentation rather than nesting another sheet; on Mac the shared report sheet belongs to the real parent window. Returning restores the same still-permitted target and logical focus. If the target/row disappeared, return to a safe surviving heading/row, not whichever account moved into the old index.

### 2. Render truthful identity, country, and complete badges

Use a permitted moderated handle, explicitly authorized avatar or neutral silhouette, and optional manually self-declared country/region with flag beside handle. Expose the full region name and self-declared meaning. Missing/unsupported flags use a neutral globe, never locale/IP/GPS/photo inference or a required picker. Reading must not request any camera, microphone, Photos, location, HealthKit, or contacts permission.

Render all permitted public badges with wrapped labels. Consume F29-F's shared catalog/order: placed/current tier composite, current truthful streak where available, then all earned launch milestones in its canonical order. First Bell and Ten Rounds exclude forfeits/no-contests; placement can include eligible rated forfeits; Three Straight uses C's canonical wins including eligible opponent-forfeit wins and is historical. Corrections can remove awards, including Placed/tier when provisional again. A zero current streak is neutral and can coexist with Three Straight. Unknown or failed badge data is not No badges yet. Unsupported artwork uses safe neutral glyphs with approved catalog labels, not dropped awards or invented meaning.

Provide one inline badge explanation at a time below the complete rail. Activation toggles/replaces that explanation without another custom destination. All awards remain visible in the scroller. Fresh updates do not re-award or replay a result animation on open/restore.

### 3. Separate match context and public record

Show the actual permitted pairing snapshot before Go and frozen match-start rating/placement after Go. Preserve legitimate historical labels only while authorized and keep their time scope explicit. Current public data is separately authorized; show no current section fields merely because a private participant was matched.

Render only permitted current Physique Elo/placement, wins, losses, draws, total rated matches, truthful streak, and complete badge state. Counts have full accessible meanings. No earned result means Unplaced, not the 1,000 seed; provisional progress is actual and has no tier or public provisional rank. No-contests, searches, pending results, practice, and cancellations do not inflate counts; forfeits are subsets of rated wins/losses, not extra matches. Do not expose a new public match list, opponent transactions, peak-rating/win-rate dashboard, body measurement, AI score, confidence percentage, prediction, attire, age, gender, reports, subscription, or private moderation information.

Keep current Elo/record/placement/badges coherent for one authoritative revision. A correction settling state retains only the allowed labeled last-confirmed snapshot. A public summary can say Rating updating, not disclose the private case/reason. Remove no-longer-authorized fields immediately rather than falling back to a stale public cache. Never compute a delta between current rating and match-start rating as supposed private progression.

### 4. Implement complete loading, permission, and account recovery

Implement every relevant state in the product matrix, including first load, partial public fetch with permitted match context, confirmed empty record/badges, withheld fields, offline with/without an allowed saved text snapshot, retryable errors, correction settling/settled, unsupported avatar/flag/badge artwork, rename, unlisting, deletion/unavailability, own-account selection, sign-out/session expiry, and account switch.

A failed refresh preserves only still-authorized coherent content with its real timestamp and reading position; Retry fetches the same target and does not invoke a judge, start a match, or create a case. A denied or revoked authorization is not an ordinary stale-data fallback. Use safe neutral unavailable labels without revealing whether the cause was private listing, a reverse block, a ban, or deletion. Do not flash prior-account data while restoring a new session. Omit self-report/block controls rather than creating disabled fake actions.

### 5. Connect actual independent Report and Block

Report player opens the shared contextual identity/account flow with its real target and legitimate match reference, when present. Do not add screenshots, private media, age/attire fields, or another custom report/case screen. Preserve the shared categories, optional note, retention disclosure, twenty-four-hour bounded text-only draft, duplicate/receipt reconciliation, support, and actual received/unsent/not-confirmed states. Only real acknowledgement becomes Report received. Reporting does not change Elo or accuse the target publicly.

Block uses the shared confirmation naming actual consequences. Before Go it cancels the pairing without Elo change; after Go it shields and prevents future pairing, not automatic leaving or rerating. Revalidate the consequence if Go/finality occurs while confirmation is open. A previously labeled pre-Go cancellation cannot become an implicit voluntary forfeit. Explicit state-aware Exit match remains separate, with no-contest precedence only when established by the trusted service.

On confirmed user action, shield local identity/related media immediately, replace old avatar/country/badges/record with the correct neutral state, and reconcile service protection. Offline/uncertain status is hidden here with block not confirmed; do not claim cross-device or future-match exclusion before acknowledgement or allow a new pairing with unresolved block state. Known safe retry uses the same target. Existing Safety owns unblocking; no instant inline unblock or automatic gallery restoration.

### 6. Integrate real match/camera/window lifecycle

The summary itself never owns or requests a camera. A covering phone sheet or safety presentation stops/shields underlying acquisition through the shared owner immediately; an invalid pre-Go camera/readiness state is reconciled with the service. Return does not take a still or silently restart capture. Any relevant countdown/Go/finality arriving while inspecting updates the real stage/clock and consequence text without throwing away a report draft, playing a celebration, resetting grace/deadlines/retakes, or charging again.

On Mac, preserve the normal title bar and existing commands. Denied/restricted TCC, absent/busy camera, and USB/Continuity disconnect do not prevent permitted public reading and safety. They remain truthful host camera/recovery states, never a fake preview or rated file-picker fallback. Inactive/minimized/background/locked windows stop acquisition and decorative work immediately, shield sensitive context, and restore the same service state before explicit valid resume. A secondary window/device cannot become another match or camera owner.

Escape resolves only the topmost state: cancel confirmation, handle the shared report draft, close badge explanation, or close summary. It is not a global leave/forfeit. Command-W/Quit use the actual active-match consequence confirmation where possible; force quit, crash, and disconnection are not confirmed voluntary forfeits. Return/Space apply only to the focused semantic control and do not fire match/safety actions globally while typing. Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O.

### 7. Accessibility and supporting motion

Implement the documented semantic reading order, full region/badge/metric names, visible focus, live-update announcements, inline disclosure states, and return-focus fallbacks. Use semantic buttons, not broad tap regions; no swipe-only, long-press-only, color-only, hover-only, haptic-only, or icon-only-discovery safety paths. Support largest iPhone Dynamic Type, enlarged Mac text, VoiceOver, Voice Control, Switch Control, Full Keyboard Access, increased contrast, Reduce Transparency, and Reduce Motion. No type clamps or minimum-scale-factor shrinking to save the composition.

Reuse the shared press spring. Keep local changes around 160–180 milliseconds and Mac continuity around 280 milliseconds, interruptible by the latest state and immediate dismissal. Native sheets keep system motion; active timer updates follow the shared real clock around 180 milliseconds with stable digits. Semantic final numbers/actions are available immediately. Reduce Motion uses static values or short opacity, no scaling/travel/count-up; no new loop. Low power/thermal pressure and offscreen/inactive/minimized/background state stop optional work. No per-frame networking, provider work, image decode, sorting, font measurement, global layout invalidation, or camera reconstruction. Protection never waits for a transition.

## Prospective Files to Create or Modify

Resolve actual current paths first and keep one convention. Do not create parallel components because these names are prospective.

- Create `TimeMaster/Views/Physique/PhysiquePlayerSummaryView.swift` only if the integrated feature does not already have the responsible shared view. Own the scoped content and native presentation variants without a generic new framework.
- Modify the actual pairing host under `TimeMaster/Views/Physique/` for summary entry/context, shared presentation, camera/readiness handoff, reachable clock/safe exit, and return focus. Preserve its complete badge rails and vertical players.
- Modify the actual standings host under `TimeMaster/Views/Physique/` for permitted row entry, target-stable inspector/inline placement, current-public scope, safe removal, and return focus. Do not change standings ranking, pagination, or privacy policy.
- Reuse the existing shared Physique identity/summary models, service, state owner, badge components/catalog, and safety router from F29-C/D/E/F. Only small caller/presentation changes necessary for this summary are in scope; do not create local authorities, new schemas, or substitute endpoints.
- Update real Xcode target membership if needed for both native platforms; no deployment-target raise or Catalyst conversion.
- Add or update an existing appropriately scoped test only for a plausible uncertain consumer-visible permission/snapshot/race boundary. Prefer existing conventions; do not add source-text, wiring, forwarding, mock-echo, copied-data, or incidental-default tests.
- Update only the approved F29-A-q implementation items in `CYCLES.md` after connected behavior and focused checks, leaving human review pending. Update the smallest product DOCKS only for accepted product decisions, never for test output or completion evidence. Do not edit other workers' documentation, global Profile, or shared styles to record this task.

No artwork generation, reference-face reuse, new global design document, README, CHANGELOG, production fixture, source-directory documentation, or unnecessary framework wrapper belongs to this slice.

## Observable Acceptance — Native iPhone

- A real paired identity opens the correct target; a permitted standings row opens that same target's current-public scope without a fabricated match. One native large sheet, not stacked sheets or a social-profile destination.
- Both context scopes remain explicit if values agree or differ. Private/unlisted paired accounts expose only their actual permitted context. Current public Elo, record, tier, streak, and badges stay coherent on refresh/correction.
- All permitted badges remain represented above the record, wrapping at the largest Dynamic Type sizes without +N, hidden slots, horizontal ticker, or truncation. Country/flag is optional/self-declared with a neutral truthful fallback.
- No private history, age/attire declaration, pose/body thumbnail, local-avatar upload, fake verification, inferred country, public allegation, or third Profile indicator appears.
- Close/swipe dismiss only the summary. A real active timer/stage and Return to match/Exit match stay reachable when needed; opening/reading does not pause or reset anything. The host remains timer → all rails → large You → large Opponent, not a phone thumbnail duel.
- Report and Block work with real acknowledgement and state-aware consequences; offline is not successful remote protection. Immediate local shielding, permission withdrawal, account switch, and camera stop do not wait for animation.
- Every intended action is reachable with VoiceOver, Voice Control, Switch Control, and supported keyboard interaction. Focus returns to the actual source or safe fallback. Reduce Motion and Reduce Transparency preserve all information and actions.

## Observable Acceptance — Native macOS

- Run the actual native macOS app, not a Catalyst/iPhone simulation. Preserve its normal title bar, commands, multiple-window behavior, and 800 by 600 minimum.
- At 800 by 600 and enlarged text, the readable inline alternative works without covering the real timer/safe actions or shrinking players. On laptop/large/full-screen/external-display windows, the nonmodal inspector and measured readable width work without making participants side by side.
- Live resize retains target/disclosure/focus and does not recreate the camera, repeatedly fetch the summary, or replay awards. Row movement/removal does not retarget the inspector to a different account.
- Pointer, wheel/trackpad, keyboard focus, badge explanations, Report, Block, Close/Hide player details, and shared report text editing are usable without hover-only discovery. Return/Space do not activate destructive/match actions globally; Escape is state-aware; existing command shortcuts remain intact.
- TCC denial, no camera, USB/Continuity disconnect, inactive/minimized/background/locked window, return, Command-W, and Quit preserve the documented truthful lifecycle and same-match recovery. Force quit is not mislabeled as a confirmed forfeit. A second window/device cannot duplicate ownership or charges.
- The same data/privacy, full-badge, public-record, safety, VoiceOver, contrast, reduced-motion/transparency, and low-energy invariants hold; Mac is not a stretched phone modal.

## Focused Native Smoke and Checks

These are future implementation scenarios, not observed results from the documentation batch. Discover the actual schemes/available runtimes and run the smallest relevant build and focused behavioral checks after implementation. Tests alone do not prove the UI; launch and exercise the changed native surface on both platforms where runtime exists.

1. Use authorized consenting test accounts and the real implemented service. Open from pairing and standings, inspect all permitted award states and country fallbacks, and dismiss/reopen. Exercise a historical Three Straight with zero current streak, different match-start/current Elo, a truthful unplaced/provisional state, and a withheld current record where real service state supports them. Do not inject client-invented achievements or fabricate results to make a screenshot.
2. Refresh with a current public change or authorized correction and observe coherent current Elo/record/badges while match-start context remains scoped. Revoke listing/access while open, switch accounts, and remove/block a row. Observe immediate clearing, stable target identity, and correct focus fallback rather than merely checking that the screen did not crash.
3. Interrupt network loading with and without a permitted saved summary. Retry the same target. Exercise actual report receipt uncertainty/unsent state and a pending block, confirming local shielding and no false remote-success claim. Use the shared safe service environment; no unapproved destructive production moderation action.
4. In a real paired flow, inspect across a countdown/Go race and, where available, finality. Confirm actual top clock and state-aware confirmation text, no silent forfeit, no hidden capture, no extra deadline/retake/allowance, and an explicit valid return. Do not extend this into an expensive judge/model experiment or claim a paid call occurred unless it actually did.
5. On a short iPhone and at the largest supported Dynamic Type sizes, scroll all awards/details, reach safety actions, open/cancel the shared report, and traverse with VoiceOver/Voice Control or available assistive input. Repeat Reduce Motion, Reduce Transparency, increased contrast, camera denial, interruption, and return. Name any unexercised physical-device or assistive-input scenario honestly.
6. In the actual Mac window, exercise 800 by 600, laptop size, enlarged text, large/full-screen presentation, live resize between inline/inspector, and an external display when available. Traverse by keyboard and pointer; type Return/Space in the report note; test Escape nesting and preserved shortcuts. Observe the selected identity and focus before/after row removal and resize.
7. Exercise Mac TCC denial and real camera absence/disconnection where hardware exists, including USB or Continuity Camera if available. Minimize, deactivate, background, restore, open another window, and request real close/quit during an active match in a safe environment. Confirm immediate acquisition/privacy handling and authoritative recovery. A simulator or a machine without that hardware cannot prove physical-camera behavior.
8. Observe no offscreen/inactive/minimized decorative activity or duplicate fetch/provider/camera ownership from this summary. Under available low-power/thermal conditions, verify the documented static/reduced presentation and continued authoritative clock/safe actions. Do not infer energy behavior merely from the absence of a compile error.

Use throwaway smoke scaffolding only outside production paths and remove it afterward. Permanent tests must cover plausible behavior, boundaries, transitions, or privacy invariants, not UI wording, forwarding, copied state, mock echoes, or incidental defaults. Do not re-pin obsolete wording/implementation tests. If real service/hardware/access is missing, finish reachable authorized work, state exactly what was tried and what cannot be proven, and do not mark an end-to-end feature complete or replace it with a mock.

## Human Verification Handoff — Required

List separately:

- Pairing and standings entry/presentation integration.
- Legitimate identity, optional country, and complete public badges.
- Match-time versus current-public rating and concise record.
- Loading/offline/revocation/account/correction recovery.
- Real Report/Block and consequence handling.
- iPhone accessibility, dismissal, clock, and camera privacy behavior.
- Native Mac adaptive inspector/inline layout, input, resize, lifecycle, and energy behavior.
- Every changed file, actual focused check/smoke exercised, and any hardware/service/accessibility proof not available.

Ask the user to review the code changes and state which items are ready for human verification. The human remains the final verifier; do not claim acceptance, operational moderation, policy approval, measured judging quality, or unseen device behavior. No screenshot/recording/log bundle or completion evidence belongs in DOCKS. Keep the final engineering handoff concise, factual, and limited to observed checks and explicit risks.

## Mandatory Agent Rules

1. **Single owner, no nested agents.** Do not launch sub-agents, external reviewers, generation workers, or a second independent implementation. Keep this scoped functional slice under one owner.
2. **User direction wins.** Follow the approved native iPhone/Mac, all-badges, large-vertical-player direction over older contradictory text. Surface a real security/product conflict instead of silently redesigning the ask. Do not begin dependent production work before the real contracts are implemented and human-reviewed.
3. **Real data and authority.** No fake peers, local Elo, invented awards/ranks, fabricated receipt/protection, local avatar publication, permissive media fallback, or placeholder/no-op action. Developer previews may use clearly labeled preview-only fixtures, never a production branch, hidden service fallback, or claim of exercised integration.
4. **Reuse ownership and patterns.** No parallel theme, public badge catalog, profile surface, match owner, camera session, presentation stack, or generic framework abstraction. Preserve exercise image privacy, global Profile's two-side shape, existing native commands, deployment floors, and other workers' files.
5. **Complete the authorized slice.** Connect entries, service state, safety, recovery, accessibility, and both native platform paths. Run actual focused native smoke after code, fix clear failures, and report honest missing physical-camera/service evidence. Compiling or adding tests alone is not completion.
6. **Keep planning honest.** Update only approved implementation todos in `CYCLES.md` when connected behavior and focused checks justify it and the code is handed off for human review. Never mark human verification yourself. Product DOCKS remain plain-language product context without code, todos, screenshots, test output, or completion evidence. Update accepted product decisions in the smallest relevant DOCKS after the user accepts behavior.
7. **Scoped commit and push for the future code slice.** After the authorized implementation, relevant checks, and handoff are prepared, commit only this slice's intended changes with a clear message and push to `origin/main`. Do not force-push, rewrite history, stage another worker's edits, or delete user changes. A commit/push failure is an exact reported blocker, not a completion claim. This future rule does not instruct the earlier documentation worker to run git during its coordinated batch.
8. **No pointless next prompt.** Finish small reachable work in this slice. Do not generate a testing-only, obvious-fix, docs-only, commit-only, or push-only handoff. Produce another prompt only if the coordinating owner has approved a genuinely separate substantial implementation slice; otherwise state that none is needed.

## Scope Decision Before Finish

Report completed connected behavior and observed checks; remaining concrete prerequisite or hardware limits; the human-review boundary; whether a next prompt was needed; and actual commit/push status for this future implementation. Do not claim the entire F29 feature is complete because player summary is ready for review.
