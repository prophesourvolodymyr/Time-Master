# Phase 1 of F29-A-g — Native Match Search

## Required Model and Thinking

Run this UI implementation assignment with **openai-codex/gpt-6.1-sol:max**: model **openai-codex/gpt-6.1-sol**, thinking level **max**. Do not silently substitute a different model, lower the thinking level, or delegate this assignment. If the requested configuration cannot be dispatched, state that exact prerequisite before implementation.

This is the coding/UI-worker assignment, not a selection of the model used inside ranked Physique Duels. The service-approved judging model, rubric, eligibility, and versions remain owned by F29-B and F29-E. No provider or judge switch is authorized here.

## Features Included

- F29-A-g — The native iPhone and native macOS match-search stage, from intentional admission through confirmed queue, cancellation/recovery, terminal search, or real-pair handoff.
- Own public Physique identity and complete shared badge/region presentation above the large vertical player positions.
- The truthful top search clock and bounded current skill-window explanation.
- Receipt-aware admission/cancellation, real reservation reconciliation, and deliberate new-attempt behavior.
- Focus, keyboard, lifecycle, accessibility, reduced-motion, and energy behavior for this stage on both platforms.

List each meaningful implemented item separately in the human handoff. This is one complete connected search slice, not permission to implement other UI owners, a new backend, a second ready room, or a mock competition.

## Context

The user chose a minimal-text, tactile sports UI on native iPhone and native Mac: top real timer, all public badges above two large vertically stacked player panels. This assignment implements only search and its real recovery/handoffs. The product/design pass produced documents, not a working view or approved prototype.

## What You Need to Read First

Read current files before editing; the repository may have advanced since this brief was written.

### Product and review boundaries

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-g-match-search/DOCKS.md` — the full owner specification; read it completely.
- `features/F29-physique-duels/DOCKS.md` — shared competition, privacy, timing, and explicit user decisions.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — preparation entry, lobby continuation, readiness, active-match exit, and existing navigation.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — Pairing Eligibility and Search, Bounded Skill Expansion, Allowance/Cancellation/Interruption Boundaries, and Authoritative Finality.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Accepted Inputs and Judge Blindness; no pre-final appearance scores or search analysis.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — eligibility, exclusions, safe display, and block/exit precedence.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — Camera and Device Privacy Lifecycle, consent withdrawal, Offline before Go, allowance, and operator/provider readiness.
- `features/DOCKS.md` and `CYCLES.md` — locate the actual integrated F29-F identity/badge specification, shared F29 state/motion component ownership, and current human-review boundaries. Read the registered dependency documents rather than guessing paths or copying another worker's component.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image, not only a description. Borrow its immediate timer-and-participants hierarchy; do not copy its people, footage, side-by-side layout, over-body pills, text, palette, or implied rights to reuse faces.

### Existing source anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing near-black surfaces, orange action language, and shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter fonts, spacing, action-size and readable-column conventions.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public materials/native availability fallback, Reduce Transparency, and the existing 0.24-response/0.88-damping press spring.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — nearby action and earned-Elo visual language, not its Dynamic Type clamps or exercise-specific values.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only. Its live provisional exercise scores and mixed horizontal scoreboard are not Physique requirements.
- `TimeMaster/App/TmaxApp.swift:8-19` — native WindowGroup, ordinary title bar, and existing 800-by-600 Mac minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, Cmd-Option-O, and normal text editing.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local cosmetic badge previews are not trusted identity, earned Physique badges, or verification.
- `TimeMaster.xcodeproj/project.pbxproj` — discover the current iPhone and native Mac target configuration. The design baseline is iOS 16 compatibility and macOS 14; do not raise deployment targets or assume 26-only APIs to implement this view.
- Discover the actual implemented files under `TimeMaster/Views/Physique/`, `TimeMaster/Services/Physique/`, `TimeMaster/Models/`, and `ranked_server/` that own shared participation, queue receipts, timer synchronization, identity rails, player panels, camera preparation, lifecycle, readiness, and restoration. Read their relevant sections. Prospective filenames in documentation are not evidence that a contract exists.

### Focused native skills and live references

The design batch already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selection and read its relevant installed files; do not repeat setup or install overlapping visual systems. Relevant selected references are `async-state.md`, `performance.md`, and `sheets.md`. The public source is `https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns` if the installed copy is unavailable; identify that distinction honestly.

Read relevant sections of installed `swiftui-pro`, `swiftui-animation`, and `apple-hig-reference`. Concentrate on availability, accessibility, narrow state observation, scoped/interruptible motion, and native Mac input. Generic skill defaults for new iOS 26 apps or a new Swift toolchain do not override this repository's deployment and build conventions.

Consult the live Apple topics `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` and `https://developer.apple.com/design/human-interface-guidelines/motion` for actual Mac window/input behavior and brief, optional, interruptible feedback. A HIG lookup is not proof that the app behaves correctly.

