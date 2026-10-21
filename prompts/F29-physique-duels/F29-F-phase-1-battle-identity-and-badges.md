# Phase 1 of F29-F — Battle Identity and Badges

## Required Model and Thinking

Run this assignment with **openai-codex/gpt-6-astra:max**: model **openai-codex/gpt-6-astra**, thinking level **max**. Max is a reasoning setting, not a different model identifier. Do not silently fall back to another model or lower thinking level. If this assignment cannot actually run with that configuration, report the concrete dispatch limitation to the main owner rather than claiming the requested specialist run.

This model assignment is for the implementation worker. It does not change the in-app judge, add an Astra tie-breaker, rerun physique comparisons, or modify F29-B's service-approved judging policy. Do all work in the assigned session; no nested agents, delegated review, or model-generation calls.

## Features Included

- F29-F — Service-authoritative launch badge meaning, qualification, removal, and correction presentation.
- F29-F — Complete owner-grouped top battle rails and original tier/achievement medallion components on native iPhone and native macOS.
- F29-F — Optional self-declared country identity, authenticated saved-state behavior, and reuse of the separate V25 editing surface.
- F29-F — Honest loading, empty, stale, unavailable, correction, privacy, accessibility, motion, and energy states.
- F29-F — Bounded integration into the reviewed battle hosts and the existing V25/V17 identity routes, without inventing another screen.

List each meaningful implemented item separately in the human-review handoff. CYCLES.md records implementation only; do not mark an item human-verified.

## Context

Physique Duels uses a true top clock, complete owner-grouped badge rails, and two large vertically stacked participants on both platforms.
F29-F owns identity and earned-badge truth; V25 owns collection/details and country editing, while F29-G owns timer, panels, atmosphere, counters, and Mac shell.
This brief follows a documentation-only design batch; it is not evidence that any identity service, native component, artwork, or production flow is already implemented.

## What You Need to Read First

Use the repository root rather than assuming the terminal starts outside its TimeMaster child. Read the current files, not an old snapshot from the design session.

### Product and review boundaries

- `features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md` — complete authoritative product meaning for this slice.
- `features/F29-physique-duels/DOCKS.md` — shared lifecycle, user decisions, and privacy constraints.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — view inventory and host behavior.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — canonical outcomes, five-result placement, current tiers, streaks, corrections, and time-scoped identity.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — valid judged outcomes, judge blindness, and no-confidence/measurement claims.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — safe identity, blocked/unavailable users, reports, and corrections.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — authenticated access, current permission, deletion, and camera lifecycle.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md` — shared composition, motion, availability, and energy rules.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md` — V25, the separate complete identity view. Do not duplicate it.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md` — V17, the permitted opponent context and safety access.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-h-ready-room/DOCKS.md` — paired host.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md` — capture host.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-k-submission-and-judging/DOCKS.md` — waiting host.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-l-result/DOCKS.md` — finalized host, immediate final meaning, and shared result choreography.
- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md` — native window, camera ownership, focus, and lifecycle.
- `features/DOCKS.md` and the relevant F29 and foundation entries in `CYCLES.md` — actual scope and review status. Documentation placement is not implementation or approval.

### Existing source anchors and visual evidence

- `TimeMaster/Utilities/Theme.swift`, lines 1–81 and 208–228 — 0A0A0A background, 141414/1C1C1C surfaces, FF6A00 action accent, and shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift`, lines 1–38 — Inter styles, existing spacing, touch targets, and readable columns.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift`, lines 20–80 — public material availability, opaque Reduce Transparency treatment, and press response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift`, lines 15–108 and 148–188 — semantic action and earned-Elo crest language. Do not copy Dynamic Type clamps or tiny fixed-size rating text.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift`, lines 25–151 — exercise HUD context only. Its live provisional scores are not physique behavior.
- `TimeMaster/Models/LocalProfileModels.swift`, lines 23–27 and 99–109 — editable local badge previews and milestone flags are not competitive achievements or identity verification.
- `TimeMaster/App/TmaxApp.swift`, lines 8–19 — normal native Mac WindowGroup and current 800×600 minimum.
- `TimeMaster/App/TmaxCommands.swift`, lines 6–37 — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O, and normal text editing.
- `TimeMaster.xcodeproj/project.pbxproj` — confirm the actual native target membership and existing iOS/macOS deployment settings before choosing APIs. Preserve iPhone iOS 16/native macOS 14 compatibility; do not raise targets for decorative effects.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual supplied image. Borrow timer prominence and identity directness, not its horizontal pair, web pills, footage, photographed people, text, or assumed asset rights.
- Discover the reviewed Physique models, services, views, trusted service, and consumer contract tests before editing. The design session identified `TimeMaster/Models/`, `TimeMaster/Services/Physique/`, `TimeMaster/Views/Physique/`, `ranked_server/src/`, and `ranked_server/schema.sql` as integration surfaces, not proof that a complete Physique implementation exists there.

