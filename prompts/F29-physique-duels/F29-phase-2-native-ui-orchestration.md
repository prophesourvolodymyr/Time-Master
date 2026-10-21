# Phase 2 of F29 — Native UI Design and Implementation Orchestration

## Features Included

- F29-A — All twenty-five custom participant-facing views, from lobby and consent to battle, results, support, and privacy.
- F29-F — Truthful battle identity, optional country/region, complete earned badges, and top rails.
- F29-G — Phase clock, large vertical players and pose icons, battle background, final counters, and native Mac presentation.

This is one coordinated UI work slice with thirty-one dedicated specialist briefs and this integration brief. It is not a requirement for thirty-one sequential sessions or a collection of disconnected previews. Every view and substantive component has an owner; native framework alerts and reused controls are not needlessly recreated. List each implemented area separately for human verification and update its own CYCLES.md task only when connected and exercised.

## Context

The prior session documented physique-only AI competition, Elo, safety, and privacy; no F29 production implementation was created. The user now fixes a vertical, animated, concise UI direction and requires both native iPhone and macOS. Design requirements are authorized; the numeric competition proposals, service readiness, and final UI acceptance are not silently treated as approved.

## Requested Models and Reasoning

| Assignment | Exact model selector | Reasoning |
| --- | --- | --- |
| Ordinary view specialists | openai-codex/gpt-6.1-sol | max |
| Battle stage and advanced component specialists | openai-codex/gpt-6-astra | max |

“Max” is the reasoning setting, not a different public model identifier. These are the coding/design workers, not the image judge inside the app. Do not substitute a default or cheaper model because dispatch is inconvenient. If the selected model cannot run, report that exact dispatch prerequisite and keep the ready brief; do not claim that the requested model completed it.

The local model catalog exposes both selectors and max reasoning. The normal task endpoint rejected model overrides for nonhistorical workers in this environment. This requirements-writing batch therefore used separate CLI worker sessions with explicit --model and --thinking max rather than mislabeling default task workers. Future orchestration must verify the dispatcher's actual controls; do not require that particular CLI if a supported task dispatcher can express the same assignment.

## What You Need to Read First

- [F29 product contract](../../features/F29-physique-duels/DOCKS.md).
- [F29-A view catalog and composition](../../features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md).
- [F29-B judging meaning](../../features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md).
- [F29-C independent competition](../../features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md).
- [F29-D safety](../../features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md).
- [F29-E privacy](../../features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md).
- [F29-F battle identity and badges](../../features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md).
- [F29-G shared native components](../../features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md).
- [Supplied visual reference](../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png).
- [CYCLES.md](../../CYCLES.md), Cycle 39, including pending foundation and human-review tasks.
- TimeMaster/Utilities/Theme.swift:1–81 and TimeMaster/Utilities/ProfileDesign.swift:1–38 for real styles.
- TimeMaster/Utilities/TimeMasterGlassControls.swift:20–80 for public material fallbacks and press feedback.
- TimeMaster/App/TmaxApp.swift:8–19 and TimeMaster/App/TmaxCommands.swift:6–37 for native window and command ownership.
- TimeMaster/Views/MainTabView.swift and current navigation catalog; inspect exact locations through find or LSP rather than guessing new APIs.
- Relevant installed SwiftUI engineering, animation, native HIG, and accessibility skills. Select the smallest UI pattern context through the UI Skills CLI. Current project deployment and source conventions outrank a skill's defaults for a brand-new app.

DOCKS.md files are plain-language product context, not implementation recipes. Validate technical direction against actual source, public API availability, and service contracts. Keep source code, API payloads, verification logs, and implementation checkboxes out of product docs.

## What Happened Last Session

The original F29 parent and A–E specifications were committed and pushed as documentation only. The latest user supplied a direct timer/player/badge reference, rejected horizontal player placement in favor of large stacked players, requested distinct user badges, maximum-reasoning per-view agents, expressive motion, and explicitly added native macOS. This requirements pass preserves those decisions without claiming an app screen, generated assets, paid judge evaluation, measured latency, or human acceptance.

