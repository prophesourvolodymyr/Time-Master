# Phase 1 of F29-G-d — Authoritative Native Score Counters

## Required Model Assignment

Assignment: **openai-codex/gpt-6-astra:max**.

The model identifier is **openai-codex/gpt-6-astra**. The thinking level is **max**. Do not silently substitute another model or reasoning level. If the requested assignment is unavailable, report that dispatch prerequisite before implementation rather than treating a fallback as this assignment.

This is the engineering/UI worker assignment, not the in-app Physique judge. It does not change the service-approved judging model, per-match judging version, or the current product discussion of GPT-6.1 Sol. Do not call an image generator, change the production judge, or create a second evaluation vote to implement this UI.

## Features Included

- **F29-G-d — Score counters:** distinct category, total, gap, rating, and adjustment presentation; bounded synchronized result choreography; real result/history integration; coherent correction, absence, offline, accessibility, and energy behavior on native iPhone and native macOS.

This is one connected functional slice. It is not permission to rebuild the result screen, badge catalog, camera pipeline, service, Profile, or unrelated native components. A component that works only in a preview is not a delivered slice.

## Context

Physique needs animated sports feedback without presenting invented intermediate scores, confusing category points with Elo, or replaying awards in saved history.
The accepted visual direction keeps the real timer above complete owner-grouped public badge rails and two large VERTICAL participants on both native platforms.
This brief implements the specification only after the real shared result, correction, badge, and host contracts are implemented and human-reviewed.

## What You Need to Read First

Product context, in this order:

- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-d-score-counters/DOCKS.md` — read completely; this is the component's product contract.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md` — integrated component ownership, shared composition, and sibling interfaces. This is main-owned documentation, not permission to create a competing parent.
- `features/F29-physique-duels/DOCKS.md` — Shared Match Contract, Metric Families, service authority, privacy, dependencies, and proposed numerical-policy status.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — Results, Selected-image details, state matrix, focus, lifecycle, platform behavior, and result actions.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Rubric and Score Meaning; Totals, Display Precision, and the Winner Boundary; Accepted Judgements and Non-Scored Outcomes; explanations and motion.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — placement, rating bounds, records, exactly-once finality, correction scope, historical receipts, and offline states.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — hiding, reports, blocking, appeals, and immediate protection.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — consent withdrawal, camera/window lifecycle, authorization, retention, result recovery, and service credentials.
- `features/DOCKS.md` and `CYCLES.md` — locate the integrated F29-F trusted identity/badge contract and actual foundation human-review state. Follow the registered F29-F paths before integration; do not guess an absent sibling filename. Read F29-F's complete collection, unlock, removal, placement, historical/current labeling, and optional-country semantics.

Installed skills and current platform guidance:

- `skill://swiftui-pro`, then `skill://swiftui-pro/references/accessibility.md`, `skill://swiftui-pro/references/performance.md`, and the directly relevant state/API guidance if needed.
- `skill://swiftui-animation` — scope state-driven motion, interruption, and reduced motion. Its newer examples are not a deployment-target decision.
- `skill://apple-hig-reference` — use the relevant current Apple chapters below, not an assumed offline HIG snapshot.
- The main owner already selected **dimillian/swiftui-ui-patterns** through UI Skills. Reuse that selection/context; do not repeat CLI setup for this assignment.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — Best practices and Providing feedback.
- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — window resizing, large-display density, native inputs, full screen, and commands.

Existing source anchors; inspect relevant sections rather than copying their assumptions:

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — near-black surfaces, toolbar orange, shared card/action language.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — scalable Inter styles, spacing, touch target, readable width.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material availability and opaque fallback, Reduce Transparency, shared press spring with response 0.24 and damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — labeled native actions, metrics, and earned crest language. Do not copy Dynamic Type clamps, small-text scaling, fake levels, or exercise-scoped labels.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — existing exercise HUD only. Physique has no live provisional physique score and must not reuse its competing live lead bar.
- `TimeMaster/App/TmaxApp.swift:8-19` — native WindowGroup, normal title bar, existing 800-by-600 Mac minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Command-N, Command-Shift-R, Command-comma, Command-Option-O, and text editing.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — local cosmetic badge previews are not trusted achievements or verification.
- `TimeMaster.xcodeproj/project.pbxproj` — locate actual application target deployment and membership settings. Retain iPhone iOS 16 compatibility and native macOS 14 compatibility; do not adopt the newer OS defaults in skill examples or change another target's settings.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow the direct sports hierarchy and top timer, not the side-by-side layout, pill colors, faces, video, or assumed asset rights.