STYLES.md was absent during design. Do not invent one or introduce another app-wide theme.

### Relevant native skills and current guidance

The main design owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selection and its supplied context rather than repeating skill setup or selecting a web stack. Read the relevant installed SwiftUI Pro design/accessibility guidance, SwiftUI Animation guidance, and Apple HIG reference guidance. Apply their compatible native principles; their newest-OS examples do not override the repository targets.

Read the current relevant Apple chapters:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — flexible windows, density, native commands, keyboard/pointer, and full screen.
- https://developer.apple.com/design/human-interface-guidelines/motion — brief purposeful feedback, optional motion, and cancellation.

DOCKS.md is plain-language product context, not an implementation recipe. Independently inspect the real service and source architecture. Do not follow an outdated technical suggestion or create a second authority merely because a document names a prospective file.

## What Happened Last Session

The dedicated F29-F design worker read the shared absolute-path design contract, relevant F29 product areas, the native style and account anchors, installed native guidance, current Apple macOS/Motion HIG, and the supplied screenshot. It specified a four-badge launch catalog, precise correction behavior, owner-grouped full rails, a minted medallion family, optional self-declared country, and native platform states.

That work wrote only F29-F product context and this future brief. It did not create Swift code, a badge endpoint, generated assets, local fake peers, a production mock, or a camera flow. It did not run native builds, tests, formatters, or runtime verification, and did not mark implementation or human review complete. The coordinated main owner owns integrated documentation validation and publication.

## Prerequisites and Review Boundaries

Before code, establish from current source and review records that the shared account/session, persistent Physique competition, canonical outcomes and correction chronology, placement/current-tier/streak authority, visibility, blocks, deletion, and authenticated service contracts are real and human-reviewed. The model's output alone cannot be the source of a badge.

The launch catalog and inherited numerical defaults require the appropriate product review; do not mistake visual approval for approval of all earlier numerical proposals. Use the accepted current contract, not a silent local reinterpretation.

The trusted service must be able to expose a coherent permitted identity/award snapshot and settle account-bound country changes. If F29-F qualification is not implemented yet, implement it only in the authorized F29-F service slice against the real reviewed canonical record. Do not derive achievements independently on the client or infer them from a paginated subset of history. Shared service changes need one clear owner, not concurrent competing migrations.

Before presenting any rail action as complete, the actual V25 own-detail/country route and V17 permitted-player route must exist and accept the selected owner and badge. Integrate with those reviewed owners in the agreed sequence. Missing destinations cannot be replaced by an empty sheet, inert arrow, generic alert, or duplicated custom screen. The same rule applies to battle hosts: a Preview-only component is not the end-to-end feature.

If a real foundation, reviewed contract, required destination, deployment, or physical-camera proof is unavailable, finish the reachable authorized work and report the exact missing prerequisite to the main owner. Do not mask the gap with local earned data, production fixtures, mock services, guessed permissions, a fake camera, or a half-connected completion claim. Do not expand this slice into an unrelated account, camera, or judging rewrite.

## Concrete Design Decisions to Preserve