## Design Decisions That Every Worker Must Preserve

1. Active stage order is top timer, both owner-grouped complete badge/identity rails, large You panel, then large Opponent panel. Players NEVER become side-by-side merely because a Mac window is wide. Mac inspectors can use spare width for secondary details.
2. All earned launch battle badges are represented; no selection cap, hidden +N, clipped tier, or auto-scrolling ticker. Rails wrap outside camera evidence. Small windows/large text scroll the central content rather than make people or labels tiny. Timer and safe actions remain reachable.
3. The opponent panel before finalization is an authorized avatar/neutral athlete with actual stage and accepted count, not a live camera or early pose still. Selected result media is intentional, moderated, permission-checked, and unavailable for forfeits/no-contests.
4. Country/region is optional, manually selected, self-declared, removable, and described accessibly. No GPS/IP/locale/photo inference, nationality verification, country matching, or score input. Public local profile photos are not uploaded silently.
5. Existing near-black surfaces, toolbar orange, Inter, public native materials, shared controls, and original ivory-athlete art define the family. No web skin, copied reference people, third Profile indicator, private API, target raise, or new global design-system abstraction.
6. Use less text through hierarchy and deliberate details, never through missing consent, unexplained units, hidden warnings, inaccessible icons, fake success, or unclear forfeit consequences. Every error has a real recovery or truthful unavailable state.
7. Motion has a real state cause. Shared timers, one quiet atmosphere layer, pose acknowledgement, final totals, Elo and badges form one vocabulary. Result/outcome and accessible final values are immediate; supporting choreography settles within 900ms and cannot block safe controls. No live body score, scanner, strobe, fake AI countdown, or humiliation.
8. Native Mac is first-class: current 800x600 minimum, resizing/fullscreen/displays, normal titlebar/toolbars/sheets/inspectors, keyboard and pointer focus, nonconflicting commands, TCC/camera resource states, privacy on inactive/minimized/background, explicit close consequences, and one active camera/match per account. It is not a stretched phone or Catalyst substitute.
9. Keep iOS 16 and native macOS 14 compatibility using public availability fallbacks. UI effects do not authorize raising targets.
10. Clean redacted captures exclude all timer, badge, country, name and score chrome. Competitive authority, image lifetime, consent withdrawal, no-contest/forfeit distinctions, exactly-once effects, and independent exercise privacy remain B/C/D/E rules.

## Specialist View Briefs