There was no `STYLES.md` during this design pass. Do not invent a second global style file; reuse source conventions. Product DOCKS files describe behavior, not implementation recipes or evidence.

## What Happened Last Session

A dedicated documentation worker read the shared F29 design contract, existing F29 A/B/C/D/E context, native theme/window/command anchors, relevant installed SwiftUI/HIG skills, the selected UI-pattern source, and the supplied reference image. It chose the vertical starting-gate composition and wrote this brief plus the child product document.

No Swift, service, schema, test, generated artwork, or production mock was created by that design work. No native runtime, physical camera, queue population, latency, cancellation race, accessibility behavior, or energy result was verified. No human accepted an implementation. Shared-document integration, publication, and validation belong to the main batch owner.

The older F29-A responsive paragraph allowed a balanced two-column comparison and treated iPhone as the first surface. The newer user direction explicitly requires native Mac as well and vertical participants at every width. Follow the newer direction. The numerical 100/200/400 bands remain F29-C proposals until reviewed with the real service; do not present them as measured or silently change deployed policy to match a drawing.

## Prerequisites and Review Boundaries

Code starts only after the real shared foundations and contracts this surface consumes are implemented and human-reviewed. Confirm that fact from the actual current review record and source; an unchecked plan or an attractive sibling preview is insufficient.

Required shared capabilities:

- Authenticated account restoration, adult eligibility, current rules/sharing consent, restrictions, and an authorized persistent HTTPS service.
- One account-wide reserved or active Physique participation across devices and windows, with one camera owner and no second queue/allowance charge on view recreation.
- Confirmed admission identity, real search cutoff/time synchronization, actual current allowed skill band, current participation retrieval, real pairing, and authoritative Go.
- Admission and cancellation receipt ambiguity recovery that survives view dismissal/relaunch, plus exactly-once reservation release/accounting. Canceling a client Task is not remote cancellation.
- Honest service readiness and allowance state, including operator/provider quota being distinct from the participant's allowance.
- Real camera preparation and availability/lifecycle contracts, without a library-image or fake-camera rated substitute.
- F29-F trusted own identity/region/all-public-badge presentation, correction/stale handling, and any reviewed shared timer/player-panel components.
- Existing lobby continuation of unresolved participation that prevents a second Find opponent, real readiness with both players' explicit Ready, and active-match rejoin/state-aware exit routes.

Do not build the backend, redefine badge achievements, expand other screen owners, add wrappers that hide missing contracts, or install a local fake service in order to call this child complete. If a required real capability is unavailable, identify the exact missing prerequisite and reachable work without shipping a disconnected stage. Preview-only fixtures can explain a proposed view, but must be explicitly labeled and cannot back production or acceptance claims.

Implementing this search slice does not authorize later dependent work before the human reviews it. Do not mark this UI human-verified yourself.

## Design Decisions to Preserve

### Vertical starting gate

The clock is the first visual anchor. Below it are complete owner-grouped public badge/identity rails, then a large You panel and a large empty Opponent panel. A real pairing fills the lower position through the readiness owner's handoff; both players remain vertical at all widths, including full-screen Mac. Panels never become tiny thumbnails to avoid scrolling. All public badge rows wrap above both panels, not across evidence, faces, or limbs. No clipped rail, cap of three, hidden plus-count, marquee, or hover-only badge meaning.

