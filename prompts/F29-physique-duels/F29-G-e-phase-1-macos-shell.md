# Phase 1 of F29-G-e — Native Mac Presentation Shell

## Execution Assignment and Mode

Required implementation worker: **openai-codex/gpt-6-astra:max**. Model identifier: **openai-codex/gpt-6-astra**. Thinking level: **max**. Max is the reasoning setting, not a different model and not an in-app judging policy. If this exact dispatch is unavailable, report the actual limitation; do not silently substitute another model or claim that a differently configured worker ran this brief.

This is a future implementation brief. The originating batch is documentation-only. Do not execute builds, app edits, generation, tests, formatting, git, or publication merely because this file was created. Implementation begins only when the user activates the slice and the prerequisite real shared foundations and contracts have been implemented and human-reviewed.

The UI worker is not the Physique image judge. GPT-6.1 Sol remains only the separately documented current judge candidate. This work does not change provider selection, model access, a rubric, consent, or competition policy.

## Features Included

- F29-G-e — Native macOS shell, responsive window composition, title-bar/toolbars/menu integration, ordinary route placement, focus, camera ownership presentation, privacy lifecycle, and state-aware close/quit.
- F29-A-a through F29-A-y — Integration of every reviewed ordinary view into that shell, using the explicit twenty-five-route matrix in the product context. These are integration consumers, not authorization to rebuild or independently redesign their owned screens.
- Native iPhone counterpart — Preserve and exercise the equivalent routes, shared vertical composition, capture privacy, focus, safe dismissal, and service recovery. Mac-specific code must not break the phone target or make its experience contingent on Mac window APIs.

List every meaningful implemented part and affected consumer in the human-review handoff. Do not mark the entire F29 feature implemented because its shell renders.

## Context

Physique Duels requires first-class native iPhone and macOS UI: a dominant real phase timer, all public badges above large You-then-Opponent panels, and tactile truthful sports motion.
The Mac keeps the existing 800 by 600 minimum, native chrome, commands, camera/TCC behavior, one active account match, and immediate privacy protection.
This slice integrates real reviewed ordinary views and service-owned state; it is not a desktop mock, Catalyst conversion, backend substitute, or deployment-target migration.

## What You Need to Read First

### Product authority and exact route inventory

Read these persistent product contexts before choosing an implementation. They describe behavior, not proof of working code:

- features/F29-physique-duels/DOCKS.md
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md
- features/F29-physique-duels/F29-F-battle-identity-and-badges/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-a-match-timer/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-c-battle-background/DOCKS.md
- features/F29-physique-duels/F29-G-native-ui-components/F29-G-d-score-counters/DOCKS.md
- CYCLES.md — the current F29 implementation and human-review entries; do not infer human approval from a documentation checkbox.

Read the integration, layout, state, and dismissal sections of every ordinary view. Missing implementation or review of these routes is a dependency gap, not permission to stub them:

| Route | Exact product-context path |
| --- | --- |
| F29-A-a — Lobby | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-a-lobby/DOCKS.md |
| F29-A-b — Account entry | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-b-account-entry/DOCKS.md |
| F29-A-c — Eligibility and consent | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-c-eligibility-and-consent/DOCKS.md |
| F29-A-d — Rules and rubric | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-d-rules-and-rubric/DOCKS.md |
| F29-A-e — Pose guide | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-e-pose-guide/DOCKS.md |
| F29-A-f — Camera setup | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-f-camera-setup/DOCKS.md |
| F29-A-g — Match search | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-g-match-search/DOCKS.md |
| F29-A-h — Ready room | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-h-ready-room/DOCKS.md |
| F29-A-i — Battle stage | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-i-battle-stage/DOCKS.md |
| F29-A-j — Pose review | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-j-pose-review/DOCKS.md |
| F29-A-k — Submission and judging | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-k-submission-and-judging/DOCKS.md |
| F29-A-l — Result | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-l-result/DOCKS.md |
| F29-A-m — Score breakdown | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-m-score-breakdown/DOCKS.md |
| F29-A-n — Pose gallery | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-n-pose-gallery/DOCKS.md |
| F29-A-o — Match history | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-o-match-history/DOCKS.md |
| F29-A-p — Standings | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-p-standings/DOCKS.md |
| F29-A-q — Player summary | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md |
| F29-A-r — Safety hub | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-r-safety-hub/DOCKS.md |
| F29-A-s — Report composer | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-s-report-composer/DOCKS.md |
| F29-A-t — Case center | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-t-case-center/DOCKS.md |
| F29-A-u — Case detail | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-u-case-detail/DOCKS.md |
| F29-A-v — Review composer | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-v-review-composer/DOCKS.md |
| F29-A-w — Privacy and sharing | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md |
| F29-A-x — Deletion status | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-x-deletion-status/DOCKS.md |
| F29-A-y — Badges and country | features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md |