1. **Timer → You badges → Opponent badges → large You panel → large Opponent panel.** Both owner inventories precede both people. Preserve this order at every native window width and text size. A broad Mac window is not permission for a horizontal matchup.
2. **Full wrapping inventories, not selected trophies.** Every earned launch badge is a visible named operable cell. No hidden +N, three-slot limit, clipped ribbon, carousel, auto-ticker, or hover-only existence. Use scrolling instead of shrinking people or type.
3. **Two medal silhouettes, one family.** Current placed tier and Placed share an opaque soft octagon. Historical achievements use notched circular medals with original sport glyphs. Shared dark enamel, orange rim, ivory-like highlight, Inter labels. No verified rosette, checkmark avatar, agency seal, or national-team crest.
4. **Current streak is not Three Straight.** The medal is historical; Win streak is the current confirmed consecutive-rated-win count, including an honest zero. A loss after earning the medal normally leaves the medal intact.
5. **Stable catalog order.** Placed/tier, First Bell, Ten Rounds, Three Straight, then the current-streak record. Missing items leave no fake slots. New grants never reorder by price or rarity or force-scroll the stage.
6. **Country is optional self-expression.** Flag beside handle; readable localized self-declared name; Not shared by default; neutral unsupported-glyph state. No device/IP/locale/photo guessing, location permission, verification, country filter, or scoring input.
7. **Current versus historical context is explicit.** A completed/history host labels a current rail Current identity and uses a separately authorized current snapshot. C's original match-time rating and attribution remain unchanged. Historical access does not grant current opponent-profile access; unavailable current identity is not reconstructed from old medals.
8. **One short event, not a moving trophy wall.** Keep the rail static during capture. A genuine new own award may settle once within 520ms, but the final-score focal event takes priority. No separate late celebration extends the shared 900ms result envelope.
9. **Native Mac, not phone magnification.** Normal title bar/toolbars, native density, keyboard and pointer focus, optional supplementary inspector, live resize, and minimum-window scrolling. The inspector never holds badges omitted from the stage.
10. **V25 owns the identity screen.** Reuse its collection/detail and country controls. F29-F owns meanings and shared components; no second badge settings flow or unrelated Profile redesign.

## What to Build

### 1. Real badge qualification and consistent presentation state

Use the trusted service's effective canonical Physique record and existing authority patterns. The public/current snapshot must distinguish authoritative empty, loading, unknown, stale, correction-settling, unauthorized, and earned states. Treat badge set, placement, tier, and streak coherently rather than composing mismatched revisions.

Implement the complete launch catalog:

- **First Bell:** at least one effective valid AI-judged win/loss/draw. Exclude every forfeit and no-contest.
- **Placed:** currently at least five effective rated results under F29-C, including eligible forfeits. Remove Placed and the current tier when correction returns the account to provisional or unplaced.
- **Ten Rounds:** at least ten effective valid AI-judged win/loss/draw matches. Exclude forfeits and no-contests.
- **Three Straight:** the effective canonical history contains any run of at least three rated wins. Eligible opponent-forfeit wins extend a run; losses, own eligible forfeits, and draws break it; no-contests neither extend nor break it. Later ordinary losses do not revoke the historical badge.

Do not conflate the rated-placement count with the judged-match count. Five forfeits can place an account without First Bell; three opponent-forfeit wins can earn Three Straight without First Bell. Provisional judged matches are real contributions to judged-match milestones.

Show a current tier only when placed and confirmed under C's actual rules: Iron 0–799, Bronze 800–999, Silver 1000–1399, Gold 1400–1799, Diamond 1800–2199, Champion 2200–5000 under the current proposal. The service remains the authority; do not create a second client threshold engine. Before any rated result show Unplaced, never the hidden 1000 pairing seed. With one through four, show the real rating and Provisional count out of five.

Corrections must re-evaluate qualification in original canonical order without rewriting later valid rating settlements. A correction can remove the only three-win run or create a run by removing a loss that separated wins. First Bell/Ten Rounds depend on effective valid judged count. A judged win changed to a judged draw still contributes to those counts. Keep one earned instance, preserve genuine later support, and distinguish qualifying time from correction time.

During settlement, keep the last coherent confirmed identity with Updating after review. On settlement apply the updated set/status together. Removals stop being earned immediately; the owner can reach the private explanation. Restorations use sober corrected-status feedback, not a new victory. Pending reports do not speculatively revoke awards. Inactivity, lower Elo, ordinary image expiry, country changes, and public unlisting do not remove historical milestones.