There is no project `STYLES.md` in the supplied design context. Reuse the actual source style owners; do not create a global design file. Discover implemented Physique model, service, result/history host, identity rails, and lifecycle sources through the repository before reading or editing them. Prospective paths below are not evidence that a file exists.

DOCKS files are plain-language product context, not implementation authority. Validate technical direction against the current source, native framework availability, and service contracts. Never add Swift, pseudocode, transport payloads, implementation recipes, test output, or completion evidence to a DOCKS file.

## What Happened Last Session

A documentation-only coordinated batch chose a concrete native counter composition and wrote this implementation brief and its child DOCKS. It did not write Swift, integrate a service, create art, run native builds/smokes, or claim human approval of an implementation. The main owner coordinates the G parent, other children, shared documentation, CYCLES, integrated validation, and publication.

The user approved both native platforms, the top-timer/all-badges/large-vertical-player direction, and a tactile minimal-text sports UI. Earlier numerical defaults remain product proposals owned by B/C/F. The older F29-A optional two-column desktop wording and simple result fade must be read in light of that explicit newer direction; they are not authorization to revert the vertical composition.

## Prerequisites and Review Boundaries

Before code, establish all of the following from the actual repository and human-review record:

- The shared authenticated Physique result state is real and distinguishes pending finality, valid judged results, eligible forfeits, no-contests, unavailable details, and account/permission failure.
- B/C shared domain contracts retain accepted whole-category scores, exact one-decimal totals/gap, service-owned outcomes, own actual rating inputs/effective delta/settled after value, judging/rating versions, and correction identity/revision. A raw model answer is never fed directly into this view.
- Result and correction application are service-owned and exactly once. Correction settling exposes a coherent last-confirmed state, and settled corrections distinguish original match settlement from later current-account adjustment.
- The result/history host exists on native iPhone and native macOS, owns routing and safe actions, and supplies the current scene/account/match presentation context. Its actual behavior has been handed to and accepted by the human as the dependency requires.
- F29-F supplies real permitted complete badge collections, trusted placement/tier/streak state, new-unlock/removal facts, optional self-declared region, historical/current labeling, and unknown/stale states. Local profile badge previews are not a substitute.
- The shared native stage, timer, identity rails, player panels, privacy lifecycle, and camera/session ownership are implemented and human-reviewed to the extent this component consumes them. Verify independence before changing any shared integration file.
- The authorized service environment and safe test identities needed for a connected result smoke are available. Do not expose credentials, use production participants as fixtures, or upload a new body image merely to exercise a number transition.

A missing real foundation is a named prerequisite, not permission for local Elo, stub callbacks, placeholder public badges, a mocked production API, a standalone demo, or a newly invented result route. Resolve information discoverable in tools/context yourself. If prerequisite implementation or human acceptance is genuinely absent, report the exact missing contract/review to the owner before starting dependent code; do not mark this UI implemented. Missing physical-camera hardware limits camera proof, not the ability to complete available noncamera work once the real contracts exist.

## Concrete Design Decisions

1. **Single-stop roll, not arithmetic count-up.** Publish the actual digits immediately. Move only the final glyphs a short distance into their resting baseline. Cycling through numbers would display scores that never existed and can momentarily contradict the draw boundary.
2. **Fixed score endpoints.** The full accepted extent of each zero-to-100 rail is visible from the first frame. A subtle fill sweep remains inside that extent. Category lanes use the same scale, not each participant's percentage of a shared pot.
3. **Gap is the static proof anchor.** Show one decimal throughout. Do not animate through 2.9 and 3.0, derive a leader from rail widths, or change the outcome while decoration runs.
4. **Elo is a separate receipt.** Before, signed whole effective change, and After belong to the own account. No morph from score to Elo, no opponent-private transaction, no inferred balancing delta, and no rating engine in the UI.
5. **One shared envelope.** Score reveal ends by 650 milliseconds; own Elo uses a 450-millisecond phase inside it; one eligible crest/badge emphasis ends by 900 milliseconds. Navigation and accessibility never wait.
6. **Two large vertical players everywhere the battle composition exists.** Mac width is used for comfortable margins and optional native detail inspection, not for a horizontal matchup. All authorized public badges remain above both players.
7. **One emphasis target, truthful rewards.** A newly confirmed badge group has priority over a changed placed-tier crest, which has priority over an existing placed crest on a positive settled gain. Other changed facts update statically. No pulsing wall, loser shake, reward claim from an animation, or separate badge catalog.
8. **No new decorative timer or ambient loop.** The real host clock retains authority. This component introduces no repeating work or artificial waiting period.

