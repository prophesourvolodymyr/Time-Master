# Phase 1 of F29-A-a — Native Lobby and Saved Entry

## Assigned Model and Thinking

Use **openai-codex/gpt-6.1-sol:max**. The model is openai-codex/gpt-6.1-sol and the thinking level is max. Max is not a different model or an in-app judging mode. Do not silently substitute another model or reasoning level. If the dispatcher cannot honor this assignment, tell the task owner before implementation rather than claiming the requested worker ran.

This assignment concerns native UI engineering. It does not select, replace, configure, or validate the service's image judge. F29-B and F29-E retain the in-app model and provider contract.

## Features Included

- F29-A-a — Physique lobby on native iPhone and native macOS.
- F29-A-a — Complete trusted own-identity/badge presentation using the reviewed shared components, optional self-declared country, meaningful compact record, and actual allowance.
- F29-A-a — Real Find opponent and existing-match recovery entry, private recent-match navigation, loading/empty/provisional/offline/unavailable/review states, and preserved saved page entry.
- F29-A-a — Platform focus, keyboard, accessibility, responsive layout, privacy lifecycle, and event-driven motion for this lobby.

These are tasks within one lobby slice, not permission to build other F29 screens. List each meaningful implemented task separately in the human handoff. Record implementation only in the corresponding approved CYCLES.md todos; do not equate implementation checkmarks with human acceptance.

## Context

The user requested an animated, minimal-text sports UI on both iPhone and native Mac, complete earned badges, and large vertically ordered participants wherever a battle exists.
The lobby is a service-backed earned-identity scoreboard with no fabricated idle timer, camera, opponent, ranking, or award.
This brief implements the detailed lobby product context only after the shared real foundations and contracts have been implemented and human-reviewed.

## What You Need to Read First

Read the current files, not just an older prompt or a screenshot:

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-a-lobby/DOCKS.md — authoritative detailed lobby composition, every lobby state/action, platform adaptation, and interruption behavior.
- features/F29-physique-duels/DOCKS.md — shared lifecycle, real-service authority, approved direction versus proposed numerical policies, and the registered F29-F/shared UI dependencies.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — page shell, preparation, consent, camera, queue, recovery, result, and contextual routes. Apply the newer vertical-player and equal native-platform direction where its older text differs.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — judge blindness, absence of lobby/body-confidence metrics, valid result meanings, and no provisional appearance scores.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — unplaced/provisional/placed, effective record/streak, tier, allowance, active-match authority, private history, and correction coherence.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — private eligibility/restrictions, support, safety access, blocks, and no report-driven rating shortcuts.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — consent, account scoping, permissions, privacy lifecycle, current media access, provider authority, and service-unavailable behavior.
- features/DOCKS.md and CYCLES.md — the current registration, approved task ownership, prerequisites, and actual human-review status. A specification or a completed documentation todo is not a reviewed service foundation.
- The exact F29-F public identity/country/badge product document and the shared native UI documents currently registered by the F29 parent. Resolve their real paths from the current parent index and read them before coding; do not guess a competing path or create replacement badge/rating components because a shared dependency is missing.
- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228 — existing palette, surfaces, and controls.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38 — shared Inter typography, spacing, readable width, and touch targets.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80 — public availability-gated materials, opaque Reduce Transparency handling, and response 0.24/damping 0.88 press feedback. No private APIs.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188 — nearby action and earned-rating vocabulary. Do not copy the Dynamic Type cap, single-line compression, or minimum-scale workaround.
- TimeMaster/Views/Ranked/RankedView.swift, lines 1–127 and 136–237 — measured content clearance and existing account/entry patterns, not the exercise loadout, fixed sixty-second preview, local-profile public-avatar assumption, or its platform sheet sizing.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151 — exercise-only HUD reference. Its live provisional scores are not allowed for Physique.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109 — editable local badge previews are not competitive achievements or verification.
- TimeMaster/Views/MainTabView.swift, lines 149–209 and 270–275 — actual destination routing and selected-page recovery.
- TimeMaster/Views/Navigation/SlotNavigationItem.swift, lines 549–738 — stable destination IDs, current catalog, saved order, and existing migrations. Do not copy Ranked's automatic reinsertion migration for Physique.
- TimeMaster/Views/ScrollingChrome.swift — read the relevant discovered header/clearance sections if the reviewed F29 shell uses them; reuse the existing pattern rather than a second global chrome system.
- TimeMaster/App/TmaxApp.swift, lines 8–19, and TimeMaster/App/TmaxCommands.swift, lines 6–37 — native Mac title bar, 800-by-600 minimum, multiwindow behavior, and reserved existing commands.
- TimeMaster.xcodeproj/project.pbxproj — relevant target membership and actual deployment settings. Preserve iPhone iOS 16 compatibility and native macOS 14; do not raise targets to use a convenient animation or material API.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the supplied reference. Borrow direct hierarchy, not its side-by-side participants, badge overlays, web pills, text, faces, footage, or implied asset rights.
- Installed skill files: /Users/volodymurvasualkiw/.agents/skills/swiftui-pro/SKILL.md with references/accessibility.md, references/navigation.md, references/design.md, and references/performance.md; /Users/volodymurvasualkiw/.agents/skills/swiftui-animation/SKILL.md; /Users/volodymurvasualkiw/.agents/skills/apple-hig-reference/SKILL.md. Load only the relevant material. The coordinator already selected dimillian/swiftui-ui-patterns through the UI Skills CLI; reuse supplied selected context instead of repeating setup or a broad skills search. Registry context is guidance, not an app dependency.
- Apple HIG, Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos and Motion: https://developer.apple.com/design/human-interface-guidelines/motion. Check current platform conditions and API availability separately. These guidelines support native resizing/input and purposeful, optional, cancellable motion; they do not prescribe a new global theme or guarantee App Store approval.