### Existing source anchors and visual reference

Re-read current source; the line anchors describe the documentation pass and may move. Discover the reviewed Physique source files from the current tree rather than inventing parallel types.

- TimeMaster/App/TmaxApp.swift:8-19 — the native WindowGroup, current Mac 800 by 600 minimum, normal title bar, and command attachment. Read its account/scene lifecycle integration too.
- TimeMaster/App/TmaxCommands.swift:6-37 — preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O and their existing meanings.
- TimeMaster/Views/MainTabView.swift:60-146,283-310 — measured navigation integration, parent focus, notifications, and arrow/number key handling. These handlers exist; a runtime focus defect is not claimed by the documentation pass. Ensure Physique fields and lists receive their own keys before parent page-navigation shortcuts.
- TimeMaster/Utilities/Theme.swift:1-81,208-228 — shared palette, surfaces, and controls.
- TimeMaster/Utilities/ProfileDesign.swift:1-38 — Inter fonts, spacing, touch target, and readable column convention.
- TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80 — public availability fallback, Reduce Transparency, and response 0.24/damping 0.88 press feedback. Do not introduce private APIs or a separate material framework.
- TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188 — native action language and earned-rating crest, not permission to copy Dynamic Type clamps or fabricated levels.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151 — exercise HUD context only; no Physique provisional score or fixed tiny camera-height copy.
- TimeMaster/Models/LocalProfileModels.swift:23-27,99-109 — local cosmetic badge previews are editable and cannot establish trusted competitive achievements.
- TimeMaster.xcodeproj/project.pbxproj — existing native Mac and iPhone target membership and deployment settings. Preserve iOS 16 compatibility and macOS 14; do not raise unrelated widget/test targets either.
- TimeMaster/Info-macOS.plist and TimeMaster/TimeMaster-macOS.entitlements — inspect actual camera privacy/capability configuration before deciding whether a narrowly scoped change is needed; do not presume the required entitlement or purpose string is missing.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the supplied image. Borrow direct hierarchy, not horizontal pairing, web colors, faces, footage, labels, or unlicensed assets.

There is no STYLES.md to create. Existing source is the shared style authority. Do not create a new global style document or restore removed unrelated feature documentation.

### Relevant skills and current native guidance

The UI Skills selection for the design batch was dimillian/swiftui-ui-patterns. Use the selected context where installed; do not repeat setup, install another UI system, or pretend a missing skill file was read. Read the relevant installed native guidance:

- skill://swiftui-pro and its references/navigation.md, references/accessibility.md, and references/performance.md.
- skill://swiftui-animation — scope events, interruption, reduced motion, and availability; its newer default platform assumptions do not override this project's targets.
- skill://apple-hig-reference, selecting only the native topics needed below.
- skill://ui-ux-mastery/references/loss-framing.md when implementing consequential exit or privacy warnings; no invented penalties, deadlines, or receipts.

Current Apple references:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- https://developer.apple.com/design/human-interface-guidelines/windows
- https://developer.apple.com/design/human-interface-guidelines/toolbars
- https://developer.apple.com/design/human-interface-guidelines/sheets
- https://developer.apple.com/design/human-interface-guidelines/motion

Validate actual API availability separately. Modern HIG illustrations are not authority to use macOS 26-only APIs on macOS 14 or to redraw native window controls. Prefer ordinary SwiftUI presentation and the smallest necessary public AppKit lifecycle integration over an application-wide window framework.

## What Happened Last Session

The documentation worker read the absolute-path shared design contract, existing F29 product rules, native SwiftUI/HIG guidance, supplied source anchors, and the reference image. It specified a native current-window composition, every ordinary route's platform integration, camera/TCC states, privacy and ownership boundaries, and close/quit consequences. It wrote only this brief and F29-G-e's product DOCKS.

No Swift code, UI runtime, production camera path, model call, asset generation, smoke run, build, test, lint, formatter, git commit, or push was performed by that documentation worker. The coordinated main owner owns integration validation and publication of the documentation batch. No human acceptance of a running interface or physical-camera compatibility is implied.

## Prerequisites and Human-Review Boundaries

Begin production code only after the real shared foundations and contracts are implemented and human-reviewed. Required foundations include account restoration, preserved navigation, Physique authoritative stage/deadlines, account-wide reservation and match ownership, acknowledged evidence/retake state, local capture and fail-closed redaction, consent and media authorization, report/block/withdrawal effects, result finality, and the ordinary view/components consumed here.