These are design decisions, not a request for private reasoning or an alternative-design essay. Preserve their outcomes while choosing a boring implementation that fits current architecture.

## What to Build

### 1. Explicit numeric and semantic boundaries

Consume the shared domain's distinct accepted category-point, total/gap-tenths, absolute Elo, signed Elo-change, and review-adjustment meanings. Do not funnel them through a generic floating-point metric whose meaning depends on a label. If domain types already exist, reuse them. Do not duplicate the transport model or silently alter a shared owner contract; a missing domain distinction is a prerequisite to resolve with the foundation owner.

Maintain exact accepted tenths for totals and gap rather than floating interpolation and repeated rounding. This is presentation precision, not permission to recompute a service outcome. Categories display whole points; totals and absolute gap always display one decimal in this surface; Elo and review adjustments display whole signed points. Use a typographic minus and plain zero with Unchanged, never negative zero. Preserve locale-specific formatting and reading direction without changing semantics.

Render valid zero and upper-bound values honestly. Zero has an empty score rail, not a minimum decorative fill. One hundred fills the actual scale without overshoot. Whole-rating bounds and any effective clipped change come from C's settled receipt, not local clamping. A draw with unequal ratings may increase or decrease Elo; a win at a bound may have zero change. Do not color or sign the change based solely on Won/Lost/Draw.

Before a first earned result, do not present the proposed 1000 pairing seed as earned Elo. The first receipt labels the after value First earned rating, with the exact service input available in details as Pairing seed — not earned. Show actual provisional progress; no placed tier until confirmed. Keep the opponent's permitted match-time rating separate from the own receipt.

Unsupported precision, missing required numbers, invalid ranges, mixed revisions, or unavailable settlement do not become zero or a locally repaired winner. Use the real domain absence/error state. If an independently confirmed outcome can be shown while its details are unavailable, keep that heading and mark the entire affected score or receipt group unavailable. Otherwise retain the coherent last-confirmed state or Result pending as appropriate. Retry retrieves the same service record, not another judgement.

### 2. Connected native composition

Integrate with the real result/history host, not a new screen. Required order:

- Real top clock with genuine stopped/ended state at finalization, plus concise outcome heading. If saved timing is unavailable, the host presents its explicit unavailable clock state rather than guessing zero or restarting a timer.
- All owner-grouped public identity/badge rails: You then Opponent, complete and wrapping, above both large players.
- Large You panel followed by equally prominent large Opponent panel. Aspect-fit authorized content, equal treatment, no body cropping or face/limb overlays. Score footers sit outside image bounds.
- Static one-decimal Gap, then separately scoped own Physique Elo receipt.
- Four category groups as reusable content composed by canonical F29-A-m Score breakdown: full category name, explicit Weight, You then Opponent whole points, and equal-scale rails. Do not force these groups onto compact F29-A-l Result.
- Host-owned Details, safe Close, Safety, intentional View poses when authorized, and explicit eligible Find another opponent routing.

Result immediately exposes confirmed totals, gap and own receipt, then routes to the canonical Breakdown destination. That destination presents the four category pairs, full rubric meaning, explanations and version through its actual owner. The counter worker supplies reusable numeric presentation, not another score-detail screen or a second disclosure competing with F29-A-m. No value waits for a reveal or image opening.

On iPhone, preserve native navigation, measured safe areas, the existing 44-point interactive-control convention, landscape/short-window scrolling, display zoom, and full accessibility font growth. Long names and before/change/after can wrap onto separate labeled lines; do not shrink participants or clamp type to keep everything above the fold.

On macOS, support the existing native 800-by-600 minimum, short laptops, large/full-screen windows, external displays, and live resize. Preserve normal title bar and toolbar behavior. Keep the central stage vertical and scrollable, with timer and safe actions reachable. Optional native Details inspector content must remain reachable in a sheet or inline disclosure when width is insufficient; an inspector must not displace essential totals or create side-by-side player panels.