Do not expose another person's qualifying-match identifiers, private progress, case, allegations, or correction rationale through public detail. Blocked/deleted/unavailable identities use neutral protected states and cannot be rediscovered through badge links. Reinstalling, duplicate service delivery, foreground refresh, result reentry, or another device cannot grant a duplicate badge.

### 2. Reusable native medallions and complete owner-grouped rail

Reuse the existing palette, Inter styles, shared button feedback, and measured layout. Build the F29-F components with stable data identity and semantic buttons, not screenshot rendering or a second theme.

Complete the original glyph family described in DOCKS: tier ingot/wedges/blades/sun/diamond/chevrons, First Bell boxing bell, Ten Rounds paired rings and 10, Three Straight three pennants, and the truthful Placed fallback. Use original native vector geometry or approved licensed art. No generation calls or screenshot-person assets are needed. Do not call missing artwork finished; a text-only diagnostic fallback is not the delivered bespoke medallion family.

Keep small art separate from readable captions and hit areas. Do not place Elo or long labels inside tiny medals. Shape, caption, and accessible state distinguish tier, milestone, and live record. The composite Placed/tier cell exposes both meanings without two duplicated medals.

Implement two stacked owner groups. Each contains role, handle, optional permitted avatar and country, scoped rating/placement state, and every permitted earned medal. The confirmed current streak follows the medals. Long handles, country names, captions, mixed-direction text, and larger text wrap without losing attribution. No maximum medal count or silent selected subset belongs in the component.

Integrate the complete rail above both large vertical participant panels wherever the battle composition exists. The rail participates in the central scrolling stage; the real timer and safe controls stay reachable. Keep the camera/evidence aspect-fit and equally framed. Do not place labels or badges on faces, limbs, or evidence regions. Do not introduce an unowned screen to compensate for a rail that does not fit.

Bind host actions to actual V25 selected-badge details and V17 permitted-player context. Own medals expose rule, earned status, owner-appropriate provenance, and correction context. Opponent medals expose only authorized public meaning. An unknown detail load preserves the known medal with Details unavailable and real Retry/Close actions.

### 3. Optional country and identity service connection

Connect the existing V25 country flow to the authenticated account service; do not duplicate the screen. Use the established region catalog and native searchable picker, with a persistent Country or region label and explicit Self-declared meaning. Not shared is a first-class choice.

A local draft cannot become confirmed public identity until acknowledged. Cover saving, rejected/offline, interrupted unknown outcome, cross-device conflict, removal pending, and account-switch states. Preserve the user's meaningful current-session choice on failure; do not silently auto-publish it on a later launch. Resolve an unknown outcome by reading actual state before retrying. Do not silently overwrite another device's newer choice.

Removing a country immediately removes it from local visible surfaces; label pending remote confirmation honestly. Once confirmed, stale history, caches, other restored surfaces, and signed-in windows cannot republish it. Country selection changes no badges, Elo, eligibility, readiness deadline, or match result.

Show a supported flag emoji beside the correct handle. Unsupported glyph uses neutral globe plus readable region, not an incorrect flag or exposed regional-indicator letters. Missing country shows no blank box or guessed flag. The accessible value is the localized region name plus self-declared country/region; never rely on emoji pronunciation.

No automatic local profile-photo upload. No copying LocalProfileSnapshot cosmetic preview values into trusted awards. Preserve Profile's two-side shape and existing exercise destination; do not add a third badge indicator or rewrite app-wide cosmetics.

### 4. Native iPhone integration

Use the existing safe-area/navigation/menu-clearance patterns and forty-four-point action convention. Timer first during a timed phase, complete wrapping You and Opponent groups next, then both large vertical panels. Phone landscape, short screens, and accessibility text keep that vertical composition with normal scrolling rather than tiny avatars.

Identity detail uses the host's native sheet/navigation behavior, growing and scrolling for explanations. Retain visible Close/Back. Dismissal returns focus and scroll to the invoking medal or owner heading. It must not dismiss the active match or acknowledge forfeit merely because the identity sheet was swiped away.

If a modal replaces or obscures capture, stop acquisition and shield private preview immediately. Opening details does not pause the service clock. Return reconciles the same match and follows the actual host's intentional capture recovery. Do not invent another capture self-timer or a delayed result clock.

