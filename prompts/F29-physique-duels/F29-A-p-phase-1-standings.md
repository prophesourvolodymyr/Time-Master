# Phase 1 of F29-A-p — Native Physique Standings

## Assignment and Execution Boundary

Required worker model: **openai-codex/gpt-6.1-sol:max**. Model identifier: **openai-codex/gpt-6.1-sol**. Thinking level: **max**. Do not silently substitute another model or reduce the thinking level. If the requested dispatch is unavailable, state the actual limitation before attempting a replacement. The worker-model assignment is not the in-app Physique judge, a judging-version change, or permission to send standings information to a provider.

This is a future implementation brief. The documentation-only worker that writes it must not execute its implementation, native runs, tests, formatting, git, or publication steps. Future production code starts only after the real shared foundations and route contracts below are implemented, available, and human-reviewed.

## Features Included

- **F29-A-p — Physique standings:** a connected iPhone and native macOS ledger of real placed, opt-in public Physique accounts; shared ties and canonical positions; complete permitted badge/country presentation without player photos; precise own placement/listing states; stable paging, refresh, privacy omissions, recovery, input, accessibility, and energy behavior.

F29-A-q player summary, F29-A-w privacy and sharing, F29-A-y badges/country, safety intake, and the shared service are dependencies, not additional screens to redesign or implement under this assignment. List each meaningful implemented standings task separately in the human-review handoff.

## Context

Standings is the public identity-and-numbers surface for the independent service-owned Physique ladder. A complete variable-height ledger, separate own-standing summary, and explicit coherent refresh preserve truthful ties, achievements, and privacy. This brief follows a documentation-only design pass; no production standings UI, service, accepted prototype, or runtime proof is established by that pass.

## What You Need to Read First

Read the actual integrated files before choosing a technical implementation. Paths are relative to the repository root unless absolute. Follow any updated ownership links in the integrated F29 parent; do not assume a document or production symbol exists just because this future brief names it.

### Product and review contracts

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-p-standings/DOCKS.md` — the complete selected composition, state matrix, privacy behavior, and motion rules.
- `features/F29-physique-duels/DOCKS.md` — separate ladder, protected evidence, user-directed vertical battle composition, and product/policy boundaries.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — native routing, view owners, match lifecycle, accessibility, and safe exits.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — especially Unplaced, Provisional, and Placed; Standings and Public Visibility; Loading, Empty, Offline, and Review States; and canonical record/correction rules.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — standings report entry, current discoverability, bidirectional block consequences, and before/after-Go distinctions.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — separate optional public listing, authenticated access, account changes/deletion, and image/processor boundaries.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Accepted Inputs and Judge Blindness; no identity, badge, country, rating, or standings context enters judging.
- `features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md` — the integrated authoritative badge/country vocabulary, order, public projection, and correction behavior.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md` and `features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md` — shared styling/motion, native windows, input, lifecycle, camera ownership, and compatibility.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md` — the existing permitted player-detail route and Mac inspector/sheet contract.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md` — the single listing-choice owner; no duplicate toggle or consent screen in standings.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md` — own badge/country access; no editing from a foreign player's row.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-r-safety-hub/DOCKS.md` and `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-s-report-composer/DOCKS.md` — contextual profile reports, real sent/unsent states, and pending block protection.
- `CYCLES.md` — the actual approved F29 scope and review status. A checked documentation item is not implemented service authority or human approval.

### Existing source anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — near-black shared surfaces, orange actions, card and back-control language.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter roles, spacing, readable content, and existing iPhone action area.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material availability, opaque Reduce Transparency behavior, and shared press response 0.24/damping 0.88. No private framework or second global theme.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — sports-action and earned-Elo visual language. Do not copy Dynamic Type clamps, fixed-size tiny badges, exercise tier assumptions, or unlabeled units.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only. Its live provisional movement score is not a Physique metric, and it does not authorize a mini battle on this screen.
- `TimeMaster/App/TmaxApp.swift:8-19` — native WindowGroup, normal title bar, current 800×600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — local editable cosmetic previews are not trusted competitive achievements or identity verification.
- `TimeMaster.xcodeproj/project.pbxproj` — retain iPhone iOS 16 and native macOS 14 compatibility and both targets' source membership.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual image. Borrow direct hierarchy, not its horizontal players, people, video, web colors, text, or asset rights.