Use native pointer states, text selection where the detail surface permits it, Tab/Shift-Tab navigation, visible focus, and focused-control Return/Space. Escape dismisses the topmost transient surface before closing a terminal result; it does not silently forfeit a still-active host. Preserve existing menu commands and text editing. Command-W/quit uses actual active-match consequences where supported, no competitive penalty after finalization, and no claim to intercept force quit.

Result reading never requests camera permission. Camera/TCC denial, no camera, external/Continuity disconnect, or a camera busy elsewhere must not block authorized saved results. A later new match returns to the real setup/recovery flow with no file-picker or fake-camera fallback. Honor one active account/match/camera owner across windows and devices; secondary windows do not claim another reveal or session.

### 3. One bounded reveal with immediate truth

Publish final semantic values before decorative work. Do not use animation completion to publish scores, change outcome, enable navigation, send settlement acknowledgement, acquire an award, fetch a required service state, or update a badge.

Use this common timeline from the original confirmed result event:

| Timing | Required effect |
| --- | --- |
| Immediately | Final outcome, all available final numbers, accessible values, units, permissions, and safe actions. |
| 0–280 ms | Coordinate with the host's existing stage continuity without hiding the final content or changing player order. |
| 0–220 ms | Final total/category glyphs make one short ease-out settle, at most 15 percent of text line height. Keep whole final glyphs legible from the first frame; labels, decimal precision, and units stay fixed. No intermediate numerical reading. |
| 0–650 ms | Subtle score-rail fill inside final, already visible extents; shared progress, no moving leader marker or overshoot. Zero has no sweep. |
| Always static | Outcome and one-decimal absolute gap. No inferred interim winner, draw, or lead. |
| 200–650 ms | Separate 450-ms own-Elo final-glyph settle. Before, sign, and Physique Elo scope remain fixed; zero stays static Unchanged. |
| 600–900 ms | At most one trusted badge-group emphasis or placed-crest response. A crest scales no higher than 1.03 and settles with a heavily damped spring; no new crest appears for provisional/unplaced state. |
| At correction | Immediately replace the effective state and remove invalidated content; at most 180 ms of neutral notice/surface opacity. No numerical interpolation, reverse award, or celebration. |

No serial 650-plus-450-plus-badge delay. A late badge event must not restart or extend the interval; apply it with a quiet ordinary state update. F29-F decides badge eligibility and ordering, including the differing forfeit rules for First Bell, Ten Rounds, Placed, and Three Straight. Do not calculate those policies in a view.

Use the existing shared press feedback rather than a second spring style. Add no ambient loop, camera shader, scanning line, flashing, confetti storm, pulsing wall, slot-machine digits, humiliation, or result suspense. If an existing preference allows a supported iPhone haptic, use at most one quiet cue for the eligible original event; there is no required sound or new permission.

### 4. Eligibility, revision, and cancellation

Drive the reveal from the real original finalization while the original active-match presentation owner is visible and foregrounded. Scope it to the owning account, match, and authoritative result revision/event, using the shared lifecycle conventions. Do not trigger it from view appearance, a score difference, a row becoming visible, a network refresh, or a property observer that cannot distinguish history from live transition.

Reuse existing session/result identity to suppress duplicates and coordinate windows. Avoid a new server endpoint, durable reward system, or unbounded animation receipt log solely for this effect. Presentation bookkeeping is not a competitive ledger. History, deep links, relaunch, result restoration, secondary windows, and recovery after background/offline all display static results even if the original animation was missed.

A newer correction cancels an in-flight reveal and replaces the effective snapshot coherently. Ignore obsolete revisions according to the shared state owner. A pending review is not a correction. During correction settlement, retain labeled last-confirmed numeric groups, show Rating updating after review, and respect the host's disabled new-rated-entry rule. Once settled, expose the original match receipt and the later current-account adjustment with separate labels. Do not rewrite intervening historical matches or infer a current Elo from an old receipt.

Immediately remove invalidated badges or placement labels through F29-F's state; do not leave a removed award visible until a fade completes. If its control was focused, transfer focus to the surviving owner heading or correction notice. Preserve every remaining authorized badge above the players.

