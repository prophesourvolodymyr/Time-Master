# Phase 1 of F29-A-y — Native Battle Identity, Badges, and Country

## Model Assignment and Execution Mode

Requested assignment: **openai-codex/gpt-6.1-sol:max**.

Execution model: **openai-codex/gpt-6.1-sol**. Thinking level: **max**. Max is the reasoning setting, not a different model name or an in-app judge. Do not silently substitute another worker model or lower the thinking setting. If the dispatcher cannot honor this assignment, report that exact limitation before implementation. This assignment does not select or change the model used to judge Physique matches.

This is a future implementation brief created during a documentation-only design batch. Its presence does not authorize Swift changes, assets, service scaffolding, builds, tests, or publication during that batch. Begin the code slice only in a later explicitly authorized implementation session after the real prerequisites below are implemented and human-reviewed.

## Features Included

- F29-A-y — The participant's native Battle identity surface on iPhone and native macOS.
- Read-only presentation of the complete launch badge collection and current competitive standing, using F29-F/F29-C authority.
- Optional manually chosen country or region, including a true acknowledged remove operation, inside this same view using platform-native pickers.
- Narrow entry/presentation integration, explicit asynchronous states, focus/accessibility, and event-driven motion for that surface.

These are parts of one functional slice, not permission for another country screen, opponent-profile browser, app-wide Profile redesign, local badge editor, or backend replacement. List each meaningful implemented item separately in the human handoff. Update only the corresponding implementation todos in CYCLES.md after connected checks and the handoff; human review remains pending until the human accepts it.

## Context

The user wants a minimal-text animated sports experience on both iPhone and native macOS, with all public badges above two large vertically ordered participants whenever a battle is present.
Battle identity makes every launch award understandable and lets the participant choose or remove an optional self-declared country without editing competitive achievements.
This phase consumes reviewed identity, badge, record, and native-host foundations; it does not manufacture them.

## What You Need to Read First

Read product context as product intent, not an implementation recipe. Independently check API availability, existing state/presentation ownership, and real service capabilities before choosing code.

### Exact repository documents

- `AGENTS.md` as already supplied by the project context; do not rediscover unrelated agent files.
- `features/DOCKS.md`, the registered F29 area/owner links.
- `CYCLES.md`, the active F29 implementation and prerequisite-review rows.
- `features/F29-physique-duels/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md` in full.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md`, Accepted Inputs and Judge Blindness.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md`, Unplaced/Provisional/Placed, tier, Record/Streak, corrections, public visibility, and unavailable identity.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md`, identity protection, blocks, reports, and account-state consequences.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md`, public recipients, account/camera lifecycle, current access, country-independent consent, deletion, and honest receipt uncertainty.
- Resolve F29-F's canonical DOCKS.md and the shared battle identity/rail host from the integrated F29 parent/index, then read their full relevant contracts and reviewed source. The design batch assigned authority to F29-F but did not establish an existing canonical F29-F path in this worker's starting tree. Do not invent that path, schema, store, or review status. A missing registered real contract is a prerequisite gap, not permission for a local substitute.

### Existing source anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing near-black surfaces, orange actions, shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter typography, existing spacing, readable-column conventions, and touch target.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public material availability, Reduce Transparency fallback, shared press response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — familiar action and earned-Elo crest language. Do not copy Dynamic Type clamps, fixed-size label compromises, exercise semantics, or a fake starting level.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only; no Physique live provisional scores, share bar, or early winner indication.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local cosmetic badge previews are not competitive achievements, placement, or identity verification.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar, current 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O, and text-editing behavior.
- `TimeMaster.xcodeproj/project.pbxproj` — confirm actual target settings; preserve iPhone iOS 16 compatibility and native macOS 14 compatibility. No deployment-target raise to simplify this view and no 26-only assumption.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow timer-first hierarchy and immediate identity recognition, not horizontal players, web pills, people, footage, captions, or rights to those faces.

`STYLES.md` was absent in the design batch. Use existing source conventions; do not create another global style file or invent missing style rules.

### Focused native skills and current Apple references

The main owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI for this design batch. Reuse that selection; do not repeat setup/installation or introduce a second design system. Its published skill entry is `https://www.ui-skills.com/skills/dimillian/swiftui-ui-patterns` if this worker's local registry cannot resolve it. Read only relevant native presentation, narrow-state-ownership, and async-state material.