Only the own group has real identity during search. The lower panel says Opponent and Not paired and must not resemble a real suggested peer. A waiting position is not a fabricated second participant. Use permitted own avatar or neutral system/licensed athlete art; never upload the local Profile photo or use a preflight camera still automatically. This assignment does not generate artwork or reuse the reference's people.

### Real clock, no prediction

Show the remaining service search interval, not an ETA. Joining admission shows a dash. Confirmed queue shows Search left and the actual remaining interval; late admission can start below 1:30. Local zero means Checking search status until service confirmation. Unknown time basis shows Time unconfirmed. A reliable remembered cutoff while offline can remain visible as Original search limit with Search not confirmed, never as proof of queue membership.

When the service confirms a pair, the search clock stops representing an active search; hand off to the readiness owner's real stage and clock semantics. Do not turn leftover queue seconds into a ready deadline or start a decorative 3, 2, 1. The synchronized three-second countdown requires both real Ready acknowledgements and service authority. Search has no independent reconnect-grace clock.

### Honest bounded expansion

Display the real current maximum Physique Elo difference in a concise unit-labeled line. Under the reviewed F29-C proposal that is 100 before thirty elapsed seconds, 200 before sixty, and 400 before ninety. Both players' current bands must admit the pair. No hidden widening beyond the cap, invented nearby-player number, opponent prediction, probability, guaranteed match, or wait estimate. Local timer thresholds alone cannot claim a service-confirmed band change.

### Quiet, camera-off search

Do not keep the camera running merely to decorate the wait. The large own panel is identity presentation, not a video feed. Preparation has already handled the camera; readiness rechecks availability and requires an explicit later action. This avoids concealed acquisition and unnecessary energy, at the cost of not showing live framing throughout search. Do not put fake Camera ready text over a disconnected device.

### Minimal text with complete consequences

Normal content is Searching, the labeled clock, one range/status line, concise identity/badges, the two position labels, and Cancel. Search details uses native disclosure for the maximum duration, bounded-band meaning, No match is used before Go, and cancellation receipt explanation. Never hide a consent recipient, recovery instruction, unit, real forfeit consequence, accessibility name, or limitation to satisfy a word count.

## What to Build

### 1. Connect one real search lifecycle

Bind the surface to the existing shared participation owner rather than owning a second queue state machine in a view. Entry follows successful real preparation and deliberate Continue. Revalidate the account's real prerequisites through that owner. View appearance, SwiftUI identity changes, timer ticks, returning from a sheet, resizing, or opening a second window must not enqueue again.

Present joining, admitted search, confirmed band update, current cutoff, deadline reached but unconfirmed, admission unknown, network loss, recovery, cancellation in flight, cancellation receipt lost, confirmed cancellation/release, release/accounting pending, confirmed no opponent, service/eligibility failure, another participation owner, and real-pair handoff as distinct actual states. Use the DOCKS state table for visible copy and meaningful actions.

Maintain account-specific unresolved participation across navigation and relaunch through the existing shared owner. Ignore superseded queue/admission events according to the reviewed service chronology; do not make view callback arrival order competitive authority. No queue attempt becomes a fake started-duel history row, rating, badge award, placement game, or consumed slot.

### 2. Connect exact timer and range semantics

Use the authoritative cutoff and reviewed synchronized time basis. Present meaningful displayed seconds without driving the entire view or network per frame. Device clock/timezone edits, background return, missed ticks, native sheets, and live resize must not reset or extend the original search. At zero await authoritative expiry/pairing; no negative seconds, looping clock, synthetic final second, or locally finalized No opponent.

Keep current certainty explicit. Do not claim current band or queue membership from a stale snapshot. Range expansion is confirmed policy, not a matching percentage. Unplaced users can use the service's hidden pairing seed without being shown an earned 1,000 Elo.

### 3. Implement receipt-aware Cancel and deliberate new attempts