Public rated operation also requires the authorized persistent HTTPS service, actual model access under the accepted configuration, protected media operation, and staffed moderation. A documented route, local service URL, available camera, or returned model JSON does not establish these prerequisites.

Read CYCLES and current code to determine what is actually reviewed. Do not infer approval, skip a missing dependency, assemble a second fake state machine, or mark this shell shippable before its consumers work. If a prerequisite is genuinely missing, identify the exact missing foundation and finish only reachable authorized work; do not deliver dead UI, a stub service, or a production mock fallback. Do not ask the user for information already available in the repo or tools.

The twenty-five ordinary views retain their design ownership. This slice adds their common Mac placement/lifecycle contract and necessary integration adapters. It does not invent a new support screen, rewrite their service contracts, change badge semantics, or redesign the rest of Tmax. A newly necessary custom screen requires explicit ownership rather than being hidden inside the shell.

## Design Decisions to Preserve

1. **Current native window, not modal match or window proliferation.** Keep the existing primary window and normal chrome. Active participation uses its available content region; short scoped forms use attached native sheets. This avoids trapping a full match in a phone-shaped Mac sheet or opening one window per route.
2. **Large vertical players at every width.** Real phase timer first, complete owner-grouped identity/badge rails next, then You above Opponent. Both evidence panels remain substantial and aspect-fit. Shortness produces stage scrolling, not tiny participants, a two-column matchup, clipped badges, or a larger global minimum.
3. **Top critical controls on Mac.** Timer and state-aware Cancel/Exit, Safety, Stop camera, and current primary action remain usable while content scrolls and when full-screen chrome hides. Do not rely on a bottom-only action bar. Ordinary unrelated routes do not receive a decorative pressure countdown.
4. **Native detail disclosure.** A trailing inspector is secondary and appears only when actual content fits. At constrained width, use the same route's in-content disclosure. Resizing never auto-opens a sheet or throws away detail state. Mandatory consent and safety do not live only in an inspector.
5. **Same authority, platform-appropriate density.** Mac uses native pointer, menu, toolbar, sheet, and focus conventions. iPhone uses touch-safe controls, native navigation and keyboard-aware forms. Both use the same reviewed match, privacy, identity, and media meanings.
6. **Privacy before presentation.** Inactive/minimized/background/locked/obscured capture stops and private surfaces shield immediately. An animation, modal confirmation, or slow service cannot delay protection. Resumption is explicit after same-match reconciliation.
7. **One account match and one acquisition owner.** Secondary windows bring the owner forward; they do not duplicate camera, Ready, Submit, reservation, charge, or award. Device recovery must be explicitly service-authorized and respect source-change rules.
8. **Close is a state decision, not always forfeit.** Pre-Go cancel, active incomplete participation, acknowledged waiting/judging, final result, unknown receipt, and forced termination have distinct consequences. Respect real service boundaries and never reinterpret an earlier Cancel as permission for a rated loss.
9. **Tactile but truthful.** Shared short spring/status/stage motion, one quiet ambient layer, and one bounded final reveal. No camera shader, body scan, fake analysis percentage, leader before finality, humiliating motion, or second celebration on window restoration.

## What to Build

### 1. Integrate the real native shell and every ordinary route

Connect the shell to the actual Physique destination without resetting saved page order, changing the current page unnecessarily, restoring a removed Ranked page, or changing Profile's two-side shape. The same reviewed ordinary route must work in its defined Mac presentation and iPhone counterpart. Follow all twenty-five rows of the F29-G-e route table; do not implement only lobby and battle and call the route inventory covered.

Keep browsing and setup in the current content hierarchy. Use native toolbar navigation, a context-appropriate title that does not expose sensitive data in system UI, menu equivalents, readable optional inspector, and one attached sheet at a time. System permissions, alerts, share sheets, account controls, and camera pickers are reused rather than wrapped in redundant custom features.

Bind loading, refresh, genuine empty, stale cache, offline-without-cache, permission denied, service unavailable, restricted identity, invalidated route, and receipt uncertainty to actual data. Preserve reading position, exact record selection, valid safe form text, and the intended return route. Never turn an unavailable record into zero, an empty ladder, a fabricated player, or success.

On active-task sheets, provide functional current deadline/exit context because the parent is modal-inaccessible. Do not inject a running match timer into ordinary standalone account, privacy, or support visits. A final event while a report is being edited updates safe status without dismissing the draft or opening imagery.

### 2. Implement responsive vertical battle hosting