Read installed `swiftui-pro` and its focused accessibility/data/navigation guidance, `swiftui-animation`, and `apple-hig-reference`. Apply APIs compatible with the project's existing minimums rather than adopting the skills' newer-OS defaults blindly. Reuse the project's legacy ownership pattern at an iOS 16 integration boundary instead of raising the target for Observation.

Inspect the current Apple chapters relevant to this surface:

- `https://developer.apple.com/design/human-interface-guidelines/pickers` — Best practices: predictable alphabetic values and in-context selection.
- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — native windows, density, keyboard, resize, and multiple displays.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — purposeful brief interruptible motion, alternatives, and no decoration-only gating.

A source lookup is not a runtime accessibility or platform-compliance result. Report actual exercise separately.

## What Happened Last Session

The documentation-only worker specified a single native identity form, inline badge explanations, an in-context iPhone country wheel/native Mac pop-up, optional manual choice and removal, full launch badge semantics, coherent service-owned corrections, privacy boundaries, and scoped motion. The supplied screenshot and relevant source/native guidance informed that specification.

No app view, service contract, model, asset, preview, test, build, native smoke result, or accepted visual prototype was produced by this worker. No existing/shared project files were changed by this worker. The integration owner owns the shared F29-F context, battle rail/host contract, index, CYCLES, validation, and documentation-batch publication. Do not interpret this prompt or the existence of a DOCKS.md as proof that any prerequisite is implemented or human-approved.

## Prerequisites and Human-Review Boundaries

Before app code, identify and read the actual human-reviewed source for all of the following:

1. Authenticated account identity, safe public projection, account scoping, and public visibility/revocation behavior under F29-F.
2. A real country/region catalog and manual choose/clear operation, including current receipt/error/conflict behavior. Saving only country must not overwrite another account field or earned state.
3. Trusted badge catalog and award/progress/correction snapshots, with the meaning of confirmed, stale, unknown, and current placement/streak. The client cannot mint awards from a partial history.
4. F29-C's coherent record/placement/tier/streak and authorized-correction projection; placement counts and judged-match counts are deliberately different.
5. An implemented reviewed native Physique lobby/account entry, presentation owner, shared identity rail, and state-aware match/window/camera host. A view is not independently shippable without these callsites.
6. Current service authentication, visibility, privacy, deletion, and protection behavior required for this surface. Public match operation additionally retains the parent requirements for protected media, authorized service/model operation, consent, and moderation.

Do not perform an unrequested upstream service build, create a second identity store, hardcode production awards, attach a fake match, or fill unavailable data with sample state. If a real prerequisite is absent, name the exact missing contract and implementation/review boundary. Finish the reachable authorized work without pretending the connected screen is implemented; do not ship a stub or mark the slice complete. Unknown capability is not permission to invent a success path.

Do not start a dependent feature merely because these documents have been handed off. The human remains the final verifier for this view and its prerequisite features.

## Design Decisions to Preserve

- **One identity form, not a badge shop.** Preview, optional country, current standing, and four native read-only badge disclosures. No Equip, Claim, selected slots, drag order, premium lock, third Profile side indicator, or badge reset.
- **Current versus historical is explicit.** Placed/current tier and current win streak are live competitive state. First Bell, Ten Rounds, and Three Straight are supported historical milestones, not a current undefeated claim.
- **All public badge meanings remain represented.** Wrap complete owner-grouped rails; no cap, hidden additional count, clipped badges, carousel, ticker, or hover-only meanings. Combining Placed with the actual current tier is allowed only if both meanings remain visible/accessibly explicit.
- **Country is a real optional metadata edit.** Not shown is the default absent a saved manual choice. It is self-declared, not verified, never geolocated, never a scoring input, and freely removable. Preview is a draft, not proof of remote publication.
- **Native controls stay in context.** iPhone expands a native wheel in this view with the full selected name above it. Mac uses a native pop-up picker in the same sheet, not a phone wheel, another country window, or a custom directory.
- **The form does not fake a battle.** No sample opponent or fake timer is added to identity editing. Where a real battle composition exists, the real timer is on top, complete You/Opponent rails below, then two LARGE VERTICAL participant panels, You above Opponent at every width. Wide Mac windows do not become horizontal matchups.
- **Minimal text does not hide consequences.** Keep the field label and optional status, self-declared explanation, actual public audience, not-verified meaning, no-judging effect, stale/error/recovery, and unsaved-removal state readable. Progressive disclosure is for badge detail, not undisclosed publication.
- **Motion acknowledges actual state.** Short draft/status transitions and at most one genuine unlock focal event. There is no ambient loop in this form, badge-wall pulse, flag bounce, verification flourish, or result celebration on reopen.