Navigation away, opening Details or Safety, offscreen movement, disruptive live resize, background/minimize/inactivity, locking, account change, permission/privacy interruption, Reduce Motion activation, or an energy constraint settles/cancels decorative work. Reentry never resumes it. Offscreen categories appear final and still when scrolled into view. Do not steal focus from an open sheet, report, or text field when a result arrives behind it.

### 5. Accessibility and energy

Expose the final semantic values only once to accessibility. Decorative bars and any render-only glyph copies are hidden from accessibility. Read the participant, category, whole points, weight, total, absolute gap, outcome, judging version, and own Physique Elo gain/loss/unchanged meaning in a logical order. The sign is not the entire accessible description.

Move accessibility focus once to the unobscured final-result heading when the live waiting stage changes. Provide one concise result announcement, not a stream of digits, timer ticks, or every badge. Refresh and animation completion make no new announcement. A meaningful correction gets one concise update without displacing an active report/text interaction. Return focus when details dismiss; give removed controls a meaningful surviving focus destination.

Keep visible labels, sufficient contrast, participant identity, and non-color outcome meaning. Support VoiceOver, Voice Control, Switch Control, Full Keyboard Access, largest text, long localization, and right-to-left number/unit grouping. Static scores are not focusable fake actions; Details, Retry, Close, Safety, and authorized host actions are actual semantic controls. No hover-only explanation, precision gesture, required long press, or replay affordance.

Reduce Motion uses immediate final glyphs and filled rails, with at most 120 ms of status-container opacity. Remove glyph travel, sweeps, springs, scale, and loops. Reduce Transparency uses the established opaque readable surfaces. Low Power Mode where supported, serious thermal pressure, and the existing equivalent energy-saving state use the same static path. Observe changes during an active reveal and settle immediately.

No unnecessary per-frame formatting, string allocation, font measurement, image decoding, service work, sorting, body-wide invalidation, camera rebuild, or layout measurement. Prepare formatted final values when the authoritative snapshot, locale, or text environment changes. Animate only the small render properties that actually move. Keep cleanup/cancellation tied to the existing view/scene lifecycle. No animation should leave an idle display-link or repeating timer behind. Camera shutdown, privacy shielding, and authoritative deadlines never wait for decoration.

### 6. Real safety, privacy, and absence behavior

Honor the child DOCKS state matrix completely: pending, unavailable details, scored win/loss/draw, valid zero and upper bounds, positive/negative/zero Elo, first earned/provisional/placed, both forfeit perspectives, no-contest/restoration state, duplicate/history/recovery, cached/uncached offline, pending/settling/settled review, stale/unknown/removed badges, media revocation, unavailable identities, and account changes.

Do not present no-contest as a draw, absent scores as zeros, missing history as empty, or an offline draft as a submitted report. No-contest/forfeit has no score meter or counterpart gallery. Retry reads the existing match and safe result state; there is no model reroll.

Before finalization, opponent content is permitted avatar/silhouette and actual stage/count, never live video or early pose thumbnails. Own preview stays local. Only a valid judged result with current permission and intentional View poses can expose moderated stills. Expiry, removal, hide, report, block, or withdrawal protects immediately; no retained animation layer may show the last sensitive frame. Ordinary 24-hour expiry is unaffected by the reveal or history visits.

Do not send country, badges, Elo, handles, UI chrome, or an app screenshot to the judge. Do not add automatic avatar upload, image-based identity/age/sex/gender/medical inference, screen replay, image-bearing telemetry, provider keys, or image export. Preserve local fail-closed face obscuring and bystander rejection in the host. Block after Go shields/excludes future pairs but does not by itself end the match or rerate it.

## Files to Create or Modify Prospectively

Discover the implemented feature structure first and reuse an existing component if it already owns this responsibility. The following are scoped intended locations, not a requirement to duplicate present code:

| Location | Intended responsibility and boundary |
| --- | --- |
| `TimeMaster/Views/Physique/Components/PhysiqueScoreCounters.swift` | Native accepted score/total/gap and own rating-receipt rendering, with accessible semantics and real absence states. |
| `TimeMaster/Views/Physique/Components/PhysiqueResultReveal.swift` | Small feature-local presentation choreography and cancellation. Not a general animation framework, service, or settlement engine. |
| The actual implemented result/history host under `TimeMaster/Views/Physique/` | Minimal connected adoption and callbacks; preserve existing routes, timer, player hierarchy, safety, and permission handling. Discover exact files through the integrated G/A ownership map before edits. |
| Existing implemented trusted identity/badge presentation | Consume its confirmed data and coordinated emphasis hook; do not fork the rail or badge catalog. A shared-file change requires the owner's coordinated scope, not opportunistic parallel editing. |
| Existing feature test target and native smoke harness, if present | Only consumer-visible numeric, revision, replay, cancellation, and accessibility behavior. Do not create a new app architecture or test framework. |
| `CYCLES.md` | Update only the approved F29-G-d implementation/human-review handoff items after connected work and focused checks. Do not reorganize unrelated cycles. |

`TimeMaster/Models/PhysiqueDuelModels.swift` and `TimeMaster/Services/Physique/` are shared foundations to inspect and consume, not authorization to create a second model/service convention. `Theme.swift`, `ProfileDesign.swift`, shared controls, `TmaxApp.swift`, and `TmaxCommands.swift` are integration/style references, not default edit targets. Add required native target membership using the current project convention without unrelated project-file churn or deployment raises.

The documentation-only batch that authored this brief authorized exactly its child DOCKS and this prompt. The prospective implementation scope above begins only in a separately authorized implementation session after prerequisites, not during that batch.

## Observable Acceptance — Both Platforms

| Scenario | Required observable result |
| --- | --- |
| First connected scored result | Correct perspective, final outcome, both accepted totals, absolute gap, all category values, own actual receipt, and actions are available on the first result frame; one bounded reveal only. |
| Proposed draw boundary | An accepted 2.9-point gap displays Draw; an accepted 3.0-point gap displays the service's winner. Totals and gap retain one decimal during the entire reveal; there is no temporary contrary winner or abbreviated whole-number boundary. |
| Numeric edge values | Valid category zero/100, total 0.0/100.0, gap 0.0, negative Elo delta, unchanged delta, bound-limited settlement, and long localized formatting remain correct and unclipped. Missing/invalid data does not turn into a legitimate zero. |
| Domain distinction | Score rails stay points out of 100; rubric percentages are explicitly weights; Elo uses whole signed points and separate before/after context. No live score, confidence percentage, medical measurement, or score-to-Elo conversion appears. |
| Draw and rating mismatch | A draw with nonzero actual Elo change and a win with zero bound-limited change retain the correct independent meanings. Opponent-private changes are not inferred. |
| Placement and badges | First earned rating does not imply an earned seed; provisional has no placed crest. All permitted badges wrap above both players. Confirmed removal can return placed to provisional/unplaced without retaining a false entitlement. |
| Forfeit and no-contest | Correct perspective and real rating/restoration effect; no invented total/category zeros, draw medal, body-superiority explanation, or pose gallery. |
| Duplicate and history | Refresh, duplicate events, reopening, deep link, relaunch, second window, and interrupted-result recovery preserve the same settled effect with no reward replay, extra charge, or badge grant. |
| Correction while rolling | Old decoration stops immediately. The newest coherent effective outcome/receipt and badge facts replace it; no mixed revision, reverse celebration, older rollback, or mutation of later valid matches. |
| Correction pending/offline | Labeled last-confirmed state, accurate pending status, safe Retry, and no new rated seed while unsettled. No apparent completed reversal before authoritative settlement. |
| iPhone layout | Short/landscape/zoomed phone and maximum accessibility text keep real timer and safe actions reachable, complete rails above large vertical players, readable units, aspect-fit content, and native details. |
| Mac layout | At 800 by 600, short laptop, large/full-screen, external-display, and during resize, both participants remain large and vertical. Scrolling, native inspector/sheet fallback, title bar, toolbar, focus, and existing commands remain usable. |
| Keyboard and accessibility | Focused Return/Space only; state-aware Escape; no disrupted report typing; correct focus restoration. VoiceOver reads final values once without interpolation/tick spam. Voice Control/Switch Control/Full Keyboard Access can operate every real action. |
| Motion and energy | All eligible decoration finishes within 900 ms total. Reduce Motion and energy constraints show identical static information. Toggling settings, going offscreen/inactive/minimized/background, or navigating away cancels work with no replay on return. |
| Camera/window privacy | Results need no camera/TCC permission. External/Continuity disconnect and multiple windows preserve the real session owner, stop/shield acquisition immediately where relevant, and do not reset any deadline or allowance. Force quit is not recorded as confirmed forfeit by this view. |
| Media and account protection | Hide/report/block/withdrawal/expiry immediately removes protected media even during animation. No gallery without current permission and intentional action. Sign-out/account change clears the previous private content and reveal state. |