Discover and read the real implemented Physique lobby/router, account-scoped presentation model, snapshot service, public-identity projection, and related tests through the repository tree. Do not open guessed source files or establish a parallel client because this brief uses prospective names below. `STYLES.md` was absent during the design pass; use current source conventions rather than create one.

### Native skills and live references

The coordinator already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selected context when supplied; do not repeat discovery/setup or install a competing visual system. In the writing session that selected slug did not resolve as a separately readable installed skill. Do not claim its full file was read on the basis of the selection alone.

Read the relevant actual installed guidance:

- `/Users/volodymurvasualkiw/.agents/skills/swiftui-pro/SKILL.md`, its `references/accessibility.md`, `references/navigation.md`, and `references/performance.md`.
- `/Users/volodymurvasualkiw/.agents/skills/swiftui-animation/SKILL.md` — scoped motion and interruption; newer examples are not deployment requirements.
- `/Users/volodymurvasualkiw/.agents/skills/apple-hig-reference/SKILL.md` — selective live Apple lookup, not an offline claim of compliance.
- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — flexible windows, native system integration, keyboard/pointer work, and use of larger displays.
- `https://developer.apple.com/design/human-interface-guidelines/lists-and-tables` — readable row content, meaningful selection, descriptive headings, and platform-specific density.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — purposeful brief feedback, optional motion, and interruption.

Apply the repository's actual deployment targets over a skill's default for a new iOS 26 app. Product DOCKS is plain-language context, not a source-code recipe or substitute for independent implementation research.

## What Happened Last Session

The specialist selected a single variable-height ranked ledger, not a podium or image grid. It specifies a separate authoritative Your standing summary, full public badge rails, optional declared-country identity, explicit update/paging controls, immediate privacy omissions with canonical rank gaps, and distinct native iPhone/Mac compositions.

The work slice was documentation only. No Swift files, endpoint, production mock, generated assets, match, UI run, test result, commit, or human approval was established by the specialist. Other F29 documents and briefs were being written by separate owners; their existence or completion must be checked in the integrated tree. The shared parent already assigned player detail to A-q and listing changes to A-w, so this brief deliberately does not add a second listing sheet or player-profile screen.

## Prerequisites and Review Boundaries

Before production edits, establish from actual source and CYCLES that the intended account/navigation foundations and the relevant F29 service and routes are implemented and have received the required human review. Do not turn a documentation checkbox into permission to bypass review.

The real reviewed service must provide:

- The single Physique competition domain, actual current whole-point Elo, effective placement count/status, canonical public position and shared-tie meaning.
- Eligible placed opt-in public accounts, stable service-selected ordering within ties, a coherent snapshot and continuation, a real end state, and truthful unavailable/expired states.
- A separate service-confirmed own-standing result even when the account is outside loaded pages, or an explicit unavailable/unlisted/unplaced/provisional state.
- Current authenticated visibility and bidirectional block omissions; deletion, unlisting, and restriction changes cannot leave discoverable stale identities or active profile links.
- Public identity, optional shared region, and authoritative badge/record projection under F29-F, including unknown data and corrections.
- Real listing changes through A-w and real contextual reporting/blocking through their existing owners, including pending/failed/offline status.

If a required real contract or reviewed route is missing, name the exact prerequisite and existing evidence. Finish reachable authorized work, but do not publish an inert screen, stub service, client-made rank, fake peers, or a mock-backed fallback as this feature. Missing shared foundations are not permission to implement another owner's scope. Resolve ordinary clear local implementation failures yourself; a normal fixable compiler error is not an external blocker.

Browsing standings does not require a camera, a new image-sharing action, an available match slot, or a healthy image judge when the account is authorized to read the board. It performs no analysis and changes no rating. Preserve the adult/media gates for any transition into the real rated flow.

## Concrete Design Decisions

