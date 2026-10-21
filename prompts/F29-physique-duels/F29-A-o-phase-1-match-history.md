# Phase 1 of F29-A-o — Native Private Match History

## Execution Assignment

Assigned model: **openai-codex/gpt-6.1-sol**. Thinking level: **max**. The effective worker assignment is **openai-codex/gpt-6.1-sol:max**; max is the reasoning setting, not another model name. Run one implementation owner with this assignment. If the execution environment cannot provide it, report the actual limitation before starting; do not silently downgrade, substitute another model, or invent a successful dispatch.

This assignment governs the coding specialist only. It does not choose, upgrade, rerun, or configure the in-app physique judge. The trusted judging policy remains owned by F29-B and the real service.

## Features Included

- F29-A-o — The authenticated participant’s private Physique match-history ledger.
- Compact exact-match rows with honest judged, forfeit, no-contest, pending, review, and correction meaning.
- Real twenty-row stable-snapshot paging, explicit Show latest, and correct refresh/recovery behavior.
- Text-only iPhone inline summaries and an adaptive native macOS inspector/inline presentation, preserving selection, focus, and scroll.
- Exact-match routing to the existing canonical result, pending match, and contextual safety/case owners.
- Account-safe nonmedia restoration, immediate private-content shielding, accessibility, and restrained event-driven motion.

These are meaningful parts of one history slice, not permission to rebuild the lobby, score screen, pose gallery, account system, camera, badge engine, or Rust competition foundation. List each implemented part separately in the human handoff and update only its corresponding implementation todos in CYCLES.md. A documentation file, compiled view, or preview is not proof of a connected feature.

## Context

The documentation-only design batch specified a native private sports ledger, not a body-photo gallery or miniature battle screen. This phase connects that design to reviewed real account, history, finality, privacy, result, and safety foundations. It must preserve the separate Physique competition and all existing exercise privacy and navigation behavior.

## What You Need to Read First

Read before planning edits; use the feature documents for product context, not as unverified implementation recipes.