### 5. Native macOS integration

Support native macOS 14+, normal titlebar and window controls, the existing 800×600 minimum, ordinary laptop windows, wide/full-screen windows, external displays, and live resizing. Do not solve layout with a raised app-wide minimum.

At short heights, scroll the central stage below reachable timer/safe controls. Keep both owner groups above both large vertical players. Wide windows may use the reviewed host's trailing inspector for explanation; it is not badge overflow. If stage and detail cannot both remain usable, move details to the native sheet without losing selected badge, text, focus, or stage state.

Use native keyboard/pointer density and visible focus. Hover adds only optional emphasis/help. Return/Space operate the focused semantic control and never globally capture while the person types. Escape closes the current detail or resolves a meaningful V25 draft before the host's state-aware exit is considered. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O, normal text editing, and unrelated menu behavior.

Cmd-W and quit use actual pre-Go cancellation/active-match consequence confirmation where possible; finalized results close normally. Force termination is not a confirmable voluntary forfeit. Do not claim it can be prevented.

Identity can be read without requesting camera access. Integrate cleanly with real Mac TCC denial/restriction, absent/busy camera, external-camera disconnect, and Continuity-camera loss in the host. No fake preview, prerecorded input, or rated file-picker alternative. Returning from Settings or reconnecting hardware restores authoritative state without extending deadlines.

On inactive/minimized/background/locked state, acquisition stops and private content shields immediately; decoration pauses. Resume the same authorized session. Enforce the reviewed single match/camera owner across windows/devices. Secondary windows cannot start another match, consume another slot, or replay another unlock ceremony.

### 6. Motion, accessibility, and energy

Use the shared press spring, response 0.24 seconds/damping 0.88. Small outline/status changes take roughly 140–180ms; initial loaded inventory uses 160ms opacity, not an unlock ceremony. Pairing/stage continuity can use about 280ms without moving medals across bodies or changing ownership.

A newly confirmed own award visible in the active result session may settle from about 0.96 through no more than 1.04 scale to rest within 520ms with one restrained rim emphasis. Names, final inventory, outcome, safety, and navigation are usable immediately. Multiple awards arrive together; only the first in catalog order receives focal emphasis. If the score result is already the focal event, use only the short opacity arrival. Do not append another celebration beyond the shared 900ms total result window. Reentering, loading existing data, returning from background, scrolling into view, or seeing duplicate state never re-awards.

Corrections and current-streak/tier replacement use sober about-180ms feedback. Country save changes only after acknowledgement. Identity removal, block, deletion, revoked access, and camera stop take effect immediately before decoration. Never animate a false current streak through intermediate counts or roll tiers like a slot machine.

No repeating badge pulse, shimmer, glint, spinning coin, skeleton trophies, parallax, ticker, or extra ambient loop. The host owns at most one quiet ambient layer plus one focal event. Pause all decorative work offscreen, hidden, inactive, minimized, or backgrounded; reduce to static art/minimal opacity under Low Power Mode or thermal constraint. Mid-animation Reduce Motion or lifecycle changes settle immediately to the latest confirmed state. No frame/tick performs network, provider, file, body-image decode, font measurement, camera rebuild, or page-wide invalidation work.

Provide one semantic button per badge. Accessible names include owner, name, actual status, and historical/current meaning; the combined badge includes Placed and current Physique tier. Current streak is a scoped live record, including zero or unavailable. Country is a named self-declaration. Facets and duplicate visual text are not separate accessibility stops.

Use scalable type and wrapping, not Dynamic Type clamps. Increased Contrast and Reduce Transparency preserve readable opaque surfaces and visible focus. Voice Control names match visible captions and disambiguate owner. VoiceOver, Switch Control, and Full Keyboard Access reach every action. Announce a confirmed unlock batch or correction once without stealing focus or reading every timer tick. Opening details focuses the selected heading; closing returns to the trigger, or its owner heading if that medal was removed. An account switch clears old content and draft immediately.

## Prospective Files and Ownership

Discover the current implementation before choosing exact edits. These prospective locations are not instructions to introduce duplicate services or a new global abstraction:

| Location | Bounded responsibility |
| --- | --- |
| `TimeMaster/Views/Physique/Components/PhysiqueBattleBadgeRail.swift`, if that component organization is used | Complete stacked owner groups, stable wrapping, truthful states, and actual selected-detail actions |
| `TimeMaster/Views/Physique/Components/PhysiqueBattleMedallion.swift`, if not already owned by the shared component work | Original tier/achievement shapes and accessible scoped event feedback |
| Existing Physique identity/record representation under `TimeMaster/Models/` | Authoritative snapshot, owner, freshness, qualification, correction, permission, and country-save state; not local achievement inference |
| Existing authenticated Physique service under `TimeMaster/Services/Physique/` | Retrieve actual identity and save country using real account ownership and existing network/error patterns |
| Reviewed V25 and V17 source discovered from their feature ownership | Reuse selected badge detail/country/player context; only bounded integration, no duplicate screen or independent redesign |
| Reviewed ready-room, battle, judging, result, and relevant history hosts under `TimeMaster/Views/Physique/` | Mount the complete rail in the agreed hierarchy and respect current versus match-time scope |
| Existing Physique domain code in `ranked_server/src/` and its persistence organization | F29-F service qualification, consistent corrections, optional region, and permitted identity access only where this slice owns them and shared foundations are reviewed |
| Existing consumer contract-test locations | Focused qualification, correction, access, and save-recovery regressions that catch plausible consumer-visible errors |
| `TimeMaster.xcodeproj/project.pbxproj` | Native target membership only if required by the repository's existing file-registration convention; no target increase |
| `CYCLES.md` | Update only the authorized implementation todos after the connected behavior and focused checks are ready for human review |

Do not modify Theme, ProfileDesign, shared glass controls, app commands, existing exercise ratings/privacy, AI Coach provider settings, or unrelated local Profile cosmetics to make this slice easier. A genuine shared integration change needs the smallest justified edit and explicit coordination, not parallel competing conventions. No new README, CHANGELOG, app-wide STYLES file, custom account screen, trophy shop, or global badge framework.

## Observable Acceptance — Both Native Platforms

### Authority and catalog

- A first valid judged loss or draw earns First Bell just as a first valid judged win does; a first eligible forfeit does not.
- Placement, judged-match milestones, and canonical streaks use distinct correct contributions. The fifth rated result can place; the tenth valid judged result can earn Ten Rounds. Pending/duplicate/no-contest events do not manufacture progress.
- A valid past three-win run retains Three Straight after an ordinary later loss while current streak becomes zero. A correction can revoke the only qualifying run or establish one by removing a breaking result.
- A correction that leaves another valid qualification does not briefly remove/re-award the badge. Placement can return from five to four with no stale Placed/current-tier medal. Restoration creates one instance with sober correction wording.
- One coherent revision is shown. Current, last confirmed, unknown, updating after review, unplaced, provisional, and unavailable are distinct. No current-profile data is leaked solely because a historical match is readable.
- Local cosmetic edits, app reinstall, another window, another device, replayed results, and duplicated service delivery do not grant/edit/replay achievements.

### Composition and real actions

- With every launch badge earned for both owners, every badge is present above the two large vertical participants, with no hidden count or selected subset. A current streak can appear independently of the historical medal.
- iPhone portrait/landscape, largest supported text, Mac 800×600, normal laptop, large/full-screen, external-display, and live-resize paths retain the vertical order and usable timer/safe actions. Scrolling is preferred to shrinking bodies or clamping type.
- Each badge opens the correct real owner-specific meaning through V25/V17; there is no empty route, generic placeholder, or accidental body-gallery opening. Closing restores sensible focus/scroll, including when the selected badge was corrected away.
- The native Mac inspector is optional detail, not where missing rail badges are hidden. Resizing can move details to a sheet without losing selection or the active match.
- Country is Not shared initially. Saving, removal, unsupported glyph, unavailable catalog entry, offline failure, unknown save outcome, conflicting device edit, sign-out, and account switch show their true states and recovery. No location inference or rating effect occurs.
- Profile retains its existing two-side shape. No local photo is uploaded automatically; the battle reference's people and badges are not reused as assets.