1. **Ledger over podium.** Canonical shared ties and privacy gaps must remain readable. A podium would privilege the first visible filtered player and tempt photo-based comparison. Use steady rank/identity/Elo alignment with complete wrapping achievements.
2. **Variable-height native rows over a rigid spreadsheet.** All legitimate public badges stay visible, including at large type; the cost is taller rows and vertical scrolling. Do not solve it with a three-slot cap, +N, ticker, ellipsis badge, or tooltip-only detail.
3. **Own summary separate from paging.** Your actual position is not your array index and not the presence of your row in a page. A service summary avoids fetching the whole board or inventing an Around you API.
4. **Native Mac list plus reused player inspector.** Use available desktop space for readable columns and authorized detail, with a sheet when space is insufficient. Do not make a fixed-width phone panel, sortable alternate ladder, or horizontal battle.
5. **Explicit coherent updates over live row racing.** Normal updates offer Refresh; privacy/safety removals are immediate. Keep page identity and focus stable and never merge incompatible snapshots.
6. **No persisted offline public board.** A saved same-account own summary can be labeled stale; discoverable other-player identities are concealed offline. This gives up offline public browsing rather than imply perpetual listing/block permission.
7. **Tactile, not theatrical.** Use shared control press and native selection plus one approximately 280-millisecond own-marker draw on a real confirmed visible update. Rank and Elo are readable immediately. No rank-number roulette, podium lift, badge pulse, or replayed award.
8. **One owner for each action.** Open A-q for player details, A-w for Public listing, A-y for own badge/country management, and the existing report/block owners for safety. There are no new unowned custom screens.

## What to Build

### 1. Connect the real entry and presentation state

Open Physique standings from the approved lobby route and restore the invoking destination on close. Reuse the reviewed account-scoped Physique service and presentation model. Handle restoration, sign-out, account changes, deleted accounts, stale requests, and permission loss without showing another account's own summary, selection, continuation, or report target.

Keep only minimal view-owned presentation state. Reuse service ordering and stable account identity; do not identify a row by position, handle, array index, or rating. Avoid sorting/filtering/ranking on every body evaluation or animation frame. Do not create another authentication store, network client, badge engine, or offline public cache.

### 2. Implement both actual native compositions

On iPhone, use the existing navigation/header and measured menu clearance; a scrolling Your standing summary; a ledger with rank, handle/optional region, labeled Physique Elo, full badge wrap, and permitted short record; named player-detail and safety controls; explicit paging and recovery. Reflow long handles, large positions, and accessibility text instead of shrinking or clipping them. Use the app's forty-four-point action-area convention.

On native macOS, use normal titlebar and toolbar; a horizontally composed own summary when it fits; a variable-height single-selection list with meaningful column headings; and the existing A-q inspector only when complete content fits. At 800×600 or short height, keep toolbar actions available and scroll the central content. Use the same A-q sheet when an inspector would squeeze the ledger. Laptop, full-screen, external-display, and live-resize states preserve meaningful density, selection, and focus without increasing the app-wide minimum. No side-by-side players at any width.

Standings has no active battle composition or decorative clock. Any route back to an actual battle preserves its real top timer, complete public owner-grouped badge rails, and two LARGE VERTICAL players, You above Opponent. Do not modify other owners' battle composition as a shortcut for this view.

### 3. Present only authoritative ranks and truthful own states

Display the service's descending current Physique Elo order and shared positions. Equal ratings share their actual position across page boundaries and privacy omissions. The row order within a tie does not confer an advantage. Do not use best Elo, wins, badges, country, or exercise levels as tie-breakers. Do not invent population denominators, percentiles, or movement arrows.

Your standing must distinguish Unplaced, Provisional with the actual count out of five, placed/listed, placed/unlisted, listing on before placement, position updating, unavailable facts, private restrictions, correction settling, and correction back to provisional/unplaced. Never display the hidden 1000 pairing seed as an earned award or grant a tier before placement. A known zero is not missing data.

Keep own Elo, position, placement, badge state, and freshness coherent. Do not combine a newly corrected rating with an old position as a current standing. An effective dispute does not imply a reversal; correction settlement, restriction restoration, and explicit listing determine the actual display.

### 4. Compose public identity and all legitimate badges