DOCKS.md is product context, not an implementation recipe or proof of service readiness. Preserve the user's accepted behavior while independently validating source patterns and framework availability. Keep source/pseudocode, implementation todos, logs, screenshots, verification evidence, and completion claims out of DOCKS.md.

## What Happened Last Session

A documentation-only UI batch defined the chosen lobby and this future implementation brief. The source palette, typography, tactile controls, exercise identity/HUD boundaries, saved navigation, native Mac window/commands, and supplied reference image informed the decisions. No lobby Swift view, API, badge service, app asset, camera flow, runtime smoke result, or human approval was produced by that documentation work.

Older F29-A prose allowed a first-iPhone emphasis and a balanced two-column comparison on larger windows. The newer user direction requires first-class native Mac support and keeps battle participants vertically stacked at every width. The lobby itself has no battle composition, so an idle timer or fake opponent would contradict service authority rather than satisfy the reference.

The documentation uses one current Elo in identity, best plus Wins/Losses/Draws adjacent, secondary definitions in disclosure/inspector, every real earned badge, and recent real matches. No numerical policy was independently accepted or measured by writing these documents.

## Prerequisites and Human-Review Boundaries

Before writing production UI, establish the actual reviewed foundation from CYCLES.md, source, and the task owner's accepted decisions:

1. Existing account/session and native navigation foundations are implemented and human-reviewed. Account restoration, sign-out/account-switch clearing, and permitted private-cache behavior are real.
2. The F29 page shell and shared route/coordinator exist and are reviewed. Account, Rules, Pose guide, eligibility/sharing, preparation, active-match restoration, History, exact result detail, Standings, Safety/support, private restriction/review, and Privacy and sharing are real destinations. A route enum or inert button is not enough.
3. The trusted Physique service supplies actual account-scoped summary/placement/record data, participation availability and next-slot time, active reserved/started/pending-match state, real recent-match references and outcomes, and coherent correction state. It enforces one account/one match, not a lobby-local boolean.
4. Reviewed F29-F/shared UI provides permitted public identity/avatar, optional country, complete authoritative badges, current tier/streak, stable ordering, detail access, freshness/removal behavior, and once-only award event handling. Local profile badge previews cannot fill this gap.
5. The matched-image service, judging eligibility, protected media, consent, and operating safety/support prerequisites required by F29 are real and authorized before Find opponent may reach rated pairing. A compiled lobby does not authorize public matches.
6. Single-owner camera/match behavior across Mac windows/devices and the approved active-match close/recovery consequences exist. The lobby consumes those contracts, not a second takeover or forfeit policy.

Resolve accessible prerequisite information yourself. If a needed real contract, service, credential, hardware proof, or human decision is genuinely missing, name exactly what is missing and what was checked. Do not invent endpoints, launch a local fake backend, hardcode a rated summary, create a production mock, silently substitute another model, or build an independently shippable shell while calling this connected slice complete. Preview-only fixtures may be explicitly labeled and isolated from production, but cannot satisfy acceptance.

Do not begin dependent screen implementations in this slice. Fix a clear, safe integration defect on the changed lobby path when needed, without expanding into unowned camera, judge, rating, moderation, or asset-generation work. If an architectural or product change is genuinely necessary, surface the concrete conflict before changing that contract.

## Concrete Design Decisions