These choices trade a custom searchable country browser and large collectible tiles for native operation, lower ownership scope, readable badge meaning, and calm disclosure. Do not silently redesign them as a web settings page or collectible loadout.

## What to Build

### 1. Real entry and a single native surface

Connect the real participant's Physique lobby/account identity action to Battle identity through the established F29 presentation owner. Reuse existing navigation and preserve the origin for focus restoration. Do not modify global Profile geometry, saved page order, exercise entry, global account settings, or the app's two-side Profile shape.

Implement the preview and all four launch badge disclosure rows. Preview country may reflect a clearly labeled unsaved draft; badge, rating, and current-streak content always reflects the appropriate coherent confirmed service projection. No local profile photo becomes a public avatar automatically. Only an already authorized avatar may appear, otherwise a neutral permitted silhouette.

On iPhone, use a large native sheet with Close/Save in its navigation bar and vertically scrolling content. On Mac, use a native window-attached sheet, native control density, title, Close/Save actions, readable content, and the existing window/title-bar contract. A minimum-size or short host must not clip actions. Reuse normal native dismissal/alerts rather than another custom modal implementation.

Do not add another battle-stage wrapper. Reuse the reviewed shared rail/identity presentation and pass its real state through the actual owner-approved callsite. The public rail requires all awards above the two large vertical participants, outside evidence framing. Timer and safe host controls remain reachable while rails/stage scroll. The opponent stays an authorized avatar/silhouette plus real stage/count before permitted still access; this view adds no live opponent video, early pose image, score, chat, or microphone.

### 2. Country choose, remove, and acknowledged publication

Implement a country-only draft with a saved baseline, native picker, full localized selected name, inline preview, and Remove country. Native Not shown selection and Remove country produce the same draft clear operation. No device locale, location, IP, account field, photograph, or heuristic preselects a country. Locale affects names/order only.

Keep this text visible before Save: Optional and self-declared, not verified. Shown to paired opponents and on permitted public battle identity. Never used for judging. A country choice does not grant public listing or other consent. Use a flag emoji beside the handle only when supported; otherwise retain the full accessible country/region name with a neutral glyph. No selection has a neutral missing-country state, never a guessed flag. Unsupported saved values remain honestly unavailable and removable, not silently remapped.

Save only a changed valid country through the reviewed authenticated operation. No optimistic public badge/flag publication and no identity-wide overwrite. Acknowledge success only from the real service, disable duplicate save while pending, preserve the draft on a safe failure, and distinguish an ordinary rejection from an uncertain receipt. Use the real status/read operation to reconcile uncertainty before another write; no invented retries or automatic queued publish on reconnect/close.

After confirmed removal, evict the old flag from this account's permitted local identity consumers. Current service projections must respect the remove operation; an old response/history cache must not resurrect it. Do not promise recall of screenshots or previously seen identity. When the removal is unconfirmed, say so.

Handle another window/device changing the saved country without silently overwriting the draft or remote value. Present the refreshed saved choice distinctly and allow an explicit Use saved choice or an explicit retained-choice save against current state, following the existing real contract. Account switch/sign-out/deletion clears the prior draft and visible account-scoped state; late responses cannot apply to the next account. Country changes do not alter an active match, deadline, allowance, outcome, badges, or gallery permission.

Dirty Close prompts Discard country change? with Keep editing/Discard. A clean close has no warning. Closing during a sent uncertain save states that close does not cancel the sent request; the next entry refreshes reality. No unsaved draft is promised to survive process termination or account changes.

### 3. Exact launch meanings and complete states

Use the launch catalog from the reviewed F29-F contract. Preserve these distinctions:

| Entry | Real meaning and consumer-visible boundary |
| --- | --- |
| First Bell | First effective valid AI-judged win/loss/draw; forfeits, no-contests, practice, and pending results never qualify |
| Placed | Currently five effective rated results under C; eligible rated forfeits count, no-contests do not. A correction can return the account to provisional/unplaced and remove the placed tier |
| Ten Rounds | Ten effective valid AI-judged matches; not ten starts, allowance charges, or rated-forfeit records |
| Three Straight | Historical achievement of a canonical at-least-three win streak; eligible opponent-forfeit wins count under C. A later ordinary loss/draw can reset current streak without removing the historical badge |
| Current Physique tier | Only the tier supported by current confirmed placed Physique Elo, never best Elo, a hidden seed, exercise rating, or a cosmetic selection |
| Current win streak | The actual canonical current value; unknown is not zero and Three Straight is not a live three-win claim |

Display all four collection rows in First Bell, Placed, Ten Rounds, Three Straight order. Unearned, currently placed, not currently placed, earned, loading, unavailable/unknown progress, stale, result pending, review pending, correction settling, corrected, and protected/deleted/unavailable identity must be distinct. Dates appear only when actually provided. Do not derive progress from a partly fetched history or substitute a local cosmetic badge preview.

Refresh and correction replace coherent related state; do not mix new placement with old tier or half-updated award counts. A supported correction can remove a historical milestone when its effective qualifying history no longer exists. Normal media expiry, a mere report, or a current loss is not a revocation. Correction/reinstatement is a neutral update, never a new award show or public accusation. Public protected identity removes country/badges along with handle/avatar, without a cached hint.

Unknown authorized catalog entries remain represented with their safe service name and neutral emblem when possible, rather than silently hidden or mapped to another achievement. If detail cannot be rendered, say Details unavailable and offer a real refresh, without invented verification or reward meaning.

Badge read failure and country read/write failure recover independently where the shared contract allows. A badge failure does not reset country and need not block an otherwise valid country save. A country catalog failure cannot turn confirmed badges into empty data. Use one named manual recovery action for the actual failed resource; no fake success or endless spinner.

### 4. Native input, focus, and lifecycle

Support full text expansion, VoiceOver, Voice Control, Switch Control, Full Keyboard Access, and native keyboard-only operation. All rows and controls have semantic labels/values; flags do not expose raw emoji sequences as the sole meaning. Every name, state, criterion, and action is available without hover, long press, or color. Keep the iPhone forty-four-point interaction convention; Mac uses native-density controls and visible focus rather than touch-sized app chrome.

Respect the complete focus/Escape/dismissal rules in the specification. Entry or an intentional destination change can orient focus; refresh does not steal it. Return focus to the origin after closing. Native picker arrow keys/type selection remain local. Return/Space activates only a focused semantic control, never global capture/Ready/Save while typing. Preserve existing app shortcuts.

The form itself never requests camera/TCC, microphone, Photos, location, or health access. Camera denied/busy/missing or external/Continuity disconnect is a real host state, not a reason for a fake preview or rated library import. Leaving capture for the sheet immediately stops/shields acquisition. Background/minimized/inactive/locked acquisition and decoration stop immediately. Return restores the same authoritative match and requires the existing explicit resume where appropriate; deadlines and allowance do not restart.

Use the existing one-account/one-active-match/camera owner across windows/devices. A secondary window does not reserve another session. Cmd-W/Quit that would end an active owning match window gets the real state-aware consequence confirmation where platform behavior permits it; closing this sheet alone is not a forfeit. Force quit cannot be blocked or treated as an intentionally confirmed forfeit.

### 5. Scoped motion and energy behavior

Use existing shared styling and feedback. Implement only the specified small state transitions; do not add a new theme, custom renderer, dependency framework, view-model hierarchy, or material wrapper for this form.

- Country draft glyph/name: stable-area 160-millisecond opacity transition; latest choice interrupts it.
- Status/load/save acknowledgement: scoped 180-millisecond opacity, truthful final content immediately readable.
- Native disclosures: native continuity, at most 280 milliseconds for custom expansion; reversals do not queue.
- Genuine visible unlock: one emblem settles from about 0.98 through at most 1.03 to rest within 320 milliseconds, with other simultaneously earned rows using short opacity. No display cap and no serial reward parade.
- Current tier/streak: 180–200-millisecond final-state change, not rolling inferred intermediate levels.
- Corrections/removals/visibility changes: protect immediately; neutral explanatory opacity only afterward.
- Resize/large-text reflow: immediate layout, no geometry spring on each size update.