Boundary records for isolated numeric checks may be clearly labeled test-only accepted-record fixtures; they are not real judged people and must never enter production as fallback data. Do not force a paid judge to produce exact values to test formatting. Conversely, fixture rendering is not proof of real service authority, camera/privacy behavior, or connected finalization.

## Focused Native Smoke, Accessibility, and Energy Scenarios

Run the smallest relevant existing build/test paths, then launch the actual changed native surface. Compiling, source inspection, and an unrun test list are not behavioral proof. Do not rerun a user-reported failure merely to confirm it; treat it as evidence and exercise the repaired path after the change.

1. Use an authorized isolated real shared service/account environment and an existing accepted result to open the connected result/history host on both native iPhone and macOS where runtimes exist. Observe exact numbers, own receipt, known finality, permitted badges, action routing, and a refresh/reopen with unchanged service settlement. Do not add a production fake-data switch or insert review accounts into unrelated persistent user data.
2. Exercise one real foreground finalization through the implemented host. Observe immediate final information, synchronized short motion, usable Close/Details/Safety during motion, and no repeated reveal after history/recovery. If live finalization requires unavailable service permissions or consenting camera participants, name that missing proof explicitly; a standalone harness does not replace it.
3. Use the existing isolated native component harness, or a throwaway one if necessary, for exact 2.9/3.0 gaps, zeros, bounds, signed changes, missing details, draw-with-nonzero-Elo, duplicate revision delivery, and a correction interrupting the reveal. Bind the production component to clearly labeled test-only accepted records; do not mock a production service or claim those records came from a judge. Remove throwaway scaffolding after use.
4. On iPhone, exercise a short available simulator/device, landscape, display zoom where available, maximum text, the native detail sheet, and safe action focus. On native Mac, exercise 800-by-600 and short resized windows, full screen, larger display geometry, optional inspector opening/closing, pointer focus, Tab/Shift-Tab, Return/Space, Escape, and preserved app commands. Test actual external-display movement where hardware exists; otherwise identify that limit.
5. Use VoiceOver on each available runtime to inspect final grouped values, one result announcement, correction notice, and focus restoration. Exercise Full Keyboard Access, supported Voice Control/Switch Control paths, long text, and non-color meaning to the available extent. Do not label source-only accessibility assertions a VoiceOver smoke.
6. Enable Reduce Motion and Reduce Transparency before a result, then change motion preference mid-reveal where practical. Exercise low-power/thermal-adaptive behavior using supported device settings or clearly labeled isolated lifecycle inputs, distinguishing simulation from actual hardware evidence. Background/minimize/inactivate the window, reopen the same result, and verify that no delayed sweep, roll, or award restarts.
7. Use a focused native performance observation if tooling is available to confirm that decoration stops offscreen/inactive and no repeating invalidation survives settlement. Inspect the changed path for per-frame formatting, allocations, decoding, or camera reconstruction. Do not add telemetry or a broad performance project for this component.
8. Exercise permission/access removal and account switch during the result through the real available foundation. Verify immediate media shielding and no prior-account values after return. Result viewing must still work when camera permission is denied. Exercise external/Continuity camera disconnection in the host only if physical hardware exists; state the exact missing physical proof otherwise.

Permanent tests should target plausible consumer-visible failures: numeric domain precision, unavailable-versus-zero distinction, stale correction precedence, cancellation/reentry, and award replay prevention. Reuse existing relevant tests, add new ones only for uncertain edges, and keep them deterministic and isolated. Do not add tests of source text, copied constants, mock echoes, initializer forwarding, wiring counts, or incidental wording. Do not re-pin implementation-detail tests just to make this change pass.

If a supported native runtime is unavailable, finish all reachable implementation and checks and identify precisely what could not be exercised. Do not call an unlaunched platform verified, a simulator a physical camera, or a two-platform compilation a two-platform interaction check. Any missing end-to-end service prerequisite remains explicit; there is no completion claim based on a compiling preview.