- **Earned scoreboard instead of decorative hero.** The first viewport prioritizes trusted identity, complete badges, actual Elo, and entry. No new image asset or stranger-body carousel is needed. Shared Physique identity/crest language and Inter numerals carry the sports tone.
- **No idle timer or opponent.** They do not exist before an actual match. Resume opens the one reviewed match flow; the lobby does not embed a small second battle.
- **Badges are complete, wrapped, and owner-scoped.** All public earned items appear; no three-slot cap, +N, clipping, ticker, selected-loadout version, or hover-only detail. Current tier/Placed and current streak are distinct from historical milestones.
- **Minimal text means concise labels, not missing meaning.** Keep Physique Elo, Best Elo, Wins/Losses/Draws, outcome names, allowance meaning, private restriction/recovery instructions, and the required sharing explanation. No arbitrary word budget takes precedence over safety or accessibility.
- **One entry action.** Find opponent in normal idle state; Resume match, Show active window, View match, or a real recovery action replaces it when appropriate. The disabled normal start remains recognizable for zero/unknown allowance or unavailable participation, with an explicit reason and useful retry/detail access.
- **Native Mac behavior, not giant touch UI.** Use native titlebar/toolbars, readable centered scoreboard, native-density recent rows, a supplementary Details inspector, compact native sheet fallback, keyboard focus, normal window lifecycle, and one shared session across windows. Preserve the app's existing minimum and shortcuts.
- **No gratuitous idle loop.** Tactility comes from shared presses, a small confirmed badge spring, disclosure reflow, and route continuity. The result screen owns score/Elo award choreography; history and lobby reopening never replay it.

## What to Build

### 1. Connect one lobby root to real account and F29 state

Implement the root composition described in the lobby DOCKS. Use the existing reviewed F29 account/participation presentation owner rather than adding another independently authoritative ObservableObject, singleton, route stack, camera session, allowance calculator, or badge store.

Read real account-scoped values and retain coherent revisions for coupled Elo, best, placement, record, current tier/streak, and corrections. The service owns all competitive effects. Model loading, genuine empty, unknown, saved, inaccessible, unavailable, review-settling, and terminal data distinctly. Account restoration must not expose a previous account's record while identity is unknown.

Refresh independently failing sections without blanking valid content or letting a failed recent-list request disable otherwise confirmed entry. Conversely, a fresh history response cannot make stale allowance or unknown active-match status safe for pairing. Prevent duplicate user actions while resolving the same entry intent; do not invent a retry framework beyond the existing service contract.

### 2. Compose the shared public identity and full badge rail

Use the reviewed F29-F identity/avatar/flag and badge components. Compose current status first, then the stable launch milestone catalog. Placed and current tier may be one readable status. Preserve every earned badge and current-streak state at all type sizes.

First Bell and Ten Rounds exclude forfeits/no-contests; placement and Three Straight have their different F29-C/F29-F semantics. Consume authoritative awards rather than recomputing them from three recent rows. Handle unknown badge state, stale permitted cache, confirmed removals, placement reversal, and once-only unseen award presentation. A badge-only fetch failure is not by itself a participation restriction if the service can confirm eligibility independently.

Country is optional and manually selected. Use flag emoji with accessible region name, neutral unset state, and readable unsupported-glyph fallback. The shared editor persists the actual choice; no new picker, locale/GPS/IP guess, verification seal, national filter, or judge input. No automatic public upload of the local profile avatar.

### 3. Build compact, semantically correct record presentation

Current Elo belongs once in identity. Adjacent Best Elo and Wins/Losses/Draws remain clearly labeled. Unplaced has no numeric earned Elo/best/tier/public place; provisional has actual earned values and progress out of five. No hidden seed, exercise rating, appearance total, workout level, body measurement, or confidence percentage becomes a lobby statistic.

Use a native iPhone Record disclosure and the Mac Details content for rated-match count, win rate, own forfeit subset, no-contests, and definitions. A zero is a genuine zero, not a missing value. No rated matches means unavailable win rate, not 0%. Corrections replace a coherent summary and remove invalid placement/badges; while settling, show last confirmed values and prevent new rated entry.

### 4. Build the real allowance and state-aware entry bar

Place actual remaining Physique matches and service-supplied next-slot time adjacent to the primary action, using reviewed policy wording. No every-second lobby countdown, local regrant at a predicted time, estimated wait, exercise quota reuse, paid rating bypass, or personal API-key entry.

Find opponent is the deliberate entry intent. If signed out, open the real existing account flow and return to the same intended lobby context after authentication. Do not auto-search, auto-capture, or transfer merely because sign-in, reconsent, Settings return, network return, or region edit completed. The preparation owner obtains the separate affirmative choices and adequate camera preflight before the service may pair.

Check current account, existing reserved/active match, restrictions, unsettled rating, participation service, allowance, and shared preparation requirements. An actual existing match takes precedence over creating another; a stale cancellation cannot become a fresh search. For a local other-window owner, Show active window actually focuses it. If the owner has gone away or another device is involved, use the reviewed service recovery action or Check status; do not invent seamless takeover. Both accepted sets pending judgement use View match for the same match.