| Owner | Product context | Future implementation brief | Worker / reasoning |
| --- | --- | --- | --- |
| F29-A-a | [Lobby](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-a-lobby/DOCKS.md) | [F29-A-a brief](F29-A-a-phase-1-lobby.md) | GPT 6.1 Sol / max |
| F29-A-b | [Account Entry](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-b-account-entry/DOCKS.md) | [F29-A-b brief](F29-A-b-phase-1-account-entry.md) | GPT 6.1 Sol / max |
| F29-A-c | [Eligibility And Consent](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-c-eligibility-and-consent/DOCKS.md) | [F29-A-c brief](F29-A-c-phase-1-eligibility-and-consent.md) | GPT 6.1 Sol / max |
| F29-A-d | [Rules And Rubric](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-d-rules-and-rubric/DOCKS.md) | [F29-A-d brief](F29-A-d-phase-1-rules-and-rubric.md) | GPT 6.1 Sol / max |
| F29-A-e | [Pose Guide](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-e-pose-guide/DOCKS.md) | [F29-A-e brief](F29-A-e-phase-1-pose-guide.md) | GPT 6.1 Sol / max |
| F29-A-f | [Camera Setup](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-f-camera-setup/DOCKS.md) | [F29-A-f brief](F29-A-f-phase-1-camera-setup.md) | GPT 6.1 Sol / max |
| F29-A-g | [Match Search](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-g-match-search/DOCKS.md) | [F29-A-g brief](F29-A-g-phase-1-match-search.md) | GPT 6.1 Sol / max |
| F29-A-h | [Ready Room](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-h-ready-room/DOCKS.md) | [F29-A-h brief](F29-A-h-phase-1-ready-room.md) | GPT 6.1 Sol / max |
| F29-A-i | [Battle Stage](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md) | [F29-A-i brief](F29-A-i-phase-1-battle-stage.md) | Astra 6 / max |
| F29-A-j | [Pose Review](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-j-pose-review/DOCKS.md) | [F29-A-j brief](F29-A-j-phase-1-pose-review.md) | GPT 6.1 Sol / max |
| F29-A-k | [Submission And Judging](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-k-submission-and-judging/DOCKS.md) | [F29-A-k brief](F29-A-k-phase-1-submission-and-judging.md) | GPT 6.1 Sol / max |
| F29-A-l | [Result](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-l-result/DOCKS.md) | [F29-A-l brief](F29-A-l-phase-1-result.md) | GPT 6.1 Sol / max |
| F29-A-m | [Score Breakdown](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-m-score-breakdown/DOCKS.md) | [F29-A-m brief](F29-A-m-phase-1-score-breakdown.md) | GPT 6.1 Sol / max |
| F29-A-n | [Pose Gallery](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-n-pose-gallery/DOCKS.md) | [F29-A-n brief](F29-A-n-phase-1-pose-gallery.md) | GPT 6.1 Sol / max |
| F29-A-o | [Match History](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-o-match-history/DOCKS.md) | [F29-A-o brief](F29-A-o-phase-1-match-history.md) | GPT 6.1 Sol / max |
| F29-A-p | [Standings](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-p-standings/DOCKS.md) | [F29-A-p brief](F29-A-p-phase-1-standings.md) | GPT 6.1 Sol / max |
| F29-A-q | [Player Summary](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md) | [F29-A-q brief](F29-A-q-phase-1-player-summary.md) | GPT 6.1 Sol / max |
| F29-A-r | [Safety Hub](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-r-safety-hub/DOCKS.md) | [F29-A-r brief](F29-A-r-phase-1-safety-hub.md) | GPT 6.1 Sol / max |
| F29-A-s | [Report Composer](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-s-report-composer/DOCKS.md) | [F29-A-s brief](F29-A-s-phase-1-report-composer.md) | GPT 6.1 Sol / max |
| F29-A-t | [Case Center](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-t-case-center/DOCKS.md) | [F29-A-t brief](F29-A-t-phase-1-case-center.md) | GPT 6.1 Sol / max |
| F29-A-u | [Case Detail](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-u-case-detail/DOCKS.md) | [F29-A-u brief](F29-A-u-phase-1-case-detail.md) | GPT 6.1 Sol / max |
| F29-A-v | [Review Composer](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-v-review-composer/DOCKS.md) | [F29-A-v brief](F29-A-v-phase-1-review-composer.md) | GPT 6.1 Sol / max |
| F29-A-w | [Privacy And Sharing](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md) | [F29-A-w brief](F29-A-w-phase-1-privacy-and-sharing.md) | GPT 6.1 Sol / max |
| F29-A-x | [Deletion Status](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-x-deletion-status/DOCKS.md) | [F29-A-x brief](F29-A-x-phase-1-deletion-status.md) | GPT 6.1 Sol / max |
| F29-A-y | [Badges And Country](../../features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md) | [F29-A-y brief](F29-A-y-phase-1-badges-and-country.md) | GPT 6.1 Sol / max |

## Advanced Component Briefs

| Owner | Product context | Future implementation brief | Worker / reasoning |
| --- | --- | --- | --- |
| F29-G-a | [Match Timer](../../features/F29-physique-duels/F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md) | [F29-G-a brief](F29-G-a-phase-1-match-timer.md) | Astra 6 / max |
| F29-G-b | [Player Panels And Pose Icons](../../features/F29-physique-duels/F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md) | [F29-G-b brief](F29-G-b-phase-1-player-panels-and-pose-icons.md) | Astra 6 / max |
| F29-G-c | [Battle Background](../../features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md) | [F29-G-c brief](F29-G-c-phase-1-battle-background.md) | Astra 6 / max |
| F29-F | [Battle Identity And Badges](../../features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md) | [F29-F brief](F29-F-phase-1-battle-identity-and-badges.md) | Astra 6 / max |
| F29-G-d | [Score Counters](../../features/F29-physique-duels/F29-G-native-ui-components/F29-G-d-score-counters/DOCKS.md) | [F29-G-d brief](F29-G-d-phase-1-score-counters.md) | Astra 6 / max |
| F29-G-e | [Macos Shell](../../features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md) | [F29-G-e brief](F29-G-e-phase-1-macos-shell.md) | Astra 6 / max |