## Human Verification Handoff — Required

List separately:

- Numeric domain/formatting and accepted-score presentation.
- Connected result, receipt, and real result/history adoption.
- Synchronized once-only reveal and crest/badge coordination.
- Pending/offline, zero/negative/bounds, review/correction, and unavailable states.
- Native iPhone composition and interaction.
- Native macOS window, inspector/sheet, pointer, keyboard, and lifecycle behavior.
- Accessibility, reduced-motion/transparency, energy, and immediate privacy cancellation.
- Every changed source, target-membership, test, and planning file, plus any deliberately unchanged shared owner boundary.

Ask the user to review the code changes and both native behaviors; state which items are ready for human verification. Report only checks actually run, the observed outcomes, and exact runtime/hardware/service gaps. Do not imply human acceptance. No screenshot package, screen recording, private result transcript, or evidence dump is required.

Update implementation/human-review tracking only in the approved `CYCLES.md` items. A completion checkbox records implementation, not human verification, and requires connected behavior and focused checks. DOCKS remains plain-language product context without todos, logs, screenshots, or completion evidence. After the user accepts a changed product decision, update the smallest relevant DOCKS; do not rewrite product documentation to conceal an implementation gap.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do this slice yourself with the exact assigned model/thinking level. Do not launch child agents to design, implement, or review it. Coordinate shared files with the main owner; do not edit another worker's live target.
2. **User direction wins.** Preserve both native platforms, real top timer, every public badge above two large vertical players, and concise tactile sports presentation. Follow explicit newer direction over older optional horizontal-layout wording; surface any actual unavoidable conflict.
3. **Real shared foundations first.** Confirm implemented, human-reviewed result, correction, badge, and host prerequisites. No production mock, sample rival, generated score, local rating award, no-op callback, stub, decorative-only route, or fake camera. Test/preview fixtures must be explicitly isolated and labeled.
4. **Scope stays F29-G-d.** No backend rewrite, judge change, extra screen, parallel theme, private API, target raise, badge-catalog fork, unrelated Profile change, new tracking, or generated artwork. Remove obsolete same-slice code/callers when cutting over; do not preserve redundant paths as shims.
5. **Use existing patterns and public compatible APIs.** Read current source before edits. Reuse the exact native styles and lifecycle conventions; check availability rather than copying a skill's newest APIs. Keep numeric meaning separate from ephemeral render state.
6. **Immediate truth and privacy.** The service owns finality, corrections, and rewards. Animation cannot delay semantics, navigation, camera shutdown, hiding, blocking, or permission revocation. Keep exercise image privacy and all physique media-access boundaries intact.
7. **Complete and exercise the whole connected slice.** Build, run focused relevant checks, launch the changed native surfaces, fix clear failures, and report genuine limitations. No handoff consisting of scaffolding, future wiring, obvious bug fixes, or a testing-only next prompt.
8. **Planning and documentation integrity.** Update only approved implementation todos in `CYCLES.md`; no duplicate IDE task system. Keep human acceptance separate. No verification evidence or code-form recipes in DOCKS.
9. **Scoped commit and push in the implementation session.** After a completed checked implementation slice, commit only owned changes with a clear message and push to `origin/main`. Do not sweep in another worker's edits, force-push, or rewrite remote history. If the push fails or authorization is unavailable, state the exact blocker and do not call publication complete. The earlier documentation-only batch is committed by its main owner, not by child workers.
10. **No pointless next prompt.** Finish small remaining work now. Create another prompt only for a genuinely separate, substantial, authorized functional slice, not for testing, a commit, an obvious fix, or this component's missing production wiring. Never describe a remaining prerequisite as completed.

## When You Finish

Return the implementation handoff above with every changed file, exercised checks, residual limitations, scoped publication status, and a request for human review. State whether another prompt was actually needed. Do not claim that this prompt's existence, a screenshot, a preview, or successful compilation proves the complete product.

## Scope Decision Before Finish

- **Completed:** name only connected behavior implemented and actually exercised in this session.
- **Remaining:** name genuine unimplemented scope, human-review boundary, or missing runtime/hardware/service prerequisite; do not silently narrow the assignment.
- **Decision:** no next prompt when this slice is complete; otherwise explain the real prerequisite or separately authorized substantial next slice. Do not stop at an internal phase boundary while actionable work remains.