Normal browsing and all detail routes consume no allowance. Reservation, Go consumption, pre-Go release, eligible forfeit consumption, and no-contest restoration remain server-owned and exactly once. Returning from result refreshes confirmed values without speculative refunds or another award.

### 5. Connect recent matches and all secondary routes

Show up to three real most-recent started matches from the service with actual permitted opponent label, time, exact outcome, own effective signed Physique Elo change, and pending/correction markers. Search attempts and pre-Go cancellation are not matches. No fabricated row, opponent, score, media thumbnail, or image-bearing empty state.

No contest says No rating change. Pending is not zero Elo. Won by forfeit and Forfeited are distinct from AI-scored outcomes and have no invented score. Corrected rows retain the permitted original/correction context. Blocked/deleted/unavailable opponent identity uses the safe current label and no active profile action.

Whole-row activation opens that exact saved match or its genuine pending state, with authorization checks. It never creates a session, chooses the latest result instead, requests a new judgement, or opens the pose gallery automatically. Expired/withdrawn/blocked media stays governed by the result owner. A missing or forbidden match has a real unavailable-detail response and return route.

Wire Rules, Account, Pose guide, Standings, History, Safety/support, Privacy and sharing, shared badge/country detail, and relevant review access to their existing functional owners. Every visible control performs its named action. Use native presentation rather than adding parallel custom sheets for framework UI. Keep contextual report/hide/block and result-specific score review in their existing owners, not a new lobby report form.

### 6. Preserve saved-navigation entry

Reuse the reviewed stable Physique page registration if already present. Otherwise make only the authorized minimal catalog and MainTab route integration required by this lobby. The destination is available on native Mac as well as iPhone, unlike the existing Mac-excluded Map.

Existing saved order, selected page, navigation placement, and removed Ranked choice must survive. Existing installations discover Physique through Add page rather than an automatic insertion migration; new-install defaults may place it beside Ranked. Use actual catalog duplicate/already-added behavior. Removing the page is not deletion, withdrawal, cancellation, or reset of competitive data. No unrelated navigation preference migration, raw-value rename, or Profile shape change.

### 7. Implement platform composition and native input

On iPhone, measure actual content bounds and existing navigation/floating-control clearance. Keep one central scroll context and a safely reachable allowance/action bar. Let badge, record, utility, and recent-row content wrap at large Dynamic Type/short or landscape size. No fixed screen coordinates, guessed bottom spacer, type-size clamp, clipped badge, scaled-down number, or precision-gesture dependency.

On native Mac, retain the normal title bar and 800-by-600 minimum. Put Rules, Account, and Details in semantic native toolbar controls. Use a centered existing-readable-width scoreboard with native-density recent ledger below and an entry bar aligned to the main column. Large/full-screen/external displays reveal useful content and optional details; they do not enlarge a phone card to fill the screen or introduce side-by-side battle players.

Details reveals the lobby's secondary record fields, allowance policy, and freshness context in an optional native inspector when readable space permits. At compact width it opens the same content in a native sheet on explicit activation. An inspector that no longer fits during live resize collapses to its toolbar control without auto-presenting another modal or stealing focus. Preserve reading position, stable rows, and current intent. Essential identity/badges/record/allowance/start are never inspector-only.

Tab/Shift-Tab, Return/Space on focused semantic controls, Escape on the top allowable native presentation, VoiceOver, Voice Control, Switch Control, pointer, wheel/trackpad, and iPhone hardware keyboard all reach equivalent actions. Do not bind Return/Space globally or intercept them while editing a shared account/safety form. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. Ordinary lobby Cmd-W has no rated consequence; a hosted active match uses its reviewed state-aware close/quit handling where permitted. Force quit is not a confirmed voluntary forfeit.

The lobby itself never requests camera/TCC or acquires a device. Routing to preparation/resume must preserve honest Mac denied/restricted/missing/busy/external/Continuity-camera recovery, immediate privacy stop/shield on inactive/minimized/background state, and one active camera/match owner. No rated file-picker fallback. Moving/resizing the window or changing display scaling never resets deadlines or changes capture selection.

### 8. Implement event-driven motion and energy behavior

Follow the lobby DOCKS motion table and the reviewed shared defaults rather than introducing an animation framework:

- Shared press spring: response 0.24, damping 0.88; no scale under Reduce Motion.
- Real status/icon updates: approximately 160 milliseconds; latest state wins, without a minimum loading duration.
- Confirmed summary-number replacement: approximately 180 milliseconds in stable geometry; final accessible values immediate, no local Elo count-up or result-award replay.
- An actual unseen badge event: one small settle, at most about 1.06 scale, completed within about 320 milliseconds; group simultaneous unlocks, never bounce the existing wall or serialize celebrations. Shared event consumption prevents result/lobby duplication.
- Correction/revocation: logical removal and new eligibility immediately, remaining layout at most about 180 milliseconds; no humiliation, red flash, or loser shake.
- Native record disclosure: approximately 220 milliseconds where custom timing is applicable; native sheets/inspectors retain system behavior.
- Shared route continuity: native behavior or 260–320 milliseconds; destination/safety controls usable immediately, no network/camera work in an animation completion.
- New recent-results affordance: one quiet approximately 160-millisecond appearance, no auto-scroll or pulse.