Use the shared F29-F public projection and canonical ordering. Every currently permitted earned launch badge is represented; Placed/current tier can be composed without duplicate labels. Current streak and Three Straight's historical milestone are distinct; unknown is not zero. Local cosmetic previews, membership, paid benefits, private declarations, moderation claims, and verification imitation are not competitive achievements.

Show an optional intentionally declared region flag beside the handle, with the readable self-declared region as accessibility content. Missing/unsupported flag states are neutral. No country guessing, filters, ranking, or judging input. No player photographs, body thumbnails, public pose gallery, early opponent media, or automatic upload of a local avatar.

Badge projection failure is Badges unavailable while otherwise authorized rank/Elo can remain. Known revoked or corrected achievements disappear coherently; reopening or paging never re-awards them. Reach definitions through the real A-q detail rather than a hover-only explanation.

### 5. Connect listing, profile, and safety without duplicating owners

Public listing opens A-w at the actual listing section. Preserve the optional, initially unconfirmed/off, explicit Physique-only choice and its disclosure of public identity, optional country, Elo/tier, permitted record/streak, and earned badges, with no body images or private declarations. Unlisted accounts retain their real Elo. Listing on before placement does not create a public row or reserved rank.

Use the real shared saving/failed/offline states. Unlisting shields locally immediately but remote removal is not confirmed until acknowledgement. Return from privacy reconciles the service, not a local switch appearance. Keep privacy access available even when the board fails.

Player details opens A-q only with current authorization. Player actions connects the actual contextual report composer and independent block path. No body enlargement, screenshot attachment, or fake sent receipt is needed. On current permission loss, remove the profile action and safely dismiss or replace an open inspector. Pending offline blocks omit locally and remain visibly unconfirmed globally.

Before/after-Go block consequences belong to the shared coordinator. Block/report never awards Elo, erases a loss, or automatically leaves a live eligible match after Go. Unblock does not auto-open the player or restore a gallery.

### 6. Implement stable pages and honest recovery

Use up to twenty actual authorized rows per reviewed service page. Fewer or zero visible rows with continuation do not mean end. Keep a named Load more action, real Loading more, local later-page Retry loading more, explicit end, and snapshot-expiry recovery. Do not append duplicates, infer ranks from visible counts, expose hidden identities to fill pages, or merge incompatible snapshots.

Existing rows and reading position remain still during continuation. Normal changes offer a quiet Standings changed notice. Explicit refresh obtains a new coherent board and preserves an available first-page anchor; otherwise announce the intentional return to the top. Privacy removals take effect immediately without waiting for refresh or an exit animation. Remaining rows retain canonical positions; do not compress gaps or insert named blocked/deleted placeholder rows.

Keep globally empty, viewer-filtered empty, invisible section with continuation, loading, unavailable, offline, expired, and end states distinct. Conceal other-player identities offline or when authorization becomes unknown. Retain only the authorized same-account saved own summary with a real freshness label, and restore safely on reconnection.

### 7. Finish native input, accessibility, motion, and lifecycle

Use native semantic controls, visible focus, no nested buttons, and complete VoiceOver meanings for scope, public identity, declared region, shared position, Physique Elo, tier, badges, permitted record, and own placement/listing status. No duplicate decorative glyph readings. Large text, increased contrast, Differentiate Without Color, Voice Control, Switch Control, and Full Keyboard Access must retain equivalent actions.

Keep focus stable through loading and paging; announce completion once. On focused-row removal, move to the next allowed row, preceding row, or heading without exposing a hidden reason. Close details to the invoking allowed row, privacy to Public listing, and About to its control. Load more retains its focus or transfers to the adjacent end state, not the first row.

Mac keyboard behavior is focus-scoped. Arrow keys navigate the focused native list; Return opens/focuses its actual selected player; Space activates the focused control, never global capture while typing. Escape respects menus, sheets, meaningful drafts, and inspector ownership. Preserve existing commands. Cmd-W/quit delegates real active-match consequences to the existing coordinator where possible; force termination is not a confirmable voluntary forfeit.