Cancel before Go is a direct withdrawal intent with no forfeit-confirmation theater. Stop local acquisition and decorative searching immediately, show Cancelling, suppress repeated action submission, and reconcile the same admission/queue/pairing through the real service. Lost receipt becomes Cancellation not confirmed, not Search cancelled.

Check status is retrieval/reconciliation for this attempt. Return is safe navigation, not remote success. The shared existing lobby must retain unresolved receipt/accounting and block another Find opponent until it is resolved. Do not trap the person forever on a spinner; do not clear the pending reference to make navigation easy.

Only a confirmed closed search and released reservation with current eligibility permit Try again to create a new <=90-second attempt. No automatic requeue, endlessly resetting timeout, different rival suggestion, bot, paid priority, or unrequested exercise fallback.

Resolve race cases:

- Cancel while admission is still unacknowledged: retain intent; a late admitted response must be withdrawn, not treated as renewed search intent.
- Pair and Cancel crossing: preserve withdrawal against the same pre-Go pairing; do not play a celebratory reveal while cancel is pending.
- Expiry or accepted cancellation with release/accounting unknown: show Checking allowance; no optimistic increment or second reservation.
- Service already past Go: show Match started and route Rejoin or the real state-aware explicit Exit/Forfeit confirmation. A pre-start Cancel is never consent to rated loss.
- Stale events after confirmed release: no reopening attempt, second allowance change, or stale opponent reveal.
- Other window/device with an existing participation: restore/show its real state, not a second queue or invented takeover. Bring the known local owner window forward when supported; do not advertise a nonworking cross-device handoff.

### 4. Reuse complete trusted identity and badge presentation

Use the reviewed F29-F presentation. Handle is public only as permitted; optional country is manually self-declared with flag/accessible region name and shared neutral unsupported-glyph state. No geolocation, inferred nationality, verified-country styling, country filter, or scoring input.

Show actual Unplaced/provisional/placed meaning and actual Physique Elo. Show all earned public launch badges and the truthful current tier/streak, with canonical order/composed placement and correction rules. Distinguish stale/unknown badge data from confirmed none; never copy editable `badgePreview`, an exercise Elo crest number, or a local display level into trusted Physique identity. Badge refresh must not reconstruct the queue or play unlock effects.

No opponent live preview, early still, chat, microphone, private age/attire declaration, email, report status, subscription, exercise rating, or provisional appearance score enters this surface or its handoff. Country, badges, timer, rating, avatar, and UI screenshots never enter judge input; later evidence remains clean, face-obscured, exact-previewed, and consented.

### 5. Deliver explicit native iPhone and Mac composition

On iPhone, use the existing native navigation/presentation host, a top clock/status band, a stage scrolling the complete rails and large stacked panels, a subordinate Search details disclosure, and reachable safe actions respecting existing measured floating-navigation clearance. Follow the existing forty-four-point touch convention. Support short screens, landscape, long handles, and accessibility text sizes without clamps, clipped badges, hidden Cancel, or body cropping. Back/dismiss follows the same real pre-Go cancellation intent; restored post-Go state uses the active owner's explicit exit rule.

On native macOS 14+, preserve the existing title bar, traffic lights, full-screen, external display movement, and 800-by-600 minimum. Keep the real clock dominant at the top of content and the single Cancel search plus Search details in native toolbar density. Use a readable centered stage, not an iPhone bezel or width stretched to fill the window. Vertical rails/players remain vertical in minimum, laptop, wide, large/full-screen, and external-display windows. Short-window scrolling preserves reachable timer and actions. Live resize preserves state, focus, original cutoff, and meaningful scroll anchor; it cannot enqueue, reset, replay entrance, or recreate the camera.

Use standard native popover/sheet behavior for Search details; no custom global modal framework or new permanent inspector is required. A detail sheet neither pauses search nor silently readies a player. If pairing arrives while details are open, announce it once without automatic Ready; return focus to the valid next stage/control on dismissal.

Implement real camera/TCC failure presentation when preparation validity changes: denied/restricted, missing/busy, external/Continuity disconnect, and interrupted are not one generic error. Withdraw pre-Go eligibility, reconcile reservation, and route to existing preparation/Settings only where useful. No silent camera switch with stale preflight, rated Photos picker, freeze-frame camera, or fake availability.