## Real Dependencies and Dispatch Order

### Foundation and contract gate

Read current CYCLES and the real backend/account/navigation state. The previous documentation pass did not implement F29, make service access available, or validate a judge. Before production-rated UI integration, the authenticated persistent HTTPS service, shared match/evidence/result contracts, legal consent, accepted capture pipeline, authoritative rating and finality, protected media, and actual safety operation must be real and reviewed as required. Do not manufacture contracts inside twenty-five view models, make unimplemented buttons look connected, or call a collection of preview fixtures a feature.

The current task is satisfied by requirements and specialist briefs. A later implementation start must resolve the real prerequisite slice, not silently convert this UI request into unrelated backend work. If a required external credential/service/hardware or material product decision is missing, state the exact inaccessible prerequisite and finish all reachable authorized work; no fake fallback or “complete scaffold” claim.

### Shared component gate

After prerequisites are ready, establish the common native representation and boundaries once under the integration owner. F29-F and F29-G children can be assigned concurrently ONLY after the actual input/output ownership and distinct file sets are agreed. The badge owner alone owns earned identity semantics and the component; the Mac shell owner owns the window and input boundary; the timer owner owns phase clocks; the panel owner owns player rendering; the background owner owns atmosphere; the counter owner owns numeric reveal. Framework alerts and shared app controls are reused.

Independence here permits design writing and later carefully scoped implementation of shared consumers under established interfaces. It does not waive the project's human-review dependency rule. Hand shared connected components to the human before dependent implementation begins where that rule applies; do not chain unreviewed pieces into a misleading complete feature.

### View groups under reviewed shared contracts

- Entry and understanding: A-a through A-f. Account uses existing auth; consent requires real policy recipients, not invented providers.
- Match lifecycle: A-g through A-k. Ready/battle/review use the same authoritative match and camera owner. The A-i specialist owns composition, not its own clock or renderer.
- Results and progression: A-l through A-q. Result and category breakdown consume validated B data; history/standings consume C; gallery consumes current D/E access and never a cached permission assumption.
- Safety and privacy: A-r through A-y. Forms, receipts, cases, appeals, withdrawal and deletion must use actual D/E service behavior; they are not static legal pages or local-only report queues pretending to be submitted.

A stage of one journey is not an independently shippable feature. Dispatch only genuine independent file slices, never agents racing on MainTabView, shared models, Xcode membership, CYCLES, or the same component. Main integration owner owns those shared edits and commits the coherent verified result. Writers must report a conflict rather than overwrite another worker.

Canonical overlapping-route boundaries are fixed before dispatch: A-t owns the case list/selection host; A-u owns its one detail document and inline safe additional-information response; A-v owns every new safety-appeal/outcome-dispute composer. A-c owns first grants and affected reconsent, while A-w owns ongoing privacy/withdrawal/removal/listing and the one protective request mechanism. A-l owns compact Result; A-m owns full Breakdown, both consuming G-d numeric presentation. Native Mac list/detail hosting embeds the same canonical document, not a third inspector or duplicate form. Treat integrated smoke scenarios traversing another owner as consumer checks, never permission to recreate its view.

## What to Build in a Later Implementation Run

Implement every connected view and component in its assigned brief, with real data, persistence, authorized service behavior and both native targets. No dead safety links, badge placeholders, hardcoded opponents, photo-library rated fallback, fabricated allowance/rating, or production preview mode. Keep the product context's complete state distinctions and the user's hierarchy. New original art may be generated or commissioned only through an authorized asset workflow and must match the existing family; no generation is claimed by this requirements pass.