Use the shared press spring, about 160-millisecond selection/notice responses, about 180-millisecond compatible content settling, and the single about 280-millisecond own-marker draw. Final values and actions are immediately usable. No animated rank reordering, replay awards, strobe, humiliating loss effect, continuous badge motion, or background loop on this nonbattle view. Reduce Motion uses static final state or brief opacity; Reduce Transparency uses readable opaque shared surfaces.

Pause optional subscriptions and decoration offscreen/inactive/minimized/backgrounded. Low Power Mode and serious thermal pressure remove nonessential marker/transition motion without changing meaning or authoritative clocks elsewhere. Do not do per-frame I/O, networking, image work, font measurement, or global layout invalidation. Do not maintain a per-second relative snapshot-age timer.

No camera is activated here. TCC denied/restricted, busy/absent hardware, external-camera removal, or Continuity disconnection must not disable an otherwise authorized board or request camera permission. Secondary windows do not create a second account session/match/camera owner or charge a slot. If the actual match owner is interrupted, its camera/privacy stop is immediate, the same match is restored, and deadlines do not reset. There is no fake preview or rated file-picker fallback.

## Prospective Files to Create or Modify

These names identify likely feature-owned locations, not source files proven to exist during documentation. Inspect the implemented foundation and reuse its organization.

- Create or extend `TimeMaster/Views/Physique/PhysiqueStandingsView.swift` for the native standings composition, real state, and dependency routes.
- Create or extend `TimeMaster/Views/Physique/PhysiqueStandingRow.swift` for the variable-height accessible public row, complete shared badge rail, and scoped actions.
- Modify only the actual approved Physique lobby/router files needed to connect Standings and the existing A-q/A-w/safety destinations. Identify their exact discovered paths before editing; do not create duplicate destinations or change the page catalog globally.
- Reuse the implemented files under `TimeMaster/Services/Physique/` and `TimeMaster/Models/PhysiqueDuelModels.swift` where the reviewed contract lives. Make only needed presentation integration; missing backend semantics are a named shared prerequisite, not an invented local implementation.
- Modify `TimeMaster.xcodeproj/project.pbxproj` only if source membership is needed for the existing iPhone and native Mac targets. No deployment-target raise or unrelated project churn.
- Update actual affected contract/behavior tests in their existing suite when the changed behavior requires it. New permanent tests are justified only by a plausible consumer-visible edge, not wiring, text snapshots, mock echoes, or a copy of an existing same-path test.
- Update only the approved F29-A-p implementation todos in `CYCLES.md` after connected code, focused checks, and the clear review handoff. Documentation, review, and human acceptance remain distinct.
- Correct this owned product DOCKS only for user-approved product decisions, not logs, test results, completion checklists, or a claim of human verification. Keep source and technical details out of DOCKS.

No new global theme, custom navigation framework, permission-alert imitation, camera pipeline, media viewer, profile/badge editor, report screen, alternate leaderboard domain, migration, backend stub, generated artwork, or unowned custom component is authorized by this brief.

## Observable Acceptance — iPhone

- Opening Standings shows only the independent Physique scope, real own placement/listing state, and actual eligible public accounts. The screen never starts a camera, sends images, consumes an allowance, or starts a match.
- On a short phone and with the largest accessibility text, rank, full permitted handle, labeled Physique Elo, all earned public badges, paging, privacy, and safety actions remain readable and reachable without clipping or font shrinkage.
- A shared tie across a page boundary or a hidden account still says Shared with the true position. Missing rows do not compress rank. Own position outside loaded pages remains correct in Your standing.
- Unplaced, provisional, unlisted, unknown, restricted, and correction-to-provisional states differ visibly and accessibly; none receives a fake seed rating, tier, rank, or award.
- Player details, About, Public listing, report, and block open their real owners and return focus safely. A badge explanation is not hover-only; a report requires no pose or screenshot.
- First/later-page errors, zero-visible continuation, actual end, snapshot expiry, refresh, offline, permission removal, and account switch follow the product states without fake rows or mixed snapshots.
- Reduce Motion/Transparency and silent interaction preserve information and actions. Normal motion is tied to actual state and never delays protection or access.

## Observable Acceptance — Native macOS