Never compete with the host's countdown/capture/result focal event. A badge becomes correct immediately; skip its focal decoration when another event owns priority rather than queueing a second celebration. Keep the shared result motion within its total 900-millisecond envelope. Do not delay safe actions or final accessible values.

No ambient loop belongs to this form. Reduce Motion removes added scale/travel and uses immediate states or at most 100 milliseconds of opacity. Reduce Transparency uses opaque existing surfaces. Low power or serious thermal state suppresses decorative travel/scale. Offscreen/inactive/minimized/background stops decoration. A missed animation never withholds or reawards a badge. Avoid per-frame service work, country sorting, image/flag decoding, font measurement, global invalidation, or rebuilding the camera when identity changes or timers tick.

## Prospective Files to Create or Modify

Identify existing ownership before editing; these are prospective boundaries, not evidence that F29 code exists.

- Create or reuse `TimeMaster/Views/Physique/PhysiqueBattleIdentityView.swift` for this one surface. Keep the native country picker and badge disclosures within its owned composition; no separate custom country screen or second profile destination.
- Modify only the actual implemented Physique lobby/account presentation callsite and, if required, the owner-approved shared identity consumer discovered under `TimeMaster/Views/Physique/`. Name the concrete existing path in the implementation plan before editing it. Do not guess a lobby filename or build an alternate host because the real one is absent.
- Reuse the implemented F29-F identity/badge/country model/service at its real registered path. If its public contract cannot express the required behavior, surface the prerequisite contract gap to its owner; do not create a competing store, endpoint, fake award count, or locally authoritative country cache.
- Reuse `TimeMaster/Utilities/Theme.swift`, `TimeMaster/Utilities/ProfileDesign.swift`, and `TimeMaster/Utilities/TimeMasterGlassControls.swift` without an unrelated shared rewrite.
- Leave `TimeMaster/Models/LocalProfileModels.swift`, global Profile chrome, app commands/window minimums, exercise ratings/privacy, and unrelated feature code unchanged. Those source anchors define boundaries, not an invitation to edit them.
- Update only approved F29-A-y implementation/handoff rows in `CYCLES.md` during the future code session. Do not rewrite the cycle plan, mark prerequisite reviews human-approved, or put evidence/checklists into DOCKS.md.
- Add/adjust an existing focused behavior regression only for a genuine uncertain consumer-visible boundary, following the repo convention. No test of copied labels, source text, trivial forwarding, mock echoes, or incidental defaults.

Do not create screenshots, evidence packages, new READMEs/CHANGELOGs, generated artwork, scaffolding, or next prompts merely to make the slice look complete. Preview-only fixtures, if useful under the existing workflow, are clearly labeled and isolated from production; they are never the service fallback.

## Observable Acceptance — iPhone and Native Mac

| Scenario | Required observable result on both platforms |
| --- | --- |
| Real signed-in entry | Correct account opens the owned native surface, no camera prompt or upload occurs, Close returns focus to origin |
| Empty earned history | No seed Elo/tier or pretend award; four criteria remain understandable; optional country stays Not shown absent a saved manual choice |
| Complete launch collection | All confirmed public badges appear without slots, selection, paid gating, hidden additional count, or clipping; every collection meaning can be opened inline |
| Placement versus judged count | Eligible forfeit can advance five-result placement without qualifying First Bell/Ten Rounds; client does not equate those counts |
| Historical milestone versus current state | After a later real loss/draw, historical Three Straight can remain while current streak resets; tier follows current placed Elo, not best Elo |
| Correction | Real coherent corrected state can remove Placed/tier or unsupported milestones; no client recalculation, mixed snapshots, public accusation, or repeat celebration |
| Country choose/replace/clear | Native in-view picker, no inferred default, full region name, explicit unsaved preview; only acknowledged save changes public country; confirmed remove is not resurrected by old state |
| Uncertain or conflicting save | Draft and confirmed value stay distinct; real recovery works; no silent overwrite, auto-publish on reconnect, duplicate confirmed write, or fabricated receipt |
| Loading/partial/offline/error | Named resource-specific status, meaningful recovery, real stale labeling, no cached-current claim, fake zero, or empty-collection substitution |
| Protected identity/account switch | Country/badges disappear with protected identity; no previous-account draft, cached flag, avatar, or late-response update leaks |
| Large text/localization | Full labels, criteria, audience text, long region names, and actions remain reachable; no text-size clamp or horizontal badge carousel |
| Real battle host | Top real timer, complete You/Opponent rails, then two LARGE VERTICAL players at every width. Scrolling preserves timer/safe actions; no badges over evidence and no early opponent media |
| Motion and energy | True state triggers only, no replay on reopen, no perpetual badge work; reduced-motion/transparency, low power, background and inactive behavior preserve information/protection |