No indefinite idle animation, ticker, scanning light over a body, camera shader, slot-machine rank, or fake queue-progress loop. At most the shared owner may animate its own genuine active-stage feedback; do not bring it into the idle lobby. Reduce Motion uses immediate changes or short opacity with identical information; Reduce Transparency uses readable opaque shared surfaces. Increased contrast and Differentiate Without Color keep states recognizable.

Pause decorative work offscreen/inactive/minimized/backgrounded and remove it for Low Power/serious thermal pressure. Cancel stale presentation effects when an account, route, correction, or new authoritative snapshot supersedes them. Do not perform service work, image decode, sorting, font measurement, or broad geometry invalidation per animation frame. Allowance refresh follows actual service needs, not a high-frequency timer. Server deadlines and finalization continue independently.

### 9. Preserve privacy and access clearing

No lobby camera/microphone/location/Contacts/HealthKit/Photos request, private body preview, raw pose caching, avatar upload, generated participant, or image-bearing analytics. Country, badge rail, handle, record, rating, and UI chrome never enter judge images/context. Shared capture must keep sending clean locally face-obscured stills, not interface screenshots; do not change exercise-only image privacy.

Sign-out/account switch/deletion immediately removes prior-account private identity state, records, allowance, recent rows, open lobby details, stale route intent, and any private-cache exposure according to the existing contract. Reauthentication retrieves the same permitted result, not a new match. App-switch/inactive privacy behavior protects sensitive account and active feature content without promising copy-proof media.

Only valid AI-judged win/loss/draw and current permission can expose counterpart stills through intentional View poses in the result owner; the lobby never bypasses the twenty-four-hour ordinary expiry or blocked/removed/withdrawn access. Do not change safety/no-contest/eligible-forfeit precedence or treat Report/Block as rating decisions.

## Custom View and Component Responsibilities

Use existing reviewed shared views and native controls first. Split source types according to the repository's current conventions; the following are responsibilities, not a demand for a new abstraction per row.

| Lobby responsibility | Composition and actual behavior | Failure, focus, and motion boundary |
| --- | --- | --- |
| PhysiqueLobbyView | One root state/composition, measured safe regions, native platform adaptation, real route selection and refresh. | Never a second authority/coordinator. Preserve focus on refresh; account change clears private targets immediately. Root appearance does not replay an award. |
| Lobby identity section | Compose shared public identity/optional region, all wrapping badges, one earned Elo/placement presentation. | Distinguish unknown/saved/removed from no earned badges. Shared semantic badge/region controls; one event-owned unlock, no custom verification. |
| Compact record section | Best and Wins/Losses/Draws, with native iPhone disclosure and common secondary fields for Mac Details. | Preserve real zeros and absent meanings; coherent correction. Disclosure remains a semantic native control, not a wholly tappable unexplained metric canvas. |
| Lobby entry bar | Actual allowance/freshness/blocker plus exactly one primary start/resume/recovery control. | Safe-area/native-density placement. Disable duplicate/new entry when authority is unknown; no fake timer, grant, or optimistic refund. |
| Recent section and row | Up to three actual stable match rows plus complete History route and independent retry/update affordance. | Exact saved-match activation, no image or rejudge; correct removed-player/outcome meanings. Retain row focus on update rather than forced insertion. |
| Lobby Details content | Secondary record definitions, real allowance policy, and freshness in native inspector/sheet/disclosure presentations. | No separate analytics screen or new competition store. Native dismissal returns focus; resizing does not auto-modal or lose main state. |

If the shared reviewed History supplies a compatible summary row, reuse it rather than cloning a second outcome formatter. If the shared identity/badge detail is missing, that is a prerequisite gap, not a reason to implement another F29-F here. Avoid extra global wrappers for a one-page composition.

## Prospective Files to Create or Modify

Confirm the actual F29 source structure immediately before editing; these locations are prospective, not claims that files already exist.