Before editing exported code, use the available LSP for references and actual declarations. Reuse existing source patterns; avoid type-erased page factories, a second global theme, cross-feature rewrites, or per-view timer/camera/network authority. Keep render paths allocation- and computation-conscious. Modern effects need older-system equivalents, not target raises. Sensitive cleanup and revocation happen before animation, with no media-bearing diagnostic replay.

## Prospective Files and Integration Ownership

- Specialist-owned view sources: TimeMaster/Views/Physique/, each focused view in a separate appropriate file.
- Shared components: feature-owned component sources within that same area, with exactly one semantic owner each.
- Native representation and service/capture boundaries: TimeMaster/Models/PhysiqueDuelModels.swift and TimeMaster/Services/Physique/, established once by the integration owner against actual reviewed contracts.
- Native page registration and saved navigation: TimeMaster/Views/MainTabView.swift and the current catalog implementation, edited only by the integration owner.
- Native Mac commands/window integration: TimeMaster/App/TmaxApp.swift and TmaxCommands.swift, coordinated with the Mac-shell owner; preserve existing commands and global behaviors.
- Profile link: existing Profile surface, only scoped routing/authorized identity as needed, no third side badge.
- Existing Xcode target membership/project registration: integration owner only, ensuring both native targets include the feature and any original approved assets.
- features/F29-physique-duels product docs: accepted decision updates only, not evidence or implementation recipes.
- CYCLES.md: each named implementation task and separate human-review handoff, scoped staging to avoid concurrent project edits.

These are prospective ownership boundaries, not proof the files or service already exist. Exact symbols and target membership must be inspected, not guessed or text-edited in place of available code intelligence.

## Observable Acceptance — iPhone

- Enter through saved navigation without resetting order/selection or reinserting a deliberately removed page.
- Exercise first visit, sign-in/restore, ineligible/decline/reconsent and camera denied/absent/interrupted states; unrelated app routes stay usable.
- Complete a real paired sequence with two eligible consenting adults: search, readiness, synchronized start, all three guided poses and bounded retakes, actual upload/check state, valid judgement, result, rating and saved history.
- Top timer and complete owner-grouped badges precede large vertical players; no body thumbnail/live opponent appears early and no badge covers evidence. Small/large phones, landscape where supported and largest text retain actions without unreadable shrinking.
- Selected/replaced masks, bystanders, poor evidence, ambiguous clothing and service moderation failures have specific private responses without a fake zero or accusation.
- Exercise valid win/loss/draw, eligible forfeit and no-contest separately. No-contest/refusal/timeout never manufactures points or a gallery; draw can have nonzero Elo under unequal ratings.
- Use every safety/privacy route: hide/report without enlargement, uncertain receipt/retry/duplicate, block before/after Go, case and appeal decisions, sharing withdrawal, media expiry and account deletion. Protection is immediate and another account never inherits private cache.
- Final scores and Elo retain precision and unit meaning, final outcome is immediate, the total reveal remains short, and history/reconnect never re-awards. Unplaced/provisional/current badge/earned milestone states are truthful.

## Observable Acceptance — Native Mac

- Run the actual macOS target, not Catalyst or a browser surrogate. At current 800x600 minimum, ordinary laptop, large/fullscreen and external-display layouts, players stay vertical, the clock/actions remain reachable and body evidence remains aspect-fit. Resize through those states without restarting camera, stage, retakes or clock.
- Exercise keyboard-only Tab/Shift-Tab, focused Return/Space, Escape, menu commands, pointer hover/click and clear focus restoration. Existing shortcuts remain intact; typing in a report cannot capture a still or activate Ready globally.
- Exercise native sheets/popovers/inspectors, window close, quit prompt where applicable, minimize, hide, inactive app, lock/interrupt and restore. Camera and private snapshots stop/shield immediately; authoritative deadlines continue; force termination is not mislabeled as confirmed voluntary forfeit.
- Exercise TCC denial/restriction, no/busy camera, external device or Continuity disconnect/reconnect and an accepted-set judging continuation while no window is active. No fake preview or file-picker substitute is used.
- Open another window or device for the same account. It must restore the one active match without a second camera owner, pairing, upload set, charge, judgement or award. Reopening an expired/withdrawn/blocked gallery cannot bypass current authorization through stale links or caches.
- Exercise the same result, history, standings, badge/country, report, review, consent and deletion paths as iPhone; native Mac is not complete merely because the window compiles.