Compose the reviewed shared clock, complete F29-F rails, player panels, background, and score components. Do not create replacements in the shell. Make the timer the top anchor and retain the two rails above both large vertically ordered player panels. Use measured usable geometry and existing spacing/readable-column conventions, not fixed screen coordinates or a device-name breakpoint.

Support the actual 800 by 600 minimum, laptop windows, large/full-screen windows, external displays, live resize, short height, and enlarged text. Timer and safe actions remain reachable; all badges wrap and remain represented. Allow the center to scroll instead of imposing a three-badge cap or shrinking body imagery. When all content cannot fit simultaneously, useful large evidence and scrolling are the accepted outcome.

Both participant frames use consistent evidence framing and aspect fit. Do not favor one body with zoom, crop required limbs, allow chrome over anatomy, or use a screenshot as submitted evidence. The opponent before finality remains a permitted avatar or neutral figure plus actual stage/count. Final screens remove the active capture countdown and show a truthful final phase or actual service-supplied timing.

Resizing or changing display scale must preserve camera and route identity, selected pose, counters, pending requests, ownership, focus, and deadlines. Do not let layout changes send Ready or create another network operation.

### 3. Connect native command and focus behavior

Preserve the meanings of Command-N, Command-Shift-R, Command-comma, and Command-Option-O. Add only the contextual Physique commands actually supported by the reviewed route actions. Give native toolbar actions menu equivalents; let the system handle toolbar overflow. Do not add global bare-letter or number shortcuts.

Use focused-window/route ownership so process-wide notifications cannot invoke the same interactive action in every window. Gate the existing MainTabView parent key handling while text, a list, a picker, a sheet, or an active Physique task owns those keys. Do not broadly rewrite unrelated navigation. Return and Space activate only a focused semantic control; they never take a picture from a report field. Arrow and number keys retain editing/navigation semantics inside their controls.

Implement the specified Escape ordering, draft protection, sheet return focus, heading/error announcements, visible focus rings, accessible badge and region labels, and non-color status. Hover and context menus may supplement, not replace, visible safety actions. Closing a sheet must not fall through to close/forfeit the window behind it.

### 4. Connect actual camera/TCC and source-change recovery

Consume the reviewed capture owner rather than making a second camera in the shell. Differentiate not requested, authorized, denied, restricted/managed, no hardware, busy, failed start, disconnected external camera, unavailable Continuity Camera, permission revocation, and interrupted capture. Use actual discovered devices; offer useful Settings guidance only where appropriate. Never promise that Retry can override a management restriction.

Do not silently substitute a built-in camera when the selected external or Continuity camera disconnects. Do not start capture on window activation, permission return, hardware reconnect, resize, or display movement. Require the explicit eligible Start preview/Resume camera path and real same-match state.

After Go, a changed source discards the person's selected set and requires the whole set again inside the original deadline and remaining retake budget. Never mix previously accepted images from the old source into the new set. If the capture foundation cannot express this actual transition, it is a dependency gap to resolve with its owner, not a view-only reset.

Every transmitted candidate and still must use the exact locally face-obscured representation. A failed mask or bystander fails closed. No microphone, broad Photos access, location, Contacts, HealthKit, face identity, or screen-recording permission belongs here. Simulator/no-camera operation is an honest unavailable route, not a recorded feed or rated file-upload fallback.

### 5. Connect activity, visibility, privacy, and explicit resume

Observe native window activity/visibility as well as app scene state. An app-wide active flag alone is insufficient when the match window is inactive on another display while a different Tmax window is key. Distinguish the owner and its attached sheet from a second window; ordinary same-window menu tracking does not create a new match or falsely restart the camera.

Stop acquisition and shield sensitive content on loss of owner activity, minimize, hide, actual background, lock, sleep, relevant interruption, or an overlaying ordinary task that hides capture. Cover bodies, exact still previews, private account/eligibility details, report/review text, and app-controlled snapshots with an opaque surface. Cancel an armed self-timer; do not defer its capture until activation. No protective effect waits for animation or server acknowledgement.

On return, authenticate/reconcile the existing match and current media authorization before revealing permitted content. Camera resumes only explicitly. Gallery images require the route's intentional reveal again and fresh access checks; stale cached imagery never flashes before an expired/blocked/withdrawn placeholder. Restore deadlines, retakes, and accepted versions without additional reservation or allowance consumption. Already received evidence may finish judging on the service without any camera.

Sign-out, account switch, access revocation, and deletion clear affected private state across all windows. Account-scoped text-only report drafts follow the real twenty-four-hour/discard/sign-out lifetime; they are not retained body evidence or a server receipt. Window restoration persists safe navigation references, never body photos or an armed destructive command. Do not claim screenshot prevention beyond surfaces the app actually controls.