### Product and review boundaries

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-o-match-history/DOCKS.md` — complete owner specification; read all of it.
- `features/F29-physique-duels/DOCKS.md` — shared lifecycle, separate rating domain, privacy, and policy risks.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — lobby/recent-match entry, canonical result, pending recovery, safe exit, and return focus.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — accepted score meaning, one-decimal totals/gap, judging versions, and non-scored outcomes.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — especially Authoritative Finality, Outcome Disputes/Corrections, Private Match History and Detail, and Loading/Empty/Offline/Review States.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — contextual safety entry, hide/block/report semantics, real receipts, case privacy, and competitive appeals.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — account access, cache boundaries, revocation, gallery permission and expiry, deletion, and service availability.
- `features/DOCKS.md` — find the final accepted F29-F trusted identity/badge context and the accepted shared native UI contracts; follow the registered exact paths rather than guessing new folders.
- `CYCLES.md` — current F29 review status and the approved implementation scope; the documentation pass did not approve the pending account/service dependencies.
- The finalized shared F29 native design contract supplied by the integrating owner. The original design-batch copy was `/Users/volodymurvasualkiw/.omp/agent/sessions/-GSpace-Personal -Time-Master-TimeMaster/2026-10-21T00-19-17-586Z_01a15bd3-9dd2-76b3-99be-62dda3a44d09/local/f29-ui-design-contract.md`; that absolute path was batch-local, not a production dependency or an assumed future local artifact scope.

### Existing source and visual anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — near-black surfaces, shared actions and toolbar orange.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — scalable Inter typography, spacing, readable width, and touch conventions.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material availability fallback, Reduce Transparency, and press spring response 0.24/damping fraction 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — established sports action and earned-Elo language; do not copy Dynamic Type clamps, minimum-scale shortcuts, or exercise crests as Physique authority.
- `TimeMaster/Views/Ranked/RankedMatchHistoryView.swift:1-177` — existing history idioms and selection/account context. Do not copy its exercise/practice modes, score-zero defaults, periodic head-page refresh, or old/new page merging into the Physique snapshot contract.
- `TimeMaster/Services/Ranked/RankedAccountStore.swift:1-120` — synchronous account-change clearing and request-generation boundaries.
- `TimeMaster/Services/Ranked/RankedAPI.swift:1-124` — authenticated shared account, account-scoped recovery, ephemeral transport, cancellation, and superseded-request handling. These are patterns, not Physique endpoint definitions or a second login lifecycle.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — nearby exercise HUD only; no live provisional physique score, horizontal player composition, or body-quality meter is authorized.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local cosmetic badge previews are not competitive achievements or verified identity.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar, and existing minimum 800 by 600.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O.
- `TimeMaster.xcodeproj/project.pbxproj` — preserve current native iPhone compatibility, including the iOS 16 baseline, and native macOS 14 target. Check APIs at their actual availability; do not raise deployment targets for this view.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual image. Its direct timer/identity/player hierarchy informs the shared battle, not a license to use its people, side-by-side layout, purple/brown web badges, or text as app assets.
- The actual reviewed Physique model, service, navigation, result, and safety source discovered from the current feature tree. Read those current files and contract tests before choosing symbols or routes; prospective paths below are not proof they already exist.

`STYLES.md` was absent at the documentation pass. Do not create a new global design file to compensate. Use existing source conventions, checking whether a later approved style file now exists through the registered project context.

### Relevant skills and primary guidance

- `skill://swiftui-pro`, selectively its accessibility, navigation, data, and performance references.
- `skill://swiftui-animation` — scope motion to actual state changes, interrupt correctly, respect Reduce Motion, and gate APIs to the existing targets.
- `skill://apple-hig-reference` — read the current relevant live chapters, not only a local link catalog.
- `skill://ui-ux-mastery/references/ui-craft.md` — concise hierarchy, native semantics, complete recovery, focus, and reflow.
- The main design owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Use that existing selected context if accessible; do not repeat setup or install another design system. This documentation worker could read the installed SwiftUI/HIG skills but the selected slug was not exposed by its skill resolver or discovered cache; do not claim otherwise or invent a local path.
- [Apple HIG: Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), especially concise content, selection feedback, and macOS considerations.
- [Apple HIG: Panels](https://developer.apple.com/design/human-interface-guidelines/panels), especially selection-following inspector behavior. This design chooses an in-window trailing pane, not a floating HUD.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially window flexibility, density, keyboard/pointer input, and reduced modality.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially purposeful, brief, interruptible feedback and nonmotion equivalence.

Current platform references do not authorize using macOS/iOS 26-only APIs unconditionally, private APIs, or a target increase. Match this repository’s supported OS versions.

## What Happened Last Session

The independent documentation worker read the shared design contract by absolute filesystem path, relevant F29-A/B/C/D/E requirements, the supplied reference image, the named existing native source anchors, installed SwiftUI/HIG guidance, and the live Apple pages cited above. It produced only this future brief and the F29-A-o DOCKS.md. It did not implement, generate assets, run the app, run checks, dispatch a nested agent, or claim human acceptance.

The design settles on a compact private scorebook, one expanded iPhone summary, a selection-following native Mac inspector when space permits, an inline Mac fallback when it does not, explicit twenty-record paging, and deliberate latest-snapshot replacement. No timer or media thumbnails belong to the ledger. Routed battle/result surfaces retain the approved timer/complete-badge-rails/large-vertical-player direction.

The older F29-A specification permits a horizontal comparison at wider sizes and describes macOS as fallback behavior. The user’s newer native Mac and always-vertical direction takes precedence. This slice must not silently edit a sibling result screen to resolve that shared conflict; consume the integrating owner’s corrected canonical composition, or identify the unmet prerequisite. Numerical rating and retention proposals were not newly accepted by the documentation batch.

## Prerequisites and Human-Review Boundaries

Before writing production UI, establish from source, current contracts, CYCLES.md, and explicit human review that all of the following exist:

1. Shared authenticated account activation and synchronous account-change invalidation, with native navigation and the actual Physique history entry route.
2. A real participant-only history service with twenty-record pages, a stable membership/order snapshot, service-owned continuation, stable tie ordering, authoritative end and expiry states, and exact-match private retrieval. A client-generated offset or exercise endpoint is not an acceptable substitute.
3. Identity-bound request lifetime, cancellation, and result revision semantics that prevent stale page/detail responses from crossing accounts, windows, snapshot replacements, selections, or settled corrections.
4. Real service-owned pending/final states, own original rating snapshots, effective match contributions, separate authorized correction adjustments and dates, correction settlement coherence, safe opponent identity, judging versions, and allowance consequences.
5. The approved protected nonmedia cache and privacy-cover policy, plus immediate access/block/deletion invalidation. A generic URL cache or saved view state is not private-history authorization.
6. Canonical exact-match result/pending routing and real safety/case destinations, with current media authorization and expiry owned outside history. An Open result or Safety button may not target a placeholder.
7. The accepted shared battle composition and F29-F identity/badge contract if those shared surfaces are reached here. Every public battle badge remains above two large vertical players; no local preview badge supplies trust.

Code starts only after the required shared foundations/contracts are implemented and human-reviewed. History is not independently shippable before them. If a prerequisite is missing, finish reachable scope analysis, report the exact absent contract or review, and do not build a production mock, local competitive store, invented endpoint, disabled-button scaffold, or replacement backend in this slice. Existing documentation is not implementation proof. Once authorized dependencies exist, ordinary clear local errors found while integrating are this owner’s responsibility, not an excuse to hand off broken code.

## Concrete Design Decisions

- A text ledger is more private, faster to scan, and less image-heavy than a result-card or body-thumbnail grid. It must still look like the existing native sports product through Inter hierarchy, aligned own Elo, semantic outcome marks, shared surfaces, and tactile disclosures.
- iPhone inline summaries preserve the row’s place and avoid forcing a push/back cycle for ordinary rating/date inspection. Exactly one is expanded; a new disclosure preserves its own anchor as the old one collapses.
- A Mac inspector exposes relevant detail without repeated modality on a larger display. It becomes the same inline summary when available space or enlarged type prevents two readable panes; the app keeps its 800-by-600 minimum and native title bar.
- Explicit Load more is preferable to automatic endless fetch for a private accessible ledger. Each continuation requests twenty real records and preserves the current snapshot. New match membership stays behind Show latest; confirmed updates to existing members can settle in place without moving the row.
- Ordinary Own Elo means the viewer’s match effect. A correction must separately explain original settlement, effective match meaning, and the actual later current-rating adjustment; it must not forge a new original before/after history or use one misleading sum.
- Reopening an archived result is reading, not earning. No score/Elo count-up, unlock animation, final-result celebration, fabricated replay timer, body scan, loser shake, or pulsing badge wall.
- The ledger is not a battle composition. It has no badge subset or fake countdown. Every actual routed battle composition keeps the timer topmost, complete owner-grouped badge rails below it, and two large vertical panels, You above Opponent, at all widths. A terminal timer/status is truthful and never restarts.
- Offline records, when permitted by the reviewed session/cache foundation, are minimal nonmedia own facts with neutral opponent identity and stale labels. This sacrifices offline identity lookup to reduce stale deleted/blocked identity exposure. Unknown or expired account authorization shows sign-in, not cached history.

## What to Build

### 1. Connect the private ledger and exact-match identity

Connect the actual History action and recent-match/saved-match entry to this history owner without resetting navigation order or creating a new account flow. Use stable service match identity, not a row index, display name, or current first result. Recent-match selection may address an exact record outside the loaded first page through the real exact-match route; never silently show another record.

Show one History heading, Only you, Show latest, and a compact native list. Use existing theme, scalable Inter and spacing, shared native surfaces, conventional iPhone touch targets, and Mac list focus/selection. No practice toggle, mixed exercise history, workout totals, new filters/sorts, public body feed, export ledger, or row-deletion capability.

Every actual Go-started match is one row, ordered by service start time descending with service-stable tie order. Search attempts and accepted pre-Go cancellations never become rows. Use absolute locale-formatted start times. The expanded summary exposes precise recorded timing and time zone and distinguishes start, finalization, and later correction; missing dates are not replaced with current time.

### 2. Present all outcome and rating states honestly

Implement the complete outcome table and state matrix in DOCKS.md, including judged win/loss/draw, Won by forfeit, Forfeited, No contest, Pending, unrefreshed/unknown finality, Under review, correction settling, and settled Corrected. Provenance must survive a wrapped or enlarged row. Do not treat color or an icon as the only distinction.

Use the viewer’s actual Physique rating effect, not AI totals, current account rating copied across rows, or the opponent’s private transaction. Preserve legitimate zero, missing, and unsettled values as different states. A draw can have a nonzero rating effect. No-contest has no rated-count contribution; a valid forfeit is rated without appearance scores. Neither receives zero-filled rubric meters or a fake judged winner.

For corrections, use the service’s effective contribution and separately labeled actual Review adjustment. A corrected no-contest is Unrated, while the review adjustment may be nonzero. Detail preserves the original settlement, later correction date/reason/outcome, actual bounded adjustment, and its confirmed or pending settlement. Do not recompute a counterfactual rating chain, rerate later opponents, overwrite historical inputs, double-apply a correction, or roll a newer revision back when an older page arrives. While settlement is incomplete, retain labeled last confirmed values rather than mixing revisions.

### 3. Implement real stable twenty-record continuation

Consume the reviewed page contract; do not invent endpoint names or derive a cursor from the displayed count. First load establishes the account/snapshot. Load more continues it, with one request per continuation and a retry at the same missing boundary. Twenty is the real request page size, not a mandate to pad a short response, expose a hidden identity, or infer end from visible count alone.

Preserve stable chronology and membership during a reading session. Existing pending records may finalize in place under the same identity; coherent corrections may update that record and open summary together, with no top-of-list move. Apply access revocation immediately despite snapshot age. Announce new match membership quietly with Show latest instead of inserting rows above the reader.

Show latest intentionally loads the newest first page and resets the continuation and list to the latest view after success. Its accessible description explains this reset. Failure leaves the old snapshot, selection, and anchor visible with stale/retry state. Never merge a new head page with an old continuation. Snapshot expiry disables further continuation and offers Show latest to continue; it does not silently start over with offsets.

Append older rows below the anchored previous last row; do not scroll to the relocated footer. For an explicit keyboard/assistive-technology paging action, focus advances once to the first new row with one safe count announcement. Touch/pointer reading stays in place. A later-page error leaves Retry at the same boundary. The authoritative end removes Load more and displays a calm snapshot-end label.

Do not add a periodic whole-list refresh loop. Use the reviewed feature’s existing real event/pending-state observation. Stop unnecessary view-owned observation when hidden or inactive; shared active-match finality remains owned by the shared coordinator.

### 4. Build the text-only selected summary and real routes

Use the exact hierarchy in DOCKS.md: effective outcome/provenance, permitted opponent, real times, own original Elo snapshot, authorized match-time opponent context, accepted judged totals/gap/version when valid, forfeit/no-contest meaning when not, and separate correction/case context. Full category detail and neutral explanations remain in the canonical result; do not build a second scoring engine or parallel result screen.

Open result targets this exact final match; Open match targets this exact pending match and actual stage. The contextual Safety action and View case use real approved owners. Match references are safe identifiers, not signed media links. No silent rematch, queue, charge, appeal reroll, or report receipt occurs by opening/closing history.

Selecting a record begins only its necessary authorized detail request. Loading/failure remains local to that summary, with Retry and other rows still usable. Cancelling/changing selection invalidates the outgoing target; a delayed response cannot fill a new selection. On access denial, show a safe unavailable state without confirming another account’s private match or exposing cached details.

Do not fetch or decode pose images in the ledger, summary, row, or inspector. Intentional pose viewing belongs to the existing canonical viewer and current real authorization. Only valid AI-judged win/loss/draw results can expose permitted moderated stills during their original twenty-four-hour window. No gallery for forfeit/no-contest, no auto-open on selection/notification/foreground, and no stale link or thumbnail bypass. Report/hide must remain reachable without enlargement through the shared owner.

### 5. Preserve native composition, scroll, and focus on both platforms

On iPhone, use one inline disclosed summary and existing navigation safe bounds. Pressing another row collapses the old summary while preserving the new row’s anchor. Back, canonical result dismissal, viewer close, and safety-sheet return preserve the invoking match, expansion, reading position, and reasonable focus. If access removes that match, return to the nearest still-authorized safe control rather than an empty focus target. Large text and landscape scroll vertically with readable labels.

On macOS 14+, use the actual native window and toolbar. Provide a native single-selection list and a labeled Details toggle. Use a trailing selection-following inspector when two readable panes fit; use the same inline summary at the existing 800-by-600 minimum or when app chrome/text scaling makes two panes unreadable. Never demand a larger app minimum or a side-by-side player battle. Large/full-screen/external-display windows expose comfortable density, not oversized phone cards.

Selection does not automatically steal typing focus into the inspector. It updates only the selected match; a newly selected record begins at its summary heading, while returning to a prior authorized selection restores its own summary position. Live resize preserves selection, ledger anchor, and focused logical action across inspector/inline adaptation, with no duplicate accessible summary exposed in both places. Short windows scroll content while toolbar/back/safe actions remain available.

Use native Up/Down list selection, Tab/Shift-Tab traversal, disclosure behavior, visible focus rings, and contextual menus as secondary access only. Return/Space act only on the focused semantic control, never globally while a safety note or another field has focus. Escape belongs first to the active sheet/draft confirmation, then details, then normal history back. Preserve all existing Mac commands. A simple archival Command-W/quit changes no result; any real active-match consequence is handled by the shared state-aware coordinator where possible. Force quit is neither preventable nor an automatically confirmed voluntary forfeit.

History never requests camera/TCC or microphone and does not initialize a camera session. Denied/missing/busy cameras and external/Continuity disconnect do not gate reading or review. Opening an active match delegates camera recovery and unchanged deadlines to its single real owner. Multiple windows share account/access truth without creating another match/camera/charge.

### 6. Enforce privacy across account changes and lifecycle

Reuse the current shared account activation/invalidation convention rather than creating a second auth owner. Clear private rows, expanded/selected detail, cursors/snapshots, private errors, freshness, and case context synchronously at the account boundary, before I/O for a replacement account. Reject stale completions by actual account/session, snapshot, target, and revision ownership as applicable. The view cannot rely only on filtering a previously populated array after drawing it.

Use only the reviewed protected account-and-service-scoped nonmedia cache. Restore account authorization before exposure. Unknown/expired/signed-out sessions see the account state, not a saved record. Permitted offline records contain minimal own result facts, date, rating/version context, neutral opponent identity, and Saved results/Not refreshed/last-fetch time. No offline opponent handle/flag/avatar/badge, live profile authorization, unsafe explanation, private case payload, gallery, or local competitive settlement.

Blocked/deleted/unavailable identities use the precise safe placeholder and no rediscovery route. Privacy/access events invalidate permitted cached identities and details across visible windows. An in-flight prior-account response, second window, backup, or selected match preference cannot repopulate removed content. Do not expose access tokens, signed media URLs, raw images, or private reports in diagnostics or automated screen replay.

Inactive, backgrounded, minimized, and locked surfaces shield private content immediately with an opaque cover, without waiting for network completion or animation. On return, reestablish account and current access before restoring authorized text context; do not reopen media or start capture. Local hide/block shielding is immediate while the shared owner labels remote confirmation truthfully. Neither a report draft nor an unacknowledged privacy request is a successful remote action.

### 7. Add purposeful, bounded native feedback

Apply only the timings and triggers in DOCKS.md, using supported public APIs and the existing shared controls:

- Existing custom press spring: response 0.24 seconds, damping fraction 0.88; no additional row bounce on Mac native selection.
- Native selection emphasis: about 160 milliseconds.
- Inline disclosure continuity: about 280 milliseconds, smooth restrained settling, preserving the invoking row’s anchor.
- Inspector content changes: about 180 milliseconds with stable chrome; native inspector show/hide uses its platform transition without a second animation.
- Requested page append: about 160 milliseconds of opacity together, not a cascade or scroll chase.
- Confirmed pending/final or correction update: about 180–200 milliseconds, coherent text replacement with final accessible numbers immediately present.
- Quiet new-membership/error notice: about 180 milliseconds.
- Privacy/access loss: immediate replacement with no transition delay.

Repeated input reverses or replaces the active presentation from its current state; no queued reveals or interaction lock. Nothing waits for decoration before navigation, safe actions, final values, cancellation, or protection. A reopening history path never repeats score/Elo/badge earning motion.

Reduce Motion uses immediate layout and at most about 120 milliseconds of helpful opacity, with the same information/focus/actions. Reduce Transparency uses readable opaque rows/panes/cover. Increased contrast retains text and selection legibility. No ambient history loop, shimmer, pulsing badge wall, body scan, strobe, loser shake, per-row ticking date, or expensive animation callback work. Low Power Mode and thermal constraints remove optional transition work; offscreen/inactive surfaces do not keep it running. Do not do per-frame I/O, image decode, provider calls, global layout invalidation, or font measurement.

## Prospective Files and Scope Boundaries

Confirm the current architecture before edits; reuse an existing reviewed owner if it already provides the named responsibility.

- Create or finish `TimeMaster/Views/Physique/PhysiqueMatchHistoryView.swift` — native ledger, adaptive iPhone/Mac composition, selection, and page-boundary presentation.
- Create or finish `TimeMaster/Views/Physique/PhysiqueMatchHistoryRow.swift` — compact semantic row and complete outcome/rating provenance; no second theme or outcome authority.
- Create or finish `TimeMaster/Views/Physique/PhysiqueMatchHistorySummaryView.swift` — one reusable text-summary hierarchy for inline/inspector presentation. Do not duplicate a full result or media viewer.
- Use the reviewed history presentation/state owner under `TimeMaster/Services/Physique/` and the current `TimeMaster/Models/PhysiqueDuelModels.swift`. Modify only the history-related binding/representation necessary to consume the approved real contract. Discover and name the actual current service file before editing; do not invent a second API, account/cache manager, rating engine, or universal pagination framework.
- Modify only the actual reviewed Physique lobby/recent-match/navigation owner needed to connect History and exact-match return. Name those existing paths in the implementation plan after reading them.
- Update focused existing behavioral/contract tests for history and account lifetime where needed. A new permanent regression is justified for a plausible consumer-visible boundary such as skipped/duplicated pages, cross-account stale completion, or incoherent correction—not for source-text wording or forwarding echoes.
- Update only the relevant approved F29-A-o implementation todos in root `CYCLES.md` after connected behavior and focused checks, with an explicit human-review handoff. Do not mark human verification or rewrite other workers’ plan entries.
- Product context lives in `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-o-match-history/DOCKS.md`; update accepted product decisions only after human acceptance unless the user directly approves them before implementation. Do not add logs, screenshots, code, project todos, completion checklists, or verification claims there.

No edits to generic Theme/Profile shape, app-wide window minimum, deployment targets, existing Mac shortcuts, exercise rating/privacy, camera capture, model policy, moderation policy, or unrelated workers’ code. If a shared owner needs a genuine contract change, identify it at the boundary rather than smuggling a replacement foundation into this UI task.

## Observable Acceptance — iPhone and Native macOS

The following are prospective acceptance criteria, not claims that any check ran.

### Records, exact routing, and authority

- Both platforms show only the authenticated participant’s real started matches, with no sample rows, pre-Go cancellations, fake opponent, mixed exercise data, local ratings, invented scores, or unknown-to-zero conversion.
- Judged results, Won by forfeit, Forfeited, No contest, Pending, Under review, correction settling, and settled Corrected remain distinguishable in compact/large text. A nonzero draw and a zero rated effect are not confused with no-contest or missing settlement.
- An exact row opens the matching service record and returns to that row, not a generic result or a neighboring match. A pending match resumes its actual stage with no new match, provider call, charge, or deadline reset.
- Corrected no-contest shows unrated effective match meaning and a separately labeled actual review adjustment. Original rating snapshots and later valid matches are not silently rewritten; stale pages cannot revert the correction, and reopening cannot apply it again.
- Deleted/blocked/unavailable opponents have safe neutral identity and no live discovery. Unlisted own history remains private and usable subject to actual access.

### Real twenty-row paging and failure recovery

- A real account with more than twenty records traverses first, second, and terminal pages with every expected authorized match exactly once in stable service order, including equal start times.
- Repeated Load more activation cannot duplicate a request/page. Concurrent new match membership does not jump into the current reading snapshot. A pending loaded row can settle in place without moving; only Show latest intentionally replaces membership and resets the head view.
- Later-page failure retries the missing continuation and preserves existing rows, selection, focus, and anchor. Show latest failure retains the previous snapshot; successful replacement drops the old continuation. Expired snapshots offer explicit replacement rather than silently joining incompatible pages.
- First-load empty, first-load error, offline without cache, same-account permitted saved records, and authoritative end are observably different. A short page is not padded or automatically called terminal against service continuation.

### Actual native surface and input

- iPhone compact/large/landscape layouts use one inline summary, the existing touch conventions, native safe bounds, and readable wrapping. Expanding another row and returning from result/safety preserve the actual selected match and reading context.
- macOS runs as the native app with its normal title bar and existing 800-by-600 minimum. Laptop, large, full-screen, external-display, short-window, and live-resize states remain readable. Inspector/inline adaptation preserves selection/anchor/focus without duplicate accessibility content or horizontal clipping.
- Native keyboard selection, focus rings, Tab/Shift-Tab, disclosure, Return/Space on the focused semantic control, state-aware Escape, and pointer menus all work. No global key handler captures typing. The existing four commands remain their existing commands. Standard archival close never forfeits a completed match.
- Camera/TCC denial, no hardware, and external/Continuity disconnect do not prevent history. Secondary windows cannot create another match/camera/charge. Active-match close/quit consequences remain the real coordinator’s responsibility, and force quit is not misrepresented as a confirmed action.
- If routed to any battle composition, both platforms keep the top real timer/truthful terminal state, complete badge rails above the panels, and two large VERTICAL players, You above Opponent, at every width. No horizontal result substitute is introduced by history.

### Privacy, access, accessibility, and energy

- Account restoration, sign-out, switching accounts, session expiry, deletion, inactive/locked/minimized state, and a delayed old-account page/detail response never expose another account’s rows, identity, cursor, case, or images—even briefly.
- List/summary/inspector performs no pose-image request or decode. Intentional canonical viewing enforces valid judged result, current access, original expiry, and exact hide/block/withdraw/remove/report states; forfeit/no-contest never unlocks a gallery. Reopen/foreground/offline/old links cannot resurrect media.
- VoiceOver and keyboard navigation expose row provenance, rating units, expanded state, precise timing, pending/corrected status, retry, paging, and safety with no hover-only or color-only dependency. Long/translated names, supported RTL, increased contrast, and large text do not hide consequential information.
- Reduce Motion, Reduce Transparency, low-power/thermal adaptation, and background/minimized suspension retain all information and safe actions. Meaningful state changes announce once, not per frame/tick. No history earning celebration or idle animation/polling persists.

## Focused Native Smoke, Accessibility, and Energy Scenarios

Once implementation is authorized, run the actual changed surface on both native platforms where runtime exists. Tests and compilation alone are not runtime proof. Do not initiate unapproved paid judging, new user-image uploads, or reference-face reuse to manufacture verification data. Use authorized consenting accounts and real known service records or the service’s already approved isolated development contract; test-only arrangements must never become a production fake-peer fallback.

1. Launch the real iPhone app and native Mac app. Open Physique, then History through the connected action. Observe first loading, real first-page rows, one disclosure/inspector, Open result for a known exact record, and return to the invoking row/anchor. Observe a genuine empty/error state using an authorized account/service state, not production samples.
2. With more than twenty known authorized records, load two continuations and the terminal state, including records sharing a start time. Interrupt the missing-page request through the approved test/service controls; retry once and observe no skipped/duplicated matches, head-page replacement, or focus jump. Observe a concurrent new match notification and deliberate Show latest separately from an in-place pending-to-final revision.
3. Open actual judged draw/zero, forfeit, no-contest, pending, and reviewed/corrected record states available from the reviewed service. Observe distinct labels, exact own effects, no invented category scores, and original-versus-review adjustment semantics. Deliver a legitimately older page after a newer correction through the reviewed test boundary and observe no rollback. Do not simulate this solely by asserting source text or hardcoding production rows.
4. While an exact detail or later page is outstanding, sign out or switch accounts through the real account surface. Observe synchronous private-content clearing and rejection of the delayed result. Reopen history in a second Mac window, invalidate access/deletion as authorized, and observe that private content and old selection cannot reappear. Check same-account permitted offline text separately from expired-account/sign-in behavior.
5. At Mac 800 by 600, a short constrained window, ordinary laptop size, full screen, and a larger/external display if available, open/close Details and live-resize through the adaptive boundary. Observe one selected summary, stable ledger position, reasonable density, and focus following its logical control. Exercise pointer and keyboard-only Up/Down, Tab/Shift-Tab, disclosure, Return/Space, and Escape; type in a real owner-controlled report note and observe that history does not capture Return/Space globally. Preserve existing commands and state-aware window-close behavior.
6. On iPhone use large accessibility text, VoiceOver, Voice Control or Switch Control where available, and the keyboard paths supported by the app. On Mac use VoiceOver and Full Keyboard Access. Read a corrected row, expand it, load older records, trigger Retry, open a contextual safety route without enlarging an image, close it, and observe understandable names/units/status and return focus. Report precisely which assistive technologies were exercised; do not claim an audit from static inspection.
7. Enable Reduce Motion, Reduce Transparency, and increased contrast and repeat disclosure, paging, correction update, and close. Observe immediate final accessible values, no duplicate award/badge animation, readable opaque protection, and no interaction waiting for animation. During disclosure or network activity, background/lock the iPhone and deactivate/minimize the Mac; observe immediate shielding and no auto-opened gallery/camera on return.
8. Use available low-power/energy controls or the platform’s supported diagnostic conditions to observe the absence of idle history animation, per-row clocks, repeated whole-list polling, image prefetch, or background decorative work. Observe that existing authorized pending/finality and privacy expiry remain correct. If a thermal or physical-energy scenario cannot be exercised, name that limit instead of claiming it passed.
9. Verify that entering history requests no camera, microphone, or Photos permission. Where physical hardware is available, disconnect an external/Continuity camera owned by a real active flow and verify history remains usable while the shared coordinator handles that flow. History itself needs no camera to read records; name missing physical-camera/Continuity proof explicitly, without replacing it with a simulator feed or claiming the capture system was validated.

Run the smallest relevant existing build/typecheck/contract checks after the connected changes and fix clear failures. Add or retain deterministic permanent regression coverage only for plausible consumer-visible boundaries: equal-time stable paging, failed continuation retry, stale response after account/selection/snapshot change, corrected outcome/rating coherence, and access removal. Do not add source-text/copy tests, bare-not-throw tests, mock-forwarding echoes, incidental defaults, or assertions that merely mirror a fixture. Remove obsolete wording/implementation-detail tests rather than re-pin them. Smoke scripts used only for this work are disposable and removed after proof; do not leave scaffolds or a new testing framework.

Report only actually exercised commands/scenarios and observed outcomes. No requirement for screenshots, recordings, logs, or a completion evidence package. An unavailable native runtime, missing real test accounts/service credentials, or absent physical hardware is a precise limitation, not permission to invent evidence or call an unconnected view complete.

## Human Verification Handoff — Required

List separately:

- The connected private ledger and outcome/provenance rows.
- Twenty-record stable paging, Show latest, end/error/expiry recovery, and exact-match identity.
- iPhone inline summary, disclosure/return anchoring, and focus.
- Native Mac inspector/inline adaptation, window lifecycle, resizing, keyboard, and preserved commands.
- Correction/original-settlement presentation and current authority.
- Account/cache/access shielding and no history pose-image fetching.
- Canonical result/pending/safety/case routing.
- Motion, reduced settings, accessibility, and energy behavior actually implemented.
- Every changed source/test/document/planning file, individually, with its purpose.

State which items are ready for human verification, what was exercised, and every real missing runtime/hardware/service prerequisite or unresolved product decision. Ask the user to review the code changes and resulting behavior. The human is the final verifier; automated checks are engineering evidence, not human approval. Do not mark a human-review todo complete or use done/verified for an unaccepted result.

After the user accepts behavior, update only the smallest relevant DOCKS.md with accepted plain-language product decisions. Implementation todos stay only in CYCLES.md. Do not put source, payloads, implementation recipes, project checkboxes, screenshots, logs, tests, or completion evidence in DOCKS.md.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do the implementation, source reading, reasoning, checks, and handoff yourself with the assigned model/thinking level. Do not delegate repository review, generate another worker, or claim unavailable dispatch.
2. **Scope to this slice.** Preserve other workers’ changes and existing app behavior. No unrelated cleanup, framework wrapper, global theme, new permission, camera pipeline, backend rewrite, judge change, badge engine, public history, or fake fallback.
3. **Real data and real service authority.** No seeded production peers, body thumbnails in history, guessed zero scores/ratings, local competitive results, fake cases, dead buttons, production mock service, or silent provider reroll. Labeled preview-only fixtures are not production substitutes or evidence of connected behavior.
4. **Respect prerequisites and human review.** Do not implement around an unreviewed account/history/privacy/result foundation. Establish actual contracts from current source and review records. Name a missing external dependency precisely; fix clear ordinary local implementation errors within the slice.
5. **User direction wins.** Follow the native iPhone/native Mac, top-timer, complete-badge-rails, large vertical-player direction wherever a battle composition appears, even when older prose differs. Numerical competition rules and privacy policy remain with their accepted owners. Surface a real security/product conflict; never silently narrow the ask.
6. **Independent native implementation.** Read relevant skills and current Apple guidance, inspect actual supported API availability, and reuse the current repo’s boring patterns. Do not blindly follow an unvalidated technical statement in documentation or copy exercise-only behavior.
7. **Focused checks and actual surface.** Exercise the changed native path on both platforms where runtime exists and cover significant behavioral boundaries. Tests/builds alone are not proof. Never fabricate output, rerun a user-reported failure merely to confirm it, or claim unexercised camera/accessibility/energy behavior passed.
8. **CYCLES only for implementation todos.** Update only the approved F29-A-o implementation entries after connected behavior and focused checks, with the human-review handoff. Do not rewrite other cycles, set human verification, create IDE task JSON, or put project checklists/evidence into DOCKS.md.
9. **Scoped commit and push.** This future implementation phase must commit each completed coherent work slice with a clear message and push it to `origin/main` before yielding. Stage only this owner’s authorized changes; do not include other workers’ edits, force-push, rewrite history, or commit secrets. If commit/push is genuinely unavailable, report the exact failure and do not claim publication or completion. The preceding documentation batch’s integrated publication belongs to its main owner, not this brief’s author.
10. **Complete the connected slice.** No stubs, placeholders, no-op actions, fake previews, misleading scaffold handoff, or testing-only next phase. Finish all reachable implementation, clear fixes, focused native smoke, CYCLES updates, human handoff, and scoped publication in the authorized session.
11. **No pointless next prompt.** Do not generate a follow-up for routine checks, fixes, docs, commit, or push. A next prompt is appropriate only for a separately approved substantial independent slice; otherwise finish this work. This feature does not authorize starting an unreviewed dependent feature.

## When You Finish

Report every implemented part and changed file separately, the native smoke/checks actually exercised, publication result, and known limits. Ask for human review and state that each reached item is ready for human verification, not human-verified. Say whether a next prompt was needed; complete routine remaining work rather than deferring it.

Use Completed, Remaining, and Decision to distinguish connected work from a genuine missing prerequisite. Do not estimate or narrate session limits. Do not claim an integrated product, accepted visual prototype, public readiness, judging quality, or safety operation merely because history compiles or its documentation exists.