- The actual native target presents a normal titlebar/toolbar and a readable variable-height ledger at 800×600, on a laptop, in full screen, and on a larger external display. No minimum increase, fixed phone-canvas layout, or horizontal battle is introduced.
- Live resize and short-window scrolling preserve allowed selection/focus and usable toolbar actions. All badge rails wrap. The reused player inspector yields to its native sheet before either region becomes unusable.
- Pointer selection, context/visible safety actions, keyboard list navigation, Full Keyboard Access, VoiceOver, and state-aware Escape work. Return/Space do not hijack typing; the existing app commands retain their meanings.
- A standings-only Cmd-W does not report a voluntary forfeit. Shared active-match close/quit consequences remain honest; force quit is not falsely intercepted or confirmed.
- TCC denial, no camera, busy camera, and external/Continuity loss do not activate a fallback or block authorized standings browsing. Secondary windows do not create or charge another match, take another camera, or reset deadlines.
- Inactive/minimized/background return reconciles the account and visibility before exposing sensitive own information or a stale selected identity. Optional update/animation work stops; Low Power Mode/thermal-reduced presentation is static and legible.

## Focused Verification to Perform During Implementation

This section is prospective, not an assertion that any scenario has run. Compilation or a unit suite alone is insufficient. Use the smallest relevant native build/checks, fix clear failures, and launch the actual changed surface on both supported native platforms wherever runtime exists.

Use isolated authorized service test accounts and the reviewed development environment for deterministic states. Do not invent production peers, inject client ranks as smoke proof, manually alter production ratings, upload unconsented bodies, or use preview fixtures as a real service. Labeled development previews may help layout; they are excluded from production and do not prove connected behavior.

1. **Native entry and layout smoke:** launch the real iPhone app/simulator and native Mac app against the available reviewed service; open standings from Physique, inspect the real scope/own state, scroll a row with the complete shared badge catalog, open the real player summary and listing owner, then return. Exercise a small phone/large type and Mac 800×600/live resize/full screen. Observe the actual surface, not only a screenshot assertion or build result.
2. **Service-authority scenario:** exercise placed/listed, unlisted, unplaced, provisional, and unavailable-own-position test accounts. Confirm that a real own position outside the loaded page survives; a hidden seed is never displayed as earned. Use an actual service-confirmed correction scenario where safely available; otherwise state that correction runtime path was not exercised.
3. **Paging/tie/privacy scenario:** cover shared ties crossing a page, an omitted row leaving a rank gap, a zero-visible page with continuation, later-page failure/retry, true end, and expired snapshot. Demonstrate no duplicates or cross-snapshot merge and no own-rank inference from list length. Add or adjust an isolated deterministic regression test for uncertain tie/omission/continuation behavior when it catches a plausible consumer-visible defect; do not test incidental page defaults or text wording.
4. **Real safety/listing scenario:** use two authorized test accounts to remove public listing or apply a block while a row/inspector is visible. Observe immediate concealment, correct focus recovery, truthful pending/confirmed state, and unchanged underlying Elo. Reverse only through the actual permitted owner; no auto-reopened profile/gallery. A pending report does not become a sent receipt or free rating correction.
5. **Failure/account scenario:** interrupt connectivity, invoke recovery, and switch/sign out of the account while a page is pending. Observe no discoverable public-board offline cache, no old own summary/selection/continuation crossing accounts, and no concealed-name flash on return. Preserve only the permitted stale same-account own summary.
6. **Native accessibility/input scenario:** inspect VoiceOver's Shared position, declared-country, Physique Elo, all badges, unavailable/stale, and own-state meanings. Use keyboard-only paging, detail close, safety controls, Escape, and focus repair after a removal. Toggle Reduce Motion/Transparency, increased text/contrast, and non-color differentiation on the actual surfaces.
7. **Lifecycle/energy scenario:** minimize/deactivate the Mac window, leave the iPhone view/background the app, and restore. Observe that nonessential animation/subscriptions do not keep running or replay awards; exercise a low-energy presentation where supported. No new telemetry subsystem or extended performance campaign is needed to satisfy a focused smoke. Do not claim measured battery savings or frame rate without measurements.
8. **Camera/secondary-window boundary:** with camera permission denied or hardware unavailable, verify that this view never requests capture and authorized browsing remains usable. With a real shared active match and suitable physical hardware available, exercise a secondary standings window plus external/Continuity interruption and same-match restoration. If that hardware/session is unavailable, name exactly which physical-camera behavior remains unexercised; a simulator or compile cannot prove it.