- Create or extend TimeMaster/Views/Physique/PhysiqueLobbyView.swift — the lobby root and existing-route integration.
- Create or extend TimeMaster/Views/Physique/PhysiqueLobbyComponents.swift only for the genuinely lobby-owned composition above. Follow the established source-type convention; reuse the actual reviewed shared F29-F/native UI/history types instead of duplicating them.
- Modify the actual reviewed F29 page-shell file only to install this real lobby and consume its existing actions. Discover its exact path from source rather than creating another shell because this prompt predates it.
- Modify TimeMaster/Views/MainTabView.swift and TimeMaster/Views/Navigation/SlotNavigationItem.swift only if the authorized Physique registration is not already provided by the reviewed foundation. Preserve saved-layout behavior and unrelated commands/pages.
- Modify TimeMaster.xcodeproj/project.pbxproj only for required target membership if the current project uses explicit membership; no target raise, Catalyst conversion, or unrelated build setting cleanup.
- Modify existing focused behavioral tests only if this slice changes a real consumer-visible contract or an uncertain boundary warrants a regression. Do not create source-string, copy, forwarding, incidental-default, mock-echo, or bare-not-throw tests. Delete obsolete wording/implementation tests rather than re-pinning them.
- Update only the approved F29-A-a implementation/handoff todos in CYCLES.md. No IDE todo JSON. Do not mark human review accepted.
- Update the smallest relevant DOCKS.md only after the user accepts a new product decision, unless that decision was directly approved before this implementation. Do not add evidence, source code, logs, or task checkboxes there. Do not create README/CHANGELOG/global style files or edit AGENTS/protocols for this slice.

Do not add new Rust endpoints/schema, service authority, provider wrappers, generation calls, production assets, camera pipelines, judge prompts, or unrelated screens to make an unready prerequisite appear complete.

## Observable Acceptance — Both Platforms

Acceptance concerns the changed connected native surface, not a plausible preview or successful compile.

### Identity, data, and navigation

- Physique opens independently in the real page catalog on iPhone and native Mac; existing saved order/selection/placement and removed Ranked choice survive adding/removing/reopening it.
- The idle lobby displays no timer, fake opponent, camera, sample history, invented rank/Elo/allowance, or local cosmetic badge as trusted identity. Current Physique Elo appears once.
- Unplaced with no earned numeric value, provisional progress, placed tier, genuine zero record, unknown data, saved cache, and corrected placement/badge removal are visibly distinct. Current best/record and review state are coherent.
- Every public earned launch badge and current status is visible through wrapping/scrolling at large text, without +N, clipping, or hidden selection. Historical Three Straight cannot claim a current streak. A valid first judged result and a rated forfeit can produce different legitimate badge/placement states.
- Optional country is manual/self-declared with readable accessible name and unsupported/unset fallback, changes only through the shared working control, and introduces no location permission or demographic/scoring behavior.
- Allowance and next slot are real Physique participation data. A zero/unknown/unavailable state cannot start a rated search; a displayed time elapsing does not locally grant a slot. Normal browsing uses no slot.
- Find opponent reaches real account/eligibility/sharing/preparation. No consent-by-navigation, automatic permission, auto-search after sign-in/Settings return, or dead route. An existing match supersedes new entry; another window focuses or recovers the one actual session without a second charge/camera.
- Recent rows use real permitted identities and exact outcome/date/own effect. They open the exact authorized match, not an unrelated latest result or new session. No-contest, pending, forfeit, correction, blocked/deleted opponent, and unavailable detail are honest. Gallery does not auto-open.
- Offline with/without cache, independently failed recent history, unavailable participation service, zero/unknown allowance, restriction, and correction-settling states have their specified actual recovery actions. Refresh does not fabricate empty state, mix accounts, or rerun judgement.

### iPhone surface

- The actual surface works at ordinary and accessibility Dynamic Type, portrait, short/landscape geometry, and both supported navigation placements without clipped badges/labels, a hidden primary action, or overlap from app floating controls.
- At least forty-four-point primary/safety targets, semantic labels, logical VoiceOver order, named native disclosures, hardware keyboard, Voice Control/Switch Control paths, and focus return work without color, sound, haptic, hover, or swipe-only dependency.
- Rules/account/safety/consent presentations remain their real native flows. Their keyboard and close behavior do not expose a competing lobby start button or trigger camera/queue work.

### Native Mac surface

- Launch the native Mac target, not Catalyst or a phone simulator. The title bar and existing minimum remain; the lobby is usable at 800 by 600, ordinary laptop size, large/full-screen size, live resize, and external-display scaling where available.
- Native toolbar controls, readable scoreboard, compact recent ledger, and optional Details inspector work. At compact width Details uses an explicitly opened native sheet; resize never auto-modals, crushes the main column, duplicates focus, or resets scroll/entry intent.
- Tab/Shift-Tab, focused Return/Space, Escape, pointer/scroll, VoiceOver, and visible native focus work. Typing in a shared form cannot trigger matchmaking. Existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their meanings.
- Ordinary lobby Cmd-W has no invented forfeit. Opening/resuming a true active match preserves the owner's real pre-Go/post-Go close handling; force quit/background is not recorded locally as deliberate forfeit.
- Known Mac TCC/camera unavailability leads to genuine preparation recovery, not a preview/file-picker substitute. Multiple windows/devices and external/Continuity disconnect do not create a second camera, second match, duplicate allowance effect, or reset deadline.