### 6. Preserve lifecycle, focus, accessibility, and energy

Inactive, hidden, minimized, locked, backgrounded, or unavailable owning scenes immediately stop acquisition and decorative work and shield sensitive content. The shared owner marks availability and requests pre-Go withdrawal as its reviewed service contract requires; do not invent a local pause or extend the cutoff. Return first reconciles existing participation. No automatic fresh search after terminal state. A secondary observer closing must not cancel the actual owner.

Cmd-W/quit on known pre-Go search requests cancellation and preserves unresolved receipt state; do not invent a forfeit consequence. Current post-Go state delegates to the active-match confirmation where platform permits. Force quit is not preventable or a confirmed voluntary Forfeit. Preserve all existing commands and text editing.

Use semantic controls and platform focus. Return/Space act on the focused control only, never via a global event handler while typing. Escape closes details first, requests Cancel once in confirmed search, is nonduplicating during unresolved cancellation, performs Return in terminal search, and delegates to real exit confirmation after Go. Tab/Shift-Tab respects platform keyboard-navigation settings and reaches all actions and badge meanings. Focus remains visible; restore it after disclosures and state changes instead of leaving it attached to a removed control.

VoiceOver reads stage, labeled clock/certainty, range with Physique Elo units, own identity/all badges, unpaired opponent group, and panel/action structure in visual order. Announce milestone/status transitions once, not every timer tick. Range updates preserve focus. Name uncertainty honestly. Country, stale badges, zero earned badges, and Unplaced are distinct meanings. Support Voice Control, Switch Control, larger text, increased contrast, Differentiate Without Color, Reduce Motion, Reduce Transparency, and silent use.

### 7. Apply the specified restrained sports motion

Use the existing shared press spring where applicable, not a new global motion/style system. Preserve the following concrete events:

- First confirmed admission: panels settle upward no more than half the existing spacing and fade over 280 ms, once per attempt; no replay on tick, resize, restore, or badge update.
- Ongoing confirmed visible search: one subtle status-symbol underlight completes a twelve-second brighten/dim cycle. No progress ring, body sweep, radar, moving rival list, or percentage. Disable immediately for uncertainty/cancel/pair/terminal/invisibility/inactivity, Reduce Motion, Low Power Mode, or thermal constraint.
- Real displayed second: stable geometry and approximately 180 ms digit replacement/crossfade; skipped seconds jump to current time, no delayed cutoff or last-ten-second pressure.
- Confirmed range change: one 180 ms label/glyph opening inside its own bounds; no intermediate replay, sound, or widening body spotlight.
- Cancellation/uncertainty/restriction: semantic/protective change immediately, status settles within 160 ms; no animation gate.
- Real pair without withdrawal pending: the empty lower position resolves through readiness over 300 ms, with at most 1.02 scale settle. You stays above Opponent; all rails remain above both panels. No winner implication or automatic Ready.
- Confirmed terminal/recovery state: 180 ms status/action update; no shake, fabricated slot-refund counter, auto-retry, or artificial dwell.

Reduce Motion removes travel, scale, repeated ambient work, and numeric rolling; use final content immediately or at most 120 ms opacity for meaningful changes. Reduce Transparency uses readable opaque native/shared surfaces. At most one quiet ambient layer plus one brief focal event. Optional admission/pair haptic is preference-respecting and nonessential; no default sound/microphone or every-tick haptic. All deadlines, navigation, accessible final values, and actions are immediately current regardless of animation.

No per-frame I/O, provider calls, camera/session rebuilds, badge sorting, image decoding, font measurement, or whole-stage invalidation. Isolate the displayed clock update. Participation that must survive dismissal belongs to the shared owner, not a view task that is silently cancelled with the route.

## Prospective Files to Create or Modify

Discover actual implemented foundations before choosing the final edit list; reuse the established naming/ownership. Do not create these as disconnected empty shells.