Additional iPhone acceptance: small/short portrait, landscape, largest supported accessibility text, inline wheel operation, VoiceOver, forty-four-point actions, safe-area/keyboard layout where applicable, native dirty-dismiss confirmation, interruption/return without deadline reset.

Additional Mac acceptance: actual native macOS app, not Catalyst or browser; 800-by-600 minimum, normal laptop, large/full-screen/external display, live resize, native pop-up keyboard/type selection, visible focus, standard title bar/sheet behavior, existing commands intact, state-aware Escape/Cmd-W/Quit, secondary-window ownership, TCC denied/missing camera and external/Continuity disconnect handling. Players never become side by side, including while resizing.

## Focused Verification in the Future Implementation Session

Run the smallest relevant available build/check after code, fix clear reproducible failures, and then launch and exercise the changed native surface. Compiling, a preview, or a passing mock-backed test alone is not acceptance. These are prospective scenarios, not results from the documentation batch.

Use approved isolated nonproduction accounts and the real reviewed service paths. Do not write to production competitive records, bypass award authority from the app, generate fake peers, or edit local state to impersonate a trusted badge. If deterministic service fixtures exist, they belong behind the real approved test-service contract, not a production fallback.

1. **iPhone actual surface:** launch the app on an available supported iPhone runtime; open from the real entry; choose, save, replace, remove, reopen; exercise dirty close, real denial/error/offline recovery and uncertain receipt using the supported environment. Inspect the public identity consumer after confirmed save/remove, not only the draft preview.
2. **Mac actual surface:** launch the native target; repeat the country/collection path at minimum and laptop heights, during live resize, full screen and on an available external display. Exercise native keyboard picker, tab focus, Escape nesting, Close, existing command shortcuts, and secondary-window identity updates without another session/camera owner.
3. **Badge semantic boundaries:** using existing authoritative test accounts/events, observe eligible-forfeit placement versus judged milestones, a historical streak badge surviving an ordinary streak reset, and a supported correction returning placed status to provisional or removing a now-unsupported milestone. Observe coherent final state and no unlock replay on reopen/duplicate delivery. Use a focused behavior regression for an uncertain real boundary if needed; do not create a source/wiring test.
4. **Privacy/account boundary:** verify local cosmetic preview edits cannot change competitive badges; account switch clears prior draft/content and ignores a late prior-account result; protected identity has no cached flag/badge leak. Confirm no permission prompt or camera acquisition merely from entering country/badge editing. Inspect the existing clean-evidence path where integrated; do not replace evidence with a screen capture to prove a UI claim.
5. **Accessibility:** actually operate relevant VoiceOver and keyboard controls, names/values, country clear, save/error recovery, every disclosure and dirty-close alert; inspect full text at large sizes, long names/regions, supported right-to-left layout, contrast, Reduce Transparency, and Reduce Motion. State exact modes exercised; do not call an unrun screen-reader path verified.
6. **Energy/lifecycle:** observe that decoration and hidden acquisition stop when offscreen/background/inactive/minimized; low-power/reduced-motion mode keeps final information without scale/loop work. If a real match host is exercised, deadlines and session ownership continue correctly; country saves/disclosures cannot restart camera or clocks.
7. **Hardware-specific host behavior:** on available physical hardware, exercise camera denial, external/Continuity loss, owning-window close and involuntary interruption through the existing host without another allowance charge or false voluntary forfeit. A simulator cannot prove physical-camera or external-device behavior. If unavailable, identify the missing exact device/runtime/service capability and the unexercised scenario without inventing a pass.