### 6. Connect close, quit, and race handling

Use the native window-close and ordinary app-termination pathways, with only the minimal public platform bridging required by the existing architecture. Route red close, Command-W, menu Close, state-aware in-app Exit, and normal Command-Q through the correct current context without blocking unrelated harmless window closure.

Implement the full product state table:

- Idle/read-only closes normally; setup stops its camera and closes without an invented penalty.
- Pre-Go cancel requests have no rating consequence only when accepted before Go. Show pending cancellation honestly. If Go wins the race, refresh the choices and require a fresh explicit forfeit decision.
- Started participation still requiring capture/transfer has a native Keep match open versus Forfeit and close/quit decision. State the eligible rated loss and consumed slot; safety/invalid/service no-contest precedence remains authoritative.
- Submitted/waiting states use acknowledged obligations, not a string comparison against a view title. A completed service-acknowledged participation with no remaining local work may leave a pending result without silently forfeiting. Incomplete upload cannot be described as safe completed submission.
- Both sets received permits ordinary close with continuing server judging. Final results close without changing finality. An explicitly chosen forfeit is separate from leaving a visual waiting screen.
- Unknown state or receipt offers truthful retry/keep-open and an explained local close; never trap the user indefinitely or promise a result/remote cancellation. A request already received may still settle. Reopening resolves the same match.
- Force quit, crash, power loss, or OS termination without a confirmation opportunity cannot be prevented and is not a confirmed voluntary-forfeit request.

Handle finalization while a confirmation is open, Go during Cancel, multiple close gestures, repeated keys, and quit while a sheet is active. One match receives one consequence decision and authoritative effect. Do not delay camera stop until the person answers. Safe cancellation of an exit leaves the camera off until explicit resume. Never queue a prior forfeit for a newly restored or different match.

### 7. Enforce presentation ownership across windows and devices

Use the reviewed shared match/camera authority. A secondary window opening the active match shows Match open in another window and a functional Show match window command; it cannot capture, become Ready, submit, reserve another slot, or falsely display another local live session. Closing it does not forfeit the owner. Existing noncamera routes remain usable in other windows, with proper private shielding when inactive.

Do not build an unnecessary general-purpose window-transfer product. If the owner is lost, offer explicit Resume existing match only after the old local owner is released and real service recovery permits the same match. A second device cannot seize active capture by rendering a view. Recovery on another device requires service authority and the source-change/evidence rules. If ownership is uncertain, show Check status, not optimistic capture.

One final record can be read in several authorized windows; that does not authorize repeated rewards or disclosures. Scope interactive menu actions to the focused surface. Any required ownership changes belong to the shared foundation and must be real, not a second view-local lock that ignores other devices.

### 8. Apply motion, accessibility, availability, and energy contracts

Reuse the shared press spring, approximately 180-millisecond local status changes, approximately 280-millisecond stage continuity, the shared real-second countdown, and stable approximately 180-millisecond timer digits. Let native windows, sheets, and full-screen transitions use native timing. Live resize follows the user with no added spring.

At most one quiet approximately twelve-second ambient layer and one focal event may run. The shell adds no extra animated background. Valid result values and safe actions are immediately available; shared score/Elo motion remains approximately 650/450 milliseconds within 900 milliseconds total, not a queue of delayed reveals. History, reconnect, resize, and secondary-window viewing do not re-award. Corrections are distinct labeled review events.

Reduce Motion gives static or short-opacity equivalents; Reduce Transparency gives opaque legible surfaces. Privacy covers are opaque regardless of settings. Large text reflows; no new Dynamic Type clamps or minimum-scale tricks. Final accepted numbers are the accessible values immediately, not interpolated scores. Announce milestones, not every tick.

Pause decoration when offscreen, inactive, minimized, backgrounded, or obscured. Low power and significant thermal pressure remove ambient work and optional transitions before affecting clarity; never skip redaction or evidence requirements. If safe capture is not sustainable, stop truthfully. Do not perform per-frame I/O, provider requests, image decoding, font measurement, camera reconstruction, or whole-window relayout. Preserve the existing deployment targets and provide public fallbacks for newer effects.

## Prospective Files and Ownership

Discover and reuse current reviewed files before creating these proposed locations. Names below do not assert that any file already exists.