### Safety, input, and lifecycle

- Keyboard, VoiceOver, Voice Control, Switch Control, large type, contrast, Reduce Transparency, and Reduce Motion can identify owner, earned rule, live streak, country self-declaration, freshness, and each action without color/hover/motion dependence.
- Return/Space only activate focused semantic controls. Typing in a country search or report does not capture, Ready, or forfeit. Escape closes the current detail first. Existing Mac shortcuts remain intact.
- Block immediately shields; after Go it does not automatically leave/rerate. Deleted or unauthorized identity cannot be rediscovered through a retained medal, avatar, flag, old detail, or cache.
- Camera-denied, external/Continuity disconnect, inactive/minimized/background, and secondary-window cases preserve real host privacy and same-session deadlines. No camera/file-picker fallback is created by identity UI.
- No flag, badge, handle, Elo, UI screenshot, or decorative artwork reaches judge evidence/context. Clean local face-obscured captures remain the only candidate/still path; opponent pre-result content remains avatar/silhouette plus real stage/count.

### Motion and energy

- Actual new own unlocks can acknowledge once, never before service settlement. Reopen, restore, refresh, correction, and offscreen arrival do not replay a victory.
- Outcome and final accessible meaning are immediately available. Medal motion does not extend the result reveal beyond 900ms or compete with another focal event.
- Reduced-motion and constrained-energy paths preserve all information with static art/short opacity. Offscreen or inactive rails perform no decorative looping work and do not cause per-tick identity requests or camera reconstruction.

## Focused Checks and Actual Native Smoke

Use the smallest relevant service and native checks after the real paths are connected. Update existing broken contract tests. Add permanent regression coverage only for plausible consumer-visible badge/access/save bugs, not source strings, copies, wiring, mock echoes, or incidental timing defaults. Suitable high-risk boundaries are fifth-rated versus tenth-judged counts, three-forfeit win streaks, correction-created/revoked runs, placement rollback, privacy revocation, and ambiguous country-save recovery.

Tests and compilation alone are not proof of the native surface. Run the real native iPhone and Mac app paths where runtimes exist, backed by the reviewed authenticated service or an explicitly isolated nonproduction service environment exercising the actual logic. Preview fixtures may be labeled for layout work but never enter production or stand in for the connected smoke.

Exercise these focused scenarios:

1. **Complete collection and wrapping:** Use legitimately provisioned isolated test accounts through the real service qualification path. Open paired identity with all launch medals and current streaks, including zero beside Three Straight. Scroll the complete rail and large players on iPhone and at Mac 800×600; resize to laptop/full screen and large text. Open exact badge details and return focus.
2. **Correction behavior:** Observe a real isolated administrative correction that makes five rated results become four and another that changes the only qualifying streak. Observe coherent settled state, private explanation routing, no false current award, and no duplicate ceremony on refresh/reopen. Do not falsify production records for a demo.
3. **Country recovery:** Save and remove a real account-bound country, disconnect during a save, restore and reconcile the actual result, and observe a second-device update while editing. Confirm the UI never labels an unacknowledged draft saved. Exercise an unsupported glyph/region rendering case in isolated presentation data without using it as production identity authority.
4. **Safety and time context:** Open a historical result with current identity permitted and then revoked; inspect separation from match-time rating. Block or remove access in an isolated account scenario and confirm immediate protected UI and no stale medal/profile bypass. Confirm badge details never open an opponent still.
5. **Keyboard and accessibility:** On both supported native surfaces, traverse headings/buttons and open/close detail with assistive technology. On Mac type in country search and use Return, Space, Escape, and preserved app commands. Enable maximum useful text, Reduce Motion, Reduce Transparency, and Increased Contrast; observe actual labels and focus rather than relying on accessibility modifiers compiling.
6. **Lifecycle and energy:** During the real host flow, background/minimize and return, make the rail offscreen, enable available energy constraints, and inspect that decoration stops, capture shields/stops appropriately, and the same deadline persists. Open a secondary window and observe single match/camera ownership. Use the project's available native profiling tools if behavior suggests per-frame rebuilding; do not claim a measured frame rate without observation.
7. **Camera availability:** Observe real denied/restricted or unavailable camera states without a fake preview, and external/Continuity disconnect/recovery when hardware is available. A simulator cannot prove a physical camera, Continuity, or thermal path; name those exact unexercised limits rather than substituting a screenshot or fixture.