Report only checks actually run and outcomes actually observed. Never invent logs, approval, native runtime coverage, energy evidence, or physical-camera proof. A missing external service/login/hardware prerequisite is explicit, not replaced by a fake implementation. Remove disposable verification scaffolding after the exercised path; keep only justified regression coverage consistent with repository conventions.

## Human Verification Handoff — Required

Ask the user to review the code changes. State that each implemented item is ready for human verification, not human-verified. List separately:

- Standings entry and each native composition.
- Canonical positions/shared ties and own-state handling.
- Complete public badge/country identity without photographs.
- Stable paging/refresh/recovery and privacy omissions.
- Connected listing/player/safety routes.
- Input/focus/accessibility, motion, energy, and window/camera boundaries.
- Every actual changed file, with its responsibility.

State known limitations, unresolved prerequisites, and unexercised platform/hardware paths plainly. Give brief actual check evidence, not a screenshot/recording/completion-evidence package. Human review is mandatory. DOCKS contains product behavior only; it never receives logs, source recipes, test results, screenshots, todos, or a fabricated acceptance claim. After the user accepts behavior, update the smallest relevant product context with the accepted plain-language decision.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do this standings slice yourself. Do not delegate repository review or implementation, call generation tools, or redesign another owner's screen/component.
2. **Preserve scope and user work.** Follow direct user decisions over older docs, preserve unexpected existing changes, reuse established architecture, and touch shared files only for the narrow real integration required here. No unrelated refactor, migration, dependency, target raise, telemetry, or global style rewrite.
3. **Real service, no production mock fallback.** No fake peers, Elo, ranks, badges, result scores, permissions, receipts, camera feeds, body galleries, or local ranking authority. A preview fixture is labeled development-only and never a production substitute.
4. **Review prerequisites are real.** Code is not independently shippable before the shared account/service, identity, privacy, safety, native shell, and destination contracts are implemented and human-reviewed. Name missing external requirements honestly; do not hide them behind a compiling scaffold.
5. **User direction wins.** Preserve both native platforms and the approved timer → complete owner-grouped badges → large VERTICAL players wherever a real battle is present. Do not silently revert to side-by-side players or use minimal text to hide safety, privacy, units, or recovery.
6. **Focused actual checks.** Exercise the changed native surface and relevant service behavior where runtime exists, resolve clear reproducible failures, and distinguish actual evidence from unrun scenarios. Do not substitute a test-only, mock-only, or compile-only handoff for the connected view.
7. **Use the project task system only.** Update only the approved relevant implementation todos in `CYCLES.md` after connected behavior, focused checks, and a clear handoff. A checked implementation item is not human approval. No IDE task JSON, duplicate todo system, or evidence/checklists in DOCKS.
8. **Commit and push the scoped implementation.** After a completed meaningful edit/work slice and focused checks, commit only the authorized change with a clear message and push to `origin/main` before yielding. Do not stage another worker's changes, force-push, rewrite history, or leave your implementation only local. Report an exact failed commit/push prerequisite without claiming completion.
9. **Complete the whole slice.** Finish connected behavior, clear fixes, focused native smoke, task updates, human-review handoff, and scoped publication together. No stubs, inert controls, no-op placeholders, or follow-up solely for ordinary testing/fixes/docs/commit/push.
10. **No pointless next prompt.** Create another prompt only for actual substantial separately authorized remaining implementation. Otherwise state No next prompt needed. A real missing prerequisite is named directly rather than buried in a testing-only handoff.

## When You Finish

Return every meaningful implemented item and changed file separately, the exercised iPhone/Mac checks and precise limits, the scoped commit/push outcome, and the human-review request. State the actual remaining external prerequisite if any, or that no next prompt is needed. Do not claim a human accepted the feature or that this future brief itself established implementation.