| File or area | Intended scope |
| --- | --- |
| TimeMaster/Views/Physique/PhysiqueMacShell.swift | Native Mac composition, readable stage, toolbar/inspector/disclosure placement, ordinary route hosting, and presentation integration. |
| TimeMaster/App/PhysiqueMacWindowLifecycle.swift | Only if needed: narrow public native window/termination integration for the reviewed Physique owner. Do not replace the app delegate, global window architecture, or unrelated feature lifecycles. |
| Existing reviewed TimeMaster/Views/Physique/ route and component files | Necessary shell attachment and platform placement for all twenty-five ordinary routes; preserve their owned content and domain meaning. No duplicate view family. |
| Existing reviewed TimeMaster/Services/Physique/ and shared state/model files | Consume actual match/camera/privacy ownership and obligations. Change only a clear required integration gap with its ownership respected; no parallel queue, authority, or provider. |
| TimeMaster/App/TmaxApp.swift | Minimal scene/window attachment while retaining title-bar style, minimum size, unrelated scene behavior, and both native targets. |
| TimeMaster/App/TmaxCommands.swift | Contextual, focused Physique menu integration with every existing binding preserved. |
| TimeMaster/Views/MainTabView.swift | Feature-scoped route/focus/command ownership integration, no unrelated page-order or navigation redesign. |
| TimeMaster/Info-macOS.plist; TimeMaster/TimeMaster-macOS.entitlements; TimeMaster.xcodeproj/project.pbxproj | Only justified target membership or actual capture privacy/capability changes; no target raise, signing bypass, broad new permission, or unrelated configuration cleanup. |
| Existing relevant native test targets | Update broken behavioral contract tests and add regression coverage only for plausible consumer-visible ownership, privacy, close-race, or focus bugs. No source-text or wiring-only tests. |
| CYCLES.md | Update only the implemented scope's existing implementation todos and honest remaining human-review status after connected checks. Do not claim acceptance. |
| features/F29-physique-duels/F29-G-native-ui-components/F29-G-e-macos-shell/DOCKS.md | Update accepted product decisions only after user acceptance, or a directly preapproved product decision; no logs, code recipes, proof packages, or implementation checklists. |

Do not create a second app theme, a replacement window framework, an unowned twenty-sixth custom screen, new artwork, media generation, or a mock server as part of this slice. If a proposed file is unnecessary because a reviewed existing owner already handles the behavior, reuse that owner rather than adding abstraction.

## Observable Acceptance — Both Native Platforms

### Mac composition and input

- The native Mac application opens the actual Physique destination at its existing 800 by 600 minimum. The stage scrolls; timer and safe controls remain usable; no required action is clipped or hidden behind a sheet or the bottom window edge.
- Laptop, wide, full-screen, and external-display layouts keep all public badge rails above two large vertical player panels. All badges wrap; no +N cap, ticker, hover-only access, body crop, unequal zoom, or horizontal matchup appears.
- Optional details are a readable inspector only when there is room; compact reflow retains the same detail content without a surprise modal. Live resize retains match, evidence, focus, and camera identity.
- Every ordinary route F29-A-a through F29-A-y opens in its specified native presentation and returns correctly, including account restoration, rules, guide, reports, cases, privacy, deletion status, and badges/country. No route has a no-op button or static-only service stand-in.
- Native close/minimize/full-screen controls, title bar, menu bar, sheets, toolbar menu equivalents, pointer feedback, and focused keyboard navigation work. Existing four command bindings retain their original meanings and fire once for the intended context.
- Typing spaces, returns, arrows, and digits in report/review/account controls never captures a still or changes the main app page. Escape and Command-W act on the top meaningful context and restore focus safely.

### iPhone composition and behavior

- The same reviewed feature routes remain native and connected on iPhone. Timer, complete rails, You, Opponent remain vertical in narrow, short, larger-text, and supported landscape geometry.
- Touch targets and safe-area clearance remain usable; keyboards do not cover consent, report, or recovery actions. Scrolling preserves substantial evidence instead of shrinking players to fit a screenshot.
- Pre-Go sheet/back behavior is native. Active capture cannot be accidentally abandoned by swipe; explicit exit presents the current consequence. Permission return, backgrounding, interruption, and camera resume use the same authority and privacy boundaries as Mac.
- All scores, badges, country meaning, safety, gallery access, stale/empty/error state, and return destinations agree across platforms. Mac-only lifecycle integration introduces no unavailable-API dependency into the iPhone target.

### Authority, privacy, and recovery