- Create or finish `TimeMaster/Views/Physique/PhysiqueMatchSearchView.swift` for this stage if no existing search owner already exists.
- Reuse the implemented shared timer, public identity/badge rail, athlete/player panel, controls, routing, and accessibility patterns under the actual Physique view hierarchy. Add a search-local helper only for behavior genuinely unique to this view; no duplicate global component suite.
- Modify only the existing reviewed search presentation/connection portions under `TimeMaster/Services/Physique/` and the existing Physique navigation/session integration necessary for this exact connected stage. Do not rewrite camera, backend, model/rubric, result, identity-unlock, or other screen ownership.
- Reuse current `TimeMaster/Models/PhysiqueDuelModels.swift` where present; any necessary type adaptation must preserve the reviewed service contract, unknown states, operation identity, and public/private boundary. Do not create client-owned competitive authority.
- Follow actual target membership conventions for iPhone and native Mac if adding a source file; do not raise targets, weaken privacy configuration, or alter unrelated build settings.
- Update existing relevant behavior tests only when contracts genuinely change. Add a deterministic regression test only for a plausible user-visible uncertain edge such as late admission after Cancel or stale pair after confirmed release, following actual repository conventions. Do not add wiring, source-text, visual-copy, mock-echo, or incidental-default tests.
- Update only the appropriate implementation todos in `CYCLES.md` after the connected work and focused checks. Human review stays pending. Update product DOCKS only after accepted behavior, not with verification logs or completion checklists.

No changes to exercise privacy, exercise ratings/quotas, Profile's two-side shape, other workers' screens, unrelated navigation, AI Coach keys/providers, or the shared palette are authorized. A minimal necessary shared connection is not permission to redesign a shared foundation.

## Observable Acceptance — Both Platforms

These are required future observable outcomes, not claims that they have already passed.

| Scenario | iPhone observation | Native macOS observation | Shared authority consequence |
| --- | --- | --- | --- |
| Join and wait | Real clock after admission; complete rails above two large vertical positions; reachable Cancel | Native toolbar/title bar, dominant top clock, same vertical positions at minimum and wide sizes | One real reserved attempt, no consumed match, no invented opponent |
| Delayed/lost admission | Joining dash or Search not confirmed, not a fabricated 1:30 | Same semantics through resize/window recreation | Reconciliation retrieves one attempt, not another enqueue |
| Thirty/sixty-second boundaries | Real unit-labeled allowed band changes only when confirmed | Same behavior while details are open or window resized | Both bands must admit a pair; cap never bypassed |
| Search cutoff | Zero leads to Checking search status until receipt | Same after inactive/foreground return | Local clock does not finalize expiry; confirmed timeout releases once |
| No opponent | No opponent found, no fake rival, intentional Try again/Return | Keyboard-accessible equivalent in native density | Try again only after release/current eligibility; new <=90s attempt |
| Cancel and lost receipt | Immediate Cancelling then honest unresolved/reconciled state, safe Return | Escape/Cmd-W/native navigation preserve unresolved intent | No false receipt, no second charge/reservation, no rated history row |
| Pair/cancel race | No celebratory reveal after withdrawal; post-Go offers Rejoin/real exit | Same even if another window/device moved state | Cancel is never silently converted to rated Forfeit |
| Real pairing | Actual public opponent resolves in lower panel, badges above both; explicit Ready later | Still vertical on full-screen/external display | Search does not emit Ready, reveal early media, or create Go |
| Large text/short window | Full badges wrap/scroll; timer and actions accessible; no clamps | 800x600 and short/live-resized window retain same facts/focus | Geometry never changes queue identity or deadline |
| Camera/permission change | Correct existing preparation/Settings recovery, no camera held for search | Real TCC, busy, external/Continuity disconnect recovery | Withdraw/reconcile pre-Go eligibility; no rated file-picker fallback |
| Offline/background/restore | Shielded surface, no camera/ambient work, same confirmed state on return | Inactive/minimized/hidden lifecycle and owner/observer distinction | No clock reset, automatic new attempt, fake cancellation, or voluntary-forfeit inference |
| Trusted identity correction | Every actual badge, truthful tier/streak/region; stale versus none distinct | All details keyboard/pointer accessible, not hover-only | No local preview badges, identity inference, or judge-context leak |
| Reduced/low-power modes | Same facts/actions with static/short opacity and stopped decoration | Same while inactive/minimized and under energy constraints | Clocks/finality unchanged; no deferred service work until animation ends |