Report only actual commands/scenarios and observed behavior. Do not rerun a user-reported failure merely to confirm it. Fix clear failures in scope; do not hide them behind disabled buttons, fake data, a production mock, a narrower test, or another unowned screen. Do not add broad telemetry/retries/frameworks while solving a focused surface.

## Human Verification Handoff — Required

List each implemented item separately: native entry/presentation, complete badge/current-standing semantics, country choose/save/remove and recovery, iPhone focus/accessibility/motion, Mac resize/keyboard/lifecycle behavior, and the minimal affected callsites. List every changed file separately and explain its purpose.

Ask the user to review the code changes and state which items are ready for human verification. The human is the final verifier. A native smoke run or automated check is engineering evidence, not human acceptance. Name any exact missing prerequisite, service behavior, runtime, physical camera, or display scenario; do not claim a broader platform/device pass than exercised.

Keep implementation todos and review handoff in CYCLES.md only. DOCKS.md contains product intent, not verification evidence, screenshots, logs, checkboxes, or implementation completion claims. Record accepted product changes in the smallest relevant DOCKS.md only after the user accepts the resulting behavior, unless the user directly approved that product decision beforehand.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do this scoped code slice yourself. Do not spawn additional agents or use a generation service to fill a missing UI/asset/service prerequisite.
2. **Real authority.** Use the reviewed service for country, catalog, awards, standing, receipt and correction state. No editable earned state, mock production fallback, fake peers, client Elo, invented counts, or no-op control. Clearly labeled isolated previews are not the feature.
3. **No unrelated changes.** Preserve account/navigation, global Profile's two-side shape, exercise privacy/ratings, app commands, target floors, window minimum, and other workers' surfaces. Coordinate required shared changes through their owner rather than overwriting concurrent work.
4. **User direction wins.** Both platforms are required. All public badges, the real top timer, and two LARGE VERTICAL participants are mandatory wherever the battle host exists. Earlier optional side-by-side layouts or narrower phone-first language do not override that direction.
5. **Research before code.** Read the referenced relevant skills and source, reuse established patterns, and check actual availability. Do not silently adopt 26-only APIs, private materials, a new global theme, or an unnecessary abstraction.
6. **Focused actual checks.** Run relevant checks after authorized code, fix clear failures, and smoke the changed native path. No completion based only on compiling, unrun acceptance text, or mock echoes. Keep permanent tests focused on plausible consumer-visible boundaries.
7. **Honest project tracking.** Update only the corresponding CYCLES implementation todos once their connected behavior and handoff are ready. Do not mark human review complete. Do not put evidence or todos into DOCKS.md or duplicate them in an IDE task system.
8. **Scoped commit and push in the future code session.** After a completed connected slice and checks, stage only your authorized changes, commit with a clear message, and push to `origin/main` under the project's existing coordinated publication policy. Never force-push, rewrite history, or stage another worker's edits. If publication fails, give the exact blocker and do not claim published completion. This rule does not authorize git during the preceding documentation-only batch, whose integrated publication belongs to the main owner.
9. **Protect first.** Camera/privacy stop, hidden/blocked identity, account switch, and revoked media access take effect immediately, never after an animation. Country/badges/UI chrome are excluded from judge inputs. Save never changes unrelated identity or competitive state.
10. **Complete the functional slice.** No scaffold, stub, production fixture, disconnected route, test-only handoff, or promise to wire service later. Missing real upstream information is a named prerequisite, not an invitation to fake completion.
11. **No pointless next prompt.** Finish reachable small remaining work in the same authorized slice. Do not create another prompt just for checks, obvious fixes, documentation, a commit, or a push. Create a later prompt only for a genuinely separate substantial authorized feature slice, not to offload this view's unfinished behavior.

## When You Finish

Return the individual implemented items, each changed file, actual focused native/check results, explicit unexercised hardware/runtime limits, human-review request, and publication result. State whether another prompt was needed; none is needed for a fully completed F29-A-y slice merely to verify or publish it.

## Scope Decision Before Finish

- Completed: connected behavior and scenarios actually exercised, not design promises.
- Remaining: exact missing prerequisite or unexercised physical scenario, if any; no concealed stub or no-op.
- Decision: no next prompt for completed F29-A-y; otherwise identify the real external/review boundary without claiming the view complete.