## Motion, Accessibility, Privacy and Focused Verification

Run the actual changed native surfaces after integration; focused tests alone are not proof of UI. Use existing relevant tests for broken contracts and plausible boundaries; add permanent regressions only for meaningful consumer-visible risks such as duplicate settlement, stale redaction acceptance or mixed-account media. Do not add source-copy/wiring/mock-echo tests. Preview fixtures are labeled preview-only and must not leak into runtime behavior.

Exercise Reduce Motion and Reduce Transparency, largest text, increased contrast, real VoiceOver labels/focus, keyboard and safe-gesture alternatives. Announce milestones, not every timer tick or counter interpolation. Check a long handle, missing/unsupported flag, all badges earned, no badges, provisional correction, zero/negative/bounded values and restored history. Do not claim a screen-reader or physical-camera check that was not run.

Observe active/inactive/minimized/offscreen work and energy reduction. One quiet atmospheric layer cannot rebuild the camera, decode photos, read files or invalidate the entire page per frame. Actual clock correctness remains independent of frame rate and animation cancellation. Name thermal/physical hardware scenarios not available in the runtime rather than claiming measurements. Delete throwaway smoke scripts and temporary scaffolds after useful evidence; no evidence package, screenshot archive, TODO scaffold, or testing-only next handoff is required.

## Human Verification Handoff — Required

List every implemented view, shared component, meaningful integration task and changed file separately. State the behavior and actual focused checks exercised on each platform. Ask the user to review; never claim human approval, measured model accuracy or App Store approval. Keep not-yet-connected work pending rather than marking a compiling surface complete. The user has not accepted the finished UI simply by asking for its requirements.

## Mandatory Agent Rules

1. Use the exact assigned model with max reasoning. Read the relevant specialist brief and real source first; do not infer secret model availability or claim a fallback is the requested worker.
2. Each specialist owns one assigned view/component slice and must not spawn nested agents. The integration owner alone delegates the mapped independent slices and owns shared files.
3. Build real connected behavior with all states on both native platforms. No stubs, no production mock fallback, no fake scores/data, no dead buttons, and no narrower “scaffold” delivery.
4. Preserve private consent, clean redacted evidence, counterpart access, exercise privacy, separate Elo, real deadlines, exactly-once outcomes, all top badges and vertical player hierarchy.
5. Run focused checks and the actual affected surfaces after the coherent slice. Fix clear failures rather than leaving an implementation-only or test-only handoff; do not run simultaneous formatters/builds while agents share edits.
6. Update only owned CYCLES.md implementation tasks, with separate human-review tasks left pending. Do not put checkboxes or verification evidence in DOCKS.md.
7. Commit and push the coherent scoped changes to origin/main before yielding. Never stage concurrent unrelated changes, force-push or rewrite history. A failed commit/push is an exact publication blocker, not completion.
8. Direct user decisions win. Technical choices need independent validation; change the smallest relevant product context after accepted behavior, or document a directly approved decision before implementation.
9. Do not raise deployment targets, add private frameworks, replace the global design system, redefine badge verification, introduce country tracking, or redesign unrelated features.
10. Finish reachable substantive work; create no next prompt solely for testing, cleanup, documentation, commit or push. Existing specialist briefs are requirements, not a reason to force artificial session boundaries.

## Scope Decision Before Finish

Completed means all authorized connected behavior, focused native checks, scoped CYCLES updates, publication and clear human-review handoff. List actual remaining work and exact external prerequisites without fabricating success. Choose no next prompt unless a genuinely substantial distinct implementation slice is needed; the mere existence of another view brief does not require a separate session.