- Actual camera denial/restriction/absence/busy/disconnect and Continuity loss remain distinct useful states; no synthetic rated preview or library substitute appears. After source change, no mixed old/new accepted set survives.
- Switching away, minimizing, locking, obscuring capture with a form, losing authorization, or changing accounts stops acquisition and shields immediately. An armed capture cannot fire after reactivation. Gallery body images do not automatically reopen.
- Resumption retrieves the same account match and acknowledged evidence, preserves original deadlines/retakes, and consumes no second slot. New pairing and capture are unavailable in secondary windows/devices while another owner is active.
- Pre-Go cancellation crossing Go does not become a silent forfeit. Ordinary close during acknowledged judging does not create a forfeit. Finalization during an exit dialog makes its old warning obsolete. Unknown receipt stays unknown until reconciled; force quit is not called a confirmed voluntary action.
- No UI screenshot, country, badge, public identity, local cosmetic preview, or app chrome enters judge inputs. Face obscuring fails closed before every transmitted image. Opponent pre-result content has no video, audio, early still, or live appearance score.
- Only current authorized valid judged results expose intentional counterpart stills. Hide/report protection is immediate, expiry remains tied to finalization, block/withdrawal/correction effects stay truthful, and another window or cache cannot bypass revocation.

### Motion and energy

- Actual Ready, pairing, clock, accepted-pose, and final-result events receive the specified shared feedback without fake progress. Safe actions and final accessible numbers are usable from the first final-state presentation.
- Reduce Motion, Reduce Transparency, increased contrast, VoiceOver, keyboard navigation, and enlarged text preserve meaning and all actions. Native dialogs remain readable at minimum size.
- Inactive, minimized, background, and offscreen surfaces stop decorative work. Low-power/thermal behavior reduces atmosphere without changing clocks, skipping privacy, or pretending lost camera capability still works. Resize/timer updates do not reacquire camera or trigger repeated decoding/network work.

## Focused Verification — Future Implementation Only

This section is a prospective scenario plan, not evidence that any checks ran. Use available native runtimes and authorized isolated accounts/services. Do not modify or delete real user data merely to exercise account deletion. A simulator can prove navigation and honest no-camera behavior; it cannot prove physical camera, TCC, Continuity, or complete rated capture.

1. **Native minimum and resize smoke.** Launch the actual native Mac target, enter Physique, and exercise lobby, a real paired stage, pose review, and an authorized final detail at 800 by 600. Resize to laptop and wide windows, enter/leave full screen, and move across available displays. Observe order, complete badge wrapping, substantial aspect-fit panels, stable focused control, reachable clock/actions, and unchanged match/camera state. If an external display is unavailable, state that exact unexercised surface rather than claiming it works.
2. **Route-inventory smoke.** From legitimate entry points, open and return from every ordinary route on Mac and iPhone. Use real available empty, loading/failure, and authorized populated states without production mocks. Check that system account/permission/share/confirmation presentations are reused and that a report or review draft survives a result arriving without auto-opening media.
3. **Keyboard/pointer smoke.** In a report or review note, type spaces, new lines, arrow keys, and digits. Traverse the camera chooser, list rows, Details, primary action, Safety, and sheet dismissal using only keyboard. Observe no unintended capture/page change and correct focus restoration. Invoke preserved app commands and the focused Physique menu with two windows present; observe one intended action.
4. **Camera availability smoke.** On real Mac hardware, exercise the actual available denial/permission-return and connected-camera path. Disconnect the selected external or Continuity source when available; observe immediate stop, shield, honest device state, no silent fallback, and explicit eligible same-match resume. Verify the shared source-change rule after Go with authorized consenting participants. Name missing hardware or permission-reset capability; do not simulate a camera in production to claim the check passed.
5. **Privacy lifecycle smoke.** During preview, an armed self-timer, selected-still review, an intentionally opened gallery, and a private draft, switch app/window, minimize, and exercise lock/sleep where available. Observe the real acquisition indicator stop and the private surface cover immediately. Return and confirm no delayed capture, auto-revealed gallery, reset deadline, or duplicate charge. Check sign-out/account-switch revocation with isolated accounts.
6. **Close/quit boundary smoke.** Exercise ordinary red close and Command-W before Go, active required capture, accepted waiting/judging, a final result, and an unknown/offline acknowledgement state. Exercise normal Command-Q with a meaningful sheet open. Use the real controlled service's stage transitions to cover Go during cancel and finalization during a confirmation. Confirm the result/allowance from the same service record, not from the alert text. Force-termination recovery is a separate interruption scenario, not a confirmable-forfeit test.
7. **Ownership smoke.** Open a second supported app window without stealing Command-N's meaning. Attempt to open the active match; observe Show match window and no second camera/queue. Close the secondary window; owner state must remain. Where two authorized devices exist, exercise existing-match recovery and verify service ownership and unchanged accounting. Do not claim cross-device proof from a local window-only check.
8. **Accessibility and energy smoke.** On both platforms, use VoiceOver, enlarged text, Reduce Motion, and Reduce Transparency on the battle, a long consent/report form, and an unavailable-media state. On Mac, include Full Keyboard Access and display scaling where available. Observe milestone-only speech, immediate final values, opaque privacy protection, and operable actions. Observe camera and decorative activity cease when inactive/minimized; exercise available low-power/thermal policy without claiming thermal hardware coverage that was not run.