Record only exercised commands/scenarios and actual results in the final handoff. Do not create screenshot/log proof packages or put verification evidence in DOCKS.md. If one native runtime or physical camera is genuinely unavailable, report exactly what was exercised and what remains unobserved; do not call the unrun platform verified.

## Human Verification Handoff — Required

List separately:

- Launch catalog and trusted qualification/correction behavior implemented.
- Complete wrapping owner rails and original medallion family implemented.
- Country persistence and recovery connection implemented through V25.
- Native iPhone integration and actual entry/detail/return behavior implemented.
- Native macOS integration, resizing, keyboard, and lifecycle behavior implemented.
- Accessibility, reduced/energy behavior, and actual once-only motion implemented.
- Every changed file, identifying any intentionally unchanged shared surface.
- Focused checks and actual native scenarios exercised, their observed outcomes, and exact runtime/hardware/service limitations.

Ask the user to review the code changes and state which items are ready for human verification. Human review remains pending until the user accepts them. Do not claim accepted UI, measured performance, human approval, or a completed feature from compiling alone.

After user acceptance, update only the smallest relevant product context with accepted plain-language decisions. Implementation todos belong only in CYCLES.md. Product documents receive no code, API payloads, checkboxes, verification logs, screenshots, or implementation-completion claims.

## Mandatory Single-Owner Rules

1. No nested agents, delegated repository review, alternate model dispatch, or model-generation calls. Use the required Astra/max worker configuration; do not alter the in-app judge.
2. Stay within F29-F and the bounded agreed callsite integration. Do not take over V25, V17, the shared Mac shell, camera, score counters, or other workers' custom views. Reuse their real reviewed surfaces and the shared architecture.
3. User direction outranks inherited documentation. All badges above large vertical players on both platforms is not negotiable because an older file or screenshot used a horizontal pair. Surface genuine conflicts without silently narrowing the task.
4. Code starts only with the real shared foundations/contracts implemented and human-reviewed. No production mock fallback, fake service data, local earned editing, made-up peer, guessed badge, false verification, stub action, empty sheet, or fake-camera substitute.
5. Use real account authority and current access. Respect clean redacted judge evidence, no opponent video/early stills, block/deletion consequences, separate Physique Elo, and historical/current time scope. Never commit secrets, private media, or provider keys.
6. Use public availability-compatible native APIs and existing theme/control conventions. Do not raise targets, add a parallel global theme, clamp accessible text to fit, or introduce unnecessary wrappers/renderers.
7. Run focused real behavior checks, fix clear failures in the changed path, and exercise the native surfaces. Tests alone are not proof; do not fabricate output or claim unrun hardware scenarios.
8. Update only authorized CYCLES.md implementation todos after connected behavior and checks are ready for handoff. Never mark human approval or use IDE-specific duplicate todo systems.
9. In this future implementation session, commit each completed scoped work slice with a clear message and push the intended changes to origin/main. Do not include unrelated user/worker changes, force-push, or rewrite history. If publication fails or the authorized branch is unavailable, report the exact blocker and do not claim completion.
10. Do not modify the product docs to make incomplete code look finished. Preserve accepted product semantics; after human acceptance update the smallest relevant context in plain language only.
11. Complete the connected slice rather than delivering a component scaffold or a next prompt only for testing, obvious fixes, documentation, commit, or push. Create no next prompt unless genuinely substantial independently scoped implementation remains and the main owner needs that handoff.

## When You Finish

Report implemented items and changed files separately, exercised verification, exact limitations, and publication status. Ask for code review and human verification. State whether any substantive next prompt was needed; do not invent a follow-up merely to close this session.

## Scope Decision Before Finish

- Completed: identify only connected behavior actually implemented and exercised.
- Remaining: identify actual unmet acceptance or missing external/review prerequisites; do not hide them behind a completion label.
- Decision: no next prompt when this slice is complete; otherwise give the concrete prerequisite or the authorized substantial next slice, without a testing-only handoff.