### Shared battle boundary

Opening any real paired stage from the lobby must retain the top real timer, both complete owner-grouped badge/identity rails, then two large vertical players, You above Opponent, at every window width. No side-by-side Mac special case, three-badge cap, over-body label, crop/warp, or tiny inline lobby battle is acceptable. The lobby does not take ownership of those other screens; a mismatch is reported/fixed through the actual shared owner, not hidden behind a different lobby route.

### Motion, accessibility, and privacy

- Actual presses/disclosures/confirmed badge events have the specified short tactile feedback; pending/unknown data never animates a false award. Reopen/history/refresh does not re-award, and correction/removal wins immediately over motion.
- Reduce Motion, Reduce Transparency, increased contrast, and Differentiate Without Color preserve the same information and usable controls. No required text is scaled/clamped away.
- Idle/background/minimized/inactive/Low Power behavior has no indefinite decorative loop, camera acquisition, or high-frequency allowance work. Shared clocks remain authoritative.
- Sign-out/account switch immediately removes prior-account private surfaces and intent. Passive lobby entry and all display-only interactions produce no camera or unrelated permission, no avatar/pose upload, no body imagery in recents/notifications/analytics, and no judge input containing country/badges/UI chrome.

## Focused Native Smoke and Accessibility/Energy Scenarios

Use the real authorized development service and supported test accounts/states. Seeded service-side test records are allowed only through the established authorized sandbox mechanisms; they are not production fallback values. Explicitly labeled preview fixtures can support layout work, but never count as these runtime scenarios. Do not mutate production competition records to manufacture evidence.

1. **Launch and saved page entry on both targets.** Start the actual iPhone app surface and native Mac app. Open Add page, add/select Physique, reorder/remove/reopen as permitted, and confirm unrelated saved choices and the absent Ranked choice stay intact. Exercise top/bottom existing navigation clearance on iPhone and native toolbar/window behavior on Mac.
2. **Real identity/record boundary states.** Use available real test accounts or supported sandbox state controls for unplaced, provisional, placed, no badges, all launch badges, current streak zero/positive, unlisted, and a corrected return to provisional. Inspect actual rendered labels, every badge, coherent best/record, region unset/unsupported fallback, and shared detail actions. Do not write permanent tests that simply assert documentation copy or duplicate formatted rows.
3. **Entry and recovery.** Exercise signed-out Find opponent, real account cancellation and success, missing consent, available preparation, confirmed zero/unknown allowance, participation outage, and a real reserved/active/pending match. Observe the actual destination/state, not just a callback. Repeated entry and a second Mac window must return/focus/check the same session rather than create another. Reconnecting from offline must not auto-start.
4. **Recent and account privacy.** Open genuine judged, pending, no-contest, forfeit, corrected, and removed/blocked-identity rows where supported. Confirm exact match restoration and no auto-gallery. Exercise an independent recent-load failure and offline with/without permitted cache. Switch/sign out while content/details are open; observe prior-account data and pending entry intent disappear before another account renders.
5. **iPhone accessibility and geometry.** Exercise large accessibility type, narrow/short/landscape space, VoiceOver, Reduce Motion/Transparency, increased contrast, and keyboard/Voice Control or Switch Control availability. Follow every named control, expand Record, return from real secondary routes, and observe focused element/scroll restoration. Confirm the entry bar is reachable and every badge remains represented.
6. **Native Mac input/window scenarios.** At 800 by 600, laptop and large/full-screen sizes, live-resize with Details open, then explicitly reopen it in compact mode. Exercise pointer/wheel/trackpad and keyboard-only navigation, Return/Space while a real text field is focused, Escape, VoiceOver, ordinary Cmd-W, and the preserved app commands. Use an external display/scaling change if available; name that physical limit if not exercised.
7. **Camera boundary and lifecycle.** Confirm passive lobby browsing never activates the camera or triggers TCC. From deliberate preparation/resume, exercise the existing denied/missing/busy state and external or Continuity disconnect where hardware exists. Background/minimize/lock or close the actual owner; observe immediate stop/shield and same-state return without an extra session/charge/deadline reset. Use two consenting eligible adults for any actual rated camera scenario; never substitute a recorded file, another person's reference image, or generated body. If physical iPhone/Mac camera hardware or paired service state is unavailable, finish all reachable lobby scenarios and report exactly which physical path remains unproven; a simulator preview is not camera proof.
8. **Motion and energy.** Observe genuine press, disclosure, newly confirmed badge, ordinary refresh, correction, return from result, and History reopen. Verify only a real unseen award settles once and final accessible values/actions are immediate. Toggle Reduce Motion during a pending effect and minimize/background during it; ensure the latest logical state wins and no delayed replay/camera work occurs. Inspect activity with the available native tools if needed to establish that the idle lobby and allowance display are not running continuous decorative/high-frequency work; do not claim a battery benchmark or physical thermal test that was not performed.