Run the smallest relevant build and existing behavioral tests after changes, then launch and exercise the changed native surface; compilation or unit tests alone do not prove the shell. Keep regression tests only for plausible consumer-visible failures such as wrong-owner acquisition, stale close decisions crossing Go, resumed armed capture, account-switch disclosure, or duplicate authoritative effects. Do not add tests that merely assert source strings, view wiring, forwarding, or mock echoes.

Fix clear local failures found during this slice. Do not rerun a user-reported failure simply to confirm their observation. Report only exercised verification and precise missing prerequisites/hardware. Do not create screenshot packages, private body recordings, evidence files in DOCKS, or an unsupported frame-rate claim.

## Human Verification Handoff — Required

List separately:

- Native shell composition and adaptive inspector/disclosure.
- All ordinary-route integration, identifying any route not actually connected rather than hiding it in an aggregate claim.
- Toolbar/menu/keyboard/focus behavior and preserved app commands.
- Camera/TCC/source-change recovery presentation.
- Inactive/minimized/background privacy and explicit same-match resume.
- State-aware close/quit and authoritative boundary/race handling.
- Multiwindow/device ownership behavior actually implemented.
- iPhone preservation and shared accessibility/motion/energy behavior.
- Each changed file and the exact focused checks/scenarios exercised.

Ask the user to review the code changes; state that each implemented item is ready for human verification, not human-approved. State any missing physical camera, Continuity, second device, external display, runtime, service, or review prerequisite plainly. A complete shell handoff does not claim App Store approval, fair judging, or completion of unrelated F29 work.

Update only the affected implementation todos in CYCLES after the connected implementation and focused checks, with human review still pending. Do not put completion evidence, screenshots, code, payloads, tasks, or verification claims in DOCKS. After the user accepts any changed product decision, update the smallest correct product context in plain language.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do this implementation slice yourself. Do not spawn reviewers, generation workers, or parallel editors. Do not change other workers' product decisions or unrelated files.
2. **Real connected behavior only.** No dead controls, placeholders, production fixture models, fake opponents, scores, badges, cameras, local rating, fabricated receipts, or hidden judge fallback. Preview-only fixtures must be clearly labeled and never reachable from production routing.
3. **User direction wins.** Preserve first-class native iPhone and Mac, all public badges above large vertical participants, concise but complete consequential copy, and animated truthful sports feedback. An older two-column idea or generic new-app skill default cannot override this direction.
4. **Independent implementation research.** Read product context and relevant installed skills, current public framework documentation, and existing source. Validate APIs against supported targets. No private API, target raise, unrelated architecture, or new global theme.
5. **Preserve privacy and authority.** No client verdict, no forced-quit-forfeit inference, no background acquisition, no live opponent stream, no screenshot-as-evidence, no unmasked fallback, and no window-level substitute for account-wide authority.
6. **Focused actual verification.** Exercise the changed native Mac and iPhone surfaces where runtime exists, with real service state and actual physical camera where needed. State unexercised limitations. Fix clear failures; no compile-only completion or test-only handoff.
7. **Scoped commit and push in the implementation session.** After each completed coherent implementation slice, commit only authorized changes with a clear message and push to origin/main. Never force-push, rewrite history, or include unrelated user changes. If publication fails, report the exact blocker and do not claim publication. This rule does not authorize git in the originating documentation-worker batch.
8. **CYCLES is the only implementation dashboard.** Update only affected implementation todos after connected checks, not human-approval status. No IDE task JSON or duplicate project checklist.
9. **No evidence in product DOCKS.** Keep source, tests, implementation notes, and verification handoff separate from plain-language product behavior. Update accepted product decisions at the permitted review boundary.
10. **Complete the connected slice.** No scaffolding as completion, silent route omissions, postponed obvious fixes, or a separate handoff solely for tests/docs/commit/push. Unreachable prerequisites must be named precisely after finishing reachable authorized work.
11. **No pointless next prompt.** Do not create another prompt for routine verification, minor fixes, publication, or cleanup. A new prompt is appropriate only for separately authorized substantial work with explicit ownership; do not inflate this shell into a new feature tree.

## Scope Decision Before Finish

Report implemented connected behavior, remaining real blockers, exercised verification, changed files, commit/push status, and the human-review boundary. Say whether a next prompt was necessary and why. Do not claim completion of unrun hardware scenarios, unreconciled ordinary routes, missing foundations, or the full Physique product.