## Focused Checks and Actual Native Smoke Scenarios

Do not rerun a user-reported failure merely to confirm it. For implementation changes, run the smallest relevant build/contract checks, fix clear regressions in this slice, and exercise the real changed surface. Compilation or mocked state screenshots alone are not acceptance.

Use the actual reviewed persistent service and authenticated consenting adult test accounts in an authorized environment. A separate account must be genuinely eligible for a real pairing; do not generate fake peers, production bots, unsafe media, or provider costs without authorization. If physical camera or second-account access is missing, finish reachable real checks and name the exact unavailable scenario; do not claim it passed or replace it with a production mock.

Exercise this focused set on actual native surfaces where runtime exists:

1. Launch the real iPhone app and native Mac app. Enter search through real preparation. Observe actual admission, permitted own identity/badges, empty lower position, current clock/range, camera-off state, and Cancel. On Mac exercise the existing minimum, ordinary laptop, wide/full-screen, external-display movement if available, and live resize while waiting. On iPhone use short/landscape and the largest accessible text presentation.
2. Let a real unpaired search reach the authoritative cutoff. Observe that local zero does not invent terminality, confirmed no opponent releases the reservation, and deliberate Try again starts only one new attempt. Inspect the actual confirmed allowance/history state rather than assuming the UI message proves accounting.
3. Cancel before admission receipt, during a confirmed queue, and while a real pair is arriving using the authorized development environment's genuine transport interruption/failure mechanism where available. Lose the receipt, Return, relaunch or restore, and reconcile. Observe one pending intent, no second enqueue, no false release, no automatic rejoin after withdrawal, and no rating/history effect before Go. Do not broaden production retry/telemetry policy merely to construct a demonstration.
4. Use a real second eligible account to observe pair handoff to the vertical readiness stage without automatic Ready or early stills. Exercise the late-Cancel-after-real-Go edge only through the reviewed authorized match environment; observe Rejoin and the explicit real exit confirmation, not a silent forfeit. Keep any private photo out of logs, recordings, or documentation.
5. Disconnect/reconnect network during queue/cancel; background/lock iPhone; deactivate/minimize/hide/restore Mac. Observe privacy shielding, camera acquisition stopped, decorative activity paused, original cutoff preserved, uncertain state labeled, and restoration of the same current service state. Open a second local window/account session and verify it cannot reserve or charge again.
6. Exercise actual camera denial/restriction/busy/device-disconnect states reachable on the available hardware. On Mac include external/Continuity disconnect when hardware exists. Observe pre-Go reconciliation and useful preparation/Settings recovery, never a fake feed or rated library picker. Do not claim physical-device proof from a simulator placeholder.
7. Traverse with keyboard and VoiceOver on both platforms where available: all earned badge meanings, clock certainty/unit, details, Cancel, Check status, Try again, Return, and real recovery routes. Exercise Escape hierarchy, native sheet focus return, and Return/Space while a text field elsewhere is active. Check Voice Control/Switch Control through the available actual accessibility path; name any unexercised modality. Timer ticks must not flood speech.
8. Enable Reduce Motion, Reduce Transparency, increased contrast and larger text; exercise the current stage and a real state transition. Enable the actual low-power setting/available thermal simulation or inspect the supported energy path without claiming nonexistent hardware evidence. Confirm at least the visible stopped decorative behavior on inactive/minimized/background states and that service time does not stop. Use focused native performance inspection if clock ticks visibly invalidate the entire stage; do not launch an unrelated optimization project.