Run the smallest relevant target build and existing focused behavioral checks after the native path works; fix clear reproducible failures. Tests alone are not proof of UI behavior. Do not rerun a user-reported failure merely to verify their observation; use it as ground truth, diagnose, and exercise the corrected path. Avoid exhaustive screenshot/recording packages, broad unrelated suite churn, and source-text tests. Report only actual exercised scenarios and exact unavailable hardware/service limitations.

## Human Verification Handoff — Required

At the end of this future implementation session:

- List the connected lobby root and saved-navigation entry task separately.
- List trusted identity/full badges/country presentation separately.
- List compact record, coherent corrections, and real allowance/entry recovery separately.
- List recent-match and real secondary-route integration separately.
- List iPhone responsive/accessibility work and native Mac toolbar/inspector/window/input work separately.
- List motion, energy/privacy lifecycle, and any meaningful integration fix separately.
- List every changed file separately with what it owns; distinguish created files from changes to existing shared integration surfaces.
- State the actual focused native smoke/build/accessibility scenarios exercised and any unproven physical-camera, external-display, multi-device, service, or operating-system path. Do not fabricate output or claim human approval.
- Ask the user to review the code changes and state that each implemented item is ready for human verification. A build, screenshot, fixture, or automated test is not human verification.
- Keep implementation status honest in CYCLES.md. Update the smallest relevant product document only after acceptance of a new behavior; put no completion evidence or task list in DOCKS.md.
- Commit and push the completed scoped implementation to origin/main as required below. Say whether a genuinely substantial next prompt is needed; do not generate a testing-only, commit-only, documentation-only, or obvious-fix handoff.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do this lobby work yourself. No delegation, repository-review subagents, generation calls, or unrelated UI/feature changes.
2. **Real foundations before code.** Respect all prerequisites and review boundaries. No stub button, placeholder API, no-op action, fake opponent/rank/score/allowance, local Elo, alternate judge, or production mock fallback. Labeled previews are not acceptance.
3. **User direction wins.** Preserve both native platforms, minimal but meaningful text, all public badges, and vertical large players wherever paired content exists. State conflicts with older prose briefly; do not silently narrow to iPhone or side-by-side desktop.
4. **Reuse established owners.** One account, one active match/camera owner, one real service authority, existing shared identity/badge and action language. No parallel theme, global state framework, custom system-permission UI, or needless wrapper layer.
5. **Scoped edits and cutover.** Adapt to the current working tree, preserve the user's unrelated changes, and migrate every affected real caller without deprecated aliases or disconnected old lobby paths. Fix clear local integration failures on this path; do not delete unrelated code or change unowned product contracts.
6. **Focused checks plus actual native smoke.** Run and interact with the changed surface on both native targets where runtime exists, using the scenarios above. Builds/tests alone are insufficient; unobserved paths are explicitly unproven. No exhaustive evidence package or misleading completion claim.
7. **Update only approved CYCLES implementation todos.** Mark implemented work after it is connected, focused checks pass, and the clear human-review handoff is prepared. These are implementation marks, never human-verification claims. No duplicate IDE task system.
8. **No evidence in DOCKS.** Keep product documentation plain-language. No source/pseudocode, payloads, logs, screenshots, completion checklists, or implementation recipes there. Accepted new product decisions go into the smallest correct DOCKS after user review.
9. **Commit and push the future implementation.** Inspect the completed scoped work slice, commit with a clear message, and push to origin/main before yielding. Do not force-push, rewrite history, stage another worker's unrelated work, or leave this implementation only local. If publication genuinely fails, state the exact blocker and do not claim completion. The earlier coordinated documentation-only batch was published by its main owner; that does not waive this future implementation rule.
10. **Complete the whole authorized lobby slice.** Build, connect real actions, exercise the native path, fix clear failures, update CYCLES, give the itemized human handoff, and publish. No next prompt merely for tests, documentation, obvious bugs, commit, or push. Missing real prerequisite requires an exact honest blocker, not a plausible shell delivered as the feature.

## When You Finish

Report implemented items and changed files individually, actual exercised native checks and limits, commit/push status, remaining real work, and whether any next prompt is needed. Ask for human review of each item. No claim that this document, a model assignment, a compiled scaffold, or an unrun scenario proves completion.

## Scope Decision Before Finish

- Completed: connected lobby behaviors actually implemented and exercised, listed individually.
- Remaining: specific unfinished dependency or external proof, if any, without inventing a follow-up phase for small reachable work.
- Decision: no next prompt for a completed lobby; a new prompt only for a separately authorized substantial implementation slice; otherwise name the exact real missing prerequisite.