Permanent tests belong only to genuine behavior boundaries and must be deterministic, isolated, and full-suite-safe. Use temporary authorized smoke tooling when useful and remove it after proof; do not leave production test switches, fake queue data, screenshots, provider response dumps, or temporary scripts as feature code. Existing wording/source/implementation-pinning tests should be removed rather than re-pinned to this design.

## Human Verification Handoff — Required

At the end of actual implementation, list separately:

- The connected native search composition on iPhone.
- The native Mac composition, resize/window, and toolbar/input behavior.
- Real timer and bounded-band semantics.
- Admission, Cancel receipt, reconciliation, timeout, and deliberate retry behavior.
- Actual pair/Go handoff and ownership/privacy boundaries.
- Trusted all-badge identity, accessibility/focus, motion/reduced/energy behavior.
- Every changed file, with its concrete responsibility.

Ask the user to review the code changes and state that each implemented item is ready for human verification. Report only checks and native scenarios actually exercised, plus exact hardware/service/model/credentials limitations and unexercised cases. Never claim human approval, full accessibility compliance, physical camera proof from a simulator, measured fairness/population, or successful service accounting from animation alone.

No screenshots, recordings, private logs, or completion evidence package is required. Do not place any in DOCKS. Mark implementation completion only in the relevant `CYCLES.md` todos, not human verification. After the user accepts the resulting behavior, update the smallest relevant product DOCKS in plain language if needed.

## Mandatory Agent Rules

1. **Single owner, no nested agents.** Do this assigned slice yourself with the specified model/thinking. Do not spawn reviewers or a second implementation worker.
2. **Real connected behavior only.** No placeholders, no-op buttons, fake queue/opponents, production mocks, speculative scores, local rating, camera substitute, or invented service success. Preview fixtures are visibly labeled and never a production fallback.
3. **Respect scope and shared ownership.** Reuse existing reviewed contracts/components; make only the smallest necessary connection. Do not implement another UI owner's screen, a second router/state authority, or unrelated feature while here.
4. **User direction wins.** Native iPhone plus native Mac, full public badges above large vertical players, and honest animated minimal-text behavior override older contrary layout prose. Do not hide privacy or forfeit consequences for brevity.
5. **Research independently.** DOCKS is product context, not implementation authority. Follow current installed skills, actual source conventions, OS availability, and service contracts. No private APIs, unrequested frameworks, target raises, or parallel global theme.
6. **Complete and check the connected slice.** Run focused relevant checks and actual native smoke on available runtimes, fix clear failures, name real missing prerequisites, and do not yield a compiling but disconnected shell. Do not claim unrun checks.
7. **Update only project implementation todos in CYCLES.** No IDE-specific task JSON, duplicate todo system, verification evidence, code recipes, or completion checklists in DOCKS. Do not mark work human-verified.
8. **Scoped commit and push.** During this future implementation session, commit the scoped completed code/check/documentation edits with a clear message and push to `origin/main` before yielding, following the repository's publication policy. Do not include unrelated user edits or secrets, force-push, or rewrite history. An unavailable origin or failed push is an exact publication blocker, not completion. The earlier documentation-only worker did not run git; its main batch owner handles that integration.
9. **Human handoff is mandatory.** List every meaningful item and changed file separately, ask for review, and state observed limits. Update accepted product behavior only after user acceptance unless the user already directly approved that decision.
10. **No pointless next prompt.** Do not generate a testing-only, commit-only, obvious-fix-only, or generic follow-up prompt. Finish small reachable work now. Create another prompt only for an explicitly needed substantial, self-contained approved implementation slice, never to hide a missing prerequisite or unfinished search behavior.

## When You Finish

Report implemented items and changed files individually, actual focused checks/native smoke, exact limitations, and publication status. Ask for human review. State whether another prompt was needed; ordinarily this complete search assignment needs none. Do not report the design specification itself as a verified operating search.

## Scope Decision Before Finish

- Completed: enumerate the actually connected, checked, and handed-off search behavior, without equating it to human acceptance.
- Remaining: name only actual remaining prerequisites or unexercised hardware/service scenarios; do not invent unrelated polish work.
- Decision: no next prompt, a specifically authorized substantial next slice, or an exact external prerequisite blocker.
